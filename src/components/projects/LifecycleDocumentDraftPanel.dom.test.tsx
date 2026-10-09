/** @vitest-environment jsdom */

import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { createMemoryHistory, createRootRoute, createRouter, RouterProvider } from "@tanstack/react-router";
import { cleanup, render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";
import { LifecycleDocumentDraftPanel } from "./LifecycleDocumentDraftPanel";

const select = vi.fn();
const historyRows = [{
  id: "draft-1", generated_drive_node_id: "file-1", template_version: 2, created_at: "2026-10-09T00:00:00Z", result: { document_number: "DOC-001" },
}];

vi.mock("@/integrations/supabase/client", () => ({
  supabase: {
    from: () => ({
      select: () => ({
        eq: () => ({
          order: () => ({ limit: () => select() }),
          eq: () => ({ order: () => Promise.resolve({ data: [], error: null }) }),
        }),
      }),
    }),
  },
}));

vi.mock("@/lib/lifecycle-template-settings", () => ({
  isLifecycleTemplateActionAvailable: () => true,
}));

vi.mock("@tanstack/react-start", async () => {
  const actual = await vi.importActual<typeof import("@tanstack/react-start")>("@tanstack/react-start");
  return { ...actual, useServerFn: () => vi.fn() };
});

const project = {
  id: "project-123", name: "Project One", code: "PROJECT-2026-0005", color: "blue", status: "active" as const,
  revision: "R1", design_link: null, project_type: "CUSTOM_PROJECT", department_id: "department-123",
  drive_project_class: "INTERNAL" as const, customer_id: null, opportunity_id: null, requirement_baseline_id: null,
  project_manager_employee_id: null, engineering_lead_employee_id: null, project_stage: "INITIATION", health_status: "GREEN",
  priority: "MEDIUM", planned_start_date: null, target_sop_date: null, prototype_quantity: null, annual_volume: null,
  project_drive_node_id: "root-123", completion_notes: null, archived_at: null, created_at: "2026-10-09T00:00:00Z", updated_at: "2026-10-09T00:00:00Z",
};

function renderPanel() {
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  const root = createRootRoute({ component: () => <LifecycleDocumentDraftPanel project={project} /> });
  const router = createRouter({ routeTree: root, history: createMemoryHistory({ initialEntries: ["/"] }) });
  return { queryClient, ...render(<QueryClientProvider client={queryClient}><RouterProvider router={router} /></QueryClientProvider>) };
}

afterEach(() => {
  cleanup();
  select.mockReset();
});

describe("LifecycleDocumentDraftPanel history reads", () => {
  it("shows a failed initial history read without the empty-history message, then retries successfully", async () => {
    const user = userEvent.setup();
    select.mockRejectedValueOnce(new Error("History unavailable")).mockResolvedValueOnce({ data: historyRows, error: null });

    renderPanel();

    const initialHistoryError = await screen.findByText("Generated document history could not be loaded with your current access.");
    expect(initialHistoryError.closest("[role=alert]")?.textContent).toContain("Generated document history could not be loaded");
    expect(screen.queryByText("No generated documents are visible for this project yet.")).toBeNull();

    await user.click(screen.getByRole("button", { name: "Retry history" }));

    expect(await screen.findByText(/DOC-001 · template v2/)).toBeTruthy();
    expect(screen.queryByText("Generated document history could not be loaded with your current access.")).toBeNull();
  });

  it("keeps cached history visible when a refresh read fails", async () => {
    select.mockResolvedValueOnce({ data: historyRows, error: null }).mockRejectedValueOnce(new Error("History refresh unavailable"));

    const { queryClient } = renderPanel();
    expect(await screen.findByText(/DOC-001 · template v2/)).toBeTruthy();

    await queryClient.invalidateQueries({ queryKey: ["lifecycle-generated-documents", "project-123"] });

    await waitFor(() => {
      expect(screen.getByText("Generated document history could not be loaded with your current access.").closest("[role=alert]")?.textContent).toContain("Generated document history could not be loaded");
    });
    expect(screen.getByText(/DOC-001 · template v2/)).toBeTruthy();
    expect(screen.queryByText("No generated documents are visible for this project yet.")).toBeNull();
  });
});