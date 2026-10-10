// @vitest-environment jsdom
import { beforeEach, describe, expect, it, vi } from "vitest";

const { createSignedUrl, from } = vi.hoisted(() => {
  const createSignedUrl = vi.fn();
  return { createSignedUrl, from: vi.fn(() => ({ createSignedUrl })) };
});
const createElement = vi.fn();
const appendChild = vi.fn();

vi.mock("@/integrations/supabase/client", () => ({
  supabase: { storage: { from } },
}));

import { downloadNode, downloadRevision, downloadUrl, previewUrl } from "./drive";

const node = {
  id: "node-1",
  name: "Design review.pdf",
  storage_path: "project-1/current.pdf",
} as any;

beforeEach(() => {
  createSignedUrl.mockReset();
  from.mockClear();
  createElement.mockReset();
  appendChild.mockReset();
  Object.defineProperty(document, "createElement", { configurable: true, value: createElement });
  Object.defineProperty(document.body, "appendChild", { configurable: true, value: appendChild });
});

describe("Drive signed URL intents", () => {
  it("keeps preview URLs inline", async () => {
    createSignedUrl.mockResolvedValue({ data: { signedUrl: "https://storage.test/inline" }, error: null });

    await expect(previewUrl("project-1/current.pdf")).resolves.toBe("https://storage.test/inline");
    expect(from).toHaveBeenCalledWith("project-drive");
    expect(createSignedUrl).toHaveBeenCalledWith("project-1/current.pdf", 3600);
  });

  it("creates a current-file attachment URL with its original filename", async () => {
    const anchor = { href: "", rel: "", target: "", click: vi.fn(), remove: vi.fn() };
    createElement.mockReturnValue(anchor);
    createSignedUrl.mockResolvedValue({ data: { signedUrl: "https://storage.test/download" }, error: null });

    await downloadNode(node);

    expect(createSignedUrl).toHaveBeenCalledWith("project-1/current.pdf", 3600, { download: "Design review.pdf" });
    expect(anchor.href).toBe("https://storage.test/download");
    expect(anchor.click).toHaveBeenCalledOnce();
  });

  it("uses the exact selected historical revision key and the current node filename", async () => {
    const anchor = { href: "", rel: "", target: "", click: vi.fn(), remove: vi.fn() };
    createElement.mockReturnValue(anchor);
    createSignedUrl.mockResolvedValue({ data: { signedUrl: "https://storage.test/revision" }, error: null });

    await downloadRevision(node, { node_id: "node-1", storage_path: "project-1/revision-2.pdf" });

    expect(createSignedUrl).toHaveBeenCalledWith("project-1/revision-2.pdf", 3600, { download: "Design review.pdf" });
    expect(anchor.click).toHaveBeenCalledOnce();
  });

  it("rejects mismatched historical revisions before requesting or navigating", async () => {
    await expect(downloadRevision(node, { node_id: "other-node", storage_path: "project-1/other.pdf" })).rejects.toThrow("does not belong");
    expect(createSignedUrl).not.toHaveBeenCalled();
    expect(createElement).not.toHaveBeenCalled();
  });

  it("does not navigate when creating a download URL fails", async () => {
    const failure = new Error("RLS denied");
    createSignedUrl.mockResolvedValue({ data: null, error: failure });

    await expect(downloadNode(node)).rejects.toThrow("RLS denied");
    expect(createElement).not.toHaveBeenCalled();
    expect(appendChild).not.toHaveBeenCalled();
  });

  it("surfaces missing signed download data without navigation", async () => {
    createSignedUrl.mockResolvedValue({ data: null, error: null });

    await expect(downloadUrl("project-1/current.pdf", node.name)).rejects.toThrow("Could not create a download link");
    expect(createElement).not.toHaveBeenCalled();
  });
});