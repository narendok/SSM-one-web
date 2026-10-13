import { useMemo, useState } from "react";
import { Plus, Search } from "lucide-react";
import type { SalesEnquiry } from "@/lib/sales";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";

type Props = { enquiries: SalesEnquiry[]; onNew: () => void; onOpen: (enquiry: SalesEnquiry) => void };

function label(value: string) { return value.replaceAll("_", " "); }

export function EnquiriesWorkspace({ enquiries, onNew, onOpen }: Props) {
  const [search, setSearch] = useState("");
  const [status, setStatus] = useState("all");
  const statuses = useMemo(() => [...new Set(enquiries.map((enquiry) => enquiry.status))].sort(), [enquiries]);
  const visible = useMemo(() => enquiries.filter((enquiry) => {
    const needle = search.trim().toLowerCase();
    return (status === "all" || enquiry.status === status) && (!needle || [enquiry.enquiry_number, enquiry.requirement_summary, enquiry.customer?.legal_name, enquiry.status].filter(Boolean).some((value) => value?.toLowerCase().includes(needle)));
  }), [enquiries, search, status]);
  return <div className="space-y-6"><div className="flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between"><div><p className="text-sm font-medium text-primary">Sales work</p><h1 className="mt-1 text-2xl font-semibold">Enquiries</h1><p className="mt-2 text-sm text-muted-foreground">Search saved customer needs and reopen their details to continue the available work.</p></div><Button onClick={onNew}><Plus className="size-4" />New enquiry</Button></div><Card><CardHeader><CardTitle>Saved enquiries</CardTitle><CardDescription>Department review remains unavailable until its protected routing action is deployed.</CardDescription></CardHeader><CardContent className="space-y-4"><div className="flex flex-col gap-3 sm:flex-row"><div className="relative flex-1"><Search className="absolute left-2.5 top-2.5 size-4 text-muted-foreground" /><Input value={search} onChange={(event) => setSearch(event.target.value)} className="pl-9" placeholder="Search customer, enquiry code, requirement, or status" /></div><Select value={status} onValueChange={setStatus}><SelectTrigger className="w-full sm:w-48"><SelectValue placeholder="All statuses" /></SelectTrigger><SelectContent><SelectItem value="all">All statuses</SelectItem>{statuses.map((item) => <SelectItem key={item} value={item}>{label(item)}</SelectItem>)}</SelectContent></Select></div><div className="divide-y">{visible.map((enquiry) => <button key={enquiry.id} type="button" onClick={() => onOpen(enquiry)} className="grid w-full gap-2 py-4 text-left md:grid-cols-[minmax(0,1fr)_auto]"><div><div className="flex flex-wrap items-center gap-2"><p className="font-medium">{enquiry.enquiry_number}</p><Badge variant="outline">{label(enquiry.priority)}</Badge></div><p className="mt-1 text-sm">{enquiry.requirement_summary}</p><p className="mt-1 text-xs text-muted-foreground">{enquiry.customer?.legal_name ?? "Customer not linked"} · {enquiry.enquiry_date} · {enquiry.next_action ?? "No next action"}</p></div><Badge variant="outline" className="h-fit w-fit">{label(enquiry.status)}</Badge></button>)}{!visible.length && <p className="py-10 text-center text-sm text-muted-foreground">No saved enquiries match these filters.</p>}</div></CardContent></Card></div>;
}