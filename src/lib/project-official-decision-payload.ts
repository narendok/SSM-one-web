/**
 * Pure local preparation rules for the review-only project decision-log
 * specification. This module does not establish authorization, committed
 * project scope, actor provenance, revision validity, or receipt replay.
 */
export const projectOfficialDecisionPayloadLimits = {
  referenceCharacters: 512,
  noteCharacters: 512,
  evidenceReferences: 32,
} as const;

export type ProjectOfficialDecisionPayloadError = { path: string; message: string };

export type ProjectOfficialDecisionSourceLocator = {
  pageReference: string;
  itemReference: string;
};

export type ProjectOfficialDecisionEvidenceReference = {
  evidenceReference: string;
  contributorReference: string;
  scopeReference: string;
};

export type ProjectOfficialDecisionAmendmentLink = {
  priorDecisionReference: string;
};

export type ProjectOfficialDecisionRequestPayload = {
  actionIntent: string;
  sourceLocator: ProjectOfficialDecisionSourceLocator;
  expectedSourceRevision: string;
  note: string;
  evidenceReferences: ProjectOfficialDecisionEvidenceReference[];
  amendment: ProjectOfficialDecisionAmendmentLink | null;
  alternativeReference: string | null;
  exceptionReference: string | null;
};

export type ProjectOfficialDecisionPayloadValidation =
  | { ok: true; payload: ProjectOfficialDecisionRequestPayload }
  | { ok: false; errors: ProjectOfficialDecisionPayloadError[] };

function copyPlainDataRecord(input: unknown): Record<string, unknown> | null {
  if (!input || typeof input !== "object" || Array.isArray(input)) return null;
  const prototype = Object.getPrototypeOf(input);
  if (prototype !== Object.prototype && prototype !== null) return null;

  const copy = Object.create(null) as Record<string, unknown>;
  for (const [key, descriptor] of Object.entries(Object.getOwnPropertyDescriptors(input))) {
    if (!("value" in descriptor)) return null;
    if (descriptor.enumerable) copy[key] = descriptor.value;
  }
  return copy;
}

function readOpaqueReference(value: unknown, path: string, errors: ProjectOfficialDecisionPayloadError[]): string | null {
  if (typeof value !== "string" || !value.trim()) {
    errors.push({ path, message: "A non-empty opaque reference is required." });
    return null;
  }
  if (value.length > projectOfficialDecisionPayloadLimits.referenceCharacters) {
    errors.push({ path, message: `Reference exceeds ${projectOfficialDecisionPayloadLimits.referenceCharacters} characters.` });
    return null;
  }
  return value;
}

function readSourceLocator(value: unknown, errors: ProjectOfficialDecisionPayloadError[]): ProjectOfficialDecisionSourceLocator | null {
  const record = copyPlainDataRecord(value);
  if (!record || Object.keys(record).length !== 2 || !("pageReference" in record) || !("itemReference" in record)) {
    errors.push({ path: "sourceLocator", message: "Source locator must contain only pageReference and itemReference data properties." });
    return null;
  }
  const pageReference = readOpaqueReference(record.pageReference, "sourceLocator.pageReference", errors);
  const itemReference = readOpaqueReference(record.itemReference, "sourceLocator.itemReference", errors);
  return pageReference && itemReference ? { pageReference, itemReference } : null;
}

function readEvidenceReferences(value: unknown, errors: ProjectOfficialDecisionPayloadError[]): ProjectOfficialDecisionEvidenceReference[] | null {
  if (value === undefined) return [];
  if (!Array.isArray(value) || value.length > projectOfficialDecisionPayloadLimits.evidenceReferences) {
    errors.push({ path: "evidenceReferences", message: "Evidence references must be an array within the local limit." });
    return null;
  }

  for (let index = 0; index < value.length; index += 1) {
    if (!(index in value)) {
      errors.push({ path: `evidenceReferences[${index}]`, message: "Evidence references must not contain sparse entries." });
    }
  }

  if (errors.length) return null;

  const references: ProjectOfficialDecisionEvidenceReference[] = [];
  value.forEach((entry, index) => {
    const path = `evidenceReferences[${index}]`;
    const record = copyPlainDataRecord(entry);
    if (!record || Object.keys(record).length !== 3 || !("evidenceReference" in record) || !("contributorReference" in record) || !("scopeReference" in record)) {
      errors.push({ path, message: "Evidence reference must contain only evidenceReference, contributorReference, and scopeReference data properties." });
      return;
    }
    const evidenceReference = readOpaqueReference(record.evidenceReference, `${path}.evidenceReference`, errors);
    const contributorReference = readOpaqueReference(record.contributorReference, `${path}.contributorReference`, errors);
    const scopeReference = readOpaqueReference(record.scopeReference, `${path}.scopeReference`, errors);
    if (evidenceReference && contributorReference && scopeReference) references.push({ evidenceReference, contributorReference, scopeReference });
  });
  return references;
}

function compareCodeUnits(left: string, right: string): number {
  const sharedLength = Math.min(left.length, right.length);
  for (let index = 0; index < sharedLength; index += 1) {
    const difference = left.charCodeAt(index) - right.charCodeAt(index);
    if (difference !== 0) return difference;
  }
  return left.length - right.length;
}

function readAmendment(value: unknown, errors: ProjectOfficialDecisionPayloadError[]): ProjectOfficialDecisionAmendmentLink | null {
  if (value === undefined || value === null) return null;
  const record = copyPlainDataRecord(value);
  if (!record || Object.keys(record).length !== 1 || !("priorDecisionReference" in record)) {
    errors.push({ path: "amendment", message: "An amendment link must contain only priorDecisionReference." });
    return null;
  }
  const priorDecisionReference = readOpaqueReference(record.priorDecisionReference, "amendment.priorDecisionReference", errors);
  return priorDecisionReference ? { priorDecisionReference } : null;
}

/** Validates shape only; protected server actions must derive and authorize all scope and actor data. */
export function validateProjectOfficialDecisionRequestPayload(input: unknown): ProjectOfficialDecisionPayloadValidation {
  const record = copyPlainDataRecord(input);
  if (!record) return { ok: false, errors: [{ path: "$", message: "Request payload must be a plain object with data properties." }] };

  const errors: ProjectOfficialDecisionPayloadError[] = [];
  const allowed = new Set(["actionIntent", "sourceLocator", "expectedSourceRevision", "note", "evidenceReferences", "amendment", "alternativeReference", "exceptionReference"]);
  Object.keys(record).filter((key) => !allowed.has(key)).forEach((key) => errors.push({ path: key, message: "Unknown request payload field." }));

  const actionIntent = readOpaqueReference(record.actionIntent, "actionIntent", errors);
  const sourceLocator = readSourceLocator(record.sourceLocator, errors);
  const expectedSourceRevision = readOpaqueReference(record.expectedSourceRevision, "expectedSourceRevision", errors);
  const note = typeof record.note === "string" && record.note.trim() ? record.note : null;
  if (!note) {
    errors.push({ path: "note", message: "A non-empty short human-authored note is required." });
  } else if (note.length > projectOfficialDecisionPayloadLimits.noteCharacters) {
    errors.push({ path: "note", message: `Note exceeds ${projectOfficialDecisionPayloadLimits.noteCharacters} characters.` });
  }
  const evidenceReferences = readEvidenceReferences(record.evidenceReferences, errors);
  const amendment = readAmendment(record.amendment, errors);
  const alternativeReference = record.alternativeReference === undefined || record.alternativeReference === null ? null : readOpaqueReference(record.alternativeReference, "alternativeReference", errors);
  const exceptionReference = record.exceptionReference === undefined || record.exceptionReference === null ? null : readOpaqueReference(record.exceptionReference, "exceptionReference", errors);

  if (errors.length || !actionIntent || !sourceLocator || !expectedSourceRevision || !note || !evidenceReferences) return { ok: false, errors };
  return { ok: true, payload: { actionIntent, sourceLocator, expectedSourceRevision, note, evidenceReferences, amendment, alternativeReference, exceptionReference } };
}

/** Stable pure comparison input for a future server-owned receipt check; it is not a receipt or authorization decision. */
export function canonicalizeProjectOfficialDecisionRequestPayload(input: unknown): string {
  const validated = validateProjectOfficialDecisionRequestPayload(input);
  if (!validated.ok) throw new Error(validated.errors.map((error) => `${error.path}: ${error.message}`).join(" "));
  const { payload } = validated;
  const evidenceReferences = [...payload.evidenceReferences].sort((left, right) => compareCodeUnits(JSON.stringify(left), JSON.stringify(right)));
  return JSON.stringify({
    actionIntent: payload.actionIntent,
    sourceLocator: payload.sourceLocator,
    expectedSourceRevision: payload.expectedSourceRevision,
    note: payload.note,
    amendment: payload.amendment,
    evidenceReferences,
    alternativeReference: payload.alternativeReference,
    exceptionReference: payload.exceptionReference,
  });
}

export function areCanonicalProjectOfficialDecisionRequestPayloadsEqual(left: unknown, right: unknown): boolean {
  return canonicalizeProjectOfficialDecisionRequestPayload(left) === canonicalizeProjectOfficialDecisionRequestPayload(right);
}