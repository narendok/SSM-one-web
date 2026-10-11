-- REVIEW-ONLY READ-ONLY PREFLIGHT. DO NOT CHANGE DATA, POLICIES, ACLS, OR THE MIGRATION JOURNAL.
-- Run this entire script separately in the Cloud SQL editor before action-time approval.
-- Any missing prerequisite, unexpected existing Sales relation, policy/ACL mismatch, or non-singleton source tuple stops installation.

BEGIN READ ONLY;

-- 1. Execution identity, target database, and migration-journal visibility only.
SELECT current_database() AS database_name, current_user AS execution_role,
       to_regclass('public.organizations') AS organizations_relation,
       to_regclass('drizzle.__drizzle_migrations') AS drizzle_journal_relation;

-- 2. Exact opportunity / Master Specification / revision-1 identity. Must return exactly one row.
SELECT o.id AS opportunity_id, o.opportunity_number, o.customer_id,
       ms.id AS master_specification_id, ms.specification_number,
       msv.id AS master_specification_version_id, msv.version_number
FROM public.sales_opportunities AS o
JOIN public.master_specifications AS ms
  ON ms.opportunity_id = o.id AND ms.customer_id = o.customer_id
JOIN public.master_specification_versions AS msv
  ON msv.specification_id = ms.id
WHERE o.opportunity_number = 'OPPORTUNITY-2026-0013'
  AND ms.specification_number = 'MASTER-2026-0001'
  AND msv.version_number = 1;

-- 3. Required relations/functions must all be present.
SELECT required.name, required.kind,
       CASE required.kind
         WHEN 'relation' THEN to_regclass(required.name) IS NOT NULL
         WHEN 'function' THEN to_regprocedure(required.name) IS NOT NULL
       END AS is_present
FROM (VALUES
  ('public.sales_opportunities', 'relation'),
  ('public.master_specifications', 'relation'),
  ('public.master_specification_versions', 'relation'),
  ('public.customers', 'relation'),
  ('public.departments', 'relation'),
  ('public.drive_nodes', 'relation'),
  ('public.drive_node_revisions', 'relation'),
  ('public.document_control_registers', 'relation'),
  ('storage.objects', 'relation'),
  ('public.has_permission(uuid,text)', 'function'),
  ('public.has_any_permission(uuid,text[])', 'function'),
  ('public.can_access_department_drive(uuid,uuid,uuid)', 'function')
) AS required(name, kind)
ORDER BY required.kind, required.name;

-- 4. Proposed relations must all be absent before this first installation.
SELECT proposed.relation_name, to_regclass(proposed.relation_name) AS existing_relation
FROM (VALUES
 ('public.sales_opportunity_structured_drafts'),
 ('public.sales_opportunity_structured_draft_revisions'),
 ('public.sales_opportunity_structured_draft_requests'),
 ('public.sales_opportunity_structured_draft_private_locations'),
 ('public.sales_opportunity_structured_draft_revision_locations'),
 ('public.sales_opportunity_structured_draft_audit_events'),
 ('public.sales_opportunity_document_locations'),
 ('public.sales_opportunity_structured_draft_storage_attempts'),
 ('public.sales_opportunity_structured_draft_materializations'),
 ('public.sales_opportunity_structured_draft_materialization_audits')
) AS proposed(relation_name)
ORDER BY proposed.relation_name;

-- 5. Complete current storage policy snapshot, including every project-drive policy.
SELECT pol.polname AS policy_name, pol.polcmd AS command, roles.rolname AS role_name,
       pg_get_expr(pol.polqual, pol.polrelid) AS using_expression,
       pg_get_expr(pol.polwithcheck, pol.polrelid) AS with_check_expression
FROM pg_policy AS pol
JOIN pg_class AS cls ON cls.oid = pol.polrelid
JOIN pg_namespace AS ns ON ns.oid = cls.relnamespace
LEFT JOIN pg_roles AS roles ON roles.oid = ANY(pol.polroles)
WHERE ns.nspname = 'storage' AND cls.relname = 'objects'
  AND (pol.polname IN (
    'project_drive_read', 'project_drive_insert', 'project_drive_update', 'project_drive_delete',
    'Project teams read project files', 'Project managers upload project files',
    'Project managers update project files', 'Project managers delete project files'
  ) OR pol.polname LIKE 'project_drive_%')
ORDER BY pol.polname, role_name NULLS FIRST;

-- 6. Complete ACL/owner snapshot for the five future authenticated entry points and their helpers.
SELECT ns.nspname AS schema_name, proc.proname AS function_name,
       pg_get_function_identity_arguments(proc.oid) AS identity_arguments,
       owner.rolname AS owner_name, proc.prosecdef AS security_definer,
       proc.proacl AS function_acl
FROM pg_proc AS proc
JOIN pg_namespace AS ns ON ns.oid = proc.pronamespace
JOIN pg_roles AS owner ON owner.oid = proc.proowner
WHERE ns.nspname = 'public'
  AND proc.proname IN (
    'save_sales_opportunity_structured_draft_at_location',
    'resolve_sales_opportunity_structured_draft_location',
    'register_sales_opportunity_structured_draft_storage_attempt',
    'commit_sales_opportunity_structured_draft_materialization',
    'can_discard_sales_opportunity_structured_draft_object',
    'save_sales_opportunity_structured_draft_revision',
    'reject_sales_opportunity_structured_draft_audit_mutation',
    'reject_sales_draft_materialization_mutation',
    'guard_sales_draft_storage_attempt'
  )
ORDER BY proc.proname, identity_arguments;

-- 7. Existing Drive folders only: inspect, do not bind or infer a location.
SELECT node.id, node.name, node.parent_id, node.department_id, node.project_id,
       node.node_type, node.is_locked, node.is_trashed, node.storage_bucket, node.storage_path
FROM public.drive_nodes AS node
WHERE lower(node.node_type) = 'folder'
  AND node.is_trashed = false
ORDER BY node.department_id NULLS LAST, node.parent_id NULLS FIRST, node.name, node.id;

ROLLBACK;
