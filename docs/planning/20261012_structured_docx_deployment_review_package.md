# Structured DOCX deployment review package (source only)

Status: unaccepted; **do not install**. This package makes no live database, Storage, RLS, user, record, or publish change.

## Ordered pending SQL package

Apply only after the managed preflight reports every prerequisite exactly and a root reviewer approves the resulting plan.

1. `20261012_structured_lifecycle_docx_registry_contract.sql` — immutable template pins and explicitly assigned responsible people.
2. `20261012_sales_structured_docx_folder_discovery.sql` — exact active, locked, non-trashed Sales location from pinned source.
3. `20261012_sales_structured_docx_materialization_contract.sql` — assignment/request/attempt/materialization/audit and atomic Drive/register/revision commit.
4. `20261012_structured_lifecycle_docx_private_object_enforcement.sql` — reserved request paths and restrictive Storage/Drive/register read overlays.
5. `20261012_structured_lifecycle_docx_trusted_receipt_authority.sql` — service-only verified-byte receipt, recheck, and one-time consume.

Record SHA-256 values from the release checkout immediately before review; any mismatch halts activation.

## Protected recipient scope

Only the current explicit responsible employee may stage, read, verify, save, history-read, or download a DOCX tagged materialization. The scope also requires current employee/dept membership, a live assignment, immutable template pin, exact source fingerprint, active private Sales location, and the request-bound create-only object version. Normal Sales access, department membership, project visibility, Drive visibility, or administrator status alone is insufficient. The restrictive Storage policy overlays are deliberately evaluated alongside broad permissive policies; UPDATE, DELETE, rename, and replacement are denied for the reserved prefix.

## Server runtime integration

- `src/lib/structured-lifecycle-docx-private-object-reader.server.ts`: current-path bytes only after pre/post exact object-version checks.
- `src/lib/structured-lifecycle-docx-private-object-bridge.server.ts`: bounded OOXML verifier binds bytes, checksum, size, actor, source/template and assignment.
- `src/lib/structured-lifecycle-docx-sales-orchestration.server.ts`: service-only scope, receipt, recheck, atomic commit adapter.
- `src/lib/structured-lifecycle-docx-private-object-bridge.functions.ts`: authenticated `authorizePrivateStructuredDocxUpload`, `verifyPrivateStructuredDocxObject`, and `commitPrivateStructuredDocxMaterialization`; all are hard-disabled by `lifecycleAcceptanceEnabled` until separately reviewed activation. The upload authorization accepts only source/actor-bound identifiers plus DOCX MIME/size; SQL derives the exact private bucket/path.
- `src/components/lifecycle/StructuredTemplatePreview.tsx`: keeps `exportLocalDocx` unchanged. No private DOCX Save control is enabled. The accepted direct Project/Drive handler will invoke only the gated sequence: protected request -> server-derived path authorization -> create-only upload -> verification/receipt -> atomic commit.

## Function/grant boundary

- `authorize_sales_structured_docx_upload(uuid,uuid,uuid,uuid,text,bigint)` is caller-authenticated only after review; it derives current assignment, source, active location, bucket, and request-key path and rejects arbitrary folder/path/template authority, non-DOCX MIME, values above 10 MB, stale source, conflicting replay, or a pre-existing unreceipted object. Its default ACL is revoked from every runtime role.
- `resolve_sales_structured_docx_server_scope(uuid,uuid,text,uuid,uuid,text,integer,text,text)`, `issue_sales_structured_docx_trusted_receipt(uuid,uuid,uuid,text,text,text,text,bigint,text,text,integer,text,text)`, `assert_sales_structured_docx_trusted_receipt_for_commit(uuid,uuid,uuid,uuid,text,text,text,text,bigint)`, and `consume_sales_structured_docx_trusted_receipt(uuid,uuid)` are revoked from PUBLIC/anon/authenticated and granted only to `service_role`.
- Storage policy helper functions have minimal `authenticated` EXECUTE only where PostgreSQL policy evaluation needs it; byte-upload assertion is service-only.
- The materialization commit remains caller-authenticated but rejects missing, altered, cross-actor, consumed, or mismatched receipts and consumes the receipt in the same transaction as Drive/revision/register/audit work.

## HTML compatibility

The existing HTML structured-draft requests, materializations, history, private downloads, audit, and OPPORTUNITY-2026-0013 / MASTER-2026-0001 rev1 remain untouched. DOCX tables and reserved paths are additive and limited to `SOR` and `CONTRACT_REVIEW`.

## Preflight and activation

Run `20261012_structured_docx_managed_preflight_read_only.sql` read-only against the managed database. Halt for any missing/changed columns, extension, function definition, policy, role grant, active assignment/template pin, source-bound location, or conflicting reserved-path policy. Minimal activation after approval: run the five SQL files in order, run their disposable/managed acceptance evidence, configure the isolated acceptance gate, then enable the UI save handler only after a protected create-only upload request endpoint is accepted. No history replay, fixture creation, broad grants, policy weakening, or storage cleanup is permitted.

## Recovery and rollback

Before activation, capture function/policy/grant/schema snapshots and the pending file hashes. If verification/commit fails, leave the object inaccessible, do not create a Drive node/register/revision, and surface the retryable error. If a post-install rollback is approved, disable the acceptance gate first, revoke service execution, retain immutable receipt/audit/materialization evidence, and restore only reviewed prior function/policy definitions. Never delete private objects, historical HTML materializations, audit rows, assignments, or template pins as rollback.

## Outstanding prerequisites

1. Managed preflight evidence that the inspected Storage object-version columns, resolver schema, helper bodies, restrictive policy behavior, roles, active pins, and exact folder binding match this package.
2. Root review of the registry's project-scoped authority mapping to Sales opportunity/Master provenance; current isolated acceptance represents the mapping with an ephemeral project row only.
3. A managed, non-owner authenticated acceptance run covering assigned, unassigned, cross-department, revoked, stale, replay, replacement, and rollback cases.

Procurement review and sample archive/restore remain separate, unaccepted work.
