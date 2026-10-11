-- LOCAL DISPOSABLE INSTALLED-CONTRACT DECISION ACCEPTANCE ONLY.
\set ON_ERROR_STOP on
BEGIN;
INSERT INTO public.customers VALUES ('10000000-0000-4000-8000-000000000010');
INSERT INTO public.sales_opportunities VALUES ('10000000-0000-4000-8000-000000000011', '10000000-0000-4000-8000-000000000010');
INSERT INTO public.customer_requirements VALUES ('10000000-0000-4000-8000-000000000012', '10000000-0000-4000-8000-000000000010', '10000000-0000-4000-8000-000000000011');
INSERT INTO public.requirement_baselines VALUES ('10000000-0000-4000-8000-000000000013', '10000000-0000-4000-8000-000000000012', 'project_initiated', '10000000-0000-4000-8000-000000000001', clock_timestamp());
INSERT INTO public.departments VALUES ('10000000-0000-4000-8000-000000000014', 'HARDWARE', true), ('10000000-0000-4000-8000-000000000024', 'FIRMWARE', true);
INSERT INTO public.employees VALUES
  ('10000000-0000-4000-8000-000000000015', '10000000-0000-4000-8000-000000000001', 'ACTIVE'),
  ('10000000-0000-4000-8000-000000000025', '10000000-0000-4000-8000-000000000002', 'ACTIVE'),
  ('10000000-0000-4000-8000-000000000026', '10000000-0000-4000-8000-000000000003', 'ACTIVE'),
  ('10000000-0000-4000-8000-000000000027', '10000000-0000-4000-8000-000000000004', 'ACTIVE');
INSERT INTO public.employee_departments VALUES
  ('10000000-0000-4000-8000-000000000015', '10000000-0000-4000-8000-000000000014'),
  ('10000000-0000-4000-8000-000000000025', '10000000-0000-4000-8000-000000000014'),
  ('10000000-0000-4000-8000-000000000026', '10000000-0000-4000-8000-000000000024'),
  ('10000000-0000-4000-8000-000000000027', '10000000-0000-4000-8000-000000000014');
INSERT INTO public.access_roles(id, name) VALUES ('10000000-0000-4000-8000-000000000028', 'Local engineering approver');
INSERT INTO public.employee_access_roles VALUES
  ('10000000-0000-4000-8000-000000000025', '10000000-0000-4000-8000-000000000028'),
  ('10000000-0000-4000-8000-000000000026', '10000000-0000-4000-8000-000000000028'),
  ('10000000-0000-4000-8000-000000000027', '10000000-0000-4000-8000-000000000028');
INSERT INTO public.access_role_permissions(role_id, permission_id)
SELECT '10000000-0000-4000-8000-000000000028', id FROM public.permissions WHERE key = 'engineering.approve';
INSERT INTO public.projects VALUES ('10000000-0000-4000-8000-000000000016', '10000000-0000-4000-8000-000000000010', '10000000-0000-4000-8000-000000000011', '10000000-0000-4000-8000-000000000013', '10000000-0000-4000-8000-000000000015');
INSERT INTO public.project_boms VALUES ('10000000-0000-4000-8000-000000000017', '10000000-0000-4000-8000-000000000016');
INSERT INTO public.project_team_members VALUES ('10000000-0000-4000-8000-000000000019', '10000000-0000-4000-8000-000000000016', '10000000-0000-4000-8000-000000000015');
INSERT INTO public.sales_project_handovers VALUES ('10000000-0000-4000-8000-000000000020', '10000000-0000-4000-8000-000000000013', '10000000-0000-4000-8000-000000000016', 'completed');

CREATE FUNCTION pg_temp.submit_local_candidate(p_part text, p_request uuid) RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE v_candidate uuid;
BEGIN
  PERFORM set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', true);
  SELECT candidate_id INTO v_candidate FROM public.submit_component_candidate('10000000-0000-4000-8000-000000000016', '10000000-0000-4000-8000-000000000017', jsonb_build_object('categoryId', 'local-category', 'name', p_part, 'partNumber', p_part), p_request);
  RETURN v_candidate;
END $$;

CREATE TEMP TABLE approved AS SELECT pg_temp.submit_local_candidate('APPROVED-LOCAL', '10000000-0000-4000-8000-000000000090') AS candidate_id;
CREATE TEMP TABLE approved_revision AS SELECT id AS revision_id FROM public.component_candidate_payload_revisions WHERE candidate_id = (SELECT candidate_id FROM approved);
SELECT set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
CREATE TEMP TABLE approved_first AS SELECT * FROM public.decide_component_candidate((SELECT candidate_id FROM approved), (SELECT revision_id FROM approved_revision), ' APPROVE ', '  Reviewed   for  purchase  ', '10000000-0000-4000-8000-000000000091');
DO $$ BEGIN
  IF (SELECT count(*) FROM approved_first) <> 1 OR (SELECT replayed FROM approved_first) OR (SELECT status FROM public.component_candidate_submissions WHERE id = (SELECT candidate_id FROM approved)) <> 'APPROVED_PENDING_PURCHASE' THEN RAISE EXCEPTION 'Authorized approve did not persist its exact pending-purchase state'; END IF;
  IF (SELECT count(*) FROM public.component_candidate_decisions WHERE candidate_id = (SELECT candidate_id FROM approved) AND decision = 'APPROVED_PENDING_PURCHASE') <> 1 OR (SELECT count(*) FROM public.component_candidate_decision_request_receipts WHERE request_key = '10000000-0000-4000-8000-000000000091') <> 1 THEN RAISE EXCEPTION 'Authorized approve did not append decision and receipt'; END IF;
END $$;
CREATE TEMP TABLE approved_replay AS SELECT * FROM public.decide_component_candidate((SELECT candidate_id FROM approved), (SELECT revision_id FROM approved_revision), 'approve', 'Reviewed for purchase', '10000000-0000-4000-8000-000000000091');
DO $$ BEGIN
  IF NOT (SELECT replayed FROM approved_replay) OR (SELECT decision_id FROM approved_replay) <> (SELECT decision_id FROM approved_first) THEN RAISE EXCEPTION 'Exact decision replay after state transition was not returned'; END IF;
END $$;
DO $$ BEGIN
  BEGIN PERFORM * FROM public.decide_component_candidate((SELECT candidate_id FROM approved), (SELECT revision_id FROM approved_revision), 'approve', 'Different note', '10000000-0000-4000-8000-000000000091'); RAISE EXCEPTION 'Decision payload mismatch was accepted'; EXCEPTION WHEN OTHERS THEN IF SQLERRM NOT LIKE 'Decision request key conflicts%' THEN RAISE; END IF; END;
  PERFORM set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', true);
  BEGIN PERFORM * FROM public.decide_component_candidate((SELECT candidate_id FROM approved), (SELECT revision_id FROM approved_revision), 'approve', 'Reviewed for purchase', '10000000-0000-4000-8000-000000000091'); RAISE EXCEPTION 'Decision actor mismatch was accepted'; EXCEPTION WHEN OTHERS THEN IF SQLERRM NOT LIKE 'Candidate decision requires%' AND SQLERRM NOT LIKE 'Decision request key conflicts%' THEN RAISE; END IF; END;
END $$;

CREATE TEMP TABLE rejected AS SELECT pg_temp.submit_local_candidate('REJECTED-LOCAL', '10000000-0000-4000-8000-000000000092') AS candidate_id;
CREATE TEMP TABLE rejected_revision AS SELECT id AS revision_id FROM public.component_candidate_payload_revisions WHERE candidate_id = (SELECT candidate_id FROM rejected);
SELECT set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
CREATE TEMP TABLE rejected_first AS SELECT * FROM public.decide_component_candidate((SELECT candidate_id FROM rejected), (SELECT revision_id FROM rejected_revision), 'REJECT', 'Rejected for local validation', '10000000-0000-4000-8000-000000000093');
DO $$ BEGIN IF (SELECT replayed FROM rejected_first) OR (SELECT status FROM public.component_candidate_submissions WHERE id = (SELECT candidate_id FROM rejected)) <> 'REJECTED' THEN RAISE EXCEPTION 'Authorized reject did not persist rejected state'; END IF; END $$;

CREATE TEMP TABLE denied AS SELECT pg_temp.submit_local_candidate('DENIED-LOCAL', '10000000-0000-4000-8000-000000000094') AS candidate_id;
CREATE TEMP TABLE denied_revision AS SELECT id AS revision_id FROM public.component_candidate_payload_revisions WHERE candidate_id = (SELECT candidate_id FROM denied);
DO $$ BEGIN
  PERFORM set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', true);
  BEGIN PERFORM * FROM public.decide_component_candidate((SELECT candidate_id FROM denied), (SELECT revision_id FROM denied_revision), 'APPROVE', 'No permission', '10000000-0000-4000-8000-000000000095'); RAISE EXCEPTION 'Missing permission was accepted'; EXCEPTION WHEN OTHERS THEN IF SQLERRM NOT LIKE 'Candidate decision requires%' THEN RAISE; END IF; END;
  PERFORM set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', true);
  BEGIN PERFORM * FROM public.decide_component_candidate((SELECT candidate_id FROM denied), (SELECT revision_id FROM denied_revision), 'APPROVE', 'Wrong department', '10000000-0000-4000-8000-000000000096'); RAISE EXCEPTION 'Wrong department was accepted'; EXCEPTION WHEN OTHERS THEN IF SQLERRM NOT LIKE 'Candidate decision requires%' THEN RAISE; END IF; END;
  UPDATE public.employees SET employment_status = 'INACTIVE' WHERE id = '10000000-0000-4000-8000-000000000025';
  PERFORM set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', true);
  BEGIN PERFORM * FROM public.decide_component_candidate((SELECT candidate_id FROM denied), (SELECT revision_id FROM denied_revision), 'APPROVE', 'Inactive employee', '10000000-0000-4000-8000-000000000097'); RAISE EXCEPTION 'Inactive employee was accepted'; EXCEPTION WHEN OTHERS THEN IF SQLERRM NOT LIKE 'Candidate decision requires%' THEN RAISE; END IF; END;
  UPDATE public.employees SET employment_status = 'ACTIVE' WHERE id = '10000000-0000-4000-8000-000000000025';
  PERFORM set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', true);
  BEGIN PERFORM * FROM public.decide_component_candidate((SELECT candidate_id FROM denied), (SELECT revision_id FROM denied_revision), 'APPROVE', 'Self review', '10000000-0000-4000-8000-000000000098'); RAISE EXCEPTION 'Self review was accepted'; EXCEPTION WHEN OTHERS THEN IF SQLERRM NOT LIKE 'Candidate decision requires%' THEN RAISE; END IF; END;
  PERFORM set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', true);
  BEGIN PERFORM * FROM public.decide_component_candidate((SELECT candidate_id FROM denied), '10000000-0000-4000-8000-000000000099', 'APPROVE', 'Wrong revision', '10000000-0000-4000-8000-000000000099'); RAISE EXCEPTION 'Wrong revision was accepted'; EXCEPTION WHEN OTHERS THEN IF SQLERRM NOT LIKE 'Candidate decision requires%' THEN RAISE; END IF; END;
  BEGIN PERFORM * FROM public.decide_component_candidate((SELECT candidate_id FROM approved), (SELECT revision_id FROM approved_revision), 'APPROVE', 'Terminal status', '10000000-0000-4000-8000-000000000100'); RAISE EXCEPTION 'Terminal candidate status was accepted'; EXCEPTION WHEN OTHERS THEN IF SQLERRM NOT LIKE 'Candidate decision requires%' THEN RAISE; END IF; END;
END $$;

CREATE TEMP TABLE rollback_candidate AS SELECT pg_temp.submit_local_candidate('ROLLBACK-LOCAL', '10000000-0000-4000-8000-000000000101') AS candidate_id;
CREATE TEMP TABLE rollback_revision AS SELECT id AS revision_id FROM public.component_candidate_payload_revisions WHERE candidate_id = (SELECT candidate_id FROM rollback_candidate);
INSERT INTO public.candidate_test_failpoints VALUES ('component_candidate_decision_request_receipts', true);
CREATE TRIGGER candidate_decision_fail_receipt BEFORE INSERT ON public.component_candidate_decision_request_receipts FOR EACH ROW EXECUTE FUNCTION public.candidate_test_failpoint();
SELECT set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', false);
DO $$ DECLARE before_decisions integer; before_audits integer; before_receipts integer; BEGIN
  SELECT count(*) INTO before_decisions FROM public.component_candidate_decisions;
  SELECT count(*) INTO before_audits FROM public.component_candidate_submission_audit_events;
  SELECT count(*) INTO before_receipts FROM public.component_candidate_decision_request_receipts;
  BEGIN PERFORM * FROM public.decide_component_candidate((SELECT candidate_id FROM rollback_candidate), (SELECT revision_id FROM rollback_revision), 'APPROVE', 'Inject receipt failure', '10000000-0000-4000-8000-000000000102'); RAISE EXCEPTION 'Decision rollback failpoint was accepted'; EXCEPTION WHEN OTHERS THEN IF SQLERRM NOT LIKE 'Injected candidate test failure%' THEN RAISE; END IF; END;
  IF (SELECT status FROM public.component_candidate_submissions WHERE id = (SELECT candidate_id FROM rollback_candidate)) <> 'SUBMITTED' OR (SELECT count(*) FROM public.component_candidate_decisions) <> before_decisions OR (SELECT count(*) FROM public.component_candidate_submission_audit_events) <> before_audits OR (SELECT count(*) FROM public.component_candidate_decision_request_receipts) <> before_receipts THEN RAISE EXCEPTION 'Decision receipt failure did not roll back status, decision, audit, and receipt'; END IF;
END $$;
ROLLBACK;