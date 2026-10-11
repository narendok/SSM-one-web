import { createServerFn } from "@tanstack/react-start";
import { z } from "zod";
import { requireSupabaseAuth } from "@/integrations/supabase/auth-middleware";
import { createPendingVersionedPrivateDocxReader } from "./structured-lifecycle-docx-private-object-reader.server";

const inputSchema = z.object({ projectId: z.string().uuid(), documentKind: z.enum(["SOR", "NDA", "COMMERCIAL_QUOTATION", "CONTRACT_REVIEW", "PRS", "BOM", "DFMEA", "MANUFACTURING_CONTROL_PLAN", "DVPR", "PDI", "COMMERCIAL_TAX_INVOICE", "ANNUAL_SKILL_MATRIX"]), assignmentId: z.string().uuid(), requestKey: z.string().uuid(), templateKey: z.string().min(1), templateVersion: z.number().int().positive(), templateSchemaHash: z.string().regex(/^[a-f0-9]{64}$/i), sourceFingerprint: z.string().regex(/^[a-f0-9]{64}$/i) });

/** Deliberately inactive until immutable private-object reading and protected receipt authority are accepted. */
export const verifyPrivateStructuredDocxObject = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((data) => inputSchema.parse(data))
  .handler(async ({ context }) => {
    if (!context.userId) throw new Error("Unauthorized");
    const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
    // Inspect the exact immutable metadata only; the reader fails closed because the
    // current storage SDK cannot fetch bytes by immutable object version.
    void createPendingVersionedPrivateDocxReader(supabaseAdmin);
    throw new Error("Private DOCX verification is unavailable until immutable object-version byte reading and protected registry receipt authority are accepted.");
  });