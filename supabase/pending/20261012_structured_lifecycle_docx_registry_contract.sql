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

-- Assignment/template management requires a separately accepted scoped authority
-- mapping. These stubs intentionally remain unavailable; no default department,
-- Sales, Operations, or administrator bypass is created by this proposal.
CREATE OR REPLACE FUNCTION public.assign_structured_lifecycle_docx_responsibility(
  p_project_id uuid, p_department_id uuid, p_document_kind text, p_responsible_employee_id uuid,
  p_reviewer_employee_id uuid, p_request_key uuid
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN RAISE EXCEPTION 'Structured lifecycle DOCX assignment management requires separately accepted authority mapping'; END;
$$;
CREATE OR REPLACE FUNCTION public.revoke_structured_lifecycle_docx_responsibility(p_assignment_id uuid, p_request_key uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN RAISE EXCEPTION 'Structured lifecycle DOCX assignment management requires separately accepted authority mapping'; END;
$$;
CREATE OR REPLACE FUNCTION public.approve_structured_lifecycle_docx_template_pin(
  p_department_id uuid, p_document_kind text, p_template_id uuid, p_template_document_revision_id uuid,
  p_template_schema_hash text, p_request_key uuid
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN RAISE EXCEPTION 'Structured lifecycle DOCX template approval requires separately accepted authority mapping'; END;
$$;
CREATE OR REPLACE FUNCTION public.revoke_structured_lifecycle_docx_template_pin(p_template_pin_id uuid, p_request_key uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN RAISE EXCEPTION 'Structured lifecycle DOCX template approval requires separately accepted authority mapping'; END;
$$;

REVOKE ALL ON FUNCTION public.resolve_structured_lifecycle_docx_registry_scope(uuid,text,uuid,uuid,text,integer,text,text) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.assign_structured_lifecycle_docx_responsibility(uuid,uuid,text,uuid,uuid,uuid) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.revoke_structured_lifecycle_docx_responsibility(uuid,uuid) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.approve_structured_lifecycle_docx_template_pin(uuid,text,uuid,uuid,text,uuid) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.revoke_structured_lifecycle_docx_template_pin(uuid,uuid) FROM PUBLIC, anon, authenticated, service_role;
