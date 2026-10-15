# Sales feasibility handover writer/root-lock inventory — 15 October 2026

Status: source-only inventory and disposable-local verification. No managed database,
policy/grant, record, UI, or deployment change occurred.

## Actual deployed writer surface read-only result

| Surface | Verified deployed state | Replay-graph effect | Root-lock compatibility | Deployment finding |
|---|---|---|---|---|
| Direct `customer_requirements` | `anon` and `authenticated` currently hold write privileges; Sales `ALL` policy permits Sales-manage writes | Header create/update/delete can change a pinned root or create a competing root | No root serialization | **Block** — no live change made |
| Direct `customer_requirement_revisions` | `anon` and `authenticated` currently hold write privileges; Sales `ALL` policy permits Sales-manage writes | Revision insert/update/delete can change exact source pins | No root serialization | **Block** — no live change made |
| Direct `requirement_feasibility_reviews` | `anon` and `authenticated` currently hold write privileges; Sales `ALL` policy permits Sales-manage writes | Review insert/update/delete can create phantoms or alter the replay graph | No root serialization | **Block** — compatibility transition remains separate |
| `assign_stabilization_codes` trigger | Deployed `BEFORE INSERT` numbering trigger on requirements | Number only; it does not alter graph scope | Not a graph writer | Compatible |
| Other deployed trigger | Requirement header touch and review touch only update timestamps | Mutates timestamps after a direct write | Does not serialize graph | Covered by direct-write blocker |
| Deployed RPC/service routes | Read-only routine inventory returned only the numbering trigger; no installed protected assignment/response/handover RPC was found | None verified as live | No installed compatibility claim | UI/action stays disabled |

The live policy/grant surface therefore remains broader than the pending source. The
`anon` grant display is an access-surface finding, not proof that RLS allows a caller.

## Source-only writer matrix

| Pending/source operation | Writes | Current root behavior after this group | Result |
|---|---|---|---|
| `submit_sales_feasibility_handover` | requirement + revision 1 + selected reviews + notification/audit/receipt | Request key; replay locks persisted requirement-root; first write locks source-root then its new requirement-root | Source corrected; not installed |
| `assign_requirement_feasibility_review` | review insert or open-review reassignment | Same requirement-root before requirement/revision/review | Source corrected; not installed |
| `record_requirement_feasibility_response` | terminal review update + audit/receipt | Same requirement-root before requirement/revision/review | Source corrected; not installed |
| `submit_external_customer_requirement` | requirement + revision 1 + audit/receipt | Request key only; no known requirement root before creation | Separate external intake contract; not a safe handover graph writer |
| `create_sales_bound_customer_requirement` | requirement + revision 1 + audit/receipt | Request key and source locks only | Separate source-bound creation contract; no review graph writer |
| `approve_sales_requirement_baseline` | baseline/audit/receipt; reads reviews | Locks requirement and existing reviews but does not introduce the handover root | Separate pending baseline gate; project-start remains blocked |
| Direct table writers / unknown service clients | any of the three tables | None | Cannot be made safe by this source-only correction | **Deployment/UI enablement blocked** |

## Deterministic disposable evidence

The local-only harness uses independent sessions and advisory barriers, not a prior row
lock or sleep-only coordination. It passed:

- same request-key replay before an ordinary graph update (`receipt=1`, writer commits only after replay);
- different-key protected assignment waiting on the same requirement-root;
- guarded new-review insertion waiting on the root, then committing after release;
- prior replay identity, changed source, Master-number/applicability, and plain-update races.

The phantom test proves only a writer that takes the accepted requirement-root. It does
not prove direct inserts are blocked. Before any installation, a target-bound direct-write
compatibility review must either move every real writer into the root protocol or apply the
separately reviewed direct privilege/policy removal with caller/RLS acceptance.

## Original-target compatibility proposal — source-only

Proposed path: `supabase/pending/20261015_requirement_feasibility_original_target_compatibility.sql`.
It is expressly for the original target, does not reuse the isolated-target transition, and
does not install any change. Its exact minimal effect is to revoke direct `INSERT`, `UPDATE`,
and `DELETE` from `PUBLIC`, `anon`, and `authenticated` on the three replay-graph tables,
then drop only these verified broad authenticated policies:

| Table | Proposed direct-write removal | Supported replacement operation |
|---|---|---|
| `customer_requirements` | direct I/U/D and `Sales users manage customer requirements` | `submit_sales_feasibility_handover`; `submit_external_customer_requirement`; `create_sales_bound_customer_requirement` |
| `customer_requirement_revisions` | direct I/U/D and `Sales users manage customer requirement revisions` | the same source-bound creation operations; later revision authority remains separately scoped |
| `requirement_feasibility_reviews` | direct I/U/D and `Sales users manage feasibility reviews` | `submit_sales_feasibility_handover`; `assign_requirement_feasibility_review`; `record_requirement_feasibility_response` |

Read preservation correction: read-only original-target inspection established the existing
authenticated predicates: Sales/Engineering/Admin can read requirement headers and revisions;
the same scope can read feasibility reviews. The three Sales-manage `FOR ALL` policies also
contribute a narrower Sales-manage/Admin SELECT path, so dropping them without replacing the
independent read scope would be unsafe to claim as SELECT-neutral. The corrected proposal
fails closed when any of its six named original-target policies differs from the inspected
command, role, or predicate, removes only the three exact `FOR ALL` policies, and retains the
three existing named `FOR SELECT` policies. It does not expand visibility, change table SELECT
grants, alter `service_role`, legacy scope helpers, historical rows, or baseline readers.

The revised disposable model proves nonempty before/after reads on all three tables for
Sales-manage, Sales-view, Engineering-manage and Engineering-view identities; unauthorized
authenticated and anon identities remain denied. It also proves protected handover,
assignment and reviewer response on their accepted synthetic prerequisite graph, and denies
each direct `INSERT`, `UPDATE`, and `DELETE` operation for authenticated and anon on each of
the three tables. A policy-drift case alters one named predicate and verifies that the proposal
rejects it. This is synthetic policy/grant evidence only; it does not certify target JWT,
managed caller/RLS behavior, or any caller not represented by the disposable graph.

A future restore needs the pre-install `information_schema.role_table_grants` rows and all six
exact policy definitions captured from the target, including command, `USING`, `WITH CHECK`,
and roles. The disposable capture query verifies this record shape only; it does not capture
or restore the target. Recreating grants/policies without a target-bound, reviewed capture is
not an approved rollback.

Disposable synthetic ordinary-caller evidence applies the exact proposed statements after
first modelling the verified broad authenticated/anon grants and named Sales policies. It
uses a nonempty historical review and tests all six read identities before/after, then permits
the three protected operations with accepted synthetic prerequisites and denies all eighteen
direct authenticated/anon × three-table × I/U/D combinations. This is synthetic policy/grant
evidence only; it does not certify the managed target's JWT, deployed policy text, or all
callers.

The handover source also now serializes an exact enquiry/opportunity/customer/Master source
tuple and rejects a different request key once one receipt owns that tuple. The local two-
session barrier case proves one receipt and requirement commit while the competing key is
denied. It does not prove safety for an unreviewed direct writer; that remains a deployment
blocker.
