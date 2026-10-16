\set ON_ERROR_STOP on
BEGIN;
SET LOCAL statement_timeout='15s';
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000062',true);
DO $hold$
DECLARE r public.requirement_feasibility_reviews%ROWTYPE;
BEGIN
 SELECT review.* INTO STRICT r FROM public.requirement_feasibility_reviews review JOIN public.sales_feasibility_handover_requests receipt ON receipt.requirement_id=review.requirement_id WHERE receipt.request_key='00000000-0000-4000-8000-000000000198';
 PERFORM public.requirement_review_private_draft_context(r.id,r.source_revision_id,r.master_specification_version_id);
END;
$hold$;
SELECT pg_advisory_xact_lock(20261016,42);
SELECT pg_sleep(8);
COMMIT;
