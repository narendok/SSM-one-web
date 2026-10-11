import { describe, expect, it } from "vitest";
import { renderStructuredSalesLocalDraftHtml } from "./structured-sales-local-renderer";

const source = {
  sourceFields: {
    PROJECT_CODE: "OPPORTUNITY-2026-0013",
    PROJECT_NAME: "Tracker <source>",
    PROJECT_REVISION: "Master Specification rev 1",
    CUSTOMER_NAME: "SAMPLE ONLY & Co",
    MASTER_SPECIFICATION: "MASTER-2026-0001 rev 1",
    SOURCE_DOCUMENT: "MASTER-2026-0001 revision 1",
    REQUIREMENT_SUMMARY: "CAN <telemetry>",
    POWER_AND_UNITS: "24 V",
    INTERFACES: "CAN",
    CONNECTIVITY_AND_GNSS: "LTE",
    ENVIRONMENT_AND_IP: "TBC",
    REQUESTED_STANDARDS: "TBC",
    VOLUMES: "20",
    WORKSTREAMS: "Hardware, Firmware",
  },
};

describe("structured Sales local draft HTML renderer", () => {
  it("renders deterministic fixed SOR markup from the verified preview source and valid own edits", () => {
    const payload = { SCOPE_STATEMENT: "  Keep this exact\nmanual text.  ", OEM_REQUIREMENT_ROWS: "REQ-1 | CAN" };
    const first = renderStructuredSalesLocalDraftHtml("SOR", source, payload);
    const second = renderStructuredSalesLocalDraftHtml("SOR", source, { OEM_REQUIREMENT_ROWS: "REQ-1 | CAN", SCOPE_STATEMENT: "  Keep this exact\nmanual text.  " });

    expect(first).toBe(second);
    expect(first).toContain("Verified preview source");
    expect(first).toContain("Automotive requirement traceability");
    expect(first).toContain("Source traceability — exact pinned preview context");
    expect(first).toContain("CAN &lt;telemetry&gt;");
    expect(first).toContain("Local working notes");
    expect(first).toContain("  Keep this exact\nmanual text.  ");
    expect(first).toContain("Tracker &lt;source&gt;");
  });

  it("escapes manual and source text so markup, handlers, and URLs remain inert text", () => {
    const html = renderStructuredSalesLocalDraftHtml("PRS", source, {
      POWER_REQUIREMENT: '<img src=x onerror="alert(1)"> javascript:alert(1)',
      VERIFICATION_METHOD: "<script>alert(1)</script>",
    });

    expect(html).toContain("&lt;img src=x onerror=&quot;alert(1)&quot;&gt; javascript:alert(1)");
    expect(html).toContain("&lt;script&gt;alert(1)&lt;/script&gt;");
    expect(html).not.toContain("<img");
    expect(html).not.toContain("<script");
    expect(html).not.toContain("href=");
    expect(html).not.toContain("onclick=");
  });

  it("rejects malformed or inherited editable payloads before producing HTML", () => {
    const inherited = Object.create({ SCOPE_STATEMENT: "unvalidated inherited text" });

    expect(() => renderStructuredSalesLocalDraftHtml("SOR", source, { PROJECT_CODE: "forbidden" })).toThrow("Derived source fields cannot be edited");
    expect(() => renderStructuredSalesLocalDraftHtml("SOR", source, { SCOPE_STATEMENT: 7 })).toThrow("Editable values must be strings");
    expect(() => renderStructuredSalesLocalDraftHtml("SOR", source, inherited)).toThrow("plain object with data properties");
  });

  it("keeps Contract Review local notes distinct from authoritative approval", () => {
    const html = renderStructuredSalesLocalDraftHtml("CONTRACT_REVIEW", source, { LOCAL_DECISION_NOTE: "Proceed" });

    expect(html).toContain("Approval status: NOT APPROVED / TBC.");
    expect(html).toContain("Local decision note");
    expect(html).toContain("Proceed");
  });

  it("renders source-pinned automotive traceability for each specialized Sales document without inventing an outcome", () => {
    for (const kind of ["SOR", "CONTRACT_REVIEW", "PRS"] as const) {
      const html = renderStructuredSalesLocalDraftHtml(kind, source, {});
      expect(html).toContain("Automotive requirement traceability");
      expect(html).toContain("OPPORTUNITY-2026-0013");
      expect(html).toContain("MASTER-2026-0001 rev 1");
      expect(html).toContain("TBC remains unresolved");
      expect(html).not.toContain("ISSUED");
      expect(html).not.toContain("APPROVED</p>");
    }
  });

  it("marks an unavailable source as unverified while preserving exact local edits", () => {
    const manualScope = "  Keep this local scope exactly.\n  ";
    const html = renderStructuredSalesLocalDraftHtml("SOR", null, { SCOPE_STATEMENT: manualScope });

    expect(html).toContain("UNVERIFIED — source unavailable");
    expect(html).toContain("No verified source loaded.");
    expect(html).not.toContain("Verified preview source");
    expect(html).not.toContain("Prepared locally from the verified preview source.");
    expect(html).toContain(manualScope);
    expect(html).toContain("<pre>TBC</pre>");
    expect(html).toContain("LOCAL PREVIEW ONLY — NOT A CONTROLLED DOCUMENT");
  });
});