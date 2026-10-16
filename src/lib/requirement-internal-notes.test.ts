import { describe, expect, it, vi } from "vitest";
import { internalNoteAvailability, internalNoteSaveSchema, readOwnInternalNoteRpc, saveOwnInternalNoteRpc } from "./requirement-internal-notes";
const id = (n: number) => `00000000-0000-4000-8000-${String(n).padStart(12,"0")}`;
const scope = { reviewId: id(1), sourceRevisionId: id(2), masterVersionId: id(3) };
const input = { ...scope, expectedVersion: 0, body: " Private note ", requestKey: id(4) };
const saved = { id: id(5), review_id: id(1), source_revision_id: id(2), master_version_id: id(3), author_user_id: id(6), expected_version: 0, version_number: 1, body: "Private note", request_key: id(4), saved_at: "2026-10-16T03:00:00+00:00" };
describe("private note caller adapter", () => {
 it("keeps the application deployment gate closed", () => expect(internalNoteAvailability.available).toBe(false));
 it("requires exact scope and excludes caller-supplied authority", () => expect(() => internalNoteSaveSchema.parse({ ...input, actorId: id(7) })).toThrow());
 it("allows an explicit empty clear", () => expect(internalNoteSaveSchema.parse({ ...input, body: "" }).body).toBe(""));
 it("preserves tabs and newlines consistently with PostgreSQL btrim", async () => {
  const value = { ...saved, body: "\tPrivate note\n" };
  const rpc = vi.fn().mockResolvedValue({ data: value, error: null });
  await expect(saveOwnInternalNoteRpc(rpc, { ...input, body: value.body }, id(6))).resolves.toEqual(value);
 });
 it("verifies a separate read after saving", async () => {
  const rpc = vi.fn().mockResolvedValue({ data: saved, error: null });
  await expect(saveOwnInternalNoteRpc(rpc, input, id(6))).resolves.toEqual(saved);
  expect(rpc.mock.calls.map(([name]) => name)).toEqual(["save_requirement_internal_note","read_own_requirement_internal_note"]);
 });
 it.each(["author_user_id","review_id","source_revision_id","master_version_id","request_key"])("rejects mismatched %s", async (field) => {
  const rpc = vi.fn().mockResolvedValue({ data: { ...saved, [field]: id(99) }, error: null });
  await expect(saveOwnInternalNoteRpc(rpc, input, id(6))).rejects.toThrow();
  expect(rpc).toHaveBeenCalledTimes(1);
 });
 it("does not claim save success when a concurrent later version is read", async () => {
  const rpc = vi.fn().mockResolvedValueOnce({ data: saved, error: null }).mockResolvedValueOnce({ data: { ...saved, id: id(9), expected_version: 1, version_number: 2 }, error: null });
  await expect(saveOwnInternalNoteRpc(rpc, input, id(6))).rejects.toThrow("Refresh before retrying");
 });
 it("propagates read denial after a save without retrying the write", async () => {
  const rpc = vi.fn().mockResolvedValueOnce({ data: saved, error: null }).mockResolvedValueOnce({ data: null, error: { message: "read denied" } });
  await expect(saveOwnInternalNoteRpc(rpc, input, id(6))).rejects.toThrow("read denied"); expect(rpc).toHaveBeenCalledTimes(2);
 });
 it("distinguishes no saved note from a denied read", async () => {
  await expect(readOwnInternalNoteRpc(vi.fn().mockResolvedValue({ data: null, error: null }), scope, id(6))).resolves.toBeNull();
 });
});

