import { useEffect, useMemo, useState } from "react";
import { createFileRoute, Link, Outlet, useLocation } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import { Building2, CircleAlert, Eye, FileText, FolderOpen, Plus } from "lucide-react";
import { PermissionGate } from "@/components/PermissionGate";
import { StructuredTemplatePreview } from "@/components/lifecycle/StructuredTemplatePreview";
import { EnquiryDialog } from "@/components/sales/SalesIntakeDialogs";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { DialogDescription, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { EnquiryDetail } from "@/components/sales/EnquiryDetail";
import { SalesDashboard } from "@/components/sales/SalesDashboard";
import { StructuredPreviewExitDialog } from "@/components/lifecycle/StructuredPreviewExitBoundary";
import {
  type CustomerRequirement,
  type MasterSpecificationSummary,
  type SalesEnquiry,
  type SalesOpportunity,
} from "@/lib/sales";
import { supabase } from "@/integrations/supabase/client";
import { createProposedProjectPlan } from "@/lib/proposed-project-plan";
import { buildSalesSourceContractAvailability } from "@/lib/feasibility-planning";
import { draftFromSpecificationData } from "@/lib/master-specification";
import { useAuth } from "@/hooks/useAuth";
import { salesOverviewQueryOptions } from "@/lib/sales-overview-query";
import { SalesOpportunityPipeline } from "@/components/sales/SalesOpportunityPipeline";
import { canOpenDirectSalesStructuredDocuments, type SalesStructuredDocumentEntry } from "@/lib/structured-lifecycle-document-access";
import { fetchTasks } from "@/lib/tasks";

export const Route = createFileRoute("/_authenticated/sales")({
  head: () => ({
    meta: [
      { title: "Sales — SSM One" },
      { name: "description", content: "Customer enquiries and opportunities for SSM One." },
      { property: "og:title", content: "Sales — SSM One" },
      { property: "og:description", content: "Customer enquiries and opportunities for SSM One." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: SalesRoute,
});

type SalesDetail = { opportunity: SalesOpportunity; specification: MasterSpecificationSummary };
type SalesDocumentLocationDiscovery = {
  location_id: string;
  department_id: string;
  target_folder_node_id: string;
};

function toSalesStructuredDocumentEntry(
  detail: SalesDetail,
  location: SalesDocumentLocationDiscovery | null | undefined,
): SalesStructuredDocumentEntry | null {
  if (!location?.location_id || !location.department_id || !location.target_folder_node_id) return null;
  return {
    opportunityId: detail.opportunity.id,
    opportunityNumber: detail.opportunity.opportunity_number,
    specificationNumber: detail.specification.specification_number,
    versionNumber: detail.specification.current_version,
    folderNodeId: location.target_folder_node_id,
    departmentId: location.department_id,
    // These assertions belong to the caller-authorized discovery RPC. The UI only
    // consumes its narrow read result and never reconstructs Drive authority.
    isActive: true,
    folderIsLocked: true,
    folderIsTrashed: false,
  };
}
function SalesRoute() {
  const { pathname } = useLocation();
  return pathname === "/sales" ? <SalesDashboardPage /> : <Outlet />;
}

function SalesDashboardPage() {
  const [dialog, setDialog] = useState<"enquiry" | null>(null);
  const [enquiryDetail, setEnquiryDetail] = useState<SalesEnquiry | null>(null);
  const [showExistingRecords, setShowExistingRecords] = useState(false);
  const [detail, setDetail] = useState<SalesDetail | null>(null);
  const [documentDetail, setDocumentDetail] = useState<SalesDetail | null>(null);
  const { loading: authLoading, user } = useAuth();
  const sales = useQuery(salesOverviewQueryOptions(user?.id ?? null));
  const salesTasks = useQuery({ queryKey: ["project_tasks", "sales-overview"], queryFn: () => fetchTasks(), enabled: Boolean(user?.id), retry: false });
  const directDocumentDetail = documentDetail;
  return (
    <PermissionGate permission="sales.view" fallback={<AccessDenied />}>
      <div className="space-y-6">
        <div className="flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
          <div>
            <p className="text-sm font-medium text-primary">Customer development</p>
            <h1 className="mt-1 text-2xl font-semibold">Sales</h1>
            <p className="mt-2 max-w-3xl text-sm text-muted-foreground">
              Start with customer enquiries, then continue work from the saved record when the required controls are available.
            </p>
          </div>
          <div className="flex flex-wrap gap-2">
            <Button asChild variant="outline">
              <Link to="/customers">Customers</Link>
            </Button>
          </div>
        </div>
        <PermissionGate permission="sales.manage"><Button onClick={() => setDialog("enquiry")}><Plus className="size-4" /> New enquiry</Button></PermissionGate>
        {sales.isError && (
          <Card>
            <CardContent className="p-4 text-sm text-destructive">
              Sales records could not be loaded:{" "}
              {sales.error instanceof Error ? sales.error.message : "Unexpected read error"}
            </CardContent>
          </Card>
        )}
        <SalesDashboard customers={sales.data?.customers ?? []} enquiries={sales.data?.enquiries ?? []} opportunities={sales.data?.opportunities ?? []} clientProjects={sales.data?.clientProjects ?? null} tickets={sales.data?.supportTickets ?? null} tasks={salesTasks.isError ? null : salesTasks.data ?? null} onOpenEnquiry={setEnquiryDetail} />
        <div><Button type="button" variant="outline" onClick={() => setShowExistingRecords((value) => !value)}>{showExistingRecords ? "Hide existing records" : "Existing records"}</Button>{showExistingRecords && <Card className="mt-3"><CardHeader><CardTitle>Opportunities</CardTitle><CardDescription>Existing records remain available here; opening a proposal keeps its established history and document controls.</CardDescription></CardHeader><CardContent className="space-y-3">{sales.data?.opportunities.map((item) => <div key={item.id} className="flex items-start justify-between gap-3 border-l-2 border-primary/30 pl-3"><div><p className="font-medium">{item.opportunity_number} · {item.name}</p><p className="mt-1 text-xs text-muted-foreground">{item.customer?.legal_name ?? "Customer pending"}</p></div><div className="flex items-center gap-2"><Badge variant="outline">{item.stage.replaceAll("_", " ")}</Badge>{sales.data?.masterSpecifications.find((specification) => specification.opportunity_id === item.id) && <Button size="sm" variant="outline" onClick={() => { const specification = sales.data?.masterSpecifications.find((candidate) => candidate.opportunity_id === item.id); if (specification) setDetail({ opportunity: item, specification }); }}>Open</Button>}</div></div>)}</CardContent></Card>}</div>
        <EnquiryDialog
          open={dialog === "enquiry"}
          onOpenChange={(open) => !open && setDialog(null)}
          customers={sales.data?.customers ?? []}
          contacts={sales.data?.contacts ?? []}
          employees={sales.data?.employees ?? []}
        />
        <EnquiryDetail enquiry={enquiryDetail} departments={sales.data?.departments ?? []} onOpenChange={(open) => !open && setEnquiryDetail(null)} />
        <ProposalDetail
          detail={detail}
          requirements={sales.data?.requirements ?? []}
          onOpenChange={(open) => !open && setDetail(null)}
          actorId={user?.id ?? null}
        />
        <SalesDocumentsDetail
          detail={directDocumentDetail}
          onOpenChange={(open) => !open && setDocumentDetail(null)}
          actorId={user?.id ?? null}
        />
      </div>
    </PermissionGate>
  );
}
export function ProposalDetail({
  detail,
  requirements,
  onOpenChange,
  actorId,
}: {
  detail: SalesDetail | null;
  requirements: CustomerRequirement[];
  onOpenChange: (open: boolean) => void;
  actorId: string | null;
}) {
  const [documentsOpen, setDocumentsOpen] = useState(false);
  const [previewDirty, setPreviewDirty] = useState(false);
  const [localPreviewEdits, setLocalPreviewEdits] = useState<Record<string, string>>({});
  const specification = useQuery({
    queryKey: [
      "master_specification",
      detail?.specification.id,
      detail?.specification.current_version,
    ],
    queryFn: async () => {
      if (!detail) throw new Error("No Master Specification was selected.");
      const { data, error } = await (supabase as any)
        .from("master_specification_versions")
        .select("id,version_number,change_summary,created_at,specification_data")
        .eq("specification_id", detail.specification.id)
        .eq("version_number", detail.specification.current_version)
        .single();
      if (error) throw error;
      return data;
    },
    enabled: Boolean(detail),
  });
  const documentLocation = useQuery({
    queryKey: [
      "sales-structured-document-location",
      detail?.opportunity.id,
      detail?.specification.id,
      specification.data?.id,
    ],
    queryFn: async () => {
      if (!detail || !specification.data?.id) throw new Error("The pinned Sales source is unavailable.");
      const { data, error } = await (supabase as any).rpc(
        "discover_sales_opportunity_structured_draft_folder",
        {
          p_opportunity_id: detail.opportunity.id,
          p_customer_id: detail.specification.customer_id,
          p_master_specification_id: detail.specification.id,
          p_master_specification_version_id: specification.data.id,
        },
      );
      if (error) throw error;
      const location = (data as Array<{
        location_id: string;
        department_id: string;
        target_folder_node_id: string;
      }> | null)?.[0];
      if (!location?.location_id || !location.department_id || !location.target_folder_node_id) return null;
      return {
        location_id: location.location_id,
        department_id: location.department_id,
        target_folder_node_id: location.target_folder_node_id,
      } satisfies SalesDocumentLocationDiscovery;
    },
    enabled: Boolean(detail && specification.data?.id),
    retry: false,
  });
  const draft = draftFromSpecificationData(specification.data?.specification_data);
  const linkedRequirements = requirements.filter(
    (item) =>
      item.opportunity_id === detail?.opportunity.id &&
      item.customer_id === detail.specification.customer_id,
  );
  const plan = draft
    ? createProposedProjectPlan({
        proposedName: draft.proposedName,
        customerOrInternalOwner: draft.customerOrInternalOwner,
        industryApplication: draft.industryApplication,
        productFamily: draft.productFamily,
        developmentScope: draft.developmentScope,
        workstreams: draft.workstreams,
        requirementSummary: draft.requirementSummary,
        optional: {
          powerAndUnits: draft.powerAndUnits,
          interfaces: draft.interfaces,
          connectivityAndGnss: draft.connectivityAndGnss,
          environmentAndIp: draft.environmentAndIp,
          volumes: draft.volumes,
          schedule: draft.schedule,
          requestedStandards: draft.requestedStandards,
          exclusions: draft.exclusions,
        },
      })
    : [];
  const sourcePin = detail
    ? {
        opportunityNumber: detail.opportunity.opportunity_number,
        specificationNumber: detail.specification.specification_number,
        versionNumber: detail.specification.current_version,
      }
    : undefined;
  const directDocumentEntry = detail ? toSalesStructuredDocumentEntry(detail, documentLocation.data) : null;
  const canOpenDocuments = canOpenDirectSalesStructuredDocuments(directDocumentEntry);
  return (
    <StructuredPreviewExitDialog
      open={Boolean(detail)}
      onOpenChange={(open) => {
        if (!open) {
          setDocumentsOpen(false);
          onOpenChange(false);
        }
      }}
      dirty={previewDirty}
      className="max-h-[90vh] max-w-4xl overflow-y-auto"
    >
      {(requestExit) => (
        <>
          <DialogHeader>
            <DialogTitle>
              {detail?.specification.specification_number} · rev{" "}
              {detail?.specification.current_version}
            </DialogTitle>
            <DialogDescription>
              {detail?.opportunity.opportunity_number} · Proposed only — no committed project,
              release, or document generation.
            </DialogDescription>
          </DialogHeader>
          {documentsOpen && sourcePin ? (
            <div className="space-y-4">
              <div className="flex items-center justify-between gap-3">
                <p className="text-sm text-muted-foreground">
                  Previewing documents from this exact saved opportunity and Master Specification
                  revision.
                </p>
                <Button
                  size="sm"
                  variant="outline"
                  onClick={() => setDocumentsOpen(false)}
                >
                  Back to proposal
                </Button>
              </div>
              <StructuredTemplatePreview
                sourcePin={sourcePin}
                actorId={actorId}
                catalogScope="sales-proposal"
                localEdits={localPreviewEdits}
                onLocalEditsChange={setLocalPreviewEdits}
                onDirtyChange={setPreviewDirty}
              />
            </div>
          ) : (
            <>
              {specification.isError && (
                <p className="text-sm text-destructive">
                  The specification could not be read:{" "}
                  {specification.error instanceof Error
                    ? specification.error.message
                    : "Unexpected read error"}
                </p>
              )}
              {specification.isLoading && (
                <p className="text-sm text-muted-foreground">Loading saved specification…</p>
              )}
              {draft && (
                <div className="space-y-5 text-sm">
                  <section className="rounded-md border p-3">
                    <div className="flex flex-wrap items-start justify-between gap-3">
                      <div>
                        <h3 className="font-semibold">Saved source provenance</h3>
                        <p className="mt-1 text-muted-foreground">
                          Source opportunity {detail?.opportunity.opportunity_number} · Master
                          Specification revision {specification.data?.version_number} · saved{" "}
                          {specification.data?.created_at
                            ? new Date(specification.data.created_at).toLocaleString()
                            : "time unavailable"}
                        </p>
                      </div>
                      <Button size="sm" onClick={() => setDocumentsOpen(true)}>
                        <Eye className="size-4" /> Open Sales documents
                      </Button>
                    </div>
                    <p className="mt-1 text-muted-foreground">
                      Change note: {specification.data?.change_summary ?? "Not recorded"}
                    </p>
                    <div className="mt-3 space-y-2">
                      {linkedRequirements.map((item) => (
                        <div key={item.id} className="border-l-2 border-primary/30 pl-3">
                          <p className="font-medium">
                            {item.requirement_number} · rev {item.current_revision}
                          </p>
                          <p className="text-xs text-muted-foreground">
                            {item.title} · {item.status.replaceAll("_", " ")}
                          </p>
                        </div>
                      ))}
                      {!linkedRequirements.length && (
                        <p className="text-muted-foreground">
                          No controlled requirement is linked to this opportunity and customer.
                        </p>
                      )}
                    </div>
                    <p className="mt-3 text-xs text-muted-foreground">
                      This is a read-only source snapshot. It does not create a project, baseline,
                      client access, or conversion.
                    </p>
                    <div className="mt-3 flex flex-wrap gap-2">
                      <Button size="sm" variant="outline" asChild disabled={!canOpenDocuments}>
                        <Link
                          to="/drive"
                          search={{
                            node: canOpenDocuments ? directDocumentEntry?.folderNodeId : undefined,
                            department: canOpenDocuments ? directDocumentEntry?.departmentId : undefined,
                            sourceBound: canOpenDocuments ? true : undefined,
                          }}
                        >
                          <FolderOpen className="size-4" /> Open Sales folder
                        </Link>
                      </Button>
                    </div>
                    {documentLocation.isError && (
                      <p className="mt-2 text-xs text-destructive">
                        The pinned Sales folder could not be verified. Direct folder access remains unavailable.
                      </p>
                    )}
                    {!documentLocation.isLoading && !documentLocation.isError && !canOpenDocuments && (
                      <p className="mt-2 text-xs text-muted-foreground">
                        No active locked Sales folder is available for this exact source. No folder or project was created.
                      </p>
                    )}
                  </section>
                  <section className="grid gap-3 sm:grid-cols-2">
                    <ReadField label="Proposed name" value={draft.proposedName} />
                    <ReadField label="Customer / owner" value={draft.customerOrInternalOwner} />
                    <ReadField label="Industry / application" value={draft.industryApplication} />
                    <ReadField label="Product family" value={draft.productFamily} />
                    <ReadField label="Development scope" value={draft.developmentScope} />
                    <ReadField
                      label="Engineering workstreams"
                      value={draft.workstreams.join(", ")}
                    />
                  </section>
                  <ReadField label="Requirement summary" value={draft.requirementSummary} />
                  <section>
                    <h3 className="font-semibold">More options</h3>
                    <div className="mt-3 grid gap-3 sm:grid-cols-2">
                      <ReadField label="Power / units" value={draft.powerAndUnits} />
                      <ReadField label="Interfaces" value={draft.interfaces} />
                      <ReadField label="Connectivity / GNSS" value={draft.connectivityAndGnss} />
                      <ReadField label="Environment / IP" value={draft.environmentAndIp} />
                      <ReadField label="Volumes" value={draft.volumes} />
                      <ReadField label="Schedule" value={draft.schedule} />
                      <ReadField label="Requested standards" value={draft.requestedStandards} />
                      <ReadField label="Exclusions" value={draft.exclusions} />
                    </div>
                  </section>
                  <section>
                    <h3 className="font-semibold">Nine-stage applicability preview</h3>
                    <div className="mt-3 space-y-2">
                      {plan.map((stage) => (
                        <div
                          key={stage.key}
                          className="flex items-start justify-between gap-3 border-l-2 border-primary/30 pl-3"
                        >
                          <div>
                            <p className="font-medium">{stage.title}</p>
                            <p className="text-xs text-muted-foreground">
                              {stage.responsibility}
                              {stage.exclusionRationale ? ` · ${stage.exclusionRationale}` : ""}
                            </p>
                          </div>
                          <Badge
                            variant={stage.state === "NOT_APPLICABLE" ? "secondary" : "outline"}
                          >
                            {stage.state.replaceAll("_", " ")}
                          </Badge>
                        </div>
                      ))}
                    </div>
                  </section>
                </div>
              )}
            </>
          )}
        </>
      )}
    </StructuredPreviewExitDialog>
  );
}
export function SalesDocumentsDetail({
  detail,
  onOpenChange,
  actorId,
}: {
  detail: SalesDetail | null;
  onOpenChange: (open: boolean) => void;
  actorId: string | null;
}) {
  const [localEdits, setLocalEdits] = useState<Record<string, string>>({});
  const sourcePin = detail
    ? {
        opportunityNumber: detail.opportunity.opportunity_number,
        specificationNumber: detail.specification.specification_number,
        versionNumber: detail.specification.current_version,
      }
    : undefined;
  useEffect(() => {
    setLocalEdits({});
  }, [detail?.opportunity.id, detail?.specification.id, detail?.specification.current_version]);
  return (
    <StructuredPreviewExitDialog
      open={Boolean(detail)}
      onOpenChange={(open) => {
        if (!open) onOpenChange(false);
      }}
      dirty={Object.keys(localEdits).length > 0}
      className="max-h-[90vh] max-w-6xl overflow-y-auto"
    >
      {() => (
        <>
          <DialogHeader>
            <DialogTitle>Sales documents</DialogTitle>
            <DialogDescription>
              {detail?.opportunity.opportunity_number} · {detail?.specification.specification_number} · rev {detail?.specification.current_version}
            </DialogDescription>
          </DialogHeader>
          {sourcePin && (
            <StructuredTemplatePreview
              sourcePin={sourcePin}
              actorId={actorId}
              catalogScope="sales-proposal"
              localEdits={localEdits}
              onLocalEditsChange={setLocalEdits}
            />
          )}
        </>
      )}
    </StructuredPreviewExitDialog>
  );
}
function ReadField({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <p className="text-xs font-medium text-muted-foreground">{label}</p>
      <p className="mt-1 whitespace-pre-wrap">{value}</p>
    </div>
  );
}
function Metric({ icon, label, value }: { icon: React.ReactNode; label: string; value: number }) {
  return (
    <Card>
      <CardContent className="flex items-center gap-3 p-4">
        <span className="text-primary">{icon}</span>
        <div>
          <p className="text-2xl font-semibold">{value}</p>
          <p className="text-xs text-muted-foreground">{label}</p>
        </div>
      </CardContent>
    </Card>
  );
}
function AccessDenied() {
  return (
    <section className="mx-auto max-w-lg py-20 text-center">
      <h1 className="text-xl font-semibold">Access restricted</h1>
      <p className="mt-2 text-sm text-muted-foreground">
        Your account does not currently have access to the sales workspace.
      </p>
      <Button asChild variant="link" className="mt-4">
        <Link to="/">Return to workspace</Link>
      </Button>
    </section>
  );
}
