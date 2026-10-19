import { describe, expect, it } from "vitest";
import {
  fetchCanonicalDepartments,
  fetchAllCanonicalDepartments,
  saveCanonicalDepartment,
  toggleDepartmentActiveStatus,
  reorderCanonicalDepartments,
  deleteCanonicalDepartment,
  resolveCanonicalDepartment,
  CANONICAL_DEPT_UUIDS,
} from "./canonical-departments";

describe("Dynamic Department Master management", () => {
  it("fetches active canonical departments including mechanical, rnd, and procurement", async () => {
    const active = await fetchCanonicalDepartments();
    expect(active.length).toBeGreaterThanOrEqual(8);
    expect(active.some((d) => d.name === "Mechanical")).toBe(true);
    expect(active.some((d) => d.name === "Hardware & R&D")).toBe(true);
    expect(active.some((d) => d.name === "Procurement")).toBe(true);
  });

  it("creates a new custom department dynamically", async () => {
    const custom = await saveCanonicalDepartment({
      name: "Battery Systems",
      code: "BMS",
      aliases: ["battery", "cells", "pack"],
      description: "High-voltage Lithium pack engineering and battery safety.",
      is_active: true,
    });

    expect(custom.id).toBeDefined();
    expect(custom.name).toBe("Battery Systems");
    expect(custom.code).toBe("BMS");

    const all = await fetchCanonicalDepartments();
    const found = all.find((d) => d.id === custom.id);
    expect(found).toBeDefined();
    expect(found?.name).toBe("Battery Systems");

    // Can resolve by code or alias
    const resolvedByCode = resolveCanonicalDepartment("BMS", all);
    expect(resolvedByCode?.id).toBe(custom.id);

    const resolvedByAlias = resolveCanonicalDepartment("cells", all);
    expect(resolvedByAlias?.id).toBe(custom.id);
  });

  it("modifies an existing department name and code", async () => {
    const custom = await saveCanonicalDepartment({
      name: "Temporary Department",
      code: "TMP",
      aliases: ["temp"],
      is_active: true,
    });

    const updated = await saveCanonicalDepartment({
      id: custom.id,
      name: "Permanent Engineering Lab",
      code: "PEL",
      aliases: ["lab", "testing"],
    });

    expect(updated.name).toBe("Permanent Engineering Lab");
    expect(updated.code).toBe("PEL");

    const all = await fetchCanonicalDepartments();
    const found = all.find((d) => d.id === custom.id);
    expect(found?.name).toBe("Permanent Engineering Lab");
  });

  it("soft-deactivates and reactivates a department", async () => {
    const dept = await saveCanonicalDepartment({
      name: "Trial Department",
      code: "TRL",
      aliases: ["trial"],
      is_active: true,
    });

    // Deactivate (soft-delete)
    await toggleDepartmentActiveStatus(dept.id, false);

    const activeList = await fetchCanonicalDepartments();
    expect(activeList.some((d) => d.id === dept.id)).toBe(false);

    const fullList = await fetchAllCanonicalDepartments();
    const foundInactive = fullList.find((d) => d.id === dept.id);
    expect(foundInactive?.is_active).toBe(false);

    // Reactivate
    await toggleDepartmentActiveStatus(dept.id, true);
    const reactivatedList = await fetchCanonicalDepartments();
    expect(reactivatedList.some((d) => d.id === dept.id)).toBe(true);
  });

  it("reorders departments dynamically", async () => {
    const active = await fetchCanonicalDepartments();
    const ids = active.map((d) => d.id);
    // Reverse first two IDs
    const reorderedIds = [ids[1], ids[0], ...ids.slice(2)];

    const reordered = await reorderCanonicalDepartments(reorderedIds);
    expect(reordered[0].id).toBe(ids[1]);
    expect(reordered[1].id).toBe(ids[0]);
  });

  it("soft-deactivates core department rather than hard deleting", async () => {
    const result = await deleteCanonicalDepartment(CANONICAL_DEPT_UUIDS.MECHANICAL);
    expect(result.deactivatedOnly).toBe(true);
    expect(result.deleted).toBe(false);

    // Clean up: reactivate mechanical so subsequent tests are pristine
    await toggleDepartmentActiveStatus(CANONICAL_DEPT_UUIDS.MECHANICAL, true);
  });
});
