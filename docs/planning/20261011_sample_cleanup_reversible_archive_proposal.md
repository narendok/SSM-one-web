# Reversible sample-data archive proposal — review only

## Status

No supported, end-to-end archive/restore contract has been verified for the candidate records. This proposal is deliberately not executable and does not authorize any change.

## Retained anchor

`OPPORTUNITY-2026-0013` / `MASTER-2026-0001` revision 1, including its one structured draft, revision, request receipt, audit event, materialization, materialization audit, private object, Drive revision, and document register, is excluded permanently from the candidate set.

## Exact reviewed candidates

- Controlled requirements by display number only: `CUSTOMER-2026-0003` through `CUSTOMER-2026-0007`. These are `customer_requirements.requirement_number` values, not customer IDs. The inspected records are draft `testcust` items for the existing ITL Sonalika customer; the customer record is never an archive target.
- Sales opportunities by display number only: `OPPORTUNITY-2026-0006` through `OPPORTUNITY-2026-0010`. The five inspected records have the matching synthetic title, but the number list—not title—is the selector.
- `OPPORTUNITY-2026-0013` / `MASTER-2026-0001` revision 1 and its saved history are retained even though its name/customer resemble the synthetic candidates.
- The exact read-only inventory is `docs/planning/20261011_sample_cleanup_inventory_read_only.sql`.

## Read-only evidence at review time

- The five requirement candidates each have one immutable requirement revision; no feasibility review, commercial record, baseline, change request, project, handover, portal-share, or activity dependency was returned by the focused read.
- The five opportunity candidates have no requirement, Master Specification, NDA, document-location, structured-draft, request, materialization, or project dependency in the focused read.
- These counts are point-in-time evidence only. The archive transaction must re-read exact IDs under lock and fail closed if any count, status, source number, or shared relation has changed.

## Dependency gate

For each proposed candidate, record exact current counts and IDs for master specifications, requirements and revisions, locations, structured drafts and revisions, request receipts, audit events, storage attempts, materializations and audits, Drive nodes and revisions, document-control registers, baselines, handovers, project tasks, and project-owned records. A non-zero dependency is a review stop, not permission to archive it.

## Concrete additive archive/restore contract — review only

1. Add root-only archive metadata to `sales_opportunities` and `customer_requirements`: `archived_at`, `archived_by`, and an immutable manifest key. Do not overload operational `status`, which drives existing workflow behavior.
2. Add append-only archive manifests and items recording actor, reason, ordered exact root IDs/display numbers, preflight dependency snapshot, request key, action (`ARCHIVE`/`RESTORE`), and result. Manifest items must carry the original root state and relationship snapshot; no dependent row or storage object is moved, deleted, or rewritten.
3. Provide one protected transaction that accepts only the reviewed root kind, display-number/UUID pair, reason, and request key. It must derive the caller, lock roots in deterministic number order, reject `OPPORTUNITY-2026-0013`, `MASTER-2026-0001` rev 1 lineage, non-draft requirements, non-new synthetic opportunities, mismatched display number, title-only requests, shared customer archival, non-zero unsupported dependencies, duplicate IDs, and changed dependency snapshots.
4. Archive changes only root metadata after the preflight snapshot and manifest write are atomically accepted. Replay of the same request key with identical actor/payload returns the original manifest; changed replay conflicts without mutation. A failure at any point rolls back manifest and root changes together.
5. Restore uses the archived manifest key plus the same root number/UUID pairs. It re-locks and rechecks the snapshot, refuses retained/shared/changed roots, restores only the recorded root metadata, and writes an append-only restore manifest. Archive and restore never delete a root, relationship, revision, review, approval, baseline, project, portal item, Drive node, register, private object, or history.
6. Read-model filtering must add `archived_at IS NULL` only to ordinary Sales and controlled-requirement list/search views. Direct lookup and audit/history views remain able to resolve archived roots through the protected caller-authorized archive read model; no client-side hiding and no RLS broadening.

## Required acceptance before activation

- Exact duplicate/replay, conflicting replay, mixed eligible/ineligible batch rollback, retained-anchor denial, title-only denial, mismatched number/UUID denial, revocation-before-commit denial, concurrent archive/restore serialization, audit immutability, and caller-scoped archive/history reads.
- Dependency mutation between preflight and lock, archive with a new dependent relationship, restore after dependency drift, and attempts to archive the real ITL Sonalika customer must all fail without mutation.
- Test fixtures must be isolated; this proposal neither creates nor authorizes fixtures, users, bindings, or live execution.

## Current gap

`drive_nodes.is_trashed` exists, but it is not an approved archive mechanism for Sales opportunities, structured draft history, registers, or their private storage. No existing supported root-level archive/restore contract was found. The contract above is a reviewed source design only: no SQL migration, permission, read-model change, archive, restore, or cleanup execution has occurred.