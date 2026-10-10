-- LOCAL DISPOSABLE EXECUTABLE ACCEPTANCE ONLY. This exercises the pending
-- contract after the runner applies it to the fresh local fixture. It does not
-- prove managed RLS, real caller transport, deployment ownership, or grants.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL request.jwt.claim.sub = '00000000-0000-4000-8000-000000000001';
SET LOCAL request.jwt.claim.role = 'authenticated';

CREATE TEMP TABLE acceptance_baseline AS
SELECT * FROM public.save_sales_opportunity_structured_draft_revision(
  '00000000-0000-4000-8000-000000000201', '00000000-0000-4000-8000-000000000101',
  '00000000-0000-4000-8000-000000000301', '00000000-0000-4000-8000-000000000401',
  'SOR', 0, '{"SCOPE_STATEMENT":"Scope","ACCEPTANCE_CRITERIA":"Accept"}'::jsonb,
  '00000000-0000-4000-8000-000000000501'
);
CREATE TEMP TABLE acceptance_update AS
SELECT * FROM public.save_sales_opportunity_structured_draft_revision(
  '00000000-0000-4000-8000-000000000201', '00000000-0000-4000-8000-000000000101',
  '00000000-0000-4000-8000-000000000301', '00000000-0000-4000-8000-000000000401',
  'SOR', 1, '{"SCOPE_STATEMENT":"Scope revised","ACCEPTANCE_CRITERIA":"Accept"}'::jsonb,
  '00000000-0000-4000-8000-000000000502'
);
CREATE TEMP TABLE acceptance_counts AS
SELECT
  (SELECT count(*)::integer FROM public.sales_opportunity_structured_drafts) AS drafts,
  (SELECT count(*)::integer FROM public.sales_opportunity_structured_draft_revisions) AS revisions,
  (SELECT count(*)::integer FROM public.sales_opportunity_structured_draft_requests) AS requests;

DO $cases$
DECLARE
  v_before record;
  v_replayed boolean;
  v_revision_id uuid;
BEGIN
  IF (SELECT revision_number FROM acceptance_baseline) <> 1 OR (SELECT replayed FROM acceptance_baseline) THEN
    RAISE EXCEPTION 'LOCAL_CASE_FAIL baseline';
  END IF;
  IF (SELECT revision_number FROM acceptance_update) <> 2 OR (SELECT replayed FROM acceptance_update) THEN
    RAISE EXCEPTION 'LOCAL_CASE_FAIL update';
  END IF;

  SELECT replayed, revision_id INTO v_replayed, v_revision_id
  FROM public.save_sales_opportunity_structured_draft_revision(
    '00000000-0000-4000-8000-000000000201', '00000000-0000-4000-8000-000000000101',
    '00000000-0000-4000-8000-000000000301', '00000000-0000-4000-8000-000000000401',
    'SOR', 0, '{"ACCEPTANCE_CRITERIA":"Accept","SCOPE_STATEMENT":"Scope"}'::jsonb,
    '00000000-0000-4000-8000-000000000501'
  );
  IF NOT v_replayed OR v_revision_id IS DISTINCT FROM (SELECT revision_id FROM acceptance_baseline) THEN
    RAISE EXCEPTION 'LOCAL_CASE_FAIL exact replay';
  END IF;

  SELECT * INTO v_before FROM acceptance_counts;
  BEGIN
    PERFORM public.save_sales_opportunity_structured_draft_revision(
      '00000000-0000-4000-8000-000000000201', '00000000-0000-4000-8000-000000000101',
      '00000000-0000-4000-8000-000000000301', '00000000-0000-4000-8000-000000000401',
      'SOR', 2, '{"SCOPE_STATEMENT":"Scope revised","ACCEPTANCE_CRITERIA":"Accept"}'::jsonb,
      '00000000-0000-4000-8000-000000000503'
    );
    RAISE EXCEPTION 'LOCAL_CASE_FAIL unchanged new key accepted';
  EXCEPTION WHEN OTHERS THEN
    IF SQLSTATE <> 'P0001' OR SQLERRM NOT LIKE 'Use the original request key%' THEN RAISE; END IF;
  END;
  BEGIN
    PERFORM public.save_sales_opportunity_structured_draft_revision(
      '00000000-0000-4000-8000-000000000201', '00000000-0000-4000-8000-000000000101',
      '00000000-0000-4000-8000-000000000301', '00000000-0000-4000-8000-000000000401',
      'SOR', 2, '{"SCOPE_STATEMENT":"Scope","DERIVED_STATUS":"no"}'::jsonb,
      '00000000-0000-4000-8000-000000000504'
    );
    RAISE EXCEPTION 'LOCAL_CASE_FAIL unknown field accepted';
  EXCEPTION WHEN OTHERS THEN
    IF SQLSTATE <> 'P0001' OR SQLERRM NOT LIKE 'Structured Sales payload contains an unknown or derived field' THEN RAISE; END IF;
  END;
  BEGIN
    PERFORM public.save_sales_opportunity_structured_draft_revision(
      '00000000-0000-4000-8000-000000000201', '00000000-0000-4000-8000-000000000101',
      '00000000-0000-4000-8000-000000000301', '00000000-0000-4000-8000-000000000401',
      'SOR', 2, jsonb_build_object('SCOPE_STATEMENT', jsonb_build_array('no')),
      '00000000-0000-4000-8000-000000000505'
    );
    RAISE EXCEPTION 'LOCAL_CASE_FAIL non-string field accepted';
  EXCEPTION WHEN OTHERS THEN
    IF SQLSTATE <> 'P0001' OR SQLERRM NOT LIKE 'Structured Sales editable field SCOPE_STATEMENT must be a string' THEN RAISE; END IF;
  END;
  BEGIN
    PERFORM public.save_sales_opportunity_structured_draft_revision(
      '00000000-0000-4000-8000-000000000201', '00000000-0000-4000-8000-000000000102',
      '00000000-0000-4000-8000-000000000301', '00000000-0000-4000-8000-000000000401',
      'SOR', 2, '{}'::jsonb, '00000000-0000-4000-8000-000000000506'
    );
    RAISE EXCEPTION 'LOCAL_CASE_FAIL opportunity mismatch accepted';
  EXCEPTION WHEN OTHERS THEN
    IF SQLSTATE <> 'P0001' OR SQLERRM NOT LIKE 'Opportunity/customer source mismatch' THEN RAISE; END IF;
  END;
  BEGIN
    PERFORM public.save_sales_opportunity_structured_draft_revision(
      '00000000-0000-4000-8000-000000000201', '00000000-0000-4000-8000-000000000101',
      '00000000-0000-4000-8000-000000000302', '00000000-0000-4000-8000-000000000401',
      'SOR', 2, '{}'::jsonb, '00000000-0000-4000-8000-000000000507'
    );
    RAISE EXCEPTION 'LOCAL_CASE_FAIL specification mismatch accepted';
  EXCEPTION WHEN OTHERS THEN
    IF SQLSTATE <> 'P0001' OR SQLERRM NOT LIKE 'Master Specification source mismatch' THEN RAISE; END IF;
  END;
  BEGIN
    PERFORM public.save_sales_opportunity_structured_draft_revision(
      '00000000-0000-4000-8000-000000000201', '00000000-0000-4000-8000-000000000101',
      '00000000-0000-4000-8000-000000000301', '00000000-0000-4000-8000-000000000402',
      'SOR', 2, '{}'::jsonb, '00000000-0000-4000-8000-000000000508'
    );
    RAISE EXCEPTION 'LOCAL_CASE_FAIL version mismatch accepted';
  EXCEPTION WHEN OTHERS THEN
    IF SQLSTATE <> 'P0001' OR SQLERRM NOT LIKE 'Master Specification version source mismatch' THEN RAISE; END IF;
  END;

  PERFORM set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000002', true);
  BEGIN
    PERFORM public.save_sales_opportunity_structured_draft_revision(
      '00000000-0000-4000-8000-000000000201', '00000000-0000-4000-8000-000000000101',
      '00000000-0000-4000-8000-000000000301', '00000000-0000-4000-8000-000000000401',
      'SOR', 0, '{"SCOPE_STATEMENT":"Scope","ACCEPTANCE_CRITERIA":"Accept"}'::jsonb,
      '00000000-0000-4000-8000-000000000501'
    );
    RAISE EXCEPTION 'LOCAL_CASE_FAIL actor replay accepted';
  EXCEPTION WHEN OTHERS THEN
    IF SQLSTATE <> 'P0001' OR SQLERRM NOT LIKE 'Request key conflicts with a different immutable source, schema, caller, revision, or payload' THEN RAISE; END IF;
  END;
  PERFORM set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000001', true);
  BEGIN
    PERFORM public.save_sales_opportunity_structured_draft_revision(
      '00000000-0000-4000-8000-000000000201', '00000000-0000-4000-8000-000000000101',
      '00000000-0000-4000-8000-000000000301', '00000000-0000-4000-8000-000000000401',
      'SOR', 1, '{"SCOPE_STATEMENT":"third"}'::jsonb,
      '00000000-0000-4000-8000-000000000509'
    );
    RAISE EXCEPTION 'LOCAL_CASE_FAIL stale revision accepted';
  EXCEPTION WHEN OTHERS THEN
    IF SQLSTATE <> 'P0001' OR SQLERRM NOT LIKE 'Structured Sales draft revision conflict' THEN RAISE; END IF;
  END;
  BEGIN
    UPDATE public.sales_opportunity_structured_draft_revisions SET canonical_payload = '{}'::jsonb
    WHERE id = (SELECT revision_id FROM acceptance_baseline);
    RAISE EXCEPTION 'LOCAL_CASE_FAIL history update accepted';
  EXCEPTION WHEN OTHERS THEN
    IF SQLSTATE <> 'P0001' OR SQLERRM NOT LIKE 'Structured Sales draft history is append-only' THEN RAISE; END IF;
  END;
  IF (SELECT count(*) FROM public.sales_opportunity_structured_drafts) <> v_before.drafts
    OR (SELECT count(*) FROM public.sales_opportunity_structured_draft_revisions) <> v_before.revisions
    OR (SELECT count(*) FROM public.sales_opportunity_structured_draft_requests) <> v_before.requests THEN
    RAISE EXCEPTION 'LOCAL_CASE_FAIL rejected input wrote partial history';
  END IF;
  RAISE NOTICE 'STRUCTURED_DRAFT_LOCAL_ACCEPTANCE_PASS drafts=% revisions=% requests=%', v_before.drafts, v_before.revisions, v_before.requests;
END;
$cases$;
ROLLBACK;