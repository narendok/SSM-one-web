-- REVIEW-ONLY PHASE B BINDING VALIDATION. NO INSERT, UPDATE, DELETE, POLICY, GRANT, OR JOURNAL CHANGE.
-- This checks the exact already-known source and Sales client folder. It does not create a location binding.

BEGIN READ ONLY;

WITH pinned AS (
  SELECT o.id AS opportunity_id, o.customer_id, ms.id AS master_specification_id, msv.id AS version_id
  FROM public.sales_opportunities AS o
  JOIN public.master_specifications AS ms ON ms.id = '7a3aba95-61f6-495a-a280-f37a3be77670'::uuid
    AND ms.opportunity_id = o.id AND ms.customer_id = o.customer_id
  JOIN public.master_specification_versions AS msv ON msv.id = '4914fba5-43a0-4486-b62f-d775a9bb16b9'::uuid
    AND msv.specification_id = ms.id AND msv.version_number = 1
  WHERE o.id = 'a6c62c81-1cc2-4804-b1c5-c004c6730b52'::uuid
    AND o.customer_id = '03e06115-a7d4-4965-9e92-9c37462f5ddc'::uuid
), folder AS (
  SELECT id, parent_id, department_id, project_id, name, node_type, is_locked, is_trashed, storage_bucket, storage_path
  FROM public.drive_nodes
  WHERE id = '020dcca5-7809-4287-88cd-537d837a3eee'::uuid
), ancestry AS (
  SELECT f.id, f.parent_id, 1 AS depth, ARRAY[f.id] AS path FROM folder AS f
  UNION ALL
  SELECT n.id, n.parent_id, a.depth + 1, a.path || n.id
  FROM public.drive_nodes AS n JOIN ancestry AS a ON a.parent_id = n.id
  WHERE a.depth < 64 AND NOT n.id = ANY(a.path)
)
SELECT pinned.*, folder.*,
  (folder.department_id = 'db21a9b2-2cd4-4891-9151-064bef8a7cb4'::uuid) AS matches_sales_department,
  (lower(folder.node_type) = 'folder' AND folder.is_locked AND NOT folder.is_trashed
   AND folder.project_id IS NULL AND folder.storage_bucket IS NULL AND folder.storage_path IS NULL) AS target_folder_valid,
  (SELECT count(*) < 64 FROM ancestry) AS ancestry_depth_valid
FROM pinned CROSS JOIN folder;

-- The approver must identify an existing locked, non-trashed Sales root from this output.
-- The target folder must descend from that root; do not infer a root or insert a binding here.
SELECT id, parent_id, department_id, project_id, name, node_type, is_locked, is_trashed, storage_bucket, storage_path
FROM public.drive_nodes
WHERE department_id = 'db21a9b2-2cd4-4891-9151-064bef8a7cb4'::uuid
  AND lower(node_type) = 'folder'
ORDER BY parent_id NULLS FIRST, name, id;

-- Phase B approval record must bind this exact prefix, but this review script never writes it.
SELECT 'sales/opportunity/a6c62c81-1cc2-4804-b1c5-c004c6730b52/'::text AS required_private_storage_prefix;

ROLLBACK;
