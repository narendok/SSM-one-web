-- LOCAL DISPOSABLE ACCEPTANCE ONLY. No external object bytes are uploaded.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL request.jwt.claim.sub = '00000000-0000-4000-8000-000000000001';
SET LOCAL request.jwt.claim.role = 'authenticated';
INSERT INTO public.drive_nodes(id,name,node_type,is_locked,is_trashed,department_id,project_id,parent_id,slug) VALUES
 ('00000000-0000-4000-8000-000000000610','Sales root','FOLDER',true,false,'00000000-0000-4000-8000-000000000501',NULL,NULL,'sales-root'),
 ('00000000-0000-4000-8000-000000000611','Opportunity folder','FOLDER',true,false,'00000000-0000-4000-8000-000000000501',NULL,'00000000-0000-4000-8000-000000000610','opportunity');
INSERT INTO public.sales_opportunity_document_locations(id,opportunity_id,customer_id,department_id,drive_root_node_id,target_folder_node_id,private_storage_bucket,private_storage_prefix,location_purpose,authorized_by,authorized_at,created_by) VALUES
 ('00000000-0000-4000-8000-000000000710','00000000-0000-4000-8000-000000000201','00000000-0000-4000-8000-000000000101','00000000-0000-4000-8000-000000000501','00000000-0000-4000-8000-000000000610','00000000-0000-4000-8000-000000000611','project-drive','sales/opportunity/00000000-0000-4000-8000-000000000201/','STRUCTURED_DRAFT', '00000000-0000-4000-8000-000000000001',now(),'00000000-0000-4000-8000-000000000001');
INSERT INTO public.sales_opportunity_structured_draft_private_locations(id,drive_folder_node_id,private_storage_bucket,private_storage_prefix,verified_private_at,verified_by,created_by) VALUES ('00000000-0000-4000-8000-000000000701','00000000-0000-4000-8000-000000000610','project-drive','sales/opportunity/00000000-0000-4000-8000-000000000201/',now(),'00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000001');
CREATE TEMP TABLE saved AS SELECT * FROM public.save_sales_opportunity_structured_draft_at_location('00000000-0000-4000-8000-000000000201','00000000-0000-4000-8000-000000000101','00000000-0000-4000-8000-000000000301','00000000-0000-4000-8000-000000000401','SOR',0,'{"SCOPE_STATEMENT":"Materialized scope"}'::jsonb,'00000000-0000-4000-8000-000000000720','00000000-0000-4000-8000-000000000701');
INSERT INTO storage.objects(bucket_id,name) VALUES ('project-drive','sales/opportunity/00000000-0000-4000-8000-000000000201/00000000-0000-4000-8000-000000000720-draft.html');
SELECT public.register_sales_opportunity_structured_draft_storage_attempt('00000000-0000-4000-8000-000000000201','00000000-0000-4000-8000-000000000101','00000000-0000-4000-8000-000000000710','00000000-0000-4000-8000-000000000720','project-drive','sales/opportunity/00000000-0000-4000-8000-000000000201/00000000-0000-4000-8000-000000000720-draft.html','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',42);
CREATE TEMP TABLE materialized AS SELECT * FROM public.commit_sales_opportunity_structured_draft_materialization('00000000-0000-4000-8000-000000000201','00000000-0000-4000-8000-000000000101','00000000-0000-4000-8000-000000000710','00000000-0000-4000-8000-000000000720','SOR-draft.html','project-drive','sales/opportunity/00000000-0000-4000-8000-000000000201/00000000-0000-4000-8000-000000000720-draft.html','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',42);
DO $assert$
DECLARE v_before integer;
BEGIN
 IF (SELECT count(*) FROM materialized) <> 1 OR (SELECT replayed FROM materialized) THEN RAISE EXCEPTION 'LOCAL_MATERIALIZATION_FAIL first materialization missing'; END IF;
 IF (SELECT count(*) FROM public.sales_opportunity_structured_draft_materializations) <> 1 OR (SELECT count(*) FROM public.sales_opportunity_structured_draft_materialization_audits) <> 1 OR NOT EXISTS (SELECT 1 FROM public.sales_opportunity_structured_draft_storage_attempts WHERE consumed_at IS NOT NULL) THEN RAISE EXCEPTION 'LOCAL_MATERIALIZATION_FAIL receipt/audit/consumption missing'; END IF;
 PERFORM public.commit_sales_opportunity_structured_draft_materialization('00000000-0000-4000-8000-000000000201','00000000-0000-4000-8000-000000000101','00000000-0000-4000-8000-000000000710','00000000-0000-4000-8000-000000000720','SOR-draft.html','project-drive','sales/opportunity/00000000-0000-4000-8000-000000000201/00000000-0000-4000-8000-000000000720-draft.html','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',42);
 IF (SELECT count(*) FROM public.sales_opportunity_structured_draft_materializations) <> 1 THEN RAISE EXCEPTION 'LOCAL_MATERIALIZATION_FAIL exact replay duplicated receipt'; END IF;
 SELECT count(*) INTO v_before FROM public.sales_opportunity_structured_draft_materializations;
 BEGIN
  PERFORM public.commit_sales_opportunity_structured_draft_materialization('00000000-0000-4000-8000-000000000201','00000000-0000-4000-8000-000000000101','00000000-0000-4000-8000-000000000710','00000000-0000-4000-8000-000000000720','changed.html','project-drive','sales/opportunity/00000000-0000-4000-8000-000000000201/00000000-0000-4000-8000-000000000720-draft.html','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',42);
  RAISE EXCEPTION 'LOCAL_MATERIALIZATION_FAIL changed replay accepted';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'Request key conflicts with a different Sales draft materialization payload' THEN RAISE; END IF; END;
 IF (SELECT count(*) FROM public.sales_opportunity_structured_draft_materializations) <> v_before THEN RAISE EXCEPTION 'LOCAL_MATERIALIZATION_FAIL mismatch changed graph'; END IF;
 BEGIN
  PERFORM public.resolve_sales_opportunity_structured_draft_location('00000000-0000-4000-8000-000000000202','00000000-0000-4000-8000-000000000102','00000000-0000-4000-8000-000000000710');
  RAISE EXCEPTION 'LOCAL_MATERIALIZATION_FAIL cross-opportunity location accepted';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'The requested Sales document location is unavailable' THEN RAISE; END IF; END;
 BEGIN
  UPDATE public.sales_opportunity_structured_draft_materializations SET size_bytes=0;
  RAISE EXCEPTION 'LOCAL_MATERIALIZATION_FAIL immutable history changed';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'Structured Sales materialization history is append-only' THEN RAISE; END IF; END;
END $assert$;
SELECT 'STRUCTURED_DRAFT_MATERIALIZATION_LOCAL_ACCEPTANCE_PASS' AS result;
ROLLBACK;
