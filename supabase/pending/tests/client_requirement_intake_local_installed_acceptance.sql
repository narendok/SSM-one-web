-- LOCAL DISPOSABLE EXECUTABLE ACCEPTANCE ONLY. It proves SQL behavior with
-- synthetic GUC actors, not managed RLS, JWT transport, grants, or deployment.
\set ON_ERROR_STOP on
BEGIN;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000001', true);
SELECT set_config('request.jwt.claim.role', 'authenticated', true);
CREATE TEMP TABLE first_submission AS SELECT public.submit_external_customer_requirement('00000000-0000-4000-8000-000000000020', '00000000-0000-4000-8000-000000000010', 'Synthetic local requirement', 'REQ-LOCAL', '{"description":"Synthetic requirement description"}'::jsonb, '00000000-0000-4000-8000-000000000090') AS requirement_id;
CREATE TEMP TABLE replay_submission AS SELECT public.submit_external_customer_requirement('00000000-0000-4000-8000-000000000020', '00000000-0000-4000-8000-000000000010', ' Synthetic local requirement ', 'REQ-LOCAL', '{"description":"Synthetic requirement description"}'::jsonb, '00000000-0000-4000-8000-000000000090') AS requirement_id;
DO $cases$
DECLARE v_requirement uuid := (SELECT requirement_id FROM first_submission); v_headers integer; v_revisions integer; v_audits integer; v_receipts integer;
BEGIN
  IF (SELECT requirement_id FROM replay_submission) IS DISTINCT FROM v_requirement THEN RAISE EXCEPTION 'LOCAL_CASE_FAIL exact replay did not return the original requirement'; END IF;
  IF (SELECT count(*) FROM public.customer_requirements WHERE id = v_requirement) <> 1 OR (SELECT count(*) FROM public.customer_requirement_revisions WHERE requirement_id = v_requirement AND revision_number = 1) <> 1 OR (SELECT count(*) FROM public.activity_log WHERE entity_id = v_requirement AND action = 'external_submitted') <> 1 OR (SELECT count(*) FROM public.external_requirement_submission_requests WHERE requirement_id = v_requirement) <> 1 THEN RAISE EXCEPTION 'LOCAL_CASE_FAIL initial submission did not persist the exact four-record graph'; END IF;
  SELECT count(*), (SELECT count(*) FROM public.customer_requirement_revisions), (SELECT count(*) FROM public.activity_log WHERE action = 'external_submitted'), (SELECT count(*) FROM public.external_requirement_submission_requests) INTO v_headers, v_revisions, v_audits, v_receipts FROM public.customer_requirements;
  BEGIN PERFORM public.submit_external_customer_requirement('00000000-0000-4000-8000-000000000020', '00000000-0000-4000-8000-000000000010', 'Changed payload', 'REQ-LOCAL', '{"description":"Synthetic requirement description"}'::jsonb, '00000000-0000-4000-8000-000000000090'); RAISE EXCEPTION 'LOCAL_CASE_FAIL changed payload replay accepted'; EXCEPTION WHEN OTHERS THEN IF SQLSTATE <> 'P0001' OR SQLERRM <> 'Request key conflicts with a different caller or payload' THEN RAISE; END IF; END;
  PERFORM set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000002', true);
  BEGIN PERFORM public.submit_external_customer_requirement('00000000-0000-4000-8000-000000000020', '00000000-0000-4000-8000-000000000010', 'Synthetic local requirement', 'REQ-LOCAL', '{"description":"Synthetic requirement description"}'::jsonb, '00000000-0000-4000-8000-000000000090'); RAISE EXCEPTION 'LOCAL_CASE_FAIL actor-mismatched replay accepted'; EXCEPTION WHEN OTHERS THEN IF SQLSTATE <> 'P0001' OR SQLERRM <> 'Request key conflicts with a different caller or payload' THEN RAISE; END IF; END;
  PERFORM set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000001', true);
  UPDATE public.external_portal_access SET expires_at = now() - interval '1 minute' WHERE external_contact_id = '00000000-0000-4000-8000-000000000040';
  BEGIN PERFORM public.submit_external_customer_requirement('00000000-0000-4000-8000-000000000020', '00000000-0000-4000-8000-000000000010', 'Expired scope', NULL, '{"description":"Expired scope must fail"}'::jsonb, '00000000-0000-4000-8000-000000000091'); RAISE EXCEPTION 'LOCAL_CASE_FAIL expired scope accepted'; EXCEPTION WHEN OTHERS THEN IF SQLSTATE <> 'P0001' OR SQLERRM <> 'Client requirement access is inactive, expired, revoked, or outside its granted scope' THEN RAISE; END IF; END;
  UPDATE public.external_portal_access SET expires_at = NULL, invitation_revoked_at = now() WHERE external_contact_id = '00000000-0000-4000-8000-000000000040';
  BEGIN PERFORM public.submit_external_customer_requirement('00000000-0000-4000-8000-000000000020', '00000000-0000-4000-8000-000000000010', 'Revoked scope', NULL, '{"description":"Revoked scope must fail"}'::jsonb, '00000000-0000-4000-8000-000000000092'); RAISE EXCEPTION 'LOCAL_CASE_FAIL revoked scope accepted'; EXCEPTION WHEN OTHERS THEN IF SQLSTATE <> 'P0001' OR SQLERRM <> 'Client requirement access is inactive, expired, revoked, or outside its granted scope' THEN RAISE; END IF; END;
  UPDATE public.external_portal_access SET invitation_revoked_at = NULL WHERE external_contact_id = '00000000-0000-4000-8000-000000000040';
  BEGIN PERFORM public.submit_external_customer_requirement('00000000-0000-4000-8000-000000000020', '00000000-0000-4000-8000-000000000011', 'Wrong customer', NULL, '{"description":"Mismatched source must fail"}'::jsonb, '00000000-0000-4000-8000-000000000093'); RAISE EXCEPTION 'LOCAL_CASE_FAIL opportunity/customer mismatch accepted'; EXCEPTION WHEN OTHERS THEN IF SQLSTATE <> 'P0001' OR SQLERRM <> 'Client requirement access is inactive, expired, revoked, or outside its granted scope' THEN RAISE; END IF; END;
  PERFORM set_config('client_requirement.test.failpoint', 'activity_log', true);
  BEGIN PERFORM public.submit_external_customer_requirement('00000000-0000-4000-8000-000000000020', '00000000-0000-4000-8000-000000000010', 'Rollback request', NULL, '{"description":"Audit failure must roll back"}'::jsonb, '00000000-0000-4000-8000-000000000094'); RAISE EXCEPTION 'LOCAL_CASE_FAIL audit failpoint accepted'; EXCEPTION WHEN OTHERS THEN IF SQLSTATE <> 'P0001' OR SQLERRM <> 'Local test failpoint: activity_log' THEN RAISE; END IF; END;
  PERFORM set_config('client_requirement.test.failpoint', '', true);
  IF (SELECT count(*) FROM public.customer_requirements) <> v_headers OR (SELECT count(*) FROM public.customer_requirement_revisions) <> v_revisions OR (SELECT count(*) FROM public.activity_log WHERE action = 'external_submitted') <> v_audits OR (SELECT count(*) FROM public.external_requirement_submission_requests) <> v_receipts THEN RAISE EXCEPTION 'LOCAL_CASE_FAIL rejected or failed input left partial records'; END IF;
  RAISE NOTICE 'CLIENT_REQUIREMENT_LOCAL_ACCEPTANCE_PASS headers=% revisions=% audits=% receipts=%', v_headers, v_revisions, v_audits, v_receipts;
END;
$cases$;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000050', true);
CREATE TEMP TABLE assigned_historical_review AS SELECT public.assign_requirement_feasibility_review('00000000-0000-4000-8000-000000000080', '00000000-0000-4000-8000-000000000060', '00000000-0000-4000-8000-000000000062') AS review_id;
DO $assignment$
DECLARE v_review uuid := (SELECT review_id FROM assigned_historical_review); v_before jsonb; v_assignment_audits integer;
BEGIN
  IF (SELECT source_revision_id FROM public.requirement_feasibility_reviews WHERE id = v_review) IS DISTINCT FROM '00000000-0000-4000-8000-000000000081'::uuid
     OR (SELECT source_revision_number FROM public.requirement_feasibility_reviews WHERE id = v_review) IS DISTINCT FROM 1
     OR (SELECT master_specification_version_id FROM public.requirement_feasibility_reviews WHERE id = v_review) IS DISTINCT FROM '00000000-0000-4000-8000-000000000071'::uuid
     OR (SELECT master_specification_version_number FROM public.requirement_feasibility_reviews WHERE id = v_review) IS DISTINCT FROM 1
     OR (SELECT applicable_workstreams FROM public.requirement_feasibility_reviews WHERE id = v_review) IS DISTINCT FROM '["HARDWARE"]'::jsonb THEN RAISE EXCEPTION 'LOCAL_CASE_FAIL historical requirement/specification tuple was not pinned exactly'; END IF;
  IF (SELECT max(version_number) FROM public.master_specification_versions WHERE specification_id = '00000000-0000-4000-8000-000000000070') <> 2
     OR (SELECT specification_data FROM public.master_specification_versions WHERE id = '00000000-0000-4000-8000-000000000072') IS DISTINCT FROM '{"workstreams":["FIRMWARE"]}'::jsonb THEN RAISE EXCEPTION 'LOCAL_CASE_FAIL fixture header advancement was not present'; END IF;
  PERFORM public.assign_requirement_feasibility_review('00000000-0000-4000-8000-000000000080', '00000000-0000-4000-8000-000000000060', '00000000-0000-4000-8000-000000000062');
  IF (SELECT count(*) FROM public.requirement_feasibility_reviews WHERE id = v_review) <> 1 THEN RAISE EXCEPTION 'LOCAL_CASE_FAIL exact assignment replay did not preserve the pinned review'; END IF;
  SELECT jsonb_build_object('source_revision_id', source_revision_id, 'source_revision_number', source_revision_number, 'master_specification_version_id', master_specification_version_id, 'master_specification_version_number', master_specification_version_number, 'applicable_workstreams', applicable_workstreams, 'reviewer_user_id', reviewer_user_id, 'status', status) INTO v_before FROM public.requirement_feasibility_reviews WHERE id = v_review;
  SELECT count(*) INTO v_assignment_audits FROM public.activity_log WHERE entity_id = v_review AND action = 'assigned';
  UPDATE public.requirement_feasibility_reviews SET master_specification_version_number = 2 WHERE id = v_review;
  BEGIN PERFORM public.assign_requirement_feasibility_review('00000000-0000-4000-8000-000000000080', '00000000-0000-4000-8000-000000000060', '00000000-0000-4000-8000-000000000062'); RAISE EXCEPTION 'LOCAL_CASE_FAIL mismatched persisted tuple accepted'; EXCEPTION WHEN OTHERS THEN IF SQLSTATE <> 'P0001' OR SQLERRM <> 'Open feasibility review is pinned to different immutable provenance' THEN RAISE; END IF; END;
  IF (SELECT jsonb_build_object('source_revision_id', source_revision_id, 'source_revision_number', source_revision_number, 'master_specification_version_id', master_specification_version_id, 'master_specification_version_number', master_specification_version_number, 'applicable_workstreams', applicable_workstreams, 'reviewer_user_id', reviewer_user_id, 'status', status) FROM public.requirement_feasibility_reviews WHERE id = v_review) IS DISTINCT FROM v_before
     OR (SELECT count(*) FROM public.activity_log WHERE entity_id = v_review AND action = 'assigned') <> v_assignment_audits THEN RAISE EXCEPTION 'LOCAL_CASE_FAIL tuple mismatch changed historical review or audit history'; END IF;
  RAISE NOTICE 'CLIENT_REQUIREMENT_HISTORICAL_ASSIGNMENT_PASS review_id=% source_revision=1 specification_version=1 replay=true mismatch_rejected=true', v_review;
END;
$assignment$;
ROLLBACK;