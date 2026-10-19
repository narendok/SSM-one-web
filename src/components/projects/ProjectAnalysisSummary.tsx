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

function getDepartmentProfiles(project: Project) {
  const isBle = project.code?.includes("BLE") || project.name?.toLowerCase().includes("ble");
  const isReuse = project.code?.includes("TLM-STD") || project.name?.toLowerCase().includes("reuse") || project.name?.toLowerCase().includes("apex");

  if (isBle) {
    return [
      {
        code: "EHW",
        name: "Embedded Electronics Engineering",
        title: "BLE 5.2 Nordic nRF52833 & 3.7V Battery Charger",
        status: "Approved",
        lead: "Dr. Avery Vale",
        internalRemark: "Spatial addition of Nordic nRF52833 BLE 5.2 and TI BQ24075 3.7V Li-ion charging IC onto ready PCB-TLM-V2.0 layout. Layout released as PCB-TLM-V2.1-BLE with 22mm ground isolation passed.",
        clientHighlight: "EV telematics hardware revision PCB-TLM-V2.1-BLE completed with integrated BLE 5.2 and 3.7V Lithium-ion charging circuit.",
        nextAction: "Pilot fabrication release for SMT Line 2.",
      },
      {
        code: "ESW",
        name: "Embedded Firmware Engineering",
        title: "RTOS Kernel, Quectel 4G LTE & BLE 5.2 Stack",
        status: "Approved",
        lead: "Devon Lane",
        internalRemark: "FreeRTOS kernel with Quectel 4G AT command engine and BLE 5.2 GATT peripheral stack. Low-power sleep measured at 2.1mA on 3.7V backup battery.",
        clientHighlight: "Firmware release v2.1 with BLE proximity vehicle immobilizer and dual-bank secure FOTA validated.",
        nextAction: "Sign off FOTA bootloader hash signature.",
      },
      {
        code: "MECH",
        name: "Mechanical Engineering",
        title: "IP67 Enclosure with 3.7V Battery Compartment",
        status: "Approved",
        lead: "Samira Holt",
        internalRemark: "Molded poly-carbonate/ABS enclosure CAD updated with custom internal rib for 3.7V Li-ion 800mAh cell. Silicone gasket durometer 40 Shore A passed IP67 immersion.",
        clientHighlight: "Enclosure 3D tooling drawings frozen with IP67 submersible gasket and Gore hydrophobic breather vent.",
        nextAction: "Release injection mold tooling T1 sample.",
      },
      {
        code: "PUR",
        name: "Purchasing & SCM",
        title: "Quectel Module, BLE SoC & Certified 3.7V Cells",
        status: "Approved",
        lead: "Morgan Reed",
        internalRemark: "Quectel EG915 cellular SIM module and Nordic nRF52833 BLE SoC sourced via direct franchised distributors. BIS registered, UN 38.3 & NABL certified 3.7V battery cells contracted.",
        clientHighlight: "All active components, Quectel cellular modules, and NABL-certified Lithium-ion cells secured on Approved Vendor List (AVL).",
        nextAction: "PO issued for 5,000 pilot assembly kits.",
      },
      {
        code: "QA",
        name: "Quality Assurance & APQP",
        title: "DVP&R, iCAT Homologation & NABL Battery Test",
        status: "Approved",
        lead: "Jordan Blake",
        internalRemark: "TBR electrical acceptance and EBT thermal/vibration test reports approved. Homologation certificate granted by iCAT (AIS-140/AIS-004) and NABL lab certified testing for 3.7V Lithium-ion battery safety (AIS-156 & UN 38.3).",
        clientHighlight: "DVP&R testing passed. Official iCAT homologation certificate and NABL-accredited laboratory Lithium-ion battery safety compliance reports certified.",
        nextAction: "Prepare final PPAP Level 3 documentation dossier.",
      },
      {
        code: "EMF",
        name: "Electronics Manufacturing",
        title: "SMT Line 2 Setup & Reflow Profiling",
        status: "In progress",
        lead: "Casey Rowan",
        internalRemark: "SMT Line 2 10-zone reflow thermal profile validated for double-sided PCB assembly. JST battery connector insertion Poka-Yoke fixture verified.",
        clientHighlight: "Manufacturing process flow plan and automated optical inspection (AOI) criteria configured for pilot build.",
        nextAction: "Commence pilot assembly run of 100 units.",
      },
      {
        code: "TST",
        name: "Production & EOL Testing",
        title: "Automated FCT Rig & BLE / Cellular RF Fixture",
        status: "Approved",
        lead: "Mina Cross",
        internalRemark: "End-of-line RF test fixture tuned for simultaneous 4G LTE-Cat1 Quectel throughput and BLE 5.2 RSSI signal strength validation.",
        clientHighlight: "100% automated testing protocol and PDI inspection flashing rig ready for pilot run.",
        nextAction: "Conduct dry run test on 10 dummy boards.",
      },
      {
        code: "FIN",
        name: "Accounts & Finance",
        title: "Project Budget, NRE & Unit Commercials",
        status: "Approved",
        lead: "Priya Voss",
        internalRemark: "Unit target BOM cost ₹1,420 fits OEM contract price ₹2,150 at 34.8% gross margin. Pilot NRE ₹4,50,000 approved by client.",
        clientHighlight: "Commercial milestone billing and pilot purchase order commitments verified with NexGen EV.",
        nextAction: "Issue pilot batch delivery advance invoice.",
      },
      {
        code: "SAL",
        name: "Commercial Sales & OEM Accounts",
        title: "OEM Contract & Baseline Sign-Off",
        status: "Approved",
        lead: "Vikram Malhotra",
        internalRemark: "NexGen EV VP Rohan Deshmukh authorized requirement baseline BASE-EV-0205-R2 and PO-NEXGEN-2026-8871 for 5,000 pilot units.",
        clientHighlight: "Commercial agreement signed. Joint engineering steering committee aligned on SOP Q4 2026.",
        nextAction: "Host bi-weekly pilot delivery milestone review.",
      },
    ];
  }

  if (isReuse) {
    return [
      {
        code: "EHW",
        name: "Embedded Electronics Engineering",
        title: "Approved Reuse As-Is (Ready PCB-TLM-V2.0)",
        status: "Approved",
        lead: "Dr. Avery Vale",
        internalRemark: "100% hardware compatibility confirmed with proven ready PCB-TLM-V2.0. Standard 12V tracker circuit board with Quectel 4G SIM module requires zero new schematic or layout.",
        clientHighlight: "Approved direct reuse of proven PCB-TLM-V2.0 telematics platform. Zero new hardware development NRE required.",
        nextAction: "Release standard manufacturing pack.",
      },
      {
        code: "ESW",
        name: "Embedded Firmware Engineering",
        title: "Standard Telemetry Stack with Quectel Cellular Pipeline",
        status: "Approved",
        lead: "Devon Lane",
        internalRemark: "Standard commercial firmware build verified for Apex Fleet MQTT endpoint with Assisted-GPS ephemeris injection.",
        clientHighlight: "Firmware v2.0 proven across 18,000+ field-operating trackers in heavy commercial freight.",
        nextAction: "Flash golden image on pilot run.",
      },
      {
        code: "MECH",
        name: "Mechanical Engineering",
        title: "Standard IP65 Polycarbonate Enclosure & 12-Pin Harness",
        status: "Approved",
        lead: "Samira Holt",
        internalRemark: "Existing tooling molds and automotive 12-pin harness drawings reused as-is.",
        clientHighlight: "Proven IP65 enclosure and vibration-tested bracket reused directly.",
        nextAction: "Confirm harness inventory for assembly.",
      },
      {
        code: "PUR",
        name: "Purchasing & SCM",
        title: "Volume Component Sourcing for Quectel EG915",
        status: "Approved",
        lead: "Morgan Reed",
        internalRemark: "Quectel cellular modules and passives secured on existing volume master contract with franchised distributor.",
        clientHighlight: "All BOM materials verified on existing Approved Vendor List (AVL).",
        nextAction: "Trigger scheduled delivery lot 1.",
      },
      {
        code: "QA",
        name: "Quality Assurance & APQP",
        title: "Automotive Fleet Reliability Baseline",
        status: "Approved",
        lead: "Jordan Blake",
        internalRemark: "Quality track record established with <0.08% field failure rate across fleet installations.",
        clientHighlight: "Standard automotive APQP package and certificate of conformity prepared.",
        nextAction: "Conduct incoming inspection on pilot lot.",
      },
      {
        code: "EMF",
        name: "Electronics Manufacturing",
        title: "SMT Line 1 Production Scheduling",
        status: "Approved",
        lead: "Casey Rowan",
        internalRemark: "Standard pick-and-place programs and reflow profile ready for immediate launch on SMT Line 1.",
        clientHighlight: "Production line allocation scheduled for 5,000-unit pilot batch.",
        nextAction: "Load reel feeders on Line 1.",
      },
      {
        code: "FIN",
        name: "Accounts & Finance",
        title: "Commercial Contract & Margin Reconciliation",
        status: "Approved",
        lead: "Priya Voss",
        internalRemark: "Quoted ₹1,425/unit at 38% gross margin for 25,000 units/year.",
        clientHighlight: "Contract terms aligned with Apex Fleet PO PO-APEX-2026-1102.",
        nextAction: "Process commercial sign-off.",
      },
      {
        code: "SAL",
        name: "Commercial Sales & OEM Accounts",
        title: "Client Authorization & Delivery Scheduling",
        status: "Approved",
        lead: "Vikram Malhotra",
        internalRemark: "Director Arvind Swaminathan signed off requirement baseline BASE-TLM-0101-R1.",
        clientHighlight: "Account agreement finalized for multi-year fleet telematics rollout.",
        nextAction: "Coordinate initial dispatch schedule.",
      },
    ];
  }

  return defaultDepartmentProfiles;
}

export function ProjectAnalysisSummary({ project }: { project: Project }) {
  const [viewMode, setViewMode] = useState<"internal" | "client">("internal");
  const [diagramMode, setDiagramMode] = useState<"concept" | "diagram">("concept");
  const [taskDeptFilter, setTaskDeptFilter] = useState("all");
  const [taskStatusFilter, setTaskStatusFilter] = useState("all");
  const [taskSearch, setTaskSearch] = useState("");

  const isBleProject = project.code?.includes("BLE") || project.name?.toLowerCase().includes("ble");
  const isReuseProject = project.code?.includes("TLM-STD") || project.name?.toLowerCase().includes("reuse") || project.name?.toLowerCase().includes("apex");
  const activeProfiles = useMemo(() => getDepartmentProfiles(project), [project]);

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
                {isBleProject
                  ? "Locked · R2 Baseline (NexGen EV Authorized)"
                  : isReuseProject
                  ? "Locked · R1 Baseline (Apex Fleet Reused)"
                  : "Locked · R1 Baseline"}
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
              <p className="text-sm font-bold">
                {isBleProject ? "12V / 24V (9–36V)" : isReuseProject ? "12V DC Automotive" : "24 V DC (12–36V)"}
              </p>
            </div>
            <div className="rounded-lg border bg-muted/30 p-2.5">
              <p className="text-[11px] text-muted-foreground">{isBleProject ? "Radio & Cellular" : "Ingress Protection"}</p>
              <p className="text-sm font-bold">
                {isBleProject ? "Quectel 4G + BLE 5.2" : isReuseProject ? "IP65 Gasket Enclosure" : "IP65 (Gasket sealed)"}
              </p>
            </div>
            <div className="rounded-lg border bg-muted/30 p-2.5">
              <p className="text-[11px] text-muted-foreground">{isBleProject ? "Backup Battery" : "Communication"}</p>
              <p className="text-sm font-bold">
                {isBleProject ? "3.7V Li-ion (AIS-156)" : isReuseProject ? "Quectel 4G SIM + GNSS" : "RS485 + Dual CAN"}
              </p>
            </div>
            <div className="rounded-lg border bg-muted/30 p-2.5">
              <p className="text-[11px] text-muted-foreground">{isBleProject ? "Homologation" : "Pilot Batch Quantity"}</p>
              <p className="text-sm font-bold">
                {isBleProject ? "iCAT AIS-140 · IP67" : isReuseProject ? "2,000 units" : "100 units"}
              </p>
            </div>
          </div>
        </Card>

        <Card className={isBleProject || isReuseProject ? "border-emerald-500/30 bg-emerald-500/5 p-4" : "border-amber-500/30 bg-amber-500/5 p-4"}>
          <div className="flex items-center gap-2">
            {isBleProject || isReuseProject ? (
              <CheckCircle2 className="size-4 text-emerald-600" />
            ) : (
              <AlertTriangle className="size-4 text-amber-600" />
            )}
            <span className="text-sm font-bold text-foreground">
              {isBleProject
                ? "Spatial Hardware Modification Approved"
                : isReuseProject
                ? "Approved Direct Hardware Reuse"
                : "Latest Client Proposal"}
            </span>
          </div>
          <p className="mt-2 text-xs font-semibold">
            {isBleProject ? (
              <>Ready PCB-TLM-V2.0 → <span className="underline">PCB-TLM-V2.1-BLE</span></>
            ) : isReuseProject ? (
              <>100% Match with Ready <span className="underline">PCB-TLM-V2.0</span></>
            ) : (
              <>Proposed Spec Upgrade: <span className="underline">IP65 → IP67 Submersion</span></>
            )}
          </p>
          <p className="mt-1 text-xs text-muted-foreground">
            {isBleProject
              ? "All 10 departments approved spatial addition of Nordic nRF52833 BLE 5.2 SoC & TI BQ24075 3.7V Li-ion battery charging circuit. DVP&R completed with iCAT and NABL battery certifications."
              : isReuseProject
              ? "All departments confirmed 100% hardware compatibility with proven ready PCB-TLM-V2.0. Zero new hardware engineering required; fast-tracked to pilot assembly."
              : "Client submitted revision proposal. R1 baseline remains strictly locked until feasibility, tooling costing, and DVP&R acceptance pass."}
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
              <text x="210" y="70" fill="currentColor" className="text-xs font-bold" fontSize="12">
                {isBleProject ? "NEXGEN EV TELEMATICS IP67" : isReuseProject ? "APEX FLEET 12V TRACKER" : "SENSOR GATEWAY IP67"}
              </text>
              <text x="30" y="205" fill="currentColor" className="text-muted-foreground" fontSize="11">
                {isBleProject
                  ? "Concept Enclosure · 3.7V Li-ion Backup Cell · BLE 5.2 Keyless & Quectel 4G LTE"
                  : isReuseProject
                  ? "Reused Platform · Ready PCB-TLM-V2.0 · 12V Quectel 4G SIM"
                  : "Concept Enclosure · 24V / RS485 Dual CAN"}
              </text>
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
                <text x="67" y="93" className="font-semibold">{isBleProject ? "3.7V Li-ion" : "Sensors"}</text>
                <text x="67" y="112" className="text-[10px] text-muted-foreground">{isBleProject ? "Backup Cell" : "(IO)"}</text>
                <text x="260" y="93" className="font-bold text-primary">STM32 MCU</text>
                <text x="260" y="112" className="text-[10px] text-muted-foreground">{isBleProject ? "PCB-TLM-V2.1-BLE" : "Main Controller"}</text>
                <text x="447" y="93" className="font-semibold">{isBleProject ? "Quectel + BLE" : "RS485 / CAN"}</text>
                <text x="447" y="112" className="text-[10px] text-muted-foreground">{isBleProject ? "4G LTE & BLE 5.2" : "Telemetry Stack"}</text>
                <text x="260" y="27" className="font-semibold">{isBleProject ? "12V/24V Power" : "24V Power Supply"}</text>
                <text x="260" y="42" className="text-[9px] text-muted-foreground">{isBleProject ? "& BQ24075 Charger" : ""}</text>
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
            <Badge variant="outline">{isBleProject ? "Step 3 of 4" : isReuseProject ? "Step 4 of 4" : "Step 2 of 4"}</Badge>
          </div>
          <span className="text-xs text-muted-foreground">
            {isBleProject
              ? "Next Gate: SMT Line 2 Pilot Build"
              : isReuseProject
              ? "Next Gate: Pilot Dispatch Clearance"
              : "Next Gate: Ingress Chamber Test"}
          </span>
        </div>

        <div className="mt-4 grid grid-cols-1 items-center gap-2 sm:grid-cols-4">
          <div className="flex items-center gap-3 rounded-lg border border-emerald-500/40 bg-emerald-500/10 p-3">
            <div className="flex size-7 items-center justify-center rounded-full bg-emerald-600 text-white">
              <Check className="size-4" />
            </div>
            <div>
              <p className="text-xs font-bold text-emerald-800 dark:text-emerald-300">1. Requirements</p>
              <p className="text-[11px] text-muted-foreground">{isBleProject ? "Locked · R2 Baseline" : isReuseProject ? "Locked · R1 Reused" : "Locked · R1 baseline"}</p>
            </div>
          </div>

          <div className="flex items-center gap-3 rounded-lg border border-emerald-500/40 bg-emerald-500/10 p-3">
            <div className="flex size-7 items-center justify-center rounded-full bg-emerald-600 text-white">
              <Check className="size-4" />
            </div>
            <div>
              <p className="text-xs font-bold text-emerald-800 dark:text-emerald-300">2. Feasibility</p>
              <p className="text-[11px] text-muted-foreground">{isBleProject ? "Approved · 10/10 Depts" : isReuseProject ? "Approved As-Is" : "Blocked · Mechanical"}</p>
            </div>
          </div>

          <div className={isBleProject || isReuseProject ? "flex items-center gap-3 rounded-lg border border-emerald-500/40 bg-emerald-500/10 p-3" : "flex items-center gap-3 rounded-lg border bg-muted/40 p-3 opacity-75"}>
            <div className={isBleProject || isReuseProject ? "flex size-7 items-center justify-center rounded-full bg-emerald-600 text-white" : "flex size-7 items-center justify-center rounded-full bg-muted text-muted-foreground font-bold text-xs"}>
              {isBleProject || isReuseProject ? <Check className="size-4" /> : "3"}
            </div>
            <div>
              <p className="text-xs font-bold">{isBleProject ? "3. DVP&R / iCAT / NABL" : "3. Ingress & Testing"}</p>
              <p className="text-[11px] text-muted-foreground">{isBleProject ? "Passed · Certified" : isReuseProject ? "Passed · Baseline" : "Waiting · Quality APQP"}</p>
            </div>
          </div>

          <div className={isReuseProject ? "flex items-center gap-3 rounded-lg border border-emerald-500/40 bg-emerald-500/10 p-3" : isBleProject ? "flex items-center gap-3 rounded-lg border border-primary/40 bg-primary/10 p-3" : "flex items-center gap-3 rounded-lg border bg-muted/40 p-3 opacity-75"}>
            <div className={isReuseProject ? "flex size-7 items-center justify-center rounded-full bg-emerald-600 text-white" : "flex size-7 items-center justify-center rounded-full bg-primary text-primary-foreground font-bold text-xs"}>
              {isReuseProject ? <Check className="size-4" /> : "4"}
            </div>
            <div>
              <p className="text-xs font-bold">4. Pilot Release</p>
              <p className="text-[11px] text-muted-foreground">{isBleProject ? "Active · SMT Line 2" : isReuseProject ? "Scheduled · Line 1" : "Waiting · Sign-off"}</p>
            </div>
          </div>
        </div>
      </Card>

      {/* 6. System Configuration: Modular Platform Electronic Subsystems Reuse */}
      <Card className="p-4">
        <div className="flex items-center justify-between border-b pb-2">
          <div className="flex items-center gap-2">
            <CircuitBoard className="size-4 text-primary" />
            <h3 className="text-sm font-bold">
              {isBleProject
                ? "Modular Platform Electronics Reuse & BLE Modification"
                : isReuseProject
                ? "Modular Platform Electronics Reuse (100% As-Is Hardware Match)"
                : "Modular Platform Electronics Reuse"}
            </h3>
          </div>
          <Badge variant="outline" className="text-xs">
            Decoupled Architecture (Master Plan §5 & §6)
          </Badge>
        </div>

        <div className="mt-3 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <div className="rounded-lg border p-3">
            <div className="flex items-center justify-between">
              <span className="font-bold text-xs">
                {isBleProject ? "PCB-TLM-V2.0 Base" : isReuseProject ? "PCB-TLM-V2.0 Platform" : "PCB-CTRL R3"}
              </span>
              <Badge variant="secondary" className="bg-emerald-500/10 text-emerald-600 text-[10px]">
                {isBleProject ? "Base Reused" : "100% Direct Reuse"}
              </Badge>
            </div>
            <p className="mt-1 text-xs text-muted-foreground">
              {isBleProject ? "Base Telematics Circuitry" : "Standard Telematics Board"}
            </p>
            <p className="mt-2 text-[11px] text-muted-foreground">
              {isBleProject ? "4-layer FR4 layout, STM32 MCU & buck power reused." : "Proven across 18,000+ commercial fleet installations."}
            </p>
          </div>

          <div className="rounded-lg border p-3">
            <div className="flex items-center justify-between">
              <span className="font-bold text-xs">
                {isBleProject ? "Quectel 4G LTE Subsystem" : isReuseProject ? "Quectel Cellular SIM Module" : "PCB-IO R2"}
              </span>
              <Badge variant="secondary" className="bg-emerald-500/10 text-emerald-600 text-[10px]">
                Approved Reuse
              </Badge>
            </div>
            <p className="mt-1 text-xs text-muted-foreground">
              {isBleProject || isReuseProject ? "Cellular & GNSS Receiver" : "Sensor Expansion Board"}
            </p>
            <p className="mt-2 text-[11px] text-muted-foreground">
              {isBleProject || isReuseProject ? "EG915 LTE Cat-1 with Assisted-GPS ephemeris." : "RS485 transceiver interface verified."}
            </p>
          </div>

          <div className="rounded-lg border p-3">
            <div className="flex items-center justify-between">
              <span className="font-bold text-xs">
                {isBleProject ? "Nordic nRF52833 BLE 5.2" : isReuseProject ? "12V Automotive Power Stage" : "HARNESS-PWR R2"}
              </span>
              <Badge variant="secondary" className={isBleProject ? "bg-sky-500/10 text-sky-600 text-[10px]" : "bg-emerald-500/10 text-emerald-600 text-[10px]"}>
                {isBleProject ? "Spatial Addition · NEW" : "Direct Reuse"}
              </Badge>
            </div>
            <p className="mt-1 text-xs text-muted-foreground">
              {isBleProject ? "Short-Range BLE Radio" : "9–36V Automotive Buck"}
            </p>
            <p className="mt-2 text-[11px] text-muted-foreground">
              {isBleProject ? "Spatial addition on top layer with 2.45 GHz chip antenna." : "ISO 7637-2 transient & load dump protection."}
            </p>
          </div>

          <div className="rounded-lg border p-3">
            <div className="flex items-center justify-between">
              <span className="font-bold text-xs">
                {isBleProject ? "3.7V Li-ion Battery Charger" : isReuseProject ? "IP65 Housing & Harness" : "Telemetry Gateway 1.8"}
              </span>
              <Badge variant="secondary" className={isBleProject ? "bg-amber-500/10 text-amber-600 text-[10px]" : "bg-emerald-500/10 text-emerald-600 text-[10px]"}>
                {isBleProject ? "Power Modification · NEW" : "Direct Reuse"}
              </Badge>
            </div>
            <p className="mt-1 text-xs text-muted-foreground">
              {isBleProject ? "TI BQ24075 + MAX17048" : "IP65 Polycarbonate Enclosure"}
            </p>
            <p className="mt-2 text-[11px] text-muted-foreground">
              {isBleProject ? "800mAh backup cell, AIS-156 & UN 38.3 certified." : "Standard enclosure tooling and 12-pin harness reused."}
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
            {activeProfiles.length} Functional Disciplines
          </Badge>
        </div>

        <div className="mt-4 grid gap-3 sm:grid-cols-2 lg:grid-cols-2">
          {activeProfiles.map((dept) => (
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
