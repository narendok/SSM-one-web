import JSZip from "jszip";
import { describe, expect, it } from "vitest";
import { mapMasterSpecificationSource, serializeLocalTableRows, structuredLifecycleTemplatePreviews } from "./lifecycle-structured-template-previews";
import { renderStructuredLifecycleDocx } from "./structured-lifecycle-docx-renderer";
import { verifyStructuredLifecycleDocxBytes } from "./structured-lifecycle-docx-verifier";

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
      const { content: xml } = await documentXml((await renderStructuredLifecycleDocx(kind, source, payload)).bytes);
      expect(xml).toBeDefined();
      const content = xml ?? "";
      expect(content).toContain("w:orient=\"landscape\"");
      expect(content).toContain("w:tblHeader");
      expect(content).toContain(escaped);
      expect(content).toContain("w:tblW w:type=\"dxa\" w:w=\"14414\"");
      const wideTableWidths = [...content.matchAll(/<w:tblW w:type="dxa" w:w="14414"\/>[\s\S]*?<\/w:tbl>/g)];
      expect(wideTableWidths).toHaveLength(1);
      expect(wideTableWidths[0]?.[0].match(/<w:gridCol/g)?.length).toBe(kind === "BOM_COST_TRACKER" ? 10 : 12);
    }
  });

  it("verifies genuine editable DOCX bytes, including paragraphs and tables", async () => {
    const rendered = await renderStructuredLifecycleDocx("COMMERCIAL_QUOTATION", source, {
      QUOTE_LINE_ROWS: serializeLocalTableRows([{ id: "row-1", line: "1", description: "Verified", quantity: "0", unitPrice: "0", currency: "SEK", leadTime: "TBC" }]),
    });
    await expect(verifyStructuredLifecycleDocxBytes(rendered.bytes)).resolves.toMatchObject({
      sha256Checksum: expect.stringMatching(/^[a-f0-9]{64}$/), sizeBytes: rendered.bytes.byteLength, paragraphs: expect.any(Number), tables: expect.any(Number),
    });
  });

  it("rejects renamed HTML, invalid ZIPs, modified packages, and external relationships", async () => {
    const rendered = await renderStructuredLifecycleDocx("SOR", source, { SCOPE_STATEMENT: "Bounded verifier" });
    const html = new TextEncoder().encode("<!doctype html><html><body>not DOCX</body></html>");
    await expect(verifyStructuredLifecycleDocxBytes(html)).rejects.toThrow("not a ZIP package");
    await expect(verifyStructuredLifecycleDocxBytes(new Uint8Array([0x50, 0x4b, 0x03, 0x04]))).rejects.toThrow("valid ZIP package");

    const modified = await JSZip.loadAsync(rendered.bytes);
    modified.file("word/document.xml", "<!doctype html><html><body>replaced</body></html>");
    await expect(verifyStructuredLifecycleDocxBytes(await modified.generateAsync({ type: "uint8array" }))).rejects.toThrow("not safe XML");

    const external = await JSZip.loadAsync(rendered.bytes);
    external.file("customXml/_rels/item1.xml.rels", "<?xml version='1.0'?><Relationships xmlns='http://schemas.openxmlformats.org/package/2006/relationships'><Relationship Id='rId1' Type='urn:test' Target='https&#x3a;//untrusted.example/doc.xml' TargetMode='External'/></Relationships>");
    await expect(verifyStructuredLifecycleDocxBytes(await external.generateAsync({ type: "uint8array" }))).rejects.toThrow("external");
  });

  it("follows the root officeDocument relationship and accepts a valid minimal package without document rels", async () => {
    const minimal = new JSZip();
    minimal.file("[Content_Types].xml", '<?xml version="1.0"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>');
    minimal.file("_rels/.rels", '<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>');
    minimal.file("word/document.xml", '<?xml version="1.0"?><x:document xmlns:x="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><x:body><x:p><x:r><x:t>Minimal</x:t></x:r></x:p></x:body></x:document>');
    await expect(verifyStructuredLifecycleDocxBytes(await minimal.generateAsync({ type: "uint8array" }))).resolves.toMatchObject({ paragraphs: 1, tables: 0 });
  });

  it("rejects ZIP traversal, declared expansion, invalid overrides, and active Word content", async () => {
    const traversal = new JSZip();
    traversal.file("../word/document.xml", "x");
    await expect(verifyStructuredLifecycleDocxBytes(await traversal.generateAsync({ type: "uint8array" }))).rejects.toThrow("unsafe original path");

    const rendered = await renderStructuredLifecycleDocx("SOR", source, { SCOPE_STATEMENT: "resource limits" });
    await expect(verifyStructuredLifecycleDocxBytes(rendered.bytes, { maxUncompressedBytes: 1 })).rejects.toThrow("uncompressed byte limit");
    await expect(verifyStructuredLifecycleDocxBytes(rendered.bytes, { maxBytes: Number.NaN })).rejects.toThrow("positive safe integers");

    const active = await JSZip.loadAsync(rendered.bytes);
    active.file("word/document.xml", '<?xml version="1.0"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>x</w:t></w:r></w:p><w:altChunk/></w:body></w:document>');
    await expect(verifyStructuredLifecycleDocxBytes(await active.generateAsync({ type: "uint8array" }))).rejects.toThrow("active Word content");
  });
});