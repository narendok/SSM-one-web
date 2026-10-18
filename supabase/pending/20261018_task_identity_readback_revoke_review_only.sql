-- REVIEW ONLY / NOT INSTALLED. No application grants or public wrappers.
BEGIN;
CREATE FUNCTION _ssm_task_identity.read_mapping_receipt(p_key uuid,p_member uuid,p_employee uuid,p_version uuid)
RETURNS TABLE(version_id uuid,verified_at timestamptz,request_key uuid)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $read$
 SELECT v.id,v.verified_at,r.request_key
 FROM _ssm_task_identity.mapping_requests r
 JOIN _ssm_task_identity.member_employee_versions v ON v.id=r.result_version_id AND v.rd_member_id=r.rd_member_id AND v.employee_id=r.employee_id
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
 revoked_at timestamptz NOT NULL,
 PRIMARY KEY(actor_id,request_key)
);
ALTER TABLE _ssm_task_identity.revocation_requests ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE _ssm_task_identity.revocation_requests FROM PUBLIC,anon,authenticated,service_role;
CREATE FUNCTION _ssm_task_identity.revoke_mapping(p_key uuid,p_member uuid,p_version uuid,p_reason text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $revoke$
DECLARE actor uuid:=auth.uid(); actor_employee uuid; canonical_reason text:=btrim(p_reason);
 receipt _ssm_task_identity.revocation_requests%ROWTYPE; source _ssm_task_identity.member_employee_versions%ROWTYPE; changed_at timestamptz;
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
  RETURN p_version;
 END IF;
 SELECT * INTO source FROM _ssm_task_identity.member_employee_versions WHERE id=p_version AND rd_member_id=p_member AND revoked_at IS NULL FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Current exact identity version required'; END IF;
 -- Withdrawal remains possible after subject deactivation/removal; actor authority is current.
 changed_at:=clock_timestamp();
 UPDATE _ssm_task_identity.member_employee_versions SET revoked_by=actor,revoked_at=changed_at WHERE id=source.id;
 INSERT INTO _ssm_task_identity.revocation_requests(actor_id,request_key,version_id,rd_member_id,reason,revoked_at) VALUES(actor,p_key,p_version,p_member,canonical_reason,changed_at);
 RETURN p_version;
END;
$revoke$;
REVOKE ALL ON FUNCTION _ssm_task_identity.revoke_mapping(uuid,uuid,uuid,text) FROM PUBLIC,anon,authenticated,service_role;
COMMIT;
