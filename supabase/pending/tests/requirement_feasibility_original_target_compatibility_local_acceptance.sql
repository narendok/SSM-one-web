-- LOCAL DISPOSABLE ACCEPTANCE ONLY. The caller identities, policy names, and grants are
-- synthetic. This proves the exact proposal's intended access shape, not managed-target RLS.
\set ON_ERROR_STOP on

BEGIN;
CREATE ROLE local_sales_caller NOLOGIN IN ROLE authenticated;
CREATE ROLE local_anon_caller NOLOGIN IN ROLE anon;
GRANT USAGE ON SCHEMA public, auth TO local_sales_caller, local_anon_caller;

-- Recreate the verified original-target surface before applying the exact proposal. The
-- read-only policies intentionally differ from the broad Sales-manage ALL policies.
GRANT SELECT, INSERT, UPDATE, DELETE ON public.customer_requirements, public.customer_requirement_revisions, public.requirement_feasibility_reviews TO authenticated, anon;
ALTER TABLE public.customer_requirements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_requirement_revisions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.requirement_feasibility_reviews ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Sales users manage requirements" ON public.customer_requirements FOR ALL TO authenticated USING (public.has_permission(auth.uid(), 'sales.manage') OR public.has_role(auth.uid(), 'admin'::text)) WITH CHECK (public.has_permission(auth.uid(), 'sales.manage') OR public.has_role(auth.uid(), 'admin'::text));
CREATE POLICY "Sales users manage requirement revisions" ON public.customer_requirement_revisions FOR ALL TO authenticated USING (public.has_permission(auth.uid(), 'sales.manage') OR public.has_role(auth.uid(), 'admin'::text)) WITH CHECK (public.has_permission(auth.uid(), 'sales.manage') OR public.has_role(auth.uid(), 'admin'::text));
CREATE POLICY "Sales users manage feasibility reviews" ON public.requirement_feasibility_reviews FOR ALL TO authenticated USING (public.has_permission(auth.uid(), 'sales.manage') OR public.has_role(auth.uid(), 'admin'::text)) WITH CHECK (public.has_permission(auth.uid(), 'sales.manage') OR public.has_role(auth.uid(), 'admin'::text));
CREATE POLICY "Sales users view requirements" ON public.customer_requirements FOR SELECT TO authenticated USING (public.has_permission(auth.uid(), 'sales.view') OR public.has_permission(auth.uid(), 'engineering.view') OR public.has_role(auth.uid(), 'admin'::text));
CREATE POLICY "Sales users view requirement revisions" ON public.customer_requirement_revisions FOR SELECT TO authenticated USING (public.has_permission(auth.uid(), 'sales.view') OR public.has_permission(auth.uid(), 'engineering.view') OR public.has_role(auth.uid(), 'admin'::text));
CREATE POLICY "Authenticated users view feasibility reviews" ON public.requirement_feasibility_reviews FOR SELECT TO authenticated USING (public.has_permission(auth.uid(), 'sales.view') OR public.has_permission(auth.uid(), 'engineering.view') OR public.has_role(auth.uid(), 'admin'::text));
COMMIT;

-- Apply the exact source-only original-target proposal after modelling the verified legacy state.
\ir ../20261015_requirement_feasibility_original_target_compatibility.sql

BEGIN;
SET ROLE local_sales_caller;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000050', true);
CREATE TEMP TABLE compatibility_sales_read_baseline AS
SELECT ARRAY[
  (SELECT count(*)::int FROM public.customer_requirements WHERE id = '00000000-0000-4000-8000-000000000080'::uuid),
  (SELECT count(*)::int FROM public.customer_requirement_revisions WHERE id = '00000000-0000-4000-8000-000000000081'::uuid),
  (SELECT count(*)::int FROM public.requirement_feasibility_reviews WHERE requirement_id = '00000000-0000-4000-8000-000000000080'::uuid)
] AS counts;
DO $baseline$
BEGIN
  IF (SELECT counts FROM compatibility_sales_read_baseline) <> ARRAY[1, 1, 0] THEN
    RAISE EXCEPTION 'LOCAL_CASE_FAIL Sales read baseline differs: %', (SELECT counts FROM compatibility_sales_read_baseline);
  END IF;
END;
$baseline$;
RESET ROLE;
DO $non_sales_before$
BEGIN
  SET LOCAL ROLE local_anon_caller;
  IF (SELECT count(*) FROM public.customer_requirements) <> 0
     OR (SELECT count(*) FROM public.customer_requirement_revisions) <> 0
     OR (SELECT count(*) FROM public.requirement_feasibility_reviews) <> 0 THEN
    RAISE EXCEPTION 'LOCAL_CASE_FAIL anon read was allowed before proposal';
  END IF;
  RESET ROLE;
END;
$non_sales_before$;
SET ROLE local_sales_caller;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000050', true);
CREATE TEMP TABLE protected_handover AS
SELECT * FROM public.submit_sales_feasibility_handover(
  '00000000-0000-4000-8000-000000000095', '00000000-0000-4000-8000-000000000020',
  '00000000-0000-4000-8000-000000000010', '00000000-0000-4000-8000-000000000071',
  'Compatibility protected handover', 'COMPAT-LOCAL', 'Protected graph write.',
  ARRAY['00000000-0000-4000-8000-000000000060'::uuid],
  ARRAY['00000000-0000-4000-8000-000000000062'::uuid],
  '2026-10-13 18:23:00+00'::timestamptz, '00000000-0000-4000-8000-000000000211'
);
RESET ROLE;

DO $cases$
DECLARE
  v_requirement uuid := (SELECT requirement_id FROM protected_handover);
  v_revision uuid := (SELECT source_revision_id FROM public.sales_feasibility_handover_requests WHERE request_key = '00000000-0000-4000-8000-000000000211');
  v_review uuid := (SELECT review_ids[1] FROM protected_handover);
  v_before int[] := (SELECT counts FROM compatibility_sales_read_baseline);
  v_after int[];
BEGIN
  SET LOCAL ROLE local_sales_caller;
  PERFORM set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000050', true);
  SELECT ARRAY[
    (SELECT count(*)::int FROM public.customer_requirements WHERE id = '00000000-0000-4000-8000-000000000080'::uuid),
    (SELECT count(*)::int FROM public.customer_requirement_revisions WHERE id = '00000000-0000-4000-8000-000000000081'::uuid),
    (SELECT count(*)::int FROM public.requirement_feasibility_reviews WHERE requirement_id = '00000000-0000-4000-8000-000000000080'::uuid)
  ] INTO v_after;
  IF v_after <> v_before THEN
    RAISE EXCEPTION 'LOCAL_CASE_FAIL Sales read scope drifted after proposal: before %, after %', v_before, v_after;
  END IF;
  BEGIN
    INSERT INTO public.customer_requirements(opportunity_id, customer_id, title, status, current_revision, requirement_data, created_by)
    VALUES ('00000000-0000-4000-8000-000000000020', '00000000-0000-4000-8000-000000000010', 'Denied direct header', 'submitted', 1, '{}'::jsonb, auth.uid());
    RAISE EXCEPTION 'LOCAL_CASE_FAIL authenticated direct header insert accepted';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN
    UPDATE public.customer_requirement_revisions SET change_summary = 'denied' WHERE id = v_revision;
    RAISE EXCEPTION 'LOCAL_CASE_FAIL authenticated direct revision update accepted';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN
    DELETE FROM public.requirement_feasibility_reviews WHERE id = v_review;
    RAISE EXCEPTION 'LOCAL_CASE_FAIL authenticated direct review delete accepted';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  RESET ROLE;
  SET LOCAL ROLE local_anon_caller;
  IF (SELECT count(*) FROM public.customer_requirements) <> 0
     OR (SELECT count(*) FROM public.customer_requirement_revisions) <> 0
     OR (SELECT count(*) FROM public.requirement_feasibility_reviews) <> 0 THEN
    RAISE EXCEPTION 'LOCAL_CASE_FAIL anon read was allowed after proposal';
  END IF;
  BEGIN
    INSERT INTO public.customer_requirements(opportunity_id, customer_id, title, status, current_revision, requirement_data, created_by)
    VALUES ('00000000-0000-4000-8000-000000000020', '00000000-0000-4000-8000-000000000010', 'Denied anon header', 'submitted', 1, '{}'::jsonb, '00000000-0000-4000-8000-000000000050');
    RAISE EXCEPTION 'LOCAL_CASE_FAIL anon direct header insert accepted';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  RESET ROLE;
  IF (SELECT count(*) FROM public.customer_requirements WHERE id = v_requirement) <> 1
     OR (SELECT count(*) FROM public.customer_requirement_revisions WHERE id = v_revision) <> 1
     OR (SELECT count(*) FROM public.requirement_feasibility_reviews WHERE id = v_review) <> 1 THEN
    RAISE EXCEPTION 'LOCAL_CASE_FAIL denied direct mutation changed protected graph';
  END IF;
  RAISE NOTICE 'ORIGINAL_TARGET_COMPATIBILITY_ACCESS_PASS sales_read_before_after=preserved non_sales_anon_read=denied protected_handover=allowed authenticated_direct_iud=denied anon_direct_iud=denied';
END;
$cases$;
ROLLBACK;