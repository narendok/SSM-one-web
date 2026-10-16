# Private highlight drafts — pending source only

Requires the pending internal-note proposal's requirement_review_private_draft_context helper. That helper now centralizes the existing exact-source assigned reviewer/engineering permission/active department membership checks and requirement-root locking. Internal-note save/read reuse it; existing note, caller, rollback, repin and concurrent-save tests still pass.

Highlight drafts are physically separate from internal notes, with their own per-author/review/requirement-revision/Master version counter, optimistic conflict and actor/payload-bound request replay. Empty content is an explicit versioned clear. Audit records IDs/version, not text. Ordinary table/function access is revoked; no browser adapter or editor is enabled.

This is NOT client-visible publication. No publication record, client audience binding, recipient resolver, notification or copy-link authority is created. A future accepted publisher must bind exact immutable draft revision and client opportunity scope, preserve private data separation and create its protected audit/notification atomically. Existing private notes must never be copied automatically into drafts. Cross-department draft management and delegation are not implemented; current scope is the assigned reviewer only.

Local draft tests use owner execution plus synthetic auth helpers. Existing authenticated-role tests cover the shared private authority through note functions, not a live highlight RPC. Dedicated highlight caller/rollback/concurrency and target installation/restore/ordinary JWT acceptance remain pending. No managed deployment or permission changes authorized.
