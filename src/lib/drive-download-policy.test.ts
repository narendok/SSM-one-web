import { describe, expect, it } from "vitest";
import { canDownloadNode, isSelectedNodeRevision } from "./drive-download-policy";

describe("Drive download selection policy", () => {
  it("requires the current node storage key before creating a download", () => {
    expect(canDownloadNode({ storage_path: "project/current.pdf" })).toBe(true);
    expect(canDownloadNode({ storage_path: null })).toBe(false);
  });

  it("keeps historical downloads bound to the selected node", () => {
    expect(isSelectedNodeRevision({ id: "node-a" }, { node_id: "node-a" })).toBe(true);
    expect(isSelectedNodeRevision({ id: "node-a" }, { node_id: "node-b" })).toBe(false);
  });
});