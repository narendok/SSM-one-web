import { useEffect, useMemo, useRef, useState } from "react";
import { AlertCircle, Box, Download, Eye, LockKeyhole, Plus, RefreshCw, Save, Trash2 } from "lucide-react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useServerFn } from "@tanstack/react-start";
import { Link } from "@tanstack/react-router";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { fetchStructuredTemplatePreviewSource } from "@/lib/lifecycle-structured-template-previews.functions";
import {
  fetchProjectBomItems,
  fetchProjectBoms,
  type ProjectBomItemRow,
  type ProjectBomSummary,
} from "@/lib/project-bom.functions";
import {
  createLocalTableRow,
  dfmeaRpn,
  parseLocalTableRows,
  quoteLineEstimate,
  renderStructuredLifecycleTemplatePreview,
  renderSpecializedLocalTraceabilityHtml,
  serializeLocalTableRows,
  structuredLifecycleTemplatePreviews,
  tableRowsForOutput,
  taxInvoiceLineTotals,
  validateSpecializedLocalPreviewPayload,
  validateLocalTableRows,
  type BomCostRow,
  type EditableField,
  type LocalTableKey,
  type QuoteLineRow,
  type StructuredLifecycleTemplateKind,
  type StructuredTemplateSource,
  type TableValidationIssue,
  type TaxInvoiceRow,
} from "@/lib/lifecycle-structured-template-previews";
import { renderStructuredSalesLocalDraftHtml } from "@/lib/structured-sales-local-renderer";
import {
  LocalBomComponentPicker,
  type LocalBomComponentCandidate,
} from "@/components/lifecycle/LocalBomComponentPicker";
import {
  adoptLocalBomComponent,
  recordLocalBomComponentSelection,
  type LocalBomComponentSelection,
} from "@/lib/local-bom-component-adapter";
import {
  structuredSalesDraftHistoryBoundaryMessage,
  structuredSalesDraftHistoryCapability,
  structuredSalesDraftSaveBoundaryMessage,
  structuredSalesDraftSaveCapability,
} from "@/lib/structured-sales-draft-capability";
import { discoverStructuredSalesDraftCapability } from "@/lib/structured-sales-draft.functions";
import { supabase } from "@/integrations/supabase/client";
import {
  canonicalizeStructuredSalesLocalPayload,
  validateStructuredSalesLocalPayload,
} from "@/lib/structured-sales-local-payload";

export type StructuredTemplatePreviewSourcePin = {
  opportunityNumber: string;
  specificationNumber: string;
  versionNumber: number;
};
const sampleSource = {
  opportunityNumber: "OPPORTUNITY-2026-0013",
  specificationNumber: "MASTER-2026-0001",
  versionNumber: 1,
};
const editKey = (kind: StructuredLifecycleTemplateKind, field: string) => `${kind}:${field}`;
const fieldValue = (value: string) => (value === "" ? "TBC" : value);
const hasLocalEdits = (userEdits: Record<string, string>) => Object.keys(userEdits).length > 0;
const structuredDraftStorageLimit = 10 * 1024 * 1024;
export function shouldWarnBeforeClosingStructuredPreview(dirty: boolean) {
  return dirty;
}
export function requestStructuredPreviewExit(
  dirty: boolean,
  exit: () => void,
  askForDiscard: () => void,
) {
  if (shouldWarnBeforeClosingStructuredPreview(dirty)) {
    askForDiscard();
    return;
  }
  exit();
}
type StructuredSalesPreviewKind = "SOR" | "CONTRACT_REVIEW" | "PRS";

type StructuredSalesDraftHistoryItem = {
  requestKey: string;
  revisionId: string;
  revisionNumber: number;
  materializationId: string | null;
  storageBucket: string | null;
  storagePath: string | null;
  checksum: string | null;
  createdAt: string;
  payload: Record<string, string> | null;
};

type DownloadFeedback =
  | { state: "idle" }
  | { state: "loading"; revisionNumber: number }
  | { state: "success"; revisionNumber: number }
  | { state: "error"; message: string };

function revisionFileName(kind: StructuredSalesPreviewKind, revisionNumber: number) {
  return `${kind.toLowerCase().replaceAll("_", "-")}-draft-rev-${revisionNumber}.html`;
}

async function sha256Text(value: string) {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return Array.from(new Uint8Array(digest)).map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

export function persistedStructuredSalesDraftFields(
  kind: StructuredSalesPreviewKind,
  payload: unknown,
): Record<string, string> | null {
  if (!payload || typeof payload !== "object" || Array.isArray(payload)) return null;
  const candidate = payload as { kind?: unknown; fields?: unknown };
  if (candidate.kind !== kind) return null;
  const validated = validateStructuredSalesLocalPayload(kind, candidate.fields);
  return validated.ok ? { ...validated.payload } : null;
}

export async function downloadVerifiedStructuredSalesDraft(
  download: () => PromiseLike<{ data: Blob | null; error: { message?: string } | null }>,
  expectedChecksum: string | null,
  timeoutMs = 15_000,
): Promise<Blob> {
  let timeoutId: ReturnType<typeof setTimeout> | undefined;
  try {
    const result = await Promise.race([
      download(),
      new Promise<never>((_, reject) => {
        timeoutId = setTimeout(() => reject(new Error("The private file download timed out. Try again.")), timeoutMs);
      }),
    ]);
    if (result.error || !result.data) throw new Error(result.error?.message ?? "The verified private file is unavailable.");
    if (!expectedChecksum) throw new Error("The verified private file has no checksum.");
    const actualChecksum = await sha256Text(await result.data.text());
    if (actualChecksum !== expectedChecksum.toLowerCase()) throw new Error("The downloaded private file did not match its verified checksum.");
    return result.data;
  } finally {
    if (timeoutId) clearTimeout(timeoutId);
  }
}

function newRequestKey() {
  return crypto.randomUUID();
}

function isStructuredSalesPreviewKind(
  kind: StructuredLifecycleTemplateKind,
): kind is StructuredSalesPreviewKind {
  return kind === "SOR" || kind === "CONTRACT_REVIEW" || kind === "PRS";
}

export function localEditsForStructuredPreview(
  kind: StructuredLifecycleTemplateKind,
  userEdits: Record<string, string>,
): Record<string, string> {
  return Object.fromEntries(
    Object.entries(userEdits)
      .filter(([key]) => key.startsWith(`${kind}:`))
      .map(([key, value]) => [key.slice(kind.length + 1), value]),
  );
}

export function buildStructuredPreviewContent(
  kind: StructuredLifecycleTemplateKind,
  source: StructuredTemplateSource | null,
  userEdits: Record<string, string>,
) {
  try {
    const edits = localEditsForStructuredPreview(kind, userEdits);
    if (!isStructuredSalesPreviewKind(kind)) {
      const validation = validateSpecializedLocalPreviewPayload(kind, edits);
      if (!validation.ok) {
        return { content: "", error: validation.errors.map((issue) => `${issue.path}: ${issue.message}`).join(" ") };
      }
    }
    const content = isStructuredSalesPreviewKind(kind)
      ? renderStructuredSalesLocalDraftHtml(kind, source, edits)
      : `${renderStructuredLifecycleTemplatePreview(kind, source, edits).content}\n\n${renderSpecializedLocalTraceabilityHtml(kind, source)}`;
    return { content, error: null };
  } catch (error) {
    return { content: "", error: error instanceof Error ? error.message : "Preview unavailable." };
  }
}

export type StructuredSalesDocumentGate = {
  state: "VERIFIED" | "SOURCE_UNAVAILABLE";
  message: string;
};

export function structuredSalesDocumentGate(
  kind: StructuredLifecycleTemplateKind,
  source: StructuredTemplateSource | null,
): StructuredSalesDocumentGate | null {
  if (!isStructuredSalesPreviewKind(kind)) return null;
  if (!source) {
    return {
      state: "SOURCE_UNAVAILABLE",
      message:
        "The exact opportunity and Master Specification revision could not be verified. This local preview cannot be used as a source-backed working draft.",
    };
  }
  return {
    state: "VERIFIED",
    message: `Working from ${source.opportunityNumber} · ${source.specificationNumber} rev ${source.versionNumber}. Local notes remain unsaved and are not an approval, issued document, or release.`,
  };
}

export function StructuredTemplatePreview({
  sourcePin = sampleSource,
  actorId,
  projectId,
  project,
  onDirtyChange,
  localEdits,
  onLocalEditsChange,
}: {
  sourcePin?: StructuredTemplatePreviewSourcePin;
  actorId?: string | null;
  projectId?: string;
  project?: { id: string; name: string; code: string | null };
  onDirtyChange?: (dirty: boolean) => void;
  localEdits?: Record<string, string>;
  onLocalEditsChange?: (edits: Record<string, string>) => void;
}) {
  const [kind, setKind] = useState<StructuredLifecycleTemplateKind>("SOR");
  const [uncontrolledEdits, setUncontrolledEdits] = useState<Record<string, string>>({});
  const scopeKey = `${actorId ?? "signed-out"}:${sourcePin.opportunityNumber}:${sourcePin.specificationNumber}:${sourcePin.versionNumber}`;
  const priorScopeKey = useRef(scopeKey);
  const scopeChanged = priorScopeKey.current !== scopeKey;
  const userEdits = scopeChanged ? {} : (localEdits ?? uncontrolledEdits);
  const setUserEdits = (
    next: Record<string, string> | ((current: Record<string, string>) => Record<string, string>),
  ) => {
    const resolved = typeof next === "function" ? next(userEdits) : next;
    if (localEdits === undefined) setUncontrolledEdits(resolved);
    onLocalEditsChange?.(resolved);
  };
  const [selectedComponentIds, setSelectedComponentIds] = useState<LocalBomComponentSelection>({});
  const [selectedBomId, setSelectedBomId] = useState<string | null>(null);
  const [requestKeys, setRequestKeys] = useState<Partial<Record<StructuredSalesPreviewKind, string>>>({});
  const [persistedEdits, setPersistedEdits] = useState<Partial<Record<StructuredSalesPreviewKind, Record<string, string>>>>({});
  const [saving, setSaving] = useState(false);
  const [downloadingRevisionId, setDownloadingRevisionId] = useState<string | null>(null);
  const [downloadFeedback, setDownloadFeedback] = useState<DownloadFeedback>({ state: "idle" });
  const hydratedRevisionRef = useRef<Record<string, string>>({});
  const queryClient = useQueryClient();
  const source = useQuery({
    queryKey: [
      "structured-template-source",
      actorId ?? "signed-out",
      sourcePin.opportunityNumber,
      sourcePin.specificationNumber,
      sourcePin.versionNumber,
    ],
    queryFn: () => fetchStructuredTemplatePreviewSource({ data: sourcePin }),
    enabled: Boolean(actorId),
    retry: false,
  });
  const listBoms = useServerFn(fetchProjectBoms);
  const getBomItems = useServerFn(fetchProjectBomItems);
  const discoverCapability = useServerFn(discoverStructuredSalesDraftCapability);
  const linkedProject = project ?? source.data?.project ?? null;
  const effectiveProjectId = projectId ?? linkedProject?.id;
  const projectBoms = useQuery({
    queryKey: ["lifecycle-project-boms", effectiveProjectId],
    queryFn: () =>
      effectiveProjectId
        ? listBoms({ data: { projectId: effectiveProjectId } })
        : Promise.resolve([] as ProjectBomSummary[]),
    enabled: Boolean(effectiveProjectId),
    retry: false,
  });
  const selectedBom = useMemo(
    () => selectedBomId ?? projectBoms.data?.[0]?.id ?? null,
    [selectedBomId, projectBoms.data],
  );
  const bomDetail = useQuery({
    queryKey: ["lifecycle-project-bom-detail", effectiveProjectId, selectedBom],
    queryFn: () =>
      selectedBom && effectiveProjectId
        ? getBomItems({ data: { bomId: selectedBom, projectId: effectiveProjectId } })
        : Promise.resolve(null),
    enabled: Boolean(selectedBom && effectiveProjectId),
    retry: false,
  });
  const dirty = hasLocalEdits(userEdits);
  const sourceAdvanced = Boolean(
    source.data &&
      Number.isInteger(source.data.currentVersionNumber) &&
      (source.data.currentVersionNumber ?? 0) > source.data.versionNumber,
  );
  const verifiedSource = actorId ? source.data : undefined;
  const capabilitySourceId = verifiedSource
    ? `${verifiedSource.opportunityId}:${verifiedSource.customerId}:${verifiedSource.specificationId}:${verifiedSource.versionId}`
    : null;
  const isSalesDraftKind = isStructuredSalesPreviewKind(kind);
  const capabilityDiscovery = useQuery({
    queryKey: [
      "structured-sales-draft-capability",
      actorId ?? "signed-out",
      capabilitySourceId,
    ],
    queryFn: () => {
      if (!verifiedSource) throw new Error("The pinned Sales source is unavailable.");
      return discoverCapability({
        data: {
          opportunityId: verifiedSource.opportunityId,
          customerId: verifiedSource.customerId,
          masterSpecificationId: verifiedSource.specificationId,
          masterSpecificationVersionId: verifiedSource.versionId,
        },
      });
    },
    enabled: Boolean(actorId && capabilitySourceId && isSalesDraftKind && source.isSuccess),
    retry: false,
  });
  const structuredHistory = useQuery({
    queryKey: ["structured-sales-draft-history", actorId ?? "signed-out", capabilitySourceId, kind],
    queryFn: async (): Promise<StructuredSalesDraftHistoryItem[]> => {
      if (!verifiedSource || !isStructuredSalesPreviewKind(kind)) return [];
      const { data: drafts, error: draftsError } = await supabase
        .from("sales_opportunity_structured_drafts")
        .select("id")
        .eq("opportunity_id", verifiedSource.opportunityId)
        .eq("customer_id", verifiedSource.customerId)
        .eq("master_specification_id", verifiedSource.specificationId)
        .eq("master_specification_version_id", verifiedSource.versionId)
        .eq("document_kind", kind);
      if (draftsError) throw new Error("Saved draft history could not be read.");
      const draftIds = (drafts ?? []).map((draft) => draft.id);
      if (!draftIds.length) return [];
      const { data: revisions, error: revisionsError } = await supabase
        .from("sales_opportunity_structured_draft_revisions")
        .select("id,revision_number,created_at,draft_id,canonical_payload")
        .in("draft_id", draftIds)
        .order("revision_number", { ascending: false });
      if (revisionsError) throw new Error("Saved draft revisions could not be read.");
      const revisionIds = (revisions ?? []).map((revision) => revision.id);
      if (!revisionIds.length) return [];
      const { data: receipts, error: receiptsError } = await supabase
        .from("sales_opportunity_structured_draft_requests")
        .select("request_key,revision_id")
        .in("revision_id", revisionIds);
      if (receiptsError) throw new Error("Saved draft receipts could not be read.");
      const { data: materializations, error: materializationsError } = await supabase
        .from("sales_opportunity_structured_draft_materializations")
        .select("id,request_key,storage_bucket,storage_path,rendered_sha256_checksum")
        .in("structured_draft_revision_id", revisionIds);
      if (materializationsError) throw new Error("Saved draft materializations could not be read.");
      const receiptByRevision = new Map((receipts ?? []).map((receipt) => [receipt.revision_id, receipt.request_key]));
      const materializationByRequest = new Map((materializations ?? []).map((materialization) => [materialization.request_key, materialization]));
      return (revisions ?? []).flatMap((revision) => {
        const requestKey = receiptByRevision.get(revision.id);
        if (!requestKey) return [];
        const materialization = materializationByRequest.get(requestKey);
        return [{
          requestKey,
          revisionId: revision.id,
          revisionNumber: revision.revision_number,
          materializationId: materialization?.id ?? null,
          storageBucket: materialization?.storage_bucket ?? null,
          storagePath: materialization?.storage_path ?? null,
          checksum: materialization?.rendered_sha256_checksum ?? null,
          createdAt: revision.created_at,
          payload: persistedStructuredSalesDraftFields(kind, revision.canonical_payload),
        }];
      });
    },
    enabled: Boolean(actorId && capabilitySourceId && isSalesDraftKind && source.isSuccess),
    retry: false,
  });
  const updateLocalEdit = (field: string, value: string) => {
    setUserEdits((current) => ({ ...current, [editKey(kind, field)]: value }));
  };
  const selectLocalBomComponent = (rowId: string, candidate: LocalBomComponentCandidate) => {
    const field = "BOM_COST_ROWS";
    const rows = parseLocalTableRows(
      field,
      userEdits[editKey("BOM_COST_TRACKER", field)],
    ) as BomCostRow[];
    const nextRows = rows.map((row) =>
      row.id === rowId ? adoptLocalBomComponent(row, candidate) : row,
    );
    updateLocalEdit(field, serializeLocalTableRows(nextRows));
    setSelectedComponentIds((current) =>
      recordLocalBomComponentSelection(current, rowId, candidate.id),
    );
  };
  useEffect(() => {
    if (scopeChanged) {
      priorScopeKey.current = scopeKey;
      setUncontrolledEdits({});
      onLocalEditsChange?.({});
      setSelectedComponentIds({});
      setSelectedBomId(null);
      setRequestKeys({});
      setPersistedEdits({});
      setDownloadFeedback({ state: "idle" });
      hydratedRevisionRef.current = {};
    }
  }, [scopeChanged, scopeKey, onLocalEditsChange]);
  useEffect(() => {
    setSelectedBomId(null);
  }, [effectiveProjectId]);
  useEffect(() => {
    onDirtyChange?.(dirty);
  }, [dirty, onDirtyChange]);
  useEffect(() => () => onDirtyChange?.(false), [onDirtyChange]);
  useEffect(() => {
    if (!shouldWarnBeforeClosingStructuredPreview(dirty)) return;
    const warn = (event: BeforeUnloadEvent) => {
      event.preventDefault();
      event.returnValue = "";
    };
    window.addEventListener("beforeunload", warn);
    return () => window.removeEventListener("beforeunload", warn);
  }, [dirty]);
  const localEditsForKind = localEditsForStructuredPreview(kind, userEdits);
  const persistedRevision = structuredHistory.data?.[0];
  const persistedFields = isStructuredSalesPreviewKind(kind) ? persistedEdits[kind] : undefined;
  const effectiveEdits = persistedFields
    ? { ...Object.fromEntries(Object.entries(persistedFields).map(([field, value]) => [editKey(kind, field), value])), ...userEdits }
    : userEdits;
  useEffect(() => {
    if (!actorId || !isStructuredSalesPreviewKind(kind) || saving || structuredHistory.isPending || structuredHistory.isError) return;
    const latest = structuredHistory.data?.[0];
    if (!latest?.payload || Object.keys(localEditsForKind).length > 0) return;
    const hydrationKey = `${scopeKey}:${kind}:${latest.revisionId}`;
    if (hydratedRevisionRef.current[kind] === hydrationKey) return;
    hydratedRevisionRef.current[kind] = hydrationKey;
    setPersistedEdits((current) => ({ ...current, [kind]: latest.payload ?? {} }));
  }, [actorId, kind, localEditsForKind, saving, scopeKey, structuredHistory.data, structuredHistory.isError, structuredHistory.isPending]);
  const rendered = useMemo(
    () => buildStructuredPreviewContent(kind, source.data ?? null, effectiveEdits),
    [kind, source.data, effectiveEdits],
  );
  // Keep local manual fields available while an identity/source transition is
  // in progress; only a settled authenticated source result can block them.
  const salesGate = actorId && !source.isPending
    ? structuredSalesDocumentGate(kind, source.data ?? null)
    : null;
  const saveCapability = structuredSalesDraftSaveCapability(
    isStructuredSalesPreviewKind(kind) && salesGate?.state === "VERIFIED",
    capabilityDiscovery.data,
  );
  const saveBoundaryMessage = structuredSalesDraftSaveBoundaryMessage(saveCapability);
  const historyCapability = structuredSalesDraftHistoryCapability(
    isStructuredSalesPreviewKind(kind) && salesGate?.state === "VERIFIED",
    capabilityDiscovery.data,
  );
  const historyBoundaryMessage = structuredSalesDraftHistoryBoundaryMessage(historyCapability);
  const sourceState = !actorId
    ? "UNVERIFIED — signed-in identity unavailable"
    : source.isPending
      ? "LOADING — authorized source request in progress"
      : source.isError
        ? "UNVERIFIED — authorized source unavailable"
        : !source.data
          ? "UNVERIFIED — authorized source returned no record"
          : null;
  const saveDraft = async () => {
    if (!source.data || !isStructuredSalesPreviewKind(kind) || !saveCapability.available || saving) return;
    const payload = localEditsForStructuredPreview(kind, effectiveEdits);
    let canonicalPayload: string;
    try {
      canonicalPayload = canonicalizeStructuredSalesLocalPayload(kind, payload);
    } catch (error) {
      toast.error(error instanceof Error ? error.message : "The draft needs correction before it can be saved.");
      return;
    }
    const expectedRevision = structuredHistory.data?.[0]?.revisionNumber ?? 0;
    const requestKey = requestKeys[kind] ?? newRequestKey();
    setRequestKeys((current) => ({ ...current, [kind]: requestKey }));
    setSaving(true);
    try {
      const { data: saveResult, error: saveError } = await supabase.rpc("save_sales_opportunity_structured_draft_at_location", {
        p_opportunity_id: source.data.opportunityId,
        p_customer_id: source.data.customerId,
        p_master_specification_id: source.data.specificationId,
        p_master_specification_version_id: source.data.versionId,
        p_document_kind: kind,
        p_expected_revision_number: expectedRevision,
        p_payload: JSON.parse(canonicalPayload).fields,
        p_request_key: requestKey,
        p_private_location_id: saveCapability.locationId,
      });
      const receipt = saveResult?.[0];
      if (saveError || !receipt) throw new Error(saveError?.message ?? "The draft receipt could not be created.");
      const html = renderStructuredSalesLocalDraftHtml(kind, source.data, payload);
      const sizeBytes = new TextEncoder().encode(html).byteLength;
      if (sizeBytes > structuredDraftStorageLimit) throw new Error("The rendered draft exceeds the approved 10 MB storage limit.");
      const checksum = await sha256Text(html);
      const storagePath = `${saveCapability.storagePathPrefix}${requestKey}-draft.html`;
      const { error: uploadError } = await supabase.storage
        .from(saveCapability.storageBucket)
        .upload(storagePath, new Blob([html], { type: "text/html;charset=utf-8" }), { contentType: "text/html", upsert: false });
      if (uploadError) throw new Error(uploadError.message);
      const { error: attemptError } = await supabase.rpc("register_sales_opportunity_structured_draft_storage_attempt", {
        p_opportunity_id: source.data.opportunityId,
        p_customer_id: source.data.customerId,
        p_location_id: saveCapability.locationId,
        p_request_key: requestKey,
        p_storage_bucket: saveCapability.storageBucket,
        p_storage_path: storagePath,
        p_sha256_checksum: checksum,
        p_size_bytes: sizeBytes,
      });
      if (attemptError) throw new Error(attemptError.message);
      const { data: committed, error: commitError } = await supabase.rpc("commit_sales_opportunity_structured_draft_materialization", {
        p_opportunity_id: source.data.opportunityId,
        p_customer_id: source.data.customerId,
        p_location_id: saveCapability.locationId,
        p_request_key: requestKey,
        p_file_name: revisionFileName(kind, receipt.revision_number),
        p_storage_bucket: saveCapability.storageBucket,
        p_storage_path: storagePath,
        p_sha256_checksum: checksum,
        p_size_bytes: sizeBytes,
      });
      if (commitError || !committed?.[0]) throw new Error(commitError?.message ?? "The draft could not be materialized.");
      setRequestKeys((current) => {
        const next = { ...current };
        delete next[kind];
        return next;
      });
      await queryClient.invalidateQueries({ queryKey: ["structured-sales-draft-history", actorId ?? "signed-out", capabilitySourceId, kind] });
      await structuredHistory.refetch();
      setUserEdits((current) => {
        const next = { ...current };
        for (const field of Object.keys(next)) {
          if (field.startsWith(`${kind}:`)) delete next[field];
        }
        return next;
      });
      setPersistedEdits((current) => ({ ...current, [kind]: payload }));
      toast.success(receipt.replayed ? "Saved draft replayed." : "Draft saved as an unissued revision.");
    } catch (error) {
      toast.error(error instanceof Error ? error.message : "The draft could not be saved.");
    } finally {
      setSaving(false);
    }
  };
  const downloadSavedDraft = async (entry: StructuredSalesDraftHistoryItem) => {
    if (!entry.storagePath || !entry.storageBucket || !entry.materializationId) {
      toast.error("The verified private file is not available for download.");
      return;
    }
    setDownloadingRevisionId(entry.revisionId);
    try {
      setDownloadFeedback({ state: "loading", revisionNumber: entry.revisionNumber });
      const blob = await downloadVerifiedStructuredSalesDraft(
        () => supabase.storage.from(entry.storageBucket as string).download(entry.storagePath as string),
        entry.checksum,
      );
      const download = document.createElement("a");
      const objectUrl = URL.createObjectURL(blob);
      download.href = objectUrl;
      download.download = revisionFileName(kind as StructuredSalesPreviewKind, entry.revisionNumber);
      download.rel = "noopener";
      document.body.appendChild(download);
      download.click();
      download.remove();
      window.setTimeout(() => URL.revokeObjectURL(objectUrl), 0);
      setDownloadFeedback({ state: "success", revisionNumber: entry.revisionNumber });
      toast.success(`Revision ${entry.revisionNumber} download started.`);
    } catch (error) {
      const message = error instanceof Error ? error.message : "The saved draft could not be downloaded.";
      setDownloadFeedback({ state: "error", message });
      toast.error(message);
    } finally {
      setDownloadingRevisionId(null);
    }
  };
  return (
    <Card>
      <CardHeader>
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div className="flex items-start gap-3">
            <Eye className="mt-0.5 size-5 text-primary" />
            <div>
              <CardTitle>Structured document previews</CardTitle>
              <CardDescription>
                Read-only authorized source: {sourcePin.opportunityNumber} ·{" "}
                {sourcePin.specificationNumber} rev {sourcePin.versionNumber}.
              </CardDescription>
            </div>
          </div>
          <Button
            size="sm"
            variant="outline"
            onClick={() => void source.refetch()}
            disabled={source.isFetching}
          >
            <RefreshCw className="size-4" /> Refresh source
          </Button>
        </div>
      </CardHeader>
      <CardContent>
        {sourceState && (
          <p
            role={source.isError ? "alert" : "status"}
            className="border p-3 text-sm text-muted-foreground"
          >
            {sourceState}
          </p>
        )}
        {source.isPending && (
          <p className="mt-3 border p-3 text-sm text-muted-foreground">
            Loading authorized source…
          </p>
        )}
        {source.isError && (
          <p
            role="alert"
            className="mt-3 border border-destructive/40 p-3 text-sm text-destructive"
          >
            Authorized source could not be loaded:{" "}
            {source.error instanceof Error ? source.error.message : "Unexpected read error"}
          </p>
        )}
        {source.data && <SourcePin source={source.data} />}
        {historyCapability.available && !structuredHistory.isLoading && !structuredHistory.isError && structuredHistory.data?.[0] && (
          <p role="status" className="mt-3 border border-primary/30 bg-primary/5 p-3 text-sm">
            Persisted unissued revision {structuredHistory.data[0].revisionNumber} is available for this exact pinned source.
          </p>
        )}
        {dirty && (
          <p role="status" className="mt-3 border border-amber-500/40 bg-amber-500/5 p-3 text-sm">
            Local edits are unsaved. Refresh reads the same pinned historical revision and does not
            overwrite local text.
          </p>
        )}
        {sourceAdvanced && (
          <p role="alert" className="mt-3 border border-amber-500/40 bg-amber-500/5 p-3 text-sm">
            A newer Master Specification revision ({source.data?.currentVersionNumber}) is available.
            This preview remains pinned to revision {source.data?.versionNumber}; no local edit,
            approval, or source content was replaced.
          </p>
        )}
        <Tabs
          value={kind}
          onValueChange={(value) => setKind(value as StructuredLifecycleTemplateKind)}
          className="mt-4"
        >
          <TabsList className="h-auto flex-wrap justify-start">
            {structuredLifecycleTemplatePreviews.map((item) => (
              <TabsTrigger key={item.kind} value={item.kind}>
                {item.label}
              </TabsTrigger>
            ))}
          </TabsList>
          {structuredLifecycleTemplatePreviews.map((item) => (
            <TabsContent key={item.kind} value={item.kind} className="space-y-4 pt-4">
              <p className="text-sm text-muted-foreground">{item.description}</p>
              {item.kind === "BOM_COST_TRACKER" && (
                <AuthoritativeBomPanel
                  project={linkedProject}
                  projectId={effectiveProjectId}
                  boms={projectBoms.data ?? []}
                  loading={projectBoms.isLoading}
                  error={projectBoms.isError ? projectBoms.error : null}
                  selectedBomId={selectedBom}
                  onSelect={setSelectedBomId}
                  detail={bomDetail.data}
                  detailLoading={bomDetail.isLoading}
                  detailError={bomDetail.isError ? bomDetail.error : null}
                />
              )}
              {item.kind === "BOM_COST_TRACKER" && (
                <p className="border border-amber-500/40 bg-amber-500/5 p-3 text-sm">
                  Any rows below are optional unsaved scratch review only. They are not the project
                  BOM and cannot be saved, matched to stock, or used for a generated document.
                </p>
              )}
              <div className="grid gap-4 2xl:grid-cols-2">
                <div className="min-w-0 space-y-4">
                  <SourceTable item={item} source={source.data ?? null} />
                  {salesGate?.state === "SOURCE_UNAVAILABLE" ? (
                    <section role="alert" className="border border-destructive/40 p-4 text-sm text-destructive">
                      {salesGate.message}
                    </section>
                  ) : (
                    <LocalEditor
                      item={item}
                      userEdits={effectiveEdits}
                      selectedComponentIds={selectedComponentIds}
                      onChange={updateLocalEdit}
                      onSelectLocalBomComponent={selectLocalBomComponent}
                    />
                  )}
                </div>
                <div className="min-w-0">
                  <FormattedPreview
                    item={item}
                    source={source.data ?? null}
                    userEdits={effectiveEdits}
                    error={rendered.error}
                    controlledText={rendered.content}
                    persistedRevisionNumber={persistedRevision?.revisionNumber ?? null}
                    cleanPersisted={Boolean(persistedRevision?.payload && !dirty)}
                  />
                  {salesGate && (
                    <p
                      data-testid="structured-sales-source-gate"
                      role={salesGate.state === "SOURCE_UNAVAILABLE" ? "alert" : "status"}
                      className="mt-3 border p-3 text-sm text-muted-foreground"
                    >
                      {salesGate.message}
                    </p>
                  )}
                </div>
              </div>
            </TabsContent>
          ))}
        </Tabs>
        <div className="mt-4 flex flex-wrap items-center justify-between gap-3 border-t pt-4">
          <p className="text-xs text-muted-foreground">
            {saveBoundaryMessage} Export, issuance, release, and controlled document generation
            remain unavailable.
          </p>
          <div className="flex flex-wrap items-center gap-2">
            <Button
              disabled={!historyCapability.available || structuredHistory.isLoading}
              aria-label="View saved revision history"
              title={historyBoundaryMessage}
              variant="outline"
              onClick={() => void structuredHistory.refetch()}
            >
              <Eye className="size-4" /> {historyCapability.available ? "Refresh history" : "History unavailable"}
            </Button>
            <Button
              disabled={!structuredHistory.data?.[0]?.storagePath || !structuredHistory.data?.[0]?.storageBucket || downloadingRevisionId !== null}
              aria-label="Download saved revision"
              title={structuredHistory.data?.[0]?.storagePath ? "Download the latest verified private draft." : historyBoundaryMessage}
              variant="outline"
              onClick={() => {
                const latest = structuredHistory.data?.[0];
                if (latest) void downloadSavedDraft(latest);
              }}
            >
              <Download className="size-4" /> {downloadingRevisionId ? "Downloading…" : "Download"}
            </Button>
            <Button disabled={!saveCapability.available || saving || !isStructuredSalesPreviewKind(kind)} aria-label="Save structured Sales draft" title={saveBoundaryMessage} onClick={() => void saveDraft()}>
              <Save className="size-4" /> {saving ? "Saving…" : saveCapability.available ? "Save draft" : "Save unavailable"}
            </Button>
          </div>
        </div>
        {capabilityDiscovery.isError && (
          <p role="alert" className="mt-3 border border-destructive/40 p-3 text-sm text-destructive">
            Sales draft capability could not be verified: {capabilityDiscovery.error instanceof Error ? capabilityDiscovery.error.message : "Unexpected read error"}
          </p>
        )}
        {historyCapability.available && structuredHistory.isError && (
          <p role="alert" className="mt-3 border border-destructive/40 p-3 text-sm text-destructive">
            Saved revision history could not be read: {structuredHistory.error instanceof Error ? structuredHistory.error.message : "Unexpected read error"}
          </p>
        )}
        {downloadFeedback.state === "loading" && (
          <p role="status" className="mt-3 border p-3 text-sm text-muted-foreground">Downloading verified private revision {downloadFeedback.revisionNumber}…</p>
        )}
        {downloadFeedback.state === "success" && (
          <p role="status" className="mt-3 border border-primary/30 bg-primary/5 p-3 text-sm">Revision {downloadFeedback.revisionNumber} passed checksum verification and the browser download was started.</p>
        )}
        {downloadFeedback.state === "error" && (
          <p role="alert" className="mt-3 border border-destructive/40 p-3 text-sm text-destructive">Private download unavailable: {downloadFeedback.message}</p>
        )}
        {historyCapability.available && !structuredHistory.isLoading && !structuredHistory.isError && (
          <section className="mt-3 border p-3" aria-label="Saved structured Sales draft history">
            <p className="text-sm font-medium">Saved unissued revisions</p>
            {structuredHistory.data?.length ? (
              <div className="mt-2 space-y-2">
                {structuredHistory.data.map((entry) => (
                  <div key={entry.requestKey} className="flex flex-wrap items-center justify-between gap-2 text-sm">
                    <span>Revision {entry.revisionNumber} · {new Date(entry.createdAt).toLocaleString()}</span>
                    <Button size="sm" variant="outline" disabled={!entry.storagePath || !entry.storageBucket || downloadingRevisionId !== null} onClick={() => void downloadSavedDraft(entry)}>
                      <Download className="size-4" /> {downloadingRevisionId === entry.revisionId ? "Preparing…" : "Download"}
                    </Button>
                  </div>
                ))}
              </div>
            ) : <p className="mt-1 text-sm text-muted-foreground">No saved revision is visible to you.</p>}
          </section>
        )}
      </CardContent>
    </Card>
  );
}
function SourcePin({ source }: { source: StructuredTemplateSource }) {
  return (
    <section data-testid="pinned-authorized-source" className="border p-3">
      <div className="flex items-center gap-2">
        <AlertCircle className="size-4 text-primary" />
        <p className="text-sm font-medium">Pinned authorized source</p>
      </div>
      <div className="mt-2 grid gap-2 text-xs text-muted-foreground sm:grid-cols-2">
        <p>
          Opportunity: <span className="font-mono text-foreground">{source.opportunityNumber}</span>
        </p>
        <p>
          Customer: <span className="text-foreground">{source.customerName}</span>
        </p>
        <p>
          Master Specification:{" "}
          <span className="font-mono text-foreground">
            {source.specificationNumber} rev {source.versionNumber}
          </span>
        </p>
        <p>
          Revision ID: <span className="font-mono text-foreground">{source.versionId}</span>
        </p>
      </div>
      <p className="mt-2 text-xs text-muted-foreground">
        Saved {source.savedAt ? new Date(source.savedAt).toLocaleString() : "TBC"} ·{" "}
        {source.changeSummary ?? "Change note TBC"}
      </p>
    </section>
  );
}
function money(value: number | null | undefined) {
  return value == null
    ? "TBC"
    : value.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}
type ProjectBomDetail = {
  header: ProjectBomSummary & { project_id: string };
  items: ProjectBomItemRow[];
};
function errorText(error: unknown): string {
  return error instanceof Error ? error.message : "Unexpected read error";
}
export function AuthoritativeBomPanel({
  project,
  projectId,
  boms,
  loading,
  error,
  selectedBomId,
  onSelect,
  detail,
  detailLoading,
  detailError,
}: {
  project: StructuredTemplateSource["project"];
  projectId?: string;
  boms: ProjectBomSummary[];
  loading: boolean;
  error: unknown;
  selectedBomId: string | null;
  onSelect: (id: string) => void;
  detail: ProjectBomDetail | null | undefined;
  detailLoading: boolean;
  detailError: unknown;
}) {
  const indexError = error ? errorText(error) : null;
  const itemError = detailError ? errorText(detailError) : null;
  if (!projectId)
    return (
      <section className="border border-amber-500/40 bg-amber-500/5 p-4">
        <div className="flex items-center gap-2">
          <Box className="size-4 text-primary" />
          <p className="font-medium">No project-linked BOM yet</p>
        </div>
        <p className="mt-2 text-sm text-muted-foreground">
          This proposal is not a committed project. No BOM is attached, and no project or BOM will
          be inferred from this opportunity.
        </p>
        <div className="mt-3 flex flex-wrap gap-2">
          <Button asChild size="sm" variant="outline">
            <Link to="/bom">Open existing BOM tool</Link>
          </Button>
          <Button asChild size="sm" variant="outline">
            <Link to="/">Search authorised component catalogue</Link>
          </Button>
        </div>
        <p className="mt-3 text-xs text-muted-foreground">
          The existing BOM tool can only save after a verified project association is selected.
          Component availability is not read here.
        </p>
      </section>
    );
  if (indexError)
    return (
      <section role="alert" className="border border-destructive/40 p-4 text-sm text-destructive">
        The authorised project BOM index could not be read: {indexError}. No BOM, price, or
        inventory state is assumed.
      </section>
    );
  if (loading)
    return (
      <section className="border p-4 text-sm text-muted-foreground">
        Loading authorised saved BOMs…
      </section>
    );
  const projectName = project?.code ?? project?.name ?? "this selected project";
  if (!boms.length)
    return (
      <section className="border p-4">
        <p className="font-medium">No saved BOM for {projectName}</p>
        <p className="mt-1 text-sm text-muted-foreground">
          This committed project has no saved BOM visible to you. Uploading or saving remains in the
          existing BOM tool.
        </p>
        <Button asChild className="mt-3" size="sm" variant="outline">
          <Link to="/bom" search={{ projectId }}>
            Open existing BOM tool
          </Link>
        </Button>
      </section>
    );
  const header = detail?.header;
  return (
    <section className="space-y-3 border p-4">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <p className="font-medium">Authoritative saved project BOM</p>
          <p className="text-sm text-muted-foreground">
            Project {projectName} · read-only from the existing BOM contract.
          </p>
        </div>
        {selectedBomId && (
          <Button asChild size="sm" variant="outline">
            <Link to="/bom" search={{ loadBom: selectedBomId, readOnly: true }}>
              Open read-only BOM detail
            </Link>
          </Button>
        )}
      </div>
      <div className="flex flex-wrap gap-2">
        {boms.map((bom) => (
          <Button
            key={bom.id}
            type="button"
            size="sm"
            variant={bom.id === selectedBomId ? "default" : "outline"}
            onClick={() => onSelect(bom.id)}
          >
            {bom.bom_number} · {bom.revision ? `rev ${bom.revision}` : "revision TBC"}
          </Button>
        ))}
      </div>
      {detailLoading && <p className="text-sm text-muted-foreground">Loading saved BOM lines…</p>}
      {itemError && (
        <p role="alert" className="text-sm text-destructive">
          Saved BOM detail could not be read: {itemError}. Lines, price, and stock remain
          unavailable.
        </p>
      )}
      {header && detail && (
        <>
          <div className="grid gap-2 text-xs text-muted-foreground sm:grid-cols-3">
            <p>
              Saved BOM: <span className="font-mono text-foreground">{header.bom_number}</span>
            </p>
            <p>
              Revision: <span className="text-foreground">{header.revision ?? "TBC"}</span>
            </p>
            <p>
              Source Drive revision:{" "}
              <span className="text-foreground">
                {header.source_drive_revision_id ? "linked" : "not linked / unsupported"}
              </span>
            </p>
          </div>
          <div className="overflow-x-auto border">
            <table className="w-full min-w-[840px] text-left text-xs">
              <thead>
                <tr className="border-b bg-muted/30">
                  <th className="p-2">Refs</th>
                  <th className="p-2">MPN</th>
                  <th className="p-2">Description</th>
                  <th className="p-2 text-right">Qty</th>
                  <th className="p-2 text-right">Unit cost</th>
                  <th className="p-2 text-right">Line total</th>
                  <th className="p-2">Matched component</th>
                  <th className="p-2">Match</th>
                </tr>
              </thead>
              <tbody>
                {detail.items.map((line) => (
                  <tr key={line.id} className="border-b last:border-0">
                    <td className="p-2">{line.refs ?? "TBC"}</td>
                    <td className="p-2 font-mono">{line.mpn ?? "TBC"}</td>
                    <td className="p-2">{line.description ?? line.value ?? "TBC"}</td>
                    <td className="p-2 text-right">{line.quantity}</td>
                    <td className="p-2 text-right">{money(line.unit_cost)}</td>
                    <td className="p-2 text-right">{money(line.total_cost)}</td>
                    <td className="p-2">{line.matched_part_number ?? "TBC"}</td>
                    <td className="p-2">{line.match_status ?? "TBC"}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <p className="text-xs text-muted-foreground">
            Unknown cost is TBC; zero remains zero. Inventory is intentionally not shown in this
            lifecycle view. Any generated controlled document must reference this saved BOM and its
            source Drive revision, not copy these lines.
          </p>
        </>
      )}
    </section>
  );
}
function SourceTable({
  item,
  source,
}: {
  item: (typeof structuredLifecycleTemplatePreviews)[number];
  source: StructuredTemplateSource | null;
}) {
  return (
    <section className="border p-3">
      <p className="text-xs font-medium text-muted-foreground">
        Injected source fields · read-only
      </p>
      <div className="mt-2 overflow-x-auto">
        <table className="w-full text-left text-xs">
          <thead>
            <tr className="border-b text-muted-foreground">
              <th className="p-2">Field</th>
              <th className="p-2">Pinned value</th>
            </tr>
          </thead>
          <tbody>
            {item.sourceFields.map((field) => (
              <tr key={field} className="border-b last:border-0">
                <td className="p-2 font-mono">{field}</td>
                <td className="p-2 whitespace-pre-wrap">{source?.sourceFields[field] ?? "TBC"}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </section>
  );
}
function LocalEditor({
  item,
  userEdits,
  selectedComponentIds,
  onChange,
  onSelectLocalBomComponent,
}: {
  item: (typeof structuredLifecycleTemplatePreviews)[number];
  userEdits: Record<string, string>;
  selectedComponentIds: LocalBomComponentSelection;
  onChange: (field: string, value: string) => void;
  onSelectLocalBomComponent: (rowId: string, candidate: LocalBomComponentCandidate) => void;
}) {
  const groups = item.editableFields.reduce<Record<string, EditableField[]>>(
    (all, field) => ({ ...all, [field.group]: [...(all[field.group] ?? []), field] }),
    {},
  );
  return (
    <section className="space-y-4 border p-3">
      <div className="flex items-center gap-2">
        <LockKeyhole className="size-4 text-muted-foreground" />
        <p className="text-xs font-medium text-muted-foreground">
          Local review edits · unsaved · no approval is recorded
        </p>
      </div>
      {Object.entries(groups).map(([group, fields]) => (
        <fieldset key={group} className="space-y-3 border-t pt-3 first:border-t-0 first:pt-0">
          <legend className="text-sm font-medium">{group}</legend>
          {fields.map((field) =>
            field.kind === "table" ? (
              <EditableRowTable
                key={field.key}
                tableKey={field.key as LocalTableKey}
                label={field.label}
                value={userEdits[editKey(item.kind, field.key)]}
                selectedComponentIds={selectedComponentIds}
                onSelectLocalBomComponent={onSelectLocalBomComponent}
                onChange={(value) => onChange(field.key, value)}
              />
            ) : (
              <div key={field.key} className="space-y-1.5">
                <Label htmlFor={`${item.kind}-${field.key}`}>{field.label}</Label>
                {field.kind === "textarea" ? (
                  <Textarea
                    id={`${item.kind}-${field.key}`}
                    value={userEdits[editKey(item.kind, field.key)] ?? "TBC"}
                    placeholder={field.placeholder}
                    onChange={(event) => onChange(field.key, event.target.value)}
                    maxLength={8000}
                  />
                ) : (
                  <Input
                    id={`${item.kind}-${field.key}`}
                    type={field.kind === "number" ? "text" : undefined}
                    inputMode={field.kind === "number" ? "decimal" : undefined}
                    value={userEdits[editKey(item.kind, field.key)] ?? "TBC"}
                    placeholder={field.placeholder}
                    onChange={(event) => onChange(field.key, event.target.value)}
                    maxLength={1000}
                  />
                )}
              </div>
            ),
          )}
        </fieldset>
      ))}
    </section>
  );
}
const tableColumns: Record<LocalTableKey, { key: string; label: string; numeric?: boolean }[]> = {
  QUOTE_LINE_ROWS: [
    { key: "line", label: "Line" },
    { key: "description", label: "Description" },
    { key: "quantity", label: "Qty", numeric: true },
    { key: "unitPrice", label: "Unit price", numeric: true },
    { key: "currency", label: "Currency" },
    { key: "leadTime", label: "Lead-time" },
  ],
  VOLUME_TIER_ROWS: [
    { key: "minQuantity", label: "Min qty", numeric: true },
    { key: "maxQuantity", label: "Max qty", numeric: true },
    { key: "unitPrice", label: "Unit price", numeric: true },
  ],
  BOM_COST_ROWS: [
    { key: "itemNumber", label: "Item #" },
    { key: "mpn", label: "MPN" },
    { key: "manufacturer", label: "Manufacturer" },
    { key: "description", label: "Description" },
    { key: "package", label: "Package" },
    { key: "quantity", label: "Qty", numeric: true },
    { key: "leadTime", label: "Lead time" },
    { key: "unitCost", label: "Unit cost", numeric: true },
    { key: "currency", label: "Currency" },
    { key: "aecqEvidence", label: "AEC-Q evidence" },
  ],
  DFMEA_ROWS: [
    { key: "function", label: "Function" },
    { key: "failureMode", label: "Failure mode" },
    { key: "effect", label: "Effect" },
    { key: "cause", label: "Cause" },
    { key: "preventionControl", label: "Prevention control" },
    { key: "detectionControl", label: "Detection control" },
    { key: "severity", label: "Severity", numeric: true },
    { key: "occurrence", label: "Occurrence", numeric: true },
    { key: "detection", label: "Detection", numeric: true },
    { key: "owner", label: "Owner" },
    { key: "action", label: "Action" },
  ],
  CONTROL_PLAN_ROWS: [
    { key: "processStep", label: "Process step" },
    { key: "characteristic", label: "Characteristic" },
    { key: "specification", label: "Specification / parameter" },
    { key: "method", label: "Control method" },
    { key: "equipment", label: "Equipment" },
    { key: "sampleFrequency", label: "Sampling" },
    { key: "reactionPlan", label: "Reaction plan" },
    { key: "owner", label: "Owner" },
  ],
  DVPR_ROWS: [
    { key: "test", label: "Test" },
    { key: "applicability", label: "Applicability" },
    { key: "sampleCount", label: "Sample count", numeric: true },
    { key: "acceptanceCriteria", label: "Criteria" },
    { key: "result", label: "Result" },
    { key: "evidence", label: "Evidence" },
    { key: "standardsReference", label: "Standards reference" },
  ],
  PDI_ROWS: [
    { key: "checkpoint", label: "Checkpoint" },
    { key: "expectedCondition", label: "Expected condition" },
    { key: "actualObservation", label: "Actual observation" },
    { key: "evidence", label: "Evidence" },
    { key: "disposition", label: "Disposition" },
  ],
  TAX_INVOICE_ROWS: [
    { key: "description", label: "Description" },
    { key: "quantity", label: "Qty", numeric: true },
    { key: "unitPrice", label: "Unit price", numeric: true },
    { key: "currency", label: "Currency" },
    { key: "taxRate", label: "Tax rate %", numeric: true },
  ],
};
function EditableRowTable({
  tableKey,
  label,
  value,
  selectedComponentIds,
  onChange,
  onSelectLocalBomComponent,
}: {
  tableKey: LocalTableKey;
  label: string;
  value?: string;
  selectedComponentIds: LocalBomComponentSelection;
  onChange: (value: string) => void;
  onSelectLocalBomComponent: (rowId: string, candidate: LocalBomComponentCandidate) => void;
}) {
  const rows = parseLocalTableRows(tableKey, value);
  const columns = tableColumns[tableKey];
  const issues = validateLocalTableRows(tableKey, value);
  const issueFor = (rowId: string, field: string) =>
    issues.find((issue) => issue.rowId === rowId && issue.field === field)?.message;
  const update = (id: string, key: string, next: string) =>
    onChange(
      serializeLocalTableRows(rows.map((row) => (row.id === id ? { ...row, [key]: next } : row))),
    );
  const extraColumns =
    tableKey === "QUOTE_LINE_ROWS" || tableKey === "DFMEA_ROWS"
      ? 2
      : tableKey === "TAX_INVOICE_ROWS"
        ? 4
        : tableKey === "BOM_COST_ROWS"
          ? 2
          : 1;
  const helper =
    tableKey === "BOM_COST_ROWS"
      ? "Component search only identifies a local selected component. It fills empty MPN, manufacturer, and description cells; all nonempty manual values and every other field stay unchanged."
      : tableKey === "DFMEA_ROWS"
        ? "Severity, occurrence, and detection each accept whole numbers from 1 to 10 or TBC. RPN is shown only when all three ratings are valid."
        : tableKey === "TAX_INVOICE_ROWS"
          ? "Calculations appear only with complete valid quantity, price, currency, and tax rate. This is not an issued invoice."
          : "Blank numeric cells are TBC; an explicit 0 stays 0. Invalid rows do not produce usable provisional estimates.";
  return (
    <div className="space-y-2">
      <div className="flex items-center justify-between gap-3">
        <Label>{label}</Label>
        <Button
          type="button"
          size="sm"
          variant="outline"
          aria-label={`Add ${label} row`}
          onClick={() =>
            onChange(
              serializeLocalTableRows([
                ...rows,
                createLocalTableRow(tableKey, crypto.randomUUID()),
              ]),
            )
          }
        >
          <Plus className="size-4" /> Add row
        </Button>
      </div>
      {issues.length > 0 && (
        <p role="alert" className="text-sm text-destructive">
          Invalid input: correct the marked cells before using this local table.
        </p>
      )}
      <div className="overflow-x-auto border">
        <table className="w-full min-w-[720px] text-left text-xs">
          <thead>
            <tr className="border-b bg-muted/30">
              {columns.map((column) => (
                <th key={column.key} scope="col" className="p-2 font-medium">
                  {column.label}
                </th>
              ))}
              {tableKey === "BOM_COST_ROWS" && (
                <th scope="col" className="p-2 font-medium">
                  Local component
                </th>
              )}
              {tableKey === "QUOTE_LINE_ROWS" && (
                <th scope="col" className="p-2 font-medium">
                  Provisional estimate
                </th>
              )}
              {tableKey === "DFMEA_ROWS" && (
                <th scope="col" className="p-2 font-medium">
                  RPN
                </th>
              )}
              {tableKey === "TAX_INVOICE_ROWS" && (
                <>
                  <th scope="col" className="p-2 font-medium">
                    Subtotal
                  </th>
                  <th scope="col" className="p-2 font-medium">
                    Tax
                  </th>
                  <th scope="col" className="p-2 font-medium">
                    Total
                  </th>
                </>
              )}
              <th scope="col" className="p-2">
                <span className="sr-only">Remove row</span>
              </th>
            </tr>
          </thead>
          <tbody>
            {rows.map((row, rowIndex) => (
              <tr key={row.id} className="border-b align-top last:border-0">
                {columns.map((column) => {
                  const issue = issueFor(row.id, column.key);
                  const inputId = `${tableKey}-${row.id}-${column.key}`;
                  return (
                    <td key={column.key} className="p-1">
                      <Input
                        id={inputId}
                        aria-label={`${label} row ${rowIndex + 1} ${column.label}`}
                        aria-invalid={Boolean(issue)}
                        aria-describedby={issue ? `${inputId}-error` : undefined}
                        type="text"
                        inputMode={column.numeric ? "decimal" : undefined}
                        value={String((row as Record<string, string>)[column.key] ?? "")}
                        placeholder="TBC"
                        maxLength={500}
                        onChange={(event) => update(row.id, column.key, event.target.value)}
                      />
                      {issue && (
                        <p
                          id={`${inputId}-error`}
                          role="alert"
                          className="mt-1 text-xs text-destructive"
                        >
                          {issue}
                        </p>
                      )}
                    </td>
                  );
                })}
                {tableKey === "BOM_COST_ROWS" && (
                  <td className="p-1">
                    <LocalBomComponentPicker
                      rowLabel={`${label} row ${rowIndex + 1}`}
                      selectedComponentId={selectedComponentIds[row.id] ?? null}
                      onSelect={(candidate) => onSelectLocalBomComponent(row.id, candidate)}
                    />
                  </td>
                )}
                {tableKey === "QUOTE_LINE_ROWS" && (
                  <td className="p-2 font-medium">
                    {issues.some((issue) => issue.rowId === row.id)
                      ? "Invalid input"
                      : quoteLineEstimate(row as QuoteLineRow)}
                  </td>
                )}
                {tableKey === "DFMEA_ROWS" && (
                  <td className="p-2 font-medium">
                    {issues.some((issue) => issue.rowId === row.id)
                      ? "Invalid input"
                      : dfmeaRpn(row as never)}
                  </td>
                )}
                {tableKey === "TAX_INVOICE_ROWS" &&
                  (() => {
                    const totals = taxInvoiceLineTotals(row as TaxInvoiceRow);
                    return (
                      <>
                        <td className="p-2 font-medium">{totals.subtotal}</td>
                        <td className="p-2 font-medium">{totals.tax}</td>
                        <td className="p-2 font-medium">{totals.total}</td>
                      </>
                    );
                  })()}
                <td className="p-1">
                  <Button
                    type="button"
                    size="icon"
                    variant="ghost"
                    aria-label={`Remove ${label} row ${rowIndex + 1}`}
                    onClick={() =>
                      onChange(
                        serializeLocalTableRows(rows.filter((current) => current.id !== row.id)),
                      )
                    }
                  >
                    <Trash2 className="size-4" />
                  </Button>
                </td>
              </tr>
            ))}
            {!rows.length && (
              <tr>
                <td colSpan={columns.length + extraColumns} className="p-3 text-muted-foreground">
                  No local rows. Add a row to begin a provisional review.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
      <p className="text-xs text-muted-foreground">{helper}</p>
    </div>
  );
}
export function FormattedPreview({
  item,
  source,
  userEdits,
  error,
  controlledText,
}: {
  item: (typeof structuredLifecycleTemplatePreviews)[number];
  source: StructuredTemplateSource | null;
  userEdits: Record<string, string>;
  error: string | null;
  controlledText: string;
}) {
  const value = (field: string) =>
    userEdits[editKey(item.kind, field)] ?? userEdits[field] ?? "TBC";
  const sourceValue = (field: string) => source?.sourceFields[field] ?? "TBC";
  const specializedTraceability = !isStructuredSalesPreviewKind(item.kind)
    ? renderSpecializedLocalTraceabilityHtml(item.kind, source)
    : null;
  const contextRows =
    item.kind === "NDA"
      ? [
          ["Confidential scope", value("CONFIDENTIAL_SCOPE")],
          ["Obligations", value("OBLIGATIONS")],
          ["Intellectual property", value("IP_POSITION")],
          ["Governing law", value("GOVERNING_LAW")],
        ]
      : item.kind === "CONTRACT_REVIEW"
        ? [
            ["Hardware", value("HARDWARE_FEASIBILITY")],
            ["Firmware", value("FIRMWARE_FEASIBILITY")],
            ["Mechanical", value("MECHANICAL_FEASIBILITY")],
            ["Customer authorization", "NOT APPROVED / TBC (not inferred)"],
          ]
        : item.kind === "SOR"
          ? [
              ["OEM requirement rows", value("OEM_REQUIREMENT_ROWS")],
              [
                "CAN / telemetry",
                `${sourceValue("INTERFACES")} · ${sourceValue("CONNECTIVITY_AND_GNSS")} · ${value("CAN_TELEMETRY_NOTES")}`,
              ],
              ["Pilot / rollout", `${sourceValue("VOLUMES")} · ${value("PILOT_ROLLOUT_NOTES")}`],
              ["SLA / warranty / delivery", value("COMMERCIAL_SLA_WARRANTY_DELIVERY")],
            ]
          : item.kind === "PRS"
            ? [
                ["Power", `${sourceValue("POWER_AND_UNITS")} · ${value("POWER_REQUIREMENT")}`],
                ["Interfaces", `${sourceValue("INTERFACES")} · ${value("INTERFACE_REQUIREMENT")}`],
                [
                  "Connectivity / GNSS",
                  `${sourceValue("CONNECTIVITY_AND_GNSS")} · ${value("CONNECTIVITY_REQUIREMENT")}`,
                ],
                [
                  "Mechanical / firmware",
                  `${value("MECHANICAL_REQUIREMENT")} · ${value("FIRMWARE_REQUIREMENT")} · ${value("VERIFICATION_METHOD")}`,
                ],
                ["Components / standards", `TBC · ${sourceValue("REQUESTED_STANDARDS")}`],
              ]
            : [];
  const localRows = item.editableFields
    .filter((field) => field.kind !== "table")
    .map((field) => [
      field.key === "LOCAL_COST_TOTAL"
        ? "Local estimated total (manual / unverified)"
        : field.label,
      value(field.key),
    ]);
  const tableOutput = (tableKey: LocalTableKey, estimate = false) => {
    const raw = value(tableKey);
    const rows = parseLocalTableRows(tableKey, raw);
    const issues = validateLocalTableRows(tableKey, raw);
    return {
      rowIds: rows.map((row) => row.id),
      rows: tableRowsForOutput(tableKey, raw).map((row, index) =>
        estimate
          ? [
              ...row,
              issues.some((issue) => issue.rowId === rows[index]?.id)
                ? "Invalid input"
                : quoteLineEstimate(rows[index] as QuoteLineRow),
            ]
          : row,
      ),
      issues,
    };
  };
  const quoteOutput = tableOutput("QUOTE_LINE_ROWS", true);
  const tierOutput = tableOutput("VOLUME_TIER_ROWS");
  const bomOutput = tableOutput("BOM_COST_ROWS");
  const dfmeaOutput = tableOutput("DFMEA_ROWS");
  const controlPlanOutput = tableOutput("CONTROL_PLAN_ROWS");
  const dvprOutput = tableOutput("DVPR_ROWS");
  const pdiOutput = tableOutput("PDI_ROWS");
  const invoiceOutput = tableOutput("TAX_INVOICE_ROWS");
  if (isStructuredSalesPreviewKind(item.kind)) {
    return (
      <section className="space-y-3">
        <div>
          <p className="text-sm font-medium">Formatted local preview</p>
          <p className="mt-1 text-xs text-muted-foreground">
            Local unsaved draft — NOT APPROVED / TBC. It cannot create an approval, release, or
            controlled record.
          </p>
        </div>
        {error ? (
          <p role="alert" className="border border-destructive/40 p-3 text-sm text-destructive">
            {error}
          </p>
        ) : (
          <iframe
            title={`${item.label} local unsaved preview`}
            sandbox=""
            srcDoc={controlledText}
            className="h-[620px] w-full border bg-background"
          />
        )}
      </section>
    );
  }
  return (
    <section className="space-y-3">
      <div>
        <p className="text-sm font-medium">Formatted local preview</p>
        <p className="mt-1 text-xs text-muted-foreground">
          React-rendered text and tables only; source and local text are escaped and never executed.
        </p>
      </div>
      {error ? (
        <p role="alert" className="border border-destructive/40 p-3 text-sm text-destructive">
          Local preview input needs correction: {error}
        </p>
      ) : null}
      {item.kind === "COMMERCIAL_QUOTATION" ? (
        <>
          <OutputTable
            title="Quote lines · provisional local estimates"
            headers={[
              "Line",
              "Description",
              "Qty",
              "Unit price",
              "Currency",
              "Lead-time",
              "Estimate",
            ]}
            fields={[
              "line",
              "description",
              "quantity",
              "unitPrice",
              "currency",
              "leadTime",
              "estimate",
            ]}
            {...quoteOutput}
          />
          <OutputTable
            title="Volume tiers · provisional"
            headers={["Min qty", "Max qty", "Unit price"]}
            fields={["minQuantity", "maxQuantity", "unitPrice"]}
            {...tierOutput}
          />
        </>
      ) : null}
      {item.kind === "BOM_COST_TRACKER" ? (
        <OutputTable
          title="BOM cost rows · local review only"
          headers={[
            "Item #",
            "MPN",
            "Manufacturer",
            "Description",
            "Package",
            "Qty",
            "Lead time",
            "Unit cost",
            "Currency",
            "AEC-Q evidence",
          ]}
          fields={[
            "itemNumber",
            "mpn",
            "manufacturer",
            "description",
            "package",
            "quantity",
            "leadTime",
            "unitCost",
            "currency",
            "aecqEvidence",
          ]}
          {...bomOutput}
        />
      ) : null}
      {item.kind === "DFMEA" ? (
        <OutputTable
          title="DFMEA rows · local risk review only"
          headers={[
            "Function",
            "Failure mode",
            "Effect",
            "Cause",
            "Prevention control",
            "Detection control",
            "Severity",
            "Occurrence",
            "Detection",
            "RPN",
            "Owner",
            "Action",
          ]}
          fields={[
            "function",
            "failureMode",
            "effect",
            "cause",
            "preventionControl",
            "detectionControl",
            "severity",
            "occurrence",
            "detection",
            "rpn",
            "owner",
            "action",
          ]}
          {...dfmeaOutput}
        />
      ) : null}
      {item.kind === "MANUFACTURING_CONTROL_PLAN" ? (
        <OutputTable
          title="Control-plan rows · local process review only"
          headers={[
            "Process step",
            "Characteristic",
            "Specification / parameter",
            "Control method",
            "Equipment",
            "Sampling",
            "Reaction plan",
            "Owner",
          ]}
          fields={[
            "processStep",
            "characteristic",
            "specification",
            "method",
            "equipment",
            "sampleFrequency",
            "reactionPlan",
            "owner",
          ]}
          {...controlPlanOutput}
        />
      ) : null}
      {item.kind === "DVPR" ? (
        <OutputTable
          title="DVP&R rows · local verification review only"
          headers={[
            "Test",
            "Applicability",
            "Sample count",
            "Criteria",
            "Result",
            "Evidence",
            "Standards reference",
          ]}
          fields={[
            "test",
            "applicability",
            "sampleCount",
            "acceptanceCriteria",
            "result",
            "evidence",
            "standardsReference",
          ]}
          {...dvprOutput}
        />
      ) : null}
      {item.kind === "PDI" ? (
        <OutputTable
          title="PDI checkpoints · local inspection review only"
          headers={[
            "Checkpoint",
            "Expected condition",
            "Actual observation",
            "Evidence",
            "Disposition",
          ]}
          fields={[
            "checkpoint",
            "expectedCondition",
            "actualObservation",
            "evidence",
            "disposition",
          ]}
          {...pdiOutput}
        />
      ) : null}
      {item.kind === "COMMERCIAL_TAX_INVOICE" ? (
        <OutputTable
          title="Draft invoice lines · local calculation only"
          headers={[
            "Description",
            "Qty",
            "Unit price",
            "Currency",
            "Tax rate %",
            "Subtotal",
            "Tax",
            "Total",
          ]}
          fields={[
            "description",
            "quantity",
            "unitPrice",
            "currency",
            "taxRate",
            "subtotal",
            "tax",
            "total",
          ]}
          {...{
            ...invoiceOutput,
            rows: invoiceOutput.rows.map((row, index) => [
              ...row,
              ...Object.values(
                taxInvoiceLineTotals(
                  parseLocalTableRows("TAX_INVOICE_ROWS", value("TAX_INVOICE_ROWS"))[
                    index
                  ] as TaxInvoiceRow,
                ),
              ),
            ]),
          }}
        />
      ) : null}
      {item.kind === "ANNUAL_SKILL_MATRIX" ? (
        <p role="status" className="border border-amber-500/40 bg-amber-500/5 p-3 text-sm">
          Unsupported here: a verified HR scope and capability are required before employee data can
          be shown. No employee data was read.
        </p>
      ) : null}
      {contextRows.length > 0 ? (
        <PreviewTable
          title="Document structure"
          rows={contextRows}
          state={item.kind === "NDA" ? "UNCONFIRMED / TBC" : "Local draft / TBC"}
        />
      ) : null}
      {localRows.length > 0 ? (
        <PreviewTable
          title="Every local editable field"
          rows={localRows}
          state="Unsaved local edit"
        />
      ) : null}
      {specializedTraceability ? (
        <section className="border p-3">
          <p className="text-sm font-medium">Source traceability</p>
          <p className="mt-1 text-xs text-muted-foreground">
            Exact pinned preview context. TBC is unresolved and is not a qualification, result, cost,
            approval, or customer acceptance.
          </p>
          <div className="mt-3 overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead>
                <tr className="border-b text-muted-foreground">
                  <th className="p-2">Trace</th>
                  <th className="p-2">Pinned source value</th>
                </tr>
              </thead>
              <tbody>
                {item.sourceFields.map((field) => (
                  <tr key={field} className="border-b last:border-0">
                    <th scope="row" className="p-2 font-medium">{field}</th>
                    <td className="p-2 whitespace-pre-wrap">{sourceValue(field)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <p className="mt-3 text-xs text-muted-foreground">
            LOCAL PREVIEW ONLY — NOT ISSUED OR CONTROLLED. Local fields remain unsaved.
          </p>
        </section>
      ) : null}
      <details className="border p-3">
        <summary className="cursor-pointer text-sm font-medium">Controlled text rendering</summary>
        {error ? (
          <p role="alert" className="mt-3 text-sm text-destructive">
            {error}
          </p>
        ) : (
          <pre className="mt-3 whitespace-pre-wrap break-words text-xs text-muted-foreground">
            {controlledText}
          </pre>
        )}
      </details>
    </section>
  );
}
function OutputTable({
  title,
  headers,
  fields,
  rowIds,
  rows,
  issues,
}: {
  title: string;
  headers: string[];
  fields: string[];
  rowIds: string[];
  rows: string[][];
  issues: TableValidationIssue[];
}) {
  const invalid = issues.length > 0;
  return (
    <div className="overflow-x-auto border">
      <p className="border-b bg-muted/30 p-2 text-xs font-medium text-muted-foreground">{title}</p>
      {invalid && (
        <p role="alert" className="border-b border-destructive/40 p-2 text-sm text-destructive">
          Invalid input — this local table is not a usable provisional estimate.
        </p>
      )}
      <table className="w-full text-left text-xs">
        <thead>
          <tr className="border-b bg-muted/30">
            {headers.map((header) => (
              <th key={header} scope="col" className="p-2">
                {header}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.length ? (
            rows.map((row, index) => (
              <tr
                key={`${title}-${rowIds[index] ?? index}`}
                className="border-b last:border-0 align-top"
              >
                {row.map((cell, cellIndex) => {
                  const cellIssues = issues.filter(
                    (issue) => issue.rowId === rowIds[index] && issue.field === fields[cellIndex],
                  );
                  return (
                    <td
                      key={`${rowIds[index] ?? index}-${fields[cellIndex] ?? cellIndex}`}
                      className="p-2 whitespace-pre-wrap break-words"
                    >
                      {fieldValue(cell)}
                      {cellIssues.map((issue) => (
                        <p
                          key={issue.message}
                          role="alert"
                          className="mt-1 text-xs text-destructive"
                        >
                          Invalid input: {issue.message}
                        </p>
                      ))}
                    </td>
                  );
                })}
              </tr>
            ))
          ) : (
            <tr>
              <td colSpan={headers.length} className="p-3 text-muted-foreground">
                TBC — no local rows entered.
              </td>
            </tr>
          )}
        </tbody>
      </table>
    </div>
  );
}
function PreviewTable({ title, rows, state }: { title: string; rows: string[][]; state: string }) {
  return (
    <div className="overflow-x-auto border">
      <p className="border-b bg-muted/30 p-2 text-xs font-medium text-muted-foreground">{title}</p>
      <table className="w-full text-left text-sm">
        <thead>
          <tr className="border-b bg-muted/30">
            <th className="p-2">Section / field</th>
            <th className="p-2">Requested or local review content</th>
            <th className="p-2">State</th>
          </tr>
        </thead>
        <tbody>
          {rows.map(([label, content]) => (
            <tr key={label} className="border-b last:border-0 align-top">
              <td className="p-2 font-medium">{label}</td>
              <td className="p-2 whitespace-pre-wrap break-words">{content}</td>
              <td className="p-2">{state}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
