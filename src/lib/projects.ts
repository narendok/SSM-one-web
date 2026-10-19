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

import { SAMPLE_PROJECTS, PROJECT_ID_BLE_MODIFIED, PROJECT_ID_AS_IS_REUSE, PROJECT_ID_BMS_48V, PROJECT_ID_MCU_72V } from "./sample-data-lifecycle";

const sb = supabase as any;

export const DEFAULT_PROJECTS: Project[] = [
  ...SAMPLE_PROJECTS,
  // Backward compatibility alias for any legacy links
  {
    ...SAMPLE_PROJECTS[1],
    id: "proj-telematics-002",
  },
  {
    ...SAMPLE_PROJECTS[2],
    id: "proj-bms-001",
  },
  {
    ...SAMPLE_PROJECTS[3],
    id: "proj-mcu-drive-003",
  },
];

export async function fetchProjects(): Promise<Project[]> {
  try {
    let query = sb.from("projects").select("*").order("status").order("name");
    const { data, error } = await query;
    if (!error && Array.isArray(data) && data.length > 0) {
      const existingIds = new Set(data.map((p: any) => p.id));
      const unrepresented = SAMPLE_PROJECTS.filter((p) => !existingIds.has(p.id));
      return [...data, ...unrepresented] as Project[];
    }
  } catch (err) {
    console.warn("fetchProjects error:", err);
  }
  return SAMPLE_PROJECTS;
}

export async function fetchDepartmentProjects(departmentId: string): Promise<Project[]> {
  try {
    const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(departmentId);
    if (isUuid) {
      const { data, error } = await sb.from("projects").select("*").eq("department_id", departmentId).order("status").order("name");
      if (!error && Array.isArray(data) && data.length > 0) {
        const existingIds = new Set(data.map((p: any) => p.id));
        const unrepresented = SAMPLE_PROJECTS.filter((p) => p.department_id === departmentId && !existingIds.has(p.id));
        return [...data, ...unrepresented] as Project[];
      }
    }
  } catch (err) {
    console.warn("fetchDepartmentProjects error:", err);
  }
  const filtered = SAMPLE_PROJECTS.filter((p) => !departmentId || p.department_id === departmentId);
  return filtered.length > 0 ? filtered : SAMPLE_PROJECTS;
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
