import { z } from "zod";

export const internalNoteAvailability = {
  available: false,
  reason: "Private note saving is pending protected deployment and caller acceptance.",
} as const;
export const internalNoteScopeSchema = z.object({
  reviewId: z.string().uuid(), sourceRevisionId: z.string().uuid(), masterVersionId: z.string().uuid(),
}).strict();
export const internalNoteSaveSchema = internalNoteScopeSchema.extend({
  expectedVersion: z.number().int().nonnegative(), body: z.string().max(12_000), requestKey: z.string().uuid(),
}).strict();
const receiptSchema = z.object({
  id: z.string().uuid(), review_id: z.string().uuid(), author_user_id: z.string().uuid(),
  source_revision_id: z.string().uuid(), master_version_id: z.string().uuid(),
  version_number: z.number().int().positive(), expected_version: z.number().int().nonnegative(),
  body: z.string().max(12_000), request_key: z.string().uuid(), saved_at: z.string().datetime({ offset: true }),
}).strict();
export type InternalNoteScope = z.infer<typeof internalNoteScopeSchema>;
export type InternalNoteSave = z.infer<typeof internalNoteSaveSchema>;
export type InternalNoteReceipt = z.infer<typeof receiptSchema>;
type Rpc = (name: string, args: Record<string, unknown>) => Promise<{ data: unknown; error: { message: string } | null }>;
function receipt(value: unknown, scope: InternalNoteScope, actorId: string): InternalNoteReceipt {
  const parsed = receiptSchema.parse(value);
  if (parsed.review_id !== scope.reviewId || parsed.source_revision_id !== scope.sourceRevisionId
    || parsed.master_version_id !== scope.masterVersionId || parsed.author_user_id !== actorId
    || parsed.version_number !== parsed.expected_version + 1) throw new Error("Private note scope was not confirmed.");
  return parsed;
}
/** Internal caller-bound adapter. Application entry points must retain the deployment gate. */
export async function readOwnInternalNoteRpc(rpc: Rpc, input: InternalNoteScope, actorId: string) {
  const scope = internalNoteScopeSchema.parse(input);
  const { data, error } = await rpc("read_own_requirement_internal_note", {
    p_review_id: scope.reviewId, p_source_revision_id: scope.sourceRevisionId, p_master_version_id: scope.masterVersionId,
  });
  if (error) throw new Error(error.message);
  return data === null ? null : receipt(data, scope, actorId);
}
export async function saveOwnInternalNoteRpc(rpc: Rpc, input: InternalNoteSave, actorId: string) {
  const parsed = internalNoteSaveSchema.parse(input);
  const { data, error } = await rpc("save_requirement_internal_note", {
    p_review_id: parsed.reviewId, p_source_revision_id: parsed.sourceRevisionId, p_master_version_id: parsed.masterVersionId,
    p_expected_version: parsed.expectedVersion, p_body: parsed.body, p_request_key: parsed.requestKey,
  });
  if (error) throw new Error(error.message);
  const saved = receipt(data, parsed, actorId);
  if (saved.request_key !== parsed.requestKey || saved.expected_version !== parsed.expectedVersion
    || saved.body !== parsed.body.replace(/^ +| +$/g, "")) throw new Error("Private note save was not confirmed. Refresh before retrying.");
  // A separate caller-authorized read is required; failure does not imply write rollback.
  const readback = await readOwnInternalNoteRpc(rpc, parsedScope(parsed), actorId);
  if (!readback || readback.id !== saved.id || readback.version_number !== saved.version_number
    || readback.body !== saved.body || readback.request_key !== saved.request_key) {
    throw new Error("Private note changed or could not be read back. Refresh before retrying.");
  }
  return readback;
}
function parsedScope(input: InternalNoteScope): InternalNoteScope {
  return { reviewId: input.reviewId, sourceRevisionId: input.sourceRevisionId, masterVersionId: input.masterVersionId };
}

