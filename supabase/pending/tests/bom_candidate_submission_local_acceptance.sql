-- LOCAL DISPOSABLE INSTALLED-CONTRACT ACCEPTANCE ONLY.
\set ON_ERROR_STOP on
BEGIN;
INSERT INTO public.customers VALUES ('00000000-0000-4000-8000-000000000010');
INSERT INTO public.sales_opportunities VALUES ('00000000-0000-4000-8000-000000000011', '00000000-0000-4000-8000-000000000010');
INSERT INTO public.customer_requirements VALUES ('00000000-0000-4000-8000-000000000012', '00000000-0000-4000-8000-000000000010', '00000000-0000-4000-8000-000000000011');
INSERT INTO public.requirement_baselines VALUES ('00000000-0000-4000-8000-000000000013', '00000000-0000-4000-8000-000000000012', 'project_initiated', '00000000-0000-4000-8000-000000000001', clock_timestamp());
INSERT INTO public.departments VALUES ('00000000-0000-4000-8000-000000000014', 'HARDWARE', true);
INSERT INTO public.employees VALUES ('00000000-0000-4000-8000-000000000015', '00000000-0000-4000-8000-000000000001', 'ACTIVE');
INSERT INTO public.projects VALUES ('00000000-0000-4000-8000-000000000016', '00000000-0000-4000-8000-000000000010', '00000000-0000-4000-8000-000000000011', '00000000-0000-4000-8000-000000000013', '00000000-0000-4000-8000-000000000015');
INSERT INTO public.project_boms VALUES ('00000000-0000-4000-8000-000000000017', '00000000-0000-4000-8000-000000000016');
INSERT INTO public.project_bom_items VALUES ('00000000-0000-4000-8000-000000000018', '00000000-0000-4000-8000-000000000017', 'Manual line remains untouched');
INSERT INTO public.project_team_members VALUES ('00000000-0000-4000-8000-000000000019', '00000000-0000-4000-8000-000000000016', '00000000-0000-4000-8000-000000000015');
INSERT INTO public.sales_project_handovers VALUES ('00000000-0000-4000-8000-000000000020', '00000000-0000-4000-8000-000000000013', '00000000-0000-4000-8000-000000000016', 'completed');
SELECT set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000001', false);
CREATE TEMP TABLE first_submit AS SELECT * FROM public.submit_component_candidate('00000000-0000-4000-8000-000000000016', '00000000-0000-4000-8000-000000000017', '{"categoryId":"cat-1","name":"  Local resistor  ","partNumber":" R-LOCAL-1 ","manufacturer":" Local Parts ","cost":1.25}'::jsonb, '00000000-0000-4000-8000-000000000090');
DO $$ BEGIN
  IF (SELECT count(*) FROM first_submit) <> 1 OR (SELECT replayed FROM first_submit) THEN RAISE EXCEPTION 'Expected one first submission'; END IF;
  IF (SELECT count(*) FROM public.component_candidate_submissions) <> 1 OR (SELECT count(*) FROM public.component_candidate_payload_revisions) <> 1 OR (SELECT count(*) FROM public.component_candidate_submission_audit_events) <> 1 OR (SELECT count(*) FROM public.component_candidate_submission_request_receipts) <> 1 THEN RAISE EXCEPTION 'Expected header, immutable payload, audit, and receipt'; END IF;
  IF (SELECT count(*) FROM public.project_bom_items) <> 1 THEN RAISE EXCEPTION 'Submission changed manual BOM lines'; END IF;
END $$;
CREATE TEMP TABLE exact_replay AS SELECT * FROM public.submit_component_candidate('00000000-0000-4000-8000-000000000016', '00000000-0000-4000-8000-000000000017', '{"partNumber":"R-LOCAL-1","name":"Local resistor","cost":1.25,"manufacturer":"Local Parts","categoryId":"cat-1"}'::jsonb, '00000000-0000-4000-8000-000000000090');
DO $$ BEGIN IF NOT (SELECT replayed FROM exact_replay) OR (SELECT candidate_id FROM exact_replay) <> (SELECT candidate_id FROM first_submit) THEN RAISE EXCEPTION 'Exact replay did not return persisted candidate'; END IF; END $$;
DO $$ BEGIN
  BEGIN PERFORM * FROM public.submit_component_candidate('00000000-0000-4000-8000-000000000016', '00000000-0000-4000-8000-000000000017', '{"categoryId":"cat-1","name":"Changed","partNumber":"R-LOCAL-1"}'::jsonb, '00000000-0000-4000-8000-000000000090'); RAISE EXCEPTION 'Changed replay was accepted'; EXCEPTION WHEN OTHERS THEN IF SQLERRM NOT LIKE 'Request key conflicts%' THEN RAISE; END IF; END;
  UPDATE public.sales_project_handovers SET status = 'initiated' WHERE id = '00000000-0000-4000-8000-000000000020';
  BEGIN PERFORM * FROM public.submit_component_candidate('00000000-0000-4000-8000-000000000016', '00000000-0000-4000-8000-000000000017', '{"categoryId":"cat-1","name":"Denied","partNumber":"R-2"}'::jsonb, '00000000-0000-4000-8000-000000000091'); RAISE EXCEPTION 'Incomplete handover was accepted'; EXCEPTION WHEN OTHERS THEN IF SQLERRM NOT LIKE 'Candidate submission requires%' THEN RAISE; END IF; END;
  UPDATE public.sales_project_handovers SET status = 'completed', project_id = '00000000-0000-4000-8000-000000000099' WHERE id = '00000000-0000-4000-8000-000000000020';
  BEGIN PERFORM * FROM public.submit_component_candidate('00000000-0000-4000-8000-000000000016', '00000000-0000-4000-8000-000000000017', '{"categoryId":"cat-1","name":"Denied","partNumber":"R-3"}'::jsonb, '00000000-0000-4000-8000-000000000092'); RAISE EXCEPTION 'Mismatched project handover was accepted'; EXCEPTION WHEN OTHERS THEN IF SQLERRM NOT LIKE 'Candidate submission requires%' THEN RAISE; END IF; END;
END $$;
UPDATE public.sales_project_handovers SET project_id = '00000000-0000-4000-8000-000000000016' WHERE id = '00000000-0000-4000-8000-000000000020';
SELECT set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000002', false);
DO $$ BEGIN
  BEGIN PERFORM * FROM public.submit_component_candidate('00000000-0000-4000-8000-000000000016', '00000000-0000-4000-8000-000000000017', '{"categoryId":"cat-1","name":"Actor denied","partNumber":"R-4"}'::jsonb, '00000000-0000-4000-8000-000000000093'); RAISE EXCEPTION 'Unauthorized actor was accepted'; EXCEPTION WHEN OTHERS THEN IF SQLERRM NOT LIKE 'Candidate submission requires%' THEN RAISE; END IF; END;
END $$;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000001', false);
INSERT INTO public.candidate_test_failpoints VALUES ('component_candidate_submission_request_receipts', true);
DO $$ DECLARE before_headers integer; before_revisions integer; before_audits integer; before_receipts integer; BEGIN
  SELECT count(*) INTO before_headers FROM public.component_candidate_submissions;
  SELECT count(*) INTO before_revisions FROM public.component_candidate_payload_revisions;
  SELECT count(*) INTO before_audits FROM public.component_candidate_submission_audit_events;
  SELECT count(*) INTO before_receipts FROM public.component_candidate_submission_request_receipts;
  BEGIN PERFORM * FROM public.submit_component_candidate('00000000-0000-4000-8000-000000000016', '00000000-0000-4000-8000-000000000017', '{"categoryId":"cat-1","name":"Rollback","partNumber":"R-5"}'::jsonb, '00000000-0000-4000-8000-000000000094'); RAISE EXCEPTION 'Rollback failpoint was accepted'; EXCEPTION WHEN OTHERS THEN IF SQLERRM NOT LIKE 'Injected candidate test failure%' THEN RAISE; END IF; END;
  IF (SELECT count(*) FROM public.component_candidate_submissions) <> before_headers OR (SELECT count(*) FROM public.component_candidate_payload_revisions) <> before_revisions OR (SELECT count(*) FROM public.component_candidate_submission_audit_events) <> before_audits OR (SELECT count(*) FROM public.component_candidate_submission_request_receipts) <> before_receipts THEN RAISE EXCEPTION 'Receipt failure did not roll back every candidate record'; END IF;
END $$;
ROLLBACK;