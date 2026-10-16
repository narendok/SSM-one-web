-- Synthetic fixture only. Never a managed deployment or grant acceptance.
\set ON_ERROR_STOP on
BEGIN;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000062',true);
DO $case$
DECLARE r public.requirement_feasibility_reviews%ROWTYPE; a jsonb; b jsonb; n integer;
BEGIN
 SELECT review.* INTO STRICT r FROM public.requirement_feasibility_reviews review JOIN public.sales_feasibility_handover_requests receipt ON receipt.requirement_id=review.requirement_id
 WHERE receipt.request_key='00000000-0000-4000-8000-000000000198';
 a:=public.save_requirement_internal_note(r.id,r.source_revision_id,r.master_specification_version_id,0,'Private engineering note','00000000-0000-4000-8000-000000000301');
 b:=public.save_requirement_internal_note(r.id,r.source_revision_id,r.master_specification_version_id,0,'Private engineering note','00000000-0000-4000-8000-000000000301');
 IF a<>b OR (a->>'version_number')::integer<>1 THEN RAISE EXCEPTION 'Replay mismatch'; END IF;
 BEGIN
  PERFORM public.save_requirement_internal_note(r.id,r.source_revision_id,r.master_specification_version_id,0,'Stale overwrite','00000000-0000-4000-8000-000000000302');
  RAISE EXCEPTION 'Unexpected stale save';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'Internal note changed; reload before saving' THEN RAISE; END IF; END;
 b:=public.save_requirement_internal_note(r.id,r.source_revision_id,r.master_specification_version_id,1,'Updated private note','00000000-0000-4000-8000-000000000303');
 IF (b->>'version_number')::integer<>2 THEN RAISE EXCEPTION 'Missing second version'; END IF;
 BEGIN
  PERFORM public.save_requirement_internal_note(r.id,r.source_revision_id,r.master_specification_version_id,0,'Changed replay','00000000-0000-4000-8000-000000000301');
  RAISE EXCEPTION 'Unexpected changed replay';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'Note request key conflicts with a different payload' THEN RAISE; END IF; END;
 BEGIN
  PERFORM public.save_requirement_internal_note(r.id,'00000000-0000-4000-8000-000000000081',r.master_specification_version_id,2,'Stale pin','00000000-0000-4000-8000-000000000305');
  RAISE EXCEPTION 'Unexpected stale pin';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'Note source revision is stale' THEN RAISE; END IF; END;
 DELETE FROM public.employee_departments WHERE department_id=r.department_id;
 BEGIN
  PERFORM public.save_requirement_internal_note(r.id,r.source_revision_id,r.master_specification_version_id,2,'Revoked replay','00000000-0000-4000-8000-000000000301');
  RAISE EXCEPTION 'Unexpected revoked replay';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'Active assigned department membership is required' THEN RAISE; END IF; END;
 IF has_table_privilege('authenticated','public.requirement_internal_note_versions','SELECT')
 OR has_function_privilege('authenticated','public.save_requirement_internal_note(uuid,uuid,uuid,integer,text,uuid)','EXECUTE') THEN RAISE EXCEPTION 'Unexpected default note access'; END IF;
 PERFORM set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000064',true);
 BEGIN
  PERFORM public.save_requirement_internal_note(r.id,r.source_revision_id,r.master_specification_version_id,2,'Unauthorized','00000000-0000-4000-8000-000000000304');
  RAISE EXCEPTION 'Unexpected unauthorized save';
 EXCEPTION WHEN OTHERS THEN IF SQLERRM<>'Engineering management permission is required' THEN RAISE; END IF; END;
 SELECT count(*) INTO n FROM public.requirement_internal_note_versions WHERE review_id=r.id;
 IF n<>2 THEN RAISE EXCEPTION 'History not preserved'; END IF;
 IF EXISTS(SELECT 1 FROM public.activity_log WHERE action='internal_note_saved' AND after_data::text LIKE '%Private engineering note%') THEN RAISE EXCEPTION 'Private note leaked into audit'; END IF;
 RAISE NOTICE 'INTERNAL_NOTE_LOCAL_PASS versions=2 replay=stable stale_write=denied unauthorized=denied audit_body=excluded';
END;
$case$;
ROLLBACK;

