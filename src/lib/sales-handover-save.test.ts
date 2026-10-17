import { describe, expect, it, vi } from "vitest";
import {
  handoverOutcomeUncertain,
  submitSalesHandoverAcknowledgement,
  submitSalesHandoverWithReadback,
} from "./sales-handover-save";
const id = (n: number) => `00000000-0000-4000-8000-${String(n).padStart(12, "0")}`;
const input = {
  enquiryId: id(1),
  opportunityId: id(2),
  customerId: id(3),
  masterSpecificationVersionId: id(4),
  expectedEnquiryUpdatedAt: "2026-10-15T00:00:00Z",
  requestKey: id(5),
  title: "Feasibility",
  customerReference: null,
  summary: null,
  teams: [
    { departmentId: id(6), reviewerUserId: id(7) },
    { departmentId: id(8), reviewerUserId: id(9) },
  ],
};
const receipt = { requirement_id: id(10), review_ids: [id(11), id(12)], replayed: false };
describe("handover acknowledgement safeguards", () => {
  it.each([false, true])("preserves a complete acknowledgement and replay=%s", async (replayed) => {
    const rpc = vi.fn().mockResolvedValue({ data: [{ ...receipt, replayed }], error: null });
    expect(await submitSalesHandoverAcknowledgement({ rpc }, input)).toEqual({
      ...receipt,
      replayed,
    });
    expect(rpc).toHaveBeenCalledTimes(1);
    expect(rpc.mock.calls[0][1].p_request_key).toBe(input.requestKey);
  });
  it.each(
    [
      [],
      [receipt, receipt],
      [{ ...receipt, review_ids: [id(11)] }],
      [{ ...receipt, review_ids: [id(11), id(11)] }],
      [{ ...receipt, review_ids: [id(10), id(12)] }],
    ].map((data) => ({ data })),
  )("does not confirm an incomplete or contradictory acknowledgement %j", async ({ data }) => {
    const rpc = vi.fn().mockResolvedValue({ data, error: null });
    await expect(submitSalesHandoverAcknowledgement({ rpc }, input)).rejects.toThrow(
      handoverOutcomeUncertain,
    );
    expect(rpc).toHaveBeenCalledTimes(1);
  });
  it.each([{}, { code: "08006", message: "connection lost" }])(
    "treats unproven server outcomes as uncertain",
    async (error) => {
      const rpc = vi.fn().mockResolvedValue({ data: null, error });
      await expect(submitSalesHandoverAcknowledgement({ rpc }, input)).rejects.toThrow(
        handoverOutcomeUncertain,
      );
      expect(rpc).toHaveBeenCalledTimes(1);
    },
  );
  it("does not retry a lost response", async () => {
    const rpc = vi.fn().mockRejectedValue(new Error("network"));
    await expect(submitSalesHandoverAcknowledgement({ rpc }, input)).rejects.toThrow(
      handoverOutcomeUncertain,
    );
    expect(rpc).toHaveBeenCalledTimes(1);
  });
  it("preserves explicit transactional denial", async () => {
    const rpc = vi
      .fn()
      .mockResolvedValue({ data: null, error: { code: "42501", message: "Assignment denied" } });
    await expect(submitSalesHandoverAcknowledgement({ rpc }, input)).rejects.toThrow(
      "Assignment denied",
    );
  });
  it("rejects invalid source scope before contacting the backend", async () => {
    const rpc = vi.fn();
    await expect(
      submitSalesHandoverAcknowledgement({ rpc }, { ...input, requestKey: "invalid" }),
    ).rejects.toThrow();
    expect(rpc).not.toHaveBeenCalled();
  });
});

describe("gated handover save requires independent caller evidence", () => {
  const observed = {
    request_key: input.requestKey,
    requirement_id: receipt.requirement_id,
    source_revision_id: id(20),
    source_revision_number: 1,
    master_specification_version_id: input.masterSpecificationVersionId,
    master_specification_version_number: 1,
    review_pins: input.teams.map((team, index) => ({
      id: receipt.review_ids[index],
      department_id: team.departmentId,
      reviewer_user_id: team.reviewerUserId,
      source_revision_id: id(20),
      source_revision_number: 1,
      master_specification_version_id: input.masterSpecificationVersionId,
      master_specification_version_number: 1,
      applicable_workstreams: ["HARDWARE"],
    })),
    notification_ids: [id(21), id(22)],
    audit_id: id(23),
  };
  it("returns success only after a separate matching reader call", async () => {
    const rpc = vi
      .fn()
      .mockResolvedValueOnce({ data: [receipt], error: null })
      .mockResolvedValueOnce({ data: [observed], error: null });
    expect(await submitSalesHandoverWithReadback({ rpc }, input)).toEqual(receipt);
    expect(rpc.mock.calls.map((call) => call[0])).toEqual([
      "submit_sales_feasibility_handover",
      "read_sales_feasibility_handover_receipt",
    ]);
    expect(rpc.mock.calls[1][1].p_request_key).toBe(input.requestKey);
  });
  it.each(
    [
      [],
      [{ ...observed, notification_ids: [id(21), id(21)] }],
      [{ ...observed, requirement_id: id(99) }],
    ].map((data) => ({ data })),
  )("withholds success for absent or contradictory persisted evidence %j", async ({ data }) => {
    const rpc = vi
      .fn()
      .mockResolvedValueOnce({ data: [receipt], error: null })
      .mockResolvedValueOnce({ data, error: null });
    await expect(submitSalesHandoverWithReadback({ rpc }, input)).rejects.toThrow(
      handoverOutcomeUncertain,
    );
    expect(rpc).toHaveBeenCalledTimes(2);
  });
  it("does not retry the mutation when the reader transport is lost", async () => {
    const rpc = vi
      .fn()
      .mockResolvedValueOnce({ data: [receipt], error: null })
      .mockRejectedValueOnce(new Error("lost"));
    await expect(submitSalesHandoverWithReadback({ rpc }, input)).rejects.toThrow(
      handoverOutcomeUncertain,
    );
    expect(rpc).toHaveBeenCalledTimes(2);
  });
  it("does not query evidence after an explicit mutation denial", async () => {
    const rpc = vi
      .fn()
      .mockResolvedValueOnce({ data: null, error: { code: "42501", message: "denied" } });
    await expect(submitSalesHandoverWithReadback({ rpc }, input)).rejects.toThrow("denied");
    expect(rpc).toHaveBeenCalledTimes(1);
  });
});
