-- SOURCE-ONLY, UNDEPLOYED REVIEW CONTRACT.
-- This narrow read extends the installed exact-source Sales location discovery
-- with only the department and target folder already validated by its resolver.
-- It does not expose a storage path, create a Drive location, grant Drive table
-- access, or let callers traverse another department's tree.

CREATE OR REPLACE FUNCTION public.discover_sales_opportunity_structured_draft_folder(
  p_opportunity_id uuid,
  p_customer_id uuid,
  p_master_specification_id uuid,
  p_master_specification_version_id uuid
) RETURNS TABLE(location_id uuid, department_id uuid, target_folder_node_id uuid)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_actor uuid := auth.uid();
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
  SELECT resolved.location_id, resolved.department_id, resolved.target_folder_node_id
  FROM public.sales_opportunity_document_locations AS location
  CROSS JOIN LATERAL public.resolve_sales_opportunity_structured_draft_location(
    p_opportunity_id, p_customer_id, location.id
  ) AS resolved
  WHERE location.opportunity_id = p_opportunity_id
    AND location.customer_id = p_customer_id
    AND location.location_purpose = 'STRUCTURED_DRAFT'
    AND location.status = 'ACTIVE'
    AND public.can_access_department_drive(v_actor, resolved.department_id, NULL);
END;
$$;

REVOKE ALL ON FUNCTION public.discover_sales_opportunity_structured_draft_folder(uuid,uuid,uuid,uuid)
  FROM PUBLIC, anon, service_role;