import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

const activation = readFileSync("supabase/migrations/20261017053400_feasibility_provenance_protected_handover_source_only.sql", "utf8");
const transition = readFileSync("supabase/migrations/20261017053401_feasibility_graph_access_transition_review_only.sql", "utf8");

describe("reviewed first feasibility activation bundle", () => {
  it("fails closed for incompatible legacy provenance before replacing uniqueness", () => {
    expect(activation).toContain("partially pinned legacy review rows require repair");
    expect(activation).toContain("duplicate revision/department review pairs require repair");
    expect(activation).toContain("FROM pg_constraint constraint_row");
    expect(activation).toContain("public.next_business_number(text,text,text)");
    expect(activation).toContain("requirement_feasibility_reviews_revision_department_key");
    expect(activation).toContain("UNIQUE (source_revision_id, department_id)");
  });

  it("keeps direct-write restriction outside the first activation migration", () => {
    expect(activation).not.toContain("REVOKE INSERT, UPDATE, DELETE ON TABLE public.customer_requirements");
    expect(activation).not.toContain('DROP POLICY "Sales users manage requirements"');
    expect(transition).toContain("REVOKE INSERT, UPDATE, DELETE ON TABLE public.customer_requirements");
    expect(transition).toContain('DROP POLICY "Sales users manage requirements"');
  });

  it("adds only protected internal graph operations and atomic handover", () => {
    expect(activation).toContain("CREATE OR REPLACE FUNCTION public.assign_requirement_feasibility_review");
    expect(activation).toContain("CREATE OR REPLACE FUNCTION public.record_requirement_feasibility_response");
    expect(activation).toContain("CREATE OR REPLACE FUNCTION public.submit_sales_feasibility_handover");
    expect(activation).not.toContain("submit_external_customer_requirement");
    expect(activation).not.toContain("save_requirement_internal_note");
    expect(activation).not.toContain("approve_sales_requirement_baseline");
  });
});
