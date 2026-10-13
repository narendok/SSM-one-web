import * as XLSX from "xlsx";

export type CustomerRegisterCustomer = {
  id: string;
  customer_code: string;
  legal_name: string;
  display_name: string | null;
  customer_type: string;
  industry: string | null;
  website: string | null;
  primary_email: string | null;
  primary_phone: string | null;
  billing_address: string | null;
  shipping_address: string | null;
  tax_identifier: string | null;
  account_owner_user_id: string | null;
  status: string;
  notes: string | null;
  created_at: string;
  updated_at: string;
};

export type CustomerRegisterContact = {
  id: string;
  customer_id: string;
  full_name: string;
  job_title: string | null;
  email: string | null;
  phone: string | null;
  mobile: string | null;
  department: string | null;
  is_primary: boolean;
  is_active: boolean;
  notes: string | null;
  created_at: string;
  updated_at: string;
};

function safeCell(value: unknown): string | number | boolean {
  if (typeof value === "number" || typeof value === "boolean") return value;
  const text = String(value ?? "");
  return /^[=+\-@]/.test(text) ? `'${text}` : text;
}

function iso(value: string) {
  return value ? new Date(value).toISOString() : "";
}

function sheet(rows: Record<string, unknown>[], name: string) {
  const normalized = rows.map((row) => Object.fromEntries(Object.entries(row).map(([key, value]) => [key, safeCell(value)])));
  const worksheet = XLSX.utils.json_to_sheet(normalized);
  const headers = Object.keys(normalized[0] ?? {});
  worksheet["!freeze"] = { xSplit: 0, ySplit: 1 } as any;
  worksheet["!cols"] = headers.map((header) => ({
    wch: Math.min(52, Math.max(header.length + 2, ...normalized.map((row) => String(row[header] ?? "").length + 2))),
  }));
  const workbook = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(workbook, worksheet, name);
  return workbook;
}

export function buildSalesCustomerRegister(customers: CustomerRegisterCustomer[], contacts: CustomerRegisterContact[], generatedAt = new Date().toISOString()): Uint8Array {
  const customerRows = customers.map((customer) => ({
    "Customer ID": customer.id,
    "Customer code": customer.customer_code,
    "Legal name": customer.legal_name,
    "Trading name": customer.display_name,
    Type: customer.customer_type,
    Industry: customer.industry,
    Website: customer.website,
    "Primary email": customer.primary_email,
    "Primary phone": customer.primary_phone,
    "Billing address": customer.billing_address,
    "Shipping address": customer.shipping_address,
    "Tax identifier": customer.tax_identifier,
    "Account owner user ID": customer.account_owner_user_id,
    Status: customer.status,
    Notes: customer.notes,
    "Created at": iso(customer.created_at),
    "Updated at": iso(customer.updated_at),
  }));
  const contactRows = contacts.map((contact) => ({
    "Contact ID": contact.id,
    "Customer ID": contact.customer_id,
    "Full name": contact.full_name,
    "Job title": contact.job_title,
    Email: contact.email,
    Phone: contact.phone,
    Mobile: contact.mobile,
    Department: contact.department,
    "Primary contact": contact.is_primary,
    Active: contact.is_active,
    Notes: contact.notes,
    "Created at": iso(contact.created_at),
    "Updated at": iso(contact.updated_at),
  }));
  const workbook = sheet([
    { Field: "Workbook", Value: "Sales Customer Register" },
    { Field: "Source", Value: "Authoritative customer and contact records" },
    { Field: "Generated at", Value: iso(generatedAt) },
    { Field: "Customer count", Value: customers.length },
    { Field: "Contact count", Value: contacts.length },
    { Field: "Direction", Value: "One-way from SSM One; spreadsheet edits are not imported" },
  ], "Register information");
  XLSX.utils.book_append_sheet(workbook, XLSX.utils.json_to_sheet(customerRows.map((row) => Object.fromEntries(Object.entries(row).map(([key, value]) => [key, safeCell(value)])))), "Customers");
  XLSX.utils.book_append_sheet(workbook, XLSX.utils.json_to_sheet(contactRows.map((row) => Object.fromEntries(Object.entries(row).map(([key, value]) => [key, safeCell(value)])))), "Contacts");
  for (const name of ["Customers", "Contacts"]) {
    const worksheet = workbook.Sheets[name];
    const headers = XLSX.utils.sheet_to_json<Record<string, unknown>>(worksheet, { header: 1 })[0] as string[] | undefined;
    if (headers) {
      worksheet["!freeze"] = { xSplit: 0, ySplit: 1 } as any;
      worksheet["!cols"] = headers.map((header) => ({ wch: Math.min(52, Math.max(String(header).length + 2, 14)) }));
    }
  }
  return XLSX.write(workbook, { bookType: "xlsx", type: "array" }) as Uint8Array;
}