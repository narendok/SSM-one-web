-- LOCAL DISPOSABLE authorization-revocation worker only.
\set ON_ERROR_STOP on
SELECT set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000001', false);
SELECT * FROM public.submit_component_candidate('00000000-0000-4000-8000-000000000216', '00000000-0000-4000-8000-000000000217', '{"categoryId":"cat-1","name":"Revoked","partNumber":"R-REVOKED"}'::jsonb, '00000000-0000-4000-8000-000000000290');