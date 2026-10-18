-- REVIEW ONLY: not installed; no application activation or identity backfill.
-- Original backend yyrvduosyyaluifqvwkr. Separate schema/access review required.
-- Proposed explicit steward-verified identity history. Names/emails are never matched.
BEGIN;
DO $identity_preflight$
DECLARE target regclass; row_security boolean; table_owner name; id_type oid;
BEGIN
  IF to_regnamespace('_ssm_task_identity') IS NOT NULL THEN
    RAISE EXCEPTION 'Identity schema already exists; inspect rather than overwrite';
  END IF;
  FOREACH target IN ARRAY ARRAY[to_regclass('public.rd_members'),to_regclass('public.employees')] LOOP
    IF target IS NULL THEN RAISE EXCEPTION 'Required identity source table is missing'; END IF;
    SELECT relrowsecurity,pg_get_userbyid(relowner) INTO row_security,table_owner FROM pg_class WHERE oid=target;
    IF NOT row_security OR table_owner<>current_user THEN
      RAISE EXCEPTION 'Identity source ownership/RLS prerequisite mismatch';
    END IF;
    SELECT atttypid INTO id_type FROM pg_attribute WHERE attrelid=target AND attname='id' AND NOT attisdropped;
    IF id_type IS DISTINCT FROM 'uuid'::regtype::oid THEN RAISE EXCEPTION 'Identity source UUID key mismatch'; END IF;
  END LOOP;
  IF to_regclass('auth.users') IS NULL THEN RAISE EXCEPTION 'Verifying actor source is missing'; END IF;
END;
$identity_preflight$;
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
DO $identity_postflight$
DECLARE actor name;
BEGIN
  FOREACH actor IN ARRAY ARRAY['anon'::name,'authenticated'::name,'service_role'::name] LOOP
    IF has_schema_privilege(actor,'_ssm_task_identity','USAGE,CREATE') OR
       has_table_privilege(actor,'_ssm_task_identity.member_employee_versions','SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER') THEN
      RAISE EXCEPTION 'Application role unexpectedly retains identity bridge access';
    END IF;
  END LOOP;
  IF EXISTS (SELECT 1 FROM _ssm_task_identity.member_employee_versions) THEN RAISE EXCEPTION 'Unexpected identity backfill'; END IF;
END;
$identity_postflight$;
COMMIT;
