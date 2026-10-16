-- Synthetic disposable fixture only. Marker is acquired after the protected root.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL statement_timeout = '12s';
SELECT pg_advisory_xact_lock(hashtextextended('sales-feasibility-requirement-root:' || (SELECT requirement_id::text FROM public.sales_feasibility_handover_requests WHERE request_key='00000000-0000-4000-8000-000000000198'),0));
SELECT pg_advisory_xact_lock(20261016,36);
SELECT pg_sleep(5);
COMMIT;
