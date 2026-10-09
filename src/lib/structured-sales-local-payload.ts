/**
 * Proposed local-contract limits only. These rules mirror the three existing
 * browser editors; they are not a deployed database or save contract.
 */
export const structuredSalesLocalPayloadLimits = {
  textareaCharacters: 8_000,
  textCharacters: 1_000,
  totalCharacters: 48_000,
} as const;

export type SorEditablePayload = {
  OEM_REQUIREMENT_ROWS?: string;
  SCOPE_STATEMENT?: string;
  ACCEPTANCE_CRITERIA?: string;
  CAN_TELEMETRY_NOTES?: string;
  PILOT_ROLLOUT_NOTES?: string;
  COMMERCIAL_SLA_WARRANTY_DELIVERY?: string;
};

export type ContractReviewEditablePayload = {
  HARDWARE_FEASIBILITY?: string;
  FIRMWARE_FEASIBILITY?: string;
  MECHANICAL_FEASIBILITY?: string;
  COMMERCIAL_EVIDENCE?: string;
  OWNER_AND_ACTION?: string;
  LOCAL_DECISION_NOTE?: string;
};

export type PrsEditablePayload = {
  POWER_REQUIREMENT?: string;
  INTERFACE_REQUIREMENT?: string;
  CONNECTIVITY_REQUIREMENT?: string;
  MECHANICAL_REQUIREMENT?: string;
  FIRMWARE_REQUIREMENT?: string;
  VERIFICATION_METHOD?: string;
};

export type StructuredSalesLocalDocumentKind = "SOR" | "CONTRACT_REVIEW" | "PRS";
export type StructuredSalesLocalEditablePayload = SorEditablePayload | ContractReviewEditablePayload | PrsEditablePayload;
export type StructuredSalesLocalPayloadError = { path: string; message: string };
export type StructuredSalesLocalPayloadValidation =
  | { ok: true; payload: StructuredSalesLocalEditablePayload }
  | { ok: false; errors: StructuredSalesLocalPayloadError[] };

type EditableFieldRule = { key: string; maximumCharacters: number };

const localFieldRules: Record<StructuredSalesLocalDocumentKind, EditableFieldRule[]> = {
  SOR: [
    { key: "OEM_REQUIREMENT_ROWS", maximumCharacters: structuredSalesLocalPayloadLimits.textareaCharacters },
    { key: "SCOPE_STATEMENT", maximumCharacters: structuredSalesLocalPayloadLimits.textareaCharacters },
    { key: "ACCEPTANCE_CRITERIA", maximumCharacters: structuredSalesLocalPayloadLimits.textareaCharacters },
    { key: "CAN_TELEMETRY_NOTES", maximumCharacters: structuredSalesLocalPayloadLimits.textareaCharacters },
    { key: "PILOT_ROLLOUT_NOTES", maximumCharacters: structuredSalesLocalPayloadLimits.textareaCharacters },
    { key: "COMMERCIAL_SLA_WARRANTY_DELIVERY", maximumCharacters: structuredSalesLocalPayloadLimits.textareaCharacters },
  ],
  CONTRACT_REVIEW: [
    { key: "HARDWARE_FEASIBILITY", maximumCharacters: structuredSalesLocalPayloadLimits.textareaCharacters },
    { key: "FIRMWARE_FEASIBILITY", maximumCharacters: structuredSalesLocalPayloadLimits.textareaCharacters },
    { key: "MECHANICAL_FEASIBILITY", maximumCharacters: structuredSalesLocalPayloadLimits.textareaCharacters },
    { key: "COMMERCIAL_EVIDENCE", maximumCharacters: structuredSalesLocalPayloadLimits.textareaCharacters },
    { key: "OWNER_AND_ACTION", maximumCharacters: structuredSalesLocalPayloadLimits.textareaCharacters },
    { key: "LOCAL_DECISION_NOTE", maximumCharacters: structuredSalesLocalPayloadLimits.textareaCharacters },
  ],
  PRS: [
    { key: "POWER_REQUIREMENT", maximumCharacters: structuredSalesLocalPayloadLimits.textareaCharacters },
    { key: "INTERFACE_REQUIREMENT", maximumCharacters: structuredSalesLocalPayloadLimits.textareaCharacters },
    { key: "CONNECTIVITY_REQUIREMENT", maximumCharacters: structuredSalesLocalPayloadLimits.textareaCharacters },
    { key: "MECHANICAL_REQUIREMENT", maximumCharacters: structuredSalesLocalPayloadLimits.textareaCharacters },
    { key: "FIRMWARE_REQUIREMENT", maximumCharacters: structuredSalesLocalPayloadLimits.textareaCharacters },
    { key: "VERIFICATION_METHOD", maximumCharacters: structuredSalesLocalPayloadLimits.textCharacters },
  ],
};

const derivedSourceKeys = new Set([
  "PROJECT_CODE",
  "PROJECT_NAME",
  "PROJECT_REVISION",
  "CUSTOMER_NAME",
  "MASTER_SPECIFICATION",
  "SOURCE_DOCUMENT",
  "REQUIREMENT_SUMMARY",
  "POWER_AND_UNITS",
  "INTERFACES",
  "CONNECTIVITY_AND_GNSS",
  "ENVIRONMENT_AND_IP",
  "VOLUMES",
  "REQUESTED_STANDARDS",
  "WORKSTREAMS",
]);

function isStructuredSalesLocalDocumentKind(value: unknown): value is StructuredSalesLocalDocumentKind {
  return value === "SOR" || value === "CONTRACT_REVIEW" || value === "PRS";
}

function copyPlainDataRecord(input: unknown): Record<string, unknown> | null {
  if (!input || typeof input !== "object" || Array.isArray(input)) return null;

  const prototype = Object.getPrototypeOf(input);
  if (prototype !== Object.prototype && prototype !== null) return null;

  const descriptors = Object.getOwnPropertyDescriptors(input);
  const snapshot = Object.create(null) as Record<string, unknown>;
  for (const [key, descriptor] of Object.entries(descriptors)) {
    if (!("value" in descriptor)) return null;
    if (descriptor.enumerable) snapshot[key] = descriptor.value;
  }

  return snapshot;
}

export function validateStructuredSalesLocalPayload(kind: unknown, input: unknown): StructuredSalesLocalPayloadValidation {
  if (!isStructuredSalesLocalDocumentKind(kind)) {
    return { ok: false, errors: [{ path: "kind", message: "Unsupported structured Sales document kind." }] };
  }

  const payload = copyPlainDataRecord(input);
  if (!payload) return { ok: false, errors: [{ path: "$", message: "Editable payload must be a plain object with data properties." }] };

  const rules = localFieldRules[kind];
  const allowed = new Map(rules.map((rule) => [rule.key, rule]));
  const errors: StructuredSalesLocalPayloadError[] = [];
  let totalCharacters = 0;

  for (const [key, value] of Object.entries(payload)) {
    const rule = allowed.get(key);
    if (!rule) {
      errors.push({ path: key, message: derivedSourceKeys.has(key) ? "Derived source fields cannot be edited in this local payload." : "Unknown editable field." });
      continue;
    }
    if (typeof value !== "string") {
      errors.push({ path: key, message: "Editable values must be strings." });
      continue;
    }
    totalCharacters += value.length;
    if (value.length > rule.maximumCharacters) errors.push({ path: key, message: `Value exceeds the proposed local limit of ${rule.maximumCharacters} characters.` });
  }

  if (totalCharacters > structuredSalesLocalPayloadLimits.totalCharacters) {
    errors.push({ path: "$", message: `Payload exceeds the proposed local limit of ${structuredSalesLocalPayloadLimits.totalCharacters} characters.` });
  }

  return errors.length ? { ok: false, errors } : { ok: true, payload };
}

/** Produces stable JSON without trimming or otherwise changing valid manual text. */
export function canonicalizeStructuredSalesLocalPayload(kind: unknown, input: unknown): string {
  const validated = validateStructuredSalesLocalPayload(kind, input);
  if (!validated.ok) throw new Error(validated.errors.map((error) => `${error.path}: ${error.message}`).join(" "));
  if (!isStructuredSalesLocalDocumentKind(kind)) throw new Error("kind: Unsupported structured Sales document kind.");

  const canonicalPayload = Object.fromEntries(
    [...localFieldRules[kind]]
      .map((rule) => [rule.key, validated.payload[rule.key as keyof StructuredSalesLocalEditablePayload]])
      .filter((entry): entry is [string, string] => typeof entry[1] === "string"),
  );

  return JSON.stringify({ kind, fields: canonicalPayload });
}