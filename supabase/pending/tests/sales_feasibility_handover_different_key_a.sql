\set ON_ERROR_STOP on
BEGIN;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000050', true);
SELECT pg_advisory_xact_lock(20261015, 13);
SELECT pg_advisory_xact_lock(hashtextextended('sales-feasibility-requirement-root:' || (SELECT requirement_id::text FROM public.sales_feasibility_handover_requests WHERE request_key = '00000000-0000-4000-8000-000000000198'), 0));
SELECT pg_advisory_xact_lock(20261015, 14);
COMMIT;
\echo SALES_FEASIBILITY_HANDOVER_ROOT_DIFFERENT_KEY_HELD
