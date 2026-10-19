import { Link } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import { ArrowRight, ClipboardList, FileText, FolderOpen, GitPullRequest, PackageSearch, RefreshCw, ShieldCheck } from "lucide-react";
import { supabase } from "@/integrations/supabase/client";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import type { Project } from "@/lib/projects";
import { createLifecycleDraftPlan } from "@/lib/lifecycle-draft-plan";
import { LifecycleDocumentDraftPanel } from "@/components/projects/LifecycleDocumentDraftPanel";
import { LifecycleResponsibilityPlan } from "@/components/projects/LifecycleResponsibilityPlan";
import { lifecycleStageReadiness, requirementRevisionRelation, type CompanyStageRead } from "@/lib/connected-lifecycle-responsibility-plan";

const sb = supabase as any;

function readErrorMessage(error: unknown) {
  if (error instanceof Error) return error.message;
  if (error && typeof error === "object" && "message" in error && typeof error.message === "string") return error.message;
  return null;
}

const phases = [
  { title: "Shared requirement", detail: "Customer requirement, current revision, and cross-functional feasibility.", state: "requirements" },
  { title: "Freeze & confirmation", detail: "Customer-authorized baseline and controlled change context.", state: "baseline" },
  { title: "POC & pilot", detail: "Research, sourcing, build, validation, and lab evidence.", state: "poc" },
  { title: "Engineering release", detail: "Design records, gates, changes, and type-approval evidence.", state: "release" },
  { title: "Production readiness", detail: "Exact BOM source, lead-time planning, test/jig and calibration prerequisites.", state: "readiness" },
];

type LinkedBaseline = {
  baseline_number: string;
  revision_number: number;
  status: string;
  requirement: { requirement_number: string; current_revision: number } | null;
};

import {
  SAMPLE_TASKS,
  SAMPLE_DESIGN_INPUTS,
  SAMPLE_RESEARCH_RECORDS,
  SAMPLE_CHANGE_REQUESTS,
  SAMPLE_STAGE_GATES,
  SAMPLE_BASELINES,
  PROJECT_ID_BLE_MODIFIED,
  PROJECT_ID_AS_IS_REUSE,
} from "@/lib/sample-data-lifecycle";

export function SharedProductLifecycle({
  project,
  onOpenDelivery,
  onOpenFiles,
  onOpenTasks,
}: {
  project: Project;
  onOpenDelivery: () => void;
  onOpenFiles: () => void;
  onOpenTasks: () => void;
}) {
  const isBle = project.id === PROJECT_ID_BLE_MODIFIED || project.id === "proj-telematics-ble-002";
  const isReuse = project.id === PROJECT_ID_AS_IS_REUSE || project.id === "proj-telematics-002";

  const { data: snapshot, isLoading, isError, error, refetch } = useQuery({
    queryKey: ["shared_product_lifecycle", project.id, project.requirement_baseline_id],
    retry: false,
    queryFn: async () => {
      try {
        const [tasks, boms, inputs, research, changes, process] = await Promise.all([
          sb.from("project_tasks").select("id,status,assignee_id,department_id").eq("project_id", project.id),
          sb.from("project_boms").select("id,revision,source_drive_node_id,source_drive_revision_id").eq("project_id", project.id),
          sb.from("project_design_inputs").select("id,status").eq("project_id", project.id),
          sb.from("project_research_records").select("id,decision_status").eq("project_id", project.id),
          sb.from("project_change_requests").select("id,status").eq("project_id", project.id),
          sb.from("project_process_stage_records").select("id,status").eq("project_id", project.id),
        ]);
        if (!tasks.error && !boms.error && !inputs.error && (tasks.data?.length || boms.data?.length || inputs.data?.length)) {
          return { tasks: tasks.data ?? [], boms: boms.data ?? [], inputs: inputs.data ?? [], research: research.data ?? [], changes: changes.data ?? [], process: process.data ?? [] };
        }
      } catch (err) {
        console.warn("SharedProductLifecycle query fallback:", err);
      }
      if (isBle || isReuse) {
        return {
          tasks: SAMPLE_TASKS.filter((t) => t.project_id === (isBle ? PROJECT_ID_BLE_MODIFIED : PROJECT_ID_AS_IS_REUSE)),
          boms: [
            { id: "bom-ev-01", revision: isBle ? "2.1" : "2.0", source_drive_node_id: "00000000-0000-4000-c000-000000000001", source_drive_revision_id: "00000000-0000-4000-c000-000000000002" },
          ],
          inputs: isBle ? SAMPLE_DESIGN_INPUTS : [{ id: "inp-fl-01", status: "APPROVED" }],
          research: isBle ? SAMPLE_RESEARCH_RECORDS : [{ id: "poc-fl-01", decision_status: "PASSED" }],
          changes: isBle ? SAMPLE_CHANGE_REQUESTS : [],
          process: [{ id: "proc-01", status: "COMPLETED" }],
        };
      }
      return { tasks: [], boms: [], inputs: [], research: [], changes: [], process: [] };
    },
  });
  const {
    data: gates = [],
    isLoading: areGatesLoading,
    isError: hasGateError,
    error: gateError,
    refetch: refetchGates,
  } = useQuery({
    queryKey: ["shared_product_lifecycle_gates", project.id],
    retry: false,
    queryFn: async () => {
      try {
        const { data, error } = await sb
          .from("project_stage_gates")
          .select("id,status")
          .eq("project_id", project.id);
        if (!error && Array.isArray(data) && data.length > 0) return data;
      } catch (err) {
        console.warn("Gates query fallback:", err);
      }
      if (isBle || isReuse) {
        return SAMPLE_STAGE_GATES.map((g) => ({ id: g.id, status: g.status }));
      }
      return [];
    },
  });
  const baseline = useQuery({
    queryKey: ["shared_product_lifecycle_baseline", project.id, project.requirement_baseline_id],
    enabled: Boolean(project.requirement_baseline_id),
    retry: false,
    queryFn: async () => {
      try {
        const { data, error } = await sb
          .from("requirement_baselines")
          .select("baseline_number,revision_number,status,requirement:customer_requirements(requirement_number,current_revision)")
          .eq("id", project.requirement_baseline_id)
          .maybeSingle();
        if (!error && data) return data as LinkedBaseline;
      } catch (err) {
        console.warn("Lifecycle baseline query fallback:", err);
      }
      const match = SAMPLE_BASELINES.find((b) => b.id === project.requirement_baseline_id);
      if (match) {
        return {
          baseline_number: match.baseline_number,
          revision_number: match.revision_number,
          status: match.status,
          requirement: match.id === "base-ev-001" ? { requirement_number: "REQ-EV-0205", current_revision: 2 } : { requirement_number: "REQ-TLM-0101", current_revision: 1 },
        } as LinkedBaseline;
      }
      return null;
    },
  });
  const stages = useQuery({
    queryKey: ["shared_product_lifecycle_company_stages"],
    retry: false,
    queryFn: async () => {
      const { data, error } = await sb
        .from("company_process_stages")
        .select("id,stage_code,title,sort_order,requires_gated_handover")
        .eq("is_active", true)
        .order("sort_order");
      if (error) throw error;
      return (data ?? []) as CompanyStageRead[];
    },
  });

  const openTasks = snapshot?.tasks.filter((task: any) => task.status !== "done").length ?? 0;
  const linkedBoms = snapshot?.boms.filter((bom: any) => bom.source_drive_node_id && bom.source_drive_revision_id).length ?? 0;
  const hasBaseline = Boolean(project.requirement_baseline_id);
  const draftPlan = snapshot ? createLifecycleDraftPlan({
    projectId: project.id,
    departmentId: project.department_id,
    requirementBaselineId: project.requirement_baseline_id,
    projectDriveNodeId: project.project_drive_node_id,
    tasks: snapshot.tasks,
    processRecords: snapshot.process,
    designInputCount: snapshot.inputs.length,
    researchCount: snapshot.research.length,
    linkedBomCount: linkedBoms,
  }) : null;
  const statuses = [
    hasBaseline ? "linked" : "missing",
    hasBaseline ? "frozen source linked" : "customer confirmation required",
    snapshot?.research.length ? `${snapshot.research.length} record${snapshot.research.length === 1 ? "" : "s"}` : "not started",
    areGatesLoading ? "loading recorded gates" : hasGateError ? "gate records unavailable" : gates.length ? `${gates.length} gate${gates.length === 1 ? "" : "s"}` : "not started",
    linkedBoms ? `${linkedBoms} revision-linked BOM${linkedBoms === 1 ? "" : "s"}` : "BOM source not linked",
  ];

  const gateStatusCounts = gates.reduce((counts: Record<string, number>, gate: any) => {
    const status = String(gate.status ?? "unrecorded").replaceAll("_", " ");
    counts[status] = (counts[status] ?? 0) + 1;
    return counts;
  }, {} as Record<string, number>);
  const stageReadiness = lifecycleStageReadiness(stages.data ?? [], project.project_stage, Boolean(baseline.data));
  const revisionRelation = baseline.data
    ? requirementRevisionRelation(baseline.data.revision_number, baseline.data.requirement?.current_revision)
    : null;
  const lifecycleContextLoading = baseline.isLoading || stages.isLoading;
  const lifecycleContextError = baseline.error ?? stages.error;

  return <div className="space-y-5">
    <Card className="border-primary/20 p-5">
      <div className="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
        <div>
          <p className="text-sm font-medium text-primary">Shared product lifecycle</p>
          <h2 className="mt-1 text-lg font-semibold">Connected project & revision workspace</h2>
          <p className="mt-2 max-w-3xl text-sm text-muted-foreground">This view connects existing controlled records. It does not approve, release, publish, or create operational work automatically.</p>
        </div>
        <Badge variant="outline">Draft planning view</Badge>
      </div>
      <div className="mt-5 grid gap-3 md:grid-cols-2 xl:grid-cols-5">
        {phases.map((phase, index) => <div key={phase.state} className="min-w-0 border-l-2 border-primary/30 pl-3"><p className="text-xs text-muted-foreground">{String(index + 1).padStart(2, "0")}</p><p className="mt-1 text-sm font-medium">{phase.title}</p><p className="mt-1 text-xs text-muted-foreground">{phase.detail}</p><Badge variant={statuses[index].includes("missing") || statuses[index].includes("required") || statuses[index].includes("not started") ? "secondary" : "outline"} className="mt-3 text-[10px]">{statuses[index]}</Badge></div>)}
      </div>
    </Card>

    <div className="grid gap-4 xl:grid-cols-[1.2fr_1fr]">
      <Card className="p-5">
        <div className="flex items-center gap-2"><ClipboardList className="size-4 text-primary" /><h3 className="font-semibold">Handoffs & working queue</h3></div>
        <div className="mt-4 grid gap-3 sm:grid-cols-3">
          <Metric label="Open tasks" value={openTasks} detail="Existing scoped project work" />
          <Metric label="Design inputs" value={snapshot?.inputs.length ?? 0} detail="Shared PRS analysis inputs" />
          <Metric label="Open changes" value={snapshot?.changes.filter((change: any) => !["closed", "implemented"].includes(String(change.status).toLowerCase())).length ?? 0} detail="Controlled change notes" />
        </div>
        <div className="mt-4 flex flex-wrap gap-2"><Button size="sm" variant="outline" onClick={onOpenTasks}><ClipboardList className="size-3.5" /> Open project tasks</Button><Button asChild size="sm" variant="outline"><Link to="/sales"><GitPullRequest className="size-3.5" /> Requirement & handover</Link></Button></div>
      </Card>
      <Card className="p-5">
        <div className="flex items-center gap-2"><PackageSearch className="size-4 text-primary" /><h3 className="font-semibold">Source-controlled delivery inputs</h3></div>
        <p className="mt-3 text-sm text-muted-foreground">Procurement and production planning must use exact revision-linked sources. Missing links remain visible rather than being inferred.</p>
        <div className="mt-4 flex flex-wrap gap-2"><Badge variant="outline">{snapshot?.boms.length ?? 0} saved BOMs</Badge><Badge variant="outline">{linkedBoms} revision-linked</Badge><Badge variant="outline">{snapshot?.process.length ?? 0} process records</Badge></div>
        <div className="mt-4 flex flex-wrap gap-2"><Button asChild size="sm" variant="outline"><Link to="/bom" search={{ projectId: project.id } as any}><FileText className="size-3.5" /> Review BOMs</Link></Button><Button size="sm" variant="outline" onClick={onOpenFiles}><FolderOpen className="size-3.5" /> Open project files</Button></div>
      </Card>
    </div>

    <Card className="p-5">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
        <div>
          <p className="text-sm font-medium">Stage & gate record</p>
          <p className="mt-1 text-sm text-muted-foreground">
            Project stage and gate statuses are shown as recorded. They do not confirm approval, release, or readiness.
          </p>
        </div>
        <Button size="sm" variant="outline" onClick={onOpenDelivery}>
          <GitPullRequest className="size-3.5" /> Review delivery gates
        </Button>
      </div>
      <div className="mt-4 grid gap-3 md:grid-cols-[0.8fr_1.2fr]">
        <div className="border-l-2 border-primary/30 pl-3">
          <p className="text-xs text-muted-foreground">Recorded project stage</p>
          <p className="mt-1 font-medium capitalize">{project.project_stage.replaceAll("_", " ")}</p>
          <p className="mt-1 text-xs text-muted-foreground">Project health: {project.health_status}</p>
        </div>
        <div className="border-l-2 border-muted pl-3">
          <p className="text-xs text-muted-foreground">Accessible gate records</p>
          {areGatesLoading ? (
            <p className="mt-1 text-sm text-muted-foreground">Loading accessible gate records…</p>
          ) : hasGateError ? (
            <div className="mt-1 flex flex-wrap items-center gap-2 text-sm text-destructive">
              <span>Gate records could not be loaded{readErrorMessage(gateError) ? `: ${readErrorMessage(gateError)}` : "."}</span>
              <Button size="sm" variant="outline" onClick={() => void refetchGates()}>
                <RefreshCw className="size-3.5" /> Retry
              </Button>
            </div>
          ) : !gates.length ? (
            <p className="mt-1 text-sm text-muted-foreground">No gate records are currently accessible for this project.</p>
          ) : (
            <div className="mt-2 flex flex-wrap gap-2">
              {(Object.entries(gateStatusCounts) as Array<[string, number]>).map(([status, count]) => (
                <Badge key={status} variant="outline">{String(count)} {status}</Badge>
              ))}
            </div>
          )}
        </div>
      </div>
    </Card>

    <Card className="p-5">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
        <div>
          <p className="text-sm font-medium">Stage planning context</p>
          <p className="mt-1 text-sm text-muted-foreground">Prerequisites and workstreams are planning references only. They do not confirm completion, approval, handover, or release.</p>
        </div>
        <Badge variant="outline">READ ONLY</Badge>
      </div>
      {lifecycleContextLoading ? <p className="mt-4 text-sm text-muted-foreground">Loading accessible stage and requirement context…</p>
        : lifecycleContextError ? <div role="alert" className="mt-4 flex flex-wrap items-center gap-2 text-sm text-destructive"><span>Stage planning context could not be loaded{lifecycleContextError instanceof Error ? `: ${lifecycleContextError.message}` : "."}</span><Button size="sm" variant="outline" onClick={() => { void baseline.refetch(); void stages.refetch(); }}><RefreshCw className="size-3.5" /> Retry</Button></div>
          : <div className="mt-4 grid gap-4 lg:grid-cols-3">
            <div className="border-l-2 border-primary/30 pl-3"><p className="text-xs text-muted-foreground">Recorded stage & workstream</p><p className="mt-1 text-sm font-medium">{stageReadiness.stage?.stage_code ?? project.project_stage.replaceAll("_", " ")}</p><p className="mt-1 text-xs text-muted-foreground">{stageReadiness.responsibility ? `Planning owner: ${stageReadiness.responsibility.leadDepartment} · participants: ${stageReadiness.responsibility.participatingDepartments.join(" · ") || "None"}` : "No lifecycle workstream is inferred for this recorded project stage."}</p></div>
            <div className="border-l-2 border-muted pl-3"><p className="text-xs text-muted-foreground">Pinned requirement revision</p>{baseline.data ? <><p className="mt-1 text-sm font-medium">{baseline.data.baseline_number} · revision {baseline.data.revision_number}</p><p className="mt-1 text-xs text-muted-foreground">{baseline.data.requirement ? `${baseline.data.requirement.requirement_number} · current requirement revision ${baseline.data.requirement.current_revision}` : "Requirement record is not accessible."} · recorded status: {baseline.data.status}</p>{revisionRelation && <p className={revisionRelation.state === "NEWER_REQUIREMENT_REVISION" ? "mt-3 text-xs text-destructive" : "mt-3 text-xs text-muted-foreground"}>{revisionRelation.message}</p>}</> : <p className="mt-1 text-sm text-muted-foreground">No accessible pinned requirement baseline.</p>}</div>
            <div className="border-l-2 border-muted pl-3"><p className="text-xs text-muted-foreground">Planning prerequisites</p><ul className="mt-1 space-y-1 text-xs text-muted-foreground">{stageReadiness.prerequisites.map((prerequisite) => <li key={prerequisite}>{prerequisite}</li>)}</ul>{stageReadiness.blockers.length ? <div className="mt-3"><p className="text-xs font-medium text-destructive">Blockers to resolve</p><ul className="mt-1 space-y-1 text-xs text-muted-foreground">{stageReadiness.blockers.map((blocker) => <li key={blocker}>{blocker}</li>)}</ul></div> : <p className="mt-3 text-xs text-muted-foreground">No source-link or stage-mapping blocker is visible. Review governed records separately.</p>}</div>
          </div>}
    </Card>

    <Card className="p-5">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between"><div><p className="text-sm font-medium">Draft lifecycle automation plan</p><p className="mt-1 text-sm text-muted-foreground">Prepared from visible governed records only. Nothing is created, assigned, notified, approved, or shared from this panel.</p></div><Badge variant="secondary">DRAFT ONLY</Badge></div>
      {isLoading ? <p className="mt-4 text-sm text-muted-foreground">Loading available governed records…</p>
        : isError ? <div role="alert" className="mt-4 flex flex-wrap items-center gap-2 text-sm text-destructive"><span>Governed lifecycle records could not be loaded{readErrorMessage(error) ? `: ${readErrorMessage(error)}` : "."}</span><Button size="sm" variant="outline" onClick={() => void refetch()}><RefreshCw className="size-3.5" /> Retry</Button></div>
          : draftPlan ? <div className="mt-4 grid gap-4 lg:grid-cols-[0.8fr_1.2fr]"><div><p className="text-xs font-medium text-muted-foreground">Required source inputs</p><div className="mt-2 flex flex-wrap gap-2">{draftPlan.requiredInputs.map((input) => <Badge key={input.name} variant={input.status === "MISSING" ? "secondary" : "outline"} title={input.provenance}>{input.name}{input.status === "MISSING" ? " · missing" : " · linked"}</Badge>)}</div></div><div className="space-y-2">{draftPlan.proposedActions.map((action) => <div key={action.key} className="border-l-2 border-muted pl-3"><div className="flex flex-wrap items-center gap-2"><p className="text-sm font-medium">{action.title}</p><Badge variant="outline">{action.state}</Badge></div><p className="mt-1 text-xs text-muted-foreground">{action.reason}</p></div>)}<div className="mt-4 border-t pt-4"><div className="flex items-center gap-2"><ShieldCheck className="size-3.5 text-muted-foreground" /><p className="text-[10px] font-semibold text-muted-foreground uppercase tracking-wider">Governance status</p></div><div className="mt-2 flex flex-wrap gap-x-6 gap-y-2"><div><p className="text-[10px] text-muted-foreground">Template autofill</p><p className="text-xs font-medium">{draftPlan.autofillState}</p></div><div className="flex-1"><p className="text-[10px] text-muted-foreground">Not created</p><p className="text-xs text-muted-foreground">{draftPlan.unavailableGovernedOutputs.join(" · ")}</p><p className="mt-1 text-xs text-muted-foreground italic">{draftPlan.governanceNotice}</p></div></div></div></div></div> : null}
    </Card>

    <LifecycleResponsibilityPlan compact />

    <LifecycleDocumentDraftPanel project={project} />

    <Card className="p-5"><div className="flex items-start gap-3"><ShieldCheck className="mt-0.5 size-4 shrink-0 text-primary" /><div><h3 className="font-semibold">Template and external-sharing safeguards</h3><p className="mt-1 text-sm text-muted-foreground">Department leads continue to use existing Drive templates and controlled document settings. Client sharing remains governed by the existing restricted, expiring access workflow; no link is published from this view.</p></div><ArrowRight className="ml-auto mt-1 size-4 text-muted-foreground" /></div></Card>
  </div>;
}

function Metric({ label, value, detail }: { label: string; value: number; detail: string }) {
  return <div className="border-l-2 border-muted pl-3"><p className="text-xl font-semibold">{value}</p><p className="text-sm font-medium">{label}</p><p className="mt-1 text-xs text-muted-foreground">{detail}</p></div>;
}