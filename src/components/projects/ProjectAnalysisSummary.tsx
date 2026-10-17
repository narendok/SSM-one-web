import { useQuery } from "@tanstack/react-query";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { fetchCanonicalDepartments, fetchTasks, statusLabel, taskAssigneeLabel } from "@/lib/tasks";
import type { Project } from "@/lib/projects";
import { ProjectRequirementContext } from "./ProjectOperationalTabs";

/** Internal caller-authorized projection only. Never reuse this as a client publication. */
export function ProjectAnalysisSummary({ project }: { project: Project }) {
  const departments = useQuery({ queryKey: ["canonical_departments"], queryFn: fetchCanonicalDepartments });
  const tasks = useQuery({ queryKey: ["project_tasks", project.id, "all-departments"], queryFn: () => fetchTasks(project.id) });
  const visible = tasks.data ?? [];
  const blocked = visible.filter(task => task.status === "blocked");
  const next = visible.filter(task => task.status !== "done").sort((a, b) => (a.due_date ?? "9999").localeCompare(b.due_date ?? "9999"))[0];
  const unavailable = tasks.isError || tasks.isPending;
  return <section aria-label="Common project analysis" className="space-y-3">
    <div className="flex flex-wrap items-center gap-2"><h2 className="text-sm font-semibold uppercase tracking-wide">Common project analysis</h2><Badge variant="outline">Internal view</Badge></div>
    <ProjectRequirementContext projectId={project.id} baselineId={project.requirement_baseline_id} />
    <div className="grid gap-3 md:grid-cols-3">
      <Card className="p-3"><h3 className="text-xs font-semibold uppercase">Current phase</h3><p className="mt-2 text-sm">{project.project_stage.replaceAll("_", " ")}</p><p className="text-xs text-muted-foreground">{project.health_status} · {project.priority} priority</p></Card>
      <Card className="p-3"><h3 className="text-xs font-semibold uppercase">Visible blockers</h3><p className="mt-2 text-sm">{unavailable ? "Task data unavailable" : blocked.length ? blocked.map(task => task.title).join(" · ") : "No blocked tasks visible"}</p><p className="text-xs text-muted-foreground">Task status does not establish lifecycle gate clearance.</p></Card>
      <Card className="p-3"><h3 className="text-xs font-semibold uppercase">Next open work</h3><p className="mt-2 text-sm">{unavailable ? "Task data unavailable" : next?.title ?? "No open tasks visible"}</p>{!unavailable && next && <p className="text-xs text-muted-foreground">{taskAssigneeLabel(next)} · {next.due_date ?? "No due date"} · {statusLabel(next.status)}</p>}</Card>
    </div>
    <details className="rounded-lg border bg-card p-3"><summary className="cursor-pointer text-sm font-semibold">Department workstreams</summary>
      <p className="my-2 text-xs text-muted-foreground">Visible project tasks grouped by canonical department. This summary grants no editing authority.</p>
      {departments.isPending ? <p>Loading departments…</p> : departments.isError ? <p role="alert">Department records unavailable.</p> : tasks.isError ? <p role="alert">Department task summaries unavailable.</p> : tasks.isPending ? <p>Loading project tasks…</p> : <div className="grid gap-2 md:grid-cols-2 xl:grid-cols-3">{departments.data.map(department => {
        const scoped = visible.filter(task => task.department_id === department.id);
        return <details key={department.id} className="rounded-md border p-3"><summary className="cursor-pointer text-sm font-medium">{department.name} <span className="text-muted-foreground">· {scoped.length} visible tasks</span></summary>
          {scoped.length ? <ul className="mt-2 space-y-2 text-sm">{scoped.map(task => <li key={task.id}><span>{task.title}</span><p className="text-xs text-muted-foreground">{statusLabel(task.status)} · {taskAssigneeLabel(task)} · {task.due_date ?? "No due date"}</p></li>)}</ul> : <p className="mt-2 text-xs text-muted-foreground">No visible project tasks.</p>}
          <p className="mt-3 text-xs text-muted-foreground">Internal remarks: shared read contract pending.</p><p className="text-xs text-muted-foreground">Client highlights: publication contract pending.</p>
        </details>;
      })}</div>}
      {!unavailable && visible.some(task => !task.department_id) && <p className="mt-2 text-xs text-muted-foreground">Tasks without a canonical department remain on the common task board.</p>}
    </details>
  </section>;
}

