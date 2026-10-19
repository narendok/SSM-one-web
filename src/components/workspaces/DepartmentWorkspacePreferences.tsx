import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useMemo, useState } from "react";
import { Link } from "@tanstack/react-router";
import { toast } from "sonner";
import {
  Boxes,
  BriefcaseBusiness,
  Building2,
  CheckCircle2,
  CircleAlert,
  ClipboardCheck,
  ClipboardList,
  ExternalLink,
  FileSearch,
  FileSpreadsheet,
  FileText,
  FolderKanban,
  HardHat,
  PackageCheck,
  Send,
  Settings2,
  ShieldCheck,
  ShoppingCart,
  Truck,
  UsersRound,
  Wrench,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Switch } from "@/components/ui/switch";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { fetchWorkspacePreference, saveWorkspacePreference } from "@/lib/department-workspace";
import {
  CANONICAL_DEPT_UUIDS,
  fetchCanonicalDepartments,
  fetchTaskMembers,
  resolveCanonicalDepartment,
} from "@/lib/tasks";
import { workspaceForDepartment } from "@/lib/department-workspace-navigation";
import { useAuth } from "@/hooks/useAuth";

const driveFilters = [
  { value: "all", label: "All files" },
  { value: "common", label: "Common documents" },
  { value: "internal", label: "Internal projects" },
  { value: "client", label: "Client projects" },
];

export interface DepartmentRoleDefinition {
  title: string;
  code: string;
  responsibilities: string[];
  options: { label: string; to: string }[];
  isDefault: boolean;
}

export interface DepartmentResponsibilityCatalogue {
  summary: string;
  standardRoles: DepartmentRoleDefinition[];
  standardOptions: { label: string; to: string; description: string }[];
  reassignableOptions: { id: string; label: string; description: string; defaultDepartments: string[] }[];
}

const DEPARTMENT_ROLES_CATALOGUE: Record<string, DepartmentResponsibilityCatalogue> = {
  [CANONICAL_DEPT_UUIDS.PROCUREMENT]: {
    summary: "Suppliers, pilot/series sourcing, PR/RFQ/PO/ASN, Stores, receiving, IQC and controlled material transactions (Master Plan §2 & §5).",
    standardRoles: [
      {
        title: "Procurement Head / Purchase Manager",
        code: "PROC-HEAD",
        responsibilities: [
          "Purchase requisition (PR) review & approval",
          "Vendor negotiations, RFQ dispatch, and quote comparison",
          "Purchase Order (PO) creation, release, and amendment",
          "Supplier relationship and vendor onboarding",
        ],
        options: [
          { label: "Purchase requests", to: "/procurement/requests" },
          { label: "RFQs & quotations", to: "/procurement/rfqs" },
          { label: "Purchase orders", to: "/procurement/orders" },
          { label: "Supplier shipments", to: "/procurement/shipments" },
        ],
        isDefault: true,
      },
      {
        title: "Sourcing & BOM Costing Specialist",
        code: "PROC-SOURCE",
        responsibilities: [
          "Electronic & mechanical BOM component pricing",
          "Component lead time & availability benchmarking",
          "Alternative MPN cross-referencing and supplier qualification",
          "BOM sourcing review for pilot and series production",
        ],
        options: [
          { label: "BOM sourcing & costing", to: "/bom" },
          { label: "Vendors directory", to: "/procurement/vendors" },
          { label: "Supplier quality", to: "/procurement/supplier-quality" },
        ],
        isDefault: true,
      },
      {
        title: "Stores Custodian & Inwarding Lead",
        code: "PROC-STORES",
        responsibilities: [
          "Goods Receipt Note (GRN) inwarding & verification",
          "Physical bin storage, component stock tracking, and audits",
          "Incoming Quality (IQC) inspection coordination",
          "Pending delivery tracking & delivery revisions",
        ],
        options: [
          { label: "Inwarding (GRN)", to: "/procurement/inward" },
          { label: "Stores inventory", to: "/stores/inventory" },
          { label: "Pending deliveries", to: "/procurement/pending" },
          { label: "Delivery revisions", to: "/procurement/delivery-revisions" },
        ],
        isDefault: true,
      },
    ],
    standardOptions: [
      { label: "Procurement workspace", to: "/dashboards?department=procurement", description: "Procurement, SCM, and supplier lead overview" },
      { label: "Purchase requests", to: "/procurement/requests", description: "Review and approve internal PRs" },
      { label: "RFQs & quotations", to: "/procurement/rfqs", description: "Request for quotes from suppliers" },
      { label: "Purchase orders", to: "/procurement/orders", description: "Generate and dispatch official POs" },
      { label: "Supplier shipments", to: "/procurement/shipments", description: "Track en-route shipments & ASNs" },
      { label: "Inwarding (GRN)", to: "/procurement/inward", description: "Generate Goods Receipt Notes on arrival" },
      { label: "Vendors", to: "/procurement/vendors", description: "Approved supplier directory & ratings" },
      { label: "Supplier quality", to: "/procurement/supplier-quality", description: "Vendor scorecards and corrective actions" },
      { label: "Stores inventory", to: "/stores/inventory", description: "Real-time bin locations and component stock" },
      { label: "BOM sourcing", to: "/bom", description: "Component pricing, lead-time & MPN sourcing" },
      { label: "Procurement documents", to: "/drive", description: "Commercial & supplier documents in Drive" },
    ],
    reassignableOptions: [
      { id: "bom_sourcing", label: "BOM component sourcing", description: "Component availability, price benchmarking, and pilot BOM review", defaultDepartments: ["PROC", "RND"] },
      { id: "supplier_quality", label: "Supplier quality & IQC", description: "Incoming material inspection and vendor scorecards", defaultDepartments: ["PROC", "OPS"] },
      { id: "stores_custody", label: "Stores inventory custody", description: "Physical bin stock levels and material inwarding", defaultDepartments: ["PROC"] },
    ],
  },
  [CANONICAL_DEPT_UUIDS.MECHANICAL]: {
    summary: "CAD models, thermal dissipation, structural analysis, mechanical drawings, and enclosure BOM components (Master Plan §2 & §5).",
    standardRoles: [
      {
        title: "Mechanical Lead Engineer",
        code: "MECH-LEAD",
        responsibilities: [
          "Enclosure architecture and 3D CAD modeling",
          "Thermal dissipation and heat-sink calculations",
          "Structural stress analysis and ingress protection (IP ratings)",
          "Mechanical drawing release and revision control",
        ],
        options: [
          { label: "Mechanical workspace", to: "/dashboards?department=mechanical" },
          { label: "Design drawings", to: "/drive" },
          { label: "Project tracker", to: "/workspace/projects" },
        ],
        isDefault: true,
      },
      {
        title: "CAD & Packaging Design Engineer",
        code: "MECH-CAD",
        responsibilities: [
          "Detailed component 3D modeling and STEP/IGES exports",
          "Fastener, gasket, connector cutout, and casing specifications",
          "Mechanical BOM item definition and drawing packages",
          "Tolerance stack-up analysis and tooling DFM reviews",
        ],
        options: [
          { label: "Mechanical BOM sourcing", to: "/bom" },
          { label: "Engineering assignments", to: "/assignments" },
        ],
        isDefault: true,
      },
      {
        title: "Packaging & Dispatch Coordinator",
        code: "MECH-DISPATCH",
        responsibilities: [
          "Product enclosure packaging and shock-protection design",
          "Dispatch carton sizing and assembly fitment verification",
          "Dispatch coordination with production and kitting teams",
        ],
        options: [
          { label: "Production dispatch coordination", to: "/production/dispatch" },
        ],
        isDefault: true,
      },
    ],
    standardOptions: [
      { label: "Mechanical workspace", to: "/dashboards?department=mechanical", description: "Primary mechanical engineering overview" },
      { label: "Mechanical BOM sourcing", to: "/bom", description: "Enclosure, hardware, and fastener BOM items" },
      { label: "Design drawings", to: "/drive", description: "Controlled CAD drawings and 3D models in Drive" },
      { label: "PPAP packages", to: "/production/ppap", description: "Production Part Approval Process documentation" },
      { label: "Engineering assignments", to: "/assignments", description: "Mechanical tasks, review requests, and milestones" },
      { label: "Production dispatch", to: "/production/dispatch", description: "Finished enclosure & packaging dispatch coordination" },
      { label: "Project tracker", to: "/workspace/projects", description: "Department project progress and milestone tracking" },
    ],
    reassignableOptions: [
      { id: "dispatch_coordination", label: "Dispatch & packaging coordination", description: "Coordinate enclosure packaging fitment and dispatch handoff", defaultDepartments: ["MECH", "PROD"] },
      { id: "bom_mechanical", label: "Mechanical BOM sourcing", description: "Manage mechanical and structural hardware BOM components", defaultDepartments: ["MECH", "RND", "PROC"] },
    ],
  },
  [CANONICAL_DEPT_UUIDS.RND]: {
    summary: "Hardware, firmware, specifications, schematic, PCB layout, BOM qualification, DFMEA, and validation (Master Plan §2).",
    standardRoles: [
      {
        title: "Hardware Lead Engineer",
        code: "HW-LEAD",
        responsibilities: [
          "System schematic design and component selection",
          "Technical BOM qualification and alternative MPN approvals",
          "Design Failure Mode and Effects Analysis (DFMEA)",
          "Product Requirement Specification (PRS) sign-off",
        ],
        options: [
          { label: "Hardware workspace", to: "/dashboards?department=rnd" },
          { label: "BOM sourcing & qualification", to: "/bom" },
          { label: "Project tracker", to: "/workspace/projects" },
        ],
        isDefault: true,
      },
      {
        title: "Embedded Hardware Engineer",
        code: "HW-ENG",
        responsibilities: [
          "PCB layout, routing, and Gerber package generation",
          "Board bring-up, signal integrity, and bench testing",
          "Engineering assignments and milestone tracking",
        ],
        options: [
          { label: "Engineering assignments", to: "/assignments" },
          { label: "Inventory locations", to: "/locations" },
          { label: "Engineering team", to: "/rd-team" },
        ],
        isDefault: true,
      },
      {
        title: "PCB Diagnostics & Repair Specialist",
        code: "HW-REPAIR",
        responsibilities: [
          "Prototype board rework, soldering, and diagnostic logs",
          "Failure root-cause analysis (RCA) and repair tracking",
          "Component verification and bench equipment maintenance",
        ],
        options: [
          { label: "PCB validation & repair", to: "/pcb" },
          { label: "Release documents", to: "/drive" },
        ],
        isDefault: true,
      },
    ],
    standardOptions: [
      { label: "Hardware workspace", to: "/dashboards?department=rnd", description: "Hardware & R&D central dashboard" },
      { label: "Electronic inventory", to: "/", description: "Electronic components & lab stock" },
      { label: "BOM sourcing", to: "/bom", description: "Electronic component sourcing & qualification" },
      { label: "Validation & repair", to: "/pcb", description: "PCB diagnostics, rework logs, and repair tickets" },
      { label: "Engineering assignments", to: "/assignments", description: "Engineering tasks and milestone tracking" },
      { label: "Inventory locations", to: "/locations", description: "Lab components, bin locations, and test gear" },
      { label: "Engineering team", to: "/rd-team", description: "R&D engineers, skill sets, and active work" },
      { label: "Release documents", to: "/drive", description: "Controlled schematics, Gerbers, and PRS in Drive" },
    ],
    reassignableOptions: [
      { id: "bom_qualification", label: "Technical BOM qualification", description: "Approve electronic MPN substitutes and component parameters", defaultDepartments: ["RND"] },
      { id: "pcb_repair", label: "PCB diagnostics & repair", description: "Manage board repair logs and bench rework", defaultDepartments: ["RND"] },
    ],
  },
  [CANONICAL_DEPT_UUIDS.PRODUCTION]: {
    summary: "Planning/kitting, SMT/PCBA, assembly, EOL/PDI testing, traceability, packaging/dispatch, and calibration (Master Plan §2).",
    standardRoles: [
      {
        title: "Production Lead / Shop Floor Manager",
        code: "PROD-LEAD",
        responsibilities: [
          "Shop floor batch scheduling and line allocation",
          "SMT & manual assembly process control and routing",
          "Pre-Delivery Inspection (PDI) and finished goods release",
          "Production dispatch and carton packaging evidence",
        ],
        options: [
          { label: "Production control", to: "/production" },
          { label: "Shop floor", to: "/production/shopfloor" },
          { label: "Finished goods release", to: "/production/release" },
          { label: "Dispatch evidence", to: "/production/dispatch" },
        ],
        isDefault: true,
      },
      {
        title: "Calibration & Test Engineer",
        code: "PROD-CALIB",
        responsibilities: [
          "Production test jigs, multimeters, and tool calibration",
          "Calibration due date tracking and certificates",
          "PPAP package compilation and assembly records",
        ],
        options: [
          { label: "Calibration records", to: "/calibration" },
          { label: "PPAP packages", to: "/production/ppap" },
        ],
        isDefault: true,
      },
    ],
    standardOptions: [
      { label: "Production workspace", to: "/dashboards?department=production", description: "Production management and KPI summary" },
      { label: "Production control", to: "/production", description: "Overview of ongoing production runs" },
      { label: "Shop floor", to: "/production/shopfloor", description: "Active batch status, routing, and kitting" },
      { label: "Tool calibration", to: "/calibration", description: "Tool calibration certificates and due dates" },
      { label: "Finished goods release", to: "/production/release", description: "Final inspection and release sign-off" },
      { label: "Dispatch evidence", to: "/production/dispatch", description: "Packaging, serial genealogy, and shipping docs" },
      { label: "PPAP packages", to: "/production/ppap", description: "Production Part Approval Process documentation" },
    ],
    reassignableOptions: [
      { id: "calibration", label: "Tool & instrument calibration", description: "Manage calibration logs and certificates", defaultDepartments: ["PROD", "FAC"] },
      { id: "dispatch_release", label: "Dispatch & packaging evidence", description: "Record outbound lot genealogy and shipping manifests", defaultDepartments: ["PROD", "MECH"] },
    ],
  },
  [CANONICAL_DEPT_UUIDS.SALES]: {
    summary: "Customer relationship management, enquiries, feasibility coordination, quotations, and commercial project handovers (Master Plan §2).",
    standardRoles: [
      {
        title: "Sales & Commercial Lead",
        code: "SALES-LEAD",
        responsibilities: [
          "OEM customer relationship management & NDA execution",
          "Enquiry review, technical feasibility alignment with engineering",
          "Commercial proposals, quotations, and customer authorization",
          "Project commercial handover to engineering & production",
        ],
        options: [
          { label: "Sales overview", to: "/sales" },
          { label: "Enquiries & Opportunities", to: "/sales/enquiries" },
          { label: "Customers", to: "/customers" },
          { label: "Project tracker", to: "/workspace/projects" },
        ],
        isDefault: true,
      },
    ],
    standardOptions: [
      { label: "Sales workspace", to: "/dashboards?department=sales", description: "Commercial CRM and customer pipeline" },
      { label: "Sales overview", to: "/sales", description: "Enquiry pipeline, active opportunities, and quotes" },
      { label: "Enquiries & Opportunities", to: "/sales/enquiries", description: "Lead tracking, technical feasibility, and baselines" },
      { label: "Customers directory", to: "/customers", description: "OEM accounts and named contacts" },
      { label: "Customer service", to: "/customer-service", description: "Field failures, complaints, and satisfaction" },
      { label: "Commercial documents", to: "/drive", description: "Contracts, NDAs, and proposals in Drive" },
    ],
    reassignableOptions: [
      { id: "client_nda", label: "NDA & legal agreements", description: "Maintain NDA records and non-disclosure validity", defaultDepartments: ["SALES", "HR"] },
    ],
  },
  [CANONICAL_DEPT_UUIDS.OPERATIONS]: {
    summary: "Quality management systems (QMS), incoming QA, CAPA, APQP/PPAP validation, and operational governance (Master Plan §2).",
    standardRoles: [
      {
        title: "Quality & QMS Manager",
        code: "OPS-QMS",
        responsibilities: [
          "Quality manual, ISO 9001 / IATF 16949 audit schedules",
          "CAPA root cause investigations and 8D reports",
          "Incoming component inspection & vendor quality tracking",
          "Customer field failure triage and warranty tracking",
        ],
        options: [
          { label: "Operations workspace", to: "/dashboards?department=operations" },
          { label: "QMS overview", to: "/qms" },
          { label: "Incoming quality", to: "/quality/incoming" },
          { label: "Customer quality", to: "/customer-service" },
        ],
        isDefault: true,
      },
    ],
    standardOptions: [
      { label: "Operations workspace", to: "/dashboards?department=operations", description: "Central operations and QMS health" },
      { label: "QMS", to: "/qms", description: "Internal audits, CAPA, and management reviews" },
      { label: "Incoming quality (IQC)", to: "/quality/incoming", description: "Material inwarding inspection reports" },
      { label: "Customer service & warranty", to: "/customer-service", description: "Field failure triage, complaints, and returns" },
      { label: "Supplier quality", to: "/procurement/supplier-quality", description: "Vendor scorecards and SCAR notices" },
      { label: "Quality documents", to: "/drive", description: "SOPs, control plans, and certificates in Drive" },
    ],
    reassignableOptions: [
      { id: "customer_quality", label: "Customer service & warranty", description: "Customer RMA and field issue investigations", defaultDepartments: ["OPS", "SALES"] },
    ],
  },
  [CANONICAL_DEPT_UUIDS.FACILITY]: {
    summary: "Building infrastructure, plant electricals, asset maintenance, physical security, and workplace safety (Master Plan §2).",
    standardRoles: [
      {
        title: "Facility & Maintenance Manager",
        code: "FAC-LEAD",
        responsibilities: [
          "Preventive & breakdown maintenance schedules",
          "Machine uptime, compressor, UPS & HVAC controls",
          "Fixed asset tracking, tagging, and location updates",
          "Physical security, visitor badges, and surveillance",
        ],
        options: [
          { label: "Facility workspace", to: "/dashboards?department=facility" },
          { label: "Facilities", to: "/facility" },
          { label: "Assets register", to: "/assets" },
          { label: "Maintenance", to: "/maintenance" },
          { label: "Security desk", to: "/security" },
        ],
        isDefault: true,
      },
    ],
    standardOptions: [
      { label: "Facility workspace", to: "/dashboards?department=facility", description: "Plant maintenance, assets, and security" },
      { label: "Facilities", to: "/facility", description: "Rooms, labs, and utility services" },
      { label: "Assets register", to: "/assets", description: "Lab equipment, machines, and tools inventory" },
      { label: "Maintenance desk", to: "/maintenance", description: "Service logs and PM work orders" },
      { label: "Security desk", to: "/security", description: "Gate passes, visitor logs, and cameras" },
      { label: "Workplace", to: "/workplace", description: "Workstations, safety equipment, and ergonomics" },
    ],
    reassignableOptions: [
      { id: "asset_calibration", label: "Asset tracking & calibration", description: "Asset custodianship and calibration scheduling", defaultDepartments: ["FAC", "PROD"] },
    ],
  },
  [CANONICAL_DEPT_UUIDS.HR]: {
    summary: "Talent acquisition, onboarding, attendance, leave management, corporate policies, and training (Master Plan §2).",
    standardRoles: [
      {
        title: "HR & Talent Manager",
        code: "HR-LEAD",
        responsibilities: [
          "Recruitment pipelines, technical interview coordination",
          "Employee onboarding, document verification & access setup",
          "Leave desk, attendance records, and leave approvals",
          "Corporate policies, safety training, and skill matrices",
        ],
        options: [
          { label: "HR workspace", to: "/dashboards?department=hr" },
          { label: "HR overview", to: "/hr" },
          { label: "Employees & access", to: "/hr/access" },
          { label: "Recruitment", to: "/hr/recruitment" },
          { label: "Leave desk", to: "/hr/leave" },
        ],
        isDefault: true,
      },
    ],
    standardOptions: [
      { label: "HR workspace", to: "/dashboards?department=hr", description: "Human resources and people management" },
      { label: "HR overview", to: "/hr", description: "Department headcounts and status summary" },
      { label: "Employees & access", to: "/hr/access", description: "Staff directory, system roles, and status" },
      { label: "Recruitment", to: "/hr/recruitment", description: "Job postings and candidate stages" },
      { label: "Leave desk", to: "/hr/leave", description: "Leave applications and team availability" },
      { label: "Training & learning", to: "/hr/training", description: "Course modules and skill development" },
      { label: "Policies", to: "/hr/policies", description: "Company handbook and safety policies" },
    ],
    reassignableOptions: [
      { id: "onboarding_training", label: "Employee training & skill tracking", description: "Coordinate corporate training programs", defaultDepartments: ["HR"] },
    ],
  },
  [CANONICAL_DEPT_UUIDS.FINANCE]: {
    summary: "Accounting, expense claims, purchase order billing approvals, payment milestones, and financial reporting (Master Plan §2).",
    standardRoles: [
      {
        title: "Finance Controller",
        code: "FIN-LEAD",
        responsibilities: [
          "Departmental operating expenses & OPEX budget tracking",
          "Purchase Order payment milestone release & vendor invoices",
          "Client project milestones billing and payment receipts",
          "Financial audit compliance and commercial documentation",
        ],
        options: [
          { label: "Finance workspace", to: "/dashboards?department=finance" },
          { label: "Expenses", to: "/finance/expenses" },
          { label: "Payment milestones", to: "/finance/payment-plans" },
          { label: "Financial records", to: "/records" },
        ],
        isDefault: true,
      },
    ],
    standardOptions: [
      { label: "Finance workspace", to: "/dashboards?department=finance", description: "Financial health, payment plans, and OPEX" },
      { label: "Expenses", to: "/finance/expenses", description: "Track expense claims and department vouchers" },
      { label: "Payment milestones", to: "/finance/payment-plans", description: "Project milestone payments and supplier disbursements" },
      { label: "Financial records", to: "/records", description: "Audit trails, invoices, and accounting docs" },
      { label: "Finance documents", to: "/drive", description: "Financial reports and agreements in Drive" },
    ],
    reassignableOptions: [
      { id: "po_milestones", label: "PO milestone payments", description: "Approve milestone payments to critical vendors", defaultDepartments: ["FIN", "PROC"] },
    ],
  },
};

export function DepartmentWorkspacePreferences({ departmentId }: { departmentId: string }) {
  const { role } = useAuth();
  const isAdmin = role === "admin";
  const client = useQueryClient();
  const [saving, setSaving] = useState(false);

  const departments = useQuery({ queryKey: ["active-departments"], queryFn: fetchCanonicalDepartments });
  const members = useQuery({ queryKey: ["rd_members_all"], queryFn: fetchTaskMembers });
  const preference = useQuery({ queryKey: ["department_workspace_preferences", departmentId], queryFn: () => fetchWorkspacePreference(departmentId) });

  const activeDepartment = useMemo(
    () => resolveCanonicalDepartment(departmentId, departments.data ?? []),
    [departmentId, departments.data]
  );
  const workspace = workspaceForDepartment(activeDepartment);

  const catalogue = activeDepartment?.id
    ? DEPARTMENT_ROLES_CATALOGUE[activeDepartment.id] ?? null
    : null;

  // Local storage customization for optional/reassignable roles
  const customRoleKey = `ssm_dept_custom_roles_${activeDepartment?.id ?? departmentId}`;
  const [customRoles, setCustomRoles] = useState<Record<string, boolean>>(() => {
    if (typeof window === "undefined") return {};
    try {
      const raw = window.localStorage.getItem(customRoleKey);
      return raw ? JSON.parse(raw) : {};
    } catch {
      return {};
    }
  });

  const toggleCustomRole = (roleId: string, enabled: boolean) => {
    const next = { ...customRoles, [roleId]: enabled };
    setCustomRoles(next);
    if (typeof window !== "undefined") {
      window.localStorage.setItem(customRoleKey, JSON.stringify(next));
    }
    toast.success(`${enabled ? "Assigned" : "Unassigned"} role capability for ${activeDepartment?.name ?? "workspace"}`);
  };

  const assignedMembers = useMemo(() => {
    if (!members.data || !activeDepartment) return [];
    return members.data.filter(
      (m) =>
        m.department_id === activeDepartment.id ||
        (m.department && activeDepartment.aliases.includes(m.department.toLowerCase()))
    );
  }, [members.data, activeDepartment]);

  const current = preference.data;
  const update = async (patch: Parameters<typeof saveWorkspacePreference>[1]) => {
    setSaving(true);
    try {
      await saveWorkspacePreference(departmentId, patch);
      await client.invalidateQueries({ queryKey: ["department_workspace_preferences", departmentId] });
      toast.success("Workspace preference saved");
    } catch (error) {
      toast.error(error instanceof Error ? error.message : "Could not save workspace preference");
    } finally {
      setSaving(false);
    }
  };

  return (
    <section className="space-y-6">
      <div className="border-b pb-4">
        <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <h2 className="text-xl font-semibold flex items-center gap-2">
              <Settings2 className="size-5 text-primary" />
              {activeDepartment?.name ?? "Department"} Workspace Settings
            </h2>
            <p className="mt-1 text-sm text-muted-foreground">
              Roles, responsibilities, workflow options, and workspace preferences as per Master Plan §2.
            </p>
          </div>
          {isAdmin && (
            <Button asChild size="sm" variant="outline" className="gap-1.5 self-start sm:self-auto">
              <Link to="/hr/access">
                <UsersRound className="size-3.5 text-primary" />
                Manage employee access & roles
                <ExternalLink className="size-3 text-muted-foreground" />
              </Link>
            </Button>
          )}
        </div>
      </div>

      {/* 1. Department Roles & Responsibilities Matrix */}
      <Card>
        <CardHeader className="pb-3">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <div>
              <CardTitle className="text-base flex items-center gap-2">
                <ShieldCheck className="size-4 text-primary" />
                Department Roles & Responsibilities
              </CardTitle>
              <CardDescription className="mt-1">
                Standard roles and responsibilities assigned to {activeDepartment?.name ?? "this department"} under the Master Plan.
              </CardDescription>
            </div>
            <Badge variant="outline" className="bg-primary/5 text-primary border-primary/20">
              Master Plan Aligned
            </Badge>
          </div>
        </CardHeader>
        <CardContent className="space-y-4">
          {catalogue ? (
            <>
              <p className="text-xs text-muted-foreground bg-muted/40 p-2.5 rounded-md border">
                <strong>Standard scope:</strong> {catalogue.summary}
              </p>
              <div className="grid gap-3 md:grid-cols-2 lg:grid-cols-3">
                {catalogue.standardRoles.map((roleDef) => (
                  <div key={roleDef.code} className="rounded-lg border p-3.5 bg-card flex flex-col justify-between">
                    <div>
                      <div className="flex items-start justify-between gap-2 mb-2">
                        <p className="text-sm font-semibold text-foreground">{roleDef.title}</p>
                        <Badge variant="secondary" className="text-[10px] shrink-0">
                          {roleDef.code}
                        </Badge>
                      </div>
                      <div className="space-y-1.5 mb-3">
                        {roleDef.responsibilities.map((resp, i) => (
                          <p key={i} className="text-xs text-muted-foreground flex items-start gap-1.5">
                            <span className="text-primary font-bold">·</span>
                            <span>{resp}</span>
                          </p>
                        ))}
                      </div>
                    </div>
                    <div className="border-t pt-2.5 mt-2">
                      <p className="text-[11px] font-medium text-muted-foreground mb-1">Permitted options:</p>
                      <div className="flex flex-wrap gap-1">
                        {roleDef.options.map((opt) => (
                          <Link
                            key={opt.to}
                            to={opt.to}
                            className="inline-flex items-center gap-1 rounded bg-muted px-2 py-0.5 text-[11px] font-medium text-foreground hover:bg-muted/80 hover:text-primary transition-colors"
                          >
                            {opt.label}
                          </Link>
                        ))}
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </>
          ) : (
            <p className="text-sm text-muted-foreground py-2">
              Standard departmental roles are active. All operations follow the canonical company workflow.
            </p>
          )}
        </CardContent>
      </Card>

      {/* 2. Permitted Department Workflow Options */}
      {catalogue && (
        <Card>
          <CardHeader className="pb-3">
            <CardTitle className="text-base flex items-center gap-2">
              <ClipboardCheck className="size-4 text-primary" />
              Standard Workflow Menus & Options
            </CardTitle>
            <CardDescription>
              Menu items and operational queues configured for {activeDepartment?.name ?? "this workspace"}.
            </CardDescription>
          </CardHeader>
          <CardContent>
            <div className="grid gap-2 sm:grid-cols-2 lg:grid-cols-3">
              {catalogue.standardOptions.map((opt) => (
                <Link
                  key={opt.to + opt.label}
                  to={opt.to}
                  className="flex items-start gap-3 rounded-md border p-3 hover:bg-muted/50 transition-colors group"
                >
                  <CheckCircle2 className="size-4 text-emerald-600 dark:text-emerald-400 shrink-0 mt-0.5" />
                  <div className="min-w-0 flex-1">
                    <p className="text-sm font-medium group-hover:text-primary transition-colors">{opt.label}</p>
                    <p className="text-xs text-muted-foreground truncate">{opt.description}</p>
                  </div>
                </Link>
              ))}
            </div>
          </CardContent>
        </Card>
      )}

      {/* 3. Reassignable / Cross-Department Role Settings */}
      {catalogue && catalogue.reassignableOptions.length > 0 && (
        <Card>
          <CardHeader className="pb-3">
            <div className="flex items-center justify-between">
              <div>
                <CardTitle className="text-base flex items-center gap-2">
                  <BriefcaseBusiness className="size-4 text-primary" />
                  Cross-Department Role & Option Assignment
                </CardTitle>
                <CardDescription className="mt-1">
                  Adjust or delegate doubtful and cross-functional responsibilities for this department workspace.
                </CardDescription>
              </div>
              <Badge variant="secondary">Configurable</Badge>
            </div>
          </CardHeader>
          <CardContent className="space-y-3">
            {catalogue.reassignableOptions.map((opt) => {
              const isEnabled = customRoles[opt.id] ?? true;
              return (
                <div
                  key={opt.id}
                  className="flex flex-col gap-2 rounded-lg border p-3.5 sm:flex-row sm:items-center sm:justify-between"
                >
                  <div className="space-y-0.5">
                    <p className="text-sm font-medium">{opt.label}</p>
                    <p className="text-xs text-muted-foreground">{opt.description}</p>
                    <p className="text-[11px] text-muted-foreground">
                      Standard assigned departments: {opt.defaultDepartments.join(", ")}
                    </p>
                  </div>
                  <div className="flex items-center gap-3 self-end sm:self-auto">
                    <span className="text-xs text-muted-foreground">
                      {isEnabled ? "Assigned" : "Unassigned"}
                    </span>
                    <Switch
                      checked={isEnabled}
                      disabled={!isAdmin}
                      onCheckedChange={(checked) => toggleCustomRole(opt.id, checked)}
                      aria-label={`Toggle ${opt.label} assignment`}
                    />
                  </div>
                </div>
              );
            })}
            {!isAdmin && (
              <p className="text-xs text-muted-foreground italic">
                Only platform administrators can reassign cross-department responsibilities.
              </p>
            )}
          </CardContent>
        </Card>
      )}

      {/* 4. Active Team Members in this Department */}
      <Card>
        <CardHeader className="pb-3">
          <CardTitle className="text-base flex items-center gap-2">
            <UsersRound className="size-4 text-primary" />
            Active Team Members & Assigned Roles
          </CardTitle>
          <CardDescription>
            Personnel currently assigned to {activeDepartment?.name ?? "this department"}.
          </CardDescription>
        </CardHeader>
        <CardContent>
          {assignedMembers.length > 0 ? (
            <div className="divide-y rounded-md border">
              {assignedMembers.map((member) => (
                <div key={member.id} className="flex items-center justify-between p-3 text-sm">
                  <div className="min-w-0">
                    <p className="font-medium text-foreground truncate">{member.name}</p>
                    <p className="text-xs text-muted-foreground truncate">{member.email}</p>
                  </div>
                  <Badge variant="outline" className="text-xs capitalize shrink-0">
                    {member.department ?? activeDepartment?.name ?? "Member"}
                  </Badge>
                </div>
              ))}
            </div>
          ) : (
            <p className="text-sm text-muted-foreground py-2">
              No specific team members are directly mapped to this department yet.
            </p>
          )}
        </CardContent>
      </Card>

      {/* 5. Personal Workspace Defaults */}
      <div className="space-y-3">
        <h3 className="text-base font-semibold">Personal Workspace Defaults</h3>
        <div className="grid gap-4 sm:grid-cols-2">
          <Card>
            <CardHeader className="pb-3">
              <CardTitle className="text-base">Drive View</CardTitle>
              <CardDescription>Choose which department Drive area opens first.</CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div>
                <p className="mb-1.5 text-sm font-medium">Default filter</p>
                <Select
                  value={current?.drive_default_filter ?? "all"}
                  onValueChange={(drive_default_filter) => void update({ drive_default_filter })}
                >
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {driveFilters.map((filter) => (
                      <SelectItem key={filter.value} value={filter.value}>
                        {filter.label}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
              <ToggleRow
                label="Show documents on dashboard"
                checked={current?.show_dashboard_documents ?? true}
                disabled={saving}
                onCheckedChange={(show_dashboard_documents) => void update({ show_dashboard_documents })}
              />
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="pb-3">
              <CardTitle className="text-base">Project Tracker</CardTitle>
              <CardDescription>Set how project progress is presented in this workspace.</CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div>
                <p className="mb-1.5 text-sm font-medium">Preferred layout</p>
                <Select
                  value={current?.project_tracker_view ?? "cards"}
                  onValueChange={(project_tracker_view) => void update({ project_tracker_view })}
                >
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="cards">Project cards</SelectItem>
                    <SelectItem value="table">Table</SelectItem>
                  </SelectContent>
                </Select>
              </div>
              {isAdmin && (
                <ToggleRow
                  label="Lead digest"
                  description="Keep this department’s lead digest enabled."
                  checked={current?.lead_digest_enabled ?? true}
                  disabled={saving}
                  onCheckedChange={(lead_digest_enabled) => void update({ lead_digest_enabled })}
                />
              )}
            </CardContent>
          </Card>
        </div>
      </div>

      <div className="flex justify-end pt-2">
        <Button variant="outline" size="sm" disabled={saving} onClick={() => void preference.refetch()}>
          Refresh settings
        </Button>
      </div>
    </section>
  );
}

function ToggleRow({
  label,
  description,
  checked,
  disabled,
  onCheckedChange,
}: {
  label: string;
  description?: string;
  checked: boolean;
  disabled: boolean;
  onCheckedChange: (value: boolean) => void;
}) {
  return (
    <div className="flex items-center justify-between gap-3 border p-3 rounded-md">
      <div>
        <p className="text-sm font-medium">{label}</p>
        {description && <p className="mt-0.5 text-xs text-muted-foreground">{description}</p>}
      </div>
      <Switch checked={checked} disabled={disabled} onCheckedChange={onCheckedChange} />
    </div>
  );
}