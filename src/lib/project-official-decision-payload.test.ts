import { describe, expect, it } from "vitest";
import {
  areCanonicalProjectOfficialDecisionRequestPayloadsEqual,
  canonicalizeProjectOfficialDecisionRequestPayload,
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

  it("rejects missing notes and malformed source locators without treating client input as an authorization decision", () => {
    const result = validateProjectOfficialDecisionRequestPayload({ ...validPayload, note: " \n ", sourceLocator: { pageReference: "project-bom", label: "BOM Item 42" } });
    expect(result).toEqual({
      ok: false,
      errors: [
        { path: "sourceLocator", message: "Source locator must contain only pageReference and itemReference data properties." },
        { path: "note", message: "A non-empty short human-authored note is required." },
      ],
    });
  });

  it("rejects a contributor reference that lacks the required bounded evidence scope", () => {
    const result = validateProjectOfficialDecisionRequestPayload({
      ...validPayload,
      evidenceReferences: [{ evidenceReference: "evidence-7", contributorReference: "contributor-5" }],
    });
    expect(result).toEqual({
      ok: false,
      errors: [{ path: "evidenceReferences[0]", message: "Evidence reference must contain only evidenceReference, contributorReference, and scopeReference data properties." }],
    });
  });

  it("requires an immutable prior decision reference whenever an amendment link is supplied", () => {
    const result = validateProjectOfficialDecisionRequestPayload({ ...validPayload, amendment: {} });
    expect(result).toEqual({ ok: false, errors: [{ path: "amendment", message: "An amendment link must contain only priorDecisionReference." }] });
  });

  it("compares equivalent canonical request payloads despite evidence order, while any note change differs", () => {
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
  });
});