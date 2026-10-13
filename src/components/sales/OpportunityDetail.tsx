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
    if (saving) return;
    const form = new FormData(event.currentTarget);
    try {
      const nextDraft = masterSpecificationDraftSchema.parse({
        proposedName: String(form.get("proposedName") ?? "").trim(),
        customerOrInternalOwner: String(form.get("customerOrInternalOwner") ?? "").trim(),
        industryApplication: String(form.get("industryApplication") ?? "").trim(),
        productFamily: String(form.get("productFamily") ?? "").trim(),
        developmentScope: String(form.get("developmentScope") ?? "").trim(),
        workstreams,
        requirementSummary: String(form.get("requirementSummary") ?? "").trim(),
        powerAndUnits: String(form.get("powerAndUnits") ?? "").trim(),
        interfaces: String(form.get("interfaces") ?? "").trim(),
        connectivityAndGnss: String(form.get("connectivityAndGnss") ?? "").trim(),
        environmentAndIp: String(form.get("environmentAndIp") ?? "").trim(),
        volumes: String(form.get("volumes") ?? "").trim(),
        schedule: String(form.get("schedule") ?? "").trim(),
        requestedStandards: String(form.get("requestedStandards") ?? "").trim(),
        exclusions: String(form.get("exclusions") ?? "").trim(),
      });
      const changeSummary = String(form.get("changeSummary") ?? "").trim();
      if (!changeSummary) return toast.error("Add a short description of this revision.");
      setSaving(true);
      const receipt = await save({ data: { specificationId: specification?.id ?? null, opportunityId: opportunity.id, expectedVersion: specification?.current_version ?? 0, changeSummary, draft: nextDraft } });
      toast.success(`${receipt.specificationNumber} revision ${receipt.versionNumber} saved`);
      onSaved();
    } catch (error) {
      toast.error(error instanceof Error ? error.message : "Could not save the specification revision.");
    } finally { setSaving(false); }
  }

  return <form className="space-y-4" onSubmit={(event) => void submit(event)}>
    <div className="grid gap-3 sm:grid-cols-2">
      <TextInput name="proposedName" label="Proposed name" defaultValue={draft.proposedName} />
      <TextInput name="customerOrInternalOwner" label="Customer / owner" defaultValue={draft.customerOrInternalOwner} />
      <TextInput name="industryApplication" label="Industry / application" defaultValue={draft.industryApplication} />
      <TextInput name="productFamily" label="Product family" defaultValue={draft.productFamily} />
    </div>
    <TextAreaInput name="developmentScope" label="Development scope" defaultValue={draft.developmentScope} />
    <fieldset><legend className="text-sm font-medium">Engineering workstreams</legend><div className="mt-2 flex flex-wrap gap-3">{["HARDWARE", "FIRMWARE", "MECHANICAL", "TEST", "MANUFACTURING"].map((value) => <label className="flex items-center gap-2 text-sm" key={value}><input type="checkbox" checked={workstreams.includes(value)} onChange={(event) => setWorkstreams((current) => event.target.checked ? [...current, value] : current.filter((item) => item !== value))} />{label(value)}</label>)}</div></fieldset>
    <TextAreaInput name="requirementSummary" label="Requirement summary" defaultValue={draft.requirementSummary} />
    <div className="grid gap-3 sm:grid-cols-2">
      <TextInput name="powerAndUnits" label="Power / units" defaultValue={draft.powerAndUnits} />
      <TextInput name="interfaces" label="Interfaces" defaultValue={draft.interfaces} />
      <TextInput name="connectivityAndGnss" label="Connectivity / GNSS" defaultValue={draft.connectivityAndGnss} />
      <TextInput name="environmentAndIp" label="Environment / IP" defaultValue={draft.environmentAndIp} />
      <TextInput name="volumes" label="Volumes" defaultValue={draft.volumes} />
      <TextInput name="schedule" label="Schedule" defaultValue={draft.schedule} />
      <TextInput name="requestedStandards" label="Requested standards" defaultValue={draft.requestedStandards} />
      <TextInput name="exclusions" label="Exclusions" defaultValue={draft.exclusions} />
    </div>
    <TextAreaInput name="changeSummary" label="What changed in this revision?" defaultValue="" />
    <p className="text-xs text-muted-foreground">Saving creates a new version and checks the current version first. Customer details are read-only here because no protected customer-edit action is available.</p>
    <Button type="submit" disabled={saving || workstreams.length === 0}>{saving ? "Saving revision…" : specification ? "Save new revision" : "Add Master Specification"}</Button>
  </form>;
}

function TextInput({ name, label: fieldLabel, defaultValue }: { name: string; label: string; defaultValue: string }) { return <div><Label htmlFor={name}>{fieldLabel}</Label><Input id={name} name={name} defaultValue={defaultValue} maxLength={2000} required /></div>; }
function TextAreaInput({ name, label: fieldLabel, defaultValue }: { name: string; label: string; defaultValue: string }) { return <div><Label htmlFor={name}>{fieldLabel}</Label><Textarea id={name} name={name} defaultValue={defaultValue} maxLength={12000} required /></div>; }

function FeasibilityHandoverDialog({ open, onOpenChange, departments, employees }: { open: boolean; onOpenChange: (open: boolean) => void; departments: Props["departments"]; employees: Props["employees"] }) {
  const [departmentId, setDepartmentId] = useState("");
  const [reviewerUserId, setReviewerUserId] = useState("");
  return <Dialog open={open} onOpenChange={onOpenChange}><DialogContent className="max-h-[90vh] w-[calc(100%-1rem)] max-w-lg overflow-y-auto sm:w-full"><DialogHeader><DialogTitle>Send for feasibility</DialogTitle><DialogDescription>Select the department and intended reviewer for the protected handover.</DialogDescription></DialogHeader><div className="space-y-4"><div><Label htmlFor="feasibility-department">Department</Label><select id="feasibility-department" className="mt-1 flex h-10 w-full rounded-md border bg-background px-3 text-sm" value={departmentId} onChange={(event) => setDepartmentId(event.target.value)}><option value="">Choose a department</option>{departments.map((department) => <option key={department.id} value={department.id}>{department.name}{department.code ? ` · ${department.code}` : ""}</option>)}</select></div><div><Label htmlFor="feasibility-reviewer">Reviewer</Label><select id="feasibility-reviewer" className="mt-1 flex h-10 w-full rounded-md border bg-background px-3 text-sm" value={reviewerUserId} onChange={(event) => setReviewerUserId(event.target.value)}><option value="">Choose an intended reviewer</option>{employees.map((employee) => <option key={employee.user_id} value={employee.user_id}>{employee.display_name ?? employee.official_email ?? "Employee"}</option>)}</select><p className="mt-1 text-xs text-muted-foreground">The protected handover will verify current active department membership before saving.</p></div><div><Label htmlFor="feasibility-due">Due date</Label><Input id="feasibility-due" disabled placeholder="Not available" /><p className="mt-1 text-xs text-muted-foreground">{salesFeasibilityHandoverAvailability.dueDateDetail}</p></div><section className="border p-3 text-sm"><p className="font-medium">Not ready to send</p><p className="mt-1 text-muted-foreground">{salesFeasibilityHandoverAvailability.detail}</p></section><DialogFooter><Button type="button" variant="outline" onClick={() => onOpenChange(false)}>Close</Button><Button disabled type="button" title={salesFeasibilityHandoverAvailability.reason}>Send for feasibility</Button></DialogFooter></div></DialogContent></Dialog>;
}

export function OpportunityDetail({ opportunity, specification, requirements, reviews, departments, employees, feasibilityProvenance, onViewSpecification, onOpenChange }: Props) {
  const queryClient = useQueryClient();
  const [editingSpecification, setEditingSpecification] = useState(false);
  const [handoverOpen, setHandoverOpen] = useState(false);
  const version = useQuery({
    queryKey: ["opportunity-specification-version", specification?.id, specification?.current_version],
    queryFn: async () => {
      const { data, error } = await (supabase as any).from("master_specification_versions").select("id,version_number,change_summary,created_at,specification_data").eq("specification_id", specification?.id).eq("version_number", specification?.current_version).single();
      if (error) throw error;
      return data as Version;
    },
    enabled: Boolean(specification?.id),
    retry: false,
  });
  const customer = useQuery({
    queryKey: ["opportunity-customer", opportunity?.customer?.id],
    queryFn: async () => {
      const { data, error } = await (supabase as any).from("customers").select("customer_code,legal_name,display_name,customer_type,industry,website,primary_email,primary_phone,status,notes,updated_at").eq("id", opportunity?.customer?.id).single();
      if (error) throw error;
      return data as Record<string, string | null>;
    },
    enabled: Boolean(opportunity?.customer?.id),
    retry: false,
  });
  const linkedRequirements = requirements.filter((item) => item.opportunity_id === opportunity?.id);
  const linkedReviews = reviews.filter((review) => linkedRequirements.some((requirement) => requirement.id === review.requirement_id));
  const saveComplete = async () => { setEditingSpecification(false); await queryClient.invalidateQueries({ queryKey: ["sales_overview"] }); await queryClient.invalidateQueries({ queryKey: ["opportunity-specification-version"] }); };

  return <><Dialog open={Boolean(opportunity)} onOpenChange={onOpenChange}><DialogContent className="max-h-[92vh] w-[calc(100%-1rem)] max-w-5xl overflow-x-hidden overflow-y-auto sm:w-full"><DialogHeader className="min-w-0"><DialogTitle className="break-words">{opportunity?.opportunity_number ?? "Opportunity"}</DialogTitle><DialogDescription className="break-words [overflow-wrap:anywhere]">{opportunity?.customer?.legal_name ?? "Customer not linked"} · {opportunity?.name}</DialogDescription></DialogHeader>{opportunity && <Tabs defaultValue="overview" className="min-w-0 space-y-4"><TabsList className="h-auto max-w-full justify-start overflow-x-auto"><TabsTrigger className="shrink-0" value="overview">Overview</TabsTrigger><TabsTrigger className="shrink-0" value="customer-inputs">Customer inputs</TabsTrigger><TabsTrigger className="shrink-0" value="feasibility">Feasibility</TabsTrigger><TabsTrigger className="shrink-0" value="history">History</TabsTrigger></TabsList><TabsContent value="overview" className="min-w-0 space-y-4"><section className="grid min-w-0 gap-3 border p-3 sm:grid-cols-2"><WorkspaceField label="Customer" value={opportunity.customer?.legal_name} /><WorkspaceField label="Status" value={label(opportunity.status)} /><WorkspaceField label="Stage" value={label(opportunity.stage)} /><WorkspaceField label="Owner" value="Not assigned" /><WorkspaceField label="Next action" value={opportunity.next_action} /><WorkspaceField label="Application" value={opportunity.application} /><WorkspaceField label="Product family" value={opportunity.product_type} /><WorkspaceField label="Estimated volume" value={opportunity.estimated_volume} /></section><section className="min-w-0 border p-3"><h3 className="font-medium">Stage progress</h3><div className="mt-3 grid min-w-0 gap-2 text-sm sm:grid-cols-3"><div className="min-w-0 border-l-2 border-primary pl-3"><p className="font-medium">Enquiry</p><p className="break-words text-muted-foreground">Saved sales record</p></div><div className="min-w-0 border-l-2 border-muted-foreground/30 pl-3"><p className="font-medium">Internal Sales review</p><p className="break-words text-muted-foreground">No protected review route is available</p></div><div className="min-w-0 border-l-2 border-muted-foreground/30 pl-3"><p className="font-medium">Feasibility</p><p className="break-words text-muted-foreground">Only assigned reviews are shown</p></div></div></section><section className="border p-3"><h3 className="font-medium">Project status</h3><p className="mt-1 break-words text-sm text-muted-foreground">This is a proposed opportunity, not a project. A project can only be created through the approved baseline and required-review path; a feasibility verdict alone does not convert it.</p></section></TabsContent><TabsContent value="customer-inputs" className="min-w-0 space-y-4"><section className="border p-3"><div className="grid grid-cols-[minmax(0,1fr)_auto] items-start gap-3"><div className="min-w-0"><h3 className="font-medium">Linked customer</h3><p className="mt-1 text-sm text-muted-foreground">Existing customer details are shown from the authorised customer record.</p></div><Badge className="shrink-0" variant="outline">Read only</Badge></div>{customer.isLoading ? <p className="mt-3 text-sm text-muted-foreground">Loading customer record…</p> : customer.isError ? <p className="mt-3 text-sm text-destructive">Customer details could not be read.</p> : <div className="mt-3 grid min-w-0 gap-3 sm:grid-cols-2"><WorkspaceField label="Customer code" value={customer.data?.customer_code} /><WorkspaceField label="Legal name" value={customer.data?.legal_name} /><WorkspaceField label="Display name" value={customer.data?.display_name} /><WorkspaceField label="Customer type" value={customer.data?.customer_type} /><WorkspaceField label="Industry" value={customer.data?.industry} /><WorkspaceField label="Website" value={customer.data?.website} /><WorkspaceField label="Email" value={customer.data?.primary_email} /><WorkspaceField label="Phone" value={customer.data?.primary_phone} /></div>}<p className="mt-3 text-xs text-muted-foreground">Editing customer details is not offered because the available customer contract creates records only; it does not provide a protected edit action.</p></section><section className="min-w-0 border p-3"><div className="grid grid-cols-[minmax(0,1fr)_auto] items-start gap-3"><div className="min-w-0"><h3 className="font-medium">Master Specification</h3><p className="mt-1 break-words text-sm text-muted-foreground">{specification ? `${specification.specification_number} · revision ${specification.current_version}` : "No saved specification is linked to this opportunity."}</p></div>{specification && <Button className="shrink-0" type="button" size="sm" variant="outline" onClick={onViewSpecification}>Open source view</Button>}</div>{specification && <div className="mt-3 max-w-full overflow-x-auto"><table className="min-w-[34rem] text-left text-sm"><thead className="border-b text-muted-foreground"><tr><th className="pb-2 pr-3 font-medium">Version</th><th className="pb-2 pr-3 font-medium">Saved</th><th className="pb-2 font-medium">Change note</th></tr></thead><tbody><tr><td className="py-2 pr-3">rev {version.data?.version_number ?? specification.current_version}</td><td className="py-2 pr-3">{version.data?.created_at ? new Date(version.data.created_at).toLocaleString() : "Loading"}</td><td className="max-w-[24rem] break-words py-2 [overflow-wrap:anywhere]">{version.data?.change_summary ?? "Not recorded"}</td></tr></tbody></table></div>}{editingSpecification ? <div className="mt-4 border-t pt-4"><SpecificationEditor opportunity={opportunity} specification={specification} version={version.data ?? null} onSaved={() => void saveComplete()} /></div> : <Button type="button" className="mt-4" variant="outline" onClick={() => setEditingSpecification(true)}>{specification ? "Edit as new revision" : "Add Master Specification"}</Button>}<p className="mt-3 text-xs text-muted-foreground">The source and version stay pinned to this opportunity. Saving checks the expected version before creating a new revision.</p></section></TabsContent><TabsContent value="feasibility" className="min-w-0 space-y-4"><section className="min-w-0 border p-3"><div className="flex flex-wrap items-center justify-between gap-3"><h3 className="font-medium">Assigned reviews</h3><Button type="button" size="sm" variant="outline" onClick={() => setHandoverOpen(true)}>Prepare feasibility handover</Button></div>{!linkedRequirements.length && <div className="mt-2 space-y-3"><p className="text-sm text-muted-foreground">Not sent for feasibility; no assigned team.</p><Button disabled title={salesFeasibilityHandoverAvailability.reason} type="button">Send for feasibility</Button><p className="text-xs text-muted-foreground">{salesFeasibilityHandoverAvailability.detail}</p></div>}{linkedReviews.map((review) => { const reviewer = employees.find((employee) => employee.user_id === review.reviewer_user_id); return <div key={review.id} className="mt-3 grid min-w-0 gap-2 border-l-2 border-primary/30 pl-3 text-sm sm:grid-cols-2"><WorkspaceField label="Requirement" value={review.requirement?.requirement_number ? `${review.requirement.requirement_number} · ${review.requirement.title ?? ""}` : "Not recorded"} /><WorkspaceField label="Department" value={review.department?.name ?? departments.find((department) => department.id === review.department_id)?.name} /><WorkspaceField label="Assigned person" value={reviewer?.display_name ?? reviewer?.official_email ?? (review.reviewer_user_id ? "Assigned person not visible" : "Not assigned")} /><WorkspaceField label="Reviewer status" value={label(review.status)} /><WorkspaceField label="Verdict recorded" value={review.reviewed_at ? new Date(review.reviewed_at).toLocaleString() : "Not recorded"} /><WorkspaceField label="Conditions" value={review.assumptions || review.risks} /></div>; })}</section><section className="border p-3"><h3 className="font-medium">Review status</h3><p className="mt-1 break-words text-sm text-muted-foreground">{feasibilityProvenance.available ? "Immutable feasibility source pins are available for read-only planning." : feasibilityProvenance.error ?? "Immutable feasibility source pins are not available."}</p><p className="mt-2 text-xs text-muted-foreground">Reviewer decisions are recorded only through the assigned-reviewer protected response path. Baseline approval and project start remain separate controlled steps.</p></section></TabsContent><TabsContent value="history" className="min-w-0 space-y-4"><section className="border p-3"><h3 className="font-medium">Source and history</h3><div className="mt-3 grid min-w-0 gap-3 sm:grid-cols-2"><WorkspaceField label="Opportunity" value={opportunity.opportunity_number} /><WorkspaceField label="Master Specification" value={specification ? `${specification.specification_number} · rev ${specification.current_version}` : "Not linked"} /><WorkspaceField label="Saved specification revision" value={version.data?.version_number != null ? String(version.data.version_number) : "Not recorded
}