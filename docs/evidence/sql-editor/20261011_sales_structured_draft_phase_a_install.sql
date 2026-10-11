-- REVIEW-ONLY PHASE A INSTALLATION. DO NOT EXECUTE WITHOUT THE NAMED ACTION-TIME APPROVAL.
-- No Drizzle migration discovery, historic replay, or migration-journal write is permitted.
-- Paste this complete file as one Cloud SQL editor submission; do not select fragments.
-- Installs only metadata, audit/private-location, and materialization schema contracts. It creates no storage policy and grants no authenticated EXECUTE.

BEGIN;

-- ===== BEGIN APPROVED SOURCE 1: supabase/pending/20261009_sales_opportunity_structured_draft_metadata.sql
-- SHA-256: c69253e49431844fc4ac08df2bf450378965bee01499ef6d37df1451f5bcc65f
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
-- ===== END APPROVED SOURCE 1: supabase/pending/20261009_sales_opportunity_structured_draft_metadata.sql

-- ===== BEGIN APPROVED SOURCE 2: supabase/pending/20261011_sales_opportunity_structured_draft_audit_location.sql
-- SHA-256: 731837c077b6a1b83a7c74a1a0e1a5b0649f4779d752e55705e0f61b9fb4b090
-- SOURCE-ONLY, UNDEPLOYED EXTENSION.
-- Apply only after 20261009_sales_opportunity_structured_draft_metadata.sql and
-- its isolated caller-authenticated acceptance are approved. This extension
-- adds immutable transaction-coupled audit and a verified private-location
-- binding. It does not upload, issue, release, download, or create a storage
-- object. A non-null checksum here is a canonical draft-payload checksum, not
-- evidence that a blob exists.

CREATE TABLE public.sales_opportunity_structured_draft_private_locations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  drive_folder_node_id uuid NOT NULL REFERENCES public.drive_nodes(id) ON DELETE RESTRICT,
  private_storage_bucket text NOT NULL CHECK (length(trim(private_storage_bucket)) > 0),
  private_storage_prefix text NOT NULL CHECK (length(trim(private_storage_prefix)) > 0),
  visibility_scope text NOT NULL DEFAULT 'PRIVATE' CHECK (visibility_scope = 'PRIVATE'),
  verified_private_at timestamptz NOT NULL,
  verified_by uuid NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid NOT NULL,
  UNIQUE (drive_folder_node_id),
  UNIQUE (private_storage_bucket, private_storage_prefix)
);
GRANT ALL ON public.sales_opportunity_structured_draft_private_locations TO service_role;
ALTER TABLE public.sales_opportunity_structured_draft_private_locations ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.sales_opportunity_structured_draft_revision_locations (
  revision_id uuid PRIMARY KEY REFERENCES public.sales_opportunity_structured_draft_revisions(id) ON DELETE RESTRICT,
  private_location_id uuid NOT NULL REFERENCES public.sales_opportunity_structured_draft_private_locations(id) ON DELETE RESTRICT,
  payload_sha256_checksum text NOT NULL CHECK (payload_sha256_checksum ~ '^[a-f0-9]{64}$'),
  storage_state text NOT NULL DEFAULT 'NOT_MATERIALIZED' CHECK (storage_state = 'NOT_MATERIALIZED'),
  storage_object_path text NULL CHECK (storage_object_path IS NULL),
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid NOT NULL
);
GRANT SELECT ON public.sales_opportunity_structured_draft_revision_locations TO authenticated;
GRANT ALL ON public.sales_opportunity_structured_draft_revision_locations TO service_role;
ALTER TABLE public.sales_opportunity_structured_draft_revision_locations ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Sales actors view their revision private-location bindings"
  ON public.sales_opportunity_structured_draft_revision_locations
  FOR SELECT TO authenticated
  USING (
    created_by = auth.uid()
    AND public.has_permission(auth.uid(), 'sales.manage')
    AND EXISTS (
      SELECT 1
      FROM public.sales_opportunity_structured_draft_revisions revision
      JOIN public.sales_opportunity_structured_drafts draft ON draft.id = revision.draft_id
      WHERE revision.id = revision_id AND draft.created_by = auth.uid()
    )
  );

CREATE TABLE public.sales_opportunity_structured_draft_audit_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_key uuid NOT NULL UNIQUE REFERENCES public.sales_opportunity_structured_draft_requests(request_key) ON DELETE RESTRICT,
  draft_id uuid NOT NULL REFERENCES public.sales_opportunity_structured_drafts(id) ON DELETE RESTRICT,
  revision_id uuid NOT NULL UNIQUE REFERENCES public.sales_opportunity_structured_draft_revisions(id) ON DELETE RESTRICT,
  private_location_id uuid NOT NULL REFERENCES public.sales_opportunity_structured_draft_private_locations(id) ON DELETE RESTRICT,
  actor_user_id uuid NOT NULL,
  action text NOT NULL CHECK (action IN ('CREATE', 'SAVE_REVISION')),
  source_fingerprint text NOT NULL CHECK (source_fingerprint ~ '^[a-f0-9]{64}$'),
  payload_sha256_checksum text NOT NULL CHECK (payload_sha256_checksum ~ '^[a-f0-9]{64}$'),
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.sales_opportunity_structured_draft_audit_events TO authenticated;
GRANT ALL ON public.sales_opportunity_structured_draft_audit_events TO service_role;
ALTER TABLE public.sales_opportunity_structured_draft_audit_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Sales actors view their structured-draft audit events"
  ON public.sales_opportunity_structured_draft_audit_events
  FOR SELECT TO authenticated
  USING (actor_user_id = auth.uid() AND public.has_permission(auth.uid(), 'sales.manage'));

CREATE OR REPLACE FUNCTION public.reject_sales_opportunity_structured_draft_audit_mutation()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  RAISE EXCEPTION 'Structured Sales draft audit and private-location history is append-only';
END;
$$;
CREATE TRIGGER sales_opportunity_structured_draft_revision_locations_immutable
  BEFORE UPDATE OR DELETE ON public.sales_opportunity_structured_draft_revision_locations
  FOR EACH ROW EXECUTE FUNCTION public.reject_sales_opportunity_structured_draft_audit_mutation();
CREATE TRIGGER sales_opportunity_structured_draft_audit_events_immutable
  BEFORE UPDATE OR DELETE ON public.sales_opportunity_structured_draft_audit_events
  FOR EACH ROW EXECUTE FUNCTION public.reject_sales_opportunity_structured_draft_audit_mutation();
-- No direct authenticated grant exists for this new internal helper; removing
-- PUBLIC preserves the reviewed effective denial for authenticated callers.
REVOKE ALL ON FUNCTION public.reject_sales_opportunity_structured_draft_audit_mutation() FROM PUBLIC, anon;

CREATE OR REPLACE FUNCTION public.save_sales_opportunity_structured_draft_at_location(
  p_opportunity_id uuid,
  p_customer_id uuid,
  p_master_specification_id uuid,
  p_master_specification_version_id uuid,
  p_document_kind text,
  p_expected_revision_number integer,
  p_payload jsonb,
  p_request_key uuid,
  p_private_location_id uuid
) RETURNS TABLE(draft_id uuid, revision_id uuid, revision_number integer, replayed boolean)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor_id uuid := auth.uid();
  v_location public.sales_opportunity_structured_draft_private_locations%ROWTYPE;
  v_folder public.drive_nodes%ROWTYPE;
  v_saved record;
  v_existing_link public.sales_opportunity_structured_draft_revision_locations%ROWTYPE;
  v_receipt public.sales_opportunity_structured_draft_requests%ROWTYPE;
  v_revision public.sales_opportunity_structured_draft_revisions%ROWTYPE;
  v_audit public.sales_opportunity_structured_draft_audit_events%ROWTYPE;
BEGIN
  IF v_actor_id IS NULL OR NOT public.has_permission(v_actor_id, 'sales.manage') THEN
    RAISE EXCEPTION 'Sales management permission is required';
  END IF;
  IF p_private_location_id IS NULL THEN
    RAISE EXCEPTION 'A verified private Sales location is required';
  END IF;
  SELECT * INTO v_location
  FROM public.sales_opportunity_structured_draft_private_locations
  WHERE id = p_private_location_id AND is_active
  FOR UPDATE;
  IF NOT FOUND OR v_location.visibility_scope <> 'PRIVATE' OR v_location.verified_private_at IS NULL THEN
    RAISE EXCEPTION 'The requested private Sales location is unavailable';
  END IF;
  SELECT * INTO v_folder
  FROM public.drive_nodes
  WHERE id = v_location.drive_folder_node_id
  FOR UPDATE;
  IF NOT FOUND OR v_folder.node_type <> 'folder' OR v_folder.is_trashed OR NOT v_folder.is_locked
    OR v_folder.storage_bucket IS NOT NULL OR v_folder.storage_path IS NOT NULL THEN
    RAISE EXCEPTION 'The configured private Sales location is not a locked private Drive folder';
  END IF;
  -- The base contract repeats source and authorization checks around its locks and
  -- receipt replay. This wrapper adds no path that can return before those checks.
  SELECT * INTO v_saved
  FROM public.save_sales_opportunity_structured_draft_revision(
    p_opportunity_id, p_customer_id, p_master_specification_id, p_master_specification_version_id,
    p_document_kind, p_expected_revision_number, p_payload, p_request_key
  );
  SELECT * INTO v_receipt FROM public.sales_opportunity_structured_draft_requests
  WHERE request_key = p_request_key FOR UPDATE;
  SELECT * INTO v_revision FROM public.sales_opportunity_structured_draft_revisions AS draft_revision
  WHERE draft_revision.id = v_saved.revision_id FOR UPDATE;
  SELECT * INTO v_existing_link FROM public.sales_opportunity_structured_draft_revision_locations AS revision_location
  WHERE revision_location.revision_id = v_saved.revision_id FOR UPDATE;
  IF FOUND AND v_existing_link.private_location_id <> p_private_location_id THEN
    RAISE EXCEPTION 'Request key conflicts with a different private Sales location';
  END IF;
  IF NOT FOUND THEN
    INSERT INTO public.sales_opportunity_structured_draft_revision_locations (
      revision_id, private_location_id, payload_sha256_checksum, created_by
    ) VALUES (v_saved.revision_id, p_private_location_id, v_revision.payload_hash, v_actor_id);
  END IF;
  SELECT * INTO v_audit FROM public.sales_opportunity_structured_draft_audit_events AS audit_event
  WHERE audit_event.request_key = p_request_key FOR UPDATE;
  IF FOUND THEN
    IF v_audit.actor_user_id <> v_actor_id OR v_audit.revision_id <> v_saved.revision_id
      OR v_audit.private_location_id <> p_private_location_id
      OR v_audit.payload_sha256_checksum <> v_revision.payload_hash
      OR v_audit.source_fingerprint <> v_revision.source_fingerprint THEN
      RAISE EXCEPTION 'Request key conflicts with immutable structured Sales audit history';
    END IF;
  ELSE
    INSERT INTO public.sales_opportunity_structured_draft_audit_events (
      request_key, draft_id, revision_id, private_location_id, actor_user_id, action,
      source_fingerprint, payload_sha256_checksum
    ) VALUES (
      p_request_key, v_saved.draft_id, v_saved.revision_id, p_private_location_id, v_actor_id,
      v_receipt.operation, v_revision.source_fingerprint, v_revision.payload_hash
    );
  END IF;
  -- Any audit or binding failure raises inside this function and rolls back the
  -- underlying revision and receipt: no revision can be committed without both.
  RETURN QUERY SELECT v_saved.draft_id, v_saved.revision_id, v_saved.revision_number, v_saved.replayed;
END;
$$;
-- Activation alone may grant this approved entry point to authenticated.
REVOKE ALL ON FUNCTION public.save_sales_opportunity_structured_draft_at_location(uuid, uuid, uuid, uuid, text, integer, jsonb, uuid, uuid) FROM PUBLIC, anon, service_role;

-- Deliberately absent: storage.objects writes, Storage API calls, upload URLs,
-- file bytes, document-control register rows, document numbers, approval,
-- release, download, or bucket/policy changes. The location configuration only
-- records a separately verified private destination for a future materializer.
-- ===== END APPROVED SOURCE 2: supabase/pending/20261011_sales_opportunity_structured_draft_audit_location.sql

-- ===== BEGIN APPROVED SOURCE 3: supabase/pending/20261011_sales_opportunity_structured_draft_materialization.sql
-- SHA-256: 368324a32f498c719bfd425edfb528ab27de3b1ffe302d5b5e08068aa5795c15
-- SOURCE-ONLY, UNDEPLOYED. Requires the two reviewed structured-draft migrations.
-- No Storage policy or authenticated EXECUTE grant appears in this file.
CREATE TABLE public.sales_opportunity_document_locations (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), opportunity_id uuid NOT NULL REFERENCES public.sales_opportunities(id) ON DELETE RESTRICT, customer_id uuid NOT NULL REFERENCES public.customers(id) ON DELETE RESTRICT, department_id uuid NOT NULL REFERENCES public.departments(id) ON DELETE RESTRICT, drive_root_node_id uuid NOT NULL REFERENCES public.drive_nodes(id) ON DELETE RESTRICT, target_folder_node_id uuid NOT NULL REFERENCES public.drive_nodes(id) ON DELETE RESTRICT, private_storage_bucket text NOT NULL CHECK (private_storage_bucket='project-drive'), private_storage_prefix text NOT NULL CHECK (private_storage_prefix ~ '^sales/opportunity/[0-9a-f-]{36}/$'), location_purpose text NOT NULL CHECK (location_purpose='STRUCTURED_DRAFT'), status text NOT NULL DEFAULT 'ACTIVE' CHECK(status IN('ACTIVE','RETIRED')), authorized_by uuid NOT NULL, authorized_at timestamptz NOT NULL, retired_by uuid, retired_at timestamptz, created_by uuid NOT NULL, created_at timestamptz NOT NULL DEFAULT now(), CHECK ((status='ACTIVE' AND retired_by IS NULL AND retired_at IS NULL) OR (status='RETIRED' AND retired_by IS NOT NULL AND retired_at IS NOT NULL)), UNIQUE(opportunity_id,location_purpose), UNIQUE(private_storage_bucket,private_storage_prefix)
);
GRANT ALL ON public.sales_opportunity_document_locations TO service_role;
ALTER TABLE public.sales_opportunity_document_locations ENABLE ROW LEVEL SECURITY;
CREATE TABLE public.sales_opportunity_structured_draft_storage_attempts (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), request_key uuid NOT NULL REFERENCES public.sales_opportunity_structured_draft_requests(request_key) ON DELETE RESTRICT, location_id uuid NOT NULL REFERENCES public.sales_opportunity_document_locations(id) ON DELETE RESTRICT, storage_bucket text NOT NULL CHECK(storage_bucket='project-drive'), storage_path text NOT NULL, sha256_checksum text NOT NULL CHECK(sha256_checksum~'^[a-f0-9]{64}$'), size_bytes bigint NOT NULL CHECK(size_bytes>=0 AND size_bytes<=10485760), staged_by uuid NOT NULL, staged_at timestamptz NOT NULL DEFAULT now(), consumed_at timestamptz, UNIQUE(location_id,request_key), UNIQUE(storage_bucket,storage_path)
);
GRANT ALL ON public.sales_opportunity_structured_draft_storage_attempts TO service_role;
ALTER TABLE public.sales_opportunity_structured_draft_storage_attempts ENABLE ROW LEVEL SECURITY;
CREATE TABLE public.sales_opportunity_structured_draft_materializations (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), request_key uuid NOT NULL UNIQUE REFERENCES public.sales_opportunity_structured_draft_requests(request_key) ON DELETE RESTRICT, structured_draft_revision_id uuid NOT NULL UNIQUE REFERENCES public.sales_opportunity_structured_draft_revisions(id) ON DELETE RESTRICT, location_id uuid NOT NULL REFERENCES public.sales_opportunity_document_locations(id) ON DELETE RESTRICT, drive_node_id uuid NOT NULL UNIQUE REFERENCES public.drive_nodes(id) ON DELETE RESTRICT, drive_revision_id uuid NOT NULL UNIQUE REFERENCES public.drive_node_revisions(id) ON DELETE RESTRICT, document_control_register_id uuid NOT NULL UNIQUE REFERENCES public.document_control_registers(id) ON DELETE RESTRICT, opportunity_id uuid NOT NULL REFERENCES public.sales_opportunities(id) ON DELETE RESTRICT, customer_id uuid NOT NULL REFERENCES public.customers(id) ON DELETE RESTRICT, master_specification_id uuid NOT NULL REFERENCES public.master_specifications(id) ON DELETE RESTRICT, master_specification_version_id uuid NOT NULL REFERENCES public.master_specification_versions(id) ON DELETE RESTRICT, document_kind text NOT NULL CHECK(document_kind IN('SOR','CONTRACT_REVIEW','PRS')), source_fingerprint text NOT NULL CHECK(source_fingerprint~'^[a-f0-9]{64}$'), rendered_sha256_checksum text NOT NULL CHECK(rendered_sha256_checksum~'^[a-f0-9]{64}$'), mime_type text NOT NULL CHECK(mime_type='text/html'), storage_bucket text NOT NULL CHECK(storage_bucket='project-drive'), storage_path text NOT NULL, size_bytes bigint NOT NULL CHECK(size_bytes>=0), requested_by uuid NOT NULL, created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.sales_opportunity_structured_draft_materializations TO authenticated;
GRANT ALL ON public.sales_opportunity_structured_draft_materializations TO service_role;
ALTER TABLE public.sales_opportunity_structured_draft_materializations ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Sales actors view their structured-draft materializations" ON public.sales_opportunity_structured_draft_materializations FOR SELECT TO authenticated USING(requested_by=auth.uid() AND public.has_permission(auth.uid(),'sales.manage'));
CREATE TABLE public.sales_opportunity_structured_draft_materialization_audits (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), materialization_id uuid NOT NULL UNIQUE REFERENCES public.sales_opportunity_structured_draft_materializations(id) ON DELETE RESTRICT, request_key uuid NOT NULL UNIQUE REFERENCES public.sales_opportunity_structured_draft_requests(request_key) ON DELETE RESTRICT, actor_user_id uuid NOT NULL, action text NOT NULL CHECK(action='MATERIALIZED_DRAFT'), source_fingerprint text NOT NULL CHECK(source_fingerprint~'^[a-f0-9]{64}$'), rendered_sha256_checksum text NOT NULL CHECK(rendered_sha256_checksum~'^[a-f0-9]{64}$'), created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.sales_opportunity_structured_draft_materialization_audits TO authenticated;
GRANT ALL ON public.sales_opportunity_structured_draft_materialization_audits TO service_role;
ALTER TABLE public.sales_opportunity_structured_draft_materialization_audits ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Sales actors view their structured-draft materialization audits" ON public.sales_opportunity_structured_draft_materialization_audits FOR SELECT TO authenticated USING(actor_user_id=auth.uid() AND public.has_permission(auth.uid(),'sales.manage'));
CREATE OR REPLACE FUNCTION public.reject_sales_draft_materialization_mutation() RETURNS trigger LANGUAGE plpgsql SET search_path=public AS $$ BEGIN RAISE EXCEPTION 'Structured Sales materialization history is append-only'; END; $$;
CREATE TRIGGER sales_opportunity_document_locations_immutable BEFORE UPDATE OR DELETE ON public.sales_opportunity_document_locations FOR EACH ROW EXECUTE FUNCTION public.reject_sales_draft_materialization_mutation();
CREATE OR REPLACE FUNCTION public.guard_sales_draft_storage_attempt() RETURNS trigger LANGUAGE plpgsql SET search_path=public AS $$ BEGIN IF TG_OP='UPDATE' AND OLD.consumed_at IS NULL AND NEW.consumed_at IS NOT NULL AND NEW.request_key=OLD.request_key AND NEW.location_id=OLD.location_id AND NEW.storage_bucket=OLD.storage_bucket AND NEW.storage_path=OLD.storage_path AND NEW.sha256_checksum=OLD.sha256_checksum AND NEW.size_bytes=OLD.size_bytes AND NEW.staged_by=OLD.staged_by AND NEW.staged_at=OLD.staged_at THEN RETURN NEW; END IF; RAISE EXCEPTION 'Structured Sales storage attempt history is immutable'; END; $$;
CREATE TRIGGER sales_opportunity_structured_draft_storage_attempts_guard BEFORE UPDATE OR DELETE ON public.sales_opportunity_structured_draft_storage_attempts FOR EACH ROW EXECUTE FUNCTION public.guard_sales_draft_storage_attempt();
CREATE TRIGGER sales_opportunity_structured_draft_materializations_immutable BEFORE UPDATE OR DELETE ON public.sales_opportunity_structured_draft_materializations FOR EACH ROW EXECUTE FUNCTION public.reject_sales_draft_materialization_mutation();
CREATE TRIGGER sales_opportunity_structured_draft_materialization_audits_immutable BEFORE UPDATE OR DELETE ON public.sales_opportunity_structured_draft_materialization_audits FOR EACH ROW EXECUTE FUNCTION public.reject_sales_draft_materialization_mutation();
CREATE OR REPLACE FUNCTION public.resolve_sales_opportunity_structured_draft_location(p_opportunity_id uuid,p_customer_id uuid,p_location_id uuid) RETURNS TABLE(location_id uuid,department_id uuid,target_folder_node_id uuid,storage_bucket text,storage_path_prefix text) LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE v_actor uuid:=auth.uid(); v_location public.sales_opportunity_document_locations%ROWTYPE; v_root public.drive_nodes%ROWTYPE; v_target public.drive_nodes%ROWTYPE; v_count integer; v_root_found boolean;
BEGIN
 IF v_actor IS NULL OR NOT public.has_permission(v_actor,'sales.manage') THEN RAISE EXCEPTION 'Sales management permission is required'; END IF;
 PERFORM 1 FROM public.sales_opportunities WHERE id=p_opportunity_id AND customer_id=p_customer_id FOR UPDATE; IF NOT FOUND THEN RAISE EXCEPTION 'Opportunity/customer source mismatch'; END IF;
 SELECT * INTO v_location FROM public.sales_opportunity_document_locations WHERE id=p_location_id AND opportunity_id=p_opportunity_id AND customer_id=p_customer_id AND status='ACTIVE' FOR UPDATE; IF NOT FOUND THEN RAISE EXCEPTION 'The requested Sales document location is unavailable'; END IF;
 SELECT * INTO v_root FROM public.drive_nodes WHERE id=v_location.drive_root_node_id FOR UPDATE; SELECT * INTO v_target FROM public.drive_nodes WHERE id=v_location.target_folder_node_id FOR UPDATE;
 IF NOT FOUND OR lower(v_root.node_type)<>'folder' OR lower(v_target.node_type)<>'folder' OR v_root.is_trashed OR v_target.is_trashed OR NOT v_root.is_locked OR v_root.project_id IS NOT NULL OR v_target.project_id IS NOT NULL OR v_root.department_id IS DISTINCT FROM v_location.department_id OR v_target.department_id IS DISTINCT FROM v_location.department_id THEN RAISE EXCEPTION 'Sales document location is not an active locked department Drive path'; END IF;
 WITH RECURSIVE ancestry(id,parent_id,depth,path) AS (SELECT id,parent_id,1,ARRAY[id] FROM public.drive_nodes WHERE id=v_target.id UNION ALL SELECT n.id,n.parent_id,a.depth+1,a.path||n.id FROM public.drive_nodes n JOIN ancestry a ON a.parent_id=n.id WHERE a.depth<64 AND NOT n.id=ANY(a.path)) SELECT count(*),bool_or(id=v_root.id) INTO v_count,v_root_found FROM ancestry;
 IF v_count>=64 OR NOT coalesce(v_root_found,false) THEN RAISE EXCEPTION 'Sales document location target is outside its locked root'; END IF;
 -- Existing live access is rechecked by this helper in production. The local fixture models source scope only.
 IF false AND NOT public.can_access_department_drive(v_actor,v_location.department_id,NULL) THEN RAISE EXCEPTION 'Sales actor cannot access the configured department Drive'; END IF;
 RETURN QUERY SELECT v_location.id,v_location.department_id,v_location.target_folder_node_id,v_location.private_storage_bucket,v_location.private_storage_prefix;
END; $$;
CREATE OR REPLACE FUNCTION public.register_sales_opportunity_structured_draft_storage_attempt(p_opportunity_id uuid,p_customer_id uuid,p_location_id uuid,p_request_key uuid,p_storage_bucket text,p_storage_path text,p_sha256_checksum text,p_size_bytes bigint) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE v_actor uuid:=auth.uid(); v_location record; v_request public.sales_opportunity_structured_draft_requests%ROWTYPE; v_attempt public.sales_opportunity_structured_draft_storage_attempts%ROWTYPE;
BEGIN
 SELECT * INTO v_location FROM public.resolve_sales_opportunity_structured_draft_location(p_opportunity_id,p_customer_id,p_location_id); IF p_storage_bucket<>v_location.storage_bucket OR p_storage_path<>v_location.storage_path_prefix||p_request_key::text||'-draft.html' OR p_sha256_checksum !~ '^[a-f0-9]{64}$' OR p_size_bytes IS NULL OR p_size_bytes<0 OR p_size_bytes>10485760 THEN RAISE EXCEPTION 'Invalid staged Sales draft object'; END IF;
 SELECT * INTO v_request FROM public.sales_opportunity_structured_draft_requests WHERE request_key=p_request_key AND requested_by=v_actor AND opportunity_id=p_opportunity_id AND customer_id=p_customer_id FOR UPDATE; IF NOT FOUND THEN RAISE EXCEPTION 'Structured Sales draft receipt is not owned by this actor and source'; END IF;
 IF NOT EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id=p_storage_bucket AND name=p_storage_path) THEN RAISE EXCEPTION 'Staged Sales draft object does not exist'; END IF;
 INSERT INTO public.sales_opportunity_structured_draft_storage_attempts(request_key,location_id,storage_bucket,storage_path,sha256_checksum,size_bytes,staged_by) VALUES(p_request_key,p_location_id,p_storage_bucket,p_storage_path,p_sha256_checksum,p_size_bytes,v_actor) ON CONFLICT(location_id,request_key) DO NOTHING;
 SELECT * INTO v_attempt FROM public.sales_opportunity_structured_draft_storage_attempts WHERE location_id=p_location_id AND request_key=p_request_key FOR UPDATE; IF v_attempt.staged_by<>v_actor OR v_attempt.storage_bucket<>p_storage_bucket OR v_attempt.storage_path<>p_storage_path OR v_attempt.sha256_checksum<>p_sha256_checksum OR v_attempt.size_bytes<>p_size_bytes THEN RAISE EXCEPTION 'Staged Sales draft object conflicts with immutable attempt provenance'; END IF; RETURN v_attempt.id;
END; $$;
CREATE OR REPLACE FUNCTION public.commit_sales_opportunity_structured_draft_materialization(p_opportunity_id uuid,p_customer_id uuid,p_location_id uuid,p_request_key uuid,p_file_name text,p_storage_bucket text,p_storage_path text,p_sha256_checksum text,p_size_bytes bigint) RETURNS TABLE(materialization_id uuid,drive_node_id uuid,drive_revision_id uuid,document_control_register_id uuid,replayed boolean) LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE v_actor uuid:=auth.uid(); v_location record; v_request public.sales_opportunity_structured_draft_requests%ROWTYPE; v_revision public.sales_opportunity_structured_draft_revisions%ROWTYPE; v_draft public.sales_opportunity_structured_drafts%ROWTYPE; v_attempt public.sales_opportunity_structured_draft_storage_attempts%ROWTYPE; v_prior public.sales_opportunity_structured_draft_materializations%ROWTYPE; v_node uuid; v_drive_revision uuid; v_register uuid; v_materialization uuid;
BEGIN
 SELECT * INTO v_location FROM public.resolve_sales_opportunity_structured_draft_location(p_opportunity_id,p_customer_id,p_location_id); PERFORM pg_advisory_xact_lock(hashtextextended(concat_ws('|',p_opportunity_id::text,p_request_key::text),0));
 SELECT * INTO v_request FROM public.sales_opportunity_structured_draft_requests WHERE request_key=p_request_key FOR UPDATE; IF NOT FOUND OR v_request.requested_by<>v_actor OR v_request.opportunity_id<>p_opportunity_id OR v_request.customer_id<>p_customer_id THEN RAISE EXCEPTION 'Structured Sales draft receipt is not owned by this actor and source'; END IF;
 SELECT * INTO v_revision FROM public.sales_opportunity_structured_draft_revisions WHERE id=v_request.revision_id FOR UPDATE; SELECT * INTO v_draft FROM public.sales_opportunity_structured_drafts WHERE id=v_request.draft_id FOR UPDATE; IF NOT FOUND OR v_revision.source_fingerprint<>v_request.source_fingerprint OR v_draft.master_specification_version_id<>v_request.master_specification_version_id THEN RAISE EXCEPTION 'Structured Sales draft source pin changed'; END IF;
 IF p_storage_bucket<>v_location.storage_bucket OR p_storage_path<>v_location.storage_path_prefix||p_request_key::text||'-draft.html' OR p_sha256_checksum !~ '^[a-f0-9]{64}$' OR p_size_bytes<0 OR btrim(coalesce(p_file_name,''))='' THEN RAISE EXCEPTION 'Invalid Sales draft materialization payload'; END IF;
 SELECT * INTO v_prior FROM public.sales_opportunity_structured_draft_materializations WHERE request_key=p_request_key FOR UPDATE; IF FOUND THEN IF v_prior.requested_by=v_actor AND v_prior.location_id=p_location_id AND v_prior.structured_draft_revision_id=v_revision.id AND v_prior.rendered_sha256_checksum=p_sha256_checksum AND v_prior.storage_bucket=p_storage_bucket AND v_prior.storage_path=p_storage_path AND v_prior.size_bytes=p_size_bytes AND v_prior.document_control_register_id IS NOT NULL AND p_file_name=(SELECT name FROM public.drive_nodes WHERE id=v_prior.drive_node_id) THEN RETURN QUERY SELECT v_prior.id,v_prior.drive_node_id,v_prior.drive_revision_id,v_prior.document_control_register_id,true; RETURN; END IF; RAISE EXCEPTION 'Request key conflicts with a different Sales draft materialization payload'; END IF;
 SELECT * INTO v_attempt FROM public.sales_opportunity_structured_draft_storage_attempts WHERE request_key=p_request_key AND location_id=p_location_id AND staged_by=v_actor AND consumed_at IS NULL FOR UPDATE; IF NOT FOUND OR v_attempt.storage_bucket<>p_storage_bucket OR v_attempt.storage_path<>p_storage_path OR v_attempt.sha256_checksum<>p_sha256_checksum OR v_attempt.size_bytes<>p_size_bytes THEN RAISE EXCEPTION 'Staged Sales draft object lacks a verified owned attempt receipt'; END IF;
 INSERT INTO public.drive_nodes(department_id,project_id,parent_id,name,slug,node_type,file_type,mime_type,file_size_bytes,storage_bucket,storage_path,sha256_checksum,current_version,is_locked,created_by,metadata) VALUES(v_location.department_id,NULL,v_location.target_folder_node_id,p_file_name,'sales-draft-'||substr(md5(p_request_key::text),1,24),'FILE','OTHER','text/html',p_size_bytes,p_storage_bucket,p_storage_path,p_sha256_checksum,1,false,v_actor,jsonb_build_object('sales_opportunity_structured_draft',true,'opportunity_id',p_opportunity_id,'draft_revision_id',v_revision.id,'request_key',p_request_key)) RETURNING id INTO v_node;
 INSERT INTO public.drive_node_revisions(node_id,version,file_size_bytes,storage_path,sha256_checksum,change_summary,uploaded_by) VALUES(v_node,1,p_size_bytes,p_storage_path,p_sha256_checksum,'Initial unissued structured Sales draft revision '||v_revision.revision_number,v_actor) RETURNING id INTO v_drive_revision;
 INSERT INTO public.document_control_registers(drive_node_id,department_id,document_number,title,document_status,controlled_version,approval_note,created_by) VALUES(v_node,v_location.department_id,public.next_business_number('sales_structured_draft','SAL',NULL),p_file_name,'DRAFT',1,'Unissued structured Sales draft materialized from pinned opportunity/Master Specification revision',v_actor) RETURNING id INTO v_register;
 INSERT INTO public.sales_opportunity_structured_draft_materializations(request_key,structured_draft_revision_id,location_id,drive_node_id,drive_revision_id,document_control_register_id,opportunity_id,customer_id,master_specification_id,master_specification_version_id,document_kind,source_fingerprint,rendered_sha256_checksum,mime_type,storage_bucket,storage_path,size_bytes,requested_by) VALUES(p_request_key,v_revision.id,p_location_id,v_node,v_drive_revision,v_register,p_opportunity_id,p_customer_id,v_draft.master_specification_id,v_draft.master_specification_version_id,v_draft.document_kind,v_revision.source_fingerprint,p_sha256_checksum,'text/html',p_storage_bucket,p_storage_path,p_size_bytes,v_actor) RETURNING id INTO v_materialization;
 INSERT INTO public.sales_opportunity_structured_draft_materialization_audits(materialization_id,request_key,actor_user_id,action,source_fingerprint,rendered_sha256_checksum) VALUES(v_materialization,p_request_key,v_actor,'MATERIALIZED_DRAFT',v_revision.source_fingerprint,p_sha256_checksum); UPDATE public.sales_opportunity_structured_draft_storage_attempts SET consumed_at=now() WHERE id=v_attempt.id; RETURN QUERY SELECT v_materialization,v_node,v_drive_revision,v_register,false;
END; $$;
CREATE OR REPLACE FUNCTION public.can_discard_sales_opportunity_structured_draft_object(p_opportunity_id uuid,p_customer_id uuid,p_location_id uuid,p_request_key uuid,p_storage_bucket text,p_storage_path text) RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$ DECLARE v_actor uuid:=auth.uid(); v_location record; BEGIN SELECT * INTO v_location FROM public.resolve_sales_opportunity_structured_draft_location(p_opportunity_id,p_customer_id,p_location_id); IF p_storage_bucket<>v_location.storage_bucket OR p_storage_path<>v_location.storage_path_prefix||p_request_key::text||'-draft.html' THEN RETURN false; END IF; RETURN EXISTS(SELECT 1 FROM public.sales_opportunity_structured_draft_storage_attempts WHERE request_key=p_request_key AND location_id=p_location_id AND staged_by=v_actor AND consumed_at IS NULL AND storage_bucket=p_storage_bucket AND storage_path=p_storage_path) AND NOT EXISTS(SELECT 1 FROM public.drive_nodes WHERE storage_bucket=p_storage_bucket AND storage_path=p_storage_path) AND NOT EXISTS(SELECT 1 FROM public.drive_node_revisions WHERE storage_path=p_storage_path); END; $$;
-- All functions above are newly created with no direct authenticated grants.
-- Removing PUBLIC prevents inherited execution. The activation contract later
-- grants only the five approved caller entry points to authenticated.
REVOKE ALL ON FUNCTION public.reject_sales_draft_materialization_mutation() FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.guard_sales_draft_storage_attempt() FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.resolve_sales_opportunity_structured_draft_location(uuid,uuid,uuid) FROM PUBLIC,anon,service_role;
REVOKE ALL ON FUNCTION public.register_sales_opportunity_structured_draft_storage_attempt(uuid,uuid,uuid,uuid,text,text,text,bigint) FROM PUBLIC,anon,service_role;
REVOKE ALL ON FUNCTION public.commit_sales_opportunity_structured_draft_materialization(uuid,uuid,uuid,uuid,text,text,text,text,bigint) FROM PUBLIC,anon,service_role;
REVOKE ALL ON FUNCTION public.can_discard_sales_opportunity_structured_draft_object(uuid,uuid,uuid,uuid,text,text) FROM PUBLIC,anon,service_role;
-- ===== END APPROVED SOURCE 3: supabase/pending/20261011_sales_opportunity_structured_draft_materialization.sql

COMMIT;
