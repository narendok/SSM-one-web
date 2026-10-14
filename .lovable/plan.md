# Sales feasibility handover source repair

## Scope
- Repair and locally verify the pending feasibility handover replay safeguards only.
- Do not install database changes, alter live grants or policies, enable the Sales action, or begin the baseline-to-project deployment path.
- Provide a separate suggestions-only review of the shared feasibility interface.

## Delivery sequence
1. Recheck current caller authority, source links, active department/reviewer scope, and the exact immutable original review graph before replay returns.
2. Add disposable acceptance for revoked reviewer/membership/department, relinked sources, altered review graph, conflict/replay, rollback, and concurrency.
3. Run the local verification suite and report exact source and results for review.

## Technical details
- The pending handover remains a source-only, single protected transaction.
- Baseline approval, customer confirmation, project creation and document access remain unchanged.
