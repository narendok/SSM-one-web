import { createServerFn } from "@tanstack/react-start";
import { requireSupabaseAuth } from "@/integrations/supabase/auth-middleware";
import { salesFeasibilityHandoverAvailability } from "./client-requirement-intake";
import { salesHandoverInputSchema, salesHandoverRpcArguments, salesHandoverReceiptSchema } from "./sales-handover-contract";

/** Unavailable until the pending atomic SQL and caller acceptance are approved. */
export const submitSalesFeasibilityHandover = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((input) => salesHandoverInputSchema.parse(input))
  .handler(async ({ data, context }) => {
    if (!salesFeasibilityHandoverAvailability.available) {
      throw new Error(salesFeasibilityHandoverAvailability.reason);
    }
    const { data: receipt, error } = await (context.supabase as any).rpc(
      "submit_sales_feasibility_handover", salesHandoverRpcArguments(data),
    );
    if (error) throw new Error(error.message);
    return salesHandoverReceiptSchema.parse(receipt)[0];
  });
