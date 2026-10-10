/** @vitest-environment jsdom */

import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { SalesOpportunityPipeline } from "./SalesOpportunityPipeline";

const opportunity = {
  id: "opportunity-id",
  opportunity_number: "OPPORTUNITY-2026-0013",
  name: "Tracker",
  stage: "new",
  status: "active",
  priority: "medium",
  application: null,
  product_type: null,
  nda_required: false,
  estimated_volume: null,
  target_timeline: null,
  next_action: null,
  next_action_date: null,
};

describe("SalesOpportunityPipeline", () => {
  it("does not render an empty state for a successful nonempty response", () => {
    render(<SalesOpportunityPipeline state={{ opportunities: [opportunity], pending: false, error: null }} />);
    expect(screen.queryByText(/No opportunities are available/i)).not.toBeInTheDocument();
    expect(screen.queryByText(/Loading opportunities/i)).not.toBeInTheDocument();
  });

  it("keeps pending separate from a settled empty response", () => {
    const { rerender } = render(<SalesOpportunityPipeline state={{ opportunities: undefined, pending: true, error: null }} />);
    expect(screen.getByText("Loading opportunities…")).toBeInTheDocument();
    rerender(<SalesOpportunityPipeline state={{ opportunities: [], pending: false, error: null }} />);
    expect(screen.getByText("No opportunities are available for this signed-in user.")).toBeInTheDocument();
  });

  it("reports a failed response instead of an empty dataset", () => {
    render(<SalesOpportunityPipeline state={{ opportunities: undefined, pending: false, error: new Error("Access query failed") }} />);
    expect(screen.getByRole("alert")).toHaveTextContent("Opportunities could not be loaded: Access query failed");
  });

  it("does not retain a prior actor's response as a new actor's settled data", () => {
    const { rerender } = render(<SalesOpportunityPipeline state={{ opportunities: [opportunity], pending: false, error: null }} />);
    expect(screen.queryByText(/Sales records are not available/i)).not.toBeInTheDocument();
    rerender(<SalesOpportunityPipeline state={{ opportunities: undefined, pending: false, error: null }} />);
    expect(screen.getByText("Sales records are not available for this signed-in user.")).toBeInTheDocument();
  });
});