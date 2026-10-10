-- LOCAL DISPOSABLE AUTHORIZATION-AFTER-LOCK ASSERTIONS ONLY.
\set ON_ERROR_STOP on

DO $assert$
DECLARE
  v_snapshot jsonb;
  v_current jsonb;
  v_drafts integer;
  v_revisions integer;
  v_requests integer;
BEGIN
  SELECT contents INTO v_snapshot FROM public.structured_draft_authorization_after_lock_snapshot;
  SELECT jsonb_build_object(
    'drafts', coalesce((SELECT jsonb_agg(to_jsonb(draft) ORDER BY draft.id) FROM public.sales_opportunity_structured_drafts AS draft), '[]'::jsonb),
    'revisions', coalesce((SELECT jsonb_agg(to_jsonb(revision) ORDER BY revision.draft_id, revision.revision_number) FROM public.sales_opportunity_structured_draft_revisions AS revision), '[]'::jsonb),
    'requests', coalesce((SELECT jsonb_agg(to_jsonb(request_receipt) ORDER BY request_receipt.request_key) FROM public.sales_opportunity_structured_draft_requests AS request_receipt), '[]'::jsonb)
  ) INTO v_current;
  IF v_current IS DISTINCT FROM v_snapshot THEN
    RAISE EXCEPTION 'Authorization-after-lock denial changed persisted draft contents';
  END IF;
  IF (SELECT count(*) FROM public.structured_draft_authorization_after_lock_results WHERE outcome = 'error' AND sqlstate = 'P0001' AND message = 'Sales management permission is required') <> 2
    OR EXISTS (SELECT 1 FROM public.structured_draft_authorization_after_lock_results WHERE draft_id IS NOT NULL OR revision_id IS NOT NULL) THEN
    RAISE EXCEPTION 'Authorization-after-lock calls returned a receipt or wrong denial';
  END IF;
  SELECT count(*) INTO v_drafts FROM public.sales_opportunity_structured_drafts;
  SELECT count(*) INTO v_revisions FROM public.sales_opportunity_structured_draft_revisions;
  SELECT count(*) INTO v_requests FROM public.sales_opportunity_structured_draft_requests;
  IF v_drafts <> 1 OR v_revisions <> 1 OR v_requests <> 1 THEN
    RAISE EXCEPTION 'Authorization-after-lock denial changed counts: %, %, %', v_drafts, v_revisions, v_requests;
  END IF;
END;
$assert$;

SELECT 'STRUCTURED_DRAFT_AUTHORIZATION_AFTER_LOCK_PASS' AS result, case_name, outcome, sqlstate, message, draft_id, revision_id, revision_number, replayed
FROM public.structured_draft_authorization_after_lock_results ORDER BY case_name;
SELECT count(*) AS drafts FROM public.sales_opportunity_structured_drafts;
SELECT count(*) AS revisions FROM public.sales_opportunity_structured_draft_revisions;
SELECT count(*) AS receipts FROM public.sales_opportunity_structured_draft_requests;
