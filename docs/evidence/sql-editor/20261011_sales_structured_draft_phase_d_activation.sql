-- REVIEW-ONLY PHASE D ACTIVATION. DO NOT EXECUTE WITHOUT THE NAMED ACTION-TIME APPROVAL.
-- No Drizzle migration discovery, historic replay, or migration-journal write is permitted.
-- Paste this complete file as one Cloud SQL editor submission; do not select fragments.
-- Run only after separately recorded Phase B binding review and Phase C managed caller acceptance. This is the only phase that changes storage policies or grants authenticated EXECUTE.

BEGIN;

-- ===== BEGIN APPROVED SOURCE 4: supabase/pending/20261011_sales_opportunity_structured_draft_materialization_activation.sql
-- SHA-256: dc3809675ccbe1eb886eae6e879e6cf8638fcc6955565f541883b64b8b776f2e
-- ACTION-TIME APPROVAL REQUIRED. UNDEPLOYED.
--
-- This contract deliberately replaces every existing permissive project-drive
-- policy that could otherwise reach the reserved sales/opportunity/ namespace.
-- Adding a narrow Sales policy alone is unsafe because PostgreSQL combines
-- permissive policies for the same command with OR.
--
-- Before execution, an approver must bind exactly one active location to an
-- opportunity/customer, a locked Sales Drive folder, and its exact prefix.
-- Apply only after the three structured-draft contracts pass managed,
-- caller-authenticated acceptance. Do not merge into schema contracts.

DROP POLICY IF EXISTS project_drive_read ON storage.objects;
DROP POLICY IF EXISTS project_drive_insert ON storage.objects;
DROP POLICY IF EXISTS project_drive_update ON storage.objects;
DROP POLICY IF EXISTS project_drive_delete ON storage.objects;
DROP POLICY IF EXISTS "Project teams read project files" ON storage.objects;
DROP POLICY IF EXISTS "Project managers upload project files" ON storage.objects;
DROP POLICY IF EXISTS "Project managers update project files" ON storage.objects;
DROP POLICY IF EXISTS "Project managers delete project files" ON storage.objects;

-- Existing project/Engineering access is preserved only for non-reserved paths.
CREATE POLICY "Project teams read project files"
ON storage.objects FOR SELECT TO authenticated
USING (
  bucket_id = 'project-drive'
  AND name !~ '^sales/opportunity/'
  AND public.has_any_permission(auth.uid(), ARRAY['projects.view', 'projects.manage', 'engineering.view', 'engineering.manage'])
);
CREATE POLICY "Project managers upload project files"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'project-drive'
  AND name !~ '^sales/opportunity/'
  AND public.has_any_permission(auth.uid(), ARRAY['projects.manage', 'engineering.manage'])
);
CREATE POLICY "Project managers update project files"
ON storage.objects FOR UPDATE TO authenticated
USING (
  bucket_id = 'project-drive'
  AND name !~ '^sales/opportunity/'
  AND public.has_any_permission(auth.uid(), ARRAY['projects.manage', 'engineering.manage'])
)
WITH CHECK (
  bucket_id = 'project-drive'
  AND name !~ '^sales/opportunity/'
  AND public.has_any_permission(auth.uid(), ARRAY['projects.manage', 'engineering.manage'])
);
CREATE POLICY "Project managers delete project files"
ON storage.objects FOR DELETE TO authenticated
USING (
  bucket_id = 'project-drive'
  AND name !~ '^sales/opportunity/'
  AND public.has_any_permission(auth.uid(), ARRAY['projects.manage', 'engineering.manage'])
);

-- Sales access is receipt- and materialization-bound. It cannot create a
-- generic project-drive path, read another actor's document, update, or delete.
CREATE POLICY "Sales structured drafts insert their recorded private prefix"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'project-drive'
  AND EXISTS (
    SELECT 1
    FROM public.sales_opportunity_document_locations location
    JOIN public.sales_opportunity_structured_draft_requests request_receipt
      ON request_receipt.opportunity_id = location.opportunity_id
      AND request_receipt.customer_id = location.customer_id
    WHERE location.status = 'ACTIVE'
      AND public.has_permission(auth.uid(), 'sales.manage')
      AND request_receipt.requested_by = auth.uid()
      AND name = location.private_storage_prefix || request_receipt.request_key::text || '-draft.html'
  )
);
CREATE POLICY "Sales structured draft actors read their recorded private prefix"
ON storage.objects FOR SELECT TO authenticated
USING (
  bucket_id = 'project-drive'
  AND EXISTS (
    SELECT 1
    FROM public.sales_opportunity_structured_draft_materializations materialization
    WHERE materialization.requested_by = auth.uid()
      AND public.has_permission(auth.uid(), 'sales.manage')
      AND materialization.storage_bucket = bucket_id
      AND materialization.storage_path = name
  )
);

GRANT EXECUTE ON FUNCTION public.save_sales_opportunity_structured_draft_at_location(uuid, uuid, uuid, uuid, text, integer, jsonb, uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.resolve_sales_opportunity_structured_draft_location(uuid, uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.register_sales_opportunity_structured_draft_storage_attempt(uuid, uuid, uuid, uuid, text, text, text, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.commit_sales_opportunity_structured_draft_materialization(uuid, uuid, uuid, uuid, text, text, text, text, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_discard_sales_opportunity_structured_draft_object(uuid, uuid, uuid, uuid, text, text) TO authenticated;
-- ===== END APPROVED SOURCE 4: supabase/pending/20261011_sales_opportunity_structured_draft_materialization_activation.sql

COMMIT;
