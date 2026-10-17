import { describe, expect, it, vi } from "vitest";
import { feasibilityResponseReadbackUnavailable, recordFeasibilityWithReadback, scopedFeasibilityResponseSchema } from "./feasibility-response-save";

const ids = Array.from({ length: 7 }, (_, i) => `00000000-0000-4000-8000-${String(i + 1).padStart(12, "0")}`);
const input = { reviewId: ids[0], requirementId: ids[1], sourceRevisionId: ids[2], masterSpecificationVersionId: ids[3], requestKey: ids[4], verdict: "feasible_with_conditions" as const, findings: "Termination required", assumptions: null, risks: "Thermal check" };
const receipt = { review_id: ids[0], requirement_id: ids[1], source_revision_id: ids[2], master_specification_version_id: ids[3], request_key: ids[4], audit_id: ids[5] };
const saved = { data: ids[0], error: null };

describe("feasibility response mutation and independent receipt", () => {
  it("returns success only after a second exact-scope caller RPC", async () => {
    const rpc = vi.fn().mockResolvedValueOnce(saved).mockResolvedValueOnce({ data: [receipt], error: null });
    expect(await recordFeasibilityWithReadback({ rpc }, input)).toEqual({ reviewId: input.reviewId });
    expect(rpc).toHaveBeenNthCalledWith(1, "record_requirement_feasibility_response", {
      p_review_id: ids[0], p_request_key: ids[4], p_status: input.verdict, p_findings: input.findings, p_assumptions: null, p_risks: input.risks,
    });
    expect(rpc).toHaveBeenNthCalledWith(2, "read_requirement_feasibility_response_receipt", {
      p_review_id: ids[0], p_requirement_id: ids[1], p_source_revision_id: ids[2], p_master_specification_version_id: ids[3], p_request_key: ids[4],
    });
    expect(rpc).toHaveBeenCalledTimes(2);
  });

  it("rejects an unpinned input before any mutation", async () => {
    for (const key of ["requirementId", "sourceRevisionId", "masterSpecificationVersionId", "requestKey"] as const) {
      const invalid = { ...input, [key]: undefined };
      expect(scopedFeasibilityResponseSchema.safeParse(invalid).success).toBe(false);
      const rpc = vi.fn();
      await expect(recordFeasibilityWithReadback({ rpc }, invalid as any)).rejects.toThrow();
      expect(rpc).not.toHaveBeenCalled();
    }
    expect(scopedFeasibilityResponseSchema.safeParse({ ...input, actorId: ids[6] }).success).toBe(false);
  });

  it("does not perform a receipt read or retry after a denied mutation", async () => {
    const rpc = vi.fn().mockResolvedValue({ data: null, error: { message: "Assigned reviewer required", code: "42501" } });
    await expect(recordFeasibilityWithReadback({ rpc }, input)).rejects.toThrow("Assigned reviewer required");
    expect(rpc).toHaveBeenCalledTimes(1);
  });

  it("reports uncertain save on an interrupted mutation without retry", async () => {
    const rpc = vi.fn().mockRejectedValue(new Error("Connection lost"));
    await expect(recordFeasibilityWithReadback({ rpc }, input)).rejects.toThrow(feasibilityResponseReadbackUnavailable);
    expect(rpc).toHaveBeenCalledTimes(1);
  });

  it("keeps transport-style error responses uncertain without retry", async () => {
    for (const error of [{ message: "Fetch failed" }, { message: "Connection failed", code: "08006" }]) {
      const rpc = vi.fn().mockResolvedValue({ data: null, error });
      await expect(recordFeasibilityWithReadback({ rpc }, input)).rejects.toThrow(feasibilityResponseReadbackUnavailable);
      expect(rpc).toHaveBeenCalledTimes(1);
    }
  });

  it("rejects absent or wrong returned mutation identity", async () => {
    for (const data of [null, ids[6], [ids[0]], { reviewId: ids[0] }]) {
      const rpc = vi.fn().mockResolvedValue({ data, error: null });
      await expect(recordFeasibilityWithReadback({ rpc }, input)).rejects.toThrow(feasibilityResponseReadbackUnavailable);
      expect(rpc).toHaveBeenCalledTimes(1);
    }
  });

  it("preserves uncertain commit for denied, missing, duplicate or mismatched receipt evidence", async () => {
    const responses = [
      { data: [receipt], error: { message: "RLS denied" } },
      ...[[], [receipt, receipt], [{ ...receipt, audit_id: null }],
        ...["review_id", "requirement_id", "source_revision_id", "master_specification_version_id", "request_key"].map((field) => [{ ...receipt, [field]: ids[6] }]),
      ].map((data) => ({ data, error: null })),
    ];
    for (const response of responses) {
      const rpc = vi.fn().mockResolvedValueOnce(saved).mockResolvedValueOnce(response);
      await expect(recordFeasibilityWithReadback({ rpc }, input)).rejects.toThrow(feasibilityResponseReadbackUnavailable);
      expect(rpc).toHaveBeenCalledTimes(2);
    }
  });

  it("does not retry the write when the independent read connection fails", async () => {
    const rpc = vi.fn().mockResolvedValueOnce(saved).mockRejectedValueOnce(new Error("Read interrupted"));
    await expect(recordFeasibilityWithReadback({ rpc }, input)).rejects.toThrow(feasibilityResponseReadbackUnavailable);
    expect(rpc.mock.calls.filter(([name]) => name === "record_requirement_feasibility_response")).toHaveLength(1);
    expect(input.requestKey).toBe(ids[4]);
  });
});

