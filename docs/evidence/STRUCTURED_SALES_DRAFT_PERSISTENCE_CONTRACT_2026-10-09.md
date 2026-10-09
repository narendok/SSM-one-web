# Structured Sales draft persistence contract — 2026-10-09

## Status and scope

**SOURCE-ONLY DESIGN. All names in the proposed contract below are UNDEPLOYED.**

This record corrects a scope boundary in the pending lifecycle document-draft proposal. Installing either of these existing proposals would **not** make editable Sales SOR, Contract Review, or PRS documents persistable:

- `supabase/pending/20261003_lifecycle_document_draft_generation.sql` — production-unapplied;
- `supabase/pending/20261004_lifecycle_document_actor_transport.sql` — unapplied actor transport proposal.

The existing proposal only supports a committed project, four server-rendered fields (`PROJECT_CODE`, `PROJECT_NAME`, `PROJECT_REVISION`, `DEPARTMENT`), and a canonical `text/plain` `.txt` object. Its commit routine rejects every other template token and only accepts a staged file that exactly equals its own project/template rendering. It has no persisted structured-edit payload, no Sales opportunity pin, and no Master Specification revision pin.

The existing Sales UI is consequently a local-only review surface. `fetchStructuredTemplatePreviewSource` verifies caller-visible `sales_opportunities → master_specifications → master_specification_versions` records and optionally reads a project by `opportunity_id`, but it does not establish a required committed-project binding. The SOR, Contract Review, and PRS editor state is intentionally memory-only.

No SQL, schema, migration, application flow, storage object, data record, role, grant, credential, activation, or publication is changed by this document.

## Authoritative boundaries already present

| Concern | Existing contract | Status | Consequence |
| --- | --- | --- | --- |
| Sales source pin | `src/lib/lifecycle-structured-template-previews.functions.ts` | Deployed read path | Confirms exact caller-visible opportunity/customer/specification/version tuple for preview only. |
| Local edit shapes | `src/lib/lifecycle-structured-template-previews.ts` | Local-only UI model | Defines document-kind-specific fields and typed tables, but has no persistence schema or validation boundary. |
| Project document render | `src/lib/lifecycle-document-preflight.server.ts`, `src/lib/lifecycle-document-fields.ts` | Source implementation for pending proposal | Server loads a committed project and emits only four project tokens. |
| Immutable template source | `20261003_lifecycle_document_draft_generation.sql` | **UNDEPLOYED** | Pins an immutable department template body, but activation only allows four project tokens. |
| Atomic Drive/register/audit receipt | `20261003_lifecycle_document_draft_generation.sql` | **UNDEPLOYED** | Stages object bytes, then atomically creates Drive metadata/revision, controlled register, audit event, and immutable receipt. |
| Trusted caller transport | `20261004_lifecycle_document_actor_transport.sql` | **UNDEPLOYED** | Service-only gateway carries a verified web actor into allowlisted lifecycle routines; it does not make Sales edits authoritative. |
| Master Specification history | `master_specifications`, `master_specification_versions` read model | Deployed read evidence; protected write hardening remains separate | A version can be selected for preview, but a persisted document must pin its exact immutable tuple and never follow `current_version`. |

The failed Sales SQL assembly is separate from these lifecycle proposals. It neither supplies this contract nor can it be treated as lifecycle document-persistence acceptance.

## Minimal proposed contract — UNDEPLOYED

### 1. One source-binding resolver, before any draft read or write

**Proposed UNDEPLOYED routine:** `public.resolve_structured_sales_document_source(...)`.

Inputs must be immutable identifiers only:

- document kind: `SOR`, `CONTRACT_REVIEW`, or `PRS`;
- opportunity ID;
- Master Specification ID and exact version ID/number;
- explicit binding mode: `PROJECT_BOUND` or `OPPORTUNITY_ONLY`;
- for `PROJECT_BOUND`, project ID and target Drive folder ID;
- immutable template ID, version, and content-revision ID;
- client request key and expected current draft revision number when editing.

The resolver locks and verifies, in one transaction:

1. caller authorization for every requested resource;
2. opportunity exists and its customer matches the Master Specification customer;
3. Master Specification belongs to that exact opportunity/customer;
4. Master Specification version belongs to that specification and exact version number;
5. `PROJECT_BOUND` requires an existing committed project whose `opportunity_id` equals the pinned opportunity, whose department/Drive root/revision are complete, and whose target folder is under that canonical root;
6. `OPPORTUNITY_ONLY` cannot infer a project, department, Drive root, folder, or project token. It requires an explicitly authorized Sales document location and must be rejected until one is governed;
7. template is active, immutable, approved for the resolved document scope, and its expected editable-field schema is an exact match for the document kind;
8. any existing receipt/draft belongs to the verified actor and exactly the same binding/pins.

A project merely being absent or a project row merely sharing a value must never be silently converted into a binding. A later project link cannot rewrite an opportunity-only draft. Null-department or null-Drive project data remains a hard failure, not inferred ownership.

### 2. Immutable pins and canonical fingerprints

**Proposed UNDEPLOYED receipt fields:**

- opportunity ID and customer ID;
- Master Specification ID, exact version ID, version number, canonical source JSON hash, and source timestamp;
- binding mode plus nullable project ID only when `PROJECT_BOUND`;
- immutable template ID, version, content-revision ID, content hash, and editable-schema version/hash;
- target Drive folder/root IDs only for a project-bound draft;
- canonical editable-payload hash, rendered-object hash, request key, draft revision number, parent receipt ID, actor, and timestamps.

The protected routine derives source values from the locked Master Specification version and template from its immutable revision. It must calculate the canonical source fingerprint over every pin above; it must never accept browser-supplied source fields, customer IDs, rendered content, document number, audit data, or current-version claims.

### 3. Structured editable payload validation

**Proposed UNDEPLOYED schema registry:** `structured_sales_document_schemas` or equivalent immutable template-revision metadata — the final physical table name is intentionally not selected here.

The registry must make field validation server-owned and versioned per document kind. It must express, at minimum:

- allowed scalar keys, required/optional state, type, length and enum/range limits;
- exact typed-table column sets, stable row-ID rule, row limits, cell limits, numeric precision/scale, and no unknown columns;
- documents that cannot record decisions, customer authorization, release, baseline, commercial approval, or feasibility approval through local-note fields;
- a canonical JSON ordering/normalization algorithm shared by server and SQL contract tests.

For the current UI, this means the established SOR, Contract Review, and PRS field sets can be proposed as explicit schemas, not an open `Record<string, unknown>`. Existing quote, BOM, review, and local table shapes must each receive their own later scope decision; they are not implicitly included by this group.

Validation rejects unknown keys, duplicate row IDs, malformed numbers, unsafe non-string shapes, out-of-range content, a schema/template mismatch, or an attempt to write derived source fields. Validation must happen before storage staging and before any receipt lookup that might disclose a protected draft.

### 4. Safe rendered output and file types

The persisted editable payload is canonical JSON, not executable HTML. User and source text remain data:

- render only from server-owned template/structured layout definitions;
- escape text in every HTML representation; forbid scripts, event attributes, active URLs, raw HTML injection, and browser-provided markup;
- generate deterministic text/HTML/PDF bytes only from validated canonical data;
- bind MIME type, extension, byte length, and SHA-256 to the selected renderer in the server contract;
- do not reuse the current `.txt`-only regular-expression path for structured documents.

A PDF or HTML materializer is not implied by this design. It requires an accepted deterministic renderer and byte/hash tests before it can be added. Until then, no editable document save exists.

### 5. Revision, replay, and conflict rules

**Proposed UNDEPLOYED operations:** `create_structured_sales_document_draft`, `save_structured_sales_document_revision`, `find_structured_sales_document_receipt`, and `can_discard_structured_sales_document_object`.

They must implement:

- create once per actor, document identity, and request key; an exact retry returns the same immutable receipt;
- an existing request key with a different source pin, template/schema pin, binding, payload hash, target, MIME/rendered hash, or expected revision fails as a conflict;
- updates are append-only draft revisions with `expected_revision_number`; stale optimistic edits fail without staging or metadata writes;
- no edit mutates an approved/released revision, a prior editable revision, its Drive revision, its register record, or its audit event;
- source/template/schema advance requires a new revision or new draft according to an explicit server-owned policy; it never silently re-renders or overwrites user edits;
- update requests lock the logical draft identity and parent revision before receipt/replay evaluation, so concurrent saves converge to one result or a conflict.

### 6. Drive, controlled register, audit, and storage compensation

For project-bound drafts, reuse the established *pattern*, not the current routine unchanged:

1. resolve and authorize the complete Sales/project/template source graph;
2. validate editable payload and server-render the exact bytes;
3. stage a unique storage object through the protected server adapter;
4. register the attempt with actor, request key, canonical pins, payload/render hashes, MIME, size, bucket, and path;
5. atomically insert the new Drive node/revision, DRAFT controlled-document register row, immutable structured-draft receipt/revision, and one audit event; consume the exact storage attempt in that same transaction;
6. only discard an object after the server proves the exact attempt is unreferenced and cleanup-eligible.

The atomic transaction must preserve existing document numbering and Drive ancestry rules. The controlled register and audit payload must record the immutable Sales/source/template/edit-revision provenance rather than mutable "current" Sales fields. An opportunity-only document cannot reuse the project Drive/register flow until a separately governed Sales document location and register ownership contract exists.

## Acceptance dependencies — all unmet for persistence

1. A reviewed, additive SQL proposal that implements the complete structured contract above, with explicit grants and RLS policies for every new public table.
2. A reviewed actor-preserving authenticated server action that accepts only immutable identifiers, request key, expected revision, and validated edit payload; it must use the service-only actor transport only after `requireSupabaseAuth` establishes the caller.
3. A deterministic structured renderer and storage adapter for an agreed MIME/file policy, including byte/hash equality with the database contract.
4. Read-only caller-RLS observation capable of proving the source pins, payload/revision chain, Drive revision, register, audit, receipt, and storage-attempt linkage without privileged substitution.
5. Approved isolated login-capable in-scope non-admin manager and out-of-scope non-admin caller identities, with a disposable existing opportunity, exact Master Specification version, and—only for project-bound tests—an explicit committed project/Drive root/target folder.
6. Isolated execution proof for source mismatch, project/opportunity mismatch, absent-project no-inference, cross-customer denial, malformed/unknown edit rejection before writes, XSS-safe output, first save, exact replay, edit conflict, stale revision, template/source advance, outsider/direct-transport denial, register/audit rollback, storage compensation, and parallel request convergence.
7. Separate review of the Sales protected-write assembly. Its acceptance is distinct and cannot stand in for lifecycle/Drive/storage acceptance.

## Exact next implementation group

**Group name: Structured Sales draft contract proposal and isolated acceptance specification — source only.**

1. Add a new **UNDEPLOYED** pending SQL proposal plus focused SQL acceptance fixtures for the source resolver, immutable pins, schema registry, append-only edit revisions, and receipt graph. Do not apply it.
2. Add browser-safe shared TypeScript types and pure canonicalization/validation tests for the current SOR, Contract Review, and PRS fields only. Do not add a save control or server action.
3. Define a server-only preflight interface and deterministic structured renderer contract, both disabled behind the existing mutation gate. Do not stage files or call lifecycle mutations.
4. Add an isolated real-caller checklist that keeps opportunity-only and project-bound acceptance cases distinct, and refuses original/shared targets.

This group deliberately excludes Sales requirement/commercial/baseline changes, template activation, actual storage uploads, generation, migration application, permissions, user setup, and publishing.
