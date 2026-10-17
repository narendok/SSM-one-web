import { z } from "zod";
import { feasibilityResponseSchema, salesReviewerResponseReadScopeSchema } from "./client-requirement-intake";
import { createSalesReviewerResponseReadbackAdapter } from "./sales-bound-requirement-readback";

export const scopedFeasibilityResponseSchema = feasibilityResponseSchema.merge(salesReviewerResponseReadScopeSchema).strict();
export type ScopedFeasibilityResponse = z.infer<typeof scopedFeasibilityResponseSchema>;

type CallerRpc = {
  rpc: (name: string, arguments_: Record<string, string | null>) => Promise<{
    data: unknown;
    error: { message?: string; code?: string } | null;
  }>;
};

export const feasibilityResponseReadbackUnavailable = "Your response may have been saved, but its readback could not be verified. Refresh before trying again.";

/** Uses only the authenticated caller client; successful mutation output is not readback. */
export async function recordFeasibilityWithReadback(caller: CallerRpc, input: ScopedFeasibilityResponse) {
  const value = scopedFeasibilityResponseSchema.parse(input);
  let saved;
  try {
    saved = await caller.rpc("record_requirement_feasibility_response", {
      p_review_id: value.reviewId,
      p_request_key: value.requestKey,
      p_status: value.verdict,
      p_findings: value.findings,
      p_assumptions: value.assumptions,
      p_risks: value.risks,
    });
  } catch {
    throw new Error(feasibilityResponseReadbackUnavailable);
  }
  if (saved.error) {
    // Only explicit transaction-aborting server errors prove this save was rejected.
    const code = saved.error.code ?? "";
    if (code === "P0001" || code === "42501" || /^(22|23|40)[A-Z0-9]{3}$/.test(code)) {
      throw new Error(saved.error.message ?? "Could not record the feasibility response.");
    }
    throw new Error(feasibilityResponseReadbackUnavailable);
  }
  if (saved.data !== value.reviewId) throw new Error(feasibilityResponseReadbackUnavailable);

  try {
    const observed = await createSalesReviewerResponseReadbackAdapter({ callerRlsRpc: caller, enabled: true }).observe({
      kind: "sales-reviewer-response-read",
      assertion: "reviewer-response-readback",
      scope: {
        reviewId: value.reviewId,
        requirementId: value.requirementId,
        sourceRevisionId: value.sourceRevisionId,
        masterSpecificationVersionId: value.masterSpecificationVersionId,
        requestKey: value.requestKey,
      },
    });
    if (observed.status !== "OBSERVED" || !observed.ok) throw new Error(feasibilityResponseReadbackUnavailable);
  } catch {
    throw new Error(feasibilityResponseReadbackUnavailable);
  }
  return { reviewId: value.reviewId };
}

