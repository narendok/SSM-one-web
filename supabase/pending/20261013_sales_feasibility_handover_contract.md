# Pending Sales feasibility handover contract

Status: **source-only verification**. The proposed executable source is
`supabase/pending/20261013_sales_feasibility_handover.sql`; it is not installed
and authorizes no application write.

## Verified reusable primitives

- `public.sales_enquiries` provides the saved enquiry/customer source but has no review lifecycle or routing fields.
- `public.sales_opportunities` can point to an enquiry and `public.customer_requirements` points to an opportunity/customer.
- The controlled requirement dependency requires the authoritative opportunity/customer pair plus an immutable `master_specification_versions` row before it can create a requirement and immutable revision 1.
- `public.departments`, `public.employees`, and `public.employee_departments` expose the active department and its active responsible employee scope.
- `public.notifications` has recipient-owned idempotency through `(user_id, event_key)`. Its private `enqueue_notification(...)` helper is correctly service-only and must remain unavailable to browser callers.

## Missing operation

Neither deployed `submit_external_customer_requirement`, `assign_requirement_feasibility_review`, nor the service-only inbox helper provides the required Sales handover. The deployed read model also lacks immutable feasibility provenance. Therefore the current UI must remain disabled.

Provide one caller-authenticated routine named `submit_sales_feasibility_handover` accepting only:

```text
enquiry_id UUID
opportunity_id UUID
customer_id UUID
master_specification_version_id UUID
title TEXT
summary TEXT NULL
customer_reference TEXT NULL
department_ids UUID[]
reviewer_user_ids UUID[]
expected_enquiry_updated_at TIMESTAMPTZ
request_key UUID
```

## Required atomic behavior

1. Authenticate the caller and verify scoped Sales authority before and after serialization.
2. Lock the actor-bound request key, then the exact enquiry and opportunity. Verify their authoritative customer, exact enquiry link, current status, and inspected `updated_at`; reject missing, archived, mismatched, or stale source facts.
3. Lock and verify the immutable Master Specification version belongs to that opportunity/customer and is eligible for source pinning.
4. Canonicalize and lock each requested active department and selected reviewer. Verify active employee status and active membership in that exact department; reject empty, duplicate, inactive, cross-department, or unresolvable selections.
5. Create or exact-replay one customer requirement, immutable revision 1, source/audit receipt, and one pending feasibility review per selected department. Each review must pin the requirement revision and Master Specification version.
6. Use the existing private inbox helper internally to create one recipient-owned notification per review with a deterministic event key. The routine, not the client, supplies recipient and target facts. The deployed review table has no due-date field; a due date must not be accepted or displayed as saved until a separately accepted schema and protected contract exists.
7. Advance only a dedicated server-owned handover/read-model status. Do not overload `sales_enquiries.status` or infer an opportunity/project conversion.
8. Return the exact persisted requirement/review identifiers on an identical request-key replay; reject a changed canonical payload under the same key. Recheck caller authority and recipient scope before returning a replay.
9. Roll back every requirement, revision, review, notification, audit, and receipt if any later step fails. Direct writes and direct notification-helper execution remain denied.

## Minimum acceptance before UI enablement

Disposable ordinary-caller evidence must cover Sales denial; enquiry/opportunity/customer and Master-version mismatch; stale enquiry timestamp; inactive/duplicate department; missing/inactive/wrong-department reviewer; no partial graph after notification failure; exact replay and changed-payload conflict; concurrent same-key and competing-department requests; direct table/helper denial; and non-owner RLS reads. It must prove that no verdict, baseline, or project conversion occurs during handover.
## Replay safeguard repair - 15 October 2026

The replay path now locks the receipt first, then repeats the normal caller-authority, enquiry/opportunity/customer, current-Master-version, active department and active reviewer-membership checks before it can return an existing result. It verifies that the receipt's requirement has exactly the selected department/reviewer review graph and that each review retains revision 1 plus the original pinned Master Specification version. It never reroutes or renotifies on replay.

The current-Master-version rule applies to both initial execution and replay. A later Master revision makes the old request stale; the caller must start a new handover request rather than reinterpret an old receipt. The original receipt stays immutable.

Disposable SQL checks cover reviewer deactivation, membership removal, department deactivation, changed enquiry/opportunity linkage, stale Master version, removed/extra/substituted review rows and unchanged graph/notification/audit counts after every denied replay. Exact replay, changed-payload conflict, caller denial and concurrency remain required.

This repair remains source-only until the local disposable suite passes and its exact output is reviewed. No installation, production database call, permission change or SQL deployment is included in this follow-up. The Sales action remains disabled.
