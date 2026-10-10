# Sales Atomic Intake — Isolated Managed Acceptance Review Bundle (2026-10-10 UTC)

Status: **review only — no installation, grant, identity, data, or remote change is authorized by this document.**

## Target boundary

- **Candidate isolated backend:** `egjotuxqguifnvdnflan`. Repository evidence identifies it as the unpublished synthetic acceptance copy used by other isolated acceptance material.
- **Suitability:** **not yet verified for this contract.** Before any installation, the designated operator must complete the read-only preflight below. If it does not prove compatibility, stop; do not substitute a different backend.
- **Original backend:** `yyrvduosyyaluifqvwkr` is explicitly excluded. It must receive no SQL, grants, fixture data, identity changes, or acceptance traffic.

## Exact reviewed source pins

| Item | Path | SHA-256 |
| --- | --- | --- |
| Pending atomic contract | `supabase/pending/20261010_sales_atomic_intake_replay.sql` | `7de31684e508b2628e51cb9fa4f290df8bb0eed1275cc0ec167301132edc2f17` |
| Managed isolated acceptance specification | `supabase/pending/tests/sales_atomic_intake_replay_acceptance.sql` | `26e23de142f39112e072f1313badb63b32e44642ce07852ca29451bcfde74d9b` |
| Local coordinated acceptance runner | `supabase/pending/tests/run_sales_atomic_intake_local_race_acceptance.sh` | `f550a782c55fd3dd27520c6d2d4760a6845429733a5a48216c3d39432bf90f0a` |
| Local failpoint acceptance | `supabase/pending/tests/sales_atomic_intake_replay_local_failpoint_acceptance.sql` | `5dc95d3f01b6781fcdbe6a8e2c3d0a6a19bec1cf3679af17bc2f2a121296d7e8` |
| Local lock holder | `supabase/pending/tests/sales_atomic_intake_replay_local_lock_holder.sql` | `e5a8137a4f1e089e6bdaa34e5f6b678d8721ae9399698375cbec5a10c04d0b1a` |
| Local lock worker | `supabase/pending/tests/sales_atomic_intake_replay_local_lock_worker.sql` | `f000308592bdd6c416f098bbf95bea46355b6467faa8c2b1488a64aa2cc56537` |
| Local execution evidence | `docs/evidence/SALES_ATOMIC_INTAKE_LOCAL_SYNTHETIC_EXECUTION_2026-10-10.md` | cfb356e8f408e06f83c22fd5496866530d0e1d4ab49456214817b33f2f832153 |

Any content/hash mismatch is a stop condition requiring a new review.

## Reviewed installation inventory

The pending SQL is additive and creates/replaces only these objects:

1. `public.sales_opportunity_intake_receipts` table, its constraints, foreign keys, RLS enablement, and owner-only authenticated SELECT policy.
2. `public.sales_opportunity_intake_canonical_payload(uuid, uuid, uuid, jsonb)` private canonicalization helper.
3. `public.create_sales_opportunity_with_initial_master_specification(uuid, uuid, uuid, jsonb, uuid)` protected atomic intake action.
4. `public.lookup_sales_opportunity_intake_receipt(uuid)` protected actor-bound receipt lookup.

It writes only through the existing opportunity, Master Specification, version, and activity-log contracts after source validation; it does not add users, roles, projects, requirements, documents, notifications, UI wiring, or background work.

### Default deployed access state

The proposal explicitly:

- revokes all direct receipt-table access from `PUBLIC`, `anon`, `authenticated`, and `service_role`, then grants only `SELECT` to `service_role`;
- enables RLS and provides authenticated owner-read only when `requested_by = auth.uid()` and `sales.manage` still holds;
- revokes all three function signatures from `PUBLIC`, `anon`, `authenticated`, and `service_role`.

Thus, installing the reviewed contract alone leaves the new RPCs and receipt transport inaccessible to ordinary callers. This is intentional.

## Separately proposed, not included, transport decision

Only after successful deployed isolated acceptance, a separate narrowly reviewed migration may consider:

```sql
GRANT EXECUTE ON FUNCTION public.create_sales_opportunity_with_initial_master_specification(uuid, uuid, uuid, jsonb, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.lookup_sales_opportunity_intake_receipt(uuid) TO authenticated;
```

No grant is proposed for the canonical helper or direct receipt mutations. These two statements are **not approved by this document** and must not be applied as part of contract installation unless a later approval explicitly includes them.

### Caller matrix to prove on the isolated backend

| Caller | Existing prerequisite | Contract expectation | Transport state to test |
| --- | --- | --- | --- |
| Active non-admin Sales manager | Existing `sales.manage`; valid RLS-visible customer/contact/enquiry | Valid create, exact same-actor replay, own receipt lookup; source mismatch/conflict denied | First prove default denial; after separately approved grant, prove real authenticated caller path |
| Active non-Sales user | No `sales.manage` | Intake and lookup denied with no writes; direct receipt/table mutation denied | Default and, if granted, authenticated transport |
| Different Sales manager | Existing `sales.manage` | Cannot replay or lookup another actor's receipt; same key with other actor denied | Only after separately approved grant |
| Administrator | Not sufficient evidence by itself | May observe only if needed for read-only preflight/teardown; cannot substitute for non-admin proof | No acceptance success may rely solely on administrator behavior |

## Identity availability gate

No identity may be created, edited, promoted, assigned a role, or granted a permission under this review. Before installation, an operator must provide a read-only availability record for already-approved isolated identities showing:

- one active non-admin user with the existing `sales.manage` capability;
- one active user without `sales.manage`;
- if replay actor-isolation is exercised, an already-approved second non-admin Sales manager;
- normal authenticated application transport for each relevant caller.

Absent any one of these facts, managed acceptance is blocked. JWT claim injection or an administrator-only identity is not acceptable substitute evidence.

## Required read-only preflight

Before any approval card or write, capture and review only:

1. Target identity: backend ref exactly `egjotuxqguifnvdnflan`; original ref excluded.
2. Current schema compatibility: exact column/constraint/trigger/function signatures for `customers`, `customer_contacts`, `sales_enquiries`, `sales_opportunities`, `master_specifications`, `master_specification_versions`, `activity_log`, `document_numbering_config`, `has_permission`, `next_business_number`, and the opportunity-number trigger.
3. Existing RLS/policy and grants for customer/contact/enquiry source reads and existing opportunity/specification writes; confirm the expected global `sales.manage` source visibility rather than inferring ownership.
4. Object absence/non-conflict: receipt table and the three exact function signatures are absent, or an approved identical prior installation is proven with hashes/signatures.
5. Existing approved identity availability above, without exposing credentials or tokens.
6. Ability to observe only acceptance-created IDs/numbers and to remove those known fixture rows transactionally or through an approved isolated teardown procedure.

Preflight failure, divergent schema, pre-existing conflicting object, or unclear identity authorization is a stop condition.

## Executed local evidence and its limit

`docs/evidence/SALES_ATOMIC_INTAKE_LOCAL_SYNTHETIC_EXECUTION_2026-10-10.md` records actual disposable PostgreSQL 17.9 execution: specification/version/receipt failpoint rollback, advisory-lock wait then revocation denial for new/replay cases, same-key exact-replay convergence, changed-payload/actor conflict, and different-key uniqueness.

It is useful behavior evidence only. It does **not** establish managed schema compatibility, deployed policy behavior, caller JWT transport, approved grants, or isolated backend identity availability.

## Managed acceptance and cleanup shape

If a later approval authorizes installation and, separately, transport grants:

1. Record preflight output and source hashes; stop on any mismatch.
2. Install only the reviewed contract on the isolated backend, retaining default function revocations.
3. Verify default RPC transport denial; run read-only table/function/direct-write denial checks.
4. Only under separately included transport approval, grant the two exact RPC signatures and perform real authenticated caller acceptance: valid source creation, exact replay, conflicts, source mismatch, actor isolation, receipt isolation, non-Sales denial, full rollback, and coordinated concurrency/number uniqueness.
5. Use unique, recorded fixture request keys and identify every row created by those receipts. Do not touch historical rows or run broad deletes.
6. Roll back failed tests; after successful acceptance, remove only rows proven to be the recorded isolated fixtures in dependency-safe order, or restore the isolated backend from its pre-approved disposable snapshot. Verify no unrecorded/historical record changed.
7. Revoke the two transport grants after acceptance unless a distinct enablement approval says otherwise. Preserve redacted evidence.

### Direct-write denial versus legacy compatibility

This contract does not revoke or alter deployed legacy opportunity/specification create paths. The new receipt table has no direct authenticated mutation grant, and direct mutation denial for the new contract must be proven. Any future transition that revokes legacy direct writes requires a separate compatibility contract and approval; it must not be bundled silently with this acceptance.

## Exact narrow approval wording

> I approve installation of only `supabase/pending/20261010_sales_atomic_intake_replay.sql`, matching SHA-256 `7de31684e508b2628e51cb9fa4f290df8bb0eed1275cc0ec167301132edc2f17`, on isolated backend `egjotuxqguifnvdnflan` after the listed read-only preflight passes. I approve no RPC EXECUTE grants, identity/role/permission changes, UI wiring, legacy-path revocation, original-backend activity, or publication. Installation must preserve the pending SQL's default revoked transport and use only existing approved isolated identities and recorded disposable fixtures.

A second, separately explicit approval is required before granting either RPC signature or running authenticated RPC success cases.
