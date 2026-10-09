import { describe, expect, it } from "vitest";
import { shouldUpdateGlobalTaskRoute } from "./task-board-selection";

describe("embedded task selection", () => {
  it("keeps task selection inside a project workspace", () => {
    expect(shouldUpdateGlobalTaskRoute("project-123", false)).toBe(false);
  });

  it("lets a controlled parent own selection state", () => {
    expect(shouldUpdateGlobalTaskRoute(undefined, true)).toBe(false);
  });

  it("keeps global task route selection for the standalone board", () => {
    expect(shouldUpdateGlobalTaskRoute(undefined, false)).toBe(true);
  });
});