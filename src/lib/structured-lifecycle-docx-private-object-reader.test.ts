import { describe, expect, it } from "vitest";
import { createContractBoundCurrentPathPrivateDocxReader, createPendingVersionedPrivateDocxReader, type PrivateDocxCreateOnlyAuthority } from "./structured-lifecycle-docx-private-object-reader.server";

const input = { storageBucket: "project-drive" as const, storagePath: "private/one.docx", objectVersion: "v1", requestKey: "00000000-0000-4000-8000-000000000001" };
function admin(result: { data: unknown; error: { message: string } | null }) {
  const chain = { is: async () => result };
  const archived = { is: () => ({ maybeSingle: async () => result }) };
  const version = { eq: () => archived };
  const name = { eq: () => version };
  return { from: () => ({ select: () => ({ eq: () => name }) }) } as never;
}

function contractAdmin(records: Array<{ data: unknown; error: { message: string } | null }>, bytes: Uint8Array) {
  let read = 0;
  const chain = {
    is: () => ({ maybeSingle: async () => records[Math.min(read++, records.length - 1)] }),
  };
  return {
    from: () => ({ select: () => ({ eq: () => ({ eq: () => ({ eq: () => chain }) }) }) }),
    storage: { from: () => ({ download: async () => ({ data: new Blob([Array.from(bytes)]), error: null }) }) },
  } as never;
}

function authority(overrides: Partial<PrivateDocxCreateOnlyAuthority> = {}): PrivateDocxCreateOnlyAuthority {
  return { assertCurrentCreateOnlyPath: async () => undefined, ...overrides };
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
  it("reads exact current bytes only after the create-only authority holds before and after the read", async () => {
    const bytes = new TextEncoder().encode("verified DOCX bytes");
    const object = { bucket_id: input.storageBucket, name: input.storagePath, version: input.objectVersion, archived_at: null, is_delete_marker: false, metadata: { size: bytes.byteLength } };
    let assertions = 0;
    const reader = createContractBoundCurrentPathPrivateDocxReader(contractAdmin([{ data: object, error: null }, { data: object, error: null }], bytes), authority({ assertCurrentCreateOnlyPath: async () => { assertions += 1; } }));
    const result = await reader.readExactObject({ ...input, requestKey: "00000000-0000-4000-8000-000000000001" });
    expect(Array.from(result.bytes)).toEqual(Array.from(bytes));
    expect(result.objectVersion).toBe("v1");
    expect(assertions).toBe(2);
  });
  it("rejects a replacement, changed bytes, or revoked authority around a current-path read", async () => {
    const bytes = new TextEncoder().encode("four");
    const object = { bucket_id: input.storageBucket, name: input.storagePath, version: input.objectVersion, archived_at: null, is_delete_marker: false, metadata: { size: bytes.byteLength } };
    const replaced = { ...object, version: "v2" };
    const request = { ...input, requestKey: "00000000-0000-4000-8000-000000000001" };
    await expect(createContractBoundCurrentPathPrivateDocxReader(contractAdmin([{ data: object, error: null }, { data: replaced, error: null }], bytes), authority()).readExactObject(request)).rejects.toThrow("identity is absent or replaced");
    await expect(createContractBoundCurrentPathPrivateDocxReader(contractAdmin([{ data: object, error: null }, { data: object, error: null }], new TextEncoder().encode("changed")), authority()).readExactObject(request)).rejects.toThrow("bytes do not match");
    let calls = 0;
    await expect(createContractBoundCurrentPathPrivateDocxReader(contractAdmin([{ data: object, error: null }, { data: object, error: null }], bytes), authority({ assertCurrentCreateOnlyPath: async () => { calls += 1; if (calls === 2) throw new Error("assignment revoked"); } })).readExactObject(request)).rejects.toThrow("assignment revoked");
  });
});
