\set ON_ERROR_STOP on
BEGIN;
INSERT INTO public.employees VALUES
 ('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000001','ACTIVE'),
 ('00000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-000000000002','ACTIVE'),
 ('00000000-0000-4000-8000-000000000003','00000000-0000-4000-8000-000000000003','ACTIVE'),
 ('00000000-0000-4000-8000-000000000004','00000000-0000-4000-8000-000000000004','ACTIVE');
INSERT INTO public.departments VALUES
 ('00000000-0000-4000-8000-000000000010','PURCHASE',true),
 ('00000000-0000-4000-8000-000000000011','HARDWARE',true);
INSERT INTO public.employee_departments VALUES
 ('00000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-000000000010'),
 ('00000000-0000-4000-8000-000000000003','00000000-0000-4000-8000-000000000011');
INSERT INTO public.projects VALUES ('00000000-0000-4000-8000-000000000020','00000000-0000-4000-8000-000000000001');
INSERT INTO public.project_team_members VALUES
 ('00000000-0000-4000-8000-000000000020','00000000-0000-4000-8000-000000000001'),
 ('00000000-0000-4000-8000-000000000020','00000000-0000-4000-8000-000000000002');
INSERT INTO public.project_boms(id,project_id,bom_number,revision) VALUES ('00000000-0000-4000-8000-000000000030','00000000-0000-4000-8000-000000000020','BOM-LOCAL-1','7');
INSERT INTO public.project_bom_items VALUES ('00000000-0000-4000-8000-000000000031','00000000-0000-4000-8000-000000000030',1,'00000000-0000-4000-8000-000000000040');
INSERT INTO public.components VALUES
 ('00000000-0000-4000-8000-000000000040','CAT-001','Catalog Inc','Authoritative component'),
 ('00000000-0000-4000-8000-000000000041','CAT-002','Catalog Inc','Other authoritative component');
INSERT INTO public.permission_test_grants VALUES
 ('00000000-0000-4000-8000-000000000001','projects.manage'),
 ('00000000-0000-4000-8000-000000000002','procurement.edit'),
 ('00000000-0000-4000-8000-000000000003','procurement.edit');
-- These grants exist only inside the disposable cluster so each non-owner
-- role exercises the proposed public transport boundary. They are never part
-- of the pending contract or a managed role.
GRANT EXECUTE ON FUNCTION public.submit_project_bom_procurement_review(uuid,uuid,text,jsonb,uuid) TO procurement_requester_test, procurement_assigned_test, procurement_other_department_test, procurement_unassigned_test;
GRANT EXECUTE ON FUNCTION public.analyze_project_bom_procurement_review(uuid,uuid,integer,jsonb,uuid) TO procurement_requester_test, procurement_assigned_test, procurement_other_department_test, procurement_unassigned_test;
GRANT EXECUTE ON FUNCTION public.decide_project_bom_procurement_review(uuid,text,timestamptz,jsonb,text,text,uuid) TO procurement_requester_test, procurement_assigned_test, procurement_other_department_test, procurement_unassigned_test;
GRANT EXECUTE ON FUNCTION public.read_project_bom_procurement_review(uuid) TO procurement_requester_test, procurement_assigned_test, procurement_other_department_test, procurement_unassigned_test;
SET ROLE procurement_requester_test;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',false);
DO $$ BEGIN
  BEGIN
    PERFORM * FROM public.submit_project_bom_procurement_review('00000000-0000-4000-8000-000000000020','00000000-0000-4000-8000-000000000030','7','[{"kind":"existing","componentId":"00000000-0000-4000-8000-000000000040","mpn":"forged","referenceDesignators":"R1","quantity":1}]'::jsonb,'00000000-0000-4000-8000-000000000050');
    RAISE EXCEPTION 'Derived catalog field was accepted';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM NOT LIKE 'Existing Procurement row 1 cannot supply derived catalog fields%' THEN RAISE; END IF; END;
  BEGIN
    PERFORM * FROM public.submit_project_bom_procurement_review('00000000-0000-4000-8000-000000000020','00000000-0000-4000-8000-000000000030','6','[]'::jsonb,'00000000-0000-4000-8000-000000000051');
    RAISE EXCEPTION 'Empty stale input was accepted';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM NOT LIKE 'Procurement submission requires%' THEN RAISE; END IF; END;
  BEGIN
    PERFORM * FROM public.submit_project_bom_procurement_review('00000000-0000-4000-8000-000000000020','00000000-0000-4000-8000-000000000030','7','[{"kind":"existing","sourceBomItemId":"00000000-0000-4000-8000-000000000031","componentId":"00000000-0000-4000-8000-000000000041","referenceDesignators":"R2","quantity":1}]'::jsonb,'00000000-0000-4000-8000-000000000052');
    RAISE EXCEPTION 'Mismatched saved BOM item pin was accepted';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM NOT LIKE 'Selected component is unavailable%' AND SQLERRM NOT LIKE 'Source BOM item does not pin the selected authoritative component%' THEN RAISE; END IF; END;
END $$;
RESET ROLE;
CREATE TEMP TABLE first_submit AS
SELECT * FROM public.submit_project_bom_procurement_review('00000000-0000-4000-8000-000000000020','00000000-0000-4000-8000-000000000030','7','[
 {"kind":"existing","sourceBomItemId":"00000000-0000-4000-8000-000000000031","componentId":"00000000-0000-4000-8000-000000000040","referenceDesignators":"R1","quantity":2,"manualNote":"keep manual note"},
 {"kind":"new","mpn":"NEW-007","manufacturer":"Proposal Ltd","description":"Uncreated proposed part","referenceDesignators":"U1","quantity":1}
]'::jsonb,'00000000-0000-4000-8000-000000000060');
GRANT SELECT ON first_submit TO procurement_requester_test, procurement_assigned_test, procurement_other_department_test, procurement_unassigned_test;
CREATE TEMP TABLE first_submit_lines AS
SELECT id, source_kind FROM public.project_bom_procurement_review_request_lines WHERE request_id=(SELECT request_id FROM first_submit);
GRANT SELECT ON first_submit_lines TO procurement_requester_test, procurement_assigned_test, procurement_other_department_test, procurement_unassigned_test;
CREATE TEMP TABLE first_submit_state AS
SELECT id, status, decision_note, pinned_bom_updated_at FROM public.project_bom_procurement_review_requests WHERE id=(SELECT request_id FROM first_submit);
GRANT SELECT ON first_submit_state TO procurement_requester_test, procurement_assigned_test, procurement_other_department_test, procurement_unassigned_test;
DO $$ BEGIN
 IF (SELECT count(*) FROM first_submit)<>1 OR (SELECT replayed FROM first_submit) THEN RAISE EXCEPTION 'First submission failed'; END IF;
 IF (SELECT count(*) FROM public.project_bom_procurement_review_requests)<>1 OR (SELECT count(*) FROM public.project_bom_procurement_review_request_lines)<>2 OR (SELECT count(*) FROM public.project_bom_procurement_review_audit_events)<>1 OR (SELECT count(*) FROM public.project_bom_procurement_review_receipts)<>1 THEN RAISE EXCEPTION 'Submission did not atomically persist snapshot, audit, and receipt'; END IF;
 IF (SELECT authoritative_mpn FROM public.project_bom_procurement_review_request_lines WHERE source_kind='EXISTING_COMPONENT') <> 'CAT-001' THEN RAISE EXCEPTION 'Existing component MPN was not server-derived'; END IF;
 IF (SELECT count(*) FROM public.components)<>2 OR (SELECT count(*) FROM public.project_bom_items)<>1 THEN RAISE EXCEPTION 'Submission changed component or BOM state'; END IF;
END $$;
CREATE TEMP TABLE exact_replay AS SELECT * FROM public.submit_project_bom_procurement_review('00000000-0000-4000-8000-000000000020','00000000-0000-4000-8000-000000000030','7','[{"quantity":2,"referenceDesignators":"R1","componentId":"00000000-0000-4000-8000-000000000040","sourceBomItemId":"00000000-0000-4000-8000-000000000031","kind":"existing","manualNote":"keep manual note"},{"quantity":1,"referenceDesignators":"U1","description":"Uncreated proposed part","manufacturer":"Proposal Ltd","mpn":"NEW-007","kind":"new"}]'::jsonb,'00000000-0000-4000-8000-000000000060');
DO $$ BEGIN
 IF NOT (SELECT replayed FROM exact_replay) OR (SELECT request_id FROM exact_replay)<>(SELECT request_id FROM first_submit) THEN RAISE EXCEPTION 'Exact replay mismatch'; END IF;
 BEGIN PERFORM * FROM public.submit_project_bom_procurement_review('00000000-0000-4000-8000-000000000020','00000000-0000-4000-8000-000000000030','7','[{"kind":"new","mpn":"CHANGED","description":"Changed","referenceDesignators":"U1","quantity":1}]'::jsonb,'00000000-0000-4000-8000-000000000060'); RAISE EXCEPTION 'Changed replay accepted'; EXCEPTION WHEN OTHERS THEN IF SQLERRM NOT LIKE 'Request key conflicts%' THEN RAISE; END IF; END;
END $$;
SET ROLE procurement_assigned_test;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000002',false);
DO $$ DECLARE v_request uuid:=(SELECT request_id FROM first_submit); v_existing_line uuid; v_new_line uuid; BEGIN
  SELECT id INTO v_existing_line FROM first_submit_lines WHERE source_kind='EXISTING_COMPONENT';
  SELECT id INTO v_new_line FROM first_submit_lines WHERE source_kind='NEW_PART';
  BEGIN PERFORM * FROM public.decide_project_bom_procurement_review(v_request,'7',(SELECT pinned_bom_updated_at FROM first_submit_state WHERE id=v_request),'[]'::jsonb,'ALLOW','all rows reviewed','00000000-0000-4000-8000-000000000061'); RAISE EXCEPTION 'Allow without analysis accepted'; EXCEPTION WHEN OTHERS THEN IF SQLERRM NOT LIKE 'Allow requires an exact reviewed analysis revision%' THEN RAISE; END IF; END;
  PERFORM * FROM public.analyze_project_bom_procurement_review(v_request,v_existing_line,0,'{"availabilityState":"AVAILABLE","costState":"TBC","sourcingState":"PENDING","observedUnitCost":12.5,"currency":"INR","leadTimeDays":14,"analysisNote":"Supplier response pending"}'::jsonb,'00000000-0000-4000-8000-000000000062');
  PERFORM * FROM public.analyze_project_bom_procurement_review(v_request,v_new_line,0,'{"availabilityState":"TBC","costState":"TBC","sourcingState":"UNAVAILABLE","analysisNote":"No verified source yet"}'::jsonb,'00000000-0000-4000-8000-000000000063');
  PERFORM * FROM public.decide_project_bom_procurement_review(v_request,'7',(SELECT pinned_bom_updated_at FROM first_submit_state WHERE id=v_request),(SELECT jsonb_agg(jsonb_build_object('requestLineId', id, 'analysisRevision', 1) ORDER BY id) FROM first_submit_lines),'ALLOW','analysis complete; Hardware selection remains separate','00000000-0000-4000-8000-000000000061');
  IF (SELECT (public.read_project_bom_procurement_review(v_request) ->> 'status')) <> 'ALLOWED_PENDING_HARDWARE_SELECTION' THEN RAISE EXCEPTION 'Allow did not remain handoff-only'; END IF;
END $$;
RESET ROLE;
SET ROLE procurement_other_department_test;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000003',false);
DO $$ BEGIN
  BEGIN PERFORM * FROM public.analyze_project_bom_procurement_review((SELECT request_id FROM first_submit),(SELECT id FROM first_submit_lines LIMIT 1),0,'{"availabilityState":"TBC","costState":"TBC","sourcingState":"TBC","analysisNote":"unauthorized"}'::jsonb,'00000000-0000-4000-8000-000000000064'); RAISE EXCEPTION 'Other-department analyst accepted'; EXCEPTION WHEN OTHERS THEN IF SQLERRM NOT LIKE 'Procurement analysis requires an active assigned Procurement employee%' THEN RAISE; END IF; END;
  BEGIN PERFORM public.read_project_bom_procurement_review((SELECT request_id FROM first_submit)); RAISE EXCEPTION 'Other-department read accepted'; EXCEPTION WHEN OTHERS THEN IF SQLERRM NOT LIKE 'Procurement analysis requires an active assigned Procurement employee%' THEN RAISE; END IF; END;
END $$;
RESET ROLE;
SET ROLE procurement_unassigned_test;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000004',false);
DO $$ BEGIN
  BEGIN PERFORM public.read_project_bom_procurement_review((SELECT request_id FROM first_submit)); RAISE EXCEPTION 'Unassigned read accepted'; EXCEPTION WHEN OTHERS THEN IF SQLERRM NOT LIKE 'Procurement analysis requires procurement.edit%' THEN RAISE; END IF; END;
END $$;
RESET ROLE;
SET ROLE procurement_requester_test;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',false);
DO $$ DECLARE v_read jsonb; BEGIN
  SELECT public.read_project_bom_procurement_review((SELECT request_id FROM first_submit)) INTO v_read;
  IF v_read->>'id' <> (SELECT request_id::text FROM first_submit) OR jsonb_array_length(v_read->'lines') <> 2 THEN RAISE EXCEPTION 'Original requester did not receive exact scoped readback'; END IF;
END $$;
RESET ROLE;
SET ROLE procurement_assigned_test;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000002',false);
DO $$ DECLARE v_request uuid:=(SELECT request_id FROM first_submit); v_line uuid:=(SELECT id FROM first_submit_lines WHERE source_kind='EXISTING_COMPONENT'); v_read jsonb; BEGIN
  SELECT public.read_project_bom_procurement_review(v_request) INTO v_read;
  IF v_read->>'pinnedBomRevision' <> '7' OR jsonb_array_length(v_read->'lines') <> 2 THEN RAISE EXCEPTION 'Scoped read did not return exact immutable request snapshot'; END IF;
  IF ((v_read->'lines'->0->'analysis'->>'revision')::integer) <> 1 OR (v_read->'lines'->0->'analysis'->>'observedUnitCost') <> '12.5' THEN RAISE EXCEPTION 'Scoped read did not return latest audited analysis'; END IF;
  BEGIN PERFORM * FROM public.analyze_project_bom_procurement_review(v_request,v_line,0,'{"availabilityState":"AVAILABLE","costState":"AVAILABLE","sourcingState":"AVAILABLE","analysisNote":"stale"}'::jsonb,'00000000-0000-4000-8000-000000000066'); RAISE EXCEPTION 'Stale analysis revision accepted'; EXCEPTION WHEN OTHERS THEN IF SQLERRM NOT LIKE 'Procurement request is no longer pending analysis%' AND SQLERRM NOT LIKE 'The Procurement line analysis revision is stale%' THEN RAISE; END IF; END;
END $$;
RESET ROLE;
-- Direct table reads are denied to authenticated non-owner roles. The only
-- authorized snapshot route above is the SECURITY DEFINER read entrypoint.
SET ROLE procurement_assigned_test;
DO $$ BEGIN
  BEGIN PERFORM count(*) FROM public.project_bom_procurement_review_requests; RAISE EXCEPTION 'Direct request read accepted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN PERFORM count(*) FROM public.project_bom_procurement_review_request_lines; RAISE EXCEPTION 'Direct snapshot-line read accepted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN PERFORM count(*) FROM public.project_bom_procurement_review_analyses; RAISE EXCEPTION 'Direct commercial-analysis read accepted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN PERFORM count(*) FROM public.project_bom_procurement_review_receipts; RAISE EXCEPTION 'Direct receipt read accepted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN PERFORM count(*) FROM public.project_bom_procurement_review_audit_events; RAISE EXCEPTION 'Direct decision/audit read accepted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
SET ROLE procurement_requester_test;
DO $$ BEGIN
  BEGIN PERFORM count(*) FROM public.project_bom_procurement_review_requests; RAISE EXCEPTION 'Requester direct request read accepted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN PERFORM count(*) FROM public.project_bom_procurement_review_analyses; RAISE EXCEPTION 'Requester direct commercial-analysis read accepted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
-- Owner-only fixture drift simulates an unrelated BOM revision; subsequent
-- decision remains a non-owner authenticated call.
DO $$ BEGIN
 UPDATE public.project_boms SET revision='8' WHERE id='00000000-0000-4000-8000-000000000030';
END $$;
SET ROLE procurement_requester_test;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',false);
DO $$ BEGIN
 BEGIN PERFORM * FROM public.submit_project_bom_procurement_review('00000000-0000-4000-8000-000000000020','00000000-0000-4000-8000-000000000030','7','[{"kind":"new","mpn":"STALE","description":"Stale","referenceDesignators":"R2","quantity":1}]'::jsonb,'00000000-0000-4000-8000-000000000065'); RAISE EXCEPTION 'Stale BOM submission accepted'; EXCEPTION WHEN OTHERS THEN IF SQLERRM NOT LIKE 'The project BOM revision is stale%' THEN RAISE; END IF; END;
END $$;
RESET ROLE;
SET ROLE procurement_requester_test;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',false);
CREATE TEMP TABLE deny_submit AS
SELECT * FROM public.submit_project_bom_procurement_review('00000000-0000-4000-8000-000000000020','00000000-0000-4000-8000-000000000030','8','[{"kind":"existing","sourceBomItemId":"00000000-0000-4000-8000-000000000031","componentId":"00000000-0000-4000-8000-000000000040","referenceDesignators":"D1","quantity":1}]'::jsonb,'00000000-0000-4000-8000-000000000070');
GRANT SELECT ON deny_submit TO procurement_assigned_test;
CREATE TEMP TABLE deny_submit_state AS
SELECT id, pinned_bom_updated_at FROM public.project_bom_procurement_review_requests WHERE id=(SELECT request_id FROM deny_submit);
GRANT SELECT ON deny_submit_state TO procurement_assigned_test;
RESET ROLE;
SET ROLE procurement_assigned_test;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000002',false);
CREATE TEMP TABLE first_deny AS
SELECT * FROM public.decide_project_bom_procurement_review((SELECT request_id FROM deny_submit),'8',(SELECT pinned_bom_updated_at FROM deny_submit_state),'[]'::jsonb,'DENY','No approved source satisfies the submitted requirement','00000000-0000-4000-8000-000000000071');
CREATE TEMP TABLE exact_deny_replay AS
SELECT * FROM public.decide_project_bom_procurement_review((SELECT request_id FROM deny_submit),'8',(SELECT pinned_bom_updated_at FROM deny_submit_state),'[]'::jsonb,'DENY','No approved source satisfies the submitted requirement','00000000-0000-4000-8000-000000000071');
DO $$ BEGIN
  IF (SELECT replayed FROM first_deny) OR NOT (SELECT replayed FROM exact_deny_replay) THEN RAISE EXCEPTION 'Deny replay state is incorrect'; END IF;
  IF (SELECT (public.read_project_bom_procurement_review((SELECT request_id FROM deny_submit)) ->> 'status')) <> 'DENIED' THEN RAISE EXCEPTION 'Deny did not set terminal denied status'; END IF;
  IF (SELECT public.read_project_bom_procurement_review((SELECT request_id FROM deny_submit)) -> 'lines' -> 0 -> 'analysis') <> 'null'::jsonb THEN RAISE EXCEPTION 'Deny incorrectly required or created analysis'; END IF;
  BEGIN PERFORM * FROM public.decide_project_bom_procurement_review((SELECT request_id FROM deny_submit),'8',(SELECT pinned_bom_updated_at FROM deny_submit_state),'[]'::jsonb,'DENY','Changed denial rationale','00000000-0000-4000-8000-000000000071'); RAISE EXCEPTION 'Changed deny replay accepted'; EXCEPTION WHEN OTHERS THEN IF SQLERRM NOT LIKE 'Request key conflicts%' THEN RAISE; END IF; END;
END $$;
RESET ROLE;
DO $$ BEGIN
  IF (SELECT count(*) FROM public.project_bom_procurement_review_audit_events WHERE request_id=(SELECT request_id FROM deny_submit) AND event_type='DENIED' AND actor_user_id='00000000-0000-4000-8000-000000000002' AND event_data->>'pinned_bom_revision'='8' AND event_data->>'decision_note'='No approved source satisfies the submitted requirement' AND event_data ? 'payload_hash') <> 1 THEN RAISE EXCEPTION 'Deny audit evidence was not exactly once or was incomplete'; END IF;
  IF (SELECT count(*) FROM public.project_bom_procurement_review_receipts WHERE request_key='00000000-0000-4000-8000-000000000071' AND action='DENY') <> 1 THEN RAISE EXCEPTION 'Deny replay created duplicate receipt'; END IF;
END $$;
SET ROLE procurement_requester_test;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',false);
CREATE TEMP TABLE stale_deny_submit AS
SELECT * FROM public.submit_project_bom_procurement_review('00000000-0000-4000-8000-000000000020','00000000-0000-4000-8000-000000000030','8','[{"kind":"new","mpn":"STALE-DENY","description":"Stale deny proposal","referenceDesignators":"D2","quantity":1}]'::jsonb,'00000000-0000-4000-8000-000000000072');
GRANT SELECT ON stale_deny_submit TO procurement_assigned_test;
CREATE TEMP TABLE stale_deny_submit_state AS
SELECT id, pinned_bom_updated_at FROM public.project_bom_procurement_review_requests WHERE id=(SELECT request_id FROM stale_deny_submit);
GRANT SELECT ON stale_deny_submit_state TO procurement_assigned_test;
RESET ROLE;
UPDATE public.project_boms SET revision='9' WHERE id='00000000-0000-4000-8000-000000000030';
SET ROLE procurement_assigned_test;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000002',false);
DO $$ BEGIN
  BEGIN PERFORM * FROM public.decide_project_bom_procurement_review((SELECT request_id FROM stale_deny_submit),'8',(SELECT pinned_bom_updated_at FROM stale_deny_submit_state),'[]'::jsonb,'DENY','Revision changed before decision','00000000-0000-4000-8000-000000000073'); RAISE EXCEPTION 'Stale deny accepted'; EXCEPTION WHEN OTHERS THEN IF SQLERRM NOT LIKE 'The project BOM source is stale%' THEN RAISE; END IF; END;
  IF (SELECT (public.read_project_bom_procurement_review((SELECT request_id FROM stale_deny_submit)) ->> 'status')) <> 'PENDING_PROCUREMENT_ANALYSIS' THEN RAISE EXCEPTION 'Stale deny mutated request state'; END IF;
END $$;
RESET ROLE;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM public.project_bom_procurement_review_audit_events WHERE request_id=(SELECT request_id FROM stale_deny_submit) AND event_type='DENIED') THEN RAISE EXCEPTION 'Stale deny wrote audit evidence'; END IF;
END $$;
ROLLBACK;
