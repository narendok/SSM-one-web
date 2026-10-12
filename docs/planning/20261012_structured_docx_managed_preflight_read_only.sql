-- REVIEW ONLY: do not execute through an installer or migration runner.
-- The final SELECT returns one JSON evidence document because some managed
-- runners display only their final result. It is read-only and targets only
-- OPPORTUNITY-2026-0013 / MASTER-2026-0001 and its exact locations.
BEGIN READ ONLY;

WITH
schema_columns AS (
  SELECT jsonb_agg(jsonb_build_object(
    'schema', table_schema, 'table', table_name, 'column', column_name,
    'type', data_type, 'nullable', is_nullable
  ) ORDER BY table_schema, table_name, ordinal_position) AS value
  FROM information_schema.columns
  WHERE (table_schema='storage' AND table_name='objects')
     OR (table_schema='public' AND table_name IN (
       'sales_opportunities','customers','sales_opportunity_document_locations',
       'master_specifications','master_specification_versions','sales_project_handovers',
       'requirement_baselines','customer_requirements','drive_nodes','drive_node_revisions',
       'document_control_registers','employees','employee_departments','projects',
       'project_team_members','department_process_templates'
     ))
),
constraints AS (
  SELECT jsonb_agg(jsonb_build_object(
    'table', relation_name, 'name', constraint_name, 'definition', definition
  ) ORDER BY relation_name, constraint_name) AS value
  FROM (
    SELECT c.relname AS relation_name, con.conname AS constraint_name,
      pg_get_constraintdef(con.oid) AS definition
    FROM pg_constraint con
    JOIN pg_class c ON c.oid=con.conrelid
    WHERE con.connamespace='public'::regnamespace
      AND con.conrelid IN (
        'public.sales_opportunity_document_locations'::regclass,
        'public.sales_project_handovers'::regclass,
        'public.requirement_baselines'::regclass,
        'public.master_specifications'::regclass,
        'public.master_specification_versions'::regclass
      )
  ) definitions
),
function_definitions AS (
  SELECT jsonb_object_agg(signature, definition) AS value
  FROM (
    SELECT p.oid::regprocedure::text AS signature, pg_get_functiondef(p.oid) AS definition
    FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='public' AND p.proname IN (
      'resolve_sales_opportunity_structured_draft_location',
      'can_access_sales_structured_draft_object',
      'lifecycle_actor','lifecycle_can_manage_department'
    )
  ) functions
),
policies AS (
  SELECT coalesce(jsonb_agg(jsonb_build_object(
    'schema',schemaname,'table',tablename,'name',policyname,'permissive',permissive,
    'roles',roles,'command',cmd,'using',qual,'with_check',with_check
  ) ORDER BY schemaname,tablename,policyname),'[]'::jsonb) AS value
  FROM pg_policies
  WHERE (schemaname='storage' AND tablename='objects')
     OR (schemaname='public' AND tablename IN (
       'drive_nodes','drive_node_revisions','document_control_registers',
       'sales_opportunity_document_locations'
     ))
),
grants AS (
  SELECT coalesce(jsonb_agg(jsonb_build_object(
    'schema',table_schema,'table',table_name,'grantee',grantee,'privilege',privilege_type
  ) ORDER BY table_schema,table_name,grantee,privilege_type),'[]'::jsonb) AS value
  FROM information_schema.role_table_grants
  WHERE (table_schema='storage' AND table_name='objects')
     OR (table_schema='public' AND table_name IN (
       'drive_nodes','drive_node_revisions','document_control_registers',
       'sales_opportunity_document_locations'
     ))
),
source_0013 AS (
  SELECT coalesce(jsonb_agg(to_jsonb(source_row) ORDER BY source_row.handover_id),'[]'::jsonb) AS value
  FROM (
    SELECT o.id AS opportunity_id,o.opportunity_number,o.customer_id,c.customer_code,c.legal_name,o.status AS opportunity_status,
      ms.id AS master_id,ms.specification_number,ms.current_version,
      mv.id AS master_revision_id,mv.version_number,mv.status AS master_revision_status,
      h.id AS handover_id,h.project_id,h.status AS handover_status,h.initiated_at AS handover_initiated_at
    FROM public.sales_opportunities o
    JOIN public.customers c ON c.id=o.customer_id
    LEFT JOIN public.master_specifications ms ON ms.opportunity_id=o.id AND ms.customer_id=o.customer_id
    LEFT JOIN public.master_specification_versions mv ON mv.specification_id=ms.id AND mv.version_number=ms.current_version
    LEFT JOIN public.customer_requirements r ON r.opportunity_id=o.id AND r.customer_id=o.customer_id
    LEFT JOIN public.requirement_baselines b ON b.requirement_id=r.id
    LEFT JOIN public.sales_project_handovers h ON h.baseline_id=b.id
    WHERE o.opportunity_number='OPPORTUNITY-2026-0013'
      AND ms.specification_number='MASTER-2026-0001'
  ) source_row
),
location_0013 AS (
  SELECT coalesce(jsonb_agg(to_jsonb(location_row) ORDER BY location_row.created_at,location_row.id),'[]'::jsonb) AS value
  FROM (
    SELECT l.id,l.opportunity_id,l.customer_id,l.department_id,l.location_purpose,l.status,
      l.drive_root_node_id,l.target_folder_node_id,l.private_storage_bucket,
      l.private_storage_prefix,l.authorized_by,l.authorized_at,l.created_at
    FROM public.sales_opportunity_document_locations l
    JOIN public.sales_opportunities o ON o.id=l.opportunity_id
    WHERE o.opportunity_number='OPPORTUNITY-2026-0013'
  ) location_row
),
checks AS (
  SELECT jsonb_build_object(
    'requirement_baselines_requirement_id', EXISTS (
      SELECT 1 FROM information_schema.columns WHERE table_schema='public'
        AND table_name='requirement_baselines' AND column_name='requirement_id'
    ),
    'location_status', EXISTS (
      SELECT 1 FROM information_schema.columns WHERE table_schema='public'
        AND table_name='sales_opportunity_document_locations' AND column_name='status'
    ),
    'location_purpose', EXISTS (
      SELECT 1 FROM information_schema.columns WHERE table_schema='public'
        AND table_name='sales_opportunity_document_locations' AND column_name='location_purpose'
    ),
    'location_is_active_absent', NOT EXISTS (
      SELECT 1 FROM information_schema.columns WHERE table_schema='public'
        AND table_name='sales_opportunity_document_locations' AND column_name='is_active'
    ),
    'exact_source_present', EXISTS (
      SELECT 1 FROM public.sales_opportunities o
      JOIN public.master_specifications ms ON ms.opportunity_id=o.id
      JOIN public.master_specification_versions mv ON mv.specification_id=ms.id AND mv.version_number=ms.current_version
      WHERE o.opportunity_number='OPPORTUNITY-2026-0013'
        AND ms.specification_number='MASTER-2026-0001'
        AND mv.version_number=1
    )
  ) AS value
)
SELECT jsonb_build_object(
  'review_only',true,
  'database',current_database(),
  'extensions',(SELECT coalesce(jsonb_agg(jsonb_build_object('name',extname,'version',extversion) ORDER BY extname),'[]'::jsonb) FROM pg_extension WHERE extname IN ('pgcrypto','uuid-ossp')),
  'schema_columns',(SELECT value FROM schema_columns),
  'constraints',(SELECT value FROM constraints),
  'function_definitions',(SELECT coalesce(value,'{}'::jsonb) FROM function_definitions),
  'policies',(SELECT value FROM policies),
  'grants',(SELECT value FROM grants),
  'source_0013',(SELECT value FROM source_0013),
  'locations_0013',(SELECT value FROM location_0013),
  'checks',(SELECT value FROM checks)
) AS structured_docx_preflight_evidence;
ROLLBACK;