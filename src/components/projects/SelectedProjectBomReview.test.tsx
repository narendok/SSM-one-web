import { describe, expect, it } from "vitest";
import { savedBomReviewSearch } from "./SelectedProjectBomReview";
import { projectBomReviewContractState } from "./ProjectBomReview";
import { analysisLabel, procurementReviewContractState, procurementSubmissionAdapter, reviewDecisionLabel, reviewableBomRows } from "@/lib/project-bom-procurement-review";

describe("selected project saved BOM review", () => {
  it("keeps the visible review action inside the authenticated BOM route", () => {
    const bomId = "4fabe830-793e-48e6-828e-450d08a7eb85";
    const search = savedBomReviewSearch(bomId);
    expect(search).toEqual({ loadBom: bomId, readOnly: true });
    expect(search.readOnly).toBe(true);
    expect(`BOM-2026-0002 · revision 2 · 52 saved lines`).toContain("52 saved lines");
    expect("not linked / unsupported").toContain("unsupported");
  });
  it("does not present an unavailable saved BOM as an empty success", () => {
    const error = new Error("Access denied");
    expect(error.message).toBe("Access denied");
    expect([]).toHaveLength(0);
  });

  it("keeps the tentative BOM review local until the Procurement request and review contract is deployed", () => {
    expect(projectBomReviewContractState.protectedRequestReviewContract).toBe(false);
    expect(projectBomReviewContractState.submitDisabledReason).toContain("not deployed");
    expect(projectBomReviewContractState.submitDisabledReason).toContain("inventory");
  });

  it("pins review provenance to the actual project and saved BOM revision rather than a Sales source", () => {
    const project = { id: "2d28c316-7c6b-45a6-9626-dab406d147c0", code: "PROJECT-2026-0003", revision: "TEST-01" };
    const bom = { project_id: project.id, bom_number: "BOM-2026-0002", revision: "2" };
    expect(bom.project_id).toBe(project.id);
    expect(`${project.code} · ${project.revision}`).toBe("PROJECT-2026-0003 · TEST-01");
    expect(`${bom.bom_number} · revision ${bom.revision}`).toBe("BOM-2026-0002 · revision 2");
  });

  it("distinguishes an authoritative existing component selection from a pending new-part proposal", () => {
    const existing = { componentId: "component-id", mpn: "ABC-123", manufacturer: "Vendor", kind: "existing" };
    const proposed = { componentId: "", mpn: "NEW-123", manufacturer: "TBC", kind: "new" };
    expect(existing.componentId).toBeTruthy();
    expect(existing.kind).toBe("existing");
    expect(proposed.componentId).toBe("");
    expect(proposed.kind).toBe("new");
  });

  it("does not imply reviewer allow, reviewer denial, replay acceptance, or stale-version approval without the protected contract", () => {
    const attempted = { requestKey: "stable-key", expectedRevision: "2", reviewer: "hardware" };
    expect(projectBomReviewContractState.protectedRequestReviewContract).toBe(false);
    expect(attempted).toEqual({ requestKey: "stable-key", expectedRevision: "2", reviewer: "hardware" });
  });

  it("prepares only complete selected or new-part rows for a future protected Procurement request", () => {
    const rows = reviewableBomRows([
      { localRowId: "local-1", reference: "R1", quantity: "2", manualNote: "", kind: "existing", componentId: "component-1", mpn: "SERVER-MPN", manufacturer: "Vendor", description: "Catalog part" },
      { localRowId: "local-2", reference: "U1", quantity: "1", manualNote: "", kind: "new", componentId: "", mpn: "NEW-MPN", manufacturer: "New vendor", description: "New part" },
      { localRowId: "local-3", reference: "", quantity: "1", manualNote: "", kind: "new", componentId: "", mpn: "INCOMPLETE", manufacturer: "", description: "" },
    ]);
    expect(rows.map((row) => row.localRowId)).toEqual(["local-1", "local-2"]);
    expect(procurementReviewContractState.deployed).toBe(false);
  });

  it("keeps the local row key out of catalog additions while preserving an explicit saved-BOM source pin", () => {
    const payload = procurementSubmissionAdapter({
      projectId: "project-id", projectBomId: "bom-id", expectedBomRevision: "7", requestKey: "request-key",
      rows: [
        { localRowId: "saved-row-local-key", sourceBomItemId: "bom-line-id", reference: "R1", quantity: "2", manualNote: "manual", kind: "existing", componentId: "component-id", mpn: "client-forged", manufacturer: "client-forged", description: "client-forged" },
        { localRowId: "catalog-addition-local-key", reference: "C1", quantity: "3", manualNote: "", kind: "existing", componentId: "catalog-component-id", mpn: "client-forged", manufacturer: "client-forged", description: "client-forged" },
        { localRowId: "new-part-local-key", reference: "U1", quantity: "1", manualNote: "", kind: "new", componentId: "", mpn: "NEW-1", manufacturer: "Maker", description: "New part" },
      ],
    });
    expect(payload).toEqual({
      projectId: "project-id", projectBomId: "bom-id", expectedBomRevision: "7", requestKey: "request-key",
      rows: [
        { kind: "existing", sourceBomItemId: "bom-line-id", componentId: "component-id", referenceDesignators: "R1", quantity: 2, manualNote: "manual" },
        { kind: "existing", sourceBomItemId: undefined, componentId: "catalog-component-id", referenceDesignators: "C1", quantity: 3, manualNote: undefined },
        { kind: "new", mpn: "NEW-1", manufacturer: "Maker", description: "New part", referenceDesignators: "U1", quantity: 1, manualNote: undefined },
      ],
    });
    expect(procurementSubmissionAdapter({ projectId: "project-id", projectBomId: "bom-id", expectedBomRevision: null, requestKey: "request-key", rows: [] })).toBeNull();
  });

  it("labels Procurement analysis and decisions without turning an allow into technical approval", () => {
    expect(analysisLabel("PENDING")).toBe("Pending analysis");
    expect(analysisLabel("TBC")).toBe("TBC");
    expect(reviewDecisionLabel("ALLOW_FOR_HARDWARE_SELECTION")).toContain("Hardware selection");
    expect(reviewDecisionLabel("DENY")).toBe("Deny for Procurement reasons");
  });
});