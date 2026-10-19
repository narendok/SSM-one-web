import { supabase } from "@/integrations/supabase/client";

const sb = supabase as any;

export type CanonicalDepartment = {
  id: string;
  name: string;
  code: string | null;
  aliases: string[];
  description?: string | null;
  is_active?: boolean;
  sort_order?: number;
  document_code_enabled?: boolean;
  is_custom?: boolean;
};

export const CANONICAL_DEPT_UUIDS = {
  RND: "00000000-0000-4000-a000-000000000001",
  FIRMWARE: "00000000-0000-4000-a000-000000000002",
  MECHANICAL: "00000000-0000-4000-a000-000000000003",
  PROCUREMENT: "00000000-0000-4000-a000-000000000004",
  PRODUCTION: "00000000-0000-4000-a000-000000000005",
  FACILITY: "00000000-0000-4000-a000-000000000006",
  OPERATIONS: "00000000-0000-4000-a000-000000000007",
  HR: "00000000-0000-4000-a000-000000000008",
  SALES: "00000000-0000-4000-a000-000000000009",
  FINANCE: "00000000-0000-4000-a000-000000000010",
} as const;

export const DEFAULT_CANONICAL_DEPARTMENTS: CanonicalDepartment[] = [
  { id: CANONICAL_DEPT_UUIDS.RND, name: "Hardware & R&D", code: "RND", aliases: ["rnd", "hardware", "engineering"], description: "Schematics, PCB routing, DFMEA, and core board electronics.", is_active: true, sort_order: 1 },
  { id: CANONICAL_DEPT_UUIDS.FIRMWARE, name: "Firmware", code: "FW", aliases: ["firmware", "software", "embedded"], description: "Embedded C/C++, RTOS, device drivers, and telemetry stacks.", is_active: true, sort_order: 2 },
  { id: CANONICAL_DEPT_UUIDS.MECHANICAL, name: "Mechanical", code: "MECH", aliases: ["mechanical", "cad", "enclosure"], description: "3D CAD modeling, IP67 enclosure design, and thermal dissipation.", is_active: true, sort_order: 3 },
  { id: CANONICAL_DEPT_UUIDS.PROCUREMENT, name: "Procurement", code: "PROC", aliases: ["proc", "procurement", "purchase", "stores"], description: "Supplier sourcing, PR/PO management, and component procurement.", is_active: true, sort_order: 4 },
  { id: CANONICAL_DEPT_UUIDS.PRODUCTION, name: "Production", code: "PROD", aliases: ["prod", "production", "manufacturing"], description: "SMT line planning, assembly, calibration, and dispatch.", is_active: true, sort_order: 5 },
  { id: CANONICAL_DEPT_UUIDS.FACILITY, name: "Facility / Maintenance", code: "FAC", aliases: ["fac", "facility", "maintenance", "security"], description: "Facility maintenance, plant utilities, and security.", is_active: true, sort_order: 6 },
  { id: CANONICAL_DEPT_UUIDS.OPERATIONS, name: "Operations / QMS", code: "OPS", aliases: ["ops", "operations", "qms", "qa", "quality"], description: "QMS audits, CAPA, compliance certifications, and quality.", is_active: true, sort_order: 7 },
  { id: CANONICAL_DEPT_UUIDS.HR, name: "HR", code: "HR", aliases: ["hr", "human resources", "people"], description: "People operations, talent acquisition, and training.", is_active: true, sort_order: 8 },
  { id: CANONICAL_DEPT_UUIDS.SALES, name: "Sales", code: "SAL", aliases: ["sal", "sales", "commercial"], description: "Customer accounts, commercial quotations, and opportunities.", is_active: true, sort_order: 9 },
  { id: CANONICAL_DEPT_UUIDS.FINANCE, name: "Finance", code: "FIN", aliases: ["fin", "finance", "accounts"], description: "Invoicing, payment milestones, and financial reporting.", is_active: true, sort_order: 10 },
];

const STORAGE_KEY = "ssm_dynamic_departments_override_v1";

let memoryDepartmentsOverride: CanonicalDepartment[] | null = null;

export function resetCanonicalDepartmentsOverride(): void {
  memoryDepartmentsOverride = null;
  if (typeof window !== "undefined") {
    localStorage.removeItem(STORAGE_KEY);
  }
}

function getLocalDepartmentsOverride(): CanonicalDepartment[] | null {
  if (typeof window === "undefined") return memoryDepartmentsOverride;
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return memoryDepartmentsOverride;
    const parsed = JSON.parse(raw);
    if (Array.isArray(parsed) && parsed.length > 0) {
      memoryDepartmentsOverride = parsed as CanonicalDepartment[];
      return memoryDepartmentsOverride;
    }
  } catch (err) {
    console.warn("Could not read local department overrides:", err);
  }
  return memoryDepartmentsOverride;
}

function setLocalDepartmentsOverride(list: CanonicalDepartment[]) {
  memoryDepartmentsOverride = [...list];
  if (typeof window === "undefined") return;
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(list));
  } catch (err) {
    console.warn("Could not save local department overrides:", err);
  }
}

/**
 * Returns all active canonical and custom departments sorted by sort_order then name.
 */
export async function fetchCanonicalDepartments(): Promise<CanonicalDepartment[]> {
  const all = await fetchAllCanonicalDepartments();
  return all.filter((d) => d.is_active !== false);
}

/**
 * Returns ALL canonical and custom departments (including inactive/deactivated ones), for admin management.
 */
export async function fetchAllCanonicalDepartments(): Promise<CanonicalDepartment[]> {
  const local = getLocalDepartmentsOverride();

  // Try Supabase first
  try {
    const { data, error } = await sb
      .from("departments")
      .select("id,name,code,description,aliases,is_active,document_code_enabled,sort_order")
      .order("sort_order", { ascending: true })
      .order("name", { ascending: true });

    if (!error && Array.isArray(data) && data.length > 0) {
      // Merge remote database rows with local overrides
      const dbList: CanonicalDepartment[] = data.map((d: any, idx: number) => ({
        id: d.id,
        name: d.name,
        code: d.code,
        description: d.description ?? null,
        aliases: Array.isArray(d.aliases) ? d.aliases : [],
        is_active: d.is_active !== false,
        sort_order: typeof d.sort_order === "number" ? d.sort_order : idx + 1,
        document_code_enabled: Boolean(d.document_code_enabled),
      }));

      if (!local) {
        return dbList;
      }

      // Merge local additions and updates
      const map = new Map<string, CanonicalDepartment>();
      dbList.forEach((d) => map.set(d.id, d));
      local.forEach((l) => map.set(l.id, { ...map.get(l.id), ...l }));
      const merged = Array.from(map.values()).sort((a, b) => (a.sort_order ?? 99) - (b.sort_order ?? 99));
      return merged;
    }
  } catch (err) {
    console.warn("Using local/fallback canonical departments:", err);
  }

  // Fallback to local storage or defaults
  if (local && local.length > 0) {
    return local.sort((a, b) => (a.sort_order ?? 99) - (b.sort_order ?? 99));
  }

  return DEFAULT_CANONICAL_DEPARTMENTS;
}

/**
 * Creates or updates a department workspace dynamically.
 */
export async function saveCanonicalDepartment(
  dept: Partial<CanonicalDepartment> & { name: string }
): Promise<CanonicalDepartment> {
  const current = await fetchAllCanonicalDepartments();
  const cleanName = dept.name.trim();
  const cleanCode = dept.code?.trim().toUpperCase() || null;
  const aliases = (dept.aliases || []).map((a) => a.trim()).filter(Boolean);

  let targetId = dept.id;
  let isNew = false;

  if (!targetId) {
    targetId = `dept-custom-${Date.now()}-${Math.random().toString(36).substring(2, 7)}`;
    isNew = true;
  }

  const existingIndex = current.findIndex((d) => d.id === targetId);

  const updatedDept: CanonicalDepartment = {
    id: targetId,
    name: cleanName,
    code: cleanCode,
    description: dept.description?.trim() || null,
    aliases,
    is_active: dept.is_active !== false,
    sort_order: typeof dept.sort_order === "number" ? dept.sort_order : (existingIndex >= 0 ? current[existingIndex].sort_order : current.length + 1),
    document_code_enabled: Boolean(dept.document_code_enabled),
    is_custom: isNew || Boolean(dept.is_custom),
  };

  let nextList: CanonicalDepartment[];
  if (existingIndex >= 0) {
    nextList = [...current];
    nextList[existingIndex] = updatedDept;
  } else {
    nextList = [...current, updatedDept];
  }

  // Save to local storage
  setLocalDepartmentsOverride(nextList);

  // Attempt to persist to Supabase if available
  try {
    const payload = {
      name: updatedDept.name,
      code: updatedDept.code,
      description: updatedDept.description,
      aliases: updatedDept.aliases,
      is_active: updatedDept.is_active,
      document_code_enabled: updatedDept.document_code_enabled,
      sort_order: updatedDept.sort_order,
    };
    if (dept.id && !dept.id.startsWith("dept-custom-")) {
      await sb.from("departments").update(payload).eq("id", dept.id);
    } else {
      await sb.from("departments").insert({ ...payload, id: targetId });
    }
  } catch (err) {
    console.warn("Could not sync department to remote Supabase database, saved locally:", err);
  }

  return updatedDept;
}

/**
 * Reorders departments given an array of department IDs in target sequence.
 */
export async function reorderCanonicalDepartments(orderedIds: string[]): Promise<CanonicalDepartment[]> {
  const current = await fetchAllCanonicalDepartments();
  const map = new Map<string, CanonicalDepartment>();
  current.forEach((d) => map.set(d.id, d));

  const reordered: CanonicalDepartment[] = [];
  orderedIds.forEach((id, idx) => {
    const dept = map.get(id);
    if (dept) {
      dept.sort_order = idx + 1;
      reordered.push(dept);
      map.delete(id);
    }
  });

  // Append any remaining departments not in orderedIds
  Array.from(map.values()).forEach((dept, idx) => {
    dept.sort_order = reordered.length + idx + 1;
    reordered.push(dept);
  });

  setLocalDepartmentsOverride(reordered);

  // Attempt remote update
  try {
    for (const d of reordered) {
      if (!d.id.startsWith("dept-custom-")) {
        await sb.from("departments").update({ sort_order: d.sort_order }).eq("id", d.id);
      }
    }
  } catch (err) {
    console.warn("Remote sort_order sync failed, updated locally:", err);
  }

  return reordered;
}

/**
 * Soft-deletes or toggles the active status of a department.
 */
export async function toggleDepartmentActiveStatus(id: string, is_active: boolean): Promise<CanonicalDepartment> {
  const current = await fetchAllCanonicalDepartments();
  const dept = current.find((d) => d.id === id);
  if (!dept) {
    throw new Error(`Department with ID ${id} not found.`);
  }

  dept.is_active = is_active;
  setLocalDepartmentsOverride(current);

  try {
    if (!id.startsWith("dept-custom-")) {
      await sb.from("departments").update({ is_active }).eq("id", id);
    }
  } catch (err) {
    console.warn("Remote status update failed, updated locally:", err);
  }

  return dept;
}

/**
 * Deletes a department. If it is a core/system department, it is soft-deactivated (is_active: false)
 * to maintain relational integrity with existing projects/tasks. If custom, it is removed.
 */
export async function deleteCanonicalDepartment(id: string): Promise<{ deleted: boolean; deactivatedOnly: boolean }> {
  const isCore = Object.values(CANONICAL_DEPT_UUIDS).includes(id as any);
  if (isCore) {
    await toggleDepartmentActiveStatus(id, false);
    return { deleted: false, deactivatedOnly: true };
  }

  const current = await fetchAllCanonicalDepartments();
  const filtered = current.filter((d) => d.id !== id);
  setLocalDepartmentsOverride(filtered);

  try {
    await sb.from("departments").delete().eq("id", id);
  } catch (err) {
    console.warn("Remote delete failed, removed locally:", err);
  }

  return { deleted: true, deactivatedOnly: false };
}

/**
 * Resolves a department name, code, alias, or ID to a canonical department.
 */
export function resolveCanonicalDepartment(
  idOrSlug: string | null | undefined,
  departments: CanonicalDepartment[] = DEFAULT_CANONICAL_DEPARTMENTS
): CanonicalDepartment | null {
  if (!idOrSlug) return null;
  const list = departments && departments.length > 0 ? departments : DEFAULT_CANONICAL_DEPARTMENTS;
  const clean = idOrSlug.trim().toLowerCase();

  // 1. Direct ID match
  const byId = list.find((d) => d.id.toLowerCase() === clean);
  if (byId) return byId;

  // 2. Direct code match
  const byCode = list.find((d) => d.code?.toLowerCase() === clean);
  if (byCode) return byCode;

  // 3. Match prefixed "dept-<code|name>"
  const strippedDept = clean.replace(/^dept-/, "");
  const byStripped = list.find(
    (d) =>
      d.code?.toLowerCase() === strippedDept ||
      d.name.toLowerCase() === strippedDept ||
      d.aliases.some((a) => a.toLowerCase() === strippedDept)
  );
  if (byStripped) return byStripped;

  // 4. Match aliases
  const byAlias = list.find((d) => d.aliases.some((a) => a.toLowerCase() === clean));
  if (byAlias) return byAlias;

  // 5. Partial name / alias match
  const byName = list.find(
    (d) =>
      d.name.toLowerCase().includes(clean) ||
      clean.includes(d.name.toLowerCase()) ||
      d.aliases.some((a) => clean.includes(a.toLowerCase()))
  );
  if (byName) return byName;

  return null;
}
