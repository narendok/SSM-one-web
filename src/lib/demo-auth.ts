import type { Session, User } from "@supabase/supabase-js";
import { CANONICAL_DEPT_UUIDS } from "@/lib/canonical-departments";
import { setWorkspaceDepartmentId } from "@/lib/workspace-context";

export type Role = "admin" | "member" | "purchase" | "storekeeper" | "project_manager" | "lead_engineer";

export interface DepartmentTestAccount {
  id: string;
  name: string;
  department: string;
  departmentId: string;
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

export const DEPARTMENT_TEST_ACCOUNTS: DepartmentTestAccount[] = [
  {
    id: "admin",
    name: "Vikram Malhotra (Executive Director)",
    department: "Executive Management & Operations",
    departmentId: CANONICAL_DEPT_UUIDS.OPERATIONS,
    category: "Management",
    role: "admin",
    roleLabel: "System Administrator & Lead",
    email: "admin@ssmone.internal",
    password: "Admin@SSMone2026",
    defaultPath: "/command-center",
    badgeColor: "bg-purple-500/15 text-purple-700 dark:text-purple-400 border-purple-500/30",
    permissions: [
      "admin.view",
      "admin.manage",
      "projects.view",
      "projects.manage",
      "engineering.view",
      "engineering.edit",
      "procurement.view",
      "procurement.manage",
      "production.view",
      "production.manage",
      "quality.view",
      "quality.manage",
      "inventory.view",
      "inventory.manage",
      "sales.view",
      "sales.manage",
      "finance.view",
      "finance.manage",
      "hr.view",
      "facility.view",
      "documents.view",
      "documents.edit",
      "my_work.view",
    ],
    description: "Full administrative visibility across all departments, system controls, and enterprise KPIs.",
  },
  {
    id: "rnd",
    name: "Dr. Rajesh Sharma (Hardware & R&D Lead)",
    department: "Hardware & Embedded R&D",
    departmentId: CANONICAL_DEPT_UUIDS.RND,
    category: "Engineering",
    role: "lead_engineer",
    roleLabel: "Hardware R&D Lead",
    email: "rnd@ssmone.internal",
    password: "Hardware@SSMone2026",
    defaultPath: "/dashboards?department=rnd",
    badgeColor: "bg-sky-500/15 text-sky-700 dark:text-sky-400 border-sky-500/30",
    permissions: [
      "engineering.view",
      "engineering.edit",
      "projects.view",
      "projects.manage",
      "inventory.view",
      "documents.view",
      "documents.edit",
      "my_work.view",
      "quality.view",
      "sales.view",
    ],
    description: "Schematic design, PCB layout, Gerber release, DFMEA analysis, and embedded lab inventory.",
  },
  {
    id: "mechanical",
    name: "Arun Kulkarni (Lead Mechanical Engineer)",
    department: "Mechanical Engineering",
    departmentId: CANONICAL_DEPT_UUIDS.MECHANICAL,
    category: "Engineering",
    role: "lead_engineer",
    roleLabel: "Lead Mechanical Engineer",
    email: "mechanical@ssmone.internal",
    password: "Mechanical@SSMone2026",
    defaultPath: "/dashboards?department=mechanical",
    badgeColor: "bg-amber-500/15 text-amber-700 dark:text-amber-400 border-amber-500/30",
    permissions: [
      "engineering.view",
      "engineering.edit",
      "projects.view",
      "projects.manage",
      "documents.view",
      "documents.edit",
      "my_work.view",
      "quality.view",
      "inventory.view",
      "sales.view",
    ],
    description: "3D CAD modeling, enclosure thermal dissipation, IP-rated seals, and tooling DFM reviews.",
  },
  {
    id: "procurement",
    name: "Pooja Deshmukh (SCM Lead)",
    department: "Procurement & SCM",
    departmentId: CANONICAL_DEPT_UUIDS.PROCUREMENT,
    category: "Operations & Supply Chain",
    role: "purchase",
    roleLabel: "Procurement / SCM Lead",
    email: "procurement@ssmone.internal",
    password: "Purchase@SSMone2026",
    defaultPath: "/dashboards?department=procurement",
    badgeColor: "bg-orange-500/15 text-orange-700 dark:text-orange-400 border-orange-500/30",
    permissions: [
      "procurement.view",
      "procurement.manage",
      "stores.view",
      "stores.manage",
      "inventory.view",
      "inventory.manage",
      "documents.view",
      "documents.edit",
      "my_work.view",
      "projects.view",
      "quality.view",
      "engineering.view",
      "sales.view",
    ],
    description: "Purchase requisitions, RFQs, vendor quotations, PO approvals, and supplier management.",
  },
  {
    id: "stores",
    name: "Ganesh Iyer (Stores Custodian)",
    department: "Stores & Inventory",
    departmentId: CANONICAL_DEPT_UUIDS.PROCUREMENT,
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
      "inventory.view",
      "inventory.manage",
      "procurement.view",
      "documents.view",
      "my_work.view",
      "projects.view",
      "sales.view",
    ],
    description: "Bin locations, GRN inwarding, component stock levels, and store audits.",
  },
  {
    id: "quality",
    name: "Ananya Bose (Quality & QMS Manager)",
    department: "Operations / QMS & APQP",
    departmentId: CANONICAL_DEPT_UUIDS.OPERATIONS,
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
      "projects.view",
      "inventory.view",
      "production.view",
      "sales.view",
    ],
    description: "Incoming inspection, Supplier Quality, CAPA, APQP/PPAP validation, and QMS audits.",
  },
  {
    id: "production",
    name: "Manoj Patil (Production Lead)",
    department: "Production & Shop Floor",
    departmentId: CANONICAL_DEPT_UUIDS.PRODUCTION,
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
      "projects.view",
      "inventory.view",
      "sales.view",
    ],
    description: "Shop floor manufacturing batches, tool calibration, assembly steps, and dispatch release.",
  },
  {
    id: "sales",
    name: "Rohit Verma (Commercial & Sales)",
    department: "Sales & Commercial",
    departmentId: CANONICAL_DEPT_UUIDS.SALES,
    category: "Commercial & Finance",
    role: "member",
    roleLabel: "Sales & Commercial Lead",
    email: "sales@ssmone.internal",
    password: "Sales@SSMone2026",
    defaultPath: "/sales/enquiries",
    badgeColor: "bg-indigo-500/15 text-indigo-700 dark:text-indigo-400 border-indigo-500/30",
    permissions: [
      "sales.view",
      "sales.manage",
      "customer_service.view",
      "documents.view",
      "my_work.view",
      "projects.view",
      "inventory.view",
    ],
    description: "Customer enquiries, opportunities, quotations, client CRM, and commercial handover.",
  },
  {
    id: "finance",
    name: "Deepa Nair (Finance Controller)",
    department: "Finance & Accounts",
    departmentId: CANONICAL_DEPT_UUIDS.FINANCE,
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
      "projects.view",
      "procurement.view",
      "inventory.view",
      "sales.view",
    ],
    description: "Operational expenses, PO payment milestones, invoice tracking, and financial records.",
  },
  {
    id: "hr",
    name: "Meera Krishnan (HR Manager)",
    department: "Human Resources",
    departmentId: CANONICAL_DEPT_UUIDS.HR,
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
