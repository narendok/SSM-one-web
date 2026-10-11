import { describe, expect, it } from "vitest";
import { structuredSalesDraftHistoryBoundaryMessage, structuredSalesDraftHistoryCapability, structuredSalesDraftSaveBoundaryMessage, structuredSalesDraftSaveCapability } from "./structured-sales-draft-capability";

describe("structured Sales draft Save capability", () => {
  it("fails closed before source verification", () => {
    const capability = structuredSalesDraftSaveCapability(false);
    expect(capability).toEqual({ available: false, reason: "SOURCE_UNVERIFIED" });
    expect(structuredSalesDraftSaveBoundaryMessage(capability)).toContain("exact authorized source revision");
  });

  it("fails closed when the private location cannot be discovered", () => {
    const capability = structuredSalesDraftSaveCapability(true);
    expect(capability).toEqual({ available: false, reason: "LOCATION_UNVERIFIED" });
    expect(structuredSalesDraftSaveBoundaryMessage(capability)).toContain("verified private Sales location");
  });
});

it("enables only a fully discovered source-bound capability", () => {
  const location = {
    locationId: "dd31a29a-dba3-49ad-abf0-349fcab64280",
    storageBucket: "project-drive",
    storagePathPrefix: "sales/opportunity/a6c62c81-1cc2-4804-b1c5-c004c6730b52/",
  };
  expect(structuredSalesDraftSaveCapability(true, location)).toEqual({
    available: true,
    functionName: "save_sales_opportunity_structured_draft_at_location",
    materializer: "commit_sales_opportunity_structured_draft_materialization",
    ...location,
  });
  expect(structuredSalesDraftHistoryCapability(true, location)).toEqual({ available: true, locationId: location.locationId });
});
