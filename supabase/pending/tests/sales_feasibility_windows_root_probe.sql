-- Must fail specifically on a contended lock, not on any arbitrary exception.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL lock_timeout = '500ms';
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000050',true);
CREATE TEMP TABLE before_counts AS SELECT (SELECT count(*) FROM public.notifications) notices,(SELECT count(*) FROM public.sales_feasibility_handover_requests) receipts;
DO $case$
BEGIN
 BEGIN
  PERFORM * FROM public.submit_sales_feasibility_handover(
   '00000000-0000-4000-8000-000000000095','00000000-0000-4000-8000-000000000020',
   '00000000-0000-4000-8000-000000000010','00000000-0000-4000-8000-000000000071',
   'Root serialization seed','ROOT-LOCAL','Deterministic root serialization validation.',
   ARRAY['00000000-0000-4000-8000-000000000060'::uuid],ARRAY['00000000-0000-4000-8000-000000000062'::uuid],
   '2026-10-13 18:23:00+00'::timestamptz,'00000000-0000-4000-8000-000000000198');
  RAISE EXCEPTION 'LOCAL_CASE_FAIL replay bypassed held root';
 EXCEPTION WHEN lock_not_available THEN NULL;
 END;
 IF (SELECT notices FROM before_counts)<>(SELECT count(*) FROM public.notifications)
 OR (SELECT receipts FROM before_counts)<>(SELECT count(*) FROM public.sales_feasibility_handover_requests) THEN
  RAISE EXCEPTION 'LOCAL_CASE_FAIL contended replay changed durable records';
 END IF;
 RAISE NOTICE 'WINDOWS_ROOT_CONTENTION_PASS expected_sqlstate=55P03 notices_receipts_unchanged=true';
END;
$case$;
ROLLBACK;
