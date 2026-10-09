// @vitest-environment jsdom
import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterAll, afterEach, beforeAll, describe, expect, it, vi } from "vitest";
import { AssignedFeasibilityDialog } from "./SalesLifecycleDialogs";

const review = {
  id: "review-1",
  requirement_id: "requirement-1",
  reviewer_user_id: "reviewer-1",
  status: "feasible",
  assumptions: null,
  risks: null,
  requirement: { id: "requirement-1", requirement_number: "REQ-001", title: "Cached requirement evidence", current_revision: 2 },
  department: { id: "department-1", name: "Hardware" },
};

const originalScrollIntoView = HTMLElement.prototype.scrollIntoView;

function renderDialog(provenanceError: string | null, reviews = [review]) {
  return render(<AssignedFeasibilityDialog open onOpenChange={() => undefined} reviews={reviews as any} provenanceError={provenanceError} />);
}

async function selectReview() {
  fireEvent.click(screen.getByRole("combobox"));
  fireEvent.click(await screen.findByRole("option", { name: "REQ-001 · rev 2 · Hardware" }));
}

afterEach(cleanup);

beforeAll(() => {
  HTMLElement.prototype.scrollIntoView = vi.fn();
});

afterAll(() => {
  HTMLElement.prototype.scrollIntoView = originalScrollIntoView;
});

describe("AssignedFeasibilityDialog provenance presentation", () => {
  it("keeps absent immutable provenance fail-closed without presenting it as a transport failure", async () => {
    renderDialog(null);
    await selectReview();
    expect(screen.getByText("Cached requirement evidence")).toBeTruthy();
    expect(screen.getByText(/current immutable customer-requirement revision is unavailable/i)).toBeTruthy();
    expect(screen.queryByText(/source records could not be verified/i)).toBeNull();
    expect(screen.getByRole("button", { name: /record feasibility response/i })).toHaveProperty("disabled", true);
  });

  it("presents an actual provenance read failure as a transport failure and remains blocked", async () => {
    renderDialog("RLS read denied");
    await selectReview();
    expect(screen.getByText(/source records could not be verified/i)).toBeTruthy();
    expect(screen.getByRole("button", { name: /record feasibility response/i })).toHaveProperty("disabled", true);
  });

  it("retains cached review evidence when a later provenance refresh fails", async () => {
    const view = renderDialog(null);
    await selectReview();
    view.rerender(<AssignedFeasibilityDialog open onOpenChange={() => undefined} reviews={[review] as any} provenanceError="RLS read denied" />);
    expect(screen.getByText("Cached requirement evidence")).toBeTruthy();
    expect(screen.getByText(/assigned department: Hardware/i)).toBeTruthy();
    expect(screen.getByText(/source records could not be verified/i)).toBeTruthy();
    expect(screen.getByRole("button", { name: /record feasibility response/i })).toHaveProperty("disabled", true);
  });
});
