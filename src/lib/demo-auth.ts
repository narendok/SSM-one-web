import type { Session, User } from "@supabase/supabase-js";
import { setWorkspaceDepartmentId } from "./workspace-context";

export type Role = "admin" | "member" | "purchase" | "storekeeper" | "project_manager" | "lead_engineer";

export interface DepartmentTestAccount {
  id: string;
  name: string;
  department: string;
  departmentId: string | null;
  category: "Management" | "Engineering" | "Operations & Supply Chain" | "Commercial & Finance" | "HR & People";
  role: Role;
  roleLabel: string;
  email: string;
  password: string;
  defaultPath: string;
  badgeColor: string;
  permissions: string[];
  description: string;
}

export const ALL_SYSTEM_PERMISSIONS = [
  "projects.view",
  "projects.manage",
  "my_work.view",
  "documents.view",
  "documents.edit",
  "engineering.view",
  "engineering.edit",
  "engineering.manage",
  "procurement.view",
  "procurement.manage",
  "stores.view",
  "stores.manage",
  "quality.view",
  "quality.manage",
  "production.view",
  "production.manage",
  "calibration.view",
  "facility.view",
  "assets.view",
  "maintenance.view",
  "security.view",
  "workplace.view",
  "qms.view",
  "sales.view",
  "sales.manage",
  "finance.view",
  "finance.manage",
  "customer_service.view",
  "external_collaboration.view",
  "hr.view",
  "admin.view",
  "recruitment.manage",
  "training.manage",
];

export const DEPARTMENT_TEST_ACCOUNTS: DepartmentTestAccount[] = [
  {
    id: "admin",
    name: "Platform Owner (Executive Admin)",
    department: "Executive & System Management",
    departmentId: null,
    category: "Management",
    role: "admin",
    roleLabel: "Platform Owner / Admin",
    email: "admin@ssmone.internal",
    password: "Admin@SSMone2026",
    defaultPath: "/projects?tab=analysis",
    badgeColor: "bg-red-500/15 text-red-700 dark:text-red-400 border-red-500/30",
    permissions: ALL_SYSTEM_PERMISSIONS,
    description: "Complete unrestricted access across all departments, project analysis, system controls, and settings.",
  },
  {
    id: "hardware",
    name: "Dr. Vikram Seth (Hardware Lead)",
    department: "Hardware & Embedded R&D",
    departmentId: "dept-rnd",
    category: "Engineering",
    role: "lead_engineer",
    roleLabel: "Hardware Lead Engineer",
    email: "hardware.lead@ssmone.internal",
    password: "Hardware@SSMone2026",
    defaultPath: "/",
    badgeColor: "bg-sky-500/15 text-sky-700 dark:text-sky-400 border-sky-500/30",
    permissions: [
      "projects.view",
      "projects.manage",
      "my_work.view",
      "engineering.view",
      "engineering.edit",
      "engineering.manage",
      "documents.view",
      "documents.edit",
    ],
    description: "Hardware schematic design, BOM sourcing, PCB repair, and engineering assignments.",
  },
  {
    id: "firmware",
    name: "Sneha Rao (Firmware Lead)",
    department: "Firmware & Software",
    departmentId: "dept-firmware",
    category: "Engineering",
    role: "lead_engineer",
    roleLabel: "Firmware Lead Engineer",
    email: "firmware.lead@ssmone.internal",
    password: "Firmware@SSMone2026",
    defaultPath: "/",
    badgeColor: "bg-violet-500/15 text-violet-700 dark:text-violet-400 border-violet-500/30",
    permissions: [
      "projects.view",
      "projects.manage",
      "my_work.view",
      "engineering.view",
      "engineering.edit",
      "documents.view",
      "documents.edit",
    ],
    description: "Firmware revisions, telematics protocols, bootloaders, and project task management.",
  },
  {
    id: "mechanical",
    name: "Karthik Menon (Mechanical Lead)",
    department: "Mechanical Engineering",
    departmentId: "dept-mechanical",
    category: "Engineering",
    role: "lead_engineer",
    roleLabel: "Mechanical Lead Engineer",
    email: "mech.lead@ssmone.internal",
    password: "Mechanical@SSMone2026",
    defaultPath: "/",
    badgeColor: "bg-amber-500/15 text-amber-700 dark:text-amber-400 border-amber-500/30",
    permissions: [
      "projects.view",
      "projects.manage",
      "my_work.view",
      "engineering.view",
      "engineering.edit",
      "documents.view",
      "documents.edit",
    ],
    description: "Enclosure CAD models, thermal dissipation, mechanical drawings, and BOM components.",
  },
  {
    id: "purchase",
    name: "Priya Sharma (Procurement Head)",
    department: "Procurement & SCM",
    departmentId: "dept-procurement",
    category: "Operations & Supply Chain",
    role: "purchase",
    roleLabel: "Procurement Head",
    email: "purchase@ssmone.internal",
    password: "Purchase@SSMone2026",
    defaultPath: "/procurement/requests",
    badgeColor: "bg-orange-500/15 text-orange-700 dark:text-orange-400 border-orange-500/30",
    permissions: [
      "procurement.view",
      "procurement.manage",
      "stores.view",
      "documents.view",
      "my_work.view",
      "projects.view",
      "quality.view",
    ],
    description: "Purchase requisitions, RFQs, vendor quotations, PO approvals, and supplier management.",
  },
  {
    id: "stores",
    name: "Ganesh Iyer (Stores Custodian)",
    department: "Stores & Inventory",
    departmentId: "dept-procurement",
    category: "Operations & Supply Chain",
    role: "storekeeper",
    roleLabel: "Stores Custodian",
    email: "stores@ssmone.internal",
    password: "Stores@SSMone2026",
    defaultPath: "/stores/inventory",
    badgeColor: "bg-emerald-500/15 text-emerald-700 dark:text-emerald-400 border-emerald-500/30",
    permissions: [
      "stores.view",
      "stores.manage",
      "procurement.view",
      "documents.view",
      "my_work.view",
    ],
    description: "Bin locations, GRN inwarding, component stock levels, and store audits.",
  },
  {
    id: "quality",
    name: "Ananya Bose (Quality & QMS Manager)",
    department: "Operations / QMS & APQP",
    departmentId: "dept-operations",
    category: "Operations & Supply Chain",
    role: "member",
    roleLabel: "Quality & QMS Manager",
    email: "quality@ssmone.internal",
    password: "Quality@SSMone2026",
    defaultPath: "/quality/incoming",
    badgeColor: "bg-rose-500/15 text-rose-700 dark:text-rose-400 border-rose-500/30",
    permissions: [
      "quality.view",
      "quality.manage",
      "qms.view",
      "customer_service.view",
      "procurement.view",
      "documents.view",
      "my_work.view",
    ],
    description: "Incoming inspection, Supplier Quality, CAPA, APQP/PPAP validation, and QMS audits.",
  },
  {
    id: "production",
    name: "Manoj Patil (Production Lead)",
    department: "Production & Shop Floor",
    departmentId: "dept-production",
    category: "Operations & Supply Chain",
    role: "member",
    roleLabel: "Production Lead",
    email: "production@ssmone.internal",
    password: "Production@SSMone2026",
    defaultPath: "/production",
    badgeColor: "bg-teal-500/15 text-teal-700 dark:text-teal-400 border-teal-500/30",
    permissions: [
      "production.view",
      "production.manage",
      "calibration.view",
      "documents.view",
      "my_work.view",
    ],
    description: "Shop floor manufacturing batches, tool calibration, assembly steps, and dispatch release.",
  },
  {
    id: "sales",
    name: "Rohit Verma (Commercial & Sales)",
    department: "Sales & Commercial",
    departmentId: "dept-sales",
    category: "Commercial & Finance",
    role: "member",
    roleLabel: "Sales & Commercial Lead",
    email: "sales@ssmone.internal",
    password: "Sales@SSMone2026",
    defaultPath: "/sales",
    badgeColor: "bg-indigo-500/15 text-indigo-700 dark:text-indigo-400 border-indigo-500/30",
    permissions: [
      "sales.view",
      "sales.manage",
      "customer_service.view",
      "documents.view",
      "my_work.view",
      "projects.view",
    ],
    description: "Customer enquiries, opportunities, quotations, client CRM, and commercial handover.",
  },
  {
    id: "finance",
    name: "Deepa Nair (Finance Controller)",
    department: "Finance & Accounts",
    departmentId: "dept-finance",
    category: "Commercial & Finance",
    role: "member",
    roleLabel: "Finance Controller",
    email: "finance@ssmone.internal",
    password: "Finance@SSMone2026",
    defaultPath: "/finance/expenses",
    badgeColor: "bg-lime-500/15 text-lime-700 dark:text-lime-400 border-lime-500/30",
    permissions: [
      "finance.view",
      "finance.manage",
      "documents.view",
      "my_work.view",
      "procurement.view",
    ],
    description: "Operational expenses, PO payment milestones, invoice tracking, and financial records.",
  },
  {
    id: "hr",
    name: "Meera Krishnan (HR Manager)",
    department: "Human Resources",
    departmentId: "dept-hr",
    category: "HR & People",
    role: "member",
    roleLabel: "HR & Talent Manager",
    email: "hr@ssmone.internal",
    password: "HR@SSMone2026",
    defaultPath: "/hr",
    badgeColor: "bg-purple-500/15 text-purple-700 dark:text-purple-400 border-purple-500/30",
    permissions: [
      "hr.view",
      "admin.view",
      "recruitment.manage",
      "training.manage",
      "documents.view",
      "my_work.view",
    ],
    description: "Employee registry, onboarding, leave desk, hiring pipelines, and corporate training.",
  },
];

export const DEMO_AUTH_STORAGE_KEY = "ssm-one-demo-auth-session";
export const DEMO_AUTH_CHANGE_EVENT = "ssm-one-demo-auth-change";

export interface StoredDemoSession {
  account: DepartmentTestAccount;
  user: User;
  session: Session;
  role: Role;
  displayName: string;
  permissions: string[];
}

export function getStoredTestSession(): StoredDemoSession | null {
  if (typeof window === "undefined") return null;
  try {
    const raw = window.localStorage.getItem(DEMO_AUTH_STORAGE_KEY);
    if (!raw) return null;
    return JSON.parse(raw) as StoredDemoSession;
  } catch (e) {
    console.error("Failed to parse stored test session", e);
    return null;
  }
}

export function setStoredTestSession(account: DepartmentTestAccount): StoredDemoSession {
  const fakeUserId = `user-${account.id}`;
  const mockUser: User = {
    id: fakeUserId,
    app_metadata: { provider: "email" },
    user_metadata: {
      display_name: account.name,
      department: account.department,
      role: account.role,
      roleLabel: account.roleLabel,
    },
    aud: "authenticated",
    email: account.email,
    created_at: new Date().toISOString(),
    confirmed_at: new Date().toISOString(),
    last_sign_in_at: new Date().toISOString(),
    role: "authenticated",
    updated_at: new Date().toISOString(),
  };

  const mockSession: Session = {
    access_token: `demo-token-${account.id}`,
    token_type: "bearer",
    expires_in: 86400,
    expires_at: Math.floor(Date.now() / 1000) + 86400,
    refresh_token: `demo-refresh-${account.id}`,
    user: mockUser,
  };

  const stored: StoredDemoSession = {
    account,
    user: mockUser,
    session: mockSession,
    role: account.role,
    displayName: account.name,
    permissions: account.permissions,
  };

  if (typeof window !== "undefined") {
    window.localStorage.setItem(DEMO_AUTH_STORAGE_KEY, JSON.stringify(stored));
    setWorkspaceDepartmentId(account.departmentId);
    window.dispatchEvent(new CustomEvent(DEMO_AUTH_CHANGE_EVENT, { detail: stored }));
  }

  return stored;
}

export function clearStoredTestSession() {
  if (typeof window === "undefined") return;
  window.localStorage.removeItem(DEMO_AUTH_STORAGE_KEY);
  setWorkspaceDepartmentId(null);
  window.dispatchEvent(new CustomEvent(DEMO_AUTH_CHANGE_EVENT, { detail: null }));
}

export function findTestAccountByEmail(email: string): DepartmentTestAccount | undefined {
  const clean = email.trim().toLowerCase();
  return DEPARTMENT_TEST_ACCOUNTS.find((acc) => acc.email.toLowerCase() === clean);
}

export function verifyTestCredentials(email: string, password: string): DepartmentTestAccount | null {
  const account = findTestAccountByEmail(email);
  if (!account) return null;
  if (account.password === password.trim()) return account;
  return null;
}

export function loginAsTestAccount(account: DepartmentTestAccount): StoredDemoSession {
  return setStoredTestSession(account);
}
