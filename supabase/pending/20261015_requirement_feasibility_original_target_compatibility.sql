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