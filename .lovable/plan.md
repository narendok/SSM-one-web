# Sales feasibility and project-start delivery

## Scope
- Correct and locally verify the pending feasibility handover contract before any live installation.
- Install the reviewed handover database change only after its replay, authority, source and immutable review-graph safeguards pass.
- Enable the Sales handover action only after the installed operation is verified.
- Then design and implement the separate customer-confirmed, review-gated baseline-to-project start contract; no project may be created before its prerequisites pass.

## Delivery sequence
1. Repair the handover receipt replay path so it rechecks current caller authority, source links, active department/reviewer scope, and the exact originally created review graph.
2. Extend disposable acceptance for revoked reviewer/membership/department, relinked sources, altered review rows, conflict/replay, rollback, and concurrency.
3. Apply the corrected additive database migration and verify the installed function and access controls.
4. Wire the existing selected department/reviewer form to the installed protected action and confirm persisted readback.
5. Inspect and implement a distinct baseline-to-project-start contract that requires current source pins, required feasible reviews, cleared conditions, recorded customer confirmation, replay protection, audit, and atomic project creation.

## Technical details
- Handover remains one server-owned transaction; browser code must not chain requirement, review, or notification writes.
- Baseline approval and project start remain separate protected actions; feasibility completion alone never creates a project.
- No document access or DOCX scope is changed.
