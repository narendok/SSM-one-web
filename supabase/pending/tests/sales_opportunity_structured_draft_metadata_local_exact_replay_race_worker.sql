-- LOCAL DISPOSABLE WORKER ONLY. One independent psql process invokes the
-- protected contract and durably records its returned receipt identifiers.
\set ON_ERROR_STOP on

SELECT set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000001', false);
SELECT set_config('request.jwt.claim.role', 'authenticated', false);

WITH response AS (
  SELECT * FROM public.save_sales_opportunity_structured_draft_revision(
    '00000000-0000-4000-8000-000000000201',
    '00000000-0000-4000-8000-000000000101',
    '00000000-0000-4000-8000-000000000301',
    '00000000-0000-4000-8000-000000000401',
    'SOR', 0,
    '{"SCOPE_STATEMENT":"Concurrent scope","ACCEPTANCE_CRITERIA":"Concurrent acceptance"}'::jsonb,
    '00000000-0000-4000-8000-000000000601'
  )
)
INSERT INTO public.structured_draft_exact_replay_race_results (
  worker_label, draft_id, revision_id, revision_number, replayed
)
SELECT :'worker_label', draft_id, revision_id, revision_number, replayed
FROM response
RETURNING worker_label, draft_id, revision_id, revision_number, replayed;