# Independent task readback — 17 October 2026

Task create/update now perform a separate caller-authorized project_tasks SELECT after checking the mutation representation. Readback must return the same ID and every submitted scalar value. A denied/missing read reports that the write may already have saved and requires refresh/review; no automatic retry or rollback claim is made. A concurrent value mismatch fails confirmation. No policy, grant, schema, fixture or identity was changed.

Focused mutation suite: 15 tests passed, including independent SELECT, denied post-write read and conflicting creation readback without a second insert. Typecheck/build results follow after completion. Mocked checks are not live persistence/RLS acceptance.

Read-only browser inspection of the original managed project opened existing OPPORTUNITY-2026-0013. The actual Feasibility tab shows MASTER-2026-0001 revision 1, zero assigned reviews, disabled Send for feasibility, missing immutable provenance and unverified client approval/baseline lock. This confirms the workflow is still unavailable in the managed preview. No writes, Publish, permission changes, generated Lovable request or screenshots were performed. It does not verify local UI integration or non-admin access.
TypeScript no-emit check passed.

Production Vite/Nitro build passed with two native workers. Unrelated generated route/auth/MCP files restored to their clean pre-build content.
