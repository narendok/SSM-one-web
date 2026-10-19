import { createFileRoute } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import { useEffect } from "react";
import { DepartmentProjectTracker } from "@/components/workspaces/DepartmentProjectTracker";
import { DepartmentWorkspacePreferences } from "@/components/workspaces/DepartmentWorkspacePreferences";
import { CANONICAL_DEPT_UUIDS, fetchCanonicalDepartments, resolveCanonicalDepartment } from "@/lib/tasks";
import { readWorkspaceDepartmentId, setWorkspaceDepartmentId } from "@/lib/workspace-context";

export const Route = createFileRoute("/_authenticated/workspace/projects")({
  component: DepartmentProjectsPage,
});

function DepartmentProjectsPage() {
  const departments = useQuery({ queryKey: ["active-departments"], queryFn: fetchCanonicalDepartments });
  const rawDepartmentId = readWorkspaceDepartmentId();

  // Resolve active canonical department resiliently (matches UUID, code, or aliases)
  const canonical = resolveCanonicalDepartment(rawDepartmentId, departments.data ?? []);
  const departmentId = canonical?.id ?? (departments.data?.[0]?.id ?? CANONICAL_DEPT_UUIDS.RND);

  useEffect(() => {
    // If the stored value was not the canonical UUID, normalize it to the canonical UUID
    if (departmentId && rawDepartmentId !== departmentId) {
      setWorkspaceDepartmentId(departmentId);
    }
  }, [rawDepartmentId, departmentId]);

  const department = canonical ?? departments.data?.find((item) => item.id === departmentId) ?? departments.data?.[0];

  return (
    <div className="mx-auto max-w-6xl space-y-6">
      <div>
        <p className="text-sm font-medium text-primary">{department?.name ?? "Department Workspace"}</p>
        <h1 className="mt-1 text-2xl font-semibold">Project tracker</h1>
      </div>
      <DepartmentProjectTracker departmentId={departmentId} />
      <DepartmentWorkspacePreferences departmentId={departmentId} />
    </div>
  );
}