-- REVIEW-ONLY / DO NOT EXECUTE.
-- Manual-install review artifact for the 42P17 repair.
-- It intentionally does not touch drizzle.__drizzle_migrations and does not invoke the
-- full-set migration runner. Run only after separate action-time approval.

BEGIN;

-- PRE-FLIGHT: record the exact managed state before any replacement.
SELECT c.relname AS table_name,
       pol.polname AS policy_name,
       pg_get_expr(pol.polqual, pol.polrelid) AS using_predicate,
       pg_get_expr(pol.polwithcheck, pol.polrelid) AS with_check_predicate,
       array_to_string(pol.polroles::regrole[], ', ') AS roles
FROM pg_policy pol
JOIN pg_class c ON c.oid = pol.polrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND ((c.relname = 'project_team_members' AND pol.polname = 'Project members view their project team')
    OR (c.relname = 'project_stage_gates' AND pol.polname = 'Project team view stage gates'))
ORDER BY c.relname;

-- ABORT unless the pre-flight output matches the originals documented in the companion
-- review proposal and owner/BYPASSRLS review is accepted; then execute the exact payload.
CREATE OR REPLACE FUNCTION public.has_project_team_membership(
  _actor_id uuid,
  _project_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.project_team_members membership
    JOIN public.employees member_employee
      ON member_employee.id = membership.employee_id
    WHERE auth.uid() IS NOT NULL
      AND _actor_id = auth.uid()
      AND membership.project_id = _project_id
      AND member_employee.user_id = _actor_id
  )
$$;

REVOKE ALL ON FUNCTION public.has_project_team_membership(uuid, uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.has_project_team_membership(uuid, uuid)
  TO authenticated;

DROP POLICY "Project members view their project team" ON public.project_team_members;
CREATE POLICY "Project members view their project team"
  ON public.project_team_members
  FOR SELECT
  TO authenticated
  USING (
    public.has_role(auth.uid(), 'admin')
    OR public.has_permission(auth.uid(), 'projects.manage')
    OR EXISTS (
      SELECT 1
      FROM public.employees viewer
      WHERE viewer.user_id = auth.uid()
        AND viewer.id = project_team_members.employee_id
    )
    OR public.has_project_team_membership(auth.uid(), project_team_members.project_id)
  );

DROP POLICY "Project team view stage gates" ON public.project_stage_gates;
CREATE POLICY "Project team view stage gates"
  ON public.project_stage_gates
  FOR SELECT
  TO authenticated
  USING (
    public.has_role(auth.uid(), 'admin')
    OR public.has_permission(auth.uid(), 'projects.view')
    OR public.has_project_team_membership(auth.uid(), project_stage_gates.project_id)
  );

-- POST-FLIGHT: record owner/security/search_path/ACL and exact replacement predicates.
SELECT pg_get_userbyid(p.proowner) AS owner,
       p.prosecdef AS security_definer,
       p.proconfig AS function_config,
       p.proacl AS function_acl,
       pg_get_functiondef(p.oid) AS function_definition
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'has_project_team_membership'
  AND pg_get_function_identity_arguments(p.oid) = '_actor_id uuid, _project_id uuid';

SELECT c.relname AS table_name,
       pol.polname AS policy_name,
       pg_get_expr(pol.polqual, pol.polrelid) AS using_predicate,
       array_to_string(pol.polroles::regrole[], ', ') AS roles
FROM pg_policy pol
JOIN pg_class c ON c.oid = pol.polrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND ((c.relname = 'project_team_members' AND pol.polname = 'Project members view their project team')
    OR (c.relname = 'project_stage_gates' AND pol.polname = 'Project team view stage gates'))
ORDER BY c.relname;

-- No COMMIT: this review artifact must be manually inspected and explicitly committed only
-- within an approved, supported action-time installation procedure.
ROLLBACK;