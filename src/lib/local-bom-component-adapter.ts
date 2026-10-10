import type { BomCostRow } from "@/lib/lifecycle-structured-template-previews";
import type { LocalBomComponentCandidate } from "@/components/lifecycle/LocalBomComponentPicker";

export type LocalBomComponentSelection = Record<string, string>;

function empty(value: string) {
  return value.trim().length === 0;
}

export function adoptLocalBomComponent(row: BomCostRow, candidate: LocalBomComponentCandidate): BomCostRow {
  return {
    ...row,
    mpn: empty(row.mpn) ? candidate.partNumber : row.mpn,
    manufacturer: empty(row.manufacturer) ? candidate.manufacturer ?? "" : row.manufacturer,
    description: empty(row.description) ? candidate.name : row.description,
  };
}

export function recordLocalBomComponentSelection(selections: LocalBomComponentSelection, rowId: string, componentId: string): LocalBomComponentSelection {
  return { ...selections, [rowId]: componentId };
}
