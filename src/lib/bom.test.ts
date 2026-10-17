import { describe, expect, it } from "vitest";
import { calculatedLineCost, guessMapping, hasTotalCostMismatch, parseCost, toLines } from "./bom";

const headers = [
  "Comment(value)", "Manufacturer-Part-Number", "Manufacturer", "Description", "Designator",
  "Footprint", "Quantity", "Remark", "Unit-Cost", "Total-Cost",
];

describe("project BOM import", () => {
  it("maps the standard header without confusing manufacturer and MPN", () => {
    expect(guessMapping(headers)).toEqual({
      value: "Comment(value)", mpn: "Manufacturer-Part-Number", manufacturer: "Manufacturer",
      description: "Description", refs: "Designator", footprint: "Footprint", quantity: "Quantity",
      remark: "Remark", unitCost: "Unit-Cost", totalCost: "Total-Cost",
    });
  });

  it("parses currency values and preserves blank costs", () => {
    expect(parseCost("₹1,234.50")).toBe(1234.5);
    expect(parseCost("$ 0.08")).toBe(0.08);
    expect(parseCost(12.5)).toBe(12.5);
    expect(parseCost("")).toBeNull();
  });

  it("keeps project quantity, remarks, and costs distinct", () => {
    const mapping = guessMapping(headers);
    const [line] = toLines([{
      "Comment(value)": "10k", "Manufacturer-Part-Number": "RC0603", Manufacturer: "Yageo",
      Description: "Resistor", Designator: "R1,R2,R3", Footprint: "0603", Quantity: "3",
      Remark: "Production", "Unit-Cost": "₹0.08", "Total-Cost": "0.24",
    }], mapping);
    expect(line).toMatchObject({ quantity: 3, value: "10k", refs: "R1,R2,R3", remark: "Production", unitCost: 0.08, totalCost: 0.24 });
    expect(calculatedLineCost(line)).toBe(0.24);
    expect(hasTotalCostMismatch(line)).toBe(false);
    expect(hasTotalCostMismatch({ ...line, totalCost: 0.3 })).toBe(true);
  });

  it("flattens production BOM lines by aggregating quantities and sorting designators", async () => {
    const { flattenedProductionRows } = await import("./bom");
    const sampleMatches: any[] = [
      {
        line: { index: 1, mpn: "RC0603", manufacturer: "Yageo", quantity: 2, refs: "R2, R1", value: "10k", description: "Resistor", footprint: "0603", remark: "", unitCost: 0.1, totalCost: 0.2 },
        kind: "exact",
        part: { id: "p1", part_number: "RC0603", total_quantity: 100 },
        shortage: 0,
      },
      {
        line: { index: 2, mpn: "RC0603", manufacturer: "Yageo", quantity: 3, refs: "R3", value: "10k", description: "Resistor", footprint: "0603", remark: "", unitCost: 0.1, totalCost: 0.3 },
        kind: "exact",
        part: { id: "p1", part_number: "RC0603", total_quantity: 100 },
        shortage: 0,
      },
    ];

    const flat = flattenedProductionRows(sampleMatches);
    expect(flat).toHaveLength(1);
    expect(flat[0]["Primary Part / MPN"]).toBe("RC0603");
    expect(flat[0]["Total Qty"]).toBe(5);
    expect(flat[0]["Reference Designators"]).toBe("R1, R2, R3");
    expect(flat[0]["Release Readiness"]).toBe("Qualified");
  });

  it("compares BOM revisions and detects added, removed, and modified line items", async () => {
    const { compareBomRevisions } = await import("./bom");
    const baseline: any[] = [
      { index: 1, refs: "R1", mpn: "RC0603", quantity: 2, unitCost: 0.1, totalCost: 0.2 },
      { index: 2, refs: "C1", mpn: "CAP0805", quantity: 1, unitCost: 0.5, totalCost: 0.5 },
    ];
    const current: any[] = [
      { index: 1, refs: "R1", mpn: "RC0603", quantity: 5, unitCost: 0.1, totalCost: 0.5 }, // Qty changed
      { index: 2, refs: "U1", mpn: "STM32G0", quantity: 1, unitCost: 3.5, totalCost: 3.5 }, // Added
    ];

    const diffs = compareBomRevisions(current, baseline);
    const modified = diffs.find((d) => d.refs === "R1");
    const added = diffs.find((d) => d.refs === "U1");
    const removed = diffs.find((d) => d.refs === "C1");

    expect(modified?.changeType).toBe("modified");
    expect(modified?.oldQty).toBe(2);
    expect(modified?.newQty).toBe(5);

    expect(added?.changeType).toBe("added");
    expect(removed?.changeType).toBe("removed");
  });

  it("validates BOM release readiness accurately", async () => {
    const { isBomReleaseReady } = await import("./bom");
    const unfulfilled: any[] = [
      { line: { mpn: "UNKNOWN" }, kind: "missing", part: null, shortage: 10 },
    ];
    const fulfilled: any[] = [
      { line: { mpn: "RC0603" }, kind: "exact", part: { id: "p1", part_number: "RC0603" }, shortage: 0 },
    ];

    expect(isBomReleaseReady(unfulfilled).ready).toBe(false);
    expect(isBomReleaseReady(unfulfilled).unfulfilledCount).toBe(1);
    expect(isBomReleaseReady(fulfilled).ready).toBe(true);
    expect(isBomReleaseReady(fulfilled).unfulfilledCount).toBe(0);
  });
});