import { useState } from "react";
import { createFileRoute } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import { PermissionGate } from "@/components/PermissionGate";
import { EnquiriesWorkspace } from "@/components/sales/EnquiriesWorkspace";
import { EnquiryDetail } from "@/components/sales/EnquiryDetail";
import { OpportunityDetail } from "@/components/sales/OpportunityDetail";
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
  const [opportunityDetail, setOpportunityDetail] = useState<SalesOpportunity | null>(null);
  const [specificationDetail, setSpecificationDetail] = useState<{ opportunity: SalesOpportunity; specification: MasterSpecificationSummary } | null>(null);
  const selectedSpecification = sales.data?.masterSpecifications.find((item) => item.opportunity_id === opportunityDetail?.id) ?? null;
  return <PermissionGate permission="sales.view"><EnquiriesWorkspace enquiries={sales.data?.enquiries ?? []} opportunities={sales.data?.opportunities ?? []} requirements={sales.data?.requirements ?? []} reviews={sales.data?.feasibilityReviews ?? []} onNew={() => setNewEnquiryOpen(true)} onOpenEnquiry={setDetail} onOpenOpportunity={setOpportunityDetail} /><EnquiryDialog open={newEnquiryOpen} onOpenChange={setNewEnquiryOpen} customers={sales.data?.customers ?? []} contacts={sales.data?.contacts ?? []} employees={sales.data?.employees ?? []} /><EnquiryDetail enquiry={detail} departments={sales.data?.departments ?? []} linkedOpportunity={sales.data?.opportunities.find((opportunity) => opportunity.enquiry_id === detail?.id) ?? null} onOpenChange={(open) => !open && setDetail(null)} /><OpportunityDetail opportunity={opportunityDetail} specification={selectedSpecification} requirements={sales.data?.requirements ?? []} reviews={sales.data?.feasibilityReviews ?? []} departments={sales.data?.departments ?? []} employees={sales.data?.employees ?? []} feasibilityProvenance={sales.data?.feasibilityProvenance ?? { available: false, error: "Feasibility source records are unavailable." }} onViewSpecification={() => { if (opportunityDetail && selectedSpecification) { setOpportunityDetail(null); setSpecificationDetail({ opportunity: opportunityDetail, specification: selectedSpecification }); } }} onOpenChange={(open) => !open && setOpportunityDetail(null)} /><ProposalDetail detail={specificationDetail} requirements={sales.data?.requirements ?? []} onOpenChange={(open) => !open && setSpecificationDetail(null)} actorId={user?.id ?? null} /></PermissionGate>;
}