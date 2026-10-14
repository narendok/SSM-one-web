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
  BEGIN PERFORM * FROM public.submit_sales_feasibility_handover('00000000-0000-4000-8000-000000000095', '00000000-0000-4000-8000-000000000020', '00000000-0000-4000-8000-000000000010', '00000000-0000-4000-8000-000000000071', 'Changed handover', 'HANDOVER-LOCAL', 'Synthetic immutable handover.', ARRAY['00000000-0000-4000-8000-000000000060'::uuid], ARRAY['00000000-0000-4000-8000-000000000062'::uuid], '2026-10-13 18:23:00+00'::timestamptz, '00000000-0000-4000-8000-000000000096'); RAISE EXCEPTION 'LOCAL_CASE_FAIL changed handover replay accepted'; EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'Request key conflicts with a different caller or payload' THEN RAISE; END IF; END;
  PERFORM set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000001', true);
  BEGIN PERFORM * FROM public.submit_sales_feasibility_handover('00000000-0000-4000-8000-000000000095', '00000000-0000-4000-8000-000000000020', '00000000-0000-4000-8000-000000000010', '00000000-0000-4000-8000-000000000071', 'Denied handover', NULL, NULL, ARRAY['00000000-0000-4000-8000-000000000060'::uuid], ARRAY['00000000-0000-4000-8000-000000000062'::uuid], '2026-10-13 18:23:00+00'::timestamptz, '00000000-0000-4000-8000-000000000097'); RAISE EXCEPTION 'LOCAL_CASE_FAIL unauthorized handover accepted'; EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'Sales management permission is required' THEN RAISE; END IF; END;
  PERFORM set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000050', true);
  BEGIN PERFORM * FROM public.submit_sales_feasibility_handover('00000000-0000-4000-8000-000000000095', '00000000-0000-4000-8000-000000000020', '00000000-0000-4000-8000-000000000010', '00000000-0000-4000-8000-000000000071', 'Wrong reviewer', NULL, NULL, ARRAY['00000000-0000-4000-8000-000000000060'::uuid], ARRAY['00000000-0000-4000-8000-000000000001'::uuid], '2026-10-13 18:23:00+00'::timestamptz, '00000000-0000-4000-8000-000000000098'); RAISE EXCEPTION 'LOCAL_CASE_FAIL cross-department reviewer accepted'; EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'Selected reviewer is not an active member of the selected department' THEN RAISE; END IF; END;
  BEGIN PERFORM * FROM public.submit_sales_feasibility_handover('00000000-0000-4000-8000-000000000095', '00000000-0000-4000-8000-000000000020', '00000000-0000-4000-8000-000000000010', '00000000-0000-4000-8000-000000000071', 'Stale enquiry', NULL, NULL, ARRAY['00000000-0000-4000-8000-000000000060'::uuid], ARRAY['00000000-0000-4000-8000-000000000062'::uuid], '2026-10-13 18:22:00+00'::timestamptz, '00000000-0000-4000-8000-000000000099'); RAISE EXCEPTION 'LOCAL_CASE_FAIL stale enquiry accepted'; EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'Enquiry source is unavailable or changed; reload before handover' THEN RAISE; END IF; END;
  IF (SELECT count(*) FROM public.customer_requirements) <> v_headers OR (SELECT count(*) FROM public.customer_requirement_revisions) <> v_revisions OR (SELECT count(*) FROM public.requirement_feasibility_reviews) <> v_reviews OR (SELECT count(*) FROM public.notifications) <> v_notices OR (SELECT count(*) FROM public.activity_log WHERE action = 'feasibility_handover_submitted') <> v_audits OR (SELECT count(*) FROM public.sales_feasibility_handover_requests) <> v_receipts THEN RAISE EXCEPTION 'LOCAL_CASE_FAIL denied input left partial handover records'; END IF;
  RAISE NOTICE 'SALES_FEASIBILITY_HANDOVER_LOCAL_ACCEPTANCE_PASS headers=% revisions=% reviews=% notifications=% audits=% receipts=%', v_headers, v_revisions, v_reviews, v_notices, v_audits, v_receipts;
END;
$cases$;
ROLLBACK;

\echo SALES_FEASIBILITY_HANDOVER_REPLAY_SCOPE_CASES_START
BEGIN;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000050', true);
CREATE TEMP TABLE replay_seed AS
SELECT * FROM public.submit_sales_feasibility_handover(
  '00000000-0000-4000-8000-000000000095', '00000000-0000-4000-8000-000000000020',
  '00000000-0000-4000-8000-000000000010', '00000000-0000-4000-8000-000000000071',
  'Replay scope seed', 'REPLAY-LOCAL', 'Replay scope validation.',
  ARRAY['00000000-0000-4000-8000-000000000060'::uuid],
  ARRAY['00000000-0000-4000-8000-000000000062'::uuid],
  '2026-10-13 18:23:00+00'::timestamptz, '00000000-0000-4000-8000-000000000196'
);
DO $cases$
DECLARE
  v_requirement uuid := (SELECT requirement_id FROM replay_seed);
  v_headers integer := (SELECT count(*) FROM public.customer_requirements);
  v_revisions integer := (SELECT count(*) FROM public.customer_requirement_revisions);
  v_reviews integer := (SELECT count(*) FROM public.requirement_feasibility_reviews);
  v_notices integer := (SELECT count(*) FROM public.notifications);
  v_audits integer := (SELECT count(*) FROM public.activity_log WHERE action = 'feasibility_handover_submitted');
  v_receipts integer := (SELECT count(*) FROM public.sales_feasibility_handover_requests);
  v_baseline_reviews integer;
  v_baseline_notices integer;
  v_baseline_audits integer;
  v_baseline_receipts integer;
  v_replay_args text := 'not used';
BEGIN
  PERFORM v_replay_args;
  CREATE TEMP TABLE replay_baseline AS SELECT v_headers AS headers, v_revisions AS revisions, v_reviews AS reviews, v_notices AS notices, v_audits AS audits, v_receipts AS receipts;
  UPDATE public.employees SET employment_status = 'INACTIVE' WHERE user_id = '00000000-0000-4000-8000-000000000062';
  BEGIN
    PERFORM * FROM public.submit_sales_feasibility_handover('00000000-0000-4000-8000-000000000095','00000000-0000-4000-8000-000000000020','00000000-0000-4000-8000-000000000010','00000000-0000-4000-8000-000000000071','Replay scope seed','REPLAY-LOCAL','Replay scope validation.',ARRAY['00000000-0000-4000-8000-000000000060'::uuid],ARRAY['00000000-0000-4000-8000-000000000062'::uuid],'2026-10-13 18:23:00+00'::timestamptz,'00000000-0000-4000-8000-000000000196');
    RAISE EXCEPTION 'LOCAL_CASE_FAIL inactive reviewer replay accepted';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'Selected reviewer is not an active member of the selected department' THEN RAISE; END IF; END;
  UPDATE public.employees SET employment_status = 'ACTIVE' WHERE user_id = '00000000-0000-4000-8000-000000000062';
  DELETE FROM public.employee_departments WHERE employee_id = '00000000-0000-4000-8000-000000000061';
  BEGIN
    PERFORM * FROM public.submit_sales_feasibility_handover('00000000-0000-4000-8000-000000000095','00000000-0000-4000-8000-000000000020','00000000-0000-4000-8000-000000000010','00000000-0000-4000-8000-000000000071','Replay scope seed','REPLAY-LOCAL','Replay scope validation.',ARRAY['00000000-0000-4000-8000-000000000060'::uuid],ARRAY['00000000-0000-4000-8000-000000000062'::uuid],'2026-10-13 18:23:00+00'::timestamptz,'00000000-0000-4000-8000-000000000196');
    RAISE EXCEPTION 'LOCAL_CASE_FAIL removed reviewer membership replay accepted';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'Selected reviewer is not an active member of the selected department' THEN RAISE; END IF; END;
  INSERT INTO public.employee_departments (employee_id, department_id) VALUES ('00000000-0000-4000-8000-000000000061','00000000-0000-4000-8000-000000000060');
  UPDATE public.departments SET is_active = false WHERE id = '00000000-0000-4000-8000-000000000060';
  BEGIN
    PERFORM * FROM public.submit_sales_feasibility_handover('00000000-0000-4000-8000-000000000095','00000000-0000-4000-8000-000000000020','00000000-0000-4000-8000-000000000010','00000000-0000-4000-8000-000000000071','Replay scope seed','REPLAY-LOCAL','Replay scope validation.',ARRAY['00000000-0000-4000-8000-000000000060'::uuid],ARRAY['00000000-0000-4000-8000-000000000062'::uuid],'2026-10-13 18:23:00+00'::timestamptz,'00000000-0000-4000-8000-000000000196');
    RAISE EXCEPTION 'LOCAL_CASE_FAIL inactive department replay accepted';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'Selected department is unavailable' THEN RAISE; END IF; END;
  UPDATE public.departments SET is_active = true WHERE id = '00000000-0000-4000-8000-000000000060';
  UPDATE public.master_specifications SET current_version = 2 WHERE id = '00000000-0000-4000-8000-000000000070';
  BEGIN
    PERFORM * FROM public.submit_sales_feasibility_handover('00000000-0000-4000-8000-000000000095','00000000-0000-4000-8000-000000000020','00000000-0000-4000-8000-000000000010','00000000-0000-4000-8000-000000000071','Replay scope seed','REPLAY-LOCAL','Replay scope validation.',ARRAY['00000000-0000-4000-8000-000000000060'::uuid],ARRAY['00000000-0000-4000-8000-000000000062'::uuid],'2026-10-13 18:23:00+00'::timestamptz,'00000000-0000-4000-8000-000000000196');
    RAISE EXCEPTION 'LOCAL_CASE_FAIL stale Master replay accepted';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'Current Master Specification version is unavailable for this opportunity and customer' THEN RAISE; END IF; END;
  UPDATE public.master_specifications SET current_version = 1 WHERE id = '00000000-0000-4000-8000-000000000070';
  DELETE FROM public.requirement_feasibility_reviews WHERE requirement_id = v_requirement;
  BEGIN
    PERFORM * FROM public.submit_sales_feasibility_handover('00000000-0000-4000-8000-000000000095','00000000-0000-4000-8000-000000000020','00000000-0000-4000-8000-000000000010','00000000-0000-4000-8000-000000000071','Replay scope seed','REPLAY-LOCAL','Replay scope validation.',ARRAY['00000000-0000-4000-8000-000000000060'::uuid],ARRAY['00000000-0000-4000-8000-000000000062'::uuid],'2026-10-13 18:23:00+00'::timestamptz,'00000000-0000-4000-8000-000000000196');
    RAISE EXCEPTION 'LOCAL_CASE_FAIL removed review replay accepted';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'Review graph has changed since this receipt was issued' THEN RAISE; END IF; END;
  INSERT INTO public.requirement_feasibility_reviews (requirement_id, department_id, reviewer_user_id, status, created_by, source_revision_number, master_specification_version_id) VALUES (v_requirement, '00000000-0000-4000-8000-000000000060', '00000000-0000-4000-8000-000000000062', 'pending', '00000000-0000-4000-8000-000000000050', 1, '00000000-0000-4000-8000-000000000071');
  INSERT INTO public.departments (id, is_active) VALUES ('00000000-0000-4000-8000-000000000063', true);
  INSERT INTO public.requirement_feasibility_reviews (requirement_id, department_id, reviewer_user_id, status, created_by, source_revision_number, master_specification_version_id) VALUES (v_requirement, '00000000-0000-4000-8000-000000000063', '00000000-0000-4000-8000-000000000062', 'pending', '00000000-0000-4000-8000-000000000050', 1, '00000000-0000-4000-8000-000000000071');
  BEGIN
    PERFORM * FROM public.submit_sales_feasibility_handover('00000000-0000-4000-8000-000000000095','00000000-0000-4000-8000-000000000020','00000000-0000-4000-8000-000000000010','00000000-0000-4000-8000-000000000071','Replay scope seed','REPLAY-LOCAL','Replay scope validation.',ARRAY['00000000-0000-4000-8000-000000000060'::uuid],ARRAY['00000000-0000-4000-8000-000000000062'::uuid],'2026-10-13 18:23:00+00'::timestamptz,'00000000-0000-4000-8000-000000000196');
    RAISE EXCEPTION 'LOCAL_CASE_FAIL expanded review graph replay accepted';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'Review graph has changed since this receipt was issued' THEN RAISE; END IF; END;
  SELECT reviews, notices, audits, receipts INTO v_baseline_reviews, v_baseline_notices, v_baseline_audits, v_baseline_receipts FROM replay_baseline;
  IF (SELECT count(*) FROM public.customer_requirements) <> v_headers OR (SELECT count(*) FROM public.customer_requirement_revisions) <> v_revisions OR (SELECT count(*) FROM public.notifications) <> v_baseline_notices OR (SELECT count(*) FROM public.activity_log WHERE action = 'feasibility_handover_submitted') <> v_baseline_audits OR (SELECT count(*) FROM public.sales_feasibility_handover_requests) <> v_baseline_receipts THEN RAISE EXCEPTION 'LOCAL_CASE_FAIL denied replay mutated handover headers, revisions, notices, audits, or receipts'; END IF;
  IF (SELECT count(*) FROM public.requirement_feasibility_reviews WHERE requirement_id <> v_requirement) <> v_baseline_reviews - 1 THEN RAISE EXCEPTION 'LOCAL_CASE_FAIL replay mutations escaped the reviewed graph'; END IF;
  RAISE NOTICE 'SALES_FEASIBILITY_HANDOVER_REPLAY_SCOPE_PASS receipt=% inactive_reviewer=denied membership=denied department=denied stale_master=denied removed_review=denied extra_review=denied', v_requirement;
END;
$cases$;
ROLLBACK;
