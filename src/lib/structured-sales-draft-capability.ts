export type StructuredSalesDraftSaveCapability =
  | { available: false; reason: "UNDEPLOYED" | "SOURCE_UNVERIFIED" | "LOCATION_UNVERIFIED" }
  | { available: true; functionName: "save_sales_opportunity_structured_draft_at_location" };

/**
 * The deployed schema currently has no approved save RPC or verified private
 * location binding. Keep browser Save fail-closed until a server capability
 * probe is introduced with the approved deployment package.
 */
export function structuredSalesDraftSaveCapability(
  sourceVerified: boolean,
): StructuredSalesDraftSaveCapability {
  if (!sourceVerified) return { available: false, reason: "SOURCE_UNVERIFIED" };
  return { available: false, reason: "UNDEPLOYED" };
}

export function structuredSalesDraftSaveBoundaryMessage(
  capability: StructuredSalesDraftSaveCapability,
): string {
  if (capability.available) return "Save is available through the verified private-location contract.";
  if (capability.reason === "SOURCE_UNVERIFIED") {
    return "Save remains unavailable until the exact authorized source revision is verified.";
  }
  if (capability.reason === "LOCATION_UNVERIFIED") {
    return "Save remains unavailable until a verified private Sales location is available.";
  }
  return "Save remains unavailable until the approved draft, immutable audit, and private-location contracts are deployed and verified.";
}