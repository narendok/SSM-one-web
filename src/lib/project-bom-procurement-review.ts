export type ProposedBomPart = {
  lineId: string;
  reference: string;
  quantity: string;
  manualNote: string;
  kind: "existing" | "new";
  componentId: string;
  mpn: string;
  manufacturer: string;
  description: string;
};

export type ProcurementAnalysisState = "PENDING" | "AVAILABLE" | "UNAVAILABLE" | "TBC";

export type ProcurementReviewDecision = "ALLOW_FOR_HARDWARE_SELECTION" | "DENY";

export type ProcurementReviewSubmission = {
  projectId: string;
  projectBomId: string;
  expectedBomRevision: string | null;
  requestKey: string;
  rows: Array<{
    kind: "existing" | "new";
    sourceBomItemId?: string;
    componentId?: string;
    mpn?: string;
    manufacturer?: string;
    description?: string;
    referenceDesignators: string;
    quantity: number;
    manualNote?: string;
  }>;
};

export const procurementReviewContractState = {
  deployed: false,
  submitDisabledReason:
    "The protected Procurement request and review contract is prepared for review but is not deployed. This local draft cannot submit or change BOM, inventory, sourcing, purchase order, stock, approval, or release records.",
} as const;

export function procurementSubmissionAdapter(input: {
  projectId: string;
  projectBomId: string;
  expectedBomRevision: string | null;
  requestKey: string;
  rows: ProposedBomPart[];
}): ProcurementReviewSubmission | null {
  const rows = reviewableBomRows(input.rows);
  if (!input.projectId || !input.projectBomId || !input.expectedBomRevision || !input.requestKey || rows.length !== input.rows.length) return null;
  const adapted = rows.map((row) => {
    const quantity = Number(row.quantity);
    if (!Number.isFinite(quantity) || quantity <= 0) return null;
    if (row.kind === "existing") {
      return {
        kind: "existing" as const,
        sourceBomItemId: row.lineId || undefined,
        componentId: row.componentId,
        referenceDesignators: row.reference.trim(),
        quantity,
        manualNote: row.manualNote.trim() || undefined,
      };
    }
    return {
      kind: "new" as const,
      mpn: row.mpn.trim(),
      manufacturer: row.manufacturer.trim() || undefined,
      description: row.description.trim(),
      referenceDesignators: row.reference.trim(),
      quantity,
      manualNote: row.manualNote.trim() || undefined,
    };
  });
  return adapted.every(Boolean)
    ? { projectId: input.projectId, projectBomId: input.projectBomId, expectedBomRevision: input.expectedBomRevision, requestKey: input.requestKey, rows: adapted as ProcurementReviewSubmission["rows"] }
    : null;
}

export function reviewableBomRows(rows: ProposedBomPart[]) {
  return rows.filter((row) => {
    if (!row.reference.trim() || !row.quantity.trim()) return false;
    if (row.kind === "existing") return Boolean(row.componentId);
    return Boolean(row.mpn.trim() && row.description.trim());
  });
}

export function analysisLabel(state: ProcurementAnalysisState) {
  if (state === "AVAILABLE") return "Available";
  if (state === "UNAVAILABLE") return "Unavailable";
  if (state === "TBC") return "TBC";
  return "Pending analysis";
}

export function reviewDecisionLabel(decision: ProcurementReviewDecision) {
  return decision === "ALLOW_FOR_HARDWARE_SELECTION"
    ? "Allow for Hardware selection"
    : "Deny for Procurement reasons";
}