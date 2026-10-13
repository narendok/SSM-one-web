import type { StructuredLifecycleTemplateKind } from "@/lib/lifecycle-structured-template-previews";

export type StructuredDocumentCatalogScope = "all" | "sales-proposal" | "project-documents";
export type StructuredDocumentDepartment = "SAL" | "OPS" | "RND" | "PROD" | "FIN" | "HR";

export type StructuredDocumentCategory = {
  kind: StructuredLifecycleTemplateKind;
  departmentScopes: readonly StructuredDocumentDepartment[];
  requiresExplicitResponsibility?: boolean;
};

export const structuredDocumentCategories: readonly StructuredDocumentCategory[] = [
  { kind: "SOR", departmentScopes: ["SAL"] },
  { kind: "NDA", departmentScopes: ["OPS"], requiresExplicitResponsibility: true },
  { kind: "COMMERCIAL_QUOTATION", departmentScopes: ["SAL"] },
  { kind: "CONTRACT_REVIEW", departmentScopes: ["SAL", "RND"], requiresExplicitResponsibility: true },
  { kind: "PRS", departmentScopes: ["RND"], requiresExplicitResponsibility: true },
  { kind: "BOM_COST_TRACKER", departmentScopes: ["RND"] },
  { kind: "DFMEA", departmentScopes: ["RND"] },
  { kind: "MANUFACTURING_CONTROL_PLAN", departmentScopes: ["PROD"] },
  { kind: "DVPR", departmentScopes: ["RND", "PROD"], requiresExplicitResponsibility: true },
  { kind: "PDI", departmentScopes: ["PROD"] },
  { kind: "COMMERCIAL_TAX_INVOICE", departmentScopes: ["FIN"] },
  { kind: "ANNUAL_SKILL_MATRIX", departmentScopes: ["HR"] },
];

export function structuredDocumentCategory(kind: StructuredLifecycleTemplateKind) {
  return structuredDocumentCategories.find((category) => category.kind === kind) ?? null;
}

export function isStructuredDocumentInCatalog(
  kind: StructuredLifecycleTemplateKind,
  scope: StructuredDocumentCatalogScope,
  departmentCode: string | null | undefined,
) {
  if (scope === "all") return true;
  if (scope === "sales-proposal") return ["SOR", "CONTRACT_REVIEW"].includes(kind);
  const category = structuredDocumentCategory(kind);
  return Boolean(category && departmentCode && category.departmentScopes.includes(departmentCode as StructuredDocumentDepartment));
}

export function documentAccessBoundaryMessage() {
  return "Project overview access does not grant document access. This catalog stays unavailable until the assigned-person document access contract is accepted.";
}

export type SalesStructuredDocumentEntry = {
  opportunityId: string;
  opportunityNumber: string;
  specificationNumber: string;
  versionNumber: number;
  folderNodeId: string;
  departmentId: string;
  isActive: boolean;
  folderIsLocked: boolean;
  folderIsTrashed: boolean;
};

export function canOpenDirectSalesStructuredDocuments(entry: SalesStructuredDocumentEntry | null) {
  return Boolean(entry && entry.isActive && entry.folderIsLocked && !entry.folderIsTrashed);
}