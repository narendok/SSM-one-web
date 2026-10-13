import type { StructuredLifecycleTemplateKind } from "@/lib/lifecycle-structured-template-previews";

export type StructuredDocumentPlanRow = {
  kind: StructuredLifecycleTemplateKind;
  label: string;
  departmentCode: "SAL" | "RND" | "PROD" | "FIN" | "HR";
  departmentName: string;
  requiresExplicitResponsibility: boolean;
  scope: "SALES_OPPORTUNITY" | "PROJECT";
  materializationState: "LOCAL_EXPORT_ONLY" | "DEPLOYMENT_PENDING";
};

const departmentNames = {
  SAL: "Sales",
  RND: "Hardware & R&D",
  PROD: "Production & Calibration",
  FIN: "Finance",
  HR: "Human Resources",
} as const;

const rows: readonly StructuredDocumentPlanRow[] = [
  { kind: "SOR", label: "Statement of Requirements", departmentCode: "SAL", departmentName: departmentNames.SAL, requiresExplicitResponsibility: false, scope: "SALES_OPPORTUNITY", materializationState: "DEPLOYMENT_PENDING" },
  { kind: "NDA", label: "NDA review", departmentCode: "SAL", departmentName: departmentNames.SAL, requiresExplicitResponsibility: false, scope: "SALES_OPPORTUNITY", materializationState: "LOCAL_EXPORT_ONLY" },
  { kind: "COMMERCIAL_QUOTATION", label: "Commercial quotation", departmentCode: "SAL", departmentName: departmentNames.SAL, requiresExplicitResponsibility: false, scope: "SALES_OPPORTUNITY", materializationState: "LOCAL_EXPORT_ONLY" },
  { kind: "CONTRACT_REVIEW", label: "Contract Review", departmentCode: "SAL", departmentName: departmentNames.SAL, requiresExplicitResponsibility: true, scope: "SALES_OPPORTUNITY", materializationState: "DEPLOYMENT_PENDING" },
  { kind: "PRS", label: "Product Requirements Specification", departmentCode: "RND", departmentName: departmentNames.RND, requiresExplicitResponsibility: true, scope: "PROJECT", materializationState: "LOCAL_EXPORT_ONLY" },
  { kind: "BOM_COST_TRACKER", label: "BOM review", departmentCode: "RND", departmentName: departmentNames.RND, requiresExplicitResponsibility: false, scope: "PROJECT", materializationState: "LOCAL_EXPORT_ONLY" },
  { kind: "DFMEA", label: "DFMEA", departmentCode: "RND", departmentName: departmentNames.RND, requiresExplicitResponsibility: false, scope: "PROJECT", materializationState: "LOCAL_EXPORT_ONLY" },
  { kind: "MANUFACTURING_CONTROL_PLAN", label: "Manufacturing Control Plan", departmentCode: "PROD", departmentName: departmentNames.PROD, requiresExplicitResponsibility: false, scope: "PROJECT", materializationState: "LOCAL_EXPORT_ONLY" },
  { kind: "DVPR", label: "DVP&R", departmentCode: "RND", departmentName: departmentNames.RND, requiresExplicitResponsibility: true, scope: "PROJECT", materializationState: "LOCAL_EXPORT_ONLY" },
  { kind: "PDI", label: "Pre-Delivery Inspection", departmentCode: "PROD", departmentName: departmentNames.PROD, requiresExplicitResponsibility: false, scope: "PROJECT", materializationState: "LOCAL_EXPORT_ONLY" },
  { kind: "COMMERCIAL_TAX_INVOICE", label: "Commercial tax invoice", departmentCode: "FIN", departmentName: departmentNames.FIN, requiresExplicitResponsibility: false, scope: "PROJECT", materializationState: "LOCAL_EXPORT_ONLY" },
  { kind: "ANNUAL_SKILL_MATRIX", label: "Annual skill matrix", departmentCode: "HR", departmentName: departmentNames.HR, requiresExplicitResponsibility: false, scope: "PROJECT", materializationState: "LOCAL_EXPORT_ONLY" },
];

export const structuredLifecycleDocumentPlan = rows;

export function structuredLifecyclePlanForDepartment(departmentCode: string | null | undefined) {
  return rows.filter((row) => row.departmentCode === departmentCode);
}

export function structuredLifecyclePlanForKind(kind: StructuredLifecycleTemplateKind) {
  return rows.find((row) => row.kind === kind) ?? null;
}