import { createFileRoute } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import { useEffect } from "react";
import { DepartmentProjectTracker } from "@/components/workspaces/DepartmentProjectTracker";
import { DepartmentWorkspacePreferences } from "@/components/workspaces/DepartmentWorkspacePreferences";
import { CANONICAL_DEPT_UUIDS, fetchCanonicalDepartments } from "@/lib/tasks";
import { readWorkspaceDepartmentId, setWorkspaceDepartmentId } from "@/lib/workspace-context";

export const Route = createFileRoute("/_authenticated/workspace/projects")({
  component: DepartmentProjectsPage,
});

function DepartmentProjectsPage() {
  const departments = useQuery({ queryKey: ["active-departments"], queryFn: fetchCanonicalDepartments });
  const rawDepartmentId = readWorkspaceDepartmentId();

  // Resolve active department ID (fallback gracefully to R&D for engineering/hardware)
  const isUuid = Boolean(rawDepartmentId && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(rawDepartmentId));
  const departmentId = isUuid && rawDepartmentId ? rawDepartmentId : (departments.data?.[0]?.id ?? CANONICAL_DEPT_UUIDS.RND);

  useEffect(() => {
    if (!isUuid && departmentId) {
      setWorkspaceDepartmentId(departmentId);
    }
  }, [isUuid, departmentId]);

  const department = departments.data?.find((item) => item.id === departmentId) ?? departments.data?.[0];

  return (
    <div className="mx-auto max-w-6xl space-y-6">
      <div>
        <p className="text-sm font-medium text-primary">{department?.name ?? "Hardware & R&D"}</p>
        <h1 className="mt-1 text-2xl font-semibold">Project tracker</h1>
      </div>
      <DepartmentProjectTracker departmentId={departmentId} />
      <DepartmentWorkspacePreferences departmentId={departmentId} />
    </div>
  );
}