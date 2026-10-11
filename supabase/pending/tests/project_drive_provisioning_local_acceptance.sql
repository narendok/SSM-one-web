-- LOCAL DISPOSABLE acceptance assertions only. Applies after the pending SQL.
\set ON_ERROR_STOP on

CREATE OR REPLACE FUNCTION public.fixture_assert(p_condition boolean, p_message text)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF NOT p_condition THEN RAISE EXCEPTION 'LOCAL_ASSERT_FAIL: %', p_message; END IF;
END;
$$;

-- Repeat provisioning must retain one authoritative root, pointer, and folder set.
SELECT public.provision_project_drive_template('00000000-0000-4000-8000-000000000101'::uuid);
SELECT public.provision_project_drive_template('00000000-0000-4000-8000-000000000101'::uuid);
DO $$
DECLARE v_root uuid; v_root_count integer; v_folder_count integer;
BEGIN
  SELECT project_drive_node_id INTO v_root FROM public.projects WHERE id = '00000000-0000-4000-8000-000000000101';
  SELECT count(*) INTO v_root_count FROM public.drive_nodes WHERE project_id = '00000000-0000-4000-8000-000000000101' AND folder_kind = 'PROJECT_ROOT' AND is_trashed = false;
  SELECT count(*) INTO v_folder_count FROM public.drive_nodes WHERE project_id = '00000000-0000-4000-8000-000000000101' AND parent_id = v_root AND folder_kind = 'STANDARD' AND is_trashed = false;
  PERFORM public.fixture_assert(v_root IS NOT NULL, 'repeat pointer missing');
  PERFORM public.fixture_assert(v_root_count = 1, 'repeat root count must be one');
  PERFORM public.fixture_assert(v_folder_count = 8, 'repeat standard folder count must be eight');
  RAISE NOTICE 'NAMED_PASS repeat_same_root_pointer root=% folders=%', v_root, v_folder_count;
END;
$$;

-- A pointer to a root owned by another project must fail without changing either manual node.
INSERT INTO public.drive_nodes(id, project_id, department_id, parent_id, name, slug, node_type, is_locked, folder_kind, metadata)
VALUES ('00000000-0000-4000-8000-000000000201', '00000000-0000-4000-8000-000000000101', '00000000-0000-4000-8000-000000000010', NULL, 'Manual other root', 'manual-other-root', 'FOLDER', false, 'PROJECT_ROOT', '{"manual":true}');
UPDATE public.projects SET project_drive_node_id = '00000000-0000-4000-8000-000000000201' WHERE id = '00000000-0000-4000-8000-000000000103';
DO $$
BEGIN
  BEGIN
    PERFORM public.provision_project_drive_template('00000000-0000-4000-8000-000000000103');
    RAISE EXCEPTION 'LOCAL_ASSERT_FAIL: wrong-project pointer should fail';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE 'Project Drive root pointer conflicts%' THEN RAISE; END IF;
  END;
  PERFORM public.fixture_assert((SELECT project_drive_node_id = '00000000-0000-4000-8000-000000000201'::uuid FROM public.projects WHERE id = '00000000-0000-4000-8000-000000000103'), 'wrong-project pointer changed');
  PERFORM public.fixture_assert((SELECT metadata = '{"manual":true}'::jsonb AND is_locked = false FROM public.drive_nodes WHERE id = '00000000-0000-4000-8000-000000000201'), 'manual wrong-project node changed');
  PERFORM public.fixture_assert((SELECT count(*) = 0 FROM public.drive_nodes WHERE project_id = '00000000-0000-4000-8000-000000000103'), 'wrong-project failure wrote nodes');
  RAISE NOTICE 'NAMED_PASS wrong_project_pointer_preserves_manual_history';
END;
$$;

-- A trashed pointer cannot be silently replaced; failed transaction preserves it and creates no root.
INSERT INTO public.drive_nodes(id, project_id, department_id, parent_id, name, slug, node_type, is_locked, folder_kind, is_trashed, metadata)
VALUES ('00000000-0000-4000-8000-000000000202', '00000000-0000-4000-8000-000000000103', '00000000-0000-4000-8000-000000000010', NULL, 'Historical trashed root', 'historical-trashed-root', 'FOLDER', false, 'PROJECT_ROOT', true, '{"historical":true}');
UPDATE public.projects SET project_drive_node_id = '00000000-0000-4000-8000-000000000202' WHERE id = '00000000-0000-4000-8000-000000000103';
DO $$
BEGIN
  BEGIN
    PERFORM public.provision_project_drive_template('00000000-0000-4000-8000-000000000103');
    RAISE EXCEPTION 'LOCAL_ASSERT_FAIL: trashed pointer should fail';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE 'Project Drive root pointer conflicts%' THEN RAISE; END IF;
  END;
  PERFORM public.fixture_assert((SELECT project_drive_node_id = '00000000-0000-4000-8000-000000000202'::uuid FROM public.projects WHERE id = '00000000-0000-4000-8000-000000000103'), 'trashed pointer changed');
  PERFORM public.fixture_assert((SELECT is_trashed AND metadata = '{"historical":true}'::jsonb FROM public.drive_nodes WHERE id = '00000000-0000-4000-8000-000000000202'), 'trashed history changed');
  PERFORM public.fixture_assert((SELECT count(*) = 1 FROM public.drive_nodes WHERE project_id = '00000000-0000-4000-8000-000000000103'), 'trashed conflict wrote replacement nodes');
  RAISE NOTICE 'NAMED_PASS trashed_pointer_preserves_history';
END;
$$;

-- Injected category failure rolls back created root, pointer, and folders.
DO $$
BEGIN
  PERFORM set_config('fixture.fail_category', 'on', true);
  BEGIN
    PERFORM public.provision_project_drive_template('00000000-0000-4000-8000-000000000104');
    RAISE EXCEPTION 'LOCAL_ASSERT_FAIL: injected failure should propagate';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE 'Injected category failure%' THEN RAISE; END IF;
  END;
  PERFORM public.fixture_assert((SELECT project_drive_node_id IS NULL FROM public.projects WHERE id = '00000000-0000-4000-8000-000000000104'), 'rollback pointer persisted');
  PERFORM public.fixture_assert((SELECT count(*) = 0 FROM public.drive_nodes WHERE project_id = '00000000-0000-4000-8000-000000000104'), 'rollback nodes persisted');
  RAISE NOTICE 'NAMED_PASS injected_failure_rolls_back_pointer_and_folders';
END;
$$;

DROP FUNCTION public.fixture_assert(boolean, text);