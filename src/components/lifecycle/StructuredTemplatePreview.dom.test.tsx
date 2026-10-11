/** @vitest-environment jsdom */

import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { cleanup, fireEvent, render, screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";
import { useState, type ReactNode } from "react";
import {
  downloadVerifiedStructuredSalesDraft,
  persistedStructuredSalesDraftFields,
  StructuredTemplatePreview,
} from "./StructuredTemplatePreview";
import { StructuredPreviewExitDialog } from "./StructuredPreviewExitBoundary";
import { mapMasterSpecificationSource } from "@/lib/lifecycle-structured-template-previews";
import { MASTER_SPECIFICATION_TBC } from "@/lib/master-specification";
import { DialogDescription, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { supabase } from "@/integrations/supabase/client";
import { ProposalDetail } from "@/routes/_authenticated/sales";

const source = mapMasterSpecificationSource({
  opportunityId: "opportunity-id",
  opportunityNumber: "OPPORTUNITY-2026-0013",
  opportunityName: "Tracker",
  customerId: "customer-id",
  customerName: "SAMPLE ONLY",
  specificationId: "specification-id",
  specificationNumber: "MASTER-2026-0001",
  versionId: "version-id",
  versionNumber: 1,
  currentVersionNumber: 1,
  changeSummary: "Initial intake",
  savedAt: "2026-10-05T18:37:27.589Z",
  project: null,
  specificationData: {},
});
const previewSource = vi.fn();
const discoverStructuredSalesDraftCapabilityMock = vi.fn().mockResolvedValue(null);
const { fetchProjectBomsMock, fetchProjectBomItemsMock } = vi.hoisted(() => ({
  fetchProjectBomsMock: vi.fn(),
  fetchProjectBomItemsMock: vi.fn(),
}));

vi.mock("@/lib/lifecycle-structured-template-previews.functions", () => ({
  fetchStructuredTemplatePreviewSource: (input: unknown) => previewSource(input),
}));

vi.mock("@/lib/structured-sales-draft.functions", () => ({
  discoverStructuredSalesDraftCapability: (input: unknown) => discoverStructuredSalesDraftCapabilityMock(input),
}));

vi.mock("@/integrations/supabase/client", () => ({
  supabase: { from: vi.fn(), rpc: vi.fn(), storage: { from: vi.fn() } },
}));

vi.mock("@/lib/project-bom.functions", async (importOriginal) => {
  const actual = await importOriginal<typeof import("@/lib/project-bom.functions")>();
  return {
    ...actual,
    fetchProjectBoms: fetchProjectBomsMock,
    fetchProjectBomItems: fetchProjectBomItemsMock,
  };
});

vi.mock("@tanstack/react-router", () => ({
  createFileRoute: () => (options: unknown) => options,
  Link: ({ children }: { children: ReactNode }) => <a href="/bom">{children}</a>,
}));

vi.mock("@tanstack/react-start", async () => {
  const actual =
    await vi.importActual<typeof import("@tanstack/react-start")>("@tanstack/react-start");
  return { ...actual, useServerFn: (serverFn: (...args: never[]) => unknown) => serverFn };
});

function renderPreview() {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={client}>
      <StructuredTemplatePreview actorId="actor-a" />
    </QueryClientProvider>,
  );
}

function ProductionExitDialogHarness() {
  const [open, setOpen] = useState(true);
  const [dirty, setDirty] = useState(false);
  return (
    <>
      <button onClick={() => setOpen(true)}>Reopen preview</button>
      {open ? (
        <StructuredPreviewExitDialog open={open} onOpenChange={setOpen} dirty={dirty}>
          {(requestExit) => (
            <>
              <DialogHeader>
                <DialogTitle>Production proposal preview</DialogTitle>
                <DialogDescription>Mounted production exit coverage.</DialogDescription>
              </DialogHeader>
              <button onClick={() => requestExit(() => setOpen(false))}>Back to opportunity</button>
              <StructuredTemplatePreview actorId="actor-a" onDirtyChange={setDirty} />
            </>
          )}
        </StructuredPreviewExitDialog>
      ) : (
        <p>Exited preview</p>
      )}
    </>
  );
}

function ReturnToProposalHarness() {
  const [documentsOpen, setDocumentsOpen] = useState(true);
  const [localEdits, setLocalEdits] = useState<Record<string, string>>({});
  return (
    <>
      <button onClick={() => setDocumentsOpen(true)}>Open previews</button>
      {documentsOpen ? (
        <>
          <button onClick={() => setDocumentsOpen(false)}>Back to proposal</button>
          <StructuredTemplatePreview
            actorId="actor-a"
            localEdits={localEdits}
            onLocalEditsChange={setLocalEdits}
          />
        </>
      ) : (
        <p>Proposal overview</p>
      )}
    </>
  );
}

function ScopedReturnToProposalHarness() {
  const [documentsOpen, setDocumentsOpen] = useState(true);
  const [activeSource, setActiveSource] = useState("first");
  const [localEdits, setLocalEdits] = useState<Record<string, string>>({});
  const sourcePin =
    activeSource === "first"
      ? {
          opportunityNumber: "OPPORTUNITY-2026-0013",
          specificationNumber: "MASTER-2026-0001",
          versionNumber: 1,
        }
      : {
          opportunityNumber: "OPPORTUNITY-2026-0099",
          specificationNumber: "MASTER-2026-0099",
          versionNumber: 2,
        };
  return (
    <>
      <button
        onClick={() => {
          setLocalEdits({});
          setActiveSource("second");
          setDocumentsOpen(true);
        }}
      >
        Open other proposal
      </button>
      {documentsOpen ? (
        <>
          <button onClick={() => setDocumentsOpen(false)}>Back to proposal</button>
          <StructuredTemplatePreview
            actorId="actor-a"
            sourcePin={sourcePin}
            localEdits={localEdits}
            onLocalEditsChange={setLocalEdits}
          />
        </>
      ) : (
        <p>Proposal overview</p>
      )}
    </>
  );
}

function ActorScopeHarness() {
  const [actorId, setActorId] = useState<string | null>("actor-a");
  const [localEdits, setLocalEdits] = useState<Record<string, string>>({});
  return (
    <>
      <button onClick={() => setActorId("actor-b")}>Switch actor</button>
      <button onClick={() => setActorId(null)}>Sign out</button>
      <StructuredTemplatePreview
        actorId={actorId}
        localEdits={localEdits}
        onLocalEditsChange={setLocalEdits}
      />
    </>
  );
}

function DeferredActorSourceHarness() {
  const [actorId, setActorId] = useState("actor-a");
  return (
    <>
      <button onClick={() => setActorId("actor-b")}>Switch actor</button>
      <StructuredTemplatePreview actorId={actorId} />
    </>
  );
}

function ProposalDetailDialogHarness() {
  const [open, setOpen] = useState(true);
  const detail = {
    opportunity: {
      id: "opportunity-id",
      opportunity_number: "OPPORTUNITY-2026-0013",
    },
    specification: {
      id: "specification-id",
      specification_number: "MASTER-2026-0001",
      current_version: 1,
      customer_id: "customer-id",
    },
  } as never;
  return (
    <>
      <button onClick={() => setOpen(true)}>Reopen proposal</button>
      <ProposalDetail
        detail={open ? detail : null}
        requirements={[]}
        onOpenChange={setOpen}
        actorId="actor-a"
      />
    </>
  );
}

const proposalSpecificationData = {
  proposedName: "Synthetic Tracker",
  customerOrInternalOwner: "Synthetic OEM",
  industryApplication: "Fleet monitoring",
  productFamily: "Vehicle tracker",
  developmentScope: "Hardware proof of concept",
  workstreams: ["HARDWARE", "TEST"],
  requirementSummary: "Synthetic intake only.",
  powerAndUnits: MASTER_SPECIFICATION_TBC,
  interfaces: MASTER_SPECIFICATION_TBC,
  connectivityAndGnss: "GNSS",
  environmentAndIp: MASTER_SPECIFICATION_TBC,
  volumes: MASTER_SPECIFICATION_TBC,
  schedule: MASTER_SPECIFICATION_TBC,
  requestedStandards: MASTER_SPECIFICATION_TBC,
  exclusions: MASTER_SPECIFICATION_TBC,
};

afterEach(() => {
  cleanup();
  previewSource.mockReset();
  discoverStructuredSalesDraftCapabilityMock.mockReset().mockResolvedValue(null);
  vi.mocked(supabase.from).mockReset();
  vi.mocked(supabase.rpc).mockReset();
  vi.mocked(supabase.storage.from).mockReset();
  fetchProjectBomsMock.mockReset().mockResolvedValue([]);
  fetchProjectBomItemsMock.mockReset().mockResolvedValue(null);
});

describe("StructuredTemplatePreview mounted local interactions", () => {
  it("hydrates the flat persisted server payload only for its already kind-bound draft provenance", () => {
    expect(
      persistedStructuredSalesDraftFields("SOR", {
        OEM_REQUIREMENT_ROWS: "TBC",
        SCOPE_STATEMENT: "TBC",
        ACCEPTANCE_CRITERIA: "TBC",
        CAN_TELEMETRY_NOTES: "TBC",
        PILOT_ROLLOUT_NOTES: "TBC",
        COMMERCIAL_SLA_WARRANTY_DELIVERY: "TBC",
      }),
    ).toEqual({
      OEM_REQUIREMENT_ROWS: "TBC",
      SCOPE_STATEMENT: "TBC",
      ACCEPTANCE_CRITERIA: "TBC",
      CAN_TELEMETRY_NOTES: "TBC",
      PILOT_ROLLOUT_NOTES: "TBC",
      COMMERCIAL_SLA_WARRANTY_DELIVERY: "TBC",
    });
    expect(persistedStructuredSalesDraftFields("SOR", { POWER_REQUIREMENT: "12V" })).toBeNull();
    expect(persistedStructuredSalesDraftFields("SOR", { PROJECT_CODE: "derived" })).toBeNull();
    expect(persistedStructuredSalesDraftFields("SOR", { SCOPE_STATEMENT: 42 })).toBeNull();
  });

  it("downloads a verified blob only when it arrives before the timeout and matches the stored checksum", async () => {
    const contents = "verified draft";
    const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(contents));
    const checksum = Array.from(new Uint8Array(digest)).map((value) => value.toString(16).padStart(2, "0")).join("");
    await expect(
      downloadVerifiedStructuredSalesDraft(
        () => Promise.resolve({ data: new Blob([contents]), error: null }),
        checksum,
      ),
    ).resolves.toBeInstanceOf(Blob);
    await expect(
      downloadVerifiedStructuredSalesDraft(
        () => Promise.resolve({ data: new Blob(["tampered"]), error: null }),
        checksum,
      ),
    ).rejects.toThrow("did not match its verified checksum");
    await expect(
      downloadVerifiedStructuredSalesDraft(
        () => Promise.resolve({ data: null, error: { message: "denied" } }),
        checksum,
      ),
    ).rejects.toThrow("denied");
    await expect(
      downloadVerifiedStructuredSalesDraft(
        () => new Promise(() => undefined),
        checksum,
        1,
      ),
    ).rejects.toThrow("timed out");
  });

  it("isolates authorized source and local edits when the mounted actor changes or signs out", async () => {
    previewSource.mockResolvedValue(source);
    const user = userEvent.setup();
    const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
    render(
      <QueryClientProvider client={client}>
        <ActorScopeHarness />
      </QueryClientProvider>,
    );

    const scope = await screen.findByLabelText("Scope statement");
    await user.clear(scope);
    await user.type(scope, "Actor A only");
    expect((scope as HTMLTextAreaElement).value).toBe("Actor A only");
    await user.click(screen.getByRole("button", { name: "Switch actor" }));
    await waitFor(() => expect(previewSource).toHaveBeenCalledTimes(2));
    expect((screen.getByLabelText("Scope statement") as HTMLTextAreaElement).value).not.toBe(
      "Actor A only",
    );
    expect(
      client.getQueryData([
        "structured-template-source",
        "actor-a",
        "OPPORTUNITY-2026-0013",
        "MASTER-2026-0001",
        1,
      ]),
    ).toBeTruthy();
    expect(
      client.getQueryData([
        "structured-template-source",
        "actor-b",
        "OPPORTUNITY-2026-0013",
        "MASTER-2026-0001",
        1,
      ]),
    ).toBeTruthy();

    await user.click(screen.getByRole("button", { name: "Sign out" }));
    expect(await screen.findByText("UNVERIFIED — signed-in identity unavailable")).toBeTruthy();
    expect((screen.getByLabelText("Scope statement") as HTMLTextAreaElement).value).not.toBe(
      "Actor A only",
    );
    expect(previewSource).toHaveBeenCalledTimes(2);
  });

  it("does not render a late response from the previous actor scope", async () => {
    let resolveActorA: (value: typeof source) => void = () => undefined;
    previewSource
      .mockImplementationOnce(
        () =>
          new Promise<typeof source>((resolve) => {
            resolveActorA = resolve;
          }),
      )
      .mockResolvedValueOnce({ ...source, versionId: "actor-b-version" });
    const user = userEvent.setup();
    render(
      <QueryClientProvider
        client={new QueryClient({ defaultOptions: { queries: { retry: false } } })}
      >
        <DeferredActorSourceHarness />
      </QueryClientProvider>,
    );

    expect(await screen.findByText("LOADING — authorized source request in progress")).toBeTruthy();
    await user.click(screen.getByRole("button", { name: "Switch actor" }));
    expect(await screen.findByText("actor-b-version")).toBeTruthy();
    resolveActorA({ ...source, versionId: "actor-a-late-version" });
    await waitFor(() => expect(screen.queryByText("actor-a-late-version")).toBeNull());
    expect(screen.getByText("actor-b-version")).toBeTruthy();
  });
  it("retains exact SOR local text across Contract Review and PRS before returning to SOR", async () => {
    previewSource.mockResolvedValue(source);
    const user = userEvent.setup();
    renderPreview();
    const scope = await screen.findByLabelText("Scope statement");
    const exact = '  Exact local <img src=x onerror="alert(1)">\nkept.  ';
    await user.clear(scope);
    await user.type(scope, exact);
    expect(
      (screen.getByRole("button", { name: "Refresh source" }) as HTMLButtonElement).disabled,
    ).toBe(false);
    await user.click(screen.getByRole("tab", { name: "Contract Review" }));
    await user.click(screen.getByRole("tab", { name: "Product Requirements Specification" }));
    await user.click(screen.getByRole("tab", { name: "Statement of Requirements" }));
    expect((screen.getByLabelText("Scope statement") as HTMLTextAreaElement).value).toBe(exact);
    const frame = screen.getByTitle("Statement of Requirements local unsaved preview");
    expect(frame.getAttribute("sandbox")).toBe("");
    expect(frame.hasAttribute("allow-scripts")).toBe(false);
    expect(frame.getAttribute("srcdoc")).toContain(
      "&lt;img src=x onerror=&quot;alert(1)&quot;&gt;",
    );
    expect(frame.getAttribute("srcdoc")).not.toContain("<img");
  });

  it("preserves SOR, Contract Review, and PRS edits when the authorized source resolves after editing starts", async () => {
    let resolveSource: (value: typeof source) => void = () => undefined;
    previewSource.mockImplementation(
      () =>
        new Promise<typeof source>((resolve) => {
          resolveSource = resolve;
        }),
    );
    const user = userEvent.setup();
    renderPreview();

    expect(await screen.findByText("LOADING — authorized source request in progress")).toBeTruthy();
    const scope = screen.getByLabelText("Scope statement");
    await user.clear(scope);
    await user.type(scope, "Keep late SOR edit.");
    await user.click(screen.getByRole("tab", { name: "Contract Review" }));
    const decision = screen.getByLabelText("Local decision note");
    await user.clear(decision);
    await user.type(decision, "Keep late Contract Review edit.");
    await user.click(screen.getByRole("tab", { name: "Product Requirements Specification" }));
    const power = screen.getByLabelText("Power requirement");
    await user.clear(power);
    await user.type(power, "Keep late PRS edit.");

    resolveSource(source);
    expect(await screen.findByText("version-id")).toBeTruthy();
    await user.click(screen.getByRole("tab", { name: "Statement of Requirements" }));
    expect((screen.getByLabelText("Scope statement") as HTMLTextAreaElement).value).toBe(
      "Keep late SOR edit.",
    );
    await user.click(screen.getByRole("tab", { name: "Contract Review" }));
    expect((screen.getByLabelText("Local decision note") as HTMLTextAreaElement).value).toBe(
      "Keep late Contract Review edit.",
    );
    await user.click(screen.getByRole("tab", { name: "Product Requirements Specification" }));
    expect((screen.getByLabelText("Power requirement") as HTMLInputElement).value).toBe(
      "Keep late PRS edit.",
    );
  });

  it("keeps SOR, Contract Review, and PRS local edits after returning to the proposal overview", async () => {
    previewSource.mockResolvedValue(source);
    const user = userEvent.setup();
    render(
      <QueryClientProvider
        client={new QueryClient({ defaultOptions: { queries: { retry: false } } })}
      >
        <ReturnToProposalHarness />
      </QueryClientProvider>,
    );

    const scope = await screen.findByLabelText("Scope statement");
    await user.clear(scope);
    await user.type(scope, "Keep SOR while returning.");
    await user.click(screen.getByRole("tab", { name: "Contract Review" }));
    const note = screen.getByLabelText("Local decision note");
    await user.clear(note);
    await user.type(note, "Keep review while returning.");
    await user.click(screen.getByRole("tab", { name: "Product Requirements Specification" }));
    const power = screen.getByLabelText("Power requirement");
    await user.clear(power);
    await user.type(power, "Keep PRS while returning.");

    await user.click(screen.getByRole("button", { name: "Back to proposal" }));
    expect(screen.getByText("Proposal overview")).toBeTruthy();
    await user.click(screen.getByRole("button", { name: "Open previews" }));
    await user.click(screen.getByRole("tab", { name: "Statement of Requirements" }));
    expect((screen.getByLabelText("Scope statement") as HTMLTextAreaElement).value).toBe(
      "Keep SOR while returning.",
    );
    await user.click(screen.getByRole("tab", { name: "Contract Review" }));
    expect((screen.getByLabelText("Local decision note") as HTMLTextAreaElement).value).toBe(
      "Keep review while returning.",
    );
    await user.click(screen.getByRole("tab", { name: "Product Requirements Specification" }));
    expect((screen.getByLabelText("Power requirement") as HTMLInputElement).value).toBe(
      "Keep PRS while returning.",
    );
  });

  it("clears local edits before opening a different opportunity and pinned revision", async () => {
    previewSource.mockResolvedValue(source);
    const user = userEvent.setup();
    render(
      <QueryClientProvider
        client={new QueryClient({ defaultOptions: { queries: { retry: false } } })}
      >
        <ScopedReturnToProposalHarness />
      </QueryClientProvider>,
    );

    const scope = await screen.findByLabelText("Scope statement");
    await user.clear(scope);
    await user.type(scope, "Only the first proposal may show this.");
    await user.click(screen.getByRole("button", { name: "Back to proposal" }));
    await user.click(screen.getByRole("button", { name: "Open other proposal" }));
    expect(((await screen.findByLabelText("Scope statement")) as HTMLTextAreaElement).value).toBe(
      "TBC",
    );
  });

  it("renders the exact successful authorized source pin instead of TBC fallback fields", async () => {
    previewSource.mockResolvedValue(source);
    renderPreview();
    expect(await screen.findByText("Pinned authorized source")).toBeTruthy();
    expect(screen.getByText("version-id")).toBeTruthy();
    expect(screen.getByText("Tracker")).toBeTruthy();
    expect(screen.queryByText("LOADING — authorized source request in progress")).toBeNull();
  });

  it.each(["denied by mock", "requested source not found"])(
    "terminates an authorized source failure as explicit unverified state: %s",
    async (message) => {
      previewSource.mockRejectedValue(new Error(message));
      renderPreview();
      expect(await screen.findByText("UNVERIFIED — authorized source unavailable")).toBeTruthy();
      expect(
        await screen.findByText(`Authorized source could not be loaded: ${message}`),
      ).toBeTruthy();
      expect(screen.queryByText("Loading authorized source…")).toBeNull();
      expect(screen.queryByText("Pinned authorized source")).toBeNull();
    },
  );

  it("terminates an invalid empty authorized source response without fabricated source fields", async () => {
    previewSource.mockResolvedValue(undefined);
    renderPreview();
    expect(await screen.findByText("UNVERIFIED — authorized source unavailable")).toBeTruthy();
    expect(await screen.findByText(/data is undefined/)).toBeTruthy();
    expect(screen.queryByText("Loading authorized source…")).toBeNull();
    expect(screen.queryByText("Pinned authorized source")).toBeNull();
  });

  it("reports a newer authorized revision after a clean refresh while retaining the pinned historical content", async () => {
    previewSource.mockResolvedValueOnce(source).mockResolvedValueOnce({
      ...source,
      currentVersionNumber: 2,
    });
    const user = userEvent.setup();
    renderPreview();
    await screen.findByText("version-id");
    await user.click(screen.getByRole("button", { name: "Refresh source" }));
    expect(await screen.findByText(/A newer Master Specification revision \(2\) is available/)).toBeTruthy();
    expect(screen.getByText("version-id")).toBeTruthy();
    expect(screen.getAllByText(/MASTER-2026-0001 rev 1/).length).toBeGreaterThan(0);
  });

  it("refreshes a dirty preview for newer-revision provenance without replacing manual text", async () => {
    previewSource.mockResolvedValueOnce(source).mockResolvedValueOnce({
      ...source,
      currentVersionNumber: 2,
    });
    const user = userEvent.setup();
    renderPreview();
    const scope = screen.getByLabelText("Scope statement");
    await user.clear(scope);
    await user.type(scope, "Keep this exact text after the clean amendment.");
    expect((screen.getByRole("button", { name: "Refresh source" }) as HTMLButtonElement).disabled).toBe(false);
    await user.click(screen.getByRole("button", { name: "Refresh source" }));
    expect(await screen.findByText(/A newer Master Specification revision \(2\) is available/)).toBeTruthy();
    expect((screen.getByLabelText("Scope statement") as HTMLTextAreaElement).value).toBe(
      "Keep this exact text after the clean amendment.",
    );
    expect(screen.getByText("version-id")).toBeTruthy();
  });

  it.each([1, null])(
    "does not report a newer revision when the authorized marker is %s",
    async (currentVersionNumber) => {
      previewSource.mockResolvedValue({ ...source, currentVersionNumber });
      renderPreview();
      await screen.findByText("version-id");
      expect(screen.queryByText(/A newer Master Specification revision/)).toBeNull();
    },
  );

  it("does not render a late newer-revision marker from the previous actor", async () => {
    let resolveActorA: (value: typeof source) => void = () => undefined;
    previewSource
      .mockImplementationOnce(
        () => new Promise<typeof source>((resolve) => { resolveActorA = resolve; }),
      )
      .mockResolvedValueOnce({ ...source, versionId: "actor-b-version", currentVersionNumber: 1 });
    const user = userEvent.setup();
    render(
      <QueryClientProvider client={new QueryClient({ defaultOptions: { queries: { retry: false } } })}>
        <DeferredActorSourceHarness />
      </QueryClientProvider>,
    );
    await user.click(screen.getByRole("button", { name: "Switch actor" }));
    await screen.findByText("actor-b-version");
    resolveActorA({ ...source, currentVersionNumber: 2 });
    await waitFor(() => expect(screen.queryByText(/revision \(2\) is available/)).toBeNull());
  });

  it("does not request project BOMs for the unprojected source while local scratch rows are edited and selected", async () => {
    previewSource.mockResolvedValue(source);
    const select = vi.fn().mockResolvedValue({
      data: [
        {
          id: "component-1",
          name: "Catalogue description",
          part_number: "CAT-001",
          manufacturer: "Catalogue maker",
        },
      ],
      error: null,
    });
    vi.mocked(supabase.from).mockReturnValue({
      select: () => ({ or: () => ({ limit: select }) }),
    } as never);
    const user = userEvent.setup();
    const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
    render(
      <QueryClientProvider client={client}>
        <StructuredTemplatePreview actorId="actor-a" />
      </QueryClientProvider>,
    );
    await screen.findByLabelText("Scope statement");
    await screen.findByText("version-id");
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
    await user.type(
      screen.getByLabelText(
        "Search caller-visible components for Optional local scratch rows row 1",
      ),
      "ca",
    );
    await screen.findByRole("option", { name: /Catalogue description/ });
    await user.click(screen.getByRole("option", { name: /Catalogue description/ }));
    expect((mpn as HTMLInputElement).value).toBe("Manual MPN");
    expect((manufacturer as HTMLInputElement).value).toBe("Catalogue maker");
    expect((description as HTMLInputElement).value).toBe("Catalogue description");
    expect((quantity as HTMLInputElement).value).toBe("7");
    expect((packageField as HTMLInputElement).value).toBe("Manual package");
    expect(
      screen.getByText(/all nonempty manual values and every other field stay unchanged/),
    ).toBeTruthy();
    expect(fetchProjectBomsMock).not.toHaveBeenCalled();
    expect(fetchProjectBomItemsMock).not.toHaveBeenCalled();
  });

  it("adopts only empty BOM component fields and retains local edits through reselection, switching, and source conflict", async () => {
    previewSource.mockResolvedValue(source);
    const select = vi.fn().mockResolvedValue({
      data: [
        {
          id: "component-1",
          name: "Catalogue description",
          part_number: "CAT-001",
          manufacturer: "Catalogue maker",
        },
      ],
      error: null,
    });
    vi.mocked(supabase.from).mockReturnValue({
      select: () => ({ or: () => ({ limit: select }) }),
    } as never);
    const user = userEvent.setup();
    const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
    render(
      <QueryClientProvider client={client}>
        <StructuredTemplatePreview
          actorId="actor-a"
          project={{ id: "project-id", name: "Test project", code: "TEST" }}
        />
      </QueryClientProvider>,
    );
    await screen.findByLabelText("Scope statement");
    await user.click(screen.getByRole("tab", { name: "BOM review" }));
    await user.click(screen.getByRole("button", { name: "Add Optional local scratch rows row" }));
    const mpn = screen.getByLabelText("Optional local scratch rows row 1 MPN");
    const manufacturer = screen.getByLabelText("Optional local scratch rows row 1 Manufacturer");
    const description = screen.getByLabelText("Optional local scratch rows row 1 Description");
    await user.type(mpn, "Manual MPN");
    await user.type(
      screen.getByLabelText(
        "Search caller-visible components for Optional local scratch rows row 1",
      ),
      "ca",
    );
    await user.click(await screen.findByRole("option", { name: /Catalogue description/ }));
    const secondSelect = vi.fn().mockResolvedValue({
      data: [
        {
          id: "component-2",
          name: "Replacement description",
          part_number: "CAT-002",
          manufacturer: "Replacement maker",
        },
      ],
      error: null,
    });
    vi.mocked(supabase.from).mockReturnValue({
      select: () => ({ or: () => ({ limit: secondSelect }) }),
    } as never);
    await user.type(
      screen.getByLabelText(
        "Search caller-visible components for Optional local scratch rows row 1",
      ),
      "re",
    );
    await screen.findByRole("option", { name: /Replacement description/ });
    await user.click(screen.getByRole("option", { name: /Replacement description/ }));
    expect((mpn as HTMLInputElement).value).toBe("Manual MPN");
    expect((manufacturer as HTMLInputElement).value).toBe("Catalogue maker");
    expect((description as HTMLInputElement).value).toBe("Catalogue description");

    await user.click(screen.getByRole("tab", { name: "Statement of Requirements" }));
    await user.click(screen.getByRole("tab", { name: "BOM review" }));
    expect(
      (screen.getByLabelText("Optional local scratch rows row 1 Description") as HTMLInputElement)
        .value,
    ).toBe("Catalogue description");
    client.setQueryData(
      ["structured-template-source", "actor-a", "OPPORTUNITY-2026-0013", "MASTER-2026-0001", 1],
      { ...source, currentVersionNumber: 2 },
    );
    await screen.findByText(/A newer Master Specification revision \(2\) is available/);
    expect(
      (screen.getByLabelText("Optional local scratch rows row 1 MPN") as HTMLInputElement).value,
    ).toBe("Manual MPN");
  });

  it("shows component search loading, empty, error, removes previous options during a new debounce, and ignores stale completions", async () => {
    previewSource.mockResolvedValue(source);
    let resolveNew: (value: {
      data: { id: string; name: string; part_number: string; manufacturer: string | null }[];
      error: null;
    }) => void = () => undefined;
    const newRequest = new Promise<{
      data: { id: string; name: string; part_number: string; manufacturer: string | null }[];
      error: null;
    }>((resolve) => {
      resolveNew = resolve;
    });
    const limit = vi.fn();
    const or = vi.fn((filter: string) => ({
      limit: () => {
        limit(filter);
        if (filter.includes("%ol%"))
          return Promise.resolve({
            data: [{ id: "old", name: "Old result", part_number: "OLD", manufacturer: null }],
            error: null,
          });
        if (filter.includes("%new%")) return newRequest;
        if (filter.includes("%re%"))
          return Promise.resolve({
            data: [{ id: "fresh", name: "Fresh result", part_number: "FRESH", manufacturer: null }],
            error: null,
          });
        return Promise.resolve({ data: null, error: new Error("read denied") });
      },
    }));
    vi.mocked(supabase.from).mockReturnValue({ select: () => ({ or }) } as never);
    const user = userEvent.setup();
    render(
      <QueryClientProvider
        client={new QueryClient({ defaultOptions: { queries: { retry: false } } })}
      >
        <StructuredTemplatePreview
          actorId="actor-a"
          project={{ id: "project-id", name: "Test project", code: "TEST" }}
        />
      </QueryClientProvider>,
    );
    await screen.findByLabelText("Scope statement");
    await user.click(screen.getByRole("tab", { name: "BOM review" }));
    await user.click(screen.getByRole("button", { name: "Add Optional local scratch rows row" }));
    const search = screen.getByLabelText(
      "Search caller-visible components for Optional local scratch rows row 1",
    );
    await user.type(search, "ol");
    expect(await screen.findByRole("option", { name: /Old result/ })).toBeTruthy();
    await user.clear(search);
    await user.type(search, "new");
    await waitFor(() =>
      expect(limit).toHaveBeenCalledWith("name.ilike.%new%,part_number.ilike.%new%"),
    );
    expect(screen.queryByRole("option", { name: /Old result/ })).toBeNull();
    expect(await screen.findByLabelText("Searching components")).toBeTruthy();
    await user.clear(search);
    await user.type(search, "re");
    expect(await screen.findByRole("option", { name: /Fresh result/ })).toBeTruthy();
    resolveNew({
      data: [{ id: "stale", name: "Stale result", part_number: "STALE", manufacturer: null }],
      error: null,
    });
    await waitFor(() => expect(screen.queryByRole("option", { name: /Stale result/ })).toBeNull());
    await user.clear(search);
    await user.type(search, "er");
    expect(
      await screen.findByText("Component search is unavailable. Your local row is unchanged."),
    ).toBeTruthy();
    expect(
      (screen.getByLabelText("Optional local scratch rows row 1 MPN") as HTMLInputElement).value,
    ).toBe("");
  });

  it("uses the production Radix dialog dismissal guard for Escape and outside interactions, retaining edits until discard", async () => {
    previewSource.mockResolvedValue(source);
    const user = userEvent.setup();
    const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
    render(
      <QueryClientProvider client={client}>
        <ProductionExitDialogHarness />
      </QueryClientProvider>,
    );
    const scope = await screen.findByLabelText("Scope statement");
    await user.clear(scope);
    await user.type(scope, "Keep this exact draft");
    await user.keyboard("{Escape}");
    const firstDialog = await screen
      .findByText("Discard unsaved local edits?")
      .then((title) => title.closest("[role=alertdialog]") as HTMLElement | null);
    if (!firstDialog) throw new Error("Discard confirmation did not open.");
    expect(within(firstDialog).getByText("Discard unsaved local edits?")).toBeTruthy();
    await user.click(within(firstDialog).getByRole("button", { name: "Keep editing" }));
    expect((screen.getByLabelText("Scope statement") as HTMLTextAreaElement).value).toBe(
      "Keep this exact draft",
    );
    fireEvent.pointerDown(document.body);
    fireEvent.click(document.body);
    expect(await screen.findByText("Discard unsaved local edits?")).toBeTruthy();
    await user.click(screen.getByRole("button", { name: "Discard edits" }));
    await waitFor(() => expect(screen.getByText("Exited preview")).toBeTruthy());
    await user.click(screen.getByRole("button", { name: "Reopen preview" }));
    expect(((await screen.findByLabelText("Scope statement")) as HTMLTextAreaElement).value).toBe(
      "TBC",
    );
    expect(
      (screen.getByRole("button", { name: "Refresh source" }) as HTMLButtonElement).disabled,
    ).toBe(false);
  });

  it("uses the production Back and built-in Close exits, keeping exact edits until an explicit discard", async () => {
    previewSource.mockResolvedValue(source);
    const user = userEvent.setup();
    const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
    render(
      <QueryClientProvider client={client}>
        <ProductionExitDialogHarness />
      </QueryClientProvider>,
    );
    const scope = await screen.findByLabelText("Scope statement");
    await user.clear(scope);
    await user.type(scope, "Keep this exact Back and Close draft");

    await user.click(screen.getByRole("button", { name: "Back to opportunity" }));
    await user.click(await screen.findByRole("button", { name: "Keep editing" }));
    expect((screen.getByLabelText("Scope statement") as HTMLTextAreaElement).value).toBe(
      "Keep this exact Back and Close draft",
    );

    await user.click(screen.getByRole("button", { name: "Close" }));
    const confirmation = await screen
      .findByText("Discard unsaved local edits?")
      .then((title) => title.closest("[role=alertdialog]") as HTMLElement | null);
    if (!confirmation)
      throw new Error("Discard confirmation did not open from the built-in Close button.");
    await user.click(within(confirmation).getByRole("button", { name: "Discard edits" }));
    await waitFor(() => expect(screen.getByText("Exited preview")).toBeTruthy());
  });

  it("keeps local preview text when the real proposal dialog returns from documents, while Close still prompts", async () => {
    previewSource.mockResolvedValue(source);
    vi.mocked(supabase.from).mockImplementation((table) => {
      if (table === "master_specification_versions") {
        return {
          select: () => ({
            eq: () => ({
              eq: () => ({
                single: () =>
                  Promise.resolve({
                    data: {
                      id: "version-id",
                      version_number: 1,
                      change_summary: "Initial intake",
                      created_at: "2026-10-05T18:37:27.589Z",
                      specification_data: proposalSpecificationData,
                    },
                    error: null,
                  }),
              }),
            }),
          }),
        } as never;
      }
      return {
        select: () => ({
          eq: () => ({
            eq: () => ({
              eq: () => ({
                eq: () => ({
                  eq: () => ({
                    maybeSingle: () =>
                      Promise.resolve({
                        data: {
                          id: "location-id",
                          opportunity_id: "opportunity-id",
                          customer_id: "customer-id",
                          department_id: "sales-department-id",
                          drive_root_node_id: "sales-root-id",
                          target_folder_node_id: "sales-folder-id",
                          status: "ACTIVE",
                          location_purpose: "STRUCTURED_DRAFT",
                        },
                        error: null,
                      }),
                  }),
                }),
              }),
            }),
          }),
        }),
      } as never;
    });
    vi.mocked(supabase.rpc).mockResolvedValue({
      data: [{ location_id: "location-id", storage_bucket: "private-sales", storage_path_prefix: "sales/" }],
      error: null,
    } as never);
    const user = userEvent.setup();
    const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
    render(
      <QueryClientProvider client={client}>
        <ProposalDetailDialogHarness />
      </QueryClientProvider>,
    );

    await user.click(await screen.findByRole("button", { name: "Open Sales documents" }));
    const scope = await screen.findByLabelText("Scope statement");
    await user.clear(scope);
    await user.type(scope, "Keep this proposal-local draft");

    await user.click(screen.getByRole("button", { name: "Back to proposal" }));
    expect(screen.queryByText("Discard unsaved local edits?")).toBeNull();
    expect(await screen.findByRole("button", { name: "Open Sales documents" })).toBeTruthy();

    await user.click(screen.getByRole("button", { name: "Open Sales documents" }));
    expect((await screen.findByLabelText("Scope statement") as HTMLTextAreaElement).value).toBe(
      "Keep this proposal-local draft",
    );

    await user.click(screen.getByRole("button", { name: "Close" }));
    expect(await screen.findByText("Discard unsaved local edits?")).toBeTruthy();
  });

  it("opens the exact discovered Sales folder only after binding it to the pinned active source", async () => {
    vi.mocked(supabase.from).mockImplementation((table) => {
      if (table === "master_specification_versions") {
        return {
          select: () => ({
            eq: () => ({
              eq: () => ({
                single: () =>
                  Promise.resolve({
                    data: {
                      id: "version-id",
                      version_number: 1,
                      change_summary: "Initial intake",
                      created_at: "2026-10-05T18:37:27.589Z",
                      specification_data: proposalSpecificationData,
                    },
                    error: null,
                  }),
              }),
            }),
          }),
        } as never;
      }
      return {
        select: () => ({
          eq: () => ({
            eq: () => ({
              eq: () => ({
                eq: () => ({
                  eq: () => ({
                    maybeSingle: () =>
                      Promise.resolve({
                        data: {
                          id: "location-id",
                          opportunity_id: "opportunity-id",
                          customer_id: "customer-id",
                          department_id: "sales-department-id",
                          drive_root_node_id: "sales-root-id",
                          target_folder_node_id: "sales-folder-id",
                          status: "ACTIVE",
                          location_purpose: "STRUCTURED_DRAFT",
                        },
                        error: null,
                      }),
                  }),
                }),
              }),
            }),
          }),
        }),
      } as never;
    });
    vi.mocked(supabase.rpc).mockResolvedValue({
      data: [{ location_id: "location-id", storage_bucket: "private-sales", storage_path_prefix: "sales/" }],
      error: null,
    } as never);
    const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
    render(
      <QueryClientProvider client={client}>
        <ProposalDetailDialogHarness />
      </QueryClientProvider>,
    );

    await waitFor(() => expect(supabase.rpc).toHaveBeenCalled());
    const folderLink = await screen.findByRole("link", { name: "Open Sales folder" });
    if (!folderLink) throw new Error("The discovered Sales folder entry was not rendered.");
    expect(folderLink.getAttribute("aria-disabled")).not.toBe("true");
    expect(supabase.rpc).toHaveBeenCalledWith("discover_sales_opportunity_structured_draft_location", {
      p_opportunity_id: "opportunity-id",
      p_customer_id: "customer-id",
      p_master_specification_id: "specification-id",
      p_master_specification_version_id: "version-id",
    });
  });

  it("fails closed when discovery does not return an active binding for the exact Sales source", async () => {
    vi.mocked(supabase.from).mockReturnValue({
      select: () => ({
        eq: () => ({
          eq: () => ({
            single: () =>
              Promise.resolve({
                data: {
                  id: "version-id",
                  version_number: 1,
                  change_summary: "Initial intake",
                  created_at: "2026-10-05T18:37:27.589Z",
                  specification_data: proposalSpecificationData,
                },
                error: null,
              }),
          }),
        }),
      }),
    } as never);
    vi.mocked(supabase.rpc).mockResolvedValue({ data: [], error: null } as never);
    const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
    render(
      <QueryClientProvider client={client}>
        <ProposalDetailDialogHarness />
      </QueryClientProvider>,
    );

    await waitFor(() => expect(supabase.rpc).toHaveBeenCalled());
    const folderLink = await screen.findByRole("link", { name: "Open Sales folder" });
    if (!folderLink) throw new Error("The unavailable Sales folder state was not rendered.");
    expect(folderLink.getAttribute("aria-disabled")).toBe("true");
    expect(folderLink.getAttribute("href")).toBeNull();
  });

  it("exits clean previews by Escape and built-in Close without confirmation, and reopens without stale dirty state", async () => {
    previewSource.mockResolvedValue(source);
    const user = userEvent.setup();
    const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
    render(
      <QueryClientProvider client={client}>
        <ProductionExitDialogHarness />
      </QueryClientProvider>,
    );

    await screen.findByLabelText("Scope statement");
    await user.keyboard("{Escape}");
    await waitFor(() => expect(screen.getByText("Exited preview")).toBeTruthy());
    expect(screen.queryByText("Discard unsaved local edits?")).toBeNull();

    await user.click(screen.getByRole("button", { name: "Reopen preview" }));
    expect(((await screen.findByLabelText("Scope statement")) as HTMLTextAreaElement).value).toBe(
      "TBC",
    );
    expect(
      (screen.getByRole("button", { name: "Refresh source" }) as HTMLButtonElement).disabled,
    ).toBe(false);
    await user.click(screen.getByRole("button", { name: "Close" }));
    await waitFor(() => expect(screen.getByText("Exited preview")).toBeTruthy());
    expect(screen.queryByText("Discard unsaved local edits?")).toBeNull();
  });
});
