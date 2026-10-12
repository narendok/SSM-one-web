import { useState } from "react";
import { ClipboardCheck, LockKeyhole } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { analysisLabel, procurementAnalysisPayload, procurementReviewContractState, reviewDecisionLabel, type ProcurementAnalysisDraft, type ProcurementAnalysisState } from "@/lib/project-bom-procurement-review";
import type { ProcurementReviewRequest } from "@/lib/project-bom-procurement-review.functions";

export type ProcurementReviewQueueRow = {
  request: string;
  project: string;
  bomRevision: string;
  submitted: string;
  availability: ProcurementAnalysisState;
  cost: ProcurementAnalysisState;
  sourcing: ProcurementAnalysisState;
};

const analysisStates: ProcurementAnalysisState[] = ["PENDING", "AVAILABLE", "UNAVAILABLE", "TBC"];
const emptyDraft: ProcurementAnalysisDraft = { availabilityState: "PENDING", costState: "PENDING", sourcingState: "PENDING", observedUnitCost: "", currency: "", supplierName: "", leadTimeDays: "", alternateComponentId: "", analysisNote: "" };

function analysisVariant(state: ProcurementAnalysisState) {
  if (state === "AVAILABLE") return "secondary" as const;
  if (state === "UNAVAILABLE") return "destructive" as const;
  return "outline" as const;
}

function AnalysisStateSelect({ label, value, onChange, disabled }: { label: string; value: ProcurementAnalysisState; onChange: (value: ProcurementAnalysisState) => void; disabled: boolean }) {
  return <label className="grid gap-1 text-sm"><span>{label}</span><Select value={value} onValueChange={(next) => onChange(next as ProcurementAnalysisState)} disabled={disabled}><SelectTrigger><SelectValue /></SelectTrigger><SelectContent>{analysisStates.map((state) => <SelectItem key={state} value={state}>{analysisLabel(state)}</SelectItem>)}</SelectContent></Select></label>;
}

export function ProcurementReviewQueue({ rows = [], review }: { rows?: ProcurementReviewQueueRow[]; review?: ProcurementReviewRequest }) {
  const [drafts, setDrafts] = useState<Record<string, ProcurementAnalysisDraft>>({});
  const [decisionNote, setDecisionNote] = useState("");
  const disabled = !procurementReviewContractState.deployed;
  const updateDraft = (lineId: string, patch: Partial<ProcurementAnalysisDraft>) => setDrafts((current) => ({ ...current, [lineId]: { ...(current[lineId] ?? emptyDraft), ...patch } }));
  return <Card className="p-4">
    <div className="flex flex-wrap items-start justify-between gap-3">
      <div>
        <h2 className="font-semibold">Procurement review queue</h2>
        <p className="mt-1 text-sm text-muted-foreground">Source-pinned BOM requests appear here only after the protected request contract is separately accepted and deployed.</p>
      </div>
      <LockKeyhole className="size-5 text-muted-foreground" aria-hidden="true" />
    </div>

    {!procurementReviewContractState.deployed && <div role="status" className="mt-4 flex gap-2 border border-warning/40 bg-warning/10 px-3 py-2 text-sm text-muted-foreground"><ClipboardCheck className="mt-0.5 size-4 shrink-0 text-warning" aria-hidden="true" /><span>{procurementReviewContractState.submitDisabledReason}</span></div>}

    {review ? <div className="mt-4 space-y-4"><div className="grid gap-3 border p-3 text-sm sm:grid-cols-3"><div><p className="text-xs text-muted-foreground">Immutable request</p><p className="mt-1 font-mono text-xs">{review.id}</p></div><div><p className="text-xs text-muted-foreground">Pinned BOM</p><p className="mt-1 font-medium">{review.pinnedBomNumber} · revision {review.pinnedBomRevision ?? "TBC"}</p></div><div><p className="text-xs text-muted-foreground">Status</p><p className="mt-1 font-medium">{review.status.replaceAll("_", " ")}</p></div></div>{review.lines.map((line) => { const draft = drafts[line.id] ?? emptyDraft; const payload = procurementAnalysisPayload(draft); return <section className="border p-3" key={line.id}><div className="flex flex-wrap items-start justify-between gap-3"><div><p className="font-medium">Line {line.lineNumber} · {line.mpn}</p><p className="mt-1 text-sm text-muted-foreground">{line.description} · {line.referenceDesignators} · qty {line.quantity}</p><p className="mt-1 text-xs text-muted-foreground">{line.sourceKind === "EXISTING_COMPONENT" ? `Pinned catalog component${line.sourceBomItemId ? " from saved BOM item" : ""}` : "New-part proposal — no component has been created"}</p></div>{line.analysis && <div className="flex gap-2"><Badge variant={analysisVariant(line.analysis.availabilityState)}>{analysisLabel(line.analysis.availabilityState)}</Badge><Badge variant={analysisVariant(line.analysis.costState)}>{analysisLabel(line.analysis.costState)}</Badge><Badge variant={analysisVariant(line.analysis.sourcingState)}>{analysisLabel(line.analysis.sourcingState)}</Badge></div>}</div><div className="mt-4 grid gap-3 md:grid-cols-3"><AnalysisStateSelect label="Availability" value={draft.availabilityState} onChange={(availabilityState) => updateDraft(line.id, { availabilityState })} disabled={disabled} /><AnalysisStateSelect label="Cost" value={draft.costState} onChange={(costState) => updateDraft(line.id, { costState })} disabled={disabled} /><AnalysisStateSelect label="Sourcing" value={draft.sourcingState} onChange={(sourcingState) => updateDraft(line.id, { sourcingState })} disabled={disabled} /><label className="grid gap-1 text-sm">Observed unit cost<Input inputMode="decimal" value={draft.observedUnitCost} disabled={disabled} onChange={(event) => updateDraft(line.id, { observedUnitCost: event.target.value })} placeholder="TBC" /></label><label className="grid gap-1 text-sm">Currency<Input value={draft.currency} disabled={disabled} onChange={(event) => updateDraft(line.id, { currency: event.target.value })} placeholder="TBC" /></label><label className="grid gap-1 text-sm">Lead time (days)<Input inputMode="numeric" value={draft.leadTimeDays} disabled={disabled} onChange={(event) => updateDraft(line.id, { leadTimeDays: event.target.value })} placeholder="TBC" /></label><label className="grid gap-1 text-sm md:col-span-2">Supplier / source<Input value={draft.supplierName} disabled={disabled} onChange={(event) => updateDraft(line.id, { supplierName: event.target.value })} placeholder="TBC" /></label><label className="grid gap-1 text-sm">Alternate component ID<Input value={draft.alternateComponentId} disabled={disabled} onChange={(event) => updateDraft(line.id, { alternateComponentId: event.target.value })} placeholder="Optional exact catalog ID" /></label></div><label className="mt-3 grid gap-1 text-sm">Analysis note<Textarea value={draft.analysisNote} disabled={disabled} onChange={(event) => updateDraft(line.id, { analysisNote: event.target.value })} placeholder="Current source, constraint, or follow-up" /></label><div className="mt-3 flex flex-wrap items-center gap-3"><Button type="button" size="sm" disabled title="Requires the separately accepted protected Procurement contract">Record analysis</Button><span className="text-xs text-muted-foreground">{payload ? "Draft is structurally ready; protected validation remains server-owned." : "Add a valid note and non-negative numeric values where supplied."}</span></div></section>; })}<section className="border p-3"><label className="grid gap-1 text-sm">Decision rationale<Textarea value={decisionNote} disabled={disabled} onChange={(event) => setDecisionNote(event.target.value)} placeholder="Required by the protected decision contract" /></label><div className="mt-3 flex flex-wrap gap-2"><Button type="button" disabled title="Requires the separately accepted protected Procurement contract">{reviewDecisionLabel("ALLOW_FOR_HARDWARE_SELECTION")}</Button><Button type="button" variant="destructive" disabled title="Requires the separately accepted protected Procurement contract">{reviewDecisionLabel("DENY")}</Button><span className="self-center text-xs text-muted-foreground">An allow only hands off for Hardware selection; it does not release the BOM, approve a part, order material, or change stock.</span></div></section></div> : rows.length === 0 ? <p className="mt-4 text-sm text-muted-foreground">No review requests are loaded. The unaccepted contract is not queried and no queue, analysis, decision, order, stock, or release record is created.</p> : <div className="mt-4 overflow-x-auto border"><table className="w-full text-left text-sm"><thead className="bg-muted/50 text-xs text-muted-foreground"><tr><th className="px-3 py-2 font-medium">Request</th><th className="px-3 py-2 font-medium">Project / BOM pin</th><th className="px-3 py-2 font-medium">Availability</th><th className="px-3 py-2 font-medium">Cost</th><th className="px-3 py-2 font-medium">Sourcing</th><th className="px-3 py-2 font-medium">Action</th></tr></thead><tbody>{rows.map((row) => <tr key={row.request} className="border-t"><td className="px-3 py-3 font-mono text-xs">{row.request}<span className="mt-1 block font-sans text-muted-foreground">{row.submitted}</span></td><td className="px-3 py-3"><span className="block font-medium">{row.project}</span><span className="text-xs text-muted-foreground">{row.bomRevision}</span></td><td className="px-3 py-3"><Badge variant={analysisVariant(row.availability)}>{analysisLabel(row.availability)}</Badge></td><td className="px-3 py-3"><Badge variant={analysisVariant(row.cost)}>{analysisLabel(row.cost)}</Badge></td><td className="px-3 py-3"><Badge variant={analysisVariant(row.sourcing)}>{analysisLabel(row.sourcing)}</Badge></td><td className="px-3 py-3"><Button type="button" size="sm" variant="outline" disabled title="Requires the separately accepted protected Procurement contract">{reviewDecisionLabel("ALLOW_FOR_HARDWARE_SELECTION")}</Button></td></tr>)}</tbody></table></div>}
  </Card>;
}