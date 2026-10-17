import { z } from "zod";
import { salesHandoverInputSchema, salesHandoverReceiptSchema } from "./sales-handover-contract";
const uuid = z.string().uuid();
const pin = z
  .object({
    id: uuid,
    department_id: uuid,
    reviewer_user_id: uuid,
    source_revision_id: uuid,
    source_revision_number: z.number().int().positive(),
    master_specification_version_id: uuid,
    master_specification_version_number: z.number().int().positive(),
    applicable_workstreams: z
      .array(z.enum(["HARDWARE", "FIRMWARE", "MECHANICAL", "TEST", "MANUFACTURING"]))
      .min(1),
  })
  .strict();
const row = z
  .object({
    request_key: uuid,
    requirement_id: uuid,
    source_revision_id: uuid,
    source_revision_number: z.number().int().positive(),
    master_specification_version_id: uuid,
    master_specification_version_number: z.number().int().positive(),
    review_pins: z.array(pin).min(1),
    notification_ids: z.array(uuid).min(1),
    audit_id: uuid,
  })
  .strict();
type CallerRpc = {
  rpc: (name: string, args: Record<string, string>) => Promise<{ data: unknown; error: unknown }>;
};
/** Opt-in proposal only. Mutation acknowledgement is an expected identity, never evidence. */
export async function observeSalesHandover(input: {
  caller: CallerRpc;
  enabled: boolean;
  source: z.infer<typeof salesHandoverInputSchema>;
  acknowledgement: unknown;
}): Promise<{ status: "OBSERVED"; sourceRevisionId: string } | { status: "BLOCKED" }> {
  if (!input.enabled) return { status: "BLOCKED" };
  const source = salesHandoverInputSchema.parse(input.source);
  const ack = salesHandoverReceiptSchema.safeParse([input.acknowledgement]);
  if (!ack.success) return { status: "BLOCKED" };
  try {
    const response = await input.caller.rpc("read_sales_feasibility_handover_receipt", {
      p_request_key: source.requestKey,
      p_enquiry_id: source.enquiryId,
      p_opportunity_id: source.opportunityId,
      p_customer_id: source.customerId,
      p_master_specification_version_id: source.masterSpecificationVersionId,
    });
    if (response.error) return { status: "BLOCKED" };
    const parsed = z.array(row).length(1).safeParse(response.data);
    if (!parsed.success) return { status: "BLOCKED" };
    const observed = parsed.data[0],
      expected = ack.data[0];
    const pins = observed.review_pins;
    if (
      observed.request_key !== source.requestKey ||
      observed.requirement_id !== expected.requirement_id ||
      observed.master_specification_version_id !== source.masterSpecificationVersionId ||
      pins.length !== source.teams.length ||
      expected.review_ids.length !== pins.length ||
      new Set(expected.review_ids).size !== pins.length ||
      new Set(pins.map((p) => p.id)).size !== pins.length ||
      observed.notification_ids.length !== pins.length ||
      new Set(observed.notification_ids).size !== pins.length ||
      pins.some(
        (p) =>
          !expected.review_ids.includes(p.id) ||
          p.source_revision_id !== observed.source_revision_id ||
          p.source_revision_number !== observed.source_revision_number ||
          p.master_specification_version_id !== source.masterSpecificationVersionId ||
          p.master_specification_version_number !== observed.master_specification_version_number,
      ) ||
      source.teams.some(
        (t) =>
          pins.filter(
            (p) => p.department_id === t.departmentId && p.reviewer_user_id === t.reviewerUserId,
          ).length !== 1,
      )
    )
      return { status: "BLOCKED" };
    return { status: "OBSERVED", sourceRevisionId: observed.source_revision_id };
  } catch {
    return { status: "BLOCKED" };
  }
}
