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

export const procurementReviewContractState = {
  deployed: false,
  submitDisabledReason:
    "The protected Procurement request and review contract is prepared for review but is not deployed. This local draft cannot submit or change BOM, inventory, sourcing, purchase order, stock, approval, or release records.",
} as const;

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