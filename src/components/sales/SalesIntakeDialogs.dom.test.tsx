/** @vitest-environment jsdom */

import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { cleanup, fireEvent, render, screen, waitFor } from "@testing-library/react";
import { useState } from "react";
import userEvent from "@testing-library/user-event";
import { afterAll, afterEach, beforeAll, describe, expect, it, vi } from "vitest";
import { OpportunityDialog } from "./SalesIntakeDialogs";

const createOpportunity = vi.fn();
const saveSpecification = vi.fn();
const originalScrollIntoView = HTMLElement.prototype.scrollIntoView;

vi.mock("@/lib/sales.functions", () => ({ createSalesEnquiry: "createSalesEnquiry", createSalesOpportunity: "createSalesOpportunity" }));
vi.mock("@/lib/master-specifications.functions", () => ({ saveMasterSpecification: "saveMasterSpecification" }));
vi.mock("@tanstack/react-start", async () => {
  const actual = await vi.importActual<typeof import("@tanstack/react-start")>("@tanstack/react-start");
  return { ...actual, useServerFn: (operation: string) => operation === "createSalesOpportunity" ? createOpportunity : saveSpecification };
});

const customer = { id: "customer-1", customer_code: "CUST-001", legal_name: "Northwind", display_name: null, customer_type: "prospect", industry: null, primary_email: null, primary_phone: null, account_owner_user_id: null, status: "active", created_at: "2026-10-09T00:00:00Z", updated_at: "2026-10-09T00:00:00Z" };

function renderDialog() {
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  const onOpenChange = vi.fn();
  render(<QueryClientProvider client={queryClient}><OpportunityDialog open onOpenChange={onOpenChange} customers={[customer]} contacts={[]} enquiries={[]} /></QueryClientProvider>);
  return { queryClient, onOpenChange };
}

function renderControlledDialog() {
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  function Harness() {
    const [open, setOpen] = useState(true);
    return <QueryClientProvider client={queryClient}><button type="button" onClick={() => setOpen(true)}>Open proposal</button><OpportunityDialog open={open} onOpenChange={setOpen} customers={[customer]} contacts={[]} enquiries={[]} /></QueryClientProvider>;
  }
  render(<Harness />);
  return { queryClient };
}

beforeAll(() => {
  HTMLElement.prototype.scrollIntoView = vi.fn();
});

afterAll(() => {
  HTMLElement.prototype.scrollIntoView = originalScrollIntoView;
});

async function completeRequiredFields(user: ReturnType<typeof userEvent.setup>) {
  fireEvent.click(screen.getAllByRole("combobox")[0]);
  fireEvent.click(await screen.findByRole("option", { name: "CUST-001 · Northwind" }));
  await user.type(screen.getByPlaceholderText("Possible / proposed project name"), "Manual proposal name");
  await user.type(screen.getAllByPlaceholderText("Unknown / To be confirmed")[0], "Medical");
  await user.type(screen.getAllByPlaceholderText("Unknown / To be confirmed")[1], "Controller");
  await user.type(screen.getByPlaceholderText(/What development is proposed/), "Manual scope retained after a partial result");
  await user.type(screen.getByPlaceholderText("Controlled summary of the proposed product need."), "Manual requirement retained after a partial result");
}

afterEach(() => {
  cleanup();
  createOpportunity.mockReset();
  saveSpecification.mockReset();
});

describe("OpportunityDialog partial-save recovery", () => {
  it("retains a known opportunity and manual inputs after specification failure without creating it again", async () => {
    const user = userEvent.setup();
    createOpportunity.mockResolvedValue({ id: "opportunity-1", opportunityNumber: "OPPORTUNITY-2026-0099" });
    saveSpecification.mockRejectedValue(new Error("Specification transport lost"));
    renderDialog();
    await completeRequiredFields(user);

    fireEvent.submit(screen.getByRole("button", { name: "Save proposed project" }).closest("form") as HTMLFormElement);

    expect((await screen.findByRole("alert")).textContent).toContain("Opportunity OPPORTUNITY-2026-0099 was saved");
    expect(screen.getByDisplayValue("Manual proposal name")).toBeTruthy();
    expect(screen.getByDisplayValue("Manual scope retained after a partial result")).toBeTruthy();
    expect((screen.getByRole("button", { name: "Reconciliation required" }) as HTMLButtonElement).disabled).toBe(true);

    fireEvent.submit(screen.getByRole("button", { name: "Reconciliation required" }).closest("form") as HTMLFormElement);
    expect(createOpportunity).toHaveBeenCalledTimes(1);
    expect(saveSpecification).toHaveBeenCalledTimes(1);
  });

  it("keeps completed writes separate from a failed refresh and retries only the existing read", async () => {
    const user = userEvent.setup();
    createOpportunity.mockResolvedValue({ id: "opportunity-1", opportunityNumber: "OPPORTUNITY-2026-0099" });
    saveSpecification.mockResolvedValue({ specificationId: "spec-1", versionId: "version-1", specificationNumber: "MASTER-2026-0099", versionNumber: 1 });
    const { queryClient, onOpenChange } = renderDialog();
    const invalidate = vi.spyOn(queryClient, "invalidateQueries").mockRejectedValueOnce(new Error("Overview unavailable")).mockResolvedValueOnce(undefined);
    await completeRequiredFields(user);

    fireEvent.submit(screen.getByRole("button", { name: "Save proposed project" }).closest("form") as HTMLFormElement);

    expect((await screen.findByRole("alert")).textContent).toContain("Sales data refresh failed: Overview unavailable");
    expect(screen.getByText(/Proposed project OPPORTUNITY-2026-0099 completed with MASTER-2026-0099 rev 1/)).toBeTruthy();
    expect(createOpportunity).toHaveBeenCalledTimes(1);
    expect(saveSpecification).toHaveBeenCalledTimes(1);

    await user.click(screen.getByRole("button", { name: "Retry sales refresh" }));
    await waitFor(() => expect(onOpenChange).toHaveBeenCalledWith(false));
    expect(invalidate).toHaveBeenCalledTimes(2);
    expect(createOpportunity).toHaveBeenCalledTimes(1);
    expect(saveSpecification).toHaveBeenCalledTimes(1);
  });

  it("resets a completed proposal only after its successful refresh closes, then allows a fresh proposal on reopen", async () => {
    const user = userEvent.setup();
    createOpportunity.mockResolvedValue({ id: "opportunity-1", opportunityNumber: "OPPORTUNITY-2026-0099" });
    saveSpecification.mockResolvedValue({ specificationId: "spec-1", versionId: "version-1", specificationNumber: "MASTER-2026-0099", versionNumber: 1 });
    const { queryClient } = renderControlledDialog();
    vi.spyOn(queryClient, "invalidateQueries").mockResolvedValue(undefined);
    await completeRequiredFields(user);

    fireEvent.submit(screen.getByRole("button", { name: "Save proposed project" }).closest("form") as HTMLFormElement);
    await waitFor(() => expect(screen.queryByRole("dialog")).toBeNull());
    await waitFor(() => expect(screen.queryByRole("dialog")).toBeNull());

    await user.click(screen.getByRole("button", { name: "Open proposal" }));
    expect(screen.getByRole("button", { name: "Save proposed project" })).toBeTruthy();
    expect(screen.queryByText(/completed with MASTER-2026-0099/)).toBeNull();
    expect(screen.queryByDisplayValue("Manual proposal name")).toBeNull();
  });

  it("blocks partial-save dismissal and retains the manual proposal for recovery", async () => {
    const user = userEvent.setup();
    createOpportunity.mockResolvedValue({ id: "opportunity-1", opportunityNumber: "OPPORTUNITY-2026-0099" });
    saveSpecification.mockRejectedValue(new Error("Specification transport lost"));
    renderControlledDialog();
    await completeRequiredFields(user);

    fireEvent.submit(screen.getByRole("button", { name: "Save proposed project" }).closest("form") as HTMLFormElement);
    await screen.findByRole("alert", { name: "" });
    await user.click(screen.getByRole("button", { name: "Close" }));

    expect(screen.getByRole("dialog")).toBeTruthy();
    expect(screen.getByText(/cannot be closed while its Master Specification outcome is unverified/)).toBeTruthy();
    expect(screen.getByDisplayValue("Manual proposal name")).toBeTruthy();
    expect(screen.getByDisplayValue("Manual scope retained after a partial result")).toBeTruthy();
  });

  it("uses a synchronous in-flight lock so two submissions create only one opportunity", async () => {
    const user = userEvent.setup();
    let resolveCreate: ((value: { id: string; opportunityNumber: string }) => void) | undefined;
    createOpportunity.mockImplementation(() => new Promise((resolve) => { resolveCreate = resolve; }));
    saveSpecification.mockResolvedValue({ specificationId: "spec-1", versionId: "version-1", specificationNumber: "MASTER-2026-0099", versionNumber: 1 });
    renderDialog();
    await completeRequiredFields(user);
    const form = screen.getByRole("button", { name: "Save proposed project" }).closest("form") as HTMLFormElement;

    fireEvent.submit(form);
    fireEvent.submit(form);
    expect(createOpportunity).toHaveBeenCalledTimes(1);
    resolveCreate?.({ id: "opportunity-1", opportunityNumber: "OPPORTUNITY-2026-0099" });
    await waitFor(() => expect(saveSpecification).toHaveBeenCalledTimes(1));
  });
});