# BOM candidate review workflow — isolated acceptance matrix

**Status:** pending design review only. This is not executable, creates no
identities, and must not target a shared or live backend.

## Preconditions

- Isolated fixtures already contain an authorized opportunity, pinned immutable
  master revision, later committed matching project, existing component, and
  verified versioned Sales commercial record.
- Separate pre-existing submitter, Hardware reviewer, Purchase user, outsider,
  and administrator identities exist. Do not create users, roles, departments,
  permissions, or records for acceptance.
- A reviewed executable contract has explicit grants/RLS and protected actions;
  this proposal has neither.

## Matrix

| Area | Isolated caller action | Required result |
| --- | --- | --- |
| Existing inventory | Select RLS-visible component in BOM row | Established read only; no candidate or inventory mutation. |
| Pre-project submission | Submit valid form against authorized opportunity + master revision, no project | Pending candidate pins source; null project remains null; no inferred project/BOM/department. |
| Source denial | Use unauthorized, mismatched, retired, or stale source pair | Denied; no candidate, receipt, audit, or partial write. |
| Duplicate match | Submit exact normalized manufacturer+MPN | Visible existing reference offered deliberately; no automatic replacement or merge. |
| Fuzzy duplicate | Submit name/description/footprint similarity only | No automatic match, merge, or substitution. |
| Later linkage | Link to committed matching project | Explicit actor/time link; reject null or unrelated project. |
| Purchase scope | Amend before Hardware approval or verified project link | Denied with no amendment/evaluation/audit. |
| Cost evaluation | Amend unit cost/currency/unit/BOM quantity | Server reads projected volume and commercial ceiling/version; computes only compatible explicit units. |
| Unavailable commercial | Commercial/version/volume/ceiling/currency/unit/quantity unknown | `UNAVAILABLE` with explicit reasons; never within-ceiling or auto-approved. |
| Amendment invalidation | Amend after Hardware approval | Immutable append; historical approval retained; new Hardware decision required. |
| Hardware decision | Approve/reject/select explicit alternative | Verified scope, self-review denied, append-only decision. |
| Conflict/replay | Race revisions; repeat same request then alter actor/payload | Stale request conflicts; exact replay returns result; altered reuse denied. |
| Promotion | Promote finalized candidate, then replay/race | Narrow zero-stock adapter once; same component ID replays; no location, stock, project-link, substitute, or provenance effects. |
| Direct access/rollback | Attempt direct writes; force audit/receipt/component failure | RLS/grants deny direct writes; each protected action rolls back fully. |

## Required transport/browser evidence

1. Execute through authenticated application transport, not fabricated JWT claims alone.
2. Capture authorization/conflict/replay outcomes without logging tokens or commercial values.
3. Prove proposal mode never imports or calls immediate `saveComponentWithStock`.
4. Existing picker browser acceptance remains pending and is not evidence for this workflow.