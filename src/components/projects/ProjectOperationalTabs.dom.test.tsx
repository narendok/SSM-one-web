/** @vitest-environment jsdom */

import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { cleanup, render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";
import { ProjectOperationalTab } from "./ProjectOperationalTabs";

const order = vi.fn();

vi.mock("@/integrations/supabase/client", () => ({
  supabase: {
    from: () => ({
      select: () => ({ eq: () => ({ order }) }),
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