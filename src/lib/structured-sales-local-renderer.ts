import type { StructuredTemplateSource } from "@/lib/lifecycle-structured-template-previews";
import {
  type StructuredSalesLocalDocumentKind,
  type StructuredSalesLocalEditablePayload,
  validateStructuredSalesLocalPayload,
} from "./structured-sales-local-payload";

/**
 * Pure local-preview preparation only. This renderer has no save, download,
 * storage, or authority over controlled Sales records.
 */
export type StructuredSalesLocalRendererSource = Pick<StructuredTemplateSource, "sourceFields">;

const unavailable = "TBC";

const fieldLabels: Record<StructuredSalesLocalDocumentKind, readonly [string, string][]> = {
  SOR: [
    ["OEM_REQUIREMENT_ROWS", "OEM requirement rows"],
    ["SCOPE_STATEMENT", "Scope statement"],
    ["ACCEPTANCE_CRITERIA", "Acceptance criteria"],
    ["CAN_TELEMETRY_NOTES", "CAN / telemetry review notes"],
    ["PILOT_ROLLOUT_NOTES", "Pilot and rollout notes"],
    ["COMMERCIAL_SLA_WARRANTY_DELIVERY", "SLA, warranty and delivery notes"],
  ],
  CONTRACT_REVIEW: [
    ["HARDWARE_FEASIBILITY", "Hardware feasibility evidence / risk / owner"],
    ["FIRMWARE_FEASIBILITY", "Firmware feasibility evidence / risk / owner"],
    ["MECHANICAL_FEASIBILITY", "Mechanical feasibility evidence / risk / owner"],
    ["COMMERCIAL_EVIDENCE", "Commercial evidence and risk"],
    ["OWNER_AND_ACTION", "Local owner and next action"],
    ["LOCAL_DECISION_NOTE", "Local decision note"],
  ],
  PRS: [
    ["POWER_REQUIREMENT", "Power requirement"],
    ["INTERFACE_REQUIREMENT", "Interface requirement"],
    ["CONNECTIVITY_REQUIREMENT", "Connectivity / GNSS requirement"],
    ["MECHANICAL_REQUIREMENT", "Mechanical / environmental requirement"],
    ["FIRMWARE_REQUIREMENT", "Firmware requirement"],
    ["VERIFICATION_METHOD", "Local verification proposal"],
  ],
};

const sourceLabels: Record<StructuredSalesLocalDocumentKind, readonly [string, string][]> = {
  SOR: [
    ["PROJECT_CODE", "Opportunity"],
    ["PROJECT_NAME", "Project name"],
    ["PROJECT_REVISION", "Master Specification revision"],
    ["CUSTOMER_NAME", "Customer"],
    ["REQUIREMENT_SUMMARY", "Requirement summary"],
    ["POWER_AND_UNITS", "Power and units"],
    ["INTERFACES", "Interfaces"],
    ["CONNECTIVITY_AND_GNSS", "Connectivity / GNSS"],
    ["VOLUMES", "Volumes"],
  ],
  CONTRACT_REVIEW: [
    ["PROJECT_CODE", "Opportunity"],
    ["CUSTOMER_NAME", "Customer"],
    ["MASTER_SPECIFICATION", "Master Specification"],
    ["SOURCE_DOCUMENT", "Source document"],
    ["REQUIREMENT_SUMMARY", "Requirement summary"],
    ["WORKSTREAMS", "Workstreams"],
    ["VOLUMES", "Volumes"],
  ],
  PRS: [
    ["PROJECT_CODE", "Opportunity"],
    ["PROJECT_NAME", "Project name"],
    ["PROJECT_REVISION", "Master Specification revision"],
    ["MASTER_SPECIFICATION", "Master Specification"],
    ["POWER_AND_UNITS", "Power and units"],
    ["INTERFACES", "Interfaces"],
    ["CONNECTIVITY_AND_GNSS", "Connectivity / GNSS"],
    ["ENVIRONMENT_AND_IP", "Environment / IP"],
    ["REQUESTED_STANDARDS", "Requested standards"],
    ["VOLUMES", "Volumes"],
  ],
};

const titles: Record<StructuredSalesLocalDocumentKind, string> = {
  SOR: "Statement of Requirements",
  CONTRACT_REVIEW: "Contract Review",
  PRS: "Product Requirements Specification",
};

const traceabilityRows: Record<StructuredSalesLocalDocumentKind, readonly [string, string][]> = {
  SOR: [
    ["Source pin", "PROJECT_CODE"],
    ["Master Specification", "MASTER_SPECIFICATION"],
    ["Requirement context", "REQUIREMENT_SUMMARY"],
    ["Interfaces", "INTERFACES"],
    ["Connectivity / GNSS", "CONNECTIVITY_AND_GNSS"],
    ["Requested volume", "VOLUMES"],
  ],
  CONTRACT_REVIEW: [
    ["Source pin", "PROJECT_CODE"],
    ["Customer", "CUSTOMER_NAME"],
    ["Master Specification", "MASTER_SPECIFICATION"],
    ["Source record", "SOURCE_DOCUMENT"],
    ["Engineering workstreams", "WORKSTREAMS"],
    ["Requested volume", "VOLUMES"],
  ],
  PRS: [
    ["Source pin", "PROJECT_CODE"],
    ["Master Specification", "MASTER_SPECIFICATION"],
    ["Power / units", "POWER_AND_UNITS"],
    ["Interfaces", "INTERFACES"],
    ["Connectivity / GNSS", "CONNECTIVITY_AND_GNSS"],
    ["Environment / IP", "ENVIRONMENT_AND_IP"],
    ["Requested standards", "REQUESTED_STANDARDS"],
  ],
};

function escapeHtml(value: string): string {
  return value.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/\"/g, "&quot;").replace(/'/g, "&#39;");
}

function sourceValue(source: StructuredSalesLocalRendererSource | null, key: string): string {
  const descriptor = source?.sourceFields ? Object.getOwnPropertyDescriptor(source.sourceFields, key) : undefined;
  return typeof descriptor?.value === "string" ? descriptor.value : unavailable;
}

function localValue(payload: StructuredSalesLocalEditablePayload, key: string): string {
  const descriptor = Object.getOwnPropertyDescriptor(payload, key);
  return typeof descriptor?.value === "string" ? descriptor.value : unavailable;
}

function definitionList(entries: readonly [string, string][], valueFor: (key: string) => string): string {
  return `<dl>${entries.map(([key, label]) => `<div><dt>${escapeHtml(label)}</dt><dd><pre>${escapeHtml(valueFor(key))}</pre></dd></div>`).join("")}</dl>`;
}

function traceabilityTable(kind: StructuredSalesLocalDocumentKind, source: StructuredSalesLocalRendererSource | null): string {
  const rows = traceabilityRows[kind]
    .map(([label, key]) => `<tr><th scope="row">${escapeHtml(label)}</th><td>${escapeHtml(sourceValue(source, key))}</td></tr>`)
    .join("");
  return `<table><caption>Source traceability — exact pinned preview context</caption><thead><tr><th>Trace</th><th>Pinned source value</th></tr></thead><tbody>${rows}</tbody></table>`;
}

/** Renders only validated local edits and existing verified-preview source fields into fixed, inert HTML. */
export function renderStructuredSalesLocalDraftHtml(kind: unknown, source: StructuredSalesLocalRendererSource | null, input: unknown): string {
  const validated = validateStructuredSalesLocalPayload(kind, input);
  if (!validated.ok) throw new Error(validated.errors.map((error) => `${error.path}: ${error.message}`).join(" "));
  if (kind !== "SOR" && kind !== "CONTRACT_REVIEW" && kind !== "PRS") throw new Error("kind: Unsupported structured Sales document kind.");

  const authorityNotice = kind === "CONTRACT_REVIEW"
    ? "Approval status: NOT APPROVED / TBC. Local inputs cannot create a feasibility, commercial, customer, or release approval."
    : "Local inputs are working notes only. They do not create an approval, release, customer commitment, or controlled record.";

  const sourceLoaded = source !== null;
  const sourceHeading = sourceLoaded ? "Verified preview source" : "UNVERIFIED — source unavailable";
  const footer = sourceLoaded
    ? "Prepared locally from the verified preview source. This output is source preparation only and does not persist, save, issue, or download a document."
    : "No verified source loaded. This output is source preparation only and does not persist, save, issue, or download a document.";

  return `<article data-document-kind="${kind}"><header><h1>${titles[kind]}</h1><p>LOCAL PREVIEW ONLY — NOT A CONTROLLED DOCUMENT</p></header><section><h2>${sourceHeading}</h2>${definitionList(sourceLabels[kind], (key) => sourceValue(source, key))}</section><section><h2>Automotive requirement traceability</h2><p>Values below are copied from the exact pinned source for review context. TBC remains unresolved and is not a requirement, verification result, compliance claim, or acceptance.</p>${traceabilityTable(kind, source)}</section><section><h2>Local working notes</h2><p>${authorityNotice}</p>${definitionList(fieldLabels[kind], (key) => localValue(validated.payload, key))}</section><footer><p>${footer}</p></footer></article>`;
}