/** @vitest-environment jsdom */

import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { cleanup, render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";
import { DriveBrowser } from "./DriveBrowser";

const fetchChildren = vi.fn();

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

function renderBrowser(setup: () => void) {
  setup();
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(<QueryClientProvider client={client}><DriveBrowser projectId="project-123" /></QueryClientProvider>);
}

afterEach(() => {
  cleanup();
  fetchChildren.mockReset();
});

describe("DriveBrowser project reads", () => {
  it("settles a failed project-files read without showing an empty folder", async () => {
    renderBrowser(() => fetchChildren.mockRejectedValue(new Error("Read unavailable")));

    expect(await screen.findByRole("alert")).toHaveTextContent("Project files could not be loaded. Read unavailable");
    expect(screen.queryByText("No accessible items are stored in this folder.")).toBeNull();
  });

  it("retries a failed project-files read and then shows the accessible empty state", async () => {
    const user = userEvent.setup();
    renderBrowser(() => fetchChildren.mockRejectedValueOnce(new Error("Read unavailable")).mockResolvedValueOnce([]));

    await user.click(await screen.findByRole("button", { name: "Retry" }));

    expect(await screen.findByText("No accessible items are stored in this folder.")).toBeTruthy();
    expect(screen.queryByRole("alert")).toBeNull();
  });
});