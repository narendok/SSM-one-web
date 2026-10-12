import type { SupabaseClient } from "@supabase/supabase-js";
import { DOCX_MIME_TYPE, verifyStructuredLifecycleDocxBytes } from "./structured-lifecycle-docx-verifier";
import type { PrivateDocxRegistryAuthorizationPort, StructuredDocxRegistryReceipt, StructuredDocxRegistryScope } from "./structured-lifecycle-docx-registry";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const SHA256 = /^[a-f0-9]{64}$/i;

export type StructuredDocxVerificationRequest = { opportunityId: string; customerId: string; documentKind: import("./structured-lifecycle-docx-registry").StructuredLifecycleDocumentKind; assignmentId: string; requestKey: string; templateKey: string; templateVersion: number; templateSchemaHash: string; sourceFingerprint: string };
export type AuthorizedStructuredDocxObject = StructuredDocxRegistryScope;
export type PrivateDocxObject = { bucket: "project-drive"; path: string; objectVersion: string; mimeType: string | null; bytes: Uint8Array };
export type StructuredDocxVerificationReceipt = StructuredDocxRegistryReceipt;
export type PrivateDocxAuthorizationPort = PrivateDocxRegistryAuthorizationPort;
export type PrivateDocxObjectReader = { readExactObject(input: Pick<AuthorizedStructuredDocxObject, "requestKey" | "storageBucket" | "storagePath" | "objectVersion">): Promise<PrivateDocxObject> };

function fail(message: string): never { throw new Error(`Private DOCX verification failed: ${message}`); }
function ensureUuid(value: string, label: string) { if (!UUID.test(value)) fail(`${label} must be a UUID`); }
function ensureHash(value: string, label: string) { if (!SHA256.test(value)) fail(`${label} must be a SHA-256 checksum`); }

function validateRequest(input: StructuredDocxVerificationRequest) {
  ensureUuid(input.opportunityId, "opportunity ID"); ensureUuid(input.customerId, "customer ID"); ensureUuid(input.assignmentId, "assignment ID"); ensureUuid(input.requestKey, "request key");
  ensureHash(input.sourceFingerprint, "source fingerprint"); ensureHash(input.templateSchemaHash, "template schema hash");
  if (!input.templateKey.trim() || !Number.isSafeInteger(input.templateVersion) || input.templateVersion < 1) fail("template pins are invalid");
}

function sameAuthority(input: StructuredDocxVerificationRequest, actorId: string, scope: AuthorizedStructuredDocxObject) {
  return scope.actorId === actorId && scope.assignmentId === input.assignmentId && scope.requestKey === input.requestKey && scope.opportunityId === input.opportunityId && scope.customerId === input.customerId && scope.documentKind === input.documentKind
    && UUID.test(scope.departmentId) && UUID.test(scope.responsibleEmployeeId) && UUID.test(scope.templateId) && UUID.test(scope.templateDocumentRevisionId)
    && scope.storageBucket === "project-drive" && scope.storagePath.endsWith(`${input.requestKey}-draft.docx`) && scope.objectVersion.trim().length > 0
    && scope.sourceFingerprint === input.sourceFingerprint && scope.templateKey === input.templateKey && scope.templateVersion === input.templateVersion && scope.templateSchemaHash === input.templateSchemaHash;
}

/** Server-only bridge; it has no browser import path and no fallback reader. */
export async function verifyAndReceiptStructuredDocxObject(input: StructuredDocxVerificationRequest, actorId: string, authorization: PrivateDocxAuthorizationPort, reader: PrivateDocxObjectReader): Promise<StructuredDocxVerificationReceipt> {
  validateRequest(input); ensureUuid(actorId, "authenticated actor");
  const scope = await authorization.resolveCurrentRegistryAssignment(input, actorId);
  if (!sameAuthority(input, actorId, scope)) fail("current assignment or pinned source/template authority changed");
  const object = await reader.readExactObject(scope);
  if (object.bucket !== scope.storageBucket || object.path !== scope.storagePath || object.objectVersion !== scope.objectVersion) fail("private object changed or does not match the authorized immutable identity");
  if (object.mimeType !== null && object.mimeType !== DOCX_MIME_TYPE) fail("private object MIME type is not DOCX");
  const verified = await verifyStructuredLifecycleDocxBytes(object.bytes);
  const receipt = { requestKey: scope.requestKey, assignmentId: scope.assignmentId, actorId, scopeType: scope.scopeType, opportunityId: scope.opportunityId, customerId: scope.customerId, projectId: scope.projectId, documentKind: scope.documentKind, departmentId: scope.departmentId, templateId: scope.templateId, templateDocumentRevisionId: scope.templateDocumentRevisionId, storageBucket: scope.storageBucket, storagePath: scope.storagePath, objectVersion: scope.objectVersion, sha256Checksum: verified.sha256Checksum, sizeBytes: verified.sizeBytes, sourceFingerprint: scope.sourceFingerprint, templateKey: scope.templateKey, templateVersion: scope.templateVersion, templateSchemaHash: scope.templateSchemaHash, paragraphs: verified.paragraphs, tables: verified.tables };
  const issued = await authorization.issueVerifiedObjectReceipt(receipt);
  if (!issued.receiptId || !UUID.test(issued.receiptId)) fail("trusted receipt issuer returned an invalid receipt identity");
  return { ...receipt, receiptId: issued.receiptId };
}

/** Rechecks exact actor, scope, source/template, and object receipt before commit. */
export async function assertCurrentStructuredDocxReceipt(receipt: StructuredDocxVerificationReceipt, actorId: string, authorization: PrivateDocxAuthorizationPort) {
  ensureUuid(actorId, "authenticated actor");
  if (receipt.actorId !== actorId || receipt.storageBucket !== "project-drive" || !UUID.test(receipt.receiptId)) fail("receipt is not bound to the current actor and private object");
  await authorization.recheckRegistryReceiptForCommit(receipt, actorId);
}

/** Inactive by design: storage.download cannot select and attest an immutable object version. */
export function createUnavailableSupabasePrivateDocxReader(_admin: Pick<SupabaseClient, "storage">): PrivateDocxObjectReader {
  return { async readExactObject() { fail("an accepted immutable private-object reader is unavailable; storage.download cannot select and attest an exact object version"); } };
}