# Structured Sales draft real-caller acceptance outline — UNDEPLOYED

This is a **separate**, operator-run acceptance outline. It is not a structural SQL result and must not be substituted by `request.jwt.claim.*` settings.

## Preconditions

- An approved isolated target has the exact reviewed migration and structural acceptance specification deployed.
- The runner preflight reports the approved isolated target and matching source hashes; it rejects `yyrvduosyyaluifqvwkr`.
- Existing approved identities are supplied at runtime only: an in-scope non-admin Sales manager and an outsider. No token, connection URL, or identity value is stored in source or output.
- Existing disposable caller-visible opportunity/customer/Master Specification/version tuples are supplied explicitly. Request keys are new and unique.

## Required authenticated transport cases

1. Manager saves revision 1 through the normal authenticated application contract; caller-RLS readback observes exactly that receipt graph.
2. Same manager repeats the exact request key and canonical payload; it returns the same receipt with no revision delta.
3. Same key with one changed immutable source tuple member, document kind/schema, expected revision, or payload is denied before a write.
4. A stale expected revision and two parallel manager requests demonstrate one valid outcome plus a conflict/replay, never duplicate revision numbers.
5. Outsider cannot save, replay, or read the manager’s draft/receipt graph; direct table/RPC transport is also denied.
6. A forced authorization/source failure leaves scoped draft, revision, and receipt deltas at zero.

## Evidence boundary

Record only redacted statuses, IDs already authorized for the isolated test record, and scoped count/readback results. A structural rollback run proves function shape and SQL behavior under its claim fixture only; it does **not** prove real authenticated transport, RLS, outsider denial, or concurrency.