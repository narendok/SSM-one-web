import { useMemo, useState } from "react";
import { Plus, Search } from "lucide-react";
import type { MasterSpecificationSummary, SalesEnquiry, SalesOpportunity } from "@/lib/sales";
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
  sourceEnquiryId: string | null;
  record: SalesEnquiry | SalesOpportunity;
};

type Props = {
  enquiries: SalesEnquiry[];
  opportunities: SalesOpportunity[];
  onNew: () => void;
  onOpenEnquiry: (enquiry: SalesEnquiry) => void;
  onOpenOpportunity: (opportunity: SalesOpportunity) => void;
};

function label(value: string) { return value.replaceAll("_", " "); }

export function EnquiriesWorkspace({ enquiries, opportunities, onNew, onOpenEnquiry, onOpenOpportunity }: Props) {
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
      sourceEnquiryId: null,
      record: opportunity,
    }));
    return [...opportunityItems, ...enquiryItems];
  }, [enquiries, opportunities]);
  const visible = useMemo(() => items.filter((item) => {
    const needle = search.trim().toLowerCase();
    return (status === "all" || item.status === status) && (!needle || [item.code, item.subject, item.customer, item.stage, item.nextAction].some((value) => value.toLowerCase().includes(needle)));
  }), [items, search, status]);
  return <div className="space-y-6"><div className="flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between"><div><p className="text-sm font-medium text-primary">Sales work</p><h1 className="mt-1 text-2xl font-semibold">Enquiries &amp; Opportunities</h1><p className="mt-2 text-sm text-muted-foreground">Review active opportunities first, then saved enquiries that are ready for the next step.</p></div><Button onClick={onNew}><Plus className="size-4" />New enquiry</Button></div><Card><CardHeader><CardTitle>Sales work</CardTitle><CardDescription>Department review and enquiry-to-opportunity conversion remain unavailable until their protected operation is deployed.</CardDescription></CardHeader><CardContent className="space-y-4"><div className="flex flex-col gap-3 sm:flex-row"><div className="relative flex-1"><Search className="absolute left-2.5 top-2.5 size-4 text-muted-foreground" /><Input value={search} onChange={(event) => setSearch(event.target.value)} className="pl-9" placeholder="Search customer, code, subject, stage, or next action" /></div><Select value={status} onValueChange={setStatus}><SelectTrigger className="w-full sm:w-48"><SelectValue placeholder="All statuses" /></SelectTrigger><SelectContent><SelectItem value="all">All statuses</SelectItem>{statuses.map((item) => <SelectItem key={item} value={item}>{label(item)}</SelectItem>)}</SelectContent></Select></div><div className="divide-y">{visible.map((item) => <button key={`${item.kind}-${item.id}`} type="button" onClick={() => item.kind === "opportunity" ? onOpenOpportunity(item.record as SalesOpportunity) : onOpenEnquiry(item.record as SalesEnquiry)} className="grid w-full gap-3 py-4 text-left md:grid-cols-[minmax(9rem,1fr)_minmax(14rem,2fr)_minmax(8rem,1fr)_minmax(8rem,1fr)_minmax(10rem,1.25fr)]"><div><p className="text-sm font-medium">{item.customer}</p><p className="mt-1 text-xs text-muted-foreground">{item.code}</p></div><div><div className="flex flex-wrap items-center gap-2"><p className="font-medium">{item.subject}</p><Badge variant="outline">{item.kind === "opportunity" ? "Opportunity" : "Enquiry"}</Badge></div><p className="mt-1 text-xs text-muted-foreground md:hidden">{label(item.stage)} · {item.owner} · {item.nextAction}</p></div><p className="text-sm text-muted-foreground">{label(item.stage)}</p><p className="text-sm text-muted-foreground">{item.owner}</p><p className="text-sm text-muted-foreground">{item.nextAction}</p></button>)}{!visible.length && <p className="py-10 text-center text-sm text-muted-foreground">No authorised enquiries or opportunities match these filters.</p>}</div></CardContent></Card></div>;
}