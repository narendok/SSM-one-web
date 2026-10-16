\set ON_ERROR_STOP on
BEGIN;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000062',true);
DO $case$
DECLARE r public.requirement_feasibility_reviews%ROWTYPE; note jsonb; draft jsonb; replay jsonb;
BEGIN
 SELECT review.* INTO STRICT r FROM public.requirement_feasibility_reviews review JOIN public.sales_feasibility_handover_requests receipt ON receipt.requirement_id=review.requirement_id WHERE receipt.request_key='00000000-0000-4000-8000-000000000198';
 note:=public.save_requirement_internal_note(r.id,r.source_revision_id,r.master_specification_version_id,0,'Private cost discussion','00000000-0000-4000-8000-000000000341');
 IF public.read_own_requirement_highlight_draft(r.id,r.source_revision_id,r.master_specification_version_id) IS NOT NULL THEN RAISE EXCEPTION 'Private note became a highlight draft'; END IF;
 draft:=public.save_requirement_highlight_draft(r.id,r.source_revision_id,r.master_specification_version_id,0,'Please confirm the connector','00000000-0000-4000-8000-000000000342');
 replay:=public.save_requirement_highlight_draft(r.id,r.source_revision_id,r.master_specification_version_id,0,'Please confirm the connector','00000000-0000-4000-8000-000000000342');
 IF draft<>replay THEN RAISE EXCEPTION 'Draft replay changed'; END IF;
 BEGIN
  PERFORM public.save_requirement_highlight_draft(r.id,r.source_revision_id,r.master_specification_version_id,0,'Stale overwrite','00000000-0000-4000-8000-000000000343');
  RAISE EXCEPTION 'Stale draft unexpectedly saved';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'Highlight draft changed; reload before saving' THEN RAISE; END IF; END;
 draft:=public.save_requirement_highlight_draft(r.id,r.source_revision_id,r.master_specification_version_id,1,'','00000000-0000-4000-8000-000000000344');
 IF draft->>'version_number'<>'2' OR draft->>'body'<>'' THEN RAISE EXCEPTION 'Draft clear not versioned'; END IF;
 IF public.read_own_requirement_internal_note(r.id,r.source_revision_id,r.master_specification_version_id)<>note THEN RAISE EXCEPTION 'Highlight edit changed private note'; END IF;
 IF public.read_own_requirement_highlight_draft(r.id,r.source_revision_id,r.master_specification_version_id)<>draft THEN RAISE EXCEPTION 'Draft readback mismatch'; END IF;
 IF has_table_privilege('authenticated','public.requirement_highlight_draft_versions','SELECT') OR has_table_privilege('anon','public.requirement_highlight_draft_versions','SELECT') THEN RAISE EXCEPTION 'Draft exposed by default'; END IF;
 RAISE NOTICE 'HIGHLIGHT_DRAFT_LOCAL_PASS channels=independent replay=stable stale=denied clear=versioned default_reads=closed publication=none';
END;
$case$;
ROLLBACK;
