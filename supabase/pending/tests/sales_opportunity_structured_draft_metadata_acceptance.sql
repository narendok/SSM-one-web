-- SOURCE-ONLY, UNDEPLOYED structural acceptance specification.
-- Isolated database only. Never run against the original/shared backend.
-- This fixture is not caller-transport evidence: it sets request.jwt.claim.*
-- directly. A separate authenticated application-transport runner and caller-RLS
-- observer are mandatory before the protected function could be enabled.
--
-- Required isolated-fixture variables:
-- sales_manager_user_id, outsider_user_id, opportunity_id, customer_id,
-- specification_id, master_version_id, request_key_create, request_key_replay,
-- request_key_update, request_key_restore, request_key_conflict,
-- request_key_empty_kind_baseline,
-- alternate_opportunity_id, alternate_customer_id, alternate_specification_id,
-- alternate_master_version_id. The alternate tuple must be a separate valid,
-- caller-authorized opportunity/customer/specification/version tuple.
-- The opportunity/customer/specification/version tuple must pre-exist. This file
-- creates no fixture, project, Drive row, storage object, register, document
-- number, activity audit, user, role, or permission.

\set ON_ERROR_STOP on

BEGIN;
SELECT set_config('request.jwt.claim.sub', :'sales_manager_user_id', false);
SELECT set_config('request.jwt.claim.role', 'authenticated', false);

CREATE TEMP TABLE structured_draft_first AS
SELECT * FROM public.save_sales_opportunity_structured_draft_revision(
  :'opportunity_id'::uuid, :'customer_id'::uuid, :'specification_id'::uuid,
  :'master_version_id'::uuid, 'SOR', 0,
  '{"OEM_REQUIREMENT_ROWS":"A","SCOPE_STATEMENT":"Scope","ACCEPTANCE_CRITERIA":"Accept","CAN_TELEMETRY_NOTES":"CAN","PILOT_ROLLOUT_NOTES":"Pilot","COMMERCIAL_SLA_WARRANTY_DELIVERY":"Commercial"}'::jsonb,
  :'request_key_create'::uuid
);
DO $$
BEGIN
  IF (SELECT count(*) FROM structured_draft_first) <> 1
     OR (SELECT revision_number FROM structured_draft_first) <> 1
     OR (SELECT replayed FROM structured_draft_first) THEN
    RAISE EXCEPTION 'Expected one non-replayed first structured draft revision';
  END IF;
  IF (SELECT count(*) FROM public.sales_opportunity_structured_drafts) <> 1
     OR (SELECT count(*) FROM public.sales_opportunity_structured_draft_revisions) <> 1
     OR (SELECT count(*) FROM public.sales_opportunity_structured_draft_requests) <> 1 THEN
    RAISE EXCEPTION 'First structured draft receipt graph is incomplete';
  END IF;
  IF EXISTS (SELECT 1 FROM public.activity_log WHERE entity_type = 'sales_opportunity_structured_draft') THEN
    RAISE EXCEPTION 'Metadata proposal must not create an activity audit';
  END IF;
END;
$$;

CREATE TEMP TABLE structured_draft_replay AS
SELECT * FROM public.save_sales_opportunity_structured_draft_revision(
  :'opportunity_id'::uuid, :'customer_id'::uuid, :'specification_id'::uuid,
  :'master_version_id'::uuid, 'SOR', 0,
  '{"SCOPE_STATEMENT":"Scope","OEM_REQUIREMENT_ROWS":"A","ACCEPTANCE_CRITERIA":"Accept","CAN_TELEMETRY_NOTES":"CAN","PILOT_ROLLOUT_NOTES":"Pilot","COMMERCIAL_SLA_WARRANTY_DELIVERY":"Commercial"}'::jsonb,
  :'request_key_create'::uuid
);
DO $$
BEGIN
  IF NOT (SELECT replayed FROM structured_draft_replay)
     OR (SELECT revision_id FROM structured_draft_first) IS DISTINCT FROM (SELECT revision_id FROM structured_draft_replay)
     OR (SELECT count(*) FROM public.sales_opportunity_structured_draft_revisions) <> 1 THEN
    RAISE EXCEPTION 'Exact request replay did not converge to the first revision';
  END IF;
END;
$$;

CREATE TEMP TABLE structured_draft_update AS
SELECT * FROM public.save_sales_opportunity_structured_draft_revision(
  :'opportunity_id'::uuid, :'customer_id'::uuid, :'specification_id'::uuid,
  :'master_version_id'::uuid, 'SOR', 1,
  '{"OEM_REQUIREMENT_ROWS":"A","SCOPE_STATEMENT":"Scope revised","ACCEPTANCE_CRITERIA":"Accept","CAN_TELEMETRY_NOTES":"CAN","PILOT_ROLLOUT_NOTES":"Pilot","COMMERCIAL_SLA_WARRANTY_DELIVERY":"Commercial"}'::jsonb,
  :'request_key_update'::uuid
);
DO $$
BEGIN
  IF (SELECT revision_number FROM structured_draft_update) <> 2
     OR (SELECT count(*) FROM public.sales_opportunity_structured_draft_revisions) <> 2 THEN
    RAISE EXCEPTION 'Expected one append-only revision two';
  END IF;
END;
$$;

CREATE TEMP TABLE structured_draft_restore AS
SELECT * FROM public.save_sales_opportunity_structured_draft_revision(
  :'opportunity_id'::uuid, :'customer_id'::uuid, :'specification_id'::uuid,
  :'master_version_id'::uuid, 'SOR', 2,
  '{"OEM_REQUIREMENT_ROWS":"A","SCOPE_STATEMENT":"Scope","ACCEPTANCE_CRITERIA":"Accept","CAN_TELEMETRY_NOTES":"CAN","PILOT_ROLLOUT_NOTES":"Pilot","COMMERCIAL_SLA_WARRANTY_DELIVERY":"Commercial"}'::jsonb,
  :'request_key_restore'::uuid
);
DO $$
BEGIN
  IF (SELECT revision_number FROM structured_draft_restore) <> 3
     OR (SELECT replayed FROM structured_draft_restore)
     OR (SELECT count(*) FROM public.sales_opportunity_structured_draft_revisions) <> 3 THEN
    RAISE EXCEPTION 'A new request must be able to restore a prior canonical payload as revision three';
  END IF;
END;
$$;

-- A dedicated empty-payload receipt lets the cross-kind conflict vary only the
-- document kind/schema. It must not reuse the non-empty SOR baseline receipt.
CREATE TEMP TABLE structured_draft_empty_kind_baseline AS
SELECT * FROM public.save_sales_opportunity_structured_draft_revision(
  :'opportunity_id'::uuid, :'customer_id'::uuid, :'specification_id'::uuid,
  :'master_version_id'::uuid, 'CONTRACT_REVIEW', 0,
  '{}'::jsonb, :'request_key_empty_kind_baseline'::uuid
);
DO $$
BEGIN
  IF (SELECT revision_number FROM structured_draft_empty_kind_baseline) <> 1
     OR (SELECT replayed FROM structured_draft_empty_kind_baseline)
     OR (SELECT count(*) FROM public.sales_opportunity_structured_drafts) <> 2
     OR (SELECT count(*) FROM public.sales_opportunity_structured_draft_revisions) <> 4
     OR (SELECT count(*) FROM public.sales_opportunity_structured_draft_requests) <> 4 THEN
    RAISE EXCEPTION 'Expected a distinct non-replayed empty Contract Review baseline receipt';
  END IF;
END;
$$;

CREATE TEMP TABLE structured_draft_acceptance_inputs AS
SELECT
  :'sales_manager_user_id'::uuid AS sales_manager_user_id,
  :'outsider_user_id'::uuid AS outsider_user_id,
  :'opportunity_id'::uuid AS opportunity_id,
  :'customer_id'::uuid AS customer_id,
  :'specification_id'::uuid AS specification_id,
  :'master_version_id'::uuid AS master_version_id,
  :'alternate_opportunity_id'::uuid AS alternate_opportunity_id,
  :'alternate_customer_id'::uuid AS alternate_customer_id,
  :'alternate_specification_id'::uuid AS alternate_specification_id,
  :'alternate_master_version_id'::uuid AS alternate_master_version_id,
  :'request_key_create'::uuid AS request_key_create,
  :'request_key_empty_kind_baseline'::uuid AS request_key_empty_kind_baseline;

DO $$
DECLARE
  v_input record;
  v_before_drafts integer;
  v_before_revisions integer;
  v_before_requests integer;
BEGIN
  SELECT * INTO v_input FROM structured_draft_acceptance_inputs;
  SELECT count(*) INTO v_before_drafts FROM public.sales_opportunity_structured_drafts;
  SELECT count(*) INTO v_before_revisions FROM public.sales_opportunity_structured_draft_revisions;
  SELECT count(*) INTO v_before_requests FROM public.sales_opportunity_structured_draft_requests;

  BEGIN
    PERFORM public.save_sales_opportunity_structured_draft_revision(
      v_input.alternate_opportunity_id, v_input.alternate_customer_id,
      v_input.alternate_specification_id, v_input.alternate_master_version_id,
      'SOR', 0,
      '{"OEM_REQUIREMENT_ROWS":"A","SCOPE_STATEMENT":"Scope","ACCEPTANCE_CRITERIA":"Accept","CAN_TELEMETRY_NOTES":"CAN","PILOT_ROLLOUT_NOTES":"Pilot","COMMERCIAL_SLA_WARRANTY_DELIVERY":"Commercial"}'::jsonb,
      v_input.request_key_create
    );
    RAISE EXCEPTION 'Expected same request key with a changed valid source tuple to fail';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE 'Request key conflicts with a different immutable source, schema, caller, revision, or payload' THEN
      RAISE;
    END IF;
  END;

  BEGIN
    PERFORM public.save_sales_opportunity_structured_draft_revision(
      v_input.opportunity_id, v_input.customer_id,
      v_input.specification_id, v_input.master_version_id,
      'PRS', 0,
      '{}'::jsonb, v_input.request_key_empty_kind_baseline
    );
    RAISE EXCEPTION 'Expected same empty-payload request key with only document kind/schema changed to fail';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE 'Request key conflicts with a different immutable source, schema, caller, revision, or payload' THEN
      RAISE;
    END IF;
  END;

  IF (SELECT count(*) FROM public.sales_opportunity_structured_drafts) <> v_before_drafts
     OR (SELECT count(*) FROM public.sales_opportunity_structured_draft_revisions) <> v_before_revisions
     OR (SELECT count(*) FROM public.sales_opportunity_structured_draft_requests) <> v_before_requests THEN
    RAISE EXCEPTION 'Changed-tuple request-key conflicts must not write history';
  END IF;
END;
$$;

CREATE TEMP TABLE structured_draft_negative_counts AS
SELECT
  count(*) FILTER (WHERE true)::integer AS draft_count,
  (SELECT count(*)::integer FROM public.sales_opportunity_structured_draft_revisions) AS revision_count,
  (SELECT count(*)::integer FROM public.sales_opportunity_structured_draft_requests) AS request_count
FROM public.sales_opportunity_structured_drafts;

DO $$
DECLARE
  v_input record;
  v_before record;
BEGIN
  SELECT * INTO v_input FROM structured_draft_acceptance_inputs;
  SELECT * INTO v_before FROM structured_draft_negative_counts;

  BEGIN
    PERFORM public.save_sales_opportunity_structured_draft_revision(
      v_input.opportunity_id, v_input.customer_id, v_input.specification_id,
      v_input.master_version_id, 'SOR', 3, NULL, gen_random_uuid()
    );
    RAISE EXCEPTION 'Expected NULL payload to fail';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE 'Structured Sales payload must be an object' THEN RAISE; END IF;
  END;

  BEGIN
    PERFORM public.save_sales_opportunity_structured_draft_revision(
      v_input.opportunity_id, v_input.customer_id, v_input.specification_id,
      v_input.master_version_id, 'PRS', 0,
      jsonb_build_object('VERIFICATION_METHOD', repeat('x', 1001)), gen_random_uuid()
    );
    RAISE EXCEPTION 'Expected VERIFICATION_METHOD over 1000 characters to fail';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE 'Structured Sales editable field VERIFICATION_METHOD exceeds its proposed local character limit' THEN RAISE; END IF;
  END;

  BEGIN
    PERFORM public.save_sales_opportunity_structured_draft_revision(
      v_input.opportunity_id, v_input.customer_id, v_input.specification_id,
      v_input.master_version_id, 'SOR', 2,
      '{"OEM_REQUIREMENT_ROWS":"stale"}'::jsonb, gen_random_uuid()
    );
    RAISE EXCEPTION 'Expected stale revision to fail';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE 'Structured Sales draft revision conflict' THEN RAISE; END IF;
  END;

  PERFORM set_config('request.jwt.claim.sub', v_input.outsider_user_id::text, true);
  BEGIN
    PERFORM public.save_sales_opportunity_structured_draft_revision(
      v_input.opportunity_id, v_input.customer_id, v_input.specification_id,
      v_input.master_version_id, 'SOR', 3,
      '{}'::jsonb, gen_random_uuid()
    );
    RAISE EXCEPTION 'Expected outsider caller to fail';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE 'Sales management permission is required' THEN RAISE; END IF;
  END;
  PERFORM set_config('request.jwt.claim.sub', v_input.sales_manager_user_id::text, true);

  BEGIN
    UPDATE public.sales_opportunity_structured_draft_revisions
    SET canonical_payload = '{}'::jsonb
    WHERE id = (SELECT revision_id FROM structured_draft_first);
    RAISE EXCEPTION 'Expected immutable revision update to fail';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE 'Structured Sales draft history is append-only' THEN RAISE; END IF;
  END;
  BEGIN
    DELETE FROM public.sales_opportunity_structured_draft_requests
    WHERE request_key = v_input.request_key_create;
    RAISE EXCEPTION 'Expected immutable request deletion to fail';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE 'Structured Sales draft history is append-only' THEN RAISE; END IF;
  END;

  IF (SELECT count(*) FROM public.sales_opportunity_structured_drafts) <> v_before.draft_count
     OR (SELECT count(*) FROM public.sales_opportunity_structured_draft_revisions) <> v_before.revision_count
     OR (SELECT count(*) FROM public.sales_opportunity_structured_draft_requests) <> v_before.request_count THEN
    RAISE EXCEPTION 'Negative assertions must not write structured draft history';
  END IF;
END;
$$;

-- Required separate isolated acceptance/runner evidence:
-- 1. Unknown/derived keys, arrays, objects, and numbers fail before writes.
-- 2. Wrong customer/opportunity/specification/version tuple fails before writes.
-- 3. A different authenticated actor cannot replay/read this actor-bound draft.
-- 4. No Drive, Drive revision, controlled register, storage, document-number, or
--    activity-log entity is created by any success or failure path.
-- 5. Two sessions racing the same logical identity converge to one revision or a
--    revision conflict; never two revision-1 rows.
ROLLBACK;
