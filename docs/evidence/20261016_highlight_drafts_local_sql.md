# Separate highlight draft SQL — 16 October 2026

Prepared independently saved private highlight drafts in a separate version table, with optimistic version checks, stable exact replay, versioned clear and own-draft readback. No client publication/access or notification is enabled. Shared private draft authority was extracted from the existing note checks without widening its assigned-reviewer scope.

Run C:/Users/Admin/AppData/Local/Temp/ssm-feasibility-fa7b8d2bf8684593a96d042066a332d3 passed HIGHLIGHT_DRAFT_LOCAL_PASS channels=independent replay=stable stale=denied clear=versioned default_reads=closed publication=none. Test confirms saving a private note does not populate the highlight, draft edits/clear do not modify that note, replay is stable, stale update fails, separate readback matches and authenticated/anon default table reads remain closed. All previous note/caller/rollback/repin/overlap and feasibility suites also passed against the shared helper refactor. Independent server status reports stopped.

Owner execution and synthetic identity helpers remain limits for this new draft path. Dedicated draft non-admin caller/rollback/concurrency checks, managed installation, publication/recipient notification and browser/UI integration remain pending. No screenshot or application build for SQL-only preparation; no working client highlight claimed.

## Dedicated highlight draft caller/rollback checks

Separate fixture test temporarily grants highlight draft RPC execution in a rolled-back transaction and uses SET LOCAL ROLE authenticated. Assigned caller saves and independently reads the exact draft; direct draft-table and wrong-source reads are denied. Unauthorized read and save use separate exception blocks, preventing an earlier denied read from masking the save check. Internal-note test corrected similarly. Injected highlight audit failure leaves one successful draft and audit, with no failed request persisted.

Run C:/Users/Admin/AppData/Local/Temp/ssm-feasibility-ca5370e5e79c45539895fb1d2abe5803 passed HIGHLIGHT_DRAFT_CALLER_ROLLBACK_PASS role=authenticated direct_read=denied audit_failure=atomic unauthorized=denied and preceding local suites. Independent server status confirms stopped. Synthetic identity helpers/local roles are not managed JWT, client publication or browser acceptance. No target permissions or application gate changed.

GitHub push is pending explicit destination/payload approval after automatic approval review rejected the combined commit/push action as potentially sensitive project data egress to a public repository. Local source/tests are retained for review; do not retry egress without resolving this gate.

## Dedicated overlapping highlight draft saves

Added separate overlapping draft sessions with distinct request keys and an observed held requirement root. Second session confirms pg_try_advisory_xact_lock cannot acquire that root before saving. Once the winning draft commits, the stale expected-version=0 write fails with the exact draft conflict message. Independent own-draft read returns the winning version and the losing request is absent.

Run C:/Users/Admin/AppData/Local/Temp/ssm-feasibility-932e4cbf76944a76ab5fa8d38d6477df passed HIGHLIGHT_DRAFT_OVERLAP_OBSERVED and HIGHLIGHT_DRAFT_CONCURRENT_PASS winner=preserved stale_writer=denied losing_request=absent. Existing local suites pass. Verified cleanup retained logs and removed stopped disposable data. Still synthetic SQL sessions/helpers; no managed JWT, client publication, notification or browser acceptance. Local-only commit pending the already requested public-push approval.
