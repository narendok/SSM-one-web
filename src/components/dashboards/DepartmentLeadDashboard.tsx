import { useEffect, useMemo, useState } from "react";
import { Link, useNavigate, useSearch } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import {
  AlertTriangle,
  ArrowUpRight,
  BarChart3,
  Building2,
  CheckSquare,
  CircleAlert,
  ClipboardCheck,
  FileText,
  FolderKanban,
  Loader2,
  PackageSearch,
  ShieldCheck,
  UsersRound,
} from "lucide-react";
import {
  canonicalToDashboardDepartment,
  dashboardToCanonicalDepartment,
  departmentAccessLabel,
  departmentDefinitions,
  fetchDepartmentDashboard,
  getPermittedDepartments,
  type DashboardDepartment,
} from "@/lib/department-dashboard";
import {
  readWorkspaceDepartmentId,
  setWorkspaceDepartmentId,
  WORKSPACE_CONTEXT_EVENT,
} from "@/lib/workspace-context";
import { useAuth } from "@/hooks/useAuth";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { DepartmentWorkspaceQueues } from "@/components/dashboards/DepartmentWorkspaceQueues";
import { cn } from "@/lib/utils";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";

const toneClasses = {
  default: "border-border",
  attention: "border-amber-500/50",
  critical: "border-destructive/50",
};

export function DepartmentLeadDashboard() {
  const { role, permissions } = useAuth();
  const isAdmin = role === "admin";
  const navigate = useNavigate({ from: "/dashboards/" });
  const search = useSearch({ from: "/_authenticated/dashboards/" });
  const availableDepartments = useMemo(() => getPermittedDepartments(role, permissions), [permissions, role]);

  const [workspaceDeptId, setWorkspaceDeptId] = useState<string | null>(() => readWorkspaceDepartmentId());

  useEffect(() => {
    const syncWorkspace = () => setWorkspaceDeptId(readWorkspaceDepartmentId());
    window.addEventListener(WORKSPACE_CONTEXT_EVENT, syncWorkspace);
    window.addEventListener("storage", syncWorkspace);
    return () => {
      window.removeEventListener(WORKSPACE_CONTEXT_EVENT, syncWorkspace);
      window.removeEventListener("storage", syncWorkspace);
    };
  }, []);

  const mappedFromContext = canonicalToDashboardDepartment(workspaceDeptId);
  const requestedDepartment = departmentDefinitions.some((department) => department.id === search.department)
    ? (search.department as DashboardDepartment)
    : undefined;

  // Active selection: For non-admins, strictly lock to their mapped assigned workspace.
  // For admins, honor URL search param if present, then top workspace context, then first available.
  const activeSelection: DashboardDepartment = !isAdmin && mappedFromContext
    ? mappedFromContext
    : requestedDepartment && availableDepartments.some((d) => d.id === requestedDepartment)
    ? requestedDepartment
    : mappedFromContext && availableDepartments.some((d) => d.id === mappedFromContext)
    ? mappedFromContext
    : availableDepartments[0]?.id ?? "rnd";

  const activeDepartment =
    availableDepartments.find((department) => department.id === activeSelection) ??
    availableDepartments[0];

  const dashboard = useQuery({
    queryKey: ["department_dashboard", activeDepartment?.id],
    queryFn: () => fetchDepartmentDashboard(activeDepartment?.id ?? "rnd"),
    enabled: Boolean(activeDepartment),
  });

  if (!availableDepartments.length) {
    return (
      <section className="mx-auto max-w-lg py-20 text-center">
        <h1 className="text-xl font-semibold">Department access required</h1>
        <p className="mt-2 text-sm text-muted-foreground">
          Your account does not currently have access to a department workspace.
        </p>
      </section>
    );
  }

  const changeDepartment = (department: DashboardDepartment) => {
    const canonicalId = dashboardToCanonicalDepartment(department);
    setWorkspaceDepartmentId(canonicalId);
    void navigate({ search: { department } });
  };

  const quickAccess = activeDepartment
    ? buildQuickAccess(
        activeDepartment.id,
        dashboard.data?.actions ?? [],
        dashboard.data?.departmentId ?? null
      )
    : [];

  return (
    <div className="mx-auto max-w-7xl space-y-6">
      <section className="flex flex-col gap-4 border-b pb-6 lg:flex-row lg:items-end lg:justify-between">
        <div>
          <p className="text-sm font-medium text-primary">
            {isAdmin ? "Platform oversight" : "Lead workspace"}
          </p>
          <h1 className="mt-1 text-2xl font-semibold">
            {activeDepartment?.label ?? "Department"} workspace
          </h1>
          <p className="mt-2 max-w-3xl text-sm text-muted-foreground">
            One daily page for team work, approvals, requests, projects, and documents.
          </p>
        </div>

        {/* Only show department selector dropdown if admin AND multiple departments are available */}
        {isAdmin && availableDepartments.length > 1 ? (
          <div className="w-full sm:w-64">
            <p className="mb-1.5 text-xs font-medium text-muted-foreground">Switch Department View</p>
            <Select
              value={activeDepartment?.id}
              onValueChange={(value) => changeDepartment(value as DashboardDepartment)}
            >
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {availableDepartments.map((department) => (
                  <SelectItem key={department.id} value={department.id}>
                    {department.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
        ) : (
          <div className="flex items-center gap-2 rounded-lg border bg-muted/40 px-3.5 py-2 text-xs font-medium text-foreground/80 self-start lg:self-end">
            <Building2 className="size-4 text-primary shrink-0" />
            <span>{activeDepartment?.label} Workspace</span>
          </div>
        )}
      </section>

      {isAdmin && (
        <div className="flex items-center gap-2 border border-primary/30 bg-primary/5 px-4 py-3 text-sm text-muted-foreground">
          <ShieldCheck className="size-4 shrink-0 text-primary" />
          Viewing {departmentAccessLabel(activeDepartment?.label ?? "department")}. This changes the page context only; your platform authorization remains unchanged.
        </div>
      )}

      {dashboard.isLoading && (
        <div className="flex min-h-56 items-center justify-center text-sm text-muted-foreground">
          <Loader2 className="mr-2 size-4 animate-spin" /> Loading department workspace…
        </div>
      )}

      {dashboard.isError && (
        <Card>
          <CardContent className="flex items-center gap-3 p-5 text-sm">
            <CircleAlert className="size-5 text-destructive" />
            This workspace could not be loaded. Refresh and try again.
          </CardContent>
        </Card>
      )}

      {dashboard.data && activeDepartment && (
        <>
          <section>
            <div className="mb-3">
              <h2 className="text-lg font-semibold">Quick access</h2>
              <p className="mt-1 text-sm text-muted-foreground">Go directly to the management area you need.</p>
            </div>
            <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
              {quickAccess.map((item) => (
                <Link
                  key={item.label}
                  to={item.to}
                  search={item.to === "/drive" ? { department: dashboard.data.departmentId ?? undefined } : undefined}
                  className={cn(
                    "group flex min-h-28 flex-col justify-between border p-4 transition-colors hover:bg-muted/60",
                    item.tone && toneClasses[item.tone]
                  )}
                >
                  <item.icon className="size-5 text-primary" />
                  <div className="mt-4">
                    <p className="font-medium">{item.label}</p>
                    <p className="mt-1 text-sm text-muted-foreground">{item.detail}</p>
                  </div>
                  <ArrowUpRight className="mt-3 size-4 text-muted-foreground transition-transform group-hover:translate-x-0.5 group-hover:-translate-y-0.5" />
                </Link>
              ))}
            </div>
          </section>

          <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
            {dashboard.data.metrics.map((metric) => (
              <Card key={metric.label} className={cn("border-l-4", toneClasses[metric.tone ?? "default"])}>
                <CardContent className="p-4">
                  <p className="text-sm text-muted-foreground">{metric.label}</p>
                  <p className="mt-1 text-3xl font-semibold">{metric.value}</p>
                  <p className="mt-1 text-xs text-muted-foreground">{metric.detail}</p>
                </CardContent>
              </Card>
            ))}
          </div>

          <div className="grid gap-4 lg:grid-cols-[1fr_1.3fr]">
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2">
                  <FileText className="size-5 text-primary" /> Department documents
                </CardTitle>
                <CardDescription>
                  {dashboard.data.documentCount} controlled file{dashboard.data.documentCount === 1 ? "" : "s"} available to this workspace.
                </CardDescription>
              </CardHeader>
              <CardContent className="space-y-2">
                {dashboard.data.recentDocuments.length ? (
                  dashboard.data.recentDocuments.map((document) => (
                    <Link
                      key={document.id}
                      to="/drive"
                      search={{ node: document.id, department: dashboard.data.departmentId ?? undefined }}
                      className="flex items-center justify-between border px-3 py-2 text-sm hover:bg-muted/60"
                    >
                      <span className="truncate font-medium">{document.name}</span>
                      <span className="ml-3 shrink-0 text-xs text-muted-foreground">
                        {new Date(document.updatedAt).toLocaleDateString()}
                      </span>
                    </Link>
                  ))
                ) : (
                  <p className="text-sm text-muted-foreground">No files have been added yet.</p>
                )}
              </CardContent>
            </Card>

            <DepartmentWorkspaceQueues department={activeDepartment.id} />
          </div>

          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <BarChart3 className="size-5 text-primary" /> Workload pulse
              </CardTitle>
              <CardDescription>Open, blocked, and overdue work that needs lead attention.</CardDescription>
            </CardHeader>
            <CardContent className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
              {dashboard.data.workload.map((item) => (
                <div key={item.label} className="border p-4">
                  <div className="flex items-center justify-between">
                    <span className="text-sm font-medium">{item.label}</span>
                    <span className="text-sm text-muted-foreground">{item.open} open</span>
                  </div>
                  <div className="mt-4 grid grid-cols-3 gap-2 text-center">
                    <div>
                      <p className="font-semibold">{item.open}</p>
                      <p className="text-xs text-muted-foreground">Open</p>
                    </div>
                    <div className="border-x px-1">
                      <p className="font-semibold text-destructive">{item.blocked}</p>
                      <p className="text-xs text-muted-foreground">Blocked</p>
                    </div>
                    <div>
                      <p className="font-semibold text-amber-700 dark:text-amber-400">{item.overdue}</p>
                      <p className="text-xs text-muted-foreground">Overdue</p>
                    </div>
                  </div>
                </div>
              ))}
            </CardContent>
          </Card>
        </>
      )}
    </div>
  );
}

type QuickAccessItem = {
  label: string;
  detail: string;
  to: string;
  icon: typeof CheckSquare;
  tone?: "default" | "attention" | "critical";
};

function buildQuickAccess(
  department: DashboardDepartment,
  actions: { label: string; detail: string; to: string; tone?: "default" | "attention" | "critical" }[],
  departmentId: string | null
): QuickAccessItem[] {
  const core = [
    { label: "Team tasks", detail: "Assign work and update due dates.", to: "/tasks", icon: CheckSquare },
    { label: "Projects", detail: "Review delivery, ownership, and progress.", to: "/projects", icon: FolderKanban },
    {
      label: "Approvals",
      detail: "Open the established decision queue.",
      to: department === "procurement" ? "/procurement/requests" : "/projects",
      icon: ClipboardCheck,
    },
    {
      label: "Documents",
      detail: departmentId ? "Open this department’s controlled files." : "Open controlled project files and links.",
      to: "/drive",
      icon: FileText,
    },
  ];
  const departmentActions = actions.map((action) => ({
    ...action,
    icon:
      action.to.includes("inventory") || action.to.includes("stores") || action.to.includes("inward")
        ? PackageSearch
        : UsersRound,
  }));
  return [...core, ...departmentActions.filter((action) => !core.some((item) => item.to === action.to))].slice(0, 8);
}