import { z } from "zod";

export const highlightDraftAvailability = {
  available: false,
  publicationAvailable: false,
  reason: "Highlight draft saving is pending protected deployment and caller acceptance.",
} as const;
export const highlightDraftScopeSchema = z.object({
  reviewId: z.string().uuid(), sourceRevisionId: z.string().uuid(), masterVersionId: z.string().uuid(),
}).strict();
export const highlightDraftSaveSchema = highlightDraftScopeSchema.extend({
  expectedVersion: z.number().int().nonnegative(), body: z.string().max(12_000), requestKey: z.string().uuid(),
}).strict();
const receiptSchema = z.object({
  id: z.string().uuid(), review_id: z.string().uuid(), author_user_id: z.string().uuid(),
  source_revision_id: z.string().uuid(), master_version_id: z.string().uuid(),
  version_number: z.number().int().positive(), expected_version: z.number().int().nonnegative(),
  body: z.string().max(12_000), request_key: z.string().uuid(), saved_at: z.string().datetime({ offset: true }),
}).strict();
export type HighlightDraftScope = z.infer<typeof highlightDraftScopeSchema>;
export type HighlightDraftSave = z.infer<typeof highlightDraftSaveSchema>;
export type HighlightDraftReceipt = z.infer<typeof receiptSchema>;
type Rpc = (name: string, args: Record<string, unknown>) => Promise<{ data: unknown; error: { message: string } | null }>;
function receipt(value: unknown, scope: HighlightDraftScope, actorId: string): HighlightDraftReceipt {
  const parsed = receiptSchema.parse(value);
  if (parsed.review_id !== scope.reviewId || parsed.source_revision_id !== scope.sourceRevisionId
    || parsed.master_version_id !== scope.masterVersionId || parsed.author_user_id !== actorId
    || parsed.version_number !== parsed.expected_version + 1) throw new Error("Highlight draft scope was not confirmed.");
  return parsed;
}
/** Internal caller-bound adapter. Application entry points must retain the deployment gate. */
export async function readOwnHighlightDraftRpc(rpc: Rpc, input: HighlightDraftScope, actorId: string) {
  const scope = highlightDraftScopeSchema.parse(input);
  const { data, error } = await rpc("read_own_requirement_highlight_draft", {
    p_review_id: scope.reviewId, p_source_revision_id: scope.sourceRevisionId, p_master_version_id: scope.masterVersionId,
  });
  if (error) throw new Error(error.message);
  return data === null ? null : receipt(data, scope, actorId);
}
export async function saveOwnHighlightDraftRpc(rpc: Rpc, input: HighlightDraftSave, actorId: string) {
  const parsed = highlightDraftSaveSchema.parse(input);
  const { data, error } = await rpc("save_requirement_highlight_draft", {
    p_review_id: parsed.reviewId, p_source_revision_id: parsed.sourceRevisionId, p_master_version_id: parsed.masterVersionId,
    p_expected_version: parsed.expectedVersion, p_body: parsed.body, p_request_key: parsed.requestKey,
  });
  if (error) throw new Error(error.message);
  const saved = receipt(data, parsed, actorId);
  if (saved.request_key !== parsed.requestKey || saved.expected_version !== parsed.expectedVersion
    || saved.body !== parsed.body.replace(/^ +| +$/g, "")) throw new Error("Highlight draft save was not confirmed. Refresh before retrying.");
  // A separate caller-authorized read is required; failure does not imply write rollback.
  const readback = await readOwnHighlightDraftRpc(rpc, parsedScope(parsed), actorId);
  if (!readback || readback.id !== saved.id || readback.version_number !== saved.version_number
    || readback.body !== saved.body || readback.request_key !== saved.request_key) {
    throw new Error("Highlight draft changed or could not be read back. Refresh before retrying.");
  }
  return readback;
}
function parsedScope(input: HighlightDraftScope): HighlightDraftScope {
  return { reviewId: input.reviewId, sourceRevisionId: input.sourceRevisionId, masterVersionId: input.masterVersionId };
}
