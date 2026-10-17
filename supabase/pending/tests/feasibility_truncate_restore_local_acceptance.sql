-- DISPOSABLE LOCAL ONLY. Exact restore SQL, no TRUNCATE operation or real identities.
BEGIN;
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='postgres') THEN CREATE ROLE postgres NOLOGIN; END IF;
 IF to_regtype('public.app_role') IS NULL THEN CREATE TYPE public.app_role AS ENUM('admin'); END IF;
END $$;
CREATE OR REPLACE FUNCTION public.has_role(p_actor uuid,p_role public.app_role) RETURNS boolean LANGUAGE sql STABLE AS $$ SELECT public.has_role(p_actor,p_role::text) $$;
ALTER TABLE public.customer_requirements OWNER TO postgres;
ALTER TABLE public.customer_requirement_revisions OWNER TO postgres;
ALTER TABLE public.requirement_feasibility_reviews OWNER TO postgres;
-- The exact restriction bundle retained these names as SELECT-only policies.
DROP POLICY "Sales users manage requirements" ON public.customer_requirements;
DROP POLICY "Sales users manage requirement revisions" ON public.customer_requirement_revisions;
DROP POLICY "Sales users manage feasibility reviews" ON public.requirement_feasibility_reviews;
\ir feasibility_truncate_legacy_setup.sql
GRANT TRUNCATE ON public.customer_requirements,public.customer_requirement_revisions,public.requirement_feasibility_reviews TO anon,authenticated;
CREATE TEMP TABLE restore_acl_before AS SELECT oid,relowner,relrowsecurity,relforcerowsecurity,relacl::text acl FROM pg_class WHERE oid IN ('public.customer_requirements'::regclass,'public.customer_requirement_revisions'::regclass,'public.requirement_feasibility_reviews'::regclass);
CREATE TEMP TABLE restore_policy_before AS SELECT tablename,policyname,cmd,permissive,roles,
 regexp_replace(coalesce(qual,''),'::(text|app_role)','','g') qual,
 regexp_replace(coalesce(with_check,''),'::(text|app_role)','','g') with_check
 FROM pg_policies WHERE schemaname='public' AND tablename IN ('customer_requirements','customer_requirement_revisions','requirement_feasibility_reviews');
\ir ../20261015_requirement_feasibility_original_target_compatibility.sql
\ir ../20261018_feasibility_preserve_manage_reads_review_only.sql
\ir ../20261018_feasibility_truncate_boundary_review_only.sql
COMMIT;
\ir ../20261018_requirement_feasibility_restore_review.sql
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM restore_acl_before b JOIN pg_class c ON c.oid=b.oid WHERE b.relowner<>c.relowner OR b.relrowsecurity<>c.relrowsecurity OR b.relforcerowsecurity<>c.relforcerowsecurity OR b.acl IS DISTINCT FROM c.relacl::text) THEN RAISE EXCEPTION 'Restore ACL/owner/RLS mismatch'; END IF;
 IF EXISTS(
 (SELECT * FROM restore_policy_before EXCEPT SELECT tablename,policyname,cmd,permissive,roles,regexp_replace(coalesce(qual,''),'::(text|app_role)','','g'),regexp_replace(coalesce(with_check,''),'::(text|app_role)','','g') FROM pg_policies WHERE schemaname='public' AND tablename IN ('customer_requirements','customer_requirement_revisions','requirement_feasibility_reviews'))
 UNION ALL
 (SELECT tablename,policyname,cmd,permissive,roles,regexp_replace(coalesce(qual,''),'::(text|app_role)','','g'),regexp_replace(coalesce(with_check,''),'::(text|app_role)','','g') FROM pg_policies WHERE schemaname='public' AND tablename IN ('customer_requirements','customer_requirement_revisions','requirement_feasibility_reviews') EXCEPT SELECT * FROM restore_policy_before)
 ) THEN RAISE EXCEPTION 'Restore policy mismatch'; END IF;
END $$;
\echo FEASIBILITY_TRUNCATE_RESTORE_LOCAL_PASS exact_restore_file=true table_acl_owner_rls_preserved=true normalized_policies_restored=true managed_execution=false
