import {
  projectOfficialDecisionPayloadLimits,
  validateProjectOfficialDecisionRequestPayload,
  type ProjectOfficialDecisionRequestPayload,
} from "./project-official-decision-payload";

/**
 * Local-only preparation for the proposed server request schema. It never
 * authorizes a request or supplies receipt data. The future protected server
 * action must derive projectBomItemId and amendmentParentDecisionId after it
 * authorizes and locks the source.
 */
export type ProjectOfficialDecisionServerRequest = {
  actionIntent: string;
  sourcePageReference: string;
  expectedSourceRevision: string;
  note: string;
  evidenceReferences: ProjectOfficialDecisionRequestPayload["evidenceReferences"];
  alternativeReference: string | null;
  exceptionReference: string | null;
};

function failUnsupported(): never {
  throw new Error("The server request accepts only local payload fields; source and amendment identifiers are server-derived.");
}

export function adaptProjectOfficialDecisionPayloadForServer(input: unknown): ProjectOfficialDecisionServerRequest {
  const validated = validateProjectOfficialDecisionRequestPayload(input);
  if (!validated.ok) throw new Error(validated.errors.map((error) => `${error.path}: ${error.message}`).join(" "));

  const { payload } = validated;
  if (payload.amendment !== null) failUnsupported();

  return {
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
export function canonicalizeProjectOfficialDecisionServerRequest(input: unknown): string {
  const request = adaptProjectOfficialDecisionPayloadForServer(input);
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