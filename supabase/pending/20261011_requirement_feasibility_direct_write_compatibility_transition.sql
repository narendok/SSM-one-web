-- SOURCE-ONLY, SEPARATELY APPROVED COMPATIBILITY TRANSITION.
-- Do not apply with 20261005_client_requirement_intake.sql by default.
-- This phase is required only after an isolated, target-bound preflight proves every existing
-- direct writer, policy dependency, and legacy scope-helper caller has a reviewed migration path.
-- Retaining legacy paths before this transition is not evidence that they are safe or ready for
-- production use. No caller-facing UI, Save path, identity, role, or permission is activated here.
--
-- Required approval gates before any future installation:
-- 1. The connection independently proves isolated target egjotuxqguifnvdnflan; production
--    yyrvduosyyaluifqvwkr remains excluded.
-- 2. Read-only dependency evidence proves no surviving function, view, trigger, application
--    caller, or approved workflow requires the legacy three-argument helper.
-- 3. Read-only compatibility evidence inventories the existing authenticated direct grants and
--    "Sales users manage feasibility reviews" policy, then proves protected assignment/response
--    callers cover the intended supported workflow without legacy bypass.
-- 4. A separate approval covers these exact revokes/drops and an isolated rollback/restore plan.
--
-- There is no automatic down migration. Do not use CASCADE. Stop on any unknown dependency.

DO $$
BEGIN
  IF to_regprocedure('public.external_requirement_scope_allows(uuid,uuid,uuid)') IS NOT NULL THEN
    EXECUTE 'REVOKE ALL ON FUNCTION public.external_requirement_scope_allows(uuid,uuid,uuid) FROM PUBLIC, anon, authenticated, service_role';
    EXECUTE 'DROP FUNCTION public.external_requirement_scope_allows(uuid,uuid,uuid)';
  END IF;
END;
$$;

REVOKE INSERT, UPDATE, DELETE ON TABLE public.requirement_feasibility_reviews FROM authenticated;
DROP POLICY IF EXISTS "Sales users manage feasibility reviews" ON public.requirement_feasibility_reviews;
