-- LOCAL DISPOSABLE lock-wait worker only. Synthetic auth GUCs do not model
-- managed JWT, RLS, grants, or backend connection behavior.
\set ON_ERROR_STOP on
SET application_name = 'bom_candidate_decision_revocation_waiter';
SELECT set_config('request.jwt.claim.sub', '30000000-0000-4000-8000-000000000002', false) \g /dev/null
SELECT * FROM public.decide_component_candidate(
  :'candidate_id'::uuid,
  :'revision_id'::uuid,
  :'decision',
  :'decision_note',
  :'request_key'::uuid
);