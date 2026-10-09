import { describe, expect, it } from "vitest";
import { canonicalizeStructuredSalesLocalPayload, structuredSalesLocalPayloadLimits, validateStructuredSalesLocalPayload } from "./structured-sales-local-payload";

describe("structured Sales local editable payload contract", () => {
  it("accepts the exact current SOR fields and preserves valid manual text byte-for-byte", () => {
    const payload = {
      SCOPE_STATEMENT: "  Keep this exact manual text.\n\nNo decision is recorded.  ",
      OEM_REQUIREMENT_ROWS: "REQ-1 | CAN telemetry | customer note",
    };

    const validated = validateStructuredSalesLocalPayload("SOR", payload);
    expect(validated).toEqual({ ok: true, payload });
    expect(canonicalizeStructuredSalesLocalPayload("SOR", payload)).toBe('{"kind":"SOR","fields":{"OEM_REQUIREMENT_ROWS":"REQ-1 | CAN telemetry | customer note","SCOPE_STATEMENT":"  Keep this exact manual text.\\n\\nNo decision is recorded.  "}}');
  });

  it("rejects unknown and derived source fields instead of treating them as local edits", () => {
    const result = validateStructuredSalesLocalPayload("CONTRACT_REVIEW", {
      HARDWARE_FEASIBILITY: "Investigate current draw.",
      PROJECT_CODE: "OPPORTUNITY-2026-0013",
      APPROVAL: "approved",
    });

    expect(result).toEqual({
      ok: false,
      errors: [
        { path: "PROJECT_CODE", message: "Derived source fields cannot be edited in this local payload." },
        { path: "APPROVAL", message: "Unknown editable field." },
      ],
    });
  });

  it("rejects malformed payload values and excessive proposed-local sizes", () => {
    const wrongType = validateStructuredSalesLocalPayload("PRS", { POWER_REQUIREMENT: 24 });
    expect(wrongType).toEqual({ ok: false, errors: [{ path: "POWER_REQUIREMENT", message: "Editable values must be strings." }] });

    const excessive = validateStructuredSalesLocalPayload("PRS", { VERIFICATION_METHOD: "x".repeat(structuredSalesLocalPayloadLimits.textCharacters + 1) });
    expect(excessive).toEqual({ ok: false, errors: [{ path: "VERIFICATION_METHOD", message: "Value exceeds the proposed local limit of 1000 characters." }] });
  });

  it("canonicalizes equivalent PRS payload key order deterministically without changing text", () => {
    const first = {
      VERIFICATION_METHOD: "Bench test; preserve punctuation: <>&",
      POWER_REQUIREMENT: "24 V nominal",
    };
    const second = {
      POWER_REQUIREMENT: "24 V nominal",
      VERIFICATION_METHOD: "Bench test; preserve punctuation: <>&",
    };

    expect(canonicalizeStructuredSalesLocalPayload("PRS", first)).toBe(canonicalizeStructuredSalesLocalPayload("PRS", second));
  });

  it("rejects inherited allowed fields before canonicalization can read them", () => {
    const inheritedPayload = Object.create({ SCOPE_STATEMENT: "x".repeat(structuredSalesLocalPayloadLimits.textareaCharacters + 1) });

    expect(validateStructuredSalesLocalPayload("SOR", inheritedPayload)).toEqual({
      ok: false,
      errors: [{ path: "$", message: "Editable payload must be a plain object with data properties." }],
    });
    expect(() => canonicalizeStructuredSalesLocalPayload("SOR", inheritedPayload)).toThrow("Editable payload must be a plain object with data properties.");
  });

  it("rejects Date, class instances, and accessor-backed records without invoking accessors", () => {
    class LocalPayload {
      SCOPE_STATEMENT = "manual";
    }
    const accessorPayload = {};
    Object.defineProperty(accessorPayload, "SCOPE_STATEMENT", {
      enumerable: true,
      get: () => {
        throw new Error("Accessor must not run.");
      },
    });

    for (const payload of [new Date(), new LocalPayload(), accessorPayload]) {
      expect(validateStructuredSalesLocalPayload("SOR", payload)).toEqual({
        ok: false,
        errors: [{ path: "$", message: "Editable payload must be a plain object with data properties." }],
      });
    }
  });

  it("accepts null-prototype records and preserves exact own text through canonicalization", () => {
    const payload = Object.create(null) as Record<string, unknown>;
    payload.SCOPE_STATEMENT = "  Exact own text\nwith spacing.  ";

    expect(validateStructuredSalesLocalPayload("SOR", payload)).toEqual({
      ok: true,
      payload: { SCOPE_STATEMENT: "  Exact own text\nwith spacing.  " },
    });
    expect(canonicalizeStructuredSalesLocalPayload("SOR", payload)).toBe('{"kind":"SOR","fields":{"SCOPE_STATEMENT":"  Exact own text\\nwith spacing.  "}}');
  });

  it("returns a controlled validation error for runtime-invalid document kinds", () => {
    expect(validateStructuredSalesLocalPayload("UNSUPPORTED", { SCOPE_STATEMENT: "manual" })).toEqual({
      ok: false,
      errors: [{ path: "kind", message: "Unsupported structured Sales document kind." }],
    });
    expect(() => canonicalizeStructuredSalesLocalPayload("UNSUPPORTED", {})).toThrow("Unsupported structured Sales document kind.");
  });
});