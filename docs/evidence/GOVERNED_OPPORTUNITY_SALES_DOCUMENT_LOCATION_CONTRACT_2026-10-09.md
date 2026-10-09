# Governed opportunity Sales document location and linkage contract — 2026-10-09

## Status, scope, and non-effects

**SOURCE-ONLY DESIGN. Every `Proposed` object, column, relation, routine, policy, grant, and acceptance test below is UNDEPLOYED.**

This document defines the smallest additive contract needed to let a pre-project Sales opportunity use the **existing** Drive, controlled-register, Drive-revision, document-number, activity-history, and `project-drive` storage infrastructure without inventing a second register or a second storage system.

It does **not** apply SQL, create or alter a database object, add a role/grant/user, write a record, stage an object, activate a save action, wire the UI, or publish. It does not make the pending structured-draft metadata proposal executable.

`supabase/pending/20261009_sales_opportunity_structured_draft_metadata.sql` at the reviewed source revision `ba22fd7d080ea043bd25357bcc869c0d238c23aa` remains **UNDEPLOYED**. Its SQL acceptance specification remains **UNEXECUTED**. It deliberately has no Drive, controlled-register, storage, document-number, or activity-log write.

## Verified existing contracts

| Concern | Existing authoritative evidence | What is available | Why it is insufficient for an opportunity-only controlled document |
| --- | --- | --- | --- |
| Opportunity/Master source | `sales_opportunities`, `master_specifications`, `master_specification_versions`; `src/lib/lifecycle-structured-template-previews.functions.ts` | The read path verifies the caller-visible `opportunity -> customer -> Master Specification -> exact version` tuple. `master_specifications` is one-per-opportunity and records `customer_id`; versions are append-only under `20261005183103_2157aab7-4509-46b0-bc31-4d5f6e7785d0.sql`. | `sales_opportunities` has no department, Drive-root/folder, register, or controlled-document relationship. The optional `projects.opportunity_id` lookup is not a binding. |
| Department Drive ownership | `20260930173641_ad877d36-e445-4ed8-8771-734df118f414.sql`, superseded/provision-expanded by `20260930182746_38ace26c-20ec-45b8-aec8-babd0f34c73b.sql` | `drive_nodes` carries nullable `department_id`, nullable `project_id`, `parent_id`, `folder_kind`, lock/trashed state, and storage metadata. Active departments have a locked `DEPARTMENT_ROOT`, `DEPARTMENT_STANDARDS`, `INTERNAL_PROJECTS`, and `CLIENT_PROJECTS` hierarchy. Sales (`SAL`) common categories include `sales-standards-commercial-templates` and `customer-requirements-quotations`. | Categories are department templates, not an opportunity binding. A folder name/category cannot prove a particular opportunity, customer, document owner, or materialization right. |
| Department access | `public.can_access_department_drive(user, department, project)` in `20260930173758_2140203c-0407-4f53-a1fa-0ef9d95ee2d4.sql` | Access is Platform Owner, active employee department membership, or a project-team membership when a project is explicitly supplied. `drive_nodes` policies additionally require `projects.manage`, `engineering.manage`, or `documents.edit` for mutation. | There is no Sales-opportunity owner/location authorization helper. `sales.manage` alone does not establish a department Drive location. |
| Project canonical location | `projects.department_id`, `projects.project_drive_node_id`; hardening proposal `supabase/pending/20261005_harden_project_drive_provisioning_boundary.sql` | A committed project can point to a canonical non-trashed `PROJECT_ROOT`; the pending lifecycle proposal locks and validates target ancestry beneath it. | The hardened root-pointer proposal is itself **UNDEPLOYED**. More importantly, no project may be inferred from an opportunity-only draft. |
| Controlled register/history | `document_control_registers`, `document_control_events`, `document_control_action_requests`; `20260930184556_35c51e69-3385-4715-bee6-4dce625acb02.sql` and `20261001160232_1e457307-b0c3-4f4b-bb8e-c4ef42492082.sql` | One register per `drive_node_id`; register requires `department_id`, has optional `project_id`, binds its source Drive revision, and has an existing replay-safe decision transition. Events retain controlled-document history. | Register ownership is department-based and has no opportunity source tuple, immutable Sales draft revision, Sales location authorization, or opportunity-only materialization receipt. |
| Existing storage | Existing `project-drive` bucket policies in `20260924030746_3e8856bf-24a2-4a39-8024-e7311aeaa252.sql` | Project/engineering roles read or mutate `project-drive`; `drive_nodes` and `drive_node_revisions` carry bucket/path/checksum/version metadata. | Current policy is role-scoped, not a proof that a path belongs to an opportunity. It must not be widened blindly to make an opportunity folder work. |
| Project-only lifecycle materialization | `supabase/pending/20261003_lifecycle_document_draft_generation.sql` | Proposed single transaction coordinates staged bytes, Drive node/revision, DRAFT register, audit, actor-bound receipt, and compensation. | It requires a committed project with `department_id`, `project_drive_node_id`, and project ancestry; accepts only project tokens and `.txt`. It cannot issue structured opportunity-only Sales documents. |

## Explicit missing contract

No installed source establishes all of the following together:

1. an opportunity-owned, department-owned canonical Drive location;
2. a verified Sales actor who may use that location for exactly one opportunity/customer tuple;
3. an immutable link from a controlled Drive file/register revision back to the exact opportunity, Master Specification version, and structured draft revision;
4. an actor-bound, replay-safe materialization receipt for a pre-project Sales document; and
5. a storage-path policy/adapter proof that relates an object to that location without granting broad Sales access to unrelated `project-drive` objects.

Therefore **controlled issuance/materialization remains unavailable**. The existing common Sales categories are not an implicit answer. No department, project, folder, owner, or register row may be selected from an opportunity’s name, customer, nullable project, category label, or historic Drive ancestry.

## Proposed additive model — UNDEPLOYED

### A. One explicit opportunity document location, not a competing Drive tree

**Proposed table:** `public.sales_opportunity_document_locations`.

One immutable active-location record per opportunity/customer/document-location purpose, with these proposed columns:

- `id uuid primary key`;
- `opportunity_id uuid not null references public.sales_opportunities(id) on delete restrict`;
- `customer_id uuid not null references public.customers(id) on delete restrict`;
- `department_id uuid not null references public.departments(id) on delete restrict`;
- `drive_root_node_id uuid not null references public.drive_nodes(id) on delete restrict`;
- `target_folder_node_id uuid not null references public.drive_nodes(id) on delete restrict`;
- `location_purpose text not null` constrained to a future explicit Sales controlled-draft purpose;
- `status text not null` constrained to `ACTIVE`/`RETIRED`;
- `authorized_by uuid not null`, `authorized_at timestamptz not null`, `retired_by uuid null`, `retired_at timestamptz null`;
- `created_by uuid not null`, `created_at timestamptz not null`.

**Proposed invariants:**

- unique active location for `(opportunity_id, location_purpose)`; a retired row remains history and cannot be reused;
- caller-selected IDs are only candidates: a protected resolver locks opportunity, customer, location, root, target, and every ancestor;
- location customer must equal `sales_opportunities.customer_id` exactly;
- both root and target are non-trashed `FOLDER` nodes, have the same non-null `department_id`, have `project_id IS NULL`, and target is below the specified root;
- the root must be the **explicitly recorded** department-controlled Sales location approved by an authorized location manager. It is not derived from `SAL` labels, a category slug, first-created node, or any other structural heuristic;
- location uses the existing `drive_nodes` tree and `project-drive` bucket. It creates neither a second Drive node table nor a second object bucket;
- a later committed project does not rewrite this location or move its history. Project-bound documents use the existing project flow only after an explicit, separately recorded project-binding operation.

This design intentionally does **not** choose which existing Sales department root/folder becomes eligible. That is a business authorization decision and is absent from the current contract.

### B. Immutable source-to-controlled-document linkage

**Proposed additive relation:** `public.sales_opportunity_structured_draft_materializations`.

It links existing records rather than duplicating any register or storage metadata:

- `id uuid primary key`;
- `structured_draft_revision_id uuid not null` referencing the proposed pending structured-draft revision record;
- `location_id uuid not null` referencing the proposed opportunity location;
- `drive_node_id uuid not null` referencing existing `drive_nodes`;
- `drive_revision_id uuid not null` referencing existing `drive_node_revisions`;
- `document_control_register_id uuid not null` referencing existing `document_control_registers`;
- `request_key uuid not null`, `requested_by uuid not null`, `payload_hash text not null`, `rendered_sha256 text not null`, `mime_type text not null`, `storage_bucket text not null`, `storage_path text not null`, `size_bytes bigint not null`;
- exact immutable Sales source pins copied from the linked draft revision: opportunity/customer, Master Specification ID/version ID/version number, document kind, editable-schema key/hash, source fingerprint, and parent materialization when revising;
- `activity_log_id uuid not null` referencing the existing activity log and `created_at timestamptz not null`.

**Proposed uniqueness/idempotency:**

- one immutable materialization per Drive revision and per controlled register;
- request identity is `(location_id, request_key)`, actor-bound and compared against the **entire** immutable tuple: actor, opportunity/customer, source version, structured revision, schema, location/root/target, renderer/mime, object hash/size/path and expected parent;
- same request identity plus exact tuple returns the original receipt; any changed member is a conflict;
- source/template/schema changes, stale structured-draft revision, changed location, or changed renderer do not replay and create no object;
- restoring equivalent content is permitted only as a new append-only structured draft revision and a new request key; no past Drive revision, register, receipt, or event is mutated.

The proposal must use existing `document_control_registers` and `document_control_events`. Its register row carries the existing required `department_id`, file `drive_node_id`, current source Drive revision, DRAFT status, and existing document number. The materialization relation—not an overloaded mutable register field—holds the immutable Sales source tuple. A possible future foreign key from `document_control_registers` to a materialization is not necessary and should not be added until exact transition/reporting implications are reviewed.

### C. Explicit ownership and authorization boundary

**Proposed protected resolver:** `public.resolve_sales_opportunity_document_location(...)` (name UNDEPLOYED).

The resolver derives `auth.uid()`; it does not receive actor, department, owner, project, root, folder, document number, or source values as authoritative input. It must:

1. require an authenticated caller with the existing `sales.manage` authority **and** verified caller-visible opportunity/customer/Master Specification source;
2. lock and verify the opportunity/customer/Master Specification/exact version tuple before any receipt read;
3. lock the active proposed location, root, target, and ancestry; reject a null/mismatched department, any project-bound node, trashed node, cycle, broken chain, or root mismatch;
4. require a new explicit location-management authority contract before a user can create, activate, retire, or reassign a location; `sales.manage`, department membership, and folder names alone do not imply it;
5. re-check `can_access_department_drive(actor, department_id, NULL)` and the existing Drive mutation authority before staging or Drive/register writes;
6. reject outsider, direct transport, caller/owner mismatch, source mismatch, and stale/replayed conflict before disclosing a protected receipt or staging bytes.

The exact permission key or role for location management is deliberately not proposed as deployed fact. It requires a separate authorization decision and caller-RLS acceptance. Existing `document_control_registers` direct write policy remains Administrator-only; an eventual service boundary must preserve—not bypass—the existing controlled-document transition/ownership model.

### D. Materialization and compensation model

**Proposed operation:** a future protected, server-only `materialize_sales_opportunity_structured_draft(...)` bridge, disabled until acceptance.

It must reuse the existing pattern, in this order:

1. resolve and lock the Sales source tuple and the explicit opportunity location;
2. load the selected immutable structured-draft revision, validate it against the pinned schema, and render deterministic inert bytes from server-owned layout code;
3. obtain a unique staged `project-drive` object through a server adapter; client code never selects bucket/path or writes a register;
4. persist an actor/request/location/source-bound staging receipt before the commit;
5. in one transaction, revalidate all pins and write the existing `drive_nodes` file, `drive_node_revisions` revision, `document_control_registers` DRAFT row, `document_control_events` history, one existing activity-log event, and the proposed materialization receipt; consume the exact staged-object attempt in the same transaction;
6. if the transaction fails, leave no partial Drive/register/materialization relation. The server may delete staged bytes only after exact proof that the attempt is unconsumed and unreferenced; cleanup failure is recorded as a recoverable compensation state, never hidden or treated as issuance success.

No operation may create a second controlled register, shadow Drive metadata, or shadow storage object record. Existing document numbering remains server-owned and is requested only inside the protected commit after every authorization/source/location precondition passes.

The existing `project-drive` policy is an identified prerequisite, not authorization evidence. The eventual design must use a narrow server-side adapter or an accepted policy extension bound to the recorded location; it must not make all Sales actors broadly read/write that bucket.

### E. Relationship to project-bound records

- **Opportunity-only:** `project_id` is absent everywhere in the new location/materialization identity. It uses a recorded Sales department location with `drive_nodes.project_id IS NULL`.
- **Project-bound:** requires an explicit committed `projects` row whose `opportunity_id` and customer match the same Sales tuple, with a verified non-null department and canonical Drive-root pointer. It reuses the project lifecycle ancestry rules, not the opportunity location.
- **No migration by inference:** a future project link cannot change old opportunity-only Drive/register/materialization history. A governed, explicit cross-reference can be designed later; it is outside this group.

## Required acceptance, original versus isolated

### Original/shared backend

The original backend is **read-only evidence only**. It may be used to verify schema/policy names and caller-visible existing source rows. It must not receive this pending SQL, test fixtures, storage attempts, controlled registers, materialization requests, location rows, grants, role changes, or direct table mutations.

### Approved isolated backend

Only an approved isolated target may execute the proposed migration and acceptance tests. Before any mutation it must prove its target identity server-side and refuse the original/shared backend. Required real-caller acceptance uses existing approved identities, never invented users:

- an in-scope non-admin Sales manager who has `sales.manage`, caller-visible source tuple access, explicit location permission, and verified department Drive access;
- a non-admin outsider lacking at least one of those scopes;
- an approved disposable opportunity/customer/Master Specification exact version; and
- an explicitly authorized, non-trashed Sales location root/target under an existing department tree, plus an independent existing controlled-document numbering/transition dependency.

Minimum caller-RLS checks: missing/retired/mismatched location; null department; target outside root; target with project ID; customer/spec/version mismatch; Sales actor without location right; Drive actor without Sales right; outsider/readback denial; direct table/transport denial; deterministic first materialization; exact replay; changed-tuple same-key conflict; stale structured revision; source/schema advance; renderer hash mismatch; register/Drive/audit rollback; unconsumed-object compensation; parallel same-request convergence; and RLS-scoped readback of the exact Drive revision/register/event/materialization chain.

A privileged query, an administrator-only seed, a successful storage upload, or a browser declaration is not acceptance evidence for non-admin caller RLS or controlled issuance.

## Prerequisites and deliberate exclusions

Before this contract can advance beyond source design:

1. Finish isolated acceptance for the pending structured-draft metadata proposal; it is currently UNDEPLOYED/UNEXECUTED.
2. Approve a narrow Sales-location manager authorization rule and the exact active location(s); no inferred department/folder policy is permitted.
3. Reconcile the generated types/current database with the proposed additions and verify existing Drive/register policies against an isolated target.
4. Review a deterministic structured renderer plus byte/hash contract for a selected MIME type; the local HTML renderer is preparation only and is not a materializer.
5. Review the server-only staging adapter, storage-attempt receipt shape, and policy boundary for `project-drive` without widening general bucket access.
6. Complete isolated real-caller, non-admin, rollback, replay/conflict/concurrency, storage-compensation, and caller-RLS readback acceptance.

Deliberately excluded: applying SQL; changing existing Drive/register/storage policies; renumbering documents; making a folder; project binding/migration; issuing/download/release; UI Save activation; template activation; users/roles/grants; fixtures; or publication.
