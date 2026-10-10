-- SOURCE-ONLY, UNDEPLOYED PROPOSAL. DO NOT APPLY.
--
-- This additive contract addresses only an atomic Sales intake: one existing
-- customer, optional existing contact/enquiry, one opportunity, its first
-- Master Specification header/version, one activity entry, and one private
-- actor-bound receipt. It does not create projects, requirements, baselines,
-- documents, notifications, users, roles, or direct-write grants.
--
-- Verified existing contracts reused here:
-- * public.has_permission(uuid, text) with sales.manage;
-- * public.sales_opportunities, whose established BEFORE INSERT trigger assigns
--   opportunity_number with public.next_business_number('opportunity', NULL, NULL)
--   only when the server supplies NULL/blank;
-- * public.master_specifications/master_specification_versions and their
--   append-only version trigger; and
-- * public.activity_log's existing Sales audit shape.
--
-- Current deployed source access is deliberately global rather than ownership
-- scoped: the "Sales teams view customers/customer contacts/enquiries" SELECT
-- policies in `supabase/migrations/20260923173813_447b78e0-6a60-4d69-875a-6b5c7d32691f.sql`
-- allow a caller with sales.manage to read every RLS-visible source row. The
-- corresponding "Authenticated users manage customers/customer contacts/enquiries"
-- policies use sales.manage or admin for writes. This proposal preserves that
-- verified authority; it does not invent per-customer ownership.
--
-- The authoritative allocator is public.next_business_number: deployed source
-- shows `FOR UPDATE` on the active document_numbering_config row and an UPDATE
-- returning the next sequence. The sales_opportunities_assign_business_code
-- trigger calls it when opportunity_number is NULL/blank. See
-- `supabase/migrations/20260923173813_447b78e0-6a60-4d69-875a-6b5c7d32691f.sql`
-- for the Sales policies and the currently deployed definitions queried from
-- public.next_business_number / public.assign_stabilization_codes. This is
-- source proof only; isolated concurrent transaction acceptance remains required.
--
-- The server validates and locks every supplied existing source. It neither
-- creates sources nor infers a source identity from browser text.
-- Existing deployed direct-write paths are intentionally untouched by this file.

CREATE TABLE public.sales_opportunity_intake_receipts (
  request_key uuid PRIMARY KEY,
  requested_by uuid NOT NULL,
  customer_id uuid NOT NULL REFERENCES public.customers(id) ON DELETE RESTRICT,
  contact_id uuid NULL REFERENCES public.customer_contacts(id) ON DELETE RESTRICT,
  enquiry_id uuid NULL REFERENCES public.sales_enquiries(id) ON DELETE RESTRICT,
  canonical_payload jsonb NOT NULL CHECK (jsonb_typeof(canonical_payload) = 'object'),
  payload_hash text NOT NULL CHECK (payload_hash ~ '^[a-f0-9]{64}$'),
  opportunity_id uuid NOT NULL UNIQUE REFERENCES public.sales_opportunities(id) ON DELETE RESTRICT,
  master_specification_id uuid NOT NULL UNIQUE REFERENCES public.master_specifications(id) ON DELETE RESTRICT,
  master_specification_version_id uuid NOT NULL UNIQUE REFERENCES public.master_specification_versions(id) ON DELETE RESTRICT,
  activity_log_id uuid NOT NULL UNIQUE REFERENCES public.activity_log(id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT now()
);
-- Default privileges are not trusted: all roles lose direct access first.
REVOKE ALL ON TABLE public.sales_opportunity_intake_receipts FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT ON TABLE public.sales_opportunity_intake_receipts TO service_role;
ALTER TABLE public.sales_opportunity_intake_receipts ENABLE ROW LEVEL SECURITY;
CREATE POLICY sales_opportunity_intake_receipts_owner_read
  ON public.sales_opportunity_intake_receipts
  FOR SELECT TO authenticated
  USING (requested_by = auth.uid() AND public.has_permission(auth.uid(), 'sales.manage'));

CREATE OR REPLACE FUNCTION public.sales_opportunity_intake_canonical_payload(
  p_customer_id uuid,
  p_contact_id uuid,
  p_enquiry_id uuid,
  p_intake jsonb
) RETURNS jsonb
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public
AS $$
DECLARE
  v_allowed text[] := ARRAY[
    'application', 'estimatedVolume', 'masterSpecification', 'name',
    'ndaRequired', 'nextAction', 'nextActionDate', 'primarySalesOwnerUserId',
    'priority', 'productType', 'targetTimeline'
  ];
  v_spec_allowed text[] := ARRAY[
    'changeSummary', 'customerOrInternalOwner', 'developmentScope',
    'connectivityAndGnss', 'environmentAndIp', 'exclusions', 'industryApplication', 'interfaces',
    'powerAndUnits', 'productFamily', 'proposedName', 'requestedStandards',
    'requirementSummary', 'schedule', 'volumes', 'workstreams'
  ];
  v_key text;
  v_workstream jsonb;
  v_spec jsonb;
BEGIN
  IF p_customer_id IS NULL OR p_intake IS NULL OR jsonb_typeof(p_intake) <> 'object' THEN
    RETURN NULL;
  END IF;
  IF EXISTS (SELECT 1 FROM jsonb_object_keys(p_intake) AS key WHERE key <> ALL(v_allowed))
     OR (SELECT array_agg(key ORDER BY key) FROM jsonb_object_keys(p_intake) AS key)
        IS DISTINCT FROM (SELECT array_agg(key ORDER BY key) FROM unnest(v_allowed) AS allowed(key)) THEN
    RETURN NULL;
  END IF;
  -- A JSON null is represented by SQL NULL in jsonb_typeof, so use explicit
  -- null-aware comparisons rather than NOT IN (which propagates SQL NULL).
  IF jsonb_typeof(p_intake->'name') <> 'string'
     OR jsonb_typeof(p_intake->'application') IS DISTINCT FROM 'null' AND jsonb_typeof(p_intake->'application') IS DISTINCT FROM 'string'
     OR jsonb_typeof(p_intake->'productType') IS DISTINCT FROM 'null' AND jsonb_typeof(p_intake->'productType') IS DISTINCT FROM 'string'
     OR jsonb_typeof(p_intake->'primarySalesOwnerUserId') IS DISTINCT FROM 'null' AND jsonb_typeof(p_intake->'primarySalesOwnerUserId') IS DISTINCT FROM 'string'
     OR jsonb_typeof(p_intake->'ndaRequired') <> 'boolean'
     OR jsonb_typeof(p_intake->'estimatedVolume') IS DISTINCT FROM 'null' AND jsonb_typeof(p_intake->'estimatedVolume') IS DISTINCT FROM 'string'
     OR jsonb_typeof(p_intake->'targetTimeline') IS DISTINCT FROM 'null' AND jsonb_typeof(p_intake->'targetTimeline') IS DISTINCT FROM 'string'
     OR jsonb_typeof(p_intake->'nextAction') IS DISTINCT FROM 'null' AND jsonb_typeof(p_intake->'nextAction') IS DISTINCT FROM 'string'
     OR jsonb_typeof(p_intake->'nextActionDate') IS DISTINCT FROM 'null' AND jsonb_typeof(p_intake->'nextActionDate') IS DISTINCT FROM 'string'
     OR jsonb_typeof(p_intake->'priority') <> 'string'
     OR jsonb_typeof(p_intake->'masterSpecification') <> 'object' THEN
    RETURN NULL;
  END IF;
  IF p_intake->>'priority' NOT IN ('low', 'medium', 'high', 'urgent')
     OR NULLIF(btrim(p_intake->>'name'), '') IS NULL
     OR char_length(p_intake->>'name') NOT BETWEEN 3 AND 240
     OR (jsonb_typeof(p_intake->'primarySalesOwnerUserId') = 'string'
         AND (p_intake->>'primarySalesOwnerUserId') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')
     OR (jsonb_typeof(p_intake->'nextActionDate') = 'string'
         AND (p_intake->>'nextActionDate') !~ '^\\d{4}-\\d{2}-\\d{2}$') THEN
    RETURN NULL;
  END IF;
  FOREACH v_key IN ARRAY ARRAY['application', 'productType', 'estimatedVolume', 'targetTimeline', 'nextAction'] LOOP
    IF jsonb_typeof(p_intake->v_key) = 'string' AND (
      (v_key = 'nextAction' AND char_length(p_intake->>v_key) > 1000)
      OR (v_key <> 'nextAction' AND char_length(p_intake->>v_key) > 240)
    ) THEN
      RETURN NULL;
    END IF;
  END LOOP;
  v_spec := p_intake->'masterSpecification';
  IF jsonb_typeof(v_spec) <> 'object' THEN
    RETURN NULL;
  END IF;
  IF EXISTS (SELECT 1 FROM jsonb_object_keys(v_spec) AS key WHERE key <> ALL(v_spec_allowed))
     OR (SELECT array_agg(key ORDER BY key) FROM jsonb_object_keys(v_spec) AS key)
        IS DISTINCT FROM (SELECT array_agg(key ORDER BY key) FROM unnest(v_spec_allowed) AS allowed(key))
     OR EXISTS (
       SELECT 1 FROM unnest(ARRAY[
         'changeSummary', 'customerOrInternalOwner', 'developmentScope',
         'environmentAndIp', 'exclusions', 'industryApplication', 'interfaces',
         'powerAndUnits', 'productFamily', 'proposedName', 'requestedStandards',
         'requirementSummary', 'schedule', 'volumes', 'connectivityAndGnss'
       ]) AS required(key)
       WHERE jsonb_typeof(v_spec->required.key) <> 'string'
     )
     OR jsonb_typeof(v_spec->'workstreams') <> 'array'
     OR jsonb_array_length(v_spec->'workstreams') NOT BETWEEN 1 AND 5 THEN
    RETURN NULL;
  END IF;
  -- Required specification fields are all strings; the surrounding predicate
  -- above validates shape before these value bounds are evaluated.
  IF NULLIF(btrim(v_spec->>'changeSummary'), '') IS NULL
     OR char_length(v_spec->>'changeSummary') NOT BETWEEN 3 AND 1000
     OR NULLIF(btrim(v_spec->>'proposedName'), '') IS NULL
     OR char_length(v_spec->>'proposedName') > 240
     OR NULLIF(btrim(v_spec->>'customerOrInternalOwner'), '') IS NULL
     OR char_length(v_spec->>'customerOrInternalOwner') > 240
     OR NULLIF(btrim(v_spec->>'industryApplication'), '') IS NULL
     OR char_length(v_spec->>'industryApplication') > 240
     OR NULLIF(btrim(v_spec->>'productFamily'), '') IS NULL
     OR char_length(v_spec->>'productFamily') > 240
     OR NULLIF(btrim(v_spec->>'developmentScope'), '') IS NULL
     OR char_length(v_spec->>'developmentScope') > 2000
     OR NULLIF(btrim(v_spec->>'requirementSummary'), '') IS NULL
     OR char_length(v_spec->>'requirementSummary') > 8000
     OR EXISTS (
       SELECT 1 FROM unnest(ARRAY['powerAndUnits', 'interfaces', 'connectivityAndGnss', 'environmentAndIp', 'volumes', 'schedule']) AS bounded(key)
       WHERE NULLIF(btrim(v_spec->>bounded.key), '') IS NULL OR char_length(v_spec->>bounded.key) > 1000
     )
     OR EXISTS (
       SELECT 1 FROM unnest(ARRAY['requestedStandards', 'exclusions']) AS bounded(key)
       WHERE NULLIF(btrim(v_spec->>bounded.key), '') IS NULL OR char_length(v_spec->>bounded.key) > 2000
     ) THEN
    RETURN NULL;
  END IF;
  FOR v_workstream IN SELECT value FROM jsonb_array_elements(v_spec->'workstreams') AS workstream(value) LOOP
    IF jsonb_typeof(v_workstream) <> 'string'
       OR v_workstream #>> '{}' NOT IN ('HARDWARE', 'FIRMWARE', 'MECHANICAL', 'TEST', 'MANUFACTURING') THEN
      RETURN NULL;
    END IF;
  END LOOP;
  IF (SELECT count(DISTINCT value #>> '{}') FROM jsonb_array_elements(v_spec->'workstreams') AS workstream(value))
       <> jsonb_array_length(v_spec->'workstreams') THEN
    RETURN NULL;
  END IF;
  RETURN jsonb_build_object(
    'customerId', p_customer_id, 'contactId', p_contact_id, 'enquiryId', p_enquiry_id,
    'name', p_intake->'name', 'application', p_intake->'application',
    'productType', p_intake->'productType', 'primarySalesOwnerUserId', p_intake->'primarySalesOwnerUserId',
    'ndaRequired', p_intake->'ndaRequired', 'estimatedVolume', p_intake->'estimatedVolume',
    'targetTimeline', p_intake->'targetTimeline', 'priority', p_intake->'priority',
    'nextAction', p_intake->'nextAction', 'nextActionDate', p_intake->'nextActionDate',
    'masterSpecification', jsonb_build_object(
      'changeSummary', v_spec->'changeSummary', 'proposedName', v_spec->'proposedName',
      'customerOrInternalOwner', v_spec->'customerOrInternalOwner',
      'industryApplication', v_spec->'industryApplication', 'productFamily', v_spec->'productFamily',
      'developmentScope', v_spec->'developmentScope', 'workstreams', v_spec->'workstreams',
      'requirementSummary', v_spec->'requirementSummary', 'powerAndUnits', v_spec->'powerAndUnits',
      'interfaces', v_spec->'interfaces', 'connectivityAndGnss', v_spec->'connectivityAndGnss',
      'environmentAndIp', v_spec->'environmentAndIp', 'volumes', v_spec->'volumes',
      'schedule', v_spec->'schedule', 'requestedStandards', v_spec->'requestedStandards',
      'exclusions', v_spec->'exclusions'
    )
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.create_sales_opportunity_with_initial_master_specification(
  p_customer_id uuid,
  p_contact_id uuid,
  p_enquiry_id uuid,
  p_intake jsonb,
  p_request_key uuid
) RETURNS TABLE(
  opportunity_id uuid,
  opportunity_number text,
  master_specification_id uuid,
  master_specification_number text,
  master_specification_version_id uuid,
  master_specification_version_number integer,
  replayed boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor_id uuid := auth.uid();
  v_canonical jsonb;
  v_payload_hash text;
  v_customer public.customers%ROWTYPE;
  v_contact public.customer_contacts%ROWTYPE;
  v_enquiry public.sales_enquiries%ROWTYPE;
  v_prior public.sales_opportunity_intake_receipts%ROWTYPE;
  v_opportunity public.sales_opportunities%ROWTYPE;
  v_specification public.master_specifications%ROWTYPE;
  v_version public.master_specification_versions%ROWTYPE;
  v_activity public.activity_log%ROWTYPE;
  v_spec_data jsonb;
BEGIN
  IF v_actor_id IS NULL OR NOT public.has_permission(v_actor_id, 'sales.manage') THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'Sales management permission is required';
  END IF;
  IF p_customer_id IS NULL OR p_request_key IS NULL THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Existing customer and request key are required';
  END IF;
  v_canonical := public.sales_opportunity_intake_canonical_payload(p_customer_id, p_contact_id, p_enquiry_id, p_intake);
  IF v_canonical IS NULL THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Sales intake payload is incomplete or invalid';
  END IF;
  v_payload_hash := encode(digest(v_canonical::text, 'sha256'), 'hex');

  -- Stable lock order: request key advisory lock, customer, contact, enquiry,
  -- receipt. Source authorization precedes receipt lookup and is rechecked after
  -- all waits/locks before a replay result or write can leave this transaction.
  PERFORM pg_advisory_xact_lock(hashtextextended(p_request_key::text, 0));
  SELECT * INTO v_customer FROM public.customers WHERE id = p_customer_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Customer source is unavailable'; END IF;
  IF p_contact_id IS NOT NULL THEN
    SELECT * INTO v_contact FROM public.customer_contacts
    WHERE id = p_contact_id AND customer_id = p_customer_id AND is_active
    FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Contact/customer source mismatch'; END IF;
  END IF;
  IF p_enquiry_id IS NOT NULL THEN
    SELECT * INTO v_enquiry FROM public.sales_enquiries
    WHERE id = p_enquiry_id
      AND customer_id = p_customer_id
      AND (p_contact_id IS NULL OR contact_id IS NULL OR contact_id = p_contact_id)
    FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Enquiry/customer/contact source mismatch'; END IF;
  END IF;
  IF NOT public.has_permission(v_actor_id, 'sales.manage') THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'Sales management permission is required';
  END IF;
  SELECT * INTO v_prior FROM public.sales_opportunity_intake_receipts WHERE request_key = p_request_key FOR UPDATE;
  IF FOUND THEN
    IF v_prior.requested_by = v_actor_id
       AND v_prior.customer_id = p_customer_id
       AND v_prior.contact_id IS NOT DISTINCT FROM p_contact_id
       AND v_prior.enquiry_id IS NOT DISTINCT FROM p_enquiry_id
       AND v_prior.payload_hash = v_payload_hash
       AND v_prior.canonical_payload = v_canonical THEN
      RETURN QUERY
      SELECT opportunity.id, opportunity.opportunity_number, specification.id, specification.specification_number,
        version.id, version.version_number, true
      FROM public.sales_opportunities opportunity
      JOIN public.master_specifications specification ON specification.id = v_prior.master_specification_id
      JOIN public.master_specification_versions version ON version.id = v_prior.master_specification_version_id
      WHERE opportunity.id = v_prior.opportunity_id;
      RETURN;
    END IF;
    RAISE EXCEPTION USING ERRCODE = '23505', MESSAGE = 'Request key conflicts with a different actor, source, or canonical payload';
  END IF;
  -- Recheck after the receipt lock so permission revocation while waiting never
  -- returns a replay and never reaches a write.
  IF NOT public.has_permission(v_actor_id, 'sales.manage') THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'Sales management permission is required';
  END IF;

  INSERT INTO public.sales_opportunities (
    opportunity_number, customer_id, primary_contact_id, enquiry_id, name,
    application, product_type, primary_sales_owner_user_id, nda_required,
    estimated_volume, target_timeline, priority, next_action, next_action_date, created_by
  ) VALUES (
    NULL, p_customer_id, p_contact_id, p_enquiry_id, v_canonical->>'name',
    v_canonical->>'application', v_canonical->>'productType',
    NULLIF(v_canonical->>'primarySalesOwnerUserId', '')::uuid,
    (v_canonical->>'ndaRequired')::boolean, v_canonical->>'estimatedVolume',
    v_canonical->>'targetTimeline', v_canonical->>'priority', v_canonical->>'nextAction',
    NULLIF(v_canonical->>'nextActionDate', '')::date, v_actor_id
  ) RETURNING * INTO v_opportunity;

  v_spec_data := (v_canonical->'masterSpecification') - 'changeSummary'::text;
  INSERT INTO public.master_specifications (
    specification_number, opportunity_id, customer_id, title, status, current_version, created_by
  ) VALUES (
    public.next_business_number('master_specification', 'MS', NULL),
    v_opportunity.id, p_customer_id, (v_spec_data->>'proposedName') || ' — Master Specification',
    'draft', 1, v_actor_id
  ) RETURNING * INTO v_specification;
  INSERT INTO public.master_specification_versions (
    specification_id, version_number, change_summary, specification_data, status, created_by
  ) VALUES (
    v_specification.id, 1, v_spec_data->>'changeSummary', v_spec_data - 'changeSummary'::text, 'working', v_actor_id
  ) RETURNING * INTO v_version;
  INSERT INTO public.activity_log (
    actor_user_id, module_key, entity_type, entity_id, action, summary, after_data
  ) VALUES (
    v_actor_id, 'sales', 'sales_opportunity', v_opportunity.id, 'created_with_initial_master_specification',
    'Created opportunity with initial Master Specification: ' || v_opportunity.name,
    jsonb_build_object('opportunity_number', v_opportunity.opportunity_number,
      'master_specification_id', v_specification.id,
      'master_specification_number', v_specification.specification_number,
      'master_specification_version_id', v_version.id,
      'master_specification_version_number', v_version.version_number)
  ) RETURNING * INTO v_activity;
  INSERT INTO public.sales_opportunity_intake_receipts (
    request_key, requested_by, customer_id, contact_id, enquiry_id, canonical_payload,
    payload_hash, opportunity_id, master_specification_id, master_specification_version_id, activity_log_id
  ) VALUES (
    p_request_key, v_actor_id, p_customer_id, p_contact_id, p_enquiry_id, v_canonical,
    v_payload_hash, v_opportunity.id, v_specification.id, v_version.id, v_activity.id
  );
  RETURN QUERY SELECT v_opportunity.id, v_opportunity.opportunity_number, v_specification.id,
    v_specification.specification_number, v_version.id, v_version.version_number, false;
END;
$$;

CREATE OR REPLACE FUNCTION public.lookup_sales_opportunity_intake_receipt(
  p_request_key uuid
) RETURNS TABLE(
  opportunity_id uuid,
  opportunity_number text,
  master_specification_id uuid,
  master_specification_number text,
  master_specification_version_id uuid,
  master_specification_version_number integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor_id uuid := auth.uid();
  v_receipt public.sales_opportunity_intake_receipts%ROWTYPE;
BEGIN
  IF v_actor_id IS NULL OR NOT public.has_permission(v_actor_id, 'sales.manage') THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'Sales management permission is required';
  END IF;
  IF p_request_key IS NULL THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Request key is required';
  END IF;
  SELECT * INTO v_receipt FROM public.sales_opportunity_intake_receipts
  WHERE request_key = p_request_key AND requested_by = v_actor_id;
  IF NOT FOUND THEN RETURN; END IF;
  IF NOT public.has_permission(v_actor_id, 'sales.manage') THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'Sales management permission is required';
  END IF;
  RETURN QUERY
  SELECT opportunity.id, opportunity.opportunity_number, specification.id, specification.specification_number,
    version.id, version.version_number
  FROM public.sales_opportunities opportunity
  JOIN public.master_specifications specification ON specification.id = v_receipt.master_specification_id
  JOIN public.master_specification_versions version ON version.id = v_receipt.master_specification_version_id
  WHERE opportunity.id = v_receipt.opportunity_id;
END;
$$;

-- Helpers remain private; the two protected actions are not granted until real
-- isolated caller-authenticated acceptance is approved. This proposal does not
-- alter existing RPC grants or existing table RLS/grants.
REVOKE ALL ON FUNCTION public.sales_opportunity_intake_canonical_payload(uuid, uuid, uuid, jsonb) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.create_sales_opportunity_with_initial_master_specification(uuid, uuid, uuid, jsonb, uuid) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.lookup_sales_opportunity_intake_receipt(uuid) FROM PUBLIC, anon, authenticated, service_role;

-- DEPLOYMENT GATE: do not apply until a disposable isolated database proves
-- actual authenticated caller transport, no direct mutations, same-key races,
-- permission revocation while waiting, source mismatch denial, receipt isolation,
-- full rollback at every write point, RLS, and non-administrator least privilege.
-- An active non-admin Sales manager must prove valid use of existing RLS-visible
-- customer/contact/enquiry sources, while a caller without sales.manage is denied.
-- The row-locked numbering source has been inspected, but its concurrent behavior
-- must still be proven by isolated acceptance. After that acceptance is installed,
-- only the combined intake transition may call this protected action; legacy
-- opportunity/specification entry points remain unchanged until their separate
-- controlled-write/direct-mutation-denial transition is accepted.
