/** @vitest-environment jsdom */
import { cleanup, fireEvent, render, screen, waitFor } from "@testing-library/react";
import { afterEach, beforeEach, expect, it, vi } from "vitest";
const mocks = vi.hoisted(() => ({ read: vi.fn(), save: vi.fn(), availability: { available: true, reason: "Pending deployment" }, actor: "actor-1" }));
vi.mock("@/hooks/useAuth", () => ({ useAuth: () => ({ user: { id: mocks.actor }, loading: false }) }));
vi.mock("@/lib/requirement-highlight-drafts", () => ({ highlightDraftAvailability: mocks.availability }));
vi.mock("@/lib/requirement-highlight-drafts.functions", () => ({ readOwnRequirementHighlightDraft: mocks.read, saveOwnRequirementHighlightDraft: mocks.save }));
import { OwnFeasibilityHighlightDraftEditor } from "./OwnFeasibilityHighlightDraftEditor";
const scope = { reviewId: "review", sourceRevisionId: "revision", masterVersionId: "master" };
const note = { id: "note", version_number: 2, body: "Saved internal note", saved_at: "2026-10-16" };
beforeEach(() => { vi.clearAllMocks(); mocks.availability.available = true; mocks.actor = "actor-1"; mocks.read.mockResolvedValue(note); mocks.save.mockResolvedValue({ ...note, version_number: 3, body: "Updated" }); });
afterEach(cleanup);
it("does not read or expose edits while deployment is disabled", () => { mocks.availability.available = false; render(<OwnFeasibilityHighlightDraftEditor scope={scope} />); expect(screen.getByText("Pending deployment")).toBeTruthy(); expect(mocks.read).not.toHaveBeenCalled(); });
it("keeps input read-only until Edit and cancels without writing", async () => { render(<OwnFeasibilityHighlightDraftEditor scope={scope} />); await screen.findByText(note.body); expect(screen.queryByRole("textbox")).toBeNull(); fireEvent.click(screen.getByText("Edit highlight draft")); fireEvent.change(screen.getByRole("textbox"), { target: { value: "Draft" } }); fireEvent.click(screen.getByText("Cancel")); expect(mocks.save).not.toHaveBeenCalled(); expect(screen.getByText(note.body)).toBeTruthy(); });
it("saves with the exact loaded version and displays the confirmed result", async () => { render(<OwnFeasibilityHighlightDraftEditor scope={scope} />); fireEvent.click(await screen.findByText("Edit highlight draft")); fireEvent.change(screen.getByRole("textbox"), { target: { value: "Updated" } }); fireEvent.click(screen.getByText("Save draft")); await screen.findByText("Updated"); expect(mocks.save).toHaveBeenCalledWith({ data: { ...scope, expectedVersion: 2, body: "Updated", requestKey: expect.any(String) } }); });
it("retains a failed draft and blocks retries until explicit reload", async () => { mocks.save.mockRejectedValue(new Error("uncertain")); render(<OwnFeasibilityHighlightDraftEditor scope={scope} />); fireEvent.click(await screen.findByText("Edit highlight draft")); fireEvent.change(screen.getByRole("textbox"), { target: { value: "Unconfirmed draft" } }); fireEvent.click(screen.getByText("Save draft")); await screen.findByRole("alert"); expect((screen.getByRole("textbox") as HTMLTextAreaElement).value).toBe("Unconfirmed draft"); expect((screen.getByText("Save draft") as HTMLButtonElement).disabled).toBe(true); fireEvent.click(screen.getByText("Reload and discard draft")); await waitFor(() => expect(mocks.read).toHaveBeenCalledTimes(2)); expect(mocks.save).toHaveBeenCalledTimes(1); });
it("does not turn denied reads into an empty editable note", async () => { mocks.read.mockRejectedValue(new Error("denied")); render(<OwnFeasibilityHighlightDraftEditor scope={scope} />); await screen.findByRole("alert"); expect((screen.getByText("Edit highlight draft") as HTMLButtonElement).disabled).toBe(true); expect(screen.queryByText("No saved highlight draft for this revision.")).toBeNull(); });
it("clears previous private state when the signed-in identity changes", async () => {
 const view = render(<OwnFeasibilityHighlightDraftEditor scope={scope} />);
 await screen.findByText(note.body);
 mocks.actor = "actor-2"; mocks.read.mockResolvedValue(null);
 view.rerender(<OwnFeasibilityHighlightDraftEditor scope={scope} />);
 await screen.findByText("No saved highlight draft for this revision.");
 expect(screen.queryByText(note.body)).toBeNull();
});
