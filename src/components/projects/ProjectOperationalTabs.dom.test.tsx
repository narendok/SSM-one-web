/** @vitest-environment jsdom */

import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { cleanup, render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";
import { ProjectOperationalTab, ProjectRequirementContext } from "./ProjectOperationalTabs";

const order = vi.fn();
const maybeSingle = vi.fn();

vi.mock("@/integrations/supabase/client", () => ({
  supabase: {
    from: () => ({
      select: () => ({ eq: () => ({ eq: () => ({ maybeSingle }), order, maybeSingle }), order }),
    }),
  },
}));

function renderDesignInputs() {
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return { queryClient, ...render(<QueryClientProvider client={queryClient}><ProjectOperationalTab projectId="project-123" kind="design" /></QueryClientProvider>) };
}

afterEach(() => {
  cleanup();
  order.mockReset();
  maybeSingle.mockReset();
});

describe("ProjectOperationalTab design-input reads", () => {
  it("shows a failed initial read without an empty count or empty-state message, then retries successfully", async () => {
    const user = userEvent.setup();
    order.mockRejectedValueOnce(new Error("Read unavailable")).mockResolvedValueOnce({ data: [{
      id: "input-1", input_code: "DI-001", category: "CUSTOMER", description: "Approved customer dimension", status: "OPEN",
    }], error: null });

    renderDesignInputs();

    expect((await screen.findByRole("alert")).textContent).toContain("These records could not be loaded. Read unavailable");
    expect(screen.getByText("Records unavailable")).toBeTruthy();
    expect(screen.queryByText("No controlled design inputs recorded.")).toBeNull();
    expect(screen.queryByText("0 recorded")).toBeNull();

    await user.click(screen.getByRole("button", { name: "Retry" }));

    await waitFor(() => expect(screen.getAllByText("Approved customer dimension").length).toBeGreaterThan(0));
    expect(screen.queryByRole("alert")).toBeNull();
    expect(screen.getByText("1 recorded")).toBeTruthy();
  });

  it("keeps cached design inputs visible when a refresh fails", async () => {
    order.mockResolvedValueOnce({ data: [{
      id: "input-1", input_code: "DI-001", category: "CUSTOMER", description: "Manual design note", status: "OPEN",
    }], error: null }).mockRejectedValueOnce(new Error("Refresh unavailable"));

    const { queryClient } = renderDesignInputs();
    expect((await screen.findAllByText("Manual design note")).length).toBeGreaterThan(0);

    await queryClient.invalidateQueries({ queryKey: ["project_design_inputs", "project-123"] });
    await waitFor(() => expect(screen.getByRole("alert").textContent).toContain("Refresh unavailable"));
    expect(screen.getAllByText("Manual design note").length).toBeGreaterThan(0);
    expect(screen.getByText("1 recorded · refresh failed")).toBeTruthy();
  });
});

describe("ProjectRequirementContext", () => {
  it("keeps a missing linked baseline distinct from an absent project baseline", async () => {
    maybeSingle.mockResolvedValue({ data: null, error: null });
    const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } });
    render(<QueryClientProvider client={queryClient}><ProjectRequirementContext projectId="project-123" baselineId="baseline-123" /></QueryClientProvider>);

    expect(await screen.findByText("The linked requirement baseline is not currently accessible.")).toBeTruthy();
    expect(screen.queryByText("No requirement baseline is linked to this project.")).toBeNull();
  });
});