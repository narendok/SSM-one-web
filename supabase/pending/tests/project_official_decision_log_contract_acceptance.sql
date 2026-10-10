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
-- No case is executable until the deployment gate in the companion source-only
-- SQL is replaced by a reviewed exact project-membership/source-action contract.

\set ON_ERROR_STOP on

BEGIN;
SELECT set_config('request.jwt.claim.sub', :'manager_user_id', true);
SELECT set_config('request.jwt.claim.role', 'authenticated', false);
SELECT set_config('project_official_decision.test.manager_user_id', :'manager_user_id', true);
SELECT set_config('project_official_decision.test.cross_project_reader_user_id', :'cross_project_reader_user_id', true);
SELECT set_config('project_official_decision.test.outsider_user_id', :'outsider_user_id', true);
SELECT set_config('project_official_decision.test.project_bom_item_id', :'project_bom_item_id', true);
SELECT set_config('project_official_decision.test.project_bom_revision', :'project_bom_revision', true);
SELECT set_config('project_official_decision.test.request_key', :'request_key', true);
SELECT set_config('project_official_decision.test.conflicting_request_key', :'conflicting_request_key', true);

CREATE TEMP TABLE official_decision_first AS
SELECT public.append_project_official_decision(
  :'project_bom_item_id'::uuid,
  NULL,
  jsonb_build_object(
    'actionIntent', 'project-bom-note',
    'sourcePageReference', 'project-bom',
    'expectedSourceRevision', :'project_bom_revision',
    'note', 'Bench review confirmed.',
    'evidenceReferences', jsonb_build_array(jsonb_build_object(
      'evidenceReference', 'evidence-1', 'contributorReference', 'contributor-1', 'scopeReference', 'project-bom'
    )),
    'alternativeReference', NULL,
    'exceptionReference', NULL
  ),
  :'request_key'::uuid
) AS decision_id;

-- Exact actor + canonical payload replay returns one immutable result.
CREATE TEMP TABLE official_decision_replay AS
SELECT public.append_project_official_decision(
  :'project_bom_item_id'::uuid, NULL, jsonb_build_object(
    'actionIntent', 'project-bom-note', 'sourcePageReference', 'project-bom',
    'expectedSourceRevision', :'project_bom_revision', 'note', 'Bench review confirmed.',
    'evidenceReferences', jsonb_build_array(jsonb_build_object(
      'evidenceReference', 'evidence-1', 'contributorReference', 'contributor-1', 'scopeReference', 'project-bom'
    )), 'alternativeReference', NULL, 'exceptionReference', NULL
  ),
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
-- Pending until the append deployment gate is enabled: run the request-key
-- mismatch check in a separate reviewed fixture. psql variables must be passed
-- into any DO block through transaction-local settings, not :variables.

-- Stale revisions must fail before any decision/evidence/receipt append.
-- Pending until the append deployment gate is enabled: run the stale-revision
-- check only in the reviewed fixture that grants the protected append action.

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


-- Genuine role-bound denials (not only forged JWT claims) required after the
-- deployment gate is resolved. Run each with an isolated login/session fixture.
-- SET LOCAL ROLE authenticated removes table/function owner privileges; every
-- expected denial is caught, an unexpected success raises, and the transaction
-- remains available for the final ROLLBACK.
DO $role_bound_denials$
DECLARE
  v_before_decisions bigint;
  v_before_evidence bigint;
  v_before_receipts bigint;
  v_cross_project_reader_user_id uuid := current_setting('project_official_decision.test.cross_project_reader_user_id')::uuid;
  v_outsider_user_id uuid := current_setting('project_official_decision.test.outsider_user_id')::uuid;
  v_project_bom_item_id uuid := current_setting('project_official_decision.test.project_bom_item_id')::uuid;
  v_project_bom_revision text := current_setting('project_official_decision.test.project_bom_revision');
  v_conflicting_request_key uuid := current_setting('project_official_decision.test.conflicting_request_key')::uuid;
BEGIN
  SELECT count(*) INTO v_before_decisions FROM public.project_official_decisions;
  SELECT count(*) INTO v_before_evidence FROM public.project_official_decision_evidence;
  SELECT count(*) INTO v_before_receipts FROM public.project_official_decision_receipts;

  SET LOCAL ROLE authenticated;
  PERFORM set_config('request.jwt.claim.sub', v_cross_project_reader_user_id::text, true);
  BEGIN
    PERFORM public.append_project_official_decision(
      v_project_bom_item_id, NULL, jsonb_build_object(
        'actionIntent', 'project-bom-note', 'sourcePageReference', 'project-bom',
        'expectedSourceRevision', v_project_bom_revision, 'note', 'Cross-project denial.',
        'evidenceReferences', '[]'::jsonb, 'alternativeReference', NULL, 'exceptionReference', NULL
      ), v_conflicting_request_key
    );
    RAISE EXCEPTION 'Expected cross-project append denial';
  EXCEPTION WHEN insufficient_privilege THEN
    IF SQLSTATE <> '42501' THEN
      RAISE EXCEPTION 'Expected SQLSTATE 42501 for revoked append EXECUTE, received %', SQLSTATE;
    END IF;
  END;

  PERFORM set_config('request.jwt.claim.sub', v_outsider_user_id::text, true);
  BEGIN
    PERFORM 1 FROM public.project_official_decision_log;
    RAISE EXCEPTION 'Expected outsider view SELECT privilege denial';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  BEGIN
    INSERT INTO public.project_official_decisions (
      project_id, project_bom_id, project_bom_item_id, source_page_reference,
      action_intent, expected_source_revision, note, actor_user_id
    ) VALUES (
      '00000000-0000-0000-0000-000000000000'::uuid,
      '00000000-0000-0000-0000-000000000000'::uuid,
      v_project_bom_item_id, 'project-bom', 'project-bom-note',
      v_project_bom_revision, 'Outsider direct write.', v_outsider_user_id
    );
    RAISE EXCEPTION 'Expected outsider direct-write privilege denial';
  EXCEPTION WHEN insufficient_privilege THEN
    IF SQLSTATE <> '42501' THEN
      RAISE EXCEPTION 'Expected SQLSTATE 42501 for direct-write denial, received %', SQLSTATE;
    END IF;
  END;

  RESET ROLE;
  IF (SELECT count(*) FROM public.project_official_decisions) <> v_before_decisions
     OR (SELECT count(*) FROM public.project_official_decision_evidence) <> v_before_evidence
     OR (SELECT count(*) FROM public.project_official_decision_receipts) <> v_before_receipts THEN
    RAISE EXCEPTION 'Role-bound denial changed append-only decision history';
  END IF;
END;
$role_bound_denials$;

-- Repeat with membership/permission removed between target locking and receipt
-- lookup once the source-action deployment gate is resolved; it must deny before
-- replay or write and preserve all three row counts.

-- The following caller tests require the deployment-gated exact project-scoped
-- read policy. They are intentionally pending because verified current project
-- reads are permission-wide rather than member-scoped:
--   1. same-project reader sees only the fixture decision and evidence;
--   2. cross-project reader and outsider receive SELECT privilege denial while
--      caller-view SELECT remains revoked; a later granted projection must return
--      no rows without distinguishing IDs;
--   3. a different actor cannot replay manager_user_id's request_key;
--   4. an amendment locks the exact parent/source, preserves earlier text, and
--      rejects a parent from another project or BOM item;
--   5. forced evidence/receipt insert failure rolls back the decision append;
--   6. two-session same-key race returns one receipt and one decision;
--   7. arbitrary Hardware/Purchase/Sales action intents fail closed and cannot
--      impersonate a separately authorized decision;
--   8. non-string evidence fields and unresolved contributor provenance deny;
--   9. canonical SQL/TypeScript parity and concurrent amendment-chain behavior
--      remain blocked for a subsequent dedicated review group.

ROLLBACK;