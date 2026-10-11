-- LOCAL DISPOSABLE concurrency assertions only.
\set ON_ERROR_STOP on
DO $$ BEGIN
  IF (SELECT count(*) FROM public.component_candidate_submissions WHERE project_id = '00000000-0000-4000-8000-000000000116') <> 1 THEN RAISE EXCEPTION 'Concurrent exact replay wrote more than one header'; END IF;
  IF (SELECT count(*) FROM public.component_candidate_payload_revisions revision JOIN public.component_candidate_submissions candidate ON candidate.id = revision.candidate_id WHERE candidate.project_id = '00000000-0000-4000-8000-000000000116') <> 1 THEN RAISE EXCEPTION 'Concurrent exact replay wrote more than one payload revision'; END IF;
  IF (SELECT count(*) FROM public.component_candidate_submission_audit_events audit JOIN public.component_candidate_submissions candidate ON candidate.id = audit.candidate_id WHERE candidate.project_id = '00000000-0000-4000-8000-000000000116') <> 1 THEN RAISE EXCEPTION 'Concurrent exact replay wrote more than one audit event'; END IF;
  IF (SELECT count(*) FROM public.component_candidate_submission_request_receipts WHERE request_key = '00000000-0000-4000-8000-000000000190') <> 1 THEN RAISE EXCEPTION 'Concurrent exact replay wrote more than one receipt'; END IF;
END $$;
SELECT 'BOM_CANDIDATE_SUBMISSION_CONCURRENCY_PASS=true';