import { Link } from "@tanstack/react-router";
import { AlertCircle, ArrowRight, CircleAlert, ClipboardList, Headset, Layers3, Users } from "lucide-react";
import type { ProjectTask } from "@/lib/tasks";
import type { SalesCustomer, SalesEnquiry, SalesOpportunity } from "@/lib/sales";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";

type SupportTicket = {
  id: string;
  complaint_code: string;
  title: string;
  severity: string;
  status: string;
  owner_user_id: string | null;
  customer_visible_update: string | null;
  updated_at: string;
};

type Props = {
  customers: SalesCustomer[];
  enquiries: SalesEnquiry[];
  opportunities: SalesOpportunity[];
  tickets: SupportTicket[] | null;
  tasks: ProjectTask[] | null;
  onOpenEnquiry: (enquiry: SalesEnquiry) => void;
};

const openEnquiryStatuses = new Set(["draft", "open", "new", "in_review", "under_review", "pending_review", "pending"]);
const openTaskStatuses = new Set(["todo", "in_progress", "in_review", "blocked"]);

function label(value: string) {
  return value.replaceAll("_", " ");
}

function dueLabel(date: string | null) {
  if (!date) return "No due date";
  const today = new Date().toISOString().slice(0, 10);
  if (date < today) return `Overdue · ${date}`;
  if (date === today) return "Due today";
  return `Due ${date}`;
}

export function SalesDashboard({ customers, enquiries, opportunities, tickets, tasks, onOpenEnquiry }: Props) {
  const ongoingEnquiries = enquiries.filter((enquiry) => openEnquiryStatuses.has(enquiry.status.toLowerCase()));
  const activeProjects = opportunities.filter((opportunity) => opportunity.status.toLowerCase() === "active");
  const openTickets = tickets?.filter((ticket) => !["closed", "resolved", "cancelled"].includes(ticket.status.toLowerCase())) ?? [];
  const salesTasks = tasks?.filter((task) => task.department === "executive" && openTaskStatuses.has(task.status)) ?? [];
  const overdueTasks = salesTasks.filter((task) => Boolean(task.due_date && task.due_date < new Date().toISOString().slice(0, 10)));

  const metrics = [
    { label: "Total customers", value: customers.length, detail: "Active customer master records" },
    { label: "Ongoing enquiries", value: ongoingEnquiries.length, detail: "Saved enquiries still in progress" },
    { label: "Active client projects", value: activeProjects.length, detail: "Active sales opportunities" },
    { label: "Deployed devices", value: "Not recorded", detail: "No deployed-device read model is available" },
    { label: "Open customer tickets", value: tickets === null ? "Unavailable" : openTickets.length, detail: tickets === null ? "Customer-support records are not available to this view" : "Open customer-support records" },
    { label: "Overdue sales tasks", value: tasks === null ? "Unavailable" : overdueTasks.length, detail: tasks === null ? "Sales team tasks are not available to this view" : "Past-due sales work" },
  ];

  return <div className="space-y-6">
    <section className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
      {metrics.map((metric) => <Card key={metric.label}><CardHeader className="pb-2"><CardDescription>{metric.label}</CardDescription><CardTitle className="text-2xl">{metric.value}</CardTitle></CardHeader><CardContent className="text-xs text-muted-foreground">{metric.detail}</CardContent></Card>)}
    </section>
    <section className="grid gap-5 xl:grid-cols-3">
      <WorkColumn icon={ClipboardList} title="Ongoing enquiries" description="Saved customer needs that need a next step." link={{ to: "/sales/enquiries", label: "View enquiries" }}>
        {ongoingEnquiries.slice(0, 6).map((enquiry) => <button type="button" key={enquiry.id} onClick={() => onOpenEnquiry(enquiry)} className="w-full border-l-2 border-primary/30 py-1 pl-3 text-left"><div className="flex items-start justify-between gap-2"><p className="font-medium">{enquiry.enquiry_number}</p><Badge variant="outline">{label(enquiry.status)}</Badge></div><p className="mt-1 line-clamp-2 text-sm">{enquiry.requirement_summary}</p><p className="mt-1 text-xs text-muted-foreground">{enquiry.customer?.legal_name ?? "Customer not linked"} · {enquiry.next_action ?? "No next action"}</p><p className="mt-1 text-xs text-muted-foreground">{dueLabel(enquiry.next_action_date)}</p></button>)}
        {!ongoingEnquiries.length && <EmptyState icon={ClipboardList} text="No ongoing enquiries are recorded." />}
      </WorkColumn>
      <WorkColumn icon={Headset} title="Customer support" description="Customer-support records available to your access." link={{ to: "/customer-service", label: "Open support" }}>
        {tickets === null && <EmptyState icon={CircleAlert} text="Customer-support records are not available to this Sales view." />}
        {tickets !== null && openTickets.slice(0, 6).map((ticket) => <div key={ticket.id} className="border-l-2 border-primary/30 py-1 pl-3"><div className="flex items-start justify-between gap-2"><p className="font-medium">{ticket.complaint_code}</p><Badge variant="outline">{label(ticket.status)}</Badge></div><p className="mt-1 text-sm">{ticket.title}</p><p className="mt-1 text-xs text-muted-foreground">{label(ticket.severity)} · {ticket.customer_visible_update ?? "No customer update recorded"}</p></div>)}
        {tickets !== null && !openTickets.length && <EmptyState icon={Headset} text="No open customer-support records are visible." />}
      </WorkColumn>
      <WorkColumn icon={Users} title="Sales team work" description="Tasks tagged to the existing sales work scope." link={{ to: "/tasks", label: "Open task board" }}>
        {tasks === null && <EmptyState icon={CircleAlert} text="Sales team tasks are not available to this view." />}
        {tasks !== null && salesTasks.slice(0, 6).map((task) => <div key={task.id} className="border-l-2 border-primary/30 py-1 pl-3"><div className="flex items-start justify-between gap-2"><p className="font-medium">{task.title}</p><Badge variant="outline">{label(task.status)}</Badge></div><p className="mt-1 text-xs text-muted-foreground">{task.assignee?.name ?? "Owner not assigned"} · {task.project?.code ?? "No project"}</p><p className="mt-1 text-xs text-muted-foreground">{dueLabel(task.due_date)}{task.status === "blocked" ? " · Blocked" : ""}</p></div>)}
        {tasks !== null && !salesTasks.length && <EmptyState icon={Users} text="No open sales team tasks are recorded." />}
      </WorkColumn>
    </section>
  </div>;
}

function WorkColumn({ icon: Icon, title, description, link, children }: { icon: typeof ClipboardList; title: string; description: string; link: { to: "/sales/enquiries" | "/customer-service" | "/tasks"; label: string }; children: React.ReactNode }) {
  return <Card><CardHeader><div className="flex items-center gap-2"><Icon className="size-4 text-primary" /><CardTitle>{title}</CardTitle></div><CardDescription>{description}</CardDescription></CardHeader><CardContent className="space-y-4">{children}<Button asChild variant="ghost" className="w-full justify-between"><Link to={link.to}>{link.label}<ArrowRight className="size-4" /></Link></Button></CardContent></Card>;
}

function EmptyState({ icon: Icon, text }: { icon: typeof AlertCircle; text: string }) {
  return <div className="flex min-h-24 items-center gap-3 text-sm text-muted-foreground"><Icon className="size-4 shrink-0" />{text}</div>;
}