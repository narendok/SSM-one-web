/** @vitest-environment jsdom */
import { afterEach, describe, expect, it, vi } from "vitest";
import { cleanup, render, screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { SharedFeasibilityAnalysis } from "./SharedFeasibilityAnalysis";
import type { FeasibilityReview } from "@/lib/sales";

afterEach(cleanup);
const review: FeasibilityReview = {
  id: "review-one",
  requirement_id: "requirement-one",
  department_id: "hardware",
  reviewer_user_id: "reviewer",
  status: "pending",
  findings: "Restricted technical finding",
  assumptions: "Internal engineering assumption",
  risks: "Private supplier concern",
  reviewed_at: null,
  created_at: "2026-10-14",
  source_revision_id: null,
  source_revision_number: null,
  master_specification_version_id: null,
  master_specification_version_number: null,
  applicable_workstreams: null,
  department: { id: "hardware", name: "Hardware", code: "RND" },
};
const source = {
  proposedName: "Private product",
  customerOrInternalOwner: "Private customer",
  industryApplication: "Restricted application",
  productFamily: "Gateway",
  developmentScope: "Internal scope",
  workstreams: ["HARDWARE"],
  requirementSummary: "Private requirement",
  powerAndUnits: "12 V",
  interfaces: "CAN",
  connectivityAndGnss: "TBC",
  environmentAndIp: "TBC",
  volumes: "100",
  schedule: "TBC",
  requestedStandards: "TBC",
  exclusions: "TBC",
};
function setup(reviews: FeasibilityReview[] = [review], sourceError = false) {
  const onOpenSource = vi.fn();
  render(
    <SharedFeasibilityAnalysis
      specification={{
        id: "spec",
        opportunity_id: "opportunity",
        customer_id: "customer",
        specification_number: "MASTER-EXAMPLE",
        title: "Private product",
        status: "active",
        current_version: 2,
      }}
      specificationData={source}
      sourceLoading={false}
      sourceError={sourceError}
      reviews={reviews}
      departments={[]}
      employees={[]}
      onOpenSource={onOpenSource}
    />,
  );
  return { user: userEvent.setup(), onOpenSource };
}

describe("SharedFeasibilityAnalysis", () => {
  it("shows caller-provided records without inventing approval or client highlights", () => {
    setup();
    expect(screen.getByText("Restricted technical finding")).toBeTruthy();
    expect(screen.getByText(/revision 2 · approval not verified/)).toBeTruthy();
    expect(screen.getByText("No published department remarks recorded.")).toBeTruthy();
    expect(screen.queryByRole("button", { name: "Edit highlight" })).toBeNull();
    expect(screen.queryByText("Example hardware reviewer")).toBeNull();
  });

  it("does not project internal source data or findings into a client preview", async () => {
    const { user } = setup();
    await user.click(screen.getByRole("button", { name: "Client preview" }));
    expect(screen.queryByText("Restricted application")).toBeNull();
    expect(screen.queryByText("Restricted technical finding")).toBeNull();
    expect(screen.queryByText("Internal engineering assumption")).toBeNull();
    expect(screen.queryByText("Private supplier concern")).toBeNull();
    expect(
      screen.getByText("No client-visible highlights have been verified for this opportunity."),
    ).toBeTruthy();
  });

  it("keeps the example opt-in and restores recorded data on exit", async () => {
    const { user } = setup([]);
    expect(screen.getByText("No assigned review records")).toBeTruthy();
    await user.click(screen.getByRole("button", { name: "Try example layout" }));
    expect(screen.getByText("UI example · not saved to the portal.")).toBeTruthy();
    expect(screen.getAllByRole("heading", { name: "Client-visible highlight" })).toHaveLength(4);
    await user.click(screen.getByRole("button", { name: "Exit example" }));
    expect(screen.getByText("No assigned review records")).toBeTruthy();
    expect(screen.queryByText("Example hardware reviewer")).toBeNull();
  });

  it("lets a highlight be reviewed in the example client view without exposing internal notes", async () => {
    const { user } = setup();
    await user.click(screen.getByRole("button", { name: "Try example layout" }));
    const hardware = within(screen.getByRole("article", { name: "Hardware analysis" }));
    await user.click(hardware.getByRole("button", { name: "Edit highlight" }));
    await user.clear(hardware.getByRole("textbox", { name: "Example highlight" }));
    await user.type(
      hardware.getByRole("textbox", { name: "Example highlight" }),
      "Please confirm the client connector drawing.",
    );
    await user.click(hardware.getByRole("button", { name: "Save preview" }));
    expect(screen.getByRole("status").textContent).toContain("Nothing was published or sent");
    await user.click(screen.getByRole("button", { name: "Client preview" }));
    expect(screen.getByText("Please confirm the client connector drawing.")).toBeTruthy();
    expect(screen.queryByText(/Supplier negotiations and internal costing/)).toBeNull();
    expect(screen.queryByText(/Compare board reuse and a layout revision/)).toBeNull();
  });

  it("edits internal remarks independently and excludes them from the client projection", async () => {
    const { user } = setup();
    await user.click(screen.getByRole("button", { name: "Try example layout" }));
    const hardware = within(screen.getByRole("article", { name: "Hardware analysis" }));
    await user.click(hardware.getByRole("button", { name: "Edit internal remark" }));
    await user.clear(hardware.getByRole("textbox", { name: "Example internal remark" }));
    await user.type(
      hardware.getByRole("textbox", { name: "Example internal remark" }),
      "Private margin concern",
    );
    await user.click(hardware.getByRole("button", { name: "Save preview" }));
    expect(hardware.getByText("Private margin concern")).toBeTruthy();
    await user.click(screen.getByRole("button", { name: "Client preview" }));
    expect(screen.queryByText("Private margin concern")).toBeNull();
    expect(screen.queryByRole("heading", { name: "Internal remarks" })).toBeNull();
    await user.click(screen.getByRole("button", { name: "Internal view" }));
    await user.click(screen.getByRole("button", { name: "Exit example" }));
    await user.click(screen.getByRole("button", { name: "Try example layout" }));
    expect(screen.queryByText("Private margin concern")).toBeNull();
  });

  it("does not autosave requirement edits or overwrite the example reviewed snapshot", async () => {
    const { user } = setup();
    await user.click(screen.getByRole("button", { name: "Try example layout" }));
    await user.click(screen.getByRole("button", { name: "Edit example" }));
    await user.clear(screen.getByRole("textbox", { name: "Interfaces" }));
    await user.type(screen.getByRole("textbox", { name: "Interfaces" }), "CAN + 12-pin connector");
    await user.click(screen.getByRole("button", { name: "Cancel" }));
    expect(screen.queryByText("Latest example input · needs review")).toBeNull();
    await user.click(screen.getByRole("button", { name: "Edit example" }));
    expect((screen.getByRole("textbox", { name: "Interfaces" }) as HTMLInputElement).value).toBe(
      "CAN + 8-pin connector",
    );
    await user.clear(screen.getByRole("textbox", { name: "Interfaces" }));
    await user.type(screen.getByRole("textbox", { name: "Interfaces" }), "CAN + 12-pin connector");
    await user.click(screen.getByRole("button", { name: "Save preview" }));
    expect(screen.getByText("Latest example input · needs review")).toBeTruthy();
    expect(screen.getByText("CAN + 8-pin connector")).toBeTruthy();
    expect(screen.getByText(/No baseline changed and no notifications sent/)).toBeTruthy();
  });

  it("keeps internal preview messages out of the client view unless explicitly marked", async () => {
    const { user } = setup();
    await user.click(screen.getByRole("button", { name: "Try example layout" }));
    await user.type(
      screen.getByRole("textbox", { name: "Preview message" }),
      "Internal sourcing discussion",
    );
    await user.click(screen.getByRole("button", { name: "Add to preview" }));
    await user.type(
      screen.getByRole("textbox", { name: "Preview message" }),
      "Can you confirm the mounting clearance?",
    );
    await user.click(screen.getByRole("checkbox", { name: "Client-visible message" }));
    await user.click(screen.getByRole("button", { name: "Add to preview" }));
    await user.click(screen.getByRole("button", { name: "Client preview" }));
    expect(screen.queryByText("Internal sourcing discussion")).toBeNull();
    expect(screen.getByText("Can you confirm the mounting clearance?")).toBeTruthy();
  });

  it("shows a source read failure without substituting requirements or approval", () => {
    setup([], true);
    expect(screen.getByRole("alert").textContent).toContain("could not be loaded");
    expect(screen.queryByText("Restricted application")).toBeNull();
    expect(screen.queryByText("12 V / 24 V input")).toBeNull();
  });
});
