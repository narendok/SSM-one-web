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
INSERT INTO public.department_process_templates(id,department_id,template_key,version,status,active_document_revision_id) VALUES ('00000000-0000-4000-8000-000000000991','00000000-0000-4000-8000-000000000501','sales-sor-local',1,'ACTIVE','00000000-0000-4000-8000-000000000992');
INSERT INTO public.department_process_template_document_revisions(id,template_id) VALUES ('00000000-0000-4000-8000-000000000992','00000000-0000-4000-8000-000000000991');
INSERT INTO public.structured_lifecycle_docx_responsibility_assignments(id,scope_type,opportunity_id,customer_id,department_id,document_kind,responsible_employee_id,assigned_by,created_by) VALUES ('00000000-0000-4000-8000-000000000901','SALES_OPPORTUNITY','00000000-0000-4000-8000-000000000201','00000000-0000-4000-8000-000000000101','00000000-0000-4000-8000-000000000501','SOR','00000000-0000-4000-8000-000000000801','00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000001');
INSERT INTO public.sales_opportunity_structured_docx_assignments(id,opportunity_id,customer_id,document_kind,department_id,responsible_employee_id,registry_assignment_id,assigned_by,created_by) VALUES
 ('00000000-0000-4000-8000-000000000901','00000000-0000-4000-8000-000000000201','00000000-0000-4000-8000-000000000101','SOR','00000000-0000-4000-8000-000000000501','00000000-0000-4000-8000-000000000801','00000000-0000-4000-8000-000000000901','00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000001');
INSERT INTO public.structured_lifecycle_docx_template_pins(id,department_id,document_kind,template_id,template_document_revision_id,template_key,template_version,template_schema_hash,approved_by,request_key,payload_hash,created_by) VALUES ('00000000-0000-4000-8000-000000000994','00000000-0000-4000-8000-000000000501','SOR','00000000-0000-4000-8000-000000000991','00000000-0000-4000-8000-000000000992','sales-sor-local',1,'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb','00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000995','cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc','00000000-0000-4000-8000-000000000001');
DO $scope_discriminator$
DECLARE v_project_assignment uuid := '00000000-0000-4000-8000-000000000906';
BEGIN
  -- The pre-handover Sales SOR assignment is deliberately valid without any project row.
  IF NOT EXISTS (
    SELECT 1 FROM public.resolve_structured_lifecycle_docx_registry_scope(
      '00000000-0000-4000-8000-000000000201','00000000-0000-4000-8000-000000000101','SOR',
      '00000000-0000-4000-8000-000000000901','00000000-0000-4000-8000-000000000902','sales-sor-local',1,
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
    )
  ) THEN RAISE EXCEPTION 'LOCAL_DOCX_FAIL pre-handover Sales scope did not resolve without a project'; END IF;
  BEGIN
    PERFORM public.resolve_structured_lifecycle_docx_registry_scope(
      '00000000-0000-4000-8000-000000000202','00000000-0000-4000-8000-000000000102','SOR',
      '00000000-0000-4000-8000-000000000901','00000000-0000-4000-8000-000000000902','sales-sor-local',1,
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
    ); RAISE EXCEPTION 'LOCAL_DOCX_FAIL other opportunity/customer resolved Sales responsibility';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'Current assigned-person DOCX authority is unavailable' THEN RAISE; END IF; END;
  INSERT INTO public.projects(id,status) VALUES ('00000000-0000-4000-8000-000000000211','active');
  INSERT INTO public.project_team_members(project_id,employee_id) VALUES ('00000000-0000-4000-8000-000000000211','00000000-0000-4000-8000-000000000801');
  INSERT INTO public.customer_requirements(id,opportunity_id,customer_id) VALUES ('00000000-0000-4000-8000-000000000821','00000000-0000-4000-8000-000000000201','00000000-0000-4000-8000-000000000101');
  INSERT INTO public.requirement_baselines(id,requirement_id) VALUES ('00000000-0000-4000-8000-000000000822','00000000-0000-4000-8000-000000000821');
  INSERT INTO public.sales_project_handovers(id,baseline_id,project_id,status) VALUES ('00000000-0000-4000-8000-000000000823','00000000-0000-4000-8000-000000000822','00000000-0000-4000-8000-000000000211','completed');
  INSERT INTO public.structured_lifecycle_docx_responsibility_assignments(id,scope_type,project_id,department_id,document_kind,responsible_employee_id,assigned_by,created_by)
  VALUES(v_project_assignment,'PROJECT','00000000-0000-4000-8000-000000000211','00000000-0000-4000-8000-000000000501','SOR','00000000-0000-4000-8000-000000000801','00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000001');
  IF NOT EXISTS (
    SELECT 1 FROM public.resolve_structured_lifecycle_docx_registry_scope(
      '00000000-0000-4000-8000-000000000201','00000000-0000-4000-8000-000000000101','SOR',v_project_assignment,
      '00000000-0000-4000-8000-000000000902','sales-sor-local',1,
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
    )
  ) THEN RAISE EXCEPTION 'LOCAL_DOCX_FAIL post-handover project scope did not resolve'; END IF;
END;
$scope_discriminator$;
CREATE TEMP TABLE requested AS SELECT * FROM public.request_sales_structured_docx_materialization(
 '00000000-0000-4000-8000-000000000201','00000000-0000-4000-8000-000000000101','00000000-0000-4000-8000-000000000720','00000000-0000-4000-8000-000000000901','sales-sor-local',1,'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb','00000000-0000-4000-8000-000000000902');
CREATE TEMP TABLE authorized_upload AS SELECT * FROM public.authorize_sales_structured_docx_upload(
 '00000000-0000-4000-8000-000000000201','00000000-0000-4000-8000-000000000101','00000000-0000-4000-8000-000000000901','00000000-0000-4000-8000-000000000902','application/vnd.openxmlformats-officedocument.wordprocessingml.document',512);
DO $upload_authority$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM authorized_upload a JOIN requested r USING (request_key) WHERE a.storage_bucket=r.storage_bucket AND a.storage_path=r.storage_path AND a.max_size_bytes=10485760 AND NOT a.replayed) THEN
    RAISE EXCEPTION 'LOCAL_DOCX_FAIL exact protected upload authority missing';
  END IF;
  BEGIN
    PERFORM public.authorize_sales_structured_docx_upload('00000000-0000-4000-8000-000000000201','00000000-0000-4000-8000-000000000101','00000000-0000-4000-8000-000000000901','00000000-0000-4000-8000-000000000902','text/html',512);
    RAISE EXCEPTION 'LOCAL_DOCX_FAIL non-DOCX upload accepted';
  EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'Invalid protected DOCX upload request' THEN RAISE; END IF; END;
END;
$upload_authority$;
-- Exercise real authenticated Storage RLS beside a representative broad
-- permissive project-drive policy. Restrictive DOCX policies must dominate.
CREATE POLICY legacy_project_drive_permissive ON storage.objects FOR ALL TO authenticated
USING (bucket_id = 'project-drive') WITH CHECK (bucket_id = 'project-drive');
GRANT SELECT, INSERT, UPDATE, DELETE ON public.drive_nodes, public.drive_node_revisions, public.document_control_registers TO authenticated;
CREATE POLICY legacy_drive_nodes_permissive ON public.drive_nodes FOR SELECT TO authenticated USING (true);
CREATE POLICY legacy_drive_revisions_permissive ON public.drive_node_revisions FOR SELECT TO authenticated USING (true);
CREATE POLICY legacy_registers_permissive ON public.document_control_registers FOR SELECT TO authenticated USING (true);
CREATE TEMP TABLE docx_storage_path AS SELECT storage_path FROM requested;
GRANT SELECT ON docx_storage_path TO authenticated;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',false);
DO $storage_policy$
DECLARE v_path text := (SELECT storage_path FROM docx_storage_path);
BEGIN
  INSERT INTO storage.objects(bucket_id,name,version,metadata) VALUES ('project-drive',v_path,'fixture-v1','{"mimetype":"application/vnd.openxmlformats-officedocument.wordprocessingml.document","size":512}'::jsonb);
  BEGIN INSERT INTO storage.objects(bucket_id,name,version) VALUES ('project-drive',v_path,'fixture-v2'); RAISE EXCEPTION 'LOCAL_DOCX_FAIL replacement accepted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  UPDATE storage.objects SET version='fixture-v2' WHERE bucket_id='project-drive' AND name=v_path;
  IF FOUND THEN RAISE EXCEPTION 'LOCAL_DOCX_FAIL update accepted'; END IF;
  DELETE FROM storage.objects WHERE bucket_id='project-drive' AND name=v_path;
  IF FOUND THEN RAISE EXCEPTION 'LOCAL_DOCX_FAIL delete accepted'; END IF;
END;
$storage_policy$;
RESET ROLE;
SELECT set_config('request.jwt.claim.sub', NULL, true);
SELECT public.assert_sales_structured_docx_uploaded_object('00000000-0000-4000-8000-000000000902','project-drive',(SELECT storage_path FROM docx_storage_path),'fixture-v1');
DO $stale_object$
BEGIN
  BEGIN PERFORM public.assert_sales_structured_docx_uploaded_object('00000000-0000-4000-8000-000000000902','project-drive',(SELECT storage_path FROM docx_storage_path),'fixture-stale'); RAISE EXCEPTION 'LOCAL_DOCX_FAIL stale object accepted'; EXCEPTION WHEN OTHERS THEN IF SQLERRM NOT LIKE 'Uploaded DOCX object version is absent or replaced%' THEN RAISE; END IF; END;
END;
$stale_object$;
SELECT set_config('request.jwt.claim.sub', NULL, true);
SELECT public.record_sales_structured_docx_object_verification('00000000-0000-4000-8000-000000000902','project-drive',(SELECT storage_path FROM docx_storage_path),'fixture-v1','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',512,true,true,false,'local-ooxml-verifier');
CREATE TEMP TABLE docx_receipt AS SELECT public.issue_sales_structured_docx_trusted_receipt(
 '00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000902','00000000-0000-4000-8000-000000000901',
 'project-drive',(SELECT storage_path FROM docx_storage_path),'fixture-v1','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',512,
 (SELECT source_fingerprint FROM public.sales_opportunity_structured_docx_requests WHERE request_key='00000000-0000-4000-8000-000000000902'),
 'sales-sor-local',1,'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb','local-ooxml-verifier') AS receipt_id;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',false);
SELECT public.assert_sales_structured_docx_current_path_create_only('00000000-0000-4000-8000-000000000902','project-drive',(SELECT storage_path FROM docx_storage_path),'fixture-v1');
RESET ROLE;
SET LOCAL request.jwt.claim.sub = '00000000-0000-4000-8000-000000000001';
CREATE TEMP TABLE committed AS SELECT * FROM public.commit_sales_structured_docx_materialization('00000000-0000-4000-8000-000000000201','00000000-0000-4000-8000-000000000101','00000000-0000-4000-8000-000000000901','00000000-0000-4000-8000-000000000902','sor-draft.docx','project-drive',(SELECT storage_path FROM requested),'fixture-v1','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',512,(SELECT receipt_id FROM docx_receipt));
DO $assert$
DECLARE v_before integer;
BEGIN
 IF (SELECT count(*) FROM committed) <> 1 OR (SELECT replayed FROM committed) OR (SELECT count(*) FROM public.sales_opportunity_structured_docx_audit_events) <> 1 THEN RAISE EXCEPTION 'LOCAL_DOCX_FAIL initial immutable graph missing'; END IF;
 IF NOT EXISTS (SELECT 1 FROM public.drive_nodes WHERE mime_type='application/vnd.openxmlformats-officedocument.wordprocessingml.document') THEN RAISE EXCEPTION 'LOCAL_DOCX_FAIL OOXML MIME missing'; END IF;
 PERFORM public.commit_sales_structured_docx_materialization('00000000-0000-4000-8000-000000000201','00000000-0000-4000-8000-000000000101','00000000-0000-4000-8000-000000000901','00000000-0000-4000-8000-000000000902','sor-draft.docx','project-drive',(SELECT storage_path FROM requested),'fixture-v1','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',512,(SELECT receipt_id FROM docx_receipt));
 IF (SELECT count(*) FROM public.sales_opportunity_structured_docx_materializations) <> 1 THEN RAISE EXCEPTION 'LOCAL_DOCX_FAIL replay duplicated materialization'; END IF;
 SELECT count(*) INTO v_before FROM public.sales_opportunity_structured_docx_materializations;
 BEGIN
  PERFORM public.commit_sales_structured_docx_materialization('00000000-0000-4000-8000-000000000201','00000000-0000-4000-8000-000000000101','00000000-0000-4000-8000-000000000901','00000000-0000-4000-8000-000000000902','changed.docx','project-drive',(SELECT storage_path FROM requested),'fixture-v1','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',512,(SELECT receipt_id FROM docx_receipt));
  RAISE EXCEPTION 'LOCAL_DOCX_FAIL changed replay accepted';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'DOCX request key conflicts with a different materialization payload' THEN RAISE; END IF; END;
 IF (SELECT count(*) FROM public.sales_opportunity_structured_docx_materializations) <> v_before THEN RAISE EXCEPTION 'LOCAL_DOCX_FAIL conflict changed graph'; END IF;
 SET LOCAL request.jwt.claim.sub = '00000000-0000-4000-8000-000000000002';
 SET ROLE authenticated;
 PERFORM set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000002',false);
 IF EXISTS (SELECT 1 FROM storage.objects WHERE bucket_id='project-drive' AND name=(SELECT storage_path FROM docx_storage_path)) THEN
   RAISE EXCEPTION 'LOCAL_DOCX_FAIL unassigned actor read the DOCX object past restrictive policy';
 END IF;
 RESET ROLE;
 SET LOCAL request.jwt.claim.sub = '00000000-0000-4000-8000-000000000002';
 BEGIN
  PERFORM public.read_sales_structured_docx_materializations('00000000-0000-4000-8000-000000000201','00000000-0000-4000-8000-000000000101','00000000-0000-4000-8000-000000000901');
  RAISE EXCEPTION 'LOCAL_DOCX_FAIL unassigned reader accepted';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM <> 'The current actor is not the assigned active responsible person' THEN RAISE; END IF; END;
 SET LOCAL request.jwt.claim.sub = '00000000-0000-4000-8000-000000000001';
 PERFORM public.authorize_sales_structured_docx_upload('00000000-0000-4000-8000-000000000201','00000000-0000-4000-8000-000000000101','00000000-0000-4000-8000-000000000901','00000000-0000-4000-8000-000000000902','application/vnd.openxmlformats-officedocument.wordprocessingml.document',512);
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
