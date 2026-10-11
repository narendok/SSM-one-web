-- LOCAL DISPOSABLE decision concurrency assertions only.
\set ON_ERROR_STOP on
DO $$ BEGIN
  IF (SELECT count(*) FROM public.component_candidate_decisions) <> 1 OR (SELECT count(*) FROM public.component_candidate_decision_request_receipts WHERE request_key = '20000000-0000-4000-8000-000000000091') <> 1 OR (SELECT status FROM public.component_candidate_submissions) <> 'APPROVED_PENDING_PURCHASE' THEN RAISE EXCEPTION 'Concurrent identical decision did not serialize to exactly one decision, receipt, and state transition'; END IF;
END $$;
SELECT 'BOM_CANDIDATE_DECISION_CONCURRENCY_PASS=true';