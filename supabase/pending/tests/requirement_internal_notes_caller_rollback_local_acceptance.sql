-- Disposable synthetic caller/transaction checks. Grants roll back with this test.
\set ON_ERROR_STOP on
BEGIN;
GRANT USAGE ON SCHEMA public,auth TO authenticated;
GRANT EXECUTE ON FUNCTION public.read_own_requirement_internal_note(uuid,uuid,uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.save_requirement_internal_note(uuid,uuid,uuid,integer,text,uuid) TO authenticated;
SELECT set_config('note_test.review',review.id::text,true),set_config('note_test.revision',review.source_revision_id::text,true),set_config('note_test.master',review.master_specification_version_id::text,true)
FROM public.requirement_feasibility_reviews review JOIN public.sales_feasibility_handover_requests receipt ON receipt.requirement_id=review.requirement_id
WHERE receipt.request_key='00000000-0000-4000-8000-000000000198';
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000062',true);
SET LOCAL ROLE authenticated;
DO $case$
DECLARE saved jsonb;
BEGIN
 IF current_user<>'authenticated' THEN RAISE EXCEPTION 'Caller role not applied'; END IF;
 saved:=public.save_requirement_internal_note(current_setting('note_test.review')::uuid,current_setting('note_test.revision')::uuid,current_setting('note_test.master')::uuid,0,'Caller-owned private note','00000000-0000-4000-8000-000000000311');
 BEGIN
  PERFORM public.read_own_requirement_internal_note(current_setting('note_test.review')::uuid,'00000000-0000-4000-8000-000000000081',current_setting('note_test.master')::uuid);
  RAISE EXCEPTION 'Wrong-source read unexpectedly allowed';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'Note source revision is stale' THEN RAISE; END IF; END;
 IF public.read_own_requirement_internal_note(current_setting('note_test.review')::uuid,current_setting('note_test.revision')::uuid,current_setting('note_test.master')::uuid) IS DISTINCT FROM saved THEN RAISE EXCEPTION 'Independent readback mismatch'; END IF;
 IF saved->>'body'<>'Caller-owned private note' OR saved->>'version_number'<>'1' THEN RAISE EXCEPTION 'Caller save representation mismatch'; END IF;
 BEGIN
  PERFORM 1 FROM public.requirement_internal_note_versions;
  RAISE EXCEPTION 'Direct note read unexpectedly allowed';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END;
$case$;
RESET ROLE;
CREATE FUNCTION public.note_test_audit_failure() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF NEW.action='internal_note_saved' THEN RAISE EXCEPTION 'LOCAL_NOTE_AUDIT_FAILPOINT'; END IF;
 RETURN NEW;
END;
$$;
CREATE TRIGGER note_test_audit_failure BEFORE INSERT ON public.activity_log FOR EACH ROW EXECUTE FUNCTION public.note_test_audit_failure();
SET LOCAL ROLE authenticated;
DO $case$
BEGIN
 BEGIN
  PERFORM public.save_requirement_internal_note(current_setting('note_test.review')::uuid,current_setting('note_test.revision')::uuid,current_setting('note_test.master')::uuid,1,'Must roll back','00000000-0000-4000-8000-000000000312');
  RAISE EXCEPTION 'Audit failure unexpectedly saved';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'LOCAL_NOTE_AUDIT_FAILPOINT' THEN RAISE; END IF; END;
 PERFORM set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000064',true);
 BEGIN
  PERFORM public.read_own_requirement_internal_note(current_setting('note_test.review')::uuid,current_setting('note_test.revision')::uuid,current_setting('note_test.master')::uuid);
  PERFORM public.save_requirement_internal_note(current_setting('note_test.review')::uuid,current_setting('note_test.revision')::uuid,current_setting('note_test.master')::uuid,1,'Unauthorized','00000000-0000-4000-8000-000000000313');
  RAISE EXCEPTION 'Unauthorized caller unexpectedly saved';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'Engineering management permission is required' THEN RAISE; END IF; END;
END;
$case$;
RESET ROLE;
DO $assert$
BEGIN
 IF (SELECT count(*) FROM public.requirement_internal_note_versions WHERE review_id=current_setting('note_test.review')::uuid)<>1
 OR (SELECT count(*) FROM public.activity_log WHERE entity_id=current_setting('note_test.review')::uuid AND action='internal_note_saved')<>1 THEN RAISE EXCEPTION 'Note/audit atomic rollback failed'; END IF;
 IF EXISTS(SELECT 1 FROM public.requirement_internal_note_versions WHERE request_key='00000000-0000-4000-8000-000000000312') THEN RAISE EXCEPTION 'Failed request persisted'; END IF;
 RAISE NOTICE 'INTERNAL_NOTE_CALLER_ROLLBACK_PASS role=authenticated direct_read=denied audit_failure=atomic unauthorized=denied';
END;
$assert$;
ROLLBACK;
