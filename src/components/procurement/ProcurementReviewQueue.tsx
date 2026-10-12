import { ClipboardCheck, LockKeyhole } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { analysisLabel, procurementReviewContractState, reviewDecisionLabel, type ProcurementAnalysisState } from "@/lib/project-bom-procurement-review";

export type ProcurementReviewQueueRow = {
  request: string;
  project: string;
  bomRevision: string;
  submitted: string;
  availability: ProcurementAnalysisState;
  cost: ProcurementAnalysisState;
  sourcing: ProcurementAnalysisState;
};

function analysisVariant(state: ProcurementAnalysisState) {
  if (state === "AVAILABLE") return "secondary" as const;
  if (state === "UNAVAILABLE") return "destructive" as const;
  return "outline" as const;
}

/** Read-only presentation for the uninstalled, protected Procurement-review contract. */
export function ProcurementReviewQueue({ rows = [] }: { rows?: ProcurementReviewQueueRow[] }) {
  return <Card className="p-4">
    <div className="flex flex-wrap items-start justify-between gap-3">
      <div>
        <h2 className="font-semibold">Procurement review queue</h2>
        <p className="mt-1 text-sm text-muted-foreground">Source-pinned BOM requests appear here only after the protected request contract is separately accepted and deployed.</p>
      </div>
      <LockKeyhole className="size-5 text-muted-foreground" aria-hidden="true" />
    </div>

    {!procurementReviewContractState.deployed && <div role="status" className="mt-4 flex gap-2 border border-warning/40 bg-warning/10 px-3 py-2 text-sm text-muted-foreground"><ClipboardCheck className="mt-0.5 size-4 shrink-0 text-warning" aria-hidden="true" /><span>{procurementReviewContractState.submitDisabledReason}</span></div>}

    {rows.length === 0 ? <p className="mt-4 text-sm text-muted-foreground">No review requests are loaded. The unaccepted contract is not queried and no queue, analysis, decision, order, stock, or release record is created.</p> : <div className="mt-4 overflow-x-auto border"><table className="w-full text-left text-sm"><thead className="bg-muted/50 text-xs text-muted-foreground"><tr><th className="px-3 py-2 font-medium">Request</th><th className="px-3 py-2 font-medium">Project / BOM pin</th><th className="px-3 py-2 font-medium">Availability</th><th className="px-3 py-2 font-medium">Cost</th><th className="px-3 py-2 font-medium">Sourcing</th><th className="px-3 py-2 font-medium">Action</th></tr></thead><tbody>{rows.map((row) => <tr key={row.request} className="border-t"><td className="px-3 py-3 font-mono text-xs">{row.request}<span className="mt-1 block font-sans text-muted-foreground">{row.submitted}</span></td><td className="px-3 py-3"><span className="block font-medium">{row.project}</span><span className="text-xs text-muted-foreground">{row.bomRevision}</span></td><td className="px-3 py-3"><Badge variant={analysisVariant(row.availability)}>{analysisLabel(row.availability)}</Badge></td><td className="px-3 py-3"><Badge variant={analysisVariant(row.cost)}>{analysisLabel(row.cost)}</Badge></td><td className="px-3 py-3"><Badge variant={analysisVariant(row.sourcing)}>{analysisLabel(row.sourcing)}</Badge></td><td className="px-3 py-3"><Button type="button" size="sm" variant="outline" disabled title="Requires the separately accepted protected Procurement contract">{reviewDecisionLabel("ALLOW_FOR_HARDWARE_SELECTION")}</Button></td></tr>)}</tbody></table></div>}
  </Card>;
}