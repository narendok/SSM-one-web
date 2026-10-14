\set ON_ERROR_STOP on
BEGIN;
SELECT pg_advisory_xact_lock(20261015, 2);
UPDATE public.requirement_feasibility_reviews
SET applicable_workstreams = '["FIRMWARE"]'::jsonb
WHERE requirement_id = (SELECT requirement_id FROM public.sales_feasibility_handover_requests WHERE request_key = '00000000-0000-4000-8000-000000000197');
COMMIT;
\echo SALES_FEASIBILITY_HANDOVER_REPLAY_HELD_PLAIN_WRITER_COMMITTED