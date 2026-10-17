-- DISPOSABLE LOCAL ONLY; synthetic actor context is not managed JWT acceptance.
BEGIN;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000050',true);
CREATE TEMP TABLE readback_seed AS SELECT * FROM public.submit_sales_feasibility_handover(
 '00000000-0000-4000-8000-000000000095','00000000-0000-4000-8000-000000000020',
 '00000000-0000-4000-8000-000000000010','00000000-0000-4000-8000-000000000071',
 'Readback seed',NULL,NULL,ARRAY['00000000-0000-4000-8000-000000000060'::uuid],
 ARRAY['00000000-0000-4000-8000-000000000062'::uuid],'2026-10-13 18:23:00+00','00000000-0000-4000-8000-000000000199');
CREATE FUNCTION pg_temp.observe_handover() RETURNS integer LANGUAGE sql AS $$
 SELECT count(*)::integer FROM public.read_sales_feasibility_handover_receipt(
 '00000000-0000-4000-8000-000000000199','00000000-0000-4000-8000-000000000095','00000000-0000-4000-8000-000000000020',
 '00000000-0000-4000-8000-000000000010','00000000-0000-4000-8000-000000000071'); $$;
DO $$ BEGIN
 IF has_function_privilege('authenticated','public.read_sales_feasibility_handover_receipt(uuid,uuid,uuid,uuid,uuid)','EXECUTE') THEN RAISE EXCEPTION 'Default caller access exposed'; END IF;
 IF pg_temp.observe_handover()<>1 THEN RAISE EXCEPTION 'Positive graph missing'; END IF;
END $$;
\ir ../20261017_sales_handover_readback_access_review_only.sql
SET LOCAL ROLE authenticated;
SELECT * FROM public.read_sales_feasibility_handover_receipt('00000000-0000-4000-8000-000000000199','00000000-0000-4000-8000-000000000095','00000000-0000-4000-8000-000000000020','00000000-0000-4000-8000-000000000010','00000000-0000-4000-8000-000000000071');
RESET ROLE;
DO $$ BEGIN
 PERFORM set_config('request.jwt.claim.sub','',true);
 IF pg_temp.observe_handover()<>0 THEN RAISE EXCEPTION 'Null actor exposed'; END IF;
 PERFORM set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
 IF pg_temp.observe_handover()<>0 THEN RAISE EXCEPTION 'Other actor exposed'; END IF;
 PERFORM set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000050',true);
 IF EXISTS(SELECT 1 FROM public.read_sales_feasibility_handover_receipt('00000000-0000-4000-8000-000000000199','00000000-0000-4000-8000-000000000095','00000000-0000-4000-8000-000000000020','00000000-0000-4000-8000-000000000011','00000000-0000-4000-8000-000000000071')) THEN RAISE EXCEPTION 'Wrong source exposed'; END IF;
 BEGIN
  DELETE FROM public.notifications WHERE target_entity_id IN (SELECT unnest(review_ids) FROM readback_seed);
  IF pg_temp.observe_handover()<>0 THEN RAISE EXCEPTION 'Missing notification accepted'; END IF;
  RAISE EXCEPTION 'restore_case' USING ERRCODE='ZX001';
 EXCEPTION WHEN SQLSTATE 'ZX001' THEN NULL; END;
 BEGIN
  UPDATE public.requirement_feasibility_reviews SET reviewer_user_id='00000000-0000-4000-8000-000000000001' WHERE requirement_id=(SELECT requirement_id FROM readback_seed);
  IF pg_temp.observe_handover()<>0 THEN RAISE EXCEPTION 'Changed assignment accepted'; END IF;
  RAISE EXCEPTION 'restore_case' USING ERRCODE='ZX001';
 EXCEPTION WHEN SQLSTATE 'ZX001' THEN NULL; END;
 BEGIN
  UPDATE public.departments SET is_active=false WHERE id='00000000-0000-4000-8000-000000000060';
  IF pg_temp.observe_handover()<>0 THEN RAISE EXCEPTION 'Inactive department accepted'; END IF;
  RAISE EXCEPTION 'restore_case' USING ERRCODE='ZX001';
 EXCEPTION WHEN SQLSTATE 'ZX001' THEN NULL; END;
 BEGIN
  DELETE FROM public.activity_log WHERE entity_id=(SELECT requirement_id FROM readback_seed);
  IF pg_temp.observe_handover()<>0 THEN RAISE EXCEPTION 'Missing audit accepted'; END IF;
  RAISE EXCEPTION 'restore_case' USING ERRCODE='ZX001';
 EXCEPTION WHEN SQLSTATE 'ZX001' THEN NULL; END;
 BEGIN
  UPDATE public.employees SET employment_status='INACTIVE' WHERE user_id='00000000-0000-4000-8000-000000000062';
  IF pg_temp.observe_handover()<>0 THEN RAISE EXCEPTION 'Inactive reviewer accepted'; END IF;
  RAISE EXCEPTION 'restore_case' USING ERRCODE='ZX001';
 EXCEPTION WHEN SQLSTATE 'ZX001' THEN NULL; END;
 BEGIN
  UPDATE public.customer_requirements SET title='Changed title' WHERE id=(SELECT requirement_id FROM readback_seed);
  IF pg_temp.observe_handover()<>0 THEN RAISE EXCEPTION 'Changed title accepted'; END IF;
  RAISE EXCEPTION 'restore_case' USING ERRCODE='ZX001';
 EXCEPTION WHEN SQLSTATE 'ZX001' THEN NULL; END;
 BEGIN
  UPDATE public.master_specifications SET current_version=2;
  IF pg_temp.observe_handover()<>0 THEN RAISE EXCEPTION 'Changed Master accepted'; END IF;
  RAISE EXCEPTION 'restore_case' USING ERRCODE='ZX001';
 EXCEPTION WHEN SQLSTATE 'ZX001' THEN NULL; END;
 BEGIN
  UPDATE public.sales_enquiries SET updated_at=updated_at+interval '1 second' WHERE id='00000000-0000-4000-8000-000000000095';
  IF pg_temp.observe_handover()<>0 THEN RAISE EXCEPTION 'Changed enquiry accepted'; END IF;
  RAISE EXCEPTION 'restore_case' USING ERRCODE='ZX001';
 EXCEPTION WHEN SQLSTATE 'ZX001' THEN NULL; END;
 IF pg_temp.observe_handover()<>1 THEN RAISE EXCEPTION 'Subcase rollback failed'; END IF;
END $$;
ROLLBACK;
\echo HANDOVER_READBACK_LOCAL_PASS own_graph=true null_other_source_denied=true notification_assignment_department_audit_drift_denied=true default_access_denied=true
