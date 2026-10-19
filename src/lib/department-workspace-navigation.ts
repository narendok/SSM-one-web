import type { LucideIcon } from "lucide-react";
import {
  BadgeDollarSign, Boxes, BriefcaseBusiness, Building2, ClipboardCheck, ClipboardList,
  FileSearch, FileSpreadsheet, FileText, FolderKanban, Gauge, GraduationCap, Handshake, HardHat,
  PackageCheck, PlaneTakeoff, ReceiptText, Search, Send, ShieldCheck, ShoppingCart,
  Truck, Users, WalletCards, Wrench, LayoutDashboard,
} from "lucide-react";
import { CANONICAL_DEPT_UUIDS } from "./canonical-departments";

export type WorkspaceKind = "rnd" | "mechanical" | "procurement" | "production" | "facility" | "operations" | "hr" | "sales" | "finance";
export type WorkspaceNavItem = { label: string; to: string; icon: LucideIcon; permission?: string };

export type WorkspaceDefinition = {
  id: WorkspaceKind;
  terms: string[];
  label: string;
  summary: string;
  items: WorkspaceNavItem[];
};

export const workspaceDefinitions: WorkspaceDefinition[] = [
  { id: "rnd", terms: ["rnd", "hardware & r&d", "hardware", "firmware"], label: "Hardware & R&D", summary: "Requirements, engineering disciplines, validation, and release evidence.", items: [
    { label: "Hardware workspace", to: "/dashboards?department=rnd", icon: LayoutDashboard, permission: "engineering.view" },
    { label: "Project tracker", to: "/workspace/projects", icon: FolderKanban, permission: "projects.view" },
    { label: "Electronic inventory", to: "/", icon: Boxes, permission: "inventory.view" },
    { label: "BOM sourcing", to: "/bom", icon: FileSpreadsheet, permission: "engineering.view" },
    { label: "Validation & repair", to: "/pcb", icon: Wrench, permission: "engineering.edit" },
    { label: "Engineering assignments", to: "/assignments", icon: ClipboardList, permission: "engineering.view" },
    { label: "Inventory locations", to: "/locations", icon: Boxes, permission: "engineering.view" },
    { label: "Engineering team", to: "/rd-team", icon: Users, permission: "engineering.view" },
    { label: "Release documents", to: "/drive", icon: FileText, permission: "documents.view" },
  ] },
  { id: "mechanical", terms: ["mech", "mechanical", "cad", "enclosure", "structural"], label: "Mechanical Engineering", summary: "CAD models, thermal dissipation, structural analysis, mechanical drawings, and enclosure BOM components.", items: [
    { label: "Mechanical workspace", to: "/dashboards?department=mechanical", icon: LayoutDashboard, permission: "engineering.view" },
    { label: "Project tracker", to: "/workspace/projects", icon: FolderKanban, permission: "projects.view" },
    { label: "BOM sourcing", to: "/bom", icon: FileSpreadsheet, permission: "engineering.view" },
    { label: "Design drawings", to: "/drive", icon: FileText, permission: "documents.view" },
    { label: "PPAP packages", to: "/production/ppap", icon: FileText, permission: "production.view" },
    { label: "Engineering assignments", to: "/assignments", icon: ClipboardList, permission: "engineering.view" },
    { label: "Production dispatch", to: "/production/dispatch", icon: Send, permission: "production.view" },
  ] },
  { id: "procurement", terms: ["proc", "procurement", "purchase", "stores", "incoming quality", "qa", "supply chain"], label: "Procurement & SCM", summary: "Supplier data, sourcing, orders, incoming quality, Stores records, and controlled BOM sourcing.", items: [
    { label: "Procurement workspace", to: "/dashboards?department=procurement", icon: LayoutDashboard, permission: "procurement.view" },
    { label: "Project tracker", to: "/workspace/projects", icon: FolderKanban, permission: "projects.view" },
    { label: "Purchase requests", to: "/procurement/requests", icon: ClipboardList, permission: "procurement.view" },
    { label: "RFQs & quotations", to: "/procurement/rfqs", icon: FileSearch, permission: "procurement.view" },
    { label: "Purchase orders", to: "/procurement/orders", icon: ShoppingCart, permission: "procurement.view" },
    { label: "Supplier shipments", to: "/procurement/shipments", icon: Truck, permission: "procurement.view" },
    { label: "Inwarding (GRN)", to: "/procurement/inward", icon: PackageCheck, permission: "procurement.view" },
    { label: "Vendors", to: "/procurement/vendors", icon: Building2, permission: "procurement.view" },
    { label: "Supplier quality", to: "/procurement/supplier-quality", icon: ShieldCheck, permission: "quality.view" },
    { label: "Stores records", to: "/stores/inventory", icon: Boxes, permission: "stores.view" },
    { label: "BOM sourcing", to: "/bom", icon: FileSpreadsheet, permission: "procurement.view" },
    { label: "Procurement documents", to: "/drive", icon: FileText, permission: "documents.view" },
  ] },
  { id: "production", terms: ["prod", "production", "calibration", "engineering production"], label: "Production", summary: "Manufacturing instructions, calibration, assembly/testing, release, and dispatch evidence.", items: [
    { label: "Production workspace", to: "/dashboards?department=production", icon: LayoutDashboard, permission: "production.view" },
    { label: "Project tracker", to: "/workspace/projects", icon: FolderKanban, permission: "projects.view" },
    { label: "Production control", to: "/production", icon: HardHat, permission: "production.view" },
    { label: "Shop floor", to: "/production/shopfloor", icon: Wrench, permission: "production.view" },
    { label: "Calibration", to: "/calibration", icon: Gauge, permission: "calibration.view" },
    { label: "Finished goods release", to: "/production/release", icon: ClipboardCheck, permission: "production.view" },
    { label: "Dispatch evidence", to: "/production/dispatch", icon: Send, permission: "production.view" },
    { label: "Production documents", to: "/drive", icon: FileText, permission: "documents.view" },
  ] },
  { id: "facility", terms: ["fac", "facility", "maintenance", "security", "electrical", "utilities", "assets"], label: "Facility / Maintenance", summary: "Assets, security, gate passes, utilities, electrical, and maintenance records.", items: [
    { label: "Facility workspace", to: "/dashboards?department=facility", icon: LayoutDashboard, permission: "facility.view" },
    { label: "Project tracker", to: "/workspace/projects", icon: FolderKanban, permission: "projects.view" },
    { label: "Facilities", to: "/facility", icon: Building2, permission: "facility.view" },
    { label: "Assets", to: "/assets", icon: Boxes, permission: "assets.view" },
    { label: "Maintenance", to: "/maintenance", icon: Wrench, permission: "maintenance.view" },
    { label: "Security desk", to: "/security", icon: ShieldCheck, permission: "security.view" },
    { label: "Workplace", to: "/workplace", icon: HardHat, permission: "workplace.view" },
    { label: "Facility documents", to: "/drive", icon: FileText, permission: "documents.view" },
  ] },
  { id: "operations", terms: ["ops", "operations", "qms", "management review"], label: "Operations / QMS", summary: "Audits, CAPA, risks, KPIs, governance, and final quality-release records.", items: [
    { label: "Operations workspace", to: "/dashboards?department=operations", icon: LayoutDashboard, permission: "qms.view" },
    { label: "Project tracker", to: "/workspace/projects", icon: FolderKanban, permission: "projects.view" },
    { label: "QMS", to: "/qms", icon: ClipboardCheck, permission: "qms.view" },
    { label: "Incoming quality", to: "/quality/incoming", icon: ShieldCheck, permission: "quality.view" },
    { label: "Customer quality", to: "/customer-service", icon: Handshake, permission: "customer_service.view" },
    { label: "Governance records", to: "/records", icon: FileSearch, permission: "documents.view" },
    { label: "Quality documents", to: "/drive", icon: FileText, permission: "documents.view" },
  ] },
  { id: "hr", terms: ["hr", "human resources"], label: "HR", summary: "Employee, recruitment, onboarding, policy, and training documents.", items: [
    { label: "HR workspace", to: "/dashboards?department=hr", icon: LayoutDashboard, permission: "hr.view" },
    { label: "Project tracker", to: "/workspace/projects", icon: FolderKanban, permission: "projects.view" },
    { label: "HR overview", to: "/hr", icon: Users, permission: "hr.view" },
    { label: "Employees & access", to: "/hr/access", icon: ShieldCheck, permission: "admin.view" },
    { label: "Recruitment", to: "/hr/recruitment", icon: ClipboardList, permission: "recruitment.manage" },
    { label: "Onboarding", to: "/hr/onboarding", icon: PlaneTakeoff, permission: "training.manage" },
    { label: "Training", to: "/hr/training", icon: GraduationCap, permission: "training.manage" },
    { label: "Policies", to: "/hr/policies", icon: FileText, permission: "hr.view" },
    { label: "HR documents", to: "/drive", icon: FileText, permission: "documents.view" },
  ] },
  { id: "sales", terms: ["sal", "sales"], label: "Sales", summary: "Customer requirements, quotations, commercial handover, and client documents.", items: [
    { label: "Sales workspace", to: "/dashboards?department=sales", icon: LayoutDashboard, permission: "sales.view" },
    { label: "Project tracker", to: "/workspace/projects", icon: FolderKanban, permission: "projects.view" },
    { label: "Sales overview", to: "/sales", icon: BriefcaseBusiness, permission: "sales.view" },
    { label: "Enquiries & Opportunities", to: "/sales/enquiries", icon: ClipboardList, permission: "sales.view" },
    { label: "Customers", to: "/customers", icon: Building2, permission: "sales.view" },
    { label: "Customer service", to: "/customer-service", icon: Handshake, permission: "customer_service.view" },
    { label: "Commercial records", to: "/records", icon: FileSearch, permission: "documents.view" },
    { label: "Client documents", to: "/drive", icon: FileText, permission: "documents.view" },
  ] },
  { id: "finance", terms: ["fin", "finance"], label: "Finance", summary: "Payment, expense, and finance-only commercial records.", items: [
    { label: "Finance workspace", to: "/dashboards?department=finance", icon: LayoutDashboard, permission: "finance.view" },
    { label: "Project tracker", to: "/workspace/projects", icon: FolderKanban, permission: "projects.view" },
    { label: "Expenses", to: "/finance/expenses", icon: ReceiptText, permission: "finance.view" },
    { label: "Payment milestones", to: "/finance/payment-plans", icon: WalletCards, permission: "finance.view" },
    { label: "Finance records", to: "/records", icon: FileSearch, permission: "documents.view" },
    { label: "Finance documents", to: "/drive", icon: FileText, permission: "documents.view" },
  ] },
];

export function workspaceForDepartment(department: { id?: string; name: string; code: string | null; aliases: string[] } | null) {
  if (!department) return null;

  // 1. Check exact canonical UUID match first
  if (department.id) {
    const id = department.id.toLowerCase();
    if (id === CANONICAL_DEPT_UUIDS.MECHANICAL.toLowerCase()) return workspaceDefinitions.find((w) => w.id === "mechanical")!;
    if (id === CANONICAL_DEPT_UUIDS.RND.toLowerCase() || id === CANONICAL_DEPT_UUIDS.FIRMWARE.toLowerCase()) return workspaceDefinitions.find((w) => w.id === "rnd")!;
    if (id === CANONICAL_DEPT_UUIDS.PROCUREMENT.toLowerCase()) return workspaceDefinitions.find((w) => w.id === "procurement")!;
    if (id === CANONICAL_DEPT_UUIDS.PRODUCTION.toLowerCase()) return workspaceDefinitions.find((w) => w.id === "production")!;
    if (id === CANONICAL_DEPT_UUIDS.FACILITY.toLowerCase()) return workspaceDefinitions.find((w) => w.id === "facility")!;
    if (id === CANONICAL_DEPT_UUIDS.OPERATIONS.toLowerCase()) return workspaceDefinitions.find((w) => w.id === "operations")!;
    if (id === CANONICAL_DEPT_UUIDS.HR.toLowerCase()) return workspaceDefinitions.find((w) => w.id === "hr")!;
    if (id === CANONICAL_DEPT_UUIDS.SALES.toLowerCase()) return workspaceDefinitions.find((w) => w.id === "sales")!;
    if (id === CANONICAL_DEPT_UUIDS.FINANCE.toLowerCase()) return workspaceDefinitions.find((w) => w.id === "finance")!;
  }

  // 2. Fall back to keywords / aliases
  const terms = [department.name, department.code ?? "", ...department.aliases]
    .filter(Boolean)
    .map((value) => value.trim().toLowerCase());
  return (
    workspaceDefinitions.find((workspace) =>
      workspace.terms.some((term) =>
        terms.some((t) => t === term || t.includes(term) || term.includes(t))
      )
    ) ?? null
  );
}