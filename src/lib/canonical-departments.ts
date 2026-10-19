import { supabase } from "@/integrations/supabase/client";

const sb = supabase as any;

export type CanonicalDepartment = { id: string; name: string; code: string | null; aliases: string[] };

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
  { id: CANONICAL_DEPT_UUIDS.RND, name: "Hardware & R&D", code: "RND", aliases: ["rnd", "hardware", "engineering"] },
  { id: CANONICAL_DEPT_UUIDS.FIRMWARE, name: "Firmware", code: "FW", aliases: ["firmware", "software", "embedded"] },
  { id: CANONICAL_DEPT_UUIDS.MECHANICAL, name: "Mechanical", code: "MECH", aliases: ["mechanical", "cad", "enclosure"] },
  { id: CANONICAL_DEPT_UUIDS.PROCUREMENT, name: "Procurement", code: "PROC", aliases: ["proc", "procurement", "purchase", "stores"] },
  { id: CANONICAL_DEPT_UUIDS.PRODUCTION, name: "Production", code: "PROD", aliases: ["prod", "production", "manufacturing"] },
  { id: CANONICAL_DEPT_UUIDS.FACILITY, name: "Facility / Maintenance", code: "FAC", aliases: ["fac", "facility", "maintenance", "security"] },
  { id: CANONICAL_DEPT_UUIDS.OPERATIONS, name: "Operations / QMS", code: "OPS", aliases: ["ops", "operations", "qms", "qa", "quality"] },
  { id: CANONICAL_DEPT_UUIDS.HR, name: "HR", code: "HR", aliases: ["hr", "human resources", "people"] },
  { id: CANONICAL_DEPT_UUIDS.SALES, name: "Sales", code: "SAL", aliases: ["sal", "sales", "commercial"] },
  { id: CANONICAL_DEPT_UUIDS.FINANCE, name: "Finance", code: "FIN", aliases: ["fin", "finance", "accounts"] },
];

export async function fetchCanonicalDepartments(): Promise<CanonicalDepartment[]> {
  try {
    const { data, error } = await sb.from("departments").select("id,name,code,aliases").eq("is_active", true).order("sort_order").order("name");
    if (!error && Array.isArray(data) && data.length > 0) {
      return data as CanonicalDepartment[];
    }
  } catch (err) {
    console.warn("Using default canonical departments fallback:", err);
  }
  return DEFAULT_CANONICAL_DEPARTMENTS;
}

export function resolveCanonicalDepartment(
  idOrSlug: string | null | undefined,
  departments: CanonicalDepartment[] = DEFAULT_CANONICAL_DEPARTMENTS
): CanonicalDepartment | null {
  if (!idOrSlug) return null;
  const list = departments && departments.length > 0 ? departments : DEFAULT_CANONICAL_DEPARTMENTS;
  const clean = idOrSlug.trim().toLowerCase();

  // 1. Direct ID match (e.g. UUID)
  const byId = list.find((d) => d.id.toLowerCase() === clean);
  if (byId) return byId;

  // 2. Direct code match (e.g. "MECH", "PROC", "RND")
  const byCode = list.find((d) => d.code?.toLowerCase() === clean);
  if (byCode) return byCode;

  // 3. Match prefixed "dept-<code|name>" (e.g. "dept-mechanical", "dept-procurement")
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
