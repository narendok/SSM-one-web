import { describe, expect, it } from "vitest";
import {
  defaultResponsibilityLead,
  lifecycleResponsibilityOverrideContract,
  responsibilityOverrideAvailability,
} from "./lifecycle-responsibility-overrides.contract";

describe("lifecycle responsibility override contract boundary", () => {
  it("keeps persisted responsibility overrides inactive until the protected contract is accepted", () => {
    expect(responsibilityOverrideAvailability()).toMatchObject({ available: false, contract: { state: "INACTIVE" } });
    expect(lifecycleResponsibilityOverrideContract.unavailableReason).toContain("Local planning adjustments remain unsaved");
  });

  it("requires revision conflict, replay, audit, and manual-history preservation", () => {
    expect(lifecycleResponsibilityOverrideContract.protectedInputs).toEqual(expect.arrayContaining([
      "Expected project-stage record updated timestamp",
      "Caller request key",
    ]));
    expect(lifecycleResponsibilityOverrideContract.preservedRecords).toEqual(expect.arrayContaining([
      "Existing linked tasks, handover notes, evidence, statuses, and completion history",
    ]));
    expect(lifecycleResponsibilityOverrideContract.requiredTransactionGuarantees.join(" ")).toMatch(/optimistic stage revision conflict.*request-key replay.*immutable audit/i);
  });

  it("maps only the agreed connected lifecycle ranges and rejects unrelated stages", () => {
    expect(defaultResponsibilityLead("HW_09")).toBe("RND");
    expect(defaultResponsibilityLead("HW_30")).toBe("PROD");
    expect(defaultResponsibilityLead("OTHER_01")).toBeNull();
  });
});