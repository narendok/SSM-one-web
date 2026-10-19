import { describe, it, expect, beforeEach } from "vitest";
import {
  getAssignedStagesForDepartment,
  getDepartmentStagesSummary,
  getDepartmentsForStage,
  assignStageToDepartment,
  unassignStageFromDepartment,
  updateDepartmentStageRole,
  updateDepartmentStageStatus,
  updateDepartmentStageDeliverables,
  resetDepartmentStageResponsibilities,
  normalizeDepartmentId,
} from "./department-stage-responsibilities";

describe("department-stage-responsibilities", () => {
  beforeEach(() => {
    resetDepartmentStageResponsibilities();
  });

  it("normalizes department codes and aliases correctly", () => {
    expect(normalizeDepartmentId("MECH")).toBe("mechanical");
    expect(normalizeDepartmentId("mechanical")).toBe("mechanical");
    expect(normalizeDepartmentId("RND")).toBe("rnd");
    expect(normalizeDepartmentId("Hardware & R&D")).toBe("rnd");
    expect(normalizeDepartmentId("PROC")).toBe("procurement");
    expect(normalizeDepartmentId("purchase")).toBe("procurement");
    expect(normalizeDepartmentId("PROD")).toBe("production");
    expect(normalizeDepartmentId("SAL")).toBe("sales");
    expect(normalizeDepartmentId("OPS")).toBe("operations");
  });

  it("seeds correct Master Plan stages for Mechanical Engineering", () => {
    const mechStages = getAssignedStagesForDepartment("mechanical");
    const stageNumbers = mechStages.map((s) => s.stageNumber);
    // Mechanical has Stage 2 (Feasibility), Stage 4 (POC), Stage 5 (Pilot), Stage 6 (Validation)
    expect(stageNumbers).toContain(2);
    expect(stageNumbers).toContain(4);
    expect(stageNumbers).toContain(5);
    expect(stageNumbers).toContain(6);

    const stg2 = mechStages.find((s) => s.stageNumber === 2);
    expect(stg2?.role).toBe("lead");
    expect(stg2?.deliverables.some((d) => d.includes("IP67"))).toBe(true);
  });

  it("seeds correct Master Plan stages for Procurement", () => {
    const procStages = getAssignedStagesForDepartment("procurement");
    const stageNumbers = procStages.map((s) => s.stageNumber);
    // Procurement has Stage 2, Stage 4, Stage 5, Stage 7, Stage 8
    expect(stageNumbers).toContain(2);
    expect(stageNumbers).toContain(5);
    expect(stageNumbers).toContain(8);

    const stg8 = procStages.find((s) => s.stageNumber === 8);
    expect(stg8?.role).toBe("lead");
    expect(stg8?.deliverables.some((d) => d.includes("PPAP"))).toBe(true);
  });

  it("seeds correct Master Plan stages for Sales", () => {
    const salesStages = getAssignedStagesForDepartment("sales");
    const stageNumbers = salesStages.map((s) => s.stageNumber);
    expect(stageNumbers).toContain(1);
    expect(stageNumbers).toContain(2);
    expect(stageNumbers).toContain(3);
    expect(stageNumbers).toContain(9);

    const stg1 = salesStages.find((s) => s.stageNumber === 1);
    expect(stg1?.role).toBe("lead");
  });

  it("generates department stages summary across all 9 stages", () => {
    const summary = getDepartmentStagesSummary("mechanical");
    expect(summary).toHaveLength(9);
    const stg2 = summary.find((s) => s.stageNumber === 2);
    expect(stg2?.isAssigned).toBe(true);
    expect(stg2?.assignment?.role).toBe("lead");

    const stg1 = summary.find((s) => s.stageNumber === 1);
    expect(stg1?.isAssigned).toBe(false);
  });

  it("allows assigning and unassigning stages dynamically", () => {
    // Give Mechanical Stage 1 (Intake)
    const assigned = assignStageToDepartment(
      "mechanical",
      1,
      "participating",
      ["Mechanical customer interface review"],
      "in_progress",
      "Custom assigned for OEM client review"
    );
    expect(assigned.role).toBe("participating");
    expect(assigned.deliverables).toContain("Mechanical customer interface review");

    let mechStages = getAssignedStagesForDepartment("mechanical");
    expect(mechStages.map((s) => s.stageNumber)).toContain(1);

    // Now unassign it
    const removed = unassignStageFromDepartment("mechanical", 1);
    expect(removed).toBe(true);

    mechStages = getAssignedStagesForDepartment("mechanical");
    expect(mechStages.map((s) => s.stageNumber)).not.toContain(1);
  });

  it("updates stage responsibility role, status, and deliverables", () => {
    // Update Mechanical Stage 6 from participating to lead
    const updatedRole = updateDepartmentStageRole("mechanical", 6, "lead");
    expect(updatedRole?.role).toBe("lead");

    // Update status to blocked
    const updatedStatus = updateDepartmentStageStatus("mechanical", 6, "blocked");
    expect(updatedStatus?.status).toBe("blocked");

    // Update deliverables
    const updatedDeliverables = updateDepartmentStageDeliverables("mechanical", 6, [
      "Custom thermal chamber shock report",
      "Vibration profile sign-off",
    ]);
    expect(updatedDeliverables?.deliverables).toHaveLength(2);
    expect(updatedDeliverables?.deliverables[0]).toBe("Custom thermal chamber shock report");
  });

  it("retrieves all departments assigned to a specific stage ordered by role weight", () => {
    const stage2Depts = getDepartmentsForStage(2);
    expect(stage2Depts.length).toBeGreaterThanOrEqual(4);
    // Lead departments should be at the front
    expect(stage2Depts[0].role).toBe("lead");
  });
});
