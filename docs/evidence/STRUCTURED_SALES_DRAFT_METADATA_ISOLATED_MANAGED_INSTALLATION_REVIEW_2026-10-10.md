# Structured Sales draft metadata — Isolated Managed Installation Review (2026-10-10 UTC)

Status: **review only — no installation, grant, identity, data, remote action, live Save wiring, or publication is authorized by this document.**

## Target boundary and source pins

- **Only candidate isolated backend:** `egjotuxqguifnvdnflan`.
- **Explicitly excluded original backend:** `yyrvduosyyaluifqvwkr`. It must receive no SQL, grants, fixture data, identity changes, or acceptance traffic.
- **Repository HEAD inspected:** `1283b676ba299bd584ec38a94d3c0cba26c18ae9`.
- **Pending contract:** `supabase/pending/20261009_sales_opportunity_structured_draft_metadata.sql` — SHA-256 `32fef255d2deeacfe859c9978d6ba25fb7c4384afb7183dc6c860bd7efdca448`.
- **Managed isolated acceptance specification:** `supabase/pending/tests/sales_opportunity_structured_draft_metadata_acceptance.sql` — SHA-256 `7be51b57b37bc5b95cd7ea861ecba748ce861f8ba2909c013c600d6f1056b2fd`.
- **Local disposable installed acceptance:** `supabase/pending/tests/sales_opportunity_structured_draft_metadata_local_installed_acceptance.sql` — SHA-256 `ba52c1776ba1cc8ef61febd9b62c57845050f5aa0292d96195836edd2700494c`.
- **Non-executing isolated-target guard:** `supabase/pending/tests/sales_opportunity_structured_draft_metadata_isolated_acceptance_runner.mjs` — SHA-256 `ab251fcebca573c9954f3954af4c53baf7f1c77f0e159aaec8edf44ce0af9c03`.
- **Guard tests:** `supabase/pending/tests/sales_opportunity_structured_draft_metadata_isolated_acceptance_runner.test.mjs` — SHA-256 `5f8b82303a8d1c4f2d275f818e4dcccd5d4512ad41f1d773b9cd5b977ae99181`.
- **Static guard:** `supabase/pending/tests/check_sales_opportunity_structured_draft_metadata_static.py` — SHA-256 `8bbc7a64c7f694e7bb697b59125dbe35e49bbabe27b01e65a00c037d1787e9e4`.

Any changed source or hash, target mismatch, pre-existing incompatible object, unavailable required caller, or missing cleanup evidence is a stop condition. Do not substitute another backend.

## Exact additive contract inventory

The pending SQL creates only the following new structured-draft metadata objects. It has no Drive, Drive revision, controlled-document register, storage, document-number, file, or materialization write.

### Tables, grants, and RLS

1. `public.sales_opportunity_structured_drafts`
   - immutable source pin: opportunity, customer, Master Specification, exact Master Specification version/number, document kind, editable schema key/hash, and source fingerprint;
   - owner provenance: `created_by`, timestamp, and logical identity uniqueness;
   - `GRANT SELECT` to `authenticated`, `GRANT ALL` to `service_role`, RLS enabled;
   - authenticated SELECT is only for `created_by = auth.uid()` with `has_permission(auth.uid(), 'sales.manage')`.
2. `public.sales_opportunity_structured_draft_revisions`
   - append-only canonical JSON payload revisions, parent link, payload/source hashes, actor and timestamp;
   - `GRANT SELECT` to `authenticated`, `GRANT ALL` to `service_role`, RLS enabled;
   - authenticated SELECT requires the same actor, `sales.manage`, and ownership of the parent draft.
3. `public.sales_opportunity_structured_draft_requests`
   - actor-bound request receipt with complete immutable source/schema/payload identity, returned draft/revision, operation, expected revision, and timestamp;
   - `GRANT SELECT` to `authenticated`, `GRANT ALL` to `service_role`, RLS enabled;
   - authenticated SELECT is only for `requested_by = auth.uid()` with `sales.manage`.

### Triggers and routines

| Object | Exact signature or scope | Installation purpose |
| --- | --- | --- |
| `public.reject_sales_opportunity_structured_draft_history_mutation()` | `RETURNS trigger` | Rejects all UPDATE/DELETE history mutation. |
| `sales_opportunity_structured_drafts_immutable` | BEFORE UPDATE OR DELETE on drafts | Append-only draft identity. |
| `sales_opportunity_structured_draft_revisions_immutable` | BEFORE UPDATE OR DELETE on revisions | Append-only revision history. |
| `sales_opportunity_structured_draft_requests_immutable` | BEFORE UPDATE OR DELETE on receipts | Append-only replay receipts. |
| `public.sales_opportunity_structured_draft_schema_hash(text)` | `RETURNS text` | Server-owned allowed-field schema hash for `SOR`, `CONTRACT_REVIEW`, and `PRS`. |
| `public.sales_opportunity_structured_draft_canonical_payload(text, jsonb)` | `RETURNS jsonb` | Rejects unknown/non-string fields and validates per-field/total limits before writes. |
| `public.sales_opportunity_structured_draft_source_fingerprint(uuid, uuid, uuid, uuid, integer, text, text, jsonb, timestamptz)` | `RETURNS text` | Binds each draft/revision/receipt to the locked immutable source tuple. |
| `public.save_sales_opportunity_structured_draft_revision(uuid, uuid, uuid, uuid, text, integer, jsonb, uuid)` | `RETURNS TABLE(draft_id uuid, revision_id uuid, revision_number integer, replayed boolean)`; `SECURITY DEFINER` | Single protected create/revision/replay operation. It authorizes before and after logical/source locks, locks receipt lookup, verifies actor/source/hash identity, and returns only same-actor exact replays. |

The protected save routine locks its logical identity, opportunity, specification, exact source version, and receipt. It rejects stale expected revisions, a new request key for unchanged payload, source mismatch, actor mismatch, malformed payloads, and conflicting request-key reuse. It does not infer a project, department, owner, current/latest version, Drive location, or controlled-document relationship.

## Default revoked transport and separate grant decision

The pending SQL revokes helper access from `PUBLIC`, `anon`, and `authenticated`. It additionally revokes the save routine from `PUBLIC`, `anon`, `authenticated`, and `service_role`:

```sql
REVOKE ALL ON FUNCTION public.save_sales_opportunity_structured_draft_revision(
  uuid, uuid, uuid, uuid, text, integer, jsonb, uuid
) FROM PUBLIC, anon, authenticated, service_role;
```

Installation therefore leaves all ordinary caller mutation transport denied. The three new tables deliberately have no authenticated INSERT, UPDATE, or DELETE grant; their policies are read-only. The local runner's temporary `authenticated` EXECUTE grant is fixture-only evidence and is not part of the pending SQL.

Only after separate successful isolated installation acceptance may a separately reviewed transport decision consider exactly:

```sql
GRANT EXECUTE ON FUNCTION public.save_sales_opportunity_structured_draft_revision(
  uuid, uuid, uuid, uuid, text, integer, jsonb, uuid
) TO authenticated;
```

That grant is **not approved by this review**. No direct table mutation, helper-function execution, service-role transport widening, legacy Sales-write revocation, or live UI Save wiring is proposed here.

## Required non-mutating target preflight

The following catalog/read queries are the minimum preflight on `egjotuxqguifnvdnflan`. They are inspection-only and must run through approved read-only access. Their results must be captured without credentials, tokens, or session material.

### 1. Target identity and object collision

```sql
SELECT current_database(), current_user, version();

SELECT c.relname, c.relkind, c.relpersistence, c.relrowsecurity
FROM pg_class AS c
JOIN pg_namespace AS n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relname IN (
    'sales_opportunity_structured_drafts',
    'sales_opportunity_structured_draft_revisions',
    'sales_opportunity_structured_draft_requests'
  )
ORDER BY c.relname;

SELECT p.oid::regprocedure AS signature, p.prosecdef, p.proconfig
FROM pg_proc AS p
JOIN pg_namespace AS n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.oid::regprocedure::text IN (
    'public.reject_sales_opportunity_structured_draft_history_mutation()',
    'public.sales_opportunity_structured_draft_schema_hash(text)',
    'public.sales_opportunity_structured_draft_canonical_payload(text,jsonb)',
    'public.sales_opportunity_structured_draft_source_fingerprint(uuid,uuid,uuid,uuid,integer,text,text,jsonb,timestamp with time zone)',
    'public.save_sales_opportunity_structured_draft_revision(uuid,uuid,uuid,uuid,text,integer,jsonb,uuid)'
  )
ORDER BY signature;
```

**Stop** if any proposed object exists unless a separately reviewed, byte-identical installed contract and compatible grants/policies/triggers are proven. Do not use `CREATE OR REPLACE` to overwrite an unknown routine.

### 2. Source schema, exact dependencies, and append-only version behavior

```sql
SELECT c.table_name, c.column_name, c.data_type, c.is_nullable, c.column_default
FROM information_schema.columns AS c
WHERE c.table_schema = 'public'
  AND c.table_name IN (
    'sales_opportunities', 'customers',
    'master_specifications', 'master_specification_versions'
  )
ORDER BY c.table_name, c.ordinal_position;

SELECT tc.table_name, tc.constraint_name, tc.constraint_type,
       kcu.column_name, ccu.table_name AS foreign_table_name,
       ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
LEFT JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_schema = kcu.constraint_schema AND tc.constraint_name = kcu.constraint_name
LEFT JOIN information_schema.constraint_column_usage AS ccu
  ON tc.constraint_schema = ccu.constraint_schema AND tc.constraint_name = ccu.constraint_name
WHERE tc.table_schema = 'public'
  AND tc.table_name IN (
    'sales_opportunities', 'customers',
    'master_specifications', 'master_specification_versions'
  )
ORDER BY tc.table_name, tc.constraint_name, kcu.ordinal_position;

SELECT t.tgname, t.tgtype, pg_get_triggerdef(t.oid) AS definition
FROM pg_trigger AS t
JOIN pg_class AS c ON c.oid = t.tgrelid
JOIN pg_namespace AS n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relname IN ('sales_opportunities', 'master_specifications', 'master_specification_versions')
  AND NOT t.tgisinternal
ORDER BY c.relname, t.tgname;

SELECT p.oid::regprocedure AS signature, p.prosecdef, p.proconfig
FROM pg_proc AS p
JOIN pg_namespace AS n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN ('has_permission')
ORDER BY signature;
```

The target must expose the fields and relationships used by the pending routine: opportunity/customer identity; specification/opportunity/customer identity; version/specification identity, version number, source JSON, and source creation time; and `has_permission(uuid, text)` semantics compatible with `sales.manage`. It must retain append-only protection for Master Specification versions. **Stop** on absent, renamed, incompatible, or broader/narrower semantic dependencies until source is reconciled and reviewed.

### 3. RLS, policies, table grants, routine grants, and dependencies

```sql
SELECT c.relname, c.relrowsecurity, c.relforcerowsecurity
FROM pg_class AS c
JOIN pg_namespace AS n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relname IN (
    'sales_opportunities', 'customers',
    'master_specifications', 'master_specification_versions'
  )
ORDER BY c.relname;

SELECT p.tablename, p.policyname, p.roles, p.cmd, p.qual, p.with_check
FROM pg_policies AS p
WHERE p.schemaname = 'public'
  AND p.tablename IN (
    'sales_opportunities', 'customers',
    'master_specifications', 'master_specification_versions'
  )
ORDER BY p.tablename, p.policyname;

SELECT table_name, grantee, privilege_type
FROM information_schema.role_table_grants
WHERE table_schema = 'public'
  AND table_name IN (
    'sales_opportunities', 'customers',
    'master_specifications', 'master_specification_versions'
  )
  AND grantee IN ('anon', 'authenticated', 'service_role', 'PUBLIC')
ORDER BY table_name, grantee, privilege_type;

SELECT p.oid::regprocedure AS signature, r.rolname AS grantee,
       has_function_privilege(r.oid, p.oid, 'EXECUTE') AS can_execute
FROM pg_proc AS p
JOIN pg_namespace AS n ON n.oid = p.pronamespace
CROSS JOIN pg_roles AS r
WHERE n.nspname = 'public'
  AND p.proname = 'has_permission'
  AND r.rolname IN ('anon', 'authenticated', 'service_role')
ORDER BY signature, grantee;
```

Review must prove that installed table read policies preserve actor isolation and that the proposed `SECURITY DEFINER` routine can resolve only the exact source tuple it locks. It must also prove that installation does not silently alter deployed legacy opportunity/specification write paths. **Stop** if source reads, caller authorization semantics, RLS, or dependency ownership differ from the contract assumptions.

### 4. Existing identities and fixture availability — no changes

Use existing protected role/permission views or an approved read-only operator report to establish only the following facts; do not output email addresses, tokens, or other credentials:

| Required existing identity | Required evidence | Required managed case |
| --- | --- | --- |
| Non-admin Sales manager A | active authenticated user; `sales.manage`; normal application transport; valid visible source tuple | create, own replay, revision, own history/read |
| Non-admin Sales manager B | active authenticated user; `sales.manage`; normal application transport | actor-bound replay/receipt conflict and isolation |
| Non-Sales user | active authenticated user without `sales.manage`; normal application transport | denied RPC/direct write with no writes |
| Existing disposable source tuple | caller-visible opportunity/customer/specification/exact version; recorded teardown selectors | success/replay/conflict/rollback without touching historical records |

An administrator, direct JWT-claim injection, a created/promoted identity, or a fabricated source row is not substitute evidence. The current contract is opportunity-only and must not impose a department membership or project ownership inference. No null department/project field can be used to authorize or identify a fixture.

## Required staged acceptance sequence

Managed acceptance remains unexecuted. If a later explicit approval allows it, proceed only in the following order and stop on the first mismatch:

1. Recalculate every pinned hash and confirm the exact target ref. Capture the read-only preflight above.
2. Obtain a distinct, narrow **installation approval** for the one pinned pending SQL. Install it only with default function revocations retained.
3. Prove, through normal caller transport, that `authenticated` cannot execute the save RPC by default; prove direct INSERT/UPDATE/DELETE against the three new tables is denied. Preserve legacy Sales direct-write compatibility; no old path is revoked or altered.
4. Obtain a separate, narrow **transport-grant approval** for only the one save signature. Apply no helper/table/legacy grant.
5. Obtain a separate **identity/fixture approval** confirming existing named test identities and the recorded disposable tuple; no identity, permission, or role may be created or changed.
6. With caller-authenticated transport, prove manager A can create an SOR draft and append a changed revision, both tied to the exact version. Confirm old revision/manual payload remains unchanged, a stale expected revision fails, and a newer source/version never overwrites a local draft or silently follows “latest”.
7. Prove manager A exact replay returns the original receipt IDs with no new rows. Prove same key with changed payload/source/schema/revision conflicts without rows; unchanged payload with a new request key is denied.
8. Prove unknown/non-string/oversized editable fields and raw opportunity/customer, specification, and version mismatches fail before writes. Prove manager B cannot replay or read manager A's receipt/draft. Prove the non-Sales caller is denied before any replay or write.
9. Exercise controlled rollback at revision and receipt insertion, confirming no partial draft/revision/receipt writes; run bounded concurrent exact-replay/conflict/stale-revision cases, confirming one convergence or one conflict and preserved history.
10. Capture only acceptance-created IDs. Roll back failures and remove only recorded isolated fixtures in dependency-safe order, or restore an explicitly approved disposable snapshot. Revoke the one transport grant unless a later enablement approval explicitly retains it.

No step may generate, save, issue, publish, download, or materialize a server document. No Drive, register, storage, document number, project binding, or background work is part of this contract.

## Verified local synthetic evidence and limits

The pending contract's local disposable PostgreSQL 17 harness has previously executed the following synthetic cases:

- installed create, changed revision, exact replay, malformed/unknown payload denial, source mismatch denial, actor replay denial, stale conflict, immutable history, and no partial write assertions;
- exact-replay race with two workers converging on one draft/revision/receipt write set and identical IDs;
- same-key changed-payload and different-actor conflicts with one winner and no losing write;
- stale-revision race with one revision-two winner, one conflict, and preserved revision one;
- revision/receipt failpoint rollback for create and update; and
- permission revocation while a new call and a receipt replay wait inside the actual contract advisory lock, both denied before receipt return or write.

The scripts use a fresh private PostgreSQL 17 Unix-socket/mmap fixture and fixture-only `authenticated` EXECUTE grant, then clean it up. They are source/local behavior evidence only. They do **not** prove candidate schema compatibility, deployed RLS/policies, real authenticated application transport, managed function ownership, existing caller availability, approval scope, or installation safety.

## Current blockers and narrow approval wording

**Current blockers:** no read-only catalog evidence has yet established target compatibility for `egjotuxqguifnvdnflan`; no existing non-admin caller matrix or disposable source tuple has been evidenced; installation has not been approved; the save function remains revoked for all ordinary transport; there is no live Save control; and managed acceptance has not run.

> I approve installation of only `supabase/pending/20261009_sales_opportunity_structured_draft_metadata.sql`, matching SHA-256 `32fef255d2deeacfe859c9978d6ba25fb7c4384afb7183dc6c860bd7efdca448`, on isolated backend `egjotuxqguifnvdnflan` only after this document's read-only preflight passes. I approve no RPC EXECUTE grant, user/role/permission change, fixture creation beyond separately approved recorded acceptance fixtures, legacy-path change, live Save wiring, Drive/register/storage/document materialization, original-backend activity, or publication. Installation must preserve default revoked transport.

A second approval is required before the exact authenticated EXECUTE grant, and a third approval is required before relying on any existing caller identities or disposable managed fixtures for authenticated acceptance.