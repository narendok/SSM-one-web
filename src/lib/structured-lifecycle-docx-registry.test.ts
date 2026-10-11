import { describe, expect, it } from "vitest";
import { STRUCTURED_LIFECYCLE_DOCUMENT_KINDS, structuredDocxRegistryStatus } from "./structured-lifecycle-docx-registry";

describe("structured DOCX registry boundary", () => {
  it("covers the closed twelve-kind catalog without exposing a live mutation", () => {
    expect(STRUCTURED_LIFECYCLE_DOCUMENT_KINDS).toEqual([
      "SOR", "NDA", "COMMERCIAL_QUOTATION", "CONTRACT_REVIEW", "PRS", "BOM", "DFMEA",
      "MANUFACTURING_CONTROL_PLAN", "DVPR", "PDI", "COMMERCIAL_TAX_INVOICE", "ANNUAL_SKILL_MATRIX",
    ]);
    expect(structuredDocxRegistryStatus().available).toBe(false);
  });
});