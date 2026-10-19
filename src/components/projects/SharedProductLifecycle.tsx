import { useState } from "react";
import { Link } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import {
  ArrowLeft,
  ArrowRight,
  Check,
  CheckCircle2,
  ChevronLeft,
  ChevronRight,
  ClipboardCheck,
  ClipboardList,
  FileCheck2,
  FileText,
  FolderOpen,
  GitPullRequest,
  Layers,
  Lock,
  MessageSquare,
  PackageSearch,
  Plus,
  RefreshCw,
  Send,
  Settings2,
  ShieldAlert,
  ShieldCheck,
  Sparkles,
  Wrench,
} from "lucide-react";
import { supabase } from "@/integrations/supabase/client";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Progress } from "@/components/ui/progress";
import type { Project } from "@/lib/projects";
import { createLifecycleDraftPlan } from "@/lib/lifecycle-draft-plan";
import { LifecycleDocumentDraftPanel } from "@/components/projects/LifecycleDocumentDraftPanel";
import { LifecycleResponsibilityPlan } from "@/components/projects/LifecycleResponsibilityPlan";
import { lifecycleStageReadiness, requirementRevisionRelation, type CompanyStageRead } from "@/lib/connected-lifecycle-responsibility-plan";
import { SAMPLE_REGULATORY_REPORTS } from "@/lib/sample-data-lifecycle";
import { DepartmentChroniclesFeed } from "@/components/departments/DepartmentChroniclesFeed";
import { getDepartmentsForStage } from "@/lib/department-stage-responsibilities";
import { DepartmentStagesManager } from "@/components/departments/DepartmentStagesManager";
import { toast } from "sonner";

const sb = supabase as any;

function readErrorMessage(error: unknown) {
  if (error instanceof Error) return error.message;
  if (error && typeof error === "object" && "message" in error && typeof error.message === "string") return error.message;
  return null;
}

export interface LifecycleStageItem {
  id: string;
  stageNumber: number;
  name: string;
  shortLabel: string;
  phase: string;
  leadDept: string;
  deptCode: string;
  status: "completed" | "in_progress" | "blocked" | "waiting" | "bypassed";
  gateName: string;
  summary: string;
  deliverables: string[];
  approvals: { department: string; lead: string; approved: boolean; date?: string }[];
  notes: { author: string; role: string; date: string; content: string }[];
}

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
  const isDirectReuse = project.code === "PRJ-TLM-001";
  const isBleModification = project.code === "PRJ-TLM-002";

  // Initial 9 stages definition customized for Telematics Journeys
  const defaultStages: LifecycleStageItem[] = [
    {
      id: "stage-1-intake",
      stageNumber: 1,
      name: "Requirement Intake & Commercial Proposal",
      shortLabel: "Intake",
      phase: "Phase 1: Commercial Scope",
      leadDept: "Sales & Commercials",
      deptCode: "SALES",
      status: "completed",
      gateName: "Gate 1: Opportunity Qualification",
      summary: "Customer PRD ingestion, NDA execution, preliminary vehicle architecture fitment, and commercial scoping.",
      deliverables: [
        "Customer PRD v1.0 ingested",
        "Mutual Non-Disclosure Agreement (NDA) executed",
        "Target vehicle battery & bus voltage spec (12V / 24V)",
        "Commercial feasibility estimate & high-level quotation",
      ],
      approvals: [
        { department: "Sales & BD", lead: "Siddharth Rao (Sales VP)", approved: true, date: "2026-01-14" },
        { department: "Project Management", lead: "Ananya Roy (PM)", approved: true, date: "2026-01-15" },
      ],
      notes: [
        { author: "Siddharth Rao", role: "Sales Lead", date: "2026-01-14", content: "Customer requirements validated against OEM fleet tracking standard." },
      ],
    },
    {
      id: "stage-2-feasibility",
      stageNumber: 2,
      name: "Cross-Department Feasibility Assessment",
      shortLabel: "Feasibility",
      phase: "Phase 2: Technical Evaluation",
      leadDept: "Hardware R&D & Mechanical",
      deptCode: "R&D / MECH",
      status: "completed",
      gateName: "Gate 2: Technical Feasibility Sign-off",
      summary: isDirectReuse
        ? "100% Direct Hardware Reuse approved. Existing PCB-TLM-V2.0 matches all Tata CV PRD requirements with zero hardware spins."
        : "Modification required: Addition of Nordic nRF52833 BLE 5.2, TI BQ24075 charger, 3.7V Li-ion battery, and IP67 sealed enclosure.",
      deliverables: [
        isDirectReuse ? "Direct reuse risk evaluation (PCB-TLM-V2.0)" : "Modification architecture proposal (PCB-TLM-V2.1-BLE)",
        "Power rail & battery safety analysis (ISO 7637-2 / UN 38.3)",
        "Thermal dissipation & IP67 enclosure feasibility",
        "BOM costing & preliminary supplier lead-time check",
      ],
      approvals: [
        { department: "Hardware R&D", lead: "Dr. Rajesh Sharma (Hardware Lead)", approved: true, date: "2026-02-12" },
        { department: "Mechanical Eng", lead: "Arun Kulkarni (Lead Mechanical)", approved: true, date: "2026-02-13" },
        { department: "Procurement & SCM", lead: "Morgan Reed (SCM Lead)", approved: true, date: "2026-02-14" },
        { department: "Quality APQP", lead: "Jordan Blake (Quality Lead)", approved: true, date: "2026-02-14" },
      ],
      notes: [
        {
          author: isDirectReuse ? "Dr. Rajesh Sharma" : "Arun Kulkarni",
          role: isDirectReuse ? "Hardware Lead" : "Mechanical Lead",
          date: "2026-02-13",
          content: isDirectReuse
            ? "Zero PCB modifications required. Direct reuse bypasses EVT POC stage entirely."
            : "IP67 enclosure requires SolidWorks seal groove optimization and Gore-Tex breather valve.",
        },
      ],
    },
    {
      id: "stage-3-baseline",
      stageNumber: 3,
      name: "Customer Authorization & Baseline Freeze",
      shortLabel: "Baseline",
      phase: "Phase 3: Formal Baseline",
      leadDept: "Project Management & Executive",
      deptCode: "PM / EXEC",
      status: "completed",
      gateName: "Gate 3: Baseline Freeze & Purchase Order",
      summary: "Customer purchase order received, formal requirement baseline locked, revision assignment, and change control enabled.",
      deliverables: [
        "Signed Customer PO / Letter of Intent (LOI)",
        "Approved Baseline Specification (BASE-TLM-001/002)",
        "Assigned revision tag & change request policy active",
        "Project master delivery schedule & milestone agreement",
      ],
      approvals: [
        { department: "Project Delivery", lead: "Ananya Roy (PM)", approved: true, date: "2026-02-18" },
        { department: "Executive Mgmt", lead: "Vikram Malhotra (Executive Dir)", approved: true, date: "2026-02-18" },
      ],
      notes: [
        { author: "Ananya Roy", role: "Project Manager", date: "2026-02-18", content: "Customer authorized baseline locked. Any change now requires formal ECO." },
      ],
    },
    {
      id: "stage-4-poc",
      stageNumber: 4,
      name: "Research & Proof of Concept (POC)",
      shortLabel: "Research / POC",
      phase: "Phase 4: EVT Validation",
      leadDept: "Hardware & Firmware R&D",
      deptCode: "RND",
      status: isDirectReuse ? "bypassed" : "completed",
      gateName: "Gate 4: EVT Functional Prototype Sign-off",
      summary: isDirectReuse
        ? "Bypassed: Direct reuse of proven PCB-TLM-V2.0 eliminates breadboard prototype risk and transitions directly to pilot line setup."
        : "Nordic nRF52833 BLE 5.2 RF range verified to 35m across vehicle body. TI BQ24075 3.7V battery charging efficiency measured at 92%.",
      deliverables: [
        "Breadboard EVT prototype board testing",
        "BLE 5.2 TPMS tire beacon wireless receiver validation",
        "Battery charge management circuit verification (BQ24075)",
        "Firmware sensor acquisition driver validation",
      ],
      approvals: [
        { department: "Hardware Engineering", lead: "Dr. Rajesh Sharma", approved: !isDirectReuse, date: isDirectReuse ? undefined : "2026-02-28" },
        { department: "Firmware R&D", lead: "Devon Lane", approved: !isDirectReuse, date: isDirectReuse ? undefined : "2026-02-28" },
      ],
      notes: [
        {
          author: isDirectReuse ? "Ananya Roy" : "Devon Lane",
          role: isDirectReuse ? "PM" : "Firmware Lead",
          date: "2026-02-25",
          content: isDirectReuse
            ? "EVT Stage skipped per approved direct reuse waiver."
            : "BLE beacon scan interval optimized to achieve 72-hour battery backup target.",
        },
      ],
    },
    {
      id: "stage-5-pilot",
      stageNumber: 5,
      name: "Pilot Manufacturing & Tooling Preparation",
      shortLabel: "Pilot",
      phase: "Phase 5: DFM & First Article",
      leadDept: "Production & Mechanical Engineering",
      deptCode: "PROD / MECH",
      status: isDirectReuse ? "in_progress" : "completed",
      gateName: "Gate 5: Pilot Run & Tooling Approval",
      summary: isDirectReuse
        ? "Active: SMT Line 2 automated placement setup, stencil fabrication, and initial 50-unit pilot batch assembly."
        : "150 prototype units successfully assembled on SMT Line 2. Tooling mold flow analysis and polycarbonate enclosure samples verified.",
      deliverables: [
        "DFM & DFA review completed",
        "SMT stencil & 10-zone reflow profile qualified",
        "Prototype batch assembly (50-150 units)",
        "First-article automated optical inspection (AOI) passed",
      ],
      approvals: [
        { department: "Production Lead", lead: "Casey Rowan", approved: !isDirectReuse, date: isDirectReuse ? undefined : "2026-03-05" },
        { department: "Mechanical Tooling", lead: "Arun Kulkarni", approved: true, date: "2026-03-04" },
      ],
      notes: [
        { author: "Casey Rowan", role: "Production Lead", date: "2026-03-04", content: "SMT line thermal profile calibrated for lead-free SAC305 solder paste." },
      ],
    },
    {
      id: "stage-6-validation",
      stageNumber: 6,
      name: "DVP&R, Regulatory & Homologation Testing",
      shortLabel: "Validation",
      phase: "Phase 6: Type Approval & Testing",
      leadDept: "Quality APQP & Regulatory",
      deptCode: "QA / HOMOLOGATION",
      status: isBleModification ? "in_progress" : "waiting",
      gateName: "Gate 6: Regulatory Certification Sign-off",
      summary: "iCAT AIS-140 vehicle tracking homologation pass; NABL battery safety testing (UN 38.3 & IS 16046); IP67 environmental chamber testing.",
      deliverables: [
        "iCAT AIS-140 Certificate: iCAT/AIS140/2026/0892",
        "NABL Battery Safety Certificate: NABL/BAT/2026/4412",
        "Environmental DVP/DVR: IP67 submersion & thermal shock (-20°C to +70°C)",
        "Automotive transient immunity (ISO 7637-2 Pulse 1, 2a, 3a/b, 5b)",
      ],
      approvals: [
        { department: "Regulatory Affairs", lead: "Deepak Chawla", approved: isBleModification, date: "2026-03-12" },
        { department: "Quality Assurance", lead: "Jordan Blake", approved: false },
      ],
      notes: [
        { author: "Jordan Blake", role: "Quality Lead", date: "2026-03-15", content: "iCAT and NABL certificates received. Final 500-hour thermal chamber endurance run in progress." },
      ],
    },
    {
      id: "stage-7-release",
      stageNumber: 7,
      name: "Engineering Release (DVT / PVT Sign-off)",
      shortLabel: "Release",
      phase: "Phase 7: Engineering Release",
      leadDept: "Hardware, Firmware & Quality Leads",
      deptCode: "ENG / QA",
      status: "waiting",
      gateName: "Gate 7: Final Golden Design Freeze",
      summary: "Golden engineering baseline freeze, firmware production hash signature, final Golden BOM lock, and release package archiving.",
      deliverables: [
        "Golden BOM frozen with AVL second-source components",
        "Signed firmware hex binary with secure bootloader signature",
        "Fabrication Gerber & drill package locked in Drive",
        "Engineering Change Order (ECO) closeout",
      ],
      approvals: [
        { department: "Lead Engineer", lead: "Dr. Rajesh Sharma", approved: false },
        { department: "Quality Manager", lead: "Jordan Blake", approved: false },
      ],
      notes: [],
    },
    {
      id: "stage-8-readiness",
      stageNumber: 8,
      name: "Supply Chain & Production Readiness",
      shortLabel: "Supply Readiness",
      phase: "Phase 8: SCM & Tooling Setup",
      leadDept: "Procurement & SCM",
      deptCode: "SCM",
      status: "waiting",
      gateName: "Gate 8: Supplier PPAP & Buffer Stock",
      summary: "Supplier PPAP Level 3 approvals, buffer inventory inwarded at Stores, component lead-time mitigation, and test jig calibration.",
      deliverables: [
        "Supplier PPAP Level 3 documentation signed",
        "Minimum 30-day component buffer in Stores inventory",
        "Automated FCT test fixture calibrated",
        "Packaging, labelling & barcode scanner validation",
      ],
      approvals: [
        { department: "SCM Controller", lead: "Morgan Reed", approved: false },
        { department: "Stores Manager", lead: "Ravi Chandran", approved: false },
      ],
      notes: [],
    },
    {
      id: "stage-9-production",
      stageNumber: 9,
      name: "Series Mass Production & Dispatch",
      shortLabel: "Production",
      phase: "Phase 9: Series Execution",
      leadDept: "Production Operations & Logistics",
      deptCode: "OPS / LOGISTICS",
      status: "waiting",
      gateName: "Gate 9: Series SOP Clearance",
      summary: "High-volume series assembly, 100% end-of-line functional testing, final quality release inspection, and OEM dispatch logistics.",
      deliverables: [
        "Work orders released on shop floor",
        "100% End-of-Line (EOL) testing & IMEI registration",
        "Controlled finished goods quality release certificate",
        "Dispatch documentation & invoice transmittal",
      ],
      approvals: [
        { department: "Operations Head", lead: "Casey Rowan", approved: false },
        { department: "Quality Release", lead: "Jordan Blake", approved: false },
      ],
      notes: [],
    },
  ];

  const [stagesList, setStagesList] = useState<LifecycleStageItem[]>(defaultStages);

  // Active inspected stage index (0 to 8)
  const initialActiveIndex = isDirectReuse ? 4 : isBleModification ? 5 : 0;
  const [activeStageIndex, setActiveStageIndex] = useState<number>(initialActiveIndex);
  const activeStage = stagesList[activeStageIndex];

  // Comment input state
  const [newNote, setNewNote] = useState("");

  const handleAddNote = () => {
    if (!newNote.trim()) return;
    const author = "Engineering Lead";
    const role = "Current Session";
    const date = new Date().toISOString().slice(0, 10);
    setStagesList((prev) =>
      prev.map((s, idx) =>
        idx === activeStageIndex
          ? { ...s, notes: [...s.notes, { author, role, date, content: newNote.trim() }] }
          : s
      )
    );
    setNewNote("");
    toast.success("Stage audit note recorded");
  };

  const handleToggleApproval = (approvalIndex: number) => {
    setStagesList((prev) =>
      prev.map((s, idx) => {
        if (idx !== activeStageIndex) return s;
        const nextApprovals = [...s.approvals];
        const current = nextApprovals[approvalIndex];
        nextApprovals[approvalIndex] = {
          ...current,
          approved: !current.approved,
          date: !current.approved ? new Date().toISOString().slice(0, 10) : undefined,
        };
        return { ...s, approvals: nextApprovals };
      })
    );
    toast.info("Stakeholder approval status updated");
  };

  // Safe data snapshot queries with graceful fallbacks
  const { data: snapshot, isLoading, isError, error, refetch } = useQuery({
    queryKey: ["shared_product_lifecycle", project.id, project.requirement_baseline_id],
    retry: false,
    queryFn: async () => {
      const [tasks, boms, inputs, research, changes, process] = await Promise.all([
          sb.from("project_tasks").select("id,status,assignee_id,department_id").eq("project_id", project.id),
          sb.from("project_boms").select("id,revision,source_drive_node_id,source_drive_revision_id").eq("project_id", project.id),
          sb.from("project_design_inputs").select("id,status").eq("project_id", project.id),
          sb.from("project_research_records").select("id,decision_status").eq("project_id", project.id),
          sb.from("project_change_requests").select("id,status").eq("project_id", project.id),
          sb.from("project_process_stage_records").select("id,status").eq("project_id", project.id),
        ]);
        for (const result of [tasks, boms, inputs, research, changes, process]) {
          if (result && result.error) throw result.error;
        }
        return {
          tasks: tasks.data ?? [],
          boms: boms.data ?? [],
          inputs: inputs.data ?? [],
          research: research.data ?? [],
          changes: changes.data ?? [],
          process: process.data ?? [],
        };
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
      const { data, error } = await sb.from("project_stage_gates").select("id,status").eq("project_id", project.id);
      if (error) throw error;
      return data ?? [];
    },
  });

  const stages = useQuery({
    queryKey: ["company_process_stages", "shared_product_lifecycle"],
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

  const baseline = useQuery({
    queryKey: ["shared_product_lifecycle_baseline", project.id, project.requirement_baseline_id],
    enabled: Boolean(project.requirement_baseline_id),
    retry: false,
    queryFn: async () => {
      const { data, error } = await sb
        .from("requirement_baselines")
        .select("baseline_number,revision_number,status,requirement:customer_requirements(requirement_number,current_revision)")
        .eq("id", project.requirement_baseline_id)
        .maybeSingle();
      if (error) throw error;
      return data;
    },
  });

  const stageReadiness = lifecycleStageReadiness(
    stages.data ?? [],
    project.project_stage,
    project.requirement_baseline_id,
    snapshot ? { designInputCount: snapshot.inputs.length, linkedBomCount: snapshot.boms.length } : null,
  );
  const revisionRelation = baseline.data
    ? requirementRevisionRelation(
        baseline.data.revision_number,
        baseline.data.requirement?.current_revision,
      )
    : null;
  const lifecycleContextLoading = stages.isLoading || baseline.isLoading;
  const lifecycleContextError = stages.error || baseline.error;

  const openTasks = snapshot?.tasks.filter((task: any) => task.status !== "done").length ?? 0;
  const draftPlan = snapshot
    ? createLifecycleDraftPlan({
        projectId: project.id,
        departmentId: project.department_id,
        requirementBaselineId: project.requirement_baseline_id,
        projectDriveNodeId: project.project_drive_node_id,
        tasks: snapshot.tasks,
        processRecords: snapshot.process,
        designInputCount: snapshot.inputs.length,
        researchCount: snapshot.research.length,
        linkedBomCount: snapshot.boms.length,
      })
    : null;

  // Filter regulatory reports for current project
  const relevantReports = SAMPLE_REGULATORY_REPORTS.filter((r) => r.projectId === project.id);
  const [isStageRespOpen, setIsStageRespOpen] = useState(false);
  const [refreshRespKey, setRefreshRespKey] = useState(0);

  return (
    <div className="space-y-6">
      {/* 1. Header Overview & Progress Ribbon */}
      <Card className="border-primary/20 p-5 bg-card/60 backdrop-blur-sm">
        <div className="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
          <div>
            <div className="flex items-center gap-2">
              <span className="flex size-7 items-center justify-center rounded-md bg-primary text-primary-foreground">
                <GitPullRequest className="size-4" />
              </span>
              <h2 className="text-xl font-bold tracking-tight">Interactive 9-Stage Product Lifecycle</h2>
              <Badge variant="outline" className="border-primary/40 text-primary font-mono text-xs">
                {project.code} · Rev {project.revision || "1.0"}
              </Badge>
            </div>
            <p className="mt-2 max-w-3xl text-sm text-muted-foreground">
              {isDirectReuse
                ? "Tata Motors CV Telematics: 100% Direct Reuse of PCB-TLM-V2.0. Stage 4 (Research/POC) bypassed; currently in Stage 5 (Pilot Manufacturing)."
                : isBleModification
                ? "Mahindra Fleet Telematics: Modification Board Spin (PCB-TLM-V2.1-BLE) with BLE 5.2 & 3.7V Li-ion battery. Currently in Stage 6 (Validation & AIS-140/NABL Testing)."
                : "Multi-department stage progression, cross-functional sign-offs, and compliance evidence register."}
            </p>
          </div>

          <div className="flex items-center gap-2">
            <Button
              size="sm"
              variant="outline"
              disabled={activeStageIndex === 0}
              onClick={() => setActiveStageIndex((i) => Math.max(0, i - 1))}
              className="gap-1 text-xs"
            >
              <ChevronLeft className="size-3.5" /> Previous Stage
            </Button>
            <Button
              size="sm"
              variant="default"
              disabled={activeStageIndex === stagesList.length - 1}
              onClick={() => setActiveStageIndex((i) => Math.min(stagesList.length - 1, i + 1))}
              className="gap-1 text-xs"
            >
              Next Stage <ChevronRight className="size-3.5" />
            </Button>
          </div>
        </div>

        {/* 9-Stage Interactive Visual Stepper Strip */}
        <div className="mt-6 grid grid-cols-1 gap-2 sm:grid-cols-3 lg:grid-cols-9">
          {stagesList.map((stage, idx) => {
            const isActive = idx === activeStageIndex;
            return (
              <button
                key={stage.id}
                type="button"
                onClick={() => setActiveStageIndex(idx)}
                className={`group relative flex flex-col justify-between rounded-lg border p-3 text-left transition-all ${
                  isActive
                    ? "border-primary bg-primary/10 shadow-sm ring-2 ring-primary/30"
                    : stage.status === "completed"
                    ? "border-emerald-500/40 bg-emerald-500/5 hover:border-emerald-500/70"
                    : stage.status === "in_progress"
                    ? "border-amber-500/50 bg-amber-500/10 hover:border-amber-500/80 animate-pulse"
                    : stage.status === "bypassed"
                    ? "border-muted/60 bg-muted/20 opacity-70 hover:opacity-100"
                    : "border-border/60 bg-card/40 opacity-75 hover:opacity-100"
                }`}
              >
                <div>
                  <div className="flex items-center justify-between gap-1">
                    <span className="font-mono text-[11px] font-bold text-muted-foreground">
                      {String(stage.stageNumber).padStart(2, "0")}
                    </span>
                    {stage.status === "completed" ? (
                      <span className="flex size-4 items-center justify-center rounded-full bg-emerald-600 text-white">
                        <Check className="size-2.5" />
                      </span>
                    ) : stage.status === "in_progress" ? (
                      <span className="size-2 rounded-full bg-amber-500" />
                    ) : stage.status === "bypassed" ? (
                      <span className="text-[10px] text-muted-foreground italic">Skip</span>
                    ) : (
                      <span className="size-2 rounded-full bg-muted" />
                    )}
                  </div>
                  <p className="mt-2 text-xs font-semibold leading-tight line-clamp-2">{stage.shortLabel}</p>
                </div>

                <div className="mt-3 border-t pt-1.5">
                  <span className="text-[10px] font-mono text-muted-foreground uppercase">{stage.deptCode}</span>
                </div>
              </button>
            );
          })}
        </div>
      </Card>

      {/* 2. Active Stage Detailed Inspector Panel */}
      <div className="grid gap-6 lg:grid-cols-[1.3fr_0.9fr]">
        <div className="space-y-6">
          <Card className="border-border p-5">
            <div className="flex flex-wrap items-center justify-between gap-2 border-b pb-4">
              <div>
                <div className="flex items-center gap-2">
                  <Badge variant="outline" className="font-mono text-xs">
                    Stage {activeStage.stageNumber} of 9
                  </Badge>
                  <h3 className="text-lg font-bold">{activeStage.name}</h3>
                </div>
                <p className="mt-1 text-xs text-muted-foreground">{activeStage.phase}</p>
              </div>

              <Badge
                variant={
                  activeStage.status === "completed"
                    ? "default"
                    : activeStage.status === "in_progress"
                    ? "secondary"
                    : "outline"
                }
                className={
                  activeStage.status === "completed"
                    ? "bg-emerald-600 text-white"
                    : activeStage.status === "in_progress"
                    ? "bg-amber-500/20 text-amber-700 dark:text-amber-400 border-amber-500/40"
                    : ""
                }
              >
                {activeStage.status.toUpperCase().replaceAll("_", " ")}
              </Badge>
            </div>

            <p className="mt-4 text-sm text-foreground leading-relaxed">{activeStage.summary}</p>

            {/* Stage Deliverables & Gate Verification */}
            <div className="mt-5 rounded-lg border bg-muted/20 p-4">
              <div className="flex items-center gap-2 text-xs font-semibold text-primary">
                <FileCheck2 className="size-4" />
                <span>Deliverables & Verification Criteria</span>
              </div>
              <ul className="mt-3 space-y-2 text-xs">
                {activeStage.deliverables.map((item, idx) => (
                  <li key={idx} className="flex items-start gap-2 text-muted-foreground">
                    <span className="mt-0.5 text-primary">▸</span>
                    <span className="text-foreground">{item}</span>
                  </li>
                ))}
              </ul>
            </div>

            {/* Department Stage Responsibilities (RACI Mapping) */}
            {(() => {
              const stageResponsibilities = getDepartmentsForStage(activeStage.stageNumber);
              return (
                <div className="mt-5 space-y-3">
                  <div className="flex items-center justify-between">
                    <span className="text-xs font-semibold uppercase tracking-wider text-muted-foreground flex items-center gap-1.5">
                      <Layers className="size-3.5 text-primary" />
                      Department Responsibilities ({stageResponsibilities.length} Teams)
                    </span>
                    <Button
                      size="sm"
                      variant="outline"
                      onClick={() => setIsStageRespOpen(true)}
                      className="h-6 px-2 text-[11px] gap-1"
                    >
                      <Settings2 className="size-3" /> Adjust
                    </Button>
                  </div>

                  <div className="grid gap-2 sm:grid-cols-2">
                    {stageResponsibilities.map((resp) => {
                      const roleBadgeClass =
                        resp.role === "lead"
                          ? "bg-emerald-500/15 text-emerald-700 dark:text-emerald-400 border-emerald-500/30"
                          : resp.role === "coordinating"
                          ? "bg-blue-500/15 text-blue-700 dark:text-blue-400 border-blue-500/30"
                          : "bg-purple-500/15 text-purple-700 dark:text-purple-400 border-purple-500/30";

                      return (
                        <div
                          key={resp.id}
                          className="rounded-md border bg-card/60 p-2.5 text-xs space-y-1.5"
                        >
                          <div className="flex items-center justify-between gap-1">
                            <span className="font-semibold text-foreground capitalize">
                              {resp.departmentId}
                            </span>
                            <Badge variant="outline" className={`text-[10px] uppercase font-mono ${roleBadgeClass}`}>
                              {resp.role}
                            </Badge>
                          </div>
                          <ul className="space-y-0.5 text-[11px] text-muted-foreground">
                            {resp.deliverables.map((deliv, dIdx) => (
                              <li key={dIdx} className="line-clamp-1">
                                • {deliv}
                              </li>
                            ))}
                          </ul>
                        </div>
                      );
                    })}
                  </div>
                </div>
              );
            })()}

            {/* Multi-Department Stakeholder Approvals Checklist */}
            <div className="mt-5 space-y-3">
              <div className="flex items-center justify-between">
                <span className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
                  Cross-Functional Stakeholder Alignment
                </span>
                <span className="text-[11px] text-muted-foreground">
                  {activeStage.approvals.filter((a) => a.approved).length} of {activeStage.approvals.length} Approved
                </span>
              </div>

              <div className="grid gap-2 sm:grid-cols-2">
                {activeStage.approvals.map((approval, idx) => (
                  <button
                    key={approval.department}
                    type="button"
                    onClick={() => handleToggleApproval(idx)}
                    className={`flex items-center justify-between rounded-md border p-3 text-left transition-colors ${
                      approval.approved
                        ? "border-emerald-500/40 bg-emerald-500/10 hover:bg-emerald-500/20"
                        : "border-border/60 bg-muted/10 hover:bg-muted/30"
                    }`}
                  >
                    <div>
                      <p className="text-xs font-semibold text-foreground">{approval.department}</p>
                      <p className="text-[11px] text-muted-foreground">{approval.lead}</p>
                    </div>
                    {approval.approved ? (
                      <div className="flex items-center gap-1.5 text-emerald-600 dark:text-emerald-400 font-medium text-xs">
                        <Check className="size-4" />
                        <span>Signed</span>
                      </div>
                    ) : (
                      <span className="text-xs text-muted-foreground">Pending</span>
                    )}
                  </button>
                ))}
              </div>
            </div>
          </Card>

          {/* Collaborative Lead Notes & Audit Log */}
          <Card className="p-5">
            <div className="flex items-center gap-2 border-b pb-3">
              <MessageSquare className="size-4 text-primary" />
              <h3 className="font-semibold text-sm">Stage Audit Trail & Lead Conditions</h3>
            </div>

            <div className="mt-4 space-y-3">
              {activeStage.notes.length ? (
                activeStage.notes.map((note, idx) => (
                  <div key={idx} className="rounded-md border bg-muted/20 p-3 text-xs">
                    <div className="flex items-center justify-between">
                      <span className="font-semibold text-foreground">
                        {note.author} · <span className="font-normal text-muted-foreground">{note.role}</span>
                      </span>
                      <span className="text-[11px] text-muted-foreground">{note.date}</span>
                    </div>
                    <p className="mt-1.5 text-muted-foreground leading-normal">{note.content}</p>
                  </div>
                ))
              ) : (
                <p className="text-xs text-muted-foreground italic">No conditions or notes recorded for this stage yet.</p>
              )}
            </div>

            <div className="mt-4 flex gap-2">
              <Input
                placeholder={`Add a lead condition or decision note for Stage ${activeStage.stageNumber}…`}
                value={newNote}
                onChange={(e) => setNewNote(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === "Enter") handleAddNote();
                }}
                className="text-xs"
              />
              <Button size="sm" onClick={handleAddNote} className="gap-1.5 text-xs shrink-0">
                <Send className="size-3" /> Post Note
              </Button>
            </div>
          </Card>

          <DepartmentChroniclesFeed
            key={activeStage.stageNumber}
            defaultStageNumber={activeStage.stageNumber}
            departmentId="all"
            departmentName={`Stage ${activeStage.stageNumber} (${activeStage.shortLabel})`}
            className="border-primary/20"
          />
        </div>

        {/* Sidebar: Regulatory Register & Quick Actions */}
        <div className="space-y-6">
          {/* Regulatory & Homologation Certificates */}
          <Card className="border-border p-5">
            <div className="flex items-center gap-2 border-b pb-3">
              <ShieldCheck className="size-4 text-emerald-600 dark:text-emerald-400" />
              <div>
                <h3 className="font-semibold text-sm">Homologation & Regulatory Evidence</h3>
                <p className="text-[11px] text-muted-foreground">Automotive AIS-140 & NABL Battery Certification</p>
              </div>
            </div>

            <div className="mt-4 space-y-3">
              {relevantReports.length ? (
                relevantReports.map((report) => (
                  <div key={report.id} className="rounded-lg border border-border/80 p-3 bg-muted/10">
                    <div className="flex items-center justify-between">
                      <span className="font-mono text-xs font-bold text-primary">{report.reportNumber}</span>
                      <Badge variant="outline" className="border-emerald-500/40 text-emerald-600 text-[10px]">
                        {report.status.toUpperCase()}
                      </Badge>
                    </div>
                    <p className="mt-1.5 text-xs font-semibold text-foreground">{report.title}</p>
                    <p className="mt-1 text-[11px] text-muted-foreground">{report.standard}</p>
                    <p className="mt-2 text-[11px] text-muted-foreground/90 border-t pt-1.5 leading-normal">
                      {report.summary}
                    </p>
                  </div>
                ))
              ) : (
                <div className="rounded-lg border border-dashed p-4 text-center text-xs text-muted-foreground">
                  <p>Standard regulatory compliance for this project variant.</p>
                  <p className="mt-1 text-[11px]">Reports will be archived upon lab completion.</p>
                </div>
              )}
            </div>
          </Card>

          {/* Quick Handoffs Card */}
          <Card className="p-5">
            <h3 className="font-semibold text-sm">Cross-Functional Navigation</h3>
            <p className="mt-1 text-xs text-muted-foreground">Access supporting engineering and delivery areas.</p>
            <div className="mt-4 space-y-2">
              <Button size="sm" variant="outline" onClick={onOpenTasks} aria-label="Open project tasks" className="w-full justify-start text-xs gap-2">
                <ClipboardList className="size-3.5 text-primary" />
                <span>Open Project Tasks ({openTasks} Open)</span>
              </Button>
              <Button size="sm" variant="outline" onClick={onOpenFiles} aria-label="Open project files" className="w-full justify-start text-xs gap-2">
                <FolderOpen className="size-3.5 text-primary" />
                <span>Open Project CAD & Drive Vault</span>
              </Button>
              <Button asChild size="sm" variant="outline" className="w-full justify-start text-xs gap-2">
                <Link to="/sales">
                  <GitPullRequest className="size-3.5 text-primary" />
                  <span>Sales Requirement & PO Context</span>
                </Link>
              </Button>
            </div>
          </Card>
        </div>
      </div>

      {/* Governed Stage Context & Requirements Revision Relationship */}
      <Card className="p-5">
        <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
          <div>
            <p className="text-sm font-medium">Stage planning context</p>
            <p className="mt-1 text-sm text-muted-foreground">
              Prerequisites and workstreams are planning references only. They do not confirm completion, approval, handover, or release.
            </p>
          </div>
          <Badge variant="outline">READ ONLY</Badge>
        </div>
        {hasGateError && (
          <div role="alert" className="mt-4 flex flex-wrap items-center gap-2 text-sm text-destructive">
            <span>Gate records could not be loaded{readErrorMessage(gateError) ? `: ${readErrorMessage(gateError)}` : "."}</span>
            <Button size="sm" variant="outline" onClick={() => void refetchGates()}>
              <RefreshCw className="size-3.5" /> Retry
            </Button>
          </div>
        )}
        {lifecycleContextLoading ? (
          <p className="mt-4 text-sm text-muted-foreground">Loading accessible stage and requirement context…</p>
        ) : lifecycleContextError ? (
          <div role="alert" className="mt-4 flex flex-wrap items-center gap-2 text-sm text-destructive">
            <span>Stage planning context could not be loaded{lifecycleContextError instanceof Error ? `: ${lifecycleContextError.message}` : "."}</span>
            <Button size="sm" variant="outline" onClick={() => { void baseline.refetch(); void stages.refetch(); }}>
              <RefreshCw className="size-3.5" /> Retry
            </Button>
          </div>
        ) : (
          <div className="mt-4 grid gap-4 lg:grid-cols-3">
            <div className="border-l-2 border-primary/30 pl-3">
              <p className="text-xs text-muted-foreground">Recorded stage & workstream</p>
              <p className="mt-1 text-sm font-medium">{stageReadiness.stage?.stage_code ?? project.project_stage.replaceAll("_", " ")}</p>
              <p className="mt-1 text-xs text-muted-foreground">
                {stageReadiness.responsibility ? `Planning owner: ${stageReadiness.responsibility.leadDepartment} · participants: ${stageReadiness.responsibility.participatingDepartments.join(" · ") || "None"}` : "No lifecycle workstream is inferred for this recorded project stage."}
              </p>
            </div>
            <div className="border-l-2 border-muted pl-3">
              <p className="text-xs text-muted-foreground">Pinned requirement revision</p>
              {baseline.data ? (
                <>
                  <p className="mt-1 text-sm font-medium">{baseline.data.baseline_number} · revision {baseline.data.revision_number}</p>
                  <p className="mt-1 text-xs text-muted-foreground">
                    {baseline.data.requirement ? `${baseline.data.requirement.requirement_number} · current requirement revision ${baseline.data.requirement.current_revision}` : "Requirement record is not accessible."} · recorded status: {baseline.data.status}
                  </p>
                  {revisionRelation && (
                    <p className={revisionRelation.state === "NEWER_REQUIREMENT_REVISION" ? "mt-3 text-xs text-destructive" : "mt-3 text-xs text-muted-foreground"}>
                      {revisionRelation.message}
                    </p>
                  )}
                </>
              ) : (
                <p className="mt-1 text-sm text-muted-foreground">No accessible pinned requirement baseline.</p>
              )}
            </div>
            <div className="border-l-2 border-muted pl-3">
              <p className="text-xs text-muted-foreground">Planning prerequisites</p>
              <ul className="mt-1 space-y-1 text-xs text-muted-foreground">
                {stageReadiness.prerequisites.map((prerequisite) => <li key={prerequisite}>{prerequisite}</li>)}
              </ul>
              {stageReadiness.blockers.length ? (
                <div className="mt-3">
                  <p className="text-xs font-medium text-destructive">Blockers to resolve</p>
                  <ul className="mt-1 space-y-1 text-xs text-muted-foreground">
                    {stageReadiness.blockers.map((blocker) => <li key={blocker}>{blocker}</li>)}
                  </ul>
                </div>
              ) : (
                <p className="mt-3 text-xs text-muted-foreground">No source-link or stage-mapping blocker is visible. Review governed records separately.</p>
              )}
            </div>
          </div>
        )}
      </Card>

      {/* Governed Lifecycle Automation Plan */}
      <Card className="p-5">
        <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
          <div>
            <p className="text-sm font-medium">Draft lifecycle automation plan</p>
            <p className="mt-1 text-sm text-muted-foreground">Prepared from visible governed records only. Nothing is created, assigned, notified, approved, or shared from this panel.</p>
          </div>
          <Badge variant="secondary">DRAFT ONLY</Badge>
        </div>
        {isLoading ? (
          <p className="mt-4 text-sm text-muted-foreground">Loading available governed records…</p>
        ) : isError ? (
          <div role="alert" className="mt-4 flex flex-wrap items-center gap-2 text-sm text-destructive">
            <span>Governed lifecycle records could not be loaded{readErrorMessage(error) ? `: ${readErrorMessage(error)}` : "."}</span>
            <Button size="sm" variant="outline" onClick={() => void refetch()}><RefreshCw className="size-3.5" /> Retry</Button>
          </div>
        ) : draftPlan ? (
          <div className="mt-4 grid gap-4 lg:grid-cols-[0.8fr_1.2fr]">
            <div>
              <p className="text-xs font-medium text-muted-foreground">Required source inputs</p>
              <div className="mt-2 flex flex-wrap gap-2">
                {draftPlan.requiredInputs.map((input) => (
                  <Badge key={input.name} variant={input.status === "MISSING" ? "secondary" : "outline"} title={input.provenance}>
                    {input.name}{input.status === "MISSING" ? " · missing" : " · linked"}
                  </Badge>
                ))}
              </div>
            </div>
            <div className="space-y-2">
              {draftPlan.proposedActions.map((action) => (
                <div key={action.key} className="border-l-2 border-muted pl-3">
                  <div className="flex flex-wrap items-center gap-2">
                    <p className="text-sm font-medium">{action.title}</p>
                    <Badge variant="outline">{action.state}</Badge>
                  </div>
                  <p className="mt-1 text-xs text-muted-foreground">{action.reason}</p>
                </div>
              ))}
              <div className="mt-4 border-t pt-4">
                <div className="flex items-center gap-2">
                  <ShieldCheck className="size-3.5 text-muted-foreground" />
                  <p className="text-[10px] font-semibold text-muted-foreground uppercase tracking-wider">Governance status</p>
                </div>
                <div className="mt-2 flex flex-wrap gap-x-6 gap-y-2">
                  <div>
                    <p className="text-[10px] text-muted-foreground">Template autofill</p>
                    <p className="text-xs font-medium">{draftPlan.autofillState}</p>
                  </div>
                  <div className="flex-1">
                    <p className="text-[10px] text-muted-foreground">Not created</p>
                    <p className="text-xs text-muted-foreground">{draftPlan.unavailableGovernedOutputs.join(" · ")}</p>
                    <p className="mt-1 text-xs text-muted-foreground italic">{draftPlan.governanceNotice}</p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        ) : null}
      </Card>

      {/* 3. Existing Lower Governed Planning & Responsibility Panels */}
      <LifecycleResponsibilityPlan compact />
      <LifecycleDocumentDraftPanel project={project} />

      <Card className="p-5 border-border/80 bg-muted/10">
        <div className="flex items-start gap-3">
          <ShieldCheck className="mt-0.5 size-4 shrink-0 text-primary" />
          <div>
            <h3 className="font-semibold text-sm">Template and external-sharing safeguards</h3>
            <p className="mt-1 text-xs text-muted-foreground leading-relaxed">
              Department leads continue to use existing Drive templates and controlled document settings. Client sharing
              remains governed by the existing restricted, expiring access workflow; no unapproved links are published
              from this view.
            </p>
          </div>
          <ArrowRight className="ml-auto mt-1 size-4 text-muted-foreground shrink-0" />
        </div>
      </Card>

      {/* Adjust Stage Responsibilities Modal */}
      <Dialog open={isStageRespOpen} onOpenChange={setIsStageRespOpen}>
        <DialogContent className="max-w-4xl max-h-[90vh] overflow-y-auto p-4 sm:p-6">
          <DialogHeader className="mb-2">
            <DialogTitle className="flex items-center gap-2">
              <Layers className="size-5 text-primary" />
              Stage {activeStage.stageNumber}: {activeStage.name} — Department Responsibilities
            </DialogTitle>
            <DialogDescription className="text-xs">
              Assign or adjust department roles (Lead / Coordinating / Participating) and deliverables for this lifecycle stage.
            </DialogDescription>
          </DialogHeader>

          <DepartmentStagesManager
            departmentId="rnd"
            departmentName="Engineering & Operations"
            isAdmin={true}
            className="border-0 shadow-none p-0"
            onChanged={() => {
              setRefreshRespKey((k) => k + 1);
            }}
          />
        </DialogContent>
      </Dialog>
    </div>
  );
}