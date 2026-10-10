-- LOCAL DISPOSABLE CONFLICT-RACE ASSERTIONS ONLY.
\set ON_ERROR_STOP on

DO $assert$
DECLARE v_case text; v_results integer; v_returned integer; v_errors integer; v_bad integer; v_drafts integer; v_revisions integer; v_requests integer;
BEGIN
  FOREACH v_case IN ARRAY ARRAY['changed_payload', 'different_actor'] LOOP
    SELECT count(*), count(*) FILTER (WHERE outcome = 'returned'), count(*) FILTER (WHERE outcome = 'error'),
      count(*) FILTER (WHERE outcome = 'error' AND sqlstate = 'P0001' AND message = 'Request key conflicts with a different immutable source, schema, caller, revision, or payload')
    INTO v_results, v_returned, v_errors, v_bad
    FROM public.structured_draft_conflict_race_results WHERE case_name = v_case;
    IF v_results <> 2 OR v_returned <> 1 OR v_errors <> 1 OR v_bad <> 1 THEN
      RAISE EXCEPTION 'Conflict race % did not produce one winner and one receipt-conflict denial', v_case;
    END IF;
  END LOOP;
  SELECT count(*) INTO v_drafts FROM public.sales_opportunity_structured_drafts;
  SELECT count(*) INTO v_revisions FROM public.sales_opportunity_structured_draft_revisions;
  SELECT count(*) INTO v_requests FROM public.sales_opportunity_structured_draft_requests;
  IF v_drafts <> 2 OR v_revisions <> 2 OR v_requests <> 2 THEN
    RAISE EXCEPTION 'Conflict races wrote an extra draft, revision, or receipt: %, %, %', v_drafts, v_revisions, v_requests;
  END IF;
END;
$assert$;

SELECT 'STRUCTURED_DRAFT_CONFLICT_RACE_PASS' AS result, case_name, worker_label, outcome, sqlstate, message, draft_id, revision_id, revision_number, replayed
FROM public.structured_draft_conflict_race_results ORDER BY case_name, worker_label;
SELECT count(*) AS drafts FROM public.sales_opportunity_structured_drafts;
SELECT count(*) AS revisions FROM public.sales_opportunity_structured_draft_revisions;
SELECT count(*) AS receipts FROM public.sales_opportunity_structured_draft_requests;
