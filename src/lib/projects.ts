import { supabase } from "@/integrations/supabase/client";

export interface Project {
  id: string;
  name: string;
  code: string;
  color: string;
  status: "active" | "archived";
  revision: string | null;
  design_link: string | null;
  project_type: string;
  department_id: string | null;
  drive_project_class: "INTERNAL" | "CLIENT";
  customer_id: string | null;
  opportunity_id: string | null;
  requirement_baseline_id: string | null;
  project_manager_employee_id: string | null;
  engineering_lead_employee_id: string | null;
  project_stage: string;
  health_status: string;
  priority: string;
  planned_start_date: string | null;
  target_sop_date: string | null;
  prototype_quantity: number | null;
  annual_volume: number | null;
  project_drive_node_id: string | null;
  completion_notes: string | null;
  archived_at: string | null;
  created_at: string;
  updated_at: string;
}

const sb = supabase as any;

export const DEFAULT_PROJECTS: Project[] = [
  {
    id: "proj-bms-001",
    name: "Smart Battery Management System (BMS-48V)",
    code: "PRJ-BMS-48V",
    color: "#0284c7",
    status: "active",
    revision: "2.1",
    design_link: null,
    project_type: "Hardware & Firmware",
    department_id: "00000000-0000-4000-a000-000000000001",
    drive_project_class: "CLIENT",
    customer_id: null,
    opportunity_id: null,
    requirement_baseline_id: null,
    project_manager_employee_id: null,
    engineering_lead_employee_id: null,
    project_stage: "PROTOTYPE",
    health_status: "GREEN",
    priority: "high",
    planned_start_date: "2026-01-10",
    target_sop_date: "2026-12-15",
    prototype_quantity: 50,
    annual_volume: 10000,
    project_drive_node_id: null,
    completion_notes: null,
    archived_at: null,
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  },
  {
    id: "proj-telematics-002",
    name: "IoT Telematics Gateway Unit (TGU-v3)",
    code: "PRJ-TGU-003",
    color: "#7c3aed",
    status: "active",
    revision: "1.4",
    design_link: null,
    project_type: "Embedded System",
    department_id: "00000000-0000-4000-a000-000000000001",
    drive_project_class: "INTERNAL",
    customer_id: null,
    opportunity_id: null,
    requirement_baseline_id: null,
    project_manager_employee_id: null,
    engineering_lead_employee_id: null,
    project_stage: "PILOT",
    health_status: "GREEN",
    priority: "medium",
    planned_start_date: "2026-02-01",
    target_sop_date: "2026-10-30",
    prototype_quantity: 25,
    annual_volume: 5000,
    project_drive_node_id: null,
    completion_notes: null,
    archived_at: null,
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  },
  {
    id: "proj-mcu-drive-003",
    name: "BLDC Motor Controller (MC-72V)",
    code: "PRJ-MCU-72V",
    color: "#059669",
    status: "active",
    revision: "3.0",
    design_link: null,
    project_type: "Power Electronics",
    department_id: "00000000-0000-4000-a000-000000000001",
    drive_project_class: "CLIENT",
    customer_id: null,
    opportunity_id: null,
    requirement_baseline_id: null,
    project_manager_employee_id: null,
    engineering_lead_employee_id: null,
    project_stage: "VALIDATION",
    health_status: "AMBER",
    priority: "high",
    planned_start_date: "2025-11-15",
    target_sop_date: "2026-09-01",
    prototype_quantity: 100,
    annual_volume: 25000,
    project_drive_node_id: null,
    completion_notes: null,
    archived_at: null,
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  },
];

export async function fetchProjects(): Promise<Project[]> {
  try {
    let query = sb.from("projects").select("*").order("status").order("name");
    const { data, error } = await query;
    if (!error && Array.isArray(data) && data.length > 0) return data as Project[];
  } catch (err) {
    console.warn("fetchProjects error:", err);
  }
  return DEFAULT_PROJECTS;
}

export async function fetchDepartmentProjects(departmentId: string): Promise<Project[]> {
  try {
    const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(departmentId);
    if (isUuid) {
      const { data, error } = await sb.from("projects").select("*").eq("department_id", departmentId).order("status").order("name");
      if (!error && Array.isArray(data) && data.length > 0) return data as Project[];
    }
  } catch (err) {
    console.warn("fetchDepartmentProjects error:", err);
  }
  const filtered = DEFAULT_PROJECTS.filter((p) => !departmentId || p.department_id === departmentId);
  return filtered.length > 0 ? filtered : DEFAULT_PROJECTS;
}

export async function fetchComponentProjectIds(componentId: string): Promise<string[]> {
  const { data, error } = await sb
    .from("component_projects")
    .select("project_id")
    .eq("component_id", componentId);
  if (error) throw error;
  return (data ?? []).map((r: any) => r.project_id as string);
}

export async function syncComponentProjects(componentId: string, projectIds: string[]) {
  const { data: existing } = await sb
    .from("component_projects")
    .select("project_id")
    .eq("component_id", componentId);
  const have = new Set<string>((existing ?? []).map((r: any) => r.project_id));
  const want = new Set(projectIds);
  const toAdd = [...want].filter((id) => !have.has(id));
  const toRemove = [...have].filter((id) => !want.has(id));
  if (toAdd.length) {
    await sb
      .from("component_projects")
      .insert(toAdd.map((project_id) => ({ component_id: componentId, project_id })));
  }
  if (toRemove.length) {
    await sb
      .from("component_projects")
      .delete()
      .eq("component_id", componentId)
      .in("project_id", toRemove);
  }
}

export async function fetchAllComponentProjectMap(): Promise<Map<string, Project[]>> {
  const { data, error } = await sb
    .from("component_projects")
    .select("component_id, project:projects(*)");
  if (error) throw error;
  const map = new Map<string, Project[]>();
  for (const row of (data ?? []) as any[]) {
    if (!row.project) continue;
    const arr = map.get(row.component_id) ?? [];
    arr.push(row.project as Project);
    map.set(row.component_id, arr);
  }
  return map;
}
