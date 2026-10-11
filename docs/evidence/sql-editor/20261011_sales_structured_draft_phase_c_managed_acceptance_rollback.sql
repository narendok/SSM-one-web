-- PHASE C ROLLBACK-ONLY ACCEPTANCE HARNESS. NEVER COMMIT.
-- Execute only through a real authenticated caller transport for an existing authorized Sales actor,
-- after a separately authorized ACTIVE location binding exists for the exact pinned source tuple.
--
-- This SQL asserts an already-established request context. It does not establish one:
-- SET LOCAL ROLE authenticated, SET LOCAL request.jwt.claim.sub, or an operator-supplied UUID are
-- operator claim simulations only. They may exercise function logic but are not caller-authentication evidence.
-- A genuine result requires the managed transport to populate auth.uid() from the caller's verified bearer/JWT.

BEGIN;

CREATE TEMP TABLE phase_c_context (
  actor_id uuid NOT NULL,
  private_location_id uuid NOT NULL,
  request_key uuid NOT NULL,
  replay_request_key uuid NOT NULL
) ON COMMIT DROP;

-- The authenticated caller transport must replace only the private-location UUID below
-- before submitting this whole transaction. Do not supply or SET an actor UUID: it is derived from auth.uid().
INSERT INTO phase_c_context(actor_id, private_location_id, request_key, replay_request_key)
SELECT auth.uid(),
       '00000000-0000-0000-0000-000000000000'::uuid,
       gen_random_uuid(),
       gen_random_uuid();

DO $preflight$
DECLARE v_actor uuid; v_private_location uuid;
BEGIN
  SELECT actor_id, private_location_id INTO v_actor, v_private_location FROM phase_c_context;
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'PHASE_C_NOT_GENUINE_CALLER_CONTEXT: auth.uid() is null; SQL-editor role or claim simulation is not acceptance';
  END IF;
  IF NOT public.has_permission(v_actor, 'sales.manage') THEN
    RAISE EXCEPTION 'PHASE_C_ACTOR_NOT_AUTHORIZED: authenticated caller lacks sales.manage';
  END IF;
  IF v_private_location = '00000000-0000-0000-0000-000000000000'::uuid THEN
    RAISE EXCEPTION 'PHASE_C_LOCATION_REQUIRED: use the separately approved verified private-location id';
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
    RAISE EXCEPTION 'PHASE_C_LOCATION_INVALID: verified exact Sales private location is absent';
  END IF;
END;
$preflight$;

-- Five entry-point grants are deliberately transaction-local and must be used only if the existing
-- authenticated caller transport otherwise receives permission denied. They roll back below.
GRANT EXECUTE ON FUNCTION public.save_sales_opportunity_structured_draft_at_location(uuid, uuid, uuid, uuid, text, integer, jsonb, uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.resolve_sales_opportunity_structured_draft_location(uuid, uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.register_sales_opportunity_structured_draft_storage_attempt(uuid, uuid, uuid, uuid, text, text, text, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.commit_sales_opportunity_structured_draft_materialization(uuid, uuid, uuid, uuid, text, text, text, text, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_discard_sales_opportunity_structured_draft_object(uuid, uuid, uuid, uuid, text, text) TO authenticated;

CREATE TEMP TABLE phase_c_first_save AS
SELECT * FROM public.save_sales_opportunity_structured_draft_at_location(
  'a6c62c81-1cc2-4804-b1c5-c004c6730b52'::uuid,
  '03e06115-a7d4-4965-9e92-9c37462f5ddc'::uuid,
  '7a3aba95-61f6-495a-a280-f37a3be77670'::uuid,
  '4914fba5-43a0-4486-b62f-d775a9bb16b9'::uuid,
  'SOR', 0, '{"SCOPE_STATEMENT":"Phase C rollback-only authenticated acceptance"}'::jsonb,
  (SELECT request_key FROM phase_c_context), (SELECT private_location_id FROM phase_c_context)
);

CREATE TEMP TABLE phase_c_exact_replay AS
SELECT * FROM public.save_sales_opportunity_structured_draft_at_location(
  'a6c62c81-1cc2-4804-b1c5-c004c6730b52'::uuid,
  '03e06115-a7d4-4965-9e92-9c37462f5ddc'::uuid,
  '7a3aba95-61f6-495a-a280-f37a3be77670'::uuid,
  '4914fba5-43a0-4486-b62f-d775a9bb16b9'::uuid,
  'SOR', 0, '{"SCOPE_STATEMENT":"Phase C rollback-only authenticated acceptance"}'::jsonb,
  (SELECT request_key FROM phase_c_context), (SELECT private_location_id FROM phase_c_context)
);

DO $assert$
BEGIN
  IF (SELECT count(*) FROM phase_c_first_save) <> 1 OR (SELECT replayed FROM phase_c_first_save) THEN
    RAISE EXCEPTION 'PHASE_C_SAVE_FAILED: expected one non-replayed pinned draft save';
  END IF;
  IF (SELECT count(*) FROM phase_c_exact_replay) <> 1 OR NOT (SELECT replayed FROM phase_c_exact_replay) THEN
    RAISE EXCEPTION 'PHASE_C_REPLAY_FAILED: expected exact request-key replay';
  END IF;
  IF (SELECT count(*) FROM public.sales_opportunity_structured_draft_audit_events) < 1 THEN
    RAISE EXCEPTION 'PHASE_C_AUDIT_FAILED: immutable save audit was not recorded';
  END IF;
END;
$assert$;

SELECT 'PHASE_C_ROLLBACK_ONLY_FUNCTION_ACCEPTANCE_PASSED' AS result,
       (SELECT actor_id FROM phase_c_context) AS transport_authenticated_actor;
ROLLBACK;

-- This script deliberately does not simulate upload/materialization. Those calls require a real staged
-- private object and must be accepted through the same caller transport in a separate rollback-only run.