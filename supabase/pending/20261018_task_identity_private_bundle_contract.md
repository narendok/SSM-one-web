# Private task identity atomic bundle — review only

NOT INSTALLED. No application grants, wrappers, task authority, UI activation or backfill. Original backend only. Specific installation approval remains required; this file is not approval.

## Artifact and reproducibility

20261018_task_identity_private_bundle_review_only.sql composes the three private identity/steward/readback-withdrawal drafts inside one BEGIN/COMMIT. Original drafts remain review inputs; do not install them separately as a purported atomic bundle. tests/task_identity_bundle_source.mjs deterministically composes LF-normalized source hashes and a whole-bundle postflight. Native acceptance compares the tracked bundle against that composition before executing it.

Postflight requires exactly three private tables and four private functions, expected table ownership/RLS, exact function signatures/installer ownership/SECURITY DEFINER/pinned search_path, no effective schema/table/function access for anon/authenticated/service_role and no private-table rows. Existing public source data/grants/policies are not changed. Existing source prerequisite checks still apply. Structural role-helper checks do not prove helper semantics or caller authorization.

## Local acceptance

Exact bundle passed native PostgreSQL 17.10 synthetic fixtures. An injected exception immediately before final COMMIT rolled back all private schema objects with no business audit rows; a normal install then passed all previous mapping, history, audit binding, readback, withdrawal, rollback, same-key overlap, queued-role removal, queued-membership removal and delayed-transaction chronology tests. Reapplying the bundle fails closed on an existing private schema. Initial failure-injection test used an incorrectly escaped JavaScript replacement; corrected the harness to preserve SQL dollar quoting before the passing run. No managed execution occurred. Evidence: docs/evidence/20261018_task_identity_atomic_bundle_native17.txt.

## Deployment and recovery boundary

Before requesting installation, review fresh original-target compatibility and proposed one-to-one identity stewardship semantics, helper implementation and the separate scoped task capability/write contract. No installed identity is inferred or auto-matched by email/name.

The installation unit is the complete transaction. Failure before COMMIT must leave no new schema; independently inspect committed metadata rather than trusting the last SQL-editor status. If an unexpected state is found after commit, preserve objects/history and keep all application execution denied; do not DROP, reset, delete rows or restore historical direct writes. Any corrective managed change requires its own reviewed scope/approval. Existing task/public schema is not a restoration target because this bundle does not alter it.

This package does not establish ordinary JWT/RLS acceptance, broad permission/membership race acceptance, department lead editing, assignment/unassignment, shared remarks, client highlights or publication. Those remain separate gated work.
