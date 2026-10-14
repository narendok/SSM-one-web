\set ON_ERROR_STOP on
BEGIN;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000050', true);
SELECT pg_advisory_xact_lock(20261015, 32);
DO $case$
BEGIN
  BEGIN
    PERFORM * FROM public.submit_sales_feasibility_handover(
      '00000000-0000-4000-8000-000000000095', '00000000-0000-4000-8000-000000000020',
      '00000000-0000-4000-8000-000000000010', '00000000-0000-4000-8000-000000000071',
      'Competing source handover different key', 'COMPETE-LOCAL', 'Second source owner attempt.',
      ARRAY['00000000-0000-4000-8000-000000000060'::uuid],
      ARRAY['00000000-0000-4000-8000-000000000062'::uuid],
      '2026-10-13 18:23:00+00'::timestamptz, '00000000-0000-4000-8000-000000000213'
    );
    RAISE EXCEPTION 'LOCAL_CASE_FAIL competing source handover accepted';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM <> 'An existing feasibility handover already owns this source; reopen it instead' THEN RAISE; END IF;
  END;
END;
$case$;
COMMIT;
\echo SALES_FEASIBILITY_HANDOVER_COMPETING_SOURCE_SECOND_DENIED