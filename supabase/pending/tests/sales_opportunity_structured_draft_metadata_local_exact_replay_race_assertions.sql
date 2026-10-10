-- LOCAL DISPOSABLE EXACT-REPLAY RACE ASSERTIONS ONLY.
\set ON_ERROR_STOP on

DO $assert$
DECLARE
  v_results integer;
  v_drafts integer;
  v_revisions integer;
  v_requests integer;
  v_distinct_drafts integer;
  v_distinct_revisions integer;
  v_replayed integer;
BEGIN
  SELECT count(*), count(DISTINCT draft_id), count(DISTINCT revision_id), count(*) FILTER (WHERE replayed)
  INTO v_results, v_distinct_drafts, v_distinct_revisions, v_replayed
  FROM public.structured_draft_exact_replay_race_results;
  SELECT count(*) INTO v_drafts FROM public.sales_opportunity_structured_drafts;
  SELECT count(*) INTO v_revisions FROM public.sales_opportunity_structured_draft_revisions;
  SELECT count(*) INTO v_requests FROM public.sales_opportunity_structured_draft_requests;

  IF v_results <> 2 OR v_distinct_drafts <> 1 OR v_distinct_revisions <> 1 OR v_replayed <> 1
     OR v_drafts <> 1 OR v_revisions <> 1 OR v_requests <> 1 THEN
    RAISE EXCEPTION 'Exact replay race did not converge to one write set and identical IDs';
  END IF;
END;
$assert$;

SELECT 'STRUCTURED_DRAFT_EXACT_REPLAY_RACE_PASS' AS result,
  count(*) AS worker_results,
  count(DISTINCT draft_id) AS distinct_draft_ids,
  count(DISTINCT revision_id) AS distinct_revision_ids,
  count(*) FILTER (WHERE replayed) AS replayed_results
FROM public.structured_draft_exact_replay_race_results;

SELECT worker_label, draft_id, revision_id, revision_number, replayed
FROM public.structured_draft_exact_replay_race_results
ORDER BY worker_label;

SELECT count(*) AS drafts FROM public.sales_opportunity_structured_drafts;
SELECT count(*) AS revisions FROM public.sales_opportunity_structured_draft_revisions;
SELECT count(*) AS receipts FROM public.sales_opportunity_structured_draft_requests;