import { createServerFn } from "@tanstack/react-start";
import { z } from "zod";
import { requireSupabaseAuth } from "@/integrations/supabase/auth-middleware";
import { lifecycleAcceptanceEnabled } from "./lifecycle-acceptance-gate";
import { authorizeSalesStructuredDocxUpload, DOCX_MIME, verifySalesStructuredDocxObject, commitVerifiedSalesStructuredDocx } from "./structured-lifecycle-docx-sales-orchestration.server";

const inputSchema = z.object({ opportunityId: z.string().uuid(), customerId: z.string().uuid(), documentKind: z.enum(["SOR", "NDA", "COMMERCIAL_QUOTATION", "CONTRACT_REVIEW", "PRS", "BOM", "DFMEA", "MANUFACTURING_CONTROL_PLAN", "DVPR", "PDI", "COMMERCIAL_TAX_INVOICE", "ANNUAL_SKILL_MATRIX"]), assignmentId: z.string().uuid(), requestKey: z.string().uuid(), templateKey: z.string().min(1), templateVersion: z.number().int().positive(), templateSchemaHash: z.string().regex(/^[a-f0-9]{64}$/i), sourceFingerprint: z.string().regex(/^[a-f0-9]{64}$/i) });

const uploadAuthorizationSchema = z.object({
  opportunityId: z.string().uuid(), customerId: z.string().uuid(), assignmentId: z.string().uuid(), requestKey: z.string().uuid(),
  contentType: z.literal(DOCX_MIME), sizeBytes: z.number().int().positive().max(10 * 1024 * 1024),
});

/** Deployment-gated authority for one exact DOCX upload path; it never uploads browser bytes itself. */
export const authorizePrivateStructuredDocxUpload = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((data) => uploadAuthorizationSchema.parse(data))
  .handler(async ({ context, data }) => {
    if (!context.userId) throw new Error("Unauthorized");
    if (!lifecycleAcceptanceEnabled(process.env["SUPABASE_URL"], process.env["LIFECYCLE_DOCUMENT_ACCEPTANCE"])) {
      throw new Error("Verified DOCX Save is unavailable pending reviewed deployment acceptance.");
    }
    const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
    return authorizeSalesStructuredDocxUpload(supabaseAdmin as never, context.userId, data);
  });

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

const commitSchema = z.object({
  opportunityId: z.string().uuid(),
  customerId: z.string().uuid(),
  fileName: z.string().min(1).max(255),
  receipt: z.object({
    receiptId: z.string().uuid(), actorId: z.string().uuid(), assignmentId: z.string().uuid(), requestKey: z.string().uuid(),
    scopeType: z.enum(["SALES_OPPORTUNITY", "PROJECT"]), opportunityId: z.string().uuid(), customerId: z.string().uuid(), projectId: z.string().uuid().nullable(), documentKind: z.enum(["SOR", "CONTRACT_REVIEW"]), departmentId: z.string().uuid(),
    templateId: z.string().uuid(), templateDocumentRevisionId: z.string().uuid(), templateKey: z.string().min(1),
    templateVersion: z.number().int().positive(), templateSchemaHash: z.string().regex(/^[a-f0-9]{64}$/i),
    sourceFingerprint: z.string().regex(/^[a-f0-9]{64}$/i), storageBucket: z.literal("project-drive"), storagePath: z.string().min(1),
    objectVersion: z.string().min(1), sha256Checksum: z.string().regex(/^[a-f0-9]{64}$/i), sizeBytes: z.number().int().positive(),
    paragraphs: z.number().int().nonnegative(), tables: z.number().int().nonnegative(), responsibleEmployeeId: z.string().uuid(), reviewerEmployeeId: z.string().uuid().nullable(),
  }),
});

/** Deployment-gated server-side commit. Browser values cannot mint or alter a receipt. */
export const commitPrivateStructuredDocxMaterialization = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((data) => commitSchema.parse(data))
  .handler(async ({ context, data }) => {
    if (!context.userId) throw new Error("Unauthorized");
    if (data.receipt.actorId !== context.userId) throw new Error("DOCX receipt actor does not match the authenticated caller.");
    if (!lifecycleAcceptanceEnabled(process.env["SUPABASE_URL"], process.env["LIFECYCLE_DOCUMENT_ACCEPTANCE"])) {
      throw new Error("Verified DOCX Save is unavailable pending reviewed deployment acceptance.");
    }
    const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
    return commitVerifiedSalesStructuredDocx(supabaseAdmin as never, context.userId, data.receipt, data);
  });
