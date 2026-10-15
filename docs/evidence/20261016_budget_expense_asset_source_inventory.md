# Budget integration source inventory — 16 October 2026

Read-only source inspection; no financial rows, backend queries, mutations or deployment. Generated types/source are not confirmation of installed target contracts.

| Area | Inspected support | Integration gap |
| --- | --- | --- |
| quick_expenses | amount, currency, project_id, department_id, requester_id, category, description, receipt_path, status, Finance review identity/time/notes | Status is typed string, not verified approval/payment enum; recognition events, period/date policy, split allocations and reimbursement matching unverified. |
| createExpense in phase6.functions.ts | Requires authenticated session, validates positive amount/category/description, server number, inserts using server client | No explicit scoped permission/project/department membership check in this handler. Do not expose as delegated budget creation without accepted authorization. Currency/receipt inputs are absent from this handler. |
| finance.expenses.tsx | Lists expenses; creates category/description/amount with is_rd=true | Does not supply project/department despite server support; hardcodes rupee display despite stored currency; failed reads must not become zero budget. No budget baseline/forecast UI or safe multi-currency aggregation inferred. |
| assets | acquisition_cost/date, custodian_user_id, PO/GRN/vendor, category/location, status | No typed currency, project/department budget allocation or depreciation policy in inspected fields. Acquisition is not recurring department spend. |
| asset_assignments | asset_id, assigned_to_user_id, assigned_at/accepted_at/returned_at, status, location and handover notes | Custody history is not financial allocation. No member budget or cost-split authority inferred. |
| savePhase8Record | Table permission mapping assets.edit for assets and assignments; has_permission before server-client save | Generic payload/scope acceptance must be inspected before budget allocation or department-specific extension. Do not create financial authority from this generic API. |

No budget table/approved period/version/transfer contract was found in the targeted generated-type name search. This is not proof of complete schema absence. Next read-only contract review must confirm actual installed objects, status constraints, scope and safe accounting recognition. Until then use labelled synthetic projections only, keep currencies separate, exclude unrecognized requests from actuals, and never total original asset acquisition again on each assignment. Do not modify RLS/privileges to bypass these gaps.

References: src/lib/phase6.functions.ts; src/routes/_authenticated/finance.expenses.tsx; src/lib/phase8.functions.ts; src/integrations/supabase/types.ts. Master scope remains docs/planning/SSM_ONE_WEB_PORTAL_MASTER_PLAN.md; this is evidence, not a competing roadmap.
