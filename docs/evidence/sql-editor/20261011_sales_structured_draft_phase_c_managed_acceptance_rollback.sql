-- REVIEW-ONLY PHASE C MANAGED CALLER ACCEPTANCE. ALWAYS ROLLS BACK.
-- Use a real authenticated request context for an existing authorized Sales actor.
-- SET LOCAL ROLE authenticated alone does NOT establish auth.uid(), JWT claims, or actor authenticity.
-- Do not execute this in the postgres SQL editor as a substitute for caller-authenticated acceptance.
--
-- Minimal temporary transport: if and only if the managed caller path cannot reach the
-- default-revoked audited save function, a privileged operator may GRANT EXECUTE inside
-- this same transaction only, run acceptance through the real bearer/JWT transport, then
-- ROLLBACK. This grant must never be committed and cannot prove caller identity.

BEGIN;
SET LOCAL ROLE authenticated;

-- Required actor evidence: must be non-null and match the pre-approved existing Sales actor.
SELECT auth.uid() AS authenticated_actor_id,
       public.has_permission(auth.uid(), 'sales.manage') AS has_sales_manage;

-- This is intentionally commented. It is transport-only, transaction-local, and rolls back.
-- GRANT EXECUTE ON FUNCTION public.save_sales_opportunity_structured_draft_at_location(uuid, uuid, uuid, uuid, text, integer, jsonb, uuid, uuid) TO authenticated;
-- GRANT EXECUTE ON FUNCTION public.resolve_sales_opportunity_structured_draft_location(uuid, uuid, uuid) TO authenticated;
-- GRANT EXECUTE ON FUNCTION public.register_sales_opportunity_structured_draft_storage_attempt(uuid, uuid, uuid, uuid, text, text, text, bigint) TO authenticated;
-- GRANT EXECUTE ON FUNCTION public.commit_sales_opportunity_structured_draft_materialization(uuid, uuid, uuid, uuid, text, text, text, text, bigint) TO authenticated;
-- GRANT EXECUTE ON FUNCTION public.can_discard_sales_opportunity_structured_draft_object(uuid, uuid, uuid, uuid, text, text) TO authenticated;

-- Required external managed acceptance cases, all against the caller’s real authenticated transport:
-- 1. audited save/reload/exact replay and conflicting-payload denial using the approved binding;
-- 2. source tuple mismatch, stale revision, unauthorized actor, and wrong-location denial;
-- 3. immutable audit/revision/location history and rollback preservation;
-- 4. storage staging/materialization checksum/size, replay, conflict, and caller-scoped download;
-- 5. reserved Sales-prefix isolation, non-reserved project/Engineering preservation, and direct-write/update/delete denial.
-- Record results outside this transaction. No acceptance write, location binding, policy, or grant persists.

ROLLBACK;
