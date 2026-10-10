# PROPOSED project official decision-log contract

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