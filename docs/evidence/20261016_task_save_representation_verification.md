# Task save representation verification — 16 October 2026

Existing task create/update helpers now request the submitted scalar fields alongside the row ID in the mutation response. They verify each submitted value, including project/department/member identity, exact status, priority and due date, before reporting success. Missing or changed server-returned values fail with a refresh/review instruction. Existing joined display fields remain excluded from update payloads. RLS, auth and mutation paths are unchanged.

This is the representation returned by the mutation, not an independent subsequent SELECT or durable history receipt. A failure may follow a committed write: refresh/review before retrying; do not infer rollback. Later concurrent changes remain possible. This does not prove delegated editing authority or live readback.

Validation: 16 focused task mutation and actual TaskDialog DOM tests passed, TypeScript noEmit passed, production Vite build passed. Added cases reject ID-only/changed deadline or assignee representations and wrong saved project on creation. Existing denial, Cancel and failed-save interactions remain covered. Build-generated unrelated route changes were restored to their previously clean contents.

No managed writes, new users, deployment, browser persistence claim or screenshots for source-only work. Live route/caller checks remain pending.
