# Task assignee visibility — 16 October 2026

Corrected actual TaskBoard counts and board/table/summary plus TaskDrawer labels. Assignment state now comes from canonical assignee_id, not whether the joined member display record is present. A missing/inaccessible member join can mean unavailable data rather than an unassigned task. Assigned rows without a matching visible member show Assigned member unavailable; no member identity is fabricated or exposed. True null assignment remains Unassigned.

Nine TaskBoard DOM checks pass, including a task with a saved member ID but no joined member: zero unassigned, unavailable label, no leaked/assumed display name. TypeScript noEmit and production build pass, with bounded worker concurrency used after typecheck. Existing jsdom scrollTo warnings are unrelated and do not fail assertions. Unrelated generated routes restored.

No query, assignment, permissions or RLS change. This is tested source handling, not a real denied-member browser session or live deployment. No screenshot captured. Work remains local pending the previously requested public-push approval.
