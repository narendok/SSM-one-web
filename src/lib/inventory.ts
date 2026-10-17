export interface Category {
  id: string;
  name: string;
  slug: string;
  icon: string | null;
  sort_order: number;
  parent_id: string | null;
}

export interface Component {
  id: string;
  category_id: string;
  name: string;
  part_number: string;
  manufacturer: string | null;
  value: string | null;
  package_case: string | null;
  footprint: string | null;
  bom_compatibility: string | null;
  voltage_rating: string | null;
  current_rating: string | null;
  temperature_rating: string | null;
  cost: number | null;
  supplier: string | null;
  supplier_url: string | null;
  datasheet_url: string | null;
  notes: string | null;
  low_stock_threshold: number;
  needs_review: boolean;
  short_description: string | null;
  image_url: string | null;
  specs: { name: string; value: string }[] | null;
  alternates: any[] | null;
  nexar_part_id: string | null;
  supplier_synced_at: string | null;
  updated_at: string;
  created_at: string;
}

export interface Location {
  id: string;
  component_id: string;
  location_type: string;
  label: string;
  quantity: number;
}

export interface ComponentWithStock extends Component {
  category: Category;
  locations: Location[];
  total_quantity: number;
}

export type StockStatus = "in_stock" | "low_stock" | "out_of_stock";
export function stockStatus(total: number, threshold: number): StockStatus {
  if (total <= 0) return "out_of_stock";
  if (total <= threshold) return "low_stock";
  return "in_stock";
}

export interface RDMember {
  id: string;
  name: string;
  email: string;
  role: string | null;
  active: boolean;
}

export interface Assignment {
  id: string;
  component_id: string;
  location_id: string | null;
  quantity: number;
  quantity_returned: number;
  assignee_id: string;
  assigned_by: string | null;
  project_name: string | null;
  notes: string | null;
  status: string;
  assigned_at: string;
  returned_at: string | null;
}

export type InventoryDiscipline = "all" | "electronics" | "mechanical" | "wire_harness" | "procurement" | "production_tools";

export interface WireHarnessSpecs {
  connector_a?: string;
  connector_b?: string;
  pin_count?: number;
  wire_gauge_awg?: string;
  length_mm?: number;
  pinout_drawing_ref?: string;
  compatible_jigs?: string[];
  cross_tags?: ("Electrical" | "Mechanical")[];
}

export type LotQualityStatus = "AVAILABLE" | "HOLD" | "REJECTED" | "QUARANTINED";

export interface ComponentStockBreakdown {
  totalQuantity: number;
  releasedQuantity: number;
  heldQuantity: number;
  rejectedQuantity: number;
}

export function getComponentDisciplineTags(c: Component, category?: Category): ("Electrical" | "Mechanical" | "Production" | "Procurement")[] {
  const catSlug = (category?.slug ?? "").toLowerCase();
  const catName = (category?.name ?? "").toLowerCase();
  const name = c.name.toLowerCase();
  const notes = (c.notes ?? "").toLowerCase();

  const isHarness = catSlug.includes("harness") || catName.includes("harness") || name.includes("harness") || notes.includes("wire harness");
  if (isHarness) {
    return ["Electrical", "Mechanical"];
  }

  const isMechanical = catSlug.includes("mechanical") || catSlug.includes("enclosure") || catName.includes("mechanical") ||
    catName.includes("enclosure") || catName.includes("fastener") || name.includes("enclosure") || name.includes("bracket");
  if (isMechanical) {
    return ["Mechanical"];
  }

  const isProduction = catSlug.includes("tool") || catName.includes("tool") || name.includes("jig") || name.includes("crimping");
  if (isProduction) {
    return ["Production"];
  }

  return ["Electrical"];
}

