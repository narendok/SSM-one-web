-- LOCAL DISPOSABLE ROLLBACK ASSERTIONS ONLY.
\set ON_ERROR_STOP on

DO $assert$
DECLARE
  v_cases integer;
  v_drafts integer;
  v_revisions integer;
  v_requests integer;
  v_seed_revision jsonb;
  v_current_revision jsonb;
BEGIN
  SELECT count(*) INTO v_cases FROM public.structured_draft_rollback_case_results;
  SELECT count(*) INTO v_drafts FROM public.sales_opportunity_structured_drafts;
  SELECT count(*) INTO v_revisions FROM public.sales_opportunity_structured_draft_revisions;
  SELECT count(*) INTO v_requests FROM public.sales_opportunity_structured_draft_requests;
  SELECT to_jsonb(revision) INTO v_seed_revision
  FROM public.sales_opportunity_structured_draft_revisions AS revision
  JOIN public.structured_draft_rollback_seed AS seed ON seed.revision_id = revision.id;
  SELECT to_jsonb(revision) INTO v_current_revision
  FROM public.sales_opportunity_structured_draft_revisions AS revision
  JOIN public.structured_draft_rollback_seed AS seed ON seed.revision_id = revision.id;

  IF v_cases <> 4 OR v_drafts <> 1 OR v_revisions <> 1 OR v_requests <> 1
    OR v_seed_revision IS DISTINCT FROM v_current_revision THEN
    RAISE EXCEPTION 'Structured draft rollback assertions failed';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.structured_draft_rollback_case_results
    WHERE sqlstate <> 'P0001'
      OR message NOT IN ('STRUCTURED_DRAFT_TEST_FAILPOINT:revision', 'STRUCTURED_DRAFT_TEST_FAILPOINT:receipt')
      OR before_drafts IS DISTINCT FROM after_drafts
      OR before_revisions IS DISTINCT FROM after_revisions
      OR before_requests IS DISTINCT FROM after_requests
  ) THEN
    RAISE EXCEPTION 'Structured draft failpoint changed persisted state';
  END IF;
END;
$assert$;

SELECT 'STRUCTURED_DRAFT_ROLLBACK_ACCEPTANCE_PASS' AS result,
  case_name, sqlstate, message,
  jsonb_array_length(before_drafts) AS drafts_before,
  jsonb_array_length(after_drafts) AS drafts_after,
  jsonb_array_length(before_revisions) AS revisions_before,
  jsonb_array_length(after_revisions) AS revisions_after,
  jsonb_array_length(before_requests) AS receipts_before,
  jsonb_array_length(after_requests) AS receipts_after
FROM public.structured_draft_rollback_case_results
ORDER BY case_name;

SELECT count(*) AS drafts FROM public.sales_opportunity_structured_drafts;
SELECT count(*) AS revisions FROM public.sales_opportunity_structured_draft_revisions;
SELECT count(*) AS receipts FROM public.sales_opportunity_structured_draft_requests;