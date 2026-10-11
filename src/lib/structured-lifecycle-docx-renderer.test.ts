import JSZip from "jszip";
import { describe, expect, it } from "vitest";
import { mapMasterSpecificationSource, serializeLocalTableRows, structuredLifecycleTemplatePreviews } from "./lifecycle-structured-template-previews";
import { renderStructuredLifecycleDocx } from "./structured-lifecycle-docx-renderer";

const source = mapMasterSpecificationSource({
  opportunityId: "opportunity-id", opportunityNumber: "OPPORTUNITY-2026-0013", opportunityName: "Tracker",
  customerId: "customer-id", customerName: "Ångström & Co", specificationId: "specification-id",
  specificationNumber: "MASTER-2026-0001", versionId: "version-id", versionNumber: 1,
  changeSummary: "Initial", savedAt: "2026-10-11T00:00:00Z", project: null,
  specificationData: { interfaces: "CAN", volumes: "0" },
});

async function documentXml(bytes: Uint8Array) {
  const zip = await JSZip.loadAsync(bytes);
  const content = await zip.file("word/document.xml")?.async("string");
  return { zip, content };
}

describe("structured lifecycle DOCX renderer", () => {
  it("creates native OOXML documents for all twelve existing template mappings", async () => {
    for (const template of structuredLifecycleTemplatePreviews) {
      const rendered = await renderStructuredLifecycleDocx(template.kind, source, {});
      const { zip, content } = await documentXml(rendered.bytes);
      expect(rendered.fileName).toMatch(/\.docx$/);
      expect(rendered.mimeType).toContain("wordprocessingml.document");
      expect(zip.file("[Content_Types].xml")).toBeTruthy();
      expect(zip.file("word/document.xml")).toBeTruthy();
      expect(zip.file("word/styles.xml")).toBeTruthy();
      expect(content).toContain("LOCAL WORKING DOCX");
      expect(content).toContain("OPPORTUNITY-2026-0013");
      expect(content).toContain("MASTER-2026-0001 rev 1");
      expect(content).toContain(`${template.template.templateKey} v${template.template.version}`);
      expect(content).toContain("UNVERIFIED — local browser schema");
    }
  });

  it("preserves editable unicode paragraphs, zero, TBC, and native editable table cells", async () => {
    const rows = serializeLocalTableRows([{ id: "quote-1", line: "1", description: "Ångström <tag>", quantity: "0", unitPrice: "0", currency: "SEK", leadTime: "TBC" }]);
    const rendered = await renderStructuredLifecycleDocx("COMMERCIAL_QUOTATION", source, {
      QUOTE_LINE_ROWS: rows,
      PAYMENT_TERMS: "Net 30 — subject to review",
      NRE_AMOUNT: "0",
      TOOLING_AMOUNT: "TBC",
    });
    const { content } = await documentXml(rendered.bytes);
    expect(content).toContain("Ångström");
    expect(content).toContain("&lt;tag&gt;");
    expect(content).toContain("Net 30 — subject to review");
    expect(content).toContain(">0<");
    expect(content).toContain("TBC");
    expect(content).toContain("w:tbl");
  });

  it("rejects unknown, derived, malformed, and cross-kind manual fields", async () => {
    await expect(renderStructuredLifecycleDocx("SOR", source, { PROJECT_CODE: "override" })).rejects.toThrow("Derived source fields");
    await expect(renderStructuredLifecycleDocx("SOR", source, { POWER_REQUIREMENT: "12V" })).rejects.toThrow("Unknown editable field");
    await expect(renderStructuredLifecycleDocx("PDI", source, { PDI_ROWS: "not JSON" })).rejects.toThrow("Table rows must be valid JSON");
  });

  it("preserves deterministic visible provenance rather than claiming Save compatibility", async () => {
    const one = await renderStructuredLifecycleDocx("SOR", source, { SCOPE_STATEMENT: "Same note" });
    const two = await renderStructuredLifecycleDocx("SOR", source, { SCOPE_STATEMENT: "Same note" });
    const first = (await documentXml(one.bytes)).content;
    const second = (await documentXml(two.bytes)).content;
    expect(first).toContain("Master Specification revision ID");
    expect(first).toContain("version-id");
    expect(first).toContain("NOT APPROVED, ISSUED, OR RELEASED");
    expect(first).toContain("Same note");
    expect(second).toContain("Same note");
  });

  it("uses landscape width and repeating headers for the full BOM and DFMEA row mappings", async () => {
    const bomRows = serializeLocalTableRows([{ id: "bom-1", itemNumber: "1", mpn: "ABC", manufacturer: "Ångström", description: "<safe>", package: "QFN", quantity: "0", leadTime: "TBC", unitCost: "0", currency: "SEK", aecqEvidence: "TBC" }]);
    const dfmeaRows = serializeLocalTableRows([{ id: "dfmea-1", function: "Power", failureMode: "Open", effect: "Loss", cause: "TBC", preventionControl: "Review", detectionControl: "Test", severity: "9", occurrence: "0", detection: "1", owner: "Owner", action: "TBC" }]);
    for (const [kind, payload, escaped] of [
      ["BOM_COST_TRACKER", { BOM_COST_ROWS: bomRows }, "&lt;safe&gt;"],
      ["DFMEA", { DFMEA_ROWS: dfmeaRows }, "Power"],
    ] as const) {
      const { content } = await documentXml((await renderStructuredLifecycleDocx(kind, source, payload)).bytes);
      expect(content).toContain("w:orient=\"landscape\"");
      expect(content).toContain("w:tblHeader");
      expect(content).toContain(escaped);
      expect(content).toContain("w:gridCol w:w=\"1441\"");
    }
  });
});