import { createServerFn } from "@tanstack/react-start";
import { z } from "zod";
import { requireSupabaseAuth } from "@/integrations/supabase/auth-middleware";
import { procurementReviewContractState, type ProcurementAnalysisState } from "./project-bom-procurement-review";

const uuid = z.string().uuid();
const analysisState = z.enum(["PENDING", "AVAILABLE", "UNAVAILABLE", "TBC"]);

export type ProcurementLineAnalysis = {
  id: string;
  revision: number;
  availabilityState: ProcurementAnalysisState;
  costState: ProcurementAnalysisState;
  sourcingState: ProcurementAnalysisState;
  observedUnitCost: number | null;
  currency: string | null;
  supplierName: string | null;
  leadTimeDays: number | null;
  alternateComponentId: string | null;
  analysisNote: string;
  analyzedAt: string;
};

export type ProcurementReviewLine = {
  id: string;
  lineNumber: number;
  sourceKind: "EXISTING_COMPONENT" | "NEW_PART";
  sourceBomItemId: string | null;
  componentId: string | null;
  mpn: string;
  manufacturer: string | null;
  description: string;
  referenceDesignators: string;
  quantity: number;
  manualNote: string | null;
  analysis: ProcurementLineAnalysis | null;
};

export type ProcurementReviewRequest = {
  id: string;
  projectId: string;
  projectBomId: string;
  pinnedBomNumber: string;
  pinnedBomRevision: string | null;
  pinnedBomUpdatedAt: string;
  status: "PENDING_PROCUREMENT_ANALYSIS" | "ALLOWED_PENDING_HARDWARE_SELECTION" | "DENIED";
  submittedAt: string;
  lines: ProcurementReviewLine[];
};

export type ProcurementAnalysisInput = Omit<ProcurementLineAnalysis, "id" | "revision" | "analyzedAt">;
export type ProcurementReviewedAnalysisRevision = { requestLineId: string; analysisRevision: number };

function deploymentRequired() {
  if (!procurementReviewContractState.deployed) {
    throw new Error(procurementReviewContractState.submitDisabledReason);
  }
}

function numberOrNull(value: unknown) {
  return typeof value === "number" && Number.isFinite(value) ? value : null;
}

function parseReview(payload: unknown): ProcurementReviewRequest {
  const raw = z.object({
    id: uuid,
    projectId: uuid,
    projectBomId: uuid,
    pinnedBomNumber: z.string(),
    pinnedBomRevision: z.string().nullable(),
    pinnedBomUpdatedAt: z.string(),
    status: z.enum(["PENDING_PROCUREMENT_ANALYSIS", "ALLOWED_PENDING_HARDWARE_SELECTION", "DENIED"]),
    submittedAt: z.string(),
    lines: z.array(z.object({
      id: uuid,
      lineNumber: z.number().int().positive(),
      sourceKind: z.enum(["EXISTING_COMPONENT", "NEW_PART"]),
      sourceBomItemId: uuid.nullable(),
      componentId: uuid.nullable(),
      mpn: z.string(),
      manufacturer: z.string().nullable(),
      description: z.string(),
      referenceDesignators: z.string(),
      quantity: z.union([z.number(), z.string()]),
      manualNote: z.string().nullable(),
      analysis: z.object({
        id: uuid,
        revision: z.number().int().positive(),
        availabilityState: analysisState,
        costState: analysisState,
        sourcingState: analysisState,
        observedUnitCost: z.union([z.number(), z.string()]).nullable(),
        currency: z.string().nullable(),
        supplierName: z.string().nullable(),
        leadTimeDays: z.union([z.number(), z.string()]).nullable(),
        alternateComponentId: uuid.nullable(),
        analysisNote: z.string(),
        analyzedAt: z.string(),
      }).nullable(),
    })),
  }).parse(payload);

  return {
    ...raw,
    lines: raw.lines.map((line) => ({
      ...line,
      quantity: Number(line.quantity),
      analysis: line.analysis ? {
        ...line.analysis,
        observedUnitCost: numberOrNull(line.analysis.observedUnitCost === null ? null : Number(line.analysis.observedUnitCost)),
        leadTimeDays: numberOrNull(line.analysis.leadTimeDays === null ? null : Number(line.analysis.leadTimeDays)),
      } : null,
    })),
  };
}

const analysisInputSchema = z.object({
  availabilityState: analysisState,
  costState: analysisState,
  sourcingState: analysisState,
  observedUnitCost: z.number().finite().nonnegative().nullable(),
  currency: z.string().trim().max(12).nullable(),
  supplierName: z.string().trim().max(500).nullable(),
  leadTimeDays: z.number().int().nonnegative().nullable(),
  alternateComponentId: uuid.nullable(),
  analysisNote: z.string().trim().min(1).max(1000),
});

export const readProjectBomProcurementReview = createServerFn({ method: "GET" })
  .middleware([requireSupabaseAuth])
  .inputValidator((data) => z.object({ requestId: uuid }).parse(data))
  .handler(async ({ data, context }) => {
    deploymentRequired();
    const { data: result, error } = await (context.supabase as any).rpc("read_project_bom_procurement_review", {
      p_request_id: data.requestId,
    });
    if (error) throw new Error(error.message);
    return parseReview(result);
  });

export const analyzeProjectBomProcurementReview = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((data) => z.object({
    requestId: uuid,
    requestLineId: uuid,
    expectedAnalysisRevision: z.number().int().nonnegative(),
    analysis: analysisInputSchema,
    requestKey: uuid,
  }).parse(data))
  .handler(async ({ data, context }) => {
    deploymentRequired();
    const { data: result, error } = await (context.supabase as any).rpc("analyze_project_bom_procurement_review", {
      p_request_id: data.requestId,
      p_request_line_id: data.requestLineId,
      p_expected_analysis_revision: data.expectedAnalysisRevision,
      p_analysis: data.analysis,
      p_request_key: data.requestKey,
    });
    if (error) throw new Error(error.message);
    return z.array(z.object({ analysis_id: uuid, analysis_revision: z.number().int().positive(), replayed: z.boolean() })).min(1).parse(result)[0];
  });

export const decideProjectBomProcurementReview = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((data) => z.object({
    requestId: uuid,
    expectedBomRevision: z.string().min(1).max(200),
    expectedBomUpdatedAt: z.string().datetime({ offset: true }),
    reviewedAnalysisRevisions: z.array(z.object({ requestLineId: uuid, analysisRevision: z.number().int().positive() })).max(500),
    decision: z.enum(["ALLOW", "DENY"]),
    decisionNote: z.string().trim().min(1).max(500),
    requestKey: uuid,
  }).parse(data))
  .handler(async ({ data, context }) => {
    deploymentRequired();
    const { data: result, error } = await (context.supabase as any).rpc("decide_project_bom_procurement_review", {
      p_request_id: data.requestId,
      p_expected_bom_revision: data.expectedBomRevision,
      p_expected_bom_updated_at: data.expectedBomUpdatedAt,
      p_reviewed_analysis_revisions: data.reviewedAnalysisRevisions,
      p_decision: data.decision,
      p_decision_note: data.decisionNote,
      p_request_key: data.requestKey,
    });
    if (error) throw new Error(error.message);
    return z.array(z.object({ request_id: uuid, replayed: z.boolean() })).min(1).parse(result)[0];
  });