import { createServerFn } from "@tanstack/react-start";
import { requireSupabaseAuth } from "@/integrations/supabase/auth-middleware";
import { internalNoteAvailability, internalNoteSaveSchema, internalNoteScopeSchema, readOwnInternalNoteRpc, saveOwnInternalNoteRpc } from "./requirement-internal-notes";

export const readOwnRequirementInternalNote = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((data) => internalNoteScopeSchema.parse(data))
  .handler(async ({ data, context }) => {
    if (!internalNoteAvailability.available) throw new Error(internalNoteAvailability.reason);
    return readOwnInternalNoteRpc((name, args) => (context.supabase as any).rpc(name, args), data, context.userId);
  });
export const saveOwnRequirementInternalNote = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((data) => internalNoteSaveSchema.parse(data))
  .handler(async ({ data, context }) => {
    if (!internalNoteAvailability.available) throw new Error(internalNoteAvailability.reason);
    return saveOwnInternalNoteRpc((name, args) => (context.supabase as any).rpc(name, args), data, context.userId);
  });
