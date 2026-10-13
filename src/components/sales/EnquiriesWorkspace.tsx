import { useMemo, useState } from "react";
import { Plus, Search } from "lucide-react";
import type { CustomerRequirement, FeasibilityReview, SalesEnquiry, SalesOpportunity } from "@/lib/sales";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";

type WorkItem = {
  id: string;
  kind: "opportunity" | "enquiry";
  customer: string;
  subject: string;
  code: string;
  stage: string;
  owner: string;
  nextAction: string;
  status: string;
  feasibility: FeasibilitySummary;
  isSample: boolean;
  sourceEnquiryId: string | null;
  record: SalesEnquiry | SalesOpportunity;
};

type Props = {
  enquiries: SalesEnquiry[];
  opportunities: SalesOpportunity[];
  requirements: CustomerRequirement[];
  reviews: FeasibilityReview[];
  onNew: () => void;
  onOpenEnquiry: (enquiry: SalesEnquiry) => void;
  onOpenOpportunity: (opportunity: SalesOpportunity) => void;
};

function label(value: string) { return value.replaceAll("_", " "); }
function isMarkedSample(name: string | null | undefined) { return (name ?? "").toUpperCase().includes("SAMPLE ONLY") || (name ?? "").toUpperCase().includes("SYNTHETIC ONLY"); }
type FeasibilitySummary = { label: string; counts: string; nextAction: string };
const completedReviewStatuses = new Set(["feasible", "feasible_with_conditions", "not_feasible"]);

function feasibilitySummary(opportunityId: string, requirements: CustomerRequirement[], reviews: FeasibilityReview[]): FeasibilitySummary {
  const linkedRequirementIds = requirements.filter((requirement) => requirement.opportunity_id === opportunityId).map((requirement) => requirement.id);
  const linkedReviews = reviews.filter((review) => linkedRequirementIds.includes(review.requirement_id));
  if (!linkedReviews.length) return { label: "Not sent for feasibility", counts: "No assigned team", nextAction: "Review routing is unavailable" };
  const completed = linkedReviews.filter((review) => completedReviewStatuses.has(review.status)).length;
  const pending = linkedReviews.length - completed;
  const departments = new Set(linkedReviews.map((review) => review.department_id).filter((value): value is string => Boolean(value))).size;
  return { label: `${departments} assigned ${departments === 1 ? "department" : "departments"}`, counts: `${pending} pending · ${completed} completed`, nextAction: pending ? "Await assigned review" : "Review recorded" };
}

export function EnquiriesWorkspace({ enquiries, opportunities, requirements, reviews, onNew, onOpenEnquiry, onOpenOpportunity }: Props) {
  const [search, setSearch] = useState("");
  const [status, setStatus] = useState("all");
  const statuses = useMemo(() => [...new Set([...enquiries.map((enquiry) => enquiry.status), ...opportunities.map((opportunity) => opportunity.status)])].sort(), [enquiries, opportunities]);
  const items = useMemo<WorkItem[]>(() => {
    const enquiryItems = enquiries.map((enquiry) => ({
      id: enquiry.id,
      kind: "enquiry" as const,
      customer: enquiry.customer?.legal_name ?? "Customer not linked",
      subject: enquiry.requirement_summary,
      code: enquiry.enquiry_number,
      stage: enquiry.status,
      owner: "Owner not assigned",
      nextAction: enquiry.next_action ?? "No next action",
      status: enquiry.status,
      feasibility: { label: "Not sent for feasibility", counts: "No assigned team", nextAction: "Review routing is unavailable" },
      isSample: Boolean(enquiry.customer?.is_sample) || isMarkedSample(enquiry.customer?.legal_name) || isMarkedSample(enquiry.requirement_summary),
      sourceEnquiryId: null,
      record: enquiry,
    }));
    const opportunityItems = opportunities.map((opportunity) => ({
      id: opportunity.id,
      kind: "opportunity" as const,
      customer: opportunity.customer?.legal_name ?? "Customer not linked",
      subject: opportunity.name,
      code: opportunity.opportunity_number,
      stage: opportunity.stage,
      owner: "Owner not assigned",
      nextAction: opportunity.next_action ?? "No next action",
      status: opportunity.status,
      feasibility: feasibilitySummary(opportunity.id, requirements, reviews),
      isSample: Boolean(opportunity.customer?.is_sample) || isMarkedSample(opportunity.customer?.legal_name) || isMarkedSample(opportunity.name),
      sourceEnquiryId: opportunity.enquiry_id,
      record: opportunity,
    }));
    return [...opportunityItems.sort((left, right) => Number(right.status === "active") - Number(left.status === "active")), ...enquiryItems];
  }, [enquiries, opportunities, requirements, reviews]);
  const visible = useMemo(() => items.filter((item) => {
    const needle = search.trim().toLowerCase();
    return (status === "all" || item.status === status) && (!needle || [item.code, item.subject, item.customer, item.stage, item.nextAction].some((value) => value.toLowerCase().includes(needle)));
  }), [items, search, status]);
  return <div className="min-w-0 space-y-6"><div className="grid grid-cols-[minmax(0,1fr)_auto] items-end gap-4 lg:flex lg:flex-wrap lg:justify-between"><div className="min-w-0"><p className="text-sm font-medium text-primary">Sales work</p><h1 className="mt-1 break-words text-2xl font-semibold">Enquiries &amp; Opportunities</h1><p className="mt-2 max-w-2xl text-sm text-muted-foreground">Review active opportunities first, then saved enquiries that are ready for the next step.</p></div><Button className="shrink-0" onClick={onNew}><Plus className="size-4" />New enquiry</Button></div><Card className="min-w-0 overflow-hidden"><CardHeader><CardTitle>Sales work</CardTitle><CardDescription>Review sending is not available yet.</CardDescription></CardHeader><CardContent className="min-w-0 space-y-4"><div className="grid gap-3 sm:grid-cols-[minmax(0,1fr)_12rem]"><div className="relative min-w-0"><Search className="absolute left-2.5 top-2.5 size-4 shrink-0 text-muted-foreground" /><Input value={search} onChange={(event) => setSearch(event.target.value)} className="pl-9" placeholder="Search customer, code, subject, stage, or next action" /></div><Select value={status} onValueChange={setStatus}><SelectTrigger className="w-full min-w-0"><SelectValue placeholder="All statuses" /></SelectTrigger><SelectContent><SelectItem value="all">All statuses</SelectItem>{statuses.map((item) => <SelectItem key={item} value={item}>{label(item)}</SelectItem>)}</SelectContent></Select></div><div className="hidden min-w-[62rem] grid-cols-[minmax(8rem,1fr)_minmax(13rem,1.6fr)_minmax(8rem,.8fr)_minmax(11rem,1fr)_minmax(7rem,.65fr)_minmax(9rem,.85fr)] gap-3 border-b pb-2 text-xs font-medium text-muted-foreground xl:grid"><span>Customer</span><span>Subject</span><span>Status / stage</span><span>Feasibility</span><span>Owner</span><span>Next action</span></div><div className="max-w-full overflow-x-auto"><div className="min-w-[19rem] divide-y xl:min-w-[62rem]">{visible.map((item) => <button key={`${item.kind}-${item.id}`} type="button" onClick={() => item.kind === "opportunity" ? onOpenOpportunity(item.record as SalesOpportunity) : onOpenEnquiry(item.record as SalesEnquiry)} className="grid w-full min-w-0 gap-3 py-4 text-left xl:grid-cols-[minmax(8rem,1fr)_minmax(13rem,1.6fr)_minmax(8rem,.8fr)_minmax(11rem,1fr)_minmax(7rem,.65fr)_minmax(9rem,.85fr)]"><div className="min-w-0"><p className="break-words text-sm font-medium [overflow-wrap:anywhere]">{item.customer}</p><p className="mt-1 truncate text-xs text-muted-foreground" title={item.code}>{item.code}</p></div><div className="min-w-0"><div className="flex min-w-0 flex-wrap items-start gap-1.5"><p className="min-w-0 break-words font-medium [overflow-wrap:anywhere]">{item.subject}</p><Badge className="shrink-0 px-1.5 py-0 text-[11px]" variant="outline">{item.kind === "opportunity" ? "Opportunity" : "Enquiry"}</Badge>{item.isSample && <Badge className="shrink-0 px-1.5 py-0 text-[11px]" variant="secondary">Sample</Badge>}{item.sourceEnquiryId && <Badge className="shrink-0 px-1.5 py-0 text-[11px]" variant="secondary">Linked</Badge>}</div><div className="mt-2 space-y-1 text-xs text-muted-foreground xl:hidden"><p><span className="font-medium text-foreground">Status:</span> {label(item.status)} · {label(item.stage)}</p><p><span className="font-medium text-foreground">Feasibility:</span> {item.feasibility.label} · {item.feasibility.counts}</p><p className="break-words"><span className="font-medium text-foreground">Next:</span> {item.nextAction}</p></div></div><div className="hidden min-w-0 flex-wrap content-start gap-1 xl:flex"><Badge className="max-w-full truncate px-1.5 py-0 text-[11px]" title={label(item.status)} variant="outline">{label(item.status)}</Badge>{item.kind === "opportunity" && <Badge className="max-w-full truncate px-1.5 py-0 text-[11px]" title={label(item.stage)} variant="secondary">{label(item.stage)}</Badge>}</div><div className="hidden min-w-0 xl:block"><p className="break-words text-sm font-medium [overflow-wrap:anywhere]">{item.feasibility.label}</p><p className="mt-1 text-xs text-muted-foreground">{item.feasibility.counts}</p></div><p className="hidden min-w-0 truncate text-sm text-muted-foreground xl:block" title={item.owner}>{item.owner}</p><p className="hidden min-w-0 truncate text-sm text-muted-foreground xl:block" title={item.nextAction}>{item.nextAction}</p></button>)}{!visible.length && <p className="py-10 text-center text-sm text-muted-foreground">No authorised enquiries or opportunities match these filters.</p>}</div></div></CardContent></Card></div>;
}