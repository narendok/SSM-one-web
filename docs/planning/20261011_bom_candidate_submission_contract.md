# BOM candidate submission — pending locked contract

**Status:** source-only and unapplied. No live database, records, access, inventory, BOM, Sales, lifecycle, or interface behavior changes.

## Locked eligibility predicate

Submission is eligible only when one locked source graph proves all of the following:

1. `projects.requirement_baseline_id` identifies the baseline and `project_boms.project_id` is the requested project.
2. The baseline is `project_initiated`, has `approved_by` and `approved_at`, and its requirement resolves to the same non-null project customer and opportunity.
3. One `sales_project_handovers` row has that exact baseline, that exact project, and `status = 'completed'`.
4. The authenticated actor resolves to the project's `project_manager_employee_id`, that employee has `employment_status = 'ACTIVE'`, and an existing `project_team_members` row binds that employee to the project.
5. An active `departments.code = 'HARDWARE'` row exists and is pinned on the submission. No department is inferred from nulls, labels, Sales text, or the caller.

The statuses are the existing schema values: an approved baseline is emitted as `active` by the pending baseline-approval routine and the existing handover initiation changes it to `project_initiated`; handovers support `ready`, `initiated`, `completed`, and `cancelled`. The candidate predicate deliberately requires the post-initiation `project_initiated` state plus a `completed` exact-project handover.

## Bounded effects

The pending SQL adds candidate headers, revision-one immutable payloads, append-only audit events, and actor-bound replay receipts. It takes project then request advisory locks, authorizes before receipt replay, and repeats the locked scope check after waits and immediately before writes. It grants no executable action and creates no client wiring.

It does not create, edit, delete, match, promote, or link components; change stock, locations, substitutes, provenance, manual BOM lines, Sales data, handovers, baselines, project teams, roles, or department data; or provide Hardware review, promotion, persistence UI, or a read queue.