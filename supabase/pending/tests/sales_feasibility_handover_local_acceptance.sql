-- LOCAL DISPOSABLE ACCEPTANCE ONLY. Proves SQL branch behavior against a
-- synthetic schema; it is not authentication, RLS, grant, or deployment proof.
\set ON_ERROR_STOP on
BEGIN;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000050', true);
CREATE TEMP TABLE handover AS
SELECT * FROM public.submit_sales_feasibility_handover(
  '00000000-0000-4000-8000-000000000095', '00000000-0000-4000-8000-000000000020',
  '00000000-0000-4000-8000-000000000010', '00000000-0000-4000-8000-000000000071',
  'Synthetic feasibility handover', 'HANDOVER-LOCAL', 'Synthetic immutable handover.',
  ARRAY['00000000-0000-4000-8000-000000000060'::uuid],
  ARRAY['00000000-0000-4000-8000-000000000062'::uuid],
  '2026-10-13 18:23:00+00'::timestamptz, '00000000-0000-4000-8000-000000000096'
);
CREATE TEMP TABLE handover_replay AS
SELECT * FROM public.submit_sales_feasibility_handover(
  '00000000-0000-4000-8000-000000000095', '00000000-0000-4000-8000-000000000020',
  '00000000-0000-4000-8000-000000000010', '00000000-0000-4000-8000-000000000071',
  ' Synthetic feasibility handover ', 'HANDOVER-LOCAL', 'Synthetic immutable handover.',
  ARRAY['00000000-0000-4000-8000-000000000060'::uuid],
  ARRAY['00000000-0000-4000-8000-000000000062'::uuid],
  '2026-10-13 18:23:00+00'::timestamptz, '00000000-0000-4000-8000-000000000096'
);
DO $cases$
DECLARE v_requirement uuid := (SELECT requirement_id FROM handover); v_headers integer; v_revisions integer; v_reviews integer; v_notices integer; v_audits integer; v_receipts integer;
BEGIN
  IF (SELECT replayed FROM handover) OR NOT (SELECT replayed FROM handover_replay) OR (SELECT requirement_id FROM handover_replay) IS DISTINCT FROM v_requirement THEN RAISE EXCEPTION 'LOCAL_CASE_FAIL exact handover replay did not return the original graph'; END IF;
  SELECT count(*), (SELECT count(*) FROM public.customer_requirement_revisions), (SELECT count(*) FROM public.requirement_feasibility_reviews), (SELECT count(*) FROM public.notifications), (SELECT count(*) FROM public.activity_log WHERE action = 'feasibility_handover_submitted'), (SELECT count(*) FROM public.sales_feasibility_handover_requests) INTO v_headers, v_revisions, v_reviews, v_notices, v_audits, v_receipts FROM public.customer_requirements;
  IF v_headers <> 2 OR v_revisions <> 2 OR v_reviews <> 1 OR v_notices <> 1 OR v_audits <> 1 OR v_receipts <> 1 THEN RAISE EXCEPTION 'LOCAL_CASE_FAIL handover did not persist an exact single graph headers=% revisions=% reviews=% notices=% audits=% receipts=%', v_headers, v_revisions, v_reviews, v_notices, v_audits, v_receipts; END IF;
  BEGIN PERFORM public.submit_sales_feasibility_handover('00000000-0000-4000-8000-000000000095', '00000000-0000-4000-8000-000000000020', '00000000-0000-4000-8000-000000000010', '00000000-0000-4000-8000-000000000071', 'Changed handover', 'HANDOVER-LOCAL', 'Synthetic immutable handover.', ARRAY['00000000-0000-4000-8000-000000000060'::uuid], ARRAY['00000000-0000-4000-8000-000000000062'::uuid], '2026-10-13 18:23:00+00'::timestamptz, '00000000-0000-4000-8000-000000000096'); RAISE EXCEPTION 'LOCAL_CASE_FAIL changed handover replay accepted'; EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'Request key conflicts with a different caller or payload' THEN RAISE; END IF; END;
  SELECT set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000001', true);
  BEGIN PERFORM public.submit_sales_feasibility_handover('00000000-0000-4000-8000-000000000095', '00000000-0000-4000-8000-000000000020', '00000000-0000-4000-8000-000000000010', '00000000-0000-4000-8000-000000000071', 'Denied handover', NULL, NULL, ARRAY['00000000-0000-4000-8000-000000000060'::uuid], ARRAY['00000000-0000-4000-8000-000000000062'::uuid], '2026-10-13 18:23:00+00'::timestamptz, '00000000-0000-4000-8000-000000000097'); RAISE EXCEPTION 'LOCAL_CASE_FAIL unauthorized handover accepted'; EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'Sales management permission is required' THEN RAISE; END IF; END;
  SELECT set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000050', true);
  BEGIN PERFORM public.submit_sales_feasibility_handover('00000000-0000-4000-8000-000000000095', '00000000-0000-4000-8000-000000000020', '00000000-0000-4000-8000-000000000010', '00000000-0000-4000-8000-000000000071', 'Wrong reviewer', NULL, NULL, ARRAY['00000000-0000-4000-8000-000000000060'::uuid], ARRAY['00000000-0000-4000-8000-000000000001'::uuid], '2026-10-13 18:23:00+00'::timestamptz, '00000000-0000-4000-8000-000000000098'); RAISE EXCEPTION 'LOCAL_CASE_FAIL cross-department reviewer accepted'; EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'Selected reviewer is not an active member of the selected department' THEN RAISE; END IF; END;
  BEGIN PERFORM public.submit_sales_feasibility_handover('00000000-0000-4000-8000-000000000095', '00000000-0000-4000-8000-000000000020', '00000000-0000-4000-8000-000000000010', '00000000-0000-4000-8000-000000000071', 'Stale enquiry', NULL, NULL, ARRAY['00000000-0000-4000-8000-000000000060'::uuid], ARRAY['00000000-0000-4000-8000-000000000062'::uuid], '2026-10-13 18:22:00+00'::timestamptz, '00000000-0000-4000-8000-000000000099'); RAISE EXCEPTION 'LOCAL_CASE_FAIL stale enquiry accepted'; EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'Enquiry source is unavailable or changed; reload before handover' THEN RAISE; END IF; END;
  IF (SELECT count(*) FROM public.customer_requirements) <> v_headers OR (SELECT count(*) FROM public.customer_requirement_revisions) <> v_revisions OR (SELECT count(*) FROM public.requirement_feasibility_reviews) <> v_reviews OR (SELECT count(*) FROM public.notifications) <> v_notices OR (SELECT count(*) FROM public.activity_log WHERE action = 'feasibility_handover_submitted') <> v_audits OR (SELECT count(*) FROM public.sales_feasibility_handover_requests) <> v_receipts THEN RAISE EXCEPTION 'LOCAL_CASE_FAIL denied input left partial handover records'; END IF;
  RAISE NOTICE 'SALES_FEASIBILITY_HANDOVER_LOCAL_ACCEPTANCE_PASS headers=% revisions=% reviews=% notifications=% audits=% receipts=%', v_headers, v_revisions, v_reviews, v_notices, v_audits, v_receipts;
END;
$cases$;
ROLLBACK;
