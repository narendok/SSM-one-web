import { describe, expect, it } from "vitest";
import { structuredLifecycleDocumentPlan, structuredLifecyclePlanForDepartment, structuredLifecyclePlanForKind } from "./structured-lifecycle-document-plan";

describe("structured lifecycle document plan", () => {
  it("maps all twelve templates to one responsible department and scope", () => {
    expect(structuredLifecycleDocumentPlan).toHaveLength(12);
    expect(structuredLifecyclePlanForDepartment("SAL").map((row) => row.kind)).toEqual([
      "SOR", "NDA", "COMMERCIAL_QUOTATION", "CONTRACT_REVIEW",
    ]);
    expect(structuredLifecyclePlanForDepartment("RND").map((row) => row.kind)).toEqual([
      "PRS", "BOM_COST_TRACKER", "DFMEA", "DVPR",
    ]);
    expect(structuredLifecyclePlanForDepartment("PROD").map((row) => row.kind)).toEqual([
      "MANUFACTURING_CONTROL_PLAN", "PDI",
    ]);
    expect(structuredLifecyclePlanForDepartment("FIN").map((row) => row.kind)).toEqual(["COMMERCIAL_TAX_INVOICE"]);
    expect(structuredLifecyclePlanForDepartment("HR").map((row) => row.kind)).toEqual(["ANNUAL_SKILL_MATRIX"]);
  });

  it("keeps only Sales SOR and Contract Review on the reviewed pending DOCX path", () => {
    expect(structuredLifecyclePlanForKind("SOR")).toMatchObject({ scope: "SALES_OPPORTUNITY", materializationState: "DEPLOYMENT_PENDING" });
    expect(structuredLifecyclePlanForKind("CONTRACT_REVIEW")).toMatchObject({ requiresExplicitResponsibility: true, materializationState: "DEPLOYMENT_PENDING" });
    expect(structuredLifecyclePlanForKind("DFMEA")).toMatchObject({ scope: "PROJECT", materializationState: "LOCAL_EXPORT_ONLY" });
  });
});