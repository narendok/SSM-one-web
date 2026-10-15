-- LOCAL DISPOSABLE ACCEPTANCE ONLY. The caller identities, policy names, and grants are
-- synthetic. This proves the exact proposal's intended access shape, not managed-target RLS.
\set ON_ERROR_STOP on

BEGIN;
CREATE ROLE local_sales_caller NOLOGIN IN ROLE authenticated;
CREATE ROLE local_sales_view_caller NOLOGIN IN ROLE authenticated;
CREATE ROLE local_engineering_caller NOLOGIN IN ROLE authenticated;
CREATE ROLE local_engineering_view_caller NOLOGIN IN ROLE authenticated;
CREATE ROLE local_unauthorized_caller NOLOGIN IN ROLE authenticated;
CREATE ROLE local_anon_caller NOLOGIN IN ROLE anon;
GRANT USAGE ON SCHEMA public, auth TO local_sales_caller, local_sales_view_caller, local_engineering_caller, local_engineering_view_caller, local_unauthorized_caller, local_anon_caller;

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
BEGIN;
SET ROLE local_sales_caller;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000050', true);
CREATE TEMP TABLE compatibility_sales_manage_read_before AS
SELECT ARRAY[
  (SELECT count(*)::int FROM public.customer_requirements WHERE id = '00000000-0000-4000-8000-000000000080'::uuid),
  (SELECT count(*)::int FROM public.customer_requirement_revisions WHERE id = '00000000-0000-4000-8000-000000000081'::uuid),
  (SELECT count(*)::int FROM public.requirement_feasibility_reviews WHERE requirement_id = '00000000-0000-4000-8000-000000000080'::uuid)
] AS counts;
RESET ROLE;
SET ROLE local_sales_view_caller;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000063', true);
CREATE TEMP TABLE compatibility_sales_view_read_before AS SELECT ARRAY[(SELECT count(*)::int FROM public.customer_requirements WHERE id = '00000000-0000-4000-8000-000000000080'::uuid), (SELECT count(*)::int FROM public.customer_requirement_revisions WHERE id = '00000000-0000-4000-8000-000000000081'::uuid), (SELECT count(*)::int FROM public.requirement_feasibility_reviews WHERE requirement_id = '00000000-0000-4000-8000-000000000080'::uuid)] AS counts;
RESET ROLE;
SET ROLE local_engineering_caller;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000062', true);
CREATE TEMP TABLE compatibility_engineering_manage_read_before AS SELECT ARRAY[(SELECT count(*)::int FROM public.customer_requirements WHERE id = '00000000-0000-4000-8000-000000000080'::uuid), (SELECT count(*)::int FROM public.customer_requirement_revisions WHERE id = '00000000-0000-4000-8000-000000000081'::uuid), (SELECT count(*)::int FROM public.requirement_feasibility_reviews WHERE requirement_id = '00000000-0000-4000-8000-000000000080'::uuid)] AS counts;
RESET ROLE;
SET ROLE local_engineering_view_caller;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000064', true);
CREATE TEMP TABLE compatibility_engineering_view_read_before AS SELECT ARRAY[(SELECT count(*)::int FROM public.customer_requirements WHERE id = '00000000-0000-4000-8000-000000000080'::uuid), (SELECT count(*)::int FROM public.customer_requirement_revisions WHERE id = '00000000-0000-4000-8000-000000000081'::uuid), (SELECT count(*)::int FROM public.requirement_feasibility_reviews WHERE requirement_id = '00000000-0000-4000-8000-000000000080'::uuid)] AS counts;
RESET ROLE;
SET ROLE local_unauthorized_caller;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000065', true);
CREATE TEMP TABLE compatibility_unauthorized_read_before AS SELECT ARRAY[(SELECT count(*)::int FROM public.customer_requirements), (SELECT count(*)::int FROM public.customer_requirement_revisions), (SELECT count(*)::int FROM public.requirement_feasibility_reviews)] AS counts;
RESET ROLE;
SET ROLE local_anon_caller;
CREATE TEMP TABLE compatibility_anon_read_before AS SELECT ARRAY[(SELECT count(*)::int FROM public.customer_requirements), (SELECT count(*)::int FROM public.customer_requirement_revisions), (SELECT count(*)::int FROM public.requirement_feasibility_reviews)] AS counts;
RESET ROLE;
COMMIT;

-- Apply the exact source-only original-target proposal after modelling the verified legacy state.
\ir ../20261015_requirement_feasibility_original_target_compatibility.sql

BEGIN;
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
  v_assigned_review uuid;
  v_response_review uuid;
  v_counts int[];
  v_role text;
  v_table text;
  v_statement text;
BEGIN
  IF (SELECT counts FROM compatibility_sales_manage_read_before) <> ARRAY[1, 1, 0]
     OR (SELECT counts FROM compatibility_sales_view_read_before) <> ARRAY[1, 1, 0]
     OR (SELECT counts FROM compatibility_engineering_manage_read_before) <> ARRAY[1, 1, 0]
     OR (SELECT counts FROM compatibility_engineering_view_read_before) <> ARRAY[1, 1, 0]
     OR (SELECT counts FROM compatibility_unauthorized_read_before) <> ARRAY[0, 0, 0]
     OR (SELECT counts FROM compatibility_anon_read_before) <> ARRAY[0, 0, 0] THEN
    RAISE EXCEPTION 'LOCAL_CASE_FAIL synthetic before-policy read baselines differ';
  END IF;
  SET LOCAL ROLE local_sales_caller;
  PERFORM set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000050', true);
  v_assigned_review := public.assign_requirement_feasibility_review(v_requirement, '00000000-0000-4000-8000-000000000060', '00000000-0000-4000-8000-000000000062');
  IF v_assigned_review IS NULL THEN RAISE EXCEPTION 'LOCAL_CASE_FAIL protected assignment returned no review'; END IF;
  RESET ROLE;
  SET LOCAL ROLE local_engineering_caller;
  PERFORM set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000062', true);
  v_response_review := public.record_requirement_feasibility_response(v_assigned_review, 'feasible_with_conditions', 'Synthetic verified finding', 'Synthetic assumption', 'Synthetic risk', '00000000-0000-4000-8000-000000000214');
  IF v_response_review IS DISTINCT FROM v_assigned_review THEN RAISE EXCEPTION 'LOCAL_CASE_FAIL protected reviewer response returned wrong review'; END IF;
  RESET ROLE;

  SET LOCAL ROLE local_sales_caller;
  PERFORM set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000050', true);
  SELECT ARRAY[
    (SELECT count(*)::int FROM public.customer_requirements WHERE id = '00000000-0000-4000-8000-000000000080'::uuid),
    (SELECT count(*)::int FROM public.customer_requirement_revisions WHERE id = '00000000-0000-4000-8000-000000000081'::uuid),
    (SELECT count(*)::int FROM public.requirement_feasibility_reviews WHERE requirement_id = '00000000-0000-4000-8000-000000000080'::uuid)
  ] INTO v_counts;
  IF v_counts <> (SELECT counts FROM compatibility_sales_manage_read_before) THEN RAISE EXCEPTION 'LOCAL_CASE_FAIL Sales-manage read scope drifted'; END IF;
  RESET ROLE;
  FOREACH v_role IN ARRAY ARRAY['local_sales_view_caller', 'local_engineering_caller', 'local_engineering_view_caller', 'local_unauthorized_caller', 'local_anon_caller'] LOOP
    EXECUTE format('SET LOCAL ROLE %I', v_role);
    IF v_role = 'local_sales_view_caller' THEN PERFORM set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000063', true);
    ELSIF v_role = 'local_engineering_caller' THEN PERFORM set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000062', true);
    ELSIF v_role = 'local_engineering_view_caller' THEN PERFORM set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000064', true);
    ELSIF v_role = 'local_unauthorized_caller' THEN PERFORM set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000065', true); END IF;
    SELECT ARRAY[(SELECT count(*)::int FROM public.customer_requirements WHERE id = '00000000-0000-4000-8000-000000000080'::uuid), (SELECT count(*)::int FROM public.customer_requirement_revisions WHERE id = '00000000-0000-4000-8000-000000000081'::uuid), (SELECT count(*)::int FROM public.requirement_feasibility_reviews WHERE requirement_id = '00000000-0000-4000-8000-000000000080'::uuid)] INTO v_counts;
    IF v_role = 'local_sales_view_caller' AND v_counts <> (SELECT counts FROM compatibility_sales_view_read_before) THEN RAISE EXCEPTION 'LOCAL_CASE_FAIL Sales-view scope drifted'; END IF;
    IF v_role = 'local_engineering_caller' AND v_counts <> (SELECT counts FROM compatibility_engineering_manage_read_before) THEN RAISE EXCEPTION 'LOCAL_CASE_FAIL Engineering-manage scope drifted'; END IF;
    IF v_role = 'local_engineering_view_caller' AND v_counts <> (SELECT counts FROM compatibility_engineering_view_read_before) THEN RAISE EXCEPTION 'LOCAL_CASE_FAIL Engineering-view scope drifted'; END IF;
    IF v_role IN ('local_unauthorized_caller', 'local_anon_caller') AND v_counts <> ARRAY[0, 0, 0] THEN RAISE EXCEPTION 'LOCAL_CASE_FAIL denied read scope expanded for %', v_role; END IF;
    RESET ROLE;
  END LOOP;
  FOREACH v_table IN ARRAY ARRAY['customer_requirements', 'customer_requirement_revisions', 'requirement_feasibility_reviews'] LOOP
    FOREACH v_statement IN ARRAY ARRAY[format('INSERT INTO public.%I DEFAULT VALUES', v_table), format('UPDATE public.%I SET id = id WHERE false', v_table), format('DELETE FROM public.%I WHERE false', v_table)] LOOP
      SET LOCAL ROLE local_sales_caller;
      PERFORM set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000050', true);
      BEGIN EXECUTE v_statement; RAISE EXCEPTION 'LOCAL_CASE_FAIL authenticated direct % accepted: %', v_table, v_statement; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
      RESET ROLE;
      SET LOCAL ROLE local_anon_caller;
      BEGIN EXECUTE v_statement; RAISE EXCEPTION 'LOCAL_CASE_FAIL anon direct % accepted: %', v_table, v_statement; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
      RESET ROLE;
    END LOOP;
  END LOOP;
  RESET ROLE;
  IF (SELECT count(*) FROM public.customer_requirements WHERE id = v_requirement) <> 1
     OR (SELECT count(*) FROM public.customer_requirement_revisions WHERE id = v_revision) <> 1
     OR (SELECT count(*) FROM public.requirement_feasibility_reviews WHERE id = v_review) <> 1
     OR (SELECT count(*) FROM public.requirement_feasibility_reviews WHERE id = v_assigned_review AND status = 'feasible_with_conditions') <> 1 THEN
    RAISE EXCEPTION 'LOCAL_CASE_FAIL denied direct mutation changed protected graph';
  END IF;
  RAISE NOTICE 'ORIGINAL_TARGET_COMPATIBILITY_ACCESS_PASS reads_before_after=sales_manage,sales_view,engineering_manage,engineering_view_preserved unauthorized_authenticated,anon_denied protected_handover,assignment,response=allowed authenticated_anon_direct_iud_all_tables=denied';
END;
$cases$;
ROLLBACK;