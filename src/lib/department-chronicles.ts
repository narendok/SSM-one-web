export type ChronicleCategory = "milestone" | "update" | "decision" | "notice" | "incident";

export interface DepartmentChronicle {
  id: string;
  departmentId: string; // e.g. "rnd", "mechanical", "procurement", "production", "operations", "sales", "finance", "hr", or "all"
  title: string;
  content: string;
  category: ChronicleCategory;
  authorName: string;
  authorRole: string;
  createdAt: string; // ISO
  pinned?: boolean;
}

const STORAGE_KEY = "ssm_department_chronicles_v1";

export const INITIAL_SAMPLE_CHRONICLES: DepartmentChronicle[] = [
  {
    id: "chr-mech-001",
    departmentId: "mechanical",
    title: "IP67 Enclosure 3D CAD Baseline Frozen",
    content: "Finalized PC/ABS injection molded housing CAD models with silicone perimeter gasket groove and Gore-Tex vent pocket for PRJ-TLM-002. Tooling DFM approved for tooling kick-off.",
    category: "milestone",
    authorName: "Karthik R",
    authorRole: "Lead Mechanical Engineer",
    createdAt: new Date(Date.now() - 3600 * 1000 * 48).toISOString(),
    pinned: true,
  },
  {
    id: "chr-mech-002",
    departmentId: "mechanical",
    title: "Thermal Dissipation Simulation Sign-off",
    content: "CFD thermal analysis verified junction temperature stays below 65°C under continuous 4G transmission and fast battery charging. 1.5mm thermal gap pad spec finalized.",
    category: "decision",
    authorName: "Karthik R",
    authorRole: "Lead Mechanical Engineer",
    createdAt: new Date(Date.now() - 3600 * 1000 * 24).toISOString(),
  },
  {
    id: "chr-rnd-001",
    departmentId: "rnd",
    title: "BLE 5.2 Board Spin PCB-TLM-V2.1-BLE Schematics Released",
    content: "Nordic nRF52833 BLE SoC and TI BQ24075 power-path manager circuit design complete. Controlled 50-ohm trace routing verified with PCB fabricator.",
    category: "milestone",
    authorName: "Arun Kumar",
    authorRole: "Senior Hardware Architect",
    createdAt: new Date(Date.now() - 3600 * 1000 * 72).toISOString(),
    pinned: true,
  },
  {
    id: "chr-rnd-002",
    departmentId: "rnd",
    title: "Firmware v2.1.0-RC1 Telemetry Stack Validated",
    content: "Integrated FreeRTOS BLE beaconing daemon alongside Quectel EG915N 4G MQTT publisher. Standby sleep current measured at 18uA on bench testing.",
    category: "update",
    authorName: "Vikram Malhotra",
    authorRole: "Firmware Lead",
    createdAt: new Date(Date.now() - 3600 * 1000 * 18).toISOString(),
  },
  {
    id: "chr-proc-001",
    departmentId: "procurement",
    title: "Quectel 4G & Nordic BLE Chipset Allocation Secured",
    content: "Closed long-lead supply contract for 5,000 units with 4-week delivery buffer. Unit BOM cost reduced by 6.2% through consolidated distributor tier pricing.",
    category: "decision",
    authorName: "Meera Nair",
    authorRole: "Procurement Specialist",
    createdAt: new Date(Date.now() - 3600 * 1000 * 96).toISOString(),
  },
  {
    id: "chr-prod-001",
    departmentId: "production",
    title: "SMT Feeder Setup & Pilot Stencil Verification",
    content: "Completed pilot stencil alignment and reflow solder profile verification for 0402 passives and 0.5mm pitch BGA ICs. First article inspection passed 100%.",
    category: "milestone",
    authorName: "Rajesh Sharma",
    authorRole: "Production Manager",
    createdAt: new Date(Date.now() - 3600 * 1000 * 30).toISOString(),
  },
  {
    id: "chr-ops-001",
    departmentId: "operations",
    title: "iCAT AIS-140 Homologation Certification Received",
    content: "Official certification iCAT/AIS140/2026/0892 issued following successful EMC/EMI, vibration, and thermal testing. NABL battery safety report also archived.",
    category: "milestone",
    authorName: "Pooja V",
    authorRole: "Operations & QMS Lead",
    createdAt: new Date(Date.now() - 3600 * 1000 * 12).toISOString(),
    pinned: true,
  },
  {
    id: "chr-sal-001",
    departmentId: "sales",
    title: "Commercial Baseline Signed with Mahindra Auto",
    content: "Client approved 9-stage delivery roadmap for 15,000 commercial telematics units. Pilot delivery of 50 prototypes scheduled for next month.",
    category: "milestone",
    authorName: "Amitabh Sen",
    authorRole: "Commercial Director",
    createdAt: new Date(Date.now() - 3600 * 1000 * 60).toISOString(),
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
      localStorage.setItem(STORAGE_KEY, JSON.stringify(memoryChronicles));
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

export function fetchDepartmentChronicles(departmentId?: string): DepartmentChronicle[] {
  const all = getStoredChronicles();
  if (!departmentId || departmentId === "all") {
    return [...all].sort((a, b) => {
      if (a.pinned && !b.pinned) return -1;
      if (!a.pinned && b.pinned) return 1;
      return new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime();
    });
  }
  const cleanDept = departmentId.toLowerCase().replace(/^dept-/, "");
  return all
    .filter(
      (c) =>
        c.departmentId.toLowerCase() === cleanDept ||
        c.departmentId === "all" ||
        (cleanDept === "hardware" && c.departmentId === "rnd")
    )
    .sort((a, b) => {
      if (a.pinned && !b.pinned) return -1;
      if (!a.pinned && b.pinned) return 1;
      return new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime();
    });
}

export function createDepartmentChronicle(
  input: Omit<DepartmentChronicle, "id" | "createdAt">
): DepartmentChronicle {
  const all = getStoredChronicles();
  const newEntry: DepartmentChronicle = {
    ...input,
    id: `chr-${Date.now()}-${Math.random().toString(36).substring(2, 7)}`,
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
  const updatedEntry = { ...all[index], ...patch };
  all[index] = updatedEntry;
  setStoredChronicles(all);
  return updatedEntry;
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
