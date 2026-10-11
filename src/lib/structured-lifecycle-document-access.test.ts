import { describe, expect, it } from "vitest";
import { isStructuredDocumentInCatalog } from "./structured-lifecycle-document-access";

describe("structured lifecycle document catalog routing", () => {
  it("excludes technical templates from the Sales proposal catalog", () => {
    expect(isStructuredDocumentInCatalog("SOR", "sales-proposal", "SAL")).toBe(true);
    expect(isStructuredDocumentInCatalog("BOM_COST_TRACKER", "sales-proposal", "SAL")).toBe(false);
    expect(isStructuredDocumentInCatalog("DFMEA", "sales-proposal", "SAL")).toBe(false);
  });

  it("keeps overview participation separate from a document category", () => {
    expect(isStructuredDocumentInCatalog("BOM_COST_TRACKER", "project-documents", "SAL")).toBe(false);
    expect(isStructuredDocumentInCatalog("BOM_COST_TRACKER", "project-documents", "RND")).toBe(true);
  });

  it("routes Hardware, Production, Finance, and HR defaults without granting other categories", () => {
    expect(isStructuredDocumentInCatalog("DFMEA", "project-documents", "RND")).toBe(true);
    expect(isStructuredDocumentInCatalog("MANUFACTURING_CONTROL_PLAN", "project-documents", "PROD")).toBe(true);
    expect(isStructuredDocumentInCatalog("PDI", "project-documents", "PROD")).toBe(true);
    expect(isStructuredDocumentInCatalog("COMMERCIAL_TAX_INVOICE", "project-documents", "FIN")).toBe(true);
    expect(isStructuredDocumentInCatalog("ANNUAL_SKILL_MATRIX", "project-documents", "HR")).toBe(true);
    expect(isStructuredDocumentInCatalog("ANNUAL_SKILL_MATRIX", "project-documents", "RND")).toBe(false);
  });

  it("keeps interdisciplinary categories visible only to their participating scopes", () => {
    expect(isStructuredDocumentInCatalog("CONTRACT_REVIEW", "project-documents", "SAL")).toBe(true);
    expect(isStructuredDocumentInCatalog("CONTRACT_REVIEW", "project-documents", "RND")).toBe(true);
    expect(isStructuredDocumentInCatalog("CONTRACT_REVIEW", "project-documents", "PROD")).toBe(false);
    expect(isStructuredDocumentInCatalog("DVPR", "project-documents", "RND")).toBe(true);
    expect(isStructuredDocumentInCatalog("DVPR", "project-documents", "PROD")).toBe(true);
  });
});