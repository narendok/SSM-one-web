# PROPOSED project official decision-log — isolated acceptance matrix

**Status:** pending review only. This is a future acceptance specification, not
an executable test. It creates no identity, role, permission, project, note,
evidence item, or live record and must not target a shared or live backend.

## Preconditions

- An isolated environment contains a committed project, an authoritative BOM
  source item, a pinned candidate revision, and a verified commercial source
  fixture where a tested transition needs them.
- Pre-existing identities represent an authorized project actor, Purchase
  actor, Hardware reviewer, separately authorized Sales exception actor,
  contributing actor, same-project reader, cross-project reader, outsider, and
  administrator. This specification does not create or assign them.
- A reviewed executable contract defines exact permissions, project access,
  source item identifiers, caller-RLS projection, and transaction boundary.

## Matrix

| Area | Isolated caller action | Required result |
| --- | --- | --- |
| Committed-project scope | Attempt an official action from an authorized committed-project source | Server derives project, actor, source item/page, and source revision; short human note is retained with the immutable action. |
| Sales proposal exclusion | Attempt the same flow from a Sales proposal or uncommitted project | Denied; no decision, amendment, evidence, receipt, source transition, or partial history exists. |
| Forged context | Supply another project, actor, page, item, title, or null-department reference | Denied; no ownership or project source is inferred and no information is leaked. |
| Short official note | Submit an eligible future official action with a human-authored short note | Entry is attached atomically to the authorized transition; no generated note or approval is substituted. |
| Supporting provenance | Authorized contributor adds bounded contextual evidence/note where the future action permits it | Evidence retains its actual contributor, decision link, and scope; it cannot replace the official decision actor or note. |
| Evidence scope | Reader lacks access to the parent decision or stated evidence scope | Parent/evidence is denied or absent without cross-project or commercial leakage. |
| Immutable amendment | Correct an official decision through its allowed amendment path | A new linked amendment is appended; original decision/note/actor/source/timestamp remain unchanged. |
| Direct history mutation | Try to update/delete an official decision, amendment, or evidence directly | Denied by future grants/RLS; historical content is unchanged. |
| Same request replay | Repeat an accepted request key with identical actor and canonical payload | Returns the original immutable result without duplicate decision, note, evidence, or source transition. |
| Request-key mismatch | Reuse a request key with a different actor, note, source, revision, evidence, alternative, or exception reference | Denied; original receipt/result remains unchanged. |
| Revision conflict | Submit against a stale project/source/candidate or amendment-parent revision | Conflict; no official entry, receipt, source transition, or partial write is added. |
| Atomic rollback | Force each official-entry, evidence, receipt, source-transition, and audit failure point | Entire future transaction rolls back; no orphan note, evidence, receipt, or advanced action remains. |
| BOM candidate submit | Submit a new candidate from the committed project BOM after its own authorization passes | Future candidate submission and required official note share one source/revision/receipt boundary. |
| Purchase costing | Add eligible Purchase cost before final Hardware decision | Future cost amendment/evaluation and official Purchase note are atomic; later amendment preserves prior history and invalidates only future decision eligibility defined by the candidate contract. |
| Hardware decision | Approve, reject, or select an explicit alternative as an eligible Hardware reviewer | Future decision and official Hardware note are atomic, reviewer self-review is denied, and prior history remains immutable. |
| Rare Sales exception | Exercise a separately authorized exception with a short human reason | Future exception and official Sales note pin the server-derived commercial source/version; no automatic exception is created. |
| Same-project read | Authorized same-project reader loads the future Decision log option | Receives only caller-visible official history, linked amendments, and in-scope evidence; no receipt/internal audit payload is exposed. |
| Cross-project read | Authorized caller guesses an entry/project ID from another project | Denied or absent with no existence, contributor, evidence, or commercial disclosure. |
| Unrelated comments | Load task/PCB comments or `activity_log` records | They remain contextual only and neither create nor alter official decision history. |

## Required transport evidence

1. Run future mutation checks through normal authenticated application
   transport, without logging tokens, commercial amounts, or private receipts.
2. Prove authorization occurs before receipt lookup for every action class.
3. Prove project/source/actor derivation server-side and demonstrate denied
   forged, null, cross-project, Sales-proposal, and stale-revision inputs.
4. Prove rollback and concurrency with independently observed caller-RLS reads,
   including denied outsider and cross-project read paths.
5. Keep existing local BOM picker browser acceptance separate and pending; it is
   not evidence for this PROPOSED contract.