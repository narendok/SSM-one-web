\set ON_ERROR_STOP on
BEGIN;
SELECT pg_advisory_xact_lock(20261015, 12);
UPDATE public.requirement_feasibility_reviews SET findings = 'same-key writer ran after replay'
WHERE requirement_id = (SELECT requirement_id FROM public.sales_feasibility_handover_requests WHERE request_key = '00000000-0000-4000-8000-000000000198');
COMMIT;
\echo SALES_FEASIBILITY_HANDOVER_ROOT_SAME_KEY_WRITER_COMMITTED_AFTER_REPLAY
