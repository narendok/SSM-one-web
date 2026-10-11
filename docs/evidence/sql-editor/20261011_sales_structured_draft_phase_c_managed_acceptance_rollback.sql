-- PHASE C1 OPERATOR ROLLBACK-ONLY FUNCTION-LOGIC HARNESS. NEVER COMMIT.
-- Run only in the Cloud SQL editor as the operator after Phase A and a separately authorized
-- private-location binding exist. This temporarily grants the five reviewed entry points, invokes
-- the audited save, exact replay, and request-scoped audit checks, then rolls everything back.
-- It proves transaction/contract logic only. SQL editor execution is NOT genuine caller authentication.

BEGIN;

-- Operator-claim simulation only: this setting drives the function's auth.uid() in the SQL editor.
-- Replace with an existing authorized Sales actor UUID after verifying that actor separately.
SET LOCAL request.jwt.claim.sub = '00000000-0000-0000-0000-000000000000';
SET LOCAL request.jwt.claim.role = 'authenticated';

CREATE TEMP TABLE phase_c1_context (
  simulated_actor_id uuid NOT NULL,
  private_location_id uuid NOT NULL,
  request_key uuid NOT NULL
) ON COMMIT DROP;

-- Replace both zero UUIDs with the verified existing Sales actor and separately approved private-location id.
INSERT INTO phase_c1_context(simulated_actor_id, private_location_id, request_key)
VALUES (
  '00000000-0000-0000-0000-000000000000'::uuid,
  '00000000-0000-0000-0000-000000000000'::uuid,
  gen_random_uuid()
);

DO $preflight$
DECLARE v_actor uuid; v_private_location uuid;
BEGIN
  SELECT simulated_actor_id, private_location_id INTO v_actor, v_private_location FROM phase_c1_context;
  IF v_actor = '00000000-0000-0000-0000-000000000000'::uuid OR auth.uid() IS DISTINCT FROM v_actor THEN
    RAISE EXCEPTION 'PHASE_C1_SIMULATED_ACTOR_REQUIRED: set the same verified actor UUID in the editor claim and context';
  END IF;
  IF v_private_location = '00000000-0000-0000-0000-000000000000'::uuid THEN
    RAISE EXCEPTION 'PHASE_C1_PRIVATE_LOCATION_REQUIRED: use the separately approved verified private-location id';
  END IF;
  IF NOT public.has_permission(v_actor, 'sales.manage') THEN
    RAISE EXCEPTION 'PHASE_C1_SIMULATED_ACTOR_NOT_AUTHORIZED: chosen actor lacks sales.manage';
  END IF;
  IF NOT EXISTS (
    SELECT 1
    FROM public.sales_opportunity_structured_draft_private_locations AS l
    JOIN public.drive_nodes AS folder ON folder.id = l.drive_folder_node_id
    WHERE l.id = v_private_location
      AND l.is_active
      AND l.visibility_scope = 'PRIVATE'
      AND l.verified_private_at IS NOT NULL
      AND l.private_storage_bucket = 'project-drive'
      AND l.private_storage_prefix = 'sales/opportunity/a6c62c81-1cc2-4804-b1c5-c004c6730b52/'
      AND folder.is_locked AND NOT folder.is_trashed
      AND folder.project_id IS NULL AND folder.storage_bucket IS NULL AND folder.storage_path IS NULL
  ) THEN
    RAISE EXCEPTION 'PHASE_C1_PRIVATE_LOCATION_INVALID: verified exact Sales private location is absent';
  END IF;
END;
$preflight$;

-- Operator-only, transaction-local grants. They are required because authenticated callers cannot
-- grant themselves access and PostgREST/RPC cannot execute arbitrary SQL. ROLLBACK removes them.
GRANT EXECUTE ON FUNCTION public.save_sales_opportunity_structured_draft_at_location(uuid, uuid, uuid, uuid, text, integer, jsonb, uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.resolve_sales_opportunity_structured_draft_location(uuid, uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.register_sales_opportunity_structured_draft_storage_attempt(uuid, uuid, uuid, uuid, text, text, text, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.commit_sales_opportunity_structured_draft_materialization(uuid, uuid, uuid, uuid, text, text, text, text, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_discard_sales_opportunity_structured_draft_object(uuid, uuid, uuid, uuid, text, text) TO authenticated;

CREATE TEMP TABLE phase_c1_first_save AS
SELECT * FROM public.save_sales_opportunity_structured_draft_at_location(
  'a6c62c81-1cc2-4804-b1c5-c004c6730b52'::uuid,
  '03e06115-a7d4-4965-9e92-9c37462f5ddc'::uuid,
  '7a3aba95-61f6-495a-a280-f37a3be77670'::uuid,
  '4914fba5-43a0-4486-b62f-d775a9bb16b9'::uuid,
  'SOR', 0, '{"SCOPE_STATEMENT":"Phase C1 operator rollback-only acceptance"}'::jsonb,
  (SELECT request_key FROM phase_c1_context), (SELECT private_location_id FROM phase_c1_context)
);

CREATE TEMP TABLE phase_c1_exact_replay AS
SELECT * FROM public.save_sales_opportunity_structured_draft_at_location(
  'a6c62c81-1cc2-4804-b1c5-c004c6730b52'::uuid,
  '03e06115-a7d4-4965-9e92-9c37462f5ddc'::uuid,
  '7a3aba95-61f6-495a-a280-f37a3be77670'::uuid,
  '4914fba5-43a0-4486-b62f-d775a9bb16b9'::uuid,
  'SOR', 0, '{"SCOPE_STATEMENT":"Phase C1 operator rollback-only acceptance"}'::jsonb,
  (SELECT request_key FROM phase_c1_context), (SELECT private_location_id FROM phase_c1_context)
);

DO $assert$
DECLARE v_request_key uuid := (SELECT request_key FROM phase_c1_context); v_draft_id uuid := (SELECT draft_id FROM phase_c1_first_save);
BEGIN
  IF (SELECT count(*) FROM phase_c1_first_save) <> 1 OR (SELECT replayed FROM phase_c1_first_save) THEN
    RAISE EXCEPTION 'PHASE_C1_SAVE_FAILED: expected one non-replayed pinned draft save';
  END IF;
  IF (SELECT count(*) FROM phase_c1_exact_replay) <> 1 OR NOT (SELECT replayed FROM phase_c1_exact_replay) THEN
    RAISE EXCEPTION 'PHASE_C1_REPLAY_FAILED: expected exact request-key replay';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.sales_opportunity_structured_draft_audit_events
    WHERE request_key = v_request_key AND draft_id = v_draft_id
  ) THEN
    RAISE EXCEPTION 'PHASE_C1_AUDIT_FAILED: request-scoped immutable save audit was not recorded';
  END IF;
END;
$assert$;

SELECT 'PHASE_C1_OPERATOR_ROLLBACK_LOGIC_PASSED' AS result,
       (SELECT simulated_actor_id FROM phase_c1_context) AS simulated_actor;
ROLLBACK;

-- C2 genuine caller acceptance is intentionally outside this SQL-editor harness.
-- It becomes executable only after Phase D commits the five reviewed authenticated EXECUTE grants.
-- Use the app's existing authenticated browser/session to call the deployed function through its
-- supported RPC/client path; capture auth.uid()-derived success, exact replay, and denial cases there.