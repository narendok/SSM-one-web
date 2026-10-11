import { useEffect, useMemo, useState } from "react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import { Plus, RefreshCw, Trash2 } from "lucide-react";
import { supabase } from "@/integrations/supabase/client";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";

const sb = supabase as any;

type EntityConfig = {
  table: string;
  queryKey: string;
  heading: string;
  empty: string;
  addLabel: string;
  codeLabel: string;
  codeKey: string;
  typeLabel: string;
  typeKey: string;
  descriptionLabel: string;
  descriptionKey: string;
  statusKey: string;
  options: string[];
};

const configs: Record<"design" | "research" | "registers" | "gates" | "issues" | "changes", EntityConfig> = {
  design: { table: "project_design_inputs", queryKey: "project_design_inputs", heading: "Design inputs", empty: "No controlled design inputs recorded.", addLabel: "Add input", codeLabel: "Input code", codeKey: "input_code", typeLabel: "Category", typeKey: "category", descriptionLabel: "Description", descriptionKey: "description", statusKey: "status", options: ["GENERAL", "CUSTOMER", "SAFETY", "REGULATORY", "PERFORMANCE"] },
  research: { table: "project_research_records", queryKey: "project_research_records", heading: "Research & POC", empty: "No research or proof-of-concept records yet.", addLabel: "Add record", codeLabel: "Title", codeKey: "title", typeLabel: "Research type", typeKey: "research_type", descriptionLabel: "Summary", descriptionKey: "summary", statusKey: "decision_status", options: ["TECHNICAL", "MARKET", "FEASIBILITY", "POC", "COMPONENT"] },
  registers: { table: "project_engineering_registers", queryKey: "project_engineering_registers", heading: "Engineering register", empty: "No controlled engineering records yet.", addLabel: "Add record", codeLabel: "Reference code", codeKey: "reference_code", typeLabel: "Register type", typeKey: "register_type", descriptionLabel: "Title", descriptionKey: "title", statusKey: "status", options: ["ARCHITECTURE", "DVP_R", "DFMEA", "DFM_DFA", "THERMAL", "EMC_ESD", "CERTIFICATION", "RELEASE"] },
  gates: { table: "project_stage_gates", queryKey: "project_stage_gates", heading: "Development gates", empty: "No product development or engineering gates have been planned.", addLabel: "Add gate", codeLabel: "Gate code", codeKey: "gate_code", typeLabel: "Gate type", typeKey: "gate_type", descriptionLabel: "Title", descriptionKey: "title", statusKey: "status", options: ["ENGINEERING_GATE", "APQP_PHASE", "EVT", "DVT", "PVT", "RELEASE"] },
  issues: { table: "project_issues", queryKey: "project_issues", heading: "Issues & corrective actions", empty: "No open engineering issues.", addLabel: "Log issue", codeLabel: "Issue code", codeKey: "issue_code", typeLabel: "Issue type", typeKey: "issue_type", descriptionLabel: "Title", descriptionKey: "title", statusKey: "status", options: ["ENGINEERING", "QUALITY", "SUPPLIER", "TEST", "RISK"] },
  changes: { table: "project_change_requests", queryKey: "project_change_requests", heading: "Engineering changes", empty: "No engineering change requests or notices.", addLabel: "Add change", codeLabel: "Change code", codeKey: "change_code", typeLabel: "Change type", typeKey: "change_type", descriptionLabel: "Title", descriptionKey: "title", statusKey: "status", options: ["ECR", "ECN", "DEVIATION", "WAIVER"] },
};

export function ProjectOperationalTab({ projectId, kind }: { projectId: string; kind: keyof typeof configs }) {
  const config = configs[kind];
  const qc = useQueryClient();
  const [open, setOpen] = useState(false);
  const { data: records = [], isLoading, isError, error, refetch } = useQuery({
    queryKey: [config.queryKey, projectId],
    queryFn: async () => {
      const { data, error } = await sb.from(config.table).select("*").eq("project_id", projectId).order("created_at", { ascending: false });
      if (error) throw error;
      return data ?? [];
    },
  });
  const refresh = () => void qc.invalidateQueries({ queryKey: [config.queryKey, projectId] });
  const remove = async (id: string) => {
    if (!confirm("Remove this record?")) return;
    const { error } = await sb.from(config.table).delete().eq("id", id);
    if (error) return toast.error(error.message);
    toast.success("Record removed");
    refresh();
  };
  const subtitle = useMemo(() => {
    if (isError) return records.length ? `${records.length} recorded · refresh failed` : "Records unavailable";
    return `${records.length} recorded`;
  }, [isError, records.length]);
  return <div className="space-y-4">
    <div className="flex flex-wrap items-center justify-between gap-2"><div><h2 className="text-base font-semibold">{config.heading}</h2><p className="text-sm text-muted-foreground">{subtitle}</p></div><Button onClick={() => setOpen(true)}><Plus className="h-4 w-4" />{config.addLabel}</Button></div>
    {isLoading ? <p className="text-sm text-muted-foreground">Loading…</p> : <>
      {isError && <Card role="alert" className="flex flex-wrap items-center justify-between gap-3 p-5 text-sm text-destructive"><span>These records could not be loaded. {error instanceof Error ? error.message : "Please try again."}</span><Button variant="outline" size="sm" onClick={() => void refetch()}>Retry</Button></Card>}
      {records.length === 0 && !isError ? <Card className="p-8 text-center text-sm text-muted-foreground">{config.empty}</Card> : records.length > 0 ? <div className="space-y-2">{records.map((record: any) => <Card key={record.id} className="p-4"><div className="flex gap-3"><div className="min-w-0 flex-1"><div className="flex flex-wrap items-center gap-2"><span className="font-medium">{record[config.descriptionKey]}</span>{record[config.codeKey] !== record[config.descriptionKey] && <span className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs">{record[config.codeKey]}</span>}<Badge variant="outline">{record[config.typeKey]}</Badge><Badge variant="secondary">{record[config.statusKey]}</Badge></div>{record.description && <p className="mt-1 text-sm text-muted-foreground">{record.description}</p>}{record.summary && <p className="mt-1 text-sm text-muted-foreground">{record.summary}</p>}{record.impact_summary && <p className="mt-1 text-sm text-muted-foreground">{record.impact_summary}</p>}{record.evidence_note && <p className="mt-1 text-sm text-muted-foreground">{record.evidence_note}</p>}</div><Button variant="ghost" size="icon" aria-label="Remove record" title="Remove record" onClick={() => remove(record.id)}><Trash2 className="h-4 w-4 text-destructive" /></Button></div></Card>)}</div> : null}
    </>}
    <OperationalDialog projectId={projectId} config={config} open={open} onOpenChange={setOpen} onSaved={refresh} />
  </div>;
}

type LinkedBaseline = {
  id: string;
  baseline_number: string;
  revision_number: number;
  status: string;
  approved_at: string | null;
  requirement: { id: string; requirement_number: string; title: string; current_revision: number } | null;
};

type ProjectHandover = {
  id: string;
  status: string;
  handover_notes: string | null;
  initiated_at: string | null;
  baseline_id: string;
};

export function ProjectRequirementContext({ projectId, baselineId }: { projectId: string; baselineId: string | null }) {
  const baselineQuery = useQuery({
    queryKey: ["project_requirement_baseline", projectId, baselineId],
    enabled: Boolean(baselineId),
    queryFn: async () => {
      const { data, error } = await sb
        .from("requirement_baselines")
        .select("id,baseline_number,revision_number,status,approved_at,requirement:customer_requirements(id,requirement_number,title,current_revision)")
        .eq("id", baselineId)
        .maybeSingle();
      if (error) throw error;
      return data as LinkedBaseline | null;
    },
  });
  const handoverQuery = useQuery({
    queryKey: ["project_sales_handover", projectId, baselineId],
    enabled: Boolean(baselineId),
    queryFn: async () => {
      const { data, error } = await sb
        .from("sales_project_handovers")
        .select("id,status,handover_notes,initiated_at,baseline_id")
        .eq("project_id", projectId)
        .eq("baseline_id", baselineId)
        .maybeSingle();
      if (error) throw error;
      return data as ProjectHandover | null;
    },
  });

  const isLoading = baselineQuery.isLoading || handoverQuery.isLoading;
  const failures = [baselineQuery.error, handoverQuery.error].filter(Boolean);
  const readFailed = failures.length > 0;
  const errorMessage = failures[0] instanceof Error ? failures[0].message : "Read unavailable";
  const retry = () => {
    void baselineQuery.refetch();
    void handoverQuery.refetch();
  };

  return (
    <Card className="p-4">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <p className="text-sm font-medium">Requirement baseline & handover</p>
          <p className="mt-1 text-sm text-muted-foreground">Linked commercial records are shown as recorded; this view does not confirm approval or release.</p>
        </div>
        {baselineId && <span className="font-mono text-xs text-muted-foreground">Linked baseline</span>}
      </div>
      {!baselineId ? (
        <p className="mt-4 text-sm text-muted-foreground">No requirement baseline is linked to this project.</p>
      ) : isLoading ? (
        <p className="mt-4 text-sm text-muted-foreground">Loading linked requirement baseline and handover…</p>
      ) : readFailed ? (
        <div role="alert" className="mt-4 flex flex-wrap items-center gap-2 text-sm text-destructive">
          <span>Linked requirement records could not be loaded. {errorMessage}</span>
          <Button variant="outline" size="sm" onClick={retry}><RefreshCw className="size-3.5" /> Retry</Button>
        </div>
      ) : !baselineQuery.data ? (
        <p className="mt-4 text-sm text-muted-foreground">The linked requirement baseline is not currently accessible.</p>
      ) : (
        <div className="mt-4 grid gap-4 lg:grid-cols-2">
          <div className="space-y-2 border-l-2 border-primary/30 pl-3">
            <p className="text-xs font-medium text-muted-foreground">Linked baseline</p>
            <p className="font-medium">{baselineQuery.data.baseline_number} · revision {baselineQuery.data.revision_number}</p>
            <div className="flex flex-wrap gap-2"><Badge variant="outline">{baselineQuery.data.status}</Badge>{baselineQuery.data.approved_at && <Badge variant="secondary">Recorded {baselineQuery.data.approved_at.slice(0, 10)}</Badge>}</div>
            {baselineQuery.data.requirement ? <p className="text-sm text-muted-foreground">{baselineQuery.data.requirement.requirement_number} · {baselineQuery.data.requirement.title} · current revision {baselineQuery.data.requirement.current_revision}</p> : <p className="text-sm text-muted-foreground">No accessible requirement record is linked to this baseline.</p>}
          </div>
          <div className="space-y-2 border-l-2 border-muted pl-3">
            <p className="text-xs font-medium text-muted-foreground">Project handover</p>
            {handoverQuery.data ? <><div className="flex flex-wrap gap-2"><Badge variant="outline">{handoverQuery.data.status}</Badge>{handoverQuery.data.initiated_at && <Badge variant="secondary">Recorded {handoverQuery.data.initiated_at.slice(0, 10)}</Badge>}</div>{handoverQuery.data.handover_notes ? <p className="text-sm text-muted-foreground">{handoverQuery.data.handover_notes}</p> : <p className="text-sm text-muted-foreground">No handover notes are recorded.</p>}</> : <p className="text-sm text-muted-foreground">No handover record is currently accessible for this linked baseline.</p>}
          </div>
        </div>
      )}
    </Card>
  );
}

function OperationalDialog({ projectId, config, open, onOpenChange, onSaved }: { projectId: string; config: EntityConfig; open: boolean; onOpenChange: (value: boolean) => void; onSaved: () => void }) {
  const [code, setCode] = useState(""); const [type, setType] = useState(config.options[0]); const [title, setTitle] = useState(""); const [detail, setDetail] = useState(""); const [saving, setSaving] = useState(false);
  useEffect(() => { if (open) { setCode(""); setType(config.options[0]); setTitle(""); setDetail(""); } }, [open, config]);
  const save = async () => {
    if (!title.trim() || (config.codeKey !== "title" && !code.trim())) return toast.error("Complete the required fields");
    const payload: Record<string, unknown> = { project_id: projectId, [config.typeKey]: type, [config.descriptionKey]: title.trim() };
    if (config.table === "project_design_inputs" || config.table === "project_research_records") payload.title = title.trim();
    if (config.codeKey !== "title") payload[config.codeKey] = code.trim().toUpperCase();
    if (config.descriptionKey !== "description" && config.descriptionKey !== "summary" && config.descriptionKey !== "title") payload[config.descriptionKey] = title.trim();
    if (config.descriptionKey === "description") payload.description = detail.trim() || null;
    else if (config.descriptionKey === "summary") payload.summary = detail.trim() || null;
    else if (config.table === "project_stage_gates") payload.evidence_note = detail.trim() || null;
    else if (config.table === "project_change_requests") payload.impact_summary = detail.trim() || null;
    else if (config.table === "project_issues") payload.description = detail.trim() || null;
    setSaving(true); const { error } = await sb.from(config.table).insert(payload); setSaving(false);
    if (error) return toast.error(error.message); toast.success("Record added"); onSaved(); onOpenChange(false);
  };
  return <Dialog open={open} onOpenChange={onOpenChange}><DialogContent><DialogHeader><DialogTitle>{config.addLabel}</DialogTitle><DialogDescription>Record controlled project information.</DialogDescription></DialogHeader><div className="grid gap-3">{config.codeKey !== "title" && <div><Label>{config.codeLabel}</Label><Input value={code} onChange={(event) => setCode(event.target.value)} placeholder="Required" /></div>}<div><Label>{config.typeLabel}</Label><Select value={type} onValueChange={setType}><SelectTrigger><SelectValue /></SelectTrigger><SelectContent>{config.options.map((option) => <SelectItem key={option} value={option}>{option.replaceAll("_", " ")}</SelectItem>)}</SelectContent></Select></div><div><Label>{config.descriptionLabel}</Label><Input value={title} onChange={(event) => setTitle(event.target.value)} placeholder="Required" /></div><div><Label>Notes</Label><Textarea value={detail} onChange={(event) => setDetail(event.target.value)} /></div></div><DialogFooter><Button variant="ghost" onClick={() => onOpenChange(false)}>Cancel</Button><Button onClick={save} disabled={saving}>{saving ? "Saving…" : "Save"}</Button></DialogFooter></DialogContent></Dialog>;
}
