/** @vitest-environment jsdom */

import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { createMemoryHistory, createRootRoute, createRouter, RouterProvider } from "@tanstack/react-router";
import { cleanup, render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";
import { SharedProductLifecycle } from "./SharedProductLifecycle";

const readLifecycle = vi.fn();
const readGates = vi.fn();
const readBaseline = vi.fn();
const readStages = vi.fn();

vi.mock("@/integrations/supabase/client", () => ({
  supabase: {
    from: (table: string) => ({
      select: () => ({
        eq: () => table === "project_stage_gates"
          ? readGates()
          : table === "requirement_baselines"
            ? ({ maybeSingle: readBaseline })
            : table === "company_process_stages"
              ? ({ order: () => readStages() })
              : ({ order: () => readLifecycle() }),
      }),
    }),
  },
}));

vi.mock("./LifecycleResponsibilityPlan", () => ({ LifecycleResponsibilityPlan: () => null }));
vi.mock("./LifecycleDocumentDraftPanel", () => ({ LifecycleDocumentDraftPanel: () => null }));

const project = {
  id: "project-123", name: "Project One", code: "PROJECT-2026-0005", color: "blue", status: "active" as const,
  revision: "R1", design_link: null, project_type: "CUSTOM_PROJECT", department_id: "department-123",
  drive_project_class: "INTERNAL" as const, customer_id: null, opportunity_id: null, requirement_baseline_id: null,
  project_manager_employee_id: null, engineering_lead_employee_id: null, project_stage: "HW_01", health_status: "GREEN",
  priority: "MEDIUM", planned_start_date: null, target_sop_date: null, prototype_quantity: null, annual_volume: null,
  project_drive_node_id: "root-123", completion_notes: null, archived_at: null, created_at: "2026-10-09T00:00:00Z", updated_at: "2026-10-09T00:00:00Z",
};

function renderLifecycle() {
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  const root = createRootRoute({ component: () => <SharedProductLifecycle project={project} onOpenDelivery={vi.fn()} onOpenFiles={vi.fn()} onOpenTasks={vi.fn()} /> });
  const router = createRouter({ routeTree: root, history: createMemoryHistory({ initialEntries: ["/"] }) });
  return render(<QueryClientProvider client={queryClient}><RouterProvider router={router} /></QueryClientProvider>);
}

afterEach(() => {
  cleanup();
  readLifecycle.mockReset();
  readGates.mockReset();
  readBaseline.mockReset();
  readStages.mockReset();
});

describe("SharedProductLifecycle governed reads", () => {
  it("settles the 42P17 gate read as unavailable while unaffected lifecycle records remain usable", async () => {
    readLifecycle.mockResolvedValue({ data: [], error: null });
    readGates.mockResolvedValue({ data: null, error: { message: "infinite recursion detected in policy", code: "42P17" } });
    readStages.mockResolvedValue({ data: [], error: null });

    renderLifecycle();

    expect((await screen.findByText(/Gate records could not be loaded/)).parentElement?.textContent).toContain("infinite recursion detected in policy");
    expect(screen.getByRole("button", { name: "Retry" })).toBeTruthy();
    expect(await screen.findByText("Draft lifecycle automation plan")).toBeTruthy();
    expect(screen.queryByText("No gate records are currently accessible for this project.")).toBeNull();
  });

  it("settles governed automation failures instead of leaving its panel loading", async () => {
    const user = userEvent.setup();
    readLifecycle.mockRejectedValueOnce(new Error("Process records unavailable")).mockResolvedValue({ data: [], error: null });
    readGates.mockResolvedValue({ data: [], error: null });
    readStages.mockResolvedValue({ data: [], error: null });

    renderLifecycle();

    expect((await screen.findByText(/Governed lifecycle records could not be loaded/)).parentElement?.textContent).toContain("Governed lifecycle records could not be loaded: Process records unavailable");
    expect(screen.queryByText("Loading available governed records…")).toBeNull();
    await user.click(screen.getByRole("button", { name: "Retry" }));
    await waitFor(() => expect(screen.getByText("Required source inputs")).toBeTruthy());
  });
});