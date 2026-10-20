import { LIFECYCLE_STAGES, type StageStatus } from "./department-chronicles";

export type StageResponsibilityRole = "lead" | "coordinating" | "participating";
export type RraciRole = "responsible" | "reviewer" | "accountable" | "consulted" | "informed";

export const RRACI_CONFIG: Record<
  RraciRole,
  { code: string; label: string; badge: string; text: string; border: string; desc: string }
> = {
  accountable: {
    code: "A",
    label: "Accountable (A)",
    badge: "bg-amber-500/15 text-amber-700 dark:text-amber-400 border-amber-500/30",
    text: "text-amber-700 dark:text-amber-400",
    border: "border-amber-500/30",
    desc: "Single decision authority approving stage gate release",
  },
  responsible: {
    code: "R",
    label: "Responsible (R)",
    badge: "bg-blue-500/15 text-blue-700 dark:text-blue-400 border-blue-500/30",
    text: "text-blue-700 dark:text-blue-400",
    border: "border-blue-500/30",
    desc: "Primary operational or engineering owner executing deliverables",
  },
  reviewer: {
    code: "Rev",
    label: "Reviewer (Rev)",
    badge: "bg-purple-500/15 text-purple-700 dark:text-purple-400 border-purple-500/30",
    text: "text-purple-700 dark:text-purple-400",
    border: "border-purple-500/30",
    desc: "Technical authority reviewing quality, compliance, and design validity",
  },
  consulted: {
    code: "C",
    label: "Consulted (C)",
    badge: "bg-emerald-500/15 text-emerald-700 dark:text-emerald-400 border-emerald-500/30",
    text: "text-emerald-700 dark:text-emerald-400",
    border: "border-emerald-500/30",
    desc: "Subject-matter experts providing two-way technical input",
  },
  informed: {
    code: "I",
    label: "Informed (I)",
    badge: "bg-slate-500/15 text-slate-700 dark:text-slate-400 border-slate-500/30",
    text: "text-slate-700 dark:text-slate-400",
    border: "border-slate-500/30",
    desc: "Stakeholders kept notified of progress, handoffs, and milestones",
  },
};

export function effectiveRraciRole(assignment: DepartmentStageAssignment): RraciRole {
  if (assignment.rraciRole) return assignment.rraciRole;
  if (assignment.role === "lead") return "responsible";
  if (assignment.role === "coordinating") return "reviewer";
  return "consulted";
}

export interface DepartmentStageAssignment {
  id: string; // unique assignment id e.g. "stg-assign-mech-2"
  departmentId: string; // e.g. "mechanical", "rnd", "procurement", "production", "operations", "sales", "firmware", "finance", "hr", "facility"
  stageNumber: number; // 1 to 9
  role: StageResponsibilityRole;
  rraciRole?: RraciRole;
  status: StageStatus;
  deliverables: string[];
  notes?: string;
  isCustom?: boolean;
  updatedAt?: string;
}

export interface DepartmentStageSummary {
  stageNumber: number;
  stageName: string;
  shortName: string;
  isAssigned: boolean;
  assignment?: DepartmentStageAssignment;
}

const STORAGE_KEY = "ssm_department_stage_responsibilities_v2";

/**
 * Authoritative Master Plan Default Stage Responsibilities across all 9 Stages.
 * Seeded as per Master Plan §2, §5, §5.1, §5.2.
 */
export const DEFAULT_DEPARTMENT_STAGE_RESPONSIBILITIES: DepartmentStageAssignment[] = [
  // --- Stage 1: Requirement Intake & Commercial Proposal ---
  {
    id: "assign-sales-stg-1",
    departmentId: "sales",
    stageNumber: 1,
    role: "lead",
    status: "completed",
    deliverables: [
      "Customer PRD v1.0 ingested",
      "Mutual Non-Disclosure Agreement (NDA) executed",
      "Target vehicle battery & bus voltage spec (12V / 24V)",
      "Commercial feasibility estimate & high-level quotation",
    ],
    notes: "Sales leads intake, commercial scoping, and initial OEM customer alignment.",
  },
  {
    id: "assign-ops-stg-1",
    departmentId: "operations",
    stageNumber: 1,
    role: "coordinating",
    status: "completed",
    deliverables: [
      "Opportunity qualification tracking",
      "Customer NDA registry & legal compliance check",
    ],
    notes: "Operations/PM coordinates opportunity tracking and document control.",
  },
  {
    id: "assign-rnd-stg-1",
    departmentId: "rnd",
    stageNumber: 1,
    role: "participating",
    status: "completed",
    deliverables: [
      "High-level vehicle electrical architecture review",
      "Preliminary power rail & MCU fitment check",
    ],
    notes: "R&D reviews vehicle power system context and preliminary technical requirements.",
  },

  // --- Stage 2: Cross-Department Feasibility Assessment ---
  {
    id: "assign-rnd-stg-2",
    departmentId: "rnd",
    stageNumber: 2,
    role: "lead",
    status: "completed",
    deliverables: [
      "Core schematic & power rail architecture sign-off",
      "Nordic nRF52833 BLE 5.2 & Quectel EG915N RF analysis",
      "Battery safety charging circuit evaluation (TI BQ24075)",
    ],
    notes: "Hardware R&D drives electronic architecture and modification analysis.",
  },
  {
    id: "assign-mech-stg-2",
    departmentId: "mechanical",
    stageNumber: 2,
    role: "lead",
    status: "completed",
    deliverables: [
      "IP67 enclosure concept & SolidWorks seal groove calculation",
      "Thermal dissipation & gap pad analysis for battery safety",
      "Vehicle bracket & harness grommet fitment check",
    ],
    notes: "Mechanical leads thermal, ingress protection, and physical mounting feasibility.",
  },
  {
    id: "assign-ops-stg-2",
    departmentId: "operations",
    stageNumber: 2,
    role: "coordinating",
    status: "completed",
    deliverables: [
      "Consolidated multi-department feasibility review sign-off",
      "Technical risk register & preliminary timeline estimation",
    ],
    notes: "PM coordinates cross-functional review and consolidates conditions.",
  },
  {
    id: "assign-proc-stg-2",
    departmentId: "procurement",
    stageNumber: 2,
    role: "participating",
    status: "completed",
    deliverables: [
      "Preliminary electronic BOM costing & supplier lead-time check",
      "Long lead-time critical component identification (SoC, GSM module)",
    ],
    notes: "Procurement checks supplier availability and BOM cost benchmarks.",
  },
  {
    id: "assign-sales-stg-2",
    departmentId: "sales",
    stageNumber: 2,
    role: "participating",
    status: "completed",
    deliverables: [
      "Customer budget and volume forecast alignment (25k-50k units/yr)",
      "Commercial pricing tier confirmation",
    ],
    notes: "Sales confirms OEM customer volume thresholds and price targets.",
  },
  {
    id: "assign-prod-stg-2",
    departmentId: "production",
    stageNumber: 2,
    role: "participating",
    status: "completed",
    deliverables: [
      "Design for Manufacturing (DFM) panelization feasibility",
      "SMT pick-and-place component height check",
    ],
    notes: "Production validates DFM constraints and line assembly feasibility.",
  },

  // --- Stage 3: Customer Authorization & Baseline Freeze ---
  {
    id: "assign-ops-stg-3",
    departmentId: "operations",
    stageNumber: 3,
    role: "lead",
    status: "completed",
    deliverables: [
      "Product Requirement Specification (PRS v1.0) freeze",
      "Customer formal Letter of Intent (LOI) / Purchase Order verification",
      "Change control baseline lock & project gate authorization",
    ],
    notes: "Operations / Project Management owns baseline lock and project-start gate.",
  },
  {
    id: "assign-sales-stg-3",
    departmentId: "sales",
    stageNumber: 3,
    role: "coordinating",
    status: "completed",
    deliverables: [
      "Signed customer quotation & SOW freeze",
      "Commercial milestone payment schedule agreement",
    ],
    notes: "Sales secures customer contract signatures and milestone billing terms.",
  },
  {
    id: "assign-rnd-stg-3",
    departmentId: "rnd",
    stageNumber: 3,
    role: "participating",
    status: "completed",
    deliverables: [
      "Engineering baseline scope commitment",
      "Technical risk mitigation commitments",
    ],
    notes: "Engineering commits to technical delivery specifications and frozen scope.",
  },

  // --- Stage 4: Research, Proof-of-Concept & Circuit Simulation ---
  {
    id: "assign-rnd-stg-4",
    departmentId: "rnd",
    stageNumber: 4,
    role: "lead",
    status: "completed",
    deliverables: [
      "SPICE power rail simulation & bench breadboard testing",
      "BLE 5.2 Nordic beacon transmission range qualification (25m)",
      "TI BQ24075 dynamic power-path thermal profiling under load",
    ],
    notes: "Hardware R&D drives circuit simulations and POC demonstrators. (Reused designs record authorized bypass).",
  },
  {
    id: "assign-mech-stg-4",
    departmentId: "mechanical",
    stageNumber: 4,
    role: "lead",
    status: "completed",
    deliverables: [
      "Rapid prototype SLA 3D printed enclosure mockup",
      "Battery pocket vibration cushion & internal clearance check",
      "Connector opening and LED light-pipe alignment",
    ],
    notes: "Mechanical validates 3D fitment and battery retention in prototype mockup.",
  },
  {
    id: "assign-ops-stg-4",
    departmentId: "operations",
    stageNumber: 4,
    role: "coordinating",
    status: "completed",
    deliverables: [
      "POC milestone demonstration review with OEM customer",
      "Proven design reuse justification audit",
    ],
    notes: "PM coordinates demonstration and audits POC exit criteria.",
  },
  {
    id: "assign-proc-stg-4",
    departmentId: "procurement",
    stageNumber: 4,
    role: "participating",
    status: "completed",
    deliverables: [
      "Sample parts acquisition for engineering bench prototypes",
      "Preliminary vendor quotes for custom rechargeable Li-ion pouch cell",
    ],
    notes: "Procurement secures engineering samples and candidate battery vendors.",
  },

  // --- Stage 5: Pilot Manufacturing & Tooling Preparation ---
  {
    id: "assign-prod-stg-5",
    departmentId: "production",
    stageNumber: 5,
    role: "lead",
    status: "in_progress",
    deliverables: [
      "Pilot SMT stencil fabrication & Fuji pick-and-place feeder setup",
      "First Article Inspection (FAI) on initial 25 pilot PCBA units",
      "Automated Optical Inspection (AOI) program creation",
    ],
    notes: "Production leads pilot SMT line setup and assembly inspection.",
  },
  {
    id: "assign-rnd-stg-5",
    departmentId: "rnd",
    stageNumber: 5,
    role: "lead",
    status: "in_progress",
    deliverables: [
      "PCB-TLM-V2.1-BLE Gerber release to fabrication partner",
      "Firmware v1.0.4 bring-up flashing & automated diagnostic script",
      "Tentative electronic BOM freeze for pilot batch",
    ],
    notes: "R&D releases Gerbers, tentative BOM, and board bring-up firmware.",
  },
  {
    id: "assign-mech-stg-5",
    departmentId: "mechanical",
    stageNumber: 5,
    role: "lead",
    status: "in_progress",
    deliverables: [
      "Single-cavity aluminium injection mould tooling for ABS+PC enclosure",
      "Laser-cut silicone sealing gasket v1 tooling",
      "Enclosure drop-test verification from 1.5m on concrete",
    ],
    notes: "Mechanical delivers injection mould tooling and enclosure pilot parts.",
  },
  {
    id: "assign-proc-stg-5",
    departmentId: "procurement",
    stageNumber: 5,
    role: "participating",
    status: "in_progress",
    deliverables: [
      "Pilot batch SMT electronic component kit procurement",
      "Mechanical hardware, fasteners, and IP67 breather valves kit",
    ],
    notes: "Procurement delivers kitted bill of materials for pilot assembly.",
  },
  {
    id: "assign-ops-stg-5",
    departmentId: "operations",
    stageNumber: 5,
    role: "coordinating",
    status: "in_progress",
    deliverables: [
      "Pilot build traveler checklist & serialization protocol",
      "Pilot build sign-off gate review",
    ],
    notes: "Operations coordinates quality travelers and batch traceability.",
  },

  // --- Stage 6: DVP&R, Regulatory & Homologation Testing ---
  {
    id: "assign-ops-stg-6",
    departmentId: "operations",
    stageNumber: 6,
    role: "lead",
    status: "in_progress",
    deliverables: [
      "DVP&R master test plan execution & tracking",
      "iCAT AIS-140 / AIS-004 Automotive Homologation Certification",
      "NABL Accredited Testing Laboratory Battery Safety Report (UN 38.3 & IS 16046)",
    ],
    notes: "Operations/Quality leads external lab homologation and formal certification.",
  },
  {
    id: "assign-rnd-stg-6",
    departmentId: "rnd",
    stageNumber: 6,
    role: "coordinating",
    status: "in_progress",
    deliverables: [
      "Environmental Bench Testing (EBT: -20°C to +70°C chamber sweep)",
      "Automotive electrical transients testing (ISO 7637-2 pulse 1, 2a, 3a/b)",
      "RF harmonic emissions & BLE antenna tuning report",
    ],
    notes: "R&D conducts electrical, thermal, and RF pre-compliance testing.",
  },
  {
    id: "assign-mech-stg-6",
    departmentId: "mechanical",
    stageNumber: 6,
    role: "participating",
    status: "in_progress",
    deliverables: [
      "IP67 ingress test certification (water submersion 1m for 30 min)",
      "Automotive random vibration & mechanical shock test (ISO 16750-3)",
    ],
    notes: "Mechanical validates physical enclosure sealing under pressure wash and vibration.",
  },
  {
    id: "assign-prod-stg-6",
    departmentId: "production",
    stageNumber: 6,
    role: "participating",
    status: "in_progress",
    deliverables: [
      "Test sample assembly tracking and serial verification",
      "Post-test visual teardown inspection support",
    ],
    notes: "Production supports test unit preparation and teardown analysis.",
  },

  // --- Stage 7: Engineering Release (DVT / PVT Sign-off) ---
  {
    id: "assign-rnd-stg-7",
    departmentId: "rnd",
    stageNumber: 7,
    role: "lead",
    status: "waiting",
    deliverables: [
      "Golden Gerber release & MD5/SHA256 checksum manifest",
      "Production schematics, assembly drawings, and test points freeze",
      "Engineering Change Order (ECO) lock for series production",
    ],
    notes: "R&D issues frozen golden engineering package and checksum manifest.",
  },
  {
    id: "assign-ops-stg-7",
    departmentId: "operations",
    stageNumber: 7,
    role: "coordinating",
    status: "waiting",
    deliverables: [
      "Design Validation (DVT) & Production Validation (PVT) sign-off",
      "Engineering Release Notice (ERN) controlled distribution",
    ],
    notes: "Operations issues formal ERN and archives engineering documents.",
  },
  {
    id: "assign-proc-stg-7",
    departmentId: "procurement",
    stageNumber: 7,
    role: "participating",
    status: "waiting",
    deliverables: [
      "Approved Manufacturer List (AML) & Approved Vendor List (AVL) freeze",
      "Component end-of-life / lifecycle risk assessment",
    ],
    notes: "Procurement locks approved vendor sources against golden BOM.",
  },
  {
    id: "assign-prod-stg-7",
    departmentId: "production",
    stageNumber: 7,
    role: "participating",
    status: "waiting",
    deliverables: [
      "PVT manufacturing sign-off & line yield targets",
      "Work instructions and operator SOP sign-off",
    ],
    notes: "Production confirms process readiness and yield targets.",
  },

  // --- Stage 8: Supply Chain & Production Readiness ---
  {
    id: "assign-proc-stg-8",
    departmentId: "procurement",
    stageNumber: 8,
    role: "lead",
    status: "waiting",
    deliverables: [
      "Production Part Approval Process (PPAP Level 3) package",
      "Long lead-time electronic component supply buffer (8-12 weeks)",
      "Vendor frame contracts and volume discount purchase orders",
    ],
    notes: "Procurement leads PPAP submissions and supply chain buffer readiness.",
  },
  {
    id: "assign-prod-stg-8",
    departmentId: "production",
    stageNumber: 8,
    role: "lead",
    status: "waiting",
    deliverables: [
      "Multi-cavity production tooling commissioning (5,000 units/mo)",
      "Automated End-of-Line (EOL) functional test jig calibration",
      "Laser marking & barcode scanner integration on packaging line",
    ],
    notes: "Production commissions high-volume tooling and calibrated test jigs.",
  },
  {
    id: "assign-ops-stg-8",
    departmentId: "operations",
    stageNumber: 8,
    role: "coordinating",
    status: "waiting",
    deliverables: [
      "APQP gate 4 review sign-off",
      "Quality calibration records and ESD compliance certificate",
    ],
    notes: "Operations signs off APQP gate and audits plant ESD compliance.",
  },

  // --- Stage 9: Series Mass Production & Dispatch ---
  {
    id: "assign-prod-stg-9",
    departmentId: "production",
    stageNumber: 9,
    role: "lead",
    status: "waiting",
    deliverables: [
      "Series production lot execution (Batch 01: 2,500 units)",
      "100% End-of-Line (EOL) functional testing & telemetry ping verification",
      "Pre-Delivery Inspection (PDI) report & QA sticker application",
    ],
    notes: "Production runs mass assembly, automated EOL testing, and packing.",
  },
  {
    id: "assign-ops-stg-9",
    departmentId: "operations",
    stageNumber: 9,
    role: "coordinating",
    status: "waiting",
    deliverables: [
      "Dispatch clearance & Outgoing Quality Control (OQC) sign-off",
      "Logistics airway bill & transporter ASN tracking",
    ],
    notes: "Operations issues OQC dispatch clearance and shipment tracking.",
  },
  {
    id: "assign-sales-stg-9",
    departmentId: "sales",
    stageNumber: 9,
    role: "participating",
    status: "waiting",
    deliverables: [
      "Customer dispatch advice notice & packing slip transmission",
      "Warranty start date registration and installation coordination",
    ],
    notes: "Sales notifies OEM customer and tracks delivery acceptance.",
  },
];

let inMemoryResponsibilities: DepartmentStageAssignment[] | null = null;

function loadStoredResponsibilities(): DepartmentStageAssignment[] {
  if (inMemoryResponsibilities) return inMemoryResponsibilities;

  if (typeof window !== "undefined") {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      if (raw) {
        const parsed = JSON.parse(raw);
        if (Array.isArray(parsed) && parsed.length > 0) {
          inMemoryResponsibilities = parsed;
          return inMemoryResponsibilities!;
        }
      }
    } catch {
      // fallback
    }
  }

  inMemoryResponsibilities = [...DEFAULT_DEPARTMENT_STAGE_RESPONSIBILITIES];
  return inMemoryResponsibilities;
}

function persistResponsibilities(list: DepartmentStageAssignment[]): void {
  inMemoryResponsibilities = list;
  if (typeof window !== "undefined") {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(list));
    } catch {
      // fallback
    }
  }
}

/**
 * Normalizes department ID or code to standard slug
 */
export function normalizeDepartmentId(idOrCode?: string | null): string {
  if (!idOrCode) return "rnd";
  const lower = idOrCode.toLowerCase().trim();
  if (lower.includes("mech")) return "mechanical";
  if (lower.includes("rnd") || lower.includes("hard") || lower.includes("eng") || lower === "rd") return "rnd";
  if (lower.includes("proc") || lower.includes("purch") || lower.includes("store")) return "procurement";
  if (lower.includes("prod") || lower.includes("mfg")) return "production";
  if (lower.includes("sale") || lower.includes("comm") || lower === "sal" || lower.startsWith("sal")) return "sales";
  if (lower.includes("ops") || lower.includes("qual") || lower.includes("qms") || lower.includes("pm") || lower === "qa") return "operations";
  if (lower.includes("fac") || lower.includes("maint")) return "facility";
  if (lower.includes("firm") || lower.includes("soft") || lower === "fw" || lower === "sw") return "firmware";
  if (lower.includes("fin")) return "finance";
  if (lower.includes("hr")) return "hr";
  return lower;
}

/**
 * Returns all stages assigned to a department as per its responsibilities.
 */
export function getAssignedStagesForDepartment(departmentId: string): DepartmentStageAssignment[] {
  const normDept = normalizeDepartmentId(departmentId);
  const all = loadStoredResponsibilities();
  return all
    .filter((a) => normalizeDepartmentId(a.departmentId) === normDept)
    .sort((a, b) => a.stageNumber - b.stageNumber);
}

/**
 * Returns summary of all 9 stages indicating which ones are assigned to this department
 */
export function getDepartmentStagesSummary(departmentId: string): DepartmentStageSummary[] {
  const assigned = getAssignedStagesForDepartment(departmentId);
  const assignedMap = new Map<number, DepartmentStageAssignment>();
  assigned.forEach((a) => assignedMap.set(a.stageNumber, a));

  return LIFECYCLE_STAGES.map((stg) => {
    const assignment = assignedMap.get(stg.stageNumber);
    return {
      stageNumber: stg.stageNumber,
      stageName: stg.name,
      shortName: stg.shortName,
      isAssigned: Boolean(assignment),
      assignment,
    };
  });
}

/**
 * Returns all departments assigned to a specific stage with their roles
 */
export function getDepartmentsForStage(stageNumber: number): DepartmentStageAssignment[] {
  const all = loadStoredResponsibilities();
  return all
    .filter((a) => a.stageNumber === stageNumber)
    .sort((a, b) => {
      const roleWeight = { lead: 1, coordinating: 2, participating: 3 };
      return (roleWeight[a.role] || 9) - (roleWeight[b.role] || 9);
    });
}

/**
 * Gives / assigns a stage to a department as per responsibilities
 */
export function assignStageToDepartment(
  departmentId: string,
  stageNumber: number,
  role: StageResponsibilityRole = "participating",
  deliverables: string[] = [],
  status: StageStatus = "in_progress",
  notes?: string
): DepartmentStageAssignment {
  const normDept = normalizeDepartmentId(departmentId);
  const all = loadStoredResponsibilities();

  const existingIdx = all.findIndex(
    (a) => normalizeDepartmentId(a.departmentId) === normDept && a.stageNumber === stageNumber
  );

  const defaultStage = LIFECYCLE_STAGES.find((s) => s.stageNumber === stageNumber);
  const finalDeliverables =
    deliverables.length > 0
      ? deliverables
      : [`${defaultStage?.shortName || `Stage ${stageNumber}`} milestone deliverable`];

  const record: DepartmentStageAssignment = {
    id: existingIdx >= 0 ? all[existingIdx].id : `stg-assign-${normDept}-${stageNumber}-${Date.now().toString(36)}`,
    departmentId: normDept,
    stageNumber,
    role,
    status,
    deliverables: finalDeliverables,
    notes: notes || existingIdx >= 0 ? all[existingIdx]?.notes : `Assigned as ${role} for Stage ${stageNumber}`,
    isCustom: true,
    updatedAt: new Date().toISOString(),
  };

  let updatedList: DepartmentStageAssignment[];
  if (existingIdx >= 0) {
    updatedList = [...all];
    updatedList[existingIdx] = record;
  } else {
    updatedList = [...all, record];
  }

  persistResponsibilities(updatedList);
  return record;
}

/**
 * Unassigns / removes a stage from a department
 */
export function unassignStageFromDepartment(departmentId: string, stageNumber: number): boolean {
  const normDept = normalizeDepartmentId(departmentId);
  const all = loadStoredResponsibilities();
  const filtered = all.filter(
    (a) => !(normalizeDepartmentId(a.departmentId) === normDept && a.stageNumber === stageNumber)
  );

  if (filtered.length !== all.length) {
    persistResponsibilities(filtered);
    return true;
  }
  return false;
}

/**
 * Updates the responsibility role (Lead, Coordinating, Participating) for a department's stage
 */
export function updateDepartmentStageRole(
  departmentId: string,
  stageNumber: number,
  role: StageResponsibilityRole
): DepartmentStageAssignment | null {
  const normDept = normalizeDepartmentId(departmentId);
  const all = loadStoredResponsibilities();
  const idx = all.findIndex(
    (a) => normalizeDepartmentId(a.departmentId) === normDept && a.stageNumber === stageNumber
  );

  if (idx < 0) return null;

  const updated: DepartmentStageAssignment = {
    ...all[idx],
    role,
    updatedAt: new Date().toISOString(),
  };
  const list = [...all];
  list[idx] = updated;
  persistResponsibilities(list);
  return updated;
}

/**
 * Updates the RRACI role (Responsible, Reviewer, Accountable, Consulted, Informed)
 */
export function updateDepartmentStageRraciRole(
  departmentId: string,
  stageNumber: number,
  rraciRole: RraciRole
): DepartmentStageAssignment | null {
  const normDept = normalizeDepartmentId(departmentId);
  const all = loadStoredResponsibilities();
  const idx = all.findIndex(
    (a) => normalizeDepartmentId(a.departmentId) === normDept && a.stageNumber === stageNumber
  );

  if (idx < 0) return null;

  const updated: DepartmentStageAssignment = {
    ...all[idx],
    rraciRole,
    updatedAt: new Date().toISOString(),
  };
  const list = [...all];
  list[idx] = updated;
  persistResponsibilities(list);
  return updated;
}

/**
 * Updates stage execution status (completed, in_progress, blocked, waiting, bypassed)
 */
export function updateDepartmentStageStatus(
  departmentId: string,
  stageNumber: number,
  status: StageStatus
): DepartmentStageAssignment | null {
  const normDept = normalizeDepartmentId(departmentId);
  const all = loadStoredResponsibilities();
  const idx = all.findIndex(
    (a) => normalizeDepartmentId(a.departmentId) === normDept && a.stageNumber === stageNumber
  );

  if (idx < 0) return null;

  const updated: DepartmentStageAssignment = {
    ...all[idx],
    status,
    updatedAt: new Date().toISOString(),
  };
  const list = [...all];
  list[idx] = updated;
  persistResponsibilities(list);
  return updated;
}

/**
 * Updates the deliverables list for a department's stage
 */
export function updateDepartmentStageDeliverables(
  departmentId: string,
  stageNumber: number,
  deliverables: string[]
): DepartmentStageAssignment | null {
  const normDept = normalizeDepartmentId(departmentId);
  const all = loadStoredResponsibilities();
  const idx = all.findIndex(
    (a) => normalizeDepartmentId(a.departmentId) === normDept && a.stageNumber === stageNumber
  );

  if (idx < 0) return null;

  const updated: DepartmentStageAssignment = {
    ...all[idx],
    deliverables,
    updatedAt: new Date().toISOString(),
  };
  const list = [...all];
  list[idx] = updated;
  persistResponsibilities(list);
  return updated;
}

/**
 * Resets all stage responsibilities back to Master Plan baseline defaults
 */
export function resetDepartmentStageResponsibilities(): void {
  inMemoryResponsibilities = null;
  if (typeof window !== "undefined") {
    try {
      localStorage.removeItem(STORAGE_KEY);
    } catch {
      // fallback
    }
  }
}
