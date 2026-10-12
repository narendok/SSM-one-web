import { describe, expect, it } from "vitest";
import { mapMasterSpecificationSource } from "./lifecycle-structured-template-previews";
import { renderStructuredLifecycleDocx } from "./structured-lifecycle-docx-renderer";
import { commitVerifiedSalesStructuredDocx, createSalesStructuredDocxAuthorization, verifySalesStructuredDocxObject } from "./structured-lifecycle-docx-sales-orchestration.server";

const ids = { actor: "00000000-0000-4000-8000-000000000001", other: "00000000-0000-4000-8000-000000000002", project: "00000000-0000-4000-8000-000000000201", assignment: "00000000-0000-4000-8000-000000000901", request: "00000000-0000-4000-8000-000000000902", department: "00000000-0000-4000-8000-000000000501", employee: "00000000-0000-4000-8000-000000000801", template: "00000000-0000-4000-8000-000000000991", templateRevision: "00000000-0000-4000-8000-000000000992", receipt: "00000000-0000-4000-8000-000000000993" };
const input = { projectId: ids.project, documentKind: "SOR" as const, assignmentId: ids.assignment, requestKey: ids.request, templateKey: "sales-sor", templateVersion: 1, templateSchemaHash: "a".repeat(64), sourceFingerprint: "b".repeat(64) };
const path = `sales/opportunity/${ids.project}/${ids.request}-draft.docx`;
const source = mapMasterSpecificationSource({ opportunityId: ids.project, opportunityNumber: "OPPORTUNITY-LOCAL", opportunityName: "Local", customerId: "00000000-0000-4000-8000-000000000101", customerName: "Customer", specificationId: "00000000-0000-4000-8000-000000000301", specificationNumber: "MASTER-LOCAL", versionId: "00000000-0000-4000-8000-000000000401", versionNumber: 1, changeSummary: "Initial", savedAt: "2026-10-12T00:00:00Z", project: null, specificationData: {} });

async function realBytes() { return (await renderStructuredLifecycleDocx("SOR", source, { SCOPE_STATEMENT: "Trusted receipt round trip" })).bytes; }
function scope() { return { actor_id: ids.actor, assignment_id: ids.assignment, request_key: ids.request, project_id: ids.project, document_kind: "SOR", department_id: ids.department, responsible_employee_id: ids.employee, reviewer_employee_id: null, template_id: ids.template, template_key: input.templateKey, template_version: 1, template_document_revision_id: ids.templateRevision, template_schema_hash: input.templateSchemaHash, source_fingerprint: input.sourceFingerprint, storage_bucket: "project-drive", storage_path: path, object_version: "v1" }; }
function rpcClient(overrides: { fail?: string; objectVersion?: string; changedObject?: boolean; committed?: unknown } = {}) {
  const calls: Array<{ name: string; args: Record<string, unknown> }> = [];
  const bytesPromise = realBytes();
  return {
    calls,
    rpc: async (name: string, args: Record<string, unknown>) => {
      calls.push({ name, args });
      if (overrides.fail === name) return { data: null, error: { message: `${name} denied` } };
      if (name === "resolve_sales_structured_docx_server_scope") return { data: { ...scope(), actor_id: args.p_actor_user_id, object_version: overrides.objectVersion ?? "v1" }, error: null };
      if (name === "issue_sales_structured_docx_trusted_receipt") return { data: ids.receipt, error: null };
      if (name === "commit_sales_structured_docx_materialization") return { data: overrides.committed ?? [{ materialization_id: "local" }], error: null };
      return { data: undefined, error: null };
    },
    from: () => ({ select: () => ({ eq: () => ({ eq: () => ({ eq: () => ({ is: async () => ({ data: { bucket_id: "project-drive", name: path, version: overrides.changedObject ? "v2" : "v1", archived_at: null, is_delete_marker: false, metadata: { size: 1 } }, error: null }) }) }) }) }) }),
    storage: { from: () => ({ download: async () => ({ data: new Blob([await bytesPromise]), error: null }) }) },
  } as never;
}

describe("trusted Sales DOCX orchestration", () => {
  it("runs renderer bytes through scope, current-path verification, receipt, and atomic commit facts", async () => {
    const client = rpcClient();
    const receipt = await verifySalesStructuredDocxObject(client, ids.actor, input);
    await commitVerifiedSalesStructuredDocx(client, ids.actor, receipt, { opportunityId: ids.project, customerId: source.customerId, fileName: "sor.docx" });
    expect(client.calls.map((call) => call.name)).toContain("issue_sales_structured_docx_trusted_receipt");
    expect(client.calls.find((call) => call.name === "commit_sales_structured_docx_materialization")?.args).toMatchObject({ p_trusted_receipt_id: ids.receipt, p_object_version: "v1" });
  });
  it("rejects forged actor, changed object, receipt denial, and commit conflict without an alternate path", async () => {
    const client = rpcClient();
    await expect(verifySalesStructuredDocxObject(client, ids.other, input)).rejects.toThrow("authority changed");
    await expect(verifySalesStructuredDocxObject(rpcClient({ changedObject: true }), ids.actor, input)).rejects.toThrow("identity is absent or replaced");
    await expect(verifySalesStructuredDocxObject(rpcClient({ fail: "issue_sales_structured_docx_trusted_receipt" }), ids.actor, input)).rejects.toThrow("denied");
    const receipt = await verifySalesStructuredDocxObject(client, ids.actor, input);
    await expect(commitVerifiedSalesStructuredDocx(rpcClient({ fail: "assert_sales_structured_docx_trusted_receipt_for_commit" }), ids.actor, receipt, { opportunityId: ids.project, customerId: source.customerId, fileName: "sor.docx" })).rejects.toThrow("denied");
  });
  it("keeps receipt recheck actor-bound and does not issue browser-side authority", async () => {
    const client = rpcClient();
    const port = createSalesStructuredDocxAuthorization(client);
    await expect(port.recheckRegistryReceiptForCommit({ receiptId: ids.receipt, requestKey: ids.request, assignmentId: ids.assignment, actorId: ids.other, projectId: ids.project, documentKind: "SOR", departmentId: ids.department, templateId: ids.template, templateDocumentRevisionId: ids.templateRevision, storageBucket: "project-drive", storagePath: path, objectVersion: "v1", sha256Checksum: "c".repeat(64), sizeBytes: 1, sourceFingerprint: input.sourceFingerprint, templateKey: input.templateKey, templateVersion: 1, templateSchemaHash: input.templateSchemaHash, paragraphs: 1, tables: 0 }, ids.actor)).resolves.toBeUndefined();
    expect(client.calls.at(-1)?.args).toMatchObject({ p_actor_user_id: ids.actor, p_receipt_id: ids.receipt });
  });
});
