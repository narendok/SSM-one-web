-- SOURCE-ONLY, UNDEPLOYED REVIEW CONTRACT.
--
-- This contract is additive and intentionally does not alter existing HTML
-- materializations or activate a caller grant. It protects only the reserved
-- structured-DOCX request path. Restrictive policies are essential here:
-- existing permissive project-drive policies combine with OR and must never
-- make a DOCX path writable by a project manager or department member.

CREATE OR REPLACE FUNCTION public.is_sales_structured_docx_request_path(p_bucket text, p_path text)
RETURNS boolean LANGUAGE sql IMMUTABLE SET search_path = public AS $$
  SELECT p_bucket = 'project-drive'
    AND p_path ~ '^sales/opportunity/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}-draft\.docx$'
$$;

-- Pre-insert authorization only. It intentionally requires that neither the
-- object nor a verifier receipt exists, so an authenticated caller can create
-- exactly one request-key object but can never replace it.
CREATE OR REPLACE FUNCTION public.can_stage_sales_structured_docx_object(p_bucket text, p_path text)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_actor uuid := auth.uid();
BEGIN
  IF v_actor IS NULL OR NOT public.is_sales_structured_docx_request_path(p_bucket, p_path) THEN RETURN false; END IF;
  RETURN EXISTS (
    SELECT 1
    FROM public.sales_opportunity_structured_docx_requests request_row
    JOIN public.sales_opportunity_structured_docx_assignments assignment_row ON assignment_row.id = request_row.assignment_id
    JOIN public.employees employee ON employee.id = assignment_row.responsible_employee_id
    JOIN public.employee_departments membership ON membership.employee_id = employee.id AND membership.department_id = assignment_row.department_id
    JOIN public.sales_opportunity_document_locations location_row ON location_row.id = request_row.location_id
    WHERE request_row.requested_by = v_actor
      AND assignment_row.status = 'ACTIVE'
      AND employee.user_id = v_actor AND employee.employment_status = 'ACTIVE'
      AND location_row.status = 'ACTIVE'
      AND location_row.private_storage_bucket = p_bucket
      AND p_path = location_row.private_storage_prefix || request_row.request_key::text || '-draft.docx'
      AND NOT EXISTS (SELECT 1 FROM public.sales_opportunity_structured_docx_storage_attempts attempt WHERE attempt.request_key = request_row.request_key)
      AND NOT EXISTS (SELECT 1 FROM storage.objects object_row WHERE object_row.bucket_id = p_bucket AND object_row.name = p_path)
  );
END;
$$;

-- Post-upload verifier boundary. This deliberately does not require a storage
-- attempt: the trusted verifier must be able to attest bytes before it issues
-- the immutable receipt. It is server-only and has no authenticated grant.
CREATE OR REPLACE FUNCTION public.assert_sales_structured_docx_uploaded_object(
  p_request_key uuid, p_bucket text, p_path text, p_object_version text
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_request public.sales_opportunity_structured_docx_requests%ROWTYPE;
BEGIN
  IF NULLIF(current_setting('request.jwt.claim.sub', true), '') IS NOT NULL THEN
    RAISE EXCEPTION 'Only the trusted DOCX object verifier may inspect an uploaded DOCX object';
  END IF;
  IF p_request_key IS NULL OR p_object_version IS NULL OR btrim(p_object_version) = ''
     OR NOT public.is_sales_structured_docx_request_path(p_bucket, p_path) THEN
    RAISE EXCEPTION 'Invalid trusted DOCX object identity';
  END IF;
  SELECT * INTO v_request
  FROM public.sales_opportunity_structured_docx_requests request_row
  WHERE request_row.request_key = p_request_key
  FOR SHARE;
  IF NOT FOUND
     OR p_path <> (SELECT location_row.private_storage_prefix || v_request.request_key::text || '-draft.docx'
                   FROM public.sales_opportunity_document_locations location_row
                   WHERE location_row.id = v_request.location_id
                     AND location_row.status = 'ACTIVE'
                     AND location_row.private_storage_bucket = p_bucket)
     OR NOT EXISTS (
       SELECT 1
       FROM public.sales_opportunity_structured_docx_assignments assignment_row
       JOIN public.employees employee ON employee.id = assignment_row.responsible_employee_id
       JOIN public.employee_departments membership ON membership.employee_id = employee.id
         AND membership.department_id = assignment_row.department_id
       WHERE assignment_row.id = v_request.assignment_id
         AND assignment_row.status = 'ACTIVE'
         AND employee.user_id = v_request.requested_by
         AND employee.employment_status = 'ACTIVE'
     ) THEN
    RAISE EXCEPTION 'Uploaded DOCX object no longer has an active assigned-person request';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM storage.objects object_row
    WHERE object_row.bucket_id = p_bucket
      AND object_row.name = p_path
      AND object_row.version = p_object_version
      AND object_row.archived_at IS NULL
      AND coalesce(object_row.is_delete_marker,false) = false
  ) THEN
    RAISE EXCEPTION 'Uploaded DOCX object version is absent or replaced';
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.can_read_sales_structured_docx_object(p_bucket text, p_path text)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_actor uuid := auth.uid();
BEGIN
  IF v_actor IS NULL OR NOT public.is_sales_structured_docx_request_path(p_bucket, p_path) THEN RETURN false; END IF;
  RETURN EXISTS (
    SELECT 1
    FROM public.sales_opportunity_structured_docx_materializations materialization
    JOIN public.sales_opportunity_structured_docx_assignments assignment_row ON assignment_row.id = materialization.assignment_id AND assignment_row.status = 'ACTIVE'
    JOIN public.employees employee ON employee.id = assignment_row.responsible_employee_id AND employee.user_id = v_actor AND employee.employment_status = 'ACTIVE'
    JOIN public.employee_departments membership ON membership.employee_id = employee.id AND membership.department_id = assignment_row.department_id
    JOIN public.sales_opportunity_document_locations location_row ON location_row.id = materialization.location_id AND location_row.status = 'ACTIVE'
    WHERE materialization.storage_bucket = p_bucket AND materialization.storage_path = p_path
      AND location_row.private_storage_bucket = p_bucket
  );
END;
$$;

-- Post-receipt actor boundary used by the server-only current-path reader
-- before and after a byte read. It is separate from pre-insert authorization:
-- an existing object/receipt is required here, but forbidden by staging.
CREATE OR REPLACE FUNCTION public.assert_sales_structured_docx_current_path_create_only(
  p_request_key uuid, p_bucket text, p_path text, p_object_version text
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_attempt public.sales_opportunity_structured_docx_storage_attempts%ROWTYPE;
BEGIN
  IF p_request_key IS NULL OR p_object_version IS NULL OR btrim(p_object_version) = ''
     OR NOT public.is_sales_structured_docx_request_path(p_bucket, p_path)
     OR NOT EXISTS (
       SELECT 1
       FROM public.sales_opportunity_structured_docx_requests request_row
       JOIN public.sales_opportunity_structured_docx_assignments assignment_row ON assignment_row.id = request_row.assignment_id
       JOIN public.employees employee ON employee.id = assignment_row.responsible_employee_id
       JOIN public.employee_departments membership ON membership.employee_id = employee.id
         AND membership.department_id = assignment_row.department_id
       JOIN public.sales_opportunity_document_locations location_row ON location_row.id = request_row.location_id
       WHERE request_row.request_key = p_request_key
         AND request_row.requested_by = auth.uid()
         AND assignment_row.status = 'ACTIVE'
         AND employee.user_id = auth.uid()
         AND employee.employment_status = 'ACTIVE'
         AND location_row.status = 'ACTIVE'
         AND location_row.private_storage_bucket = p_bucket
         AND p_path = location_row.private_storage_prefix || request_row.request_key::text || '-draft.docx'
     ) THEN
    RAISE EXCEPTION 'Current actor no longer owns an active verified DOCX request path';
  END IF;
  SELECT * INTO v_attempt FROM public.sales_opportunity_structured_docx_storage_attempts
  WHERE request_key = p_request_key AND storage_bucket = p_bucket AND storage_path = p_path AND object_version = p_object_version AND consumed_at IS NULL FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Trusted DOCX storage receipt is absent, consumed, or changed'; END IF;
  IF NOT EXISTS (SELECT 1 FROM storage.objects object_row WHERE object_row.bucket_id = p_bucket AND object_row.name = p_path AND object_row.version = p_object_version AND object_row.archived_at IS NULL AND coalesce(object_row.is_delete_marker,false) = false) THEN
    RAISE EXCEPTION 'Current DOCX object version is absent or replaced';
  END IF;
END;
$$;

-- Ordinary Drive/register/revision visibility must not become a second DOCX
-- authority. These helpers bind each tagged row back to the immutable
-- materialization graph and reuse the same active responsible-person check as
-- private object downloads.
CREATE OR REPLACE FUNCTION public.is_sales_structured_docx_drive_node(p_node_id uuid)
RETURNS boolean LANGUAGE sql SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.drive_nodes node
    WHERE node.id = p_node_id
      AND coalesce(node.metadata ->> 'sales_structured_docx', 'false') = 'true'
  ) OR EXISTS (
    SELECT 1 FROM public.sales_opportunity_structured_docx_materializations materialization
    WHERE materialization.drive_node_id = p_node_id
  )
$$;

CREATE OR REPLACE FUNCTION public.can_read_sales_structured_docx_drive_node(p_node_id uuid)
RETURNS boolean LANGUAGE sql SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.sales_opportunity_structured_docx_materializations materialization
    JOIN public.sales_opportunity_structured_docx_assignments assignment_row
      ON assignment_row.id = materialization.assignment_id AND assignment_row.status = 'ACTIVE'
    JOIN public.employees employee
      ON employee.id = assignment_row.responsible_employee_id
      AND employee.user_id = auth.uid()
      AND employee.employment_status = 'ACTIVE'
    JOIN public.employee_departments membership
      ON membership.employee_id = employee.id AND membership.department_id = assignment_row.department_id
    WHERE materialization.drive_node_id = p_node_id
  )
$$;

CREATE OR REPLACE FUNCTION public.can_read_sales_structured_docx_drive_revision(p_revision_id uuid)
RETURNS boolean LANGUAGE sql SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.sales_opportunity_structured_docx_materializations materialization
    WHERE materialization.drive_revision_id = p_revision_id
      AND public.can_read_sales_structured_docx_drive_node(materialization.drive_node_id)
  )
$$;

CREATE OR REPLACE FUNCTION public.can_read_sales_structured_docx_register(p_register_id uuid)
RETURNS boolean LANGUAGE sql SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.sales_opportunity_structured_docx_materializations materialization
    WHERE materialization.document_control_register_id = p_register_id
      AND public.can_read_sales_structured_docx_drive_node(materialization.drive_node_id)
  )
$$;

CREATE POLICY sales_structured_docx_read_restrictive ON storage.objects AS RESTRICTIVE FOR SELECT TO authenticated
USING (NOT public.is_sales_structured_docx_request_path(bucket_id, name) OR public.can_read_sales_structured_docx_object(bucket_id, name));
CREATE POLICY sales_structured_docx_insert_restrictive ON storage.objects AS RESTRICTIVE FOR INSERT TO authenticated
WITH CHECK (NOT public.is_sales_structured_docx_request_path(bucket_id, name) OR public.can_stage_sales_structured_docx_object(bucket_id, name));
CREATE POLICY sales_structured_docx_update_restrictive ON storage.objects AS RESTRICTIVE FOR UPDATE TO authenticated
USING (NOT public.is_sales_structured_docx_request_path(bucket_id, name))
WITH CHECK (NOT public.is_sales_structured_docx_request_path(bucket_id, name));
CREATE POLICY sales_structured_docx_delete_restrictive ON storage.objects AS RESTRICTIVE FOR DELETE TO authenticated
USING (NOT public.is_sales_structured_docx_request_path(bucket_id, name));

ALTER TABLE public.drive_nodes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.drive_node_revisions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.document_control_registers ENABLE ROW LEVEL SECURITY;

CREATE POLICY sales_structured_docx_drive_nodes_read_restrictive ON public.drive_nodes AS RESTRICTIVE FOR SELECT TO authenticated
USING (NOT public.is_sales_structured_docx_drive_node(id) OR public.can_read_sales_structured_docx_drive_node(id));
CREATE POLICY sales_structured_docx_drive_revisions_read_restrictive ON public.drive_node_revisions AS RESTRICTIVE FOR SELECT TO authenticated
USING (
  NOT EXISTS (
    SELECT 1 FROM public.drive_nodes node WHERE node.id = drive_node_revisions.node_id
      AND public.is_sales_structured_docx_drive_node(node.id)
  )
  OR public.can_read_sales_structured_docx_drive_revision(id)
);
CREATE POLICY sales_structured_docx_registers_read_restrictive ON public.document_control_registers AS RESTRICTIVE FOR SELECT TO authenticated
USING (
  NOT EXISTS (
    SELECT 1 FROM public.drive_nodes node WHERE node.id = document_control_registers.drive_node_id
      AND public.is_sales_structured_docx_drive_node(node.id)
  )
  OR public.can_read_sales_structured_docx_register(id)
);

REVOKE ALL ON FUNCTION public.is_sales_structured_docx_request_path(text,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.can_stage_sales_structured_docx_object(text,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.can_read_sales_structured_docx_object(text,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.is_sales_structured_docx_drive_node(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.can_read_sales_structured_docx_drive_node(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.can_read_sales_structured_docx_drive_revision(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.can_read_sales_structured_docx_register(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.assert_sales_structured_docx_uploaded_object(uuid,text,text,text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.assert_sales_structured_docx_current_path_create_only(uuid,text,text,text) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.is_sales_structured_docx_request_path(text,text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.can_stage_sales_structured_docx_object(text,text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.can_read_sales_structured_docx_object(text,text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.is_sales_structured_docx_drive_node(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.can_read_sales_structured_docx_drive_node(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.can_read_sales_structured_docx_drive_revision(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.can_read_sales_structured_docx_register(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.assert_sales_structured_docx_uploaded_object(uuid,text,text,text) TO service_role;