import { describe, it, expect, vi } from "vitest";
import {
  assignFeasibilityWithReadback,
  assignmentOutcomeUncertain,
} from "./feasibility-assignment-save";
const id = (n: number) => `00000000-0000-4000-8000-${String(n).padStart(12, "0")}`;
const input = { requirementId: id(1), departmentId: id(2), reviewerUserId: id(3) };
const row = {
  id: id(4),
  requirement_id: id(1),
  department_id: id(2),
  reviewer_user_id: id(3),
  status: "pending",
  source_revision_id: id(5),
  source_revision_number: 1,
  master_specification_version_id: id(6),
  master_specification_version_number: 1,
  applicable_workstreams: ["HARDWARE"],
};
function caller(data: unknown = row, error: unknown = null) {
  const read = vi.fn().mockResolvedValue({ data, error });
  const eq = vi.fn(() => ({ maybeSingle: read }));
  const select = vi.fn(() => ({ eq }));
  return {
    rpc: vi.fn().mockResolvedValue({ data: id(4), error: null }),
    from: vi.fn(() => ({ select })),
    read,
    eq,
  };
}
describe("protected assignment stored readback", () => {
  it("requires a separate caller read matching submitted identities", async () => {
    const c = caller();
    expect(await assignFeasibilityWithReadback(c, input)).toEqual({ id: id(4) });
    expect(c.rpc).toHaveBeenCalledTimes(1);
    expect(c.from).toHaveBeenCalledWith("requirement_feasibility_reviews");
    expect(c.eq).toHaveBeenCalledWith("id", id(4));
  });
  it.each(
    [
      null,
      { ...row, id: id(99) },
      { ...row, requirement_id: id(99) },
      { ...row, department_id: id(99) },
      { ...row, reviewer_user_id: id(99) },
      { ...row, status: "feasible" },
      { ...row, source_revision_id: null },
      { ...row, applicable_workstreams: ["UNKNOWN"] },
    ].map((data) => ({ data })),
  )("does not confirm absent/mismatched/unpinned evidence %j", async ({ data }) => {
    const c = caller(data);
    await expect(assignFeasibilityWithReadback(c, input)).rejects.toThrow(
      assignmentOutcomeUncertain,
    );
    expect(c.rpc).toHaveBeenCalledTimes(1);
  });
  it("treats denied or lost reads as uncertain without repeating assignment", async () => {
    const denied = caller(null, { code: "42501" });
    await expect(assignFeasibilityWithReadback(denied, input)).rejects.toThrow(
      assignmentOutcomeUncertain,
    );
    expect(denied.rpc).toHaveBeenCalledTimes(1);
    const lost = caller();
    lost.read.mockRejectedValue(new Error("lost"));
    await expect(assignFeasibilityWithReadback(lost, input)).rejects.toThrow(
      assignmentOutcomeUncertain,
    );
    expect(lost.rpc).toHaveBeenCalledTimes(1);
  });
  it("preserves explicit mutation denial and never queries the review", async () => {
    const c = caller();
    c.rpc.mockResolvedValue({ data: null, error: { code: "42501", message: "denied" } });
    await expect(assignFeasibilityWithReadback(c, input)).rejects.toThrow("denied");
    expect(c.from).not.toHaveBeenCalled();
  });
  it("does not retry lost mutation responses or read using an unverified ID", async () => {
    const c = caller();
    c.rpc.mockRejectedValue(new Error("lost"));
    await expect(assignFeasibilityWithReadback(c, input)).rejects.toThrow(
      assignmentOutcomeUncertain,
    );
    expect(c.rpc).toHaveBeenCalledTimes(1);
    expect(c.from).not.toHaveBeenCalled();
  });
});
