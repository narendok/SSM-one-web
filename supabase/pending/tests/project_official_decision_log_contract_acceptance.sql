-- SOURCE-ONLY — ISOLATED-ENVIRONMENT STRUCTURAL ACCEPTANCE PLAN. DO NOT RUN
-- against preview, shared, or production data. This requires the unapplied
-- 20261010_project_official_decision_log_contract.sql and pre-existing approved
-- isolated manager, same-project reader, cross-project reader, and outsider
-- identities. It sets JWT claims directly, so it does not prove application
-- transport or real browser/session authentication.
--
-- Required variables: manager_user_id, same_project_reader_user_id,
-- cross_project_reader_user_id, outsider_user_id, project_bom_item_id,
-- project_bom_revision, request_key, conflicting_request_key.

\set ON_ERROR_STOP on

BEGIN;
SELECT set_config('request.jwt.claim.sub', :'manager_user_id', false);
SELECT set_config('request.jwt.claim.role', 'authenticated', false);

CREATE TEMP TABLE official_decision_first AS
SELECT public.append_project_official_decision(
  :'project_bom_item_id'::uuid,
  'project-bom',
  'project-bom-note',
  :'project_bom_revision',
  'Bench review confirmed.',
  NULL,
  NULL,
  NULL,
  '[{"evidenceReference":"evidence-1","contributorReference":"contributor-1","scopeReference":"project-bom"}]'::jsonb,
  :'request_key'::uuid
) AS decision_id;

-- Exact actor + canonical payload replay returns one immutable result.
CREATE TEMP TABLE official_decision_replay AS
SELECT public.append_project_official_decision(
  :'project_bom_item_id'::uuid, 'project-bom', 'project-bom-note', :'project_bom_revision',
  'Bench review confirmed.', NULL, NULL, NULL,
  '[{"evidenceReference":"evidence-1","contributorReference":"contributor-1","scopeReference":"project-bom"}]'::jsonb,
  :'request_key'::uuid
) AS decision_id;
DO $$
BEGIN
  IF (SELECT decision_id FROM official_decision_first) IS DISTINCT FROM (SELECT decision_id FROM official_decision_replay) THEN
    RAISE EXCEPTION 'Exact replay created a second decision';
  END IF;
  IF (SELECT count(*) FROM public.project_official_decisions) <> 1 THEN
    RAISE EXCEPTION 'Exact replay appended a second decision';
  END IF;
END;
$$;

-- Same key with changed canonical payload must fail and leave the original intact.
DO $same_key_mismatch$
BEGIN
  PERFORM public.append_project_official_decision(
    :'project_bom_item_id'::uuid, 'project-bom', 'project-bom-note', :'project_bom_revision',
    'Changed note.', NULL, NULL, NULL, '[]'::jsonb, :'request_key'::uuid
  );
  RAISE EXCEPTION 'Expected request-key canonical mismatch rejection';
EXCEPTION WHEN OTHERS THEN
  IF SQLERRM NOT LIKE '%Request key conflicts%' THEN RAISE; END IF;
END;
$same_key_mismatch$;

-- Stale revisions must fail before any decision/evidence/receipt append.
DO $stale_revision$
BEGIN
  PERFORM public.append_project_official_decision(
    :'project_bom_item_id'::uuid, 'project-bom', 'project-bom-note', 'stale-revision',
    'Stale note.', NULL, NULL, NULL, '[]'::jsonb, :'conflicting_request_key'::uuid
  );
  RAISE EXCEPTION 'Expected stale source revision rejection';
EXCEPTION WHEN OTHERS THEN
  IF SQLERRM NOT LIKE '%revision conflict%' THEN RAISE; END IF;
END;
$stale_revision$;

-- Direct table mutation must fail for the authenticated actor.
DO $direct_write$
BEGIN
  INSERT INTO public.project_official_decisions (
    project_id, project_bom_id, project_bom_item_id, source_page_reference,
    action_intent, expected_source_revision, note, actor_user_id
  ) SELECT project_id, project_bom_id, project_bom_item_id, 'project-bom',
    'project-bom-note', :'project_bom_revision', 'Direct write must fail.', :'manager_user_id'::uuid
  FROM public.project_official_decisions LIMIT 1;
  RAISE EXCEPTION 'Expected direct decision insertion denial';
EXCEPTION WHEN insufficient_privilege THEN NULL;
END;
$direct_write$;

-- The following caller tests require the deployment-gated exact project-scoped
-- read policy. They are intentionally pending because verified current project
-- reads are permission-wide rather than member-scoped:
--   1. same-project reader sees only the fixture decision and evidence;
--   2. cross-project reader and outsider see no rows and cannot distinguish IDs;
--   3. a different actor cannot replay manager_user_id's request_key;
--   4. an amendment locks the exact parent/source, preserves earlier text, and
--      rejects a parent from another project or BOM item;
--   5. forced evidence/receipt insert failure rolls back the decision append;
--   6. two-session same-key race returns one receipt and one decision;
--   7. every future Hardware/Purchase/Sales action intent fails closed until
--      independently verified department-specific authority is installed.

ROLLBACK;