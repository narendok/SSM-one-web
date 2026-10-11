# Project stage-gate RLS recursion: source-only repair proposal

## Status

**Unapplied source-only proposal.** No managed policy, grant, function, record, membership, or frontend access path is changed by this document.

## Verified blocker

On the existing authenticated project workspace, the `project_stage_gates` scoped read fails with PostgreSQL error `42P17` (infinite recursion detected in policy). The Lifecycle panel at commit `bc786ffe8cdd35b5b1b13489a0a784dcaa495d76` isolates that failure as “Gate records could not be loaded” with retry; it does not present it as an empty result.

The source predicate is in `drizzle/migrations/0011_phase5_project_delivery_registers.sql`:

- `Project team view stage gates` grants a read when the caller is an administrator, has `projects.view`, or has a matching project-team membership.
- Its membership branch queries `public.project_team_members`.
- `Project members view their project team` in `drizzle/migrations/0010_phase5_project_foundation.sql` also queries `public.project_team_members` to determine peer membership for the same project.

That second self-reference is the recursion path. The intended stage-gate reader semantics are not in question: administrator, `projects.view`, or an authenticated employee who is a member of the same project.

## Narrow repair design

1. Add one `STABLE SECURITY DEFINER` helper owned and reviewed as a security boundary. It accepts an actor UUID and a project UUID, pins `search_path` to `public`, and returns only whether an `employees.user_id = actor` row has a matching `project_team_members.project_id = project` membership.
2. Replace only the self-querying membership branches of the existing project-record SELECT policies with that helper. Preserve the existing administrator and permission checks verbatim.
3. Resolve the recursive `project_team_members` SELECT policy with the same helper for its “another member of this project” branch, while keeping the caller’s own membership branch and manager access intact.
4. Do not use an elevated client read, service-role read, broad `projects.view` grant, or frontend fallback. A policy error must continue to display as an error, and a zero-row authorized result must remain a distinct empty state.

## Review and acceptance evidence required before application

- Exact deployed policy inventory, helper ownership, function privilege inventory, and `pg_get_functiondef` review in an isolated environment.
- Authenticated cases for: administrator, `projects.view`, same-project active employee membership, unrelated employee, and unauthenticated caller.
- Reads for `project_stage_gates`, `project_team_members`, `project_design_inputs`, `project_issues`, and `project_change_requests`, proving the repair removes recursion without widening the original predicates.
- A denied direct helper call unless explicitly required by the policy execution role; no public execute widening by default.
- Browser evidence that gate reads show records, zero rows show the existing empty message, and denied/error reads show the existing error state rather than an empty state.
- Rollback text that restores the exact prior policies and removes the helper only after dependent policies are restored.

## Explicit exclusions

No migration is prepared for installation, no RLS/grant change is applied, and no existing member, project, gate, approval, release, or historical record is modified. This proposal does not authorize gate approval, release, readiness, or any derived lifecycle state.