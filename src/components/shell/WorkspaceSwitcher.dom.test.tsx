/** @vitest-environment jsdom */
import { afterEach, describe, expect, it, vi } from "vitest";
import { cleanup, render, screen } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { WorkspaceSwitcher } from "./WorkspaceSwitcher";
import { setWorkspaceDepartmentId } from "@/lib/workspace-context";

const mockAuth = vi.hoisted(() => ({
  role: "admin",
  permissions: ["*"],
  employeeStatus: "ACTIVE",
}));

vi.mock("@/hooks/useAuth", () => ({
  useAuth: () => ({
    role: mockAuth.role,
    permissions: mockAuth.permissions,
    employeeStatus: mockAuth.employeeStatus,
  }),
}));

const mockDepartments = [
  { id: "dept-sales", name: "Sales", code: "SAL", aliases: ["sales"] },
  { id: "dept-rnd", name: "Hardware & R&D", code: "RND", aliases: ["rnd", "hardware"] },
];

vi.mock("@/lib/tasks", async (importOriginal) => ({
  ...(await importOriginal<typeof import("@/lib/tasks")>()),
  fetchCanonicalDepartments: vi.fn().mockImplementation(async () => mockDepartments),
}));

function renderWithClient(ui: React.ReactElement) {
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(<QueryClientProvider client={queryClient}>{ui}</QueryClientProvider>);
}

describe("WorkspaceSwitcher", () => {
  afterEach(() => {
    cleanup();
    setWorkspaceDepartmentId(null);
  });

  it("renders a dropdown switcher for admin users", () => {
    mockAuth.role = "admin";
    renderWithClient(<WorkspaceSwitcher />);

    const switcherButton = screen.getByRole("button", { name: /Department workspace:/i });
    expect(switcherButton).toBeDefined();
  });

  it("renders a locked static indicator without dropdown for single-department non-admin users", async () => {
    mockAuth.role = "member";
    mockAuth.permissions = ["sales.view"];
    setWorkspaceDepartmentId("dept-sales");

    renderWithClient(<WorkspaceSwitcher />);

    // Should NOT have a dropdown button to switch workspaces
    expect(screen.queryByRole("button", { name: /Department workspace:/i })).toBeNull();

    // Should display the assigned workspace badge
    await vi.waitFor(() => {
      expect(screen.getByText("Sales")).toBeDefined();
    });
  });
});
