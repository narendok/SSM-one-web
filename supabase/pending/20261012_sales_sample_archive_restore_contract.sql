-- SOURCE-ONLY, UNDEPLOYED REVIEW CONTRACT. DO NOT APPLY.
--
-- Exact candidate roots are frozen inside the transaction by UUID + display
-- number. This contract never deletes, truncates, rewrites, or moves a legacy
-- dependency. It only adds reversible root metadata plus append-only receipts
-- and audit facts after every dependency gate has passed.

ALTER TABLE public.sales_opportunities
  ADD COLUMN archived_at timestamptz NULL,
  ADD COLUMN archived_by uuid NULL,
  ADD COLUMN archive_manifest_id uuid NULL;
ALTER TABLE public.customer_requirements
  ADD COLUMN archived_at timestamptz NULL,
  ADD COLUMN archived_by uuid NULL,
  ADD COLUMN archive_manifest_id uuid NULL;

CREATE TABLE public.sales_sample_archive_manifests (
  id uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
  action text NOT NULL CHECK (action IN ('ARCHIVE', 'RESTORE')),
  request_key uuid NOT NULL UNIQUE,
  actor_user_id uuid NOT NULL,
  reason text NOT NULL CHECK (char_length(btrim(reason)) BETWEEN 3 AND 500),
  payload_hash text NOT NULL CHECK (btrim(payload_hash) <> ''),
  prior_manifest_id uuid NULL REFERENCES public.sales_sample_archive_manifests(id) ON DELETE RESTRICT,
  result jsonb NOT NULL CHECK (jsonb_typeof(result) = 'object'),
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.sales_sample_archive_manifests TO authenticated;
GRANT ALL ON public.sales_sample_archive_manifests TO service_role;
ALTER TABLE public.sales_sample_archive_manifests ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.sales_sample_archive_manifest_items (
  id uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
  manifest_id uuid NOT NULL REFERENCES public.sales_sample_archive_manifests(id) ON DELETE RESTRICT,
  root_kind text NOT NULL CHECK (root_kind IN ('OPPORTUNITY', 'REQUIREMENT')),
  root_id uuid NOT NULL,
  display_number text NOT NULL,
  prior_state jsonb NOT NULL CHECK (jsonb_typeof(prior_state) = 'object'),
  dependency_snapshot jsonb NOT NULL CHECK (jsonb_typeof(dependency_snapshot) = 'object'),
  UNIQUE (manifest_id, root_kind, root_id),
  UNIQUE (manifest_id, root_kind, display_number)
);
GRANT SELECT ON public.sales_sample_archive_manifest_items TO authenticated;
GRANT ALL ON public.sales_sample_archive_manifest_items TO service_role;
ALTER TABLE public.sales_sample_archive_manifest_items ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.sales_sample_archive_audit_events (
  id uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
  manifest_id uuid NOT NULL REFERENCES public.sales_sample_archive_manifests(id) ON DELETE RESTRICT,
  actor_user_id uuid NOT NULL,
  action text NOT NULL CHECK (action IN ('ARCHIVED', 'RESTORED')),
  event_data jsonb NOT NULL CHECK (jsonb_typeof(event_data) = 'object'),
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.sales_sample_archive_audit_events TO authenticated;
GRANT ALL ON public.sales_sample_archive_audit_events TO service_role;
ALTER TABLE public.sales_sample_archive_audit_events ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.sales_sample_archive_can_manage(p_actor uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, extensions AS $$
  SELECT p_actor IS NOT NULL AND public.has_permission(p_actor, 'sales.manage');
$$;

CREATE OR REPLACE FUNCTION public.sales_sample_archive_canonical_roots(p_roots jsonb)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SET search_path = public, extensions AS $$
DECLARE v_root jsonb; v_kind text; v_id uuid; v_number text; v_out jsonb := '[]'::jsonb;
BEGIN
  IF jsonb_typeof(p_roots) IS DISTINCT FROM 'array' OR jsonb_array_length(p_roots) <> 10 THEN
    RAISE EXCEPTION 'Exactly the ten reviewed sample roots are required';
  END IF;
  FOR v_root IN SELECT value FROM jsonb_array_elements(p_roots) AS roots(value) LOOP
    IF jsonb_typeof(v_root) IS DISTINCT FROM 'object'
      OR EXISTS (SELECT 1 FROM jsonb_object_keys(v_root) AS key WHERE key <> ALL (ARRAY['kind','id','displayNumber'])) THEN
      RAISE EXCEPTION 'Archive root shape is invalid';
    END IF;
    v_kind := upper(btrim(coalesce(v_root ->> 'kind', '')));
    IF v_kind NOT IN ('OPPORTUNITY','REQUIREMENT') THEN RAISE EXCEPTION 'Archive root kind is invalid'; END IF;
    BEGIN v_id := (v_root ->> 'id')::uuid; EXCEPTION WHEN invalid_text_representation THEN RAISE EXCEPTION 'Archive root id is invalid'; END;
    v_number := btrim(coalesce(v_root ->> 'displayNumber', ''));
    IF v_number = '' THEN RAISE EXCEPTION 'Archive display number is required'; END IF;
    v_out := v_out || jsonb_build_array(jsonb_build_object('kind', v_kind, 'id', v_id, 'displayNumber', v_number));
  END LOOP;
  IF (SELECT count(*) FROM jsonb_array_elements(v_out)) <> (SELECT count(DISTINCT value) FROM jsonb_array_elements(v_out)) THEN
    RAISE EXCEPTION 'Archive roots must be unique';
  END IF;
  SELECT coalesce(jsonb_agg(value ORDER BY value ->> 'kind', value ->> 'displayNumber', value ->> 'id'), '[]'::jsonb) INTO v_out
  FROM jsonb_array_elements(v_out);
  IF v_out IS DISTINCT FROM
     '[{"kind":"OPPORTUNITY","id":"104fb9e2-7f83-40f9-a295-64b37aa8c7ee","displayNumber":"OPPORTUNITY-2026-0006"},{"kind":"OPPORTUNITY","id":"becebb23-e0f2-4264-a78f-fda04275cade","displayNumber":"OPPORTUNITY-2026-0007"},{"kind":"OPPORTUNITY","id":"428d7d9e-25bf-4e98-94d5-416ea56155e3","displayNumber":"OPPORTUNITY-2026-0008"},{"kind":"OPPORTUNITY","id":"dc101dd9-89a2-4dad-9903-3b2301a97d3b","displayNumber":"OPPORTUNITY-2026-0009"},{"kind":"OPPORTUNITY","id":"d79f58c1-bbee-4940-9e67-88f267f5449b","displayNumber":"OPPORTUNITY-2026-0010"},{"kind":"REQUIREMENT","id":"aaabd18c-5885-45de-9e0e-da70d4ec491f","displayNumber":"CUSTOMER-2026-0003"},{"kind":"REQUIREMENT","id":"36cdc159-57c7-4568-a1b0-ec481f5d3d93","displayNumber":"CUSTOMER-2026-0004"},{"kind":"REQUIREMENT","id":"6aa2fc2f-eb75-48c2-a9de-d13008cf1c5c","displayNumber":"CUSTOMER-2026-0005"},{"kind":"REQUIREMENT","id":"2db48440-5424-4e5e-bb5b-01f203a7662f","displayNumber":"CUSTOMER-2026-0006"},{"kind":"REQUIREMENT","id":"e829dd82-381d-42ab-a808-62979e9156f4","displayNumber":"CUSTOMER-2026-0007"}]'::jsonb THEN
    RAISE EXCEPTION 'Archive roots do not match the reviewed candidate set';
  END IF;
  RETURN v_out;
END;
$$;

CREATE OR REPLACE FUNCTION public.sales_sample_archive_dependency_snapshot(p_kind text, p_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, extensions AS $$
BEGIN
  IF p_kind = 'REQUIREMENT' THEN
    RETURN jsonb_build_object(
      'requirementRevisions', COALESCE((SELECT jsonb_agg(jsonb_build_object('id', id, 'revisionNumber', revision_number, 'status', status) ORDER BY revision_number, id) FROM public.customer_requirement_revisions WHERE requirement_id=p_id), '[]'::jsonb),
      'feasibilityReviews', (SELECT count(*) FROM public.requirement_feasibility_reviews WHERE requirement_id=p_id),
      'commercialRecords', (SELECT count(*) FROM public.sales_commercial_records WHERE requirement_id=p_id),
      'baselines', (SELECT count(*) FROM public.requirement_baselines WHERE requirement_id=p_id),
      'changeRequests', (SELECT count(*) FROM public.requirement_change_requests WHERE requirement_id=p_id),
      'projectDesignInputs', (SELECT count(*) FROM public.project_design_inputs WHERE source_requirement_id=p_id OR source_revision_id IN (SELECT id FROM public.customer_requirement_revisions WHERE requirement_id=p_id)),
      'portalShares', (SELECT count(*) FROM public.customer_portal_shares WHERE entity_id=p_id),
      'history', COALESCE((SELECT jsonb_agg(jsonb_build_object('id', id, 'action', action, 'createdAt', created_at) ORDER BY created_at, id) FROM public.activity_log WHERE entity_id=p_id), '[]'::jsonb)
    );
  END IF;
  RETURN jsonb_build_object(
    'requirements', COALESCE((SELECT jsonb_agg(jsonb_build_object('id', id, 'opportunityId', opportunity_id, 'requirementNumber', requirement_number) ORDER BY requirement_number, id) FROM public.customer_requirements WHERE opportunity_id=p_id), '[]'::jsonb),
    'masterSpecifications', (SELECT count(*) FROM public.master_specifications WHERE opportunity_id=p_id),
    'ndaRecords', (SELECT count(*) FROM public.sales_nda_records WHERE opportunity_id=p_id),
    'documentLocations', (SELECT count(*) FROM public.sales_opportunity_document_locations WHERE opportunity_id=p_id),
    'structuredDrafts', (SELECT count(*) FROM public.sales_opportunity_structured_drafts WHERE opportunity_id=p_id),
    'structuredRequests', (SELECT count(*) FROM public.sales_opportunity_structured_draft_requests WHERE opportunity_id=p_id),
    'structuredMaterializations', (SELECT count(*) FROM public.sales_opportunity_structured_draft_materializations WHERE opportunity_id=p_id),
    'projects', (SELECT count(*) FROM public.projects WHERE opportunity_id=p_id),
    'portalShares', (SELECT count(*) FROM public.customer_portal_shares WHERE entity_id=p_id),
    'history', COALESCE((SELECT jsonb_agg(jsonb_build_object('id', id, 'action', action, 'createdAt', created_at) ORDER BY created_at, id) FROM public.activity_log WHERE entity_id=p_id), '[]'::jsonb)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.sales_sample_archive_assert_zero_dependencies(p_snapshot jsonb)
RETURNS void LANGUAGE plpgsql IMMUTABLE SET search_path = public, extensions AS $$
BEGIN
  IF jsonb_typeof(p_snapshot) IS DISTINCT FROM 'object' THEN RAISE EXCEPTION 'Archive dependency snapshot is invalid'; END IF;
  IF p_snapshot ? 'requirements' AND p_snapshot->'requirements' <> '[]'::jsonb THEN
    RAISE EXCEPTION 'Archive is blocked by a non-reviewed opportunity requirement';
  END IF;
  IF EXISTS (
    SELECT 1 FROM jsonb_each(p_snapshot) AS entry(key, value)
    WHERE key NOT IN ('requirementRevisions', 'requirements', 'history')
      AND value IS DISTINCT FROM '0'::jsonb
  ) THEN RAISE EXCEPTION 'Archive is blocked by a live business dependency'; END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.archive_reviewed_sales_samples(p_roots jsonb, p_reason text, p_request_key uuid)
RETURNS TABLE(manifest_id uuid, replayed boolean)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp AS $$
DECLARE v_actor uuid := auth.uid(); v_roots jsonb; v_hash text; v_receipt public.sales_sample_archive_manifests%ROWTYPE; v_manifest uuid; v_root jsonb; v_snapshot jsonb; v_state jsonb;
BEGIN
  IF NOT public.sales_sample_archive_can_manage(v_actor) THEN RAISE EXCEPTION 'Sales archive requires sales.manage'; END IF;
  v_roots := public.sales_sample_archive_canonical_roots(p_roots);
  IF char_length(btrim(coalesce(p_reason,''))) NOT BETWEEN 3 AND 500 OR p_request_key IS NULL THEN RAISE EXCEPTION 'Archive reason and request key are required'; END IF;
  v_hash := encode(extensions.digest(convert_to(jsonb_build_object('action','ARCHIVE','roots',v_roots,'reason',btrim(p_reason))::text, 'UTF8'), 'sha256'), 'hex');
  PERFORM pg_advisory_xact_lock(hashtextextended('reviewed-sales-sample-archive', 0));
  SELECT * INTO v_receipt FROM public.sales_sample_archive_manifests WHERE request_key=p_request_key FOR UPDATE;
  IF FOUND THEN
    IF v_receipt.actor_user_id=v_actor AND v_receipt.action='ARCHIVE' AND v_receipt.payload_hash=v_hash THEN RETURN QUERY SELECT v_receipt.id, true; RETURN; END IF;
    RAISE EXCEPTION 'Archive request key conflicts';
  END IF;
  INSERT INTO public.sales_sample_archive_manifests(action,request_key,actor_user_id,reason,payload_hash,result)
    VALUES ('ARCHIVE',p_request_key,v_actor,btrim(p_reason),v_hash,'{}') RETURNING id INTO v_manifest;
  FOR v_root IN SELECT value FROM jsonb_array_elements(v_roots) AS roots(value) LOOP
    IF v_root->>'kind'='OPPORTUNITY' THEN
      PERFORM 1 FROM public.sales_opportunities WHERE id=(v_root->>'id')::uuid AND opportunity_number=v_root->>'displayNumber' AND name='SYNTHETIC ONLY — Automotive Vehicle Tracker' AND customer_id='03e06115-a7d4-4965-9e92-9c37462f5ddc'::uuid AND stage='new' AND status='active' AND archived_at IS NULL FOR UPDATE;
      IF NOT FOUND THEN RAISE EXCEPTION 'Reviewed opportunity is missing, changed, or already archived'; END IF;
      v_state:=jsonb_build_object('stage','new','status','active','name','SYNTHETIC ONLY — Automotive Vehicle Tracker','customerId','03e06115-a7d4-4965-9e92-9c37462f5ddc','archivedAt',NULL); v_snapshot:=public.sales_sample_archive_dependency_snapshot('OPPORTUNITY',(v_root->>'id')::uuid);
    ELSE
      PERFORM 1 FROM public.customer_requirements WHERE id=(v_root->>'id')::uuid AND requirement_number=v_root->>'displayNumber' AND title='testcust' AND customer_id='a2f299d4-f8ba-4c5c-8dcf-5437bb21166e'::uuid AND opportunity_id='0f965acc-5f00-4e3d-9000-9176d739a38c'::uuid AND status='draft' AND current_revision=1 AND archived_at IS NULL FOR UPDATE;
      IF NOT FOUND THEN RAISE EXCEPTION 'Reviewed requirement is missing, changed, or already archived'; END IF;
      v_state:=jsonb_build_object('status','draft','title','testcust','customerId','a2f299d4-f8ba-4c5c-8dcf-5437bb21166e','opportunityId','0f965acc-5f00-4e3d-9000-9176d739a38c','currentRevision',1,'archivedAt',NULL); v_snapshot:=public.sales_sample_archive_dependency_snapshot('REQUIREMENT',(v_root->>'id')::uuid);
    END IF;
    PERFORM public.sales_sample_archive_assert_zero_dependencies(v_snapshot);
    INSERT INTO public.sales_sample_archive_manifest_items(manifest_id,root_kind,root_id,display_number,prior_state,dependency_snapshot) VALUES(v_manifest,v_root->>'kind',(v_root->>'id')::uuid,v_root->>'displayNumber',v_state,v_snapshot);
  END LOOP;
  UPDATE public.sales_opportunities SET archived_at=now(), archived_by=v_actor, archive_manifest_id=v_manifest WHERE id IN (SELECT (value->>'id')::uuid FROM jsonb_array_elements(v_roots) WHERE value->>'kind'='OPPORTUNITY');
  UPDATE public.customer_requirements SET archived_at=now(), archived_by=v_actor, archive_manifest_id=v_manifest WHERE id IN (SELECT (value->>'id')::uuid FROM jsonb_array_elements(v_roots) WHERE value->>'kind'='REQUIREMENT');
  UPDATE public.sales_sample_archive_manifests SET result=jsonb_build_object('rootCount',10,'action','ARCHIVE') WHERE id=v_manifest;
  INSERT INTO public.sales_sample_archive_audit_events(manifest_id,actor_user_id,action,event_data) VALUES(v_manifest,v_actor,'ARCHIVED',jsonb_build_object('rootCount',10,'requestKey',p_request_key));
  RETURN QUERY SELECT v_manifest,false;
END;
$$;

CREATE OR REPLACE FUNCTION public.restore_reviewed_sales_samples(p_archive_manifest_id uuid, p_reason text, p_request_key uuid)
RETURNS TABLE(manifest_id uuid, replayed boolean)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp AS $$
DECLARE v_actor uuid := auth.uid(); v_prior public.sales_sample_archive_manifests%ROWTYPE; v_receipt public.sales_sample_archive_manifests%ROWTYPE; v_manifest uuid; v_item record; v_hash text; v_snapshot jsonb;
BEGIN
  IF NOT public.sales_sample_archive_can_manage(v_actor) THEN RAISE EXCEPTION 'Sales restore requires sales.manage'; END IF;
  IF p_archive_manifest_id IS NULL OR char_length(btrim(coalesce(p_reason,''))) NOT BETWEEN 3 AND 500 OR p_request_key IS NULL THEN RAISE EXCEPTION 'Restore manifest, reason, and request key are required'; END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('reviewed-sales-sample-archive', 0));
  SELECT * INTO v_prior FROM public.sales_sample_archive_manifests WHERE id=p_archive_manifest_id AND action='ARCHIVE' FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Archive manifest was not found'; END IF;
  v_hash:=encode(extensions.digest(convert_to(jsonb_build_object('action','RESTORE','archiveManifestId',p_archive_manifest_id,'reason',btrim(p_reason))::text,'UTF8'),'sha256'),'hex');
  SELECT * INTO v_receipt FROM public.sales_sample_archive_manifests WHERE request_key=p_request_key FOR UPDATE;
  IF FOUND THEN
    IF v_receipt.actor_user_id=v_actor AND v_receipt.action='RESTORE' AND v_receipt.payload_hash=v_hash THEN RETURN QUERY SELECT v_receipt.id,true; RETURN; END IF;
    RAISE EXCEPTION 'Restore request key conflicts';
  END IF;
  IF (SELECT count(*) FROM public.sales_sample_archive_manifest_items AS check_items WHERE check_items.manifest_id=p_archive_manifest_id) <> 10 THEN RAISE EXCEPTION 'Archive manifest does not contain the exact reviewed root set'; END IF;
  PERFORM public.sales_sample_archive_canonical_roots((
    SELECT jsonb_agg(jsonb_build_object('kind', root_kind, 'id', root_id, 'displayNumber', display_number) ORDER BY root_kind, display_number, root_id)
    FROM public.sales_sample_archive_manifest_items AS canonical_items WHERE canonical_items.manifest_id=p_archive_manifest_id
  ));
  INSERT INTO public.sales_sample_archive_manifests(action,request_key,actor_user_id,reason,payload_hash,prior_manifest_id,result) VALUES('RESTORE',p_request_key,v_actor,btrim(p_reason),v_hash,p_archive_manifest_id,'{}') RETURNING id INTO v_manifest;
  FOR v_item IN
    SELECT *
    FROM public.sales_sample_archive_manifest_items AS item
    WHERE item.manifest_id=p_archive_manifest_id
    ORDER BY item.root_kind,item.display_number
    FOR UPDATE
  LOOP
    IF v_item.root_kind='OPPORTUNITY' THEN
      PERFORM 1 FROM public.sales_opportunities WHERE id=v_item.root_id AND opportunity_number=v_item.display_number AND name='SYNTHETIC ONLY — Automotive Vehicle Tracker' AND customer_id='03e06115-a7d4-4965-9e92-9c37462f5ddc'::uuid AND stage='new' AND status='active' AND archive_manifest_id=p_archive_manifest_id AND archived_at IS NOT NULL FOR UPDATE;
      IF NOT FOUND OR v_item.prior_state IS DISTINCT FROM jsonb_build_object('stage','new','status','active','name','SYNTHETIC ONLY — Automotive Vehicle Tracker','customerId','03e06115-a7d4-4965-9e92-9c37462f5ddc','archivedAt',NULL) THEN RAISE EXCEPTION 'Archived opportunity no longer matches its manifest'; END IF;
    ELSE
      PERFORM 1 FROM public.customer_requirements WHERE id=v_item.root_id AND requirement_number=v_item.display_number AND title='testcust' AND customer_id='a2f299d4-f8ba-4c5c-8dcf-5437bb21166e'::uuid AND opportunity_id='0f965acc-5f00-4e3d-9000-9176d739a38c'::uuid AND status='draft' AND current_revision=1 AND archive_manifest_id=p_archive_manifest_id AND archived_at IS NOT NULL FOR UPDATE;
      IF NOT FOUND OR v_item.prior_state IS DISTINCT FROM jsonb_build_object('status','draft','title','testcust','customerId','a2f299d4-f8ba-4c5c-8dcf-5437bb21166e','opportunityId','0f965acc-5f00-4e3d-9000-9176d739a38c','currentRevision',1,'archivedAt',NULL) THEN RAISE EXCEPTION 'Archived requirement no longer matches its manifest'; END IF;
    END IF;
    v_snapshot:=public.sales_sample_archive_dependency_snapshot(v_item.root_kind,v_item.root_id);
    IF v_snapshot IS DISTINCT FROM v_item.dependency_snapshot THEN RAISE EXCEPTION 'Restore is blocked by dependency drift'; END IF;
    INSERT INTO public.sales_sample_archive_manifest_items(manifest_id,root_kind,root_id,display_number,prior_state,dependency_snapshot) VALUES(v_manifest,v_item.root_kind,v_item.root_id,v_item.display_number,v_item.prior_state,v_snapshot);
  END LOOP;
  UPDATE public.sales_opportunities SET archived_at=NULL,archived_by=NULL,archive_manifest_id=NULL WHERE id IN (SELECT restore_items.root_id FROM public.sales_sample_archive_manifest_items AS restore_items WHERE restore_items.manifest_id=p_archive_manifest_id AND restore_items.root_kind='OPPORTUNITY') AND archive_manifest_id=p_archive_manifest_id;
  UPDATE public.customer_requirements SET archived_at=NULL,archived_by=NULL,archive_manifest_id=NULL WHERE id IN (SELECT restore_items.root_id FROM public.sales_sample_archive_manifest_items AS restore_items WHERE restore_items.manifest_id=p_archive_manifest_id AND restore_items.root_kind='REQUIREMENT') AND archive_manifest_id=p_archive_manifest_id;
  UPDATE public.sales_sample_archive_manifests SET result=jsonb_build_object('rootCount',10,'action','RESTORE') WHERE id=v_manifest;
  INSERT INTO public.sales_sample_archive_audit_events(manifest_id,actor_user_id,action,event_data) VALUES(v_manifest,v_actor,'RESTORED',jsonb_build_object('archiveManifestId',p_archive_manifest_id,'requestKey',p_request_key));
  RETURN QUERY SELECT v_manifest,false;
END;
$$;

CREATE OR REPLACE FUNCTION public.read_sales_sample_archive_history(p_manifest_id uuid)
RETURNS TABLE(id uuid, action text, request_key uuid, actor_user_id uuid, reason text, prior_manifest_id uuid, created_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_temp AS $$
BEGIN
  IF NOT public.sales_sample_archive_can_manage(auth.uid()) THEN RAISE EXCEPTION 'Sales archive history requires sales.manage'; END IF;
  RETURN QUERY SELECT m.id,m.action,m.request_key,m.actor_user_id,m.reason,m.prior_manifest_id,m.created_at FROM public.sales_sample_archive_manifests m WHERE m.id=p_manifest_id OR m.prior_manifest_id=p_manifest_id ORDER BY m.created_at;
END;
$$;

REVOKE ALL ON FUNCTION public.sales_sample_archive_can_manage(uuid) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.sales_sample_archive_canonical_roots(jsonb) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.sales_sample_archive_dependency_snapshot(text,uuid) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.sales_sample_archive_assert_zero_dependencies(jsonb) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.archive_reviewed_sales_samples(jsonb,text,uuid) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.restore_reviewed_sales_samples(uuid,text,uuid) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.read_sales_sample_archive_history(uuid) FROM PUBLIC, anon, authenticated, service_role;
-- No EXECUTE grant is included. Activation requires separate reviewed caller acceptance.
