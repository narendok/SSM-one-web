import { useMemo, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import {
  Layers,
  Eye,
  Lock,
  CheckCircle2,
  AlertTriangle,
  CircuitBoard,
  ExternalLink,
  ShieldCheck,
  Check,
} from "lucide-react";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Progress } from "@/components/ui/progress";
import { fetchCanonicalDepartments, fetchTasks, statusLabel, taskAssigneeLabel } from "@/lib/tasks";
import type { Project } from "@/lib/projects";
import { ProjectRequirementContext } from "./ProjectOperationalTabs";

const defaultDepartmentProfiles = [
  {
    code: "EHW",
    name: "Embedded Electronics Engineering",
    title: "Proposed STM32 MCU & RS485 Interface",
    status: "In review",
    lead: "Avery Vale",
    internalRemark: "Evaluate board reuse (PCB-CTRL R3) and connector footprint before freezing pilot BOM.",
    clientHighlight: "MCU architecture and RS485 interface variant proposed for OEM technical baseline.",
    nextAction: "Confirm MCU peripheral and pin mapping with Firmware team.",
  },
  {
    code: "ESW",
    name: "Embedded Firmware Engineering",
    title: "RTOS Kernel & CAN J1939 Driver",
    status: "In progress",
    lead: "Devon Lane",
    internalRemark: "Review MCU peripherals, driver support and provisional register map against selected circuitry.",
    clientHighlight: "Firmware compatibility assessment underway. Dual-bank secure FOTA architecture configured.",
    nextAction: "Validate controller drivers following PCB controller peripheral map.",
  },
  {
    code: "MECH",
    name: "Mechanical Engineering",
    title: "IP67 Enclosure Sealing & Harness CAD",
    status: "Blocked",
    lead: "Samira Holt",
    internalRemark: "Resolve gasket tolerance and prepare enclosure seal sample for IP67 water ingress tests.",
    clientHighlight: "Enclosure 3D CAD modeling active. Tooling and ingress sealing validation pending test sample.",
    nextAction: "Prepare and hand over seal sample to QA.",
  },
  {
    code: "PUR",
    name: "Purchasing & SCM",
    title: "Dual-Track Component Sourcing & AVL",
    status: "In progress",
    lead: "Morgan Reed",
    internalRemark: "Connector availability and lead-time review underway; Mouser component intelligence synced.",
    clientHighlight: "Critical parts availability verified on Approved Vendor List (AVL).",
    nextAction: "Reconcile supplier quotes for engineering BOM freeze.",
  },
  {
    code: "QA",
    name: "Quality Assurance & APQP",
    title: "IATF 16949 / DVP&R / Ingress Testing",
    status: "Waiting",
    lead: "Jordan Blake",
    internalRemark: "Cannot complete ingress chamber run until Mechanical submits physical seal sample.",
    clientHighlight: "DVP&R matrix active with 18 electrical/environmental test suites mapped.",
    nextAction: "Execute 24-hour IP67 ingress testing upon sample receipt.",
  },
  {
    code: "EMF",
    name: "Electronics Manufacturing",
    title: "SMT Line 2 Setup & Thermal Profiling",
    status: "Planned",
    lead: "Casey Rowan",
    internalRemark: "SMT line thermal profile ready for 10-zone reflow once PCB fabrication batch arrives.",
    clientHighlight: "Process Control Plan and automated optical inspection (AOI) criteria prepared.",
    nextAction: "Conduct pilot stencil validation.",
  },
  {
    code: "TST",
    name: "Production & EOL Testing",
    title: "Automated FCT Jigs & Flashing Rigs",
    status: "Planned",
    lead: "Mina Cross",
    internalRemark: "Test jigs require stable CAN harness pinout from Mechanical CAD.",
    clientHighlight: "100% PDI inspection protocol and automated test jig ready for pilot run.",
    nextAction: "Finalize jig harness pinout alignment.",
  },
  {
    code: "FIN",
    name: "Accounts & Finance",
    title: "Project Budget & Commercial Costing",
    status: "In progress",
    lead: "Priya Voss",
    internalRemark: "Pilot batch expenditure tracking within approved margin targets.",
    clientHighlight: "Commercial milestone billing and tax invoicing schedule aligned with client PO.",
    nextAction: "Reconcile pilot PO spending commitments.",
  },
];

export function ProjectAnalysisSummary({ project }: { project: Project }) {
  const [viewMode, setViewMode] = useState<"internal" | "client">("internal");
  const [diagramMode, setDiagramMode] = useState<"concept" | "diagram">("concept");
  const [taskDeptFilter, setTaskDeptFilter] = useState("all");
  const [taskStatusFilter, setTaskStatusFilter] = useState("all");
  const [taskSearch, setTaskSearch] = useState("");

  const departments = useQuery({
    queryKey: ["canonical_departments"],
    queryFn: fetchCanonicalDepartments,
  });

  const tasks = useQuery({
    queryKey: ["project_tasks", project.id, "all-departments"],
    queryFn: () => fetchTasks(project.id),
  });

  const visibleTasks = tasks.data ?? [];
  const blockedTasks = visibleTasks.filter((t) => t.status === "blocked");
  const nextTask = visibleTasks
    .filter((t) => t.status !== "done")
    .sort((a, b) => (a.due_date ?? "9999").localeCompare(b.due_date ?? "9999"))[0];
  const unavailable = tasks.isError || tasks.isPending;

  let designReference: string | null = null;
  try {
    const url = new URL(project.design_link ?? "");
    if (["https:", "http:"].includes(url.protocol) && !url.username && !url.password) {
      designReference = url.href;
    }
  } catch {
    // Missing or invalid reference
  }

  const filteredTasks = useMemo(() => {
    return visibleTasks.filter((t) => {
      const matchDept = taskDeptFilter === "all" || t.department_id === taskDeptFilter;
      const matchStatus = taskStatusFilter === "all" || t.status === taskStatusFilter;
      const matchSearch =
        !taskSearch.trim() ||
        t.title.toLowerCase().includes(taskSearch.toLowerCase()) ||
        (t.description ?? "").toLowerCase().includes(taskSearch.toLowerCase());
      return matchDept && matchStatus && matchSearch;
    });
  }, [visibleTasks, taskDeptFilter, taskStatusFilter, taskSearch]);

  const completionPercent = useMemo(() => {
    if (!visibleTasks.length) return 25; // Approved illustrative baseline
    const completed = visibleTasks.filter((t) => t.status === "done").length;
    return Math.round((completed / visibleTasks.length) * 100);
  }, [visibleTasks]);

  return (
    <section aria-label="Common project analysis" className="space-y-4">
      {/* 1. Header Toolbar with Mode Switch */}
      <div className="flex flex-wrap items-center justify-between gap-3 border-b pb-3">
        <div className="flex items-center gap-2">
          <div className="flex size-8 items-center justify-center rounded-lg bg-primary/10 text-primary">
            <Layers className="size-4" />
          </div>
          <div>
            <div className="flex items-center gap-2">
              <h2 className="text-base font-bold uppercase tracking-tight">Common project analysis</h2>
              <Badge variant="outline">{viewMode === "internal" ? "Internal view" : "Client view"}</Badge>
            </div>
            <p className="text-xs text-muted-foreground">
              Master Plan §5 & §10 · Page 1 Cross-Department Governance & Client Alignment
            </p>
          </div>
        </div>

        <div className="flex items-center gap-2">
          <Button
            type="button"
            size="sm"
            variant={viewMode === "internal" ? "default" : "outline"}
            onClick={() => setViewMode("internal")}
            className="h-8 gap-1.5 text-xs font-semibold"
          >
            <Lock className="size-3.5" />
            <span>Internal view</span>
          </Button>
          <Button
            type="button"
            size="sm"
            variant={viewMode === "client" ? "default" : "outline"}
            onClick={() => setViewMode("client")}
            className="h-8 gap-1.5 text-xs font-semibold"
          >
            <Eye className="size-3.5" />
            <span>Client preview</span>
          </Button>
        </div>
      </div>

      {viewMode === "client" && (
        <div className="flex items-center justify-between rounded-lg border border-emerald-500/30 bg-emerald-500/10 p-3 text-xs text-emerald-600 dark:text-emerald-400">
          <div className="flex items-center gap-2 font-medium">
            <ShieldCheck className="size-4" />
            <span>Client-Safe Filter Active: Internal company costing, private remarks, and confidential tasks are hidden.</span>
          </div>
          <Badge variant="outline" className="border-emerald-500/40 text-emerald-600">
            OEM Portal View
          </Badge>
        </div>
      )}

      {/* Linked baseline context */}
      <ProjectRequirementContext projectId={project.id} baselineId={project.requirement_baseline_id} />

      {/* Recorded project context */}
      <Card className="flex flex-wrap items-center justify-between gap-2 p-3" aria-label="Recorded project context">
        <div>
          <h3 className="text-xs font-semibold uppercase">Recorded project context</h3>
          <p className="mt-1 text-sm">
            {project.project_type?.replaceAll("_", " ") || "Project type not recorded"} ·{" "}
            {project.revision?.trim() ? `Revision ${project.revision}` : "Revision not recorded"}
          </p>
        </div>
        {designReference ? (
          <a
            href={designReference}
            target="_blank"
            rel="noopener noreferrer"
            className="text-sm text-primary underline underline-offset-4"
          >
            Open design reference
          </a>
        ) : (
          <p className="text-xs text-muted-foreground">Design reference unavailable</p>
        )}
      </Card>

      {/* 2. Executive KPI Strip */}
      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        <Card className="p-3">
          <p className="text-xs font-medium uppercase text-muted-foreground">Workflow completion</p>
          <div className="mt-2 flex items-baseline justify-between">
            <span className="text-2xl font-bold text-emerald-600 dark:text-emerald-400">
              {completionPercent}%
            </span>
            <span className="text-xs text-muted-foreground">
              {visibleTasks.filter((t) => t.status === "done").length} of {visibleTasks.length || 4} steps
            </span>
          </div>
          <Progress className="mt-2 h-1.5" value={completionPercent} />
        </Card>

        <Card className="p-3">
          <h3 className="text-xs font-semibold uppercase text-muted-foreground">Current phase</h3>
          <p className="mt-2 text-base font-semibold capitalize">
            {project.project_stage?.replaceAll("_", " ") || "Pilot preparation"}
          </p>
          <p className="text-xs text-muted-foreground">
            {project.health_status} · {project.priority} priority
          </p>
        </Card>

        <Card className="p-3">
          <h3 className="text-xs font-semibold uppercase text-muted-foreground">Visible blockers</h3>
          <p className="mt-2 text-sm font-semibold text-rose-600 dark:text-rose-400">
            {unavailable
              ? "Task data unavailable"
              : blockedTasks.length
              ? blockedTasks.map((t) => t.title).join(" · ")
              : "No blocked tasks visible"}
          </p>
          <p className="text-xs text-muted-foreground">
            Task status does not establish lifecycle gate clearance.
          </p>
        </Card>

        <Card className="p-3">
          <h3 className="text-xs font-semibold uppercase text-muted-foreground">Next open work</h3>
          <p className="mt-2 text-sm font-semibold">
            {unavailable
              ? "Task data unavailable"
              : nextTask?.status !== "blocked"
              ? nextTask?.title ?? "No open tasks visible"
              : "No open tasks visible"}
          </p>
          <p className="text-xs text-muted-foreground">
            {!unavailable && nextTask && nextTask.status !== "blocked"
              ? `${taskAssigneeLabel(nextTask)} · ${nextTask.due_date ?? "No due date"} · ${statusLabel(nextTask.status)}`
              : "Task queue clear"}
          </p>
        </Card>
      </div>

      {/* 3. Approved Requirements & Client Change Proposal */}
      <div className="grid gap-3 md:grid-cols-3">
        <Card className="p-4 md:col-span-2">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <span className="font-bold text-sm">Approved Requirements</span>
              <Badge variant="outline" className="border-emerald-500/40 text-emerald-600">
                Locked · R1 Baseline
              </Badge>
            </div>
            {designReference && (
              <a
                href={designReference}
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex items-center gap-1 text-xs text-primary hover:underline"
              >
                <span>Design reference</span>
                <ExternalLink className="size-3" />
              </a>
            )}
          </div>
          <div className="mt-3 grid grid-cols-2 gap-3 sm:grid-cols-4">
            <div className="rounded-lg border bg-muted/30 p-2.5">
              <p className="text-[11px] text-muted-foreground">Operating Supply</p>
              <p className="text-sm font-bold">24 V DC (12–36V)</p>
            </div>
            <div className="rounded-lg border bg-muted/30 p-2.5">
              <p className="text-[11px] text-muted-foreground">Ingress Protection</p>
              <p className="text-sm font-bold">IP65 (Gasket sealed)</p>
            </div>
            <div className="rounded-lg border bg-muted/30 p-2.5">
              <p className="text-[11px] text-muted-foreground">Communication</p>
              <p className="text-sm font-bold">RS485 + Dual CAN</p>
            </div>
            <div className="rounded-lg border bg-muted/30 p-2.5">
              <p className="text-[11px] text-muted-foreground">Pilot Batch Quantity</p>
              <p className="text-sm font-bold">100 units</p>
            </div>
          </div>
        </Card>

        <Card className="border-amber-500/30 bg-amber-500/5 p-4">
          <div className="flex items-center gap-2">
            <AlertTriangle className="size-4 text-amber-600" />
            <span className="text-sm font-bold text-amber-700 dark:text-amber-400">
              Latest Client Proposal
            </span>
          </div>
          <p className="mt-2 text-xs font-semibold">
            Proposed Spec Upgrade: <span className="underline">IP65 → IP67 Submersion</span>
          </p>
          <p className="mt-1 text-xs text-muted-foreground">
            Client submitted revision proposal. R1 baseline remains strictly locked until feasibility, tooling costing, and DVP&R acceptance pass.
          </p>
        </Card>
      </div>

      {/* 4. Interactive Concept / Block Diagram Architecture */}
      <Card className="p-4">
        <div className="flex flex-wrap items-center justify-between gap-3 border-b pb-3">
          <div>
            <h3 className="text-sm font-bold">System Architecture & Engineering Concept</h3>
            <p className="text-xs text-muted-foreground">
              Physical circuitry topology, controller interfaces, and power routing
            </p>
          </div>
          <div className="flex gap-1 rounded-lg border bg-muted/40 p-1">
            <Button
              type="button"
              size="sm"
              variant={diagramMode === "concept" ? "default" : "ghost"}
              onClick={() => setDiagramMode("concept")}
              className="h-7 text-xs"
            >
              Enclosure Concept
            </Button>
            <Button
              type="button"
              size="sm"
              variant={diagramMode === "diagram" ? "default" : "ghost"}
              onClick={() => setDiagramMode("diagram")}
              className="h-7 text-xs"
            >
              Block Diagram
            </Button>
          </div>
        </div>

        <div className="mt-4 flex min-h-[180px] items-center justify-center rounded-lg border bg-gradient-to-br from-muted/30 to-muted/10 p-4">
          {diagramMode === "concept" ? (
            <svg viewBox="0 0 520 220" className="max-h-[170px] w-full max-w-[500px]" role="img" aria-label="Concept gateway enclosure">
              <ellipse cx="265" cy="190" rx="150" ry="15" fill="currentColor" className="text-muted/40" />
              <path d="M120 60L330 32L410 80L200 115Z" fill="currentColor" className="text-primary/10 stroke-primary" strokeWidth="2" />
              <path d="M120 60L200 115V180L120 130Z" fill="currentColor" className="text-primary/20 stroke-primary" strokeWidth="2" />
              <path d="M200 115L410 80V150L200 180Z" fill="currentColor" className="text-primary/30 stroke-primary" strokeWidth="2" />
              <rect x="240" y="130" width="55" height="22" rx="3" fill="#1e293b" />
              <circle cx="330" cy="130" r="6" fill="#10b981" />
              <circle cx="355" cy="127" r="6" fill="#38bdf8" />
              <text x="210" y="70" fill="currentColor" className="text-xs font-bold" fontSize="12">SENSOR GATEWAY IP67</text>
              <text x="30" y="205" fill="currentColor" className="text-muted-foreground" fontSize="11">Concept Enclosure · 24V / RS485 Dual CAN</text>
            </svg>
          ) : (
            <svg viewBox="0 0 520 200" className="max-h-[170px] w-full max-w-[500px]" role="img" aria-label="System block diagram">
              <g fill="currentColor" className="text-muted/20 stroke-primary" strokeWidth="1.5">
                <rect x="15" y="70" width="105" height="55" rx="8" />
                <rect x="195" y="70" width="130" height="55" rx="8" />
                <rect x="390" y="70" width="115" height="55" rx="8" />
                <rect x="195" y="10" width="130" height="40" rx="8" />
                <path d="M120 98H195M325 98H390M260 50V70" />
              </g>
              <g fontSize="12" textAnchor="middle" fill="currentColor">
                <text x="67" y="102" className="font-semibold">Sensors (IO)</text>
                <text x="260" y="93" className="font-bold text-primary">STM32 MCU</text>
                <text x="260" y="112" className="text-[10px] text-muted-foreground">Main Controller</text>
                <text x="447" y="93" className="font-semibold">RS485 / CAN</text>
                <text x="447" y="112" className="text-[10px] text-muted-foreground">Telemetry Stack</text>
                <text x="260" y="34" className="font-semibold">24V Power Supply</text>
              </g>
            </svg>
          )}
        </div>
      </Card>

      {/* 5. Progress & Dependencies Track (4 Steps) */}
      <Card className="p-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <span className="font-bold text-sm">Progress & Lifecycle Gate Dependencies</span>
            <Badge variant="outline">Step 2 of 4</Badge>
          </div>
          <span className="text-xs text-muted-foreground">Next Gate: Ingress Chamber Test</span>
        </div>

        <div className="mt-4 grid grid-cols-1 items-center gap-2 sm:grid-cols-4">
          <div className="flex items-center gap-3 rounded-lg border border-emerald-500/40 bg-emerald-500/10 p-3">
            <div className="flex size-7 items-center justify-center rounded-full bg-emerald-600 text-white">
              <Check className="size-4" />
            </div>
            <div>
              <p className="text-xs font-bold text-emerald-800 dark:text-emerald-300">1. Requirements</p>
              <p className="text-[11px] text-muted-foreground">Locked · R1 baseline</p>
            </div>
          </div>

          <div className="flex items-center gap-3 rounded-lg border border-rose-500/40 bg-rose-500/10 p-3">
            <div className="flex size-7 items-center justify-center rounded-full bg-rose-600 text-white">
              <AlertTriangle className="size-4" />
            </div>
            <div>
              <p className="text-xs font-bold text-rose-800 dark:text-rose-300">2. Seal Sample</p>
              <p className="text-[11px] text-muted-foreground">Blocked · Mechanical</p>
            </div>
          </div>

          <div className="flex items-center gap-3 rounded-lg border bg-muted/40 p-3 opacity-75">
            <div className="flex size-7 items-center justify-center rounded-full bg-muted text-muted-foreground font-bold text-xs">
              3
            </div>
            <div>
              <p className="text-xs font-bold">3. Ingress Test</p>
              <p className="text-[11px] text-muted-foreground">Waiting · Quality APQP</p>
            </div>
          </div>

          <div className="flex items-center gap-3 rounded-lg border bg-muted/40 p-3 opacity-75">
            <div className="flex size-7 items-center justify-center rounded-full bg-muted text-muted-foreground font-bold text-xs">
              4
            </div>
            <div>
              <p className="text-xs font-bold">4. Pilot Release</p>
              <p className="text-[11px] text-muted-foreground">Waiting · Sign-off</p>
            </div>
          </div>
        </div>
      </Card>

      {/* 6. System Configuration: Modular Platform Electronic Subsystems Reuse */}
      <Card className="p-4">
        <div className="flex items-center justify-between border-b pb-2">
          <div className="flex items-center gap-2">
            <CircuitBoard className="size-4 text-primary" />
            <h3 className="text-sm font-bold">Modular Platform Electronics Reuse</h3>
          </div>
          <Badge variant="outline" className="text-xs">
            Decoupled Architecture (Master Plan §6)
          </Badge>
        </div>

        <div className="mt-3 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <div className="rounded-lg border p-3">
            <div className="flex items-center justify-between">
              <span className="font-bold text-xs">PCB-CTRL R3</span>
              <Badge variant="secondary" className="bg-emerald-500/10 text-emerald-600 text-[10px]">
                Reuse Proposed
              </Badge>
            </div>
            <p className="mt-1 text-xs text-muted-foreground">Main Controller (STM32)</p>
            <p className="mt-2 text-[11px] text-muted-foreground">
              FW-GATEWAY 2.4 compatibility verified.
            </p>
          </div>

          <div className="rounded-lg border p-3">
            <div className="flex items-center justify-between">
              <span className="font-bold text-xs">PCB-IO R2</span>
              <Badge variant="secondary" className="bg-emerald-500/10 text-emerald-600 text-[10px]">
                Reuse Proposed
              </Badge>
            </div>
            <p className="mt-1 text-xs text-muted-foreground">Sensor Expansion Board</p>
            <p className="mt-2 text-[11px] text-muted-foreground">
              RS485 transceiver interface verified.
            </p>
          </div>

          <div className="rounded-lg border p-3">
            <div className="flex items-center justify-between">
              <span className="font-bold text-xs">HARNESS-PWR R2</span>
              <Badge variant="secondary" className="bg-emerald-500/10 text-emerald-600 text-[10px]">
                Reuse Proposed
              </Badge>
            </div>
            <p className="mt-1 text-xs text-muted-foreground">24V Input Harness</p>
            <p className="mt-2 text-[11px] text-muted-foreground">
              Automotive grade cross-section wired.
            </p>
          </div>

          <div className="rounded-lg border p-3">
            <div className="flex items-center justify-between">
              <span className="font-bold text-xs">Telemetry Gateway 1.8</span>
              <Badge variant="secondary" className="bg-blue-500/10 text-blue-600 text-[10px]">
                Adapt Config
              </Badge>
            </div>
            <p className="mt-1 text-xs text-muted-foreground">Telemetry & Register Map</p>
            <p className="mt-2 text-[11px] text-muted-foreground">
              Custom register map configured.
            </p>
          </div>
        </div>
      </Card>

      {/* 7. Canonical Department Workstreams & Task Grouping */}
      <details open className="rounded-lg border bg-card p-4">
        <summary className="cursor-pointer text-sm font-semibold">
          Department workstreams
        </summary>
        <p className="my-2 text-xs text-muted-foreground">
          Visible project tasks grouped by canonical department. This summary grants no editing authority.
        </p>

        {departments.isPending ? (
          <p className="text-xs text-muted-foreground">Loading departments…</p>
        ) : departments.isError ? (
          <p role="alert" className="text-xs text-destructive">Department records unavailable.</p>
        ) : tasks.isError ? (
          <p role="alert" className="text-xs text-destructive">Department task summaries unavailable.</p>
        ) : tasks.isPending ? (
          <p className="text-xs text-muted-foreground">Loading project tasks…</p>
        ) : (
          <div className="grid gap-3 md:grid-cols-2 xl:grid-cols-3">
            {departments.data.map((department) => {
              const scoped = visibleTasks.filter((task) => task.department_id === department.id);
              return (
                <details key={department.id} className="rounded-md border p-3" open={scoped.length > 0}>
                  <summary className="cursor-pointer text-sm font-medium">
                    {department.name}{" "}
                    <span className="text-muted-foreground">· {scoped.length} visible tasks</span>
                  </summary>
                  {scoped.length ? (
                    <ul className="mt-2 space-y-2 text-sm">
                      {scoped.map((task) => (
                        <li key={task.id} className="rounded border bg-muted/20 p-2">
                          <span className="font-medium text-xs">{task.title}</span>
                          <p className="text-[11px] text-muted-foreground">
                            {statusLabel(task.status)} · {taskAssigneeLabel(task)} ·{" "}
                            {task.due_date ?? "No due date"}
                          </p>
                        </li>
                      ))}
                    </ul>
                  ) : (
                    <p className="mt-2 text-xs text-muted-foreground">No visible project tasks.</p>
                  )}
                  <div className="mt-3 space-y-1 text-xs text-muted-foreground border-t pt-2">
                    <p>Internal remarks: shared read contract pending.</p>
                    <p>Client highlights: publication contract pending.</p>
                  </div>
                </details>
              );
            })}
          </div>
        )}

        {!unavailable && visibleTasks.some((task) => !task.department_id) && (
          <p className="mt-2 text-xs text-muted-foreground">
            Tasks without a canonical department remain on the common task board.
          </p>
        )}
      </details>

      {/* 8. 11-Department Workstreams & Dual Remarks Matrix */}
      <Card className="p-4">
        <div className="flex items-center justify-between border-b pb-3">
          <div>
            <h3 className="text-sm font-bold">11-Department Workstreams & Dual Remarks Matrix</h3>
            <p className="text-xs text-muted-foreground">
              Synchronized cross-department remarks with strict company vs. client visibility separation
            </p>
          </div>
          <Badge variant="outline">
            {defaultDepartmentProfiles.length} Functional Disciplines
          </Badge>
        </div>

        <div className="mt-4 grid gap-3 sm:grid-cols-2 lg:grid-cols-2">
          {defaultDepartmentProfiles.map((dept) => (
            <Card key={dept.code} className="p-3.5 space-y-2.5">
              <div className="flex items-center justify-between">
                <div>
                  <span className="font-bold text-xs">{dept.code} · {dept.name} Discipline</span>
                  <p className="text-[11px] text-muted-foreground">{dept.title}</p>
                </div>
                <Badge
                  variant={dept.status === "Blocked" ? "destructive" : dept.status === "In review" ? "secondary" : "outline"}
                  className="text-[10px]"
                >
                  {dept.status}
                </Badge>
              </div>

              {/* Dual Remarks */}
              <div className="space-y-2 pt-1 text-xs">
                {viewMode === "internal" && (
                  <div className="rounded-md border border-slate-700/50 bg-slate-900/60 p-2.5">
                    <p className="text-[10px] font-bold uppercase text-amber-500/90">
                      🔒 Internal Remark · Company-Confidential
                    </p>
                    <p className="mt-1 text-slate-300">{dept.internalRemark}</p>
                  </div>
                )}
                <div className="rounded-md border border-emerald-500/30 bg-emerald-500/5 p-2.5">
                  <p className="text-[10px] font-bold uppercase text-emerald-600 dark:text-emerald-400">
                    🌐 Client's Remarks · Shared OEM Status
                  </p>
                  <p className="mt-1 text-muted-foreground">{dept.clientHighlight}</p>
                </div>
              </div>

              <div className="flex items-center justify-between border-t pt-2 text-[11px] text-muted-foreground">
                <span>Lead: {dept.lead}</span>
                <span className="truncate max-w-[200px]">Next: {dept.nextAction}</span>
              </div>
            </Card>
          ))}
        </div>
      </Card>

      {/* 9. Interactive Task Board View */}
      {viewMode === "internal" && (
        <Card className="p-4 space-y-3">
          <div className="flex flex-wrap items-center justify-between gap-2 border-b pb-2">
            <div>
              <h3 className="text-sm font-bold">Project Team Tasks</h3>
              <p className="text-xs text-muted-foreground">
                {filteredTasks.length} visible tasks in project workspace
              </p>
            </div>
            <div className="flex flex-wrap gap-2 text-xs">
              <Input
                placeholder="Find task..."
                value={taskSearch}
                onChange={(e) => setTaskSearch(e.target.value)}
                className="h-8 w-40 text-xs"
              />
              <select
                value={taskStatusFilter}
                onChange={(e) => setTaskStatusFilter(e.target.value)}
                className="h-8 rounded-md border bg-background px-2 text-xs"
              >
                <option value="all">All statuses</option>
                <option value="todo">To do</option>
                <option value="in_progress">In progress</option>
                <option value="in_review">In review</option>
                <option value="blocked">Blocked</option>
                <option value="done">Done</option>
              </select>
              {(taskSearch || taskStatusFilter !== "all" || taskDeptFilter !== "all") && (
                <Button
                  size="sm"
                  variant="ghost"
                  onClick={() => {
                    setTaskSearch("");
                    setTaskStatusFilter("all");
                    setTaskDeptFilter("all");
                  }}
                  className="h-8 text-xs"
                >
                  Reset
                </Button>
              )}
            </div>
          </div>

          <div className="grid gap-2 sm:grid-cols-2 lg:grid-cols-3">
            {filteredTasks.map((t) => (
              <div key={t.id} className="rounded-lg border bg-card p-3 space-y-1.5">
                <div className="flex items-start justify-between gap-2">
                  <span className="text-xs font-semibold line-clamp-1">{t.title}</span>
                  <Badge variant={t.status === "blocked" ? "destructive" : "outline"} className="text-[10px]">
                    {statusLabel(t.status)}
                  </Badge>
                </div>
                {t.description && (
                  <p className="text-[11px] text-muted-foreground line-clamp-2">{t.description}</p>
                )}
                <div className="flex items-center justify-between border-t pt-1.5 text-[10px] text-muted-foreground">
                  <span>{taskAssigneeLabel(t)}</span>
                  <span>{t.due_date ? `Due: ${t.due_date}` : "No due date"}</span>
                </div>
              </div>
            ))}
          </div>
        </Card>
      )}
    </section>
  );
}
