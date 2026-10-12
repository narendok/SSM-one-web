-- SOURCE-ONLY, UNDEPLOYED REVIEW CONTRACT.
--
-- Trusted receipt authority for structured Sales DOCX. This is intentionally
-- additive. It has no authenticated caller grant and no deployment action.
-- The server-only issuer authenticates an actor first, then invokes these
-- service-only routines after it has read and verified private OOXML bytes.
-- Browser data cannot mint, alter, or consume a receipt.

CREATE TABLE public.sales_opportunity_structured_docx_trusted_receipts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_key uuid NOT NULL UNIQUE REFERENCES public.sales_opportunity_structured_docx_requests(request_key) ON DELETE RESTRICT,
  assignment_id uuid NOT NULL REFERENCES public.sales_opportunity_structured_docx_assignments(id) ON DELETE RESTRICT,
  actor_user_id uuid NOT NULL,
  location_id uuid NOT NULL REFERENCES public.sales_opportunity_document_locations(id) ON DELETE RESTRICT,
  storage_bucket text NOT NULL CHECK (storage_bucket = 'project-drive'),
  storage_path text NOT NULL,
  object_version text NOT NULL CHECK (btrim(object_version) <> ''),
  sha256_checksum text NOT NULL CHECK (sha256_checksum ~ '^[a-f0-9]{64}$'),
  size_bytes bigint NOT NULL CHECK (size_bytes > 0 AND size_bytes <= 10485760),
  source_fingerprint text NOT NULL CHECK (source_fingerprint ~ '^[a-f0-9]{64}$'),
  template_key text NOT NULL CHECK (btrim(template_key) <> ''),
  template_version integer NOT NULL CHECK (template_version > 0),
  template_schema_hash text NOT NULL CHECK (template_schema_hash ~ '^[a-f0-9]{64}$'),
  verifier_service text NOT NULL CHECK (btrim(verifier_service) <> ''),
  issued_at timestamptz NOT NULL DEFAULT now(),
  consumed_at timestamptz NULL,
  UNIQUE (storage_bucket, storage_path, object_version)
);
GRANT ALL ON public.sales_opportunity_structured_docx_trusted_receipts TO service_role;
ALTER TABLE public.sales_opportunity_structured_docx_trusted_receipts ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.guard_sales_structured_docx_trusted_receipt()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  IF TG_OP = 'DELETE'
    OR NEW.request_key IS DISTINCT FROM OLD.request_key
    OR NEW.assignment_id IS DISTINCT FROM OLD.assignment_id
    OR NEW.actor_user_id IS DISTINCT FROM OLD.actor_user_id
    OR NEW.location_id IS DISTINCT FROM OLD.location_id
    OR NEW.storage_bucket IS DISTINCT FROM OLD.storage_bucket
    OR NEW.storage_path IS DISTINCT FROM OLD.storage_path
    OR NEW.object_version IS DISTINCT FROM OLD.object_version
    OR NEW.sha256_checksum IS DISTINCT FROM OLD.sha256_checksum
    OR NEW.size_bytes IS DISTINCT FROM OLD.size_bytes
    OR NEW.source_fingerprint IS DISTINCT FROM OLD.source_fingerprint
    OR NEW.template_key IS DISTINCT FROM OLD.template_key
    OR NEW.template_version IS DISTINCT FROM OLD.template_version
    OR NEW.template_schema_hash IS DISTINCT FROM OLD.template_schema_hash
    OR NEW.verifier_service IS DISTINCT FROM OLD.verifier_service
    OR NEW.issued_at IS DISTINCT FROM OLD.issued_at
    OR (OLD.consumed_at IS NOT NULL AND NEW.consumed_at IS DISTINCT FROM OLD.consumed_at)
  THEN RAISE EXCEPTION 'Structured Sales DOCX trusted receipt is immutable after issuance'; END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER sales_structured_docx_trusted_receipts_guard
BEFORE UPDATE OR DELETE ON public.sales_opportunity_structured_docx_trusted_receipts
FOR EACH ROW EXECUTE FUNCTION public.guard_sales_structured_docx_trusted_receipt();

-- Service-only scope resolver. The issuer supplies the already authenticated
-- actor as p_actor_user_id; this routine verifies that it agrees with the
-- current request, active assignment, location, source and immutable template
-- pin. Lock order is advisory request -> request -> assignment/location ->
-- source/template and is shared by issue and commit paths.
CREATE OR REPLACE FUNCTION public.assert_sales_structured_docx_trusted_issue_scope(
  p_actor_user_id uuid, p_request_key uuid, p_assignment_id uuid,
  p_storage_bucket text, p_storage_path text, p_object_version text,
  p_sha256_checksum text, p_size_bytes bigint, p_source_fingerprint text,
  p_template_key text, p_template_version integer, p_template_schema_hash text
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_request public.sales_opportunity_structured_docx_requests%ROWTYPE; v_assignment public.sales_opportunity_structured_docx_assignments%ROWTYPE; v_location public.sales_opportunity_document_locations%ROWTYPE;
BEGIN
  IF p_actor_user_id IS NULL OR p_request_key IS NULL OR p_assignment_id IS NULL
    OR p_storage_bucket <> 'project-drive' OR btrim(coalesce(p_storage_path,'')) = ''
    OR btrim(coalesce(p_object_version,'')) = '' OR p_sha256_checksum !~ '^[a-f0-9]{64}$'
    OR p_size_bytes IS NULL OR p_size_bytes <= 0 OR p_size_bytes > 10485760
    OR p_source_fingerprint !~ '^[a-f0-9]{64}$' OR p_template_schema_hash !~ '^[a-f0-9]{64}$'
    OR btrim(coalesce(p_template_key,'')) = '' OR p_template_version <= 0
  THEN RAISE EXCEPTION 'Invalid trusted DOCX receipt facts'; END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended(concat_ws('|','sales-structured-docx',p_request_key::text),0));
  SELECT * INTO v_request FROM public.sales_opportunity_structured_docx_requests WHERE request_key=p_request_key FOR UPDATE;
  IF NOT FOUND OR v_request.requested_by <> p_actor_user_id OR v_request.assignment_id <> p_assignment_id
    OR v_request.source_fingerprint <> p_source_fingerprint OR v_request.template_key <> p_template_key
    OR v_request.template_version <> p_template_version OR v_request.template_schema_hash <> p_template_schema_hash
  THEN RAISE EXCEPTION 'Trusted DOCX receipt actor, request, source, or template pin changed'; END IF;
  SELECT * INTO v_assignment FROM public.sales_opportunity_structured_docx_assignments WHERE id=v_request.assignment_id FOR UPDATE;
  SELECT * INTO v_location FROM public.sales_opportunity_document_locations WHERE id=v_request.location_id FOR UPDATE;
  IF NOT FOUND OR v_assignment.status <> 'ACTIVE' OR v_location.status <> 'ACTIVE'
    OR v_location.private_storage_bucket <> p_storage_bucket
    OR p_storage_path <> v_location.private_storage_prefix || p_request_key::text || '-draft.docx'
    OR NOT EXISTS (SELECT 1 FROM public.employees e JOIN public.employee_departments ed ON ed.employee_id=e.id AND ed.department_id=v_assignment.department_id WHERE e.id=v_assignment.responsible_employee_id AND e.user_id=p_actor_user_id AND e.employment_status='ACTIVE')
  THEN RAISE EXCEPTION 'Trusted DOCX receipt no longer has an active assigned-person location scope'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.master_specifications s WHERE s.id=v_request.master_specification_id AND s.current_version_id=v_request.master_specification_version_id) THEN RAISE EXCEPTION 'Trusted DOCX receipt source is no longer current'; END IF;
  PERFORM set_config('structured_docx.trusted_actor', p_actor_user_id::text, true);
  PERFORM public.resolve_structured_lifecycle_docx_registry_scope(v_request.opportunity_id, v_request.document_kind, v_request.assignment_id, v_request.request_key, v_request.template_key, v_request.template_version, v_request.template_schema_hash, v_request.source_fingerprint);
  IF NOT EXISTS (SELECT 1 FROM storage.objects o WHERE o.bucket_id=p_storage_bucket AND o.name=p_storage_path AND o.version=p_object_version AND o.archived_at IS NULL AND coalesce(o.is_delete_marker,false)=false) THEN RAISE EXCEPTION 'Trusted DOCX receipt object version is absent or replaced'; END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.issue_sales_structured_docx_trusted_receipt(
  p_actor_user_id uuid, p_request_key uuid, p_assignment_id uuid,
  p_storage_bucket text, p_storage_path text, p_object_version text,
  p_sha256_checksum text, p_size_bytes bigint, p_source_fingerprint text,
  p_template_key text, p_template_version integer, p_template_schema_hash text,
  p_verifier_service text
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_existing public.sales_opportunity_structured_docx_trusted_receipts%ROWTYPE; v_receipt_id uuid;
BEGIN
  IF nullif(current_setting('request.jwt.claim.sub', true), '') IS NOT NULL OR btrim(coalesce(p_verifier_service,'')) = '' THEN
    RAISE EXCEPTION 'Only the trusted server DOCX verifier may issue a receipt';
  END IF;
  PERFORM public.assert_sales_structured_docx_trusted_issue_scope(p_actor_user_id,p_request_key,p_assignment_id,p_storage_bucket,p_storage_path,p_object_version,p_sha256_checksum,p_size_bytes,p_source_fingerprint,p_template_key,p_template_version,p_template_schema_hash);
  SELECT * INTO v_existing FROM public.sales_opportunity_structured_docx_trusted_receipts WHERE request_key=p_request_key FOR UPDATE;
  IF FOUND THEN
    IF v_existing.actor_user_id=p_actor_user_id AND v_existing.assignment_id=p_assignment_id AND v_existing.storage_bucket=p_storage_bucket AND v_existing.storage_path=p_storage_path AND v_existing.object_version=p_object_version AND v_existing.sha256_checksum=p_sha256_checksum AND v_existing.size_bytes=p_size_bytes AND v_existing.source_fingerprint=p_source_fingerprint AND v_existing.template_key=p_template_key AND v_existing.template_version=p_template_version AND v_existing.template_schema_hash=p_template_schema_hash THEN RETURN v_existing.id; END IF;
    RAISE EXCEPTION 'Trusted DOCX receipt conflicts with immutable request facts';
  END IF;
  INSERT INTO public.sales_opportunity_structured_docx_trusted_receipts(request_key,assignment_id,actor_user_id,location_id,storage_bucket,storage_path,object_version,sha256_checksum,size_bytes,source_fingerprint,template_key,template_version,template_schema_hash,verifier_service)
  SELECT r.request_key,r.assignment_id,p_actor_user_id,r.location_id,p_storage_bucket,p_storage_path,p_object_version,p_sha256_checksum,p_size_bytes,p_source_fingerprint,p_template_key,p_template_version,p_template_schema_hash,p_verifier_service FROM public.sales_opportunity_structured_docx_requests r WHERE r.request_key=p_request_key RETURNING id INTO v_receipt_id;
  RETURN v_receipt_id;
END;
$$;


-- Server-only scope resolver. It never returns authority to a browser role;
-- its only caller is the authenticated server bridge using service-role DB
-- transport after requireSupabaseAuth has established p_actor_user_id.
CREATE OR REPLACE FUNCTION public.resolve_sales_structured_docx_server_scope(
  p_actor_user_id uuid, p_project_id uuid, p_document_kind text, p_assignment_id uuid,
  p_request_key uuid, p_template_key text, p_template_version integer,
  p_template_schema_hash text, p_source_fingerprint text
) RETURNS TABLE(
  actor_id uuid, assignment_id uuid, request_key uuid, project_id uuid,
  document_kind text, department_id uuid, responsible_employee_id uuid,
  reviewer_employee_id uuid, template_id uuid, template_key text,
  template_version integer, template_document_revision_id uuid,
  template_schema_hash text, source_fingerprint text, storage_bucket text,
  storage_path text, object_version text
) LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_request public.sales_opportunity_structured_docx_requests%ROWTYPE; v_assignment public.sales_opportunity_structured_docx_assignments%ROWTYPE; v_location public.sales_opportunity_document_locations%ROWTYPE; v_attempt public.sales_opportunity_structured_docx_storage_attempts%ROWTYPE; v_registry record;
BEGIN
  IF nullif(current_setting('request.jwt.claim.sub', true), '') IS NOT NULL THEN RAISE EXCEPTION 'Only the authenticated server DOCX bridge may resolve a trusted scope'; END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended(concat_ws('|','sales-structured-docx',p_request_key::text),0));
  SELECT * INTO v_request FROM public.sales_opportunity_structured_docx_requests WHERE request_key=p_request_key FOR UPDATE;
  IF NOT FOUND OR v_request.requested_by<>p_actor_user_id OR v_request.assignment_id<>p_assignment_id OR v_request.opportunity_id<>p_project_id OR v_request.document_kind<>p_document_kind OR v_request.template_key<>p_template_key OR v_request.template_version<>p_template_version OR v_request.template_schema_hash<>p_template_schema_hash OR v_request.source_fingerprint<>p_source_fingerprint THEN RAISE EXCEPTION 'Trusted DOCX server scope does not match the authenticated request'; END IF;
  SELECT * INTO v_assignment FROM public.sales_opportunity_structured_docx_assignments WHERE id=v_request.assignment_id FOR UPDATE;
  SELECT * INTO v_location FROM public.sales_opportunity_document_locations WHERE id=v_request.location_id FOR UPDATE;
  SELECT * INTO v_attempt FROM public.sales_opportunity_structured_docx_storage_attempts WHERE request_key=p_request_key FOR SHARE;
  IF NOT FOUND OR v_assignment.status<>'ACTIVE' OR v_location.status<>'ACTIVE' OR v_location.private_storage_bucket<>v_attempt.storage_bucket OR v_attempt.storage_path<>v_location.private_storage_prefix||p_request_key::text||'-draft.docx' OR v_attempt.object_version IS NULL OR NOT EXISTS (SELECT 1 FROM public.employees e JOIN public.employee_departments ed ON ed.employee_id=e.id AND ed.department_id=v_assignment.department_id WHERE e.id=v_assignment.responsible_employee_id AND e.user_id=p_actor_user_id AND e.employment_status='ACTIVE') THEN RAISE EXCEPTION 'Trusted DOCX server scope has no active assigned-person request/object'; END IF;
  SELECT * INTO v_registry FROM public.resolve_structured_lifecycle_docx_registry_scope(p_project_id,p_document_kind,p_assignment_id,p_request_key,p_template_key,p_template_version,p_template_schema_hash,p_source_fingerprint);
  RETURN QUERY SELECT p_actor_user_id,v_assignment.id,v_request.request_key,p_project_id,v_request.document_kind,v_assignment.department_id,v_assignment.responsible_employee_id,NULL::uuid,v_registry.template_id,v_request.template_key,v_request.template_version,v_registry.template_document_revision_id,v_request.template_schema_hash,v_request.source_fingerprint,v_attempt.storage_bucket,v_attempt.storage_path,v_attempt.object_version;
END;
$$;

-- Commit is service-only at this layer: the authenticated server function
-- validates actor identity then calls this after it has rechecked the receipt.
CREATE OR REPLACE FUNCTION public.assert_sales_structured_docx_trusted_receipt_for_commit(
  p_actor_user_id uuid, p_receipt_id uuid, p_request_key uuid, p_assignment_id uuid,
  p_storage_bucket text, p_storage_path text, p_object_version text,
  p_sha256_checksum text, p_size_bytes bigint
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_receipt public.sales_opportunity_structured_docx_trusted_receipts%ROWTYPE;
BEGIN
  IF nullif(current_setting('request.jwt.claim.sub', true), '') IS NOT NULL THEN RAISE EXCEPTION 'Only the trusted server DOCX commit path may inspect a receipt'; END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended(concat_ws('|','sales-structured-docx',p_request_key::text),0));
  SELECT * INTO v_receipt FROM public.sales_opportunity_structured_docx_trusted_receipts WHERE id=p_receipt_id AND request_key=p_request_key FOR UPDATE;
  IF NOT FOUND OR v_receipt.consumed_at IS NOT NULL OR v_receipt.actor_user_id<>p_actor_user_id OR v_receipt.assignment_id<>p_assignment_id OR v_receipt.storage_bucket<>p_storage_bucket OR v_receipt.storage_path<>p_storage_path OR v_receipt.object_version<>p_object_version OR v_receipt.sha256_checksum<>p_sha256_checksum OR v_receipt.size_bytes<>p_size_bytes THEN RAISE EXCEPTION 'Trusted DOCX receipt is absent, consumed, or conflicts with commit facts'; END IF;
  PERFORM public.assert_sales_structured_docx_trusted_issue_scope(v_receipt.actor_user_id,p_request_key,p_assignment_id,p_storage_bucket,p_storage_path,p_object_version,p_sha256_checksum,p_size_bytes,v_receipt.source_fingerprint,v_receipt.template_key,v_receipt.template_version,v_receipt.template_schema_hash);
END;
$$;

CREATE OR REPLACE FUNCTION public.consume_sales_structured_docx_trusted_receipt(p_receipt_id uuid, p_request_key uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  UPDATE public.sales_opportunity_structured_docx_trusted_receipts SET consumed_at=now() WHERE id=p_receipt_id AND request_key=p_request_key AND consumed_at IS NULL;
  IF NOT FOUND THEN RAISE EXCEPTION 'Trusted DOCX receipt was already consumed or unavailable'; END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.resolve_sales_structured_docx_server_scope(uuid,uuid,text,uuid,uuid,text,integer,text,text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.guard_sales_structured_docx_trusted_receipt() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.assert_sales_structured_docx_trusted_issue_scope(uuid,uuid,uuid,text,text,text,text,bigint,text,text,integer,text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.issue_sales_structured_docx_trusted_receipt(uuid,uuid,uuid,text,text,text,text,bigint,text,text,integer,text,text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.assert_sales_structured_docx_trusted_receipt_for_commit(uuid,uuid,uuid,uuid,text,text,text,text,bigint) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.consume_sales_structured_docx_trusted_receipt(uuid,uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.resolve_sales_structured_docx_server_scope(uuid,uuid,text,uuid,uuid,text,integer,text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.assert_sales_structured_docx_trusted_issue_scope(uuid,uuid,uuid,text,text,text,text,bigint,text,text,integer,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.issue_sales_structured_docx_trusted_receipt(uuid,uuid,uuid,text,text,text,text,bigint,text,text,integer,text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.assert_sales_structured_docx_trusted_receipt_for_commit(uuid,uuid,uuid,uuid,text,text,text,text,bigint) TO service_role;
GRANT EXECUTE ON FUNCTION public.consume_sales_structured_docx_trusted_receipt(uuid,uuid) TO service_role;
