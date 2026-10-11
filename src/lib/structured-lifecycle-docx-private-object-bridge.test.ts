import { describe, expect, it } from "vitest";
import { mapMasterSpecificationSource } from "./lifecycle-structured-template-previews";
import { renderStructuredLifecycleDocx } from "./structured-lifecycle-docx-renderer";
import { assertCurrentStructuredDocxReceipt, createUnavailableSupabasePrivateDocxReader, verifyAndReceiptStructuredDocxObject, type AuthorizedStructuredDocxObject, type PrivateDocxAuthorizationPort, type PrivateDocxObjectReader } from "./structured-lifecycle-docx-private-object-bridge.server";

const ids = { projectId: "00000000-0000-0000-0000-000000000001", assignmentId: "00000000-0000-0000-0000-000000000003", requestKey: "00000000-0000-0000-0000-000000000004", actorId: "00000000-0000-0000-0000-000000000005", receiptId: "00000000-0000-0000-0000-000000000006", employeeId: "00000000-0000-0000-0000-000000000007", departmentId: "00000000-0000-0000-0000-000000000008", templateId: "00000000-0000-0000-0000-000000000009", templateRevisionId: "00000000-0000-0000-0000-000000000010" };
const input = { projectId: ids.projectId, documentKind: "SOR" as const, assignmentId: ids.assignmentId, requestKey: ids.requestKey, templateKey: "sales-sor", templateVersion: 1, templateSchemaHash: "a".repeat(64), sourceFingerprint: "b".repeat(64) };
const source = mapMasterSpecificationSource({ opportunityId: "opportunity", opportunityNumber: "OPPORTUNITY-TEST", opportunityName: "Test", customerId: "customer", customerName: "Customer", specificationId: "spec", specificationNumber: "MASTER-TEST", versionId: "version", versionNumber: 1, changeSummary: "Initial", savedAt: "2026-10-12T00:00:00Z", project: null, specificationData: {} });
function scope(): AuthorizedStructuredDocxObject { return { actorId: ids.actorId, assignmentId: ids.assignmentId, requestKey: ids.requestKey, projectId: ids.projectId, documentKind: "SOR", departmentId: ids.departmentId, responsibleEmployeeId: ids.employeeId, reviewerEmployeeId: null, templateId: ids.templateId, templateKey: input.templateKey, templateVersion: input.templateVersion, templateDocumentRevisionId: ids.templateRevisionId, templateSchemaHash: input.templateSchemaHash, storageBucket: "project-drive", storagePath: `private/project/${ids.requestKey}-draft.docx`, objectVersion: "version-1", sourceFingerprint: input.sourceFingerprint }; }
async function realDocx() { return (await renderStructuredLifecycleDocx("SOR", source, { SCOPE_STATEMENT: "Server-verified bytes" })).bytes; }
function authorization(overrides: Partial<PrivateDocxAuthorizationPort> = {}): PrivateDocxAuthorizationPort { return { resolveCurrentRegistryAssignment: async () => scope(), issueVerifiedObjectReceipt: async () => ({ receiptId: ids.receiptId }), recheckRegistryReceiptForCommit: async () => undefined, ...overrides }; }

describe("private DOCX server bridge", () => {
  it("binds genuine editable DOCX bytes to current actor, assignment, source/template, and object version", async () => {
    const bytes = await realDocx(); const reader: PrivateDocxObjectReader = { readExactObject: async () => ({ bucket: "project-drive", path: scope().storagePath, objectVersion: "version-1", mimeType: "application/vnd.openxmlformats-officedocument.wordprocessingml.document", bytes }) };
    const receipt = await verifyAndReceiptStructuredDocxObject(input, ids.actorId, authorization(), reader);
    expect(receipt).toMatchObject({ receiptId: ids.receiptId, actorId: ids.actorId, requestKey: ids.requestKey, objectVersion: "version-1", sizeBytes: bytes.byteLength, sourceFingerprint: input.sourceFingerprint });
    await expect(assertCurrentStructuredDocxReceipt(receipt, ids.actorId, authorization())).resolves.toBeUndefined();
  });
  it("rejects denied or stale assignment/source authority before reading bytes", async () => {
    const reader: PrivateDocxObjectReader = { readExactObject: async () => { throw new Error("must not read"); } };
    await expect(verifyAndReceiptStructuredDocxObject(input, ids.actorId, authorization({ resolveCurrentRegistryAssignment: async () => ({ ...scope(), actorId: "00000000-0000-0000-0000-000000000099" }) }), reader)).rejects.toThrow("authority changed");
  });
  it("rejects a cross-department registry scope before reading private bytes", async () => {
    const reader: PrivateDocxObjectReader = { readExactObject: async () => { throw new Error("must not read"); } };
    await expect(verifyAndReceiptStructuredDocxObject(input, ids.actorId, authorization({ resolveCurrentRegistryAssignment: async () => ({ ...scope(), departmentId: "00000000-0000-0000-0000-000000000099" }) }), reader)).rejects.toThrow("authority changed");
  });
  it("rejects object replacement and does not issue a receipt", async () => {
    const bytes = await realDocx(); let issued = false; const reader: PrivateDocxObjectReader = { readExactObject: async () => ({ bucket: "project-drive", path: scope().storagePath, objectVersion: "version-replaced", mimeType: null, bytes }) };
    await expect(verifyAndReceiptStructuredDocxObject(input, ids.actorId, authorization({ issueVerifiedObjectReceipt: async () => { issued = true; return { receiptId: ids.receiptId }; } }), reader)).rejects.toThrow("object changed"); expect(issued).toBe(false);
  });
  it("rejects malformed bytes and a replayed receipt after assignment revocation", async () => {
    const reader: PrivateDocxObjectReader = { readExactObject: async () => ({ bucket: "project-drive", path: scope().storagePath, objectVersion: "version-1", mimeType: "application/vnd.openxmlformats-officedocument.wordprocessingml.document", bytes: new TextEncoder().encode("<html>not docx</html>") }) };
    await expect(verifyAndReceiptStructuredDocxObject(input, ids.actorId, authorization(), reader)).rejects.toThrow("not a ZIP package");
    const receipt = { receiptId: ids.receiptId, ...scope(), sha256Checksum: "c".repeat(64), sizeBytes: 1, paragraphs: 1, tables: 0 };
    await expect(assertCurrentStructuredDocxReceipt(receipt, ids.actorId, authorization({ recheckRegistryReceiptForCommit: async () => { throw new Error("assignment revoked"); } }))).rejects.toThrow("assignment revoked");
  });
  it("rejects a stale template revision and keeps receipt rechecks authoritative", async () => {
    const bytes = await realDocx(); const reader: PrivateDocxObjectReader = { readExactObject: async () => ({ bucket: "project-drive", path: scope().storagePath, objectVersion: "version-1", mimeType: null, bytes }) };
    await expect(verifyAndReceiptStructuredDocxObject(input, ids.actorId, authorization({ resolveCurrentRegistryAssignment: async () => ({ ...scope(), templateVersion: 2 }) }), reader)).rejects.toThrow("authority changed");
  });
  it("keeps the production adapter unavailable without immutable object-version reading", async () => {
    await expect(createUnavailableSupabasePrivateDocxReader({} as never).readExactObject(scope())).rejects.toThrow("immutable private-object reader is unavailable");
  });
});