import { useEffect, useState } from "react";
import { useAuth } from "@/hooks/useAuth";
import { highlightDraftAvailability, type HighlightDraftReceipt, type HighlightDraftScope } from "@/lib/requirement-highlight-drafts";
import { readOwnRequirementHighlightDraft, saveOwnRequirementHighlightDraft } from "@/lib/requirement-highlight-drafts.functions";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";

export function OwnFeasibilityHighlightDraftEditor({ scope }: { scope: HighlightDraftScope }) {
  if (!highlightDraftAvailability.available) return <p className="text-xs text-muted-foreground">{highlightDraftAvailability.reason}</p>;
  return <AuthenticatedNote scope={scope} />;
}
function AuthenticatedNote({ scope }: { scope: HighlightDraftScope }) {
  const { user, loading } = useAuth();
  if (loading) return <p>Checking sign-in…</p>;
  if (!user) return <p>Sign in to read your private highlight draft.</p>;
  // Identity isolates local state only. All access decisions remain in the protected RPC.
  return <NoteForm key={[user.id, scope.reviewId, scope.sourceRevisionId, scope.masterVersionId].join(":")} scope={scope} />;
}
function NoteForm({ scope }: { scope: HighlightDraftScope }) {
  const [saved, setSaved] = useState<HighlightDraftReceipt | null>(null);
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
    readOwnRequirementHighlightDraft({ data: scope }).then((note) => {
      if (active) setSaved(note);
    }).catch(() => {
      if (active) setError("Could not read your draft. Access or source may have changed.");
    }).finally(() => { if (active) setLoading(false); });
    return () => { active = false; };
  }, [scope.reviewId, scope.sourceRevisionId, scope.masterVersionId, reload]);
  async function save() {
    if (saving || error || loading) return;
    setSaving(true);
    try {
      const note = await saveOwnRequirementHighlightDraft({ data: { ...scope, expectedVersion: saved?.version_number ?? 0, body: draft, requestKey } });
      setSaved(note); setEditing(false); setDraft("");
    } catch {
      // The transaction may have committed before readback failed. Do not retry blindly.
      setError("Save was not confirmed. Reload the saved draft before trying again; your draft remains visible.");
    } finally { setSaving(false); }
  }
  if (loading) return <p role="status">Loading your highlight draft…</p>;
  return <div className="mt-2 space-y-2">
    <p className="text-[10px] text-muted-foreground">Private highlight draft · saving does not publish or notify the client</p>
    {error && <p role="alert" className="text-xs text-destructive">{error}</p>}
    {editing ? <form onSubmit={(event) => { event.preventDefault(); void save(); }} className="space-y-2">
      <Textarea aria-label="Your highlight draft" value={draft} maxLength={12000} rows={4} disabled={saving || !!error} onChange={(event) => setDraft(event.target.value)} />
      <div className="flex gap-2"><Button type="submit" size="sm" disabled={saving || !!error}>{saving ? "Saving…" : "Save draft"}</Button>
      <Button type="button" size="sm" variant="ghost" disabled={saving} onClick={() => { setEditing(false); setDraft(""); }}>Cancel</Button></div>
    </form> : <>
      <p className="whitespace-pre-wrap break-words text-xs">{saved ? saved.body || "Draft cleared." : error ? "Saved draft unavailable." : "No saved highlight draft for this revision."}</p>
      {saved && <p className="text-[10px] text-muted-foreground">Version {saved.version_number} · {saved.saved_at}</p>}
      <Button type="button" size="sm" variant="ghost" disabled={!!error} onClick={() => { setDraft(saved?.body ?? ""); setRequestKey(crypto.randomUUID()); setEditing(true); }}>Edit highlight draft</Button>
    </>}
    {error && <Button type="button" size="sm" variant="outline" disabled={saving} onClick={() => setReload((value) => value + 1)}>{editing ? "Reload and discard draft" : "Reload saved draft"}</Button>}
  </div>;
}
