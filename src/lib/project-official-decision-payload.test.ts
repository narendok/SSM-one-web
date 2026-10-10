import { describe, expect, it } from "vitest";
import {
  areCanonicalProjectOfficialDecisionRequestPayloadsEqual,
  canonicalizeProjectOfficialDecisionRequestPayload,
  projectOfficialDecisionPayloadLimits,
  validateProjectOfficialDecisionRequestPayload,
} from "./project-official-decision-payload";

const validPayload = {
  actionIntent: "hardware-approve",
  sourceLocator: { pageReference: "project-bom", itemReference: "bom-item-42" },
  expectedSourceRevision: "candidate-revision-3",
  note: "  Confirmed after bench review.  ",
  evidenceReferences: [{ evidenceReference: "evidence-7", contributorReference: "contributor-5", scopeReference: "project-42" }],
  amendment: { priorDecisionReference: "decision-1" },
  alternativeReference: null,
  exceptionReference: null,
};

describe("project official decision local payload contract", () => {
  it("preserves a short manual note and validates source, evidence, and amendment reference shapes", () => {
    expect(validateProjectOfficialDecisionRequestPayload(validPayload)).toEqual({ ok: true, payload: validPayload });
  });

  it("rejects missing and oversized notes plus malformed source locators without treating client input as authorization", () => {
    const result = validateProjectOfficialDecisionRequestPayload({ ...validPayload, note: " \n ", sourceLocator: { pageReference: "project-bom", label: "BOM Item 42" } });
    expect(result).toEqual({
      ok: false,
      errors: [
        { path: "sourceLocator", message: "Source locator must contain only pageReference and itemReference data properties." },
        { path: "note", message: "A non-empty short human-authored note is required." },
      ],
    });
    expect(validateProjectOfficialDecisionRequestPayload({ ...validPayload, note: "n".repeat(projectOfficialDecisionPayloadLimits.noteCharacters) })).toEqual({
      ok: true,
      payload: { ...validPayload, note: "n".repeat(projectOfficialDecisionPayloadLimits.noteCharacters) },
    });
    expect(validateProjectOfficialDecisionRequestPayload({ ...validPayload, note: "n".repeat(projectOfficialDecisionPayloadLimits.noteCharacters + 1) })).toEqual({
      ok: false,
      errors: [{ path: "note", message: `Note exceeds ${projectOfficialDecisionPayloadLimits.noteCharacters} characters.` }],
    });
  });

  it("rejects unknown nested source, evidence, and amendment fields", () => {
    const result = validateProjectOfficialDecisionRequestPayload({
      ...validPayload,
      sourceLocator: { ...validPayload.sourceLocator, injected: "ignored" },
      evidenceReferences: [{ ...validPayload.evidenceReferences[0], injected: "ignored" }],
      amendment: { ...validPayload.amendment, injected: "ignored" },
    });
    expect(result).toEqual({
      ok: false,
      errors: [
        { path: "sourceLocator", message: "Source locator must contain only pageReference and itemReference data properties." },
        { path: "evidenceReferences[0]", message: "Evidence reference must contain only evidenceReference, contributorReference, and scopeReference data properties." },
        { path: "amendment", message: "An amendment link must contain only priorDecisionReference." },
      ],
    });
  });

  it("requires an immutable prior decision reference whenever an amendment link is supplied", () => {
    const result = validateProjectOfficialDecisionRequestPayload({ ...validPayload, amendment: {} });
    expect(result).toEqual({ ok: false, errors: [{ path: "amendment", message: "An amendment link must contain only priorDecisionReference." }] });
  });

  it("compares evidence order canonically while preserving every source, amendment, contributor, and evidence field", () => {
    const reordered = {
      ...validPayload,
      evidenceReferences: [
        { evidenceReference: "evidence-8", contributorReference: "contributor-6", scopeReference: "project-42" },
        ...validPayload.evidenceReferences,
      ],
    };
    const sameReferencesDifferentOrder = { ...reordered, evidenceReferences: [...reordered.evidenceReferences].reverse() };

    expect(canonicalizeProjectOfficialDecisionRequestPayload(reordered)).toBe(canonicalizeProjectOfficialDecisionRequestPayload(sameReferencesDifferentOrder));
    expect(areCanonicalProjectOfficialDecisionRequestPayloadsEqual(reordered, sameReferencesDifferentOrder)).toBe(true);
    expect(areCanonicalProjectOfficialDecisionRequestPayloadsEqual(validPayload, { ...validPayload, note: "Changed note." })).toBe(false);
    expect(areCanonicalProjectOfficialDecisionRequestPayloadsEqual(validPayload, { ...validPayload, sourceLocator: { ...validPayload.sourceLocator, pageReference: "project-delivery" } })).toBe(false);
    expect(areCanonicalProjectOfficialDecisionRequestPayloadsEqual(validPayload, { ...validPayload, sourceLocator: { ...validPayload.sourceLocator, itemReference: "bom-item-43" } })).toBe(false);
    expect(areCanonicalProjectOfficialDecisionRequestPayloadsEqual(validPayload, { ...validPayload, amendment: { priorDecisionReference: "decision-2" } })).toBe(false);
    expect(areCanonicalProjectOfficialDecisionRequestPayloadsEqual(validPayload, { ...validPayload, evidenceReferences: [{ ...validPayload.evidenceReferences[0], evidenceReference: "evidence-8" }] })).toBe(false);
    expect(areCanonicalProjectOfficialDecisionRequestPayloadsEqual(validPayload, { ...validPayload, evidenceReferences: [{ ...validPayload.evidenceReferences[0], contributorReference: "contributor-6" }] })).toBe(false);
    expect(areCanonicalProjectOfficialDecisionRequestPayloadsEqual(validPayload, { ...validPayload, evidenceReferences: [{ ...validPayload.evidenceReferences[0], scopeReference: "project-43" }] })).toBe(false);
  });

  it("throws rather than silently canonicalizing payloads with unknown meaningful fields", () => {
    expect(() => canonicalizeProjectOfficialDecisionRequestPayload({ ...validPayload, sourceLocator: { ...validPayload.sourceLocator, injected: "ignored" } })).toThrow(
      "sourceLocator: Source locator must contain only pageReference and itemReference data properties.",
    );
  });
});