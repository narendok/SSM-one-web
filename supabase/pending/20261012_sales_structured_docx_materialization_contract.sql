-- SOURCE-ONLY, UNDEPLOYED REVIEW CONTRACT.
--
-- This additive proposal preserves the installed HTML-only Sales materialization
-- path and existing saved SOR HTML history. It does not activate any storage
-- policy, grant any caller EXECUTE privilege, create a binding, upload bytes, or
-- alter a legacy HTML record. Apply only after the reviewed HTML draft/location
-- contracts and a separate assigned-person authorization source are accepted.
--
-- The current deployed schema exposes department membership but no exact
-- document-responsibility relation. Therefore the explicit assignment relation
-- below is mandatory: department membership, sales.manage, Drive access, project
-- access, and platform-owner status do not themselves authorize DOCX operations.

CREATE TABLE public.sales_opportunity_structured_docx_assignments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  opportunity_id uuid NOT NULL REFERENCES public.sales_opportunities(id) ON DELETE RESTRICT,
  customer_id uuid NOT NULL REFERENCES public.customers(id) ON DELETE RESTRICT,
  document_kind text NOT NULL CHECK (document_kind IN ('SOR','CONTRACT_REVIEW','PRS')),
  department_id uuid NOT NULL REFERENCES public.departments(id) ON DELETE RESTRICT,
  responsible_employee_id uuid NOT NULL REFERENCES public.employees(id) ON DELETE RESTRICT,
  status text NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','REVOKED')),
  assigned_by uuid NOT NULL,
  assigned_at timestamptz NOT NULL DEFAULT now(),
  revoked_by uuid NULL,
  revoked_at timestamptz NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid NOT NULL,
  CHECK ((status = 'ACTIVE' AND revoked_by IS NULL AND revoked_at IS NULL) OR (status = 'REVOKED' AND revoked_by IS NOT NULL AND revoked_at IS NOT NULL)),
  UNIQUE (opportunity_id, document_kind, responsible_employee_id, status)
);
GRANT ALL ON public.sales_opportunity_structured_docx_assignments TO service_role;
ALTER TABLE public.sales_opportunity_structured_docx_assignments ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.sales_opportunity_structured_docx_requests (
  request_key uuid PRIMARY KEY,
  requested_by uuid NOT NULL,
  assignment_id uuid NOT NULL REFERENCES public.sales_opportunity_structured_docx_assignments(id) ON DELETE RESTRICT,
  structured_draft_request_key uuid NOT NULL REFERENCES public.sales_opportunity_structured_draft_requests(request_key) ON DELETE RESTRICT,
  structured_draft_revision_id uuid NOT NULL REFERENCES public.sales_opportunity_structured_draft_revisions(id) ON DELETE RESTRICT,
  location_id uuid NOT NULL REFERENCES public.sales_opportunity_document_locations(id) ON DELETE RESTRICT,
  opportunity_id uuid NOT NULL REFERENCES public.sales_opportunities(id) ON DELETE RESTRICT,
  customer_id uuid NOT NULL REFERENCES public.customers(id) ON DELETE RESTRICT,
  master_specification_id uuid NOT NULL REFERENCES public.master_specifications(id) ON DELETE RESTRICT,
  master_specification_version_id uuid NOT NULL REFERENCES public.master_specification_versions(id) ON DELETE RESTRICT,
  document_kind text NOT NULL CHECK (document_kind IN ('SOR','CONTRACT_REVIEW','PRS')),
  editable_schema_key text NOT NULL,
  editable_schema_hash text NOT NULL CHECK (editable_schema_hash ~ '^[a-f0-9]{64}$'),
  source_fingerprint text NOT NULL CHECK (source_fingerprint ~ '^[a-f0-9]{64}$'),
  payload_hash text NOT NULL CHECK (payload_hash ~ '^[a-f0-9]{64}$'),
  template_key text NOT NULL CHECK (length(trim(template_key)) > 0),
  template_version integer NOT NULL CHECK (template_version > 0),
  template_schema_hash text NOT NULL CHECK (template_schema_hash ~ '^[a-f0-9]{64}$'),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (structured_draft_revision_id, template_key, template_version, template_schema_hash)
);
GRANT ALL ON public.sales_opportunity_structured_docx_requests TO service_role;
ALTER TABLE public.sales_opportunity_structured_docx_requests ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.sales_opportunity_structured_docx_storage_attempts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_key uuid NOT NULL REFERENCES public.sales_opportunity_structured_docx_requests(request_key) ON DELETE RESTRICT,
  location_id uuid NOT NULL REFERENCES public.sales_opportunity_document_locations(id) ON DELETE RESTRICT,
  storage_bucket text NOT NULL CHECK (storage_bucket = 'project-drive'),
  storage_path text NOT NULL,
  sha256_checksum text NOT NULL CHECK (sha256_checksum ~ '^[a-f0-9]{64}$'),
  size_bytes bigint NOT NULL CHECK (size_bytes > 0 AND size_bytes <= 10485760),
  staged_by uuid NOT NULL,
  staged_at timestamptz NOT NULL DEFAULT now(),
  consumed_at timestamptz NULL,
  UNIQUE (request_key, location_id),
  UNIQUE (storage_bucket, storage_path)
);
GRANT ALL ON public.sales_opportunity_structured_docx_storage_attempts TO service_role;
ALTER TABLE public.sales_opportunity_structured_docx_storage_attempts ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.sales_opportunity_structured_docx_materializations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_key uuid NOT NULL UNIQUE REFERENCES public.sales_opportunity_structured_docx_requests(request_key) ON DELETE RESTRICT,
  assignment_id uuid NOT NULL REFERENCES public.sales_opportunity_structured_docx_assignments(id) ON DELETE RESTRICT,
  structured_draft_revision_id uuid NOT NULL REFERENCES public.sales_opportunity_structured_draft_revisions(id) ON DELETE RESTRICT,
  location_id uuid NOT NULL REFERENCES public.sales_opportunity_document_locations(id) ON DELETE RESTRICT,
  drive_node_id uuid NOT NULL UNIQUE REFERENCES public.drive_nodes(id) ON DELETE RESTRICT,
  drive_revision_id uuid NOT NULL UNIQUE REFERENCES public.drive_node_revisions(id) ON DELETE RESTRICT,
  document_control_register_id uuid NOT NULL UNIQUE REFERENCES public.document_control_registers(id) ON DELETE RESTRICT,
  opportunity_id uuid NOT NULL REFERENCES public.sales_opportunities(id) ON DELETE RESTRICT,
  customer_id uuid NOT NULL REFERENCES public.customers(id) ON DELETE RESTRICT,
  master_specification_id uuid NOT NULL REFERENCES public.master_specifications(id) ON DELETE RESTRICT,
  master_specification_version_id uuid NOT NULL REFERENCES public.master_specification_versions(id) ON DELETE RESTRICT,
  document_kind text NOT NULL CHECK (document_kind IN ('SOR','CONTRACT_REVIEW','PRS')),
  template_key text NOT NULL,
  template_version integer NOT NULL,
  template_schema_hash text NOT NULL CHECK (template_schema_hash ~ '^[a-f0-9]{64}$'),
  source_fingerprint text NOT NULL CHECK (source_fingerprint ~ '^[a-f0-9]{64}$'),
  payload_hash text NOT NULL CHECK (payload_hash ~ '^[a-f0-9]{64}$'),
  docx_sha256_checksum text NOT NULL CHECK (docx_sha256_checksum ~ '^[a-f0-9]{64}$'),
  mime_type text NOT NULL CHECK (mime_type = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'),
  storage_bucket text NOT NULL CHECK (storage_bucket = 'project-drive'),
  storage_path text NOT NULL,
  size_bytes bigint NOT NULL CHECK (size_bytes > 0),
  requested_by uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (structured_draft_revision_id, template_key, template_version, template_schema_hash)
);
GRANT ALL ON public.sales_opportunity_structured_docx_materializations TO service_role;
ALTER TABLE public.sales_opportunity_structured_docx_materializations ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.sales_opportunity_structured_docx_audit_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  materialization_id uuid NOT NULL UNIQUE REFERENCES public.sales_opportunity_structured_docx_materializations(id) ON DELETE RESTRICT,
  request_key uuid NOT NULL UNIQUE REFERENCES public.sales_opportunity_structured_docx_requests(request_key) ON DELETE RESTRICT,
  actor_user_id uuid NOT NULL,
  action text NOT NULL CHECK (action = 'MATERIALIZED_UNISSUED_DOCX'),
  source_fingerprint text NOT NULL CHECK (source_fingerprint ~ '^[a-f0-9]{64}$'),
  docx_sha256_checksum text NOT NULL CHECK (docx_sha256_checksum ~ '^[a-f0-9]{64}$'),
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT ALL ON public.sales_opportunity_structured_docx_audit_events TO service_role;
ALTER TABLE public.sales_opportunity_structured_docx_audit_events ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.reject_sales_structured_docx_history_mutation()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
BEGIN RAISE EXCEPTION 'Structured Sales DOCX history is append-only'; END;
$$;
CREATE TRIGGER sales_structured_docx_assignments_immutable BEFORE UPDATE OR DELETE ON public.sales_opportunity_structured_docx_assignments FOR EACH ROW EXECUTE FUNCTION public.reject_sales_structured_docx_history_mutation();
CREATE TRIGGER sales_structured_docx_requests_immutable BEFORE UPDATE OR DELETE ON public.sales_opportunity_structured_docx_requests FOR EACH ROW EXECUTE FUNCTION public.reject_sales_structured_docx_history_mutation();
CREATE OR REPLACE FUNCTION public.guard_sales_structured_docx_storage_attempt()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  IF TG_OP = 'DELETE'
    OR NEW.request_key IS DISTINCT FROM OLD.request_key
    OR NEW.location_id IS DISTINCT FROM OLD.location_id
    OR NEW.staged_by IS DISTINCT FROM OLD.staged_by
    OR NEW.storage_bucket IS DISTINCT FROM OLD.storage_bucket
    OR NEW.storage_path IS DISTINCT FROM OLD.storage_path
    OR NEW.sha256_checksum IS DISTINCT FROM OLD.sha256_checksum
    OR NEW.size_bytes IS DISTINCT FROM OLD.size_bytes
    OR (OLD.consumed_at IS NOT NULL AND NEW.consumed_at IS DISTINCT FROM OLD.consumed_at)
  THEN
    RAISE EXCEPTION 'Structured Sales DOCX storage receipt is immutable after staging';
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER sales_structured_docx_storage_attempts_guard BEFORE UPDATE OR DELETE ON public.sales_opportunity_structured_docx_storage_attempts FOR EACH ROW EXECUTE FUNCTION public.guard_sales_structured_docx_storage_attempt();
CREATE TRIGGER sales_structured_docx_materializations_immutable BEFORE UPDATE OR DELETE ON public.sales_opportunity_structured_docx_materializations FOR EACH ROW EXECUTE FUNCTION public.reject_sales_structured_docx_history_mutation();
CREATE TRIGGER sales_structured_docx_audits_immutable BEFORE UPDATE OR DELETE ON public.sales_opportunity_structured_docx_audit_events FOR EACH ROW EXECUTE FUNCTION public.reject_sales_structured_docx_history_mutation();

CREATE OR REPLACE FUNCTION public.resolve_sales_structured_docx_assignment(
  p_opportunity_id uuid, p_customer_id uuid, p_document_kind text, p_assignment_id uuid
) RETURNS TABLE(assignment_id uuid, location_id uuid, department_id uuid, target_folder_node_id uuid, storage_bucket text, storage_path_prefix text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_actor uuid := auth.uid(); v_assignment public.sales_opportunity_structured_docx_assignments%ROWTYPE; v_employee public.employees%ROWTYPE; v_location record;
BEGIN
  IF v_actor IS NULL OR NOT public.has_permission(v_actor, 'sales.manage') THEN RAISE EXCEPTION 'Sales management permission is required'; END IF;
  SELECT * INTO v_assignment FROM public.sales_opportunity_structured_docx_assignments WHERE id = p_assignment_id AND opportunity_id = p_opportunity_id AND customer_id = p_customer_id AND document_kind = p_document_kind AND status = 'ACTIVE' FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'The current assigned-person DOCX authority is unavailable'; END IF;
  SELECT * INTO v_employee FROM public.employees WHERE id = v_assignment.responsible_employee_id AND user_id = v_actor AND employment_status = 'ACTIVE' FOR UPDATE;
  IF NOT FOUND OR NOT EXISTS (SELECT 1 FROM public.employee_departments ed WHERE ed.employee_id = v_employee.id AND ed.department_id = v_assignment.department_id) THEN RAISE EXCEPTION 'The current actor is not the assigned active responsible person'; END IF;
  IF NOT public.can_access_department_drive(v_actor, v_assignment.department_id, NULL) THEN RAISE EXCEPTION 'The assigned person cannot access the configured department Drive'; END IF;
  -- The location resolver requires the actual location ID; obtain exactly one matching active location only after locking the assignment.
  SELECT * INTO v_location FROM public.sales_opportunity_document_locations AS configured_location WHERE configured_location.opportunity_id = p_opportunity_id AND configured_location.customer_id = p_customer_id AND configured_location.department_id = v_assignment.department_id AND configured_location.location_purpose = 'STRUCTURED_DRAFT' AND configured_location.status = 'ACTIVE' FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'No active private Sales location matches the current assignment'; END IF;
  SELECT * INTO v_location FROM public.resolve_sales_opportunity_structured_draft_location(p_opportunity_id, p_customer_id, v_location.id);
  RETURN QUERY SELECT v_assignment.id, v_location.location_id, v_location.department_id, v_location.target_folder_node_id, v_location.storage_bucket, v_location.storage_path_prefix;
END;
$$;

CREATE OR REPLACE FUNCTION public.request_sales_structured_docx_materialization(
  p_opportunity_id uuid, p_customer_id uuid, p_structured_draft_request_key uuid, p_assignment_id uuid,
  p_template_key text, p_template_version integer, p_template_schema_hash text, p_request_key uuid
) RETURNS TABLE(request_key uuid, storage_bucket text, storage_path text, replayed boolean)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_actor uuid := auth.uid(); v_scope record; v_html_request public.sales_opportunity_structured_draft_requests%ROWTYPE; v_revision public.sales_opportunity_structured_draft_revisions%ROWTYPE; v_draft public.sales_opportunity_structured_drafts%ROWTYPE; v_existing public.sales_opportunity_structured_docx_requests%ROWTYPE;
BEGIN
  SELECT * INTO v_scope FROM public.resolve_sales_structured_docx_assignment(p_opportunity_id, p_customer_id, (SELECT html_request.document_kind FROM public.sales_opportunity_structured_draft_requests AS html_request WHERE html_request.request_key = p_structured_draft_request_key), p_assignment_id);
  IF p_request_key IS NULL OR btrim(coalesce(p_template_key,'')) = '' OR p_template_version <= 0 OR p_template_schema_hash !~ '^[a-f0-9]{64}$' THEN RAISE EXCEPTION 'Invalid DOCX request pins'; END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended(concat_ws('|', p_opportunity_id::text, p_request_key::text), 0));
  SELECT * INTO v_existing FROM public.sales_opportunity_structured_docx_requests AS existing_request WHERE existing_request.request_key = p_request_key FOR UPDATE;
  IF FOUND THEN
    IF v_existing.requested_by = v_actor AND v_existing.assignment_id = p_assignment_id AND v_existing.structured_draft_request_key = p_structured_draft_request_key AND v_existing.template_key = p_template_key AND v_existing.template_version = p_template_version AND v_existing.template_schema_hash = p_template_schema_hash THEN
      RETURN QUERY SELECT v_existing.request_key, v_scope.storage_bucket, v_scope.storage_path_prefix || v_existing.request_key::text || '-draft.docx', true; RETURN;
    END IF;
    RAISE EXCEPTION 'DOCX request key conflicts with a different actor, source, assignment, or template pin';
  END IF;
  SELECT * INTO v_html_request FROM public.sales_opportunity_structured_draft_requests AS structured_request WHERE structured_request.request_key = p_structured_draft_request_key AND structured_request.requested_by = v_actor AND structured_request.opportunity_id = p_opportunity_id AND structured_request.customer_id = p_customer_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Pinned structured Sales revision is not owned by this actor and source'; END IF;
  SELECT * INTO v_revision FROM public.sales_opportunity_structured_draft_revisions WHERE id = v_html_request.revision_id FOR UPDATE;
  SELECT * INTO v_draft FROM public.sales_opportunity_structured_drafts WHERE id = v_html_request.draft_id FOR UPDATE;
  IF NOT FOUND OR v_revision.source_fingerprint <> v_html_request.source_fingerprint OR v_draft.master_specification_version_id <> v_html_request.master_specification_version_id THEN RAISE EXCEPTION 'Pinned structured Sales revision changed'; END IF;
  INSERT INTO public.sales_opportunity_structured_docx_requests(request_key,requested_by,assignment_id,structured_draft_request_key,structured_draft_revision_id,location_id,opportunity_id,customer_id,master_specification_id,master_specification_version_id,document_kind,editable_schema_key,editable_schema_hash,source_fingerprint,payload_hash,template_key,template_version,template_schema_hash)
  VALUES(p_request_key,v_actor,p_assignment_id,p_structured_draft_request_key,v_revision.id,v_scope.location_id,p_opportunity_id,p_customer_id,v_html_request.master_specification_id,v_html_request.master_specification_version_id,v_html_request.document_kind,v_html_request.editable_schema_key,v_html_request.editable_schema_hash,v_revision.source_fingerprint,v_revision.payload_hash,p_template_key,p_template_version,p_template_schema_hash);
  RETURN QUERY SELECT p_request_key, v_scope.storage_bucket, v_scope.storage_path_prefix || p_request_key::text || '-draft.docx', false;
END;
$$;

CREATE OR REPLACE FUNCTION public.register_sales_structured_docx_storage_attempt(
  p_opportunity_id uuid, p_customer_id uuid, p_assignment_id uuid, p_request_key uuid, p_storage_bucket text, p_storage_path text, p_sha256_checksum text, p_size_bytes bigint
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_actor uuid := auth.uid(); v_request public.sales_opportunity_structured_docx_requests%ROWTYPE; v_scope record; v_attempt public.sales_opportunity_structured_docx_storage_attempts%ROWTYPE;
BEGIN
  SELECT * INTO v_request FROM public.sales_opportunity_structured_docx_requests AS docx_request WHERE docx_request.request_key = p_request_key AND docx_request.requested_by = v_actor AND docx_request.opportunity_id = p_opportunity_id AND docx_request.customer_id = p_customer_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'DOCX request is not owned by this actor and source'; END IF;
  SELECT * INTO v_scope FROM public.resolve_sales_structured_docx_assignment(p_opportunity_id,p_customer_id,v_request.document_kind,p_assignment_id);
  IF v_request.assignment_id <> p_assignment_id OR v_request.location_id <> v_scope.location_id OR p_storage_bucket <> v_scope.storage_bucket OR p_storage_path <> v_scope.storage_path_prefix || p_request_key::text || '-draft.docx' OR p_sha256_checksum !~ '^[a-f0-9]{64}$' OR p_size_bytes IS NULL OR p_size_bytes <= 0 OR p_size_bytes > 10485760 THEN RAISE EXCEPTION 'Invalid staged DOCX object'; END IF;
  IF NOT EXISTS (SELECT 1 FROM storage.objects WHERE bucket_id = p_storage_bucket AND name = p_storage_path) THEN RAISE EXCEPTION 'Staged DOCX object does not exist'; END IF;
  INSERT INTO public.sales_opportunity_structured_docx_storage_attempts(request_key,location_id,storage_bucket,storage_path,sha256_checksum,size_bytes,staged_by) VALUES(p_request_key,v_scope.location_id,p_storage_bucket,p_storage_path,p_sha256_checksum,p_size_bytes,v_actor) ON CONFLICT(request_key,location_id) DO NOTHING;
  SELECT * INTO v_attempt FROM public.sales_opportunity_structured_docx_storage_attempts AS docx_attempt WHERE docx_attempt.request_key = p_request_key AND docx_attempt.location_id = v_scope.location_id FOR UPDATE;
  IF v_attempt.staged_by <> v_actor OR v_attempt.storage_bucket <> p_storage_bucket OR v_attempt.storage_path <> p_storage_path OR v_attempt.sha256_checksum <> p_sha256_checksum OR v_attempt.size_bytes <> p_size_bytes THEN RAISE EXCEPTION 'Staged DOCX object conflicts with immutable attempt provenance'; END IF;
  RETURN v_attempt.id;
END;
$$;

CREATE OR REPLACE FUNCTION public.commit_sales_structured_docx_materialization(
  p_opportunity_id uuid, p_customer_id uuid, p_assignment_id uuid, p_request_key uuid, p_file_name text, p_storage_bucket text, p_storage_path text, p_sha256_checksum text, p_size_bytes bigint
) RETURNS TABLE(materialization_id uuid, drive_node_id uuid, drive_revision_id uuid, document_control_register_id uuid, replayed boolean)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_actor uuid := auth.uid(); v_request public.sales_opportunity_structured_docx_requests%ROWTYPE; v_scope record; v_attempt public.sales_opportunity_structured_docx_storage_attempts%ROWTYPE; v_prior public.sales_opportunity_structured_docx_materializations%ROWTYPE; v_node uuid; v_drive_revision uuid; v_register uuid; v_materialization uuid;
BEGIN
  SELECT * INTO v_request FROM public.sales_opportunity_structured_docx_requests AS docx_request WHERE docx_request.request_key = p_request_key AND docx_request.requested_by = v_actor AND docx_request.opportunity_id = p_opportunity_id AND docx_request.customer_id = p_customer_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'DOCX request is not owned by this actor and source'; END IF;
  SELECT * INTO v_scope FROM public.resolve_sales_structured_docx_assignment(p_opportunity_id,p_customer_id,v_request.document_kind,p_assignment_id);
  PERFORM pg_advisory_xact_lock(hashtextextended(concat_ws('|',p_opportunity_id::text,p_request_key::text),0));
  IF v_request.assignment_id <> p_assignment_id OR v_request.location_id <> v_scope.location_id OR p_storage_bucket <> v_scope.storage_bucket OR p_storage_path <> v_scope.storage_path_prefix || p_request_key::text || '-draft.docx' OR p_sha256_checksum !~ '^[a-f0-9]{64}$' OR p_size_bytes IS NULL OR p_size_bytes <= 0 OR btrim(coalesce(p_file_name,'')) = '' OR p_file_name !~ '\.docx$' THEN RAISE EXCEPTION 'Invalid DOCX materialization payload'; END IF;
  SELECT * INTO v_prior FROM public.sales_opportunity_structured_docx_materializations AS prior_materialization WHERE prior_materialization.request_key = p_request_key FOR UPDATE;
  IF FOUND THEN
    IF v_prior.requested_by = v_actor AND v_prior.assignment_id = p_assignment_id AND v_prior.docx_sha256_checksum = p_sha256_checksum AND v_prior.storage_bucket = p_storage_bucket AND v_prior.storage_path = p_storage_path AND v_prior.size_bytes = p_size_bytes AND p_file_name = (SELECT name FROM public.drive_nodes WHERE id = v_prior.drive_node_id) THEN RETURN QUERY SELECT v_prior.id,v_prior.drive_node_id,v_prior.drive_revision_id,v_prior.document_control_register_id,true; RETURN; END IF;
    RAISE EXCEPTION 'DOCX request key conflicts with a different materialization payload';
  END IF;
  SELECT * INTO v_attempt FROM public.sales_opportunity_structured_docx_storage_attempts AS staged_attempt WHERE staged_attempt.request_key = p_request_key AND staged_attempt.location_id = v_scope.location_id AND staged_attempt.staged_by = v_actor AND staged_attempt.consumed_at IS NULL FOR UPDATE;
  IF NOT FOUND OR v_attempt.storage_bucket <> p_storage_bucket OR v_attempt.storage_path <> p_storage_path OR v_attempt.sha256_checksum <> p_sha256_checksum OR v_attempt.size_bytes <> p_size_bytes THEN RAISE EXCEPTION 'Staged DOCX object lacks a verified owned attempt receipt'; END IF;
  INSERT INTO public.drive_nodes(department_id,project_id,parent_id,name,slug,node_type,file_type,mime_type,file_size_bytes,storage_bucket,storage_path,sha256_checksum,current_version,is_locked,created_by,metadata)
  VALUES(v_scope.department_id,NULL,v_scope.target_folder_node_id,p_file_name,'sales-docx-' || substr(md5(p_request_key::text),1,24),'FILE','OTHER','application/vnd.openxmlformats-officedocument.wordprocessingml.document',p_size_bytes,p_storage_bucket,p_storage_path,p_sha256_checksum,1,false,v_actor,jsonb_build_object('sales_structured_docx',true,'opportunity_id',p_opportunity_id,'structured_draft_revision_id',v_request.structured_draft_revision_id,'request_key',p_request_key,'template_key',v_request.template_key,'template_version',v_request.template_version,'template_schema_hash',v_request.template_schema_hash)) RETURNING id INTO v_node;
  INSERT INTO public.drive_node_revisions(node_id,version,file_size_bytes,storage_path,sha256_checksum,change_summary,uploaded_by) VALUES(v_node,1,p_size_bytes,p_storage_path,p_sha256_checksum,'Initial unissued structured Sales DOCX revision from pinned source/template/schema',v_actor) RETURNING id INTO v_drive_revision;
  INSERT INTO public.document_control_registers(drive_node_id,department_id,document_number,title,document_status,controlled_version,approval_note,owner_employee_id,source_revision_id,created_by) VALUES(v_node,v_scope.department_id,public.next_business_number('sales_structured_docx','SAL',NULL),p_file_name,'DRAFT',1,'Unissued editable structured Sales DOCX; no approval, issuance, or release is recorded',(SELECT responsible_employee_id FROM public.sales_opportunity_structured_docx_assignments WHERE id=p_assignment_id),v_request.structured_draft_revision_id,v_actor) RETURNING id INTO v_register;
  INSERT INTO public.sales_opportunity_structured_docx_materializations(request_key,assignment_id,structured_draft_revision_id,location_id,drive_node_id,drive_revision_id,document_control_register_id,opportunity_id,customer_id,master_specification_id,master_specification_version_id,document_kind,template_key,template_version,template_schema_hash,source_fingerprint,payload_hash,docx_sha256_checksum,mime_type,storage_bucket,storage_path,size_bytes,requested_by)
  VALUES(p_request_key,p_assignment_id,v_request.structured_draft_revision_id,v_scope.location_id,v_node,v_drive_revision,v_register,p_opportunity_id,p_customer_id,v_request.master_specification_id,v_request.master_specification_version_id,v_request.document_kind,v_request.template_key,v_request.template_version,v_request.template_schema_hash,v_request.source_fingerprint,v_request.payload_hash,p_sha256_checksum,'application/vnd.openxmlformats-officedocument.wordprocessingml.document',p_storage_bucket,p_storage_path,p_size_bytes,v_actor) RETURNING id INTO v_materialization;
  INSERT INTO public.sales_opportunity_structured_docx_audit_events(materialization_id,request_key,actor_user_id,action,source_fingerprint,docx_sha256_checksum) VALUES(v_materialization,p_request_key,v_actor,'MATERIALIZED_UNISSUED_DOCX',v_request.source_fingerprint,p_sha256_checksum);
  UPDATE public.sales_opportunity_structured_docx_storage_attempts SET consumed_at = now() WHERE id = v_attempt.id;
  RETURN QUERY SELECT v_materialization,v_node,v_drive_revision,v_register,false;
END;
$$;

CREATE OR REPLACE FUNCTION public.read_sales_structured_docx_materializations(p_opportunity_id uuid, p_customer_id uuid, p_assignment_id uuid)
RETURNS TABLE(materialization_id uuid, request_key uuid, structured_draft_revision_id uuid, document_kind text, template_key text, template_version integer, template_schema_hash text, storage_bucket text, storage_path text, docx_sha256_checksum text, size_bytes bigint, drive_node_id uuid, drive_revision_id uuid, document_control_register_id uuid, created_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_scope record;
BEGIN
  SELECT * INTO v_scope FROM public.resolve_sales_structured_docx_assignment(p_opportunity_id,p_customer_id,(SELECT document_kind FROM public.sales_opportunity_structured_docx_assignments WHERE id=p_assignment_id),p_assignment_id);
  RETURN QUERY SELECT m.id,m.request_key,m.structured_draft_revision_id,m.document_kind,m.template_key,m.template_version,m.template_schema_hash,m.storage_bucket,m.storage_path,m.docx_sha256_checksum,m.size_bytes,m.drive_node_id,m.drive_revision_id,m.document_control_register_id,m.created_at FROM public.sales_opportunity_structured_docx_materializations m WHERE m.opportunity_id=p_opportunity_id AND m.customer_id=p_customer_id AND m.assignment_id=v_scope.assignment_id ORDER BY m.created_at DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.reject_sales_structured_docx_history_mutation() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.guard_sales_structured_docx_storage_attempt() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.resolve_sales_structured_docx_assignment(uuid,uuid,text,uuid) FROM PUBLIC, anon, service_role;
REVOKE ALL ON FUNCTION public.request_sales_structured_docx_materialization(uuid,uuid,uuid,uuid,text,integer,text,uuid) FROM PUBLIC, anon, service_role;
REVOKE ALL ON FUNCTION public.register_sales_structured_docx_storage_attempt(uuid,uuid,uuid,uuid,text,text,text,bigint) FROM PUBLIC, anon, service_role;
REVOKE ALL ON FUNCTION public.commit_sales_structured_docx_materialization(uuid,uuid,uuid,uuid,text,text,text,text,bigint) FROM PUBLIC, anon, service_role;
REVOKE ALL ON FUNCTION public.read_sales_structured_docx_materializations(uuid,uuid,uuid) FROM PUBLIC, anon, service_role;