import { createServerFn } from "@tanstack/react-start";
import { z } from "zod";
import { requireSupabaseAuth } from "@/integrations/supabase/auth-middleware";

const uuid = z.string().uuid();

const discoveryInput = z.object({
  opportunityId: uuid,
  customerId: uuid,
  masterSpecificationId: uuid,
  masterSpecificationVersionId: uuid,
});

export type StructuredSalesDraftDiscovery = {
  locationId: string;
  storageBucket: string;
  storagePathPrefix: string;
};

/**
 * This endpoint stays fail-closed until the separately reviewed discovery
 * function is installed. The UI never reads the private location tables.
 */
export const discoverStructuredSalesDraftCapability = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((data) => discoveryInput.parse(data))
  .handler(async ({ data, context }): Promise<StructuredSalesDraftDiscovery | null> => {
    const { data: allowed, error: permissionError } = await context.supabase.rpc("has_permission", {
      _user_id: context.userId,
      _permission_key: "sales.manage",
    });
    if (permissionError || !allowed) throw new Error("You do not have permission to manage Sales drafts.");

    const { data: source, error: sourceError } = await context.supabase
      .from("master_specifications")
      .select("id,opportunity_id,customer_id")
      .eq("id", data.masterSpecificationId)
      .eq("opportunity_id", data.opportunityId)
      .eq("customer_id", data.customerId)
      .maybeSingle();
    if (sourceError || !source) throw new Error("The pinned Sales source is unavailable.");

    const { data: version, error: versionError } = await context.supabase
      .from("master_specification_versions")
      .select("id,specification_id")
      .eq("id", data.masterSpecificationVersionId)
      .eq("specification_id", data.masterSpecificationId)
      .maybeSingle();
    if (versionError || !version) throw new Error("The pinned Master Specification revision is unavailable.");

    // REVIEW-ONLY DEPENDENCY: this RPC must prove caller authorization, source
    // pins, and one active private location while exposing no private tables.
    const { data: location, error: locationError } = await (context.supabase as any).rpc(
      "discover_sales_opportunity_structured_draft_location",
      {
        p_opportunity_id: data.opportunityId,
        p_customer_id: data.customerId,
        p_master_specification_id: data.masterSpecificationId,
        p_master_specification_version_id: data.masterSpecificationVersionId,
      },
    );
    if (locationError) {
      if (locationError.code === "42883") return null;
      throw new Error("The private Sales draft location could not be verified.");
    }

    const first = Array.isArray(location) ? location[0] : null;
    if (!first || typeof first.location_id !== "string" || typeof first.storage_bucket !== "string" || typeof first.storage_path_prefix !== "string") {
      return null;
    }
    return {
      locationId: first.location_id,
      storageBucket: first.storage_bucket,
      storagePathPrefix: first.storage_path_prefix,
    };
  });