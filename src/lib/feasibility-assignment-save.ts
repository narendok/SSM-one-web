import { z } from "zod";
const uuid = z.string().uuid();
export const protectedAssignmentInputSchema = z
  .object({ requirementId: uuid, departmentId: uuid, reviewerUserId: uuid })
  .strict();
const assignedRow = z
  .object({
    id: uuid,
    requirement_id: uuid,
    department_id: uuid,
    reviewer_user_id: uuid,
    status: z.literal("pending"),
    source_revision_id: uuid,
    source_revision_number: z.number().int().positive(),
    master_specification_version_id: uuid,
    master_specification_version_number: z.number().int().positive(),
    applicable_workstreams: z
      .array(z.enum(["HARDWARE", "FIRMWARE", "MECHANICAL", "TEST", "MANUFACTURING"]))
      .min(1),
  })
  .strict();
type Result = { data: unknown; error: { message?: string; code?: string } | null };
type Caller = {
  rpc: (name: string, args: Record<string, string>) => Promise<Result>;
  from: (table: string) => {
    select: (fields: string) => {
      eq: (field: string, value: string) => { maybeSingle: () => Promise<Result> };
    };
  };
};
export const assignmentOutcomeUncertain =
  "The reviewer assignment may have been saved, but its readback could not be verified. Refresh before trying again.";
/** Matching stored values only. Authority is owned by the protected RPC and caller RLS. */
export async function assignFeasibilityWithReadback(
  caller: Caller,
  input: z.infer<typeof protectedAssignmentInputSchema>,
) {
  const value = protectedAssignmentInputSchema.parse(input);
  let saved: Result;
  try {
    saved = await caller.rpc("assign_requirement_feasibility_review", {
      p_requirement_id: value.requirementId,
      p_department_id: value.departmentId,
      p_reviewer_user_id: value.reviewerUserId,
    });
  } catch {
    throw new Error(assignmentOutcomeUncertain);
  }
  if (saved.error) {
    const code = saved.error.code ?? "";
    if (code === "P0001" || code === "42501" || /^(22|23|40)[A-Z0-9]{3}$/.test(code))
      throw new Error(saved.error.message ?? "Reviewer assignment was rejected.");
    throw new Error(assignmentOutcomeUncertain);
  }
  const reviewId = uuid.safeParse(saved.data);
  if (!reviewId.success) throw new Error(assignmentOutcomeUncertain);
  try {
    const result = await caller
      .from("requirement_feasibility_reviews")
      .select(
        "id,requirement_id,department_id,reviewer_user_id,status,source_revision_id,source_revision_number,master_specification_version_id,master_specification_version_number,applicable_workstreams",
      )
      .eq("id", reviewId.data)
      .maybeSingle();
    const observed = assignedRow.safeParse(result.data);
    if (
      result.error ||
      !observed.success ||
      observed.data.id !== reviewId.data ||
      observed.data.requirement_id !== value.requirementId ||
      observed.data.department_id !== value.departmentId ||
      observed.data.reviewer_user_id !== value.reviewerUserId
    )
      throw new Error(assignmentOutcomeUncertain);
  } catch {
    throw new Error(assignmentOutcomeUncertain);
  }
  return { id: reviewId.data };
}
