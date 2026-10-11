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
