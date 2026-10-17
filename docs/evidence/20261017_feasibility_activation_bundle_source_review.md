# Feasibility activation bundle — source-only review

## Scope

Prepared for the original managed backend only. This package is source-only: no migration was applied, no managed grant/RLS/data/user change occurred, and the UI remains disabled. It includes pinned feasibility provenance, protected assignment/response, and atomic Sales handover.

Excluded: external client intake, private notes, highlight publication, client links, baseline approval, project start, and the direct-write access transition.

## Package

1. `supabase/migrations/20261017053400_feasibility_provenance_protected_handover_source_only.sql`
   - Verifies exact prerequisite tables, helper signatures, and notification-helper authority.
   - Adds nullable review provenance pins and fails closed for partial legacy pins or duplicate non-null revision/department pairs.
   - Replaces only the historical `(requirement_id, department_id)` uniqueness after preflight, preserves fully-null legacy review pins, and adds the revision-scoped uniqueness/check.
   - Adds the private reviewer-response receipt, protected assignment and response routines, private handover receipt, and atomic Sales handover routine.
   - Grants only the reviewed RPC entry points to `authenticated` and `service_role`; it neither changes graph-table direct privileges nor RLS policies.
2. `supabase/migrations/20261017053401_feasibility_graph_access_transition_review_only.sql`
   - Separate, non-automatic proposal to remove broad direct graph writes after target-bound writer and caller/RLS acceptance.
3. `supabase/migrations/tests/20261017053400_feasibility_protected_handover_local_acceptance.sql`
   - Disposable local replay, source-pin, rollback and graph-integrity checks.
4. `supabase/migrations/tests/20261017053400_feasibility_access_transition_local_acceptance.sql`
   - Disposable local access-transition checks; does not authorize a managed transition.

## Managed schema comparison

The generated schema snapshot shows that managed `requirement_feasibility_reviews` currently has no provenance columns, while requirement/revision table shapes and the notification helper signature support the proposed additive path. Read-only catalog evidence records the historical `(requirement_id, department_id)` uniqueness, broad direct graph writes, and no installed protected graph routines.

The migration’s legacy-row preflight deliberately permits only all-null legacy provenance. It rejects partial pin sets and duplicate future `(source_revision_id, department_id)` pairs before dropping the historical uniqueness. Exact row counts and any repair decision remain managed acceptance work; no rows were read or changed in this source package.

## Reconciled writers and unresolved paths

| Writer | Status in this bundle | Root serialization |
| --- | --- | --- |
| Atomic Sales handover | Added as reviewed source draft | shared requirement root |
| Protected assignment/reassignment | Added as reviewed source draft | shared requirement root |
| Protected reviewer response | Added as reviewed source draft | shared requirement root |
| Direct graph writes | unchanged; blocks activation | none |
| External client intake | excluded | request/source only |
| Sales-bound requirement creation | excluded | request/source only |
| Baseline approval | excluded | existing-row locks only |
| Sample archive/restore | excluded | archive-wide lock only |

The separate access-transition proposal must not run until every remaining writer either follows the shared root protocol or has an approved replacement. Dynamic/service writers and managed caller/RLS behavior remain unresolved.

## Verification boundary

Focused source tests must validate transport and package structure. The SQL acceptance scripts are fixture-backed local evidence only. Before any managed execution, obtain explicit approval and run target-bound schema/policy/grant capture, ordinary-caller RLS tests, concurrency tests, notification rollback checks, and reviewed restore evidence.
