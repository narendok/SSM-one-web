# Structured Sales Draft Audit and Private Location Review

## Scope

`supabase/pending/20261011_sales_opportunity_structured_draft_audit_location.sql` extends the unapproved structured-draft metadata contract. It is source-only and must be reviewed together with `20261009_sales_opportunity_structured_draft_metadata.sql`.

## Verified existing objects reused

- `public.drive_nodes` is the existing private Drive tree metadata. It records `node_type`, `department_id`, `project_id`, lock/trash state, storage fields, and metadata; caller visibility is governed by `can_access_department_drive`.
- `public.drive_node_revisions` already records `storage_path` and optional `sha256_checksum` for actual uploaded Drive files.
- `public.activity_log` is not used for this transaction because authenticated actors can currently insert their own entries and it is not append-only. The proposal instead creates a protected immutable audit ledger.
- `storage.objects` has object metadata but no checksum column. This proposal creates no object and therefore never treats object metadata as upload success.

## Proposed transaction boundary

The protected wrapper first validates an active, administrator-provisioned private-location configuration and a locked, non-trashed Drive folder. It then delegates the exact source pin, authorization, replay, and optimistic revision work to the base protected routine. Before returning it atomically writes:

1. the immutable revision-to-location record, with the canonical payload SHA-256;
2. the immutable audit event keyed to the same request receipt.

Any failure rolls back the base revision and request receipt. Exact replay verifies the original actor, revision, checksum, source fingerprint, and private location; a changed location fails closed.

`NOT_MATERIALIZED` is deliberate. The recorded checksum is the canonical JSON payload checksum only, not a file checksum and not proof that a Storage object exists.

## Deployment package still requiring approval

1. Apply the metadata migration, then this additive audit/location migration, in an isolated managed environment.
2. Independently review the selected locked Sales folder, its private bucket and prefix, and the administrator-provisioned location row. No folder, bucket, prefix, or policy is inferred by this package.
3. Approve a narrowly scoped authenticated `EXECUTE` grant for the new wrapper only after caller-authenticated acceptance. The base and wrapper functions remain revoked by default.
4. Approve a separate materialization/issuance contract before any Storage upload, Drive revision, controlled-register record, document number, download, approval, or release.