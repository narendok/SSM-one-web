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
REVOKE ALL ON FUNCTION public.reject_sales_opportunity_structured_draft_audit_mutation() FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.save_sales_opportunity_structured_draft_revision_at_private_location(
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
  SELECT * INTO v_revision FROM public.sales_opportunity_structured_draft_revisions
  WHERE id = v_saved.revision_id FOR UPDATE;
  SELECT * INTO v_existing_link FROM public.sales_opportunity_structured_draft_revision_locations
  WHERE revision_id = v_saved.revision_id FOR UPDATE;
  IF FOUND AND v_existing_link.private_location_id <> p_private_location_id THEN
    RAISE EXCEPTION 'Request key conflicts with a different private Sales location';
  END IF;
  IF NOT FOUND THEN
    INSERT INTO public.sales_opportunity_structured_draft_revision_locations (
      revision_id, private_location_id, payload_sha256_checksum, created_by
    ) VALUES (v_saved.revision_id, p_private_location_id, v_revision.payload_hash, v_actor_id);
  END IF;
  SELECT * INTO v_audit FROM public.sales_opportunity_structured_draft_audit_events
  WHERE request_key = p_request_key FOR UPDATE;
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
REVOKE ALL ON FUNCTION public.save_sales_opportunity_structured_draft_revision_at_private_location(uuid, uuid, uuid, uuid, text, integer, jsonb, uuid, uuid) FROM PUBLIC, anon, authenticated, service_role;

-- Deliberately absent: storage.objects writes, Storage API calls, upload URLs,
-- file bytes, document-control register rows, document numbers, approval,
-- release, download, or bucket/policy changes. The location configuration only
-- records a separately verified private destination for a future materializer.