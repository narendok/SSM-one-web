-- LOCAL DISPOSABLE trusted-receipt race fixture only.
\set ON_ERROR_STOP on

INSERT INTO public.drive_nodes(id,name,node_type,is_locked,is_trashed,department_id,project_id,parent_id,slug) VALUES
 ('00000000-0000-4000-8000-000000000610','Sales root','folder',true,false,'00000000-0000-4000-8000-000000000501',NULL,NULL,'sales-root-race'),
 ('00000000-0000-4000-8000-000000000611','Opportunity folder','folder',true,false,'00000000-0000-4000-8000-000000000501',NULL,'00000000-0000-4000-8000-000000000610','opportunity-race');
INSERT INTO public.sales_opportunity_document_locations(id,opportunity_id,customer_id,department_id,drive_root_node_id,target_folder_node_id,private_storage_bucket,private_storage_prefix,location_purpose,authorized_by,authorized_at,created_by) VALUES
 ('00000000-0000-4000-8000-000000000710','00000000-0000-4000-8000-000000000201','00000000-0000-4000-8000-000000000101','00000000-0000-4000-8000-000000000501','00000000-0000-4000-8000-000000000610','00000000-0000-4000-8000-000000000611','project-drive','sales/race/','STRUCTURED_DRAFT','00000000-0000-4000-8000-000000000001',now(),'00000000-0000-4000-8000-000000000001');
INSERT INTO public.sales_opportunity_structured_draft_private_locations(id,drive_folder_node_id,private_storage_bucket,private_storage_prefix,verified_private_at,verified_by,created_by) VALUES
 ('00000000-0000-4000-8000-000000000701','00000000-0000-4000-8000-000000000610','project-drive','sales/race/',now(),'00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000001');
INSERT INTO public.department_process_templates(id,department_id,template_key,version,status,active_document_revision_id) VALUES
 ('00000000-0000-4000-8000-000000000991','00000000-0000-4000-8000-000000000501','sales-sor-race',1,'ACTIVE','00000000-0000-4000-8000-000000000992');
INSERT INTO public.department_process_template_document_revisions(id,template_id) VALUES
 ('00000000-0000-4000-8000-000000000992','00000000-0000-4000-8000-000000000991');
INSERT INTO public.structured_lifecycle_docx_responsibility_assignments(id,scope_type,opportunity_id,customer_id,department_id,document_kind,responsible_employee_id,assigned_by,created_by) VALUES
 ('00000000-0000-4000-8000-000000000901','SALES_OPPORTUNITY','00000000-0000-4000-8000-000000000201','00000000-0000-4000-8000-000000000101','00000000-0000-4000-8000-000000000501','SOR','00000000-0000-4000-8000-000000000801','00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000001');
INSERT INTO public.sales_opportunity_structured_docx_assignments(id,opportunity_id,customer_id,document_kind,department_id,responsible_employee_id,registry_assignment_id,assigned_by,created_by) VALUES
 ('00000000-0000-4000-8000-000000000901','00000000-0000-4000-8000-000000000201','00000000-0000-4000-8000-000000000101','SOR','00000000-0000-4000-8000-000000000501','00000000-0000-4000-8000-000000000801','00000000-0000-4000-8000-000000000901','00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000001');
INSERT INTO public.structured_lifecycle_docx_template_pins(id,department_id,document_kind,template_id,template_document_revision_id,template_key,template_version,template_schema_hash,approved_by,request_key,payload_hash,created_by) VALUES
 ('00000000-0000-4000-8000-000000000994','00000000-0000-4000-8000-000000000501','SOR','00000000-0000-4000-8000-000000000991','00000000-0000-4000-8000-000000000992','sales-sor-race',1,'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb','00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000995','cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc','00000000-0000-4000-8000-000000000001');
CREATE TABLE public.trusted_receipt_race_control(case_name text PRIMARY KEY, verifier_ready boolean NOT NULL DEFAULT false, mutation_ready boolean NOT NULL DEFAULT false, released boolean NOT NULL DEFAULT false);
INSERT INTO public.trusted_receipt_race_control(case_name) VALUES ('revoke'),('template'),('source');