import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";
import { buildStructuredPreviewContent, FormattedPreview, localEditsForStructuredPreview, requestStructuredPreviewExit, shouldWarnBeforeClosingStructuredPreview, structuredSalesDocumentGate } from "./StructuredTemplatePreview";
import { mapMasterSpecificationSource, serializeLocalTableRows, structuredLifecycleTemplatePreviews } from "@/lib/lifecycle-structured-template-previews";

const source = mapMasterSpecificationSource({ opportunityId: "opportunity-id", opportunityNumber: "OPPORTUNITY-2026-0013", opportunityName: "Tracker", customerId: "customer-id", customerName: "SAMPLE ONLY", specificationId: "specification-id", specificationNumber: "MASTER-2026-0001", versionId: "version-id", versionNumber: 1, changeSummary: "Initial intake", savedAt: "2026-10-05T18:37:27.589Z", project: null, specificationData: {} });
const bomRows = serializeLocalTableRows([{ id: "bom-1", itemNumber: "1", mpn: "TBC", manufacturer: "TBC", description: "Local board", package: "TBC", quantity: "0", leadTime: "TBC", unitCost: "0", currency: "SEK", aecqEvidence: "TBC" }]);
const quoteRows = serializeLocalTableRows([{ id: "quote-1", line: "1", description: "Prototype <img src=x onerror=alert(1)>", quantity: "20", unitPrice: "0", currency: "SEK", leadTime: "TBC" }]);
const tierRows = serializeLocalTableRows([{ id: "tier-1", minQuantity: "1", maxQuantity: "20", unitPrice: "0" }]);

describe("formatted structured template preview", () => {
  const authoritativeBom = {
    id: "bom-2026-0002-id",
    bom_number: "BOM-2026-0002",
    name: "BOM_Emulator_V2.0 for procurement",
    source_filename: null,
    revision: "2",
    notes: null,
    line_count: 52,
    total_cost: 0,
    created_at: "2026-09-28T01:41:43.991Z",
    source_drive_node_id: null,
    source_drive_revision_id: null,
  };

  it("renders every typed table through the actual formatted-preview component", () => {
    const bomItem = structuredLifecycleTemplatePreviews.find((item) => item.kind === "BOM_COST_TRACKER");
    const quoteItem = structuredLifecycleTemplatePreviews.find((item) => item.kind === "COMMERCIAL_QUOTATION");
    if (!bomItem || !quoteItem) throw new Error("Expected table preview definitions.");
    const bomPreview = renderToStaticMarkup(<FormattedPreview item={bomItem} source={source} userEdits={{ "BOM_COST_TRACKER:BOM_COST_ROWS": bomRows, "BOM_COST_TRACKER:LOCAL_COST_TOTAL": "999", "BOM_COST_TRACKER:COST_RISK_NOTES": "TBC" }} error={null} controlledText="TBC" />);
    expect(bomPreview).toContain("BOM cost rows · local review only");
    expect(bomPreview).toContain("Local board");
    expect(bomPreview).toContain(">0<");
    expect(bomPreview).toContain("manual / unverified");
    const quotePreview = renderToStaticMarkup(<FormattedPreview item={quoteItem} source={source} userEdits={{ "COMMERCIAL_QUOTATION:QUOTE_LINE_ROWS": quoteRows, "COMMERCIAL_QUOTATION:VOLUME_TIER_ROWS": tierRows, "COMMERCIAL_QUOTATION:NRE_AMOUNT": "TBC", "COMMERCIAL_QUOTATION:TOOLING_AMOUNT": "TBC", "COMMERCIAL_QUOTATION:PAYMENT_TERMS": "TBC", "COMMERCIAL_QUOTATION:LEAD_TIME": "TBC" }} error={null} controlledText="TBC" />);
    expect(quotePreview).toContain("Prototype &lt;img src=x onerror=alert(1)&gt;");
    expect(quotePreview).toContain("Volume tiers · provisional");
    expect(quotePreview).toContain(">0<");
  });

  it("renders row-level errors and removes them after recovery", () => {
    const bomItem = structuredLifecycleTemplatePreviews.find((item) => item.kind === "BOM_COST_TRACKER");
    if (!bomItem) throw new Error("Expected BOM preview definition.");
    const invalidRows = serializeLocalTableRows([{ id: "bad", itemNumber: "2", mpn: "TBC", manufacturer: "TBC", description: "Bad row", package: "TBC", quantity: "-1", leadTime: "TBC", unitCost: "0", currency: "SEK", aecqEvidence: "TBC" }]);
    const invalidPreview = renderToStaticMarkup(<FormattedPreview item={bomItem} source={source} userEdits={{ "BOM_COST_TRACKER:BOM_COST_ROWS": invalidRows, "BOM_COST_TRACKER:LOCAL_COST_TOTAL": "TBC", "BOM_COST_TRACKER:COST_RISK_NOTES": "TBC" }} error={null} controlledText="TBC" />);
    expect(invalidPreview).toContain("Invalid input");
    expect(invalidPreview).toContain("Quantity must be a non-negative finite number or TBC.");
    const recoveredPreview = renderToStaticMarkup(<FormattedPreview item={bomItem} source={source} userEdits={{ "BOM_COST_TRACKER:BOM_COST_ROWS": bomRows, "BOM_COST_TRACKER:LOCAL_COST_TOTAL": "TBC", "BOM_COST_TRACKER:COST_RISK_NOTES": "TBC" }} error={null} controlledText="TBC" />);
    expect(recoveredPreview).not.toContain("Quantity must be a non-negative finite number or TBC.");
  });

  it("renders DFMEA, control-plan, and DVP&R typed local tables with TBC and safe literal output", () => {
    const dfmeaItem = structuredLifecycleTemplatePreviews.find((item) => item.kind === "DFMEA");
    const controlItem = structuredLifecycleTemplatePreviews.find((item) => item.kind === "MANUFACTURING_CONTROL_PLAN");
    const dvprItem = structuredLifecycleTemplatePreviews.find((item) => item.kind === "DVPR");
    if (!dfmeaItem || !controlItem || !dvprItem) throw new Error("Expected new preview definitions.");
    const dfmea = serializeLocalTableRows([{ id: "risk", function: "Power <img src=x>", failureMode: "TBC", effect: "TBC", cause: "TBC", preventionControl: "TBC", detectionControl: "TBC", severity: "10", occurrence: "2", detection: "3", owner: "TBC", action: "TBC" }]);
    const control = serializeLocalTableRows([{ id: "control", processStep: "Assembly", characteristic: "TBC", specification: "TBC", method: "TBC", equipment: "TBC", sampleFrequency: "TBC", reactionPlan: "TBC", owner: "TBC" }]);
    const dvpr = serializeLocalTableRows([{ id: "dvpr", test: "CAN verification", applicability: "TBC", sampleCount: "TBC", acceptanceCriteria: "TBC", result: "TBC", evidence: "TBC", standardsReference: "Customer-requested reference only" }]);
    expect(renderToStaticMarkup(<FormattedPreview item={dfmeaItem} source={source} userEdits={{ "DFMEA:DFMEA_ROWS": dfmea, "DFMEA:DFMEA_REVIEW_NOTE": "TBC" }} error={null} controlledText="TBC" />)).toContain("Power &lt;img src=x&gt;");
    expect(renderToStaticMarkup(<FormattedPreview item={controlItem} source={source} userEdits={{ "MANUFACTURING_CONTROL_PLAN:CONTROL_PLAN_ROWS": control, "MANUFACTURING_CONTROL_PLAN:CONTROL_PLAN_NOTE": "TBC" }} error={null} controlledText="TBC" />)).toContain("Control-plan rows");
    expect(renderToStaticMarkup(<FormattedPreview item={dvprItem} source={source} userEdits={{ "DVPR:DVPR_ROWS": dvpr, "DVPR:DVPR_REVIEW_NOTE": "TBC" }} error={null} controlledText="TBC" />)).toContain("Customer-requested reference only");
  });

  it("renders PDI and invoice typed tables as escaped local drafts and protects the HR placeholder", () => {
    const pdiItem = structuredLifecycleTemplatePreviews.find((item) => item.kind === "PDI");
    const invoiceItem = structuredLifecycleTemplatePreviews.find((item) => item.kind === "COMMERCIAL_TAX_INVOICE");
    const skillItem = structuredLifecycleTemplatePreviews.find((item) => item.kind === "ANNUAL_SKILL_MATRIX");
    if (!pdiItem || !invoiceItem || !skillItem) throw new Error("Expected final preview definitions.");
    const pdi = serializeLocalTableRows([{ id: "pdi", checkpoint: "Packing <img src=x>", expectedCondition: "TBC", actualObservation: "TBC", evidence: "", disposition: "TBC" }]);
    const invoice = serializeLocalTableRows([{ id: "invoice", description: "Pilot <img src=x>", quantity: "2", unitPrice: "10.50", currency: "INR", taxRate: "18" }]);
    expect(renderToStaticMarkup(<FormattedPreview item={pdiItem} source={source} userEdits={{ "PDI:PDI_ROWS": pdi, "PDI:PDI_REVIEW_NOTE": "TBC" }} error={null} controlledText="TBC" />)).toContain("Packing &lt;img src=x&gt;");
    const invoicePreview = renderToStaticMarkup(<FormattedPreview item={invoiceItem} source={source} userEdits={{ "COMMERCIAL_TAX_INVOICE:BUYER_DETAILS": "TBC", "COMMERCIAL_TAX_INVOICE:CONSIGNEE_DETAILS": "TBC", "COMMERCIAL_TAX_INVOICE:TAX_INVOICE_ROWS": invoice, "COMMERCIAL_TAX_INVOICE:INVOICE_NOTE": "TBC" }} error={null} controlledText="TBC" />);
    expect(invoicePreview).toContain("Pilot &lt;img src=x&gt;");
    expect(invoicePreview).toContain("24.78");
    expect(renderToStaticMarkup(<FormattedPreview item={skillItem} source={source} userEdits={{}} error={null} controlledText="HR SCOPE REQUIRED" />)).toContain("No employee data was read.");
  });

  it("shows pinned source traceability and the unissued boundary in every specialized formatted preview", () => {
    for (const kind of ["DFMEA", "MANUFACTURING_CONTROL_PLAN", "DVPR", "COMMERCIAL_QUOTATION"] as const) {
      const item = structuredLifecycleTemplatePreviews.find((candidate) => candidate.kind === kind);
      if (!item) throw new Error(`Expected ${kind} preview definition.`);
      const markup = renderToStaticMarkup(<FormattedPreview item={item} source={source} userEdits={{}} error={null} controlledText="TBC" />);
      expect(markup).toContain("Source traceability");
      expect(markup).toContain("OPPORTUNITY-2026-0013");
      expect(markup).toContain("MASTER-2026-0001 rev 1");
      expect(markup).toContain("TBC is unresolved");
      expect(markup).toContain("LOCAL PREVIEW ONLY — NOT ISSUED OR CONTROLLED");
    }
  });
});

describe("local structured preview draft safety", () => {
  it("warns before leaving only when a local draft has unsaved edits", () => {
    expect(shouldWarnBeforeClosingStructuredPreview(false)).toBe(false);
    expect(shouldWarnBeforeClosingStructuredPreview(true)).toBe(true);
  });

  it("reflects exact manual SOR edits in the sandboxed local preview", () => {
    const content = buildStructuredPreviewContent("SOR", source, { "SOR:SCOPE_STATEMENT": "  Manual scope\nkept exactly.  " });
    const item = structuredLifecycleTemplatePreviews.find((candidate) => candidate.kind === "SOR");
    if (!item || content.error) throw new Error("Expected a safe SOR preview.");

    const markup = renderToStaticMarkup(<FormattedPreview item={item} source={source} userEdits={{ "SOR:SCOPE_STATEMENT": "  Manual scope\nkept exactly.  " }} error={content.error} controlledText={content.content} />);
    expect(content.content).toContain("  Manual scope\nkept exactly.  ");
    expect(markup).toContain('sandbox=""');
    expect(markup).toContain("Local unsaved draft — NOT APPROVED / TBC.");
  });

  it("permits SOR, Contract Review, and PRS local editing only behind an exact verified Sales source pin", () => {
    for (const kind of ["SOR", "CONTRACT_REVIEW", "PRS"] as const) {
      expect(structuredSalesDocumentGate(kind, source)).toEqual({
        state: "VERIFIED",
        message: expect.stringContaining("OPPORTUNITY-2026-0013 · MASTER-2026-0001 rev 1"),
      });
      expect(structuredSalesDocumentGate(kind, null)).toEqual({
        state: "SOURCE_UNAVAILABLE",
        message: expect.stringContaining("could not be verified"),
      });
    }
    expect(structuredSalesDocumentGate("NDA", null)).toBeNull();
  });

  it("labels a clean persisted Sales draft as unissued instead of claiming local notes remain unsaved", () => {
    expect(structuredSalesDocumentGate("SOR", source, 1, false)).toEqual({
      state: "VERIFIED",
      message: "Persisted unissued revision 1 is based on OPPORTUNITY-2026-0013 · MASTER-2026-0001 rev 1. No approval, issuance, or release is recorded.",
    });
    const dirtyGate = structuredSalesDocumentGate("SOR", source, 1, true);
    expect(dirtyGate?.message).toContain("Local notes remain unsaved");
  });

  it("keeps XSS text inert in a sandboxed SOR preview", () => {
    const content = buildStructuredPreviewContent("SOR", source, { "SOR:SCOPE_STATEMENT": '<img src=x onerror="alert(1)"><script>alert(1)</script>' });
    const item = structuredLifecycleTemplatePreviews.find((candidate) => candidate.kind === "SOR");
    if (!item || content.error) throw new Error("Expected a safe SOR preview.");

    const markup = renderToStaticMarkup(<FormattedPreview item={item} source={source} userEdits={{}} error={content.error} controlledText={content.content} />);
    expect(content.content).not.toContain("<img");
    expect(content.content).not.toContain("<script");
    expect(markup).toContain('sandbox=""');
    expect(markup).not.toContain("allow-scripts");
  });

  it("shows specialized malformed local table input as a correction error instead of silently rendering an empty preview", () => {
    const item = structuredLifecycleTemplatePreviews.find((candidate) => candidate.kind === "PDI");
    if (!item) throw new Error("Expected PDI preview definition.");
    const content = buildStructuredPreviewContent("PDI", source, { "PDI:PDI_ROWS": "not json" });
    expect(content).toEqual(expect.objectContaining({ content: "", error: expect.stringContaining("Table rows must be valid JSON") }));
    const markup = renderToStaticMarkup(<FormattedPreview item={item} source={source} userEdits={{ "PDI:PDI_ROWS": "not json" }} error={content.error} controlledText={content.content} />);
    expect(markup).toContain("Local preview input needs correction");
    expect(markup).toContain("Table rows must be valid JSON");
  });

  it("retains manual fields across template switches and routes an exit through the discard guard", () => {
    const edits = { "SOR:SCOPE_STATEMENT": "Retain me", "PRS:POWER_REQUIREMENT": "24 V" };
    expect(localEditsForStructuredPreview("SOR", edits)).toEqual({ SCOPE_STATEMENT: "Retain me" });
    expect(localEditsForStructuredPreview("PRS", edits)).toEqual({ POWER_REQUIREMENT: "24 V" });
    expect(localEditsForStructuredPreview("SOR", edits)).toEqual({ SCOPE_STATEMENT: "Retain me" });

    let exited = false;
    let discardAsked = false;
    requestStructuredPreviewExit(true, () => { exited = true; }, () => { discardAsked = true; });
    expect(discardAsked).toBe(true);
    expect(exited).toBe(false);
    requestStructuredPreviewExit(false, () => { exited = true; }, () => { discardAsked = true; });
    expect(exited).toBe(true);
  });
});