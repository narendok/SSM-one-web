import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@/integrations/supabase/types";
import { createContractBoundCurrentPathPrivateDocxReader } from "./structured-lifecycle-docx-private-object-reader.server";
import {
  assertCurrentStructuredDocxReceipt,
  verifyAndReceiptStructuredDocxObject,
  type PrivateDocxAuthorizationPort,
  type StructuredDocxVerificationReceipt,
  type StructuredDocxVerificationRequest,
} from "./structured-lifecycle-docx-private-object-bridge.server";
import type { StructuredDocxRegistryScope } from "./structured-lifecycle-docx-registry";

const DOCX_MIME = "application/vnd.openxmlformats-officedocument.wordprocessingml.document" as const;

type RpcClient = Pick<SupabaseClient<Database>, "rpc" | "storage" | "from">;

function requireRpc<T>(result: { data: T | null; error: { message: string } | null }, fallback: string): T {
  if (result.error || result.data === null) throw new Error(result.error?.message ?? fallback);
  return result.data;
}

function requireVoidRpc(result: { error: { message: string } | null }, fallback: string) {
  if (result.error) throw new Error(result.error.message ?? fallback);
}

/**
 * Server-only adapter for the pending Sales DOCX contracts. It is deliberately
 * called only after requireSupabaseAuth supplied actorId. The deployment gate
 * lives in the server functions; this module does not activate browser access.
 */
export function createSalesStructuredDocxAuthorization(admin: RpcClient): PrivateDocxAuthorizationPort {
  return {
    async resolveCurrentRegistryAssignment(input, actorId): Promise<StructuredDocxRegistryScope> {
      const rawScope = requireRpc(await admin.rpc("resolve_sales_structured_docx_server_scope" as never, {
        p_actor_user_id: actorId,
        p_project_id: input.projectId,
        p_document_kind: input.documentKind,
        p_assignment_id: input.assignmentId,
        p_request_key: input.requestKey,
        p_template_key: input.templateKey,
        p_template_version: input.templateVersion,
        p_template_schema_hash: input.templateSchemaHash,
        p_source_fingerprint: input.sourceFingerprint,
      } as never), "The trusted DOCX assignment scope is unavailable.") as unknown as Record<string, unknown>;
      return {
        actorId: rawScope.actor_id as string,
        assignmentId: rawScope.assignment_id as string,
        requestKey: rawScope.request_key as string,
        projectId: rawScope.project_id as string,
        documentKind: rawScope.document_kind as StructuredDocxRegistryScope["documentKind"],
        departmentId: rawScope.department_id as string,
        responsibleEmployeeId: rawScope.responsible_employee_id as string,
        reviewerEmployeeId: rawScope.reviewer_employee_id as string | null,
        templateId: rawScope.template_id as string,
        templateKey: rawScope.template_key as string,
        templateVersion: rawScope.template_version as number,
        templateDocumentRevisionId: rawScope.template_document_revision_id as string,
        templateSchemaHash: rawScope.template_schema_hash as string,
        sourceFingerprint: rawScope.source_fingerprint as string,
        storageBucket: rawScope.storage_bucket as "project-drive",
        storagePath: rawScope.storage_path as string,
        objectVersion: rawScope.object_version as string,
      };
    },
    async issueVerifiedObjectReceipt(receipt) {
      const receiptId = requireRpc(await admin.rpc("issue_sales_structured_docx_trusted_receipt" as never, {
        p_actor_user_id: receipt.actorId,
        p_request_key: receipt.requestKey,
        p_assignment_id: receipt.assignmentId,
        p_storage_bucket: receipt.storageBucket,
        p_storage_path: receipt.storagePath,
        p_object_version: receipt.objectVersion,
        p_sha256_checksum: receipt.sha256Checksum,
        p_size_bytes: receipt.sizeBytes,
        p_source_fingerprint: receipt.sourceFingerprint,
        p_template_key: receipt.templateKey,
        p_template_version: receipt.templateVersion,
        p_template_schema_hash: receipt.templateSchemaHash,
        p_verifier_service: "tanstack-structured-docx-verifier-v1",
      } as never), "The trusted DOCX receipt could not be issued.") as unknown as string;
      return { receiptId };
    },
    async recheckRegistryReceiptForCommit(receipt, actorId) {
      requireVoidRpc(await admin.rpc("assert_sales_structured_docx_trusted_receipt_for_commit" as never, {
        p_actor_user_id: actorId,
        p_receipt_id: receipt.receiptId,
        p_request_key: receipt.requestKey,
        p_assignment_id: receipt.assignmentId,
        p_storage_bucket: receipt.storageBucket,
        p_storage_path: receipt.storagePath,
        p_object_version: receipt.objectVersion,
        p_sha256_checksum: receipt.sha256Checksum,
        p_size_bytes: receipt.sizeBytes,
      } as never), "The trusted DOCX receipt could not be rechecked.");
    },
  };
}

export function createSalesStructuredDocxReader(admin: RpcClient) {
  return createContractBoundCurrentPathPrivateDocxReader(admin as never, {
    async assertCurrentCreateOnlyPath(input) {
      requireVoidRpc(await admin.rpc("assert_sales_structured_docx_current_path_create_only" as never, {
        p_request_key: input.requestKey,
        p_bucket: input.bucket,
        p_path: input.path,
        p_object_version: input.objectVersion,
      } as never), "The current private DOCX object could not be rechecked.");
    },
  });
}

export async function verifySalesStructuredDocxObject(
  admin: RpcClient,
  actorId: string,
  input: StructuredDocxVerificationRequest,
) {
  return verifyAndReceiptStructuredDocxObject(input, actorId, createSalesStructuredDocxAuthorization(admin), createSalesStructuredDocxReader(admin));
}

export async function commitVerifiedSalesStructuredDocx(
  admin: RpcClient,
  actorId: string,
  receipt: StructuredDocxVerificationReceipt,
  input: { opportunityId: string; customerId: string; fileName: string },
) {
  const authorization = createSalesStructuredDocxAuthorization(admin);
  await assertCurrentStructuredDocxReceipt(receipt, actorId, authorization);
  return requireRpc(await admin.rpc("commit_sales_structured_docx_materialization" as never, {
    p_opportunity_id: input.opportunityId,
    p_customer_id: input.customerId,
    p_assignment_id: receipt.assignmentId,
    p_request_key: receipt.requestKey,
    p_file_name: input.fileName,
    p_storage_bucket: receipt.storageBucket,
    p_storage_path: receipt.storagePath,
    p_object_version: receipt.objectVersion,
    p_sha256_checksum: receipt.sha256Checksum,
    p_size_bytes: receipt.sizeBytes,
    p_trusted_receipt_id: receipt.receiptId,
  } as never), "The verified DOCX materialization could not be committed.");
}

export { DOCX_MIME };
