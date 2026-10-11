-- LOCAL DISPOSABLE decision concurrency worker only.
\set ON_ERROR_STOP on
SELECT set_config('request.jwt.claim.sub', '20000000-0000-4000-8000-000000000002', false);
SELECT * FROM public.decide_component_candidate(
  (SELECT candidate_id FROM public.component_candidate_submission_request_receipts WHERE request_key = '20000000-0000-4000-8000-000000000090'),
  (SELECT payload_revision_id FROM public.component_candidate_submission_request_receipts WHERE request_key = '20000000-0000-4000-8000-000000000090'),
  'APPROVE', 'Concurrent decision', '20000000-0000-4000-8000-000000000091'
);