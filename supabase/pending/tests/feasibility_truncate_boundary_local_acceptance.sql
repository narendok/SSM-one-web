-- DISPOSABLE LOCAL ONLY. Privilege checks only; no TRUNCATE statement is executed.
BEGIN;
\ir feasibility_truncate_legacy_setup.sql
GRANT TRUNCATE ON public.customer_requirements,public.customer_requirement_revisions,public.requirement_feasibility_reviews TO anon,authenticated;
CREATE TEMP TABLE truncate_before AS SELECT c.oid,c.relowner,c.relrowsecurity,c.relforcerowsecurity,
 has_table_privilege('authenticated',c.oid,'SELECT') auth_select,
 has_table_privilege('anon',c.oid,'SELECT') anon_select
 FROM pg_class c WHERE c.oid IN ('public.customer_requirements'::regclass,'public.customer_requirement_revisions'::regclass,'public.requirement_feasibility_reviews'::regclass);
SET LOCAL ROLE local_sales_caller;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000066',true);
CREATE TEMP TABLE manage_only_before AS SELECT (SELECT count(*) FROM public.customer_requirements)+(SELECT count(*) FROM public.customer_requirement_revisions)+(SELECT count(*) FROM public.requirement_feasibility_reviews) total;
DO $$ BEGIN IF (SELECT total FROM manage_only_before)=0 OR public.has_permission(auth.uid(),'sales.view') OR NOT public.has_permission(auth.uid(),'sales.manage') THEN RAISE EXCEPTION 'Manage-only fixture unavailable'; END IF; END $$;
RESET ROLE;
\ir ../20261015_requirement_feasibility_original_target_compatibility.sql
SET LOCAL ROLE local_sales_caller;
DO $$ BEGIN IF (SELECT count(*) FROM public.customer_requirements)+(SELECT count(*) FROM public.customer_requirement_revisions)+(SELECT count(*) FROM public.requirement_feasibility_reviews)<>0 THEN RAISE EXCEPTION 'Old read-scope gap not reproduced'; END IF; END $$;
RESET ROLE;
DO $$ DECLARE target regclass; BEGIN
 FOREACH target IN ARRAY ARRAY['public.customer_requirements'::regclass,'public.customer_requirement_revisions'::regclass,'public.requirement_feasibility_reviews'::regclass] LOOP
  IF NOT has_table_privilege('authenticated',target,'TRUNCATE') OR NOT has_table_privilege('anon',target,'TRUNCATE') THEN RAISE EXCEPTION 'Old-gap reproduction failed'; END IF;
 END LOOP;
END $$;
ROLLBACK;
BEGIN;
\ir feasibility_truncate_legacy_setup.sql
GRANT TRUNCATE ON public.customer_requirements,public.customer_requirement_revisions,public.requirement_feasibility_reviews TO anon,authenticated;
CREATE TEMP TABLE truncate_before AS SELECT c.oid,c.relowner,c.relrowsecurity,c.relforcerowsecurity,
 has_table_privilege('authenticated',c.oid,'SELECT') auth_select,
 has_table_privilege('anon',c.oid,'SELECT') anon_select
 FROM pg_class c WHERE c.oid IN ('public.customer_requirements'::regclass,'public.customer_requirement_revisions'::regclass,'public.requirement_feasibility_reviews'::regclass);
SET LOCAL ROLE local_sales_caller;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000066',true);
CREATE TEMP TABLE manage_only_before AS SELECT (SELECT count(*) FROM public.customer_requirements)+(SELECT count(*) FROM public.customer_requirement_revisions)+(SELECT count(*) FROM public.requirement_feasibility_reviews) total;
DO $$ BEGIN IF (SELECT total FROM manage_only_before)=0 OR public.has_permission(auth.uid(),'sales.view') OR NOT public.has_permission(auth.uid(),'sales.manage') THEN RAISE EXCEPTION 'Manage-only fixture unavailable'; END IF; END $$;
RESET ROLE;
COMMIT;
\ir ../20261018_feasibility_runtime_write_boundary_atomic_review_only.sql
BEGIN;
SET LOCAL ROLE local_sales_caller;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000066',true);
DO $$ BEGIN IF (SELECT count(*) FROM public.customer_requirements)+(SELECT count(*) FROM public.customer_requirement_revisions)+(SELECT count(*) FROM public.requirement_feasibility_reviews) IS DISTINCT FROM (SELECT total FROM manage_only_before) THEN RAISE EXCEPTION 'Manage-only reads changed'; END IF; END $$;
RESET ROLE;
ROLLBACK;
DO $$ DECLARE target regclass; BEGIN
 FOREACH target IN ARRAY ARRAY['public.customer_requirements'::regclass,'public.customer_requirement_revisions'::regclass,'public.requirement_feasibility_reviews'::regclass] LOOP
  IF has_table_privilege('local_sales_caller',target,'TRUNCATE') OR has_table_privilege('local_anon_caller',target,'TRUNCATE') THEN RAISE EXCEPTION 'Inherited truncate remains'; END IF;
 END LOOP;
 IF EXISTS (SELECT 1 FROM truncate_before b JOIN pg_class c ON c.oid=b.oid WHERE c.relowner<>b.relowner OR c.relrowsecurity<>b.relrowsecurity OR c.relforcerowsecurity<>b.relforcerowsecurity
 OR has_table_privilege('authenticated',c.oid,'SELECT')<>b.auth_select OR has_table_privilege('anon',c.oid,'SELECT')<>b.anon_select) THEN RAISE EXCEPTION 'Read/owner/RLS drift'; END IF;
END $$;

\echo FEASIBILITY_TRUNCATE_BOUNDARY_LOCAL_PASS original_gap_reproduced=true runtime_and_inherited_truncate_denied=true select_owner_rls_unchanged=true no_truncate_executed=true
