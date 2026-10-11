-- SOURCE-ONLY, UNDEPLOYED PROPOSAL. DO NOT APPLY.
-- This creates a new proposed deviation submission only. It never changes
-- legacy project_change_requests or candidate approvals. Approval, customer
-- approval, expiry/closure transitions, reads, and execution are out of scope.

CREATE TABLE public.project_deviation_submissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid NOT NULL REFERENCES public.projects(id) ON DELETE RESTRICT,
  requirement_baseline_id uuid NOT NULL REFERENCES public.requirement_baselines(id) ON DELETE RESTRICT,
  sales_handover_id uuid NOT NULL REFERENCES public.sales_project_handovers(id) ON DELETE RESTRICT,
  source_document_register_id uuid NOT NULL REFERENCES public.document_control_registers(id) ON DELETE RESTRICT,
  source_document_revision_id uuid NOT NULL REFERENCES public.drive_node_revisions(id) ON DELETE RESTRICT,
  source_document_version integer NOT NULL CHECK (source_document_version > 0),
  status text NOT NULL DEFAULT 'PROPOSED_SUBMITTED' CHECK (status = 'PROPOSED_SUBMITTED'),
  requested_by uuid NOT NULL,
  requested_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.project_deviation_submissions TO service_role;
ALTER TABLE public.project_deviation_submissions ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.project_deviation_submission_revisions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  deviation_submission_id uuid NOT NULL REFERENCES public.project_deviation_submissions(id) ON DELETE RESTRICT,
  revision_number integer NOT NULL CHECK (revision_number = 1),
  payload jsonb NOT NULL CHECK (jsonb_typeof(payload) = 'object'),
  payload_hash text NOT NULL CHECK (btrim(payload_hash) <> ''),
  created_by uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (deviation_submission_id, revision_number),
  UNIQUE (deviation_submission_id, payload_hash)
);
GRANT SELECT ON public.project_deviation_submission_revisions TO service_role;
ALTER TABLE public.project_deviation_submission_revisions ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.project_deviation_submission_evidence (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  deviation_submission_id uuid NOT NULL REFERENCES public.project_deviation_submissions(id) ON DELETE RESTRICT,
  evidence_document_register_id uuid NOT NULL REFERENCES public.document_control_registers(id) ON DELETE RESTRICT,
  evidence_document_revision_id uuid NOT NULL REFERENCES public.drive_node_revisions(id) ON DELETE RESTRICT,
  evidence_document_version integer NOT NULL CHECK (evidence_document_version > 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (deviation_submission_id, evidence_document_revision_id)
);
GRANT SELECT ON public.project_deviation_submission_evidence TO service_role;
ALTER TABLE public.project_deviation_submission_evidence ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.project_deviation_submission_audit_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  deviation_submission_id uuid NOT NULL REFERENCES public.project_deviation_submissions(id) ON DELETE RESTRICT,
  event_type text NOT NULL CHECK (event_type = 'PROPOSED_SUBMITTED'),
  actor_user_id uuid NOT NULL,
  event_data jsonb NOT NULL CHECK (jsonb_typeof(event_data) = 'object'),
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.project_deviation_submission_audit_events TO service_role;
ALTER TABLE public.project_deviation_submission_audit_events ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.project_deviation_submission_request_receipts (
  request_key uuid PRIMARY KEY,
  requested_by uuid NOT NULL,
  action text NOT NULL CHECK (action = 'SUBMIT_PROPOSED_DEVIATION'),
  payload_hash text NOT NULL CHECK (btrim(payload_hash) <> ''),
  deviation_submission_id uuid NOT NULL REFERENCES public.project_deviation_submissions(id) ON DELETE RESTRICT,
  deviation_revision_id uuid NOT NULL REFERENCES public.project_deviation_submission_revisions(id) ON DELETE RESTRICT,
  result jsonb NOT NULL CHECK (jsonb_typeof(result) = 'object'),
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.project_deviation_submission_request_receipts TO service_role;
ALTER TABLE public.project_deviation_submission_request_receipts ENABLE ROW LEVEL SECURITY;

CREATE INDEX project_deviation_submissions_project_idx ON public.project_deviation_submissions(project_id, requested_at DESC);
CREATE INDEX project_deviation_submission_evidence_submission_idx ON public.project_deviation_submission_evidence(deviation_submission_id);

CREATE OR REPLACE FUNCTION public.project_deviation_submission_canonical_payload(p_payload jsonb)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SET search_path = public AS $$
DECLARE
  v_allowed text[] := ARRAY['reason', 'risk', 'safeguards', 'customerImpact', 'affectedPartReference', 'affectedRevisionReference', 'affectedQuantity', 'validFrom', 'validUntil'];
  v_key text; v_has_part_scope boolean; v_has_validity_scope boolean;
BEGIN
  IF jsonb_typeof(p_payload) IS DISTINCT FROM 'object' THEN RAISE EXCEPTION 'Deviation payload must be an object'; END IF;
  IF EXISTS (SELECT 1 FROM jsonb_object_keys(p_payload) AS key WHERE key <> ALL(v_allowed)) THEN RAISE EXCEPTION 'Deviation payload has an unsupported field'; END IF;
  FOREACH v_key IN ARRAY ARRAY['reason', 'risk', 'safeguards'] LOOP
    IF jsonb_typeof(p_payload -> v_key) IS DISTINCT FROM 'string' OR char_length(btrim(p_payload ->> v_key)) NOT BETWEEN 1 AND 2000 THEN RAISE EXCEPTION 'Deviation payload % must be a non-empty string within 2000 characters', v_key; END IF;
  END LOOP;
  IF jsonb_typeof(p_payload -> 'customerImpact') IS DISTINCT FROM 'boolean' THEN RAISE EXCEPTION 'Deviation payload customerImpact must be boolean'; END IF;
  FOREACH v_key IN ARRAY ARRAY['affectedPartReference', 'affectedRevisionReference', 'validFrom', 'validUntil'] LOOP
    IF p_payload ? v_key AND jsonb_typeof(p_payload -> v_key) NOT IN ('string', 'null') THEN RAISE EXCEPTION 'Deviation payload % must be a string or null', v_key; END IF;
    IF jsonb_typeof(p_payload -> v_key) = 'string' AND char_length(btrim(p_payload ->> v_key)) > 512 THEN RAISE EXCEPTION 'Deviation payload % exceeds 512 characters', v_key; END IF;
  END LOOP;
  IF p_payload ? 'affectedQuantity' AND jsonb_typeof(p_payload -> 'affectedQuantity') NOT IN ('number', 'null') THEN RAISE EXCEPTION 'Deviation payload affectedQuantity must be a number or null'; END IF;
  IF jsonb_typeof(p_payload -> 'affectedQuantity') = 'number' AND (p_payload ->> 'affectedQuantity')::numeric <= 0 THEN RAISE EXCEPTION 'Deviation payload affectedQuantity must be positive'; END IF;
  v_has_part_scope := NULLIF(btrim(coalesce(p_payload ->> 'affectedPartReference', '')), '') IS NOT NULL AND NULLIF(btrim(coalesce(p_payload ->> 'affectedRevisionReference', '')), '') IS NOT NULL AND jsonb_typeof(p_payload -> 'affectedQuantity') = 'number';
  v_has_validity_scope := NULLIF(btrim(coalesce(p_payload ->> 'validFrom', '')), '') IS NOT NULL AND NULLIF(btrim(coalesce(p_payload ->> 'validUntil', '')), '') IS NOT NULL;
  IF v_has_part_scope = v_has_validity_scope THEN RAISE EXCEPTION 'Deviation payload requires exactly one affected part scope or validity period'; END IF;
  IF v_has_validity_scope AND (p_payload ->> 'validFrom')::date > (p_payload ->> 'validUntil')::date THEN RAISE EXCEPTION 'Deviation validity period is inverted'; END IF;
  RETURN jsonb_build_object('reason', btrim(p_payload ->> 'reason'), 'risk', btrim(p_payload ->> 'risk'), 'safeguards', btrim(p_payload ->> 'safeguards'), 'customerImpact', (p_payload ->> 'customerImpact')::boolean, 'affectedPartReference', CASE WHEN v_has_part_scope THEN btrim(p_payload ->> 'affectedPartReference') ELSE NULL END, 'affectedRevisionReference', CASE WHEN v_has_part_scope THEN btrim(p_payload ->> 'affectedRevisionReference') ELSE NULL END, 'affectedQuantity', CASE WHEN v_has_part_scope THEN p_payload -> 'affectedQuantity' ELSE 'null'::jsonb END, 'validFrom', CASE WHEN v_has_validity_scope THEN btrim(p_payload ->> 'validFrom') ELSE NULL END, 'validUntil', CASE WHEN v_has_validity_scope THEN btrim(p_payload ->> 'validUntil') ELSE NULL END);
END;
$$;

CREATE OR REPLACE FUNCTION public.project_deviation_submission_canonical_evidence(p_evidence jsonb)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SET search_path = public AS $$
DECLARE v_entry jsonb; v_result jsonb := '[]'::jsonb;
BEGIN
  IF jsonb_typeof(p_evidence) IS DISTINCT FROM 'array' OR jsonb_array_length(p_evidence) = 0 OR jsonb_array_length(p_evidence) > 16 THEN RAISE EXCEPTION 'Deviation evidence must be a non-empty array of at most 16 exact controlled revisions'; END IF;
  FOR v_entry IN SELECT value FROM jsonb_array_elements(p_evidence) LOOP
    IF jsonb_typeof(v_entry) <> 'object' OR (SELECT array_agg(key ORDER BY key) FROM jsonb_object_keys(v_entry) AS key) IS DISTINCT FROM ARRAY['documentRegisterId', 'documentRevisionId'] OR jsonb_typeof(v_entry -> 'documentRegisterId') <> 'string' OR jsonb_typeof(v_entry -> 'documentRevisionId') <> 'string' THEN RAISE EXCEPTION 'Each deviation evidence entry requires only documentRegisterId and documentRevisionId UUID strings'; END IF;
    BEGIN v_result := v_result || jsonb_build_array(jsonb_build_object('documentRegisterId', (v_entry ->> 'documentRegisterId')::uuid, 'documentRevisionId', (v_entry ->> 'documentRevisionId')::uuid)); EXCEPTION WHEN invalid_text_representation THEN RAISE EXCEPTION 'Each deviation evidence entry requires UUID identifiers'; END;
  END LOOP;
  IF jsonb_array_length((SELECT jsonb_agg(DISTINCT value) FROM jsonb_array_elements(v_result) AS value)) <> jsonb_array_length(v_result) THEN RAISE EXCEPTION 'Deviation evidence revisions must be unique'; END IF;
  RETURN (SELECT jsonb_agg(value ORDER BY value::text COLLATE "C") FROM jsonb_array_elements(v_result) AS value);
END;
$$;

CREATE OR REPLACE FUNCTION public.project_deviation_submission_scope(p_actor uuid, p_project_id uuid, p_source_document_register_id uuid, p_source_document_revision_id uuid)
RETURNS TABLE(project_id uuid, baseline_id uuid, handover_id uuid, source_document_register_id uuid, source_document_revision_id uuid, source_document_version integer)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF p_actor IS NULL OR p_project_id IS NULL OR p_source_document_register_id IS NULL OR p_source_document_revision_id IS NULL THEN RAISE EXCEPTION 'Authenticated actor, committed project, and exact controlled source revision are required'; END IF;
  SELECT project.id, baseline.id, handover.id, source_register.id, source_revision.id, source_revision.version INTO project_id, baseline_id, handover_id, source_document_register_id, source_document_revision_id, source_document_version
  FROM public.projects project
  JOIN public.requirement_baselines baseline ON baseline.id = project.requirement_baseline_id
  JOIN public.customer_requirements requirement ON requirement.id = baseline.requirement_id
  JOIN public.sales_project_handovers handover ON handover.baseline_id = baseline.id AND handover.project_id = project.id AND handover.status = 'completed'
  JOIN public.sales_opportunities opportunity ON opportunity.id = project.opportunity_id AND opportunity.id = requirement.opportunity_id AND opportunity.customer_id = project.customer_id AND requirement.customer_id = project.customer_id
  JOIN public.employees manager ON manager.id = project.project_manager_employee_id AND manager.user_id = p_actor AND manager.employment_status = 'ACTIVE'
  JOIN public.project_team_members team ON team.project_id = project.id AND team.employee_id = manager.id
  JOIN public.document_control_registers source_register ON source_register.id = p_source_document_register_id AND source_register.project_id = project.id AND source_register.document_status = 'APPROVED'
  JOIN public.drive_node_revisions source_revision ON source_revision.id = p_source_document_revision_id AND source_revision.node_id = source_register.drive_node_id AND source_revision.version = source_register.controlled_version
  WHERE project.id = p_project_id AND baseline.status = 'project_initiated' AND baseline.approved_by IS NOT NULL AND baseline.approved_at IS NOT NULL
  FOR UPDATE OF project, baseline, handover, source_register, source_revision, manager, team;
  IF NOT FOUND THEN RAISE EXCEPTION 'Deviation submission requires a project-manager team member, an approved project-initiated baseline, a completed exact-project handover, exact customer/opportunity linkage, and an approved project-controlled source revision'; END IF;
  RETURN NEXT;
END;
$$;

CREATE OR REPLACE FUNCTION public.submit_project_deviation(p_project_id uuid, p_source_document_register_id uuid, p_source_document_revision_id uuid, p_payload jsonb, p_evidence jsonb, p_request_key uuid)
RETURNS TABLE(deviation_submission_id uuid, deviation_revision_id uuid, replayed boolean)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_actor uuid := auth.uid(); v_payload jsonb; v_evidence jsonb; v_payload_hash text; v_scope record; v_prior public.project_deviation_submission_request_receipts%ROWTYPE; v_submission public.project_deviation_submissions%ROWTYPE; v_revision public.project_deviation_submission_revisions%ROWTYPE; v_entry jsonb; v_register public.document_control_registers%ROWTYPE; v_source_revision public.drive_node_revisions%ROWTYPE;
BEGIN
  IF v_actor IS NULL OR p_request_key IS NULL THEN RAISE EXCEPTION 'Authenticated actor and request key are required'; END IF;
  v_payload := public.project_deviation_submission_canonical_payload(p_payload); v_evidence := public.project_deviation_submission_canonical_evidence(p_evidence);
  v_payload_hash := md5(jsonb_build_object('projectId', p_project_id, 'sourceDocumentRegisterId', p_source_document_register_id, 'sourceDocumentRevisionId', p_source_document_revision_id, 'payload', v_payload, 'evidence', v_evidence)::text);
  PERFORM pg_advisory_xact_lock(hashtextextended('project-deviation-project:' || p_project_id::text, 0)); PERFORM pg_advisory_xact_lock(hashtextextended('project-deviation-request:' || p_request_key::text, 0));
  SELECT * INTO v_scope FROM public.project_deviation_submission_scope(v_actor, p_project_id, p_source_document_register_id, p_source_document_revision_id);
  SELECT * INTO v_prior FROM public.project_deviation_submission_request_receipts WHERE request_key = p_request_key FOR UPDATE;
  IF FOUND THEN
    SELECT * INTO v_scope FROM public.project_deviation_submission_scope(v_actor, p_project_id, p_source_document_register_id, p_source_document_revision_id);
    IF v_prior.requested_by = v_actor AND v_prior.action = 'SUBMIT_PROPOSED_DEVIATION' AND v_prior.payload_hash = v_payload_hash THEN RETURN QUERY SELECT v_prior.deviation_submission_id, v_prior.deviation_revision_id, true; RETURN; END IF;
    RAISE EXCEPTION 'Request key conflicts with a different actor or canonical payload';
  END IF;
  SELECT * INTO v_scope FROM public.project_deviation_submission_scope(v_actor, p_project_id, p_source_document_register_id, p_source_document_revision_id);
  FOR v_entry IN SELECT value FROM jsonb_array_elements(v_evidence) LOOP
    SELECT * INTO v_register FROM public.document_control_registers WHERE id = (v_entry ->> 'documentRegisterId')::uuid AND project_id = v_scope.project_id AND document_status = 'APPROVED' FOR KEY SHARE;
    SELECT * INTO v_source_revision FROM public.drive_node_revisions WHERE id = (v_entry ->> 'documentRevisionId')::uuid AND node_id = v_register.drive_node_id AND version = v_register.controlled_version FOR KEY SHARE;
    IF NOT FOUND OR v_register.id IS NULL THEN RAISE EXCEPTION 'Deviation evidence requires an approved controlled revision owned by the exact project'; END IF;
  END LOOP;
  INSERT INTO public.project_deviation_submissions(project_id, requirement_baseline_id, sales_handover_id, source_document_register_id, source_document_revision_id, source_document_version, requested_by) VALUES (v_scope.project_id, v_scope.baseline_id, v_scope.handover_id, v_scope.source_document_register_id, v_scope.source_document_revision_id, v_scope.source_document_version, v_actor) RETURNING * INTO v_submission;
  INSERT INTO public.project_deviation_submission_revisions(deviation_submission_id, revision_number, payload, payload_hash, created_by) VALUES (v_submission.id, 1, v_payload, v_payload_hash, v_actor) RETURNING * INTO v_revision;
  FOR v_entry IN SELECT value FROM jsonb_array_elements(v_evidence) LOOP
    SELECT * INTO v_register FROM public.document_control_registers WHERE id = (v_entry ->> 'documentRegisterId')::uuid; SELECT * INTO v_source_revision FROM public.drive_node_revisions WHERE id = (v_entry ->> 'documentRevisionId')::uuid;
    INSERT INTO public.project_deviation_submission_evidence(deviation_submission_id, evidence_document_register_id, evidence_document_revision_id, evidence_document_version) VALUES (v_submission.id, v_register.id, v_source_revision.id, v_source_revision.version);
  END LOOP;
  INSERT INTO public.project_deviation_submission_audit_events(deviation_submission_id, event_type, actor_user_id, event_data) VALUES (v_submission.id, 'PROPOSED_SUBMITTED', v_actor, jsonb_build_object('project_id', v_scope.project_id, 'baseline_id', v_scope.baseline_id, 'handover_id', v_scope.handover_id, 'source_document_register_id', v_scope.source_document_register_id, 'source_document_revision_id', v_scope.source_document_revision_id, 'source_document_version', v_scope.source_document_version, 'payload_hash', v_payload_hash, 'approval_rule', 'responsible_technical_authority_and_quality_plus_customer_when_customer_requirements_affected'));
  INSERT INTO public.project_deviation_submission_request_receipts(request_key, requested_by, action, payload_hash, deviation_submission_id, deviation_revision_id, result) VALUES (p_request_key, v_actor, 'SUBMIT_PROPOSED_DEVIATION', v_payload_hash, v_submission.id, v_revision.id, jsonb_build_object('deviation_submission_id', v_submission.id, 'deviation_revision_id', v_revision.id));
  RETURN QUERY SELECT v_submission.id, v_revision.id, false;
END;
$$;

REVOKE ALL ON FUNCTION public.project_deviation_submission_canonical_payload(jsonb) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.project_deviation_submission_canonical_evidence(jsonb) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.project_deviation_submission_scope(uuid, uuid, uuid, uuid) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.submit_project_deviation(uuid, uuid, uuid, jsonb, jsonb, uuid) FROM PUBLIC, anon, authenticated, service_role;