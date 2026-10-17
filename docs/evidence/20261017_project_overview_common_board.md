# Project overview common board — 17 October 2026

The authenticated project overview now embeds the existing TaskBoard in compact board mode, under a collapsible Project work section. The Tasks tab continues to use that same component, TaskDialog and project task records. No new task store, status, department role, backend permission or fixture was introduced.

The overview totals now use the identical project_tasks/project ID/all-departments query key as the common board. Existing board mutation invalidation therefore also refreshes overview totals; previously the overview used a separate key that was not invalidated.

The user confirmed the selected compact analysis UI as final on 17 October. The master plan records that decision; no further design selection is requested.

Verification: existing TaskBoard DOM suite passed all nine tests, including embedded route ownership and unavailable-member display. TypeScript no-emit check passed. Production build result is recorded below after completion.

Limits: this is local source integration in the real authenticated route, not a live deployment or browser acceptance. No actual task was changed and no durable save/readback was performed. Department projections/delegation, private remarks/highlights installation, client publication and lifecycle approval gates remain pending. No screenshot was taken because successful browser operation has not yet been verified. GitHub fetch completed; local HEAD was ten commits ahead of origin/main with no remote-only commits before this change. Public push remains separately blocked pending explicit approval.
Production build passed (Vite/Nitro, two native workers). Existing server-function deprecation warnings remain. Unrelated build-generated route/auth/MCP files were restored to their clean pre-build contents.
