import { describe, expect, it } from "vitest";
import { CANONICAL_DEPT_UUIDS, resolveCanonicalDepartment, type CanonicalDepartment } from "./tasks";
import { workspaceForDepartment } from "./department-workspace-navigation";
import { canonicalToDashboardDepartment, dashboardToCanonicalDepartment } from "./department-dashboard";

describe("canonical department workspaces", () => {
  it("maps the real department fields without requiring a retired department_type column", () => {
    const department: CanonicalDepartment = {
      id: "hardware-id",
      name: "Hardware & R&D",
      code: "RND",
      aliases: [],
    };

    expect(workspaceForDepartment(department)?.id).toBe("rnd");
  });

  it("resolves canonical departments by UUID, code, slug, and alias", () => {
    expect(resolveCanonicalDepartment(CANONICAL_DEPT_UUIDS.MECHANICAL)?.name).toBe("Mechanical");
    expect(resolveCanonicalDepartment("MECH")?.name).toBe("Mechanical");
    expect(resolveCanonicalDepartment("dept-mechanical")?.name).toBe("Mechanical");
    expect(resolveCanonicalDepartment("mechanical")?.name).toBe("Mechanical");

    expect(resolveCanonicalDepartment(CANONICAL_DEPT_UUIDS.PROCUREMENT)?.name).toBe("Procurement");
    expect(resolveCanonicalDepartment("PROC")?.name).toBe("Procurement");
    expect(resolveCanonicalDepartment("dept-procurement")?.name).toBe("Procurement");
    expect(resolveCanonicalDepartment("purchase")?.name).toBe("Procurement");

    expect(resolveCanonicalDepartment(CANONICAL_DEPT_UUIDS.RND)?.name).toBe("Hardware & R&D");
    expect(resolveCanonicalDepartment("RND")?.name).toBe("Hardware & R&D");
  });

  it("symmetrically maps dashboard departments to canonical UUIDs and back", () => {
    expect(dashboardToCanonicalDepartment("mechanical")).toBe(CANONICAL_DEPT_UUIDS.MECHANICAL);
    expect(canonicalToDashboardDepartment(CANONICAL_DEPT_UUIDS.MECHANICAL)).toBe("mechanical");

    expect(dashboardToCanonicalDepartment("procurement")).toBe(CANONICAL_DEPT_UUIDS.PROCUREMENT);
    expect(canonicalToDashboardDepartment(CANONICAL_DEPT_UUIDS.PROCUREMENT)).toBe("procurement");

    expect(dashboardToCanonicalDepartment("rnd")).toBe(CANONICAL_DEPT_UUIDS.RND);
    expect(canonicalToDashboardDepartment(CANONICAL_DEPT_UUIDS.RND)).toBe("rnd");
  });

  it("resolves dedicated workspace navigation definitions for Mechanical and Procurement", () => {
    const mechDept = resolveCanonicalDepartment(CANONICAL_DEPT_UUIDS.MECHANICAL);
    const mechWs = workspaceForDepartment(mechDept);
    expect(mechWs?.id).toBe("mechanical");
    expect(mechWs?.items.some((i) => i.label === "Mechanical workspace")).toBe(true);
    expect(mechWs?.items.some((i) => i.label === "Production dispatch")).toBe(true);

    const procDept = resolveCanonicalDepartment(CANONICAL_DEPT_UUIDS.PROCUREMENT);
    const procWs = workspaceForDepartment(procDept);
    expect(procWs?.id).toBe("procurement");
    expect(procWs?.items.some((i) => i.label === "Purchase requests")).toBe(true);
    expect(procWs?.items.some((i) => i.label === "BOM sourcing")).toBe(true);
    expect(procWs?.items.some((i) => i.label === "Inwarding (GRN)")).toBe(true);
  });
});