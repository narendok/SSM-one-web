/** @vitest-environment jsdom */

import { afterEach, describe, expect, it, vi } from "vitest";
import { cleanup, render, screen, fireEvent } from "@testing-library/react";
import { DepartmentTestAccounts } from "./DepartmentTestAccounts";
import { DEPARTMENT_TEST_ACCOUNTS } from "@/lib/demo-auth";

afterEach(() => {
  cleanup();
});

describe("DepartmentTestAccounts", () => {
  it("renders all department profiles and handles category filtering", () => {
    const handleFill = vi.fn();
    const handleLogin = vi.fn();

    render(
      <DepartmentTestAccounts
        onFillCredentials={handleFill}
        onInstantLogin={handleLogin}
      />
    );

    expect(screen.getByText("Department Test Logins")).toBeTruthy();
    expect(screen.getByText(`${DEPARTMENT_TEST_ACCOUNTS.length} Profiles Ready`)).toBeTruthy();

    // Check that Hardware and Mechanical appear
    expect(screen.getByText("Dr. Rajesh Sharma (Hardware & R&D Lead)")).toBeTruthy();
    expect(screen.getByText("Arun Kulkarni (Lead Mechanical Engineer)")).toBeTruthy();

    // Filter to Management
    const mgmtBtn = screen.getByRole("button", { name: /^Management/ });
    fireEvent.click(mgmtBtn);

    expect(screen.getByText("Vikram Malhotra (Executive Director)")).toBeTruthy();
    expect(screen.queryByText("Dr. Rajesh Sharma (Hardware & R&D Lead)")).toBeNull();
  });

  it("triggers onFillCredentials when Fill Form is clicked", () => {
    const handleFill = vi.fn();
    const handleLogin = vi.fn();

    render(
      <DepartmentTestAccounts
        onFillCredentials={handleFill}
        onInstantLogin={handleLogin}
      />
    );

    const fillButtons = screen.getAllByRole("button", { name: /Fill Form/i });
    fireEvent.click(fillButtons[0]);

    expect(handleFill).toHaveBeenCalledTimes(1);
    expect(handleFill).toHaveBeenCalledWith(DEPARTMENT_TEST_ACCOUNTS[0]);
  });

  it("triggers onInstantLogin when One-Click Sign In is clicked", () => {
    const handleFill = vi.fn();
    const handleLogin = vi.fn();

    render(
      <DepartmentTestAccounts
        onFillCredentials={handleFill}
        onInstantLogin={handleLogin}
      />
    );

    const loginButtons = screen.getAllByRole("button", { name: /One-Click Sign In/i });
    fireEvent.click(loginButtons[0]);

    expect(handleLogin).toHaveBeenCalledTimes(1);
    expect(handleLogin).toHaveBeenCalledWith(DEPARTMENT_TEST_ACCOUNTS[0]);
  });
});
