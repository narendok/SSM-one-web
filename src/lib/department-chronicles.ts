export type ChronicleCategory = "milestone" | "update" | "decision" | "notice" | "incident";
export type StageStatus = "completed" | "in_progress" | "blocked" | "waiting" | "bypassed";

export interface DepartmentChronicle {
  id: string;
  departmentId: string; // e.g. "mechanical", "rnd", "procurement", "production", "operations", "sales", "finance", "hr", or "all"
  projectCode?: string; // e.g. "PRJ-TLM-002", "PRJ-TLM-001"
  projectName?: string; // e.g. "Mahindra Fleet Telematics (BLE 5.2)", "Tata Motors CV Telematics"
  stageNumber?: number; // 1 to 9
  stageName?: string;   // e.g. "Stage 1: Intake", "Stage 6: Validation"
  stageStatus?: StageStatus; // "completed", "in_progress", "blocked", "waiting", "bypassed"
  title: string;
  content: string;
  category: ChronicleCategory;
  deliverables?: string[];
  authorName: string;
  authorRole: string;
  createdAt: string; // ISO
  pinned?: boolean;
}

export const LIFECYCLE_STAGES = [
  { stageNumber: 1, name: "Stage 1: Intake & Commercial Proposal", shortName: "Intake" },
  { stageNumber: 2, name: "Stage 2: Cross-Department Feasibility Assessment", shortName: "Feasibility" },
  { stageNumber: 3, name: "Stage 3: Customer Authorization & Baseline Freeze", shortName: "Baseline" },
  { stageNumber: 4, name: "Stage 4: Research, Proof-of-Concept & Circuit Simulation", shortName: "Research / POC" },
  { stageNumber: 5, name: "Stage 5: Pilot Manufacturing & Tooling Preparation", shortName: "Pilot" },
  { stageNumber: 6, name: "Stage 6: DVP&R, Regulatory & Homologation Testing", shortName: "Validation" },
  { stageNumber: 7, name: "Stage 7: Engineering Release (DVT / PVT Sign-off)", shortName: "Release" },
  { stageNumber: 8, name: "Stage 8: Supply Chain & Production Readiness", shortName: "Supply Readiness" },
  { stageNumber: 9, name: "Stage 9: Series Mass Production & Dispatch", shortName: "Production" },
] as const;

export function getStageNameByNumber(num?: number): string | undefined {
  if (!num) return undefined;
  return LIFECYCLE_STAGES.find((s) => s.stageNumber === num)?.name;
}

const STORAGE_KEY = "ssm_department_chronicles_v2";

export const INITIAL_SAMPLE_CHRONICLES: DepartmentChronicle[] = [
  // --- Stage 1: Intake ---
  {
    id: "chr-stg-1-01",
    departmentId: "sales",
    projectCode: "PRJ-TLM-002",
    projectName: "Mahindra Fleet Telematics (BLE 5.2 + 3.7V Li-ion)",
    stageNumber: 1,
    stageName: "Stage 1: Intake & Commercial Proposal",
    stageStatus: "completed",
    title: "Customer PRD v1.0 Ingested & Scoped",
    content: "Customer requirements validated against OEM fleet tracking standard. Mutual NDA executed and target vehicle 12V/24V power architecture verified.",
    category: "milestone",
    deliverables: ["Customer PRD v1.0 ingested", "Mutual NDA executed", "12V/24V power architecture verified"],
    authorName: "Siddharth Rao",
    authorRole: "Commercial Director",
    createdAt: new Date(Date.now() - 3600 * 1000 * 24 * 35).toISOString(),
    pinned: true,
  },
  {
    id: "chr-stg-1-02",
    departmentId: "sales",
    projectCode: "PRJ-TLM-001",
    projectName: "Tata Motors CV Telematics 12V Direct Reuse",
    stageNumber: 1,
    stageName: "Stage 1: Intake & Commercial Proposal",
    stageStatus: "completed",
    title: "Tata Motors CV Enquiry & Direct SOW Qualified",
    content: "Customer requested standard 12V GPS telematics unit. Commercial scope finalized under LOI for 25,000 annual volume.",
    category: "milestone",
    deliverables: ["Standard PRD confirmed", "Commercial LOI signed"],
    authorName: "Siddharth Rao",
    authorRole: "Commercial Director",
    createdAt: new Date(Date.now() - 3600 * 1000 * 24 * 40).toISOString(),
  },

  // --- Stage 2: Feasibility ---
  {
    id: "chr-stg-2-01",
    departmentId: "mechanical",
    projectCode: "PRJ-TLM-002",
    projectName: "Mahindra Fleet Telematics (BLE 5.2 + 3.7V Li-ion)",
    stageNumber: 2,
    stageName: "Stage 2: Cross-Department Feasibility Assessment",
    stageStatus: "completed",
    title: "IP67 Enclosure & Thermal Feasibility Signed Off",
    content: "Enclosure requires SolidWorks seal groove optimization and Gore-Tex breather valve to prevent condensation during pressure wash.",
    category: "decision",
    deliverables: ["IP67 enclosure feasibility analysis", "Thermal gap pad calculation"],
    authorName: "Arun Kulkarni",
    authorRole: "Lead Mechanical Engineer",
    createdAt: new Date(Date.now() - 3600 * 1000 * 24 * 30).toISOString(),
    pinned: true,
  },
  {
    id: "chr-stg-2-02",
    departmentId: "rnd",
    projectCode: "PRJ-TLM-002",
    projectName: "Mahindra Fleet Telematics (BLE 5.2 + 3.7V Li-ion)",
    stageNumber: 2,
    stageName: "Stage 2: Cross-Department Feasibility Assessment",
    stageStatus: "completed",
    title: "BLE 5.2 & 3.7V Battery Hardware Architecture Sign-off",
    content: "Hardware modification feasibility approved: board spin to PCB-TLM-V2.1-BLE with Nordic nRF52833 SoC and TI BQ24075 dynamic power-path IC.",
    category: "milestone",
    deliverables: ["Architecture block diagram", "BQ24075 power budget simulation"],
    authorName: "Dr. Rajesh Sharma",
    authorRole: "Hardware Lead",
    createdAt: new Date(Date.now() - 3600 * 1000 * 24 * 28).toISOString(),
  },
  {
    id: "chr-stg-2-03",
    departmentId: "rnd",
    projectCode: "PRJ-TLM-001",
    projectName: "Tata Motors CV Telematics 12V Direct Reuse",
    stageNumber: 2,
    stageName: "Stage 2: Cross-Department Feasibility Assessment",
    stageStatus: "completed",
    title: "100% Direct Hardware Reuse Formally Approved",
    content: "Existing PCB-TLM-V2.0 matches 100% of Tata CV requirements with zero hardware spins. EVT POC stage approved to be bypassed.",
    category: "decision",
    deliverables: ["Direct reuse waiver document", "Bypass justification memo"],
    authorName: "Dr. Rajesh Sharma",
    authorRole: "Hardware Lead",
    createdAt: new Date(Date.now() - 3600 * 1000 * 24 * 32).toISOString(),
  },

  // --- Stage 3: Baseline ---
  {
    id: "chr-stg-3-01",
    departmentId: "operations",
    projectCode: "PRJ-TLM-002",
    projectName: "Mahindra Fleet Telematics (BLE 5.2 + 3.7V Li-ion)",
    stageNumber: 3,
    stageName: "Stage 3: Customer Authorization & Baseline Freeze",
    stageStatus: "completed",
    title: "Customer PO Received & Baseline BASE-TLM-002 Frozen",
    content: "Customer purchase order formal LOI acknowledged. Baseline specification locked. Any further requirements changes require formal ECO approval.",
    category: "milestone",
    deliverables: ["Baseline Specification BASE-TLM-002", "Revision control activated", "Master project schedule"],
    authorName: "Ananya Roy",
    authorRole: "Project Manager",
    createdAt: new Date(Date.now() - 3600 * 1000 * 24 * 25).toISOString(),
    pinned: true,
  },

  // --- Stage 4: Research / POC ---
  {
    id: "chr-stg-4-01",
    departmentId: "rnd",
    projectCode: "PRJ-TLM-002",
    projectName: "Mahindra Fleet Telematics (BLE 5.2 + 3.7V Li-ion)",
    stageNumber: 4,
    stageName: "Stage 4: Research, Proof-of-Concept & Circuit Simulation",
    stageStatus: "completed",
    title: "Nordic BLE 5.2 TPMS Beacon Range Verified (35m In-Vehicle)",
    content: "Bench EVT prototype successfully decoded TPMS BLE tire pressure sensor packets at 35 meters line-of-sight. TI BQ24075 charging efficiency measured at 92%.",
    category: "milestone",
    deliverables: ["Breadboard EVT test report", "BLE RSSI signal mapping", "Battery charging efficiency curve"],
    authorName: "Devon Lane",
    authorRole: "Firmware Lead",
    createdAt: new Date(Date.now() - 3600 * 1000 * 24 * 20).toISOString(),
  },
  {
    id: "chr-stg-4-02",
    departmentId: "rnd",
    projectCode: "PRJ-TLM-001",
    projectName: "Tata Motors CV Telematics 12V Direct Reuse",
    stageNumber: 4,
    stageName: "Stage 4: Research, Proof-of-Concept & Circuit Simulation",
    stageStatus: "bypassed",
    title: "EVT POC Stage Bypassed for Proven Design",
    content: "Direct reuse of proven PCB-TLM-V2.0 eliminates prototype breadboard risk. Team transitioned directly to pilot SMT line setup.",
    category: "notice",
    deliverables: ["EVT bypass justification memo signed"],
    authorName: "Ananya Roy",
    authorRole: "Project Manager",
    createdAt: new Date(Date.now() - 3600 * 1000 * 24 * 26).toISOString(),
  },

  // --- Stage 5: Pilot ---
  {
    id: "chr-stg-5-01",
    departmentId: "production",
    projectCode: "PRJ-TLM-002",
    projectName: "Mahindra Fleet Telematics (BLE 5.2 + 3.7V Li-ion)",
    stageNumber: 5,
    stageName: "Stage 5: Pilot Manufacturing & Tooling Preparation",
    stageStatus: "completed",
    title: "150 Prototype Units Assembled on SMT Line 2",
    content: "Lead-free SAC305 10-zone reflow profile qualified. First article inspection (AOI) passed with 100% yield on 0402 passives and BGA ICs.",
    category: "milestone",
    deliverables: ["150 prototype units built", "SMT reflow profile report", "First Article AOI record"],
    authorName: "Casey Rowan",
    authorRole: "Production Lead",
    createdAt: new Date(Date.now() - 3600 * 1000 * 24 * 15).toISOString(),
    pinned: true,
  },
  {
    id: "chr-stg-5-02",
    departmentId: "mechanical",
    projectCode: "PRJ-TLM-002",
    projectName: "Mahindra Fleet Telematics (BLE 5.2 + 3.7V Li-ion)",
    stageNumber: 5,
    stageName: "Stage 5: Pilot Manufacturing & Tooling Preparation",
    stageStatus: "completed",
    title: "First-Article Polycarbonate Tooling Samples Verified",
    content: "First-off tool injection molded PC/ABS housing samples arrived from toolmaker. Ultrasonic welding rib and silicone gasket groove dimensionally verified.",
    category: "milestone",
    deliverables: ["CMM dimensional report", "Mold flow correlation analysis"],
    authorName: "Arun Kulkarni",
    authorRole: "Lead Mechanical Engineer",
    createdAt: new Date(Date.now() - 3600 * 1000 * 24 * 16).toISOString(),
  },
  {
    id: "chr-stg-5-03",
    departmentId: "production",
    projectCode: "PRJ-TLM-001",
    projectName: "Tata Motors CV Telematics 12V Direct Reuse",
    stageNumber: 5,
    stageName: "Stage 5: Pilot Manufacturing & Tooling Preparation",
    stageStatus: "in_progress",
    title: "SMT Line 2 Tooling & Stencil Calibration for Tata Units",
    content: "SMT feeder loading and stencil calibration active for 50-unit pilot batch.",
    category: "update",
    deliverables: ["SMT Stencil fabrication", "Feeder setup verification"],
    authorName: "Casey Rowan",
    authorRole: "Production Lead",
    createdAt: new Date(Date.now() - 3600 * 1000 * 24 * 5).toISOString(),
  },

  // --- Stage 6: Validation ---
  {
    id: "chr-stg-6-01",
    departmentId: "operations",
    projectCode: "PRJ-TLM-002",
    projectName: "Mahindra Fleet Telematics (BLE 5.2 + 3.7V Li-ion)",
    stageNumber: 6,
    stageName: "Stage 6: DVP&R, Regulatory & Homologation Testing",
    stageStatus: "completed",
    title: "iCAT AIS-140 Homologation Certificate Received",
    content: "Official certification iCAT/AIS140/2026/0892 issued following EMC/EMI, vibration, and automotive electrical transient testing under AIS-004.",
    category: "milestone",
    deliverables: ["iCAT Test Report iCAT/AIS140/2026/0892", "EMC/EMI test certificate"],
    authorName: "Deepak Chawla",
    authorRole: "Regulatory & Homologation Lead",
    createdAt: new Date(Date.now() - 3600 * 1000 * 24 * 8).toISOString(),
    pinned: true,
  },
  {
    id: "chr-stg-6-02",
    departmentId: "operations",
    projectCode: "PRJ-TLM-002",
    projectName: "Mahindra Fleet Telematics (BLE 5.2 + 3.7V Li-ion)",
    stageNumber: 6,
    stageName: "Stage 6: DVP&R, Regulatory & Homologation Testing",
    stageStatus: "completed",
    title: "NABL Battery Safety Certification (UN 38.3 & IS 16046)",
    content: "NABL certified laboratory issued test certificate NABL/BAT/2026/4412 for 3.7V 850mAh Li-ion pouch cell. Overcharge, short-circuit, and crush tests passed 100%.",
    category: "milestone",
    deliverables: ["NABL Safety Report NABL/BAT/2026/4412", "UN 38.3 compliance dossier"],
    authorName: "Deepak Chawla",
    authorRole: "Regulatory & Homologation Lead",
    createdAt: new Date(Date.now() - 3600 * 1000 * 24 * 7).toISOString(),
    pinned: true,
  },
  {
    id: "chr-stg-6-03",
    departmentId: "operations",
    projectCode: "PRJ-TLM-002",
    projectName: "Mahindra Fleet Telematics (BLE 5.2 + 3.7V Li-ion)",
    stageNumber: 6,
    stageName: "Stage 6: DVP&R, Regulatory & Homologation Testing",
    stageStatus: "in_progress",
    title: "500-Hour Environmental Chamber Thermal Shock Test",
    content: "Units undergoing 500-hour thermal shock cycling (-20°C to +70°C) with continuous 4G/BLE telemetry transmission. 360 hours elapsed without reset.",
    category: "update",
    deliverables: ["Environmental Chamber Log", "IP67 1-meter immersion test report"],
    authorName: "Jordan Blake",
    authorRole: "Quality APQP Lead",
    createdAt: new Date(Date.now() - 3600 * 1000 * 24 * 2).toISOString(),
  },

  // --- Stage 7: Release ---
  {
    id: "chr-stg-7-01",
    departmentId: "rnd",
    projectCode: "PRJ-TLM-002",
    projectName: "Mahindra Fleet Telematics (BLE 5.2 + 3.7V Li-ion)",
    stageNumber: 7,
    stageName: "Stage 7: Engineering Release (DVT / PVT Sign-off)",
    stageStatus: "waiting",
    title: "Golden BOM & Production Firmware Hash Pending Final Review",
    content: "Golden Master BOM BOM-TLM-2026-E01 and firmware production hex binary prepared for Gate 7 release lock pending final chamber test completion.",
    category: "notice",
    deliverables: ["Golden Master BOM locked", "Production hex hash signed", "Fabrication Gerbers archived"],
    authorName: "Dr. Rajesh Sharma",
    authorRole: "Hardware Lead",
    createdAt: new Date(Date.now() - 3600 * 1000 * 24 * 3).toISOString(),
  },

  // --- Stage 8: Supply Readiness ---
  {
    id: "chr-stg-8-01",
    departmentId: "procurement",
    projectCode: "PRJ-TLM-002",
    projectName: "Mahindra Fleet Telematics (BLE 5.2 + 3.7V Li-ion)",
    stageNumber: 8,
    stageName: "Stage 8: Supply Chain & Production Readiness",
    stageStatus: "waiting",
    title: "Supplier PPAP Level 3 & Buffer Stock Scheduled",
    content: "Procurement secured Quectel EG915N and Nordic nRF52833 allocation. PPAP Level 3 documentation in review with suppliers for series manufacturing.",
    category: "decision",
    deliverables: ["Supplier PPAP Level 3 dossier", "30-day buffer inventory plan", "Stores inwarding checklist"],
    authorName: "Morgan Reed",
    authorRole: "SCM Controller",
    createdAt: new Date(Date.now() - 3600 * 1000 * 24 * 4).toISOString(),
  },

  // --- Stage 9: Production ---
  {
    id: "chr-stg-9-01",
    departmentId: "production",
    projectCode: "PRJ-TLM-002",
    projectName: "Mahindra Fleet Telematics (BLE 5.2 + 3.7V Li-ion)",
    stageNumber: 9,
    stageName: "Stage 9: Series Mass Production & Dispatch",
    stageStatus: "waiting",
    title: "Series SOP & End-of-Line Automated Test Jig Ready",
    content: "Automated FCT test fixture and IMEI flash programming station calibrated. Work orders ready for mass release following Gate 7 release.",
    category: "update",
    deliverables: ["Automated FCT test fixture calibrated", "Work orders configured in ERP", "Finished goods packing spec"],
    authorName: "Casey Rowan",
    authorRole: "Production Lead",
    createdAt: new Date(Date.now() - 3600 * 1000 * 24 * 1).toISOString(),
  },
];

let memoryChronicles: DepartmentChronicle[] = [...INITIAL_SAMPLE_CHRONICLES];

function getStoredChronicles(): DepartmentChronicle[] {
  if (typeof window === "undefined") {
    return memoryChronicles;
  }
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(INITIAL_SAMPLE_CHRONICLES));
      memoryChronicles = [...INITIAL_SAMPLE_CHRONICLES];
      return memoryChronicles;
    }
    const parsed = JSON.parse(raw);
    if (Array.isArray(parsed) && parsed.length > 0) {
      memoryChronicles = parsed as DepartmentChronicle[];
      return memoryChronicles;
    }
  } catch (err) {
    console.warn("Failed reading department chronicles from storage, using fallback:", err);
  }
  return memoryChronicles;
}

function setStoredChronicles(chronicles: DepartmentChronicle[]) {
  memoryChronicles = [...chronicles];
  if (typeof window === "undefined") return;
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(chronicles));
  } catch (err) {
    console.warn("Failed storing department chronicles:", err);
  }
}

export function fetchDepartmentChronicles(departmentId?: string, stageNumber?: number): DepartmentChronicle[] {
  const all = getStoredChronicles();
  let filtered = all;

  if (departmentId && departmentId !== "all") {
    const cleanDept = departmentId.toLowerCase().replace(/^dept-/, "");
    filtered = filtered.filter(
      (c) =>
        c.departmentId.toLowerCase() === cleanDept ||
        c.departmentId === "all" ||
        (cleanDept === "hardware" && c.departmentId === "rnd")
    );
  }

  if (stageNumber) {
    filtered = filtered.filter((c) => c.stageNumber === stageNumber);
  }

  return [...filtered].sort((a, b) => {
    if (a.pinned && !b.pinned) return -1;
    if (!a.pinned && b.pinned) return 1;
    return new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime();
  });
}

export function createDepartmentChronicle(
  input: Omit<DepartmentChronicle, "id" | "createdAt">
): DepartmentChronicle {
  const all = getStoredChronicles();
  const stageName = input.stageName || getStageNameByNumber(input.stageNumber);
  const newEntry: DepartmentChronicle = {
    ...input,
    id: `chr-${Date.now()}-${Math.random().toString(36).substring(2, 7)}`,
    stageName,
    createdAt: new Date().toISOString(),
  };
  const updated = [newEntry, ...all];
  setStoredChronicles(updated);
  return newEntry;
}

export function updateDepartmentChronicle(
  id: string,
  patch: Partial<Omit<DepartmentChronicle, "id" | "createdAt">>
): DepartmentChronicle {
  const all = getStoredChronicles();
  const index = all.findIndex((c) => c.id === id);
  if (index === -1) {
    throw new Error(`Chronicle entry with id ${id} not found.`);
  }

  const stageName = patch.stageNumber
    ? getStageNameByNumber(patch.stageNumber)
    : patch.stageName || all[index].stageName;

  const updatedEntry = {
    ...all[index],
    ...patch,
    stageName: stageName || all[index].stageName,
  };
  all[index] = updatedEntry;
  setStoredChronicles(all);
  return updatedEntry;
}

export function quickUpdateChronicleStatus(id: string, nextStatus: StageStatus): DepartmentChronicle {
  return updateDepartmentChronicle(id, { stageStatus: nextStatus });
}

export function quickUpdateChronicleStage(id: string, nextStageNumber: number): DepartmentChronicle {
  const stageName = getStageNameByNumber(nextStageNumber);
  return updateDepartmentChronicle(id, { stageNumber: nextStageNumber, stageName });
}

export function deleteDepartmentChronicle(id: string): boolean {
  const all = getStoredChronicles();
  const filtered = all.filter((c) => c.id !== id);
  if (filtered.length === all.length) return false;
  setStoredChronicles(filtered);
  return true;
}

export function resetDepartmentChronicles(): void {
  memoryChronicles = [...INITIAL_SAMPLE_CHRONICLES];
  setStoredChronicles(INITIAL_SAMPLE_CHRONICLES);
}
