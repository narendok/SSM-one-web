# Pending Sales enquiry department review contract

## Verified deployed facts

- `public.sales_enquiries` holds customer/contact links, requirement summary, operational status, actor and timestamps only. It has no review department, reviewer, request receipt, or review status field.
- `public.departments` provides active departments and a department lead user; `public.employees` provides active employee identities; `public.employee_departments` binds an employee to a department.
- `public.notifications` has user-owned inbox entries and an idempotency `event_key`. `public.enqueue_notification(...)` is `SECURITY DEFINER` but is revoked from `PUBLIC`, `anon`, and `authenticated`, with execute granted only to `service_role`.
- There is no installed routine referencing `sales_enquiries` for review routing.

## Required protected operation

Provide one caller-authenticated `request_sales_enquiry_department_review` operation. It must accept an enquiry ID, department ID, expected current review revision, and actor-bound request key.

Within one transaction it must:

1. Verify the caller has the scoped Sales authority and lock the request key then the exact enquiry.
2. Lock and recheck the selected active department and its current active responsible employee, including active membership in that department.
3. Reject archived or unavailable enquiries and reject absent, inactive, or cross-department recipients.
4. Append an immutable review-request record containing the enquiry, department, recipient, creator, request key, and an inspected enquiry revision/timestamp.
5. Advance only a server-owned review status exposed through a dedicated read model; do not overload the existing general enquiry `status` without an accepted lifecycle mapping.
6. Insert one recipient-owned inbox entry in the same transaction with a deterministic event key. The protected routine may call the private inbox helper internally; the client never receives its authority.
7. Return an exact replay result for an identical request key and reject a changed payload under that key. Recheck authority and recipient scope before replay is returned.

## Acceptance required before UI enablement

Disposable ordinary-caller proof must cover unauthorized Sales caller, inactive department, missing/inactive/wrong-department recipient, stale enquiry or review revision, same-key replay, changed-payload conflict, notification idempotency, audit rollback, concurrent competing requests, and direct table/RLS denial. No public grant, direct client write, or notification helper grant is acceptable.