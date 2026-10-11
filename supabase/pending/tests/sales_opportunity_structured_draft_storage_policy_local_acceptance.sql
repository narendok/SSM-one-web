-- LOCAL DISPOSABLE POLICY ACCEPTANCE ONLY. It models all eight pre-existing
-- permissive project-drive policies, then proves the reviewed replacement.
\set ON_ERROR_STOP on
BEGIN;

CREATE POLICY project_drive_read ON storage.objects FOR SELECT TO authenticated USING (bucket_id = 'project-drive');
CREATE POLICY project_drive_insert ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'project-drive');
CREATE POLICY project_drive_update ON storage.objects FOR UPDATE TO authenticated USING (bucket_id = 'project-drive') WITH CHECK (bucket_id = 'project-drive');
CREATE POLICY project_drive_delete ON storage.objects FOR DELETE TO authenticated USING (bucket_id = 'project-drive');
CREATE POLICY "Project teams read project files" ON storage.objects FOR SELECT TO authenticated USING (bucket_id = 'project-drive' AND public.has_any_permission(auth.uid(), ARRAY['projects.view', 'projects.manage', 'engineering.view', 'engineering.manage']));
CREATE POLICY "Project managers upload project files" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'project-drive' AND public.has_any_permission(auth.uid(), ARRAY['projects.manage', 'engineering.manage']));
CREATE POLICY "Project managers update project files" ON storage.objects FOR UPDATE TO authenticated USING (bucket_id = 'project-drive' AND public.has_any_permission(auth.uid(), ARRAY['projects.manage', 'engineering.manage'])) WITH CHECK (bucket_id = 'project-drive' AND public.has_any_permission(auth.uid(), ARRAY['projects.manage', 'engineering.manage']));
CREATE POLICY "Project managers delete project files" ON storage.objects FOR DELETE TO authenticated USING (bucket_id = 'project-drive' AND public.has_any_permission(auth.uid(), ARRAY['projects.manage', 'engineering.manage']));

INSERT INTO storage.objects(bucket_id, name) VALUES
  ('project-drive', 'sales/opportunity/00000000-0000-4000-8000-000000000201/00000000-0000-4000-8000-000000000720-draft.html'),
  ('project-drive', 'projects/retained-engineering-file.html');
SET ROLE authenticated;
SET request.jwt.claim.sub = '00000000-0000-4000-8000-000000000003';
DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM storage.objects WHERE name LIKE 'sales/opportunity/%') THEN RAISE EXCEPTION 'LOCAL_POLICY_FAIL expected pre-remediation PM Sales-prefix leak'; END IF;
END $baseline$;
RESET ROLE;

\ir ../20261011_sales_opportunity_structured_draft_materialization_activation.sql

-- The materialization acceptance rolls back its fixture; seed the minimum
-- immutable receipt graph needed to exercise the Sales SELECT policy here.
INSERT INTO public.sales_opportunity_structured_drafts(id,opportunity_id,customer_id,master_specification_id,master_specification_version_id,master_specification_version_number,document_kind,editable_schema_key,editable_schema_hash,source_fingerprint,created_by)
VALUES ('00000000-0000-4000-8000-000000000722','00000000-0000-4000-8000-000000000201','00000000-0000-4000-8000-000000000101','00000000-0000-4000-8000-000000000301','00000000-0000-4000-8000-000000000401',1,'SOR','sales-local-scalar-v1','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa','00000000-0000-4000-8000-000000000001');
INSERT INTO public.sales_opportunity_structured_draft_revisions(id,draft_id,revision_number,canonical_payload,payload_hash,source_fingerprint,created_by)
VALUES ('00000000-0000-4000-8000-000000000721','00000000-0000-4000-8000-000000000722',1,'{}','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa','00000000-0000-4000-8000-000000000001');
INSERT INTO public.sales_opportunity_structured_draft_requests(request_key,requested_by,opportunity_id,customer_id,master_specification_id,master_specification_version_id,master_specification_version_number,document_kind,editable_schema_key,editable_schema_hash,draft_id,revision_id,operation,expected_revision_number,payload_hash,source_fingerprint)
VALUES ('00000000-0000-4000-8000-000000000720','00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000201','00000000-0000-4000-8000-000000000101','00000000-0000-4000-8000-000000000301','00000000-0000-4000-8000-000000000401',1,'SOR','sales-local-scalar-v1','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa','00000000-0000-4000-8000-000000000722','00000000-0000-4000-8000-000000000721','CREATE',0,'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');
INSERT INTO public.sales_opportunity_document_locations(id,opportunity_id,customer_id,department_id,drive_root_node_id,target_folder_node_id,private_storage_bucket,private_storage_prefix,location_purpose,authorized_by,authorized_at,created_by)
VALUES ('00000000-0000-4000-8000-000000000710','00000000-0000-4000-8000-000000000201','00000000-0000-4000-8000-000000000101','00000000-0000-4000-8000-000000000501','00000000-0000-4000-8000-000000000601','00000000-0000-4000-8000-000000000601','project-drive','sales/opportunity/00000000-0000-4000-8000-000000000201/','STRUCTURED_DRAFT','00000000-0000-4000-8000-000000000001',now(),'00000000-0000-4000-8000-000000000001');
INSERT INTO public.drive_nodes(id,name,node_type,is_locked,is_trashed,department_id,parent_id,slug) VALUES ('00000000-0000-4000-8000-000000000801','SOR-draft.html','file',true,false,'00000000-0000-4000-8000-000000000501','00000000-0000-4000-8000-000000000601','sor-draft');
INSERT INTO public.drive_node_revisions(id,node_id,version,file_size_bytes,storage_path,sha256_checksum,uploaded_by) VALUES ('00000000-0000-4000-8000-000000000802','00000000-0000-4000-8000-000000000801',1,42,'sales/opportunity/00000000-0000-4000-8000-000000000201/00000000-0000-4000-8000-000000000720-draft.html','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa','00000000-0000-4000-8000-000000000001');
INSERT INTO public.document_control_registers(id,drive_node_id,department_id,document_number,title,created_by) VALUES ('00000000-0000-4000-8000-000000000803','00000000-0000-4000-8000-000000000801','00000000-0000-4000-8000-000000000501','SOR-LOCAL-0001','Local SOR','00000000-0000-4000-8000-000000000001');

SET ROLE authenticated;
SET request.jwt.claim.sub = '00000000-0000-4000-8000-000000000003';
DO $pm$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM storage.objects WHERE name = 'projects/retained-engineering-file.html') THEN RAISE EXCEPTION 'LOCAL_POLICY_FAIL PM lost non-Sales read'; END IF;
  IF EXISTS (SELECT 1 FROM storage.objects WHERE name LIKE 'sales/opportunity/%') THEN RAISE EXCEPTION 'LOCAL_POLICY_FAIL PM retained Sales-prefix read'; END IF;
  BEGIN INSERT INTO storage.objects(bucket_id,name) VALUES ('project-drive','sales/opportunity/00000000-0000-4000-8000-000000000201/pm.html'); RAISE EXCEPTION 'LOCAL_POLICY_FAIL PM Sales-prefix insert allowed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN
    UPDATE storage.objects SET name='sales/opportunity/00000000-0000-4000-8000-000000000201/changed.html' WHERE name='projects/retained-engineering-file.html';
    IF FOUND THEN RAISE EXCEPTION 'LOCAL_POLICY_FAIL PM moved file into Sales prefix'; END IF;
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  DELETE FROM storage.objects WHERE name='sales/opportunity/00000000-0000-4000-8000-000000000201/00000000-0000-4000-8000-000000000720-draft.html';
  IF FOUND THEN RAISE EXCEPTION 'LOCAL_POLICY_FAIL PM Sales-prefix delete allowed'; END IF;
END $pm$;
RESET ROLE;

INSERT INTO public.sales_opportunity_structured_draft_materializations(id,request_key,structured_draft_revision_id,location_id,drive_node_id,drive_revision_id,document_control_register_id,opportunity_id,customer_id,master_specification_id,master_specification_version_id,document_kind,source_fingerprint,rendered_sha256_checksum,mime_type,storage_bucket,storage_path,size_bytes,requested_by)
VALUES ('00000000-0000-4000-8000-000000000901','00000000-0000-4000-8000-000000000720','00000000-0000-4000-8000-000000000721','00000000-0000-4000-8000-000000000710','00000000-0000-4000-8000-000000000801','00000000-0000-4000-8000-000000000802','00000000-0000-4000-8000-000000000803','00000000-0000-4000-8000-000000000201','00000000-0000-4000-8000-000000000101','00000000-0000-4000-8000-000000000301','00000000-0000-4000-8000-000000000401','SOR','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa','text/html','project-drive','sales/opportunity/00000000-0000-4000-8000-000000000201/00000000-0000-4000-8000-000000000720-draft.html',42,'00000000-0000-4000-8000-000000000001');
SET ROLE authenticated;
SET request.jwt.claim.sub = '00000000-0000-4000-8000-000000000001';
DO $sales$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM storage.objects WHERE name='sales/opportunity/00000000-0000-4000-8000-000000000201/00000000-0000-4000-8000-000000000720-draft.html') THEN RAISE EXCEPTION 'LOCAL_POLICY_FAIL Sales actor cannot read own materialization'; END IF;
  BEGIN INSERT INTO storage.objects(bucket_id,name) VALUES ('project-drive','sales/opportunity/00000000-0000-4000-8000-000000000202/00000000-0000-4000-8000-000000000720-draft.html'); RAISE EXCEPTION 'LOCAL_POLICY_FAIL Sales cross-opportunity insert allowed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN
    UPDATE storage.objects SET name='projects/moved.html' WHERE name='sales/opportunity/00000000-0000-4000-8000-000000000201/00000000-0000-4000-8000-000000000720-draft.html';
    IF FOUND THEN RAISE EXCEPTION 'LOCAL_POLICY_FAIL Sales update allowed'; END IF;
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  DELETE FROM storage.objects WHERE name='sales/opportunity/00000000-0000-4000-8000-000000000201/00000000-0000-4000-8000-000000000720-draft.html';
  IF FOUND THEN RAISE EXCEPTION 'LOCAL_POLICY_FAIL Sales delete allowed'; END IF;
END $sales$;
RESET ROLE;

SET ROLE anon;
DO $anon$
BEGIN
  IF EXISTS (SELECT 1 FROM storage.objects) THEN RAISE EXCEPTION 'LOCAL_POLICY_FAIL unauthenticated read allowed'; END IF;
  BEGIN INSERT INTO storage.objects(bucket_id,name) VALUES ('project-drive','sales/opportunity/00000000-0000-4000-8000-000000000201/anon.html'); RAISE EXCEPTION 'LOCAL_POLICY_FAIL unauthenticated insert allowed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $anon$;
RESET ROLE;

DO $grants$
BEGIN
  IF NOT has_function_privilege('authenticated','public.save_sales_opportunity_structured_draft_at_location(uuid,uuid,uuid,uuid,text,integer,jsonb,uuid,uuid)','EXECUTE') OR NOT has_function_privilege('authenticated','public.resolve_sales_opportunity_structured_draft_location(uuid,uuid,uuid)','EXECUTE') OR NOT has_function_privilege('authenticated','public.register_sales_opportunity_structured_draft_storage_attempt(uuid,uuid,uuid,uuid,text,text,text,bigint)','EXECUTE') OR NOT has_function_privilege('authenticated','public.commit_sales_opportunity_structured_draft_materialization(uuid,uuid,uuid,uuid,text,text,text,text,bigint)','EXECUTE') OR NOT has_function_privilege('authenticated','public.can_discard_sales_opportunity_structured_draft_object(uuid,uuid,uuid,uuid,text,text)','EXECUTE') THEN RAISE EXCEPTION 'LOCAL_POLICY_FAIL one or more authenticated EXECUTE grants missing'; END IF;
  IF has_function_privilege('authenticated','public.reject_sales_opportunity_structured_draft_history_mutation()','EXECUTE') OR has_function_privilege('authenticated','public.sales_opportunity_structured_draft_schema_hash(text)','EXECUTE') OR has_function_privilege('authenticated','public.sales_opportunity_structured_draft_canonical_payload(text,jsonb)','EXECUTE') OR has_function_privilege('authenticated','public.sales_opportunity_structured_draft_source_fingerprint(uuid,uuid,uuid,uuid,integer,text,text,jsonb,timestamp with time zone)','EXECUTE') OR has_function_privilege('authenticated','public.save_sales_opportunity_structured_draft_revision(uuid,uuid,uuid,uuid,text,integer,jsonb,uuid)','EXECUTE') OR has_function_privilege('authenticated','public.reject_sales_opportunity_structured_draft_audit_mutation()','EXECUTE') OR has_function_privilege('authenticated','public.reject_sales_draft_materialization_mutation()','EXECUTE') OR has_function_privilege('authenticated','public.guard_sales_draft_storage_attempt()','EXECUTE') THEN RAISE EXCEPTION 'LOCAL_POLICY_FAIL authenticated internal helper execute grant'; END IF;
  IF has_function_privilege('anon','public.save_sales_opportunity_structured_draft_at_location(uuid,uuid,uuid,uuid,text,integer,jsonb,uuid,uuid)','EXECUTE') OR has_function_privilege('anon','public.resolve_sales_opportunity_structured_draft_location(uuid,uuid,uuid)','EXECUTE') OR has_function_privilege('anon','public.register_sales_opportunity_structured_draft_storage_attempt(uuid,uuid,uuid,uuid,text,text,text,bigint)','EXECUTE') OR has_function_privilege('anon','public.commit_sales_opportunity_structured_draft_materialization(uuid,uuid,uuid,uuid,text,text,text,text,bigint)','EXECUTE') OR has_function_privilege('anon','public.can_discard_sales_opportunity_structured_draft_object(uuid,uuid,uuid,uuid,text,text)','EXECUTE') OR has_function_privilege('anon','public.reject_sales_opportunity_structured_draft_history_mutation()','EXECUTE') OR has_function_privilege('anon','public.sales_opportunity_structured_draft_schema_hash(text)','EXECUTE') OR has_function_privilege('anon','public.sales_opportunity_structured_draft_canonical_payload(text,jsonb)','EXECUTE') OR has_function_privilege('anon','public.sales_opportunity_structured_draft_source_fingerprint(uuid,uuid,uuid,uuid,integer,text,text,jsonb,timestamp with time zone)','EXECUTE') OR has_function_privilege('anon','public.save_sales_opportunity_structured_draft_revision(uuid,uuid,uuid,uuid,text,integer,jsonb,uuid)','EXECUTE') OR has_function_privilege('anon','public.reject_sales_opportunity_structured_draft_audit_mutation()','EXECUTE') OR has_function_privilege('anon','public.reject_sales_draft_materialization_mutation()','EXECUTE') OR has_function_privilege('anon','public.guard_sales_draft_storage_attempt()','EXECUTE') THEN RAISE EXCEPTION 'LOCAL_POLICY_FAIL anonymous function execute grant'; END IF;
END $grants$;
SELECT 'STRUCTURED_DRAFT_STORAGE_POLICY_LOCAL_ACCEPTANCE_PASS' AS result;
ROLLBACK;