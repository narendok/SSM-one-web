-- REVIEW ONLY. Separate specific approval required; no UI activation.
-- Original backend yyrvduosyyaluifqvwkr. Pairs the existing I/U/D restriction
-- with the newly verified TRUNCATE boundary in one transaction.
BEGIN;
DO $runtime_preflight$
BEGIN
 IF EXISTS(SELECT 1 FROM pg_class c WHERE c.oid IN ('public.customer_requirements'::regclass,'public.customer_requirement_revisions'::regclass,'public.requirement_feasibility_reviews'::regclass)
  AND (c.relowner<>current_user::regrole OR NOT c.relrowsecurity OR c.relforcerowsecurity)) THEN RAISE EXCEPTION 'Graph owner/RLS differs from accepted capture'; END IF;
 IF EXISTS(SELECT 1 FROM pg_attribute WHERE attrelid IN ('public.customer_requirements'::regclass,'public.customer_requirement_revisions'::regclass,'public.requirement_feasibility_reviews'::regclass) AND attnum>0 AND NOT attisdropped AND attacl IS NOT NULL) THEN RAISE EXCEPTION 'Unexpected column ACLs require review'; END IF;
 IF (SELECT count(*) FROM pg_proc WHERE oid IN (
 'public.submit_sales_feasibility_handover(uuid,uuid,uuid,uuid,text,text,text,uuid[],uuid[],timestamptz,uuid)'::regprocedure,
 'public.assign_requirement_feasibility_review(uuid,uuid,uuid)'::regprocedure,
 'public.record_requirement_feasibility_response(uuid,text,text,text,text,uuid)'::regprocedure)
 AND proowner=current_user::regrole AND prosecdef AND proconfig=ARRAY['search_path=public, pg_temp']
 AND has_function_privilege('authenticated',oid,'EXECUTE') AND NOT has_function_privilege('anon',oid,'EXECUTE'))<>3 THEN RAISE EXCEPTION 'Protected graph writers are not accepted'; END IF;
END;
$runtime_preflight$;
-- SOURCE-ONLY ORIGINAL-TARGET COMPATIBILITY PROPOSAL.
--
-- This file is for the original managed target only. It is not the isolated-target
-- `20261011_requirement_feasibility_direct_write_compatibility_transition.sql`, does not
-- repurpose that proposal, and must not be run without a separate exact approval.
--
-- Verified original-target read policies (read-only capture: 15 October 2026) are restated
-- below before the broad FOR ALL policies are removed. The proposal fails closed if any named
-- policy has drifted: it refuses to install rather than guessing an equivalent read predicate.
--
-- Prerequisites before any future installation:
-- 1. Install and caller-RLS accept the protected handover, assignment, and response routines
--    named below on the original target.
-- 2. Verify every remaining direct writer/service route for these three tables has either moved
--    to a listed protected operation or has a separately approved replacement.
-- 3. Run target-bound ordinary-caller RLS, rollback, concurrency, and restore acceptance.
-- 4. Capture current grants and every named policy definition below for a reversible restore.
--
-- This change deliberately does not drop any legacy scope helper or expand SELECT access.
-- It preserves the current read scope explicitly while removing only direct I/U/D access.

DO $read_policy_preflight$
DECLARE
  v_expected jsonb := jsonb_build_object(
    'customer_requirements', jsonb_build_object(
      'Sales users manage requirements', jsonb_build_object('cmd', '*', 'qual', '(has_permission(auth.uid(), ''sales.manage''::text) OR has_role(auth.uid(), ''admin''::app_role))'),
      'Sales users view requirements', jsonb_build_object('cmd', 'r', 'qual', '(has_permission(auth.uid(), ''sales.view''::text) OR has_permission(auth.uid(), ''engineering.view''::text) OR has_role(auth.uid(), ''admin''::app_role))')
    ),
    'customer_requirement_revisions', jsonb_build_object(
      'Sales users manage requirement revisions', jsonb_build_object('cmd', '*', 'qual', '(has_permission(auth.uid(), ''sales.manage''::text) OR has_role(auth.uid(), ''admin''::app_role))'),
      'Sales users view requirement revisions', jsonb_build_object('cmd', 'r', 'qual', '(has_permission(auth.uid(), ''sales.view''::text) OR has_permission(auth.uid(), ''engineering.view''::text) OR has_role(auth.uid(), ''admin''::app_role))')
    ),
    'requirement_feasibility_reviews', jsonb_build_object(
      'Sales users manage feasibility reviews', jsonb_build_object('cmd', '*', 'qual', '(has_permission(auth.uid(), ''sales.manage''::text) OR has_role(auth.uid(), ''admin''::app_role))'),
      'Authenticated users view feasibility reviews', jsonb_build_object('cmd', 'r', 'qual', '(has_permission(auth.uid(), ''sales.view''::text) OR has_permission(auth.uid(), ''engineering.view''::text) OR has_role(auth.uid(), ''admin''::app_role))')
    )
  );
  v_table_name text;
  v_policy_name text;
  v_policy jsonb;
  v_actual_command text;
  v_actual_qual text;
  v_actual_roles text[];
BEGIN
  FOR v_table_name, v_policy_name, v_policy IN
    SELECT table_entry.key, policy_entry.key, policy_entry.value
    FROM jsonb_each(v_expected) AS table_entry
    CROSS JOIN LATERAL jsonb_each(table_entry.value) AS policy_entry
  LOOP
    SELECT policy.polcmd, pg_get_expr(policy.polqual, policy.polrelid),
           ARRAY(SELECT role.rolname FROM pg_roles role WHERE role.oid = ANY(policy.polroles) ORDER BY role.rolname)
    INTO v_actual_command, v_actual_qual, v_actual_roles
    FROM pg_policy policy
    WHERE policy.polrelid = format('public.%I', v_table_name)::regclass
      AND policy.polname = v_policy_name;
    IF NOT FOUND
       OR v_actual_command IS DISTINCT FROM v_policy->>'cmd'
       OR regexp_replace(replace(replace(v_actual_qual, '::text', ''), '::app_role', ''), '\s+', '', 'g') IS DISTINCT FROM regexp_replace(replace(replace(v_policy->>'qual', '::text', ''), '::app_role', ''), '\s+', '', 'g')
       OR v_actual_roles IS DISTINCT FROM ARRAY['authenticated'] THEN
      RAISE EXCEPTION 'Original-target requirement read/write policy drift detected for %.%; capture and review the live policy before installation', v_table_name, v_policy_name;
    END IF;
  END LOOP;
END;
$read_policy_preflight$;

REVOKE INSERT, UPDATE, DELETE ON TABLE public.customer_requirements FROM PUBLIC, anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON TABLE public.customer_requirement_revisions FROM PUBLIC, anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON TABLE public.requirement_feasibility_reviews FROM PUBLIC, anon, authenticated;

DROP POLICY "Sales users manage requirements" ON public.customer_requirements;
DROP POLICY "Sales users manage requirement revisions" ON public.customer_requirement_revisions;
DROP POLICY IF EXISTS "Sales users manage feasibility reviews" ON public.requirement_feasibility_reviews;

-- The target's existing SELECT-only policies remain in place. Their predicates were compared
-- above, so the proposal does not rely on the removed ALL policies for read authorization.

-- The only proposed authenticated mutation entry points for this graph are:
-- * public.submit_sales_feasibility_handover(...)
-- * public.assign_requirement_feasibility_review(uuid, uuid, uuid)
-- * public.record_requirement_feasibility_response(uuid, text, text, text, text, uuid)
-- * public.submit_external_customer_requirement(uuid, uuid, text, text, jsonb, uuid)
-- * public.create_sales_bound_customer_requirement(uuid, uuid, uuid, text, text, text, uuid)
-- Existing protected baseline readers/approval may read the graph but are not granted a new
-- direct table write path here. service_role retains its existing administrative contract.
-- REVIEW ONLY: preserve the SELECT contribution of the removed ALL policies.
-- These exact predicates/roles already granted reads; this adds no read audience.
CREATE POLICY "Sales users manage requirements" ON public.customer_requirements FOR SELECT TO authenticated USING (has_permission(auth.uid(),'sales.manage'::text) OR has_role(auth.uid(),'admin'::app_role));
CREATE POLICY "Sales users manage requirement revisions" ON public.customer_requirement_revisions FOR SELECT TO authenticated USING (has_permission(auth.uid(),'sales.manage'::text) OR has_role(auth.uid(),'admin'::app_role));
CREATE POLICY "Sales users manage feasibility reviews" ON public.requirement_feasibility_reviews FOR SELECT TO authenticated USING (has_permission(auth.uid(),'sales.manage'::text) OR has_role(auth.uid(),'admin'::app_role));

-- REVIEW ONLY. Not installed; requires separate approval and restore/caller acceptance.
-- Include after the reviewed original-target I/U/D transition in the SAME transaction.
-- TRUNCATE bypasses row-level policies; leaving its table grant is not direct-write denial.
DO $truncate_preflight$
DECLARE target regclass;
BEGIN
 FOREACH target IN ARRAY ARRAY['public.customer_requirements'::regclass,'public.customer_requirement_revisions'::regclass,'public.requirement_feasibility_reviews'::regclass] LOOP
  IF has_table_privilege('authenticated',target,'INSERT,UPDATE,DELETE') OR has_table_privilege('anon',target,'INSERT,UPDATE,DELETE') THEN
   RAISE EXCEPTION 'Apply the reviewed direct I/U/D transition first';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_class WHERE oid=target AND relrowsecurity AND NOT relforcerowsecurity) THEN
   RAISE EXCEPTION 'Unexpected graph RLS state';
  END IF;
 END LOOP;
 IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND cmd='ALL' AND (tablename,policyname) IN (
 ('customer_requirements','Sales users manage requirements'),
 ('customer_requirement_revisions','Sales users manage requirement revisions'),
 ('requirement_feasibility_reviews','Sales users manage feasibility reviews'))) THEN
  RAISE EXCEPTION 'Broad graph write policies remain';
 END IF;
END;
$truncate_preflight$;
REVOKE TRUNCATE ON public.customer_requirements,public.customer_requirement_revisions,public.requirement_feasibility_reviews FROM PUBLIC,anon,authenticated;
DO $truncate_postflight$
DECLARE target regclass;
BEGIN
 FOREACH target IN ARRAY ARRAY['public.customer_requirements'::regclass,'public.customer_requirement_revisions'::regclass,'public.requirement_feasibility_reviews'::regclass] LOOP
  IF has_table_privilege('authenticated',target,'INSERT,UPDATE,DELETE,TRUNCATE') OR has_table_privilege('anon',target,'INSERT,UPDATE,DELETE,TRUNCATE') THEN
   RAISE EXCEPTION 'Runtime graph write boundary is incomplete';
  END IF;
 END LOOP;
END;
$truncate_postflight$;

COMMIT;
