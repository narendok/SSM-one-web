import { queryOptions } from "@tanstack/react-query";
import { fetchSalesOverview } from "@/lib/sales";

export const salesOverviewQueryKey = (actorId: string | null) =>
  ["sales_overview", actorId ?? "signed-out"] as const;

export const salesOverviewQueryOptions = (actorId: string | null) =>
  queryOptions({
    queryKey: salesOverviewQueryKey(actorId),
    queryFn: fetchSalesOverview,
    enabled: Boolean(actorId),
  });