import { describe, expect, it } from "vitest";
import {
  adaptProjectOfficialDecisionPayloadForServer,
  canonicalizeProjectOfficialDecisionServerRequest,
} from "./project-official-decision-server-request";

const payload = {
  actionIntent: "project-bom-note",
  sourceLocator: { pageReference: "project-bom", itemReference: "item-local-only" },
  expectedSourceRevision: "rev-1",
  note: "  Note keeps spaces, é, and 🚀 exactly.  ",
  evidenceReferences: [{ evidenceReference: "évidence", contributorReference: "Contrib", scopeReference: "project-bom" }],
  amendment: null,
  alternativeReference: null,
  exceptionReference: null,
};

describe("project official decision proposed server request adapter", () => {
  it("maps only supported request fields and preserves manual string bytes", () => {
    expect(adaptProjectOfficialDecisionPayloadForServer(payload)).toEqual({
      actionIntent: "project-bom-note",
      sourcePageReference: "project-bom",
      expectedSourceRevision: "rev-1",
      note: "  Note keeps spaces, é, and 🚀 exactly.  ",
      evidenceReferences: payload.evidenceReferences,
      alternativeReference: null,
      exceptionReference: null,
    });
  });

  it("rejects local amendment links because the server must derive the immutable parent", () => {
    expect(() => adaptProjectOfficialDecisionPayloadForServer({ ...payload, amendment: { priorDecisionReference: "decision-local" } })).toThrow(
      "source and amendment identifiers are server-derived",
    );
  });

  it("keeps local canonical comparisons explicit without asserting a server hash", () => {
    const reordered = {
      ...payload,
      evidenceReferences: [
        { evidenceReference: "!", contributorReference: "A", scopeReference: "scope" },
        { evidenceReference: "𝌆", contributorReference: "É", scopeReference: "scope" },
        ...payload.evidenceReferences,
      ],
    };
    expect(canonicalizeProjectOfficialDecisionServerRequest(reordered)).toBe(
      canonicalizeProjectOfficialDecisionServerRequest({ ...reordered, evidenceReferences: [...reordered.evidenceReferences].reverse() }),
    );
    expect(canonicalizeProjectOfficialDecisionServerRequest(payload)).not.toBe(canonicalizeProjectOfficialDecisionServerRequest({ ...payload, note: "Note keeps spaces, é, and 🚀 exactly." }));
  });
});