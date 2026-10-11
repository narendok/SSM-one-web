-- ACTION-TIME APPROVAL REQUIRED. UNDEPLOYED.
-- Apply only after the three pending structured Sales migrations pass isolated
-- caller-authenticated acceptance and an approver records the exact active Sales
-- folder binding. This file intentionally holds the only authenticated transport
-- grants and Storage policy change; do not merge it into the schema contract.
--
-- The location row must be provisioned by an approved administrator operation
-- before any caller can use this policy. The policy permits only a path derived
-- from that active recorded location and request receipt. It does not grant
-- generic Sales access to project-drive or to other departments' objects.
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
