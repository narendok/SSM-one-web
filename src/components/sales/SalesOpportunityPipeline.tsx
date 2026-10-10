import type { SalesOpportunity } from "@/lib/sales";

export type SalesOpportunityPipelineState = {
  opportunities: SalesOpportunity[] | undefined;
  pending: boolean;
  error: Error | null;
};

export function SalesOpportunityPipeline({ state }: { state: SalesOpportunityPipelineState }) {
  if (state.pending) {
    return <p className="py-6 text-sm text-muted-foreground">Loading opportunities…</p>;
  }

  if (state.error) {
    return (
      <p className="py-6 text-sm text-destructive" role="alert">
        Opportunities could not be loaded: {state.error.message}
      </p>
    );
  }

  if (!state.opportunities) {
    return <p className="py-6 text-sm text-muted-foreground">Sales records are not available for this signed-in user.</p>;
  }

  if (!state.opportunities.length) {
    return <p className="py-6 text-sm text-muted-foreground">No opportunities are available for this signed-in user.</p>;
  }

  return null;
}