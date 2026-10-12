import { createServerFn } from "@tanstack/react-start";
import { z } from "zod";
import { requireSupabaseAuth } from "@/integrations/supabase/auth-middleware";
import { lifecycleAcceptanceEnabled } from "./lifecycle-acceptance-gate";
import { verifySalesStructuredDocxObject } from "./structured-lifecycle-docx-sales-orchestration.server";

const inputSchema = z.object({ projectId: z.string().uuid(), documentKind: z.enum(["SOR", "NDA", "COMMERCIAL_QUOTATION", "CONTRACT_REVIEW", "PRS", "BOM", "DFMEA", "MANUFACTURING_CONTROL_PLAN", "DVPR", "PDI", "COMMERCIAL_TAX_INVOICE", "ANNUAL_SKILL_MATRIX"]), assignmentId: z.string().uuid(), requestKey: z.string().uuid(), templateKey: z.string().min(1), templateVersion: z.number().int().positive(), templateSchemaHash: z.string().regex(/^[a-f0-9]{64}$/i), sourceFingerprint: z.string().regex(/^[a-f0-9]{64}$/i) });

/** Deployment-gated trusted server verifier. It has no browser/admin transport. */
export const verifyPrivateStructuredDocxObject = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((data) => inputSchema.parse(data))
  .handler(async ({ context, data }) => {
    if (!context.userId) throw new Error("Unauthorized");
    if (!lifecycleAcceptanceEnabled(process.env["SUPABASE_URL"], process.env["LIFECYCLE_DOCUMENT_ACCEPTANCE"])) {
      throw new Error("Verified DOCX Save is unavailable pending reviewed deployment acceptance.");
    }
    const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
    return verifySalesStructuredDocxObject(supabaseAdmin as never, context.userId, data);
  });