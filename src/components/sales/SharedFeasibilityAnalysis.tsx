import { useMemo, useState, type ReactNode } from "react";
import {
  ArrowRight,
  Check,
  ChevronDown,
  ClipboardList,
  Eye,
  FlaskConical,
  LockKeyhole,
  MessageSquare,
  Pencil,
  RotateCcw,
  Users,
} from "lucide-react";
import type { FeasibilityReview, MasterSpecificationSummary } from "@/lib/sales";
import { draftFromSpecificationData } from "@/lib/master-specification";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { OwnFeasibilityNoteEditor } from "./OwnFeasibilityNoteEditor";
import { OwnFeasibilityHighlightDraftEditor } from "./OwnFeasibilityHighlightDraftEditor";
import type { InternalNoteScope } from "@/lib/requirement-internal-notes";

type Department = { id: string; name: string; code: string | null };
type Employee = { user_id: string; display_name: string | null; official_email: string | null };
type Props = {
  specification: MasterSpecificationSummary | null;
  specificationData: unknown;
  sourceLoading: boolean;
  sourceError: boolean;
  reviews: FeasibilityReview[];
  departments: Department[];
  employees: Employee[];
  onOpenSource: () => void;
  internalDetails?: ReactNode;
};
type Column = {
  id: string;
  name: string;
  owner: string;
  status: string;
  findings: string;
  conditions: string;
  risks?: string;
  noteScope?: InternalNoteScope;
  internal: string;
  highlight: string | null;
  tone: "blue" | "amber" | "green" | "violet";
};
const exampleRequirements = {
  Application: "Vehicle gateway · connector variant",
  Power: "12 V / 24 V input",
  Interfaces: "CAN + 8-pin connector",
  Volume: "500 units · planning estimate",
};
const exampleColumns: Column[] = [
  {
    id: "hardware",
    name: "Hardware",
    owner: "Example hardware reviewer",
    status: "Conditional",
    findings:
      "Evaluate the existing board and connector footprint before committing to a PCB revision.",
    conditions: "Confirm the client pinout. A changed footprint requires a design revision.",
    internal: "Compare board reuse and a layout revision before estimating engineering effort.",
    highlight:
      "Please confirm the connector drawing and pin assignment. We will then confirm whether the existing board can be reused.",
    tone: "blue",
  },
  {
    id: "firmware",
    name: "Firmware / software",
    owner: "Example firmware reviewer",
    status: "Needs clarification",
    findings:
      "Check MCU peripherals, CAN interface and driver support against the selected hardware configuration.",
    conditions: "Await Hardware's proposed key-part and interface snapshot.",
    internal:
      "Coordinate the interface review with the hardware owner before committing the firmware estimate.",
    highlight:
      "Please share the required CAN messages and operating modes so we can confirm firmware compatibility.",
    tone: "violet",
  },
  {
    id: "procurement",
    name: "Procurement",
    owner: "Example procurement reviewer",
    status: "In review",
    findings:
      "Review connector availability, alternatives and lead time against the proposed BOM revision.",
    conditions: "Cost and availability are not confirmed until the exact connector is selected.",
    internal: "Supplier negotiations and internal costing stay in the internal workspace.",
    highlight:
      "Delivery timing will be confirmed after the connector specification and sourcing review are complete.",
    tone: "amber",
  },
  {
    id: "production",
    name: "Production / Quality",
    owner: "Example production reviewer",
    status: "In review",
    findings:
      "Assess assembly clearance, harness fit and the inspection method for the connector variant.",
    conditions: "Review a physical sample or drawing before confirming build readiness.",
    internal: "Check fixture access and the inspection work instruction with the assigned team.",
    highlight:
      "A connector drawing or sample will help us verify assembly fit and agree the required checks.",
    tone: "green",
  },
];
const accents = {
  blue: "border-t-sky-500",
  violet: "border-t-violet-500",
  amber: "border-t-amber-500",
  green: "border-t-emerald-500",
};
const readable = (value: string) => value.replaceAll("_", " ");
const recorded = (value: string | null | undefined) => value?.trim() || "Not recorded";

/** Caller-authorized reads only. All sample edits are deliberately held in component memory. */
export function SharedFeasibilityAnalysis({
  specification,
  specificationData,
  sourceLoading,
  sourceError,
  reviews,
  departments,
  employees,
  onOpenSource,
  internalDetails,
}: Props) {
  const [example, setExample] = useState(false);
  const [audience, setAudience] = useState<"internal" | "client">("internal");
  const [phase, setPhase] = useState("Initial feasibility");
  const [requirements, setRequirements] = useState(exampleRequirements);
  const [draft, setDraft] = useState(exampleRequirements);
  const [editingRequirements, setEditingRequirements] = useState(false);
  const [highlights, setHighlights] = useState<Record<string, string>>({});
  const [editingHighlight, setEditingHighlight] = useState<string | null>(null);
  const [highlightDraft, setHighlightDraft] = useState("");
  const [internalRemarks, setInternalRemarks] = useState<Record<string, string>>({});
  const [editingInternal, setEditingInternal] = useState<string | null>(null);
  const [internalDraft, setInternalDraft] = useState("");
  const [notice, setNotice] = useState("");
  const [question, setQuestion] = useState("");
  const [discussion, setDiscussion] = useState<Array<{ body: string; clientVisible: boolean }>>([]);
  const [shareMessage, setShareMessage] = useState(false);
  const client = audience === "client";
  const source = draftFromSpecificationData(specificationData);
  const changed =
    example &&
    Object.keys(exampleRequirements).some(
      (key) =>
        requirements[key as keyof typeof requirements] !==
        exampleRequirements[key as keyof typeof exampleRequirements],
    );
  const columns = useMemo<Column[]>(
    () =>
      example
        ? exampleColumns
        : reviews.map((review, index) => ({
            id: review.id,
            name:
              review.department?.name ??
              departments.find((department) => department.id === review.department_id)?.name ??
              "Department not recorded",
            owner:
              employees.find((employee) => employee.user_id === review.reviewer_user_id)
                ?.display_name ?? "Reviewer not recorded",
            status: readable(review.status),
            findings: recorded(review.findings),
            conditions: recorded(review.assumptions),
            risks: recorded(review.risks),
            internal: "Independent internal remarks are not available yet.",
            noteScope: review.source_revision_id && review.master_specification_version_id ? { reviewId: review.id, sourceRevisionId: review.source_revision_id, masterVersionId: review.master_specification_version_id } : undefined,
            // Existing findings are NOT an accepted client-publication contract.
            highlight: null,
            tone: (["blue", "violet", "amber", "green"] as const)[index % 4],
          })),
    [example, reviews, departments, employees],
  );
  const fields: Record<string, string> = example
    ? exampleRequirements
    : source
      ? {
          Application: source.industryApplication,
          Power: source.powerAndUnits,
          Interfaces: source.interfaces,
          Volume: source.volumes,
        }
      : {
          Application: "Not recorded",
          Power: "Not recorded",
          Interfaces: "Not recorded",
          Volume: "Not recorded",
        };

  function toggleExample() {
    setExample(!example);
    setAudience("internal");
    setRequirements(exampleRequirements);
    setDraft(exampleRequirements);
    setHighlights({});
    setInternalRemarks({});
    setEditingInternal(null);
    setEditingHighlight(null);
    setEditingRequirements(false);
    setNotice("");
    setDiscussion([]);
    setQuestion("");
    setShareMessage(false);
    setPhase("Initial feasibility");
  }

  return (
    <div className="min-w-0 space-y-5" aria-label="Shared feasibility analysis">
      <header className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0">
          <p className="text-[10px] font-semibold uppercase tracking-[0.18em] text-primary">
            One workspace · shared analysis
          </p>
          <h3 className="mt-1 text-xl font-semibold tracking-tight">
            Requirements to a shared decision
          </h3>
          <p className="mt-1 max-w-2xl text-sm text-muted-foreground">
            Compare department inputs, surface conditions and keep the client conversation
            connected.
          </p>
        </div>
        <Button
          type="button"
          size="sm"
          variant={example ? "secondary" : "outline"}
          onClick={toggleExample}
        >
          {example ? (
            <RotateCcw className="mr-2 size-3.5" />
          ) : (
            <FlaskConical className="mr-2 size-3.5" />
          )}
          {example ? "Exit example" : "Try example layout"}
        </Button>
      </header>

      {example && (
        <div className="rounded-lg border border-amber-500/30 bg-amber-500/5 px-4 py-3 text-sm">
          <strong className="font-semibold">UI example · not saved to the portal.</strong>
          <span className="ml-1 text-muted-foreground">
            Fictional content for reviewing this layout. Edits and discussion stay in this view and
            reset when you exit. No notifications or client links are sent.
          </span>
        </div>
      )}

      <div className="flex flex-wrap items-center justify-between gap-3">
        <div
          className="inline-flex max-w-full rounded-lg border bg-muted/30 p-1"
          aria-label="Analysis audience"
        >
          <Button
            type="button"
            size="sm"
            variant={!client ? "secondary" : "ghost"}
            aria-pressed={!client}
            onClick={() => {
              setAudience("internal");
              setQuestion("");
              setShareMessage(false);
              setEditingHighlight(null);
            }}
          >
            <Users className="mr-2 size-3.5" />
            Internal view
          </Button>
          <Button
            type="button"
            size="sm"
            variant={client ? "secondary" : "ghost"}
            aria-pressed={client}
            onClick={() => {
              setAudience("client");
              setQuestion("");
              setShareMessage(false);
              setEditingHighlight(null);
              setEditingRequirements(false);
            }}
          >
            <Eye className="mr-2 size-3.5" />
            Client preview
          </Button>
        </div>
        {example ? (
          <label className="flex items-center gap-2 text-xs text-muted-foreground">
            Example phase
            <select
              aria-label="Example phase"
              className="h-8 max-w-[12rem] rounded-md border bg-background px-2 text-xs text-foreground"
              value={phase}
              onChange={(event) => setPhase(event.target.value)}
            >
              {["Initial feasibility", "Research / POC (optional)", "Pilot review"].map((item) => (
                <option key={item}>{item}</option>
              ))}
            </select>
          </label>
        ) : (
          <Badge variant="outline">Recorded reviews · read only</Badge>
        )}
      </div>

      {example && (
        <p className="flex items-start gap-2 text-xs leading-relaxed text-muted-foreground">
          <FlaskConical className="mt-0.5 size-3.5 shrink-0" />
          {phase === "Initial feasibility"
            ? "Compare the client requirement with each discipline’s assumptions before deciding how to proceed."
            : phase === "Research / POC (optional)"
              ? "Optional research: agree the objective and uncertainties with the client. Findings may change before the next review."
              : "Review the same candidate BOM revision in parallel. Firmware compatibility and Procurement analysis precede the approved BOM lock."}
        </p>
      )}
      {client && (
        <p className="rounded-lg border border-sky-500/20 bg-sky-500/5 px-3 py-2 text-xs text-muted-foreground">
          Client preview only, not a shared client portal.{" "}
          {example
            ? "Only the example requirements and client-visible highlights appear here."
            : "No client summary has been published for this opportunity. Internal analysis stays private."}
        </p>
      )}

      {(!client || example) && (
        <section
          className="overflow-hidden rounded-xl border bg-card"
          aria-label="Requirements summary"
        >
          <div className="flex flex-wrap items-center justify-between gap-3 border-b bg-muted/20 px-4 py-3">
            <div className="flex min-w-0 items-center gap-2.5">
              <div className="rounded-md border bg-background p-2">
                <LockKeyhole className="size-4 text-primary" />
              </div>
              <div className="min-w-0">
                <h4 className="text-sm font-semibold">
                  {example ? "Example reviewed requirements" : "Recorded requirements"}
                </h4>
                <p className="mt-0.5 break-words text-xs text-muted-foreground">
                  {example
                    ? "Illustrative snapshot · not an approved customer baseline"
                    : specification
                      ? `${specification.specification_number} · revision ${specification.current_version} · approval not verified`
                      : "No Master Specification linked"}
                </p>
              </div>
            </div>
            <div className="flex items-center gap-2">
              <Badge variant="outline">
                <LockKeyhole className="mr-1 size-3" />
                Read only
              </Badge>
              {example ? (
                <Button
                  type="button"
                  variant="ghost"
                  size="sm"
                  onClick={() => {
                    setDraft(requirements);
                    setEditingRequirements(true);
                    setNotice("");
                  }}
                >
                  <Pencil className="mr-1.5 size-3" />
                  Edit example
                </Button>
              ) : (
                <Button type="button" variant="ghost" size="sm" onClick={onOpenSource}>
                  Open Master
                  <ArrowRight className="ml-1.5 size-3" />
                </Button>
              )}
            </div>
          </div>
          {sourceLoading && !example ? (
            <p className="p-4 text-sm text-muted-foreground">
              Loading the recorded Master revision…
            </p>
          ) : sourceError && !example ? (
            <p role="alert" className="p-4 text-sm text-destructive">
              The Master revision could not be loaded. No requirements are inferred.
            </p>
          ) : (
            <dl className="grid divide-y sm:grid-cols-2 sm:divide-y-0 lg:grid-cols-4">
              {Object.entries(fields).map(([name, value]) => (
                <div key={name} className="min-w-0 px-4 py-3">
                  <dt className="text-[10px] font-semibold uppercase tracking-wider text-muted-foreground">
                    {name}
                  </dt>
                  <dd className="mt-1.5 whitespace-pre-wrap break-words text-sm [overflow-wrap:anywhere]">
                    {value}
                  </dd>
                </div>
              ))}
            </dl>
          )}
          {editingRequirements && example && (
            <form
              aria-label="Edit example requirements"
              className="space-y-3 border-t bg-muted/10 p-4"
              onSubmit={(event) => {
                event.preventDefault();
                setRequirements({ ...draft });
                setEditingRequirements(false);
                setNotice(
                  "Example changes kept in this preview only. No baseline changed and no notifications sent.",
                );
              }}
            >
              <p className="text-xs font-medium">
                Edit latest example input · reviewed snapshot stays above
              </p>
              <div className="grid gap-3 sm:grid-cols-2">
                {Object.entries(draft).map(([name, value]) => (
                  <div key={name}>
                    <Label htmlFor={`example-${name}`}>{name}</Label>
                    <Input
                      id={`example-${name}`}
                      value={value}
                      maxLength={500}
                      required
                      onChange={(event) => setDraft({ ...draft, [name]: event.target.value })}
                    />
                  </div>
                ))}
              </div>
              <div className="flex gap-2">
                <Button type="submit" size="sm">
                  Save preview
                </Button>
                <Button
                  type="button"
                  size="sm"
                  variant="outline"
                  onClick={() => setEditingRequirements(false)}
                >
                  Cancel
                </Button>
              </div>
            </form>
          )}
          {changed && (
            <div className="border-t border-amber-500/20 bg-amber-500/5 p-4">
              <p className="text-xs font-semibold">Latest example input · needs review</p>
              <div className="mt-2 space-y-1 text-xs">
                {Object.entries(requirements)
                  .filter(
                    ([name, value]) =>
                      value !== exampleRequirements[name as keyof typeof exampleRequirements],
                  )
                  .map(([name, value]) => (
                    <p key={name} className="break-words">
                      <span className="font-medium">{name}:</span>{" "}
                      {exampleRequirements[name as keyof typeof exampleRequirements]}{" "}
                      <span aria-label="changed to">→</span> {value}
                    </p>
                  ))}
              </div>
            </div>
          )}
          {!example && source && (
            <details className="border-t px-4 py-3">
              <summary className="flex cursor-pointer list-none items-center gap-2 text-xs font-medium">
                <ChevronDown className="size-3.5" />
                More requirement details
              </summary>
              <dl className="mt-3 grid gap-3 text-xs sm:grid-cols-2">
                {Object.entries({
                  Scope: source.developmentScope,
                  Summary: source.requirementSummary,
                  Environment: source.environmentAndIp,
                  Schedule: source.schedule,
                  Standards: source.requestedStandards,
                  Exclusions: source.exclusions,
                }).map(([name, value]) => (
                  <div key={name}>
                    <dt className="text-muted-foreground">{name}</dt>
                    <dd className="mt-1 whitespace-pre-wrap break-words">{value}</dd>
                  </div>
                ))}
              </dl>
            </details>
          )}
        </section>
      )}

      {!client && (
        <section aria-label="Project start readiness" className="rounded-xl border bg-muted/20 p-4">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <h4 className="text-sm font-semibold">Before project start</h4>
            <Badge variant="outline">{example ? "Example only" : "Not verified for start"}</Badge>
          </div>
          <dl className="mt-3 grid gap-3 text-xs sm:grid-cols-2 xl:grid-cols-5">
            {[
              [
                "Master revision",
                example
                  ? "Illustrative snapshot"
                  : sourceError || sourceLoading
                    ? "Source not verified"
                    : specification
                      ? `${specification.specification_number} / revision ${specification.current_version}`
                      : "Not linked",
              ],
              [
                "Assigned reviews",
                example
                  ? "4 example disciplines"
                  : `${reviews.filter((review) => review.department_id && review.reviewer_user_id).length} recorded assignments`,
              ],
              [
                "Conditions",
                example
                  ? "Example conditions need review"
                  : reviews.some((review) => review.assumptions?.trim() || review.risks?.trim())
                    ? "Review notes recorded; resolution not verified"
                    : "Resolution not verified",
              ],
              ["Client approval", "Not verified"],
              ["Baseline lock", "Not verified"],
            ].map(([name, value]) => (
              <div key={name} className="min-w-0">
                <dt className="font-medium text-muted-foreground">{name}</dt>
                <dd className="mt-1 whitespace-pre-wrap break-words">{value}</dd>
              </div>
            ))}
          </dl>
          <p className="mt-3 text-xs text-muted-foreground">
            Required reviews, resolved conditions and client approval must match the final
            requirements revision. An authorized start needs a locked approved baseline; this
            summary does not approve or start a project.
          </p>
        </section>
      )}
      <section aria-label="Department comparison" className="min-w-0 space-y-3">
        <div className="flex flex-wrap items-center justify-between gap-2">
          <div>
            <h4 className="text-sm font-semibold">
              {client ? "Department highlights" : "Department analysis"}
            </h4>
            <p className="mt-1 text-xs text-muted-foreground">
              {client
                ? "Key points intended for the client conversation."
                : example
                  ? "Illustrative parallel review · conditions need human resolution."
                  : "Team responses recorded for this opportunity."}
            </p>
          </div>
          <Badge variant="secondary">
            {example ? "4 example disciplines" : `${reviews.length} recorded reviews`}
          </Badge>
        </div>
        {!columns.length ? (
          <div className="rounded-xl border border-dashed p-7 text-center">
            <ClipboardList className="mx-auto size-6 text-muted-foreground" />
            <p className="mt-3 text-sm font-medium">No assigned review records</p>
            <p className="mx-auto mt-1 max-w-lg text-xs text-muted-foreground">
              No department decisions or remarks are inferred. Use the example layout to review the
              proposed shared workspace.
            </p>
          </div>
        ) : client && !example ? (
          <div className="rounded-xl border border-dashed p-7 text-center text-sm text-muted-foreground">
            No client-visible highlights have been verified for this opportunity.
          </div>
        ) : (
          <div className="grid min-w-0 items-stretch gap-3 md:grid-cols-2 2xl:grid-cols-4">
            {columns.map((column) => (
              <article
                key={column.id}
                aria-label={`${column.name} analysis`}
                className={`flex min-w-0 flex-col overflow-hidden rounded-xl border border-t-[3px] bg-card ${accents[column.tone]}`}
              >
                <header className="border-b px-4 py-3">
                  <div className="flex flex-wrap items-center justify-between gap-2">
                    <h5 className="break-words text-sm font-semibold">{column.name}</h5>
                    <Badge variant="outline" className="max-w-full whitespace-normal text-[10px]">
                      {column.status}
                    </Badge>
                  </div>
                  {!client && (
                    <p className="mt-2 break-words text-[11px] text-muted-foreground">
                      {column.owner}
                    </p>
                  )}
                </header>
                {!client && (
                  <div className="flex-1 space-y-4 p-4 text-xs">
                    <div>
                      <p className="font-medium text-muted-foreground">Analysis</p>
                      <p className="mt-1.5 whitespace-pre-wrap break-words leading-relaxed">
                        {column.findings}
                      </p>
                    </div>
                    <div>
                      <p className="font-medium text-muted-foreground">{example ? "Conditions / dependencies" : "Recorded assumptions"}</p>
                      <p className="mt-1.5 whitespace-pre-wrap break-words leading-relaxed">
                        {column.conditions}
                      </p>
                    </div>
                    {!example && (
                      <div>
                        <p className="font-medium text-muted-foreground">Recorded risks</p>
                        <p className="mt-1.5 whitespace-pre-wrap break-words leading-relaxed">{column.risks}</p>
                      </div>
                    )}
                  </div>
                )}
                <footer className="mt-auto border-t bg-primary/[0.04] p-4">
                  {!client && (
                    <section className="mb-4 border-b pb-4" aria-label="Internal remarks">
                      <h6 className="text-xs font-semibold">Internal remarks</h6>
                      <p className="mt-1 text-[10px] text-muted-foreground">
                        Team only � never included in client highlights
                      </p>
                      {example && editingInternal === column.id ? (
                        <form
                          className="mt-3 space-y-2"
                          onSubmit={(event) => {
                            event.preventDefault();
                            setInternalRemarks({
                              ...internalRemarks,
                              [column.id]: internalDraft.trim(),
                            });
                            setEditingInternal(null);
                            setNotice(
                              "Internal remark updated in the UI example only. Nothing was published or sent.",
                            );
                          }}
                        >
                          <Label htmlFor={`internal-${column.id}`}>Example internal remark</Label>
                          <Textarea
                            id={`internal-${column.id}`}
                            value={internalDraft}
                            maxLength={1200}
                            rows={4}
                            onChange={(event) => setInternalDraft(event.target.value)}
                          />
                          <div className="flex flex-wrap gap-2">
                            <Button size="sm" type="submit">
                              Save preview
                            </Button>
                            <Button
                              size="sm"
                              type="button"
                              variant="ghost"
                              onClick={() => setEditingInternal(null)}
                            >
                              Cancel
                            </Button>
                          </div>
                        </form>
                      ) : (
                        <>
                          {!example && column.noteScope ? <OwnFeasibilityNoteEditor scope={column.noteScope} /> : (
                            <p className="mt-2.5 whitespace-pre-wrap break-words text-xs leading-relaxed">
                              {internalRemarks[column.id] ?? column.internal}
                            </p>
                          )}
                          {example && (
                            <Button
                              type="button"
                              size="sm"
                              variant="ghost"
                              className="mt-2 h-7 px-0 text-xs"
                              onClick={() => {
                                setInternalDraft(internalRemarks[column.id] ?? column.internal);
                                setEditingInternal(column.id);
                              }}
                            >
                              Edit internal remark
                            </Button>
                          )}
                        </>
                      )}
                    </section>
                  )}

                  <div className="flex items-center gap-1.5">
                    <MessageSquare className="size-3.5 text-primary" />
                    <h6 className="text-xs font-semibold">Client-visible highlight</h6>
                  </div>
                  <p className="mt-1 text-[10px] font-medium uppercase tracking-wider text-muted-foreground">
                    {example
                      ? "Client-visible highlight · example"
                      : "Client publication not connected"}
                  </p>
                  {editingHighlight === column.id && example && !client ? (
                    <form
                      className="mt-3 space-y-2"
                      onSubmit={(event) => {
                        event.preventDefault();
                        setHighlights({ ...highlights, [column.id]: highlightDraft.trim() });
                        setEditingHighlight(null);
                        setNotice(
                          "Highlight updated in the UI example only. Nothing was published or sent.",
                        );
                      }}
                    >
                      <Label htmlFor={`highlight-${column.id}`} className="text-xs">
                        Example highlight
                      </Label>
                      <Textarea
                        id={`highlight-${column.id}`}
                        value={highlightDraft}
                        maxLength={1200}
                        rows={5}
                        required
                        onChange={(event) => setHighlightDraft(event.target.value)}
                      />
                      <div className="flex flex-wrap gap-2">
                        <Button size="sm" type="submit" disabled={!highlightDraft.trim()}>
                          Save preview
                        </Button>
                        <Button
                          size="sm"
                          type="button"
                          variant="ghost"
                          onClick={() => setEditingHighlight(null)}
                        >
                          Cancel
                        </Button>
                      </div>
                    </form>
                  ) : (
                    <>
                      <p className="mt-2.5 whitespace-pre-wrap break-words text-xs leading-relaxed">
                        {highlights[column.id] ??
                          column.highlight ??
                          "No published department remarks recorded."}
                      </p>
                      {!example && !client && column.noteScope && <OwnFeasibilityHighlightDraftEditor scope={column.noteScope} />}
                      {example && !client && (
                        <Button
                          type="button"
                          size="sm"
                          variant="ghost"
                          className="mt-2 h-7 px-0 text-xs"
                          onClick={() => {
                            setHighlightDraft(highlights[column.id] ?? column.highlight ?? "");
                            setEditingHighlight(column.id);
                            setNotice("");
                          }}
                        >
                          <Pencil className="mr-1.5 size-3" />
                          Edit highlight
                        </Button>
                      )}
                    </>
                  )}
                </footer>
              </article>
            ))}
          </div>
        )}
      </section>

      {example && (
        <section className="rounded-xl border bg-card p-4" aria-label="Preview discussion">
          <div className="flex items-center gap-2">
            <MessageSquare className="size-4 text-primary" />
            <h4 className="text-sm font-semibold">
              {client ? "Questions for the team" : "Shared discussion"}
            </h4>
            <Badge variant="outline" className="text-[10px]">
              UI example
            </Badge>
          </div>
          <p className="mt-1 text-xs text-muted-foreground">
            A place to clarify the requirements. Example messages stay in this view only.
          </p>
          {discussion
            .filter((message) => !client || message.clientVisible)
            .map((message, index) => (
              <p
                key={index}
                className="mt-3 rounded-md bg-muted/30 p-3 text-xs [overflow-wrap:anywhere]"
              >
                {message.body}
              </p>
            ))}
          <form
            className="mt-3 flex flex-wrap items-end gap-2"
            onSubmit={(event) => {
              event.preventDefault();
              if (!question.trim()) return;
              setDiscussion([
                ...discussion,
                { body: question.trim(), clientVisible: client || shareMessage },
              ]);
              setQuestion("");
              setShareMessage(false);
              setNotice("Message added to this UI preview only. No team or client was notified.");
            }}
          >
            <div className="min-w-[12rem] flex-1">
              <Label htmlFor="analysis-question" className="sr-only">
                Preview message
              </Label>
              <Input
                id="analysis-question"
                value={question}
                maxLength={1000}
                placeholder={
                  client
                    ? "Ask a question about the example requirements…"
                    : "Add a clarification for this UI review…"
                }
                onChange={(event) => setQuestion(event.target.value)}
              />
            </div>
            {!client && (
              <label className="flex items-center gap-1.5 text-xs text-muted-foreground">
                <input
                  type="checkbox"
                  checked={shareMessage}
                  onChange={(event) => setShareMessage(event.target.checked)}
                />
                Client-visible message
              </label>
            )}
            <Button type="submit" size="sm" disabled={!question.trim()}>
              Add to preview
            </Button>
          </form>
        </section>
      )}
      {notice && (
        <p
          role="status"
          className="flex items-start gap-2 rounded-lg border bg-muted/30 p-3 text-xs text-muted-foreground"
        >
          <Check className="mt-0.5 size-3.5 shrink-0" />
          {notice}
        </p>
      )}
      {!client && internalDetails}
      {!example && (
        <p className="text-xs leading-relaxed text-muted-foreground">
          This first version lets you review the layout. Live remarks editing, client sharing and
          notifications are not connected yet.
        </p>
      )}
    </div>
  );
}
