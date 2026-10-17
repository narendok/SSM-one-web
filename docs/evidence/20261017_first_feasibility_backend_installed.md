# First feasibility backend bundle installed — 17 October 2026

User specifically approved the first backend installation. Executed the unchanged first bundle on the original project's Cloud SQL editor, through the locally tested 98_direct_editor.sql payload from pinned public source commit 561f2caf1888ea282a7500aa617a7473c5a90e47. Browser-loaded and editor Copy text matched exactly at 75572 characters before Run. The editor displayed Query succeeded. The source payload itself checks normalized-LF 53542 bytes and SHA256 a990777fe0c51ca4d12b6d3c6adcce3f35e0028fe4de5805d9303ae26ed12d9e before any graph DDL. No business action was submitted.

The direct editor avoided the managed migration tool, which had first truncated SQL and subsequently attempted unrelated organizations creation (42P07). Tool summaries claiming no partial transport were incomplete: a later check found the isolated empty staging schema. Direct precheck confirmed zero chunks; final transaction verified its owner and removed only that staging table/schema, without CASCADE. Do not rerun the migration tool or repair/rewrite migration history automatically.

Independent committed-catalog export: docs/evidence/20261017_feasibility_installed_catalog.json. Original downloaded CSV: C:/Users/Admin/Downloads/query-results-export-2026-10-17_16-30-19.csv.

Verified after commit:
- All five provenance columns present; UNIQUE (source_revision_id, department_id).
- assign_requirement_feasibility_review, record_requirement_feasibility_response, read_requirement_feasibility_response_receipt and submit_sales_feasibility_handover installed with exact signatures, owner postgres, SECURITY DEFINER, search_path=public, pg_temp.
- Authenticated/service_role execution allowed for the four scoped routines; anon execution denied.
- Both private receipt tables have RLS and no anon/authenticated direct SELECT/INSERT/UPDATE/DELETE privileges.
- Existing graph table ACL/RLS/policy definitions were compared inside the installation transaction and remained unchanged. The committed catalog retains the six preexisting Sales/admin ALL and Sales/Engineering/admin SELECT policies.
- Review, handover-receipt and response-receipt counts are all zero. No handover/review notification, client approval or project start was performed.
- Transport schema absent after commit.

Managed read-only missing-actor check: BEGIN READ ONLY; clear transaction-local JWT claim/sub settings; SET LOCAL ROLE authenticated; call the four exact RPCs and assert their specific actor/scope denial messages; ROLLBACK. Observed MANAGED_MISSING_ACTOR_DENIAL_PASS four protected RPCs denied without identity; read-only rollback; not real-JWT acceptance. No identities, roles, grants or business rows were created by this check. This is a managed PostgreSQL role/context test, not an ordinary user JWT end-to-end test.

Read-only pg_proc body-pattern inventory found exactly the three newly installed protected graph writers; signatures and effective EXECUTE privileges are retained in 20261017_installed_requirement_graph_writers.csv. No installed archive/restore or concrete department-remapping writer was observed. This static SQL-pattern inspection is not proof that arbitrary privileged dynamic SQL cannot write; do not invent hypothetical writers as a universal blocker. Existing direct table writes remain a concrete separate transition.

Still pending: real permitted/denied caller and membership acceptance, durable notification delivery, exact saved/readback UI evidence, separate original-target direct-write transition and migration-history alignment. First-bundle installation does not enable UI controls or complete the phase. Internal remarks/highlight drafts, publication/client resolver, conflict resolution and exact-Master feasibility pass, client approval/baseline lock, and explicit optional Research/POC or justified Pilot decision remain separate scoped work. No other pending SQL, private-draft permissions, archive/restore, user creation, credential change, deployment/Publish, or business approval was performed.
