/** @vitest-environment jsdom */

import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { cleanup, render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";
import { DriveBrowser } from "./DriveBrowser";

const fetchChildren = vi.fn();
const initialFolder = vi.fn();

vi.mock("@/integrations/supabase/client", () => ({
  supabase: {
    from: () => ({
      select: () => ({
        eq: () => ({
          maybeSingle: () => initialFolder(),
        }),
      }),
    }),
  },
}));

vi.mock("@/lib/drive", async () => {
  const actual = await vi.importActual<typeof import("@/lib/drive")>("@/lib/drive");
  return {
    ...actual,
    fetchChildren: (...args: unknown[]) => fetchChildren(...args),
    fetchCanonicalDepartments: vi.fn().mockResolvedValue([]),
  };
});
vi.mock("@/lib/tasks", async () => {
  const actual = await vi.importActual<typeof import("@/lib/tasks")>("@/lib/tasks");
  return { ...actual, fetchCanonicalDepartments: vi.fn().mockResolvedValue([]) };
});
vi.mock("@/hooks/useAuth", () => ({ useAuth: () => ({ role: "employee" }) }));
vi.mock("@tanstack/react-start", async () => {
  const actual = await vi.importActual<typeof import("@tanstack/react-start")>("@tanstack/react-start");
  return { ...actual, useServerFn: () => vi.fn() };
});
vi.mock("./FilePreviewDialog", () => ({ FilePreviewDialog: () => null }));
vi.mock("./RevisionsDialog", () => ({ RevisionsDialog: () => null }));
vi.mock("./ShareNodeDialog", () => ({ ShareNodeDialog: () => null }));

function renderBrowser(setup: () => void, initialNodeId?: string, restrictedFolderId?: string) {
  setup();
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(<QueryClientProvider client={client}><DriveBrowser projectId="project-123" initialNodeId={initialNodeId} restrictedFolderId={restrictedFolderId} /></QueryClientProvider>);
}

afterEach(() => {
  cleanup();
  fetchChildren.mockReset();
  initialFolder.mockReset();
});

describe("DriveBrowser project reads", () => {
  it("settles a failed project-files read without showing an empty folder", async () => {
    renderBrowser(() => fetchChildren.mockRejectedValue(new Error("Read unavailable")));

    expect((await screen.findByRole("alert")).textContent).toContain("Project files could not be loaded. Read unavailable");
    expect(screen.queryByText("No accessible items are stored in this folder.")).toBeNull();
  });

  it("retries a failed project-files read and then shows the accessible empty state", async () => {
    const user = userEvent.setup();
    renderBrowser(() => fetchChildren.mockRejectedValueOnce(new Error("Read unavailable")).mockResolvedValueOnce([]));

    await user.click(await screen.findByRole("button", { name: "Retry" }));

    expect(await screen.findByText("No accessible items are stored in this folder.")).toBeTruthy();
    expect(screen.queryByRole("alert")).toBeNull();
  });

  it("disables upload and folder creation for a loaded locked folder", async () => {
    initialFolder.mockResolvedValue({ data: { id: "locked-folder", node_type: "FOLDER", is_locked: true, department_id: null, project_id: "project-123" }, error: null });
    renderBrowser(() => fetchChildren.mockResolvedValue([]), "locked-folder");

    expect((await screen.findByRole("button", { name: "Folder" })).hasAttribute("disabled")).toBe(true);
    expect(screen.getByRole("button", { name: "Upload" }).hasAttribute("disabled")).toBe(true);
  });

  it("keeps a source-bound folder read-only after a reload", async () => {
    initialFolder.mockResolvedValue({ data: { id: "sales-folder", node_type: "FOLDER", is_locked: false, department_id: "sales-department", project_id: null }, error: null });
    renderBrowser(() => fetchChildren.mockResolvedValue([]), "sales-folder", "sales-folder");

    expect((await screen.findByRole("button", { name: "Folder" })).hasAttribute("disabled")).toBe(true);
    expect(screen.getByRole("button", { name: "Upload" }).hasAttribute("disabled")).toBe(true);
    expect(screen.getByRole("button", { name: "Project files" }).hasAttribute("disabled")).toBe(true);
  });

  it("keeps upload and folder creation available for a loaded unlocked folder", async () => {
    initialFolder.mockResolvedValue({ data: { id: "unlocked-folder", node_type: "FOLDER", is_locked: false, department_id: null, project_id: "project-123" }, error: null });
    renderBrowser(() => fetchChildren.mockResolvedValue([]), "unlocked-folder");

    const folderButton = await screen.findByRole("button", { name: "Folder" });
    const uploadButton = screen.getByRole("button", { name: "Upload" });
    await vi.waitFor(() => {
      expect(folderButton.hasAttribute("disabled")).toBe(false);
      expect(uploadButton.hasAttribute("disabled")).toBe(false);
    });
  });
});