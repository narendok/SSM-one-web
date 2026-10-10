/** @vitest-environment jsdom */

import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { createMemoryHistory, createRootRoute, createRouter, RouterProvider } from "@tanstack/react-router";
import { cleanup, render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";
import { LifecycleDocumentDraftPanel } from "./LifecycleDocumentDraftPanel";
import { generateLifecycleDocumentDraft, generateProjectLifecycleDocumentDrafts } from "@/lib/lifecycle-actions.functions";

const historyQuery = vi.fn();
const saveDraft = vi.fn();
const refreshDrafts = vi.fn();
const historyRows = [{
  id: "draft-1", generated_drive_node_id: "file-1", template_version: 2, created_at: "2026-10-09T00:00:00Z", result: { document_number: "DOC-001" },
}];

vi.mock("@/integrations/supabase/client", () => ({
  supabase: {
    from: (table: string) => table === ("project_lifecycle_document_drafts" as never)
      ? { select: () => ({ eq: () => ({ order: () => ({ limit: historyQuery }) }) }) }
      : { select: () => ({ eq: () => ({ order: () => Promise.resolve({ data: [], error: null }) }) }) },
  },
}));

vi.mock("@/lib/lifecycle-template-settings", () => ({
  isLifecycleTemplateActionAvailable: () => true,
}));

vi.mock("@tanstack/react-start", async () => {
  const actual = await vi.importActual<typeof import("@tanstack/react-start")>("@tanstack/react-start");
  return { ...actual, useServerFn: (action: unknown) => action === generateLifecycleDocumentDraft ? saveDraft : action === generateProjectLifecycleDocumentDrafts ? refreshDrafts : vi.fn() };
});

const project = {
  id: "project-123", name: "Project One", code: "PROJECT-2026-0005", color: "blue", status: "active" as const,
  revision: "R1", design_link: null, project_type: "CUSTOM_PROJECT", department_id: "department-123",
  drive_project_class: "INTERNAL" as const, customer_id: null, opportunity_id: null, requirement_baseline_id: null,
  project_manager_employee_id: null, engineering_lead_employee_id: null, project_stage: "INITIATION", health_status: "GREEN",
  priority: "MEDIUM", planned_start_date: null, target_sop_date: null, prototype_quantity: null, annual_volume: null,
  project_drive_node_id: "root-123", completion_notes: null, archived_at: null, created_at: "2026-10-09T00:00:00Z", updated_at: "2026-10-09T00:00:00Z",
};

function renderPanel(initialDocuments?: typeof historyRows) {
  historyQuery.mockImplementation(() => Promise.resolve({ data: initialDocuments ?? historyRows, error: null }));
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false, staleTime: initialDocuments ? Infinity : 0 } } });
  if (initialDocuments) queryClient.setQueryData(["lifecycle-generated-documents", project.id], initialDocuments);
  const root = createRootRoute({ component: () => <LifecycleDocumentDraftPanel project={project} /> });
  const router = createRouter({ routeTree: root, history: createMemoryHistory({ initialEntries: ["/"] }) });
  return { queryClient, ...render(<QueryClientProvider client={queryClient}><RouterProvider router={router} /></QueryClientProvider>) };
}

afterEach(() => {
  cleanup();
  historyQuery.mockReset();
  saveDraft.mockReset();
  refreshDrafts.mockReset();
});

describe("LifecycleDocumentDraftPanel history reads", () => {
  it("shows a failed initial history read without the empty-history message, then retries successfully", async () => {
    const user = userEvent.setup();
    historyQuery.mockRejectedValueOnce(new Error("History unavailable")).mockResolvedValueOnce({ data: historyRows, error: null });

    renderPanel();

    const initialHistoryError = await screen.findByText("Generated document history could not be loaded with your current access.");
    expect(initialHistoryError.closest("[role=alert]")?.textContent).toContain("Generated document history could not be loaded");
    expect(screen.queryByText("No generated documents are visible for this project yet.")).toBeNull();

    await user.click(screen.getByRole("button", { name: "Retry history" }));

    expect(await screen.findByText(/DOC-001 · template v2/)).toBeTruthy();
    expect(screen.queryByText("Generated document history could not be loaded with your current access.")).toBeNull();
  });

  async function selectReadyDraft(user: ReturnType<typeof userEvent.setup>) {
    await user.selectOptions(await screen.findByLabelText("Active template"), "11111111-1111-4111-8111-111111111111");
    await user.selectOptions(screen.getByLabelText("Project Drive folder"), "22222222-2222-4222-8222-222222222222");
  }

  it("invalidates Drive and exact project history only after a successful protected draft receipt", async () => {
    const user = userEvent.setup();
    let resolveAction: (value: { result: { receipt: { nodeId: string; revisionId: string; registerId: string } } }) => void = () => undefined;
    const action = new Promise<{ result: { receipt: { nodeId: string; revisionId: string; registerId: string } } }>((resolve) => { resolveAction = resolve; });
    saveDraft.mockReturnValueOnce(action);
    const { queryClient } = renderPanel(historyRows);
    const invalidate = vi.spyOn(queryClient, "invalidateQueries");

    await selectReadyDraft(user);
    await user.click(screen.getByRole("button", { name: "Generate draft" }));
    expect(invalidate).not.toHaveBeenCalled();

    resolveAction({ result: { receipt: { nodeId: "node-1", revisionId: "revision-1", registerId: "register-1" } } });
    await screen.findByText("Draft saved. The original files and approved versions remain preserved.");
    await waitFor(() => expect(invalidate).toHaveBeenCalledWith({ queryKey: ["drive_children"] }));
    expect(invalidate).toHaveBeenCalledWith({ queryKey: ["lifecycle-generated-documents", project.id] });
  });

  it("keeps cached history and Drive state untouched when the protected draft action rejects", async () => {
    const user = userEvent.setup();
    saveDraft.mockRejectedValueOnce(new Error("Protected action rejected"));
    const { queryClient } = renderPanel(historyRows);
    const invalidate = vi.spyOn(queryClient, "invalidateQueries");

    await selectReadyDraft(user);
    await user.click(screen.getByRole("button", { name: "Generate draft" }));
    expect(await screen.findByRole("alert")).toHaveTextContent("Protected action rejected");
    expect(screen.getByText(/DOC-001 · template v2/)).toBeTruthy();
    expect(invalidate).not.toHaveBeenCalled();
  });

  it("refreshes history and Drive after a completed department outcome, including partial failures", async () => {
    const user = userEvent.setup();
    refreshDrafts.mockResolvedValueOnce({ failures: [{ message: "Template scope unavailable" }] });
    const { queryClient } = renderPanel(historyRows);
    const invalidate = vi.spyOn(queryClient, "invalidateQueries");

    await user.click(await screen.findByRole("button", { name: "Refresh department drafts" }));
    expect(await screen.findByRole("alert")).toHaveTextContent("1 drafts need attention: Template scope unavailable");
    await waitFor(() => expect(invalidate).toHaveBeenCalledWith({ queryKey: ["lifecycle-generated-documents", project.id] }));
    expect(invalidate).toHaveBeenCalledWith({ queryKey: ["drive_children"] });
  });

  it("keeps cached history visible when a refresh read fails", async () => {
    historyQuery.mockRejectedValue(new Error("History refresh unavailable"));

    const { queryClient } = renderPanel(historyRows);
    expect(await screen.findByText(/DOC-001 · template v2/)).toBeTruthy();

    await queryClient.invalidateQueries({ queryKey: ["lifecycle-generated-documents", project.id] });

    expect(await screen.findByText("Generated document history could not be loaded with your current access.")).toBeTruthy();
    expect(screen.getByText(/DOC-001 · template v2/)).toBeTruthy();
    expect(screen.queryByText("No generated documents are visible for this project yet.")).toBeNull();
  });
});