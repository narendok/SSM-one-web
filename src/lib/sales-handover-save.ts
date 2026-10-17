import { z } from "zod";
import { salesHandoverInputSchema, salesHandoverReceiptSchema, salesHandoverRpcArguments } from "./sales-handover-contract";

type HandoverInput = z.infer<typeof salesHandoverInputSchema>;
type CallerRpc = { rpc: (name: string, args: ReturnType<typeof salesHandoverRpcArguments>) => Promise<{ data: unknown; error: { code?: string; message?: string } | null }> };
export const handoverOutcomeUncertain = "The handover may have been saved, but its result could not be verified. Refresh before trying again.";

/** Validates the mutation acknowledgement only; this does not prove independent readback. */
export async function submitSalesHandoverAcknowledgement(caller: CallerRpc, input: HandoverInput) {
  const value = salesHandoverInputSchema.parse(input);
  let result;
  try {
    result = await caller.rpc("submit_sales_feasibility_handover", salesHandoverRpcArguments(value));
  } catch {
    throw new Error(handoverOutcomeUncertain);
  }
  if (result.error) {
    const code = result.error.code ?? "";
    if (code === "P0001" || code === "42501" || /^(22|23|40)[A-Z0-9]{3}$/.test(code)) {
      throw new Error(result.error.message ?? "Could not submit the feasibility handover.");
    }
    throw new Error(handoverOutcomeUncertain);
  }
  const parsed = salesHandoverReceiptSchema.safeParse(result.data);
  if (!parsed.success) throw new Error(handoverOutcomeUncertain);
  const receipt = parsed.data[0];
  if (receipt.review_ids.length !== value.teams.length ||
      new Set(receipt.review_ids).size !== receipt.review_ids.length ||
      receipt.review_ids.includes(receipt.requirement_id)) {
    throw new Error(handoverOutcomeUncertain);
  }
  return receipt;
}
