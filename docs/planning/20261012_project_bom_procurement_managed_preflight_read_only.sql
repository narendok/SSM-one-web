-- READ-ONLY PROCUREMENT REVIEW PREFLIGHT. DO NOT APPLY OR MODIFY DATA.
-- This query only reports exact pending-contract deployment state and prerequisite shape.
WITH targets(schema_name, object_name) AS (VALUES
  ('public','project_bom_procurement_review_requests'),
  ('public','project_bom_procurement_review_request_lines'),
  ('public','project_bom_procurement_review_analyses'),
  ('public','project_bom_procurement_review_receipts'),
  ('public','project_bom_procurement_review_audit_events')
), functions(function_name) AS (VALUES
  ('submit_project_bom_procurement_review'),
  ('analyze_project_bom_procurement_review'),
  ('decide_project_bom_procurement_review'),
  ('read_project_bom_procurement_review')
)
SELECT jsonb_build_object(
  'preflight_type','project_bom_procurement_review_read_only',
  'database', current_database(),
  'execution_identity', current_user,
  'checked_at_utc', now(),
  'deployed_tables', (SELECT coalesce(jsonb_agg(jsonb_build_object('schema', schema_name, 'table', object_name, 'exists', to_regclass(format('%I.%I', schema_name, object_name)) IS NOT NULL) ORDER BY object_name), '[]'::jsonb) FROM targets),
  'deployed_functions', (SELECT coalesce(jsonb_agg(jsonb_build_object('name', function_name, 'signatures', coalesce(signatures, '[]'::jsonb)) ORDER BY function_name), '[]'::jsonb) FROM functions f LEFT JOIN LATERAL (SELECT jsonb_agg(jsonb_build_object('identity_arguments', pg_get_function_identity_arguments(p.oid), 'security_definer', p.prosecdef, 'acl', coalesce(p.proacl::text, 'NULL')) ORDER BY pg_get_function_identity_arguments(p.oid)) AS signatures FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname=f.function_name) fn ON true),
  'prerequisite_columns', (SELECT coalesce(jsonb_agg(jsonb_build_object('table', table_name, 'column', column_name, 'data_type', data_type, 'nullable', is_nullable) ORDER BY table_name, ordinal_position), '[]'::jsonb) FROM information_schema.columns WHERE table_schema='public' AND (table_name, column_name) IN (('projects','project_manager_employee_id'),('project_boms','revision'),('project_boms','updated_at'),('project_bom_items','bom_id'),('project_bom_items','matched_component_id'),('components','part_number'),('components','manufacturer'),('components','name'),('employees','user_id'),('employees','employment_status'),('employee_departments','employee_id'),('employee_departments','department_id'),('departments','code'),('departments','is_active'),('project_team_members','project_id'),('project_team_members','employee_id'))),
  'permission_function', (SELECT coalesce(jsonb_agg(jsonb_build_object('identity_arguments', pg_get_function_identity_arguments(p.oid), 'security_definer', p.prosecdef, 'acl', coalesce(p.proacl::text, 'NULL'))), '[]'::jsonb) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='has_permission')
) AS result;
