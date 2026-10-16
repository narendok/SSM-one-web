-- Synthetic overlapping saves only. First writer holds root through commit.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL statement_timeout='12s';
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000062',true);
SELECT public.save_requirement_internal_note(review.id,review.source_revision_id,review.master_specification_version_id,0,'Concurrent winning note','00000000-0000-4000-8000-000000000331')
FROM public.requirement_feasibility_reviews review JOIN public.sales_feasibility_handover_requests receipt ON receipt.requirement_id=review.requirement_id
WHERE receipt.request_key='00000000-0000-4000-8000-000000000198';
SELECT pg_advisory_xact_lock(20261016,40);
SELECT pg_sleep(5);
COMMIT;
