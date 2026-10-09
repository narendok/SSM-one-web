/** @vitest-environment jsdom */

import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { cleanup, render, screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";
import { useState } from "react";
import { StructuredTemplatePreview } from "./StructuredTemplatePreview";
import { mapMasterSpecificationSource } from "@/lib/lifecycle-structured-template-previews";

const source = mapMasterSpecificationSource({ opportunityId: "opportunity-id", opportunityNumber: "OPPORTUNITY-2026-0013", opportunityName: "Tracker", customerId: "customer-id", customerName: "SAMPLE ONLY", specificationId: "specification-id", specificationNumber: "MASTER-2026-0001", versionId: "version-id", versionNumber: 1, changeSummary: "Initial intake", savedAt: "2026-10-05T18:37:27.589Z", project: null, specificationData: {} });
const previewSource = vi.fn();

vi.mock("@/lib/lifecycle-structured-template-previews.functions", () => ({
  fetchStructuredTemplatePreviewSource: (input: unknown) => previewSource(input),
}));

vi.mock("@tanstack/react-start", async () => {
  const actual = await vi.importActual<typeof import("@tanstack/react-start")>("@tanstack/react-start");
  return { ...actual, useServerFn: () => vi.fn() };
});

function renderPreview() {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(<QueryClientProvider client={client}><StructuredTemplatePreview /></QueryClientProvider>);
}

function ExitHarness() {
  const [open, setOpen] = useState(true);
  const [dirty, setDirty] = useState(false);
  const [confirming, setConfirming] = useState(false);
  if (!open) return <p>Exited preview</p>;
  return <><button onClick={() => dirty ? setConfirming(true) : setOpen(false)}>Back</button><button aria-label="Close preview" onClick={() => dirty ? setConfirming(true) : setOpen(false)}>Close</button><StructuredTemplatePreview onDirtyChange={setDirty} />{confirming && <section role="dialog"><p>Discard unsaved local edits?</p><button onClick={() => setConfirming(false)}>Keep editing</button><button onClick={() => setOpen(false)}>Discard edits</button></section>}</>;
}

afterEach(() => {
  cleanup();
  previewSource.mockReset();
});

describe("StructuredTemplatePreview mounted local interactions", () => {
  it("retains exact SOR local text across Contract Review and PRS before returning to SOR", async () => {
    previewSource.mockResolvedValue(source);
    const user = userEvent.setup();
    renderPreview();
    const scope = await screen.findByLabelText("Scope statement");
    const exact = '  Exact local <img src=x onerror="alert(1)">\nkept.  ';
    await user.clear(scope);
    await user.type(scope, exact);
    expect((screen.getByRole("button", { name: "Refresh source" }) as HTMLButtonElement).disabled).toBe(true);
    await user.click(screen.getByRole("tab", { name: "Contract Review" }));
    await user.click(screen.getByRole("tab", { name: "Product Requirements Specification" }));
    await user.click(screen.getByRole("tab", { name: "Statement of Requirements" }));
    expect((screen.getByLabelText("Scope statement") as HTMLTextAreaElement).value).toBe(exact);
    const frame = screen.getByTitle("Statement of Requirements local unsaved preview");
    expect(frame.getAttribute("sandbox")).toBe("");
    expect(frame.hasAttribute("allow-scripts")).toBe(false);
    expect(frame.getAttribute("srcdoc")).toContain("&lt;img src=x onerror=&quot;alert(1)&quot;&gt;");
    expect(frame.getAttribute("srcdoc")).not.toContain("<img");
  });

  it("labels loading and failed source reads as unverified without network access", async () => {
    let resolveSource: (value: typeof source) => void = () => undefined;
    previewSource.mockImplementation(() => new Promise<typeof source>((resolve) => { resolveSource = resolve; }));
    const { rerender } = renderPreview();
    expect(await screen.findByText("LOADING — source unavailable")).toBeTruthy();
    resolveSource(source);
    expect(await screen.findByText("Pinned authorized source")).toBeTruthy();
    previewSource.mockRejectedValue(new Error("denied by mock"));
    rerender(<QueryClientProvider client={new QueryClient({ defaultOptions: { queries: { retry: false } } })}><StructuredTemplatePreview sourcePin={{ opportunityNumber: "OPPORTUNITY-2026-9999", specificationNumber: "MASTER-2026-9999", versionNumber: 1 }} /></QueryClientProvider>);
    expect(await screen.findByText("UNVERIFIED — source unavailable")).toBeTruthy();
    expect(await screen.findByText(/Authorized source could not be loaded: denied by mock/)).toBeTruthy();
  });

  it("keeps local edits after Back or Close confirmation is cancelled and exits only after discard", async () => {
    previewSource.mockResolvedValue(source);
    const user = userEvent.setup();
    const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
    render(<QueryClientProvider client={client}><ExitHarness /></QueryClientProvider>);
    const scope = await screen.findByLabelText("Scope statement");
    await user.clear(scope);
    await user.type(scope, "Keep this exact draft");
    await user.click(screen.getByRole("button", { name: "Back" }));
    const firstDialog = await screen.findByRole("dialog");
    expect(within(firstDialog).getByText("Discard unsaved local edits?")).toBeTruthy();
    await user.click(within(firstDialog).getByRole("button", { name: "Keep editing" }));
    expect((screen.getByLabelText("Scope statement") as HTMLTextAreaElement).value).toBe("Keep this exact draft");
    await user.click(screen.getByRole("button", { name: "Close preview" }));
    await user.click(screen.getByRole("button", { name: "Discard edits" }));
    await waitFor(() => expect(screen.getByText("Exited preview")).toBeTruthy());
  });
});