-- REVIEW ONLY, NOT INSTALLED. Requires the separately reviewed private identity schema.
-- No application-role execution, public wrapper, mapping backfill or task authority.
BEGIN;
CREATE TABLE _ssm_task_identity.mapping_requests (
 actor_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
 request_key uuid NOT NULL,
 rd_member_id uuid NOT NULL REFERENCES public.rd_members(id) ON DELETE RESTRICT,
 employee_id uuid NOT NULL REFERENCES public.employees(id) ON DELETE RESTRICT,
 expected_version_id uuid,
 verification_reason text NOT NULL,
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
 receipt _ssm_task_identity.mapping_requests%ROWTYPE; result_id uuid;
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
  RETURN receipt.result_version_id;
 END IF;
 SELECT * INTO previous FROM _ssm_task_identity.member_employee_versions WHERE rd_member_id=p_member AND revoked_at IS NULL FOR UPDATE;
 IF previous.id IS DISTINCT FROM p_expected_version THEN RAISE EXCEPTION 'Identity version changed; refresh before mapping'; END IF;
 IF EXISTS(SELECT 1 FROM _ssm_task_identity.member_employee_versions WHERE employee_id=p_employee AND revoked_at IS NULL AND rd_member_id<>p_member) THEN RAISE EXCEPTION 'Employee already linked to another member'; END IF;
 IF previous.employee_id=p_employee THEN result_id:=previous.id;
 ELSE
  IF previous.id IS NOT NULL THEN UPDATE _ssm_task_identity.member_employee_versions SET revoked_by=actor,revoked_at=transaction_timestamp() WHERE id=previous.id; END IF;
  INSERT INTO _ssm_task_identity.member_employee_versions(rd_member_id,employee_id,verified_by,verification_reason) VALUES(p_member,p_employee,actor,canonical_reason) RETURNING id INTO result_id;
 END IF;
 INSERT INTO _ssm_task_identity.mapping_requests(actor_id,request_key,rd_member_id,employee_id,expected_version_id,verification_reason,result_version_id) VALUES(actor,p_request_key,p_member,p_employee,p_expected_version,canonical_reason,result_id);
 RETURN result_id;
END;
$mapping$;
REVOKE ALL ON FUNCTION _ssm_task_identity.record_mapping(uuid,uuid,uuid,uuid,text) FROM PUBLIC,anon,authenticated,service_role;
COMMIT;
