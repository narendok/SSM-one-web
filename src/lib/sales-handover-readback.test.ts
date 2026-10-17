import { describe, expect, it, vi } from "vitest";
import { observeSalesHandover } from "./sales-handover-readback";
const id = (n: number) => `00000000-0000-4000-8000-${String(n).padStart(12, "0")}`;
const source = {
  enquiryId: id(1),
  opportunityId: id(2),
  customerId: id(3),
  masterSpecificationVersionId: id(4),
  expectedEnquiryUpdatedAt: "2026-10-17T00:00:00Z",
  requestKey: id(5),
  title: "Scope",
  customerReference: null,
  summary: null,
  teams: [{ departmentId: id(6), reviewerUserId: id(7) }],
};
const acknowledgement = { requirement_id: id(8), review_ids: [id(9)], replayed: false };
const valid = {
  request_key: id(5),
  requirement_id: id(8),
  source_revision_id: id(10),
  source_revision_number: 1,
  master_specification_version_id: id(4),
  master_specification_version_number: 1,
  review_pins: [
    {
      id: id(9),
      department_id: id(6),
      reviewer_user_id: id(7),
      source_revision_id: id(10),
      source_revision_number: 1,
      master_specification_version_id: id(4),
      master_specification_version_number: 1,
      applicable_workstreams: ["HARDWARE"],
    },
  ],
  notification_ids: [id(11)],
  audit_id: id(12),
};
describe("source-only handover independent evidence adapter", () => {
  it("makes no caller request while deployment is disabled", async () => {
    const rpc = vi.fn();
    expect(
      await observeSalesHandover({ caller: { rpc }, enabled: false, source, acknowledgement }),
    ).toEqual({ status: "BLOCKED" });
    expect(rpc).not.toHaveBeenCalled();
  });
  it("observes exact review, source and notification identity only from the separate reader", async () => {
    const rpc = vi.fn().mockResolvedValue({ data: [valid], error: null });
    expect(
      await observeSalesHandover({ caller: { rpc }, enabled: true, source, acknowledgement }),
    ).toEqual({ status: "OBSERVED", sourceRevisionId: id(10) });
    expect(rpc).toHaveBeenCalledWith("read_sales_feasibility_handover_receipt", {
      p_request_key: id(5),
      p_enquiry_id: id(1),
      p_opportunity_id: id(2),
      p_customer_id: id(3),
      p_master_specification_version_id: id(4),
    });
  });
  it.each(
    [
      [],
      [valid, valid],
      [{ ...valid, request_key: id(99) }],
      [{ ...valid, notification_ids: [] }],
      [{ ...valid, review_pins: [{ ...valid.review_pins[0], reviewer_user_id: id(99) }] }],
      [{ ...valid, review_pins: [{ ...valid.review_pins[0], source_revision_id: id(99) }] }],
    ].map((data) => ({ data })),
  )("blocks incomplete or mismatched evidence %j", async ({ data }) => {
    const rpc = vi.fn().mockResolvedValue({ data, error: null });
    expect(
      await observeSalesHandover({ caller: { rpc }, enabled: true, source, acknowledgement }),
    ).toEqual({ status: "BLOCKED" });
    expect(rpc).toHaveBeenCalledTimes(1);
  });
  it("blocks denied and lost reads without retries", async () => {
    for (const rpc of [
      vi.fn().mockResolvedValue({ data: [valid], error: { message: "denied" } }),
      vi.fn().mockRejectedValue(new Error("network")),
    ]) {
      expect(
        await observeSalesHandover({ caller: { rpc }, enabled: true, source, acknowledgement }),
      ).toEqual({ status: "BLOCKED" });
      expect(rpc).toHaveBeenCalledTimes(1);
    }
  });
});
