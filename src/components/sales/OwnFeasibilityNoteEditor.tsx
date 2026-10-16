import { useEffect, useState } from "react";
import { useAuth } from "@/hooks/useAuth";
import { internalNoteAvailability, type InternalNoteReceipt, type InternalNoteScope } from "@/lib/requirement-internal-notes";
import { readOwnRequirementInternalNote, saveOwnRequirementInternalNote } from "@/lib/requirement-internal-notes.functions";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";

export function OwnFeasibilityNoteEditor({ scope }: { scope: InternalNoteScope }) {
  if (!internalNoteAvailability.available) return <p className="text-xs text-muted-foreground">{internalNoteAvailability.reason}</p>;
  return <AuthenticatedNote scope={scope} />;
}
function AuthenticatedNote({ scope }: { scope: InternalNoteScope }) {
  const { user, loading } = useAuth();
  if (loading) return <p>Checking sign-in…</p>;
  if (!user) return <p>Sign in to read your private note.</p>;
  // Identity isolates local state only. All access decisions remain in the protected RPC.
  return <NoteForm key={[user.id, scope.reviewId, scope.sourceRevisionId, scope.masterVersionId].join(":")} scope={scope} />;
}
function NoteForm({ scope }: { scope: InternalNoteScope }) {
  const [saved, setSaved] = useState<InternalNoteReceipt | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [editing, setEditing] = useState(false);
  const [draft, setDraft] = useState("");
  const [requestKey, setRequestKey] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [reload, setReload] = useState(0);
  useEffect(() => {
    let active = true;
    setLoading(true); setError(null); setEditing(false); setDraft(""); setSaved(null);
    readOwnRequirementInternalNote({ data: scope }).then((note) => {
      if (active) setSaved(note);
    }).catch(() => {
      if (active) setError("Could not read your note. Access or source may have changed.");
    }).finally(() => { if (active) setLoading(false); });
    return () => { active = false; };
  }, [scope.reviewId, scope.sourceRevisionId, scope.masterVersionId, reload]);
  async function save() {
    if (saving || error || loading) return;
    setSaving(true);
    try {
      const note = await saveOwnRequirementInternalNote({ data: { ...scope, expectedVersion: saved?.version_number ?? 0, body: draft, requestKey } });
      setSaved(note); setEditing(false); setDraft("");
    } catch {
      // The transaction may have committed before readback failed. Do not retry blindly.
      setError("Save was not confirmed. Reload the saved note before trying again; your draft remains visible.");
    } finally { setSaving(false); }
  }
  if (loading) return <p role="status">Loading your private note…</p>;
  return <div className="mt-2 space-y-2">
    <p className="text-[10px] text-muted-foreground">Your private note · not published to the client</p>
    {error && <p role="alert" className="text-xs text-destructive">{error}</p>}
    {editing ? <form onSubmit={(event) => { event.preventDefault(); void save(); }} className="space-y-2">
      <Textarea aria-label="Your internal note" value={draft} maxLength={12000} rows={4} disabled={saving || !!error} onChange={(event) => setDraft(event.target.value)} />
      <div className="flex gap-2"><Button type="submit" size="sm" disabled={saving || !!error}>{saving ? "Saving…" : "Save note"}</Button>
      <Button type="button" size="sm" variant="ghost" disabled={saving} onClick={() => { setEditing(false); setDraft(""); }}>Cancel</Button></div>
    </form> : <>
      <p className="whitespace-pre-wrap break-words text-xs">{saved ? saved.body || "Note cleared." : error ? "Saved note unavailable." : "No saved note for this revision."}</p>
      {saved && <p className="text-[10px] text-muted-foreground">Version {saved.version_number} · {saved.saved_at}</p>}
      <Button type="button" size="sm" variant="ghost" disabled={!!error} onClick={() => { setDraft(saved?.body ?? ""); setRequestKey(crypto.randomUUID()); setEditing(true); }}>Edit my note</Button>
    </>}
    {error && <Button type="button" size="sm" variant="outline" disabled={saving} onClick={() => setReload((value) => value + 1)}>{editing ? "Reload and discard draft" : "Reload saved note"}</Button>}
  </div>;
}
