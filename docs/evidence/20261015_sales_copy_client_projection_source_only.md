# Sales Copy client projection — source-only, 15 October 2026

## Delivered local boundary

`src/lib/client-opportunity-copy.ts` provides a pure typed allowlist projection only. It has no database call, server function, token, invitation, UI link, access decision, or publication side effect.

The projection exposes only the opportunity number/customer name; exact Master Specification number and revision ID/number with customer-facing requirement fields; customer requirement title/number/reference/summary with exact revision pins; and separately supplied client highlights only where their publication source revision ID and number exactly match the selected Master revision.

It excludes internal owner, development scope, workstreams, review findings/assumptions/risks, internal remarks, costing, staff/reviewer identifiers, notifications, attachments, Drive locations, and every unallowlisted value. Shared-analysis examples are not supplied to this projection and do not constitute publication.

## Current gate

`clientOpportunityCopyLinkAvailability.available` remains `false`. No installed caller-authorized resolver exists. A future resolver must verify immutable recipient binding, exact opportunity/customer scope, active access, expiry, revocation/deactivation, exact source revision, narrow field projection, audit, and one-time/rotation semantics where a credential is used.

No invitation was issued or accepted; no token, user, authorization, policy, grant, SQL installation, record, fixture, handover state, Git connection, or publication changed.

## Focused checks

Tests assert the allowlist, exact Master and requirement revision pins, stale-highlight exclusion, rejection of an unallowlisted staff field, and the unavailable resolver gate. These are source-level tests only, not external identity/RLS or deployed-contract acceptance.