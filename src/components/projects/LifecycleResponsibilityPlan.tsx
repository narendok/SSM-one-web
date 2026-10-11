import { useMemo, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { AlertCircle, ClipboardList, RefreshCw, Settings2 } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { fetchCanonicalDepartments, type CanonicalDepartment } from "@/lib/tasks";
import {
  connectedLifecycleResponsibilityDefaults,
  connectedLifecyclePreparationDefaults,
  lifecycleResponsibilitySettingsStatus,
  stagesForResponsibilityDefault,
  type CompanyStageRead,
  type LifecycleDepartmentCode,
} from "@/lib/connected-lifecycle-responsibility-plan";
import { lifecycleResponsibilityOverrideContract } from "@/lib/lifecycle-responsibility-overrides.contract";
import { supabase } from "@/integrations/supabase/client";

const sb = supabase as any;

const departmentCodes: Record<LifecycleDepartmentCode, string> = {
  RND: "Hardware & R&D",
  PROC: "Procurement, Stores & Incoming Quality",
  PROD: "Production & Calibration",
  OPS: "Operations & QMS / PM",
  SAL: "Sales",
};

function departmentName(code: LifecycleDepartmentCode, departments: CanonicalDepartment[]) {
  return departments.find((department) => department.code === code)?.name ?? departmentCodes[code];
}

export function LifecycleResponsibilityPlan({ compact = false }: { compact?: boolean }) {
  const [localLeadOverrides, setLocalLeadOverrides] = useState<Record<string, LifecycleDepartmentCode>>({});
  const stages = useQuery({
    queryKey: ["company-process-stages", "connected-lifecycle-responsibilities"],
    queryFn: async () => {
      const { data, error } = await sb
        .from("company_process_stages")
        .select("id,stage_code,title,sort_order,requires_gated_handover")
        .eq("is_active", true)
        .order("sort_order");
      if (error) throw error;
      return (data ?? []) as CompanyStageRead[];
    },
    retry: false,
  });
  const departments = useQuery({
    queryKey: ["active-departments"],
    queryFn: fetchCanonicalDepartments,
    retry: false,
  });
  const settingsStatus = lifecycleResponsibilitySettingsStatus();
  const departmentsByCode = useMemo(() => departments.data ?? [], [departments.data]);

  return <Card className={compact ? "p-4" : "p-5"}>
    <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
      <div>
        <div className="flex items-center gap-2"><Settings2 className="size-4 text-primary" /><h3 className="font-semibold">Connected lifecycle responsibility plan</h3></div>
        <p className="mt-1 text-sm text-muted-foreground">Default planning responsibilities are mapped to the existing company stage vocabulary. They never approve, release, assign, or overwrite recorded project work.</p>
      </div>
      <Badge variant="secondary">LOCAL PLANNING ONLY</Badge>
    </div>
    {stages.isPending || departments.isPending ? <p className="mt-4 text-sm text-muted-foreground">Loading visible stage and department settings…</p>
      : stages.isError || departments.isError ? <div role="alert" className="mt-4 flex flex-wrap items-center gap-2 border border-destructive/40 p-3 text-sm text-destructive">
        <span>Responsibility settings could not be loaded{stages.error instanceof Error ? `: ${stages.error.message}` : departments.error instanceof Error ? `: ${departments.error.message}` : "."}</span>
        <Button size="sm" variant="outline" onClick={() => { void stages.refetch(); void departments.refetch(); }}><RefreshCw className="size-3.5" /> Retry</Button>
      </div>
        : !stages.data?.length ? <p className="mt-4 border p-3 text-sm text-muted-foreground">No active company lifecycle stages are accessible. No stage responsibility is inferred.</p>
          : <div className="mt-4 space-y-3">
            {connectedLifecycleResponsibilityDefaults.map((responsibility) => {
              const mappedStages = stagesForResponsibilityDefault(stages.data, responsibility);
              const lead = localLeadOverrides[responsibility.key] ?? responsibility.leadDepartment;
              return <section key={responsibility.key} className="border-l-2 border-primary/30 pl-3">
                <div className="flex flex-wrap items-start justify-between gap-3">
                  <div>
                    <p className="text-sm font-medium">{responsibility.title}</p>
                    <p className="mt-1 text-xs text-muted-foreground">{mappedStages.length ? mappedStages.map((stage) => stage.stage_code).join(" · ") : "No matching visible company stages"}</p>
                  </div>
                  <Badge variant="outline">{mappedStages.length} visible stage{mappedStages.length === 1 ? "" : "s"}</Badge>
                </div>
                <div className="mt-3 grid gap-3 text-sm lg:grid-cols-3">
                  <div><p className="text-xs text-muted-foreground">Local planning lead</p><select aria-label={`${responsibility.title} local planning lead`} className="mt-1 w-full rounded-md border bg-background px-2 py-1.5 text-sm" value={lead} onChange={(event) => setLocalLeadOverrides((current) => ({ ...current, [responsibility.key]: event.target.value as LifecycleDepartmentCode }))}>{Object.keys(departmentCodes).map((code) => <option key={code} value={code}>{departmentName(code as LifecycleDepartmentCode, departmentsByCode)}</option>)}</select></div>
                  <div><p className="text-xs text-muted-foreground">PM coordination</p><p className="mt-1">{responsibility.coordinatingDepartment ? departmentName(responsibility.coordinatingDepartment, departmentsByCode) : "Not set"}</p></div>
                  <div><p className="text-xs text-muted-foreground">Participating</p><p className="mt-1">{responsibility.participatingDepartments.map((code) => departmentName(code, departmentsByCode)).join(" · ") || "None"}</p></div>
                </div>
                {!compact && <><p className="mt-3 text-xs text-muted-foreground">Planning deliverables: {responsibility.deliverables.join(" · ")}</p><p className="mt-1 text-xs text-muted-foreground">{responsibility.handoff}</p></>}
              </section>;
            })}
          </div>}
    {!compact && !stages.isPending && !departments.isPending && !stages.isError && !departments.isError && stages.data?.length ? <section className="mt-6 border-t pt-5">
      <div className="flex items-start gap-2"><ClipboardList className="mt-0.5 size-4 text-primary" /><div><h4 className="text-sm font-medium">Stage deliverable & task preparation preview</h4><p className="mt-1 text-xs text-muted-foreground">Uses visible company stages and department lookup only. It preserves manual tasks and creates no task, dependency, handoff, notification, approval, or release.</p></div></div>
      <div className="mt-4 space-y-3">
        {connectedLifecyclePreparationDefaults.map((preparation, index) => {
          const visibleStages = stages.data.filter((stage) => stage.stage_code >= `HW_${String(preparation.stageRange[0]).padStart(2, "0")}` && stage.stage_code <= `HW_${String(preparation.stageRange[1]).padStart(2, "0")}`);
          return <div key={preparation.key} className="border-l-2 border-muted pl-3">
            <div className="flex flex-wrap items-center gap-2"><p className="text-sm font-medium">{preparation.title}</p><Badge variant="outline">{visibleStages.map((stage) => stage.stage_code).join(" · ") || "No visible stages"}</Badge><Badge variant="secondary">Preview only</Badge></div>
            <p className="mt-1 text-xs text-muted-foreground">Lead: {departmentName(preparation.leadDepartment, departmentsByCode)} · Participants: {preparation.participatingDepartments.map((code) => departmentName(code, departmentsByCode)).join(" · ") || "None"}</p>
            <p className="mt-1 text-xs text-muted-foreground">Deliverables: {preparation.deliverables.join(" · ")}</p>
            {index > 0 && <p className="mt-1 text-xs text-muted-foreground">Dependency: visible prior-stage records are planning context only; their status does not release this work.</p>}
            {preparation.purchaseHandoff === "HARDWARE_APPROVED_HANDOFF_REQUIRED" && <p className="mt-1 text-xs text-muted-foreground">Purchase handoff: only an existing Hardware-approved handoff may be used; this preview neither confirms nor creates one.</p>}
          </div>;
        })}
      </div>
    </section> : null}
    <div className="mt-4 flex items-start gap-2 border-t pt-4 text-xs text-muted-foreground"><AlertCircle className="mt-0.5 size-3.5 shrink-0" /><p>{settingsStatus.message} {lifecycleResponsibilityOverrideContract.title} stay inactive; changes above are local to this screen and do not change template stages, project assignments, history, tasks, handoffs, or notifications.</p></div>
  </Card>;
}