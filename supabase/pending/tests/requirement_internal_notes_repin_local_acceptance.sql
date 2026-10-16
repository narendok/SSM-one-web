-- Synthetic repin only, not an authorized live revision-edit workflow.
\set ON_ERROR_STOP on
BEGIN;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000062',true);
DO $case$
DECLARE r public.requirement_feasibility_reviews%ROWTYPE; old_note jsonb; new_note jsonb; new_revision uuid:=gen_random_uuid();
BEGIN
 SELECT review.* INTO STRICT r FROM public.requirement_feasibility_reviews review JOIN public.sales_feasibility_handover_requests receipt ON receipt.requirement_id=review.requirement_id
 WHERE receipt.request_key='00000000-0000-4000-8000-000000000198';
 old_note:=public.save_requirement_internal_note(r.id,r.source_revision_id,r.master_specification_version_id,0,'Old revision note','00000000-0000-4000-8000-000000000321');
 INSERT INTO public.customer_requirement_revisions(id,requirement_id,revision_number,change_summary,requirement_data,status,created_by)
 VALUES(new_revision,r.requirement_id,2,'Synthetic repin','{}'::jsonb,'submitted',auth.uid());
 UPDATE public.customer_requirements SET current_revision=2 WHERE id=r.requirement_id;
 UPDATE public.requirement_feasibility_reviews SET source_revision_id=new_revision,source_revision_number=2,
 master_specification_version_id='00000000-0000-4000-8000-000000000072',master_specification_version_number=2 WHERE id=r.id;
 IF public.read_own_requirement_internal_note(r.id,new_revision,'00000000-0000-4000-8000-000000000072') IS NOT NULL THEN RAISE EXCEPTION 'Old note copied into new source'; END IF;
 BEGIN
  PERFORM public.read_own_requirement_internal_note(r.id,r.source_revision_id,r.master_specification_version_id);
  RAISE EXCEPTION 'Old source read unexpectedly allowed';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'Note source revision is stale' THEN RAISE; END IF; END;
 BEGIN
  PERFORM public.save_requirement_internal_note(r.id,r.source_revision_id,r.master_specification_version_id,0,'Old revision note','00000000-0000-4000-8000-000000000321');
  RAISE EXCEPTION 'Old source replay unexpectedly allowed';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'Note source revision is stale' THEN RAISE; END IF; END;
 new_note:=public.save_requirement_internal_note(r.id,new_revision,'00000000-0000-4000-8000-000000000072',0,'New revision note','00000000-0000-4000-8000-000000000322');
 IF new_note->>'version_number'<>'1' THEN RAISE EXCEPTION 'New source did not restart version counter'; END IF;
 new_note:=public.save_requirement_internal_note(r.id,new_revision,'00000000-0000-4000-8000-000000000072',1,'','00000000-0000-4000-8000-000000000323');
 IF new_note->>'body'<>'' OR new_note->>'version_number'<>'2' THEN RAISE EXCEPTION 'Explicit clear not versioned'; END IF;
 IF public.read_own_requirement_internal_note(r.id,new_revision,'00000000-0000-4000-8000-000000000072') IS DISTINCT FROM new_note THEN RAISE EXCEPTION 'Latest cleared note read mismatch'; END IF;
 IF (SELECT count(*) FROM public.requirement_internal_note_versions WHERE review_id=r.id)<>3
 OR NOT EXISTS(SELECT 1 FROM public.requirement_internal_note_versions WHERE id=(old_note->>'id')::uuid AND body='Old revision note') THEN RAISE EXCEPTION 'History changed during repin or clear'; END IF;
 RAISE NOTICE 'INTERNAL_NOTE_REPIN_PASS old_history=preserved old_scope=denied new_counter=1 clear_version=2 latest_read=exact';
END;
$case$;
ROLLBACK;
