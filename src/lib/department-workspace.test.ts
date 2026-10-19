import { describe, it, expect } from "vitest";
import { CANONICAL_DEPT_UUIDS, DEFAULT_CANONICAL_DEPARTMENTS, resolveCanonicalDepartment } from "./canonical-departments";
import { workspaceForDepartment, workspaceDefinitions } from "./department-workspace-navigation";
import { canonicalToDashboardDepartment, tasksForDepartment } from "./department-dashboard";
import { DEPARTMENT_TEST_ACCOUNTS, ALL_SYSTEM_PERMISSIONS } from "./demo-auth";

describe("Department Workspace Navigation & Configuration", () => {
  it("resolves canonical department UUIDs correctly", () => {
    const mech = resolveCanonicalDepartment(CANONICAL_DEPT_UUIDS.MECHANICAL);
    expect(mech?.code).toBe("MECH");

    const rnd = resolveCanonicalDepartment(CANONICAL_DEPT_UUIDS.RND);
    expect(rnd?.code).toBe("RND");

    const proc = resolveCanonicalDepartment(CANONICAL_DEPT_UUIDS.PROCUREMENT);
    expect(proc?.code).toBe("PROC");
  });

  it("maps canonical departments to workspaces without ambiguity", () => {
    const mechDept = { id: CANONICAL_DEPT_UUIDS.MECHANICAL, name: "Mechanical Engineering", code: "MECH", aliases: ["mech"] };
    const mechWs = workspaceForDepartment(mechDept);
    expect(mechWs?.id).toBe("mechanical");
    expect(mechWs?.items.some((item) => item.to === "/dashboards?department=mechanical")).toBe(true);
    // Mechanical workspace must NOT point to inventory root "/"
    expect(mechWs?.items.find((item) => item.label === "Mechanical workspace")?.to).toBe("/dashboards?department=mechanical");

    const rndDept = { id: CANONICAL_DEPT_UUIDS.RND, name: "Hardware & Embedded R&D", code: "RND", aliases: ["rnd", "hardware"] };
    const rndWs = workspaceForDepartment(rndDept);
    expect(rndWs?.id).toBe("rnd");
    expect(rndWs?.items.find((item) => item.label === "Hardware workspace")?.to).toBe("/dashboards?department=rnd");

    const procDept = { id: CANONICAL_DEPT_UUIDS.PROCUREMENT, name: "Procurement & SCM", code: "PROC", aliases: ["proc", "purchase"] };
    const procWs = workspaceForDepartment(procDept);
    expect(procWs?.id).toBe("procurement");
    expect(procWs?.items.find((item) => item.label === "Procurement workspace")?.to).toBe("/dashboards?department=procurement");
  });

  it("maps canonical UUIDs to DashboardDepartment", () => {
    expect(canonicalToDashboardDepartment(CANONICAL_DEPT_UUIDS.MECHANICAL)).toBe("mechanical");
    expect(canonicalToDashboardDepartment(CANONICAL_DEPT_UUIDS.RND)).toBe("rnd");
    expect(canonicalToDashboardDepartment(CANONICAL_DEPT_UUIDS.PROCUREMENT)).toBe("procurement");
    expect(canonicalToDashboardDepartment(CANONICAL_DEPT_UUIDS.PRODUCTION)).toBe("production");
    expect(canonicalToDashboardDepartment(CANONICAL_DEPT_UUIDS.SALES)).toBe("sales");
  });

  it("verifies permissions and defaultPaths across all department test accounts", () => {
    expect(ALL_SYSTEM_PERMISSIONS).toContain("inventory.view");
    expect(ALL_SYSTEM_PERMISSIONS).toContain("inventory.manage");
    expect(ALL_SYSTEM_PERMISSIONS).toContain("assets.edit");

    const admin = DEPARTMENT_TEST_ACCOUNTS.find((a) => a.id === "admin");
    expect(admin?.role).toBe("admin");
    expect(admin?.defaultPath).toBe("/projects?tab=analysis");

    const hw = DEPARTMENT_TEST_ACCOUNTS.find((a) => a.id === "hardware");
    expect(hw?.permissions).toContain("inventory.view");
    expect(hw?.permissions).toContain("projects.view");
    expect(hw?.permissions).toContain("sales.view");
    expect(hw?.defaultPath).toBe("/dashboards?department=rnd");

    const mech = DEPARTMENT_TEST_ACCOUNTS.find((a) => a.id === "mechanical");
    expect(mech?.permissions).toContain("inventory.view");
    expect(mech?.permissions).toContain("projects.view");
    expect(mech?.permissions).toContain("sales.view");
    expect(mech?.defaultPath).toBe("/dashboards?department=mechanical");

    const purchase = DEPARTMENT_TEST_ACCOUNTS.find((a) => a.id === "purchase");
    expect(purchase?.permissions).toContain("inventory.view");
    expect(purchase?.permissions).toContain("procurement.view");
    expect(purchase?.permissions).toContain("sales.view");
    expect(purchase?.defaultPath).toBe("/dashboards?department=procurement");

    const stores = DEPARTMENT_TEST_ACCOUNTS.find((a) => a.id === "stores");
    expect(stores?.permissions).toContain("inventory.view");
    expect(stores?.permissions).toContain("stores.view");
  });
});
