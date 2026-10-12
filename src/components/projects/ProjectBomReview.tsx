import { useEffect, useMemo, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { AlertTriangle, ClipboardCheck, Plus, Search, ShieldAlert } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { procurementReviewContractState, reviewableBomRows, type ProposedBomPart } from "@/lib/project-bom-procurement-review";
import type { Project } from "@/lib/projects";
import { fetchProjectBoms, type ProjectBomSummary } from "@/lib/project-bom.functions";
import { supabase } from "@/integrations/supabase/client";
import { ProcurementReviewQueue } from "@/components/procurement/ProcurementReviewQueue";

type CatalogPart = { id: string; name: string; part_number: string; manufacturer: string | null };
type ReviewRow = ProposedBomPart & {
  id: string;
};

export const projectBomReviewContractState = {
  protectedRequestReviewContract: procurementReviewContractState.deployed,
  submitDisabledReason: procurementReviewContractState.submitDisabledReason,
} as const;

function newReviewRow(): ReviewRow {
  const id = crypto.randomUUID();
  return { id, localRowId: id, reference: "", quantity: "", manualNote: "", kind: "existing", componentId: "", mpn: "", manufacturer: "", description: "" };
}

function formatBomPin(bom: ProjectBomSummary | undefined) {
  if (!bom) return "No visible saved BOM revision";
  return `${bom.bom_number} · revision ${bom.revision ?? "TBC"}`;
}

export function ProjectBomReview({ project }: { project: Project }) {
  const [rows, setRows] = useState<ReviewRow[]>(() => [newReviewRow()]);
  const [query, setQuery] = useState("");
  const bomsQuery = useQuery({ queryKey: ["project-bom-review-pins", project.id], queryFn: () => fetchProjectBoms({ data: { projectId: project.id } }) });
  const catalogQuery = useQuery({
    queryKey: ["project-bom-review-catalog"],
    queryFn: async (): Promise<CatalogPart[]> => {
      const { data, error } = await supabase.from("components").select("id, name, part_number, manufacturer").order("part_number").limit(100);
      if (error) throw error;
      return (data ?? []) as CatalogPart[];
    },
  });
  const pinnedBom = bomsQuery.data?.[0];
  const completeRows = reviewableBomRows(rows);
  const filteredCatalog = useMemo(() => {
    const normalized = query.trim().toLowerCase();
    if (!normalized) return catalogQuery.data ?? [];
    return (catalogQuery.data ?? []).filter((part) => [part.part_number, part.name, part.manufacturer].filter(Boolean).some((value) => value!.toLowerCase().includes(normalized)));
  }, [catalogQuery.data, query]);

  useEffect(() => {
    setRows((current) => current.map((row) => ({ ...row, componentId: row.componentId })));
  }, [project.id]);

  const updateRow = (id: string, patch: Partial<ReviewRow>) => setRows((current) => current.map((row) => row.id === id ? { ...row, ...patch } : row));
  const choosePart = (id: string, part: CatalogPart) => updateRow(id, { kind: "existing", componentId: part.id, mpn: part.part_number, manufacturer: part.manufacturer ?? "", description: part.name });
  const switchKind = (id: string, kind: ReviewRow["kind"]) => updateRow(id, kind === "new" ? { kind, componentId: "" } : { kind, mpn: "", manufacturer: "", description: "" });

  return <div className="space-y-4">
    <Card className="p-4">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <h2 className="font-semibold">Tentative BOM & parts review</h2>
          <p className="mt-1 text-sm text-muted-foreground">Local working rows for this project only. This is not an approval, released BOM, purchase request, or stock action.</p>
        </div>
        <ClipboardCheck className="size-5 text-muted-foreground" aria-hidden="true" />
      </div>
      <dl className="mt-4 grid gap-3 text-sm sm:grid-cols-3">
        <div><dt className="text-xs text-muted-foreground">Project</dt><dd className="mt-1 font-medium">{project.code} · {project.name}</dd></div>
        <div><dt className="text-xs text-muted-foreground">Project revision</dt><dd className="mt-1 font-medium">{project.revision ?? "TBC"}</dd></div>
        <div><dt className="text-xs text-muted-foreground">Current saved BOM</dt><dd className="mt-1 font-medium">{bomsQuery.isLoading ? "Checking visible revisions…" : bomsQuery.isError ? "Unavailable — not assumed" : formatBomPin(pinnedBom)}</dd></div>
      </dl>
    </Card>

    <Card className="border-warning/40 p-4">
      <div className="flex gap-3"><ShieldAlert className="mt-0.5 size-5 text-warning" aria-hidden="true" /><div><p className="font-medium">Procurement review contract awaiting activation</p><p className="mt-1 text-sm text-muted-foreground">{projectBomReviewContractState.submitDisabledReason}</p><p className="mt-2 text-xs text-muted-foreground">The planned review records MPN, availability, cost, sourcing, lead time, and alternates. A reviewer can allow a handoff for Hardware selection or deny it; neither action approves a part, releases a BOM, orders material, or changes stock. Unknown values remain TBC.</p></div></div>
    </Card>

    <ProcurementReviewQueue />

    <Card className="p-4">
      <div className="flex flex-wrap items-center justify-between gap-3"><div><h3 className="font-medium">Tentative rows</h3><p className="mt-1 text-sm text-muted-foreground">Existing catalog parts retain their authoritative ID, MPN, and manufacturer. New parts remain pending Procurement review.</p></div><Button type="button" variant="outline" size="sm" onClick={() => setRows((current) => [...current, newReviewRow()])}><Plus className="size-4" /> Add row</Button></div>
      <div className="mt-4 space-y-4">
        {rows.map((row, index) => <section key={row.id} className="border-t pt-4 first:border-t-0 first:pt-0">
          <div className="grid gap-3 lg:grid-cols-[0.8fr_0.8fr_1.4fr]">
            <label className="text-sm">Reference<Input value={row.reference} onChange={(event) => updateRow(row.id, { reference: event.target.value })} placeholder="e.g. R12" /></label>
            <label className="text-sm">Quantity<Input inputMode="numeric" value={row.quantity} onChange={(event) => updateRow(row.id, { quantity: event.target.value })} placeholder="Manual quantity" /></label>
            <label className="text-sm">Manual note<Input value={row.manualNote} onChange={(event) => updateRow(row.id, { manualNote: event.target.value })} placeholder="Preserved locally" /></label>
          </div>
          <div className="mt-3 flex flex-wrap gap-2"><Button type="button" size="sm" variant={row.kind === "existing" ? "default" : "outline"} onClick={() => switchKind(row.id, "existing")}>Select existing part</Button><Button type="button" size="sm" variant={row.kind === "new" ? "default" : "outline"} onClick={() => switchKind(row.id, "new")}>Add new part</Button><span className="self-center text-xs text-muted-foreground">Row {index + 1} · {row.kind === "new" ? "Pending Procurement review" : row.sourceBomItemId ? "Pinned saved BOM item" : row.componentId ? "Authoritative catalog selection" : "No part selected"}</span></div>
          {row.kind === "existing" ? <div className="mt-3"><label className="relative block text-sm">Find existing catalog part<Search className="absolute bottom-2.5 left-2.5 size-4 text-muted-foreground" aria-hidden="true" /><Input className="pl-8" value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search MPN, manufacturer, or name" /></label><div className="mt-2 max-h-40 overflow-auto border"><button type="button" className="w-full px-3 py-2 text-left text-sm text-muted-foreground hover:bg-accent" onClick={() => updateRow(row.id, { componentId: "", mpn: "", manufacturer: "", description: "" })}>No selection</button>{catalogQuery.isLoading ? <p className="px-3 py-2 text-sm text-muted-foreground">Loading authorized catalog…</p> : catalogQuery.isError ? <p className="px-3 py-2 text-sm text-destructive">Catalog unavailable; no component is assumed.</p> : filteredCatalog.length ? filteredCatalog.map((part) => <button type="button" key={part.id} className="block w-full border-t px-3 py-2 text-left text-sm hover:bg-accent" onClick={() => choosePart(row.id, part)}><span className="font-mono">{part.part_number}</span><span className="ml-2">{part.name}</span><span className="ml-2 text-muted-foreground">{part.manufacturer ?? "Manufacturer TBC"}</span></button>) : <p className="px-3 py-2 text-sm text-muted-foreground">No matching authorized catalog component.</p>}</div>{row.componentId && <p className="mt-2 text-xs text-muted-foreground">Selected ID: {row.componentId} · {row.mpn} · {row.manufacturer || "Manufacturer TBC"}</p>}</div> : <div className="mt-3 grid gap-3 md:grid-cols-3"><label className="text-sm">MPN<Input value={row.mpn} onChange={(event) => updateRow(row.id, { mpn: event.target.value })} placeholder="Proposed MPN" /></label><label className="text-sm">Manufacturer<Input value={row.manufacturer} onChange={(event) => updateRow(row.id, { manufacturer: event.target.value })} placeholder="Proposed manufacturer" /></label><label className="text-sm">Description<Input value={row.description} onChange={(event) => updateRow(row.id, { description: event.target.value })} placeholder="Proposed part description" /></label></div>}
        </section>)}
      </div>
      <label className="mt-4 block text-sm">Review context<Textarea placeholder="Manual design rationale or procurement questions; retained only in this local draft." /></label>
       <div className="mt-4 flex flex-wrap items-center gap-3"><Button type="button" disabled>Submit for Procurement review</Button><span className="flex items-center gap-1 text-sm text-muted-foreground"><AlertTriangle className="size-4" /> {completeRows.length} complete tentative row{completeRows.length === 1 ? "" : "s"}; submission remains unavailable until the protected contract is deployed and accepted.</span></div>
    </Card>
  </div>;
}