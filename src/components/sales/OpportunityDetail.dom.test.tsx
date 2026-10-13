/** @vitest-environment jsdom */

import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
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
  customer: { id: "customer-id", legal_name: "OEM Tracker", customer_code: "CUSTOMER-2026-0001", is_sample: true },
};

describe("OpportunityDetail", () => {
  it("shows one tabbed workspace with source pins and no invented feasibility route", () => {
    const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } });
    render(<QueryClientProvider client={queryClient}><OpportunityDetail opportunity={opportunity} specification={{ id: "spec-id", opportunity_id: "opportunity-id", customer_id: "customer-id", specification_number: "MASTER-2026-0001", title: "Tracker", status: "active", current_version: 1 }} requirements={[]} reviews={[]} departments={[]} employees={[]} feasibilityProvenance={{ available: false, error: "Immutable feasibility provenance is unavailable." }} onViewSpecification={() => undefined} onOpenChange={() => undefined} /></QueryClientProvider>);
    expect(screen.getByRole("tab", { name: "Overview" })).toBeTruthy();
    expect(screen.getByRole("tab", { name: "Customer inputs" })).toBeTruthy();
    expect(screen.getByRole("tab", { name: "Feasibility" })).toBeTruthy();
    expect(screen.getByText("Project status")).toBeTruthy();
    expect(screen.getByText(/A project can only be created through the approved baseline/i)).toBeTruthy();
    expect(screen.getByText("Not sent for feasibility; no assigned team.")).toBeTruthy();
    expect(screen.getByRole("button", { name: "Start feasibility review" })).toBeDisabled();
  });
});