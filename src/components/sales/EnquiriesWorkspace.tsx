import { useMemo, useState } from "react";
import { Plus, Search, LayoutDashboard, Share2, ArrowUpRight } from "lucide-react";
import type {
  CustomerRequirement,
  FeasibilityReview,
  SalesEnquiry,
  SalesOpportunity,
} from "@/lib/sales";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";

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
  onOpenAnalysis?: (opportunity: SalesOpportunity) => void;
  onShareOpportunity?: (opportunity: SalesOpportunity) => void;
  onOpenEnquiry: (enquiry: SalesEnquiry) => void;
  onOpenOpportunity: (opportunity: SalesOpportunity) => void;
};

function label(value: string) {
  return value.replaceAll("_", " ");
}
function isMarkedSample(name: string | null | undefined) {
  return (
    (name ?? "").toUpperCase().includes("SAMPLE ONLY") ||
    (name ?? "").toUpperCase().includes("SYNTHETIC ONLY")
  );
}
type FeasibilitySummary = { label: string; counts: string; nextAction: string };
const completedReviewStatuses = new Set(["feasible", "feasible_with_conditions", "not_feasible"]);

function feasibilitySummary(
  opportunityId: string,
  requirements: CustomerRequirement[],
  reviews: FeasibilityReview[],
): FeasibilitySummary {
  const linkedRequirementIds = requirements
    .filter((requirement) => requirement.opportunity_id === opportunityId)
    .map((requirement) => requirement.id);
  const linkedReviews = reviews.filter((review) =>
    linkedRequirementIds.includes(review.requirement_id),
  );
  if (!linkedReviews.length)
    return {
      label: "Not sent for feasibility",
      counts: "No assigned team",
      nextAction: "Review routing is unavailable",
    };
  const completed = linkedReviews.filter((review) =>
    completedReviewStatuses.has(review.status),
  ).length;
  const pending = linkedReviews.length - completed;
  const departments = new Set(
    linkedReviews
      .map((review) => review.department_id)
      .filter((value): value is string => Boolean(value)),
  ).size;
  return {
    label: `${departments} assigned ${departments === 1 ? "department" : "departments"}`,
    counts: `${pending} pending · ${completed} completed`,
    nextAction: pending ? "Await assigned review" : "Review recorded",
  };
}

export function EnquiriesWorkspace({
  enquiries,
  opportunities,
  requirements,
  reviews,
  onNew,
  onOpenEnquiry,
  onOpenOpportunity,
  onOpenAnalysis,
  onShareOpportunity,
}: Props) {
  const [search, setSearch] = useState("");
  const [status, setStatus] = useState("all");
  const statuses = useMemo(
    () =>
      [
        ...new Set([
          ...enquiries.map((enquiry) => enquiry.status),
          ...opportunities.map((opportunity) => opportunity.status),
        ]),
      ].sort(),
    [enquiries, opportunities],
  );
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
      feasibility: {
        label: "Not sent for feasibility",
        counts: "No assigned team",
        nextAction: "Review routing is unavailable",
      },
      isSample:
        Boolean(enquiry.customer?.is_sample) ||
        isMarkedSample(enquiry.customer?.legal_name) ||
        isMarkedSample(enquiry.requirement_summary),
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
      isSample:
        Boolean(opportunity.customer?.is_sample) ||
        isMarkedSample(opportunity.customer?.legal_name) ||
        isMarkedSample(opportunity.name),
      sourceEnquiryId: opportunity.enquiry_id,
      record: opportunity,
    }));
    return [
      ...opportunityItems.sort(
        (left, right) => Number(right.status === "active") - Number(left.status === "active"),
      ),
      ...enquiryItems,
    ];
  }, [enquiries, opportunities, requirements, reviews]);
  const visible = useMemo(
    () =>
      items.filter((item) => {
        const needle = search.trim().toLowerCase();
        return (
          (status === "all" || item.status === status) &&
          (!needle ||
            [item.code, item.subject, item.customer, item.stage, item.nextAction].some((value) =>
              value.toLowerCase().includes(needle),
            ))
        );
      }),
    [items, search, status],
  );
  return (
    <div className="min-w-0 space-y-5">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="min-w-0">
          <p className="text-sm font-medium text-primary">Sales work</p>
          <h1 className="mt-1 text-2xl font-semibold">Enquiries &amp; Opportunities</h1>
          <p className="mt-2 text-sm text-muted-foreground">
            Active opportunities first. Open details, shared analysis or team handover from each
            row.
          </p>
        </div>
        <Button onClick={onNew}>
          <Plus className="size-4" />
          New enquiry
        </Button>
      </div>
      <Card className="min-w-0 overflow-hidden">
        <CardHeader className="pb-3">
          <CardTitle>Sales pipeline</CardTitle>
          <CardDescription>
            Team handover can be prepared here. Sending is pending backend activation.
          </CardDescription>
        </CardHeader>
        <CardContent className="min-w-0 space-y-4">
          <div className="grid gap-3 sm:grid-cols-[minmax(0,1fr)_12rem]">
            <div className="relative min-w-0">
              <Search className="absolute left-2.5 top-2.5 size-4 text-muted-foreground" />
              <Input
                aria-label="Search sales pipeline"
                value={search}
                onChange={(event) => setSearch(event.target.value)}
                className="pl-9"
                placeholder="Search customer, code, subject or next action"
              />
            </div>
            <Select value={status} onValueChange={setStatus}>
              <SelectTrigger className="w-full">
                <SelectValue placeholder="All statuses" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All statuses</SelectItem>
                {statuses.map((item) => (
                  <SelectItem key={item} value={item}>
                    {label(item)}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
          <div className="max-w-full overflow-x-auto rounded-md border">
            <table
              className="w-full min-w-[760px] table-fixed text-left text-sm"
              aria-label="Enquiries and opportunities"
            >
              <thead className="bg-muted/40 text-xs text-muted-foreground">
                <tr>
                  <th className="w-[32%] px-3 py-3">Opportunity / customer</th>
                  <th className="w-[16%] px-3 py-3">Status / stage</th>
                  <th className="w-[21%] px-3 py-3">Feasibility / team</th>
                  <th className="w-[18%] px-3 py-3">Next action</th>
                  <th className="w-[13%] px-3 py-3 text-right">Open / actions</th>
                </tr>
              </thead>
              <tbody className="divide-y">
                {visible.map((item) => (
                  <tr key={`${item.kind}-${item.id}`} className="align-top hover:bg-muted/20">
                    <td className="px-3 py-3">
                      <button
                        type="button"
                        className="max-w-full text-left font-medium text-primary hover:underline focus-visible:outline focus-visible:outline-2"
                        onClick={() =>
                          item.kind === "opportunity"
                            ? onOpenOpportunity(item.record as SalesOpportunity)
                            : onOpenEnquiry(item.record as SalesEnquiry)
                        }
                      >
                        <span className="block break-words [overflow-wrap:anywhere]">
                          {item.subject}
                        </span>
                        <span className="mt-1 block text-xs font-normal text-muted-foreground">
                          {item.code}
                        </span>
                      </button>
                      <p className="mt-1 break-words text-xs text-muted-foreground [overflow-wrap:anywhere]">
                        {item.customer}
                      </p>
                      <div className="mt-2 flex flex-wrap gap-1">
                        <Badge variant="outline" className="text-[10px]">
                          {item.kind === "opportunity" ? "Opportunity" : "Enquiry"}
                        </Badge>
                        {item.isSample && (
                          <Badge variant="secondary" className="text-[10px]">
                            Sample
                          </Badge>
                        )}
                      </div>
                    </td>
                    <td className="px-3 py-3">
                      <Badge
                        variant={item.status === "active" ? "secondary" : "outline"}
                        className="max-w-full whitespace-normal"
                      >
                        {label(item.status)}
                      </Badge>
                      {item.kind === "opportunity" && (
                        <p className="mt-1 break-words text-xs text-muted-foreground">
                          {label(item.stage)}
                        </p>
                      )}
                    </td>
                    <td className="px-3 py-3">
                      <p className="break-words text-xs font-medium">{item.feasibility.label}</p>
                      <p className="mt-1 break-words text-xs text-muted-foreground">
                        {item.feasibility.counts}
                      </p>
                    </td>
                    <td className="px-3 py-3">
                      <p className="break-words text-xs [overflow-wrap:anywhere]">
                        {item.nextAction === "No next action"
                          ? item.kind === "opportunity"
                            ? item.feasibility.nextAction === "Review routing is unavailable"
                              ? "Prepare team handover"
                              : item.feasibility.nextAction
                            : "Internal Sales review"
                          : item.nextAction}
                      </p>
                    </td>
                    <td className="px-2 py-3">
                      <div className="flex flex-wrap justify-end gap-1">
                        <Button
                          size="icon"
                          variant="ghost"
                          className="size-8"
                          aria-label={`Open details for ${item.code}`}
                          title="Open details"
                          onClick={() =>
                            item.kind === "opportunity"
                              ? onOpenOpportunity(item.record as SalesOpportunity)
                              : onOpenEnquiry(item.record as SalesEnquiry)
                          }
                        >
                          <ArrowUpRight className="size-4" />
                        </Button>
                        {item.kind === "opportunity" && (
                          <>
                            <Button
                              size="icon"
                              variant="ghost"
                              className="size-8"
                              aria-label={`Open shared analysis for ${item.code}`}
                              title="Shared analysis"
                              onClick={() =>
                                (onOpenAnalysis ?? onOpenOpportunity)(
                                  item.record as SalesOpportunity,
                                )
                              }
                            >
                              <LayoutDashboard className="size-4" />
                            </Button>
                            <Button
                              size="icon"
                              variant="ghost"
                              className="size-8"
                              aria-label={`Prepare team handover for ${item.code}`}
                              title="Prepare team handover (sending not active yet)"
                              onClick={() =>
                                (onShareOpportunity ?? onOpenOpportunity)(
                                  item.record as SalesOpportunity,
                                )
                              }
                            >
                              <Share2 className="size-4" />
                            </Button>
                          </>
                        )}
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
            {!visible.length && (
              <p className="p-8 text-center text-sm text-muted-foreground">
                No authorised enquiries or opportunities match these filters.
              </p>
            )}
          </div>
          <p className="text-xs text-muted-foreground">
            On small screens, scroll the table sideways to see row actions. Sharing a document does
            not submit feasibility or approve a project.
          </p>
        </CardContent>
      </Card>
    </div>
  );
}
