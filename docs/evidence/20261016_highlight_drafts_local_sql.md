# Separate highlight draft SQL — 16 October 2026

Prepared independently saved private highlight drafts in a separate version table, with optimistic version checks, stable exact replay, versioned clear and own-draft readback. No client publication/access or notification is enabled. Shared private draft authority was extracted from the existing note checks without widening its assigned-reviewer scope.

Run C:/Users/Admin/AppData/Local/Temp/ssm-feasibility-fa7b8d2bf8684593a96d042066a332d3 passed HIGHLIGHT_DRAFT_LOCAL_PASS channels=independent replay=stable stale=denied clear=versioned default_reads=closed publication=none. Test confirms saving a private note does not populate the highlight, draft edits/clear do not modify that note, replay is stable, stale update fails, separate readback matches and authenticated/anon default table reads remain closed. All previous note/caller/rollback/repin/overlap and feasibility suites also passed against the shared helper refactor. Independent server status reports stopped.

Owner execution and synthetic identity helpers remain limits for this new draft path. Dedicated draft non-admin caller/rollback/concurrency checks, managed installation, publication/recipient notification and browser/UI integration remain pending. No screenshot or application build for SQL-only preparation; no working client highlight claimed.
