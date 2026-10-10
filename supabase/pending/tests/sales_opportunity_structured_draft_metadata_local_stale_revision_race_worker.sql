-- LOCAL DISPOSABLE WORKER ONLY. Captures the stale conflict without a receipt result.
\set ON_ERROR_STOP on

SELECT set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000001', false);
SELECT set_config('request.jwt.claim.role', 'authenticated', false);
SELECT set_config('structured_draft.stale_payload', :'payload', false);
SELECT set_config('structured_draft.stale_worker_label', :'worker_label', false);
SELECT set_config('structured_draft.stale_request_key', :'request_key', false);
DO $worker$
DECLARE
  v_draft_id uuid; v_revision_id uuid; v_revision_number integer; v_replayed boolean;
  v_state text; v_message text;
BEGIN
  BEGIN
    SELECT draft_id, revision_id, revision_number, replayed INTO v_draft_id, v_revision_id, v_revision_number, v_replayed
    FROM public.save_sales_opportunity_structured_draft_revision(
      '00000000-0000-4000-8000-000000000201', '00000000-0000-4000-8000-000000000101',
      '00000000-0000-4000-8000-000000000301', '00000000-0000-4000-8000-000000000401',
      'SOR', 1, current_setting('structured_draft.stale_payload')::jsonb,
      current_setting('structured_draft.stale_request_key')::uuid
    );
    INSERT INTO public.structured_draft_stale_revision_race_results (worker_label, outcome, draft_id, revision_id, revision_number, replayed)
    VALUES (current_setting('structured_draft.stale_worker_label'), 'returned', v_draft_id, v_revision_id, v_revision_number, v_replayed);
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_message = MESSAGE_TEXT;
    INSERT INTO public.structured_draft_stale_revision_race_results (worker_label, outcome, sqlstate, message)
    VALUES (current_setting('structured_draft.stale_worker_label'), 'error', v_state, v_message);
  END;
END;
$worker$;
SELECT worker_label, outcome, sqlstate, message, draft_id, revision_id, revision_number, replayed
FROM public.structured_draft_stale_revision_race_results WHERE worker_label = current_setting('structured_draft.stale_worker_label');