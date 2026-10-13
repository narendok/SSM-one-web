import type { StructuredLifecycleTemplateKind } from "@/lib/lifecycle-structured-template-previews";

export type StructuredDocumentPlanRow = {
  kind: StructuredLifecycleTemplateKind;
  label: string;
  description: string;
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
  { kind: "SOR", label: "Statement of Requirements", description: "Sales source requirements and scope.", departmentCode: "SAL", departmentName: departmentNames.SAL, requiresExplicitResponsibility: false, scope: "SALES_OPPORTUNITY", materializationState: "DEPLOYMENT_PENDING" },
  { kind: "NDA", label: "NDA review", description: "Sales confidentiality review.", departmentCode: "SAL", departmentName: departmentNames.SAL, requiresExplicitResponsibility: false, scope: "SALES_OPPORTUNITY", materializationState: "LOCAL_EXPORT_ONLY" },
  { kind: "COMMERCIAL_QUOTATION", label: "Commercial quotation", description: "Sales commercial worksheet.", departmentCode: "SAL", departmentName: departmentNames.SAL, requiresExplicitResponsibility: false, scope: "SALES_OPPORTUNITY", materializationState: "LOCAL_EXPORT_ONLY" },
  { kind: "CONTRACT_REVIEW", label: "Contract Review", description: "Sales-led cross-functional review.", departmentCode: "SAL", departmentName: departmentNames.SAL, requiresExplicitResponsibility: true, scope: "SALES_OPPORTUNITY", materializationState: "DEPLOYMENT_PENDING" },
  { kind: "PRS", label: "Product Requirements Specification", description: "Hardware & R&D requirements specification.", departmentCode: "RND", departmentName: departmentNames.RND, requiresExplicitResponsibility: true, scope: "PROJECT", materializationState: "LOCAL_EXPORT_ONLY" },
  { kind: "BOM_COST_TRACKER", label: "BOM review", description: "Hardware & R&D BOM cost review.", departmentCode: "RND", departmentName: departmentNames.RND, requiresExplicitResponsibility: false, scope: "PROJECT", materializationState: "LOCAL_EXPORT_ONLY" },
  { kind: "DFMEA", label: "DFMEA", description: "Hardware & R&D design-risk analysis.", departmentCode: "RND", departmentName: departmentNames.RND, requiresExplicitResponsibility: false, scope: "PROJECT", materializationState: "LOCAL_EXPORT_ONLY" },
  { kind: "MANUFACTURING_CONTROL_PLAN", label: "Manufacturing Control Plan", description: "Production process-control plan.", departmentCode: "PROD", departmentName: departmentNames.PROD, requiresExplicitResponsibility: false, scope: "PROJECT", materializationState: "LOCAL_EXPORT_ONLY" },
  { kind: "DVPR", label: "DVP&R", description: "Cross-functional design verification plan.", departmentCode: "RND", departmentName: departmentNames.RND, requiresExplicitResponsibility: true, scope: "PROJECT", materializationState: "LOCAL_EXPORT_ONLY" },
  { kind: "PDI", label: "Pre-Delivery Inspection", description: "Production pre-delivery inspection.", departmentCode: "PROD", departmentName: departmentNames.PROD, requiresExplicitResponsibility: false, scope: "PROJECT", materializationState: "LOCAL_EXPORT_ONLY" },
  { kind: "COMMERCIAL_TAX_INVOICE", label: "Commercial tax invoice", description: "Finance invoice worksheet.", departmentCode: "FIN", departmentName: departmentNames.FIN, requiresExplicitResponsibility: false, scope: "PROJECT", materializationState: "LOCAL_EXPORT_ONLY" },
  { kind: "ANNUAL_SKILL_MATRIX", label: "Annual skill matrix", description: "Human Resources capability record.", departmentCode: "HR", departmentName: departmentNames.HR, requiresExplicitResponsibility: false, scope: "PROJECT", materializationState: "LOCAL_EXPORT_ONLY" },
];

export const structuredLifecycleDocumentPlan = rows;

export function structuredLifecyclePlanForDepartment(departmentCode: string | null | undefined) {
  return rows.filter((row) => row.departmentCode === departmentCode);
}

export function structuredLifecyclePlanForKind(kind: StructuredLifecycleTemplateKind) {
  return rows.find((row) => row.kind === kind) ?? null;
}