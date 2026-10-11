# Project stage-gate RLS recursion: review-only repair package

## Status

**Unapplied and review-only.** This package makes no managed database, RLS, grant, journal, user, credential, record, browser, or publishing change. It does not unblock the separate Sales installation or any other lifecycle acceptance gap.

## Verified live blocker and source

The authenticated Lifecycle query of `public.project_stage_gates` fails with PostgreSQL `42P17` (infinite recursion detected in policy). The interface keeps that failure distinct from empty gate records.

Read-only live catalog evidence on 2026-10-11 confirms:

- RLS is enabled, not forced, on `project_stage_gates` and `project_team_members`; both have authenticated Data API access and the existing service-role access.
- `Project team view stage gates` currently permits `admin`, `projects.view`, or an `EXISTS` subquery through `project_team_members` joined to `employees`.
- `Project members view their project team` currently permits `admin`, `projects.manage`, the caller's own employee row, or an `EXISTS` subquery that reads `project_team_members` again for a same-project membership.
- The latter self-reference causes the `42P17` recursion when the stage-gate policy evaluates its membership branch.
- No `has_project_team_membership(uuid, uuid)` helper exists in the managed catalog. Existing `has_role` and `has_permission` are `STABLE SECURITY DEFINER`, with `search_path = public`.
- Indexes already exist on `project_team_members(project_id)`, `project_team_members(employee_id)`, and `project_stage_gates(project_id)`; no relation, column, constraint, index, or table ACL change is needed.

The original policy source is `drizzle/migrations/0010_phase5_project_foundation.sql` and `drizzle/migrations/0011_phase5_project_delivery_registers.sql`.

## Exact review-only source package

| File | Purpose | SHA-256 |
| --- | --- | --- |
| `supabase/pending/20261011_project_stage_gates_rls_recursion_repair.sql` | helper plus replacement of exactly two SELECT policies | `570301ab3f90a9c7bf360d3883721e30e6102b643af0c01acfd6b580125d3588` |
| `supabase/pending/tests/project_stage_gates_rls_recursion_local_fixture.sql` | disposable schema and original-policy reproduction | local test fixture |
| `supabase/pending/tests/project_stage_gates_rls_recursion_local_acceptance.sql` | caller-scope and privilege assertions | local acceptance |
| `supabase/pending/tests/run_project_stage_gates_rls_recursion_local_acceptance.sh` | isolated PostgreSQL runner and cleanup | local runner |

### Smallest SQL diff

1. Create `public.has_project_team_membership(actor_id uuid, project_id uuid) RETURNS boolean`, `STABLE SECURITY DEFINER`, `search_path = public`. It reads only matching `project_team_members` + active `employees` membership.
2. Revoke its default `PUBLIC` and `anon` execution; grant `authenticated` execution. PostgreSQL needs caller execute privilege to evaluate a policy expression, so an authenticated grant is required. The helper has no write path and returns only a boolean membership fact.
3. Drop and recreate exactly these two existing **SELECT** policies with their original names:
   - `public.project_team_members` / `Project members view their project team`: preserve `admin`, `projects.manage`, and direct own-employee-row branches verbatim; replace only the recursive peer-membership `EXISTS` with the helper.
   - `public.project_stage_gates` / `Project team view stage gates`: preserve `admin` and `projects.view` branches verbatim; replace only the membership `EXISTS` with the helper.

No `FOR ALL` policy, write predicate, table grant, `anon` grant, role, company predicate, department predicate, or frontend access path is changed. The live policy has no company or department condition; this package deliberately does not add one.

## Current-versus-proposed access comparison

| Caller/path | Current intended result | Proposed result |
| --- | --- | --- |
| Admin | all team and stage-gate rows | unchanged |
| `projects.view` | all stage-gate rows; not team rows without `projects.manage` or membership | unchanged |
| Active employee in same project | peer team rows and that project’s stage-gate rows | unchanged, without recursion |
| Unrelated employee/nonmember | no rows via membership branch | unchanged |
| Employee's own team row | direct own-row path | unchanged |
| Anon | no table select and no helper execution | unchanged |
| Department/company-wide reader | no such predicate exists in either verified live policy | unchanged; no new path added |

## Local regression evidence

Executed successfully in a fresh disposable PostgreSQL cluster:

```text
LOCAL_PROJECT_STAGE_GATES_RLS_DISPOSABLE=yes \
  supabase/pending/tests/run_project_stage_gates_rls_recursion_local_acceptance.sh
PROJECT_STAGE_GATES_RLS_LOCAL_ACCEPTANCE_PASS
CLEANUP_VERIFIED project_stage_gates_rls_fixture_removed=true
```

The fixture reproduces the old recursive SELECT policies before applying the review-only replacement. Assertions passed for:

1. active same-project member: sees one project’s gate and peer team rows, not the unrelated-company project;
2. unrelated-company nonmember: sees neither gates nor team rows;
3. `projects.view`: sees both gate rows but no team rows, preserving the distinct live predicates;
4. admin: sees all gate and team rows;
5. inactive employee: direct own team-row behavior remains distinct and unchanged;
6. anon: denied table SELECT and helper execution;
7. authenticated: helper returns false for a false membership fact.

This is local evidence only. Managed caller acceptance still requires testing the exact deployed role/membership data after a separately approved installation. The helper's direct authenticated execution cannot be denied while used in an RLS policy; the reviewed boundary is its narrow boolean-only result, `PUBLIC`/anon denial, and no write capability.

## Rollback approach

A future installation review must capture the then-current exact policy definitions with `pg_get_expr` and function ACL before change. Rollback must:

1. drop the two replacement SELECT policies;
2. recreate the recorded prior definitions exactly;
3. revoke `authenticated` helper execution, then drop `has_project_team_membership(uuid, uuid)` only after no dependent policy remains.

Do not roll back by disabling RLS, granting `projects.view`, adding a broad role, or using elevated client reads.

## Remaining acceptance gaps and exclusions

- Browser acceptance must prove accessible gate rows, true empty gate rows, and denied/error settlement after managed installation.
- Restricted-role acceptance remains pending.
- The source-only Sales package remains blocked by migration-journal reconciliation; this package does not retry or alter that installer path.
- No gate approval, release, readiness, workflow transition, record creation, or manual history change is authorized by this repair.
