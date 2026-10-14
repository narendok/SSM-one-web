# Sales feasibility handover replay-locking source review — 15 October 2026

Status: source-only and disposable-local verification. No managed database, grant,
policy, record, UI, or deployment operation is included.

## Repair

The pending handover replay now acquires `FOR SHARE` locks on existing mutable
facts that it validates before returning a replay: the current Master version,
selected departments, selected employees and memberships, the pinned
requirement/revision, and every existing review in the pinned requirement graph.
The lock order is request key, receipt, enquiry/opportunity/specification/version,
departments, employees/memberships, requirement/revision, then review rows.

This blocks ordinary non-key updates to those selected existing rows while a replay
is validating them. It does not claim to secure direct writes or new-row phantoms.

## Required disposable schedules

1. **Replay-held:** replay reaches the graph validation barrier and holds its shared
   review lock; a separate session issues a plain `UPDATE` to the review workstreams.
   The writer cannot commit before replay releases its lock. Replay returns only the
   original pinned identities.
2. **Writer-held:** a separate session first performs a plain `UPDATE` and holds the
   row transaction; replay waits for the writer, then sees the changed workstreams
   and rejects with `Review graph has changed since this receipt was issued`.

The harness uses database advisory barriers for deterministic sequencing. It does
not use an artificial prior `SELECT ... FOR UPDATE` or timing sleeps as the sole
coordination mechanism.

## Writer/root compatibility update

The source-only inventory is recorded in
`20261015_sales_feasibility_handover_writer_root_lock_inventory.md`. Handover replay and
the pending protected assignment/response routines now share an advisory key derived from
the requirement ID. Disposable same-key replay, different-key assignment, and guarded
new-review insertion schedules passed. This covers only writers that opt into that key.

## Remaining blocker

Existing-row locks cannot stop a new review row inserted by a writer that bypasses the
requirement-root protocol or any direct table writer. Before installation, every real
review/assignment writer must adopt one accepted root serialization or predicate-safe
guard at the requirement root, and direct-write/RLS denial must be proven under
production-like roles. Until then, the handover action remains disabled.
