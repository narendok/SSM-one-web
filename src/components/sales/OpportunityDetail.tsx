import { useEffect, useMemo, useState } from "react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useServerFn } from "@tanstack/react-start";
import { toast } from "sonner";
import { supabase } from "@/integrations/supabase/client";
import { saveMasterSpecification } from "@/lib/master-specifications.functions";
import { salesFeasibilityHandoverAvailability } from "@/lib/client-requirement-intake";
import { MASTER_SPECIFICATION_TBC, draftFromSpecificationData, masterSpecificationDraftSchema, type MasterSpecificationDraft } from "@/lib/master-specification";
import type { CustomerRequirement, FeasibilityProvenanceState, FeasibilityReview, MasterSpecificationSummary, SalesOpportunity } from "@/lib/sales";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Textarea } from "@/components/ui/textarea";

type Props = {
  opportunity: SalesOpportunity | null;
  specification: MasterSpecificationSummary | null;
  requirements: CustomerRequirement[];
  reviews: FeasibilityReview[];
  departments: Array<{ id: string; name: string; code: string | null }>;
  employees: Array<{ user_id: string; display_name: string | null; official_email: string | null }>;
  feasibilityProvenance: FeasibilityProvenanceState;
  onViewSpecification: () => void;
  onOpenChange: (open: boolean) => void;
};

type Version = { id: string; version_number: number; change_summary: string | null; created_at: string; specification_data: unknown };

const label = (value: string) => value.replaceAll("_", " ");
const text = (value: string | null | undefined) => value?.trim() || "Not recorded";

function initialDraft(opportunity: SalesOpportunity, existing: unknown): MasterSpecificationDraft {
  const saved = draftFromSpecificationData(existing);
  if (saved) return saved;
  return {
    proposedName: opportunity.name || MASTER_SPECIFICATION_TBC,
    customerOrInternalOwner: opportunity.customer?.legal_name || MASTER_SPECIFICATION_TBC,
    industryApplication: opportunity.application || MASTER_SPECIFICATION_TBC,
    productFamily: opportunity.product_type || MASTER_SPECIFICATION_TBC,
    developmentScope: MASTER_SPECIFICATION_TBC,
    workstreams: ["HARDWARE"],
    requirementSummary: opportunity.name || MASTER_SPECIFICATION_TBC,
    powerAndUnits: MASTER_SPECIFICATION_TBC,
    interfaces: MASTER_SPECIFICATION_TBC,
    connectivityAndGnss: MASTER_SPECIFICATION_TBC,
    environmentAndIp: MASTER_SPECIFICATION_TBC,
    volumes: opportunity.estimated_volume || MASTER_SPECIFICATION_TBC,
    schedule: opportunity.target_timeline || MASTER_SPECIFICATION_TBC,
    requestedStandards: MASTER_SPECIFICATION_TBC,
    exclusions: MASTER_SPECIFICATION_TBC,
  };
}

function WorkspaceField({ label: fieldLabel, value }: { label: string; value: string | null | undefined }) {
  return <div><p className="text-xs font-medium text-muted-foreground">{fieldLabel}</p><p className="mt-1 whitespace-pre-wrap text-sm">{text(value)}</p></div>;
}

function SpecificationEditor({ opportunity, specification, version, onSaved }: { opportunity: SalesOpportunity; specification: MasterSpecificationSummary | null; version: Version | null; onSaved: () => void }) {
  const save = useServerFn(saveMasterSpecification);
  const [saving, setSaving] = useState(false);
  const draft = useMemo(() => initialDraft(opportunity, version?.specification_data), [opportunity, version?.specification_data]);
  const [workstreams, setWorkstreams] = useState<string[]>(draft.workstreams);

  useEffect(() => setWorkstreams(draft.workstreams), [draft.workstreams]);

  async function submit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
function FeasibilityHandoverDialog({ open, onOpenChange, departments, employees }: { open: boolean; onOpenChange: (open: boolean) => void; departments: Props["departments"]; employees: Props["employees"] }) {
  const [departmentId, setDepartmentId] = useState("");
  const [reviewerUserId, setReviewerUserId] = useState("");
  return <Dialog open={open} onOpenChange={onOpenChange}><DialogContent className="max-h-[90vh] w-[calc(100%-1rem)] max-w-lg overflow-y-auto sm:w-full"><DialogHeader><DialogTitle>Send for feasibility</DialogTitle><DialogDescription>Prepare a selected department and intended reviewer. Sending remains unavailable until the protected handover is approved.</DialogDescription></DialogHeader><div className="space-y-4"><div><Label htmlFor="feasibility-department">Department</Label><select id="feasibility-department" className="mt-1 flex h-10 w-full rounded-md border bg-background px-3 text-sm" value={departmentId} onChange={(event) => setDepartmentId(event.target.value)}><option value="">Choose a department</option>{departments.map((department) => <option key={department.id} value={department.id}>{department.name}{department.code ? ` · ${department.code}` : ""}</option>)}</select></div><div><Label htmlFor="feasibility-reviewer">Intended reviewer</Label><select id="feasibility-reviewer" className="mt-1 flex h-10 w-full rounded-md border bg-background px-3 text-sm" value={reviewerUserId} onChange={(event) => setReviewerUserId(event.target.value)}><option value="">Choose an intended reviewer</option>{employees.map((employee) => <option key={employee.user_id} value={employee.user_id}>{employee.display_name ?? employee.official_email ?? "Employee"}</option>)}</select><p className="mt-1 text-xs text-muted-foreground">This list is not a membership decision. The protected action must verify active department membership before it can save.</p></div><div><Label htmlFor="feasibility-due">Due date</Label><Input id="feasibility-due" disabled placeholder="Not available" /><p className="mt-1 text-xs text-muted-foreground">{salesFeasibilityHandoverAvailability.dueDateDetail}</p></div><section className="border p-3 text-sm"><p className="font-medium">Not ready to send</p><p className="mt-1 text-muted-foreground">{salesFeasibilityHandoverAvailability.detail}</p></section><DialogFooter><Button type="button" variant="outline" onClick={() => onOpenChange(false)}>Close</Button><Button disabled type="button" title={salesFeasibilityHandoverAvailability.reason}>Send for feasibility</Button></DialogFooter></div></DialogContent></Dialog>;
}

export function OpportunityDetail({ opportunity, specification, requirements, reviews, departments, employees, feasibilityProvenance, onViewSpecification, onOpenChange }: Props) {
  const queryClient = useQueryClient();
  const [editingSpecification, setEditingSpecification] = useState(false);
  const [handoverOpen, setHandoverOpen] = useState(false);
  const version = useQuery({
    queryKey: ["opportunity-specification-version", specification?.id, specification?.current_version],
    queryFn: async () => { const { data, error } = await (supabase as any).from("master_specification_versions").select("id,version_number,change_summary,created_at,specification_data").eq("specification_id", specification?.id).eq("version_number", specification?.current_version).single(); if (error) throw error; return data as Version; },
    enabled: Boolean(specification?.id), retry: false,
  });
  const customer = useQuery({ queryKey: ["opportunity-customer", opportunity?.customer?.id], queryFn: async () => { const { data, error } = await (supabase as any).from("customers").select("customer_code,legal_name,display_name,customer_type,industry,website,primary_email,primary_phone,status,notes,updated_at").eq("id", opportunity?.customer?.id).single(); if (error) throw error; return data as Record<string, string | null>; }, enabled: Boolean(opportunity?.customer?.id), retry: false });
  const linkedRequirements = requirements.filter((item) => item.opportunity_id === opportunity?.id);
  const linkedReviews = reviews.filter((review) => linkedRequirements.some((requirement) => requirement.id === review.requirement_id));
  const saveComplete = async () => { setEditingSpecification(false); await queryClient.invalidateQueries({ queryKey: ["sales_overview"] }); await queryClient.invalidateQueries({ queryKey: ["opportunity-specification-version"] }); };
  return <><Dialog open={Boolean(opportunity)} onOpenChange={onOpenChange}><DialogContent className="max-h-[92vh] w-[calc(100%-1rem)] max-w-5xl overflow-x-hidden overflow-y-auto sm:w-full"><DialogHeader className="min-w-0"><DialogTitle className="break-words">{opportunity?.opportunity_number ?? "Opportunity"}</DialogTitle><DialogDescription className="break-words [overflow-wrap:anywhere]">{opportunity?.customer?.legal_name ?? "Customer not linked"} · {opportunity?.name}</DialogDescription></DialogHeader>{opportunity && <Tabs defaultValue="overview" className="min-w-0 space-y-4"><TabsList className="h-auto max-w-full justify-start overflow-x-auto"><TabsTrigger className="shrink-0" value="overview">Overview</TabsTrigger><TabsTrigger className="shrink-0" value="customer-inputs">Customer inputs</TabsTrigger><TabsTrigger className="shrink-0" value="feasibility">Feasibility</TabsTrigger><TabsTrigger className="shrink-0" value="history">History</TabsTrigger></TabsList><TabsContent value="overview" className="space-y-4"><section className="grid min-w-0 gap-3 border p-3 sm:grid-cols-2"><WorkspaceField label="Customer" value={opportunity.customer?.legal_name} /><WorkspaceField label="Status" value={label(opportunity.status)} /><WorkspaceField label="Stage" value={label(opportunity.stage)} /><WorkspaceField label="Owner" value="Not assigned" /><WorkspaceField label="Next action" value={opportunity.next_action} /><WorkspaceField label="Application" value={opportunity.application} /></section><section className="border p-3"><h3 className="font-medium">Project status</h3><p className="mt-1 text-sm text-muted-foreground">This is a proposed opportunity, not a project. A project can only be created through the approved baseline and required-review path; a feasibility verdict alone does not convert it.</p></section></TabsContent><TabsContent value="customer-inputs" className="space-y-4"><section className="border p-3"><div className="flex flex-wrap items-start justify-between gap-3"><div><h3 className="font-medium">Master Specification</h3><p className="mt-1 text-sm text-muted-foreground">{specification ? `${specification.specification_number} · revision ${specification.current_version}` : "No saved specification is linked to this opportunity."}</p></div>{specification && <Button type="button" size="sm" variant="outline" onClick={onViewSpecification}>Open source view</Button>}</div>{specification && <div className="mt-3 max-w-full overflow-x-auto"><table className="min-w-[34rem] text-left text-sm"><thead className="border-b text-muted-foreground"><tr><th className="pb-2 pr-3">Version</th><th className="pb-2 pr-3">Saved</th><th className="pb-2">Change note</th></tr></thead><tbody><tr><td className="py-2 pr-3">rev {version.data?.version_number ?? specification.current_version}</td><td className="py-2 pr-3">{version.data?.created_at ? new Date(version.data.created_at).toLocaleString() : "Loading"}</td><td className="break-words py-2">{version.data?.change_summary ?? "Not recorded"}</td></tr></tbody></table></div>}{editingSpecification ? <div className="mt-4 border-t pt-4"><SpecificationEditor opportunity={opportunity} specification={specification} version={version.data ?? null} onSaved={() => void saveComplete()} /></div> : <Button type="button" className="mt-4" variant="outline" onClick={() => setEditingSpecification(true)}>{specification ? "Edit as new revision" : "Add Master Specification"}</Button>}</section></TabsContent><TabsContent value="feasibility" className="space-y-4"><section className="border p-3"><div className="flex flex-wrap items-center justify-between gap-3"><h3 className="font-medium">Assigned reviews</h3><Button type="button" size="sm" variant="outline" onClick={() => setHandoverOpen(true)}>Prepare feasibility handover</Button></div>{linkedRequirements.length === 0 ? <div className="mt-3 space-y-2"><p className="text-sm text-muted-foreground">Not sent for feasibility; no assigned team.</p><Button disabled type="button" title={salesFeasibilityHandoverAvailability.reason}>Send for feasibility</Button><p className="text-xs text-muted-foreground">{salesFeasibilityHandoverAvailability.detail}</p></div> : linkedReviews.map((review) => { const reviewer = employees.find((employee) => employee.user_id === review.reviewer_user_id); return <div key={review.id} className="mt-3 grid min-w-0 gap-2 border-l-2 border-primary/30 pl-3 text-sm sm:grid-cols-2"><WorkspaceField label="Requirement" value={review.requirement?.requirement_number ?? "Not recorded"} /><WorkspaceField label="Department" value={review.department?.name ?? departments.find((department) => department.id === review.department_id)?.name} /><WorkspaceField label="Assigned person" value={reviewer?.display_name ?? reviewer?.official_email ?? "Not assigned"} /><WorkspaceField label="Reviewer status" value={label(review.status)} /><WorkspaceField label="Verdict recorded" value={review.reviewed_at ? new Date(review.reviewed_at).toLocaleString() : "Not recorded"} /><WorkspaceField label="Conditions" value={review.assumptions || review.risks} /></div>; })}</section><section className="border p-3"><h3 className="font-medium">Review status</h3><p className="mt-1 text-sm text-muted-foreground">{feasibilityProvenance.available ? "Immutable feasibility source pins are available for read-only planning." : feasibilityProvenance.error ?? "Immutable feasibility source pins are not available."}</p><p className="mt-2 text-xs text-muted-foreground">Reviewer decisions are displayed only from linked review records. Baseline approval and project start remain separate controlled steps.</p></section></TabsContent><TabsContent value="history"><section className="border p-3"><h3 className="font-medium">Source and history</h3><div className="mt-3 grid gap-3 sm:grid-cols-2"><WorkspaceField label="Opportunity" value={opportunity.opportunity_number} /><WorkspaceField label="Master Specification" value={specification ? `${specification.specification_number} · rev ${specification.current_version}` : "Not linked"} /><WorkspaceField label="Saved specification revision" value={version.data?.version_number != null ? String(version.data.version_number) : "Not recorded"} /></div></section></TabsContent></Tabs>}</DialogContent></Dialog><FeasibilityHandoverDialog open={handoverOpen} onOpenChange={setHandoverOpen} departments={departments} employees={employees} /></>;
}
