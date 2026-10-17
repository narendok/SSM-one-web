import { submitSalesHandoverAcknowledgement } from "./sales-handover-save";
import { createServerFn } from "@tanstack/react-start";
import { requireSupabaseAuth } from "@/integrations/supabase/auth-middleware";
import { salesFeasibilityHandoverAvailability } from "./client-requirement-intake";
import { salesHandoverInputSchema } from "./sales-handover-contract";

/** Installed backend; UI remains unavailable until workflow and caller acceptance. */
export const submitSalesFeasibilityHandover = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((input) => salesHandoverInputSchema.parse(input))
  .handler(async ({ data, context }) => {
    if (!salesFeasibilityHandoverAvailability.available) {
      throw new Error(salesFeasibilityHandoverAvailability.reason);
    }
    return submitSalesHandoverAcknowledgement(context.supabase as any, data);
  });
