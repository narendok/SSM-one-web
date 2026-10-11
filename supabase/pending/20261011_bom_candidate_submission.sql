-- SOURCE-ONLY, UNDEPLOYED PROPOSAL. DO NOT APPLY.
-- Candidate submission only. This file does not alter components, inventory,
-- locations, project BOM rows, substitutes, provenance, Sales records, or any
-- existing grants, RLS policies, identities, memberships, or permissions.
-- No EXECUTE permission is granted for the protected function below.

CREATE TABLE public.component_candidate_submissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid NOT NULL REFERENCES public.projects(id) ON DELETE RESTRICT,
  project_bom_id uuid NOT NULL REFERENCES public.project_boms(id) ON DELETE RESTRICT,
  requirement_baseline_id uuid NOT NULL REFERENCES public.requirement_baselines(id) ON DELETE RESTRICT,
  sales_handover_id uuid NOT NULL REFERENCES public.sales_project_handovers(id) ON DELETE RESTRICT,
  opportunity_id uuid NOT NULL REFERENCES public.sales_opportunities(id) ON DELETE RESTRICT,
  customer_id uuid NOT NULL REFERENCES public.customers(id) ON DELETE RESTRICT,
  hardware_department_id uuid NOT NULL REFERENCES public.departments(id) ON DELETE RESTRICT,
  status text NOT NULL DEFAULT 'SUBMITTED' CHECK (status = 'SUBMITTED'),
  submitted_by uuid NOT NULL,
  submitted_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.component_candidate_submissions TO service_role;
ALTER TABLE public.component_candidate_submissions ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.component_candidate_payload_revisions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  candidate_id uuid NOT NULL REFERENCES public.component_candidate_submissions(id) ON DELETE RESTRICT,
  revision_number integer NOT NULL CHECK (revision_number = 1),
  payload jsonb NOT NULL CHECK (jsonb_typeof(payload) = 'object'),
  payload_hash text NOT NULL CHECK (btrim(payload_hash) <> ''),
  created_by uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (candidate_id, revision_number),
  UNIQUE (candidate_id, payload_hash)
);
GRANT SELECT ON public.component_candidate_payload_revisions TO service_role;
ALTER TABLE public.component_candidate_payload_revisions ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.component_candidate_submission_audit_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  candidate_id uuid NOT NULL REFERENCES public.component_candidate_submissions(id) ON DELETE RESTRICT,
  candidate_revision_number integer NOT NULL CHECK (candidate_revision_number = 1),
  event_type text NOT NULL CHECK (event_type = 'SUBMITTED'),
  actor_user_id uuid NOT NULL,
  event_data jsonb NOT NULL CHECK (jsonb_typeof(event_data) = 'object'),
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.component_candidate_submission_audit_events TO service_role;
ALTER TABLE public.component_candidate_submission_audit_events ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.component_candidate_submission_request_receipts (
  request_key uuid PRIMARY KEY,
  requested_by uuid NOT NULL,
  action text NOT NULL CHECK (action = 'SUBMIT'),
  payload_hash text NOT NULL CHECK (btrim(payload_hash) <> ''),
  candidate_id uuid NOT NULL REFERENCES public.component_candidate_submissions(id) ON DELETE RESTRICT,
  payload_revision_id uuid NOT NULL REFERENCES public.component_candidate_payload_revisions(id) ON DELETE RESTRICT,
  result jsonb NOT NULL CHECK (jsonb_typeof(result) = 'object'),
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.component_candidate_submission_request_receipts TO service_role;
ALTER TABLE public.component_candidate_submission_request_receipts ENABLE ROW LEVEL SECURITY;

CREATE INDEX component_candidate_submissions_project_idx
  ON public.component_candidate_submissions(project_id, submitted_at DESC);
CREATE INDEX component_candidate_submission_audit_candidate_idx
  ON public.component_candidate_submission_audit_events(candidate_id, created_at);

CREATE OR REPLACE FUNCTION public.component_candidate_submission_canonical_payload(p_payload jsonb)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SET search_path = public AS $$
DECLARE
  v_allowed text[] := ARRAY['categoryId', 'name', 'partNumber', 'manufacturer', 'footprint', 'bomCompatibility', 'voltageRating', 'currentRating', 'temperatureRating', 'cost', 'supplier', 'supplierUrl', 'datasheetUrl', 'notes'];
  v_required text[] := ARRAY['categoryId', 'name', 'partNumber'];
  v_key text; v_text text;
BEGIN
  IF jsonb_typeof(p_payload) IS DISTINCT FROM 'object' THEN RAISE EXCEPTION 'Candidate payload must be an object'; END IF;
  IF EXISTS (SELECT 1 FROM jsonb_object_keys(p_payload) AS key WHERE key <> ALL(v_allowed)) THEN RAISE EXCEPTION 'Candidate payload has an unsupported field'; END IF;
  FOREACH v_key IN ARRAY v_required LOOP
    IF jsonb_typeof(p_payload -> v_key) IS DISTINCT FROM 'string' OR btrim(p_payload ->> v_key) = '' THEN
      RAISE EXCEPTION 'Candidate payload requires a non-empty %', v_key;
    END IF;
  END LOOP;
  FOREACH v_key IN ARRAY v_allowed LOOP
    IF v_key = 'cost' THEN
      IF p_payload ? v_key AND jsonb_typeof(p_payload -> v_key) NOT IN ('number', 'null') THEN RAISE EXCEPTION 'Candidate payload cost must be a number or null'; END IF;
      IF jsonb_typeof(p_payload -> v_key) = 'number' AND (p_payload ->> v_key)::numeric < 0 THEN RAISE EXCEPTION 'Candidate payload cost cannot be negative'; END IF;
    ELSIF p_payload ? v_key AND jsonb_typeof(p_payload -> v_key) NOT IN ('string', 'null') THEN
      RAISE EXCEPTION 'Candidate payload field % must be a string or null', v_key;
    END IF;
  END LOOP;
  RETURN jsonb_build_object(
    'categoryId', btrim(p_payload ->> 'categoryId'), 'name', regexp_replace(btrim(p_payload ->> 'name'), '\s+', ' ', 'g'),
    'partNumber', regexp_replace(btrim(p_payload ->> 'partNumber'), '\s+', ' ', 'g'),
    'manufacturer', NULLIF(regexp_replace(btrim(coalesce(p_payload ->> 'manufacturer', '')), '\s+', ' ', 'g'), ''),
    'footprint', NULLIF(btrim(coalesce(p_payload ->> 'footprint', '')), ''),
    'bomCompatibility', NULLIF(btrim(coalesce(p_payload ->> 'bomCompatibility', '')), ''),
    'voltageRating', NULLIF(btrim(coalesce(p_payload ->> 'voltageRating', '')), ''),
    'currentRating', NULLIF(btrim(coalesce(p_payload ->> 'currentRating', '')), ''),
    'temperatureRating', NULLIF(btrim(coalesce(p_payload ->> 'temperatureRating', '')), ''),
    'cost', CASE WHEN jsonb_typeof(p_payload -> 'cost') = 'number' THEN p_payload -> 'cost' ELSE 'null'::jsonb END,
    'supplier', NULLIF(regexp_replace(btrim(coalesce(p_payload ->> 'supplier', '')), '\s+', ' ', 'g'), ''),
    'supplierUrl', NULLIF(btrim(coalesce(p_payload ->> 'supplierUrl', '')), ''),
    'datasheetUrl', NULLIF(btrim(coalesce(p_payload ->> 'datasheetUrl', '')), ''),
    'notes', NULLIF(btrim(coalesce(p_payload ->> 'notes', '')), '')
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.component_candidate_submission_scope(
  p_actor uuid, p_project_id uuid, p_project_bom_id uuid
) RETURNS TABLE (
  project_id uuid, project_bom_id uuid, baseline_id uuid, handover_id uuid,
  opportunity_id uuid, customer_id uuid, hardware_department_id uuid
) LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF p_actor IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;
  SELECT project.id, bom.id, baseline.id, handover.id, opportunity.id, customer.id, hardware.id
  INTO project_id, project_bom_id, baseline_id, handover_id, opportunity_id, customer_id, hardware_department_id
  FROM public.projects project
  JOIN public.project_boms bom ON bom.id = p_project_bom_id AND bom.project_id = project.id
  JOIN public.requirement_baselines baseline ON baseline.id = project.requirement_baseline_id
  JOIN public.customer_requirements requirement ON requirement.id = baseline.requirement_id
  JOIN public.sales_project_handovers handover ON handover.baseline_id = baseline.id AND handover.project_id = project.id AND handover.status = 'completed'
  JOIN public.sales_opportunities opportunity ON opportunity.id = project.opportunity_id AND opportunity.id = requirement.opportunity_id AND opportunity.customer_id = project.customer_id AND opportunity.customer_id = requirement.customer_id
  JOIN public.customers customer ON customer.id = project.customer_id
  JOIN public.employees manager ON manager.id = project.project_manager_employee_id AND manager.user_id = p_actor AND manager.employment_status = 'ACTIVE'
  JOIN public.project_team_members team ON team.project_id = project.id AND team.employee_id = manager.id
  JOIN public.departments hardware ON hardware.code = 'HARDWARE' AND hardware.is_active
  WHERE project.id = p_project_id
    AND baseline.status = 'project_initiated'
    AND baseline.approved_by IS NOT NULL
    AND baseline.approved_at IS NOT NULL
  FOR UPDATE OF project, bom, baseline, handover, opportunity, customer, manager, team, hardware;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Candidate submission requires a project-manager team member, an approved project-initiated baseline, a completed exact-project handover, exact customer/opportunity linkage, and an active HARDWARE department';
  END IF;
  RETURN NEXT;
END;
$$;

CREATE OR REPLACE FUNCTION public.submit_component_candidate(
  p_project_id uuid, p_project_bom_id uuid, p_payload jsonb, p_request_key uuid
) RETURNS TABLE(candidate_id uuid, payload_revision_id uuid, replayed boolean)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_actor uuid := auth.uid(); v_payload jsonb; v_payload_hash text;
  v_scope record; v_prior public.component_candidate_submission_request_receipts%ROWTYPE;
  v_candidate public.component_candidate_submissions%ROWTYPE; v_revision public.component_candidate_payload_revisions%ROWTYPE;
BEGIN
  IF v_actor IS NULL OR p_project_id IS NULL OR p_project_bom_id IS NULL OR p_request_key IS NULL THEN
    RAISE EXCEPTION 'Authenticated actor, project, BOM, and request key are required';
  END IF;
  v_payload := public.component_candidate_submission_canonical_payload(p_payload);
  v_payload_hash := md5(jsonb_build_object('projectId', p_project_id, 'projectBomId', p_project_bom_id, 'payload', v_payload)::text);
  PERFORM pg_advisory_xact_lock(hashtextextended('component-candidate-project:' || p_project_id::text, 0));
  PERFORM pg_advisory_xact_lock(hashtextextended('component-candidate-request:' || p_request_key::text, 0));
  SELECT * INTO v_scope FROM public.component_candidate_submission_scope(v_actor, p_project_id, p_project_bom_id);
  SELECT * INTO v_prior FROM public.component_candidate_submission_request_receipts WHERE request_key = p_request_key FOR UPDATE;
  IF FOUND THEN
    SELECT * INTO v_scope FROM public.component_candidate_submission_scope(v_actor, p_project_id, p_project_bom_id);
    IF v_prior.requested_by = v_actor AND v_prior.action = 'SUBMIT' AND v_prior.payload_hash = v_payload_hash THEN
      RETURN QUERY SELECT v_prior.candidate_id, v_prior.payload_revision_id, true;
      RETURN;
    END IF;
    RAISE EXCEPTION 'Request key conflicts with a different actor or canonical payload';
  END IF;
  -- Re-authorize after both advisory waits and before every write.
  SELECT * INTO v_scope FROM public.component_candidate_submission_scope(v_actor, p_project_id, p_project_bom_id);
  INSERT INTO public.component_candidate_submissions(project_id, project_bom_id, requirement_baseline_id, sales_handover_id, opportunity_id, customer_id, hardware_department_id, submitted_by)
  VALUES (v_scope.project_id, v_scope.project_bom_id, v_scope.baseline_id, v_scope.handover_id, v_scope.opportunity_id, v_scope.customer_id, v_scope.hardware_department_id, v_actor)
  RETURNING * INTO v_candidate;
  INSERT INTO public.component_candidate_payload_revisions(candidate_id, revision_number, payload, payload_hash, created_by)
  VALUES (v_candidate.id, 1, v_payload, v_payload_hash, v_actor) RETURNING * INTO v_revision;
  INSERT INTO public.component_candidate_submission_audit_events(candidate_id, candidate_revision_number, event_type, actor_user_id, event_data)
  VALUES (v_candidate.id, 1, 'SUBMITTED', v_actor, jsonb_build_object('project_id', v_scope.project_id, 'project_bom_id', v_scope.project_bom_id, 'baseline_id', v_scope.baseline_id, 'handover_id', v_scope.handover_id, 'opportunity_id', v_scope.opportunity_id, 'customer_id', v_scope.customer_id, 'hardware_department_id', v_scope.hardware_department_id, 'payload_hash', v_payload_hash));
  INSERT INTO public.component_candidate_submission_request_receipts(request_key, requested_by, action, payload_hash, candidate_id, payload_revision_id, result)
  VALUES (p_request_key, v_actor, 'SUBMIT', v_payload_hash, v_candidate.id, v_revision.id, jsonb_build_object('candidate_id', v_candidate.id, 'payload_revision_id', v_revision.id));
  RETURN QUERY SELECT v_candidate.id, v_revision.id, false;
END;
$$;

REVOKE ALL ON FUNCTION public.component_candidate_submission_scope(uuid, uuid, uuid) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.submit_component_candidate(uuid, uuid, jsonb, uuid) FROM PUBLIC, anon, authenticated, service_role;