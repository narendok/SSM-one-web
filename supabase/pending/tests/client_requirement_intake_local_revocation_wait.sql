-- LOCAL DISPOSABLE WAITING-WORKER ONLY. Synthetic auth GUCs do not represent
-- managed JWT, RLS, grant, or connection behavior.
\set ON_ERROR_STOP on
SELECT set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000001', false);
SELECT set_config('request.jwt.claim.role', 'authenticated', false);
SELECT public.submit_external_customer_requirement(
  '00000000-0000-4000-8000-000000000020',
  '00000000-0000-4000-8000-000000000010',
  'Revoked while waiting',
  'REQ-REVOKED-WAIT',
  '{"description":"Scope must be revalidated after the request lock wait"}'::jsonb,
  '00000000-0000-4000-8000-000000000096'
);