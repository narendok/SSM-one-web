\set ON_ERROR_STOP on
BEGIN;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000050', true);
DO $replay$
BEGIN
  BEGIN
    PERFORM * FROM public.submit_sales_feasibility_handover(
      '00000000-0000-4000-8000-000000000095', '00000000-0000-4000-8000-000000000020',
      '00000000-0000-4000-8000-000000000010', '00000000-0000-4000-8000-000000000071',
      'Graph lock seed', 'GRAPH-LOCK', 'Concurrent graph lock validation.',
      ARRAY['00000000-0000-4000-8000-000000000060'::uuid],
      ARRAY['00000000-0000-4000-8000-000000000062'::uuid],
      '2026-10-13 18:23:00+00'::timestamptz, '00000000-0000-4000-8000-000000000197'
    );
    RAISE EXCEPTION 'LOCAL_CASE_FAIL concurrent graph modification replay accepted';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM <> 'Review graph has changed since this receipt was issued' THEN RAISE; END IF;
  END;
END;
$replay$;
COMMIT;
\echo SALES_FEASIBILITY_HANDOVER_GRAPH_LOCK_REPLAY_DENIED