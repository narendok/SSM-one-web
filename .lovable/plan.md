# Project BOM candidate-part workflow

## Outcome
Allow a member of a committed project to select an existing inventory component or submit a new candidate part from the BOM editor. A new candidate is not an inventory component until Hardware approves it. Purchase can read only the post-Hardware handoff.

## Scope
- Keep existing component lookup intact.
- Reuse `ComponentFormDialog` fields in a proposal-only mode.
- Restrict the new action to the committed project BOM surface; settings and uncommitted Sales previews remain unchanged.
- Persist submissions, decisions, promotion receipts, and audit events through protected, idempotent database contracts.
- Add Hardware and Purchase read queues using the existing department-workspace patterns.

## Backend contract
- Add an additive component-proposal entity scoped to an explicit project and Hardware department. It stores the candidate payload, submitter, revision, and explicit status.
- Add append-only decision/event and request-receipt records. Every submit, decision, and promotion takes a caller-supplied request key, validates actor and canonical payload, serializes the target row, records an audit event, and replays only the same actor/payload result.
- Submission requires authenticated project-manager authority and verified active project-team membership; it never derives a project from a Sales opportunity or a null department.
- Hardware approval/rejection requires the new `engineering.approve` permission plus active membership in the Hardware department; submitters cannot approve their own candidate.
- Purchase receives read-only rows only in the post-Hardware `APPROVED_PENDING_PURCHASE` state. The submitter and Hardware retain their own scoped visibility.
- Promotion runs only from an approved candidate through a protected transaction, creates the inventory component without stock/location/project/substitute/provenance side effects, records the promoted component ID, and cannot be repeated.

## Frontend
- Add `ComponentFormDialog` proposal mode with a separate callback and no immediate component, stock, location, project, substitute, provenance, or delete operation.
- In the committed project BOM editor, add a new-part action per scratch row. On successful proposal submission, preserve the row and show the pending state; do not replace manual values or infer prices, stock, package, sourcing, qualification, or ownership.
- Add a Hardware review queue with approve/reject actions and a Purchase read-only handoff queue.

## Validation
- Add pure payload/status tests, dialog proposal-mode tests, project-BOM integration tests, and protected server-function tests.
- Add migration acceptance coverage for denied callers, project/dept scope, self-review denial, request replay mismatch, revision conflicts, rollback, immutable events, duplicate promotion, and caller-RLS read visibility.
- Run focused tests, `tsgo --noEmit`, build, and a clean diff check. Browser acceptance remains separate.

## Technical details
```text
Committed project BOM
  ├─ existing inventory component → select only
  └─ new candidate → submit → PENDING_HARDWARE_REVIEW
                              ├─ reject → REJECTED
                              └─ approve → APPROVED_PENDING_PURCHASE
                                               └─ protected promotion → PROMOTED
```

New records use explicit grants plus RLS. Database functions use `SECURITY DEFINER`, fixed `search_path`, authorization before receipt replay, row locks, canonical payload hashes, transaction-local audit inserts, and explicit function grants.
