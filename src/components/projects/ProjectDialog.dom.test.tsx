/** @vitest-environment jsdom */

import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { cleanup, render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";
import { ProjectDialog } from "./ProjectDialog";

const insert = vi.fn();
const update = vi.fn();
const projectSelect = vi.fn();
const projectSingle = vi.fn();
const toast = { error: vi.fn(), success: vi.fn(), warning: vi.fn(), info: vi.fn() };

vi.mock("sonner", () => ({ toast }));
vi.mock("@/lib/lifecycle-template-settings", () => ({ isLifecycleTemplateActionAvailable: () => false }));
vi.mock("@tanstack/react-start", async () => {
  const actual = await vi.importActual<typeof import("@tanstack/react-start")>("@tanstack/react-start");
  return { ...actual, useServerFn: () => vi.fn() };
});
vi.mock("@/integrations/supabase/client", () => ({
  supabase: {
    from: (table: string) => {
      if (table === "departments") {
        const departmentsQuery = {
          select: () => departmentsQuery,
          eq: () => departmentsQuery,
          order: async () => ({ data: [{ id: "department-1", name: "Engineering", code: "ENG" }], error: null }),
        };
        return departmentsQuery;
      }
      const projectQuery = {
        insert,
        update,
        eq: () => projectQuery,
        select: projectSelect,
      };
      return projectQuery;
    },
  },
}));

const project = {
  id: "project-1", name: "Existing project", code: "PROJECT-1", color: "#3b82f6", status: "active" as const,
  revision: "R1", design_link: null, project_type: "CUSTOM_PROJECT", department_id: "department-1",
  drive_project_class: "INTERNAL" as const, customer_id: null, opportunity_id: null, requirement_baseline_id: null,
  project_manager_employee_id: null, engineering_lead_employee_id: null, project_stage: "INITIATION", health_status: "GREEN",
  priority: "MEDIUM", planned_start_date: null, target_sop_date: null, prototype_quantity: null, annual_volume: null,
  project_drive_node_id: null, completion_notes: null, archived_at: null, created_at: "2026-10-11T00:00:00Z", updated_at: "2026-10-11T00:00:00Z",
};

function renderDialog(editing?: typeof project) {
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  const onOpenChange = vi.fn();
  const onSaved = vi.fn();
  render(<QueryClientProvider client={queryClient}><ProjectDialog open onOpenChange={onOpenChange} onSaved={onSaved} editing={editing} defaultDepartmentId="department-1" /></QueryClientProvider>);
  return { onOpenChange, onSaved };
}

async function saveNamedProject(user: ReturnType<typeof userEvent.setup>) {
  await user.type(screen.getByLabelText("Name"), "New project");
  await user.click(screen.getByRole("button", { name: "Save project" }));
}

beforeEach(() => {
  insert.mockImplementation(() => ({ select: projectSelect }));
  update.mockImplementation(() => ({ eq: () => ({ select: projectSelect }) }));
  projectSelect.mockImplementation(() => ({ single: projectSingle }));
  projectSingle.mockResolvedValue({ data: { id: "project-1", project_drive_node_id: null }, error: null });
});

afterEach(() => {
  cleanup();
  vi.clearAllMocks();
});

describe("ProjectDialog save reporting", () => {
  it("reports creation factually when the save response does not confirm a Drive root", async () => {
    const user = userEvent.setup();
    renderDialog();

    await saveNamedProject(user);

    await waitFor(() => expect(toast.success).toHaveBeenCalledWith("Project created"));
    expect(toast.success).not.toHaveBeenCalledWith(expect.stringContaining("folder structure"));
    expect(insert).toHaveBeenCalledTimes(1);
    expect(update).not.toHaveBeenCalled();
  });

  it("reports an update and only confirms the caller-visible Drive root pointer when returned", async () => {
    projectSingle.mockResolvedValueOnce({ data: { id: "project-1", project_drive_node_id: "drive-root-1" }, error: null });
    const user = userEvent.setup();
    renderDialog(project);

    await user.click(screen.getByRole("button", { name: "Save project" }));

    await waitFor(() => expect(toast.success).toHaveBeenCalledWith("Project updated. Project Drive root is linked."));
    expect(update).toHaveBeenCalledTimes(1);
    expect(insert).not.toHaveBeenCalled();
  });

  it("keeps the dialog open after a save error and never retries the mutation automatically", async () => {
    projectSingle.mockResolvedValueOnce({ data: null, error: { message: "Project save denied" } });
    const user = userEvent.setup();
    renderDialog();

    await saveNamedProject(user);

    await waitFor(() => expect(toast.error).toHaveBeenCalledWith("Project save denied"));
    expect(screen.getByRole("dialog")).toBeTruthy();
    await new Promise((resolve) => setTimeout(resolve, 0));
    expect(insert).toHaveBeenCalledTimes(1);
    expect(toast.success).not.toHaveBeenCalled();
  });
});