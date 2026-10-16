# Internal notes local SQL verification — 16 October 2026

Prepared an atomic, source-only private reviewer-note save transaction with retained versions, exact requirement/Master pins, current assigned-reviewer/membership checks, optimistic version conflict and actor/payload-bound request replay. Audit excludes note contents. No public/client read or execution access enabled. See pending contract for explicitly missing read/publication/delegation and target race acceptance.

Fresh PostgreSQL 17.11 fixture run: C:/Users/Admin/AppData/Local/Temp/ssm-feasibility-25077d6468914e57a3b095e10a939b9c. Internal-note SQL passed: two retained versions, identical replay, stale expected-version rejection, changed replay-payload rejection, wrong source pin rejection, revoked membership rejection before replay, unauthorized actor rejection and default authenticated table/function access unavailable. Existing compatibility, handover/replay and root-contention suites passed in the same run. This proves synthetic SQL behavior under owner execution and configured helper identities, not actual non-admin JWT/RLS callers. Independent status confirms no server running and password file absent.

No app integration, managed install/grants, independent shared-read resolver, notification/publication or live persistence is claimed. No UI screenshot/build needed for pending SQL-only changes. New objects and their removal/data retention require reviewed deployment/restore planning before target installation.

## Synthetic non-superuser caller and audit rollback

Extended runner with requirement_internal_notes_caller_rollback_local_acceptance.sql. Its transaction temporarily grants execution in the disposable fixture only and SET LOCAL ROLE authenticated. The assigned synthetic actor receives its saved note/version through the SECURITY DEFINER function; direct table SELECT raises insufficient_privilege. A separate synthetic actor is denied. An injected internal-note audit trigger failure rolls back the new note version/request: exactly one successful note and one metadata audit remain. Test grants, trigger, data and helper roll back together.

Run C:/Users/Admin/AppData/Local/Temp/ssm-feasibility-ff91edc8b14f496a814f94c270c6144b passed with INTERNAL_NOTE_CALLER_ROLLBACK_PASS role=authenticated direct_read=denied audit_failure=atomic unauthorized=denied. All preceding local suites passed; server status after completion reports no server running.

This advances local role/atomicity evidence beyond owner-only calls. Identity still comes from synthetic auth.uid/GUC helpers; no managed JWT, live users, target RLS/publication or production grants are accepted. No UI feature success claimed or screenshot captured.

## Author-only exact-source readback

Pending read_own_requirement_internal_note now rechecks current assigned reviewer, engineering permission, active membership/department and exact requirement/Master provenance under the same root before returning only that author's latest note for the requested tuple. No cross-department discovery/client access is introduced. No note returns null; no raw table access is granted. Note version counters now include source revision and Master identity so a future repin starts an independent note stream without overwriting history.

Final local run: C:/Users/Admin/AppData/Local/Temp/ssm-feasibility-3c4b76dab1e041e5adabdd178ea63c49. Existing role/rollback test additionally verifies a separate resolver call equals the saved note and rejects a wrong-source read and unauthorized actor. All preceding SQL suites pass and runner reports shutdown. This remains a pending contract; no installed resolver, UI save/read or managed JWT acceptance claimed. Revision-stream reset semantics are source-reviewed but not yet covered by a multi-revision fixture case.

## Repin and explicit clear acceptance

Added a synthetic requirement/Master repin case. The owner changes only the disposable source graph inside a rolled-back transaction; this is not a live revision-edit workflow. Old-source read and request replay are denied, new-source read begins null, new-source note version starts at 1, explicit empty-body clear creates version 2, and separate readback returns that latest empty version. All three historical records remain, including the original source note unchanged.

Run C:/Users/Admin/AppData/Local/Temp/ssm-feasibility-8f7de34a516c4f33a63d2d60b0e2ebf1 passed INTERNAL_NOTE_REPIN_PASS old_history=preserved old_scope=denied new_counter=1 clear_version=2 latest_read=exact. Other local suites pass; independent pg_ctl status reports no running server. This closes the prior untested revision-stream-reset case only. No managed deployment, real revision changes, client publication or visible feature completion claimed.

## Overlapping note saves

Two local sessions now exercise the same author's same-source expected-version=0 saves. First saves its note and holds the requirement root until commit. Runner observes a readiness marker, then the second session independently confirms pg_try_advisory_xact_lock cannot acquire that root before attempting its save. After the first commits, the second receives the exact optimistic-conflict error, reads the winning version and verifies no losing request was stored. This checks a real overlapping pair, rather than simply running sequential stale saves.

Final run C:/Users/Admin/AppData/Local/Temp/ssm-feasibility-e4031258d7ec41d1894ce280c5b2f882 records INTERNAL_NOTE_OVERLAP_OBSERVED and INTERNAL_NOTE_CONCURRENT_PASS winner=preserved stale_writer=denied losing_request=absent. Remaining local suites also pass; independent status confirms no running server. This is synthetic owner/session evidence with fixture auth helpers; managed concurrency, capability-revocation races and browser acceptance remain pending. No screenshot or app build for SQL harness-only work.
