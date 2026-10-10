/** @vitest-environment jsdom */

import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { cleanup, fireEvent, render, screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";
import { useState } from "react";
import { StructuredTemplatePreview } from "./StructuredTemplatePreview";
import { StructuredPreviewExitDialog } from "./StructuredPreviewExitBoundary";
import { mapMasterSpecificationSource } from "@/lib/lifecycle-structured-template-previews";
import { DialogDescription, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { supabase } from "@/integrations/supabase/client";

const source = mapMasterSpecificationSource({ opportunityId: "opportunity-id", opportunityNumber: "OPPORTUNITY-2026-0013", opportunityName: "Tracker", customerId: "customer-id", customerName: "SAMPLE ONLY", specificationId: "specification-id", specificationNumber: "MASTER-2026-0001", versionId: "version-id", versionNumber: 1, changeSummary: "Initial intake", savedAt: "2026-10-05T18:37:27.589Z", project: null, specificationData: {} });
const previewSource = vi.fn();

vi.mock("@/lib/lifecycle-structured-template-previews.functions", () => ({
  fetchStructuredTemplatePreviewSource: (input: unknown) => previewSource(input),
}));

vi.mock("@/integrations/supabase/client", () => ({
  supabase: { from: vi.fn() },
}));

vi.mock("@tanstack/react-start", async () => {
  const actual = await vi.importActual<typeof import("@tanstack/react-start")>("@tanstack/react-start");
  return { ...actual, useServerFn: () => vi.fn() };
});

function renderPreview() {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(<QueryClientProvider client={client}><StructuredTemplatePreview /></QueryClientProvider>);
}

function ProductionExitDialogHarness() {
  const [open, setOpen] = useState(true);
  const [dirty, setDirty] = useState(false);
  return <><button onClick={() => setOpen(true)}>Reopen preview</button>{open ? <StructuredPreviewExitDialog open={open} onOpenChange={setOpen} dirty={dirty}>{(requestExit) => <><DialogHeader><DialogTitle>Production proposal preview</DialogTitle><DialogDescription>Mounted production exit coverage.</DialogDescription></DialogHeader><button onClick={() => requestExit(() => setOpen(false))}>Back to opportunity</button><StructuredTemplatePreview onDirtyChange={setDirty} /></>}</StructuredPreviewExitDialog> : <p>Exited preview</p>}</>;
}

afterEach(() => {
  cleanup();
  previewSource.mockReset();
  vi.mocked(supabase.from).mockReset();
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

  it("preserves manual SOR text and shows a stale-source conflict only when a changed source arrives with local edits", async () => {
    previewSource.mockResolvedValue(source);
    const user = userEvent.setup();
    const { client } = (() => {
      const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
      render(<QueryClientProvider client={client}><StructuredTemplatePreview /></QueryClientProvider>);
      return { client };
    })();
    const scope = await screen.findByLabelText("Scope statement");
    await screen.findByText("version-id");
    expect(screen.queryByText(/The source pin advanced while local edits exist/)).toBeNull();
    await user.clear(scope);
    await user.type(scope, "Keep this manual scope exactly.");
    await waitFor(() => expect(screen.getByText(/Local edits are unsaved/)).toBeTruthy());
    client.setQueryData(["structured-template-source", "OPPORTUNITY-2026-0013", "MASTER-2026-0001", 1], { ...source, versionId: "amended-version-id", sourceFields: { ...source.sourceFields, REQUIREMENT_SUMMARY: "Amended source summary" } });
    await screen.findByText("amended-version-id");
    await waitFor(() => expect(screen.getByText(/The source pin advanced while local edits exist/)).toBeTruthy());
    expect((screen.getByLabelText("Scope statement") as HTMLTextAreaElement).value).toBe("Keep this manual scope exactly.");
    expect(screen.getByText("Amended source summary")).toBeTruthy();
  });

  it("uses a clean amended source as the next edit baseline without overwriting manual text", async () => {
    previewSource.mockResolvedValue(source);
    const user = userEvent.setup();
    const { client } = (() => {
      const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
      render(<QueryClientProvider client={client}><StructuredTemplatePreview /></QueryClientProvider>);
      return { client };
    })();
    const queryKey = ["structured-template-source", "OPPORTUNITY-2026-0013", "MASTER-2026-0001", 1];
    await screen.findByLabelText("Scope statement");
    await screen.findByText("version-id");
    client.setQueryData(queryKey, { ...source, versionId: "clean-amended-version-id" });
    await waitFor(() => expect(screen.getByText("clean-amended-version-id")).toBeTruthy());
    expect(screen.queryByText(/The source pin advanced while local edits exist/)).toBeNull();

    const scope = screen.getByLabelText("Scope statement");
    await user.clear(scope);
    await user.type(scope, "Keep this exact text after the clean amendment.");
    expect(screen.queryByText(/The source pin advanced while local edits exist/)).toBeNull();

    client.setQueryData(queryKey, { ...source, versionId: "dirty-amended-version-id" });
    await waitFor(() => expect(screen.getByText(/The source pin advanced while local edits exist/)).toBeTruthy());
    expect((screen.getByLabelText("Scope statement") as HTMLTextAreaElement).value).toBe("Keep this exact text after the clean amendment.");
  });

  it("adopts only empty BOM component fields, retains local edits through switching and source conflict, and makes no project-BOM calls while unprojected", async () => {
    previewSource.mockResolvedValue(source);
    const select = vi.fn().mockResolvedValue({ data: [{ id: "component-1", name: "Catalogue description", part_number: "CAT-001", manufacturer: "Catalogue maker" }], error: null });
    vi.mocked(supabase.from).mockReturnValue({ select: () => ({ or: () => ({ limit: select }) }) } as never);
    const user = userEvent.setup();
    const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
    render(<QueryClientProvider client={client}><StructuredTemplatePreview /></QueryClientProvider>);
    await screen.findByLabelText("Scope statement");
    await user.click(screen.getByRole("tab", { name: "BOM review" }));
    await user.click(screen.getByRole("button", { name: "Add Optional local scratch rows row" }));
    const mpn = screen.getByLabelText("Optional local scratch rows row 1 MPN");
    const manufacturer = screen.getByLabelText("Optional local scratch rows row 1 Manufacturer");
    const description = screen.getByLabelText("Optional local scratch rows row 1 Description");
    const quantity = screen.getByLabelText("Optional local scratch rows row 1 Qty");
    const packageField = screen.getByLabelText("Optional local scratch rows row 1 Package");
    await user.type(mpn, "Manual MPN");
    await user.type(quantity, "7");
    await user.type(packageField, "Manual package");
    await user.type(screen.getByLabelText("Search caller-visible components for Optional local scratch rows row 1"), "ca");
    await screen.findByRole("option", { name: /Catalogue description/ });
    await user.click(screen.getByRole("option", { name: /Catalogue description/ }));
    expect((mpn as HTMLInputElement).value).toBe("Manual MPN");
    expect((manufacturer as HTMLInputElement).value).toBe("Catalogue maker");
    expect((description as HTMLInputElement).value).toBe("Catalogue description");
    expect((quantity as HTMLInputElement).value).toBe("7");
    expect((packageField as HTMLInputElement).value).toBe("Manual package");
    expect(screen.getByText(/all nonempty manual values and every other field stay unchanged/)).toBeTruthy();

    const secondSelect = vi.fn().mockResolvedValue({ data: [{ id: "component-2", name: "Replacement description", part_number: "CAT-002", manufacturer: "Replacement maker" }], error: null });
    vi.mocked(supabase.from).mockReturnValue({ select: () => ({ or: () => ({ limit: secondSelect }) }) } as never);
    await user.type(screen.getByLabelText("Search caller-visible components for Optional local scratch rows row 1"), "re");
    await screen.findByRole("option", { name: /Replacement description/ });
    await user.click(screen.getByRole("option", { name: /Replacement description/ }));
    expect((mpn as HTMLInputElement).value).toBe("Manual MPN");
    expect((manufacturer as HTMLInputElement).value).toBe("Catalogue maker");
    expect((description as HTMLInputElement).value).toBe("Catalogue description");

    await user.click(screen.getByRole("tab", { name: "Statement of Requirements" }));
    await user.click(screen.getByRole("tab", { name: "BOM review" }));
    expect((screen.getByLabelText("Optional local scratch rows row 1 Description") as HTMLInputElement).value).toBe("Catalogue description");
    client.setQueryData(["structured-template-source", "OPPORTUNITY-2026-0013", "MASTER-2026-0001", 1], { ...source, versionId: "amended-version-id" });
    await screen.findByText(/The source pin advanced while local edits exist/);
    expect((screen.getByLabelText("Optional local scratch rows row 1 MPN") as HTMLInputElement).value).toBe("Manual MPN");
    expect(vi.mocked(supabase.from).mock.calls.map(([table]) => table)).toEqual(expect.arrayContaining(["components"]));
  });

  it("shows component search loading, empty, error, and ignores stale results without clearing local rows", async () => {
    previewSource.mockResolvedValue(source);
    let firstResolve: (value: { data: { id: string; name: string; part_number: string; manufacturer: string | null }[]; error: null }) => void = () => undefined;
    const first = new Promise<{ data: { id: string; name: string; part_number: string; manufacturer: string | null }[]; error: null }>((resolve) => { firstResolve = resolve; });
    const second = vi.fn().mockResolvedValue({ data: [], error: null });
    const limit = vi.fn().mockReturnValueOnce(first).mockImplementation(second);
    vi.mocked(supabase.from).mockReturnValue({ select: () => ({ or: () => ({ limit }) }) } as never);
    const user = userEvent.setup();
    renderPreview();
    await screen.findByLabelText("Scope statement");
    await user.click(screen.getByRole("tab", { name: "BOM review" }));
    await user.click(screen.getByRole("button", { name: "Add Optional local scratch rows row" }));
    const search = screen.getByLabelText("Search caller-visible components for Optional local scratch rows row 1");
    await user.type(search, "ol");
    expect(await screen.findByLabelText("Searching components")).toBeTruthy();
    await user.clear(search);
    await user.type(search, "new");
    await screen.findByText("No caller-visible components match this search. Your local row is unchanged.");
    firstResolve({ data: [{ id: "stale", name: "Stale result", part_number: "STALE", manufacturer: null }], error: null });
    await waitFor(() => expect(screen.queryByRole("option", { name: /Stale result/ })).toBeNull());

    vi.mocked(supabase.from).mockReturnValue({ select: () => ({ or: () => ({ limit: vi.fn().mockResolvedValue({ data: null, error: new Error("read denied") }) }) }) } as never);
    await user.clear(search);
    await user.type(search, "er");
    expect(await screen.findByText("Component search is unavailable. Your local row is unchanged.")).toBeTruthy();
    expect((screen.getByLabelText("Optional local scratch rows row 1 MPN") as HTMLInputElement).value).toBe("");
  });

  it("uses the production Radix dialog dismissal guard for Escape and outside interactions, retaining edits until discard", async () => {
    previewSource.mockResolvedValue(source);
    const user = userEvent.setup();
    const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
    render(<QueryClientProvider client={client}><ProductionExitDialogHarness /></QueryClientProvider>);
    const scope = await screen.findByLabelText("Scope statement");
    await user.clear(scope);
    await user.type(scope, "Keep this exact draft");
    await user.keyboard("{Escape}");
    const firstDialog = await screen.findByText("Discard unsaved local edits?").then((title) => title.closest("[role=alertdialog]") as HTMLElement | null);
    if (!firstDialog) throw new Error("Discard confirmation did not open.");
    expect(within(firstDialog).getByText("Discard unsaved local edits?")).toBeTruthy();
    await user.click(within(firstDialog).getByRole("button", { name: "Keep editing" }));
    expect((screen.getByLabelText("Scope statement") as HTMLTextAreaElement).value).toBe("Keep this exact draft");
    fireEvent.pointerDown(document.body);
    fireEvent.click(document.body);
    expect(await screen.findByText("Discard unsaved local edits?")).toBeTruthy();
    await user.click(screen.getByRole("button", { name: "Discard edits" }));
    await waitFor(() => expect(screen.getByText("Exited preview")).toBeTruthy());
    await user.click(screen.getByRole("button", { name: "Reopen preview" }));
    expect((await screen.findByLabelText("Scope statement") as HTMLTextAreaElement).value).toBe("TBC");
    expect((screen.getByRole("button", { name: "Refresh source" }) as HTMLButtonElement).disabled).toBe(false);
  });

  it("uses the production Back and built-in Close exits, keeping exact edits until an explicit discard", async () => {
    previewSource.mockResolvedValue(source);
    const user = userEvent.setup();
    const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
    render(<QueryClientProvider client={client}><ProductionExitDialogHarness /></QueryClientProvider>);
    const scope = await screen.findByLabelText("Scope statement");
    await user.clear(scope);
    await user.type(scope, "Keep this exact Back and Close draft");

    await user.click(screen.getByRole("button", { name: "Back to opportunity" }));
    await user.click(await screen.findByRole("button", { name: "Keep editing" }));
    expect((screen.getByLabelText("Scope statement") as HTMLTextAreaElement).value).toBe("Keep this exact Back and Close draft");

    await user.click(screen.getByRole("button", { name: "Close" }));
    const confirmation = await screen.findByText("Discard unsaved local edits?").then((title) => title.closest("[role=alertdialog]") as HTMLElement | null);
    if (!confirmation) throw new Error("Discard confirmation did not open from the built-in Close button.");
    await user.click(within(confirmation).getByRole("button", { name: "Discard edits" }));
    await waitFor(() => expect(screen.getByText("Exited preview")).toBeTruthy());
  });

  it("exits clean previews by Escape and built-in Close without confirmation, and reopens without stale dirty state", async () => {
    previewSource.mockResolvedValue(source);
    const user = userEvent.setup();
    const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
    render(<QueryClientProvider client={client}><ProductionExitDialogHarness /></QueryClientProvider>);

    await screen.findByLabelText("Scope statement");
    await user.keyboard("{Escape}");
    await waitFor(() => expect(screen.getByText("Exited preview")).toBeTruthy());
    expect(screen.queryByText("Discard unsaved local edits?")).toBeNull();

    await user.click(screen.getByRole("button", { name: "Reopen preview" }));
    expect((await screen.findByLabelText("Scope statement") as HTMLTextAreaElement).value).toBe("TBC");
    expect((screen.getByRole("button", { name: "Refresh source" }) as HTMLButtonElement).disabled).toBe(false);
    await user.click(screen.getByRole("button", { name: "Close" }));
    await waitFor(() => expect(screen.getByText("Exited preview")).toBeTruthy());
    expect(screen.queryByText("Discard unsaved local edits?")).toBeNull();
  });
});