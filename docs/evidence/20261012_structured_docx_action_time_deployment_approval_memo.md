# Action-time approval memo — private structured Sales DOCX

**Status:** review-only; **no approval to install is implied.** This memo neither runs nor authorizes SQL, permissions, policy changes, storage writes, assignments, template pins, records, users, or publishing.

- **Prepared:** 2026-10-12T06:23:48Z
- **Source snapshot:** `1f5af3a0a6b95762e0a7d4bb1f73cb5c4a642477`
- **Working-tree status at capture:** `(clean)`
- **Scope inspected:** OPPORTUNITY-2026-0013 / MASTER-2026-0001 rev 1
- **Existing HTML preservation counts at 2026-10-12T06:23:05Z:** 1 draft, 1 revision, 1 request, 1 HTML materialization, 1 HTML audit event.

## Decision requested

Approve only a separately scheduled, operator-reviewed installation of the five exact files below, in the listed order, subject to every halt condition and prerequisite in this memo. A hash mismatch, unexpected preflight result, missing existing source/location, altered policy/grant/function body, or failed non-owner acceptance is a **stop** — not a reason to widen access or improvise a repair.

## Exact ordered package

| Order | Pending source | SHA-256 |
|---|---|---|
| 1. Registry | `supabase/pending/20261012_structured_lifecycle_docx_registry_contract.sql` | `8a193a8bd3f9b3125e0cfad2804d827d86dbcbe6210f9ff6c11171c2d8107209` |
| 2. Folder discovery | `supabase/pending/20261012_sales_structured_docx_folder_discovery.sql` | `ffbcf4a95e43824e6222f2b57f61a945cc7e3c5099524738b886b0cc1cebd8e3` |
| 3. DOCX materialization | `supabase/pending/20261012_sales_structured_docx_materialization_contract.sql` | `4e7fe8bdfb5d4f24e970148d0945106ffa3418d34cb706ae4cf36bb37e362424` |
| 4. Private object enforcement | `supabase/pending/20261012_structured_lifecycle_docx_private_object_enforcement.sql` | `767f13f4583138b4ab94c654547b0013b9396f667278ca4740053b7a316e46e9` |
| 5. Trusted receipt authority | `supabase/pending/20261012_structured_lifecycle_docx_trusted_receipt_authority.sql` | `371cc51960cfbfa96d0e081441da876d8b98b6882467294b9ef5cbbff7a7ab60` |

Compatibility order is intentional: registry → exact folder discovery → request/materialization graph → restrictive private-object guards → trusted verified-byte receipt authority. Do not use a migration runner, a reset script, `DROP`, blanket history marking, fixture creation, or any broad/public grant.

## Fresh managed read-only preflight

**Execute only read-only evidence collection immediately before any decision:**

```text
psql "$MANAGED_DATABASE_URL" -v ON_ERROR_STOP=1 -f docs/planning/20261012_structured_docx_managed_preflight_read_only.sql
```

The checked-in baseline evidence is `docs/evidence/20261012_structured_docx_managed_preflight_result.json` (SHA-256 `ca07fc4cf2e46896cafe17dce67b89b9df4a3998d8f5a6ef418aec90e05c42a0`), captured read-only at `2026-10-12T01:57:54Z`. It is evidence only, not a substitute for a fresh action-time run.

Action-time source read at `2026-10-12T06:23:05Z` independently confirmed:

- exact active source `OPPORTUNITY-2026-0013` / `MASTER-2026-0001`, current revision 1 (working), with no handover/project fabricated;
- one active `STRUCTURED_DRAFT` location, bucket `project-drive`, with the captured existing root/folder/prefix binding;
- the five preserved HTML counts listed above; and
- the installed helper signatures `resolve_sales_opportunity_structured_draft_location(uuid,uuid,uuid)`, `can_access_sales_structured_draft_object(text,text,text)`, `lifecycle_actor()`, and `lifecycle_can_manage_department(uuid,uuid)`.

**Halt** if the fresh preflight does not show the expected `requirement_baselines.requirement_id`, Storage object-version metadata, source/Master revision, active locked non-trashed source-bound location, helper definitions/signatures, extensions, existing policy/grant snapshot, or preserved HTML counts. The pending registry/assignment/template-pin tables are expected to be absent before installation.

## Intended access boundary — no broad or public access

### Caller-authenticated, responsible-person-only production entrypoints

These are the only functions intended for the authenticated assigned responsible person after a separately approved installation. Each derives identity from `auth.uid()`, validates the exact Sales source and active department membership, and does not accept a caller-selected folder/path/bucket/template authority:

- `request_sales_structured_docx_materialization(uuid,uuid,uuid,uuid,text,integer,text,uuid)` — creates/replays the request-key record bound to the pre-existing saved HTML revision and source pins.
- `authorize_sales_structured_docx_upload(uuid,uuid,uuid,uuid,text,bigint)` — returns only the server-derived create-only DOCX path, for DOCX MIME and 1 byte–10 MB.
- `commit_sales_structured_docx_materialization(uuid,uuid,uuid,uuid,text,text,text,text,text,bigint,uuid)` — caller-authenticated atomic commit; binds `auth.uid()` to the receipt actor and creates Drive node/revision/register/audit only after receipt recheck.
- `read_sales_structured_docx_materializations(uuid,uuid,uuid)` — assigned-person history metadata only.
- `discover_sales_opportunity_structured_draft_folder(uuid,uuid,uuid,uuid)` — existing exact Sales folder metadata only; never a free Drive traversal or storage-path disclosure.

The reviewed installation must explicitly grant `EXECUTE` to `authenticated` only for those entrypoints. The source package currently revokes their default ACLs; the operator must not compensate with `PUBLIC`, `anon`, table grants, direct Storage access, or an all-function grant. The final grant statement belongs in the reviewed action runbook after fresh preflight, not in an unreviewed emergency command.

### Policy helper grants (separate and minimal)

Only the following helpers receive `authenticated` execution because PostgreSQL evaluates them inside restrictive policy predicates. These are not direct application commands:

- request-path test/stage/upload/read helpers;
- DOCX Drive-node, Drive-revision, and document-register read helpers;
- current-path create-only assertion required for caller-authenticated commit/read rechecks.

The byte-upload assertion remains `service_role` only. All helpers are revoked from `PUBLIC` and `anon`; internal registry/trusted scope helpers remain non-callable by browser roles.

### Service-only trust boundary

Only `service_role` receives execution for these server bridge calls:

- `resolve_sales_structured_docx_server_scope(uuid,uuid,uuid,text,uuid,uuid,text,integer,text,text)`;
- `issue_sales_structured_docx_trusted_receipt(uuid,uuid,uuid,text,text,text,text,bigint,text,text,integer,text,text)`;
- `assert_sales_structured_docx_trusted_receipt_for_commit(uuid,uuid,uuid,uuid,text,text,text,text,bigint)`;
- `consume_sales_structured_docx_trusted_receipt(uuid,uuid)`.

Receipt issuance rejects a browser JWT subject. The bridge is server-only and gate-disabled; no browser gets a service credential. The commit helper is not directly callable by authenticated users even though the atomic commit invokes it under the same authenticated transaction.

### Registry administration

Registry responsibility/template-pin management is caller-derived but **not granted to runtime browser roles in this package**. The management functions require existing active project-team/Sales-manager plus scoped department document-management conditions, keep responsible and reviewer distinct, and leave reviewer capability read/review-only. Reviewer status never permits upload, save, ownership, or private download. No assignment or immutable template pin is created by this package.

## Restrictive policy diffs

The pending enforcement file adds **restrictive** overlays, deliberately evaluated alongside existing permissive policies:

- `storage.objects`: exact reserved DOCX request path only; assigned responsible person may create/read the one authorized object; every UPDATE, UPSERT/replacement, DELETE, and rename is denied.
- `drive_nodes`, `drive_node_revisions`, `document_control_registers`: DOCX-tagged rows require the same assigned-person resolver for reads; normal Sales, project, department, administrator, or ordinary Drive visibility does not bypass it.

These are additive DOCX-only rules. They do not modify existing HTML structured-draft materializations or non-DOCX Drive content. Any conflicting policy behavior or missing helper execution evidence is a halt condition, not permission-escalation justification.

## Transaction and compatibility checks

1. Take fresh read-only schema/function/policy/grant/source/location evidence and hash the exact checkout.
2. Confirm no pending file has changed and apply the five files once, in order, in the reviewed operator transaction plan — no reset, `DROP`, history replay, or broad ACL repair.
3. Confirm every new `public` table is followed by the reviewed `service_role` grant, RLS enablement, and no browser table access. Confirm public/anon execute remains revoked.
4. Re-run the isolated and managed non-owner acceptance before enabling the runtime gate or DOCX Save control.
5. Configure one explicit existing responsible-person assignment and one approved immutable template pin only after the installation is accepted. This configuration is not a seed, fixture, or inferred project/handover.
6. Keep the acceptance gate disabled until protected upload → byte verification → trusted receipt → atomic commit proves successful under an existing approved non-owner identity.

## Required post-install configuration (not performed)

- Pick the correct scope for the verified source: it remains `SALES_OPPORTUNITY` because the observed record has no handover/project.
- Have an authorized registry manager configure exactly one active **responsible employee** assignment for `SOR` or `CONTRACT_REVIEW` and the actual bound department/location.
- Have an authorized department document manager approve one immutable template pin matching an existing active template revision and schema hash.
- Use an already approved non-owner authenticated identity for acceptance. Do **not** create a user, employee, customer, opportunity, Master, storage object, revision, or fixture for this action.

## Required managed acceptance before UI enablement

Using the approved existing non-owner identity plus an isolated trusted server issuer, prove: assigned success; unassigned and cross-department denial; revocation/template/source staleness denial; storage replacement/update/delete/rename denial; exact replay; altered replay conflict; atomic rollback; private history/read/download denial outside the responsible person. Preserve and compare the existing HTML counts before/after.

## Remaining blockers and material limitation

1. **No deployment authorization exists.** This memo requests review evidence only.
2. **Fresh managed preflight and real managed non-owner acceptance remain mandatory.** The checked-in and action-time reads are read-only evidence, not installation evidence.
3. **No active responsibility assignment or immutable template pin is configured.** These are intentional post-install, authorized configuration steps.
4. **DOCX scope is limited to `SOR` and `CONTRACT_REVIEW`.** The other ten planned templates remain local/export-only and are not a completed portal workflow.
5. **The DOCX Save control remains disabled.** Existing HTML history, `OPPORTUNITY-2026-0013`, `MASTER-2026-0001` revision 1, Procurement review, and Sales sample archive/restore are unchanged and unaccepted.

## Recovery boundary

If verification or commit fails, leave the private object inaccessible and do not create a Drive node, revision, register, or audit materialization. Any approved rollback must first disable the acceptance gate and revoke service execution, retain immutable receipt/audit/materialization evidence, and restore only reviewed prior definitions. Never delete private objects, existing HTML history, assignments, pins, or audit records as a rollback shortcut.
