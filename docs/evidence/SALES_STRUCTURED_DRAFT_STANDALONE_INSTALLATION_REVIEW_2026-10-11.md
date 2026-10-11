# Sales structured-draft standalone installation review — 2026-10-11

## Status and hard boundary

**PREPARED FOR REVIEW ONLY. Nothing in this package has been executed against backend `yyrvduosyyaluifqvwkr`.** It does not apply a migration, change a policy/grant/binding/user, upload an object, alter the migration journal, retry the installer, or publish.

This is a four-file standalone SQL package pinned to reviewed commit `dd19219ff5248f308e9e7917f37bbdb9ae38033e`. It deliberately excludes every historic Drizzle migration (`0000`–`0016`) and every unrelated pending source file. It must never be substituted for migration-history reconciliation.

## Exact reviewed source manifest

Apply only in this order and only when the content SHA-256 matches:

| Order | Source path | SHA-256 |
|---:|---|---|
| 1 | `supabase/pending/20261009_sales_opportunity_structured_draft_metadata.sql` | `c69253e49431844fc4ac08df2bf450378965bee01499ef6d37df1451f5bcc65f` |
| 2 | `supabase/pending/20261011_sales_opportunity_structured_draft_audit_location.sql` | `731837c077b6a1b83a7c74a1a0e1a5b0649f4779d752e55705e0f61b9fb4b090` |
| 3 | `supabase/pending/20261011_sales_opportunity_structured_draft_materialization.sql` | `368324a32f498c719bfd425edfb528ab27de3b1ffe302d5b5e08068aa5795c15` |
| 4 | `supabase/pending/20261011_sales_opportunity_structured_draft_materialization_activation.sql` | `dc3809675ccbe1eb886eae6e879e6cf8638fcc6955565f541883b64b8b776f2e` |

Source verification performed on 2026-10-11: each working-tree file matches the byte-for-byte content from the reviewed commit above.

## Read-only preconditions

All checks below must be read-only and must complete before an action-time approval. Any false/zero/error result stops execution.

1. **Capability.** The operator has an explicitly supported, transaction-capable targeted SQL deployment route that can apply these exact four files without discovering/replaying `0000`–`0016`, mutating `drizzle.__drizzle_migrations`, or marking any history as applied. The current migration runner does **not** supply this route: it prepends historical `0000`, conflicts with live `public.organizations`, and has no targeted/skip-history mode.
2. **Schema.** Existing prerequisites are present and compatible: Sales opportunity/Master/version tuple, `customers`, `departments`, `drive_nodes`, `drive_node_revisions`, `document_control_registers`, `storage.objects`, `has_permission`, `has_any_permission`, `can_access_department_drive`, and the current project-drive policy set.
3. **Pinned source.** Read-only verification found exactly one existing `OPPORTUNITY-2026-0013`, one matching `MASTER-2026-0001`, and one matching Master version `1`. None of the four proposed Sales tables exists yet, so there is no deployed metadata, private location, or document-location binding.
4. **Private location.** Before activation, an administrator must separately review and approve one active `STRUCTURED_DRAFT` location for the verified opportunity/customer tuple. It must bind a Sales department, a locked/non-trashed Drive root and target folder with valid ancestry, bucket `project-drive`, and exact prefix `sales/opportunity/<opportunity-uuid>/`. This package contains no inferred folder, prefix, department, project, or location insert; **no binding is presently installed**.
5. **Policy/ACL snapshot.** Capture the complete current definitions and role ACLs for the eight named `storage.objects` policies, the five entry-point functions, and any pre-existing `project_drive_*` policies immediately before execution. Stop if policy names/predicates or effective ACLs differ from the reviewed snapshot below.

## Reviewed policy and ACL delta

### Original snapshot that activation replaces

The activation file drops only these policy names from `storage.objects`:

- `project_drive_read`
- `project_drive_insert`
- `project_drive_update`
- `project_drive_delete`
- `Project teams read project files`
- `Project managers upload project files`
- `Project managers update project files`
- `Project managers delete project files`

It recreates the four named project policies with `bucket_id = 'project-drive'` and `name !~ '^sales/opportunity/'`, retaining the documented project/Engineering permission predicates. It adds Sales INSERT and SELECT policies constrained to a matching active location, actor-bound request/materialization, and `sales.manage`. It adds no Sales UPDATE or DELETE policy.

Adding a Sales-only policy without replacing these permissive policies is unsafe: permissive policies for a command combine with OR, so an existing broad project-drive policy could reach the reserved `sales/opportunity/` namespace.

### Exact authenticated entry-point grants

Activation grants `authenticated` EXECUTE only on:

1. `public.save_sales_opportunity_structured_draft_at_location(uuid, uuid, uuid, uuid, text, integer, jsonb, uuid, uuid)`
2. `public.resolve_sales_opportunity_structured_draft_location(uuid, uuid, uuid)`
3. `public.register_sales_opportunity_structured_draft_storage_attempt(uuid, uuid, uuid, uuid, text, text, text, bigint)`
4. `public.commit_sales_opportunity_structured_draft_materialization(uuid, uuid, uuid, uuid, text, text, text, text, bigint)`
5. `public.can_discard_sales_opportunity_structured_draft_object(uuid, uuid, uuid, uuid, text, text)`

No other authenticated function EXECUTE grant appears in the activation source. Internal helpers and the base save wrapper remain non-public as defined by the preceding sources. New public-schema tables carry explicit service-role grants; user-visible read tables carry the exact authenticated SELECT grants in their creating source.

## Transaction boundary and post-install verification

The deployment capability must run all four sources as one transaction: commit only after all DDL, RLS, policy replacement, and five grants succeed; roll back all four on any failure. Do not insert the approved location binding in that transaction or as an implicit side effect.

After a committed schema installation and separately approved location binding, use caller-authenticated managed acceptance—not local fixtures—to verify:

- the exact opportunity/Master/version-1 source pin and approved location;
- Save/reload/history/download/retry behavior;
- SHA-256 and size checks, immutable materialization/audit/receipt history, exact replay, conflict, stale-source and unauthorized denial;
- Sales isolation from unrelated prefixes and preservation of non-reserved project/Engineering access; and
- direct-write and update/delete denial outside the five entry points.

Local harnesses are supporting evidence only. Re-run `run_sales_opportunity_structured_draft_audit_location_local_acceptance.sh` and `run_sales_opportunity_structured_draft_materialization_local_acceptance.sh` only if one of the four source files changes.

## Safe rollback limitations

A failed single transaction can roll back the four source files completely. After commit, automatic rollback is **not safe**: immutable history, materializations, Drive revisions, controlled-register rows, receipts, or uploaded bytes may already exist. A post-commit rollback requires a separately reviewed, data-aware remediation plan that preserves history and must not drop tables, delete files, or restore broad storage policies blindly. The activation policy replacement must be restored only from the immediately captured original definitions after verifying no Sales-prefix objects or receipts rely on the new policies.

## Required supported execution capability

This package needs a human-approved, audited backend operator capability to execute the exact four SHA-pinned SQL files in one explicit transaction against `yyrvduosyyaluifqvwkr`, with an allowlist of those paths, no migration discovery, no historical replay, no journal writes, and an abort-before-commit facility. The missing capability is a tooling limitation, not a missing source approval. Existing runner behavior is insufficient and must not be retried.
