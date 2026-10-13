-- SOURCE-ONLY, UNDEPLOYED REVIEW CONTRACT. DO NOT EXECUTE.
--
-- Additive optimistic reassignment extension for the frozen structured DOCX
-- registry. It does not alter its five reviewed files, materialize documents,
-- change template pins, create locations, or grant browser access.

ALTER TABLE public.structured_lifecycle_docx_responsibility_assignments
  ADD COLUMN responsibility_revision integer NOT NULL DEFAULT 1 CHECK (responsibility_revision > 0);

CREATE TABLE public.structured_lifecycle_docx_responsibility_update_receipts (
  request_key uuid PRIMARY KEY,
  actor_user_id uuid NOT NULL,
  payload_hash text NOT NULL CHECK (payload_hash ~ '^[a-f0-9]{64}$'),
  previous_assignment_id uuid NOT NULL REFERENCES public.structured_lifecycle_docx_responsibility_assignments(id) ON DELETE RESTRICT,
  replacement_assignment_id uuid NOT NULL REFERENCES public.structured_lifecycle_docx_responsibility_assignments(id) ON DELETE RESTRICT,
  expected_revision integer NOT NULL CHECK (expected_revision > 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (actor_user_id, request_key)
);
GRANT ALL ON public.structured_lifecycle_docx_responsibility_update_receipts TO service_role;
ALTER TABLE public.structured_lifecycle_docx_responsibility_update_receipts ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.structured_lifecycle_docx_responsibility_update_audit_events (
  id uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
  request_key uuid NOT NULL REFERENCES public.structured_lifecycle_docx_responsibility_update_receipts(request_key) ON DELETE RESTRICT,
  actor_user_id uuid NOT NULL,
  previous_assignment_id uuid NOT NULL REFERENCES public.structured_lifecycle_docx_responsibility_assignments(id) ON DELETE RESTRICT,
  replacement_assignment_id uuid NOT NULL REFERENCES public.structured_lifecycle_docx_responsibility_assignments(id) ON DELETE RESTRICT,
  before_data jsonb NOT NULL CHECK (jsonb_typeof(before_data) = 'object'),
  after_data jsonb NOT NULL CHECK (jsonb_typeof(after_data) = 'object'),
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT ALL ON public.structured_lifecycle_docx_responsibility_update_audit_events TO service_role;
ALTER TABLE public.structured_lifecycle_docx_responsibility_update_audit_events ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.reject_structured_lifecycle_docx_responsibility_update_audit_mutation()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
BEGIN RAISE EXCEPTION 'Structured lifecycle DOCX responsibility update audit is append-only'; END;
$$;
CREATE TRIGGER structured_lifecycle_docx_responsibility_update_audit_guard
BEFORE UPDATE OR DELETE ON public.structured_lifecycle_docx_responsibility_update_audit_events
FOR EACH ROW EXECUTE FUNCTION public.reject_structured_lifecycle_docx_responsibility_update_audit_mutation();

CREATE OR REPLACE FUNCTION public.reassign_project_structured_docx_responsibility(
  p_assignment_id uuid, p_expected_revision integer, p_responsible_employee_id uuid,
  p_reviewer_employee_id uuid, p_request_key uuid
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_actor uuid;
  v_previous public.structured_lifecycle_docx_responsibility_assignments%ROWTYPE;
  v_receipt public.structured_lifecycle_docx_responsibility_update_receipts%ROWTYPE;
  v_replacement_id uuid;
  v_payload_hash text;
BEGIN
  IF p_assignment_id IS NULL OR p_expected_revision IS NULL OR p_expected_revision < 1
     OR p_responsible_employee_id IS NULL OR p_request_key IS NULL
     OR (p_reviewer_employee_id IS NOT NULL AND p_reviewer_employee_id = p_responsible_employee_id) THEN
    RAISE EXCEPTION 'Invalid project structured DOCX responsibility reassignment payload';
  END IF;

  SELECT * INTO v_previous
  FROM public.structured_lifecycle_docx_responsibility_assignments
  WHERE id = p_assignment_id;
  IF NOT FOUND OR v_previous.scope_type <> 'PROJECT' THEN
    RAISE EXCEPTION 'Active project structured DOCX responsibility assignment is unavailable';
  END IF;

  v_actor := public.assert_structured_lifecycle_docx_registry_manager(v_previous.project_id, v_previous.department_id);
  v_payload_hash := encode(extensions.digest(convert_to(jsonb_build_object(
    'assignment_id',p_assignment_id,'expected_revision',p_expected_revision,
    'responsible_employee_id',p_responsible_employee_id,'reviewer_employee_id',p_reviewer_employee_id
  )::text,'UTF8'),'sha256'),'hex');
  SELECT * INTO v_receipt
  FROM public.structured_lifecycle_docx_responsibility_update_receipts
  WHERE actor_user_id = v_actor AND request_key = p_request_key
  FOR UPDATE;
  IF FOUND THEN
    IF v_receipt.payload_hash = v_payload_hash THEN RETURN v_receipt.replacement_assignment_id; END IF;
    RAISE EXCEPTION 'Responsibility reassignment request key conflicts with a different payload';
  END IF;

  SELECT * INTO v_previous
  FROM public.structured_lifecycle_docx_responsibility_assignments
  WHERE id = p_assignment_id;
  PERFORM pg_advisory_xact_lock(hashtextextended(concat_ws('|','structured-docx-assignment',v_previous.project_id::text,v_previous.document_kind),0));
  SELECT * INTO v_previous
  FROM public.structured_lifecycle_docx_responsibility_assignments
  WHERE id = p_assignment_id
  FOR UPDATE;
  IF NOT FOUND OR v_previous.scope_type <> 'PROJECT' OR v_previous.status <> 'ACTIVE' THEN
    RAISE EXCEPTION 'Active project structured DOCX responsibility assignment is unavailable';
  END IF;

  IF v_previous.responsibility_revision <> p_expected_revision THEN
    RAISE EXCEPTION 'Project structured DOCX responsibility revision is stale';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.employees employee
    JOIN public.employee_departments membership ON membership.employee_id = employee.id
      AND membership.department_id = v_previous.department_id
    JOIN public.project_team_members team_membership ON team_membership.employee_id = employee.id
      AND team_membership.project_id = v_previous.project_id
    WHERE employee.id = p_responsible_employee_id AND employee.employment_status = 'ACTIVE'
  ) OR (p_reviewer_employee_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.employees employee
    JOIN public.employee_departments membership ON membership.employee_id = employee.id
      AND membership.department_id = v_previous.department_id
    JOIN public.project_team_members team_membership ON team_membership.employee_id = employee.id
      AND team_membership.project_id = v_previous.project_id
    WHERE employee.id = p_reviewer_employee_id AND employee.employment_status = 'ACTIVE'
  )) THEN
    RAISE EXCEPTION 'Assigned responsible and reviewer employees must be active department project-team members';
  END IF;

  UPDATE public.structured_lifecycle_docx_responsibility_assignments
  SET status = 'REVOKED', revoked_by = v_actor, revoked_at = now()
  WHERE id = v_previous.id;
  INSERT INTO public.structured_lifecycle_docx_responsibility_assignments(
    scope_type, project_id, department_id, document_kind, responsible_employee_id,
    reviewer_employee_id, responsibility_revision, assigned_by, created_by
  ) VALUES (
    'PROJECT', v_previous.project_id, v_previous.department_id, v_previous.document_kind,
    p_responsible_employee_id, p_reviewer_employee_id, v_previous.responsibility_revision + 1,
    v_actor, v_actor
  ) RETURNING id INTO v_replacement_id;
  INSERT INTO public.structured_lifecycle_docx_responsibility_update_receipts(
    request_key, actor_user_id, payload_hash, previous_assignment_id,
    replacement_assignment_id, expected_revision
  ) VALUES (
    p_request_key, v_actor, v_payload_hash, v_previous.id,
    v_replacement_id, p_expected_revision
  );
  INSERT INTO public.structured_lifecycle_docx_responsibility_update_audit_events(
    request_key, actor_user_id, previous_assignment_id, replacement_assignment_id,
    before_data, after_data
  ) VALUES (
    p_request_key, v_actor, v_previous.id, v_replacement_id,
    jsonb_build_object('status','ACTIVE','responsibility_revision',v_previous.responsibility_revision,'responsible_employee_id',v_previous.responsible_employee_id,'reviewer_employee_id',v_previous.reviewer_employee_id),
    jsonb_build_object('status','ACTIVE','responsibility_revision',v_previous.responsibility_revision + 1,'responsible_employee_id',p_responsible_employee_id,'reviewer_employee_id',p_reviewer_employee_id)
  );
  RETURN v_replacement_id;
END;
$$;

REVOKE ALL ON FUNCTION public.reassign_project_structured_docx_responsibility(uuid,integer,uuid,uuid,uuid) FROM PUBLIC, anon, authenticated, service_role;