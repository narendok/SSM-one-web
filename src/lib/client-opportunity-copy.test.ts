import { describe, expect, it } from "vitest";
import { clientOpportunityCopyInputSchema, clientOpportunityCopyLinkAvailability, projectClientOpportunityCopy, type ClientOpportunityCopyInput } from "./client-opportunity-copy";

const input: ClientOpportunityCopyInput = {
  opportunity: { id: "a0c80d22-1007-4a60-b8cf-9c20a6c4f1a8", opportunityNumber: "OPPORTUNITY-2026-0013", customerId: "dfd5f3f8-0caf-46cb-bf16-436a1c063650", customerName: "OEM Tracker" },
  masterRevision: {
    id: "9ce5a383-9ebf-430e-9bba-2e550c20fe3e", number: 1, specificationNumber: "MASTER-2026-0001",
    data: { proposedName: "Tracker controller", customerOrInternalOwner: "OEM Tracker", industryApplication: "Fleet tracking", productFamily: "Tracker", developmentScope: "Internal scope excluded from client copy", workstreams: ["HARDWARE"], requirementSummary: "CAN/LTE tracker for 20 pilot units", powerAndUnits: "Tentative 12/24 V", interfaces: "CAN", connectivityAndGnss: "LTE and GNSS", environmentAndIp: "To be confirmed", volumes: "20 pilot units", schedule: "To be confirmed", requestedStandards: "To be confirmed", exclusions: "To be confirmed" },
  },
  customerRequirements: [{ id: "2fce1111-430e-4bbb-8bba-2e550c20fe3e", revisionNumber: 1, title: "CAN interface", requirementNumber: "REQ-2026-0001", customerReference: "OEM-CAN-1", summary: "Support the agreed CAN interface." }],
  publishedHighlights: [
    { departmentName: "Hardware", body: "We will confirm connector fit after the drawing is received.", sourceRevisionId: "9ce5a383-9ebf-430e-9bba-2e550c20fe3e", sourceRevisionNumber: 1, publishedAt: "2026-10-15T05:17:00.000Z" },
    { departmentName: "Procurement", body: "This stale highlight must not appear.", sourceRevisionId: "9ce5a383-9ebf-430e-9bba-2e550c20fe3e", sourceRevisionNumber: 2, publishedAt: "2026-10-15T05:17:00.000Z" },
  ],
};

describe("client opportunity copy projection", () => {
  it("projects only the explicit customer-facing allowlist with exact source revisions", () => {
    const projected = projectClientOpportunityCopy(input);
    expect(projected.opportunity).toEqual({ number: "OPPORTUNITY-2026-0013", customerName: "OEM Tracker" });
    expect(projected.masterSpecification.sourceRevision).toEqual({ id: "9ce5a383-9ebf-430e-9bba-2e550c20fe3e", number: 1 });
    expect(projected.customerRequirements[0]).toEqual({ title: "CAN interface", number: "REQ-2026-0001", customerReference: "OEM-CAN-1", summary: "Support the agreed CAN interface.", sourceRevision: { id: "2fce1111-430e-4bbb-8bba-2e550c20fe3e", number: 1 } });
    expect(projected.clientHighlights).toHaveLength(1);
    expect(JSON.stringify(projected)).not.toContain("Internal scope excluded from client copy");
    expect(JSON.stringify(projected)).not.toContain("workstreams");
    expect(JSON.stringify(projected)).not.toContain("This stale highlight must not appear");
  });

  it("rejects unallowlisted source fields instead of silently widening the copy", () => {
    expect(clientOpportunityCopyInputSchema.safeParse({ ...input, opportunity: { ...input.opportunity, staffEmail: "private@example.com" } }).success).toBe(false);
  });

  it("keeps client link resolution unavailable without the accepted access contract", () => {
    expect(clientOpportunityCopyLinkAvailability.available).toBe(false);
    expect(clientOpportunityCopyLinkAvailability.reason).toContain("recipient-bound");
  });
});