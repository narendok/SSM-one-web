\set ON_ERROR_STOP on
BEGIN;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000050', true);
SELECT pg_advisory_xact_lock(20261015, 14);
DO $case$
BEGIN
  BEGIN
    PERFORM public.assign_requirement_feasibility_review(
      (SELECT requirement_id FROM public.sales_feasibility_handover_requests WHERE request_key = '00000000-0000-4000-8000-000000000198'),
      '00000000-0000-4000-8000-000000000060', '00000000-0000-4000-8000-000000000062');
    RAISE EXCEPTION 'LOCAL_CASE_FAIL different-key assignment unexpectedly completed while root lock held';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM = 'LOCAL_CASE_FAIL different-key assignment unexpectedly completed while root lock held' THEN RAISE; END IF;
  END;
END;
$case$;
COMMIT;
\echo SALES_FEASIBILITY_HANDOVER_ROOT_DIFFERENT_KEY_SERIALIZED
