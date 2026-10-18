-- REVIEW ONLY / NOT INSTALLED. Owner-private, no application grants or backfill.
-- Generated from reviewed sources with one atomic transaction; do not install pieces separately.
BEGIN;
-- Source: 20261018_task_member_identity_private_review_only.sql; LF-normalized SHA256 5872257c7217bb985be0a60f5aab88644c560989c6c5b6695155dfb4553e9fe8
-- REVIEW ONLY: not installed; no application activation or identity backfill.
-- Original backend yyrvduosyyaluifqvwkr. Separate schema/access review required.
-- Proposed explicit steward-verified identity history. Names/emails are never matched.
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

-- Source: 20261018_task_identity_steward_transaction_review_only.sql; LF-normalized SHA256 874eb65277c11909a1afa1b6845c272b95afe8ca819402fa46ce8e2e27f33dba
-- REVIEW ONLY, NOT INSTALLED. Requires the separately reviewed private identity schema.
-- No application-role execution, public wrapper, mapping backfill or task authority.
DO $steward_preflight$
DECLARE source_name text; source_oid regclass; spec record;
BEGIN
 IF to_regclass('_ssm_task_identity.member_employee_versions') IS NULL THEN RAISE EXCEPTION 'Private identity prerequisite missing'; END IF;
 FOREACH source_name IN ARRAY ARRAY['public.employees','public.rd_members','public.employee_departments','public.activity_log'] LOOP
  source_oid:=to_regclass(source_name);
  IF source_oid IS NULL OR NOT EXISTS(SELECT 1 FROM pg_class WHERE oid=source_oid AND relkind='r' AND relrowsecurity AND relowner=(SELECT oid FROM pg_roles WHERE rolname=current_user)) THEN
   RAISE EXCEPTION 'Steward source ownership/RLS prerequisite mismatch: %',source_name;
  END IF;
 END LOOP;
 FOR spec IN SELECT * FROM (VALUES
  ('public.employees','id','uuid'),('public.employees','user_id','uuid'),
  ('public.rd_members','id','uuid'),('public.rd_members','department_id','uuid'),('public.rd_members','active','boolean'),
  ('public.employee_departments','employee_id','uuid'),('public.employee_departments','department_id','uuid'),
  ('public.activity_log','id','uuid'),('public.activity_log','actor_user_id','uuid'),
  ('public.activity_log','entity_id','uuid'),('public.activity_log','module_key','text'),
  ('public.activity_log','entity_type','text'),('public.activity_log','action','text'),
  ('public.activity_log','summary','text'),('public.activity_log','after_data','jsonb')
 ) AS expected(table_name,column_name,type_name) LOOP
  IF NOT EXISTS(SELECT 1 FROM pg_attribute WHERE attrelid=to_regclass(spec.table_name) AND attname=spec.column_name AND NOT attisdropped AND atttypid=to_regtype(spec.type_name)) THEN
   RAISE EXCEPTION 'Steward source column prerequisite mismatch: %.%',spec.table_name,spec.column_name;
  END IF;
 END LOOP;
 IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='public.employee_departments'::regclass AND contype='p' AND conkey=ARRAY[
  (SELECT attnum FROM pg_attribute WHERE attrelid='public.employee_departments'::regclass AND attname='employee_id'),
  (SELECT attnum FROM pg_attribute WHERE attrelid='public.employee_departments'::regclass AND attname='department_id')]) THEN
  RAISE EXCEPTION 'Steward membership primary key prerequisite mismatch';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_proc WHERE oid=to_regprocedure('public.has_role(uuid,public.app_role)') AND prorettype='boolean'::regtype AND provolatile='s' AND prosecdef) THEN
  RAISE EXCEPTION 'Steward role helper prerequisite mismatch';
 END IF;
END;
$steward_preflight$;
CREATE TABLE _ssm_task_identity.mapping_requests (
 actor_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
 request_key uuid NOT NULL,
 rd_member_id uuid NOT NULL REFERENCES public.rd_members(id) ON DELETE RESTRICT,
 employee_id uuid NOT NULL REFERENCES public.employees(id) ON DELETE RESTRICT,
 expected_version_id uuid,
 verification_reason text NOT NULL,
 audit_id uuid NOT NULL UNIQUE REFERENCES public.activity_log(id) ON DELETE RESTRICT,
 result_version_id uuid NOT NULL REFERENCES _ssm_task_identity.member_employee_versions(id) ON DELETE RESTRICT,
 recorded_at timestamptz NOT NULL DEFAULT transaction_timestamp(),
 PRIMARY KEY(actor_id,request_key)
);
ALTER TABLE _ssm_task_identity.mapping_requests ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE _ssm_task_identity.mapping_requests FROM PUBLIC,anon,authenticated,service_role;
CREATE FUNCTION _ssm_task_identity.record_mapping(
 p_member uuid,p_employee uuid,p_expected_version uuid,p_request_key uuid,p_reason text
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $mapping$
DECLARE actor uuid:=auth.uid(); actor_employee uuid; canonical_reason text:=btrim(p_reason);
 member_department uuid; previous _ssm_task_identity.member_employee_versions%ROWTYPE;
 receipt _ssm_task_identity.mapping_requests%ROWTYPE; result_id uuid; audit_id uuid; transition_at timestamptz;
BEGIN
 IF actor IS NULL OR NOT public.has_role(actor,'admin'::public.app_role) THEN RAISE EXCEPTION 'Identity steward authority required'; END IF;
 -- Serialize this proposed low-volume stewardship operation; external membership changes
 -- are separately held with row locks. This is not a concurrency acceptance claim.
 PERFORM pg_advisory_xact_lock(839071418);
 -- A queued request must not retain a role revoked while it waited.
 IF NOT public.has_role(actor,'admin'::public.app_role) THEN RAISE EXCEPTION 'Identity steward authority required'; END IF;
 SELECT id INTO STRICT actor_employee FROM public.employees WHERE user_id=actor AND employment_status='ACTIVE' FOR SHARE;
 IF p_member IS NULL OR p_employee IS NULL OR p_request_key IS NULL OR canonical_reason IS NULL OR length(canonical_reason) NOT BETWEEN 1 AND 1000 THEN RAISE EXCEPTION 'Explicit identity and verification reason required'; END IF;
 SELECT department_id INTO member_department FROM public.rd_members WHERE id=p_member AND active IS TRUE FOR SHARE;
 IF NOT FOUND OR member_department IS NULL THEN RAISE EXCEPTION 'Active canonical member required'; END IF;
 PERFORM 1 FROM public.employees WHERE id=p_employee AND employment_status='ACTIVE' FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Active employee required'; END IF;
 PERFORM 1 FROM public.employee_departments WHERE employee_id=p_employee AND department_id=member_department FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Current employee department membership required'; END IF;
 -- Current authority/scope is checked before replay, including removed membership.
 SELECT * INTO receipt FROM _ssm_task_identity.mapping_requests WHERE actor_id=actor AND request_key=p_request_key;
 IF FOUND THEN
  IF receipt.rd_member_id<>p_member OR receipt.employee_id<>p_employee OR receipt.expected_version_id IS DISTINCT FROM p_expected_version OR receipt.verification_reason<>canonical_reason THEN RAISE EXCEPTION 'Identity request payload conflict'; END IF;
  PERFORM 1 FROM _ssm_task_identity.member_employee_versions WHERE id=receipt.result_version_id AND rd_member_id=p_member AND employee_id=p_employee AND revoked_at IS NULL;
  IF NOT FOUND THEN RAISE EXCEPTION 'Identity receipt is no longer current'; END IF;
  PERFORM 1 FROM public.activity_log a WHERE a.id=receipt.audit_id AND a.actor_user_id=actor AND a.module_key='projects' AND a.entity_type='task_member_identity' AND a.entity_id=receipt.result_version_id AND a.action='mapping_verified'
   AND a.after_data=jsonb_build_object('request_key',p_request_key,'rd_member_id',p_member,'employee_id',p_employee,'expected_version_id',p_expected_version,'result_version_id',receipt.result_version_id);
  IF NOT FOUND THEN RAISE EXCEPTION 'Mapping audit receipt mismatch'; END IF;
  RETURN receipt.result_version_id;
 END IF;
 SELECT * INTO previous FROM _ssm_task_identity.member_employee_versions WHERE rd_member_id=p_member AND revoked_at IS NULL FOR UPDATE;
 IF previous.id IS DISTINCT FROM p_expected_version THEN RAISE EXCEPTION 'Identity version changed; refresh before mapping'; END IF;
 IF EXISTS(SELECT 1 FROM _ssm_task_identity.member_employee_versions WHERE employee_id=p_employee AND revoked_at IS NULL AND rd_member_id<>p_member) THEN RAISE EXCEPTION 'Employee already linked to another member'; END IF;
 IF previous.employee_id=p_employee THEN result_id:=previous.id;
 ELSE
  -- Capture transition time after serialization; transaction start may predate a newer mapping.
  transition_at:=clock_timestamp();
  IF previous.id IS NOT NULL THEN UPDATE _ssm_task_identity.member_employee_versions SET revoked_by=actor,revoked_at=transition_at WHERE id=previous.id; END IF;
  INSERT INTO _ssm_task_identity.member_employee_versions(rd_member_id,employee_id,verified_by,verification_reason,verified_at) VALUES(p_member,p_employee,actor,canonical_reason,transition_at) RETURNING id INTO result_id;
 END IF;
 INSERT INTO public.activity_log(actor_user_id,module_key,entity_type,entity_id,action,summary,after_data)
 VALUES(actor,'projects','task_member_identity',result_id,'mapping_verified','Task member identity mapping verified.',jsonb_build_object('request_key',p_request_key,'rd_member_id',p_member,'employee_id',p_employee,'expected_version_id',p_expected_version,'result_version_id',result_id)) RETURNING id INTO audit_id;
 INSERT INTO _ssm_task_identity.mapping_requests(actor_id,request_key,rd_member_id,employee_id,expected_version_id,verification_reason,result_version_id,audit_id) VALUES(actor,p_request_key,p_member,p_employee,p_expected_version,canonical_reason,result_id,audit_id);
 RETURN result_id;
END;
$mapping$;
REVOKE ALL ON FUNCTION _ssm_task_identity.record_mapping(uuid,uuid,uuid,uuid,text) FROM PUBLIC,anon,authenticated,service_role;

-- Source: 20261018_task_identity_readback_revoke_review_only.sql; LF-normalized SHA256 f6927df6b426d99be30c18c94cf643c9b46aaf30f373090fc8fa9aa05c71aefa
-- REVIEW ONLY / NOT INSTALLED. No application grants or public wrappers.
CREATE FUNCTION _ssm_task_identity.read_mapping_receipt(p_key uuid,p_member uuid,p_employee uuid,p_version uuid)
RETURNS TABLE(version_id uuid,verified_at timestamptz,request_key uuid)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $read$
 SELECT v.id,v.verified_at,r.request_key
 FROM _ssm_task_identity.mapping_requests r
 JOIN _ssm_task_identity.member_employee_versions v ON v.id=r.result_version_id AND v.rd_member_id=r.rd_member_id AND v.employee_id=r.employee_id
 JOIN public.activity_log a ON a.id=r.audit_id AND a.actor_user_id=r.actor_id AND a.module_key='projects' AND a.entity_type='task_member_identity' AND a.entity_id=v.id AND a.action='mapping_verified' AND a.after_data=jsonb_build_object('request_key',r.request_key,'rd_member_id',r.rd_member_id,'employee_id',r.employee_id,'expected_version_id',r.expected_version_id,'result_version_id',v.id)
 JOIN public.rd_members m ON m.id=v.rd_member_id AND m.active IS TRUE
 JOIN public.employees e ON e.id=v.employee_id AND e.employment_status='ACTIVE'
 JOIN public.employee_departments d ON d.employee_id=e.id AND d.department_id=m.department_id
 WHERE r.actor_id=auth.uid() AND r.request_key=p_key AND r.rd_member_id=p_member AND r.employee_id=p_employee AND v.id=p_version AND v.revoked_at IS NULL
 AND public.has_role(auth.uid(),'admin'::public.app_role)
 AND (SELECT count(*) FROM public.employees actor WHERE actor.user_id=auth.uid() AND actor.employment_status='ACTIVE')=1;
$read$;
REVOKE ALL ON FUNCTION _ssm_task_identity.read_mapping_receipt(uuid,uuid,uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;
CREATE TABLE _ssm_task_identity.revocation_requests(
 actor_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
 request_key uuid NOT NULL,
 version_id uuid NOT NULL REFERENCES _ssm_task_identity.member_employee_versions(id) ON DELETE RESTRICT,
 rd_member_id uuid NOT NULL REFERENCES public.rd_members(id) ON DELETE RESTRICT,
 reason text NOT NULL,
 audit_id uuid NOT NULL UNIQUE REFERENCES public.activity_log(id) ON DELETE RESTRICT,
 revoked_at timestamptz NOT NULL,
 PRIMARY KEY(actor_id,request_key)
);
ALTER TABLE _ssm_task_identity.revocation_requests ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE _ssm_task_identity.revocation_requests FROM PUBLIC,anon,authenticated,service_role;
CREATE FUNCTION _ssm_task_identity.revoke_mapping(p_key uuid,p_member uuid,p_version uuid,p_reason text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $revoke$
DECLARE actor uuid:=auth.uid(); actor_employee uuid; canonical_reason text:=btrim(p_reason);
 receipt _ssm_task_identity.revocation_requests%ROWTYPE; source _ssm_task_identity.member_employee_versions%ROWTYPE; changed_at timestamptz; audit_id uuid;
BEGIN
 IF actor IS NULL THEN RAISE EXCEPTION 'Identity steward authority required'; END IF;
 PERFORM pg_advisory_xact_lock(839071418);
 IF NOT public.has_role(actor,'admin'::public.app_role) THEN RAISE EXCEPTION 'Identity steward authority required'; END IF;
 SELECT id INTO STRICT actor_employee FROM public.employees WHERE user_id=actor AND employment_status='ACTIVE' FOR SHARE;
 IF p_key IS NULL OR p_member IS NULL OR p_version IS NULL OR canonical_reason IS NULL OR length(canonical_reason) NOT BETWEEN 1 AND 1000 THEN RAISE EXCEPTION 'Explicit revocation identity and reason required'; END IF;
 SELECT * INTO receipt FROM _ssm_task_identity.revocation_requests WHERE actor_id=actor AND request_key=p_key;
 IF FOUND THEN
  IF receipt.version_id<>p_version OR receipt.rd_member_id<>p_member OR receipt.reason<>canonical_reason THEN RAISE EXCEPTION 'Revocation payload conflict'; END IF;
  PERFORM 1 FROM _ssm_task_identity.member_employee_versions WHERE id=p_version AND rd_member_id=p_member AND revoked_by=actor AND revoked_at=receipt.revoked_at;
  IF NOT FOUND THEN RAISE EXCEPTION 'Revocation receipt mismatch'; END IF;
  PERFORM 1 FROM public.activity_log a WHERE a.id=receipt.audit_id AND a.actor_user_id=actor AND a.module_key='projects' AND a.entity_type='task_member_identity' AND a.entity_id=p_version AND a.action='mapping_revoked' AND a.after_data=jsonb_build_object('request_key',p_key,'rd_member_id',p_member,'version_id',p_version);
  IF NOT FOUND THEN RAISE EXCEPTION 'Revocation audit receipt mismatch'; END IF;
  RETURN p_version;
 END IF;
 SELECT * INTO source FROM _ssm_task_identity.member_employee_versions WHERE id=p_version AND rd_member_id=p_member AND revoked_at IS NULL FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Current exact identity version required'; END IF;
 -- Withdrawal remains possible after subject deactivation/removal; actor authority is current.
 changed_at:=clock_timestamp();
 UPDATE _ssm_task_identity.member_employee_versions SET revoked_by=actor,revoked_at=changed_at WHERE id=source.id;
 INSERT INTO public.activity_log(actor_user_id,module_key,entity_type,entity_id,action,summary,after_data) VALUES(actor,'projects','task_member_identity',p_version,'mapping_revoked','Task member identity mapping withdrawn.',jsonb_build_object('request_key',p_key,'rd_member_id',p_member,'version_id',p_version)) RETURNING id INTO audit_id;
 INSERT INTO _ssm_task_identity.revocation_requests(actor_id,request_key,version_id,rd_member_id,reason,revoked_at,audit_id) VALUES(actor,p_key,p_version,p_member,canonical_reason,changed_at,audit_id);
 RETURN p_version;
END;
$revoke$;
REVOKE ALL ON FUNCTION _ssm_task_identity.revoke_mapping(uuid,uuid,uuid,text) FROM PUBLIC,anon,authenticated,service_role;
CREATE FUNCTION _ssm_task_identity.read_revocation_receipt(p_key uuid,p_member uuid,p_version uuid)
RETURNS TABLE(version_id uuid,revoked_at timestamptz,audit_id uuid)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $read_revoke$
 SELECT v.id,v.revoked_at,a.id FROM _ssm_task_identity.revocation_requests r
 JOIN _ssm_task_identity.member_employee_versions v ON v.id=r.version_id AND v.rd_member_id=r.rd_member_id AND v.revoked_by=r.actor_id AND v.revoked_at=r.revoked_at
 JOIN public.activity_log a ON a.id=r.audit_id AND a.actor_user_id=r.actor_id AND a.module_key='projects' AND a.entity_type='task_member_identity' AND a.entity_id=v.id AND a.action='mapping_revoked' AND a.after_data=jsonb_build_object('request_key',r.request_key,'rd_member_id',r.rd_member_id,'version_id',v.id)
 WHERE r.actor_id=auth.uid() AND r.request_key=p_key AND r.rd_member_id=p_member AND v.id=p_version
 AND public.has_role(auth.uid(),'admin'::public.app_role)
 AND (SELECT count(*) FROM public.employees actor WHERE actor.user_id=auth.uid() AND actor.employment_status='ACTIVE')=1;
$read_revoke$;
REVOKE ALL ON FUNCTION _ssm_task_identity.read_revocation_receipt(uuid,uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;

DO $bundle_postflight$
DECLARE application_role name; object_oid oid; object_count integer; populated boolean;
BEGIN
 SELECT count(*) INTO object_count FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='_ssm_task_identity' AND c.relkind='r';
 IF object_count<>3 THEN RAISE EXCEPTION 'Private identity bundle table inventory mismatch'; END IF;
 IF EXISTS(SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='_ssm_task_identity' AND c.relkind='r' AND (NOT c.relrowsecurity OR c.relowner<>(SELECT oid FROM pg_roles WHERE rolname=current_user))) THEN RAISE EXCEPTION 'Private identity bundle table ownership/RLS mismatch'; END IF;
 SELECT count(*) INTO object_count FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='_ssm_task_identity';
 IF object_count<>4 THEN RAISE EXCEPTION 'Private identity bundle function inventory mismatch'; END IF;
 FOREACH application_role IN ARRAY ARRAY['anon'::name,'authenticated'::name,'service_role'::name] LOOP
  IF has_schema_privilege(application_role,'_ssm_task_identity','USAGE,CREATE') THEN RAISE EXCEPTION 'Private identity schema application access remains'; END IF;
  FOR object_oid IN SELECT c.oid FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='_ssm_task_identity' AND c.relkind='r' LOOP
   IF has_table_privilege(application_role,object_oid,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER') THEN RAISE EXCEPTION 'Private identity table application access remains'; END IF;
  END LOOP;
  FOR object_oid IN SELECT p.oid FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='_ssm_task_identity' LOOP
   IF has_function_privilege(application_role,object_oid,'EXECUTE') THEN RAISE EXCEPTION 'Private identity function application execution remains'; END IF;
  END LOOP;
 END LOOP;
 FOR object_oid IN SELECT c.oid FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='_ssm_task_identity' AND c.relkind='r' LOOP
  EXECUTE format('SELECT EXISTS(SELECT 1 FROM %s)',object_oid::regclass) INTO populated;
  IF populated THEN RAISE EXCEPTION 'Unexpected private identity backfill'; END IF;
 END LOOP;
END;
$bundle_postflight$;
COMMIT;
