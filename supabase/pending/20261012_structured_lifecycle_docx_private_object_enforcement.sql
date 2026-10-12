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
    AND p_path ~ '^sales/opportunity/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}-draft\\.docx$'
$$;

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

-- Used by the server-only current-path reader before and after a byte read.
-- It binds request, active assigned person, reserved path, and exact version.
CREATE OR REPLACE FUNCTION public.assert_sales_structured_docx_current_path_create_only(
  p_request_key uuid, p_bucket text, p_path text, p_object_version text
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_attempt public.sales_opportunity_structured_docx_storage_attempts%ROWTYPE;
BEGIN
  IF p_request_key IS NULL OR p_object_version IS NULL OR btrim(p_object_version) = '' OR NOT public.can_stage_sales_structured_docx_object(p_bucket, p_path) THEN
    RAISE EXCEPTION 'Current actor no longer owns an active create-only DOCX request path';
  END IF;
  SELECT * INTO v_attempt FROM public.sales_opportunity_structured_docx_storage_attempts
  WHERE request_key = p_request_key AND storage_bucket = p_bucket AND storage_path = p_path AND object_version = p_object_version AND consumed_at IS NULL FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Trusted DOCX storage receipt is absent, consumed, or changed'; END IF;
  IF NOT EXISTS (SELECT 1 FROM storage.objects object_row WHERE object_row.bucket_id = p_bucket AND object_row.name = p_path AND object_row.version = p_object_version AND object_row.archived_at IS NULL AND coalesce(object_row.is_delete_marker,false) = false) THEN
    RAISE EXCEPTION 'Current DOCX object version is absent or replaced';
  END IF;
END;
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

REVOKE ALL ON FUNCTION public.is_sales_structured_docx_request_path(text,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.can_stage_sales_structured_docx_object(text,text) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.can_read_sales_structured_docx_object(text,text) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.assert_sales_structured_docx_current_path_create_only(uuid,text,text,text) FROM PUBLIC, anon, authenticated, service_role;