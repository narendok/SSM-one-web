-- SOURCE-ONLY, UNDEPLOYED REVIEW CONTRACT. DO NOT APPLY.
--
-- Inspected deployed prerequisites:
--   * public.projects.project_manager_employee_id and public.project_team_members
--   * public.project_boms.revision plus public.project_bom_items
--   * public.components as the authoritative existing-component catalog
--   * public.employees / employee_departments / departments and public.has_permission
--
-- This additive contract records a request-scoped immutable BOM/parts snapshot
-- and separate Procurement analysis. It deliberately never writes project_boms,
-- project_bom_items, components, inventory, purchase requests, RFQs, quotations,
-- purchase orders, stock, or release/approval state. It does not create a part.
-- A new-part row is only a Procurement-review subject.

CREATE TABLE public.project_bom_procurement_review_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid NOT NULL REFERENCES public.projects(id) ON DELETE RESTRICT,
  project_bom_id uuid NOT NULL REFERENCES public.project_boms(id) ON DELETE RESTRICT,
  pinned_bom_number text NOT NULL,
  pinned_bom_revision text NULL,
  pinned_bom_updated_at timestamptz NOT NULL,
  status text NOT NULL DEFAULT 'PENDING_PROCUREMENT_ANALYSIS'
    CHECK (status IN ('PENDING_PROCUREMENT_ANALYSIS', 'ALLOWED_PENDING_HARDWARE_SELECTION', 'DENIED')),
  submitted_by uuid NOT NULL,
  submitted_at timestamptz NOT NULL DEFAULT now(),
  decided_by uuid NULL,
  decided_at timestamptz NULL,
  decision_note text NULL,
  CHECK (
    (status = 'PENDING_PROCUREMENT_ANALYSIS' AND decided_by IS NULL AND decided_at IS NULL AND decision_note IS NULL)
    OR (status IN ('ALLOWED_PENDING_HARDWARE_SELECTION', 'DENIED')
      AND decided_by IS NOT NULL AND decided_at IS NOT NULL
      AND char_length(btrim(decision_note)) BETWEEN 1 AND 500)
  )
);
GRANT ALL ON public.project_bom_procurement_review_requests TO service_role;
ALTER TABLE public.project_bom_procurement_review_requests ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.project_bom_procurement_review_request_lines (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id uuid NOT NULL REFERENCES public.project_bom_procurement_review_requests(id) ON DELETE RESTRICT,
  line_number integer NOT NULL CHECK (line_number > 0),
  source_kind text NOT NULL CHECK (source_kind IN ('EXISTING_COMPONENT', 'NEW_PART')),
  source_bom_item_id uuid NULL REFERENCES public.project_bom_items(id) ON DELETE RESTRICT,
  component_id uuid NULL REFERENCES public.components(id) ON DELETE RESTRICT,
  authoritative_mpn text NOT NULL,
  authoritative_manufacturer text NULL,
  description text NOT NULL,
  reference_designators text NOT NULL,
  quantity numeric NOT NULL CHECK (quantity > 0),
  manual_note text NULL,
  CHECK (
    (source_kind = 'EXISTING_COMPONENT' AND component_id IS NOT NULL)
    OR (source_kind = 'NEW_PART' AND component_id IS NULL)
  ),
  UNIQUE (request_id, line_number)
);
GRANT ALL ON public.project_bom_procurement_review_request_lines TO service_role;
ALTER TABLE public.project_bom_procurement_review_request_lines ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.project_bom_procurement_review_analyses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_line_id uuid NOT NULL REFERENCES public.project_bom_procurement_review_request_lines(id) ON DELETE RESTRICT,
  analysis_revision integer NOT NULL CHECK (analysis_revision > 0),
  availability_state text NOT NULL CHECK (availability_state IN ('PENDING', 'AVAILABLE', 'UNAVAILABLE', 'TBC')),
  cost_state text NOT NULL CHECK (cost_state IN ('PENDING', 'AVAILABLE', 'UNAVAILABLE', 'TBC')),
  sourcing_state text NOT NULL CHECK (sourcing_state IN ('PENDING', 'AVAILABLE', 'UNAVAILABLE', 'TBC')),
  observed_unit_cost numeric NULL CHECK (observed_unit_cost >= 0),
  currency text NULL CHECK (currency IS NULL OR char_length(btrim(currency)) BETWEEN 3 AND 12),
  supplier_name text NULL,
  lead_time_days integer NULL CHECK (lead_time_days >= 0),
  alternate_component_id uuid NULL REFERENCES public.components(id) ON DELETE RESTRICT,
  analysis_note text NOT NULL CHECK (char_length(btrim(analysis_note)) BETWEEN 1 AND 1000),
  analyzed_by uuid NOT NULL,
  analyzed_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (request_line_id, analysis_revision)
);
GRANT ALL ON public.project_bom_procurement_review_analyses TO service_role;
ALTER TABLE public.project_bom_procurement_review_analyses ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.project_bom_procurement_review_receipts (
  request_key uuid PRIMARY KEY,
  requested_by uuid NOT NULL,
  action text NOT NULL CHECK (action IN ('SUBMIT', 'ANALYZE', 'ALLOW', 'DENY')),
  request_id uuid NOT NULL REFERENCES public.project_bom_procurement_review_requests(id) ON DELETE RESTRICT,
  request_line_id uuid NULL REFERENCES public.project_bom_procurement_review_request_lines(id) ON DELETE RESTRICT,
  payload_hash text NOT NULL CHECK (btrim(payload_hash) <> ''),
  result jsonb NOT NULL CHECK (jsonb_typeof(result) = 'object'),
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT ALL ON public.project_bom_procurement_review_receipts TO service_role;
ALTER TABLE public.project_bom_procurement_review_receipts ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.project_bom_procurement_review_audit_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id uuid NOT NULL REFERENCES public.project_bom_procurement_review_requests(id) ON DELETE RESTRICT,
  request_line_id uuid NULL REFERENCES public.project_bom_procurement_review_request_lines(id) ON DELETE RESTRICT,
  event_type text NOT NULL CHECK (event_type IN ('SUBMITTED', 'ANALYZED', 'ALLOWED_PENDING_HARDWARE_SELECTION', 'DENIED')),
  actor_user_id uuid NOT NULL,
  event_data jsonb NOT NULL CHECK (jsonb_typeof(event_data) = 'object'),
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT ALL ON public.project_bom_procurement_review_audit_events TO service_role;
ALTER TABLE public.project_bom_procurement_review_audit_events ENABLE ROW LEVEL SECURITY;

CREATE INDEX project_bom_procurement_review_requests_project_idx
  ON public.project_bom_procurement_review_requests(project_id, submitted_at DESC);
CREATE INDEX project_bom_procurement_review_lines_request_idx
  ON public.project_bom_procurement_review_request_lines(request_id, line_number);
CREATE INDEX project_bom_procurement_review_analyses_line_idx
  ON public.project_bom_procurement_review_analyses(request_line_id, analysis_revision DESC);

CREATE OR REPLACE FUNCTION public.project_bom_procurement_review_canonical_decision_analyses(p_analysis_revisions jsonb)
RETURNS jsonb
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public
AS $$
DECLARE v_item jsonb; v_out jsonb := '[]'::jsonb; v_line_id uuid; v_revision integer;
BEGIN
  IF jsonb_typeof(p_analysis_revisions) IS DISTINCT FROM 'array' OR jsonb_array_length(p_analysis_revisions) > 500 THEN RAISE EXCEPTION 'Reviewed analysis revisions must be an array of at most 500 lines'; END IF;
  FOR v_item IN SELECT value FROM jsonb_array_elements(p_analysis_revisions) AS rows(value) LOOP
    IF jsonb_typeof(v_item) IS DISTINCT FROM 'object' OR EXISTS (SELECT 1 FROM jsonb_object_keys(v_item) AS key WHERE key NOT IN ('requestLineId', 'analysisRevision')) OR jsonb_typeof(v_item -> 'requestLineId') IS DISTINCT FROM 'string' OR jsonb_typeof(v_item -> 'analysisRevision') IS DISTINCT FROM 'number' THEN RAISE EXCEPTION 'Each reviewed analysis revision requires only requestLineId and analysisRevision'; END IF;
    v_line_id := (v_item ->> 'requestLineId')::uuid; v_revision := (v_item ->> 'analysisRevision')::integer;
    IF v_revision <= 0 THEN RAISE EXCEPTION 'Reviewed analysis revisions must be positive'; END IF;
    v_out := v_out || jsonb_build_array(jsonb_build_object('requestLineId', v_line_id, 'analysisRevision', v_revision));
  END LOOP;
  SELECT coalesce(jsonb_agg(item ORDER BY item ->> 'requestLineId'), '[]'::jsonb) INTO v_out FROM jsonb_array_elements(v_out) AS values(item);
  IF (SELECT count(*) FROM jsonb_array_elements(v_out)) <> (SELECT count(DISTINCT value ->> 'requestLineId') FROM jsonb_array_elements(v_out) AS values(value)) THEN RAISE EXCEPTION 'Reviewed analysis revisions contain a duplicate line'; END IF;
  RETURN v_out;
END;
$$;

CREATE OR REPLACE FUNCTION public.project_bom_procurement_review_canonical_submission(
  p_rows jsonb
) RETURNS jsonb
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public
AS $$
DECLARE
  v_item jsonb;
  v_out jsonb := '[]'::jsonb;
  v_allowed text[] := ARRAY['sourceBomItemId', 'kind', 'componentId', 'mpn', 'manufacturer', 'description', 'referenceDesignators', 'quantity', 'manualNote'];
  v_key text;
  v_position integer := 0;
  v_kind text;
  v_quantity numeric;
BEGIN
  IF jsonb_typeof(p_rows) IS DISTINCT FROM 'array' OR jsonb_array_length(p_rows) = 0 OR jsonb_array_length(p_rows) > 500 THEN
    RAISE EXCEPTION 'Procurement submission requires 1 to 500 rows';
  END IF;
  FOR v_item IN SELECT value FROM jsonb_array_elements(p_rows) AS rows(value) LOOP
    v_position := v_position + 1;
    IF jsonb_typeof(v_item) IS DISTINCT FROM 'object' THEN RAISE EXCEPTION 'Procurement row % must be an object', v_position; END IF;
    IF EXISTS (SELECT 1 FROM jsonb_object_keys(v_item) AS key WHERE key <> ALL(v_allowed)) THEN
      RAISE EXCEPTION 'Procurement row % has an unsupported field', v_position;
    END IF;
    v_kind := lower(btrim(coalesce(v_item ->> 'kind', '')));
    IF v_kind NOT IN ('existing', 'new') THEN RAISE EXCEPTION 'Procurement row % has an invalid kind', v_position; END IF;
    IF jsonb_typeof(v_item -> 'quantity') IS DISTINCT FROM 'number' THEN RAISE EXCEPTION 'Procurement row % quantity must be numeric', v_position; END IF;
    v_quantity := (v_item ->> 'quantity')::numeric;
    IF v_quantity <= 0 THEN RAISE EXCEPTION 'Procurement row % quantity must be positive', v_position; END IF;
    IF jsonb_typeof(v_item -> 'referenceDesignators') IS DISTINCT FROM 'string' OR char_length(btrim(v_item ->> 'referenceDesignators')) NOT BETWEEN 1 AND 500 THEN
      RAISE EXCEPTION 'Procurement row % requires reference designators', v_position;
    END IF;
    IF v_kind = 'existing' THEN
      IF jsonb_typeof(v_item -> 'componentId') IS DISTINCT FROM 'string' OR nullif(btrim(v_item ->> 'componentId'), '') IS NULL THEN
        RAISE EXCEPTION 'Existing Procurement row % requires componentId', v_position;
      END IF;
      IF v_item ? 'mpn' OR v_item ? 'manufacturer' OR v_item ? 'description' THEN
        RAISE EXCEPTION 'Existing Procurement row % cannot supply derived catalog fields', v_position;
      END IF;
    ELSE
      IF v_item ? 'componentId' OR v_item ? 'sourceBomItemId' THEN RAISE EXCEPTION 'New Procurement row % cannot supply an existing identifier', v_position; END IF;
      IF jsonb_typeof(v_item -> 'mpn') IS DISTINCT FROM 'string' OR char_length(btrim(v_item ->> 'mpn')) NOT BETWEEN 1 AND 200 THEN RAISE EXCEPTION 'New Procurement row % requires MPN', v_position; END IF;
      IF jsonb_typeof(v_item -> 'description') IS DISTINCT FROM 'string' OR char_length(btrim(v_item ->> 'description')) NOT BETWEEN 1 AND 500 THEN RAISE EXCEPTION 'New Procurement row % requires description', v_position; END IF;
    END IF;
    IF v_item ? 'manualNote' AND jsonb_typeof(v_item -> 'manualNote') NOT IN ('string', 'null') THEN RAISE EXCEPTION 'Procurement row % manualNote must be text or null', v_position; END IF;
    IF v_item ? 'manufacturer' AND jsonb_typeof(v_item -> 'manufacturer') NOT IN ('string', 'null') THEN RAISE EXCEPTION 'Procurement row % manufacturer must be text or null', v_position; END IF;
    v_out := v_out || jsonb_build_array(jsonb_build_object(
      'kind', v_kind,
      'sourceBomItemId', nullif(btrim(coalesce(v_item ->> 'sourceBomItemId', '')), ''),
      'componentId', nullif(btrim(coalesce(v_item ->> 'componentId', '')), ''),
      'mpn', nullif(regexp_replace(btrim(coalesce(v_item ->> 'mpn', '')), '\s+', ' ', 'g'), ''),
      'manufacturer', nullif(regexp_replace(btrim(coalesce(v_item ->> 'manufacturer', '')), '\s+', ' ', 'g'), ''),
      'description', nullif(regexp_replace(btrim(coalesce(v_item ->> 'description', '')), '\s+', ' ', 'g'), ''),
      'referenceDesignators', regexp_replace(btrim(v_item ->> 'referenceDesignators'), '\s+', ' ', 'g'),
      'quantity', v_quantity,
      'manualNote', nullif(regexp_replace(btrim(coalesce(v_item ->> 'manualNote', '')), '\s+', ' ', 'g'), '')
    ));
  END LOOP;
  RETURN v_out;
END;
$$;

CREATE OR REPLACE FUNCTION public.project_bom_procurement_review_submission_scope(
  p_actor uuid, p_project_id uuid, p_project_bom_id uuid, p_expected_bom_revision text
) RETURNS TABLE(project_id uuid, project_bom_id uuid, bom_number text, bom_revision text, bom_updated_at timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF p_actor IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;
  SELECT project.id, bom.id, bom.bom_number, bom.revision, bom.updated_at
  INTO project_id, project_bom_id, bom_number, bom_revision, bom_updated_at
  FROM public.projects project
  JOIN public.project_boms bom ON bom.id = p_project_bom_id AND bom.project_id = project.id
  JOIN public.employees manager ON manager.id = project.project_manager_employee_id
    AND manager.user_id = p_actor AND manager.employment_status = 'ACTIVE'
  JOIN public.project_team_members team ON team.project_id = project.id AND team.employee_id = manager.id
  WHERE project.id = p_project_id
    AND public.has_permission(p_actor, 'projects.manage')
  FOR UPDATE OF project, bom, manager, team;
  IF NOT FOUND THEN RAISE EXCEPTION 'Procurement submission requires the active assigned project manager, project-team membership, and projects.manage'; END IF;
  IF bom_revision IS DISTINCT FROM p_expected_bom_revision THEN RAISE EXCEPTION 'The project BOM revision is stale'; END IF;
  RETURN NEXT;
END;
$$;

CREATE OR REPLACE FUNCTION public.project_bom_procurement_review_procurement_scope(
  p_actor uuid, p_request_id uuid
) RETURNS TABLE(request_id uuid, project_id uuid, project_bom_id uuid, pinned_bom_revision text, pinned_bom_updated_at timestamptz, request_status text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF p_actor IS NULL OR NOT public.has_permission(p_actor, 'procurement.edit') THEN
    RAISE EXCEPTION 'Procurement analysis requires procurement.edit';
  END IF;
  SELECT request.id, request.project_id, request.project_bom_id, request.pinned_bom_revision, request.pinned_bom_updated_at, request.status
  INTO request_id, project_id, project_bom_id, pinned_bom_revision, pinned_bom_updated_at, request_status
  FROM public.project_bom_procurement_review_requests request
  JOIN public.employees employee ON employee.user_id = p_actor AND employee.employment_status = 'ACTIVE'
  JOIN public.employee_departments membership ON membership.employee_id = employee.id
  JOIN public.departments procurement ON procurement.id = membership.department_id
    AND procurement.code IN ('PURCHASE', 'PROCUREMENT', 'PUR', 'PD', 'PUR/PD') AND procurement.is_active
  JOIN public.project_team_members team ON team.project_id = request.project_id AND team.employee_id = employee.id
  WHERE request.id = p_request_id
  FOR UPDATE OF request, employee, membership, procurement, team;
  IF NOT FOUND THEN RAISE EXCEPTION 'Procurement analysis requires an active assigned Procurement employee'; END IF;
  RETURN NEXT;
END;
$$;

-- Read-only caller scope deliberately differs from analysis/decision scope:
-- the original authenticated project-manager requester can retrieve only their
-- exact immutable request through the protected function, while Procurement
-- reviewers require the active assigned Procurement scope above. No direct
-- table policy exposes request, line, analysis, receipt, or audit rows.
CREATE OR REPLACE FUNCTION public.project_bom_procurement_review_read_scope(
  p_actor uuid, p_request_id uuid
) RETURNS TABLE(request_id uuid)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF p_actor IS NULL OR p_request_id IS NULL THEN
    RAISE EXCEPTION 'Authenticated actor and Procurement request are required';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.project_bom_procurement_review_requests request
    WHERE request.id = p_request_id
      AND request.submitted_by = p_actor
  ) THEN
    RETURN QUERY SELECT p_request_id;
    RETURN;
  END IF;

  RETURN QUERY
  SELECT scope.request_id
  FROM public.project_bom_procurement_review_procurement_scope(p_actor, p_request_id) scope;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Procurement request read requires the original requester or an active assigned Procurement employee';
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.project_bom_procurement_review_canonical_analysis(p_analysis jsonb)
RETURNS jsonb
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public
AS $$
DECLARE v_allowed text[] := ARRAY['availabilityState', 'costState', 'sourcingState', 'observedUnitCost', 'currency', 'supplierName', 'leadTimeDays', 'alternateComponentId', 'analysisNote']; v_key text;
BEGIN
  IF jsonb_typeof(p_analysis) IS DISTINCT FROM 'object' THEN RAISE EXCEPTION 'Procurement analysis must be an object'; END IF;
  IF EXISTS (SELECT 1 FROM jsonb_object_keys(p_analysis) AS key WHERE key <> ALL(v_allowed)) THEN RAISE EXCEPTION 'Procurement analysis has an unsupported field'; END IF;
  IF upper(btrim(coalesce(p_analysis ->> 'availabilityState', ''))) NOT IN ('PENDING','AVAILABLE','UNAVAILABLE','TBC') OR upper(btrim(coalesce(p_analysis ->> 'costState', ''))) NOT IN ('PENDING','AVAILABLE','UNAVAILABLE','TBC') OR upper(btrim(coalesce(p_analysis ->> 'sourcingState', ''))) NOT IN ('PENDING','AVAILABLE','UNAVAILABLE','TBC') THEN RAISE EXCEPTION 'Procurement analysis states are invalid'; END IF;
  IF p_analysis ? 'observedUnitCost' AND jsonb_typeof(p_analysis -> 'observedUnitCost') NOT IN ('number','null') THEN RAISE EXCEPTION 'Observed unit cost must be numeric or null'; END IF;
  IF jsonb_typeof(p_analysis -> 'observedUnitCost') = 'number' AND (p_analysis ->> 'observedUnitCost')::numeric < 0 THEN RAISE EXCEPTION 'Observed unit cost cannot be negative'; END IF;
  IF p_analysis ? 'leadTimeDays' AND jsonb_typeof(p_analysis -> 'leadTimeDays') NOT IN ('number','null') THEN RAISE EXCEPTION 'Lead time must be numeric or null'; END IF;
  IF jsonb_typeof(p_analysis -> 'leadTimeDays') = 'number' AND ((p_analysis ->> 'leadTimeDays')::numeric < 0 OR (p_analysis ->> 'leadTimeDays')::numeric <> trunc((p_analysis ->> 'leadTimeDays')::numeric)) THEN RAISE EXCEPTION 'Lead time must be a non-negative whole number'; END IF;
  IF jsonb_typeof(p_analysis -> 'analysisNote') IS DISTINCT FROM 'string' OR char_length(btrim(p_analysis ->> 'analysisNote')) NOT BETWEEN 1 AND 1000 THEN RAISE EXCEPTION 'Procurement analysis requires a note'; END IF;
  RETURN jsonb_build_object('availabilityState', upper(btrim(p_analysis ->> 'availabilityState')), 'costState', upper(btrim(p_analysis ->> 'costState')), 'sourcingState', upper(btrim(p_analysis ->> 'sourcingState')), 'observedUnitCost', CASE WHEN jsonb_typeof(p_analysis -> 'observedUnitCost')='number' THEN p_analysis -> 'observedUnitCost' ELSE 'null'::jsonb END, 'currency', nullif(upper(btrim(coalesce(p_analysis ->> 'currency',''))), ''), 'supplierName', nullif(regexp_replace(btrim(coalesce(p_analysis ->> 'supplierName','')), '\s+', ' ', 'g'), ''), 'leadTimeDays', CASE WHEN jsonb_typeof(p_analysis -> 'leadTimeDays')='number' THEN to_jsonb((p_analysis ->> 'leadTimeDays')::integer) ELSE 'null'::jsonb END, 'alternateComponentId', nullif(btrim(coalesce(p_analysis ->> 'alternateComponentId','')), ''), 'analysisNote', regexp_replace(btrim(p_analysis ->> 'analysisNote'), '\s+', ' ', 'g'));
END;
$$;

CREATE OR REPLACE FUNCTION public.submit_project_bom_procurement_review(
  p_project_id uuid, p_project_bom_id uuid, p_expected_bom_revision text, p_rows jsonb, p_request_key uuid
) RETURNS TABLE(request_id uuid, replayed boolean)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_actor uuid := auth.uid(); v_rows jsonb; v_hash text; v_scope record; v_prior public.project_bom_procurement_review_receipts%ROWTYPE; v_request public.project_bom_procurement_review_requests%ROWTYPE; v_row jsonb; v_component public.components%ROWTYPE; v_bom_item public.project_bom_items%ROWTYPE; v_line_no integer := 0;
BEGIN
  IF v_actor IS NULL OR p_project_id IS NULL OR p_project_bom_id IS NULL OR p_request_key IS NULL THEN RAISE EXCEPTION 'Authenticated actor, project, BOM, and request key are required'; END IF;
  v_rows := public.project_bom_procurement_review_canonical_submission(p_rows);
  v_hash := md5(jsonb_build_object('projectId', p_project_id, 'projectBomId', p_project_bom_id, 'expectedBomRevision', p_expected_bom_revision, 'rows', v_rows)::text);
  PERFORM pg_advisory_xact_lock(hashtextextended('project-bom-procurement-request:' || p_request_key::text, 0));
  PERFORM pg_advisory_xact_lock(hashtextextended('project-bom-procurement-bom:' || p_project_bom_id::text, 0));
  SELECT * INTO v_scope FROM public.project_bom_procurement_review_submission_scope(v_actor, p_project_id, p_project_bom_id, p_expected_bom_revision);
  SELECT * INTO v_prior FROM public.project_bom_procurement_review_receipts WHERE request_key = p_request_key FOR UPDATE;
  IF FOUND THEN
    SELECT * INTO v_scope FROM public.project_bom_procurement_review_submission_scope(v_actor, p_project_id, p_project_bom_id, p_expected_bom_revision);
    IF v_prior.requested_by = v_actor AND v_prior.action = 'SUBMIT' AND v_prior.payload_hash = v_hash THEN RETURN QUERY SELECT v_prior.request_id, true; RETURN; END IF;
    RAISE EXCEPTION 'Request key conflicts with a different actor or canonical payload';
  END IF;
  SELECT * INTO v_scope FROM public.project_bom_procurement_review_submission_scope(v_actor, p_project_id, p_project_bom_id, p_expected_bom_revision);
  INSERT INTO public.project_bom_procurement_review_requests(project_id, project_bom_id, pinned_bom_number, pinned_bom_revision, pinned_bom_updated_at, submitted_by) VALUES(v_scope.project_id, v_scope.project_bom_id, v_scope.bom_number, v_scope.bom_revision, v_scope.bom_updated_at, v_actor) RETURNING * INTO v_request;
  FOR v_row IN SELECT value FROM jsonb_array_elements(v_rows) AS x(value) LOOP
    v_line_no := v_line_no + 1;
    IF v_row ->> 'kind' = 'existing' THEN
      SELECT * INTO v_component FROM public.components WHERE id = (v_row ->> 'componentId')::uuid FOR SHARE;
      IF NOT FOUND THEN RAISE EXCEPTION 'Selected component is unavailable'; END IF;
      IF nullif(v_row ->> 'sourceBomItemId','') IS NOT NULL THEN
        SELECT * INTO v_bom_item FROM public.project_bom_items WHERE id=(v_row ->> 'sourceBomItemId')::uuid AND bom_id=v_scope.project_bom_id FOR SHARE;
        IF NOT FOUND THEN RAISE EXCEPTION 'Source BOM item does not belong to the pinned BOM'; END IF;
        IF v_bom_item.matched_component_id IS DISTINCT FROM v_component.id THEN RAISE EXCEPTION 'Source BOM item does not pin the selected authoritative component'; END IF;
      END IF;
      INSERT INTO public.project_bom_procurement_review_request_lines(request_id,line_number,source_kind,source_bom_item_id,component_id,authoritative_mpn,authoritative_manufacturer,description,reference_designators,quantity,manual_note) VALUES(v_request.id,v_line_no,'EXISTING_COMPONENT',v_bom_item.id,v_component.id,v_component.part_number,v_component.manufacturer,v_component.name,v_row->>'referenceDesignators',(v_row->>'quantity')::numeric,nullif(v_row->>'manualNote',''));
    ELSE
      INSERT INTO public.project_bom_procurement_review_request_lines(request_id,line_number,source_kind,authoritative_mpn,authoritative_manufacturer,description,reference_designators,quantity,manual_note) VALUES(v_request.id,v_line_no,'NEW_PART',v_row->>'mpn',nullif(v_row->>'manufacturer',''),v_row->>'description',v_row->>'referenceDesignators',(v_row->>'quantity')::numeric,nullif(v_row->>'manualNote',''));
    END IF;
  END LOOP;
  INSERT INTO public.project_bom_procurement_review_audit_events(request_id,event_type,actor_user_id,event_data) VALUES(v_request.id,'SUBMITTED',v_actor,jsonb_build_object('project_id',v_scope.project_id,'project_bom_id',v_scope.project_bom_id,'pinned_bom_number',v_scope.bom_number,'pinned_bom_revision',v_scope.bom_revision,'payload_hash',v_hash));
  INSERT INTO public.project_bom_procurement_review_receipts(request_key,requested_by,action,request_id,payload_hash,result) VALUES(p_request_key,v_actor,'SUBMIT',v_request.id,v_hash,jsonb_build_object('request_id',v_request.id,'status',v_request.status));
  RETURN QUERY SELECT v_request.id,false;
END;
$$;

CREATE OR REPLACE FUNCTION public.analyze_project_bom_procurement_review(
  p_request_id uuid, p_request_line_id uuid, p_expected_analysis_revision integer, p_analysis jsonb, p_request_key uuid
) RETURNS TABLE(analysis_id uuid, analysis_revision integer, replayed boolean)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_actor uuid:=auth.uid(); v_analysis jsonb; v_hash text; v_scope record; v_line public.project_bom_procurement_review_request_lines%ROWTYPE; v_prior public.project_bom_procurement_review_receipts%ROWTYPE; v_analysis_row public.project_bom_procurement_review_analyses%ROWTYPE; v_current_analysis_revision integer;
BEGIN
  IF v_actor IS NULL OR p_request_id IS NULL OR p_request_line_id IS NULL OR p_request_key IS NULL OR p_expected_analysis_revision IS NULL OR p_expected_analysis_revision < 0 THEN RAISE EXCEPTION 'Authenticated actor, request, line, expected analysis revision, and request key are required'; END IF;
  v_analysis:=public.project_bom_procurement_review_canonical_analysis(p_analysis); v_hash:=md5(jsonb_build_object('requestId',p_request_id,'requestLineId',p_request_line_id,'expectedAnalysisRevision',p_expected_analysis_revision,'analysis',v_analysis)::text);
  PERFORM pg_advisory_xact_lock(hashtextextended('project-bom-procurement-analysis-request:'||p_request_key::text,0));
  SELECT * INTO v_scope FROM public.project_bom_procurement_review_procurement_scope(v_actor,p_request_id);
  SELECT * INTO v_prior FROM public.project_bom_procurement_review_receipts WHERE request_key=p_request_key FOR UPDATE;
  IF FOUND THEN SELECT * INTO v_scope FROM public.project_bom_procurement_review_procurement_scope(v_actor,p_request_id); IF v_prior.requested_by=v_actor AND v_prior.action='ANALYZE' AND v_prior.request_line_id=p_request_line_id AND v_prior.payload_hash=v_hash THEN RETURN QUERY SELECT (v_prior.result->>'analysis_id')::uuid,(v_prior.result->>'analysis_revision')::integer,true; RETURN; END IF; RAISE EXCEPTION 'Request key conflicts with a different actor or canonical payload'; END IF;
  IF v_scope.request_status <> 'PENDING_PROCUREMENT_ANALYSIS' THEN RAISE EXCEPTION 'Procurement request is no longer pending analysis'; END IF;
  SELECT * INTO v_line FROM public.project_bom_procurement_review_request_lines WHERE id=p_request_line_id AND request_id=p_request_id FOR UPDATE; IF NOT FOUND THEN RAISE EXCEPTION 'Procurement request line does not belong to this request'; END IF;
  SELECT analysis.analysis_revision INTO v_current_analysis_revision FROM public.project_bom_procurement_review_analyses analysis WHERE analysis.request_line_id=v_line.id ORDER BY analysis.analysis_revision DESC LIMIT 1 FOR UPDATE;
  v_current_analysis_revision := coalesce(v_current_analysis_revision, 0);
  IF v_current_analysis_revision IS DISTINCT FROM p_expected_analysis_revision THEN RAISE EXCEPTION 'The Procurement line analysis revision is stale'; END IF;
  INSERT INTO public.project_bom_procurement_review_analyses(request_line_id,analysis_revision,availability_state,cost_state,sourcing_state,observed_unit_cost,currency,supplier_name,lead_time_days,alternate_component_id,analysis_note,analyzed_by) VALUES(v_line.id,v_current_analysis_revision+1,v_analysis->>'availabilityState',v_analysis->>'costState',v_analysis->>'sourcingState',NULLIF(v_analysis->>'observedUnitCost','')::numeric,NULLIF(v_analysis->>'currency',''),NULLIF(v_analysis->>'supplierName',''),NULLIF(v_analysis->>'leadTimeDays','')::integer,NULLIF(v_analysis->>'alternateComponentId','')::uuid,v_analysis->>'analysisNote',v_actor) RETURNING * INTO v_analysis_row;
  INSERT INTO public.project_bom_procurement_review_audit_events(request_id,request_line_id,event_type,actor_user_id,event_data) VALUES(p_request_id,p_request_line_id,'ANALYZED',v_actor,jsonb_build_object('analysis_id',v_analysis_row.id,'analysis_revision',v_analysis_row.analysis_revision,'payload_hash',v_hash));
  INSERT INTO public.project_bom_procurement_review_receipts(request_key,requested_by,action,request_id,request_line_id,payload_hash,result) VALUES(p_request_key,v_actor,'ANALYZE',p_request_id,p_request_line_id,v_hash,jsonb_build_object('analysis_id',v_analysis_row.id,'analysis_revision',v_analysis_row.analysis_revision));
  RETURN QUERY SELECT v_analysis_row.id,v_analysis_row.analysis_revision,false;
END;
$$;

CREATE OR REPLACE FUNCTION public.decide_project_bom_procurement_review(
  p_request_id uuid, p_expected_bom_revision text, p_expected_bom_updated_at timestamptz,
  p_reviewed_analysis_revisions jsonb, p_decision text, p_decision_note text, p_request_key uuid
) RETURNS TABLE(request_id uuid, replayed boolean)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_actor uuid:=auth.uid(); v_scope record; v_prior public.project_bom_procurement_review_receipts%ROWTYPE; v_decision text:=upper(btrim(coalesce(p_decision,''))); v_note text:=regexp_replace(btrim(coalesce(p_decision_note,'')),'\s+',' ','g'); v_hash text; v_current_revision text; v_current_updated_at timestamptz; v_reviewed jsonb; v_line_count integer; v_reviewed_count integer; v_line record; v_current_analysis integer;
BEGIN
  IF v_actor IS NULL OR p_request_id IS NULL OR p_request_key IS NULL OR p_expected_bom_updated_at IS NULL THEN RAISE EXCEPTION 'Authenticated actor, request, BOM update pin, and request key are required'; END IF;
  IF v_decision NOT IN ('ALLOW','DENY') OR char_length(v_note) NOT BETWEEN 1 AND 500 THEN RAISE EXCEPTION 'Decision and decision note are invalid'; END IF;
  v_reviewed := public.project_bom_procurement_review_canonical_decision_analyses(p_reviewed_analysis_revisions);
  v_hash:=md5(jsonb_build_object('requestId',p_request_id,'expectedBomRevision',p_expected_bom_revision,'expectedBomUpdatedAt',p_expected_bom_updated_at,'reviewedAnalysisRevisions',v_reviewed,'decision',v_decision,'decisionNote',v_note)::text);
  PERFORM pg_advisory_xact_lock(hashtextextended('project-bom-procurement-decision-request:'||p_request_key::text,0));
  PERFORM pg_advisory_xact_lock(hashtextextended('project-bom-procurement-decision:'||p_request_id::text,0));
  SELECT * INTO v_scope FROM public.project_bom_procurement_review_procurement_scope(v_actor,p_request_id);
  SELECT * INTO v_prior FROM public.project_bom_procurement_review_receipts WHERE request_key=p_request_key FOR UPDATE;
  IF FOUND THEN SELECT * INTO v_scope FROM public.project_bom_procurement_review_procurement_scope(v_actor,p_request_id); IF v_prior.requested_by=v_actor AND v_prior.action=v_decision AND v_prior.payload_hash=v_hash THEN RETURN QUERY SELECT v_prior.request_id,true; RETURN; END IF; RAISE EXCEPTION 'Request key conflicts with a different actor or canonical payload'; END IF;
  SELECT revision, updated_at INTO v_current_revision, v_current_updated_at FROM public.project_boms WHERE id=v_scope.project_bom_id FOR UPDATE;
  -- The immutable submission pin is authoritative. The caller's inspected
  -- pins must agree with it and with the currently locked BOM; a reviewer
  -- cannot refresh a timestamp after a manual same-revision BOM edit and
  -- decide an older submitted snapshot.
  IF v_current_revision IS DISTINCT FROM v_scope.pinned_bom_revision
    OR v_current_revision IS DISTINCT FROM p_expected_bom_revision
    OR v_current_updated_at IS DISTINCT FROM v_scope.pinned_bom_updated_at
    OR p_expected_bom_updated_at IS DISTINCT FROM v_scope.pinned_bom_updated_at
  THEN RAISE EXCEPTION 'The project BOM source is stale; resubmit the Procurement request from the current BOM'; END IF;
  IF v_scope.request_status <> 'PENDING_PROCUREMENT_ANALYSIS' THEN RAISE EXCEPTION 'Procurement request is no longer pending analysis'; END IF;
  PERFORM 1 FROM public.project_bom_procurement_review_request_lines line WHERE line.request_id=p_request_id FOR UPDATE;
  SELECT count(*) INTO v_line_count FROM public.project_bom_procurement_review_request_lines line WHERE line.request_id=p_request_id;
  SELECT count(*) INTO v_reviewed_count FROM jsonb_array_elements(v_reviewed);
  IF v_decision='ALLOW' AND v_reviewed_count <> v_line_count THEN RAISE EXCEPTION 'Allow requires an exact reviewed analysis revision for every submitted line'; END IF;
  IF v_decision='ALLOW' THEN
    FOR v_line IN SELECT line.id FROM public.project_bom_procurement_review_request_lines line WHERE line.request_id=p_request_id ORDER BY line.id FOR UPDATE LOOP
      SELECT analysis.analysis_revision INTO v_current_analysis FROM public.project_bom_procurement_review_analyses analysis WHERE analysis.request_line_id=v_line.id ORDER BY analysis.analysis_revision DESC LIMIT 1 FOR UPDATE;
      IF v_current_analysis IS NULL OR v_current_analysis IS DISTINCT FROM (SELECT (value ->> 'analysisRevision')::integer FROM jsonb_array_elements(v_reviewed) WHERE (value ->> 'requestLineId')::uuid = v_line.id) THEN RAISE EXCEPTION 'Reviewed Procurement analysis is missing or stale'; END IF;
    END LOOP;
  ELSIF jsonb_array_length(v_reviewed) <> 0 THEN RAISE EXCEPTION 'Deny must not supply reviewed analysis revisions';
  END IF;
  UPDATE public.project_bom_procurement_review_requests SET status=CASE WHEN v_decision='ALLOW' THEN 'ALLOWED_PENDING_HARDWARE_SELECTION' ELSE 'DENIED' END,decided_by=v_actor,decided_at=clock_timestamp(),decision_note=v_note WHERE id=p_request_id;
  INSERT INTO public.project_bom_procurement_review_audit_events(request_id,event_type,actor_user_id,event_data) VALUES(p_request_id,CASE WHEN v_decision='ALLOW' THEN 'ALLOWED_PENDING_HARDWARE_SELECTION' ELSE 'DENIED' END,v_actor,jsonb_build_object('pinned_bom_revision',v_scope.pinned_bom_revision,'pinned_bom_updated_at',v_scope.pinned_bom_updated_at,'reviewer_expected_bom_updated_at',p_expected_bom_updated_at,'reviewed_analysis_revisions',v_reviewed,'decision_note',v_note,'payload_hash',v_hash));
  INSERT INTO public.project_bom_procurement_review_receipts(request_key,requested_by,action,request_id,payload_hash,result) VALUES(p_request_key,v_actor,v_decision,p_request_id,v_hash,jsonb_build_object('request_id',p_request_id,'status',CASE WHEN v_decision='ALLOW' THEN 'ALLOWED_PENDING_HARDWARE_SELECTION' ELSE 'DENIED' END));
  RETURN QUERY SELECT p_request_id,false;
END;
$$;

-- Readback resolves only the original requester or an active assigned
-- Procurement employee's exact immutable request snapshot. It does not expose
-- private receipts/audit data and does not imply a decision or release.
CREATE OR REPLACE FUNCTION public.read_project_bom_procurement_review(p_request_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_actor uuid:=auth.uid(); v_scope record; v_result jsonb;
BEGIN
  IF v_actor IS NULL OR p_request_id IS NULL THEN RAISE EXCEPTION 'Authenticated actor and Procurement request are required'; END IF;
  SELECT * INTO v_scope FROM public.project_bom_procurement_review_read_scope(v_actor,p_request_id);
  SELECT jsonb_build_object(
    'id', request.id,
    'projectId', request.project_id,
    'projectBomId', request.project_bom_id,
    'pinnedBomNumber', request.pinned_bom_number,
    'pinnedBomRevision', request.pinned_bom_revision,
    'pinnedBomUpdatedAt', request.pinned_bom_updated_at,
    'status', request.status,
    'submittedAt', request.submitted_at,
    'lines', coalesce((SELECT jsonb_agg(jsonb_build_object(
      'id', line.id,
      'lineNumber', line.line_number,
      'sourceKind', line.source_kind,
      'sourceBomItemId', line.source_bom_item_id,
      'componentId', line.component_id,
      'mpn', line.authoritative_mpn,
      'manufacturer', line.authoritative_manufacturer,
      'description', line.description,
      'referenceDesignators', line.reference_designators,
      'quantity', line.quantity,
      'manualNote', line.manual_note,
      'analysis', latest.analysis
    ) ORDER BY line.line_number)
    FROM public.project_bom_procurement_review_request_lines line
    LEFT JOIN LATERAL (
      SELECT jsonb_build_object(
        'id', analysis.id,
        'revision', analysis.analysis_revision,
        'availabilityState', analysis.availability_state,
        'costState', analysis.cost_state,
        'sourcingState', analysis.sourcing_state,
        'observedUnitCost', analysis.observed_unit_cost,
        'currency', analysis.currency,
        'supplierName', analysis.supplier_name,
        'leadTimeDays', analysis.lead_time_days,
        'alternateComponentId', analysis.alternate_component_id,
        'analysisNote', analysis.analysis_note,
        'analyzedAt', analysis.analyzed_at
      ) AS analysis
      FROM public.project_bom_procurement_review_analyses analysis
      WHERE analysis.request_line_id=line.id
      ORDER BY analysis.analysis_revision DESC
      LIMIT 1
    ) latest ON true
    WHERE line.request_id=request.id), '[]'::jsonb)
  ) INTO v_result
  FROM public.project_bom_procurement_review_requests request
  WHERE request.id=v_scope.request_id
  FOR SHARE;
  IF v_result IS NULL THEN RAISE EXCEPTION 'Procurement request is unavailable'; END IF;
  RETURN v_result;
END;
$$;

-- No authenticated table grants or SELECT policies are intentionally created.
-- All requester/reviewer reads flow through the scope-checked SECURITY DEFINER
-- entrypoint above; receipts and audit evidence remain implementation-private.

-- Execution is intentionally withheld pending installation review and authenticated caller acceptance.
REVOKE ALL ON FUNCTION public.project_bom_procurement_review_canonical_submission(jsonb) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.project_bom_procurement_review_submission_scope(uuid, uuid, uuid, text) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.project_bom_procurement_review_procurement_scope(uuid, uuid) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.project_bom_procurement_review_read_scope(uuid, uuid) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.project_bom_procurement_review_canonical_analysis(jsonb) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.project_bom_procurement_review_canonical_decision_analyses(jsonb) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.submit_project_bom_procurement_review(uuid, uuid, text, jsonb, uuid) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.analyze_project_bom_procurement_review(uuid, uuid, integer, jsonb, uuid) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.decide_project_bom_procurement_review(uuid, text, timestamptz, jsonb, text, text, uuid) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.read_project_bom_procurement_review(uuid) FROM PUBLIC, anon, authenticated, service_role;
-- No GRANT EXECUTE statement is present. Deployment must grant only the four
-- public entry points after real caller acceptance; helpers stay private.
