/** @vitest-environment jsdom */

import { afterEach, describe, expect, it, vi } from "vitest";
import { cleanup, render, screen } from "@testing-library/react";
import { WorkspaceSwitcher } from "./WorkspaceSwitcher";
import { CANONICAL_DEPT_UUIDS } from "@/lib/canonical-departments";

let mockAuth: {
  role: string;
  permissions: string[];
  employeeStatus: string;
} = {
  role: "member",
  permissions: ["engineering.view"],
  employeeStatus: "active",
};

vi.mock("@/hooks/useAuth", () => ({
  useAuth: () => mockAuth,
}));

const mockDepartments = [
  {
    id: CANONICAL_DEPT_UUIDS.MECHANICAL,
    name: "Mechanical Engineering",
    code: "MECH",
    aliases: ["mech", "mechanical", "cad"],
    is_active: true,
  },
  {
    id: CANONICAL_DEPT_UUIDS.RND,
    name: "Hardware & R&D",
    code: "RND",
    aliases: ["rnd", "hardware"],
    is_active: true,
  },
  {
    id: CANONICAL_DEPT_UUIDS.OPERATIONS,
    name: "Operations & QMS",
    code: "OPS",
    aliases: ["ops", "operations"],
    is_active: true,
  },
];

vi.mock("@tanstack/react-query", () => ({
  useQuery: () => ({
    data: mockDepartments,
    isLoading: false,
  }),
}));

afterEach(() => {
  cleanup();
  window.localStorage.clear();
});

describe("WorkspaceSwitcher", () => {
  it("renders a locked badge for non-admin users with their assigned department", () => {
    mockAuth = {
      role: "member",
      permissions: ["engineering.view"],
      employeeStatus: "active",
    };
    window.localStorage.setItem("ssm-one-workspace-department-id", CANONICAL_DEPT_UUIDS.MECHANICAL);

    render(<WorkspaceSwitcher />);

    const lockedBadge = screen.getByTestId("workspace-locked-badge");
    expect(lockedBadge).toBeTruthy();
    expect(lockedBadge.textContent).toContain("Mechanical Engineering");

    // Interactive dropdown trigger should NOT be present
    expect(screen.queryByTestId("workspace-switcher-trigger")).toBeNull();
  });

  it("renders interactive switcher for admin users", () => {
    mockAuth = {
      role: "admin",
      permissions: ["admin.view", "engineering.view"],
      employeeStatus: "active",
    };
    window.localStorage.removeItem("ssm-one-workspace-department-id");

    render(<WorkspaceSwitcher />);

    // Admin should see the interactive trigger button
    const triggerBtn = screen.getByTestId("workspace-switcher-trigger");
    expect(triggerBtn).toBeTruthy();
    expect(triggerBtn.textContent).toContain("All workspaces");

    // Locked badge should NOT be present
    expect(screen.queryByTestId("workspace-locked-badge")).toBeNull();
  });
});
