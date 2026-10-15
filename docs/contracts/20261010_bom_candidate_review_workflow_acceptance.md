# BOM candidate review workflow — isolated acceptance matrix

**Status:** Hardware decision, cost, promotion, UI, and managed-install scope
remain pending. Submission-only now has an unapplied local contract at
`supabase/pending/20261011_bom_candidate_submission.sql`; it remains disabled
until separate managed authorization and RLS acceptance.

## Preconditions

- The submission-only local fixture contains a project-linked authoritative BOM,
  matching customer/opportunity/requirement lineage, `project_initiated`
  approved baseline, and `completed` exact-project handover. It never creates
  or changes application records.
- Separate pre-existing submitter, Hardware reviewer, Purchase user, outsider,
  and administrator identities exist. Do not create users, roles, departments,
  permissions, or records for acceptance.
- A reviewed executable contract has explicit grants/RLS and protected actions;
  this proposal has neither.

## Matrix

| Area | Isolated caller action | Required result |
| --- | --- | --- |
| Existing inventory | Select RLS-visible component in BOM row | Established read only; no candidate or inventory mutation. |
| Committed-project submission | Submit a canonical candidate payload from the project manager who is an active employee-backed team member | Pending candidate pins project/BOM/customer/opportunity/baseline/completed-handover/Hardware-department source; Sales proposal stays unchanged. |
| Source denial | Use unauthorized, mismatched, stale, or non-committed project/BOM source | Denied; no candidate, receipt, audit, or partial write. |
| Duplicate match | Submit exact normalized manufacturer+MPN | Visible existing reference offered deliberately; no automatic replacement or merge. |
| Fuzzy duplicate | Submit name/description/footprint similarity only | No automatic match, merge, or substitution. |
| Purchase scope | Add cost from a committed-project candidate before final Hardware decision | Purchase-scoped cost is accepted only in its eligible state; unrelated or post-finalization writes are denied. |
| Cost evaluation | Add unit cost/currency/unit/BOM quantity | Server reads projected volume and commercial ceiling/version; computes only compatible explicit units before Hardware decides. |
| Unavailable commercial | Commercial/version/volume/ceiling/currency/unit/quantity unknown | `UNAVAILABLE` with explicit reasons; never within-ceiling or auto-approved. |
| Amendment invalidation | Amend after Hardware approval | Immutable append; historical approval retained; a new Hardware decision is required. |
| Hardware decision | Approve/reject/select explicit alternative | Verified scope, self-review denied, append-only decision. |
| Sales exception | Approve a ceiling exception | Only a rare explicit, separately authorized exception with short reason and immutable source link; never automatic. |
| Conflict/replay | Repeat same request then alter actor/payload | Exact replay returns the original persisted IDs; altered reuse is denied. Concurrency remains a future managed acceptance gate. |
| Promotion | Promote finalized candidate, then replay/race | Narrow zero-stock adapter once; same component ID replays; no location, stock, project-link, substitute, or provenance effects. |
| Direct access/rollback | Attempt direct writes; force audit/receipt/component failure | RLS/grants deny direct writes; each protected action rolls back fully. |

## Required transport/browser evidence

1. Execute through authenticated application transport, not fabricated JWT claims alone, before treating the pending submission contract as installed.
2. Capture authorization/conflict/replay outcomes without logging tokens or commercial values.
3. Prove proposal mode never imports or calls immediate `saveComponentWithStock`.
4. Existing picker browser acceptance remains pending and is not evidence for this workflow.