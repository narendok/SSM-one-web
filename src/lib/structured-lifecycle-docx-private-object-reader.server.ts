import type { SupabaseClient } from "@supabase/supabase-js";
import type { PrivateDocxObject, PrivateDocxObjectReader } from "./structured-lifecycle-docx-private-object-bridge.server";

type ImmutableObjectRecord = {
  bucket_id: string;
  name: string;
  version: string | null;
  archived_at: string | null;
  is_delete_marker: boolean | null;
  metadata: unknown;
};

type PrivateStorageAdmin = Pick<SupabaseClient, "storage"> & {
  from(table: "objects"): {
    select(columns: string): {
      eq(column: string, value: string): {
        eq(column: string, value: string): {
          eq(column: string, value: string): {
            is(column: string, value: null): {
              maybeSingle(): PromiseLike<{ data: ImmutableObjectRecord | null; error: { message: string } | null }>;
            };
          };
        };
      };
    };
  };
};

export type PrivateDocxCreateOnlyAuthority = {
  /**
   * Binds the exact request, active assigned-person scope, and reserved
   * create-only storage path before and after the mutable-path SDK read.
   */
  assertCurrentCreateOnlyPath(input: Pick<PrivateDocxObject, "bucket" | "path" | "objectVersion"> & { requestKey: string }): Promise<void>;
};

type CurrentPathStorageAdmin = PrivateStorageAdmin & {
  storage: {
    from(bucket: "project-drive"): {
      download(path: string): PromiseLike<{ data: Blob | null; error: { message: string } | null }>;
    };
  };
};

function fail(message: string): never { throw new Error(`Private DOCX object reader unavailable: ${message}`); }
function byteSize(metadata: unknown) {
  if (!metadata || typeof metadata !== "object") return null;
  const value = (metadata as Record<string, unknown>).size;
  return typeof value === "number" && Number.isSafeInteger(value) && value > 0 ? value : null;
}

/**
 * Server-only, inactive adapter for the existing private storage runtime.
 * It never falls back to a latest-object read: a versioned object metadata lookup
 * must agree with the requested immutable identity before any bytes are read.
 * Current storage.download does not address a specific immutable version, so this
 * adapter fails closed after identity inspection until that runtime capability is accepted.
 */
export function createPendingVersionedPrivateDocxReader(admin: PrivateStorageAdmin): PrivateDocxObjectReader {
  return {
    async readExactObject(input): Promise<PrivateDocxObject> {
      const { data: object, error } = await admin
        .from("objects")
        .select("bucket_id,name,version,archived_at,is_delete_marker,metadata")
        .eq("bucket_id", input.storageBucket)
        .eq("name", input.storagePath)
        .eq("version", input.objectVersion)
        .is("archived_at", null)
        .maybeSingle();
      if (error) fail("immutable object metadata could not be read");
      if (!object || object.is_delete_marker || object.bucket_id !== input.storageBucket || object.name !== input.storagePath || object.version !== input.objectVersion) fail("exact immutable object identity is absent or replaced");
      if (byteSize(object.metadata) === null) fail("immutable object byte size is unavailable");
      // Supabase Storage download() selects current path content, not object version.
      // Do not read mutable bytes after a version metadata match.
      fail("the current server storage SDK cannot download the requested immutable object version");
    },
  };
}

/**
 * Reads the current storage path only behind the pending create-only contract.
 * The before/after metadata checks turn a current-path SDK read into an exact
 * object-version read only when the database contract prevents replacement,
 * update, and deletion for the reserved request path. Callers must not wire
 * this reader until that SQL contract and its receipt authority are accepted.
 */
export function createContractBoundCurrentPathPrivateDocxReader(
  admin: CurrentPathStorageAdmin,
  authority: PrivateDocxCreateOnlyAuthority,
): PrivateDocxObjectReader {
  async function readIdentity(input: Pick<PrivateDocxObject, "bucket" | "path" | "objectVersion">): Promise<ImmutableObjectRecord> {
    const { data: object, error } = await admin
      .from("objects")
      .select("bucket_id,name,version,archived_at,is_delete_marker,metadata")
      .eq("bucket_id", input.bucket)
      .eq("name", input.path)
      .eq("version", input.objectVersion)
      .is("archived_at", null)
      .maybeSingle();
    if (error) fail("immutable object metadata could not be read");
    if (!object || object.is_delete_marker || object.bucket_id !== input.bucket || object.name !== input.path || object.version !== input.objectVersion) {
      fail("exact immutable object identity is absent or replaced");
    }
    if (byteSize(object.metadata) === null) fail("immutable object byte size is unavailable");
    return object;
  }

  return {
    async readExactObject(input): Promise<PrivateDocxObject> {
      await authority.assertCurrentCreateOnlyPath({ bucket: input.storageBucket, path: input.storagePath, objectVersion: input.objectVersion, requestKey: input.requestKey });
      const before = await readIdentity({ bucket: input.storageBucket, path: input.storagePath, objectVersion: input.objectVersion });
      const expectedSize = byteSize(before.metadata);
      if (expectedSize === null) fail("immutable object byte size is unavailable");
      const { data, error } = await admin.storage.from(input.storageBucket).download(input.storagePath);
      if (error || !data) fail("private DOCX bytes could not be read");
      const bytes = new Uint8Array(await data.arrayBuffer());
      if (bytes.byteLength !== expectedSize) fail("current-path bytes do not match immutable object size");
      const after = await readIdentity({ bucket: input.storageBucket, path: input.storagePath, objectVersion: input.objectVersion });
      if (byteSize(after.metadata) !== expectedSize) fail("immutable object metadata changed during current-path read");
      await authority.assertCurrentCreateOnlyPath({ bucket: input.storageBucket, path: input.storagePath, objectVersion: input.objectVersion, requestKey: input.requestKey });
      return { bucket: input.storageBucket, path: input.storagePath, objectVersion: input.objectVersion, mimeType: null, bytes };
    },
  };
}
