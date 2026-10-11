-- LOCAL DISPOSABLE lock-wait worker only. Synthetic auth GUCs do not model
-- managed JWT, RLS, grants, or backend connection behavior.
\set ON_ERROR_STOP on
SET application_name = 'bom_candidate_decision_revocation_waiter';
SELECT set_config('request.jwt.claim.sub', '30000000-0000-4000-8000-000000000002', false) \g /dev/null
SELECT 'LOCAL_WORKER_PREWAIT auth_uid=' || auth.uid()
  || ' has_permission=' || public.has_permission(auth.uid(), 'engineering.approve')
  || ' active_hardware_membership=' || EXISTS (
    SELECT 1
    FROM public.employees employee
    JOIN public.employee_departments membership ON membership.employee_id = employee.id
    JOIN public.departments department ON department.id = membership.department_id
    WHERE employee.user_id = auth.uid()
      AND employee.employment_status = 'ACTIVE'
      AND department.code = 'HARDWARE'
      AND department.is_active
  )
  || ' scope_rows=' || (
    SELECT count(*)
    FROM public.component_candidate_decision_scope(auth.uid(), :'candidate_id'::uuid, :'revision_id'::uuid)
  );
SELECT * FROM public.decide_component_candidate(
  :'candidate_id'::uuid,
  :'revision_id'::uuid,
  :'decision',
  :'decision_note',
  :'request_key'::uuid
);