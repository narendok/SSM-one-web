-- SOURCE-ONLY, REVIEW-ONLY PROPOSAL. DO NOT APPLY.
--
-- This is a candidate implementation of the tracked PROPOSED project official
-- decision-log contract. It is not installed, callable, granted, seeded, or
-- wired to any application action. It must be reviewed against the final
-- committed-project transition contracts before using lov_database--migration.
--
-- Verified existing authority: public.has_permission(uuid, text) and the
-- existing projects.view / projects.manage permission keys. No verified
-- department-specific Hardware, Purchase, or Sales-exception permission exists;
-- this contract consequently fails closed for those action kinds.
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
GRANT SELECT ON public.project_official_decisions TO authenticated;
GRANT ALL ON public.project_official_decisions TO service_role;
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
GRANT SELECT ON public.project_official_decision_evidence TO authenticated;
GRANT ALL ON public.project_official_decision_evidence TO service_role;
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
GRANT ALL ON public.project_official_decision_receipts TO service_role;
ALTER TABLE public.project_official_decision_receipts ENABLE ROW LEVEL SECURITY;

-- Caller-scoped, security-invoker read projection. It relies only on the
-- verified project read boundary and deliberately exposes neither receipts nor
-- their canonical payload/hash. Direct base-table writes remain without policy.
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
JOIN public.projects project ON project.id = decision.project_id
WHERE public.has_any_permission(auth.uid(), ARRAY['projects.view', 'projects.manage'])
;
GRANT SELECT ON public.project_official_decision_log TO authenticated;

CREATE OR REPLACE FUNCTION public.project_official_decision_canonical_payload(
  p_project_bom_item_id uuid,
  p_source_page_reference text,
  p_action_intent text,
  p_expected_source_revision text,
  p_note text,
  p_amendment_parent_decision_id uuid,
  p_alternative_reference text,
  p_exception_reference text,
  p_evidence jsonb
) RETURNS jsonb
LANGUAGE sql
IMMUTABLE
SET search_path = public
AS $$
  SELECT jsonb_build_object(
    'project_bom_item_id', p_project_bom_item_id,
    'source_page_reference', btrim(p_source_page_reference),
    'action_intent', btrim(p_action_intent),
    'expected_source_revision', btrim(p_expected_source_revision),
    'note', p_note,
    'amendment_parent_decision_id', p_amendment_parent_decision_id,
    'alternative_reference', nullif(btrim(coalesce(p_alternative_reference, '')), ''),
    'exception_reference', nullif(btrim(coalesce(p_exception_reference, '')), ''),
    'evidence', COALESCE((
      SELECT jsonb_agg(entry.value ORDER BY entry.value::text COLLATE "C")
      FROM jsonb_array_elements(COALESCE(p_evidence, '[]'::jsonb)) AS entry(value)
    ), '[]'::jsonb)
  )
$$;

CREATE OR REPLACE FUNCTION public.project_official_decision_payload_hash(
  p_project_bom_item_id uuid,
  p_source_page_reference text,
  p_action_intent text,
  p_expected_source_revision text,
  p_note text,
  p_amendment_parent_decision_id uuid,
  p_alternative_reference text,
  p_exception_reference text,
  p_evidence jsonb
) RETURNS text
LANGUAGE sql
IMMUTABLE
SET search_path = public
AS $$
  SELECT md5(public.project_official_decision_canonical_payload(
    p_project_bom_item_id, p_source_page_reference, p_action_intent,
    p_expected_source_revision, p_note, p_amendment_parent_decision_id,
    p_alternative_reference, p_exception_reference, p_evidence
  )::text)
$$;

-- PROPOSED protected append action. Its action intent is deliberately limited
-- to 'project-bom-note' until separately accepted candidate/Purchase/Hardware/
-- Sales transition contracts define their exact authorization predicates.
CREATE OR REPLACE FUNCTION public.append_project_official_decision(
  p_project_bom_item_id uuid,
  p_source_page_reference text,
  p_action_intent text,
  p_expected_source_revision text,
  p_note text,
  p_amendment_parent_decision_id uuid,
  p_alternative_reference text,
  p_exception_reference text,
  p_evidence jsonb,
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
  v_evidence_entry jsonb;
  v_evidence_index integer := 0;
BEGIN
  IF v_actor_id IS NULL OR NOT public.has_permission(v_actor_id, 'projects.manage') THEN
    RAISE EXCEPTION 'Project management permission is required';
  END IF;
  IF p_request_key IS NULL
     OR p_project_bom_item_id IS NULL
     OR NULLIF(btrim(p_source_page_reference), '') IS NULL
     OR NULLIF(btrim(p_action_intent), '') IS NULL
     OR NULLIF(btrim(p_expected_source_revision), '') IS NULL
     OR NULLIF(btrim(p_note), '') IS NULL
     OR char_length(btrim(p_source_page_reference)) > 512
     OR char_length(btrim(p_action_intent)) > 512
     OR char_length(btrim(p_expected_source_revision)) > 512
     OR char_length(p_note) > 512
     OR p_action_intent <> 'project-bom-note'
     OR (p_evidence IS NOT NULL AND jsonb_typeof(p_evidence) <> 'array')
     OR COALESCE(jsonb_array_length(p_evidence), 0) > 32 THEN
    RAISE EXCEPTION 'A valid bounded project-BOM official decision request is required';
  END IF;

  -- Each evidence reference is bounded, shape-fixed, and kept only as
  -- contributor-scoped contextual provenance. The server derives its actor.
  FOR v_evidence_entry IN SELECT value FROM jsonb_array_elements(COALESCE(p_evidence, '[]'::jsonb))
  LOOP
    IF jsonb_typeof(v_evidence_entry) <> 'object'
       OR (SELECT count(*) FROM jsonb_object_keys(v_evidence_entry)) <> 3
       OR NOT (v_evidence_entry ? 'evidenceReference' AND v_evidence_entry ? 'contributorReference' AND v_evidence_entry ? 'scopeReference')
       OR NULLIF(btrim(v_evidence_entry->>'evidenceReference'), '') IS NULL
       OR NULLIF(btrim(v_evidence_entry->>'contributorReference'), '') IS NULL
       OR NULLIF(btrim(v_evidence_entry->>'scopeReference'), '') IS NULL
       OR char_length(v_evidence_entry->>'evidenceReference') > 512
       OR char_length(v_evidence_entry->>'contributorReference') > 512
       OR char_length(v_evidence_entry->>'scopeReference') > 512 THEN
      RAISE EXCEPTION 'Evidence entry % is invalid', v_evidence_index;
    END IF;
    v_evidence_index := v_evidence_index + 1;
  END LOOP;

  -- Authorize before receipt lookup. The verified existing boundary has no
  -- department-specific authority, so this intentionally fails closed for all
  -- future action intents until their independent contracts are accepted.
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
  IF v_actual_revision IS NULL OR v_actual_revision <> p_expected_source_revision THEN
    RAISE EXCEPTION 'Project BOM source revision conflict';
  END IF;

  v_payload_canonical := public.project_official_decision_canonical_payload(
    p_project_bom_item_id, p_source_page_reference, p_action_intent,
    p_expected_source_revision, p_note, p_amendment_parent_decision_id,
    p_alternative_reference, p_exception_reference, p_evidence
  );
  v_payload_hash := public.project_official_decision_payload_hash(
    p_project_bom_item_id, p_source_page_reference, p_action_intent,
    p_expected_source_revision, p_note, p_amendment_parent_decision_id,
    p_alternative_reference, p_exception_reference, p_evidence
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
    v_project_id, v_project_bom_id, p_project_bom_item_id, btrim(p_source_page_reference),
    btrim(p_action_intent), btrim(p_expected_source_revision), p_note, v_actor_id,
    p_amendment_parent_decision_id, nullif(btrim(coalesce(p_alternative_reference, '')), ''),
    nullif(btrim(coalesce(p_exception_reference, '')), '')
  ) RETURNING id INTO v_decision_id;

  FOR v_evidence_entry IN SELECT value FROM jsonb_array_elements(COALESCE(p_evidence, '[]'::jsonb))
  LOOP
    INSERT INTO public.project_official_decision_evidence (
      decision_id, evidence_reference, contributor_reference, scope_reference, contributor_user_id
    ) VALUES (
      v_decision_id, btrim(v_evidence_entry->>'evidenceReference'),
      btrim(v_evidence_entry->>'contributorReference'), btrim(v_evidence_entry->>'scopeReference'),
      v_actor_id
    );
  END LOOP;

  INSERT INTO public.project_official_decision_receipts (
    request_key, requested_by, project_id, payload_hash, payload_canonical, decision_id
  ) VALUES (
    p_request_key, v_actor_id, v_project_id, v_payload_hash, v_payload_canonical, v_decision_id
  );
  RETURN v_decision_id;
END;
$$;

REVOKE ALL ON FUNCTION public.append_project_official_decision(uuid, text, text, text, text, uuid, text, text, jsonb, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.append_project_official_decision(uuid, text, text, text, text, uuid, text, text, jsonb, uuid) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.project_official_decision_canonical_payload(uuid, text, text, text, text, uuid, text, text, jsonb) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.project_official_decision_payload_hash(uuid, text, text, text, text, uuid, text, text, jsonb) FROM PUBLIC, anon, authenticated;

-- Direct writes are denied by omission of INSERT/UPDATE/DELETE policies. The
-- read policy mirrors the verified project read boundary; its project-scoping
-- remains a deployment gate because existing project reads are permission-wide.
CREATE POLICY project_official_decisions_project_read
ON public.project_official_decisions
FOR SELECT TO authenticated
USING (public.has_any_permission(auth.uid(), ARRAY['projects.view', 'projects.manage']));

CREATE POLICY project_official_decision_evidence_project_read
ON public.project_official_decision_evidence
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.project_official_decisions decision
    WHERE decision.id = project_official_decision_evidence.decision_id
      AND public.has_any_permission(auth.uid(), ARRAY['projects.view', 'projects.manage'])
  )
);

-- DEPLOYMENT GATE: do not apply until a reviewed executable authority maps each
-- future action intent to a verified project membership/department permission,
-- narrows project visibility to exact caller scope, defines server-derived page
-- and source identifiers, and passes isolated non-admin, rollback, replay,
-- conflict, cross-project, and two-session acceptance.