-- SOURCE-ONLY, UNDEPLOYED REVIEW CONTRACT. DO NOT EXECUTE.
--
-- Configurable document responsibility and immutable approved-template registry
-- for private lifecycle DOCX documents. This proposal reuses the authoritative
-- department_process_templates/document revision and employees/employee_departments
-- relations. It does not alter legacy Sales HTML materializations, historical
-- document registers, existing assignments, Drive bindings, policies, or grants.
--
-- Activation requires a separately accepted private-object reader, Drive/storage
-- object enforcement, and caller-authenticated acceptance. Every externally
-- callable entrypoint is explicitly revoked below.

CREATE TABLE public.structured_lifecycle_docx_responsibility_assignments (
  id uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
  project_id uuid NOT NULL REFERENCES public.projects(id) ON DELETE RESTRICT,
  department_id uuid NOT NULL REFERENCES public.departments(id) ON DELETE RESTRICT,
  document_kind text NOT NULL CHECK (document_kind IN (
    'SOR','NDA','COMMERCIAL_QUOTATION','CONTRACT_REVIEW','PRS','BOM','DFMEA',
    'MANUFACTURING_CONTROL_PLAN','DVPR','PDI','COMMERCIAL_TAX_INVOICE','ANNUAL_SKILL_MATRIX'
  )),
  responsible_employee_id uuid NOT NULL REFERENCES public.employees(id) ON DELETE RESTRICT,
  reviewer_employee_id uuid NULL REFERENCES public.employees(id) ON DELETE RESTRICT,
  status text NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','REVOKED')),
  assigned_by uuid NOT NULL,
  assigned_at timestamptz NOT NULL DEFAULT now(),
  revoked_by uuid NULL,
  revoked_at timestamptz NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid NOT NULL,
  CHECK (reviewer_employee_id IS NULL OR reviewer_employee_id <> responsible_employee_id),
  CHECK ((status = 'ACTIVE' AND revoked_by IS NULL AND revoked_at IS NULL) OR (status = 'REVOKED' AND revoked_by IS NOT NULL AND revoked_at IS NOT NULL))
);
GRANT ALL ON public.structured_lifecycle_docx_responsibility_assignments TO service_role;
ALTER TABLE public.structured_lifecycle_docx_responsibility_assignments ENABLE ROW LEVEL SECURITY;
CREATE UNIQUE INDEX structured_lifecycle_docx_one_active_assignment
  ON public.structured_lifecycle_docx_responsibility_assignments(project_id, document_kind)
  WHERE status = 'ACTIVE';

CREATE TABLE public.structured_lifecycle_docx_template_pins (
  id uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
  department_id uuid NOT NULL REFERENCES public.departments(id) ON DELETE RESTRICT,
  document_kind text NOT NULL CHECK (document_kind IN (
    'SOR','NDA','COMMERCIAL_QUOTATION','CONTRACT_REVIEW','PRS','BOM','DFMEA',
    'MANUFACTURING_CONTROL_PLAN','DVPR','PDI','COMMERCIAL_TAX_INVOICE','ANNUAL_SKILL_MATRIX'
  )),
  template_id uuid NOT NULL REFERENCES public.department_process_templates(id) ON DELETE RESTRICT,
  template_document_revision_id uuid NOT NULL REFERENCES public.department_process_template_document_revisions(id) ON DELETE RESTRICT,
  template_key text NOT NULL CHECK (btrim(template_key) <> ''),
  template_version integer NOT NULL CHECK (template_version > 0),
  template_schema_hash text NOT NULL CHECK (template_schema_hash ~ '^[a-f0-9]{64}$'),
  status text NOT NULL DEFAULT 'APPROVED' CHECK (status IN ('APPROVED','REVOKED')),
  approved_by uuid NOT NULL,
  approved_at timestamptz NOT NULL DEFAULT now(),
  revoked_by uuid NULL,
  revoked_at timestamptz NULL,
  request_key uuid NOT NULL,
  payload_hash text NOT NULL CHECK (payload_hash ~ '^[a-f0-9]{64}$'),
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid NOT NULL,
  CHECK ((status = 'APPROVED' AND revoked_by IS NULL AND revoked_at IS NULL) OR (status = 'REVOKED' AND revoked_by IS NOT NULL AND revoked_at IS NOT NULL)),
  UNIQUE (approved_by, request_key)
);
GRANT ALL ON public.structured_lifecycle_docx_template_pins TO service_role;
ALTER TABLE public.structured_lifecycle_docx_template_pins ENABLE ROW LEVEL SECURITY;
CREATE UNIQUE INDEX structured_lifecycle_docx_one_approved_template
  ON public.structured_lifecycle_docx_template_pins(department_id, document_kind)
  WHERE status = 'APPROVED';

CREATE TABLE public.structured_lifecycle_docx_registry_audit_events (
  id uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
  request_key uuid NOT NULL,
  actor_user_id uuid NOT NULL,
  action text NOT NULL CHECK (action IN ('ASSIGNED','REVOKED','TEMPLATE_APPROVED','TEMPLATE_REVOKED')),
  assignment_id uuid NULL REFERENCES public.structured_lifecycle_docx_responsibility_assignments(id) ON DELETE RESTRICT,
  template_pin_id uuid NULL REFERENCES public.structured_lifecycle_docx_template_pins(id) ON DELETE RESTRICT,
  payload_hash text NOT NULL CHECK (payload_hash ~ '^[a-f0-9]{64}$'),
  before_data jsonb NULL,
  after_data jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK ((assignment_id IS NOT NULL)::integer + (template_pin_id IS NOT NULL)::integer = 1),
  UNIQUE (actor_user_id, request_key)
);
GRANT ALL ON public.structured_lifecycle_docx_registry_audit_events TO service_role;
ALTER TABLE public.structured_lifecycle_docx_registry_audit_events ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.guard_structured_lifecycle_docx_assignment()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  IF TG_OP = 'DELETE'
    OR NEW.project_id IS DISTINCT FROM OLD.project_id
    OR NEW.department_id IS DISTINCT FROM OLD.department_id
    OR NEW.document_kind IS DISTINCT FROM OLD.document_kind
    OR NEW.responsible_employee_id IS DISTINCT FROM OLD.responsible_employee_id
    OR NEW.reviewer_employee_id IS DISTINCT FROM OLD.reviewer_employee_id
    OR NEW.assigned_by IS DISTINCT FROM OLD.assigned_by
    OR NEW.assigned_at IS DISTINCT FROM OLD.assigned_at
    OR (OLD.status = 'ACTIVE' AND (NEW.status <> 'REVOKED' OR NEW.revoked_by IS NULL OR NEW.revoked_at IS NULL))
    OR (OLD.status = 'REVOKED' AND NEW IS DISTINCT FROM OLD)
  THEN RAISE EXCEPTION 'Structured lifecycle DOCX assignment is immutable except one revocation'; END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER structured_lifecycle_docx_assignment_guard
BEFORE UPDATE OR DELETE ON public.structured_lifecycle_docx_responsibility_assignments
FOR EACH ROW EXECUTE FUNCTION public.guard_structured_lifecycle_docx_assignment();

CREATE OR REPLACE FUNCTION public.guard_structured_lifecycle_docx_template_pin()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  IF TG_OP = 'DELETE'
    OR NEW.department_id IS DISTINCT FROM OLD.department_id
    OR NEW.document_kind IS DISTINCT FROM OLD.document_kind
    OR NEW.template_id IS DISTINCT FROM OLD.template_id
    OR NEW.template_document_revision_id IS DISTINCT FROM OLD.template_document_revision_id
    OR NEW.template_key IS DISTINCT FROM OLD.template_key
    OR NEW.template_version IS DISTINCT FROM OLD.template_version
    OR NEW.template_schema_hash IS DISTINCT FROM OLD.template_schema_hash
    OR NEW.approved_by IS DISTINCT FROM OLD.approved_by
    OR NEW.approved_at IS DISTINCT FROM OLD.approved_at
    OR (OLD.status = 'APPROVED' AND (NEW.status <> 'REVOKED' OR NEW.revoked_by IS NULL OR NEW.revoked_at IS NULL))
    OR (OLD.status = 'REVOKED' AND NEW IS DISTINCT FROM OLD)
  THEN RAISE EXCEPTION 'Structured lifecycle DOCX template pin is immutable except one revocation'; END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER structured_lifecycle_docx_template_pin_guard
BEFORE UPDATE OR DELETE ON public.structured_lifecycle_docx_template_pins
FOR EACH ROW EXECUTE FUNCTION public.guard_structured_lifecycle_docx_template_pin();

CREATE OR REPLACE FUNCTION public.reject_structured_lifecycle_docx_registry_audit_mutation()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
BEGIN RAISE EXCEPTION 'Structured lifecycle DOCX registry audit is append-only'; END;
$$;
CREATE TRIGGER structured_lifecycle_docx_registry_audit_guard
BEFORE UPDATE OR DELETE ON public.structured_lifecycle_docx_registry_audit_events
FOR EACH ROW EXECUTE FUNCTION public.reject_structured_lifecycle_docx_registry_audit_mutation();

CREATE OR REPLACE FUNCTION public.resolve_structured_lifecycle_docx_registry_scope(
  p_project_id uuid, p_document_kind text, p_assignment_id uuid, p_request_key uuid,
  p_template_key text, p_template_version integer, p_template_schema_hash text, p_source_fingerprint text
) RETURNS TABLE(
  assignment_id uuid, project_id uuid, department_id uuid, document_kind text,
  responsible_employee_id uuid, reviewer_employee_id uuid, template_id uuid,
  template_document_revision_id uuid, template_key text, template_version integer,
  template_schema_hash text
) LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_actor uuid := auth.uid(); v_assignment public.structured_lifecycle_docx_responsibility_assignments%ROWTYPE; v_template public.structured_lifecycle_docx_template_pins%ROWTYPE;
BEGIN
  IF v_actor IS NULL OR p_request_key IS NULL OR p_template_schema_hash !~ '^[a-f0-9]{64}$' OR p_source_fingerprint !~ '^[a-f0-9]{64}$' THEN RAISE EXCEPTION 'Authenticated pinned DOCX registry lookup is required'; END IF;
  SELECT * INTO v_assignment FROM public.structured_lifecycle_docx_responsibility_assignments WHERE id=p_assignment_id AND project_id=p_project_id AND document_kind=p_document_kind AND status='ACTIVE' FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Current assigned-person DOCX authority is unavailable'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.employees e JOIN public.employee_departments ed ON ed.employee_id=e.id AND ed.department_id=v_assignment.department_id WHERE e.id IN (v_assignment.responsible_employee_id, v_assignment.reviewer_employee_id) AND e.user_id=v_actor AND e.employment_status='ACTIVE') THEN RAISE EXCEPTION 'Current actor is not an active assigned responsible person'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.project_team_members ptm JOIN public.employees e ON e.id=ptm.employee_id WHERE ptm.project_id=p_project_id AND e.user_id=v_actor AND e.employment_status='ACTIVE') THEN RAISE EXCEPTION 'Project membership is required in addition to assigned-person authority'; END IF;
  SELECT * INTO v_template FROM public.structured_lifecycle_docx_template_pins WHERE department_id=v_assignment.department_id AND document_kind=v_assignment.document_kind AND template_key=p_template_key AND template_version=p_template_version AND template_schema_hash=p_template_schema_hash AND status='APPROVED' FOR UPDATE;
  IF NOT FOUND OR NOT EXISTS (SELECT 1 FROM public.department_process_templates t JOIN public.department_process_template_document_revisions r ON r.id=v_template.template_document_revision_id AND r.template_id=t.id WHERE t.id=v_template.template_id AND t.department_id=v_assignment.department_id AND t.template_key=v_template.template_key AND t.version=v_template.template_version AND t.status='ACTIVE' AND t.active_document_revision_id=v_template.template_document_revision_id) THEN RAISE EXCEPTION 'Current immutable approved template pin is unavailable'; END IF;
  RETURN QUERY SELECT v_assignment.id,v_assignment.project_id,v_assignment.department_id,v_assignment.document_kind,v_assignment.responsible_employee_id,v_assignment.reviewer_employee_id,v_template.template_id,v_template.template_document_revision_id,v_template.template_key,v_template.template_version,v_template.template_schema_hash;
END;
$$;

-- Registry management is limited to the existing lifecycle department-management
-- predicate plus an active project-team member. This deliberately does not treat
-- ordinary project visibility, Sales visibility, or administrator status alone as
-- a document-assignment bypass. The caller is derived from auth.uid(); all entries
-- are request-key replay protected and append immutable audit facts.
CREATE OR REPLACE FUNCTION public.assert_structured_lifecycle_docx_registry_manager(
  p_project_id uuid, p_department_id uuid
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_actor uuid := public.lifecycle_actor();
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.projects project
    JOIN public.project_team_members membership ON membership.project_id = project.id
    JOIN public.employees employee ON employee.id = membership.employee_id
    WHERE project.id = p_project_id AND project.status = 'active'
      AND employee.user_id = v_actor AND employee.employment_status = 'ACTIVE'
  ) THEN RAISE EXCEPTION 'Active project-team membership is required for registry management'; END IF;
  IF NOT public.lifecycle_can_manage_department(v_actor, p_department_id)
     OR NOT public.can_access_department_drive(v_actor, p_department_id, p_project_id) THEN
    RAISE EXCEPTION 'Scoped department document-management authority is required';
  END IF;
  RETURN v_actor;
END;
$$;

CREATE OR REPLACE FUNCTION public.assign_structured_lifecycle_docx_responsibility(
  p_project_id uuid, p_department_id uuid, p_document_kind text, p_responsible_employee_id uuid,
  p_reviewer_employee_id uuid, p_request_key uuid
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_actor uuid; v_existing_audit public.structured_lifecycle_docx_registry_audit_events%ROWTYPE;
  v_existing public.structured_lifecycle_docx_responsibility_assignments%ROWTYPE; v_assignment uuid;
  v_payload_hash text;
BEGIN
  IF p_request_key IS NULL OR p_document_kind NOT IN ('SOR','NDA','COMMERCIAL_QUOTATION','CONTRACT_REVIEW','PRS','BOM','DFMEA','MANUFACTURING_CONTROL_PLAN','DVPR','PDI','COMMERCIAL_TAX_INVOICE','ANNUAL_SKILL_MATRIX')
     OR p_responsible_employee_id IS NULL OR (p_reviewer_employee_id IS NOT NULL AND p_reviewer_employee_id = p_responsible_employee_id) THEN
    RAISE EXCEPTION 'Invalid structured DOCX responsibility assignment payload';
  END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended(concat_ws('|','structured-docx-assignment',p_project_id::text,p_document_kind), 0));
  v_actor := public.assert_structured_lifecycle_docx_registry_manager(p_project_id, p_department_id);
  v_payload_hash := encode(extensions.digest(convert_to(jsonb_build_object('project_id',p_project_id,'department_id',p_department_id,'document_kind',p_document_kind,'responsible_employee_id',p_responsible_employee_id,'reviewer_employee_id',p_reviewer_employee_id)::text, 'UTF8'), 'sha256'), 'hex');
  SELECT * INTO v_existing_audit FROM public.structured_lifecycle_docx_registry_audit_events WHERE actor_user_id=v_actor AND request_key=p_request_key FOR UPDATE;
  IF FOUND THEN
    IF v_existing_audit.action='ASSIGNED' AND v_existing_audit.payload_hash=v_payload_hash THEN RETURN v_existing_audit.assignment_id; END IF;
    RAISE EXCEPTION 'Registry request key conflicts with a different assignment payload';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.employees employee JOIN public.employee_departments membership ON membership.employee_id=employee.id AND membership.department_id=p_department_id WHERE employee.id=p_responsible_employee_id AND employee.employment_status='ACTIVE')
     OR (p_reviewer_employee_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.employees employee JOIN public.employee_departments membership ON membership.employee_id=employee.id AND membership.department_id=p_department_id WHERE employee.id=p_reviewer_employee_id AND employee.employment_status='ACTIVE')) THEN
    RAISE EXCEPTION 'Assigned responsible and reviewer employees must be active department members';
  END IF;
  SELECT * INTO v_existing FROM public.structured_lifecycle_docx_responsibility_assignments WHERE project_id=p_project_id AND document_kind=p_document_kind AND status='ACTIVE' FOR UPDATE;
  IF FOUND THEN RAISE EXCEPTION 'An active structured DOCX responsibility assignment already exists for this project and document kind'; END IF;
  INSERT INTO public.structured_lifecycle_docx_responsibility_assignments(project_id,department_id,document_kind,responsible_employee_id,reviewer_employee_id,assigned_by,created_by)
  VALUES(p_project_id,p_department_id,p_document_kind,p_responsible_employee_id,p_reviewer_employee_id,v_actor,v_actor) RETURNING id INTO v_assignment;
  INSERT INTO public.structured_lifecycle_docx_registry_audit_events(request_key,actor_user_id,action,assignment_id,payload_hash,after_data)
  VALUES(p_request_key,v_actor,'ASSIGNED',v_assignment,v_payload_hash,jsonb_build_object('assignment_id',v_assignment,'project_id',p_project_id,'department_id',p_department_id,'document_kind',p_document_kind,'responsible_employee_id',p_responsible_employee_id,'reviewer_employee_id',p_reviewer_employee_id));
  RETURN v_assignment;
END;
$$;

CREATE OR REPLACE FUNCTION public.revoke_structured_lifecycle_docx_responsibility(p_assignment_id uuid, p_request_key uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_assignment public.structured_lifecycle_docx_responsibility_assignments%ROWTYPE; v_actor uuid;
  v_existing_audit public.structured_lifecycle_docx_registry_audit_events%ROWTYPE; v_payload_hash text;
BEGIN
  IF p_assignment_id IS NULL OR p_request_key IS NULL THEN RAISE EXCEPTION 'Assignment and request key are required'; END IF;
  SELECT * INTO v_assignment FROM public.structured_lifecycle_docx_responsibility_assignments WHERE id=p_assignment_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Structured DOCX responsibility assignment is unavailable'; END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended(concat_ws('|','structured-docx-assignment',v_assignment.project_id::text,v_assignment.document_kind), 0));
  SELECT * INTO v_assignment FROM public.structured_lifecycle_docx_responsibility_assignments WHERE id=p_assignment_id FOR UPDATE;
  v_actor := public.assert_structured_lifecycle_docx_registry_manager(v_assignment.project_id, v_assignment.department_id);
  v_payload_hash := encode(extensions.digest(convert_to(jsonb_build_object('assignment_id',p_assignment_id,'action','REVOKED')::text, 'UTF8'), 'sha256'), 'hex');
  SELECT * INTO v_existing_audit FROM public.structured_lifecycle_docx_registry_audit_events WHERE actor_user_id=v_actor AND request_key=p_request_key FOR UPDATE;
  IF FOUND THEN
    IF v_existing_audit.action='REVOKED' AND v_existing_audit.payload_hash=v_payload_hash THEN RETURN; END IF;
    RAISE EXCEPTION 'Registry request key conflicts with a different revocation payload';
  END IF;
  IF v_assignment.status <> 'ACTIVE' THEN RAISE EXCEPTION 'Only an active structured DOCX responsibility assignment may be revoked'; END IF;
  UPDATE public.structured_lifecycle_docx_responsibility_assignments SET status='REVOKED',revoked_by=v_actor,revoked_at=now() WHERE id=p_assignment_id;
  INSERT INTO public.structured_lifecycle_docx_registry_audit_events(request_key,actor_user_id,action,assignment_id,payload_hash,before_data,after_data)
  VALUES(p_request_key,v_actor,'REVOKED',p_assignment_id,v_payload_hash,jsonb_build_object('status','ACTIVE'),jsonb_build_object('status','REVOKED','assignment_id',p_assignment_id));
END;
$$;

CREATE OR REPLACE FUNCTION public.approve_structured_lifecycle_docx_template_pin(
  p_department_id uuid, p_document_kind text, p_template_id uuid, p_template_document_revision_id uuid,
  p_template_schema_hash text, p_request_key uuid
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_actor uuid := public.lifecycle_actor(); v_template public.department_process_templates%ROWTYPE;
  v_revision public.department_process_template_document_revisions%ROWTYPE; v_existing_audit public.structured_lifecycle_docx_registry_audit_events%ROWTYPE;
  v_existing public.structured_lifecycle_docx_template_pins%ROWTYPE; v_pin uuid; v_payload_hash text;
BEGIN
  IF p_request_key IS NULL OR p_document_kind NOT IN ('SOR','NDA','COMMERCIAL_QUOTATION','CONTRACT_REVIEW','PRS','BOM','DFMEA','MANUFACTURING_CONTROL_PLAN','DVPR','PDI','COMMERCIAL_TAX_INVOICE','ANNUAL_SKILL_MATRIX') OR p_template_schema_hash !~ '^[a-f0-9]{64}$' THEN
    RAISE EXCEPTION 'Invalid structured DOCX template approval payload';
  END IF;
  SELECT * INTO v_template FROM public.department_process_templates WHERE id=p_template_id AND department_id=p_department_id FOR UPDATE;
  IF NOT FOUND OR v_template.status <> 'ACTIVE' OR v_template.active_document_revision_id IS DISTINCT FROM p_template_document_revision_id THEN RAISE EXCEPTION 'Template approval requires the current active immutable template revision'; END IF;
  IF NOT public.lifecycle_can_manage_department(v_actor,p_department_id) OR NOT public.can_access_department_drive(v_actor,p_department_id,NULL) THEN RAISE EXCEPTION 'Scoped department document-management authority is required'; END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended(concat_ws('|','structured-docx-template',p_department_id::text,p_document_kind), 0));
  SELECT * INTO v_revision FROM public.department_process_template_document_revisions WHERE id=p_template_document_revision_id AND template_id=v_template.id FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Template approval requires the exact immutable template revision'; END IF;
  v_payload_hash := encode(extensions.digest(convert_to(jsonb_build_object('department_id',p_department_id,'document_kind',p_document_kind,'template_id',p_template_id,'template_document_revision_id',p_template_document_revision_id,'template_schema_hash',p_template_schema_hash)::text, 'UTF8'), 'sha256'), 'hex');
  SELECT * INTO v_existing_audit FROM public.structured_lifecycle_docx_registry_audit_events WHERE actor_user_id=v_actor AND request_key=p_request_key FOR UPDATE;
  IF FOUND THEN
    IF v_existing_audit.action='TEMPLATE_APPROVED' AND v_existing_audit.payload_hash=v_payload_hash THEN RETURN v_existing_audit.template_pin_id; END IF;
    RAISE EXCEPTION 'Registry request key conflicts with a different template approval payload';
  END IF;
  SELECT * INTO v_existing FROM public.structured_lifecycle_docx_template_pins WHERE department_id=p_department_id AND document_kind=p_document_kind AND status='APPROVED' FOR UPDATE;
  IF FOUND THEN RAISE EXCEPTION 'An approved structured DOCX template already exists for this department and document kind'; END IF;
  INSERT INTO public.structured_lifecycle_docx_template_pins(department_id,document_kind,template_id,template_document_revision_id,template_key,template_version,template_schema_hash,approved_by,request_key,payload_hash,created_by)
  VALUES(p_department_id,p_document_kind,p_template_id,p_template_document_revision_id,v_template.template_key,v_template.version,p_template_schema_hash,v_actor,p_request_key,v_payload_hash,v_actor) RETURNING id INTO v_pin;
  INSERT INTO public.structured_lifecycle_docx_registry_audit_events(request_key,actor_user_id,action,template_pin_id,payload_hash,after_data)
  VALUES(p_request_key,v_actor,'TEMPLATE_APPROVED',v_pin,v_payload_hash,jsonb_build_object('template_pin_id',v_pin,'department_id',p_department_id,'document_kind',p_document_kind,'template_id',p_template_id,'template_document_revision_id',p_template_document_revision_id));
  RETURN v_pin;
END;
$$;

CREATE OR REPLACE FUNCTION public.revoke_structured_lifecycle_docx_template_pin(p_template_pin_id uuid, p_request_key uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_pin public.structured_lifecycle_docx_template_pins%ROWTYPE; v_actor uuid := public.lifecycle_actor();
  v_existing_audit public.structured_lifecycle_docx_registry_audit_events%ROWTYPE; v_payload_hash text;
BEGIN
  IF p_template_pin_id IS NULL OR p_request_key IS NULL THEN RAISE EXCEPTION 'Template pin and request key are required'; END IF;
  SELECT * INTO v_pin FROM public.structured_lifecycle_docx_template_pins WHERE id=p_template_pin_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Structured DOCX template pin is unavailable'; END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended(concat_ws('|','structured-docx-template',v_pin.department_id::text,v_pin.document_kind), 0));
  SELECT * INTO v_pin FROM public.structured_lifecycle_docx_template_pins WHERE id=p_template_pin_id FOR UPDATE;
  IF NOT public.lifecycle_can_manage_department(v_actor,v_pin.department_id) OR NOT public.can_access_department_drive(v_actor,v_pin.department_id,NULL) THEN RAISE EXCEPTION 'Scoped department document-management authority is required'; END IF;
  v_payload_hash := encode(extensions.digest(convert_to(jsonb_build_object('template_pin_id',p_template_pin_id,'action','REVOKED')::text, 'UTF8'), 'sha256'), 'hex');
  SELECT * INTO v_existing_audit FROM public.structured_lifecycle_docx_registry_audit_events WHERE actor_user_id=v_actor AND request_key=p_request_key FOR UPDATE;
  IF FOUND THEN
    IF v_existing_audit.action='TEMPLATE_REVOKED' AND v_existing_audit.payload_hash=v_payload_hash THEN RETURN; END IF;
    RAISE EXCEPTION 'Registry request key conflicts with a different template revocation payload';
  END IF;
  IF v_pin.status <> 'APPROVED' THEN RAISE EXCEPTION 'Only an approved structured DOCX template pin may be revoked'; END IF;
  UPDATE public.structured_lifecycle_docx_template_pins SET status='REVOKED',revoked_by=v_actor,revoked_at=now() WHERE id=p_template_pin_id;
  INSERT INTO public.structured_lifecycle_docx_registry_audit_events(request_key,actor_user_id,action,template_pin_id,payload_hash,before_data,after_data)
  VALUES(p_request_key,v_actor,'TEMPLATE_REVOKED',p_template_pin_id,v_payload_hash,jsonb_build_object('status','APPROVED'),jsonb_build_object('status','REVOKED','template_pin_id',p_template_pin_id));
END;
$$;

REVOKE ALL ON FUNCTION public.resolve_structured_lifecycle_docx_registry_scope(uuid,text,uuid,uuid,text,integer,text,text) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.assign_structured_lifecycle_docx_responsibility(uuid,uuid,text,uuid,uuid,uuid) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.revoke_structured_lifecycle_docx_responsibility(uuid,uuid) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.approve_structured_lifecycle_docx_template_pin(uuid,text,uuid,uuid,text,uuid) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.revoke_structured_lifecycle_docx_template_pin(uuid,uuid) FROM PUBLIC, anon, authenticated, service_role;
