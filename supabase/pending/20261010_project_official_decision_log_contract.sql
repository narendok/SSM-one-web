-- SOURCE-ONLY, REVIEW-ONLY PROPOSAL. DO NOT APPLY.
--
-- This is a candidate implementation of the tracked PROPOSED project official
-- decision-log contract. It is not installed, callable, granted, seeded, or
-- wired to any application action. It must be reviewed against the final
-- committed-project transition contracts before using lov_database--migration.
--
-- Verified existing authority: public.has_permission(uuid, text), the existing
-- projects.view / projects.manage permission keys, and active employee-backed
-- public.project_team_members membership. No verified committed-project action
-- authority maps a source page/item locator to a caller. This proposal therefore
-- exposes neither caller reads nor append authority until that missing mapping is
-- accepted; future Hardware, Purchase, and Sales-exception action kinds remain
-- fail-closed.
--
-- Scope: committed projects and authoritative existing project BOM items only.
-- It does not alter Sales proposals, candidate workflow state, inventory,
-- commercial values, project-BOM source rows, notifications, or UI behavior.

CREATE TABLE public.project_official_decisions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid NOT NULL REFERENCES public.projects(id) ON DELETE RESTRICT,
  project_bom_id uuid NOT NULL REFERENCES public.project_boms(id) ON DELETE RESTRICT,
  project_bom_item_id uuid NOT NULL REFERENCES public.project_bom_items(id) ON DELETE RESTRICT,
  source_page_reference text NOT NULL,
  action_intent text NOT NULL,
  expected_source_revision text NOT NULL,
  note text NOT NULL,
  actor_user_id uuid NOT NULL,
  amendment_parent_decision_id uuid NULL REFERENCES public.project_official_decisions(id) ON DELETE RESTRICT,
  alternative_reference text NULL,
  exception_reference text NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT project_official_decisions_source_page_reference_nonblank CHECK (length(btrim(source_page_reference)) > 0),
  CONSTRAINT project_official_decisions_action_intent_nonblank CHECK (length(btrim(action_intent)) > 0),
  CONSTRAINT project_official_decisions_expected_source_revision_nonblank CHECK (length(btrim(expected_source_revision)) > 0),
  CONSTRAINT project_official_decisions_note_short CHECK (length(btrim(note)) BETWEEN 1 AND 512),
  CONSTRAINT project_official_decisions_no_self_amendment CHECK (amendment_parent_decision_id IS NULL OR amendment_parent_decision_id <> id)
);
REVOKE ALL ON TABLE public.project_official_decisions FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT ON TABLE public.project_official_decisions TO service_role;
ALTER TABLE public.project_official_decisions ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.project_official_decision_evidence (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  decision_id uuid NOT NULL REFERENCES public.project_official_decisions(id) ON DELETE RESTRICT,
  evidence_reference text NOT NULL,
  contributor_reference text NOT NULL,
  scope_reference text NOT NULL,
  contributor_user_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT project_official_decision_evidence_reference_nonblank CHECK (length(btrim(evidence_reference)) > 0),
  CONSTRAINT project_official_decision_evidence_contributor_reference_nonblank CHECK (length(btrim(contributor_reference)) > 0),
  CONSTRAINT project_official_decision_evidence_scope_reference_nonblank CHECK (length(btrim(scope_reference)) > 0)
);
REVOKE ALL ON TABLE public.project_official_decision_evidence FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT ON TABLE public.project_official_decision_evidence TO service_role;
ALTER TABLE public.project_official_decision_evidence ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.project_official_decision_receipts (
  request_key uuid PRIMARY KEY,
  requested_by uuid NOT NULL,
  project_id uuid NOT NULL REFERENCES public.projects(id) ON DELETE RESTRICT,
  payload_hash text NOT NULL,
  payload_canonical jsonb NOT NULL,
  decision_id uuid NOT NULL UNIQUE REFERENCES public.project_official_decisions(id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT project_official_decision_receipts_payload_hash_nonblank CHECK (length(btrim(payload_hash)) > 0),
  CONSTRAINT project_official_decision_receipts_payload_canonical_object CHECK (jsonb_typeof(payload_canonical) = 'object')
);
REVOKE ALL ON TABLE public.project_official_decision_receipts FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT ON TABLE public.project_official_decision_receipts TO service_role;
ALTER TABLE public.project_official_decision_receipts ENABLE ROW LEVEL SECURITY;

-- Caller-scoped, security-invoker read projection. It intentionally returns no
-- rows until the deployment gate identifies a verified exact committed-project
-- membership-and-permission authority. It never exposes receipts or direct writes.
CREATE VIEW public.project_official_decision_log
WITH (security_invoker = true)
AS
SELECT
  decision.id,
  decision.project_id,
  decision.project_bom_id,
  decision.project_bom_item_id,
  decision.source_page_reference,
  decision.action_intent,
  decision.expected_source_revision,
  decision.note,
  decision.actor_user_id,
  decision.amendment_parent_decision_id,
  decision.alternative_reference,
  decision.exception_reference,
  decision.created_at,
  '[]'::jsonb AS evidence
FROM public.project_official_decisions decision
WHERE false;
REVOKE ALL ON TABLE public.project_official_decision_log FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT ON TABLE public.project_official_decision_log TO service_role;

-- PROPOSED server request adapter. It accepts one exact JSONB representation,
-- preserves every manual string byte, and rejects unsupported/ambiguous shapes.
-- All 512-character limits are Unicode code points (PostgreSQL char_length),
-- matching the local validator's Array.from code-point count.
-- Client-side payload comparison is local-only. This JSONB result, produced
-- after future server-derived source resolution, is the receipt authority.
CREATE OR REPLACE FUNCTION public.project_official_decision_request_adapter(
  p_request jsonb
) RETURNS jsonb
LANGUAGE sql
IMMUTABLE
SET search_path = public
AS $$
  WITH request_shape AS (
    SELECT p_request
    WHERE jsonb_typeof(p_request) = 'object'
  ), request_fields AS (
    SELECT request_shape.p_request,
      (SELECT array_agg(key ORDER BY key) FROM jsonb_object_keys(request_shape.p_request) AS key) AS keys
    FROM request_shape
  ), evidence_shape AS (
    SELECT request_fields.p_request, evidence.value
    FROM request_fields
    CROSS JOIN LATERAL jsonb_array_elements(request_fields.p_request->'evidenceReferences') AS evidence(value)
    WHERE jsonb_typeof(request_fields.p_request->'evidenceReferences') = 'array'
  )
  SELECT CASE
    WHEN p_request IS NULL
      OR jsonb_typeof(p_request) <> 'object'
      OR p_request ?| ARRAY[
        'projectBomItemId', 'sourceLocator', 'amendment',
        'project_bom_item_id', 'source_page_reference',
        'amendment_parent_decision_id'
      ]
      OR (SELECT keys FROM request_fields)
         IS DISTINCT FROM ARRAY[
           'actionIntent', 'alternativeReference', 'evidenceReferences',
           'exceptionReference', 'expectedSourceRevision', 'note',
           'sourcePageReference'
         ]
      OR jsonb_typeof(p_request->'actionIntent') <> 'string'
      OR jsonb_typeof(p_request->'sourcePageReference') <> 'string'
      OR jsonb_typeof(p_request->'expectedSourceRevision') <> 'string'
      OR jsonb_typeof(p_request->'note') <> 'string'
      OR jsonb_typeof(p_request->'evidenceReferences') <> 'array'
      OR jsonb_typeof(p_request->'alternativeReference') NOT IN ('null', 'string')
      OR jsonb_typeof(p_request->'exceptionReference') NOT IN ('null', 'string')
      OR CASE WHEN jsonb_typeof(p_request->'evidenceReferences') = 'array'
        THEN jsonb_array_length(p_request->'evidenceReferences') > 32 ELSE false END
      OR NULLIF(btrim(p_request->>'actionIntent'), '') IS NULL
      OR NULLIF(btrim(p_request->>'sourcePageReference'), '') IS NULL
      OR NULLIF(btrim(p_request->>'expectedSourceRevision'), '') IS NULL
      OR NULLIF(btrim(p_request->>'note'), '') IS NULL
      OR char_length(p_request->>'actionIntent') > 512
      OR char_length(p_request->>'sourcePageReference') > 512
      OR char_length(p_request->>'expectedSourceRevision') > 512
      OR char_length(p_request->>'note') > 512
      OR (jsonb_typeof(p_request->'alternativeReference') = 'string'
          AND (NULLIF(btrim(p_request->>'alternativeReference'), '') IS NULL
            OR char_length(p_request->>'alternativeReference') > 512))
      OR (jsonb_typeof(p_request->'exceptionReference') = 'string'
          AND (NULLIF(btrim(p_request->>'exceptionReference'), '') IS NULL
            OR char_length(p_request->>'exceptionReference') > 512))
      OR EXISTS (
        SELECT 1
        FROM evidence_shape AS evidence
        WHERE jsonb_typeof(evidence.value) <> 'object'
          OR (SELECT array_agg(key ORDER BY key) FROM jsonb_object_keys(evidence.value) AS key)
             IS DISTINCT FROM ARRAY['contributorReference', 'evidenceReference', 'scopeReference']
          OR jsonb_typeof(evidence.value->'evidenceReference') <> 'string'
          OR jsonb_typeof(evidence.value->'contributorReference') <> 'string'
          OR jsonb_typeof(evidence.value->'scopeReference') <> 'string'
          OR NULLIF(btrim(evidence.value->>'evidenceReference'), '') IS NULL
          OR NULLIF(btrim(evidence.value->>'contributorReference'), '') IS NULL
          OR NULLIF(btrim(evidence.value->>'scopeReference'), '') IS NULL
          OR char_length(evidence.value->>'evidenceReference') > 512
          OR char_length(evidence.value->>'contributorReference') > 512
          OR char_length(evidence.value->>'scopeReference') > 512
      )
    THEN NULL
    ELSE jsonb_build_object(
      'actionIntent', p_request->'actionIntent',
      'sourcePageReference', p_request->'sourcePageReference',
      'expectedSourceRevision', p_request->'expectedSourceRevision',
      'note', p_request->'note',
      'evidenceReferences', COALESCE((
        SELECT jsonb_agg(evidence.value ORDER BY evidence.value::text COLLATE "C")
        FROM evidence_shape AS evidence
      ), '[]'::jsonb),
      'alternativeReference', p_request->'alternativeReference',
      'exceptionReference', p_request->'exceptionReference'
    )
  END
$$;

-- PROPOSED receipt canonicalizer. The protected action must inject only
-- client-supplied projectBomItemId after it has authorized and locked the
-- target against the source. The action must derive amendmentParentDecisionId
-- from server-owned history; neither identity is accepted in p_request.
CREATE OR REPLACE FUNCTION public.project_official_decision_canonical_payload(
  p_project_bom_item_id uuid,
  p_amendment_parent_decision_id uuid,
  p_request jsonb
) RETURNS jsonb
LANGUAGE sql
IMMUTABLE
SET search_path = public
AS $$
  SELECT CASE
    WHEN p_project_bom_item_id IS NULL OR adapted.payload IS NULL THEN NULL
    ELSE adapted.payload || jsonb_build_object(
      'projectBomItemId', p_project_bom_item_id,
      'amendmentParentDecisionId', p_amendment_parent_decision_id
    )
  END
  FROM (SELECT public.project_official_decision_request_adapter(p_request) AS payload) AS adapted
$$;

CREATE OR REPLACE FUNCTION public.project_official_decision_payload_hash(
  p_project_bom_item_id uuid,
  p_amendment_parent_decision_id uuid,
  p_request jsonb
) RETURNS text
LANGUAGE sql
IMMUTABLE
SET search_path = public
AS $$
  SELECT CASE WHEN canonical.payload IS NULL THEN NULL ELSE md5(canonical.payload::text) END
  FROM (
    SELECT public.project_official_decision_canonical_payload(
      p_project_bom_item_id, p_amendment_parent_decision_id, p_request
    ) AS payload
  ) AS canonical
$$;

-- PROPOSED protected append action. Its action intent is deliberately limited
-- to 'project-bom-note' until separately accepted candidate/Purchase/Hardware/
-- Sales transition contracts define their exact authorization predicates.
CREATE OR REPLACE FUNCTION public.append_project_official_decision(
  p_project_bom_item_id uuid,
  p_amendment_parent_decision_id uuid,
  p_request jsonb,
  p_request_key uuid
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor_id uuid := auth.uid();
  v_project_id uuid;
  v_project_bom_id uuid;
  v_actual_revision text;
  v_parent public.project_official_decisions%ROWTYPE;
  v_prior public.project_official_decision_receipts%ROWTYPE;
  v_decision_id uuid;
  v_payload_canonical jsonb;
  v_payload_hash text;
  v_adapted_request jsonb;
BEGIN
  IF v_actor_id IS NULL THEN
    RAISE EXCEPTION 'Authentication is required';
  END IF;
  -- Deployment gate: a permission alone is intentionally insufficient. Do not
  -- enable append authority until an exact active committed-project membership
  -- and approved source-page/item authority mapping are available.
  IF p_request_key IS NULL
     OR p_project_bom_item_id IS NULL
     OR p_amendment_parent_decision_id IS NOT NULL
     OR public.project_official_decision_request_adapter(p_request) IS NULL THEN
    RAISE EXCEPTION 'A valid bounded project-BOM official decision request is required';
  END IF;
  v_adapted_request := public.project_official_decision_request_adapter(p_request);
  IF v_adapted_request->>'actionIntent' <> 'project-bom-note' THEN
    RAISE EXCEPTION 'A valid bounded project-BOM official decision request is required';
  END IF;

  -- Evidence is optional. Nonempty evidence remains fail-closed until a
  -- reviewed contract resolves contributor and evidence provenance.
  IF jsonb_array_length(v_adapted_request->'evidenceReferences') <> 0 THEN
    RAISE EXCEPTION 'Evidence provenance authority is not installed';
  END IF;

  -- Authorize before receipt lookup. Existing project membership proves only
  -- membership; it does not verify this requested page/item action. Fail closed
  -- until a reviewed authority maps the exact active membership plus existing
  -- permission to a server-derived source-page/item action.
  IF NOT public.has_permission(v_actor_id, 'projects.manage')
     OR NOT EXISTS (
       SELECT 1
       FROM public.project_team_members membership
       JOIN public.employees member_employee ON member_employee.id = membership.employee_id
       WHERE member_employee.user_id = v_actor_id
         AND member_employee.employment_status = 'ACTIVE'
     ) THEN
    RAISE EXCEPTION 'Exact active project membership and project authority are required';
  END IF;
  RAISE EXCEPTION 'Official decision append authority is not installed: exact committed-project source action mapping is unresolved';

  -- The following reviewed implementation sketch remains unreachable until the
  -- deployment gate above is replaced in one acceptance-tested contract.
  PERFORM pg_advisory_xact_lock(hashtextextended(p_request_key::text, 0));
  SELECT bom.project_id, bom.id, bom.revision
  INTO v_project_id, v_project_bom_id, v_actual_revision
  FROM public.project_bom_items item
  JOIN public.project_boms bom ON bom.id = item.bom_id
  JOIN public.projects project ON project.id = bom.project_id
  WHERE item.id = p_project_bom_item_id
    AND project.status = 'active'
  FOR UPDATE OF project, bom, item;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Committed project BOM source is unavailable';
  END IF;
  -- Re-check current actor authority after target locks and before any replay or
  -- write. The final enabled contract must bind membership to v_project_id and
  -- derive the exact source page/item reference server-side.
  IF NOT public.has_permission(v_actor_id, 'projects.manage')
     OR NOT EXISTS (
       SELECT 1
       FROM public.project_team_members membership
       JOIN public.employees member_employee ON member_employee.id = membership.employee_id
       WHERE membership.project_id = v_project_id
         AND member_employee.user_id = v_actor_id
         AND member_employee.employment_status = 'ACTIVE'
     ) THEN
    RAISE EXCEPTION 'Current active project membership and project authority are required';
  END IF;
  IF v_actual_revision IS NULL OR v_actual_revision <> v_adapted_request->>'expectedSourceRevision' THEN
    RAISE EXCEPTION 'Project BOM source revision conflict';
  END IF;

  v_payload_canonical := public.project_official_decision_canonical_payload(
    p_project_bom_item_id, p_amendment_parent_decision_id, p_request
  );
  v_payload_hash := public.project_official_decision_payload_hash(
    p_project_bom_item_id, p_amendment_parent_decision_id, p_request
  );

  SELECT * INTO v_prior
  FROM public.project_official_decision_receipts
  WHERE request_key = p_request_key
  FOR UPDATE;
  IF FOUND THEN
    IF v_prior.requested_by = v_actor_id
       AND v_prior.project_id = v_project_id
       AND v_prior.payload_hash = v_payload_hash
       AND v_prior.payload_canonical = v_payload_canonical THEN
      RETURN v_prior.decision_id;
    END IF;
    RAISE EXCEPTION 'Request key conflicts with a different caller or canonical payload';
  END IF;

  IF p_amendment_parent_decision_id IS NOT NULL THEN
    SELECT * INTO v_parent
    FROM public.project_official_decisions
    WHERE id = p_amendment_parent_decision_id
      AND project_id = v_project_id
      AND project_bom_id = v_project_bom_id
      AND project_bom_item_id = p_project_bom_item_id
    FOR UPDATE;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Amendment parent is unavailable for this project BOM source';
    END IF;
  END IF;

  INSERT INTO public.project_official_decisions (
    project_id, project_bom_id, project_bom_item_id, source_page_reference,
    action_intent, expected_source_revision, note, actor_user_id,
    amendment_parent_decision_id, alternative_reference, exception_reference
  ) VALUES (
    v_project_id, v_project_bom_id, p_project_bom_item_id, v_adapted_request->>'sourcePageReference',
    v_adapted_request->>'actionIntent', v_adapted_request->>'expectedSourceRevision', v_adapted_request->>'note', v_actor_id,
    p_amendment_parent_decision_id, v_adapted_request->>'alternativeReference',
    v_adapted_request->>'exceptionReference'
  ) RETURNING id INTO v_decision_id;

  -- No evidence insert occurs until provenance is verified. When enabled, it
  -- must persist v_adapted_request evidence strings without trimming.

  INSERT INTO public.project_official_decision_receipts (
    request_key, requested_by, project_id, payload_hash, payload_canonical, decision_id
  ) VALUES (
    p_request_key, v_actor_id, v_project_id, v_payload_hash, v_payload_canonical, v_decision_id
  );
  RETURN v_decision_id;
END;
$$;

REVOKE ALL ON FUNCTION public.append_project_official_decision(uuid, uuid, jsonb, uuid) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.append_project_official_decision(uuid, text, text, text, text, uuid, text, text, jsonb, uuid) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.project_official_decision_request_adapter(jsonb) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.project_official_decision_canonical_payload(uuid, uuid, jsonb) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.project_official_decision_canonical_payload(uuid, text, text, text, text, uuid, text, text, jsonb) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.project_official_decision_payload_hash(uuid, uuid, jsonb) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.project_official_decision_payload_hash(uuid, text, text, text, text, uuid, text, text, jsonb) FROM PUBLIC, anon, authenticated, service_role;

-- Direct writes, including service-role UPDATE/DELETE, are denied by explicit
-- table privileges and by omission of INSERT/UPDATE/DELETE policies. Caller reads are deliberately denied until exact active project
-- membership plus existing permission can be proven for the target project.
CREATE POLICY project_official_decisions_project_read_denied_pending_authority
ON public.project_official_decisions
FOR SELECT TO authenticated
USING (false);

CREATE POLICY project_official_decision_evidence_project_read_denied_pending_authority
ON public.project_official_decision_evidence
FOR SELECT TO authenticated
USING (false);

-- DEPLOYMENT GATE: do not apply until a reviewed executable authority maps each
-- future action intent to an exact active project-team membership plus verified
-- existing permission, derives the committed project and source page/item from
-- server-owned identifiers, re-checks revocation after locks before replay/write,
-- defines evidence/contributor provenance, and passes isolated non-admin,
-- SET ROLE authenticated, rollback, replay, conflict, cross-project, and
-- two-session acceptance. Cross-runtime byte/hash parity is intentionally not
-- required: JSONB canonicalization is the server receipt authority and the TS
-- comparison helper remains local-only. Amendment-chain concurrency remains
-- separately blocked and is not established by this file.