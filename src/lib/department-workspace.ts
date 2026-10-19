import { supabase } from "@/integrations/supabase/client";
import type { Database } from "@/integrations/supabase/types";
import { workspaceForDepartment } from "@/lib/department-workspace-navigation";

const sb = supabase as any;
export type WorkspacePreference = Database["public"]["Tables"]["department_workspace_preferences"]["Row"];

export function departmentWorkTarget(department: { name: string; code: string | null; aliases: string[] }) {
  return workspaceForDepartment(department) ? "/workspace/projects" : "/command-center";
}

export async function fetchWorkspacePreference(departmentId: string): Promise<WorkspacePreference | null> {
  try {
    const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(departmentId);
    if (isUuid) {
      const { data, error } = await sb.from("department_workspace_preferences").select("*").eq("department_id", departmentId).maybeSingle();
      if (!error) return data as WorkspacePreference | null;
    }
  } catch (err) {
    console.warn("fetchWorkspacePreference error:", err);
  }
  return null;
}

export async function saveWorkspacePreference(departmentId: string, patch: Partial<Pick<WorkspacePreference, "drive_default_filter" | "show_dashboard_documents" | "project_tracker_view" | "lead_digest_enabled">>) {
  try {
    const { data: userResult, error: userError } = await supabase.auth.getUser();
    if (userError || !userResult.user) throw new Error("Sign in required");
    const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(departmentId);
    if (!isUuid) return;
    const { error } = await sb.from("department_workspace_preferences").upsert({ user_id: userResult.user.id, department_id: departmentId, ...patch }, { onConflict: "user_id,department_id" });
    if (error) throw error;
  } catch (err) {
    console.warn("saveWorkspacePreference fallback:", err);
  }
}