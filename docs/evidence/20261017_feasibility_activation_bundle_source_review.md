# Feasibility activation bundle — verified source-only review

## Scope

Prepared for the original managed backend only. This package is source-only: no migration was applied, no managed grant/RLS/data/user change occurred, and the UI remains disabled. It includes pinned feasibility provenance, protected assignment/response, and atomic Sales handover.

Excluded: external client intake, private notes, highlight publication, client links, baseline approval, project start, and the direct-write access transition.

## Corrected package

1. `supabase/migrations/20261017053400_feasibility_provenance_protected_handover_source_only.sql`
   - Corrects the PostgreSQL-reserved `constraint` alias to `constraint_row` in the uniqueness preflight.
   - Retains the production preflight for `next_business_number(text,text,text)`, matching the managed helper signature confirmed by catalog read; it was not weakened for the fixture.
   - Adds nullable review provenance pins, fails closed for partial legacy pins and duplicate non-null revision/department pairs, and replaces only the historical `(requirement_id, department_id)` uniqueness after that preflight.
   - Adds private reviewer-response and Sales-handover receipts, protected assignment/response, and atomic Sales handover routines. Narrow execution grants are limited to `authenticated` and `service_role`; graph-table direct grants/RLS remain unchanged.
2. `supabase/migrations/20261017053401_feasibility_graph_access_transition_review_only.sql`
   - Separate, non-automatic proposal that removes direct graph I/U/D only after target-bound writer, caller/RLS, concurrency, rollback, and restore acceptance.
3. `supabase/migrations/tests/20261017053400_feasibility_protected_handover_local_acceptance.sql`
   - Corrects replay fixtures to use complete provenance pins after the new all-null-or-all-present constraint.
   - Covers handover, normalized exact replay, payload conflict, stale enquiry/Master, unauthorized caller, invalid reviewer, graph-drift replay denial, and injected notification-stage rollback.
4. `supabase/migrations/tests/20261017053400_feasibility_access_transition_local_acceptance.sql`
   - Includes the exact new separate transition with `\ir ../20261017053401_feasibility_graph_access_transition_review_only.sql`.
   - Verifies the synthetic read surface is preserved while authenticated and anon direct graph I/U/D are denied and protected handover/assignment/response remain callable.
5. `supabase/migrations/tests/run_20261017053400_feasibility_protected_handover_local_acceptance.sh`
   - Creates an isolated temporary PostgreSQL fixture, loads the fixture, activation migration, protected-handover checks, then separate transition checks. It never contacts a managed backend.
6. `supabase/pending/tests/client_requirement_intake_local_fixture.sql`
   - Aligns only the disposable `next_business_number` helper with the verified managed `text,text,text` signature.

## Executed local verification — 17 October 2026

Executed from repository root:

```text
./supabase/migrations/tests/run_20261017053400_feasibility_protected_handover_local_acceptance.sh
bunx vitest run src/lib/feasibility-activation-bundle.test.ts
```

Results:

```text
SALES_FEASIBILITY_HANDOVER_LOCAL_ACCEPTANCE_PASS headers=2 revisions=2 reviews=1 notifications=1 audits=1 receipts=1
SALES_FEASIBILITY_HANDOVER_REPLAY_SCOPE_PASS ... inactive_reviewer=denied membership=denied department=denied stale_master=denied changed_source_revision=denied changed_master_number=denied changed_applicability=denied replacement_review_id=denied removed_review=denied extra_review=denied
SALES_FEASIBILITY_HANDOVER_NOTIFICATION_ROLLBACK_PASS graph_and_receipt_unchanged=true
ORIGINAL_TARGET_COMPATIBILITY_ACCESS_PASS ... protected_handover,assignment,response=allowed authenticated_anon_direct_iud_all_tables=denied
FEASIBILITY_ACTIVATION_LOCAL_ACCEPTANCE_COMPLETE=true
Vitest: 1 file passed, 3 tests passed.
```

The runner uses a temporary local PostgreSQL cluster and removes it on exit. Results are saved at `supabase/migrations/tests/results/20261017_feasibility_activation_local_acceptance.log`; the log is source-review evidence, not a managed-target acceptance result.

## Managed-target facts and remaining gates

Catalog read confirmed `public.next_business_number(text,text,text)` with a `SECURITY DEFINER` / `search_path=public` contract. This is the signature enforced by the production preflight.

Managed activation remains blocked pending: exact target preflight for legacy pin counts/constraints and named-policy/grant capture; all remaining direct, dynamic and service writer reconciliation; ordinary-caller managed RLS and execution-grant checks; target concurrency schedules against the installed routines; notification rollback under the managed helper; reviewed restore capture/rehearsal; and explicit approval to install the first bundle. The separate access transition remains blocked until those gates have passed and a separate approval is issued.
