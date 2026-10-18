# Project rules

- Keep candidate-part submission as a pending, database-owned transaction with all source and authorization checks before replay; this prevents inventory and BOM paths from becoming implicit approval paths.
- Keep deviation-note submission separate from legacy project changes and candidate approvals; approval authority, customer approval, closure, and caller reads require independently accepted protected contracts.
- Keep editable structured DOCX generation local until an accepted materialization contract binds immutable source/template/schema pins, an assigned responsible employee, and the private Drive/register revision atomically; department membership alone is never document authorization.
- Keep lifecycle document discovery bound to the committed project and its category; project overview access, Sales access, and normal administrator status must not bypass the accepted assigned-person resolver.
- Keep Legal document discovery separate from Sales initiation: NDA defaults to Operations / Legal until a separately accepted configurable responsibility contract exists, and Sales initiation never grants Legal read or edit access.
- Direct Sales document navigation may reuse only an existing active, locked, non-trashed Sales location bound to the exact opportunity/source; it must never fabricate a project, folder, or document authority.
- Direct Sales folder navigation must obtain the exact source-bound location through the caller-authorized discovery contract; a client-side Drive join is not proof of an active, locked, non-trashed location.
- Private DOCX materialization must resolve the current active assigned employee, department membership, and exact source-bound location before request, storage receipt, commit, history, or readback; this prevents Sales or department membership from becoming document authority.
- Keep OOXML byte verification as a pure bounded server-safe verifier that validates the package relationship graph, declared ZIP resource limits, and active-content policy until a separately accepted server-side object-read and receipt authority binds verified object identity to the protected materialization contract; this prevents browser-supplied storage facts from becoming trusted.
- Keep private DOCX verification behind a server-only dependency-injected bridge: authenticated actor identity, current assignment/source/template authority, immutable object version, bytes, and receipt recheck must all agree; fail closed while a version-addressable private-object reader or protected receipt issuer is unavailable.
- A current-path DOCX byte reader is permissible only behind accepted create-only request-path enforcement and before/after exact-version rechecks; restrictive Storage policies must guard the DOCX prefix so broader permissive Drive policies cannot permit replacement.
- Keep DOCX object staging, trusted post-upload verification, and post-receipt current-path reads as separate authority states; Drive nodes, revisions, and registers tagged by DOCX materialization must reuse the same assigned-person resolver so ordinary document visibility cannot bypass private-object access.
- Keep structured DOCX responsibility/template authority in one future registry: immutable department template revisions and explicit active person assignments must resolve every project/category action; registry management must derive caller authority from active project membership plus scoped department document-management capability, while ordinary signed-in visibility never implies private document access.
- Sample cleanup remains review-only until a supported root-level archive/restore workflow can retain dependencies and replay audit evidence; Drive trash alone is not such a workflow.
- Sales sample archival and trusted DOCX receipts require exact-root server contracts with locked sources and append-only replay/audit; DOCX receipts bind actor, assignment/source/template, object version, verified bytes, and atomic consume before Drive/register/audit materialization.
- Keep Procurement-review reads and mutations behind caller-authenticated typed RPC adapters gated by the pending deployment switch, so an uninstalled contract never becomes an inferred client-side queue or decision authority.
- Keep project DOCX reassignment source-only and require every named responsible or reviewer to remain active in the assigned department and exact project team; this prevents unscoped authority.
- Serialize project DOCX updates by actor/request key before the assignment root, then recheck manager authority and lock mutable target prerequisites; this preserves replay without stale authority or membership races.
- Keep Sales feasibility handover behind one pending atomic source-bound requirement-and-routing contract; separate client calls must not create partial requirements, assignments, or notifications.
- Keep Sales feasibility routing receipts private, replay-bound to the Sales actor and immutable enquiry/opportunity/Master source tuple; reviewer notifications must be generated inside the protected transaction, never by the client.

## Single planning entry point

Read docs/planning/SSM_ONE_WEB_PORTAL_MASTER_PLAN.md for the current web/backend requirements and delivery order; update it in place rather than adding competing dated portal roadmaps. Use docs/planning/SSM_ONE_DOCUMENT_CATALOGUE.md as an optimized reference, not an implementation prerequisite. Preserve technical contracts, pending SQL and historical evidence; source-only work is not a live API. Android builds have their own plan in the Android repository. SSMOneWeb itself is the full Git repository root; application code and docs/ are tracked together. No separate docs mirror or nested source checkout is used. Historical backups live outside this repository in sibling SSMOneWebBackups. Dated backups are immutable.

## Workspace authority

Use original Lovable project d758dbf2-2f0e-44b3-b149-1ec51def58eb and backend yyrvduosyyaluifqvwkr. Preserve existing auth, departments, RLS, official numbering, manual edits and historical revisions. Do not create a competing backend. No destructive database operations, new production test users, privileged credential/access changes or Publish without required specific authorization. Historical backup captures are immutable; code/Git capture is not a database or private Storage backup.

## Workspace names — 18 October 2026

Web product: **SSMone**. Android application/display name: **SSMone-App**. Preferred workspace entry paths:
- Web: `C:/Users/Admin/AndroidStudioProjects/SSMone/SSMone-Web`
- Android: `C:/Users/Admin/AndroidStudioProjects/SSMone/SSMone-App`

Both SSMone-Web and SSMone-App are actual physical directories under C:/Users/Admin/AndroidStudioProjects/SSMone, with separate Git repositories and histories. Neither entry is a junction or duplicate checkout; this parent is not a monorepo. The former SSMOneWeb and SSMApplication3 roots no longer exist. Preserve historical backups, application/package identity, backend/project IDs and official document names. Use these physical workspace paths for new Studio/Antigravity sessions and schedulers.

### Physical-root web verification

Run web validation from C:/Users/Admin/AndroidStudioProjects/SSMone/SSMone-Web, now the physical repository root. The former SSMOneWeb path is no longer valid.
