import * as XLSX from "xlsx";
import { describe, expect, it } from "vitest";
import { buildSalesCustomerRegister } from "./sales-customer-register";

describe("Sales Customer Register", () => {
  it("keeps stable customer and contact IDs and neutralizes spreadsheet formulas", () => {
    const bytes = buildSalesCustomerRegister([
      { id: "customer-1", customer_code: "CUSTOMER-1", legal_name: "=formula", display_name: null, customer_type: "customer", industry: null, website: null, primary_email: null, primary_phone: null, billing_address: null, shipping_address: null, tax_identifier: null, account_owner_user_id: null, status: "active", notes: null, created_at: "2026-10-13T00:00:00.000Z", updated_at: "2026-10-13T00:00:00.000Z" },
    ], [
      { id: "contact-1", customer_id: "customer-1", full_name: "+unsafe", job_title: null, email: null, phone: null, mobile: null, department: null, is_primary: true, is_active: true, notes: null, created_at: "2026-10-13T00:00:00.000Z", updated_at: "2026-10-13T00:00:00.000Z" },
    ], "2026-10-13T13:59:00.000Z");
    const workbook = XLSX.read(bytes, { type: "array" });
    expect(workbook.SheetNames).toEqual(["Register information", "Customers", "Contacts"]);
    expect(workbook.Sheets.Customers?.A2?.v).toBe("customer-1");
    expect(workbook.Sheets.Customers?.C2?.v).toBe("'=formula");
    expect(workbook.Sheets.Contacts?.A2?.v).toBe("contact-1");
    expect(workbook.Sheets.Contacts?.C2?.v).toBe("'+unsafe");
  });
});