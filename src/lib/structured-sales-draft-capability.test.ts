import { describe, expect, it } from "vitest";
import { structuredSalesDraftHistoryBoundaryMessage, structuredSalesDraftHistoryCapability, structuredSalesDraftSaveBoundaryMessage, structuredSalesDraftSaveCapability } from "./structured-sales-draft-capability";

describe("structured Sales draft Save capability", () => {
  it("fails closed before source verification", () => {
    const capability = structuredSalesDraftSaveCapability(false);
    expect(capability).toEqual({ available: false, reason: "SOURCE_UNVERIFIED" });
    expect(structuredSalesDraftSaveBoundaryMessage(capability)).toContain("exact authorized source revision");
  });

  it("fails closed when the approved backend package is not deployed", () => {
    const capability = structuredSalesDraftSaveCapability(true);
    expect(capability).toEqual({ available: false, reason: "UNDEPLOYED" });
    expect(structuredSalesDraftSaveBoundaryMessage(capability)).toContain("immutable audit");
  });
});

it("keeps history and private download fail-closed until materialization is deployed", () => {
  const history = structuredSalesDraftHistoryCapability(true);
  expect(history).toEqual({ available: false, reason: "UNDEPLOYED" });
  expect(structuredSalesDraftHistoryBoundaryMessage(history)).toContain("private download");
});
