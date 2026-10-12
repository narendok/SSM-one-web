# Sales Sample Archive Dependency Coverage — Source Review

**Status:** SOURCE-ONLY REVIEW. **ARCHIVE LIVE BLOCKED.**

**Reviewed contract:** `supabase/pending/20261012_sales_sample_archive_restore_contract.sql`  
**Contract SHA-256 at review:** `f16c371be25eefbd7f003ddd3996c330d21aea97b61a360b0898b743f79c90bd`  
**Scope:** the exact ten reviewed roots only: opportunities `OPPORTUNITY-2026-0006` through `OPPORTUNITY-2026-0010` and requirements `CUSTOMER-2026-0003` through `CUSTOMER-2026-0007`.

## Method and protection meanings

The dependency snapshot is read after each root is locked `FOR UPDATE` by `archive_reviewed_sales_samples`. A surface is covered only when a concurrent writer is prevented from adding or rebinding relevant lineage during that root lock by one of these mechanisms:

1. **Archive guard:** the pending contract's narrow `BEFORE INSERT OR UPDATE` trigger takes `FOR KEY SHARE` on the same root row and rejects the write if `archived_at` is non-null.
2. **Parent absence:** the root snapshot requires a direct, guarded parent count to be zero. Its descendants cannot become root lineage unless that direct parent is first created; a verified foreign key/reference path preserves that condition.
3. **Existing writer lock:** an inspected writer function already locks the same root `FOR UPDATE` before the relevant insert. This is evidence for that named writer only, not for arbitrary direct table writes.

An ordinary foreign key alone is **not** concurrency protection: it preserves referential existence but permits a new child against an archived parent unless a root-state guard or writer lock also rejects it. Polymorphic `entity_id` fields have no root foreign-key protection in this review.

## Requirement-root snapshot coverage

| Snapshot key | Table / relation read by `sales_sample_archive_dependency_snapshot` | Existing writer or FK/root-lock evidence | Installed-in-source archive protection | Coverage result / gap |
|---|---|---|---|---|
| `requirementRevisions` | `public.customer_requirement_revisions.requirement_id` | Fixture and reviewed schema use a requirement foreign key. | `sales_sample_archive_guard_requirements` calls `sales_sample_archive_reject_archived_requirement_lineage`, takes `FOR KEY SHARE` on `customer_requirements`, and rejects archived roots. | **Covered** for inserts/rebinding of revisions. |
| `feasibilityReviews` | `public.requirement_feasibility_reviews.requirement_id` | Fixture exposes only a plain `requirement_id`; no inspected writer/root lock or archive trigger was found. | None. | **Uncovered blocker.** A writer can add a review after the archive snapshot without conflicting with the root lock. |
| `commercialRecords` | `public.sales_commercial_records.requirement_id` | `save_sales_commercial_record` is an inspected protected writer in `20261006_sales_bound_requirement_creation.sql`; no archive-state trigger covers direct or future writers. | None. | **Uncovered blocker.** The named writer and any direct writer need a root archived-state recheck/guard before live activation. |
| `baselines` | `public.requirement_baselines.requirement_id` | `approve_sales_requirement_baseline` locks the requirement `FOR UPDATE` before inserting a baseline. | Existing writer lock only. | **Partially evidenced, not complete.** No table-level root-state guard prevents another legitimate writer path or direct insert; do not treat as archive-safe. |
| `changeRequests` | `public.requirement_change_requests.requirement_id` | Fixture exposes only a plain `requirement_id`; no inspected writer/root lock or guard was found. | None. | **Uncovered blocker.** |
| `projectDesignInputs` | `public.project_design_inputs.source_requirement_id` or `source_revision_id` | Relationship is indirect and no inspected lock/trigger serializes either source reference with the requirement root. | None. | **Uncovered blocker.** Both requirement and revision-based writes can change the snapshot. |
| `handovers` | `public.sales_project_handovers.baseline_id` joined through `requirement_baselines` | Indirect baseline relation; no inspected writer/root lock or archive guard was found. | None. | **Uncovered blocker.** A handover can appear through a baseline lineage path. |
| `portalShares` | `public.customer_portal_shares.entity_id` | Polymorphic `entity_id`; fixture has no foreign key. | None. | **Uncovered blocker.** |
| `provenance` | `public.data_provenance.entity_id` | Polymorphic `entity_id`; fixture has no foreign key. | None. | **Uncovered blocker.** |
| `registry` | `public.entity_registry.entity_id` | Polymorphic `entity_id`; fixture has no foreign key. | None. | **Uncovered blocker.** |
| `externalAccess` | `public.external_access_events.entity_id` | Polymorphic `entity_id`; fixture has no foreign key. | None. | **Uncovered blocker.** |
| `history` | `public.activity_log.entity_id` | `activity_log` is append-only business history but its `entity_id` is polymorphic in the fixture; several source writers append history. | None. | **Uncovered blocker.** A concurrent append can evade the snapshot and make restoration unsafe. |

## Opportunity-root snapshot coverage

| Snapshot key | Table / relation read by `sales_sample_archive_dependency_snapshot` | Existing writer or FK/root-lock evidence | Installed-in-source archive protection | Coverage result / gap |
|---|---|---|---|---|
| `requirements` | `public.customer_requirements.opportunity_id` | Fixture has an opportunity foreign key. `create_sales_bound_customer_requirement` is an inspected writer, but no archive root-state trigger covers this child table. | None. | **Uncovered blocker.** A new requirement can be attached after the opportunity snapshot; an FK alone permits it. |
| `masterSpecifications` | `public.master_specifications.opportunity_id` | `create_sales_opportunity_with_initial_master_specification` creates one with its new opportunity; no general archive guard/root lock was found. | None. | **Uncovered blocker.** |
| `ndaRecords` | `public.sales_nda_records.opportunity_id` | Fixture exposes only a plain `opportunity_id`; no inspected writer/root lock or guard was found. | None. | **Uncovered blocker.** |
| `documentLocations` | `public.sales_opportunity_document_locations.opportunity_id` | Fixture uses an opportunity foreign key. | `sales_sample_archive_guard_document_locations` uses the opportunity root `FOR KEY SHARE` guard. | **Covered.** |
| `structuredDrafts` | `public.sales_opportunity_structured_drafts.opportunity_id` | Reviewed draft metadata table has `ON DELETE RESTRICT` opportunity FK. | `sales_sample_archive_guard_structured_drafts`. | **Covered, conditional on this pending table being installed.** |
| `structuredRequests` | `public.sales_opportunity_structured_draft_requests.opportunity_id` | Reviewed draft-request table has `ON DELETE RESTRICT` opportunity FK. | `sales_sample_archive_guard_structured_requests`. | **Covered, conditional on this pending table being installed.** |
| `structuredStorageAttempts` | attempt joined through `structured_draft_requests` | Attempts reference a request key; snapshot requires `structuredRequests = 0`. | **Parent absence** through the guarded request surface. | **Covered as a descendant only** while request-key FK/relationship remains enforced. |
| `structuredRevisionLocations` | location joined through revision → draft | Revision locations depend on a draft; snapshot requires `structuredDrafts = 0`. | **Parent absence** through the guarded draft surface. | **Covered as a descendant only** while the reviewed draft/revision references remain enforced. |
| `structuredPrivateLocations` | private location reached through revision location → revision → draft | Root linkage exists only through the guarded draft chain. | **Parent absence** through the guarded draft surface. | **Covered as a descendant only**; no independent root writer is asserted. |
| `structuredAudits` | audit joined through draft | Audit is reached through a draft; snapshot requires `structuredDrafts = 0`. | **Parent absence** through the guarded draft surface. | **Covered as a descendant only**. |
| `structuredMaterializations` | `public.sales_opportunity_structured_draft_materializations.opportunity_id` | Reviewed materialization contract resolves/locks the opportunity before materialization. | `sales_sample_archive_guard_structured_materializations`. | **Covered.** |
| `structuredDriveNodes` | `drive_nodes` reached through draft materializations, locations, or private draft locations | No direct opportunity key; all reviewed paths are descendants of a guarded direct parent. | **Parent absence** via guarded location/draft/materialization surfaces. | **Covered only for the enumerated reviewed paths.** A new Drive-to-opportunity relation would require review. |
| `structuredDriveRevisions` | `drive_node_revisions` reached through draft materialization | No direct root key. | **Parent absence** through guarded draft materialization. | **Covered only for this reviewed descendant path.** |
| `structuredRegisters` | `document_control_registers` reached through draft materialization | No direct root key. | **Parent absence** through guarded draft materialization. | **Covered only for this reviewed descendant path.** |
| `structuredDocxAssignments` | `public.sales_opportunity_structured_docx_assignments.opportunity_id` | Pending DOCX contract defines the direct root relation. | `sales_sample_archive_guard_docx_assignments`. | **Guard present, but prerequisite absent from deployed state is not proven.** |
| `structuredDocxRequests` | `public.sales_opportunity_structured_docx_requests.opportunity_id` | Pending DOCX contract defines the direct root relation. | `sales_sample_archive_guard_docx_requests`. | **Guard present, but prerequisite absent from deployed state is not proven.** |
| `structuredDocxStorageAttempts` | attempt joined through DOCX request | Attempts reference a request key; snapshot requires DOCX requests to be zero. | **Parent absence** through guarded DOCX request. | **Conditional only:** requires the pending DOCX request/attempt tables and their relationship. |
| `structuredDocxReceipts` | receipt joined through DOCX request | Receipts reference a request key; snapshot requires DOCX requests to be zero. | **Parent absence** through guarded DOCX request. | **Conditional only:** requires the pending DOCX receipt table and relationship. |
| `structuredDocxMaterializations` | `public.sales_opportunity_structured_docx_materializations.opportunity_id` | Pending DOCX materialization contract defines the direct root relation. | `sales_sample_archive_guard_docx_materializations`. | **Guard present, but prerequisite absent from deployed state is not proven.** |
| `structuredDocxAudits` | audit joined through DOCX request | Audits are reached through a DOCX request; snapshot requires DOCX requests to be zero. | **Parent absence** through guarded DOCX request. | **Conditional only:** requires the pending DOCX audit table and relationship. |
| `structuredDocxDriveNodes` | `drive_nodes` reached through DOCX materialization | No direct root key. | **Parent absence** through guarded DOCX materialization. | **Conditional only:** requires pending DOCX materialization tables. |
| `structuredDocxDriveRevisions` | `drive_node_revisions` reached through DOCX materialization | No direct root key. | **Parent absence** through guarded DOCX materialization. | **Conditional only:** requires pending DOCX materialization tables. |
| `structuredDocxRegisters` | `document_control_registers` reached through DOCX materialization | No direct root key. | **Parent absence** through guarded DOCX materialization. | **Conditional only:** requires pending DOCX materialization tables. |
| `projects` | `public.projects.opportunity_id` | Fixture exposes only a plain `opportunity_id`; no inspected writer/root lock or guard was found. | None. | **Uncovered blocker.** |
| `portalShares` | `public.customer_portal_shares.entity_id` | Polymorphic `entity_id`; fixture has no foreign key. | None. | **Uncovered blocker.** |
| `provenance` | `public.data_provenance.entity_id` | Polymorphic `entity_id`; fixture has no foreign key. | None. | **Uncovered blocker.** |
| `registry` | `public.entity_registry.entity_id` | Polymorphic `entity_id`; fixture has no foreign key. | None. | **Uncovered blocker.** |
| `externalAccess` | `public.external_access_events.entity_id` | Polymorphic `entity_id`; fixture has no foreign key. | None. | **Uncovered blocker.** |
| `history` | `public.activity_log.entity_id` | Polymorphic history key; source writers append activity. | None. | **Uncovered blocker.** |

## Optional/undeployed DOCX prerequisite finding

The archive contract references all `sales_opportunity_structured_docx_*` tables directly and unconditionally in `sales_sample_archive_dependency_snapshot`, including assignments, requests, storage attempts, trusted receipts, materializations, audits, and their Drive/register joins. The local fixture can create these names, but that is not evidence that every table, column, constraint, trigger, or dependency is installed in the managed environment.

Therefore, even if every non-DOCX writer gap were later closed, **archive activation must remain blocked** until an action-time read-only preflight proves the full DOCX schema prerequisite set exists and matches the reviewed contract, or until an explicitly reviewed compatibility design avoids querying absent tables. The archive package must not silently assume an uninstalled DOCX source group.

## Exact live-activation blocker

**ARCHIVE LIVE BLOCKED:** the current contract has no root-state serialization for multiple snapshot surfaces: requirement feasibility reviews, commercial records, baselines beyond one inspected writer, requirement change requests, project design inputs, handovers, opportunity requirements, master specifications, NDA records, projects, polymorphic portal/provenance/registry/external-access rows, and activity history. In addition, the DOCX tables queried by the snapshot are pending-source prerequisites whose managed installation is not established. The prior DOCX-assignment concurrency proof covers only its guarded direct surface; it does not establish safety for these unrelated writers.

No source contract, schema, grant, policy, data, or live environment was changed by this coverage review. The archive, Procurement, and DOCX deployment gates remain off.