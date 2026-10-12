/**
 * Browser-safe shape of the review-only registry contract. These records are
 * intentionally never queried until its protected resolver is deployed.
 */
export const STRUCTURED_LIFECYCLE_DOCUMENT_KINDS = [
  "SOR", "NDA", "COMMERCIAL_QUOTATION", "CONTRACT_REVIEW", "PRS", "BOM", "DFMEA",
  "MANUFACTURING_CONTROL_PLAN", "DVPR", "PDI", "COMMERCIAL_TAX_INVOICE", "ANNUAL_SKILL_MATRIX",
] as const;

export type StructuredLifecycleDocumentKind = typeof STRUCTURED_LIFECYCLE_DOCUMENT_KINDS[number];

export type StructuredDocxRegistryScope = {
  actorId: string;
  assignmentId: string;
  requestKey: string;
  scopeType: "SALES_OPPORTUNITY" | "PROJECT";
  opportunityId: string;
  customerId: string;
  projectId: string | null;
  documentKind: StructuredLifecycleDocumentKind;
  departmentId: string;
  responsibleEmployeeId: string;
  reviewerEmployeeId: string | null;
  templateId: string;
  templateKey: string;
  templateVersion: number;
  templateDocumentRevisionId: string;
  templateSchemaHash: string;
  sourceFingerprint: string;
  storageBucket: "project-drive";
  storagePath: string;
  objectVersion: string;
};

/** This port is server-only in use; its shared type keeps browser calls inactive. */
export type PrivateDocxRegistryAuthorizationPort = {
  resolveCurrentRegistryAssignment(input: {
    opportunityId: string;
    customerId: string;
    documentKind: StructuredLifecycleDocumentKind;
    assignmentId: string;
    requestKey: string;
    templateKey: string;
    templateVersion: number;
    templateSchemaHash: string;
    sourceFingerprint: string;
  }, actorId: string): Promise<StructuredDocxRegistryScope>;
  issueVerifiedObjectReceipt(receipt: Omit<StructuredDocxRegistryReceipt, "receiptId">): Promise<{ receiptId: string }>;
  recheckRegistryReceiptForCommit(receipt: StructuredDocxRegistryReceipt, actorId: string): Promise<void>;
};

export type StructuredDocxRegistryReceipt = {
  receiptId: string;
  requestKey: string;
  assignmentId: string;
  actorId: string;
  scopeType: "SALES_OPPORTUNITY" | "PROJECT";
  opportunityId: string;
  customerId: string;
  projectId: string | null;
  documentKind: StructuredLifecycleDocumentKind;
  departmentId: string;
  templateId: string;
  templateDocumentRevisionId: string;
  storageBucket: "project-drive";
  storagePath: string;
  objectVersion: string;
  sha256Checksum: string;
  sizeBytes: number;
  sourceFingerprint: string;
  templateKey: string;
  templateVersion: number;
  templateSchemaHash: string;
  paragraphs: number;
  tables: number;
};

export function structuredDocxRegistryStatus() {
  return {
    available: false,
    message: "Document responsibility, template approval, and private DOCX actions are acceptance-pending. No assignment or template version can be changed here.",
  } as const;
}