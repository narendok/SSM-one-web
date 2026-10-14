-- SOURCE-ONLY PROPOSAL. Do not install until caller-authenticated isolated
-- acceptance covers replay, rollback, concurrency, source pins, department
-- scope, reviewer scope, notification linkage, and direct-write denial.
--
-- This is intentionally one transaction. Calling the separate pending
-- requirement-create and reviewer-assignment routines would make a partial
-- requirement, review, or notification possible if a later call failed.

CREATE TABLE public.sales_feasibility_handover_requests (
  request_key uuid PRIMARY KEY,
  requested_by uuid NOT NULL,
  enquiry_id uuid NOT NULL REFERENCES public.sales_enquiries(id) ON DELETE RESTRICT,
  opportunity_id uuid NOT NULL REFERENCES public.sales_opportunities(id) ON DELETE RESTRICT,
  customer_id uuid NOT NULL REFERENCES public.customers(id) ON DELETE RESTRICT,
  master_specification_version_id uuid NOT NULL REFERENCES public.master_specification_versions(id) ON DELETE RESTRICT,
  payload_hash text NOT NULL,
  payload_canonical jsonb NOT NULL,
  requirement_id uuid NOT NULL UNIQUE REFERENCES public.customer_requirements(id) ON DELETE RESTRICT,
  source_revision_id uuid NOT NULL REFERENCES public.customer_requirement_revisions(id) ON DELETE RESTRICT,
  source_revision_number integer NOT NULL,
  master_specification_version_number integer NOT NULL,
  applicable_workstreams jsonb NOT NULL,
  review_pins jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK (length(btrim(payload_hash)) > 0),
  CHECK (jsonb_typeof(payload_canonical) = 'object'),
  CHECK (source_revision_number > 0),
  CHECK (master_specification_version_number > 0),
  CHECK (jsonb_typeof(applicable_workstreams) = 'array'),
  CHECK (jsonb_typeof(review_pins) = 'array')
);
GRANT ALL ON TABLE public.sales_feasibility_handover_requests TO service_role;
REVOKE ALL ON TABLE public.sales_feasibility_handover_requests FROM PUBLIC, anon, authenticated;
ALTER TABLE public.sales_feasibility_handover_requests ENABLE ROW LEVEL SECURITY;
CREATE POLICY "No direct Sales feasibility handover receipt access"
  ON public.sales_feasibility_handover_requests
  FOR ALL TO authenticated
  USING (false)
  WITH CHECK (false);

CREATE OR REPLACE FUNCTION public.sales_feasibility_handover_canonical_payload(
  p_enquiry_id uuid,
  p_opportunity_id uuid,
  p_customer_id uuid,
  p_master_specification_version_id uuid,
  p_title text,
  p_customer_reference text,
  p_summary text,
  p_department_ids uuid[],
  p_reviewer_user_ids uuid[],
  p_expected_enquiry_updated_at timestamptz
) RETURNS jsonb
LANGUAGE sql
IMMUTABLE
SET search_path = public
AS $$
  SELECT jsonb_build_object(
    'enquiry_id', p_enquiry_id,
    'opportunity_id', p_opportunity_id,
    'customer_id', p_customer_id,
    'master_specification_version_id', p_master_specification_version_id,
    'title', btrim(p_title),
    'customer_reference', nullif(btrim(coalesce(p_customer_reference, '')), ''),
    'summary', nullif(btrim(coalesce(p_summary, '')), ''),
    'department_ids', to_jsonb(p_department_ids),
    'reviewer_user_ids', to_jsonb(p_reviewer_user_ids),
    'expected_enquiry_updated_at', p_expected_enquiry_updated_at
  )
$$;

CREATE OR REPLACE FUNCTION public.submit_sales_feasibility_handover(
  p_enquiry_id uuid,
  p_opportunity_id uuid,
  p_customer_id uuid,
  p_master_specification_version_id uuid,
  p_title text,
  p_customer_reference text,
  p_summary text,
  p_department_ids uuid[],
  p_reviewer_user_ids uuid[],
  p_expected_enquiry_updated_at timestamptz,
  p_request_key uuid
) RETURNS TABLE(requirement_id uuid, review_ids uuid[], replayed boolean)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor_id uuid := auth.uid();
  v_enquiry public.sales_enquiries%ROWTYPE;
  v_opportunity public.sales_opportunities%ROWTYPE;
  v_specification public.master_specifications%ROWTYPE;
  v_master_version public.master_specification_versions%ROWTYPE;
  v_requirement public.customer_requirements%ROWTYPE;
  v_revision public.customer_requirement_revisions%ROWTYPE;
  v_prior public.sales_feasibility_handover_requests%ROWTYPE;
  v_payload_canonical jsonb;
  v_payload_hash text;
  v_department_id uuid;
  v_reviewer_user_id uuid;
  v_review_id uuid;
  v_review_ids uuid[] := ARRAY[]::uuid[];
  v_workstreams jsonb;
  v_current_review_pins jsonb;
  v_expected_review_pins jsonb;
  v_source_version_number integer;
  v_index integer;
BEGIN
  IF v_actor_id IS NULL OR NOT public.has_permission(v_actor_id, 'sales.manage') THEN
    RAISE EXCEPTION 'Sales management permission is required';
  END IF;
  IF p_request_key IS NULL OR p_enquiry_id IS NULL OR p_opportunity_id IS NULL
     OR p_customer_id IS NULL OR p_master_specification_version_id IS NULL
     OR p_expected_enquiry_updated_at IS NULL OR NULLIF(btrim(p_title), '') IS NULL
     OR char_length(btrim(p_title)) > 240
     OR (p_customer_reference IS NOT NULL AND char_length(btrim(p_customer_reference)) > 160)
     OR (p_summary IS NOT NULL AND char_length(btrim(p_summary)) > 8000)
     OR p_department_ids IS NULL OR p_reviewer_user_ids IS NULL
     OR cardinality(p_department_ids) IS NULL OR cardinality(p_department_ids) = 0
     OR cardinality(p_department_ids) <> cardinality(p_reviewer_user_ids)
     OR EXISTS (SELECT 1 FROM unnest(p_department_ids) item WHERE item IS NULL)
     OR EXISTS (SELECT 1 FROM unnest(p_reviewer_user_ids) item WHERE item IS NULL)
     OR cardinality(ARRAY(SELECT DISTINCT item FROM unnest(p_department_ids) item)) <> cardinality(p_department_ids)
     OR cardinality(ARRAY(SELECT DISTINCT item FROM unnest(p_reviewer_user_ids) item)) <> cardinality(p_reviewer_user_ids) THEN
    RAISE EXCEPTION 'A request key, current sources, and distinct department reviewer selections are required';
  END IF;

  -- Canonical department order prevents two equivalent selections producing a different receipt.
  SELECT array_agg(pair.department_id ORDER BY pair.department_id), array_agg(pair.reviewer_user_id ORDER BY pair.department_id)
  INTO p_department_ids, p_reviewer_user_ids
  FROM unnest(p_department_ids, p_reviewer_user_ids) AS pair(department_id, reviewer_user_id);
  v_payload_canonical := public.sales_feasibility_handover_canonical_payload(
    p_enquiry_id, p_opportunity_id, p_customer_id, p_master_specification_version_id,
    p_title, p_customer_reference, p_summary, p_department_ids, p_reviewer_user_ids,
    p_expected_enquiry_updated_at
  );
  v_payload_hash := md5(v_payload_canonical::text);

  -- Global order: request key -> receipt -> enquiry -> opportunity -> specification
  -- -> requirement/revision -> review rows (by id) -> active employee/membership prerequisites.
  -- A receipt never bypasses current authority, source, or recipient-scope checks.
  PERFORM pg_advisory_xact_lock(hashtextextended(p_request_key::text, 0));
  IF NOT public.has_permission(v_actor_id, 'sales.manage') THEN
    RAISE EXCEPTION 'Sales management permission is required';
  END IF;
  SELECT * INTO v_prior FROM public.sales_feasibility_handover_requests
  WHERE request_key = p_request_key FOR UPDATE;

  SELECT * INTO v_enquiry FROM public.sales_enquiries
  WHERE id = p_enquiry_id AND customer_id = p_customer_id FOR UPDATE;
  IF NOT FOUND OR v_enquiry.updated_at IS DISTINCT FROM p_expected_enquiry_updated_at
     OR v_enquiry.status = 'archived' THEN
    RAISE EXCEPTION 'Enquiry source is unavailable or changed; reload before handover';
  END IF;
  SELECT * INTO v_opportunity FROM public.sales_opportunities
  WHERE id = p_opportunity_id AND customer_id = p_customer_id AND enquiry_id = p_enquiry_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Opportunity, enquiry, and customer source mismatch';
  END IF;
  SELECT specification.* INTO v_specification
  FROM public.master_specifications specification
  JOIN public.master_specification_versions version ON version.specification_id = specification.id
  WHERE version.id = p_master_specification_version_id
    AND specification.opportunity_id = p_opportunity_id
    AND specification.customer_id = p_customer_id
    AND version.version_number = specification.current_version
  FOR UPDATE OF specification;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Current Master Specification version is unavailable for this opportunity and customer';
  END IF;
  SELECT * INTO v_master_version FROM public.master_specification_versions
  WHERE id = p_master_specification_version_id FOR KEY SHARE;
  v_workstreams := v_master_version.specification_data->'workstreams';
  IF jsonb_typeof(v_workstreams) IS DISTINCT FROM 'array' OR jsonb_array_length(v_workstreams) = 0
     OR EXISTS (SELECT 1 FROM jsonb_array_elements(v_workstreams) item(value)
                WHERE jsonb_typeof(item.value) <> 'string'
                  OR trim(both '"' FROM item.value::text) NOT IN ('HARDWARE', 'FIRMWARE', 'MECHANICAL', 'TEST', 'MANUFACTURING')) THEN
    RAISE EXCEPTION 'Master Specification workstreams are missing, unknown, or incomplete';
  END IF;
  v_source_version_number := v_master_version.version_number;

  FOR v_index IN 1..cardinality(p_department_ids) LOOP
    v_department_id := p_department_ids[v_index];
    v_reviewer_user_id := p_reviewer_user_ids[v_index];
    PERFORM 1 FROM public.departments department WHERE department.id = v_department_id AND department.is_active FOR KEY SHARE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Selected department is unavailable'; END IF;
    PERFORM 1 FROM public.employees employee
    JOIN public.employee_departments membership ON membership.employee_id = employee.id
    WHERE employee.user_id = v_reviewer_user_id
      AND employee.employment_status = 'ACTIVE'
      AND membership.department_id = v_department_id
    FOR KEY SHARE OF employee, membership;
    IF NOT FOUND THEN RAISE EXCEPTION 'Selected reviewer is not an active member of the selected department'; END IF;
  END LOOP;

  IF v_prior.request_key IS NOT NULL THEN
    IF v_prior.requested_by <> v_actor_id
       OR v_prior.enquiry_id <> p_enquiry_id
       OR v_prior.opportunity_id <> p_opportunity_id
       OR v_prior.customer_id <> p_customer_id
       OR v_prior.master_specification_version_id <> p_master_specification_version_id
       OR v_prior.payload_hash <> v_payload_hash
       OR v_prior.payload_canonical <> v_payload_canonical THEN
      RAISE EXCEPTION 'Request key conflicts with a different caller or payload';
    END IF;

    SELECT * INTO v_requirement
    FROM public.customer_requirements requirement
    WHERE requirement.id = v_prior.requirement_id
    FOR KEY SHARE;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Review graph has changed since this receipt was issued';
    END IF;
    SELECT * INTO v_revision
    FROM public.customer_requirement_revisions revision
    WHERE revision.id = v_prior.source_revision_id
      AND revision.requirement_id = v_prior.requirement_id
      AND revision.revision_number = v_prior.source_revision_number
    FOR KEY SHARE;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Review graph has changed since this receipt was issued';
    END IF;
    SELECT coalesce(jsonb_agg(jsonb_build_object(
      'id', locked_review.id,
      'department_id', locked_review.department_id,
      'reviewer_user_id', locked_review.reviewer_user_id,
      'source_revision_id', locked_review.source_revision_id,
      'source_revision_number', locked_review.source_revision_number,
      'master_specification_version_id', locked_review.master_specification_version_id,
      'master_specification_version_number', locked_review.master_specification_version_number,
      'applicable_workstreams', locked_review.applicable_workstreams
    ) ORDER BY locked_review.department_id, locked_review.id), '[]'::jsonb)
    INTO v_current_review_pins
    FROM (
      SELECT review.*
      FROM public.requirement_feasibility_reviews review
      WHERE review.requirement_id = v_prior.requirement_id
      ORDER BY review.id
      FOR KEY SHARE
    ) AS locked_review;
    SELECT coalesce(jsonb_agg(pin ORDER BY (pin->>'department_id')::uuid, (pin->>'id')::uuid), '[]'::jsonb)
    INTO v_expected_review_pins
    FROM jsonb_array_elements(v_prior.review_pins) pin;
    IF v_requirement.current_revision <> v_prior.source_revision_number
       OR v_revision.requirement_data IS DISTINCT FROM v_requirement.requirement_data
       OR v_prior.master_specification_version_number <> v_source_version_number
       OR v_prior.applicable_workstreams IS DISTINCT FROM v_workstreams
       OR v_current_review_pins IS DISTINCT FROM v_expected_review_pins THEN
      RAISE EXCEPTION 'Review graph has changed since this receipt was issued';
    END IF;
    IF NOT public.has_permission(v_actor_id, 'sales.manage') THEN
      RAISE EXCEPTION 'Sales management permission is required';
    END IF;
    RETURN QUERY SELECT v_prior.requirement_id, ARRAY(
      SELECT (pin->>'id')::uuid
      FROM jsonb_array_elements(v_expected_review_pins) pin
      ORDER BY (pin->>'department_id')::uuid, (pin->>'id')::uuid
    ), true;
    RETURN;
  END IF;

  INSERT INTO public.customer_requirements (
    requirement_number, opportunity_id, customer_id, title, status, current_revision,
    customer_reference, requirement_data, submitted_at, created_by
  ) VALUES (
    public.next_business_number('customer_requirement', NULL, NULL), p_opportunity_id, p_customer_id,
    btrim(p_title), 'submitted', 1, nullif(btrim(coalesce(p_customer_reference, '')), ''),
    jsonb_build_object('summary', nullif(btrim(coalesce(p_summary, '')), ''), 'source', jsonb_build_object(
      'enquiry_id', p_enquiry_id, 'opportunity_id', p_opportunity_id, 'customer_id', p_customer_id,
      'master_specification_id', v_specification.id, 'master_specification_version_id', p_master_specification_version_id,
      'master_specification_version_number', v_source_version_number, 'applicable_workstreams', v_workstreams
    )), now(), v_actor_id
  ) RETURNING * INTO v_requirement;
  INSERT INTO public.customer_requirement_revisions (
    requirement_id, revision_number, change_summary, requirement_data, status, created_by
  ) VALUES (v_requirement.id, 1, 'Initial source-bound Sales feasibility handover', v_requirement.requirement_data, 'submitted', v_actor_id)
  RETURNING * INTO v_revision;

  FOR v_index IN 1..cardinality(p_department_ids) LOOP
    v_department_id := p_department_ids[v_index];
    v_reviewer_user_id := p_reviewer_user_ids[v_index];
    INSERT INTO public.requirement_feasibility_reviews (
      requirement_id, department_id, reviewer_user_id, status, created_by,
      source_revision_id, source_revision_number, master_specification_version_id,
      master_specification_version_number, applicable_workstreams
    ) VALUES (
      v_requirement.id, v_department_id, v_reviewer_user_id, 'pending', v_actor_id,
      v_revision.id, 1, p_master_specification_version_id, v_source_version_number, v_workstreams
    ) RETURNING id INTO v_review_id;
    v_review_ids := array_append(v_review_ids, v_review_id);
    PERFORM public.enqueue_notification(
      v_reviewer_user_id, 'feasibility_review', 'Feasibility review assigned',
      'A Sales feasibility review is ready for your decision.', '/sales/enquiries',
      'requirement_feasibility_review', v_review_id, 'sales-feasibility-handover:' || v_review_id::text
    );
  END LOOP;
  INSERT INTO public.activity_log (actor_user_id, module_key, entity_type, entity_id, action, summary, after_data)
  VALUES (v_actor_id, 'sales', 'customer_requirement', v_requirement.id, 'feasibility_handover_submitted',
    'Submitted source-bound Sales feasibility handover.', jsonb_build_object(
      'enquiry_id', p_enquiry_id, 'opportunity_id', p_opportunity_id, 'customer_id', p_customer_id,
      'source_revision_id', v_revision.id, 'master_specification_version_id', p_master_specification_version_id,
      'master_specification_version_number', v_source_version_number, 'department_ids', to_jsonb(p_department_ids),
      'reviewer_user_ids', to_jsonb(p_reviewer_user_ids), 'review_ids', to_jsonb(v_review_ids), 'request_key', p_request_key
    ));
  INSERT INTO public.sales_feasibility_handover_requests (
    request_key, requested_by, enquiry_id, opportunity_id, customer_id, master_specification_version_id,
    payload_hash, payload_canonical, requirement_id, source_revision_id, source_revision_number,
    master_specification_version_number, applicable_workstreams, review_pins
  ) VALUES (p_request_key, v_actor_id, p_enquiry_id, p_opportunity_id, p_customer_id,
    p_master_specification_version_id, v_payload_hash, v_payload_canonical, v_requirement.id,
    v_revision.id, v_revision.revision_number, v_source_version_number, v_workstreams,
    (
      SELECT jsonb_agg(jsonb_build_object(
        'id', review.id,
        'department_id', review.department_id,
        'reviewer_user_id', review.reviewer_user_id,
        'source_revision_id', review.source_revision_id,
        'source_revision_number', review.source_revision_number,
        'master_specification_version_id', review.master_specification_version_id,
        'master_specification_version_number', review.master_specification_version_number,
        'applicable_workstreams', review.applicable_workstreams
      ) ORDER BY review.department_id, review.id)
      FROM public.requirement_feasibility_reviews review
      WHERE review.id = ANY(v_review_ids)
    ));
  RETURN QUERY SELECT v_requirement.id, v_review_ids, false;
END;
$$;

REVOKE ALL ON FUNCTION public.submit_sales_feasibility_handover(uuid, uuid, uuid, uuid, text, text, text, uuid[], uuid[], timestamptz, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_sales_feasibility_handover(uuid, uuid, uuid, uuid, text, text, text, uuid[], uuid[], timestamptz, uuid) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.sales_feasibility_handover_canonical_payload(uuid, uuid, uuid, uuid, text, text, text, uuid[], uuid[], timestamptz) FROM PUBLIC, anon, authenticated;