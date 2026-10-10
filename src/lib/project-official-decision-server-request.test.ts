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
const targetOne = "11111111-1111-4111-8111-111111111111";
const targetTwo = "22222222-2222-4222-8222-222222222222";

describe("project official decision proposed server request adapter", () => {
  it("maps only supported request fields and preserves manual string bytes", () => {
    expect(adaptProjectOfficialDecisionPayloadForServer(payload, targetOne)).toEqual({
      targetProjectBomItemId: targetOne,
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
    expect(() => adaptProjectOfficialDecisionPayloadForServer({ ...payload, amendment: { priorDecisionReference: "decision-local" } }, targetOne)).toThrow(
      "server derives and verifies the immutable parent",
    );
  });

  it("rejects unsupported targets and keeps different client-supplied target identities distinct", () => {
    expect(() => adaptProjectOfficialDecisionPayloadForServer(payload, "item-local-only")).toThrow("server-verification-required");
    expect(canonicalizeProjectOfficialDecisionServerRequest(payload, targetOne)).not.toBe(canonicalizeProjectOfficialDecisionServerRequest(payload, targetTwo));
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
    expect(canonicalizeProjectOfficialDecisionServerRequest(reordered, targetOne)).toBe(
      canonicalizeProjectOfficialDecisionServerRequest({ ...reordered, evidenceReferences: [...reordered.evidenceReferences].reverse() }, targetOne),
    );
    expect(canonicalizeProjectOfficialDecisionServerRequest(payload, targetOne)).not.toBe(canonicalizeProjectOfficialDecisionServerRequest({ ...payload, note: "Note keeps spaces, é, and 🚀 exactly." }, targetOne));
  });

  it("uses Unicode code-point limits for astral text in local payload preparation", () => {
    const maxAstralNote = "🚀".repeat(512);
    expect(() => adaptProjectOfficialDecisionPayloadForServer({ ...payload, note: maxAstralNote }, targetOne)).not.toThrow();
    expect(() => adaptProjectOfficialDecisionPayloadForServer({ ...payload, note: `${maxAstralNote}🚀` }, targetOne)).toThrow("Note exceeds 512 characters.");
  });
});