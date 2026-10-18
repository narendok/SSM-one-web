-- REVIEW ONLY: not installed; no application activation or identity backfill.
-- Original backend yyrvduosyyaluifqvwkr. Separate schema/access review required.
-- Proposed explicit steward-verified identity history. Names/emails are never matched.
BEGIN;
CREATE SCHEMA _ssm_task_identity;
REVOKE ALL ON SCHEMA _ssm_task_identity FROM PUBLIC, anon, authenticated, service_role;
CREATE TABLE _ssm_task_identity.member_employee_versions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rd_member_id uuid NOT NULL REFERENCES public.rd_members(id) ON DELETE RESTRICT,
  employee_id uuid NOT NULL REFERENCES public.employees(id) ON DELETE RESTRICT,
  verified_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  verified_at timestamptz NOT NULL DEFAULT transaction_timestamp(),
  verification_reason text NOT NULL CHECK (length(btrim(verification_reason)) BETWEEN 1 AND 1000),
  revoked_by uuid REFERENCES auth.users(id) ON DELETE RESTRICT,
  revoked_at timestamptz,
  CHECK ((revoked_by IS NULL) = (revoked_at IS NULL)),
  CHECK (revoked_at IS NULL OR revoked_at >= verified_at)
);
-- Proposed one-to-one CURRENT link, while retaining revoked rows. Requires review.
CREATE UNIQUE INDEX member_employee_current_member ON _ssm_task_identity.member_employee_versions(rd_member_id) WHERE revoked_at IS NULL;
CREATE UNIQUE INDEX member_employee_current_employee ON _ssm_task_identity.member_employee_versions(employee_id) WHERE revoked_at IS NULL;
ALTER TABLE _ssm_task_identity.member_employee_versions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE _ssm_task_identity.member_employee_versions FROM PUBLIC, anon, authenticated, service_role;
-- No app roles, policies, RPCs, existing task/member updates, or approved mappings.
-- Membership, capability/delegation, audit/replay and protected write contracts are separate.
COMMIT;
