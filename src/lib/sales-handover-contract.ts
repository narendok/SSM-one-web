import { z } from "zod";

const uuid = z.string().uuid();
/** Pending SQL contract only. This validates transport, never membership or authority. */
export const salesHandoverInputSchema = z.object({
  enquiryId: uuid, opportunityId: uuid, customerId: uuid,
  masterSpecificationVersionId: uuid,
  expectedEnquiryUpdatedAt: z.string().datetime({ offset: true }),
  requestKey: uuid,
  title: z.string().trim().min(1).max(240),
  customerReference: z.string().trim().max(160).nullable(),
  summary: z.string().trim().max(8000).nullable(),
  teams: z.array(z.object({ departmentId: uuid, reviewerUserId: uuid }).strict()).min(1),
}).strict().superRefine((input, ctx) => {
  if (new Set(input.teams.map((team) => team.departmentId)).size !== input.teams.length ||
      new Set(input.teams.map((team) => team.reviewerUserId)).size !== input.teams.length) {
    ctx.addIssue({ code: "custom", path: ["teams"], message: "Choose distinct departments and reviewers." });
  }
});

export function salesHandoverRpcArguments(input: z.infer<typeof salesHandoverInputSchema>) {
  const value = salesHandoverInputSchema.parse(input);
  const teams = [...value.teams].sort((a, b) => a.departmentId.localeCompare(b.departmentId));
  return {
    p_enquiry_id: value.enquiryId, p_opportunity_id: value.opportunityId,
    p_customer_id: value.customerId,
    p_master_specification_version_id: value.masterSpecificationVersionId,
    p_title: value.title, p_customer_reference: value.customerReference, p_summary: value.summary,
    p_department_ids: teams.map((team) => team.departmentId),
    p_reviewer_user_ids: teams.map((team) => team.reviewerUserId),
    p_expected_enquiry_updated_at: value.expectedEnquiryUpdatedAt, p_request_key: value.requestKey,
  };
}

export const salesHandoverReceiptSchema = z.array(z.object({
  requirement_id: uuid, review_ids: z.array(uuid).min(1), replayed: z.boolean(),
})).length(1);
