-- LOCAL DISPOSABLE EXECUTABLE ACCEPTANCE ONLY.
-- The location configuration is fixture-only and is not a production folder,
-- storage bucket, or object. No Storage upload is exercised here.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL request.jwt.claim.sub = '00000000-0000-4000-8000-000000000001';
SET LOCAL request.jwt.claim.role = 'authenticated';

INSERT INTO public.sales_opportunity_structured_draft_private_locations (
  id, drive_folder_node_id, private_storage_bucket, private_storage_prefix,
  verified_private_at, verified_by, created_by
) VALUES (
  '00000000-0000-4000-8000-000000000701',
  '00000000-0000-4000-8000-000000000601', 'private-sales-drafts',
  'sales/opportunity-2026-0013', now(),
  '00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000001'
);

CREATE TEMP TABLE audit_location_first AS
SELECT * FROM public.save_sales_opportunity_structured_draft_at_location(
  '00000000-0000-4000-8000-000000000201', '00000000-0000-4000-8000-000000000101',
  '00000000-0000-4000-8000-000000000301', '00000000-0000-4000-8000-000000000401',
  'SOR', 0, '{"SCOPE_STATEMENT":"Audited scope","ACCEPTANCE_CRITERIA":"Audited acceptance"}'::jsonb,
  '00000000-0000-4000-8000-000000000702', '00000000-0000-4000-8000-000000000701'
);

DO $cases$
DECLARE v_revision_id uuid; v_before_revisions integer; v_before_receipts integer; v_before_audits integer;
BEGIN
  SELECT revision_id INTO v_revision_id FROM audit_location_first;
  IF (SELECT revision_number FROM audit_location_first) <> 1 OR (SELECT replayed FROM audit_location_first)
    OR (SELECT count(*) FROM public.sales_opportunity_structured_draft_revision_locations WHERE revision_id = v_revision_id) <> 1
    OR (SELECT count(*) FROM public.sales_opportunity_structured_draft_audit_events WHERE revision_id = v_revision_id) <> 1 THEN
    RAISE EXCEPTION 'LOCAL_AUDIT_LOCATION_FAIL missing transaction-coupled location or audit';
  END IF;
  IF EXISTS (SELECT 1 FROM public.sales_opportunity_structured_draft_revision_locations WHERE revision_id = v_revision_id AND storage_state <> 'NOT_MATERIALIZED') THEN
    RAISE EXCEPTION 'LOCAL_AUDIT_LOCATION_FAIL fake storage materialization';
  END IF;
  PERFORM public.save_sales_opportunity_structured_draft_at_location(
    '00000000-0000-4000-8000-000000000201', '00000000-0000-4000-8000-000000000101',
    '00000000-0000-4000-8000-000000000301', '00000000-0000-4000-8000-000000000401',
    'SOR', 0, '{"ACCEPTANCE_CRITERIA":"Audited acceptance","SCOPE_STATEMENT":"Audited scope"}'::jsonb,
    '00000000-0000-4000-8000-000000000702', '00000000-0000-4000-8000-000000000701'
  );
  IF (SELECT count(*) FROM public.sales_opportunity_structured_draft_audit_events WHERE revision_id = v_revision_id) <> 1 THEN
    RAISE EXCEPTION 'LOCAL_AUDIT_LOCATION_FAIL exact replay duplicated audit';
  END IF;
  SELECT count(*), (SELECT count(*) FROM public.sales_opportunity_structured_draft_requests), (SELECT count(*) FROM public.sales_opportunity_structured_draft_audit_events)
    INTO v_before_revisions, v_before_receipts, v_before_audits FROM public.sales_opportunity_structured_draft_revisions;
  BEGIN
    PERFORM public.save_sales_opportunity_structured_draft_at_location(
      '00000000-0000-4000-8000-000000000201', '00000000-0000-4000-8000-000000000101',
      '00000000-0000-4000-8000-000000000301', '00000000-0000-4000-8000-000000000401',
      'SOR', 1, '{"SCOPE_STATEMENT":"Rejected scope"}'::jsonb,
      '00000000-0000-4000-8000-000000000703', '00000000-0000-4000-8000-000000000799'
    );
    RAISE EXCEPTION 'LOCAL_AUDIT_LOCATION_FAIL unknown location accepted';
  EXCEPTION WHEN OTHERS THEN
    IF SQLSTATE <> 'P0001' OR SQLERRM <> 'The requested private Sales location is unavailable' THEN RAISE; END IF;
  END;
  IF (SELECT count(*) FROM public.sales_opportunity_structured_draft_revisions) <> v_before_revisions
    OR (SELECT count(*) FROM public.sales_opportunity_structured_draft_requests) <> v_before_receipts
    OR (SELECT count(*) FROM public.sales_opportunity_structured_draft_audit_events) <> v_before_audits THEN
    RAISE EXCEPTION 'LOCAL_AUDIT_LOCATION_FAIL denied location changed receipt graph';
  END IF;
  BEGIN
    UPDATE public.sales_opportunity_structured_draft_audit_events SET action = 'CREATE' WHERE revision_id = v_revision_id;
    RAISE EXCEPTION 'LOCAL_AUDIT_LOCATION_FAIL audit mutation accepted';
  EXCEPTION WHEN OTHERS THEN
    IF SQLSTATE <> 'P0001' OR SQLERRM <> 'Structured Sales draft audit and private-location history is append-only' THEN RAISE; END IF;
  END;
END;
$cases$;

SELECT 'STRUCTURED_DRAFT_AUDIT_LOCATION_LOCAL_ACCEPTANCE_PASS' AS result,
  (SELECT count(*) FROM public.sales_opportunity_structured_draft_audit_events) AS audits,
  (SELECT count(*) FROM public.sales_opportunity_structured_draft_revision_locations) AS locations;
ROLLBACK;