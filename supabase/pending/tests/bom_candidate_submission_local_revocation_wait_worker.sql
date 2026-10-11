-- LOCAL DISPOSABLE lock-wait worker only. Synthetic auth GUCs do not model
-- managed JWT, RLS, grants, or backend connection behavior.
\set ON_ERROR_STOP on
SET application_name = 'bom_candidate_submission_revocation_waiter';
SELECT set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000001', false) \g /dev/null
SELECT * FROM public.submit_component_candidate(
  '00000000-0000-4000-8000-000000000116',
  '00000000-0000-4000-8000-000000000117',
  :'candidate_payload'::jsonb,
  :'request_key'::uuid
);