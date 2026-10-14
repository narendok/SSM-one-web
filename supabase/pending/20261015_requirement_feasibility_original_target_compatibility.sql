-- SOURCE-ONLY ORIGINAL-TARGET COMPATIBILITY PROPOSAL.
--
-- This file is for the original managed target only. It is not the isolated-target
-- `20261011_requirement_feasibility_direct_write_compatibility_transition.sql`, does not
-- repurpose that proposal, and must not be run without a separate exact approval.
--
-- Prerequisites before any future installation:
-- 1. Install and caller-RLS accept the protected handover, assignment, and response routines
--    named below on the original target.
-- 2. Verify every remaining direct writer/service route for these three tables has either moved
--    to a listed protected operation or has a separately approved replacement.
-- 3. Run target-bound ordinary-caller RLS, rollback, concurrency, and restore acceptance.
-- 4. Capture current grants and the three named policy definitions for a reversible restore.
--
-- This change deliberately does not drop any legacy scope helper or alter SELECT access.
-- It removes only direct INSERT/UPDATE/DELETE access to the handover replay graph.

REVOKE INSERT, UPDATE, DELETE ON TABLE public.customer_requirements FROM PUBLIC, anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON TABLE public.customer_requirement_revisions FROM PUBLIC, anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON TABLE public.requirement_feasibility_reviews FROM PUBLIC, anon, authenticated;

DROP POLICY IF EXISTS "Sales users manage customer requirements" ON public.customer_requirements;
DROP POLICY IF EXISTS "Sales users manage customer requirement revisions" ON public.customer_requirement_revisions;
DROP POLICY IF EXISTS "Sales users manage feasibility reviews" ON public.requirement_feasibility_reviews;

-- The only proposed authenticated mutation entry points for this graph are:
-- * public.submit_sales_feasibility_handover(...)
-- * public.assign_requirement_feasibility_review(uuid, uuid, uuid)
-- * public.record_requirement_feasibility_response(uuid, text, text, text, text, uuid)
-- * public.submit_external_customer_requirement(uuid, uuid, text, text, jsonb, uuid)
-- * public.create_sales_bound_customer_requirement(uuid, uuid, uuid, text, text, text, uuid)
-- Existing protected baseline readers/approval may read the graph but are not granted a new
-- direct table write path here. service_role retains its existing administrative contract.