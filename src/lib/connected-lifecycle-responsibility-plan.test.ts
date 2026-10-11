import { describe, expect, it } from "vitest";
import {
  connectedLifecycleResponsibilityDefaults,
  lifecycleResponsibilitySettingsStatus,
  lifecycleStageReadiness,
  preparationDefaultForStage,
  requirementRevisionRelation,
  responsibilityDefaultForStage,
  stagePreparationSummary,
  stagesForResponsibilityDefault,
} from "./connected-lifecycle-responsibility-plan";

describe("connected lifecycle responsibility defaults", () => {
  it("covers the authoritative HW_01 through HW_37 vocabulary without inventing a stage code", () => {
    for (let number = 1; number <= 37; number += 1) {
      expect(responsibilityDefaultForStage(`HW_${String(number).padStart(2, "0")}`)).not.toBeNull();
    }
    expect(responsibilityDefaultForStage("OTHER_01")).toBeNull();
  });

  it("keeps hardware BOM qualification and the governed Purchase handoff separate", () => {
    expect(responsibilityDefaultForStage("HW_09")).toMatchObject({
      key: "poc",
      leadDepartment: "RND",
    });
    expect(responsibilityDefaultForStage("HW_23")?.handoff).toContain("Purchase receives an approved handoff");
  });

  it("only groups the provided company stages and leaves persistence explicitly unavailable", () => {
    const readiness = connectedLifecycleResponsibilityDefaults.find((item) => item.key === "release_readiness");
    if (!readiness) throw new Error("Release-readiness mapping is required for this test.");
    expect(stagesForResponsibilityDefault([
      { id: "1", stage_code: "HW_22", title: "22", sort_order: 22, requires_gated_handover: false },
      { id: "2", stage_code: "HW_24", title: "24", sort_order: 24, requires_gated_handover: true },
      { id: "3", stage_code: "OTHER_01", title: "Other", sort_order: 25, requires_gated_handover: false },
    ], readiness).map((stage) => stage.stage_code)).toEqual(["HW_22", "HW_24"]);
    expect(lifecycleResponsibilitySettingsStatus()).toMatchObject({
      available: false,
      message: expect.stringContaining("Local planning adjustments are unsaved"),
    });
  });

  it("prepares deterministic stage deliverables without creating work or treating a handoff as approval", () => {
    expect(preparationDefaultForStage("HW_01")).toMatchObject({ key: "intake", leadDepartment: "SAL" });
    expect(preparationDefaultForStage("HW_09")).toMatchObject({ key: "poc", leadDepartment: "RND" });
    expect(preparationDefaultForStage("HW_23")).toMatchObject({
      key: "release_readiness",
      purchaseHandoff: "HARDWARE_APPROVED_HANDOFF_REQUIRED",
    });
    expect(preparationDefaultForStage("HW_30")).toMatchObject({ key: "dispatch", leadDepartment: "PROD" });
    expect(preparationDefaultForStage("OTHER_01")).toBeNull();
    expect(stagePreparationSummary([
      { id: "1", stage_code: "HW_22", title: "22", sort_order: 22, requires_gated_handover: false },
      { id: "2", stage_code: "HW_23", title: "23", sort_order: 23, requires_gated_handover: false },
      { id: "3", stage_code: "HW_30", title: "30", sort_order: 30, requires_gated_handover: false },
    ], "HW_23").matchingStages.map((stage) => stage.stage_code)).toEqual(["HW_22", "HW_23"]);
  });

  it("shows source prerequisites and unmapped-stage blockers without inferring release", () => {
    const readiness = lifecycleStageReadiness([
      { id: "23", stage_code: "HW_23", title: "Release readiness", sort_order: 23, requires_gated_handover: true },
    ], "HW_23", true);

    expect(readiness.responsibility?.leadDepartment).toBe("RND");
    expect(readiness.prerequisites).toEqual([
      "Pinned requirement baseline",
      "Visible records from the preceding lifecycle workstream",
      "Existing governed handover record",
    ]);
    expect(readiness.blockers).toEqual([]);

    const unmapped = lifecycleStageReadiness([], "INITIATION", false);
    expect(unmapped.responsibility).toBeNull();
    expect(unmapped.blockers).toEqual([
      "No requirement baseline is linked to this project.",
      "Recorded project stage INITIATION is not an accessible active company lifecycle stage.",
      "No default workstream is mapped to the recorded project stage.",
    ]);
  });

  it("flags a newer accessible requirement revision without treating the comparison as approval", () => {
    expect(requirementRevisionRelation(1, 2)).toMatchObject({
      state: "NEWER_REQUIREMENT_REVISION",
      message: expect.stringContaining("no acceptance is implied"),
    });
    expect(requirementRevisionRelation(1, 1)).toMatchObject({
      state: "PINNED_CURRENT",
      message: expect.stringContaining("does not confirm approval"),
    });
    expect(requirementRevisionRelation(1, null)).toMatchObject({
      state: "REQUIREMENT_UNAVAILABLE",
    });
  });
});