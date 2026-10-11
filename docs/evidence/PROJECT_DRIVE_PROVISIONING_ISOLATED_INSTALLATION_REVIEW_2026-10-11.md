# Project Drive Provisioning — Isolated Installation Review

**Status:** source-only review; no isolated or production connection, catalog query, installation, grant change, or application mutation was performed.

## Contract pin and scope

| Item | Value |
| --- | --- |
| Source proposal | `supabase/pending/20261005_harden_project_drive_provisioning_boundary.sql` |
| Full SHA-256 | `973af20c3877ab211680c2502bf235bc60576099a39d0b291d2b6a947d80a4c0` |
| Repository HEAD during local acceptance | `d128a52b0ce21d4c1b6fefa049c82093cd05127f` |
| Future preflight target only | isolated `egjotuxqguifnvdnflan` |
| Explicitly excluded | production `yyrvduosyyaluifqvwkr` |

The proposal replaces only `public.provision_project_drive_template(uuid)`. It does not create, alter, or drop a table, index, constraint, policy, trigger, type, or data row.

## Source contract reviewed

The replacement retains the `void` signature and is `LANGUAGE plpgsql SECURITY DEFINER SET search_path = public`. It acquires `pg_advisory_xact_lock(hashtextextended('project-drive:' || project_id, 0))`, locks the target project row, selects only non-trashed `FOLDER` candidates, and locks the selected parent/root. The project pointer is written with a compare-and-set condition: it may be NULL or already equal to the selected canonical root; a conflict raises instead of overwriting it.

It keeps the existing service-only access boundary:

```sql
REVOKE ALL ON FUNCTION public.provision_project_drive_template(uuid)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.provision_project_drive_template(uuid)
  TO service_role;
```

No new authenticated or anonymous execution path is proposed.

### Trigger and helper dependencies

- `public.provision_department_project_drive_folders()` calls the project provisioner after project insert or changes to `department_id` / `drive_project_class` (`supabase/migrations/20260930174414_879f34cc-8019-4817-9180-e6480a31d76d.sql:1-24`).
- The trigger is `public.provision_department_project_drive_folders_trigger` on `public.projects` (`:21-24`). The proposal does not replace it.
- The replacement invokes the existing service-only helpers `public.provision_department_drive_template(uuid)` and `public.provision_drive_category_template(uuid, uuid, text, uuid)` when a department exists (`pending proposal:32-42, 122-129`).
- The deployed-source helper definitions and service-only grants are in `supabase/migrations/20260930182746_38ace26c-20ec-45b8-aec8-babd0f34c73b.sql:40-132, 264-269`.

### Manual and historical root treatment

The proposal does not infer ownership from NULL department values, names, slugs, or arbitrary descendants. It accepts only a non-trashed `FOLDER` attached to the exact project and matching department scope, first as `PROJECT_ROOT`, then as a parentless fallback. It never repoints a conflicting `projects.project_drive_node_id`; it raises `Project Drive root pointer conflicts with the canonical root`. A trashed candidate is excluded. Failed calls remain transactional, so created root/folders/pointer writes are rolled back with the failure.

The source review found no proposal-level unique root constraint. Serialization and pointer compare-and-set are the protections in this replacement; the target must be checked for existing duplicate or stale roots before any approval.

## Executed local PostgreSQL 17.9 evidence

The fixture was disposable, private-socket PostgreSQL only. It supplied reduced `departments`, `projects`, and `drive_nodes` tables plus minimal deterministic helper implementations. Fixture-only `anon`, `authenticated`, and `service_role` roles existed solely to parse the unchanged grant lines. It did not install a project trigger, emulate managed RLS/JWT claims, or assert managed role/grant behavior.

| Evidence file | Purpose |
| --- | --- |
| `supabase/pending/tests/project_drive_provisioning_local_fixture.sql` | disposable prerequisite schema and helper stubs |
| `supabase/pending/tests/project_drive_provisioning_local_worker.sql` | second-session contention invocation |
| `supabase/pending/tests/project_drive_provisioning_local_acceptance.sql` | repeat, conflict, history, and rollback assertions |
| `supabase/pending/tests/run_project_drive_provisioning_local_acceptance.sh` | isolated cluster lifecycle and contention controller |

Exact successful command:

```text
bash -n supabase/pending/tests/run_project_drive_provisioning_local_acceptance.sh && supabase/pending/tests/run_project_drive_provisioning_local_acceptance.sh; status=$?; printf 'RUNNER_EXIT=%s\n' "$status"; exit "$status"
```

Result: exit `0`; `PROJECT_DRIVE_PROVISIONING_LOCAL_ACCEPTANCE_PASS=true`; `CLEANUP_VERIFIED disposable_fixture_removed=true`.

| Named assertion | Result |
| --- | --- |
| `repeat_same_root_pointer` | PASS: one pointer/root and eight standard folders after two calls |
| `deterministic_two_session_contention` | PASS: two workers exit `0/0`; root/folders/valid-pointer count `1/8/1` |
| `wrong_project_pointer_preserves_manual_history` | PASS: conflicting pointer and manual node unchanged; no project nodes written |
| `trashed_pointer_preserves_history` | PASS: trashed historical node/pointer unchanged; no replacement root written |
| `injected_failure_rolls_back_pointer_and_folders` | PASS: injected helper failure left NULL pointer and zero project nodes |

This is owner/service fixture proof of PostgreSQL transactional behavior for the pinned SQL. It is not managed JWT transport, caller RLS, service-role grants, trigger execution, catalog compatibility, or original browser acceptance. Existing browser evidence remains limited to read-only ProjectDialog rendering; no live create/update or provisioning outcome was submitted or verified.

## Required isolated preflight — no execution authorized

Before any separate approval could permit a preflight against **only** `egjotuxqguifnvdnflan`, an already-authorized connection must prove that exact target identity. Until then, target binding is absent and no catalog check is justified.

After identity proof, read-only preflight must capture:

1. Exact function identity, signature, owner, `prosecdef`, `proconfig` / search path, and grants for the replacement and both helper functions.
2. Trigger definition, enabled state, and function dependency for `provision_department_project_drive_folders_trigger` on `public.projects`.
3. Current `projects`, `drive_nodes`, and related constraint/index definitions required by the body: `project_drive_node_id`, `department_id`, `drive_project_class`, `project_id`, `parent_id`, `node_type`, `folder_kind`, `is_trashed`, `is_locked`, `metadata`, and `created_at`.
4. Duplicate/stale-root report limited to project-linked Drive nodes: multiple non-trashed `PROJECT_ROOT` folders, parentless fallback folders, pointers missing a node, pointers to another project, trashed pointers, mismatched department roots, and duplicates that sorting would select.
5. Existing project-trigger dependencies, protected Drive structure triggers, and any constraint/policy/function that can reject the proposal’s root/pointer/folder writes.
6. Category-template/helper availability and service owner capability, without invoking provisioning.

## Compatibility and rollback risks

- `CREATE OR REPLACE FUNCTION` preserves the signature but replaces function body behavior atomically; active triggers thereafter use the hardened behavior.
- Existing duplicate roots are not merged or deleted. The proposal selects the earliest non-trashed qualifying root, so historical ordering and pointer conflicts need review before installation.
- A project pointing to a stale, trashed, mismatched, or other-project root fails closed rather than being silently repaired. This protects history but can cause project insert/update or retry failures until a separately authorized remediation exists.
- The function’s `SECURITY DEFINER` owner and `search_path` must be verified on the isolated target; a mismatched owner, helper signature, or revoked dependency can block trigger-driven provisioning.
- No database schema change exists to roll back. Reversion would require restoring the previous function body only after assessing roots/pointers written under the hardened behavior; it cannot safely resolve pre-existing duplicate or manual ownership ambiguities automatically.

## Approval boundaries

This packet requests nothing and authorizes no action. Future approvals must be separate and scoped at least as follows:

1. **Target-bound read-only preflight:** only the verified isolated target; production remains excluded.
2. **Isolated installation and acceptance:** explicit approval after preflight, including trigger-path, service-role/grant, managed RLS/JWT non-regression, duplicate-root compatibility, rollback, and audited cleanup criteria.
3. **Any production consideration:** a new review and approval; this artifact neither covers nor proposes it.