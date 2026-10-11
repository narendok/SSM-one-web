-- LOCAL DISPOSABLE authorization-revocation assertions only.
\set ON_ERROR_STOP on
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM public.component_candidate_submissions WHERE project_id = '00000000-0000-4000-8000-000000000216') THEN RAISE EXCEPTION 'Revoked actor created a candidate after serialized wait'; END IF;
  IF EXISTS (SELECT 1 FROM public.component_candidate_submission_request_receipts WHERE request_key = '00000000-0000-4000-8000-000000000290') THEN RAISE EXCEPTION 'Revoked actor created a receipt after serialized wait'; END IF;
END $$;
SELECT 'BOM_CANDIDATE_SUBMISSION_REVOCATION_PASS=true';