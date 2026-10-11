\set ON_ERROR_STOP on
SET ROLE authenticated;
-- same-company project member: own project gates + peer team, not another-company project
SELECT set_config('request.jwt.claim.sub', '40000000-0000-4000-8000-000000000001', false);
DO $$ BEGIN
  IF (SELECT count(*) FROM public.project_stage_gates) <> 1 OR EXISTS (SELECT 1 FROM public.project_stage_gates WHERE gate_code = 'GATE-B') THEN RAISE EXCEPTION 'same-project member gate scope changed'; END IF;
  IF (SELECT count(*) FROM public.project_team_members) <> 3 THEN RAISE EXCEPTION 'same-project peer team scope changed'; END IF;
END $$;
-- unrelated-company nonmember: no gates or team rows
SELECT set_config('request.jwt.claim.sub', '40000000-0000-4000-8000-000000000002', false);
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM public.project_stage_gates) OR EXISTS (SELECT 1 FROM public.project_team_members) THEN RAISE EXCEPTION 'unrelated company nonmember gained access'; END IF;
END $$;
-- projects.view path: both projects remain visible, exactly as existing policy semantics
SELECT set_config('request.jwt.claim.sub', '40000000-0000-4000-8000-000000000003', false);
DO $$ BEGIN
  IF (SELECT count(*) FROM public.project_stage_gates) <> 2 OR EXISTS (SELECT 1 FROM public.project_team_members) THEN RAISE EXCEPTION 'projects.view gate/team access changed'; END IF;
END $$;
-- admin path: both projects remain visible
SELECT set_config('request.jwt.claim.sub', '40000000-0000-4000-8000-000000000004', false);
DO $$ BEGIN
  IF (SELECT count(*) FROM public.project_stage_gates) <> 2 OR (SELECT count(*) FROM public.project_team_members) <> 4 THEN RAISE EXCEPTION 'admin access changed'; END IF;
END $$;
-- Direct employee self-row access is preserved exactly; the helper is tested separately for active membership only.
SELECT set_config('request.jwt.claim.sub', '40000000-0000-4000-8000-000000000005', false);
DO $$ BEGIN
  IF (SELECT count(*) FROM public.project_team_members) <> 1 THEN RAISE EXCEPTION 'inactive self-row access changed'; END IF;
END $$;
RESET ROLE;
-- anon has no table SELECT or helper EXECUTE privileges.
SET ROLE anon;
DO $$ BEGIN
  BEGIN PERFORM * FROM public.project_stage_gates; RAISE EXCEPTION 'anon unexpectedly read gates'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN PERFORM public.has_project_team_membership('40000000-0000-4000-8000-000000000001', '50000000-0000-4000-8000-000000000001'); RAISE EXCEPTION 'anon unexpectedly executed helper'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
-- Authenticated EXECUTE is required for RLS policy evaluation. The function has no mutation path and returns only a boolean membership fact.
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '40000000-0000-4000-8000-000000000002', false);
DO $$ BEGIN
  IF public.has_project_team_membership('40000000-0000-4000-8000-000000000002', '50000000-0000-4000-8000-000000000001') THEN RAISE EXCEPTION 'helper returned a false membership fact'; END IF;
END $$;
RESET ROLE;
SELECT 'PROJECT_STAGE_GATES_RLS_LOCAL_ACCEPTANCE_PASS' AS result;
