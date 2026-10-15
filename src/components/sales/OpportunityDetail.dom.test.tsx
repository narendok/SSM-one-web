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
  expect(screen.getAllByRole("heading", { name: "Client-visible highlight" })).toHaveLength(4);
  expect(screen.getByText("UI example · not saved to the portal.")).toBeTruthy();
  await user.click(screen.getByRole("button", { name: "Client preview" }));
  expect(screen.queryByRole("heading", { name: "Assigned reviews" })).toBeNull();
  expect(screen.queryByRole("heading", { name: "Review status" })).toBeNull();
});

it.each(["feasibility", "handover"] as const)(
  "opens directly at the %s row shortcut",
  (initialView) => {
    const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
    render(
      <QueryClientProvider client={client}>
        <OpportunityDetail
          initialView={initialView}
          opportunity={opportunity}
          specification={null}
          requirements={[]}
          reviews={[]}
          departments={[]}
          employees={[]}
          feasibilityProvenance={{ available: false, error: "Not installed" }}
          onViewSpecification={() => undefined}
          onOpenChange={() => undefined}
        />
      </QueryClientProvider>,
    );
    if (initialView === "handover") {
      expect(screen.getByRole("dialog", { name: "Send for feasibility" })).toBeTruthy();
      expect(
        screen.getByRole("button", { name: "Send for feasibility" }).hasAttribute("disabled"),
      ).toBe(true);
    } else {
      expect(screen.getByRole("tab", { name: "Feasibility" }).getAttribute("aria-selected")).toBe(
        "true",
      );
      expect(
        screen.getByRole("heading", { name: "Requirements to a shared decision" }),
      ).toBeTruthy();
    }
  },
);

it("prepares multiple distinct teams without enabling submission", async () => {
  const user = userEvent.setup();
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  render(
    <QueryClientProvider client={client}>
      <OpportunityDetail
        initialView="handover"
        opportunity={opportunity}
        specification={null}
        requirements={[]}
        reviews={[]}
        departments={[
          { id: "hardware", name: "Hardware", code: null },
          { id: "firmware", name: "Firmware", code: null },
        ]}
        employees={[
          { user_id: "reviewer-a", display_name: "Reviewer A", official_email: null },
          { user_id: "reviewer-b", display_name: "Reviewer B", official_email: null },
        ]}
        feasibilityProvenance={{ available: false, error: "Not installed" }}
        onViewSpecification={() => undefined}
        onOpenChange={() => undefined}
      />
    </QueryClientProvider>,
  );
  expect(
    (screen.getByRole("button", { name: "Add department" }) as HTMLButtonElement).disabled,
  ).toBe(true);
  await user.selectOptions(screen.getByLabelText("Department 1"), "hardware");
  await user.selectOptions(screen.getByLabelText("Intended reviewer 1"), "reviewer-a");
  await user.click(screen.getByRole("button", { name: "Add department" }));
  const secondDepartment = screen.getByLabelText("Department 2") as HTMLSelectElement;
  expect(
    secondDepartment.querySelector<HTMLOptionElement>('option[value="hardware"]')?.disabled,
  ).toBe(true);
  const secondReviewer = screen.getByLabelText("Intended reviewer 2") as HTMLSelectElement;
  expect(
    secondReviewer.querySelector<HTMLOptionElement>('option[value="reviewer-a"]')?.disabled,
  ).toBe(true);
  await user.selectOptions(secondDepartment, "firmware");
  await user.selectOptions(secondReviewer, "reviewer-b");
  expect(
    (screen.getByRole("button", { name: "Send for feasibility" }) as HTMLButtonElement).disabled,
  ).toBe(true);
  await user.click(screen.getByRole("button", { name: "Remove team 1" }));
  expect((screen.getByLabelText("Department 1") as HTMLSelectElement).value).toBe("firmware");
  expect(screen.queryByLabelText("Department 2")).toBeNull();
});
