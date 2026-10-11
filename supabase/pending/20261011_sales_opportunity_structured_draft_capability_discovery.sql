-- REVIEW-ONLY. DO NOT EXECUTE WITHOUT A SEPARATE ACTION-TIME APPROVAL.
--
-- This narrow caller-authenticated discovery transport exists solely to let the
-- browser determine whether one already-approved, active Sales location can be
-- used for the caller's exact opportunity/customer/Master revision pin. It
-- deliberately exposes no private location, Drive, receipt, revision, audit,
-- or materialization table to the client. It does not grant write access, alter
-- Storage policies, or create a binding.

CREATE OR REPLACE FUNCTION public.discover_sales_opportunity_structured_draft_location(
  p_opportunity_id uuid,
  p_customer_id uuid,
  p_master_specification_id uuid,
  p_master_specification_version_id uuid
) RETURNS TABLE(location_id uuid, storage_bucket text, storage_path_prefix text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor uuid := auth.uid();
BEGIN
  IF v_actor IS NULL OR NOT public.has_permission(v_actor, 'sales.manage') THEN
    RAISE EXCEPTION 'Sales management permission is required';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.sales_opportunities AS opportunity
    JOIN public.master_specifications AS specification
      ON specification.id = p_master_specification_id
      AND specification.opportunity_id = opportunity.id
      AND specification.customer_id = opportunity.customer_id
    JOIN public.master_specification_versions AS version
      ON version.id = p_master_specification_version_id
      AND version.specification_id = specification.id
    WHERE opportunity.id = p_opportunity_id
      AND opportunity.customer_id = p_customer_id
  ) THEN
    RAISE EXCEPTION 'Pinned Sales source is unavailable';
  END IF;

  RETURN QUERY
  SELECT location.id, location.private_storage_bucket, location.private_storage_prefix
  FROM public.sales_opportunity_document_locations AS location
  WHERE location.opportunity_id = p_opportunity_id
    AND location.customer_id = p_customer_id
    AND location.location_purpose = 'STRUCTURED_DRAFT'
    AND location.status = 'ACTIVE'
    AND public.can_access_sales_structured_draft_object(
      'SELECT',
      location.private_storage_bucket,
      location.private_storage_prefix
    );
END;
$$;

REVOKE ALL ON FUNCTION public.discover_sales_opportunity_structured_draft_location(uuid, uuid, uuid, uuid) FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.discover_sales_opportunity_structured_draft_location(uuid, uuid, uuid, uuid) TO authenticated;