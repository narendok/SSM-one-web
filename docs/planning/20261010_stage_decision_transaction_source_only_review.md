# Source-only stage-decision transaction review

**Status:** design review only; not a migration, deployed-contract assertion, callable action, grant, UI activation, or instruction to mutate data. This review distinguishes repository evidence from managed deployment: no managed target was queried for this work.

## Evidence boundary

| Evidence class | What is verified in this repository | What is not verified here |
| --- | --- | --- |
| Migration/source | Existing table/function/policy names and source definitions cited below. | That any migration is present, current, or executable in a managed target. |
| Generated client types | The listed tables/fields exist in the generated client contract. | Current target data, grants, policies, function signatures, or caller access. |
| Runtime/UI | The lifecycle draft plan is expressly read-only and non-generating. | Any authoritative stage decision, Review Handoff, recipient intent, or outbox action. |

## Verified existing objects and boundaries

| Object | Proven repository evidence | Reusable boundary, not a new authority |
| --- | --- | --- |
| `public.projects`, `public.departments`, `public.company_process_stages` | Stage records reference a project and company stage; company stages carry nullable owning/reviewer departments (`supabase/migrations/20261001160232_1e457307-b0c3-4f4b-bb8e-c4ef42492082.sql:1-35`). | A decision must lock and validate the exact project/stage; null department values must fail closed, never infer ownership. |
| `public.project_process_stage_records` | Exact fields include stage, status, owner/reviewer employees, evidence Drive node, change request, handover note, immutable creator and timestamps (`…20261001160232…sql:19-49`; generated shape `src/integrations/supabase/types.ts:7866-7998`). | Existing broad manage policy is not a decision-transition authority or a RACI contract. |
| `public.project_stage_dependencies` | Same-project dependency guard locks and validates graph writes (`supabase/migrations/20261002220916_5d158822-de77-479d-a8af-54037acc96ad.sql:39-50,211-294`). | It does not define stage decision, evidence sufficiency, recipients, or notification delivery. |
| Project team / permission helpers | Existing permission helper resolves admin or employee access-role permissions (`supabase/migrations/20260923173813_447b78e0-6a60-4d69-875a-6b5c7d32691f.sql:3-21`). Lifecycle manager check combines department-drive access with project/engineering/document permissions (`…20261002220916…sql:100-123`). | No inspected callable maps a RACI role or exact stage action to an actor. `project_team_members` is a known table, but its authority semantics were not established by an executable stage-decision contract. |
| Baseline / amendment-linked fields | `project_feedback_revisions` references `requirement_baselines`; a stage can reference `project_change_requests`; generated stage types expose both links (`…20261002220916…sql:52-69`; `src/integrations/supabase/types.ts:7866-7998`). | No inspected source defines an approved baseline predicate, amendment applicability rule, or authoritative evidence set for a stage decision. |
| Evidence links | A stage has only nullable `evidence_drive_node_id`; Drive/revision linkage is enforced for controlled documents, not stage decisions (`…20261001160232…sql:28-30,107-124`). | A Drive-node reference alone does not prove readable, current, approved, sufficient, or correctly scoped evidence. |
| `public.notifications` and `public.enqueue_notification` | Notifications have recipient/read/event fields (`src/integrations/supabase/types.ts:6038-6081`). The enqueue helper validates recipient/relative target, deduplicates `(user_id,event_key)`, and is service-role-only (`supabase/migrations/20260929020257_1473243e-4f08-4583-a786-dbd7c6cfe6cf.sql:1-41`). Inbox read/mark-read functions are recipient-scoped (`supabase/migrations/20260927181412_e3bfd0c1-6f5e-428b-a813-7d1087d26a11.sql:113-148`). | The helper is an insertion primitive, not a durable stage-decision outbox or recipient-resolution contract. No deployment claim is made. |
| Lifecycle draft plan | It labels all stage/handoff/feedback actions `DRAFT`, returns `canGenerate: false`, and says governed notifications are absent (`src/lib/lifecycle-draft-plan.ts:34-38,74-115`). | It must not be used as authoritative stage state, a status transition, recipient source, or evidence proof. |
| Existing lifecycle generation | The repository contains request-key receipts, locks, and gated generation source; authenticated execution is revoked (`…20261002220916…sql:71-83,465-535`; `supabase/migrations/20261002220956_e9863fb2-326a-48c2-92e7-3ecf984fadef.sql:1-6`; gate `src/lib/lifecycle-actions.functions.ts:178-186`). | It is a separate materialization contract, not a reusable stage-decision procedure. |

## Missing dependencies — executable implementation blocked

The following absent or unverified authority blocks an executable decision contract. No callable name, status vocabulary, recipient rule, or persistence schema is inferred by this review.

1. **Exact RACI action authority:** no verified mapping from an actor to a permitted decision on a particular project-stage record, including self-review/exclusion rules.
2. **Authoritative decision semantics:** no accepted stage-decision state machine or approved decision/status set was found. Existing stage status values cannot be repurposed by assumption.
3. **Baseline/amendment applicability:** no verified predicate binds an approved requirement baseline and any applicable amendment/change record to the exact stage and expected revision.
4. **Evidence authority:** no verified rule establishes the required evidence collection, revision freshness, ownership, or access scope; a nullable Drive node link is insufficient.
5. **Recipient intent and deep-link authority:** no verified recipient resolver or authorized Review Handoff/View Stage route contract exists for a decision.
6. **Durable outbox and append-only decision audit:** neither a transactional outbox nor an immutable decision/audit schema was found in deployed-source migrations. The earlier official-decision document is explicitly proposal-only (`docs/planning/20261010_project_official_decision_log_contract.md:1-5,111-121`).
7. **Managed acceptance:** deployment/catalog identity, grants, RLS behavior, rollback, replay/concurrency, and non-admin acceptance remain unverified. Repository migrations alone do not prove managed deployment.

## Proposed protected transaction shape (non-executable)

This section records inputs and invariants for later separate review; it introduces no callable names or statuses.

### Server-derived inputs

- `request_key` (UUID) and a canonical decision intent containing only immutable identifiers and bounded human-authored rationale.
- Exact `project_id`, `project_stage_record_id`, expected stage revision/version boundary, and requested decision kind.
- Exact baseline identifier and expected baseline revision/version boundary, when required by the accepted future action.
- Exact amendment/change identifier and expected revision boundary, only when the accepted future action permits it.
- Exact evidence identifiers and revision boundaries, only after an accepted evidence authority defines them.

The server derives the actor from authentication, project/department scope from the locked project and stage, and all recipient identities from an accepted recipient authority. Display labels, nullable department values, client-supplied actor IDs, inferred ownership, and draft-plan output are not inputs.

### Required checks before replay

1. Authenticate; lock the project and stage; derive actor and non-null owning/reviewer department context from authoritative locked rows.
2. Authorize the actor for the exact project-stage decision before reading a receipt; re-check after all relevant locks.
3. Confirm stage/project association, authoritative decision state, expected revision boundary, and any required dependency/gate condition under lock.
4. Confirm baseline, amendment/change, and evidence applicability against their future accepted authorities; fail closed on missing, stale, unrelated, unreadable, or ambiguous records.
5. Validate recipients only through the accepted resolver; reject a self-recipient or invalid/inactive identity when the future RACI rule requires exclusion.

### Canonical replay and lock discipline

- Hash a canonical payload containing the derived actor, project/stage IDs, expected boundaries, decision kind, normalized rationale, baseline/amendment/evidence identifiers and revision boundaries, and resolved recipient intent identities.
- Look up a receipt only after authorization. The same request key may replay only for the same derived actor and byte-equivalent canonical payload; a changed actor or payload conflicts and performs no writes.
- Establish one reviewed lock order: project → stage → baseline/amendment/evidence records → recipient authority rows → receipt. Add only the necessary stable graph/dependency locks after the authoritative state machine is accepted.

### Atomic outputs

On a fully accepted action, one transaction must atomically:

1. append the immutable decision/audit event with derived actor and source boundaries;
2. append any evidence/baseline/amendment provenance references required by the accepted action without altering historical records;
3. change only the authorized stage state under its accepted transition rule;
4. create recipient outbox intents with a unique deterministic deduplication key per decision/recipient/intent;
5. enqueue recipient inbox entries using the existing service-role-only primitive only from within the protected server-side unit, preserving its `(user_id,event_key)` deduplication; and
6. store an actor-bound request receipt containing only the approved result identifiers.

Any failure rolls back the stage transition, append-only audit, recipient intents, notification inserts, and receipt together. Delivery must not be asserted merely because an inbox row exists; a durable outbox requires its own delivery state and retry authority, neither of which exists today.

## Required later acceptance

A separately approved executable proposal must prove, on an isolated authorized target, denied caller/no-write behavior; exact authorization; baseline/amendment/evidence mismatch rejection; duplicate/replay and changed-payload conflicts; concurrent decision locks; atomic rollback across audit, stage, receipt, recipient intent, and notification; recipient unread/read visibility; and non-admin RLS behavior. It must also prove target identity before any deployment claim.

## Non-goals

No SQL installation, grant, RLS/auth change, UI activation, Save/Publish wiring, document generation, background worker, delegation, fixture, or managed-backend call is part of this review.
