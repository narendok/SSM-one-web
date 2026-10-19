import { useEffect, useState } from "react";
import { Building2, Check, Layers3, Lock } from "lucide-react";
import { useQuery } from "@tanstack/react-query";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { fetchCanonicalDepartments, type CanonicalDepartment } from "@/lib/tasks";
import { readWorkspaceDepartmentId, setWorkspaceDepartmentId, WORKSPACE_CONTEXT_EVENT } from "@/lib/workspace-context";
import { workspaceForDepartment } from "@/lib/department-workspace-navigation";
import { useAuth } from "@/hooks/useAuth";
import { getStoredTestSession } from "@/lib/demo-auth";

export function WorkspaceSwitcher() {
  const { role, permissions, employeeStatus } = useAuth();
  const departments = useQuery({ queryKey: ["active-departments"], queryFn: fetchCanonicalDepartments });
  const [departmentId, setDepartmentId] = useState<string | null>(() => readWorkspaceDepartmentId());

  useEffect(() => {
    const syncWorkspace = () => setDepartmentId(readWorkspaceDepartmentId());
    window.addEventListener(WORKSPACE_CONTEXT_EVENT, syncWorkspace);
    window.addEventListener("storage", syncWorkspace);
    return () => {
      window.removeEventListener(WORKSPACE_CONTEXT_EVENT, syncWorkspace);
      window.removeEventListener("storage", syncWorkspace);
    };
  }, []);

  const hasWorkspaceAccess = (department: CanonicalDepartment) =>
    role === "admin" || Boolean(workspaceForDepartment(department)?.items.some((item) => !item.permission || permissions.includes(item.permission)));
  const availableDepartments = (departments.data ?? []).filter(hasWorkspaceAccess);

  // Auto-resolve department for non-admin if not set
  useEffect(() => {
    if (role !== "admin" && !departmentId) {
      const demo = getStoredTestSession();
      if (demo?.account?.departmentId) {
        setDepartmentId(demo.account.departmentId);
        setWorkspaceDepartmentId(demo.account.departmentId);
      } else if (availableDepartments.length === 1) {
        setDepartmentId(availableDepartments[0].id);
        setWorkspaceDepartmentId(availableDepartments[0].id);
      }
    }
  }, [role, departmentId, availableDepartments]);

  const selectedDepartment = (departments.data ?? []).find((department) => department.id === departmentId) ?? null;
  const workspace = workspaceForDepartment(selectedDepartment);
  const triggerLabel = workspace?.label ?? selectedDepartment?.name ?? "All workspaces";

  const chooseWorkspace = (nextDepartmentId: string | null) => {
    setWorkspaceDepartmentId(nextDepartmentId);
    setDepartmentId(nextDepartmentId);
  };

  // Non-admin users are locked to their assigned workspace
  if (role !== "admin") {
    const lockedLabel = workspace?.label ?? selectedDepartment?.name ?? availableDepartments[0]?.name ?? "Assigned department";
    return (
      <div
        className="flex h-8 max-w-56 items-center gap-1.5 rounded-md border border-border/60 bg-muted/40 px-2.5 py-1 text-xs font-medium text-foreground select-none"
        title="Department workspace locked to your assigned role"
        data-testid="workspace-locked-badge"
        aria-label={`Department workspace locked: ${lockedLabel}`}
      >
        <Lock className="size-3.5 text-muted-foreground shrink-0" />
        <span className="truncate">{lockedLabel}</span>
      </div>
    );
  }

  // Admin users can switch freely between all workspaces
  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button
          variant="ghost"
          size="sm"
          className="h-8 max-w-44 gap-1.5 px-2"
          title="Change department workspace"
          data-testid="workspace-switcher-trigger"
          aria-label={`Department workspace: ${triggerLabel}`}
        >
          <Building2 className="size-4 shrink-0" />
          <span className="hidden truncate text-xs font-medium lg:inline">{triggerLabel}</span>
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end" className="w-64">
        <DropdownMenuLabel>Department workspace</DropdownMenuLabel>
        <DropdownMenuSeparator />
        <WorkspaceItem label="All workspaces" active={!departmentId} onSelect={() => chooseWorkspace(null)} icon={<Layers3 className="size-4" />} />
        {availableDepartments.map((department) => (
          <WorkspaceItem
            key={department.id}
            label={workspaceForDepartment(department)?.label ?? department.name}
            active={department.id === departmentId}
            onSelect={() => chooseWorkspace(department.id)}
          />
        ))}
      </DropdownMenuContent>
    </DropdownMenu>
  );
}

function WorkspaceItem({ label, active, onSelect, icon }: { label: string; active: boolean; onSelect: () => void; icon?: React.ReactNode }) {
  return (
    <DropdownMenuItem onSelect={onSelect} className="flex items-center gap-2">
      {icon ?? <Building2 className="size-4" />}
      <span className="flex-1">{label}</span>
      {active && <Check className="size-4 text-primary" />}
    </DropdownMenuItem>
  );
}