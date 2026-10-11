export type StructuredSalesDraftSaveCapability =
  | { available: false; reason: "UNDEPLOYED" | "SOURCE_UNVERIFIED" | "LOCATION_UNVERIFIED" }
  | { available: true; functionName: "save_sales_opportunity_structured_draft_at_location"; materializer: "commit_sales_opportunity_structured_draft_materialization" };

export type StructuredSalesDraftHistoryCapability =
  | { available: false; reason: "UNDEPLOYED" | "SOURCE_UNVERIFIED" }
  | { available: true };

/**
 * Browser state is never evidence that protected functions, a recorded private
 * location, or narrow bucket policy are deployed. The server capability probe is
 * deliberately not introduced until the reviewed SQL package is installed.
 */
export function structuredSalesDraftSaveCapability(sourceVerified: boolean): StructuredSalesDraftSaveCapability {
  if (!sourceVerified) return { available: false, reason: "SOURCE_UNVERIFIED" };
  return { available: false, reason: "UNDEPLOYED" };
}

export function structuredSalesDraftHistoryCapability(sourceVerified: boolean): StructuredSalesDraftHistoryCapability {
  if (!sourceVerified) return { available: false, reason: "SOURCE_UNVERIFIED" };
  return { available: false, reason: "UNDEPLOYED" };
}

export function structuredSalesDraftSaveBoundaryMessage(capability: StructuredSalesDraftSaveCapability): string {
  if (capability.available) return "Save is available through the verified private-location materialization contract.";
  if (capability.reason === "SOURCE_UNVERIFIED") return "Save remains unavailable until the exact authorized source revision is verified.";
  if (capability.reason === "LOCATION_UNVERIFIED") return "Save remains unavailable until a verified private Sales location is available.";
  return "Save remains unavailable until the approved draft, immutable audit, private location, and staged object contracts are deployed and verified.";
}

export function structuredSalesDraftHistoryBoundaryMessage(capability: StructuredSalesDraftHistoryCapability): string {
  if (capability.available) return "Saved private revisions are available through the verified history contract.";
  return capability.reason === "SOURCE_UNVERIFIED"
    ? "Saved revision history is unavailable until the exact authorized source revision is verified."
    : "Saved revision history and private download remain unavailable until the approved materialization contract is deployed and verified.";
}
