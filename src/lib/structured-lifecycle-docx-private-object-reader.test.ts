import { describe, expect, it } from "vitest";
import { createPendingVersionedPrivateDocxReader } from "./structured-lifecycle-docx-private-object-reader.server";

const input = { storageBucket: "project-drive" as const, storagePath: "private/one.docx", objectVersion: "v1" };
function admin(result: { data: unknown; error: { message: string } | null }) {
  const chain = { is: async () => result };
  const version = { is: () => chain };
  const name = { eq: () => version };
  return { from: () => ({ select: () => ({ eq: () => name }) }) } as never;
}

describe("pending immutable private DOCX reader", () => {
  it("rejects a missing or replaced immutable identity before any byte read", async () => {
    await expect(createPendingVersionedPrivateDocxReader(admin({ data: null, error: null })).readExactObject(input)).rejects.toThrow("identity is absent or replaced");
    await expect(createPendingVersionedPrivateDocxReader(admin({ data: { bucket_id: "project-drive", name: "private/one.docx", version: "v2", archived_at: null, is_delete_marker: false, metadata: { size: 1 } }, error: null })).readExactObject(input)).rejects.toThrow("identity is absent or replaced");
  });
  it("does not downgrade immutable verification to a mutable path download", async () => {
    const record = { bucket_id: "project-drive", name: "private/one.docx", version: "v1", archived_at: null, is_delete_marker: false, metadata: { size: 99 } };
    await expect(createPendingVersionedPrivateDocxReader(admin({ data: record, error: null })).readExactObject(input)).rejects.toThrow("cannot download the requested immutable object version");
  });
  it("rejects unreadable metadata rather than trusting browser-supplied size", async () => {
    const record = { bucket_id: "project-drive", name: "private/one.docx", version: "v1", archived_at: null, is_delete_marker: false, metadata: {} };
    await expect(createPendingVersionedPrivateDocxReader(admin({ data: record, error: null })).readExactObject(input)).rejects.toThrow("byte size is unavailable");
  });
});
