import {
  projectOfficialDecisionPayloadLimits,
  validateProjectOfficialDecisionRequestPayload,
  type ProjectOfficialDecisionRequestPayload,
} from "./project-official-decision-payload";

/**
 * Local-only preparation for the proposed server request schema. It never
 * authorizes a request or supplies receipt data. The future protected server
 * action must verify the client-supplied target UUID against the locked source
 * and derive any amendment identity from server-owned records.
 */
export type ProjectOfficialDecisionServerRequest = {
  /** Client-supplied target only; never authorization or server verification. */
  targetProjectBomItemId: string;
  actionIntent: string;
  sourcePageReference: string;
  expectedSourceRevision: string;
  note: string;
  evidenceReferences: ProjectOfficialDecisionRequestPayload["evidenceReferences"];
  alternativeReference: string | null;
  exceptionReference: string | null;
};

function isUuid(value: unknown): value is string {
  return typeof value === "string" && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
}

export function adaptProjectOfficialDecisionPayloadForServer(
  payloadInput: unknown,
  targetProjectBomItemId: unknown,
): ProjectOfficialDecisionServerRequest {
  if (!isUuid(targetProjectBomItemId)) {
    throw new Error("A client-supplied target project BOM item UUID is required and remains server-verification-required.");
  }
  const validated = validateProjectOfficialDecisionRequestPayload(payloadInput);
  if (!validated.ok) throw new Error(validated.errors.map((error) => `${error.path}: ${error.message}`).join(" "));

  const { payload } = validated;
  if (payload.amendment !== null) {
    throw new Error("The local server request adapter rejects amendment links until the server derives and verifies the immutable parent.");
  }

  return {
    targetProjectBomItemId,
    actionIntent: payload.actionIntent,
    sourcePageReference: payload.sourceLocator.pageReference,
    expectedSourceRevision: payload.expectedSourceRevision,
    note: payload.note,
    evidenceReferences: payload.evidenceReferences.map((reference) => ({ ...reference })),
    alternativeReference: payload.alternativeReference,
    exceptionReference: payload.exceptionReference,
  };
}

/** Local comparison only; the server JSONB canonicalizer is the receipt authority. */
export function canonicalizeProjectOfficialDecisionServerRequest(payloadInput: unknown, targetProjectBomItemId: unknown): string {
  const request = adaptProjectOfficialDecisionPayloadForServer(payloadInput, targetProjectBomItemId);
  const evidenceReferences = [...request.evidenceReferences].sort((left, right) => {
    const leftText = JSON.stringify(left);
    const rightText = JSON.stringify(right);
    const length = Math.min(leftText.length, rightText.length);
    for (let index = 0; index < length; index += 1) {
      const difference = leftText.charCodeAt(index) - rightText.charCodeAt(index);
      if (difference !== 0) return difference;
    }
    return leftText.length - rightText.length;
  });
  return JSON.stringify({ ...request, evidenceReferences });
}

export const projectOfficialDecisionServerRequestLimits = projectOfficialDecisionPayloadLimits;