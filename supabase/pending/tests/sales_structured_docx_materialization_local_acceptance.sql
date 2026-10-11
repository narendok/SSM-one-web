-- LOCAL DISPOSABLE ACCEPTANCE ONLY. No application record or storage object is changed.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL request.jwt.claim.sub = '00000000-0000-4000-8000-000000000001';
SET LOCAL request.jwt.claim.role = 'authenticated';

INSERT INTO public.drive_nodes(id,name,node_type,is_locked,is_trashed,department_id,project_id,parent_id,slug) VALUES
 ('00000000-0000-4000-8000-000000000610','Sales root','folder',true,false,'00000000-0000-4000-8000-000000000501',NULL,NULL,'sales-root'),
 ('00000000-0000-4000-8000-000000000611','Opportunity folder','folder',true,false,'00000000-0000-4000-8000-000000000501',NULL,'00000000-0000-4000-8000-000000000610','opportunity');
INSERT INTO public.sales_opportunity_document_locations(id,opportunity_id,customer_id,department_id,drive_root_node_id,target_folder_node_id,private_storage_bucket,private_storage_prefix,location_purpose,authorized_by,authorized_at,created_by) VALUES
 ('00000000-0000-4000-8000-000000000710','00000000-0000-4000-8000-000000000201','00000000-0000-4000-8000-000000000101','00000000-0000-4000-8000-000000000501','00000000-0000-4000-8000-000000000610','00000000-0000-4000-8000-000000000611','project-drive','sales/opportunity/00000000-0000-4000-8000-000000000201/','STRUCTURED_DRAFT','00000000-0000-4000-8000-000000000001',now(),'00000000-0000-4000-8000-000000000001');
INSERT INTO public.sales_opportunity_structured_draft_private_locations(id,drive_folder_node_id,private_storage_bucket,private_storage_prefix,verified_private_at,verified_by,created_by) VALUES
 ('00000000-0000-4000-8000-000000000701','00000000-0000-4000-8000-000000000610','project-drive','sales/opportunity/00000000-0000-4000-8000-000000000201/',now(),'00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000001');
CREATE TEMP TABLE saved AS SELECT * FROM public.save_sales_opportunity_structured_draft_at_location(
 '00000000-0000-4000-8000-000000000201','00000000-0000-4000-8000-000000000101','00000000-0000-4000-8000-000000000301','00000000-0000-4000-8000-000000000401','SOR',0,'{"SCOPE_STATEMENT":"DOCX scope"}'::jsonb,'00000000-0000-4000-8000-000000000720','00000000-0000-4000-8000-000000000701');
INSERT INTO public.sales_opportunity_structured_docx_assignments(id,opportunity_id,customer_id,document_kind,department_id,responsible_employee_id,assigned_by,created_by) VALUES
 ('00000000-0000-4000-8000-000000000901','00000000-0000-4000-8000-000000000201','00000000-0000-4000-8000-000000000101','SOR','00000000-0000-4000-8000-000000000501','00000000-0000-4000-8000-000000000801','00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000001');
CREATE TEMP TABLE requested AS SELECT * FROM public.request_sales_structured_docx_materialization(
 '00000000-0000-4000-8000-000000000201','00000000-0000-4000-8000-000000000101','00000000-0000-4000-8000-000000000720','00000000-0000-4000-8000-000000000901','sales-sor-local',1,'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb','00000000-0000-4000-8000-000000000902');
UPDATE public.master_specifications SET current_version_id='00000000-0000-4000-8000-000000000401' WHERE id='00000000-0000-4000-8000-000000000301';
SELECT public.record_sales_structured_docx_object_verification('00000000-0000-4000-8000-000000000902','project-drive',(SELECT storage_path FROM requested),'fixture-v1','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',512,true,true,false,'local-ooxml-verifier');
CREATE TEMP TABLE committed AS SELECT * FROM public.commit_sales_structured_docx_materialization('00000000-0000-4000-8000-000000000201','00000000-0000-4000-8000-000000000101','00000000-0000-4000-8000-000000000901','00000000-0000-4000-8000-000000000902','sor-draft.docx','project-drive',(SELECT storage_path FROM requested),'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',512);
DO $assert$
DECLARE v_before integer;
BEGIN
 IF (SELECT count(*) FROM committed) <> 1 OR (SELECT replayed FROM committed) OR (SELECT count(*) FROM public.sales_opportunity_structured_docx_audit_events) <> 1 THEN RAISE EXCEPTION 'LOCAL_DOCX_FAIL initial immutable graph missing'; END IF;
 IF NOT EXISTS (SELECT 1 FROM public.drive_nodes WHERE mime_type='application/vnd.openxmlformats-officedocument.wordprocessingml.document') THEN RAISE EXCEPTION 'LOCAL_DOCX_FAIL OOXML MIME missing'; END IF;
 PERFORM public.commit_sales_structured_docx_materialization('00000000-0000-4000-8000-000000000201','00000000-0000-4000-8000-000000000101','00000000-0000-4000-8000-000000000901','00000000-0000-4000-8000-000000000902','sor-draft.docx','project-drive',(SELECT storage_path FROM requested),'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',512);
 IF (SELECT count(*) FROM public.sales_opportunity_structured_docx_materializations) <> 1 THEN RAISE EXCEPTION 'LOCAL_DOCX_FAIL replay duplicated materialization'; END IF;
 SELECT count(*) INTO v_before FROM public.sales_opportunity_structured_docx_materializations;
 BEGIN
  PERFORM public.commit_sales_structured_docx_materialization('00000000-0000-4000-8000-000000000201','00000000-0000-4000-8000-000000000101','00000000-0000-4000-8000-000000000901','00000000-0000-4000-8000-000000000902','changed.docx','project-drive',(SELECT storage_path FROM requested),'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',512);
  RAISE EXCEPTION 'LOCAL_DOCX_FAIL changed replay accepted';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'DOCX request key conflicts with a different materialization payload' THEN RAISE; END IF; END;
 IF (SELECT count(*) FROM public.sales_opportunity_structured_docx_materializations) <> v_before THEN RAISE EXCEPTION 'LOCAL_DOCX_FAIL conflict changed graph'; END IF;
 SET LOCAL request.jwt.claim.sub = '00000000-0000-4000-8000-000000000002';
 BEGIN
  PERFORM public.read_sales_structured_docx_materializations('00000000-0000-4000-8000-000000000201','00000000-0000-4000-8000-000000000101','00000000-0000-4000-8000-000000000901');
  RAISE EXCEPTION 'LOCAL_DOCX_FAIL unassigned reader accepted';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'The current actor is not the assigned active responsible person' THEN RAISE; END IF; END;
 SET LOCAL request.jwt.claim.sub = '00000000-0000-4000-8000-000000000001';
 BEGIN
  PERFORM public.request_sales_structured_docx_materialization('00000000-0000-4000-8000-000000000202','00000000-0000-4000-8000-000000000102','00000000-0000-4000-8000-000000000720','00000000-0000-4000-8000-000000000901','sales-sor-local',1,'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb','00000000-0000-4000-8000-000000000903');
  RAISE EXCEPTION 'LOCAL_DOCX_FAIL cross-department/source accepted';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'Pinned structured Sales revision is not owned by this actor and source' THEN RAISE; END IF; END;
 UPDATE public.sales_opportunity_structured_docx_assignments SET status='REVOKED', revoked_by='00000000-0000-4000-8000-000000000001', revoked_at=now() WHERE id='00000000-0000-4000-8000-000000000901';
 BEGIN
  PERFORM public.read_sales_structured_docx_materializations('00000000-0000-4000-8000-000000000201','00000000-0000-4000-8000-000000000101','00000000-0000-4000-8000-000000000901');
  RAISE EXCEPTION 'LOCAL_DOCX_FAIL revoked assignment accepted';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'The current assigned-person DOCX authority is unavailable' THEN RAISE; END IF; END;
END;
$assert$;
SELECT 'SALES_STRUCTURED_DOCX_LOCAL_ACCEPTANCE_PASS' AS result;
ROLLBACK;
