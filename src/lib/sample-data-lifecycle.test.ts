import { describe, expect, it } from "vitest";
import {
  SAMPLE_OEM_CUSTOMERS,
  SAMPLE_CONTACTS,
  SAMPLE_ENQUIRIES,
  SAMPLE_OPPORTUNITIES,
  SAMPLE_LIFECYCLE_PROJECTS,
  SAMPLE_REGULATORY_REPORTS,
} from "./sample-data-lifecycle";
import { fetchProjects, getSampleProjectById } from "./projects";
import { fetchSalesOverview } from "./sales";

describe("Sample Lifecycle & OEM Dataset", () => {
  it("defines exactly 10 OEM automotive customers", () => {
    expect(SAMPLE_OEM_CUSTOMERS).toHaveLength(10);
    const codes = SAMPLE_OEM_CUSTOMERS.map((c) => c.customer_code);
    expect(codes).toContain("CUST-TATA-CV");
    expect(codes).toContain("CUST-MM-AUTO");
    expect(codes).toContain("CUST-BBENZ");
    expect(codes).toContain("CUST-OLA-FLT");
    expect(codes).toContain("CUST-ASHOK-LEY");
    expect(codes).toContain("CUST-ATHER");
    expect(codes).toContain("CUST-TVS");
    expect(codes).toContain("CUST-MS-COMM");
    expect(codes).toContain("CUST-SWITCH-MOB");
    expect(codes).toContain("CUST-PINNACLE");
  });

  it("defines customer contacts with correct hierarchy", () => {
    // Tata Motors CV has 5 contacts
    const tataContacts = SAMPLE_CONTACTS.filter((c) => c.customer_id === "cust-tata-cv");
    expect(tataContacts).toHaveLength(5);
    expect(tataContacts.some((c) => c.full_name === "Rajesh Nambiar" && c.is_primary)).toBe(true);

    // Mahindra & Mahindra Auto has 4 contacts
    const mmContacts = SAMPLE_CONTACTS.filter((c) => c.customer_id === "cust-mm-auto");
    expect(mmContacts).toHaveLength(4);
    expect(mmContacts.some((c) => c.full_name === "Dr. Vikramaditya Patil" && c.is_primary)).toBe(true);

    // BharatBenz has 3 contacts
    const benzContacts = SAMPLE_CONTACTS.filter((c) => c.customer_id === "cust-bbenz");
    expect(benzContacts).toHaveLength(3);

    // Total contacts
    expect(SAMPLE_CONTACTS.length).toBeGreaterThanOrEqual(20);
  });

  it("defines Telematics Journey 1 (Tata Direct Reuse) and Journey 2 (Mahindra BLE Modification)", () => {
    const j1 = SAMPLE_LIFECYCLE_PROJECTS.find((p) => p.code === "PRJ-TLM-001");
    expect(j1).toBeDefined();
    expect(j1?.name).toContain("Tata Motors");
    expect(j1?.revision).toBe("2.0");
    expect(j1?.project_stage).toBe("pilot_manufacturing");
    expect(j1?.completion_notes).toContain("Direct Reuse");

    const j2 = SAMPLE_LIFECYCLE_PROJECTS.find((p) => p.code === "PRJ-TLM-002");
    expect(j2).toBeDefined();
    expect(j2?.name).toContain("Mahindra");
    expect(j2?.revision).toBe("2.1-BLE");
    expect(j2?.project_stage).toBe("validation_and_testing");
    expect(j2?.completion_notes).toContain("BLE 5.2");
  });

  it("includes regulatory test reports for AIS-140 and NABL battery certification", () => {
    const icatReport = SAMPLE_REGULATORY_REPORTS.find((r) => r.reportNumber === "iCAT/AIS140/2026/0892");
    expect(icatReport).toBeDefined();
    expect(icatReport?.agency).toBe("iCAT");
    expect(icatReport?.status).toBe("certified");

    const nablReport = SAMPLE_REGULATORY_REPORTS.find((r) => r.reportNumber === "NABL/BAT/2026/4412");
    expect(nablReport).toBeDefined();
    expect(nablReport?.agency).toBe("NABL");
    expect(nablReport?.status).toBe("certified");
  });

  it("retrieves project by ID or code via getSampleProjectById", () => {
    expect(getSampleProjectById("prj-tlm-001")?.code).toBe("PRJ-TLM-001");
    expect(getSampleProjectById("PRJ-TLM-002")?.id).toBe("prj-tlm-002");
    expect(getSampleProjectById("non-existent")).toBeUndefined();
  });

  it("merges sample projects into fetchProjects", async () => {
    const projects = await fetchProjects();
    expect(projects.some((p) => p.code === "PRJ-TLM-001")).toBe(true);
    expect(projects.some((p) => p.code === "PRJ-TLM-002")).toBe(true);
  });

  it("merges 10 OEM customers into fetchSalesOverview", async () => {
    const sales = await fetchSalesOverview();
    expect(sales.customers.length).toBeGreaterThanOrEqual(10);
    expect(sales.customers.some((c) => c.customer_code === "CUST-TATA-CV")).toBe(true);
    expect(sales.customers.some((c) => c.customer_code === "CUST-MM-AUTO")).toBe(true);
    expect(sales.contacts.length).toBeGreaterThanOrEqual(20);
    expect(sales.opportunities.length).toBeGreaterThanOrEqual(8);
  });
});
