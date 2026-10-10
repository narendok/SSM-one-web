-- LOCAL DISPOSABLE CONCURRENCY WORKERS ONLY. Each session uses a synthetic
-- auth.uid() GUC; this does not represent managed JWT/RLS/grant behavior.
\set ON_ERROR_STOP on
SELECT set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000001', false);
SELECT set_config('request.jwt.claim.role', 'authenticated', false);
SELECT pg_advisory_lock(918273645);
SELECT pg_advisory_unlock(918273645);
SELECT public.submit_external_customer_requirement(
  '00000000-0000-4000-8000-000000000020',
  '00000000-0000-4000-8000-000000000010',
  :'submission_title',
  'REQ-CONCURRENT',
  :'submission_payload'::jsonb,
  '00000000-0000-4000-8000-000000000095'
) AS requirement_id;
SELECT pg_advisory_unlock(918273645);