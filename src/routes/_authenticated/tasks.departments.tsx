import { createFileRoute, Link } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import { Users } from "lucide-react";
import { supabase } from "@/integrations/supabase/client";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Progress } from "@/components/ui/progress";
import { Button } from "@/components/ui/button";
import { fetchCanonicalDepartments, TASK_STATUSES, fetchTasks } from "@/lib/tasks";
import type { RDMember } from "@/lib/inventory";

export const Route = createFileRoute("/_authenticated/tasks/departments")({
  head: () => ({ meta: [{ title: "Departments — SSM One" }, { name: "description", content: "Workload and responsible people by department." }] }),
  component: DepartmentsPage,
});

/** Read-only projection. Backend RLS controls visible records; this page grants no membership. */
export function DepartmentsPage() {
  const departments = useQuery({ queryKey: ["canonical_departments"], queryFn: fetchCanonicalDepartments });
  const tasks = useQuery({ queryKey: ["project_tasks", "all"], queryFn: () => fetchTasks() });
  const members = useQuery({
    queryKey: ["rd_members_all"],
    queryFn: async () => {
      const { data, error } = await supabase.from("rd_members").select("*").order("name");
      if (error) throw error;
      return (data ?? []) as (RDMember & { department_id: string | null })[];
    },
  });
  return <div className="space-y-5">
    <div className="flex flex-wrap items-end justify-between gap-3">
      <div><h1 className="text-2xl font-bold tracking-tight flex items-center gap-2"><Users className="h-6 w-6" /> Departments</h1><p className="text-sm text-muted-foreground mt-0.5">Workload and responsible people by department.</p></div>
      <Button asChild variant="outline"><Link to="/rd-team">Manage team</Link></Button>
    </div>
    {departments.isPending ? <p>Loading departments…</p> : departments.isError ? <p role="alert">Department records could not be loaded.</p> : !departments.data.length ? <p>No department records are available.</p> : <>
      {tasks.isError && <p role="alert">Task workload could not be loaded. Counts are unavailable.</p>}
      {members.isError && <p role="alert">Responsible member records could not be loaded.</p>}
      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">{departments.data.map(d => {
        const mine = (tasks.data ?? []).filter(task => task.department_id === d.id);
        const done = mine.filter(task => task.status === "done").length;
        const people = (members.data ?? []).filter(member => member.department_id === d.id);
        const tasksAvailable = tasks.isSuccess;
        return <Card key={d.id} className="p-4 space-y-3">
          <div className="flex items-center gap-2"><h2 className="font-semibold">{d.name}</h2><Badge variant="outline" className="ml-auto">{tasksAvailable ? `${mine.length} tasks` : tasks.isPending ? "Loading tasks…" : "Tasks unavailable"}</Badge></div>
          {tasksAvailable && <><Progress value={mine.length ? Math.round(done / mine.length * 100) : 0} className="h-1.5" /><div className="text-xs text-muted-foreground">{done} of {mine.length} done</div><div className="flex flex-wrap gap-1.5 text-xs">{TASK_STATUSES.filter(s => s.value !== "done").map(s => <span key={s.value} className="rounded bg-muted px-1.5 py-0.5">{s.label}: {mine.filter(task => task.status === s.value).length}</span>)}</div></>}
          <div className="text-sm"><span className="text-muted-foreground">Team: </span>{members.isPending ? "Loading members…" : members.isError ? "Members unavailable" : people.length ? people.map(person => person.name).join(", ") : "No visible responsible members"}</div>
        </Card>;
      })}</div>
      {tasks.isSuccess && tasks.data.some(task => !task.department_id) && <p className="text-sm text-muted-foreground">Tasks without a canonical department are excluded from these totals.</p>}
    </>}
  </div>;
}
