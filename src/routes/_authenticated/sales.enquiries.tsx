import { useState } from "react";
import { createFileRoute } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import { PermissionGate } from "@/components/PermissionGate";
import { EnquiriesWorkspace } from "@/components/sales/EnquiriesWorkspace";
import { EnquiryDetail } from "@/components/sales/EnquiryDetail";
import { EnquiryDialog } from "@/components/sales/SalesIntakeDialogs";
import { ProposalDetail } from "@/routes/_authenticated/sales";
import type { MasterSpecificationSummary, SalesEnquiry, SalesOpportunity } from "@/lib/sales";
import { salesOverviewQueryOptions } from "@/lib/sales-overview-query";
import { useAuth } from "@/hooks/useAuth";

export const Route = createFileRoute("/_authenticated/sales/enquiries")({
  head: () => ({ meta: [{ title: "Enquiries & Opportunities — SSM One" }, { name: "description", content: "Authorised sales enquiries and opportunities for SSM One." }, { property: "og:title", content: "Enquiries & Opportunities — SSM One" }, { property: "og:description", content: "Authorised sales enquiries and opportunities for SSM One." }, { property: "og:type", content: "website" }, { name: "twitter:card", content: "summary" }] }),
  component: EnquiriesPage,
});

function EnquiriesPage() {
  const { user } = useAuth();
  const sales = useQuery(salesOverviewQueryOptions(user?.id ?? null));
  const [newEnquiryOpen, setNewEnquiryOpen] = useState(false);
  const [detail, setDetail] = useState<SalesEnquiry | null>(null);
  const [opportunityDetail, setOpportunityDetail] = useState<{ opportunity: SalesOpportunity; specification: MasterSpecificationSummary } | null>(null);
  return <PermissionGate permission="sales.view"><EnquiriesWorkspace enquiries={sales.data?.enquiries ?? []} opportunities={sales.data?.opportunities ?? []} onNew={() => setNewEnquiryOpen(true)} onOpenEnquiry={setDetail} onOpenOpportunity={(opportunity) => { const specification = sales.data?.masterSpecifications.find((item) => item.opportunity_id === opportunity.id); if (specification) setOpportunityDetail({ opportunity, specification }); }} /><EnquiryDialog open={newEnquiryOpen} onOpenChange={setNewEnquiryOpen} customers={sales.data?.customers ?? []} contacts={sales.data?.contacts ?? []} employees={sales.data?.employees ?? []} /><EnquiryDetail enquiry={detail} departments={sales.data?.departments ?? []} onOpenChange={(open) => !open && setDetail(null)} /><ProposalDetail detail={opportunityDetail} requirements={sales.data?.requirements ?? []} onOpenChange={(open) => !open && setOpportunityDetail(null)} actorId={user?.id ?? null} /></PermissionGate>;
}