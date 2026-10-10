-- LOCAL DISPOSABLE STALE-REVISION RACE ASSERTIONS ONLY.
\set ON_ERROR_STOP on

DO $assert$
DECLARE
  v_returned integer; v_errors integer; v_stale integer; v_drafts integer; v_revisions integer; v_requests integer; v_loser_receipts integer;
  v_winner record; v_old record; v_snapshot record;
BEGIN
  SELECT count(*) FILTER (WHERE outcome = 'returned'), count(*) FILTER (WHERE outcome = 'error'), count(*) FILTER (WHERE outcome = 'error' AND sqlstate = 'P0001' AND message = 'Structured Sales draft revision conflict')
  INTO v_returned, v_errors, v_stale FROM public.structured_draft_stale_revision_race_results;
  IF v_returned <> 1 OR v_errors <> 1 OR v_stale <> 1 THEN RAISE EXCEPTION 'Stale-revision race did not produce one winner and one stale conflict'; END IF;
  SELECT * INTO v_winner FROM public.structured_draft_stale_revision_race_results WHERE outcome = 'returned';
  IF v_winner.revision_number <> 2 OR v_winner.replayed THEN RAISE EXCEPTION 'Stale-revision winner did not create revision two'; END IF;
  SELECT * INTO v_snapshot FROM public.structured_draft_stale_revision_race_history;
  SELECT * INTO v_old FROM public.sales_opportunity_structured_draft_revisions WHERE id = v_snapshot.id;
  IF v_old.draft_id IS DISTINCT FROM v_snapshot.draft_id OR v_old.revision_number IS DISTINCT FROM v_snapshot.revision_number OR v_old.parent_revision_id IS DISTINCT FROM v_snapshot.parent_revision_id OR v_old.canonical_payload IS DISTINCT FROM v_snapshot.canonical_payload OR v_old.payload_hash IS DISTINCT FROM v_snapshot.payload_hash THEN RAISE EXCEPTION 'Original revision history changed during stale-revision race'; END IF;
  SELECT count(*) INTO v_drafts FROM public.sales_opportunity_structured_drafts;
  SELECT count(*) INTO v_revisions FROM public.sales_opportunity_structured_draft_revisions;
  SELECT count(*) INTO v_requests FROM public.sales_opportunity_structured_draft_requests;
  SELECT count(*) INTO v_loser_receipts FROM public.sales_opportunity_structured_draft_requests WHERE request_key IN ('00000000-0000-4000-8000-000000000612', '00000000-0000-4000-8000-000000000613') AND revision_id <> v_winner.revision_id;
  IF v_drafts <> 1 OR v_revisions <> 2 OR v_requests <> 2 OR v_loser_receipts <> 0 THEN RAISE EXCEPTION 'Stale-revision loser wrote draft history or a receipt: %, %, %, %', v_drafts, v_revisions, v_requests, v_loser_receipts; END IF;
END;
$assert$;
SELECT 'STRUCTURED_DRAFT_STALE_REVISION_RACE_PASS' AS result, worker_label, outcome, sqlstate, message, draft_id, revision_id, revision_number, replayed FROM public.structured_draft_stale_revision_race_results ORDER BY worker_label;
SELECT count(*) AS drafts FROM public.sales_opportunity_structured_drafts;
SELECT count(*) AS revisions FROM public.sales_opportunity_structured_draft_revisions;
SELECT count(*) AS receipts FROM public.sales_opportunity_structured_draft_requests;