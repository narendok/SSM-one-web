import { createServerFn } from "@tanstack/react-start";
import { requireSupabaseAuth } from "@/integrations/supabase/auth-middleware";
import { highlightDraftAvailability, highlightDraftSaveSchema, highlightDraftScopeSchema, readOwnHighlightDraftRpc, saveOwnHighlightDraftRpc } from "./requirement-highlight-drafts";

export const readOwnRequirementHighlightDraft = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((data) => highlightDraftScopeSchema.parse(data))
  .handler(async ({ data, context }) => {
    if (!highlightDraftAvailability.available) throw new Error(highlightDraftAvailability.reason);
    return readOwnHighlightDraftRpc((name, args) => (context.supabase as any).rpc(name, args), data, context.userId);
  });
export const saveOwnRequirementHighlightDraft = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((data) => highlightDraftSaveSchema.parse(data))
  .handler(async ({ data, context }) => {
    if (!highlightDraftAvailability.available) throw new Error(highlightDraftAvailability.reason);
    return saveOwnHighlightDraftRpc((name, args) => (context.supabase as any).rpc(name, args), data, context.userId);
  });
