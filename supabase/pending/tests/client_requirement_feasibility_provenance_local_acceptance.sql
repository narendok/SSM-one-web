-- LOCAL DISPOSABLE OWNER-FIXTURE ACCEPTANCE ONLY. This checks relational
-- pin behavior, not managed authenticated-role RLS, grants, or JWT transport.
\set ON_ERROR_STOP on
BEGIN;

INSERT INTO public.requirement_feasibility_reviews (
  id, requirement_id, department_id, reviewer_user_id, status, created_by,
  source_revision_id, source_revision_number,
  master_specification_version_id, master_specification_version_number,
  applicable_workstreams
) VALUES (
  '00000000-0000-4000-8000-000000000082',
  '00000000-0000-4000-8000-000000000080',
  '00000000-0000-4000-8000-000000000060',
  '00000000-0000-4000-8000-000000000062', 'pending',
  '00000000-0000-4000-8000-000000000050',
  '00000000-0000-4000-8000-000000000081', 1,
  '00000000-0000-4000-8000-000000000071', 1,
  '["HARDWARE"]'::jsonb
);

INSERT INTO public.requirement_feasibility_reviews (
  id, requirement_id, department_id, reviewer_user_id, status, created_by
) VALUES (
  '00000000-0000-4000-8000-000000000083',
  '00000000-0000-4000-8000-000000000080', NULL, NULL, 'pending',
  '00000000-0000-4000-8000-000000000050'
);

INSERT INTO public.requirement_feasibility_reviews (
  id, requirement_id, department_id, reviewer_user_id, status, created_by,
  source_revision_id, source_revision_number,
  master_specification_version_id, master_specification_version_number,
  applicable_workstreams
) VALUES (
  '00000000-0000-4000-8000-000000000084',
  '00000000-0000-4000-8000-000000000080', NULL, NULL, 'pending',
  '00000000-0000-4000-8000-000000000050',
  '00000000-0000-4000-8000-000000000081', 2,
  '00000000-0000-4000-8000-000000000071', 1,
  '["HARDWARE"]'::jsonb
);

DO $cases$
DECLARE
  v_historical record;
  v_legacy record;
  v_mismatch record;
  v_review_count integer;
BEGIN
  SELECT * INTO v_historical
  FROM public.requirement_feasibility_review_provenance
  WHERE review_id = '00000000-0000-4000-8000-000000000082';
  IF v_historical.provenance_status <> 'AVAILABLE'
     OR v_historical.verified_source_revision_id IS DISTINCT FROM '00000000-0000-4000-8000-000000000081'::uuid
     OR v_historical.verified_master_specification_version_id IS DISTINCT FROM '00000000-0000-4000-8000-000000000071'::uuid THEN
    RAISE EXCEPTION 'LOCAL_CASE_FAIL historical v1 provenance was not preserved';
  END IF;

  SELECT * INTO v_legacy
  FROM public.requirement_feasibility_review_provenance
  WHERE review_id = '00000000-0000-4000-8000-000000000083';
  IF v_legacy.provenance_status <> 'UNAVAILABLE_LEGACY_OR_MISSING_PIN'
     OR v_legacy.verified_source_revision_id IS NOT NULL
     OR v_legacy.verified_master_specification_version_id IS NOT NULL THEN
    RAISE EXCEPTION 'LOCAL_CASE_FAIL legacy review substituted source provenance';
  END IF;

  SELECT * INTO v_mismatch
  FROM public.requirement_feasibility_review_provenance
  WHERE review_id = '00000000-0000-4000-8000-000000000084';
  IF v_mismatch.provenance_status <> 'UNAVAILABLE_MISMATCHED_PIN'
     OR v_mismatch.verified_source_revision_id IS NOT NULL
     OR v_mismatch.verified_master_specification_version_id IS NOT NULL THEN
    RAISE EXCEPTION 'LOCAL_CASE_FAIL mismatched review exposed unverified provenance';
  END IF;

  SELECT count(*) INTO v_review_count FROM public.requirement_feasibility_reviews;
  IF v_review_count <> 3 THEN
    RAISE EXCEPTION 'LOCAL_CASE_FAIL provenance read changed source rows';
  END IF;
  RAISE NOTICE 'FEASIBILITY_PROVENANCE_LOCAL_ACCEPTANCE_PASS historical_v1=1 legacy_unavailable=1 mismatched_unavailable=1 preserved_reviews=%', v_review_count;
END;
$cases$;
ROLLBACK;