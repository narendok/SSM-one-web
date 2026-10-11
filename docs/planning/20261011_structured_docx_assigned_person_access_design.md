# Structured DOCX and assigned-person access design — review only

## Current boundary

All twelve structured templates require real editable DOCX output: SOR, NDA, Commercial quotation, Contract Review, PRS, BOM cost tracker, DFMEA, Manufacturing Control Plan, DVP&R, PDI, Commercial tax invoice, and Annual Skill Matrix.

The deployed Sales structured-draft materialization contract is deliberately incompatible with that target. It accepts only `text/html`, a `<request-key>-draft.html` object path, and the three Sales kinds `SOR`, `CONTRACT_REVIEW`, and `PRS`. Its current actor-bound read rule uses `requested_by`; it must remain unchanged. Existing saved HTML revisions remain valid historical DRAFT/UNISSUED records and are not rewritten or reinterpreted.

The browser now generates local editable OOXML DOCX working files. Every document visibly pins its available template key and version. There is no immutable deployed editable-schema version available to pin, so the DOCX explicitly labels that schema identity as unverified rather than fabricating one. BOM cost tracker and DFMEA tables use landscape A4 widths with repeated headers; their OOXML structure is tested, but visual rendering in Word/LibreOffice remains browser-unverified.

This is an export only: it has no private Drive upload, document-register write, revision creation, import, approval, issuance, or release path. A DOCX file can be edited in Word-compatible software and its current in-portal edit round trip remains limited to the existing canonical scalar/table fields. Importing arbitrary DOCX changes is intentionally unsupported until a controlled DOCX parser/schema contract is accepted.

## Existing responsibility evidence

`document_control_registers` already has `owner_employee_id`, `reviewer_employee_id`, and `approver_employee_id`, each referencing `employees`. These fields are the only verified responsible-person anchors found for controlled documents. Department membership and `sales.manage` are insufficient on their own for DOCX read, write, or revision access.

## Additive contract proposal — not applied

1. Add a `structured_lifecycle_docx_materializations` identity, a matching immutable revision/receipt/audit graph, and a protected private-location binding. Every record references one closed kind, immutable source pin, template key/version, server-owned schema key/hash, assigned owner employee, optional reviewer employee, one non-trashed locked department Drive folder, one Drive node/revision, and one document-control register.
2. Accept only the twelve closed document kinds and OOXML MIME type `application/vnd.openxmlformats-officedocument.wordprocessingml.document`; enforce `.docx` storage names and an exact server-rendered checksum.
3. Resolve the caller to an active employee through the existing `employees.user_id` identity mapping, then authorize discovery, save, history, and download only when that employee equals the pinned register owner or reviewer, or has a separately approved document-control authority. A department member who is not assigned must be denied. The resolver must return no row when the employee/user mapping is absent, inactive, reassigned, or revoked.
4. Preserve source-owned company/numbering/register fields as server-derived and immutable. Editable canonical payloads remain limited to the closed scalar/table schemas for each kind; import must reject unknown fields, derived source fields, malformed tables, and content that cannot be mapped exactly.
5. Resolve one active pinned private document location by document kind, department, source scope, and exact locked non-trashed Drive folder. Validate the bucket/prefix against that binding before upload; never derive a destination from the browser or a department alone.
6. Before every replay/commit, lock and revalidate the source pins, assigned responsible persons, location, target Drive folder, canonical payload checksum, expected revision, and request key. An unchanged request returns the same receipt; a changed tuple conflicts. If ownership/reviewer assignment is revoked or changed during a wait, the save/download/history action denies and creates no new revision.
7. Stage one server-rendered `.docx` at a request-key path, record MIME, byte count, SHA-256, and an upload receipt, verify the exact object before the immutable commit, then create Drive revision/register/audit/materialization records atomically. Compensate only a storage object proven unreferenced by the matching staging receipt.

## Required acceptance before enabling DOCX Save

- An approved additive SQL contract with grants, RLS, and a protected resolver; no broad department-membership policy.
- Caller-authenticated tests for assigned owner, assigned reviewer, unassigned department member, revoked/reassigned owner or reviewer, wrong source/location, stale revision, identical replay, conflicting replay, rollback, and private read/download denial.
- Byte/checksum acceptance for server-rendered OOXML and a real Drive/document-register materialization test.
- A deliberate import policy. Until then, only canonical in-portal fields can round-trip; arbitrary DOCX edits are not imported.

No migration, permission, policy, binding, data, user, fixture, or publication action is included in this design.