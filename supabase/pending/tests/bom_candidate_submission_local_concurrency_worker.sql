-- LOCAL DISPOSABLE worker only.
\set ON_ERROR_STOP on
SELECT set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000001', false);
SELECT * FROM public.submit_component_candidate('00000000-0000-4000-8000-000000000116', '00000000-0000-4000-8000-000000000117', '{"categoryId":"cat-1","name":"Concurrent","partNumber":"R-CONCURRENT"}'::jsonb, '00000000-0000-4000-8000-000000000190');