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
  return render(<QueryClientProvider client={queryClient}><ProjectOperationalTab projectId="project-123" kind="design" /></QueryClientProvider>);
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

    expect(await screen.findByRole("alert")).toHaveTextContent("These records could not be loaded. Read unavailable");
    expect(screen.getByText("Records unavailable")).toBeInTheDocument();
    expect(screen.queryByText("No controlled design inputs recorded.")).not.toBeInTheDocument();
    expect(screen.queryByText("0 recorded")).not.toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: "Retry" }));

    await waitFor(() => expect(screen.getByText("Approved customer dimension")).toBeInTheDocument());
    expect(screen.queryByRole("alert")).not.toBeInTheDocument();
    expect(screen.getByText("1 recorded")).toBeInTheDocument();
  });

  it("keeps cached design inputs visible when a refresh fails", async () => {
    order.mockResolvedValueOnce({ data: [{
      id: "input-1", input_code: "DI-001", category: "CUSTOMER", description: "Manual design note", status: "OPEN",
    }], error: null }).mockRejectedValueOnce(new Error("Refresh unavailable"));

    const { rerender } = renderDesignInputs();
    expect(await screen.findByText("Manual design note")).toBeInTheDocument();

    rerender(<QueryClientProvider client={new QueryClient({ defaultOptions: { queries: { retry: false } } })}><ProjectOperationalTab projectId="project-123" kind="design" /></QueryClientProvider>);
    await waitFor(() => expect(screen.getByRole("alert")).toHaveTextContent("Refresh unavailable"));
    expect(screen.getByText("Manual design note")).toBeInTheDocument();
    expect(screen.getByText("1 recorded · refresh failed")).toBeInTheDocument();
  });
});