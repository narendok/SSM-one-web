
### Basic common-project task view — 18 October 2026

Prepared an explicit readOnly presentation mode in the existing TaskBoard, and applied it to the common project overview board. The same caller-visible task query/cache/records remain in use. Basic view keeps filters, status columns, assignment/priority/date details and a read-only task dialog, while omitting creation/editing drawers/forms and disabling drag/drop mutation handlers. No client projection is inferred; this remains an internal RLS-authorized view. Existing full Tasks tab behavior remains unchanged and still depends on backend authority. This presentation mode is not an authorization boundary and does not remediate the captured legacy task policies.

Ten focused TaskBoard DOM tests passed using one threads worker. The first attempt timed out before a forks worker started (zero tests), then the focused retry passed. TypeScript passed before the production build started. Build completion is recorded below. Department-delegated editing, private remarks/shared reads and exact client publication/resolver remain pending; no new permission, SQL, business rows or Publish. No managed-browser acceptance is claimed for this increment until the synced build is inspected.

Build repair: first production build rejected a newly added non-UTF-8 dialog separator. Re-encoded only that invalid separator; existing UTF-8 content preserved. Rebuild pending completion in ssm-basic-project-build-retry.log.

Final validation: production rebuild passed (vite/nitro). No live mutation or managed browser acceptance was performed. Generated route/MCP artifacts were clean at start and restored after build.
