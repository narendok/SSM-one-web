/** @vitest-environment jsdom */
import { afterEach, expect, it, vi } from "vitest";
import { cleanup, render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { EnquiriesWorkspace } from "./EnquiriesWorkspace";
import type { SalesOpportunity } from "@/lib/sales";
afterEach(cleanup);
const opportunity = {
  id: "opp",
  opportunity_number: "OPPORTUNITY-2026-0013",
  name: "Tracker connector variant",
  stage: "new",
  status: "active",
  enquiry_id: null,
  next_action: null,
  customer: { legal_name: "Sample customer", is_sample: true },
} as SalesOpportunity;
it("shows a compact status table and opens the exact row analysis or handover", async () => {
  const open = vi.fn(),
    analysis = vi.fn(),
    share = vi.fn();
  render(
    <EnquiriesWorkspace
      enquiries={[]}
      opportunities={[opportunity]}
      requirements={[]}
      reviews={[]}
      onNew={vi.fn()}
      onOpenEnquiry={vi.fn()}
      onOpenOpportunity={open}
      onOpenAnalysis={analysis}
      onShareOpportunity={share}
    />,
  );
  expect(screen.getByRole("table", { name: "Enquiries and opportunities" })).toBeTruthy();
  expect(screen.getByRole("columnheader", { name: "Next action" })).toBeTruthy();
  expect(screen.getByText("active")).toBeTruthy();
  expect(screen.getByText("Prepare team handover")).toBeTruthy();
  const user = userEvent.setup();
  await user.click(
    screen.getByRole("button", { name: "Open shared analysis for OPPORTUNITY-2026-0013" }),
  );
  expect(analysis).toHaveBeenCalledWith(opportunity);
  await user.click(
    screen.getByRole("button", { name: "Prepare team handover for OPPORTUNITY-2026-0013" }),
  );
  expect(share).toHaveBeenCalledWith(opportunity);
  expect(open).not.toHaveBeenCalled();
  await user.type(screen.getByRole("textbox", { name: "Search sales pipeline" }), "unmatched");
  expect(screen.getByText(/No authorised enquiries/)).toBeTruthy();
});
