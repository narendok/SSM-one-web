import { describe, expect, it, beforeEach } from "vitest";
import {
  fetchDepartmentChronicles,
  createDepartmentChronicle,
  updateDepartmentChronicle,
  quickUpdateChronicleStatus,
  quickUpdateChronicleStage,
  deleteDepartmentChronicle,
  resetDepartmentChronicles,
  LIFECYCLE_STAGES,
} from "./department-chronicles";

describe("Department Chronicles feed & 9-stage milestones management", () => {
  beforeEach(() => {
    resetDepartmentChronicles();
  });

  it("fetches seeded initial chronicles across all 9 lifecycle stages", () => {
    const all = fetchDepartmentChronicles();
    expect(all.length).toBeGreaterThanOrEqual(9);

    // Verify milestones exist across stages
    const stage1 = fetchDepartmentChronicles(undefined, 1);
    expect(stage1.length).toBeGreaterThanOrEqual(1);
    expect(stage1.some((c) => c.title.includes("PRD"))).toBe(true);

    const stage2 = fetchDepartmentChronicles(undefined, 2);
    expect(stage2.length).toBeGreaterThanOrEqual(1);

    const stage6 = fetchDepartmentChronicles(undefined, 6);
    expect(stage6.length).toBeGreaterThanOrEqual(1);
    expect(stage6.some((c) => c.title.includes("iCAT"))).toBe(true);
    expect(stage6.some((c) => c.title.includes("NABL"))).toBe(true);
  });

  it("creates a new stage milestone with deliverables", () => {
    const created = createDepartmentChronicle({
      departmentId: "mechanical",
      projectCode: "PRJ-TLM-002",
      stageNumber: 6,
      stageStatus: "completed",
      title: "Drop Test & Submersion Seal Integrity Pass",
      content: "IP67 housing survived 1.5m drop and 1-meter water immersion testing for 30 minutes with zero moisture ingress.",
      category: "milestone",
      deliverables: ["1.5m drop test report", "IP67 immersion test video log"],
      authorName: "Arun Kulkarni",
      authorRole: "Lead Mechanical Engineer",
      pinned: true,
    });

    expect(created.id).toBeDefined();
    expect(created.stageNumber).toBe(6);
    expect(created.stageName).toContain("Stage 6");
    expect(created.deliverables?.length).toBe(2);

    const stage6Chronicles = fetchDepartmentChronicles("mechanical", 6);
    expect(stage6Chronicles[0].title).toBe("Drop Test & Submersion Seal Integrity Pass");
  });

  it("allows changing status here and there via quickUpdateChronicleStatus", () => {
    const all = fetchDepartmentChronicles();
    const target = all[0];

    const updated = quickUpdateChronicleStatus(target.id, "blocked");
    expect(updated.stageStatus).toBe("blocked");

    const refreshed = fetchDepartmentChronicles().find((c) => c.id === target.id);
    expect(refreshed?.stageStatus).toBe("blocked");
  });

  it("allows changing stage here and there via quickUpdateChronicleStage", () => {
    const all = fetchDepartmentChronicles();
    const target = all[0];

    const updated = quickUpdateChronicleStage(target.id, 7);
    expect(updated.stageNumber).toBe(7);
    expect(updated.stageName).toContain("Stage 7");

    const refreshed = fetchDepartmentChronicles(undefined, 7).find((c) => c.id === target.id);
    expect(refreshed).toBeDefined();
  });

  it("updates and deletes a chronicle milestone", () => {
    const created = createDepartmentChronicle({
      departmentId: "procurement",
      title: "Temporary Quotation Inquiry",
      content: "Inquiry sent to distributor.",
      category: "notice",
      authorName: "Meera Nair",
      authorRole: "Procurement Specialist",
    });

    const updated = updateDepartmentChronicle(created.id, {
      title: "Approved PO Issued",
      category: "decision",
    });
    expect(updated.title).toBe("Approved PO Issued");

    const deleted = deleteDepartmentChronicle(created.id);
    expect(deleted).toBe(true);

    const check = fetchDepartmentChronicles().find((c) => c.id === created.id);
    expect(check).toBeUndefined();
  });
});
