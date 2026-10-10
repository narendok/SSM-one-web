-- LOCAL DISPOSABLE WORKER ONLY. Its save call must wait inside the contract.
\set ON_ERROR_STOP on

SELECT set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000001', false);
SELECT set_config('request.jwt.claim.role', 'authenticated', false);
SELECT set_config('structured_draft.authorization_case', :'authorization_case', false);
DO $worker$
DECLARE
  v_draft_id uuid; v_revision_id uuid; v_revision_number integer; v_replayed boolean;
  v_state text; v_message text; v_case text := current_setting('structured_draft.authorization_case');
BEGIN
  BEGIN
    SELECT draft_id, revision_id, revision_number, replayed INTO v_draft_id, v_revision_id, v_revision_number, v_replayed
    FROM public.save_sales_opportunity_structured_draft_revision(
      '00000000-0000-4000-8000-000000000201', '00000000-0000-4000-8000-000000000101',
      '00000000-0000-4000-8000-000000000301', '00000000-0000-4000-8000-000000000401',
      'SOR', CASE WHEN v_case = 'new_write' THEN 1 ELSE 0 END,
      CASE WHEN v_case = 'new_write'
        THEN '{"SCOPE_STATEMENT":"Unauthorized new write","ACCEPTANCE_CRITERIA":"Must be denied"}'::jsonb
        ELSE '{"SCOPE_STATEMENT":"Replay seed scope","ACCEPTANCE_CRITERIA":"Replay seed acceptance"}'::jsonb END,
      CASE WHEN v_case = 'new_write' THEN '00000000-0000-4000-8000-000000000802'::uuid ELSE '00000000-0000-4000-8000-000000000801'::uuid END
    );
    INSERT INTO public.structured_draft_authorization_after_lock_results (case_name, outcome, draft_id, revision_id, revision_number, replayed)
    VALUES (v_case, 'returned', v_draft_id, v_revision_id, v_revision_number, v_replayed);
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_message = MESSAGE_TEXT;
    INSERT INTO public.structured_draft_authorization_after_lock_results (case_name, outcome, sqlstate, message)
    VALUES (v_case, 'error', v_state, v_message);
  END;
END;
$worker$;
SELECT case_name, outcome, sqlstate, message, draft_id, revision_id, revision_number, replayed
FROM public.structured_draft_authorization_after_lock_results
WHERE case_name = current_setting('structured_draft.authorization_case');
