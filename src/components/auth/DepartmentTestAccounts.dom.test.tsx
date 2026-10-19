/** @vitest-environment jsdom */
import { afterEach, describe, expect, it, vi } from "vitest";
import { cleanup, render, screen, fireEvent } from "@testing-library/react";

afterEach(() => {
  cleanup();
});
import { DepartmentTestAccounts } from "./DepartmentTestAccounts";
import {
  DEPARTMENT_TEST_ACCOUNTS,
  findTestAccountByEmail,
  verifyTestCredentials,
  loginAsTestAccount,
  getStoredTestSession,
  clearStoredTestSession,
} from "@/lib/demo-auth";

describe("DepartmentTestAccounts Component", () => {
  it("renders all department test accounts and their credentials", () => {
    const handleFill = vi.fn();
    const handleLogin = vi.fn();

    render(
      <DepartmentTestAccounts
        onFillCredentials={handleFill}
        onInstantLogin={handleLogin}
      />
    );

    expect(screen.getByText("Department Test Logins")).toBeDefined();
    expect(screen.getByText(`${DEPARTMENT_TEST_ACCOUNTS.length} Profiles Ready`)).toBeDefined();

    // Verify key test accounts are present
    expect(screen.getByText("Platform Owner (Executive Admin)")).toBeDefined();
    expect(screen.getByText("Dr. Vikram Seth (Hardware Lead)")).toBeDefined();
    expect(screen.getByText("Priya Sharma (Procurement Head)")).toBeDefined();
    expect(screen.getByText("Rohit Verma (Commercial & Sales)")).toBeDefined();
  });

  it("filters accounts by category", () => {
    const handleFill = vi.fn();
    const handleLogin = vi.fn();

    render(
      <DepartmentTestAccounts
        onFillCredentials={handleFill}
        onInstantLogin={handleLogin}
      />
    );

    // Click "Engineering" category
    const engButton = screen.getByRole("button", { name: /^Engineering/i });
    fireEvent.click(engButton);

    expect(screen.getByText("Dr. Vikram Seth (Hardware Lead)")).toBeDefined();
    expect(screen.getByText("Sneha Rao (Firmware Lead)")).toBeDefined();
    expect(screen.getByText("Karthik Menon (Mechanical Lead)")).toBeDefined();

    // Accounts from other categories should be hidden
    expect(screen.queryByText("Rohit Verma (Commercial & Sales)")).toBeNull();
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

describe("demo-auth helper module", () => {
  it("verifies credentials correctly", () => {
    const valid = verifyTestCredentials("admin@ssmone.internal", "Admin@SSMone2026");
    expect(valid).not.toBeNull();
    expect(valid?.role).toBe("admin");

    const wrongPass = verifyTestCredentials("admin@ssmone.internal", "WrongPassword");
    expect(wrongPass).toBeNull();

    const nonExistent = verifyTestCredentials("nonexistent@example.com", "pass");
    expect(nonExistent).toBeNull();
  });

  it("finds test accounts by case-insensitive email", () => {
    const found = findTestAccountByEmail("HARDWARE.LEAD@SSMONE.INTERNAL");
    expect(found).toBeDefined();
    expect(found?.name).toContain("Hardware Lead");
  });

  it("manages stored test session and cleanup", () => {
    clearStoredTestSession();
    expect(getStoredTestSession()).toBeNull();

    const account = DEPARTMENT_TEST_ACCOUNTS[0];
    loginAsTestAccount(account);

    const stored = getStoredTestSession();
    expect(stored).not.toBeNull();
    expect(stored?.account.id).toBe("admin");
    expect(stored?.role).toBe("admin");
    expect(stored?.user.email).toBe("admin@ssmone.internal");

    clearStoredTestSession();
    expect(getStoredTestSession()).toBeNull();
  });
});
