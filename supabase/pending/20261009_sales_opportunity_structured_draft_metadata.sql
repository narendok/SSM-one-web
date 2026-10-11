-- SOURCE-ONLY, UNDEPLOYED PROPOSAL.
-- This file is deliberately under supabase/pending and must not be applied until
-- reviewed isolated caller-authenticated acceptance proves authorization, RLS,
-- replay, optimistic conflict, rollback, and concurrency behavior.
--
-- Scope: opportunity-only SOR, Contract Review, and PRS draft metadata and
-- append-only revisions. This is NOT a Drive/register/storage/materialization
-- contract. It creates no controlled document, storage object, file, document
-- number, or controlled-document materialization record. Any established
-- transactional audit requirement remains governed by its authoritative contract;
-- this proposal neither removes nor bypasses it. Controlled issuance and
-- materialization remain unavailable until a separately governed Sales document
-- location linkage exists.
--
-- Existing authoritative source tuple, locked by the protected functions below:
-- public.sales_opportunities(id, customer_id)
--   -> public.master_specifications(id, opportunity_id, customer_id)
--   -> public.master_specification_versions(id, specification_id, version_number,
--      specification_data, created_at).
-- Existing authorization helper: public.has_permission(auth.uid(), 'sales.manage').
-- No project, department, Drive, folder, register, owner, or template object is
-- inferred from this proposal or from nullable fields.

CREATE TABLE public.sales_opportunity_structured_drafts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  opportunity_id uuid NOT NULL REFERENCES public.sales_opportunities(id) ON DELETE RESTRICT,
  customer_id uuid NOT NULL REFERENCES public.customers(id) ON DELETE RESTRICT,
  master_specification_id uuid NOT NULL REFERENCES public.master_specifications(id) ON DELETE RESTRICT,
  master_specification_version_id uuid NOT NULL REFERENCES public.master_specification_versions(id) ON DELETE RESTRICT,
  master_specification_version_number integer NOT NULL CHECK (master_specification_version_number > 0),
  document_kind text NOT NULL CHECK (document_kind IN ('SOR', 'CONTRACT_REVIEW', 'PRS')),
  editable_schema_key text NOT NULL CHECK (editable_schema_key IN ('sales-local-scalar-v1')),
  editable_schema_hash text NOT NULL CHECK (editable_schema_hash ~ '^[a-f0-9]{64}$'),
  source_fingerprint text NOT NULL CHECK (source_fingerprint ~ '^[a-f0-9]{64}$'),
  created_by uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (opportunity_id, master_specification_version_id, document_kind, editable_schema_key, editable_schema_hash)
);
GRANT SELECT ON public.sales_opportunity_structured_drafts TO authenticated;
GRANT ALL ON public.sales_opportunity_structured_drafts TO service_role;
ALTER TABLE public.sales_opportunity_structured_drafts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Sales actors view their opportunity structured drafts"
  ON public.sales_opportunity_structured_drafts
  FOR SELECT TO authenticated
  USING (created_by = auth.uid() AND public.has_permission(auth.uid(), 'sales.manage'));

CREATE TABLE public.sales_opportunity_structured_draft_revisions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  draft_id uuid NOT NULL REFERENCES public.sales_opportunity_structured_drafts(id) ON DELETE RESTRICT,
  revision_number integer NOT NULL CHECK (revision_number > 0),
  parent_revision_id uuid REFERENCES public.sales_opportunity_structured_draft_revisions(id) ON DELETE RESTRICT,
  canonical_payload jsonb NOT NULL CHECK (jsonb_typeof(canonical_payload) = 'object'),
  payload_hash text NOT NULL CHECK (payload_hash ~ '^[a-f0-9]{64}$'),
  source_fingerprint text NOT NULL CHECK (source_fingerprint ~ '^[a-f0-9]{64}$'),
  created_by uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (draft_id, revision_number)
);
GRANT SELECT ON public.sales_opportunity_structured_draft_revisions TO authenticated;
GRANT ALL ON public.sales_opportunity_structured_draft_revisions TO service_role;
ALTER TABLE public.sales_opportunity_structured_draft_revisions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Sales actors view their structured draft revision history"
  ON public.sales_opportunity_structured_draft_revisions
  FOR SELECT TO authenticated
  USING (
    created_by = auth.uid()
    AND public.has_permission(auth.uid(), 'sales.manage')
    AND EXISTS (
      SELECT 1 FROM public.sales_opportunity_structured_drafts draft
      WHERE draft.id = draft_id AND draft.created_by = auth.uid()
    )
  );

CREATE TABLE public.sales_opportunity_structured_draft_requests (
  request_key uuid PRIMARY KEY,
  requested_by uuid NOT NULL,
  opportunity_id uuid NOT NULL REFERENCES public.sales_opportunities(id) ON DELETE RESTRICT,
  customer_id uuid NOT NULL REFERENCES public.customers(id) ON DELETE RESTRICT,
  master_specification_id uuid NOT NULL REFERENCES public.master_specifications(id) ON DELETE RESTRICT,
  master_specification_version_id uuid NOT NULL REFERENCES public.master_specification_versions(id) ON DELETE RESTRICT,
  master_specification_version_number integer NOT NULL CHECK (master_specification_version_number > 0),
  document_kind text NOT NULL CHECK (document_kind IN ('SOR', 'CONTRACT_REVIEW', 'PRS')),
  editable_schema_key text NOT NULL CHECK (editable_schema_key IN ('sales-local-scalar-v1')),
  editable_schema_hash text NOT NULL CHECK (editable_schema_hash ~ '^[a-f0-9]{64}$'),
  draft_id uuid NOT NULL REFERENCES public.sales_opportunity_structured_drafts(id) ON DELETE RESTRICT,
  revision_id uuid NOT NULL REFERENCES public.sales_opportunity_structured_draft_revisions(id) ON DELETE RESTRICT,
  operation text NOT NULL CHECK (operation IN ('CREATE', 'SAVE_REVISION')),
  expected_revision_number integer NOT NULL CHECK (expected_revision_number >= 0),
  payload_hash text NOT NULL CHECK (payload_hash ~ '^[a-f0-9]{64}$'),
  source_fingerprint text NOT NULL CHECK (source_fingerprint ~ '^[a-f0-9]{64}$'),
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.sales_opportunity_structured_draft_requests TO authenticated;
GRANT ALL ON public.sales_opportunity_structured_draft_requests TO service_role;
ALTER TABLE public.sales_opportunity_structured_draft_requests ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Sales actors view their structured draft request receipts"
  ON public.sales_opportunity_structured_draft_requests
  FOR SELECT TO authenticated
  USING (requested_by = auth.uid() AND public.has_permission(auth.uid(), 'sales.manage'));

CREATE OR REPLACE FUNCTION public.reject_sales_opportunity_structured_draft_history_mutation()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  RAISE EXCEPTION 'Structured Sales draft history is append-only';
END;
$$;
CREATE TRIGGER sales_opportunity_structured_drafts_immutable
  BEFORE UPDATE OR DELETE ON public.sales_opportunity_structured_drafts
  FOR EACH ROW EXECUTE FUNCTION public.reject_sales_opportunity_structured_draft_history_mutation();
CREATE TRIGGER sales_opportunity_structured_draft_revisions_immutable
  BEFORE UPDATE OR DELETE ON public.sales_opportunity_structured_draft_revisions
  FOR EACH ROW EXECUTE FUNCTION public.reject_sales_opportunity_structured_draft_history_mutation();
CREATE TRIGGER sales_opportunity_structured_draft_requests_immutable
  BEFORE UPDATE OR DELETE ON public.sales_opportunity_structured_draft_requests
  FOR EACH ROW EXECUTE FUNCTION public.reject_sales_opportunity_structured_draft_history_mutation();
-- New functions inherit PUBLIC EXECUTE unless it is removed. `authenticated`
-- has no direct grant here, so removing PUBLIC preserves its effective denial.
REVOKE ALL ON FUNCTION public.reject_sales_opportunity_structured_draft_history_mutation() FROM PUBLIC, anon;

CREATE OR REPLACE FUNCTION public.sales_opportunity_structured_draft_schema_hash(
  p_document_kind text
) RETURNS text
LANGUAGE sql
IMMUTABLE
SET search_path = public
AS $$
  SELECT encode(digest(
    CASE p_document_kind
      WHEN 'SOR' THEN 'sales-local-scalar-v1|SOR|OEM_REQUIREMENT_ROWS,SCOPE_STATEMENT,ACCEPTANCE_CRITERIA,CAN_TELEMETRY_NOTES,PILOT_ROLLOUT_NOTES,COMMERCIAL_SLA_WARRANTY_DELIVERY'
      WHEN 'CONTRACT_REVIEW' THEN 'sales-local-scalar-v1|CONTRACT_REVIEW|HARDWARE_FEASIBILITY,FIRMWARE_FEASIBILITY,MECHANICAL_FEASIBILITY,COMMERCIAL_EVIDENCE,OWNER_AND_ACTION,LOCAL_DECISION_NOTE'
      WHEN 'PRS' THEN 'sales-local-scalar-v1|PRS|POWER_REQUIREMENT,INTERFACE_REQUIREMENT,CONNECTIVITY_REQUIREMENT,MECHANICAL_REQUIREMENT,FIRMWARE_REQUIREMENT,VERIFICATION_METHOD'
      ELSE NULL
    END,
    'sha256'
  ), 'hex')
$$;

CREATE OR REPLACE FUNCTION public.sales_opportunity_structured_draft_canonical_payload(
  p_document_kind text,
  p_payload jsonb
) RETURNS jsonb
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public
AS $$
DECLARE
  v_allowed text[];
  v_key text;
  v_value jsonb;
  v_canonical jsonb := '{}'::jsonb;
  v_total_length integer := 0;
BEGIN
  IF p_payload IS NULL OR jsonb_typeof(p_payload) IS DISTINCT FROM 'object' THEN
    RAISE EXCEPTION 'Structured Sales payload must be an object';
  END IF;
  CASE p_document_kind
    WHEN 'SOR' THEN
      v_allowed := ARRAY['OEM_REQUIREMENT_ROWS','SCOPE_STATEMENT','ACCEPTANCE_CRITERIA','CAN_TELEMETRY_NOTES','PILOT_ROLLOUT_NOTES','COMMERCIAL_SLA_WARRANTY_DELIVERY'];
    WHEN 'CONTRACT_REVIEW' THEN
      v_allowed := ARRAY['HARDWARE_FEASIBILITY','FIRMWARE_FEASIBILITY','MECHANICAL_FEASIBILITY','COMMERCIAL_EVIDENCE','OWNER_AND_ACTION','LOCAL_DECISION_NOTE'];
    WHEN 'PRS' THEN
      v_allowed := ARRAY['POWER_REQUIREMENT','INTERFACE_REQUIREMENT','CONNECTIVITY_REQUIREMENT','MECHANICAL_REQUIREMENT','FIRMWARE_REQUIREMENT','VERIFICATION_METHOD'];
    ELSE
      RAISE EXCEPTION 'Unsupported structured Sales document kind';
  END CASE;
  IF EXISTS (SELECT 1 FROM jsonb_object_keys(p_payload) key WHERE NOT key = ANY(v_allowed)) THEN
    RAISE EXCEPTION 'Structured Sales payload contains an unknown or derived field';
  END IF;
  FOREACH v_key IN ARRAY v_allowed LOOP
    IF p_payload ? v_key THEN
      v_value := p_payload -> v_key;
      IF jsonb_typeof(v_value) <> 'string' THEN
        RAISE EXCEPTION 'Structured Sales editable field % must be a string', v_key;
      END IF;
      IF char_length(v_value #>> '{}') > (
        CASE
          WHEN p_document_kind = 'PRS' AND v_key = 'VERIFICATION_METHOD' THEN 1000
          ELSE 8000
        END
      ) THEN
        RAISE EXCEPTION 'Structured Sales editable field % exceeds its proposed local character limit', v_key;
      END IF;
      v_total_length := v_total_length + char_length(v_value #>> '{}');
      v_canonical := v_canonical || jsonb_build_object(v_key, v_value #>> '{}');
    END IF;
  END LOOP;
  IF v_total_length > 48000 THEN
    RAISE EXCEPTION 'Structured Sales payload exceeds 48000 total characters';
  END IF;
  RETURN v_canonical;
END;
$$;

CREATE OR REPLACE FUNCTION public.sales_opportunity_structured_draft_source_fingerprint(
  p_opportunity_id uuid,
  p_customer_id uuid,
  p_master_specification_id uuid,
  p_master_specification_version_id uuid,
  p_master_specification_version_number integer,
  p_document_kind text,
  p_editable_schema_hash text,
  p_specification_data jsonb,
  p_source_created_at timestamptz
) RETURNS text
LANGUAGE sql
IMMUTABLE
SET search_path = public
AS $$
  SELECT encode(digest(jsonb_build_object(
    'opportunity_id', p_opportunity_id,
    'customer_id', p_customer_id,
    'master_specification_id', p_master_specification_id,
    'master_specification_version_id', p_master_specification_version_id,
    'master_specification_version_number', p_master_specification_version_number,
    'document_kind', p_document_kind,
    'editable_schema_key', 'sales-local-scalar-v1',
    'editable_schema_hash', p_editable_schema_hash,
    'specification_data', p_specification_data,
    'source_created_at', p_source_created_at
  )::text, 'sha256'), 'hex')
$$;

CREATE OR REPLACE FUNCTION public.save_sales_opportunity_structured_draft_revision(
  p_opportunity_id uuid,
  p_customer_id uuid,
  p_master_specification_id uuid,
  p_master_specification_version_id uuid,
  p_document_kind text,
  p_expected_revision_number integer,
  p_payload jsonb,
  p_request_key uuid
) RETURNS TABLE(draft_id uuid, revision_id uuid, revision_number integer, replayed boolean)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor_id uuid := auth.uid();
  v_opportunity public.sales_opportunities%ROWTYPE;
  v_specification public.master_specifications%ROWTYPE;
  v_version public.master_specification_versions%ROWTYPE;
  v_draft public.sales_opportunity_structured_drafts%ROWTYPE;
  v_request public.sales_opportunity_structured_draft_requests%ROWTYPE;
  v_revision public.sales_opportunity_structured_draft_revisions%ROWTYPE;
  v_payload jsonb;
  v_payload_hash text;
  v_schema_hash text;
  v_source_fingerprint text;
  v_operation text;
  v_next_revision_number integer;
BEGIN
  IF v_actor_id IS NULL OR NOT public.has_permission(v_actor_id, 'sales.manage') THEN
    RAISE EXCEPTION 'Sales management permission is required';
  END IF;
  IF p_opportunity_id IS NULL OR p_customer_id IS NULL OR p_master_specification_id IS NULL
    OR p_master_specification_version_id IS NULL OR p_request_key IS NULL
    OR p_expected_revision_number IS NULL OR p_expected_revision_number < 0 THEN
    RAISE EXCEPTION 'Immutable sources, expected revision, and request key are required';
  END IF;
  v_schema_hash := public.sales_opportunity_structured_draft_schema_hash(p_document_kind);
  IF v_schema_hash IS NULL THEN
    RAISE EXCEPTION 'Unsupported structured Sales document kind';
  END IF;
  v_payload := public.sales_opportunity_structured_draft_canonical_payload(p_document_kind, p_payload);
  v_payload_hash := encode(digest(v_payload::text, 'sha256'), 'hex');

  PERFORM pg_advisory_xact_lock(hashtextextended(
    concat_ws('|', p_opportunity_id::text, p_master_specification_version_id::text, p_document_kind, v_schema_hash), 0
  ));
  -- Lock order: logical draft identity -> opportunity -> specification -> source version -> request receipt.
  -- Source and authorization are verified before any replay receipt may be returned.
  SELECT * INTO v_opportunity
  FROM public.sales_opportunities
  WHERE id = p_opportunity_id AND customer_id = p_customer_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Opportunity/customer source mismatch';
  END IF;
  SELECT * INTO v_specification
  FROM public.master_specifications
  WHERE id = p_master_specification_id
    AND opportunity_id = p_opportunity_id
    AND customer_id = p_customer_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Master Specification source mismatch';
  END IF;
  -- The authoritative migration
  -- 20261005183103_2157aab7-4509-46b0-bc31-4d5f6e7785d0.sql installs
  -- master_specification_versions_no_update_delete, whose trigger function
  -- rejects all UPDATE/DELETE operations as append-only. FOR UPDATE therefore
  -- serializes this source read with any attempted writer while the immutable
  -- version row stabilizes specification_data for the fingerprint below.
  SELECT * INTO v_version
  FROM public.master_specification_versions
  WHERE id = p_master_specification_version_id
    AND specification_id = v_specification.id
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Master Specification version source mismatch';
  END IF;
  v_source_fingerprint := public.sales_opportunity_structured_draft_source_fingerprint(
    p_opportunity_id, p_customer_id, v_specification.id, v_version.id, v_version.version_number,
    p_document_kind, v_schema_hash, v_version.specification_data, v_version.created_at
  );

  -- Re-check authorization after waiting on the logical/source locks and before
  -- a receipt can be observed. A permission revoked while this call waited must
  -- deny both a new write and an otherwise exact replay.
  IF NOT public.has_permission(v_actor_id, 'sales.manage') THEN
    RAISE EXCEPTION 'Sales management permission is required';
  END IF;

  SELECT * INTO v_request
  FROM public.sales_opportunity_structured_draft_requests AS request_receipt
  WHERE request_receipt.request_key = p_request_key
  FOR UPDATE;
  IF FOUND THEN
    IF v_request.requested_by = v_actor_id
      AND v_request.opportunity_id = p_opportunity_id
      AND v_request.customer_id = p_customer_id
      AND v_request.master_specification_id = v_specification.id
      AND v_request.master_specification_version_id = v_version.id
      AND v_request.master_specification_version_number = v_version.version_number
      AND v_request.document_kind = p_document_kind
      AND v_request.editable_schema_key = 'sales-local-scalar-v1'
      AND v_request.editable_schema_hash = v_schema_hash
      AND v_request.expected_revision_number = p_expected_revision_number
      AND v_request.payload_hash = v_payload_hash
      AND v_request.source_fingerprint = v_source_fingerprint THEN
      RETURN QUERY SELECT v_request.draft_id, v_request.revision_id,
        (SELECT stored_revision.revision_number
         FROM public.sales_opportunity_structured_draft_revisions AS stored_revision
         WHERE stored_revision.id = v_request.revision_id), true;
      RETURN;
    END IF;
    RAISE EXCEPTION 'Request key conflicts with a different immutable source, schema, caller, revision, or payload';
  END IF;

  SELECT * INTO v_draft
  FROM public.sales_opportunity_structured_drafts
  WHERE opportunity_id = p_opportunity_id
    AND master_specification_version_id = p_master_specification_version_id
    AND document_kind = p_document_kind
    AND editable_schema_key = 'sales-local-scalar-v1'
    AND editable_schema_hash = v_schema_hash
  FOR UPDATE;

  IF NOT FOUND THEN
    IF p_expected_revision_number <> 0 THEN
      RAISE EXCEPTION 'Initial structured Sales draft must expect revision 0';
    END IF;
    INSERT INTO public.sales_opportunity_structured_drafts (
      opportunity_id, customer_id, master_specification_id, master_specification_version_id,
      master_specification_version_number, document_kind, editable_schema_key,
      editable_schema_hash, source_fingerprint, created_by
    ) VALUES (
      p_opportunity_id, p_customer_id, v_specification.id, v_version.id,
      v_version.version_number, p_document_kind, 'sales-local-scalar-v1',
      v_schema_hash, v_source_fingerprint, v_actor_id
    ) RETURNING * INTO v_draft;
    v_operation := 'CREATE';
    v_next_revision_number := 1;
  ELSE
    IF v_draft.created_by <> v_actor_id
      OR v_draft.customer_id <> p_customer_id
      OR v_draft.master_specification_id <> v_specification.id
      OR v_draft.master_specification_version_number <> v_version.version_number
      OR v_draft.source_fingerprint <> v_source_fingerprint THEN
      RAISE EXCEPTION 'Structured Sales draft source or actor mismatch';
    END IF;
    SELECT * INTO v_revision
    FROM public.sales_opportunity_structured_draft_revisions AS draft_revision
    WHERE draft_revision.draft_id = v_draft.id
    ORDER BY draft_revision.revision_number DESC
    LIMIT 1
    FOR UPDATE;
    IF NOT FOUND OR v_revision.revision_number <> p_expected_revision_number THEN
      RAISE EXCEPTION 'Structured Sales draft revision conflict';
    END IF;
    IF v_revision.payload_hash = v_payload_hash THEN
      RAISE EXCEPTION 'Use the original request key to replay an unchanged structured Sales draft revision';
    END IF;
    v_operation := 'SAVE_REVISION';
    v_next_revision_number := v_revision.revision_number + 1;
  END IF;

  INSERT INTO public.sales_opportunity_structured_draft_revisions (
    draft_id, revision_number, parent_revision_id, canonical_payload, payload_hash,
    source_fingerprint, created_by
  ) VALUES (
    v_draft.id, v_next_revision_number,
    CASE WHEN v_next_revision_number = 1 THEN NULL ELSE v_revision.id END,
    v_payload, v_payload_hash, v_source_fingerprint, v_actor_id
  ) RETURNING * INTO v_revision;
  INSERT INTO public.sales_opportunity_structured_draft_requests (
    request_key, requested_by, opportunity_id, customer_id, master_specification_id,
    master_specification_version_id, master_specification_version_number, document_kind,
    editable_schema_key, editable_schema_hash, draft_id, revision_id, operation,
    expected_revision_number, payload_hash, source_fingerprint
  ) VALUES (
    p_request_key, v_actor_id, p_opportunity_id, p_customer_id, v_specification.id,
    v_version.id, v_version.version_number, p_document_kind,
    'sales-local-scalar-v1', v_schema_hash, v_draft.id, v_revision.id, v_operation,
    p_expected_revision_number, v_payload_hash, v_source_fingerprint
  );
  RETURN QUERY SELECT v_draft.id, v_revision.id, v_revision.revision_number, false;
END;
$$;
-- These functions are created above and carry no direct authenticated grants.
-- Revoking PUBLIC (and anon explicitly) leaves authenticated denied until the
-- separate activation contract grants one of the approved entry points.
REVOKE ALL ON FUNCTION public.sales_opportunity_structured_draft_schema_hash(text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.sales_opportunity_structured_draft_canonical_payload(text, jsonb) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.sales_opportunity_structured_draft_source_fingerprint(uuid, uuid, uuid, uuid, integer, text, text, jsonb, timestamptz) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.save_sales_opportunity_structured_draft_revision(uuid, uuid, uuid, uuid, text, integer, jsonb, uuid) FROM PUBLIC, anon, service_role;

-- Deliberately absent: Drive, storage, controlled-register, document-number, or
-- controlled-document materialization. This metadata-only proposal must not be used to issue,
-- materialize, download, release, or classify a controlled Sales document.
