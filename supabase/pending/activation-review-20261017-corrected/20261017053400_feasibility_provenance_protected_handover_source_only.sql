-- REVIEWED, SOURCE-ONLY ACTIVATION DRAFT.
-- This repository change does not apply this SQL. It excludes external intake,
-- notes/highlights/publication, baseline approval, and project conversion.
-- Review managed acceptance and the separate access transition before execution.

-- REVIEWED SOURCE-ONLY ACTIVATION DRAFT — FIRST FEASIBILITY BUNDLE
-- This file is intentionally not applied by this source change. It excludes external
-- client intake, private notes/highlights/publication, baseline approval, and project start.
--
-- Preflight fails closed before replacing the historical uniqueness constraint. Existing
-- legacy reviews may retain all provenance columns NULL, but partially pinned rows and
-- duplicate non-null (source_revision_id, department_id) pairs are incompatible.
DO $feasibility_preflight$
DECLARE
  v_legacy_unique_name text;
BEGIN
  IF to_regclass('public.customer_requirements') IS NULL
     OR to_regclass('public.customer_requirement_revisions') IS NULL
     OR to_regclass('public.requirement_feasibility_reviews') IS NULL
     OR to_regclass('public.master_specifications') IS NULL
     OR to_regclass('public.master_specification_versions') IS NULL
     OR to_regclass('public.sales_enquiries') IS NULL
     OR to_regclass('public.sales_opportunities') IS NULL
     OR to_regclass('public.notifications') IS NULL
     OR to_regclass('public.activity_log') IS NULL THEN
    RAISE EXCEPTION 'Feasibility activation prerequisites are missing';
  END IF;
  IF to_regprocedure('public.has_permission(uuid,text)') IS NULL
     OR to_regprocedure('public.next_business_number(text,text,text)') IS NULL
     OR to_regprocedure('public.enqueue_notification(uuid,text,text,text,text,text,uuid,text)') IS NULL THEN
    RAISE EXCEPTION 'Feasibility activation helper signature is incompatible';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc procedure
    JOIN pg_namespace namespace ON namespace.oid = procedure.pronamespace
    WHERE namespace.nspname = 'public'
      AND procedure.oid = 'public.enqueue_notification(uuid,text,text,text,text,text,uuid,text)'::regprocedure
      AND procedure.prosecdef
      AND procedure.proconfig @> ARRAY['search_path=public']
  ) THEN
    RAISE EXCEPTION 'Notification helper authority is incompatible';
  END IF;
  SELECT constraint_name INTO v_legacy_unique_name
  FROM information_schema.table_constraints table_constraint
  WHERE table_constraint.table_schema = 'public'
    AND table_constraint.table_name = 'requirement_feasibility_reviews'
    AND table_constraint.constraint_type = 'UNIQUE'
    AND (SELECT array_agg(column_usage.column_name::text ORDER BY column_usage.ordinal_position)
         FROM information_schema.key_column_usage column_usage
         WHERE column_usage.constraint_schema = 'public'
           AND column_usage.constraint_name = table_constraint.constraint_name)
        = ARRAY['requirement_id', 'department_id']
  LIMIT 1;
  IF v_legacy_unique_name IS NULL
     AND NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'public.requirement_feasibility_reviews'::regclass AND conname = 'requirement_feasibility_reviews_revision_department_key') THEN
    RAISE EXCEPTION 'Feasibility review uniqueness is incompatible';
  END IF;
  IF EXISTS (
    SELECT 1 FROM pg_constraint constraint_row
    WHERE constraint_row.conrelid = 'public.requirement_feasibility_reviews'::regclass
      AND constraint_row.contype = 'u'
      AND constraint_row.conname NOT IN ('requirement_feasibility_reviews_revision_department_key', v_legacy_unique_name)
  ) THEN
    RAISE EXCEPTION 'Feasibility review uniqueness has an unreviewed constraint';
  END IF;
END;
$feasibility_preflight$;

ALTER TABLE public.requirement_feasibility_reviews
  ADD COLUMN IF NOT EXISTS source_revision_id uuid REFERENCES public.customer_requirement_revisions(id) ON DELETE RESTRICT,
  ADD COLUMN IF NOT EXISTS source_revision_number integer,
  ADD COLUMN IF NOT EXISTS master_specification_version_id uuid REFERENCES public.master_specification_versions(id) ON DELETE RESTRICT,
  ADD COLUMN IF NOT EXISTS master_specification_version_number integer,
  ADD COLUMN IF NOT EXISTS applicable_workstreams jsonb;

DO $legacy_pin_preflight$
DECLARE
  v_partial_count bigint;
  v_duplicate_count bigint;
BEGIN
  SELECT count(*) INTO v_partial_count
  FROM public.requirement_feasibility_reviews review
  WHERE (review.source_revision_id IS NULL)::integer
      + (review.source_revision_number IS NULL)::integer
      + (review.master_specification_version_id IS NULL)::integer
      + (review.master_specification_version_number IS NULL)::integer
      + (review.applicable_workstreams IS NULL)::integer NOT IN (0, 5);
  IF v_partial_count <> 0 THEN
    RAISE EXCEPTION 'Feasibility activation blocked: % partially pinned legacy review rows require repair', v_partial_count;
  END IF;
  SELECT count(*) INTO v_duplicate_count
  FROM (
    SELECT review.source_revision_id, review.department_id
    FROM public.requirement_feasibility_reviews review
    WHERE review.source_revision_id IS NOT NULL
    GROUP BY review.source_revision_id, review.department_id
    HAVING count(*) > 1
  ) duplicates;
  IF v_duplicate_count <> 0 THEN
    RAISE EXCEPTION 'Feasibility activation blocked: % duplicate revision/department review pairs require repair', v_duplicate_count;
  END IF;
END;
$legacy_pin_preflight$;

DO $feasibility_constraints$
DECLARE
  v_constraint record;
BEGIN
  FOR v_constraint IN
    SELECT table_constraint.constraint_name
    FROM information_schema.table_constraints table_constraint
    WHERE table_constraint.table_schema = 'public'
      AND table_constraint.table_name = 'requirement_feasibility_reviews'
      AND table_constraint.constraint_type = 'UNIQUE'
      AND table_constraint.constraint_name <> 'requirement_feasibility_reviews_revision_department_key'
      AND (SELECT array_agg(column_usage.column_name::text ORDER BY column_usage.ordinal_position)
           FROM information_schema.key_column_usage column_usage
           WHERE column_usage.constraint_schema = 'public'
             AND column_usage.constraint_name = table_constraint.constraint_name)
          = ARRAY['requirement_id', 'department_id']
  LOOP
    EXECUTE format('ALTER TABLE public.requirement_feasibility_reviews DROP CONSTRAINT %I', v_constraint.constraint_name);
  END LOOP;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'public.requirement_feasibility_reviews'::regclass AND conname = 'requirement_feasibility_reviews_revision_department_key') THEN
    ALTER TABLE public.requirement_feasibility_reviews ADD CONSTRAINT requirement_feasibility_reviews_revision_department_key UNIQUE (source_revision_id, department_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'public.customer_requirement_revisions'::regclass AND conname = 'customer_requirement_revisions_requirement_revision_key') THEN
    ALTER TABLE public.customer_requirement_revisions ADD CONSTRAINT customer_requirement_revisions_requirement_revision_key UNIQUE (requirement_id, revision_number);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'public.requirement_feasibility_reviews'::regclass AND conname = 'requirement_feasibility_reviews_pinned_source_check') THEN
    ALTER TABLE public.requirement_feasibility_reviews ADD CONSTRAINT requirement_feasibility_reviews_pinned_source_check CHECK (
      (source_revision_id IS NULL AND source_revision_number IS NULL AND master_specification_version_id IS NULL AND master_specification_version_number IS NULL AND applicable_workstreams IS NULL)
      OR
      (source_revision_id IS NOT NULL AND source_revision_number IS NOT NULL AND master_specification_version_id IS NOT NULL AND master_specification_version_number IS NOT NULL AND applicable_workstreams IS NOT NULL AND jsonb_typeof(applicable_workstreams) = 'array')
    );
  END IF;
END;
$feasibility_constraints$;

CREATE INDEX IF NOT EXISTS requirement_feasibility_reviews_source_revision_idx
  ON public.requirement_feasibility_reviews(source_revision_id);

CREATE OR REPLACE FUNCTION public.assign_requirement_feasibility_review(
  p_requirement_id uuid,
  p_department_id uuid,
  p_reviewer_user_id uuid
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_review public.requirement_feasibility_reviews%ROWTYPE;
  v_requirement public.customer_requirements%ROWTYPE;
  v_revision public.customer_requirement_revisions%ROWTYPE;
  v_master_version public.master_specification_versions%ROWTYPE;
  v_master_version_id uuid;
  v_source_opportunity_id uuid;
  v_source_customer_id uuid;
  v_source_version_number integer;
  v_workstreams jsonb;
  v_review_found boolean := false;
  v_root_lock_key bigint;
BEGIN
  IF auth.uid() IS NULL OR NOT public.has_permission(auth.uid(), 'sales.manage') THEN
    RAISE EXCEPTION 'Sales management permission is required';
  END IF;
  IF p_requirement_id IS NULL OR p_department_id IS NULL OR p_reviewer_user_id IS NULL THEN
    RAISE EXCEPTION 'Requirement, department, and reviewer are required';
  END IF;

  -- Shared graph order: requirement-root -> requirement -> revision -> review -> version.
  -- This pending routine participates in handover replay serialization; direct table
  -- writers remain outside it and must be removed in the separate compatibility gate.
  v_root_lock_key := hashtextextended('sales-feasibility-requirement-root:' || p_requirement_id::text, 0);
  PERFORM pg_advisory_xact_lock(v_root_lock_key);
  SELECT * INTO v_requirement
  FROM public.customer_requirements
  WHERE id = p_requirement_id
  FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Feasibility source requirement is unavailable'; END IF;

  SELECT * INTO v_revision
  FROM public.customer_requirement_revisions
  WHERE requirement_id = v_requirement.id
    AND revision_number = v_requirement.current_revision
  FOR KEY SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Current immutable customer requirement revision is unavailable'; END IF;

  IF jsonb_typeof(v_revision.requirement_data) IS DISTINCT FROM 'object'
     OR NULLIF(v_revision.requirement_data #>> '{source,master_specification_version_id}', '') IS NULL THEN
    RAISE EXCEPTION 'Current immutable customer requirement revision lacks a Master Specification version source; legacy provenance is unavailable';
  END IF;
  BEGIN
    v_master_version_id := (v_revision.requirement_data #>> '{source,master_specification_version_id}')::uuid;
    v_source_opportunity_id := (v_revision.requirement_data #>> '{source,opportunity_id}')::uuid;
    v_source_customer_id := (v_revision.requirement_data #>> '{source,customer_id}')::uuid;
    v_source_version_number := (v_revision.requirement_data #>> '{source,master_specification_version_number}')::integer;
  EXCEPTION WHEN invalid_text_representation THEN
    RAISE EXCEPTION 'Current immutable customer requirement revision has an invalid Master Specification source tuple';
  END;
  IF v_source_opportunity_id IS NULL OR v_source_customer_id IS NULL OR v_source_version_number IS NULL THEN
    RAISE EXCEPTION 'Current immutable customer requirement revision lacks a complete Master Specification source tuple; legacy provenance is unavailable';
  END IF;
  IF v_source_opportunity_id IS DISTINCT FROM v_requirement.opportunity_id
     OR v_source_customer_id IS DISTINCT FROM v_requirement.customer_id THEN
    RAISE EXCEPTION 'Current immutable customer requirement revision source does not match its requirement opportunity and customer';
  END IF;

  SELECT * INTO v_review
  FROM public.requirement_feasibility_reviews
  WHERE source_revision_id = v_revision.id
    AND department_id = p_department_id
  FOR UPDATE;
  v_review_found := FOUND;

  SELECT version.* INTO v_master_version
  FROM public.master_specification_versions version
  JOIN public.master_specifications specification ON specification.id = version.specification_id
  WHERE version.id = v_master_version_id
    AND version.version_number = v_source_version_number
    AND specification.opportunity_id = v_requirement.opportunity_id
    AND specification.customer_id = v_requirement.customer_id
  FOR KEY SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Pinned Master Specification version is unavailable for the immutable requirement revision'; END IF;

  v_workstreams := v_master_version.specification_data->'workstreams';
  IF jsonb_typeof(v_workstreams) IS DISTINCT FROM 'array' THEN
    RAISE EXCEPTION 'Master Specification workstreams are missing, null, non-string, unknown, or incomplete; applicability is TBC';
  END IF;
  IF jsonb_array_length(v_workstreams) = 0
     OR EXISTS (
       SELECT 1
       FROM jsonb_array_elements(v_workstreams) AS workstream(value)
       WHERE jsonb_typeof(workstream.value) <> 'string'
          OR trim(both '"' FROM workstream.value::text) NOT IN ('HARDWARE', 'FIRMWARE', 'MECHANICAL', 'TEST', 'MANUFACTURING')
     ) THEN
    RAISE EXCEPTION 'Master Specification workstreams are missing, null, non-string, unknown, or incomplete; applicability is TBC';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.employees employee
    JOIN public.employee_departments membership ON membership.employee_id = employee.id
    WHERE employee.user_id = p_reviewer_user_id
      AND employee.employment_status = 'ACTIVE'
      AND membership.department_id = p_department_id
  ) THEN RAISE EXCEPTION 'Assigned reviewer is not an active member of the selected department'; END IF;

  IF v_review_found THEN
    IF v_review.status NOT IN ('pending', 'in_review') THEN
      RAISE EXCEPTION 'A terminal review is immutable history; a new requirement revision is required for another feasibility review';
    END IF;
    IF v_review.source_revision_number IS DISTINCT FROM v_revision.revision_number
       OR v_review.master_specification_version_id IS DISTINCT FROM v_master_version.id
       OR v_review.master_specification_version_number IS DISTINCT FROM v_master_version.version_number
       OR v_review.applicable_workstreams IS DISTINCT FROM v_workstreams THEN
      RAISE EXCEPTION 'Open feasibility review is pinned to different immutable provenance';
    END IF;
    UPDATE public.requirement_feasibility_reviews
    SET reviewer_user_id = p_reviewer_user_id, status = 'pending', findings = NULL,
        assumptions = NULL, risks = NULL, reviewed_at = NULL
    WHERE id = v_review.id;
  ELSE
    INSERT INTO public.requirement_feasibility_reviews (
      requirement_id, department_id, reviewer_user_id, status, created_by,
      source_revision_id, source_revision_number,
      master_specification_version_id, master_specification_version_number, applicable_workstreams
    ) VALUES (
      p_requirement_id, p_department_id, p_reviewer_user_id, 'pending', auth.uid(),
      v_revision.id, v_revision.revision_number,
      v_master_version.id, v_master_version.version_number, v_workstreams
    ) RETURNING id INTO v_review.id;
  END IF;

  INSERT INTO public.activity_log(actor_user_id, module_key, entity_type, entity_id, action, summary, after_data)
  VALUES (
    auth.uid(), 'sales', 'requirement_feasibility', v_review.id, 'assigned',
    'Engineering feasibility review assigned.',
    jsonb_build_object(
      'requirement_id', p_requirement_id, 'source_revision_id', v_revision.id,
      'source_revision_number', v_revision.revision_number,
      'master_specification_version_id', v_master_version.id,
      'master_specification_version_number', v_master_version.version_number,
      'applicable_workstreams', v_workstreams, 'department_id', p_department_id,
      'reviewer_user_id', p_reviewer_user_id, 'status', 'pending'
    )
  );
  RETURN v_review.id;
END;
$$;

REVOKE ALL ON FUNCTION public.assign_requirement_feasibility_review(uuid, uuid, uuid) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.assign_requirement_feasibility_review(uuid, uuid, uuid) TO authenticated, service_role;

-- A reviewer response needs its own immutable request receipt before a caller-RLS observer can
-- prove a positive response graph. Direct receipt access remains denied; the narrow reader below
-- returns only one actor-bound, exact graph and does not prove rollback, history, or concurrency.
CREATE TABLE public.requirement_feasibility_response_requests (
  request_key uuid PRIMARY KEY,
  requested_by uuid NOT NULL,
  review_id uuid NOT NULL UNIQUE REFERENCES public.requirement_feasibility_reviews(id) ON DELETE RESTRICT,
  requirement_id uuid NOT NULL REFERENCES public.customer_requirements(id) ON DELETE RESTRICT,
  source_revision_id uuid NOT NULL REFERENCES public.customer_requirement_revisions(id) ON DELETE RESTRICT,
  master_specification_version_id uuid NOT NULL REFERENCES public.master_specification_versions(id) ON DELETE RESTRICT,
  payload_hash text NOT NULL,
  payload_canonical jsonb NOT NULL,
  CHECK (length(btrim(payload_hash)) > 0),
  CHECK (jsonb_typeof(payload_canonical) = 'object')
);
GRANT ALL ON TABLE public.requirement_feasibility_response_requests TO service_role;
REVOKE ALL ON TABLE public.requirement_feasibility_response_requests FROM PUBLIC, anon, authenticated;
ALTER TABLE public.requirement_feasibility_response_requests ENABLE ROW LEVEL SECURITY;
CREATE POLICY "No direct feasibility response receipt access" ON public.requirement_feasibility_response_requests
  FOR ALL TO authenticated USING (false) WITH CHECK (false);

CREATE OR REPLACE FUNCTION public.requirement_feasibility_response_canonical_payload(
  p_review_id uuid,
  p_status text,
  p_findings text,
  p_assumptions text,
  p_risks text
) RETURNS jsonb
LANGUAGE sql
IMMUTABLE
SET search_path = public
AS $$
  SELECT jsonb_build_object(
    'review_id', p_review_id,
    'status', p_status,
    'findings', btrim(p_findings),
    'assumptions', nullif(btrim(coalesce(p_assumptions, '')), ''),
    'risks', nullif(btrim(coalesce(p_risks, '')), '')
  )
$$;

-- PostgreSQL overloads are distinct callable functions. Retire the pre-receipt prototype so a
-- reviewer cannot bypass replay binding by calling the former five-argument signature.
DO $$
BEGIN
  IF to_regprocedure('public.record_requirement_feasibility_response(uuid,text,text,text,text)') IS NOT NULL THEN
    EXECUTE 'REVOKE ALL ON FUNCTION public.record_requirement_feasibility_response(uuid,text,text,text,text) FROM PUBLIC, anon, authenticated, service_role';
    EXECUTE 'DROP FUNCTION public.record_requirement_feasibility_response(uuid,text,text,text,text)';
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.record_requirement_feasibility_response(
  p_review_id uuid,
  p_status text,
  p_findings text,
  p_assumptions text,
  p_risks text,
  p_request_key uuid
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_review public.requirement_feasibility_reviews%ROWTYPE;
  v_requirement public.customer_requirements%ROWTYPE;
  v_revision public.customer_requirement_revisions%ROWTYPE;
  v_master_version public.master_specification_versions%ROWTYPE;
  v_prior public.requirement_feasibility_response_requests%ROWTYPE;
  v_payload_canonical jsonb;
  v_payload_hash text;
  v_root_lock_key bigint;
BEGIN
  IF auth.uid() IS NULL OR NOT public.has_permission(auth.uid(), 'engineering.manage') THEN
    RAISE EXCEPTION 'Engineering management permission is required';
  END IF;
  IF p_request_key IS NULL THEN
    RAISE EXCEPTION 'A response request key is required';
  END IF;
  IF p_status IS NULL OR p_status NOT IN ('feasible', 'feasible_with_conditions', 'not_feasible')
     OR NULLIF(btrim(p_findings), '') IS NULL THEN
    RAISE EXCEPTION 'A terminal feasibility verdict and findings are required';
  END IF;

  -- Resolve the root without a row lock, then serialize the graph before the first
  -- mutable source row: requirement-root -> requirement -> revision -> review -> version.
  SELECT * INTO v_review FROM public.requirement_feasibility_reviews WHERE id = p_review_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Feasibility review is unavailable'; END IF;
  v_root_lock_key := hashtextextended('sales-feasibility-requirement-root:' || v_review.requirement_id::text, 0);
  PERFORM pg_advisory_xact_lock(v_root_lock_key);
  SELECT * INTO v_requirement FROM public.customer_requirements
  WHERE id = v_review.requirement_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Feasibility review source requirement is unavailable'; END IF;
  SELECT * INTO v_revision FROM public.customer_requirement_revisions
  WHERE id = v_review.source_revision_id AND requirement_id = v_requirement.id
    AND revision_number = v_review.source_revision_number FOR KEY SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Pinned customer requirement revision is unavailable'; END IF;
  SELECT * INTO v_review FROM public.requirement_feasibility_reviews WHERE id = p_review_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Feasibility review is unavailable'; END IF;

  IF v_review.source_revision_id IS NULL OR v_review.source_revision_number IS NULL
     OR v_review.master_specification_version_id IS NULL OR v_review.master_specification_version_number IS NULL
     OR jsonb_typeof(v_review.applicable_workstreams) IS DISTINCT FROM 'array' THEN
    RAISE EXCEPTION 'Feasibility review lacks immutable provenance and cannot receive a protected response';
  END IF;
  SELECT version.* INTO v_master_version FROM public.master_specification_versions version
  JOIN public.master_specifications specification ON specification.id = version.specification_id
  WHERE version.id = v_review.master_specification_version_id
    AND version.version_number = v_review.master_specification_version_number
    AND specification.opportunity_id = v_requirement.opportunity_id
    AND specification.customer_id = v_requirement.customer_id FOR KEY SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Pinned Master Specification version is unavailable'; END IF;
  IF v_review.reviewer_user_id IS NULL OR v_review.department_id IS NULL THEN
    RAISE EXCEPTION 'Feasibility review requires an assigned reviewer and department';
  END IF;
  IF v_review.reviewer_user_id IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'Only the assigned reviewer may submit this feasibility response';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.employees employee
    JOIN public.employee_departments membership ON membership.employee_id = employee.id
    WHERE employee.user_id = auth.uid() AND employee.employment_status = 'ACTIVE'
      AND membership.department_id = v_review.department_id
  ) THEN RAISE EXCEPTION 'The assigned reviewer is not an active member of this review department'; END IF;
  v_payload_canonical := public.requirement_feasibility_response_canonical_payload(
    p_review_id, p_status, p_findings, p_assumptions, p_risks
  );
  v_payload_hash := md5(v_payload_canonical::text);
  PERFORM pg_advisory_xact_lock(hashtextextended(p_request_key::text, 0));
  SELECT * INTO v_prior
  FROM public.requirement_feasibility_response_requests
  WHERE request_key = p_request_key
  FOR UPDATE;
  IF FOUND THEN
    IF v_prior.requested_by = auth.uid()
       AND v_prior.review_id = v_review.id
       AND v_prior.requirement_id = v_review.requirement_id
       AND v_prior.source_revision_id = v_review.source_revision_id
       AND v_prior.master_specification_version_id = v_review.master_specification_version_id
       AND v_prior.payload_hash = v_payload_hash
       AND v_prior.payload_canonical = v_payload_canonical THEN
      RETURN v_prior.review_id;
    END IF;
    RAISE EXCEPTION 'Response request key conflicts with a different reviewer, scope, or payload';
  END IF;
  IF v_review.status NOT IN ('pending', 'in_review') THEN
    RAISE EXCEPTION 'Feasibility review is not open for a response';
  END IF;

  UPDATE public.requirement_feasibility_reviews
  SET status = p_status, findings = p_findings, assumptions = p_assumptions,
      risks = p_risks, reviewed_at = now()
  WHERE id = v_review.id;
  INSERT INTO public.activity_log(actor_user_id, module_key, entity_type, entity_id, action, summary, after_data)
  VALUES (
    auth.uid(), 'engineering', 'requirement_feasibility', v_review.id, 'responded',
    'Engineering feasibility response recorded.',
    jsonb_build_object(
      'requirement_id', v_review.requirement_id, 'source_revision_id', v_review.source_revision_id,
      'source_revision_number', v_review.source_revision_number,
      'master_specification_version_id', v_review.master_specification_version_id,
      'master_specification_version_number', v_review.master_specification_version_number,
      'applicable_workstreams', v_review.applicable_workstreams,
      'opportunity_id', v_requirement.opportunity_id, 'customer_id', v_requirement.customer_id,
      'department_id', v_review.department_id, 'reviewer_user_id', v_review.reviewer_user_id,
      'status', p_status, 'request_key', p_request_key,
      'response_payload', v_payload_canonical
    )
  );
  INSERT INTO public.requirement_feasibility_response_requests (
    request_key, requested_by, review_id, requirement_id, source_revision_id,
    master_specification_version_id, payload_hash, payload_canonical
  ) VALUES (
    p_request_key, auth.uid(), v_review.id, v_review.requirement_id, v_review.source_revision_id,
    v_review.master_specification_version_id, v_payload_hash, v_payload_canonical
  );
  RETURN v_review.id;
END;
$$;

REVOKE ALL ON FUNCTION public.record_requirement_feasibility_response(uuid, text, text, text, text, uuid) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.record_requirement_feasibility_response(uuid, text, text, text, text, uuid) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.read_requirement_feasibility_response_receipt(
  p_review_id uuid,
  p_requirement_id uuid,
  p_source_revision_id uuid,
  p_master_specification_version_id uuid,
  p_request_key uuid
) RETURNS TABLE (
  request_key uuid,
  review_id uuid,
  requirement_id uuid,
  source_revision_id uuid,
  master_specification_version_id uuid,
  audit_id uuid
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor_id uuid := auth.uid();
  v_receipt public.requirement_feasibility_response_requests%ROWTYPE;
  v_review public.requirement_feasibility_reviews%ROWTYPE;
  v_requirement public.customer_requirements%ROWTYPE;
  v_revision public.customer_requirement_revisions%ROWTYPE;
  v_master_version public.master_specification_versions%ROWTYPE;
  v_audit_count bigint;
  v_audit_id uuid;
BEGIN
  IF v_actor_id IS NULL OR NOT public.has_permission(v_actor_id, 'engineering.manage')
     OR p_review_id IS NULL OR p_requirement_id IS NULL OR p_source_revision_id IS NULL
     OR p_master_specification_version_id IS NULL OR p_request_key IS NULL THEN
    RAISE EXCEPTION 'Immutable reviewer response receipt-readback scope is required';
  END IF;
  SELECT * INTO v_receipt FROM public.requirement_feasibility_response_requests receipt
  WHERE receipt.request_key = p_request_key AND receipt.requested_by = v_actor_id
    AND receipt.review_id = p_review_id AND receipt.requirement_id = p_requirement_id
    AND receipt.source_revision_id = p_source_revision_id
    AND receipt.master_specification_version_id = p_master_specification_version_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Positive scoped reviewer response receipt graph is unavailable or incomplete'; END IF;
  SELECT * INTO v_review FROM public.requirement_feasibility_reviews review
  WHERE review.id = v_receipt.review_id AND review.reviewer_user_id = v_actor_id
    AND review.requirement_id = v_receipt.requirement_id
    AND review.source_revision_id = v_receipt.source_revision_id
    AND review.master_specification_version_id = v_receipt.master_specification_version_id
    AND review.status IN ('feasible', 'feasible_with_conditions', 'not_feasible')
    AND review.reviewed_at IS NOT NULL;
  IF NOT FOUND THEN RAISE EXCEPTION 'Positive scoped reviewer response receipt graph is unavailable or incomplete'; END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.employees employee
    JOIN public.employee_departments membership ON membership.employee_id = employee.id
    WHERE employee.user_id = v_actor_id AND employee.employment_status = 'ACTIVE'
      AND membership.department_id = v_review.department_id
  ) THEN RAISE EXCEPTION 'Positive scoped reviewer response receipt graph is unavailable or incomplete'; END IF;
  SELECT * INTO v_requirement FROM public.customer_requirements requirement
  WHERE requirement.id = v_review.requirement_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Positive scoped reviewer response receipt graph is unavailable or incomplete'; END IF;
  SELECT * INTO v_revision FROM public.customer_requirement_revisions revision
  WHERE revision.id = v_review.source_revision_id AND revision.requirement_id = v_requirement.id
    AND revision.revision_number = v_review.source_revision_number;
  IF NOT FOUND THEN RAISE EXCEPTION 'Positive scoped reviewer response receipt graph is unavailable or incomplete'; END IF;
  SELECT version.* INTO v_master_version FROM public.master_specification_versions version
  JOIN public.master_specifications specification ON specification.id = version.specification_id
  WHERE version.id = v_review.master_specification_version_id
    AND version.version_number = v_review.master_specification_version_number
    AND specification.opportunity_id = v_requirement.opportunity_id
    AND specification.customer_id = v_requirement.customer_id;
  IF NOT FOUND
     OR jsonb_typeof(v_master_version.specification_data -> 'workstreams') IS DISTINCT FROM 'array'
     OR jsonb_array_length(v_master_version.specification_data -> 'workstreams') = 0
     OR EXISTS (
       SELECT 1 FROM jsonb_array_elements(v_master_version.specification_data -> 'workstreams') AS workstream(value)
       WHERE jsonb_typeof(workstream.value) <> 'string'
          OR workstream.value #>> '{}' NOT IN ('HARDWARE', 'FIRMWARE', 'MECHANICAL', 'TEST', 'MANUFACTURING')
     )
     OR v_review.applicable_workstreams IS DISTINCT FROM v_master_version.specification_data -> 'workstreams'
     OR v_revision.requirement_data #>> '{source,opportunity_id}' IS DISTINCT FROM v_requirement.opportunity_id::text
     OR v_revision.requirement_data #>> '{source,customer_id}' IS DISTINCT FROM v_requirement.customer_id::text
     OR v_revision.requirement_data #>> '{source,master_specification_version_id}' IS DISTINCT FROM v_master_version.id::text
     OR v_revision.requirement_data #>> '{source,master_specification_version_number}' IS DISTINCT FROM v_master_version.version_number::text
     OR v_receipt.payload_canonical IS DISTINCT FROM public.requirement_feasibility_response_canonical_payload(
       v_review.id, v_review.status, v_review.findings, v_review.assumptions, v_review.risks
     )
     OR v_receipt.payload_hash IS DISTINCT FROM md5(v_receipt.payload_canonical::text) THEN
    RAISE EXCEPTION 'Positive scoped reviewer response receipt graph is unavailable or incomplete';
  END IF;
  SELECT count(*), min(audit.id::text)::uuid INTO v_audit_count, v_audit_id
  FROM public.activity_log audit
  WHERE audit.actor_user_id = v_actor_id AND audit.module_key = 'engineering'
    AND audit.entity_type = 'requirement_feasibility' AND audit.entity_id = v_review.id
    AND audit.action = 'responded'
    AND audit.after_data #>> '{requirement_id}' = v_review.requirement_id::text
    AND audit.after_data #>> '{source_revision_id}' = v_review.source_revision_id::text
    AND audit.after_data #>> '{master_specification_version_id}' = v_review.master_specification_version_id::text
    AND audit.after_data #>> '{reviewer_user_id}' = v_actor_id::text
    AND audit.after_data #>> '{source_revision_number}' = v_review.source_revision_number::text
    AND audit.after_data #>> '{master_specification_version_number}' = v_review.master_specification_version_number::text
    AND audit.after_data #>> '{department_id}' = v_review.department_id::text
    AND audit.after_data -> 'applicable_workstreams' = v_review.applicable_workstreams
    AND audit.after_data #>> '{status}' = v_review.status
    AND audit.after_data #>> '{request_key}' = v_receipt.request_key::text
    AND audit.after_data -> 'response_payload' = v_receipt.payload_canonical;
  IF v_audit_count <> 1 THEN
    RAISE EXCEPTION 'Positive scoped reviewer response receipt graph is unavailable or incomplete';
  END IF;
  RETURN QUERY SELECT v_receipt.request_key, v_review.id, v_requirement.id,
    v_revision.id, v_master_version.id, v_audit_id;
END;
$$;

REVOKE ALL ON FUNCTION public.read_requirement_feasibility_response_receipt(uuid, uuid, uuid, uuid, uuid) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.read_requirement_feasibility_response_receipt(uuid, uuid, uuid, uuid, uuid) TO authenticated, service_role;
-- Empty results never prove response rollback, previous response history, or concurrency.



-- REVIEWED SOURCE-ONLY ACTIVATION DRAFT. Not applied by this repository change.
-- Execute only after separately approved managed acceptance; UI remains disabled.
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
  v_root_lock_key bigint;
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

  -- Global order: request key -> receipt -> enquiry -> opportunity -> specification/version
  -- -> selected departments -> selected employees/memberships -> requirement-root
  -- -> requirement/revision -> review rows. A replay obtains the known requirement-root
  -- after its private receipt; first execution acquires the source-root before creating a
  -- requirement and then its new requirement-root. The root lock is shared only with the
  -- verified pending review assignment/response contracts. It serializes their graph
  -- insert/update paths but cannot make direct table writers safe; live installation stays
  -- blocked until direct grants/policies are removed after compatibility evidence.
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
  WHERE id = p_master_specification_version_id FOR SHARE;
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
    PERFORM 1 FROM public.departments department WHERE department.id = v_department_id AND department.is_active FOR SHARE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Selected department is unavailable'; END IF;
    PERFORM 1 FROM public.employees employee
    JOIN public.employee_departments membership ON membership.employee_id = employee.id
    WHERE employee.user_id = v_reviewer_user_id
      AND employee.employment_status = 'ACTIVE'
      AND membership.department_id = v_department_id
    FOR SHARE OF employee, membership;
    IF NOT FOUND THEN RAISE EXCEPTION 'Selected reviewer is not an active member of the selected department'; END IF;
  END LOOP;

  IF v_prior.request_key IS NOT NULL THEN
    v_root_lock_key := hashtextextended('sales-feasibility-requirement-root:' || v_prior.requirement_id::text, 0);
    PERFORM pg_advisory_xact_lock(v_root_lock_key);
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
    FOR SHARE;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Review graph has changed since this receipt was issued';
    END IF;
    SELECT * INTO v_revision
    FROM public.customer_requirement_revisions revision
    WHERE revision.id = v_prior.source_revision_id
      AND revision.requirement_id = v_prior.requirement_id
      AND revision.revision_number = v_prior.source_revision_number
    FOR SHARE;
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
      FOR SHARE
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

  -- New requirements have no existing root. Serialize the exact enquiry/opportunity/customer/
  -- Master source before creation, then reject a different request key that already owns
  -- that source tuple. This is deliberately a business-source guard, not a replacement for
  -- the private request-key receipt or the requirement-root graph lock.
  PERFORM pg_advisory_xact_lock(hashtextextended('sales-feasibility-source-root:' || p_opportunity_id::text || '|' || p_master_specification_version_id::text, 0));
  SELECT * INTO v_prior
  FROM public.sales_feasibility_handover_requests existing_source
  WHERE existing_source.opportunity_id = p_opportunity_id
    AND existing_source.customer_id = p_customer_id
    AND existing_source.master_specification_version_id = p_master_specification_version_id
    AND existing_source.payload_canonical->>'title' = btrim(p_title)
  FOR UPDATE;
  IF FOUND AND (v_prior.request_key <> p_request_key OR v_prior.requested_by <> v_actor_id) THEN
    RAISE EXCEPTION 'An existing feasibility handover already owns this source; reopen it instead';
  END IF;
  IF FOUND THEN
    v_root_lock_key := hashtextextended('sales-feasibility-requirement-root:' || v_prior.requirement_id::text, 0);
    PERFORM pg_advisory_xact_lock(v_root_lock_key);
    IF v_prior.payload_hash <> v_payload_hash OR v_prior.payload_canonical <> v_payload_canonical THEN
      RAISE EXCEPTION 'Request key conflicts with a different caller or payload';
    END IF;
    SELECT * INTO v_requirement FROM public.customer_requirements WHERE id = v_prior.requirement_id FOR SHARE;
    SELECT coalesce(array_agg((pin->>'id')::uuid ORDER BY (pin->>'department_id')::uuid, (pin->>'id')::uuid), ARRAY[]::uuid[])
    INTO v_review_ids FROM jsonb_array_elements(v_prior.review_pins) pin;
    RETURN QUERY SELECT v_prior.requirement_id, v_review_ids, true;
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
  v_root_lock_key := hashtextextended('sales-feasibility-requirement-root:' || v_requirement.id::text, 0);
  PERFORM pg_advisory_xact_lock(v_root_lock_key);
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

REVOKE ALL ON FUNCTION public.submit_sales_feasibility_handover(uuid, uuid, uuid, uuid, text, text, text, uuid[], uuid[], timestamptz, uuid) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.submit_sales_feasibility_handover(uuid, uuid, uuid, uuid, text, text, text, uuid[], uuid[], timestamptz, uuid) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.sales_feasibility_handover_canonical_payload(uuid, uuid, uuid, uuid, text, text, text, uuid[], uuid[], timestamptz) FROM PUBLIC, anon, authenticated, service_role;