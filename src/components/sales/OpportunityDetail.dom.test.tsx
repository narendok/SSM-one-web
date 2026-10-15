/** @vitest-environment jsdom */

import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { cleanup, render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it } from "vitest";
afterEach(cleanup);
import { OpportunityDetail } from "./OpportunityDetail";

const opportunity = {
  id: "opportunity-id",
  opportunity_number: "OPPORTUNITY-2026-0013",
  enquiry_id: null,
  name: "Tracker controller",
  stage: "requirement_pending",
  status: "active",
  priority: "medium",
  application: "Fleet tracking",
  product_type: "Tracker",
  nda_required: false,
  estimated_volume: "20",
  target_timeline: null,
  next_action: "Internal review",
  next_action_date: null,
  customer: {
    id: "customer-id",
    legal_name: "OEM Tracker",
    customer_code: "CUSTOMER-2026-0001",
    is_sample: true,
  },
};

describe("OpportunityDetail", () => {
  it("shows one tabbed workspace with source pins and no invented feasibility route", () => {
    const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } });
    render(
      <QueryClientProvider client={queryClient}>
        <OpportunityDetail
          opportunity={opportunity}
          specification={{
            id: "spec-id",
            opportunity_id: "opportunity-id",
            customer_id: "customer-id",
            specification_number: "MASTER-2026-0001",
            title: "Tracker",
            status: "active",
            current_version: 1,
          }}
          requirements={[]}
          reviews={[]}
          departments={[]}
          employees={[]}
          feasibilityProvenance={{
            available: false,
            error: "Immutable feasibility provenance is unavailable.",
          }}
          onViewSpecification={() => undefined}
          onOpenChange={() => undefined}
        />
      </QueryClientProvider>,
    );
    expect(screen.getByRole("tab", { name: "Overview" })).toBeTruthy();
    expect(screen.getByRole("tab", { name: "Customer inputs" })).toBeTruthy();
    expect(screen.getByRole("tab", { name: "Feasibility" })).toBeTruthy();
    expect(screen.getByText("Project status")).toBeTruthy();
    expect(
      screen.getByText(/A project can only be created through the approved baseline/i),
    ).toBeTruthy();
  });
});
it("opens the integrated shared analysis and its explicit UI example from the opportunity", async () => {
  const user = userEvent.setup();
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  render(
    <QueryClientProvider client={queryClient}>
      <OpportunityDetail
        opportunity={opportunity}
        specification={null}
        requirements={[]}
        reviews={[]}
        departments={[]}
        employees={[]}
        feasibilityProvenance={{ available: false, error: "Source not installed" }}
        onViewSpecification={() => undefined}
        onOpenChange={() => undefined}
      />
    </QueryClientProvider>,
  );
  await user.click(screen.getByRole("button", { name: "Open shared analysis" }));
  expect(screen.getByRole("heading", { name: "Requirements to a shared decision" })).toBeTruthy();
  await user.click(screen.getByRole("button", { name: "Try example layout" }));
  expect(screen.getAllByRole("heading", { name: "Department remarks" })).toHaveLength(4);
  expect(screen.getByText("UI example · not saved to the portal.")).toBeTruthy();
  await user.click(screen.getByRole("button", { name: "Client preview" }));
  expect(screen.queryByRole("heading", { name: "Assigned reviews" })).toBeNull();
  expect(screen.queryByRole("heading", { name: "Review status" })).toBeNull();
});
