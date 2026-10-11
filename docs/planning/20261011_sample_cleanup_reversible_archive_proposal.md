# Reversible sample-data archive proposal — review only

## Status

No supported, end-to-end archive/restore contract has been verified for the candidate records. This proposal is deliberately not executable and does not authorize any change.

## Retained anchor

`OPPORTUNITY-2026-0013` / `MASTER-2026-0001` revision 1, including its one structured draft, revision, request receipt, audit event, materialization, materialization audit, private object, Drive revision, and document register, is excluded permanently from the candidate set.

## Known candidate selectors

- Sales opportunities with names containing `SAMPLE ONLY` or `SYNTHETIC ONLY`, excluding `OPPORTUNITY-2026-0013`.
- Projects with names containing `SAMPLE ONLY` or `SYNTHETIC ONLY`.
- The read-only inventory is `docs/planning/20261011_sample_cleanup_inventory_read_only.sql`.

## Dependency gate

For each proposed candidate, record exact current counts and IDs for master specifications, requirements and revisions, locations, structured drafts and revisions, request receipts, audit events, storage attempts, materializations and audits, Drive nodes and revisions, document-control registers, baselines, handovers, project tasks, and project-owned records. A non-zero dependency is a review stop, not permission to archive it.

## Narrow reversible behavior, if a supported contract is later approved

1. Create an immutable archive manifest containing the candidate IDs, observed dependency IDs/counts, actor, timestamp, explicit reason, and restore key.
2. Mark only eligible sample roots as archived through an existing audited business workflow. Do not delete rows or storage objects; do not mutate retained anchors or shared dependencies.
3. Hide archived roots only where the existing read path supports that state. Do not retrofit broad filters or weaken access controls.
4. Restore only by the manifest restore key after re-reading each dependency and rejecting changed/shared/retained references.
5. Replay the same archive or restore key idempotently; conflicting payloads fail without mutation.

## Current gap

`drive_nodes.is_trashed` exists, but it is not an approved archive mechanism for Sales opportunities, structured draft history, registers, or their private storage. No existing supported root-level archive/restore contract was found. Therefore there is no proposed SQL mutation, no migration, and no cleanup execution.