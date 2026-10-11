-- LOCAL DISPOSABLE STAGED-FLOW ACCEPTANCE ONLY. Never run against an application database.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL request.jwt.claim.sub = '00000000-0000-4000-8000-000000000001';
SET LOCAL request.jwt.claim.role = 'authenticated';

DO $phase_a$
BEGIN
  IF to_regclass('public.sales_opportunity_structured_draft_materializations') IS NULL
     OR to_regprocedure('public.save_sales_opportunity_structured_draft_at_location(uuid,uuid,uuid,uuid,text,integer,jsonb,uuid,uuid)') IS NULL
     OR to_regprocedure('public.commit_sales_opportunity_structured_draft_materialization(uuid,uuid,uuid,uuid,text,text,text,text,bigint)') IS NULL THEN
    RAISE EXCEPTION 'LOCAL_STAGED_FLOW_FAIL phase A contracts missing';
  END IF;
  IF has_function_privilege('authenticated', 'public.save_sales_opportunity_structured_draft_at_location(uuid,uuid,uuid,uuid,text,integer,jsonb,uuid,uuid)', 'EXECUTE')
     OR has_function_privilege('authenticated', 'public.resolve_sales_opportunity_structured_draft_location(uuid,uuid,uuid)', 'EXECUTE')
     OR has_function_privilege('authenticated', 'public.register_sales_opportunity_structured_draft_storage_attempt(uuid,uuid,uuid,uuid,text,text,text,bigint)', 'EXECUTE')
     OR has_function_privilege('authenticated', 'public.commit_sales_opportunity_structured_draft_materialization(uuid,uuid,uuid,uuid,text,text,text,text,bigint)', 'EXECUTE')
     OR has_function_privilege('authenticated', 'public.can_discard_sales_opportunity_structured_draft_object(uuid,uuid,uuid,uuid,text,text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'LOCAL_STAGED_FLOW_FAIL phase A leaked authenticated execute';
  END IF;
END;
$phase_a$;

-- Phase B's administrative location write is represented only in this disposable fixture.
INSERT INTO public.drive_nodes(id,name,node_type,is_locked,is_trashed,department_id,project_id,parent_id,slug) VALUES
 ('00000000-0000-4000-8000-000000000610','Sales root','folder',true,false,'00000000-0000-4000-8000-000000000501',NULL,NULL,'sales-root'),
 ('00000000-0000-4000-8000-000000000611','Sales client folder','folder',true,false,'00000000-0000-4000-8000-000000000501',NULL,'00000000-0000-4000-8000-000000000610','sales-client');
INSERT INTO public.sales_opportunity_document_locations(id,opportunity_id,customer_id,department_id,drive_root_node_id,target_folder_node_id,private_storage_bucket,private_storage_prefix,location_purpose,authorized_by,authorized_at,created_by) VALUES
 ('00000000-0000-4000-8000-000000000710','00000000-0000-4000-8000-000000000201','00000000-0000-4000-8000-000000000101','00000000-0000-4000-8000-000000000501','00000000-0000-4000-8000-000000000610','00000000-0000-4000-8000-000000000611','project-drive','sales/opportunity/00000000-0000-4000-8000-000000000201/','STRUCTURED_DRAFT','00000000-0000-4000-8000-000000000001',now(),'00000000-0000-4000-8000-000000000001');
INSERT INTO public.sales_opportunity_structured_draft_private_locations(id,drive_folder_node_id,private_storage_bucket,private_storage_prefix,verified_private_at,verified_by,created_by) VALUES
 ('00000000-0000-4000-8000-000000000701','00000000-0000-4000-8000-000000000610','project-drive','sales/opportunity/00000000-0000-4000-8000-000000000201/',now(),'00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000001');

-- Phase C is bounded by this transaction: grants make transport executable only here and vanish on rollback.
GRANT EXECUTE ON FUNCTION public.save_sales_opportunity_structured_draft_at_location(uuid,uuid,uuid,uuid,text,integer,jsonb,uuid,uuid) TO authenticated;
CREATE TEMP TABLE saved AS SELECT * FROM public.save_sales_opportunity_structured_draft_at_location(
 '00000000-0000-4000-8000-000000000201','00000000-0000-4000-8000-000000000101',
 '00000000-0000-4000-8000-000000000301','00000000-0000-4000-8000-000000000401',
 'SOR',0,'{"SCOPE_STATEMENT":"Staged acceptance"}'::jsonb,
 '00000000-0000-4000-8000-000000000720','00000000-0000-4000-8000-000000000701');
DO $phase_c$
BEGIN
  IF (SELECT count(*) FROM saved) <> 1 OR (SELECT replayed FROM saved) THEN
    RAISE EXCEPTION 'LOCAL_STAGED_FLOW_FAIL rollback-only caller acceptance did not save';
  END IF;
  IF (SELECT count(*) FROM public.sales_opportunity_structured_draft_audit_events) <> 1
     OR (SELECT count(*) FROM public.sales_opportunity_structured_draft_revision_locations) <> 1 THEN
    RAISE EXCEPTION 'LOCAL_STAGED_FLOW_FAIL audit/location graph missing';
  END IF;
END;
$phase_c$;
ROLLBACK;

-- A fresh transaction proves the Phase C temporary grant and test graph did not persist.
BEGIN;
DO $rollback$
BEGIN
  IF has_function_privilege('authenticated', 'public.save_sales_opportunity_structured_draft_at_location(uuid,uuid,uuid,uuid,text,integer,jsonb,uuid,uuid)', 'EXECUTE')
     OR EXISTS (SELECT 1 FROM public.sales_opportunity_structured_draft_requests) THEN
    RAISE EXCEPTION 'LOCAL_STAGED_FLOW_FAIL phase C rollback leaked access or history';
  END IF;
END;
$rollback$;
ROLLBACK;
SELECT 'STRUCTURED_DRAFT_STAGED_FLOW_LOCAL_ACCEPTANCE_PASS' AS result;
