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

CREATE TEMP TABLE structured_draft_acceptance_inputs AS
SELECT
  :'opportunity_id'::uuid AS opportunity_id,
  :'customer_id'::uuid AS customer_id,
  :'specification_id'::uuid AS specification_id,
  :'master_version_id'::uuid AS master_version_id,
  :'alternate_opportunity_id'::uuid AS alternate_opportunity_id,
  :'alternate_customer_id'::uuid AS alternate_customer_id,
  :'alternate_specification_id'::uuid AS alternate_specification_id,
  :'alternate_master_version_id'::uuid AS alternate_master_version_id,
  :'request_key_create'::uuid AS request_key_create;

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
      '{"OEM_REQUIREMENT_ROWS":"alternate"}'::jsonb, v_input.request_key_create
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
      '{"VERIFICATION_METHOD":"inspection"}'::jsonb, v_input.request_key_create
    );
    RAISE EXCEPTION 'Expected same request key with a changed document kind/schema to fail';
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

-- Required negative assertions for the isolated implementation/runner:
-- 1. NULL payloads, unknown/derived keys, arrays, objects, numbers, and scalar
--    values over the proposed local limit fail before any draft/revision/request
--    insertion. VERIFICATION_METHOD is limited to 1,000 characters; all other
--    present current-editor fields are limited to 8,000. Omitted current-editor
--    fields remain omitted in canonical payloads, matching the local validator.
-- 2. Wrong customer/opportunity/specification/version tuple fails before writes.
-- 3. Stale expected revision and reused request key with changed payload fail.
-- 4. A different authenticated actor cannot replay/read this actor-bound draft.
-- 5. The outsider caller fails before receipt lookup or write.
-- 6. UPDATE/DELETE attempts against all three proposed tables fail as immutable.
-- 7. No Drive, Drive revision, controlled register, storage, document-number, or
--    activity-log entity is created by any success or failure path.
-- 8. Two sessions racing the same logical identity converge to one revision or a
--    revision conflict; never two revision-1 rows.
ROLLBACK;
