\set ON_ERROR_STOP on
BEGIN;
SET LOCAL statement_timeout='12s';
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000062',true);
DO $case$
DECLARE r public.requirement_feasibility_reviews%ROWTYPE; n jsonb;
BEGIN
 SELECT review.* INTO STRICT r FROM public.requirement_feasibility_reviews review JOIN public.sales_feasibility_handover_requests receipt ON receipt.requirement_id=review.requirement_id
 WHERE receipt.request_key='00000000-0000-4000-8000-000000000198';
 BEGIN
  IF pg_try_advisory_xact_lock(hashtextextended('sales-feasibility-requirement-root:'||r.requirement_id::text,0)) THEN RAISE EXCEPTION 'Concurrent root contention not observed'; END IF;
  RAISE NOTICE 'HIGHLIGHT_DRAFT_OVERLAP_OBSERVED';
  PERFORM public.save_requirement_highlight_draft(r.id,r.source_revision_id,r.master_specification_version_id,0,'Concurrent stale draft','00000000-0000-4000-8000-000000000352');
  RAISE EXCEPTION 'Concurrent stale overwrite succeeded';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'Highlight draft changed; reload before saving' THEN RAISE; END IF; END;
 n:=public.read_own_requirement_highlight_draft(r.id,r.source_revision_id,r.master_specification_version_id);
 IF n->>'body'<>'Concurrent winning draft' OR n->>'version_number'<>'1' THEN RAISE EXCEPTION 'Winning note lost'; END IF;
 IF EXISTS(SELECT 1 FROM public.requirement_highlight_draft_versions WHERE request_key='00000000-0000-4000-8000-000000000352') THEN RAISE EXCEPTION 'Losing save persisted'; END IF;
 RAISE NOTICE 'HIGHLIGHT_DRAFT_CONCURRENT_PASS winner=preserved stale_writer=denied losing_request=absent';
END;
$case$;
ROLLBACK;
