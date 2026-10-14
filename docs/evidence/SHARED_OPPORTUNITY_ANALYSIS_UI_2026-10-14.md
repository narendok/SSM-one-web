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
