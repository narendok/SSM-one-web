# Client Requirement Intake and Feasibility Provenance — Isolated Installation Review (2026-10-10 UTC)

**Status:** Source-only review packet. It authorizes **no** installation, target connection, query, grant, identity change, fixture, user-interface activation, Save, generation, or publishing.

## 1. Target boundary and source pins

| Item | Value |
| --- | --- |
| Reviewed repository HEAD | Pending final verification after this source-only compatibility split |
| Only permitted future installation target | `egjotuxqguifnvdnflan` |
| Explicitly excluded production target | `yyrvduosyyaluifqvwkr` |
| Phase 1 pending intake/provenance proposal | `supabase/pending/20261005_client_requirement_intake.sql` |
| Phase 1 SHA-256 | Pending final verification after this source-only compatibility split |
| Phase 2 separately gated direct-write compatibility transition | `supabase/pending/20261011_requirement_feasibility_direct_write_compatibility_transition.sql` |
| Phase 2 SHA-256 | Pending final verification after this source-only compatibility split |

`dee4a625…` is a stale pre-split SHA-256 of the former entire 841-line intake proposal file, not a view-only hash. It is not approval evidence for either phase. Phase 1 retains external intake, protected feasibility RPCs, immutable source pins, and the invoker provenance view. Phase 2 contains only the deferred legacy scope-helper removal and feasibility direct-write/policy removal.

Any changed byte, target mismatch, pre-existing incompatible object, or unverified connection identity is a stop condition. The earlier five-file approval does **not** cover either new phase hash, this view, the post-lock authorization revalidation, or any installation/transport action described here.

## 2. Exact changed contract inventory

### New objects

| Object | Constraint / purpose |
| --- | --- |
| `external_requirement_submission_requests` | Request-key receipt for one external requirement submission; records actor/contact/opportunity/customer, canonical payload/hash, and exactly one requirement result. |
| `requirement_feasibility_response_requests` | Request-key receipt for one protected feasibility response; binds reviewer, review, immutable requirement/master pins, payload/hash. |
| `external_requirement_submission_canonical_payload(...)` | Private immutable canonical JSON constructor. |
| `external_requirement_submission_payload_hash(...)` | Private immutable hash helper. |
| `external_requirement_scope_allows(uuid, uuid)` | Security-definer scope check for the current external contact, active/unrevoked/unexpired portal access, and explicit opportunity/customer scope. |
| `submit_external_customer_requirement(uuid, uuid, text, text, jsonb, uuid)` | Security-definer atomic intake action; authenticates/re-derives scope before and after request-key lock, performs exact replay/conflict handling, then writes requirement, revision, audit, and receipt atomically. |
| `requirement_feasibility_review_provenance` | `SECURITY INVOKER` read projection of explicit review pins. No fallback to current/latest source. RLS-hidden joined source rows suppress the projection row. |
| `assign_requirement_feasibility_review(uuid, uuid, uuid)` | Security-definer assignment/reassignment action that pins the exact current requirement revision and the exact Master Specification version named in that immutable revision. |
| `requirement_feasibility_response_canonical_payload(...)` | Private immutable canonical JSON constructor for a reviewer response. |
| `record_requirement_feasibility_response(uuid, text, text, text, text, uuid)` | Security-definer terminal response action with immutable receipt/audit binding. |
| `read_requirement_feasibility_response_receipt(uuid, uuid, uuid, uuid, uuid)` | Security-definer actor-bound positive receipt readback; does not prove rollback/history/concurrency by an empty result. |
| `requirement_feasibility_reviews_source_revision_idx` | Lookup index on the pinned source revision. |

### Existing objects altered

| Object | Change | Compatibility constraint |
| --- | --- | --- |
| `external_requirement_submission_requests` | Adds nullable `payload_canonical` if an older draft table exists, plus an object-shape check accepting `NULL`. | Legacy receipts without canonical payload remain deliberately non-replayable; they must use a new request key. |
| `requirement_feasibility_reviews` | Adds nullable explicit source revision/version IDs and numbers plus applicable workstreams; adds all-null-or-complete-pin check. | No legacy backfill. Unpinned legacy rows remain readable but report `UNAVAILABLE_LEGACY_OR_MISSING_PIN` when joins are readable. |
| `customer_requirement_revisions` | Adds unique `(requirement_id, revision_number)` if absent. | Must be preflighted for existing duplicate values before install. |
| `requirement_feasibility_reviews` uniqueness | Replaces only an exactly-shaped legacy unique `(requirement_id, department_id)` constraint with `UNIQUE (source_revision_id, department_id)`. | Preserves historical verdicts and permits a separate review for a new immutable revision. This remains a Phase 1 non-additive change. |

### Explicitly not created or activated

No user-interface wiring, Save action, generation/publishing path, background work, identity/role/permission, project, document, automatic approval, quotation, release, or current/latest-source fallback is included.

## 3. Access model, grants, revokes, and RLS

### Receipt tables

- `external_requirement_submission_requests`: `REVOKE ALL` from `PUBLIC`, `anon`, and `authenticated`; `GRANT ALL` to `service_role`; RLS enabled.
- `requirement_feasibility_response_requests`: `REVOKE ALL` from `PUBLIC`, `anon`, and `authenticated`; `GRANT ALL` to `service_role`; RLS enabled; authenticated `FOR ALL` policy always evaluates false.
- Direct receipt access is intentionally unavailable to ordinary callers.

### Functions

- Public/anonymous execution is revoked from all proposed callable functions.
- `submit_external_customer_requirement(..., uuid)`, `assign_requirement_feasibility_review(...)`, `record_requirement_feasibility_response(..., uuid)`, and `read_requirement_feasibility_response_receipt(...)` are proposed with `EXECUTE` to `authenticated` and `service_role`.
- Private canonical/hash helpers and `external_requirement_scope_allows(...)` are revoked from ordinary callers.
- The submission and assignment/response/readback actions use `SECURITY DEFINER`; their full caller, scope, permission, pin, and replay conditions require managed non-admin caller acceptance before they can be trusted.

### Provenance projection

- `requirement_feasibility_review_provenance` is explicitly `WITH (security_invoker = true)`, not `SECURITY DEFINER`.
- It revokes all access from `PUBLIC`, `anon`, and `authenticated`; only `service_role` is granted access by the proposal.
- No authenticated projection grant is proposed in this packet. A later explicit caller-access decision must specify the narrow SELECT grant/policy posture and prove it with genuine caller-RLS acceptance.
- The projection uses inner joins to requirement, exact pinned revision, exact pinned Master version, and specification. If any joined row is RLS-hidden, the view emits no row rather than exposing source contents, current header fields, or a source-existence oracle.

## 4. Legacy, source-binding, and disclosure treatment

- No row is backfilled, inferred from latest/current data, or synthesized from labels/proximity.
- Missing/legacy pin fields result in `UNAVAILABLE_LEGACY_OR_MISSING_PIN`; mismatched explicit pins result in `UNAVAILABLE_MISMATCHED_PIN` only where the caller can read the joined source rows.
- With source joins hidden under invoker RLS, the projection row is suppressed. This is intentional confidentiality behavior, not a fallback/unavailable payload.
- Historical pins retain their referenced revision/version even after a requirement header or Master Specification advances.
- Invalid or incomplete workstreams fail protected assignment rather than creating a speculative applicability result.

## 5. Installation phases and non-additive effects

### Phase 1 — intake, protected feasibility paths, historical pins, and invoker provenance

`20261005_client_requirement_intake.sql` remains non-additive only for the exact legacy submission and response signature removals and the feasibility uniqueness replacement:

1. It conditionally drops any `requirement_feasibility_reviews` unique constraint whose exact ordered keys are `(requirement_id, department_id)`, then adds `requirement_feasibility_reviews_revision_department_key` on `(source_revision_id, department_id)`.
2. It drops the former five-argument `submit_external_customer_requirement(...)` signature if present, after revoking its execution.
3. It drops the former five-argument `record_requirement_feasibility_response(...)` signature if present, after revoking its execution.

These signature removals remain in Phase 1 because the six-argument protected functions use a request key for canonical replay; keeping the old callable overload would retain a path that bypasses that binding. They still require a target-bound dependency inventory and separate installation approval. No `CASCADE` is used.

### Phase 2 — separately gated direct-write compatibility transition

`20261011_requirement_feasibility_direct_write_compatibility_transition.sql` contains only the operations deferred from Phase 1:

1. revoke and drop the former three-argument `external_requirement_scope_allows(uuid,uuid,uuid)` overload if it exists;
2. revoke authenticated `INSERT`, `UPDATE`, and `DELETE` on `requirement_feasibility_reviews`; and
3. drop the `Sales users manage feasibility reviews` policy if it exists.

Phase 1 deliberately retains those legacy paths. That preserves existing behavior only; it does **not** establish that direct writers or the legacy scope helper are safe, approved, or production-ready. Phase 2 requires its own target-bound dependency/compatibility preflight, direct-writer migration proof, protected-path caller acceptance, rollback/restore plan, and explicit approval. There is no automatic down migration for either phase.

## 6. Dependency and collision preflight — read-only only

Do not connect or query until the supplied connection independently proves its target is exactly `egjotuxqguifnvdnflan`. A generic/read-only PostgreSQL identity, a hostname substring alone, or any connection pointing to `yyrvduosyyaluifqvwkr` is insufficient.

Once target binding is proven, capture read-only evidence for:

1. Backend reference and database identity matching only `egjotuxqguifnvdnflan`; stop on ambiguity. Never substitute production.
2. Exact schemas, column types/nullability/defaults, foreign keys, indexes, constraints, policies, triggers, and grants for `external_requirement_submission_requests`, `requirement_feasibility_reviews`, `customer_requirement_revisions`, `customer_requirements`, `master_specifications`, `master_specification_versions`, `external_portal_access`, `external_contacts`, `external_parties`, `sales_opportunities`, `employees`, `employee_departments`, and `activity_log`.
3. Exact signatures, owners, security modes, search paths, dependencies, and existing privileges for every same-named/overloaded function in Section 2, plus `external_current_contact_id`, `external_current_party_id`, and `has_permission`.
4. Existing data compatibility: duplicate `(requirement_id, revision_number)` rows; duplicate/legacy feasibility rows; rows that would violate all-null-or-complete pins; existing receipt-table rows and payload shape; constraint/policy names targeted by conditional drops.
5. Phase 1 dependencies/callers of the old submission/response overloads and legacy unique constraint; Phase 2 dependencies/callers of the three-argument helper, direct feasibility-write grant, and `Sales users manage feasibility reviews` policy.
6. Existing non-admin external contact and engineering reviewer identities, normal authenticated caller transport, permission/department membership, source rows, and auditable isolated cleanup capacity. Do not create or modify any of them.
7. RLS/grant matrix for every source relation and exact expected owner/invoker behavior; no service-role, owner, synthetic-GUC, or admin-only substitute proves end-user access.

Stop on absent/mismatched prerequisites, collisions, unknown dependency scope, inability to prove cleanup boundaries, or any required use of production.

## 7. Transactional and rollback risks

- Intake holds a transaction advisory lock by request key, revalidates external identity/scope after waiting, locks the receipt row, and writes header/revision/audit/receipt as one transaction. A failure should roll back the entire graph, but this must be proven on the isolated target with its actual triggers/policies.
- The receipt table's unique `requirement_id` and immutable replay binding must be checked against existing data and concurrent callers.
- Assignment locks requirement, exact revision, review, and Master version; response locks the same governed source sequence. Actual target lock order, trigger interactions, deadlock behavior, and statement timeouts remain unverified.
- Phase 1 includes signature/constraint changes; Phase 2 includes the deferred helper, grant, and policy changes. Neither phase supplies a reversal migration. Each installation rollback strategy must use an isolated snapshot/approved restoration plan, not ad hoc deletion.
- Managed test fixtures must be uniquely recorded by request key and cleaned up only with a dependency-safe, approved isolated procedure; no broad delete and no historical-row edits.

## 8. Executed local synthetic evidence

All commands below use disposable local PostgreSQL 17 fixtures, create temporary fixture-only grants and/or synthetic JWT GUC claims, and remove the fixture at exit. They never contacted a managed backend. Exit `0` is local behavior evidence only.

| Command | Result recorded |
| --- | --- |
| `bash supabase/pending/tests/run_client_requirement_intake_local_acceptance.sh` | Exit `0`; exact replay, payload/actor conflicts (`P0001`), expired/revoked/scope denials, source mismatch, audit failure rollback; request graph assertions. |
| `bash supabase/pending/tests/run_client_requirement_intake_local_concurrency.sh` | Exit `0`; same actor/canonical request converged to one graph; conflicting same-key payloads had one winner and one `P0001` loser. |
| `bash supabase/pending/tests/run_client_requirement_intake_local_revocation_wait.sh` | Exit `0`; scope revoked while request waited on request-key lock; post-lock recheck rejected `P0001`, graph `0/0/0/0`. |
| `bash supabase/pending/tests/run_client_requirement_intake_local_revocation_replay_wait.sh` | Exit `0`; existing same-actor receipt was not replayed after scope revocation during the lock wait; original graph remained `1/1/1/1`. |
| `bash supabase/pending/tests/run_client_requirement_feasibility_provenance_local_acceptance.sh` | Exit `0`; historical v1 provenance survived later header/version advancement; legacy and mismatched pins stayed unavailable; source rows were unchanged. |
| `bash supabase/pending/tests/run_client_requirement_feasibility_provenance_invoker_rls_local_acceptance.sh` | Exit `0`; synthetic non-owner with visible review but hidden joined source rows got no projection row; direct join stayed hidden; revoking the fixture-only view grant denied access. |
| `bash supabase/pending/tests/check_client_requirement_feasibility_provenance_security.sh` | Exit `0`; confirms source text includes invoker view, no definer, no authenticated projection grant, revoked direct projection access, and inner hidden-source joins. |
| `bash -n supabase/pending/tests/run_client_requirement_intake_*.sh supabase/pending/tests/run_client_requirement_feasibility_provenance*.sh` | Exit `0`; runner syntax only. |
| `git diff --check` | Exit `0`; whitespace check only. |

Synthetic limitations: these runs use owner fixture sessions, fixture-only grants, and synthetic GUC actor claims. They do not prove managed database compatibility, real JWT/auth transport, RLS predicates, caller grants, function ownership, service-role boundaries, existing data compatibility, or deployment/rollback behavior.

## 9. Managed tests still missing

After a separate installation approval, and only on `egjotuxqguifnvdnflan`, all of the following remain required:

1. Read-only preflight in Section 6, including collisions/dependencies and actual object signatures.
2. Phase 1 install-time transaction behavior and approved restore/rollback rehearsal for its signature/constraint changes; separately, the same proof for every Phase 2 helper/grant/policy removal.
3. Default post-install transport/privilege verification: direct receipt read/write denial, private-helper denial, non-granted projection denial, and any expected denied RPC paths.
4. Real external authenticated caller: valid scoped submission; exact replay; payload/actor/key conflicts; expiry/revocation; cross-customer/opportunity rejection; direct underlying-table denial; full transaction rollback after an isolated failure boundary.
5. Real two-session external concurrency: same key/same canonical payload; same key/conflicting payload; revocation while waiting for both fresh request and existing receipt replay.
6. Real Sales manager and non-manager assignment behavior; active department membership/reviewer constraints; pinning an explicit historical revision/version after headers advance; terminal review immutability; conflicts/races; audit rollback.
7. Real assigned reviewer response behavior: actor/department/permission checks; exact replay/conflicts; terminal-state protection; source/pin/workstream mismatch rejection; audit/receipt transaction rollback; receipt readback isolation.
8. Real authenticated caller-RLS projection matrix: review-visible/source-visible, review-visible/source-hidden, review-hidden, legacy/missing pins, mismatched pins, cross-opportunity/customer, and no source-payload/current-header/existence disclosure.
9. Fixture cleanup/readback proving only recorded isolated rows changed and no historical rows or production target was touched.

## 10. Separate approvals required

1. **Isolated read-only preflight approval** for the target-bound inspection in Section 6. This approval authorizes no installation.
2. **Phase 1 isolated installation approval** for its final full-file hash only, including its signature/constraint changes.
3. **Phase 2 isolated transition approval** for its final full-file hash only, after its separate direct-writer/helper dependency evidence and compatibility acceptance pass.
4. **Existing-identity/caller acceptance approval** to use already approved isolated identities and unique disposable fixtures after installation; no user, role, or permission changes are included.
5. **Any additional caller-access approval** if the provenance view is to be exposed to authenticated users. This packet proposes no such grant.
6. **Future frontend/Save/generation/publish enablement approval**. None is included here.

No one approval substitutes for another. Prior five-file approval does not authorize any item above.

## 11. Exact source paths and content-integrity check

- Review packet: `docs/evidence/CLIENT_REQUIREMENT_INTAKE_PROVENANCE_ISOLATED_INSTALLATION_REVIEW_2026-10-10.md`
- Phase 1 pending intake/provenance proposal: `supabase/pending/20261005_client_requirement_intake.sql`
- Phase 2 deferred direct-write compatibility transition: `supabase/pending/20261011_requirement_feasibility_direct_write_compatibility_transition.sql`
- Split static guard: `supabase/pending/tests/check_client_requirement_intake_compatibility_split.sh`
- Managed acceptance specification: `supabase/pending/tests/client_requirement_intake_acceptance.sql`
- Guarded isolated preflight runner: `supabase/pending/tests/run_client_requirement_intake_isolated_acceptance.sh`
- Local intake evidence runners: `supabase/pending/tests/run_client_requirement_intake_local_acceptance.sh`, `supabase/pending/tests/run_client_requirement_intake_local_concurrency.sh`, `supabase/pending/tests/run_client_requirement_intake_local_revocation_wait.sh`, `supabase/pending/tests/run_client_requirement_intake_local_revocation_replay_wait.sh`
- Local provenance evidence: `supabase/pending/tests/client_requirement_feasibility_provenance_local_acceptance.sql`, `supabase/pending/tests/run_client_requirement_feasibility_provenance_local_acceptance.sh`, `supabase/pending/tests/client_requirement_feasibility_provenance_invoker_rls_local_acceptance.sql`, `supabase/pending/tests/run_client_requirement_feasibility_provenance_invoker_rls_local_acceptance.sh`, `supabase/pending/tests/check_client_requirement_feasibility_provenance_security.sh`

Before any later approval, recompute SHA-256 for this review packet and every cited executable/source file, compare them to the approval record, and stop on any mismatch.
