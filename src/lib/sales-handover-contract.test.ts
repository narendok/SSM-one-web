import { describe, expect, it } from "vitest";
import { salesHandoverInputSchema, salesHandoverRpcArguments, salesHandoverReceiptSchema } from "./sales-handover-contract";
const id = (n: number) => `00000000-0000-4000-8000-${String(n).padStart(12, "0")}`;
const input = { enquiryId: id(1), opportunityId: id(2), customerId: id(3), masterSpecificationVersionId: id(4), expectedEnquiryUpdatedAt: "2026-10-15T00:00:00Z", requestKey: id(5), title: "Feasibility", customerReference: null, summary: null, teams: [{ departmentId: id(8), reviewerUserId: id(9) }, { departmentId: id(6), reviewerUserId: id(7) }] };
describe("pending Sales handover transport", () => {
  it("keeps department/reviewer pairs together in canonical order and pins exact sources", () => {
    const args = salesHandoverRpcArguments(input);
    expect(args.p_department_ids).toEqual([id(6), id(8)]);
    expect(args.p_reviewer_user_ids).toEqual([id(7), id(9)]);
    expect(args.p_master_specification_version_id).toBe(id(4));
    expect(args.p_expected_enquiry_updated_at).toBe(input.expectedEnquiryUpdatedAt);
    expect(args.p_request_key).toBe(id(5));
    expect(input.teams[0].departmentId).toBe(id(8));
  });
  it("rejects duplicate reviewers, duplicate departments, empty routing and missing immutable pins", () => {
    for (const teams of [[], [input.teams[0], input.teams[0]], [{...input.teams[0]}, {...input.teams[1], reviewerUserId: id(9)}]]) {
      expect(salesHandoverInputSchema.safeParse({...input, teams}).success).toBe(false);
    }
    expect(salesHandoverInputSchema.safeParse({...input, masterSpecificationVersionId: undefined}).success).toBe(false);
    expect(salesHandoverInputSchema.safeParse({...input, customerReference: "x".repeat(161)}).success).toBe(false);
  });
  it("requires exactly one nonempty atomic receipt instead of treating empty success as saved", () => {
    expect(salesHandoverReceiptSchema.safeParse([]).success).toBe(false);
    expect(salesHandoverReceiptSchema.safeParse([{requirement_id: id(10), review_ids: [], replayed: false}]).success).toBe(false);
    expect(salesHandoverReceiptSchema.parse([{requirement_id: id(10), review_ids: [id(11)], replayed: true}])[0].replayed).toBe(true);
  });
});
