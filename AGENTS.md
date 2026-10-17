# Project rules

See scoped safeguards in `supabase/AGENTS.md` before changing database SQL, and `src/AGENTS.md` before changing application code.

- Keep pending operations database-owned, source/authorization-checked, replay-safe, and separately accepted; never let ordinary client or legacy paths imply approval authority.
- Document authority is exact-source, active-assignee and department scoped; ordinary visibility, Sales access, or admin status must not bypass it. Preserve immutable source/template/version pins, private receipts, append-only audit, and fail-closed verification.
- Legal remains Operations/Legal by default; Sales initiation grants no Legal access. Direct Sales navigation may reuse only an active, locked, exact-source location resolved through caller-authorized discovery.
- Sample cleanup remains review-only without root archive/restore evidence. Procurement contracts remain behind typed caller-authenticated adapters until accepted.
- Project DOCX reassignment is source-only: named people must be active in the assigned department and exact project team; serialize actor/request-key updates before rechecking authority and mutable prerequisites.

## Single planning entry point

Read and update `docs/planning/SSM_ONE_WEB_PORTAL_MASTER_PLAN.md` in place; preserve contracts, pending SQL and evidence. The catalogue is reference only. This repository is the complete web source; Android is separate and historical sibling backups are immutable.

## Workspace authority

Use the original project/backend only. Preserve auth, departments, RLS, numbering, manual edits and history. No competing backend, destructive operation, production test user, privileged access change, or Publish without specific authorization. Code/Git captures are not database or private-storage backups.
