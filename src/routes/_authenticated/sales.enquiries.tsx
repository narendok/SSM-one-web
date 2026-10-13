import { useState } from "react";
import { createFileRoute } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import { PermissionGate } from "@/components/PermissionGate";
import { EnquiriesWorkspace } from "@/components/sales/EnquiriesWorkspace";
import { EnquiryDetail } from "@/components/sales/EnquiryDetail";
import { EnquiryDialog } from "@/components/sales/SalesIntakeDialogs";
import type { SalesEnquiry } from "@/lib/sales";
import { salesOverviewQueryOptions } from "@/lib/sales-overview-query";
import { useAuth } from "@/hooks/useAuth";

export const Route = createFileRoute("/_authenticated/sales/enquiries")({
  head: () => ({ meta: [{ title: "Enquiries — SSM One" }, { name: "description", content: "Saved customer enquiries for SSM One." }, { property: "og:title", content: "Enquiries — SSM One" }, { property: "og:description", content: "Saved customer enquiries for SSM One." }, { property: "og:type", content: "website" }, { name: "twitter:card", content: "summary" }] }),
  component: EnquiriesPage,
});

function EnquiriesPage() {
  const { user } = useAuth();
  const sales = useQuery(salesOverviewQueryOptions(user?.id ?? null));
  const [newEnquiryOpen, setNewEnquiryOpen] = useState(false);
  const [detail, setDetail] = useState<SalesEnquiry | null>(null);
  return <PermissionGate permission="sales.view"><EnquiriesWorkspace enquiries={sales.data?.enquiries ?? []} onNew={() => setNewEnquiryOpen(true)} onOpen={setDetail} /><EnquiryDialog open={newEnquiryOpen} onOpenChange={setNewEnquiryOpen} customers={sales.data?.customers ?? []} contacts={sales.data?.contacts ?? []} employees={sales.data?.employees ?? []} /><EnquiryDetail enquiry={detail} departments={sales.data?.departments ?? []} onOpenChange={(open) => !open && setDetail(null)} /></PermissionGate>;
}