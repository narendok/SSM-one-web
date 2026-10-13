# Pending Sales feasibility handover contract

Status: **source-only review**. This is not installed SQL and authorizes no application write.

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
expected_enquiry_updated_at TIMESTAMPTZ
request_key UUID
```

## Required atomic behavior

1. Authenticate the caller and verify scoped Sales authority before and after serialization.
2. Lock the actor-bound request key, then the exact enquiry and opportunity. Verify their authoritative customer, exact enquiry link, current status, and inspected `updated_at`; reject missing, archived, mismatched, or stale source facts.
3. Lock and verify the immutable Master Specification version belongs to that opportunity/customer and is eligible for source pinning.
4. Canonicalize and lock each requested active department. Resolve and lock one current active responsible employee with active membership in that exact department; reject empty, duplicate, inactive, or unresolvable selections.
5. Create or exact-replay one customer requirement, immutable revision 1, source/audit receipt, and one pending feasibility review per selected department. Each review must pin the requirement revision and Master Specification version.
6. Use the existing private inbox helper internally to create one recipient-owned notification per review with a deterministic event key. The routine, not the client, supplies the recipient and target facts.
7. Advance only a dedicated server-owned handover/read-model status. Do not overload `sales_enquiries.status` or infer an opportunity/project conversion.
8. Return the exact persisted requirement/review identifiers on an identical request-key replay; reject a changed canonical payload under the same key. Recheck caller authority and recipient scope before returning a replay.
9. Roll back every requirement, revision, review, notification, audit, and receipt if any later step fails. Direct writes and direct notification-helper execution remain denied.

## Minimum acceptance before UI enablement

Disposable ordinary-caller evidence must cover Sales denial; enquiry/opportunity/customer and Master-version mismatch; stale enquiry timestamp; inactive/duplicate department; missing/inactive/wrong-department responsible employee; no partial graph after notification failure; exact replay and changed-payload conflict; concurrent same-key and competing-department requests; direct table/helper denial; and non-owner RLS reads. It must prove that no verdict or project conversion occurs during handover.