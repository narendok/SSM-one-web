import { describe, expect, it, beforeEach } from "vitest";
import {
  fetchDepartmentChronicles,
  createDepartmentChronicle,
  updateDepartmentChronicle,
  deleteDepartmentChronicle,
  resetDepartmentChronicles,
} from "./department-chronicles";

describe("Department Chronicles feed management", () => {
  beforeEach(() => {
    resetDepartmentChronicles();
  });

  it("fetches seeded initial chronicles across departments", () => {
    const all = fetchDepartmentChronicles();
    expect(all.length).toBeGreaterThanOrEqual(5);

    const mechChronicles = fetchDepartmentChronicles("mechanical");
    expect(mechChronicles.length).toBeGreaterThanOrEqual(1);
    expect(mechChronicles.some((c) => c.title.includes("CAD"))).toBe(true);

    const rndChronicles = fetchDepartmentChronicles("rnd");
    expect(rndChronicles.length).toBeGreaterThanOrEqual(1);
    expect(rndChronicles.some((c) => c.title.includes("BLE"))).toBe(true);
  });

  it("creates a new chronicle entry successfully", () => {
    const created = createDepartmentChronicle({
      departmentId: "mechanical",
      title: "Vibration Test Fixture Fabricated",
      content: "Custom aluminum mounting fixture completed for MIL-STD vibration testing profile.",
      category: "milestone",
      authorName: "Karthik R",
      authorRole: "Lead Mechanical Engineer",
      pinned: true,
    });

    expect(created.id).toBeDefined();
    expect(created.createdAt).toBeDefined();

    const mechChronicles = fetchDepartmentChronicles("mechanical");
    expect(mechChronicles[0].title).toBe("Vibration Test Fixture Fabricated");
    expect(mechChronicles[0].pinned).toBe(true);
  });

  it("updates an existing chronicle entry", () => {
    const created = createDepartmentChronicle({
      departmentId: "rnd",
      title: "Initial Draft Note",
      content: "Drafting schematic review notes.",
      category: "update",
      authorName: "Arun Kumar",
      authorRole: "Hardware Engineer",
    });

    const updated = updateDepartmentChronicle(created.id, {
      title: "Finalized Schematic Sign-off",
      category: "decision",
      content: "Schematic signed off after peer review.",
    });

    expect(updated.title).toBe("Finalized Schematic Sign-off");
    expect(updated.category).toBe("decision");

    const rndList = fetchDepartmentChronicles("rnd");
    const found = rndList.find((c) => c.id === created.id);
    expect(found?.title).toBe("Finalized Schematic Sign-off");
  });

  it("deletes a chronicle entry", () => {
    const created = createDepartmentChronicle({
      departmentId: "procurement",
      title: "Temporary Quotation Inquiry",
      content: "Inquiry sent to distributor.",
      category: "notice",
      authorName: "Meera Nair",
      authorRole: "Procurement Specialist",
    });

    const deleted = deleteDepartmentChronicle(created.id);
    expect(deleted).toBe(true);

    const procList = fetchDepartmentChronicles("procurement");
    expect(procList.some((c) => c.id === created.id)).toBe(false);
  });
});
