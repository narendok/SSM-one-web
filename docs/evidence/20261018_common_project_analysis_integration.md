
### Common project analysis route integration — 18 October 2026

The user reiterated that the previously approved compact analysis UI must be completed, including department editing and basic internal/client projections. The requirement remains in the approved UI baseline and department project management sections; no new layout selection is needed.

A bounded internal read integration now places ProjectAnalysisSummary at the top of the existing project overview: linked baseline/handover context, recorded phase/health/priority, visible blocked tasks, next open work ordered by due date, and collapsed canonical department/task summaries. It uses the same project_tasks query key and fetchTasks contract as the existing common TaskBoard. Canonical department_id alone controls grouping; legacy department labels never confer scope. Failed reads show unavailable rather than zero work. No sample records, parallel task table, private remark reads, client publication, new edit grants or managed SQL were introduced.

Three DOM tests passed for canonical ID grouping despite contradictory labels, denied reads, and unclassified task handling. TypeScript passed. Production build verification is being recorded separately below. This is local source preparation, not managed browser acceptance or completion of the full approved design. Remaining: exact design composition/reference and dependency contracts, verified department membership/delegated editing, durable remarks/highlights integration, and an accepted opportunity/client/revision publication resolver. Existing task editing remains subject to backend RLS; no department authority or client access is inferred from this summary.

Production build completed successfully (vite/nitro); log: C:/Users/Admin/AppData/Local/Temp/ssm-project-analysis-build.log. Generated route/MCP files were clean before validation and restored afterward. No managed browser acceptance claimed.
