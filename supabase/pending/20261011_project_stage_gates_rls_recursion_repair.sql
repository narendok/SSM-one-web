-- REVIEW-ONLY / UNAPPLIED. Minimal repair for project_stage_gates /
-- project_team_members SELECT-policy recursion. No table, data, grant, or role change.

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
    WHERE membership.project_id = _project_id
      AND member_employee.user_id = _actor_id
      AND member_employee.employment_status = 'ACTIVE'
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
