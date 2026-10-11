-- LOCAL DISPOSABLE WORKER ONLY. Captures expected SQLSTATE without returning a receipt on denial.
\set ON_ERROR_STOP on

SELECT set_config('request.jwt.claim.sub', :'actor_id', false);
SELECT set_config('request.jwt.claim.role', 'authenticated', false);
SELECT set_config('structured_draft.test_actor_id', :'actor_id', false);
SELECT set_config('structured_draft.test_payload', :'payload', false);
SELECT set_config('structured_draft.test_case_name', :'case_name', false);
SELECT set_config('structured_draft.test_worker_label', :'worker_label', false);

DO $worker$
DECLARE
  v_draft_id uuid; v_revision_id uuid; v_revision_number integer; v_replayed boolean;
  v_state text; v_message text; v_observed_actor uuid; v_expected_actor uuid := current_setting('structured_draft.test_actor_id')::uuid;
BEGIN
  v_observed_actor := auth.uid();
  IF v_observed_actor IS DISTINCT FROM v_expected_actor THEN
    RAISE EXCEPTION 'LOCAL_CASE_FAIL worker actor context mismatch: expected %, observed %', v_expected_actor, v_observed_actor;
  END IF;
  BEGIN
    SELECT draft_id, revision_id, revision_number, replayed
    INTO v_draft_id, v_revision_id, v_revision_number, v_replayed
    FROM public.save_sales_opportunity_structured_draft_revision(
      '00000000-0000-4000-8000-000000000201',
      '00000000-0000-4000-8000-000000000101',
      '00000000-0000-4000-8000-000000000301',
      '00000000-0000-4000-8000-000000000401',
      'SOR', 0, current_setting('structured_draft.test_payload')::jsonb,
      '00000000-0000-4000-8000-000000000601'
    );
    INSERT INTO public.structured_draft_conflict_race_results (case_name, worker_label, outcome, draft_id, revision_id, revision_number, replayed)
    VALUES (
      current_setting('structured_draft.test_case_name'),
      current_setting('structured_draft.test_worker_label'),
      'returned', v_draft_id, v_revision_id, v_revision_number, v_replayed
    );
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_message = MESSAGE_TEXT;
    INSERT INTO public.structured_draft_conflict_race_results (case_name, worker_label, outcome, sqlstate, message)
    VALUES (
      current_setting('structured_draft.test_case_name'),
      current_setting('structured_draft.test_worker_label'),
      'error', v_state, v_message
    );
  END;
END;
$worker$;

SELECT case_name, worker_label, outcome, sqlstate, message, draft_id, revision_id, revision_number, replayed
FROM public.structured_draft_conflict_race_results
WHERE case_name = current_setting('structured_draft.test_case_name')
  AND worker_label = current_setting('structured_draft.test_worker_label');
