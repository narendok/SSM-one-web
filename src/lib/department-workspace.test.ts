import { describe, expect, it } from "vitest";
import { departmentWorkTarget } from "./department-workspace";
import { workspaceForDepartment, workspaceDefinitions } from "./department-workspace-navigation";
import { departmentDefinitions, getPermittedDepartments } from "./department-dashboard";

describe("department workspace navigation and mapping", () => {
  it("includes mechanical as a first-class workspace definition", () => {
    const mechanicalDef = workspaceDefinitions.find((def) => def.id === "mechanical");
    expect(mechanicalDef).toBeDefined();
    expect(mechanicalDef?.label).toBe("Mechanical Engineering");
    expect(mechanicalDef?.items.length).toBeGreaterThanOrEqual(4);
    expect(mechanicalDef?.items.some((item) => item.to === "/dashboards?department=mechanical")).toBe(true);
    expect(mechanicalDef?.items.some((item) => item.label.toLowerCase().includes("cad"))).toBe(true);
  });

  it("resolves mechanical department aliases accurately", () => {
    const dept1 = { name: "Mechanical Engineering", code: "MECH", aliases: ["cad", "tooling"] };
    const ws1 = workspaceForDepartment(dept1);
    expect(ws1).toBeDefined();
    expect(ws1?.id).toBe("mechanical");

    const dept2 = { name: "Product Design", code: "PD", aliases: ["enclosure"] };
    const ws2 = workspaceForDepartment(dept2);
    expect(ws2).toBeDefined();
    expect(ws2?.id).toBe("mechanical");
  });

  it("resolves R&D and Procurement accurately", () => {
    const rndDept = { name: "Hardware & R&D", code: "RND", aliases: ["embedded", "electronics"] };
    const wsRnd = workspaceForDepartment(rndDept);
    expect(wsRnd?.id).toBe("rnd");

    const procDept = { name: "Procurement & SCM", code: "PROC", aliases: ["purchase", "stores"] };
    const wsProc = workspaceForDepartment(procDept);
    expect(wsProc?.id).toBe("procurement");
  });

  it("computes departmentWorkTarget correctly for all departments", () => {
    expect(departmentWorkTarget(null)).toBe("/command-center");
    expect(departmentWorkTarget(undefined)).toBe("/command-center");

    const mechDept = { name: "Mechanical Engineering", code: "MECH", aliases: [] };
    expect(departmentWorkTarget(mechDept)).toBe("/dashboards?department=mechanical");

    const rndDept = { name: "Hardware & R&D", code: "RND", aliases: [] };
    expect(departmentWorkTarget(rndDept)).toBe("/dashboards?department=rnd");

    const procDept = { name: "Procurement & SCM", code: "PROC", aliases: [] };
    expect(departmentWorkTarget(procDept)).toBe("/dashboards?department=procurement");

    const unmapped = { name: "Unknown Department", code: "UNK", aliases: [] };
    expect(departmentWorkTarget(unmapped)).toBe("/command-center");
  });

  it("includes mechanical in departmentDefinitions and checks permission scoping", () => {
    const mechDef = departmentDefinitions.find((d) => d.id === "mechanical");
    expect(mechDef).toBeDefined();
    expect(mechDef?.permission).toBe("engineering.view");

    // Admin gets all departments
    const adminDepts = getPermittedDepartments("admin", []);
    expect(adminDepts.some((d) => d.id === "mechanical")).toBe(true);
    expect(adminDepts.some((d) => d.id === "rnd")).toBe(true);
    expect(adminDepts.length).toBe(departmentDefinitions.length);

    // Engineer with engineering.view gets rnd and mechanical
    const engDepts = getPermittedDepartments("member", ["engineering.view"]);
    expect(engDepts.some((d) => d.id === "mechanical")).toBe(true);
    expect(engDepts.some((d) => d.id === "rnd")).toBe(true);
    expect(engDepts.some((d) => d.id === "finance")).toBe(false);
  });
});
