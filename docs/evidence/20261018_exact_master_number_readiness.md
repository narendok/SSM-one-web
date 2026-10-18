# Exact immutable Master version-number readiness — 18 October 2026

The read-only feasibility planner now requires a verified positive safe-integer Master version number from the immutable requirement source projection, and compares it with the assigned review's version number as well as its Master version UUID. Mismatch yields STALE; missing/invalid source number yields UNSUPPORTED_UNVERIFIED. Advancing a mutable Master header does not invalidate the exact pinned historical version.

The new source number is explicitly a derived requirement_data.source field, not a presumed database column. Its JSON location is already used by the inspected protected assignment SQL. No aggregate read was changed, no new database column queried, no UI/approval/start gate activated and no backend records/permissions changed. Callers lacking the verified projection remain blocked.

Focused tests: 31 passed, including mismatched number with the same Master UUID, missing/null/nonpositive/fractional/nonfinite/unsafe source numbers, preserved historical pins and all prior peer-conflict cases. TypeScript no-emit and production Vite/Nitro build both passed (exit 0). Existing build deprecation warnings remain. This is local source acceptance only, not managed JWT/RLS or live browser workflow acceptance. No screenshot of pending work was taken.
