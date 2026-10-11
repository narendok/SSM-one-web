# PROPOSED project official decision-log contract

> **Scope correction — 2026-10-11:** Earlier use of “division note” in this planning artifact meant a **deviation note**: an approved, bounded exception or change that bypasses a specified standard or requirement. It does **not** mean a departmental decision note. This correction preserves the historical proposed project-decision and BOM-candidate material below. Ordinary BOM candidate submissions or Hardware approvals do not create, grant, or imply a deviation. No executable deviation workflow, authority, status, permission, record, RLS policy, or user action is established by this document.

**Status:** review-only specification. Nothing in this document is installed,
callable, seeded, granted, or applied. It must not be used to create a note,
approval, notification, record, or database object.

## Scope and source boundary

- This contract applies only to an authorized **committed project**. Sales
  proposal flows remain unchanged.
- The server must derive the project, actor, source item, and source-page
  reference from the authorized transition context. A browser must not select
  another project, forge an actor, or attach a note to a title/name match.
- A missing, null, mismatched, stale, unauthorized, or uncommitted source must
  fail closed. No project ownership is inferred from opportunity, department,
  task, component, or null-department data.
- Existing task/PCB comments and `activity_log` are contextual history only.
  They are not substitutes for, sources of truth for, or automatic inputs to
  the PROPOSED official decision log.

## PROPOSED records and immutable history

The executable design may introduce the following **PROPOSED** records only
after separate review. Names below are descriptive, not installed schema or
callable APIs.

| PROPOSED record | Purpose | Immutable boundary |
| --- | --- | --- |
| `project_official_decisions` | One official project decision/action entry with its server-derived project, actor, source item/page reference, action kind, short human-authored note, and source revision. | An entry is never edited or deleted through the workflow. |
| `project_official_decision_amendments` | A later correction or clarification that names its exact prior entry and carries a new short human-authored note. | Earlier entry text, actor, source, and timestamp remain visible and unchanged; amendment links form a one-way chain. |
| `project_official_decision_evidence` | Contextual supporting note/evidence reference contributed by another authorized actor, including contributor provenance and bounded scope. | Evidence is additive and source-bound; it cannot rewrite the decision or impersonate its actor. |
| `project_official_decision_receipts` | Private request-key receipt binding the actor, normalized intent, target source revision, and returned immutable identifiers. | Exact same actor/payload may replay its original result only; changed actor or payload is denied. |

The authoritative decision note is short, human-authored, and mandatory where
the future action requires an official decision. Supporting notes/evidence are
contextual and optional unless the future action specifically requires an
exception reason or contributing-party record. No generated copy, approval, or
note may satisfy this requirement.

## Deviation-note scope correction and verified boundary

A deviation note is a distinct controlled exception/change record. Its minimum future content must identify the source standard and its revision, the bounded exception reason, risk, safeguards, and evidence, the affected project and — where applicable — part, revision, and quantity or a validity period, the required existing authority, and a closure or expiry outcome. An ordinary candidate approval never supplies this exception authority.

**Verified implementation evidence (2026-10-11 source trace):** `public.project_change_requests` is the only directly relevant operational record found. Its schema is `id`, `project_id`, `change_code`, `title`, optional `description`, `change_type` (default `ECR`), `status` (default `DRAFT`), optional `impact_summary`, requester/approver employee references, `approved_at`, `implemented_at`, and timestamps (`drizzle/migrations/0011_phase5_project_delivery_registers.sql:63-79`; generated client shape `src/integrations/supabase/types.ts:7462-7533`). `project_process_stage_records.change_request_id` can link an existing change request to a process-stage record, but it does not create a deviation state or approval predicate (`supabase/migrations/20261001160232_1e457307-b0c3-4f4b-bb8e-c4ef42492082.sql:19-35`).

The current Project → Delivery → Engineering changes UI reads rows directly, offers generic `ECR`, `ECN`, `DEVIATION`, and `WAIVER` type choices, and directly inserts or deletes `project_change_requests` rows; it does not call a protected server action or implement an approval transition (`src/components/projects/ProjectOperationalTabs.tsx:39,46-60,76-93`). The original access policy grants authenticated `SELECT, INSERT, UPDATE, DELETE`; read access accepts administrator, `projects.view`, or project-team membership, while *all* mutations accept administrator or `projects.manage` without exact project-team, active-employee, revision, type, status, requester/approver separation, or reauthorization-after-lock checks (`drizzle/migrations/0011_phase5_project_delivery_registers.sql:80-93`). There is no status check constraint, change-type constraint, protected change-request function/RPC, deviation/concession/waiver function/table/view, or request receipt found in reviewed source.

**Configured authority evidence and limit:** `projects.manage` is the generic Project Manager access-catalog permission (`drizzle/migrations/0012_phase5_project_access_catalog.sql:14-36`). The current role mapping gives engineering roles `engineering.view/create/edit`, not `engineering.approve`; QMS Manager has the separate generic `qms.approve` (`supabase/migrations/20260929030650_b96e7101-e314-4468-abe9-d23050b1636d.sql:130-147`). QMS save paths use `qms.edit` for listed QMS tables (`src/lib/phase9.functions.ts:4-23`); they do not include `project_change_requests` or supply a deviation approval adapter. These generic grants are not an accepted deviation authority matrix.

**Missing for a bounded deviation implementation:** source standard and immutable revision; a distinct exception reason, risk, safeguards, and evidence model; exact affected project plus optional part/revision/quantity or validity period; a defined expiry/closure model; an explicit authority choice and separation-of-duties predicate; immutable approved history; requester-bound idempotency receipt; lock/recheck/rollback transition; caller-RLS read projection; and an authenticated acceptance matrix. Ordinary candidate approval never supplies any of these.

**Safe current boundary:** Project → Delivery → Engineering changes remains the only relevant existing project link. It may display existing generic change-request rows subject to existing caller access, but it must not be relabeled as a deviation-note register or gain a create/approve action for deviations. Until an authority choice and an authoritative deviation workflow with caller-read contract are verified, any future deviation-specific page must remain disabled/not configured rather than infer authority or reuse candidate approval.

## PROPOSED future action linkage

Each listed transition remains unavailable until its own protected contract is
reviewed and accepted. When enabled in a future single transaction, it must
write its official-decision entry with the same source lock/revision boundary;
it must not create a standalone note before or after an unsuccessful action.

| Future committed-project transition | Required PROPOSED official entry |
| --- | --- |
| BOM candidate submission | Submitter note bound to the committed project, authoritative BOM item, candidate revision, and server-derived submitter. |
| Purchase cost amendment before final Hardware decision | Purchase note bound to the candidate revision, cost-amendment revision, and server-derived commercial provenance. A later cost amendment leaves prior notes/history intact and invalidates only the future decision eligibility defined by that workflow. |
| Hardware approval, rejection, or explicit alternative | Hardware decision note bound to the exact candidate revision and any explicit existing-component/candidate alternative. A reviewer may not decide their own submission. |
| Rare explicit Sales exception | Separately authorized exception note stating the short exception reason and immutable server-derived commercial source/version. It is never inferred from a ceiling result or auto-created. |

Inventory promotion is not an approval note substitute. Any later promotion
contract must preserve the preceding official-decision chain and may add its
own official action entry only under separately reviewed authority.

## Concrete authority-mapping review

This is a source-only mapping artifact, not an acceptance of any action. The
terms **verified** and **proposed** are deliberately distinct:

- **Verified** identifies an existing source object or field found in this
  repository. It does not establish that the object is deployed, caller-readable,
  immutable, or sufficient for an official decision.
- **Proposed** states the minimum binding a later protected transition must make
  in one reviewed transaction. It is not an installed RPC, policy, grant, event,
  receipt, schema, or permission.
- **Absent** means this review found no exact source object or accepted contract
  for the stated role; it must not be reconstructed from display text, generic
  activity, a null department, or an unrelated historical row.

### Verified source inventory and limits

| Source | Verified identifiers/fields | What it proves | What it does **not** prove |
| --- | --- | --- | --- |
| Project | `projects.id`, `status`, `project_manager_employee_id`, `department_id`, `revision`, `opportunity_id`, `annual_volume` (generated client type: `src/integrations/supabase/types.ts:8455-8514`) | A project row has stable IDs and contextual manager, department, commercial-link, and revision fields. | There is no verified `committed_at`/committed-state contract, immutable decision revision, or manager-to-action authorization rule. `status = 'active'` appears only in the unreachable pending sketch and is not accepted here as the meaning of committed. |
| BOM header | `project_boms.id`, `project_id`, `revision`, `source_drive_node_id`, `source_drive_revision_id`, `updated_at` (generated type: `src/integrations/supabase/types.ts:7345-`) | A BOM can be tied to one project and optionally to an exact Drive node/revision. | The current save path can update a header and replace all its item rows (`src/lib/project-bom.functions.ts:99-166`); header `revision` is not a verified immutable candidate revision. |
| BOM item | `project_bom_items.id`, `bom_id`, `matched_component_id`, `match_status`, `created_at`, line and commercial fields (generated type: `src/integrations/supabase/types.ts:7314-7403`) | A stable item ID joins through its BOM to a project. | There is no candidate-submission state, candidate revision, handoff ID, reviewer ID, official-action event, or immutable per-item revision. A component match is not a candidate approval. |
| Project membership | `project_team_members.project_id`, `employee_id`, `discipline`, `project_role`, `is_lead`; employee `user_id` and `employment_status = 'ACTIVE'` are used by the pending sketch (`supabase/pending/20261010_project_official_decision_log_contract.sql:287-325`) | Existing employee-backed membership can be checked against the exact project when a contract joins it correctly. | The table has no validity interval, action entitlement, self-review flag, or binding to a BOM item/candidate revision. An active employee elsewhere is not project membership. |
| Permission helpers | `public.has_permission(uuid, text)` and `public.has_any_permission(uuid, text[])` are generated helpers (`src/integrations/supabase/types.ts:12479-12485`); existing role seed source includes `projects.view`/`projects.edit` and `engineering.edit` (`supabase/migrations/20260929030650_b96e7101-e314-4468-abe9-d23050b1636d.sql:130-148`) | Permission evaluation exists independently of browser state. | This review found no existing `engineering.approve` permission key, no Hardware-specific approval predicate, and no permission-to-project-BOM-action mapping. The user-required `engineering.approve` is therefore a **proposed prerequisite**, not a verified current capability. |
| Department membership | `employee_departments` and active employee checks occur in other pending contracts (for example `supabase/pending/20261005_client_requirement_intake.sql:487-489`) | Department membership and active employment are existing concepts. | No existing candidate workflow binds a Hardware reviewer to the canonical Hardware department and an exact source action. Department naming/type alone cannot establish authority. |
| Existing history | `activity_log` exists, but current lifecycle observation explicitly records no scoped authenticated read contract (`src/lib/lifecycle-deployment-observation.ts:117`) | Contextual audit rows may exist for unrelated workflows. | It is not an official-decision event, receipt, candidate-state record, or caller-RLS evidence feed for this contract. |

### Action-to-authority matrix

The matrix turns the agreed business rules into exact future bindings while
keeping every unsupported link fail-closed. “Reader scope” describes a future
security-invoker projection only; the existing projection remains `WHERE false`
and is not enabled by this document.

| Action | Immutable source identity and revision | Actor and division authority | Reader scope | Contributor/support evidence | Event / receipt | Unresolved executable gates |
| --- | --- | --- | --- | --- | --- | --- |
| **BOM candidate submission** | **Verified identity:** `project_bom_items.id` → `project_boms.id` → `projects.id`. **Absent revision:** no immutable candidate revision exists. **Proposed binding:** a new candidate record/revision must be server-created from the locked item and committed-project source; the official note pins that returned candidate revision, not mutable BOM-header text. | **Proposed:** resolve `projects.project_manager_employee_id` to the authenticated active employee; require a matching active `project_team_members` row for that same `projects.id`. Neither field alone suffices. | **Proposed:** caller may see the resulting entry only through the exact committed project access predicate accepted for this action; no broad project list or guessed item lookup. | **Proposed:** evidence may reference only a source owned by the same committed project and an active contributor whose permitted scope is resolved server-side. It cannot replace the manager’s note. | **Absent:** no candidate submission RPC/event/receipt exists. **Proposed:** one locked transition writes candidate revision, short official note, evidence rows if authorized, audit event, and actor-bound receipt atomically. | Committed-project definition; candidate schema/state/revision; manager employee-to-user resolution; active membership semantics; exact source page locator; source-action permission; contributor evidence source/scope; receipt/audit contract; caller-RLS read projection. |
| **Hardware review: approve, reject, or explicit alternative** | **Proposed:** consume the immutable candidate revision emitted by the preceding submission, plus the locked project/BOM/item tuple. An alternative must be an explicit server-resolved candidate/component reference under the same project; `matched_component_id` is not sufficient evidence of approval. | **User-agreed proposed rule:** require `engineering.approve` **and** active Hardware department membership **and** active membership on the same project. Reject if the reviewer is the candidate submitter. The exact `engineering.approve` key and Hardware predicate are currently absent/unverified. | **Proposed:** same-project callers see the Hardware decision and only evidence whose parent and evidence scope independently pass the accepted predicate. Purchase readers receive only the approved-handoff projection below. | **Proposed:** Hardware contributors must resolve to active Hardware membership and a source-owned same-project evidence item; their identity is stored separately from the reviewer and cannot be supplied in request text. | **Absent:** no Hardware approval RPC, immutable decision event, or receipt exists. **Proposed:** lock candidate revision before receipt lookup, re-check membership/permission after locks, write decision/note/evidence/receipt/audit together. | Candidate approval state and lock; `engineering.approve` definition/grant; canonical Hardware department identity; no-self-review predicate; explicit-alternative ownership/revision rule; Hardware evidence model; action audit; approval-to-handoff transition. |
| **Purchase post-Hardware handoff (read-only)** | **Proposed:** consume only the exact approved Hardware decision ID and its candidate revision; a candidate/BOM ID without that approved decision is insufficient. Cost material remains a separate commercial source/version and must never be promoted to a decision by the note. | **User-agreed proposed rule:** Purchase has no approval authority here. Its only future access is read-only after server verification of the approved Hardware handoff and same committed project. | **Proposed:** a narrow handoff view may disclose the approved decision and allowed non-commercial identifiers to authorized Purchase members; it must not make Purchase a general decision-log reader or expose hidden evidence/commercial values. | **Proposed:** Purchase may attach no official decision note or evidence unless a separately accepted cost-amendment action defines exact commercial provenance and scope. | **Absent:** no approved-handoff object, Purchase projection, receipt, or cost-amendment transition exists. | Hardware-approved status model; handoff identifier; Purchase department/membership predicate; field-level redaction; commercial source/version; whether a later cost amendment is an independent protected action. |
| **Sales projected-volume/cost baseline context** | **Verified contextual fields:** `projects.opportunity_id` and `projects.annual_volume`. **Proposed:** if a future action needs commercial context, it pins an exact server-resolved baseline/version rather than a current project field. | No default Sales part approval. Existing `sales.*` permissions and project visibility do not authorize a BOM candidate or Hardware decision. | **Proposed:** baseline context is visible only where a reader is already entitled to the parent decision and the separately accepted commercial projection; no cross-project Sales lookup. | Sales material is contextual evidence only under a separately accepted source/version/scope rule; it cannot act as the official Hardware or project-manager note. | **Absent:** no verified baseline-to-decision event or receipt binding. | Exact immutable Sales baseline/version; caller-RLS commercial projection; redaction; commercial-to-project provenance; no-default-approval enforcement. |
| **Rare explicit Sales exception** | **Proposed:** bind an exact immutable commercial source/version and the target committed-project decision/candidate revision. No exception may be inferred from projected volume, cost, ceiling, or a missing Hardware decision. | **Unresolved by agreement:** this is a separate exceptional action. No existing Sales permission, department membership, project membership, or exception approver predicate is accepted as authority here. | **Proposed:** visible only to callers entitled to both the parent project decision and the separately approved exception scope; all other callers receive no row. | **Proposed:** require a short exception reason and only separately scoped evidence. It cannot alter the ordinary Hardware decision or impersonate its actor. | **Absent:** no exception RPC, immutable event, receipt, or lifecycle state exists. | Exception owner/approver and separation-of-duties rule; commercial source/version; project linkage; expiry/revocation; reader redaction; replay/rollback/concurrency acceptance. |
| **Central project Decision log (read-only)** | **Proposed:** read immutable official-decision IDs only after each parent action has resolved its own source revision. Historical actions retain their original source/revision even if a later BOM/header changes. | No action authority is inferred from reading. **Proposed:** a reader must satisfy the accepted committed-project read predicate for the exact project; generic membership or `projects.view` alone remains insufficient until proven. | One project-options **Decision log** option, project-scoped only: immutable historical order, linked amendments, and evidence only where both parent and evidence scope pass. No receipts/internal audit payloads, cross-project search, or general activity feed. | A hidden parent, hidden evidence scope, or hidden contributor causes the evidence to be absent; it may not reveal that an inaccessible record exists. | **Verified current state:** `public.project_official_decision_log` is explicitly `WHERE false` and receives no authenticated grant in the pending source (`supabase/pending/20261010_project_official_decision_log_contract.sql:75-99`). | Exact caller-RLS project predicate; action-specific parent/evidence scope evaluation; grant/RLS review; projection query; pagination/history ordering; managed non-admin acceptance. |

### Required rejection cases for the future executable contract

The following cases are mandatory negatives, not optional UI behavior. They
must be demonstrated through authenticated transport and caller-RLS reads only
after a separately approved implementation exists.

| Rejected case | Required result |
| --- | --- |
| Cross-project item, candidate, decision, evidence, or handoff ID | Deny or return no row without leaking project, actor, commercial, evidence, or history existence. Never infer ownership from name, opportunity, component, or a null department. |
| Cross-department review or contribution | Deny Hardware review/evidence unless the caller’s active Hardware membership and exact project membership both resolve at authorization time. Purchase is denied any review or approval path. |
| Self-review | Deny Hardware approval/rejection/alternative when reviewer resolves to the candidate submitter, including an alias employee/user mapping; no receipt/result is returned and no row is written. |
| Missing or stale source revision | Conflict before receipt replay or write; no official note, evidence, event, receipt, or source transition is appended. A mutable BOM header/item snapshot cannot be substituted for the missing candidate revision. |
| Sales baseline used as part approval | Deny. Project volume/cost context and ordinary Sales permissions never create candidate, Hardware, or default Sales approval authority. |
| Hidden parent decision or hidden evidence | Return no evidence and no parent-derived metadata to an unauthorized reader; direct evidence IDs cannot bypass parent scope. |
| History mutation or forged actor/contributor/source locator | Deny direct update/delete and deny payload-supplied identities/locators that differ from server resolution. Corrections are linked amendments only, with prior notes and provenance unchanged. |
| Receipt replay after revocation or with changed actor/payload | Re-authorize after target locks and before replay. Deny changed/revoked requests without returning a stored result or writing a second history graph. |

### Remaining executable blockers

1. Define the canonical committed-project state and its server-side predicate;
   current source does not prove that `projects.status = 'active'` means
   committed.
2. Introduce a protected candidate workflow with an immutable candidate
   identity/revision, submitter identity, state model, and exact source-page
   locator. The current BOM save path replaces item rows and cannot supply it.
3. Define and accept `engineering.approve`, the canonical Hardware department
   predicate, exact active project membership semantics, and the no-self-review
   check.
4. Define the Hardware-approved handoff and its narrow Purchase read model;
   no Purchase approval is in scope.
5. Define source-owned contributor evidence, scopes, retention/redaction, and
   provenance resolution. Existing task/PCB notes and `activity_log` cannot be
   substituted.
6. Define the rare Sales-exception authority, immutable commercial baseline,
   expiry/revocation, and reader scope independently of normal Sales context.
7. Only after the above, replace the pending deny-all projection/append gate in
   one reviewed transaction and prove authorization-before-receipt, locks,
   replay, rollback, self-review, cross-project/cross-department, hidden-parent
   evidence, and non-admin caller-RLS behavior in isolated acceptance.

## Authorization, replay, and transaction requirements

- Future protected transitions must authorize the caller against the exact
  committed project and exact source item before looking up a request receipt.
- The receipt hash must cover normalized action intent, committed project ID,
  exact source item/page reference, expected revision, short note, amendment
  parent where applicable, evidence references, and explicit alternative or
  exception reference. It must not treat display labels as identifiers.
- A duplicate request key returns the saved result only when the same actor and
  canonical payload match exactly. Reuse by another actor or with changed
  payload is denied. A stale expected revision conflicts; it must not append to
  a newer source version.
- A stable future lock order must include the authoritative project/source,
  source revision, decision/amendment parent when present, and receipt. The
  final order must be reviewed with the executable data model.
- Authorization, source validation, immutable decision/amendment/evidence
  insert, receipt insert, source transition, and any audit insert must succeed
  or roll back together. A failed note/evidence/receipt/audit write must not
  advance the source action; a failed action must not leave an official entry.
- Historical decisions, notes, evidence provenance, and amendments stay
  immutable. Corrections are new linked amendments, never updates, deletions,
  or replacement text.

## PROPOSED caller-read scope

Future caller-visible reads must be narrow, caller-RLS-scoped projections over
the caller's authorized committed project. The executable contract must deny
all direct writes and must not expose private receipt hashes or internal audit
payloads.

- A caller may read only entries for a project they can already access through
  the established project authorization boundary.
- Cross-project, guessed-ID, outsider, and null/uncommitted-project reads are
  denied or return no row without leaking existence, actor details, commercial
  values, or evidence content.
- Supporting evidence is visible only where both its decision and its stated
  scope are visible to that caller. Contributor provenance remains attached to
  the evidence and cannot be supplied by a different caller.

## One Project options design

The future Project interface may add one **Decision log** option for an
authorized committed project. It is a project-scoped history view, not a
general activity feed and not a cross-project search.

- It shows official decision entries in immutable historical order, linked
  amendments, contextual evidence within caller scope, source-page/item
  references, and contributor provenance.
- It does not auto-generate notes, expose receipts/internal audit data, create
  approvals, or alter candidate, commercial, Hardware, or Sales state.
- Any future action control belongs only on the established source page and
  requires that action's separately reviewed protected contract.

## Non-goals and unresolved dependencies

- No permission key, role, membership, RLS policy, table, function, migration,
  queue, notification, storage object, or UI is proposed for application here.
- Exact action authority, source-page identifiers, evidence retention rules,
  redaction rules, and the final read projection require executable-contract
  review against the existing project, BOM-candidate, commercial, and
  department boundaries.
- This document does not approve the candidate workflow, commercial ceiling
  calculation, Hardware review, Sales exception, promotion, or any live
  mutation.