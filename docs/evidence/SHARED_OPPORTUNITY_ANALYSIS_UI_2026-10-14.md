# Shared opportunity analysis — first UI pass, 14 October 2026

## Implemented scope

The existing opportunity workspace now has an Open shared analysis entry point and a reusable SharedFeasibilityAnalysis component in its Feasibility tab. It shows caller-provided Master revision data and linked department-level reviews, with explicit empty/error and unverified-approval states. It does not infer per-requirement reviews, assignments, approved baselines or client publication from the legacy records.

An opt-in Try example layout provides four fictional discipline cards, conditions, prominent department-remarks footers, editable client-visible highlights, read-only reviewed requirements plus separate edited example input, internal/client preview switching and a local discussion. All example changes stay in component memory and reset on exit. Internal notes, unpublished live source fields/findings, private discussion and unsent internal message drafts are excluded from the client projection. Client preview is not an external portal or permission decision.

The example phase selector explains initial feasibility, optional Research/POC and pilot review. It does not change operational stage, build BOMs, lock records or send notifications. Existing Master editing and handover gates are preserved. No new API, SQL, role, grant, production user, sample customer/project, external client link, publication or backend data mutation was introduced.

## Verification

- Focused tests: 13 passed across SharedFeasibilityAnalysis.dom.test.tsx, OpportunityDetail.dom.test.tsx and SalesOpportunityPipeline.dom.test.tsx.
- Full TypeScript check passed; final production Vite/Nitro build passed. Existing deprecation/module-directive warnings remain non-blocking.
- The pre-existing package-lock did not match package.json (including missing DOCX and UI-test dependencies). npm install repaired package-lock without changing package.json; the resulting installed dependencies passed the tests/typecheck/build.
- Build-generated unrelated route/MCP files were restored to their original tracked content and excluded from the change.
- Actual localhost browser checks exercised opt-in example rendering, highlight editing, client projection and desktop column alignment. At the requested 390px mobile viewport the visible document width and scroll width both measured 375px; no horizontal overflow. This is UI/layout evidence, not live business workflow or external caller acceptance.

[Internal UI](ssm-analysis-internal-preview.png) · [Client preview](ssm-analysis-client-preview.png) · [Mobile layout](ssm-analysis-mobile-preview.png)

## Review and reuse

Open Sales → Enquiries & Opportunities → an existing opportunity → Feasibility → Try example layout. Open Master returns to the existing Customer inputs tab. The component accepts source data and existing review records through props; it owns no backend. Reuse this component with caller-authorized adapters instead of duplicating file/record authorities for other projects.

Live shared-remarks persistence, granular requirement/department responses, actual client publication, notifications, consolidated decisions and project start remain separate pending contracts. Do not interpret a saved example edit as a Drive, Master, review or notification receipt. Original opportunity/customer data and historical revisions remain unchanged.

## Original-project browser confirmation — 15 October 2026

The first UI commit was observed in the original Lovable project's GitHub-update history. In the existing authenticated embedded preview, Sales → Enquiries & Opportunities → OPPORTUNITY-2026-0013 → Open shared analysis displayed MASTER-2026-0001 revision 1 from the existing read path. Approval was explicitly unverified and no assigned reviews were invented. Try example layout displayed all four fictional discipline cards and their remarks footers. The light-theme original preview and dark-theme isolated preview were both visually inspected.

A final UI isolation refinement places the pre-existing handover/review-status panels inside the internal projection, so they are omitted in Client preview. The integration test covers this host-panel boundary; other tests cover private findings, internal notes and private posted discussion. Unsent internal message drafts are cleared when switching audience. This is a preview inside an existing internal session, not proof of external client identity/RLS acceptance. No external client invitation was created.

Final isolation refinement validation: all 13 focused tests passed again, full TypeScript check passed, and production Vite/Nitro build passed. No runtime/backend gate or unrelated generated route was changed.

Original-project final confirmation: Lovable history showed the client-isolation fix as the previewed source. The existing opportunity opened its linked Master revision, and the example client projection showed four Department remarks headings with Assigned reviews and Review status absent. This confirms UI projection in the existing internal preview, not external client authorization. No record edits or notifications were sent.

[Original project requirements](ssm-analysis-lovable-top-20261015.png) · [Original department columns](ssm-analysis-lovable-departments-20261015.png) · [Final client highlights](ssm-analysis-lovable-client-20261015.png)

## Separate remarks follow-up - 15 October 2026

Each department card now ends with independent Internal remarks (team only) and Client-visible highlight areas. Example internal remarks support Edit, Save preview and Cancel; they never populate the client highlight and are absent from the client projection. Example edits reset on exit. Recorded internal data remains read-only; no live persistence or publication contract was invented. Focused verification: 14 tests passed across shared analysis, opportunity details and combined pipeline, including internal-remark audience isolation and reset.

The existing lifecycle heartbeat was updated and resumed at the user's request. Its first completion boundary is operational feasibility pass plus recorded client approval of the final Master requirements revision and baseline lock before authorized Research/POC or justified Pilot start. This schedules remaining work; it does not declare operational approval or deployment complete.
TypeScript no-emit check and production Vite/Nitro build passed for this follow-up.

## Feasibility readiness correction - 15 October 2026

Inspection found the pure read-only feasibility composer counted a source-pinned not_feasible verdict as READY because it accepted any terminal decision. It now preserves that terminal decision as NOT_FEASIBLE and cannot satisfy baseline readiness. A regression verifies the negative decision blocks the composed baseline even when commercial authorization exists and no unresolved conditions were supplied. All 14 feasibility-planning tests passed. This is a read-only readiness correction, not a deployed handover/approval contract or client acceptance.

Original Lovable preview of the prior remarks commit was inspected using existing OPPORTUNITY-2026-0013: four Internal remarks headings and four Edit internal remark controls appeared in the opt-in example; Client preview excluded those internal headings while retaining Department highlights. No fixtures or live records were changed. Protected submit_sales_feasibility_handover remains source-only pending installation and caller-authenticated acceptance.
Validation completed: 14 feasibility-planning tests, TypeScript no-emit check and production Vite/Nitro build passed. The production build was rerun after the previous run was interrupted; no business changes were made during verification.

## Compact highlight layout - 15 October 2026

Applied two bounded suggestions from Lovable's requested design review: the client footer heading now explicitly says Client-visible highlight, and the department grid uses two columns at normal desktop widths with four columns reserved for extra-wide screens. Internal remarks remain separately labelled and excluded from the client projection. No persistence, notifications or live approval behavior changed.

All 14 focused shared-analysis, opportunity-detail and pipeline tests passed after updating the intentional heading expectations. The existing local-only browser harness showed the actual component with two cards per row and separate audience footer headings, with no backend records accessed. Screenshot: [local compact highlights](ssm-compact-highlights-20261015.png). This is local UI evidence, not original-project browser acceptance or a working client portal.
TypeScript no-emit and production Vite/Nitro build passed for the compact highlight layout.

## Read-only start summary - 15 October 2026

Added a compact internal Before project start summary above department cards: current Master identifier/revision where read, count of recorded department/person assignments, whether review notes exist without claiming condition resolution, client approval and baseline lock. The latter two remain Not verified because no accepted approval/lock read contract is supplied. Missing source remains Not linked or Source not verified. Example mode is explicit, no fake approval. Client projection excludes the entire internal summary.

All 15 focused shared-analysis, opportunity-detail and pipeline tests passed, including recorded-source rendering and client exclusion. Local actual-component browser observation verified the truthful empty state and five fields: [readiness summary](ssm-readiness-summary-20261015.png). No backend reads/writes, approvals, fixtures, notification or project creation were added by this change.
TypeScript no-emit and production Vite/Nitro build passed for the read-only start summary.

## Compact opportunity table and row shortcuts - 15 October 2026

Replaced the stacked button rows with a contained semantic table: opportunity/customer, status/stage, feasibility/team, next action and accessible icon actions. Long content wraps within cells; narrow screens scroll inside the table. Search/status filtering, active-opportunity order, sample labels and actual linked review counts remain. Removed the invented always-unassigned owner column. Next-action fallback suggests preparation without claiming routing success.

The actual Sales route now opens the selected opportunity directly in shared analysis or directly in the existing handover preparation dialog. Row details still open Overview. Handover Send remains disabled under the current explicit backend availability gate; this change does not activate routing, notifications, permissions or project creation. No fixture was saved or duplicated.

Focused tests: 12 shared-analysis/list/details tests passed, followed by 5 direct-shortcut/list tests including both initial views and disabled Send. TypeScript no-emit and production Vite/Nitro build passed. Local actual-component browser evidence: [compact opportunity table](ssm-opportunity-table-20261015.png). Local preview callbacks are inert; real route shortcut behavior is tested in the integration suite, not claimed from the visual harness. Original-project browser readback after sync remains a separate check.

## Original preview shortcut verification - 15 October 2026

Independently verified the original Lovable project d758dbf2-2f0e-44b3-b149-1ec51def58eb using existing OPPORTUNITY-2026-0013. The shared-analysis row icon opens the selected Feasibility tab and Requirements to a shared decision view. The team-handover icon opens Send for feasibility preparation with department and intended reviewer controls; Send remains disabled and Due date unavailable. No routing, notification, fixture, approval or project-start mutation was performed. Screenshot: [original preview table](ssm-original-opportunity-table-20261015.png).

Lovable reported applied original source bf6059784e7e958e8568c98e9a70dd53d2fef37e equivalent to public UI candidate 6685732ccb28e43e3208148a333d0cee562e1718, preserving its separate compatibility changes. Browser behavior above was independently observed; source hash equivalence remains a reported fact. This is not Git history reconciliation or proof that the public GitHub connection is synchronized. Backend installation, ordinary-caller acceptance, persisted remarks/client publication, and approval/lock operations remain pending.
