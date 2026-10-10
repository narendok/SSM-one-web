-- LOCAL DISPOSABLE ROLLBACK ACCEPTANCE ONLY. Executes contract calls inside
-- durable cases and proves each injected failure leaves all contract tables
-- byte-for-byte identical to their pre-call state.
\set ON_ERROR_STOP on

CREATE OR REPLACE FUNCTION public.structured_draft_rollback_run_case(
  p_case_name text,
  p_failpoint text,
  p_expected_revision integer,
  p_payload jsonb,
  p_request_key uuid
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_before jsonb;
  v_after jsonb;
  v_state text;
  v_message text;
BEGIN
  v_before := public.structured_draft_rollback_capture();
  BEGIN
    PERFORM set_config('structured_draft.test_failpoint', p_failpoint, true);
    PERFORM public.save_sales_opportunity_structured_draft_revision(
      '00000000-0000-4000-8000-000000000201',
      '00000000-0000-4000-8000-000000000101',
      '00000000-0000-4000-8000-000000000301',
      '00000000-0000-4000-8000-000000000401',
      'SOR', p_expected_revision, p_payload, p_request_key
    );
    RAISE EXCEPTION 'LOCAL_CASE_FAIL failpoint was not raised: %', p_case_name;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_message = MESSAGE_TEXT;
    IF v_state <> 'P0001' OR v_message <> 'STRUCTURED_DRAFT_TEST_FAILPOINT:' || p_failpoint THEN
      RAISE;
    END IF;
  END;
  v_after := public.structured_draft_rollback_capture();
  IF v_after IS DISTINCT FROM v_before THEN
    RAISE EXCEPTION 'LOCAL_CASE_FAIL failpoint wrote partial state: %', p_case_name;
  END IF;
  INSERT INTO public.structured_draft_rollback_case_results (
    case_name, sqlstate, message, before_drafts, after_drafts,
    before_revisions, after_revisions, before_requests, after_requests
  ) VALUES (
    p_case_name, v_state, v_message,
    v_before -> 'drafts', v_after -> 'drafts',
    v_before -> 'revisions', v_after -> 'revisions',
    v_before -> 'requests', v_after -> 'requests'
  );
END;
$$;

SELECT set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000001', false);
SELECT set_config('request.jwt.claim.role', 'authenticated', false);

-- Initial-create failures prove the new draft row rolls back with the failed
-- revision or receipt insertion.
SELECT public.structured_draft_rollback_run_case(
  'create_revision', 'revision', 0,
  '{"SCOPE_STATEMENT":"Create revision failure"}'::jsonb,
  '00000000-0000-4000-8000-000000000701'
);
SELECT public.structured_draft_rollback_run_case(
  'create_receipt', 'receipt', 0,
  '{"SCOPE_STATEMENT":"Create receipt failure"}'::jsonb,
  '00000000-0000-4000-8000-000000000702'
);

-- Seed the historical draft only after the create rollback proofs, then prove
-- update failures preserve its exact current revision and immutable history.
CREATE TABLE public.structured_draft_rollback_seed AS
SELECT * FROM public.save_sales_opportunity_structured_draft_revision(
  '00000000-0000-4000-8000-000000000201',
  '00000000-0000-4000-8000-000000000101',
  '00000000-0000-4000-8000-000000000301',
  '00000000-0000-4000-8000-000000000401',
  'SOR', 0, '{"SCOPE_STATEMENT":"Seed scope","ACCEPTANCE_CRITERIA":"Seed acceptance"}'::jsonb,
  '00000000-0000-4000-8000-000000000703'
);
SELECT public.structured_draft_rollback_run_case(
  'update_revision', 'revision', 1,
  '{"SCOPE_STATEMENT":"Update revision failure","ACCEPTANCE_CRITERIA":"Seed acceptance"}'::jsonb,
  '00000000-0000-4000-8000-000000000704'
);
SELECT public.structured_draft_rollback_run_case(
  'update_receipt', 'receipt', 1,
  '{"SCOPE_STATEMENT":"Update receipt failure","ACCEPTANCE_CRITERIA":"Seed acceptance"}'::jsonb,
  '00000000-0000-4000-8000-000000000705'
);