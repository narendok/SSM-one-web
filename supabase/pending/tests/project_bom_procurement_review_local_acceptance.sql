\set ON_ERROR_STOP on
BEGIN;
INSERT INTO public.employees VALUES
 ('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000001','ACTIVE'),
 ('00000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-000000000002','ACTIVE'),
 ('00000000-0000-4000-8000-000000000003','00000000-0000-4000-8000-000000000003','ACTIVE');
INSERT INTO public.departments VALUES ('00000000-0000-4000-8000-000000000010','PURCHASE',true);
INSERT INTO public.employee_departments VALUES ('00000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-000000000010');
INSERT INTO public.projects VALUES ('00000000-0000-4000-8000-000000000020','00000000-0000-4000-8000-000000000001');
INSERT INTO public.project_team_members VALUES
 ('00000000-0000-4000-8000-000000000020','00000000-0000-4000-8000-000000000001'),
 ('00000000-0000-4000-8000-000000000020','00000000-0000-4000-8000-000000000002');
INSERT INTO public.project_boms(id,project_id,bom_number,revision) VALUES ('00000000-0000-4000-8000-000000000030','00000000-0000-4000-8000-000000000020','BOM-LOCAL-1','7');
INSERT INTO public.project_bom_items VALUES ('00000000-0000-4000-8000-000000000031','00000000-0000-4000-8000-000000000030',1);
INSERT INTO public.components VALUES ('00000000-0000-4000-8000-000000000040','CAT-001','Catalog Inc','Authoritative component');
INSERT INTO public.permission_test_grants VALUES
 ('00000000-0000-4000-8000-000000000001','projects.manage'),
 ('00000000-0000-4000-8000-000000000002','procurement.edit');
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
END $$;
CREATE TEMP TABLE first_submit AS
SELECT * FROM public.submit_project_bom_procurement_review('00000000-0000-4000-8000-000000000020','00000000-0000-4000-8000-000000000030','7','[
 {"kind":"existing","sourceBomItemId":"00000000-0000-4000-8000-000000000031","componentId":"00000000-0000-4000-8000-000000000040","referenceDesignators":"R1","quantity":2,"manualNote":"keep manual note"},
 {"kind":"new","mpn":"NEW-007","manufacturer":"Proposal Ltd","description":"Uncreated proposed part","referenceDesignators":"U1","quantity":1}
]'::jsonb,'00000000-0000-4000-8000-000000000060');
DO $$ BEGIN
 IF (SELECT count(*) FROM first_submit)<>1 OR (SELECT replayed FROM first_submit) THEN RAISE EXCEPTION 'First submission failed'; END IF;
 IF (SELECT count(*) FROM public.project_bom_procurement_review_requests)<>1 OR (SELECT count(*) FROM public.project_bom_procurement_review_request_lines)<>2 OR (SELECT count(*) FROM public.project_bom_procurement_review_audit_events)<>1 OR (SELECT count(*) FROM public.project_bom_procurement_review_receipts)<>1 THEN RAISE EXCEPTION 'Submission did not atomically persist snapshot, audit, and receipt'; END IF;
 IF (SELECT authoritative_mpn FROM public.project_bom_procurement_review_request_lines WHERE source_kind='EXISTING_COMPONENT') <> 'CAT-001' THEN RAISE EXCEPTION 'Existing component MPN was not server-derived'; END IF;
 IF (SELECT count(*) FROM public.components)<>1 OR (SELECT count(*) FROM public.project_bom_items)<>1 THEN RAISE EXCEPTION 'Submission changed component or BOM state'; END IF;
END $$;
CREATE TEMP TABLE exact_replay AS SELECT * FROM public.submit_project_bom_procurement_review('00000000-0000-4000-8000-000000000020','00000000-0000-4000-8000-000000000030','7','[{"quantity":2,"referenceDesignators":"R1","componentId":"00000000-0000-4000-8000-000000000040","sourceBomItemId":"00000000-0000-4000-8000-000000000031","kind":"existing","manualNote":"keep manual note"},{"quantity":1,"referenceDesignators":"U1","description":"Uncreated proposed part","manufacturer":"Proposal Ltd","mpn":"NEW-007","kind":"new"}]'::jsonb,'00000000-0000-4000-8000-000000000060');
DO $$ BEGIN
 IF NOT (SELECT replayed FROM exact_replay) OR (SELECT request_id FROM exact_replay)<>(SELECT request_id FROM first_submit) THEN RAISE EXCEPTION 'Exact replay mismatch'; END IF;
 BEGIN PERFORM * FROM public.submit_project_bom_procurement_review('00000000-0000-4000-8000-000000000020','00000000-0000-4000-8000-000000000030','7','[{"kind":"new","mpn":"CHANGED","description":"Changed","referenceDesignators":"U1","quantity":1}]'::jsonb,'00000000-0000-4000-8000-000000000060'); RAISE EXCEPTION 'Changed replay accepted'; EXCEPTION WHEN OTHERS THEN IF SQLERRM NOT LIKE 'Request key conflicts%' THEN RAISE; END IF; END;
END $$;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000002',false);
DO $$ DECLARE v_request uuid:=(SELECT request_id FROM first_submit); v_existing_line uuid; v_new_line uuid; BEGIN
 SELECT id INTO v_existing_line FROM public.project_bom_procurement_review_request_lines WHERE request_id=v_request AND source_kind='EXISTING_COMPONENT';
 SELECT id INTO v_new_line FROM public.project_bom_procurement_review_request_lines WHERE request_id=v_request AND source_kind='NEW_PART';
 BEGIN PERFORM * FROM public.decide_project_bom_procurement_review(v_request,'7','ALLOW','all rows reviewed','00000000-0000-4000-8000-000000000061'); RAISE EXCEPTION 'Allow without analysis accepted'; EXCEPTION WHEN OTHERS THEN IF SQLERRM NOT LIKE 'Allow requires an analysis%' THEN RAISE; END IF; END;
 PERFORM * FROM public.analyze_project_bom_procurement_review(v_request,v_existing_line,'{"availabilityState":"AVAILABLE","costState":"TBC","sourcingState":"PENDING","analysisNote":"Supplier response pending"}'::jsonb,'00000000-0000-4000-8000-000000000062');
 PERFORM * FROM public.analyze_project_bom_procurement_review(v_request,v_new_line,'{"availabilityState":"TBC","costState":"TBC","sourcingState":"UNAVAILABLE","analysisNote":"No verified source yet"}'::jsonb,'00000000-0000-4000-8000-000000000063');
 PERFORM * FROM public.decide_project_bom_procurement_review(v_request,'7','ALLOW','analysis complete; Hardware selection remains separate','00000000-0000-4000-8000-000000000061');
 IF (SELECT status FROM public.project_bom_procurement_review_requests WHERE id=v_request) <> 'ALLOWED_PENDING_HARDWARE_SELECTION' THEN RAISE EXCEPTION 'Allow did not remain handoff-only'; END IF;
END $$;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000003',false);
DO $$ BEGIN
 BEGIN PERFORM * FROM public.analyze_project_bom_procurement_review((SELECT request_id FROM first_submit),(SELECT id FROM public.project_bom_procurement_review_request_lines LIMIT 1),'{"availabilityState":"TBC","costState":"TBC","sourcingState":"TBC","analysisNote":"unauthorized"}'::jsonb,'00000000-0000-4000-8000-000000000064'); RAISE EXCEPTION 'Unauthorized analyst accepted'; EXCEPTION WHEN OTHERS THEN IF SQLERRM NOT LIKE 'Procurement analysis requires procurement.edit%' THEN RAISE; END IF; END;
END $$;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',false);
DO $$ BEGIN
 UPDATE public.project_boms SET revision='8' WHERE id='00000000-0000-4000-8000-000000000030';
 BEGIN PERFORM * FROM public.submit_project_bom_procurement_review('00000000-0000-4000-8000-000000000020','00000000-0000-4000-8000-000000000030','7','[{"kind":"new","mpn":"STALE","description":"Stale","referenceDesignators":"R2","quantity":1}]'::jsonb,'00000000-0000-4000-8000-000000000065'); RAISE EXCEPTION 'Stale BOM submission accepted'; EXCEPTION WHEN OTHERS THEN IF SQLERRM NOT LIKE 'The project BOM revision is stale%' THEN RAISE; END IF; END;
END $$;
ROLLBACK;
