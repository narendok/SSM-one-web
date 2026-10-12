-- REVIEW ONLY: do not execute through an installer or migration runner.
-- All statements are read-only and intentionally return evidence for root review.
BEGIN READ ONLY;
SELECT current_database(), current_user, version();
SELECT extname, extversion FROM pg_extension WHERE extname IN ('pgcrypto','uuid-ossp');
SELECT n.nspname AS schema_name, c.relname AS relation_name, a.attname AS column_name, pg_catalog.format_type(a.atttypid,a.atttypmod) AS column_type, a.attnotnull
FROM pg_attribute a JOIN pg_class c ON c.oid=a.attrelid JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname IN ('public','storage') AND c.relname IN ('objects','sales_opportunities','customers','sales_opportunity_document_locations','master_specifications','master_specification_versions','sales_project_handovers','requirement_baselines','customer_requirements','drive_nodes','drive_node_revisions','document_control_registers','employees','employee_departments','projects','project_team_members','department_process_templates') AND a.attnum>0 AND NOT a.attisdropped
ORDER BY 1,2,3;
SELECT p.oid::regprocedure AS signature, pg_get_functiondef(p.oid) AS definition, pg_get_userbyid(p.proowner) AS owner
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public' AND p.proname IN ('resolve_sales_opportunity_structured_draft_location','resolve_sales_structured_docx_assignment','can_stage_sales_structured_docx_object','can_read_sales_structured_docx_object','can_access_sales_structured_draft_object','lifecycle_actor','lifecycle_can_manage_department') ORDER BY 1;
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies WHERE (schemaname='storage' AND tablename='objects') OR (schemaname='public' AND tablename IN ('drive_nodes','drive_node_revisions','document_control_registers','sales_opportunity_document_locations')) ORDER BY 1,2,3;
SELECT routine_schema, routine_name, privilege_type, grantee FROM information_schema.routine_privileges WHERE routine_schema='public' AND routine_name LIKE '%docx%' ORDER BY 1,2,4;
SELECT table_schema, table_name, grantee, privilege_type FROM information_schema.role_table_grants WHERE table_schema IN ('public','storage') AND table_name IN ('objects','drive_nodes','drive_node_revisions','document_control_registers') ORDER BY 1,2,3,4;
SELECT o.id AS opportunity_id,o.opportunity_number,o.customer_id,c.customer_code,c.legal_name,o.status,
  ms.id AS master_id,ms.specification_number,ms.current_version,mv.id AS master_revision_id,mv.version_number,mv.status AS master_revision_status,
  handover.id AS handover_id,handover.project_id,handover.status AS handover_status
FROM public.sales_opportunities o
JOIN public.customers c ON c.id=o.customer_id
LEFT JOIN public.master_specifications ms ON ms.opportunity_id=o.id AND ms.customer_id=o.customer_id
LEFT JOIN public.master_specification_versions mv ON mv.specification_id=ms.id AND mv.version_number=ms.current_version
LEFT JOIN public.customer_requirements requirement ON requirement.opportunity_id=o.id AND requirement.customer_id=o.customer_id
LEFT JOIN public.requirement_baselines baseline ON baseline.customer_requirement_id=requirement.id
LEFT JOIN public.sales_project_handovers handover ON handover.baseline_id=baseline.id
WHERE o.opportunity_number='OPPORTUNITY-2026-0013';
-- The first install cannot require rows in the pending registry tables. Review the
-- existing source/handover rows above, install only after approval, then configure
-- Sales-before-handover or handed-over-project assignments and immutable pins.
SELECT * FROM public.sales_opportunity_document_locations WHERE is_active IS TRUE ORDER BY updated_at DESC NULLS LAST LIMIT 100;
ROLLBACK;
