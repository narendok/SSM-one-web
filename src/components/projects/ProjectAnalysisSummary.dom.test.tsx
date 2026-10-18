/** @vitest-environment jsdom */
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { cleanup, render, screen, waitFor } from "@testing-library/react";
import { afterEach, expect, it, vi } from "vitest";
import { ProjectAnalysisSummary } from "./ProjectAnalysisSummary";
import type { Project } from "@/lib/projects";
const reads = vi.hoisted(() => ({ tasks: vi.fn(), departments: vi.fn() }));
vi.mock("@/lib/tasks", async importOriginal => ({ ...await importOriginal<typeof import("@/lib/tasks")>(), fetchTasks: reads.tasks, fetchCanonicalDepartments: reads.departments }));
vi.mock("./ProjectOperationalTabs", () => ({ ProjectRequirementContext: () => <p>Linked baseline context</p> }));
const project = { id: "project-one", project_stage: "PILOT", health_status: "GREEN", priority: "medium", requirement_baseline_id: null } as Project;
function mount(record = project) { return render(<QueryClientProvider client={new QueryClient({ defaultOptions: { queries: { retry: false } } })}><ProjectAnalysisSummary project={record} /></QueryClientProvider>); }
afterEach(() => { cleanup(); vi.clearAllMocks(); });
it("groups by canonical department and preserves the same task identity and review status", async () => {
  reads.departments.mockResolvedValue([{ id: "dep-1", name: "Hardware" }, { id: "dep-2", name: "Software" }]);
  reads.tasks.mockResolvedValue([{ id: "t1", title: "Review pinout", department_id: "dep-1", department: "software", status: "in_review", assignee_id: null, due_date: "2026-10-20" }]);
  mount(); await screen.findByText(/Hardware/);
  expect(screen.getByText(/Hardware/).textContent).toContain("1 visible tasks");
  expect(screen.getByText(/Software/).textContent).toContain("0 visible tasks");
  expect(screen.getAllByText(/In review/).length).toBeGreaterThan(0);
  expect(reads.tasks).toHaveBeenCalledWith("project-one");
  expect(screen.queryByRole("button", { name: /Save|Publish|Approve/ })).toBeNull();
});
it("does not turn denied task reads into zero blockers or empty department work", async () => {
  reads.departments.mockResolvedValue([{ id: "dep-1", name: "Hardware" }]); reads.tasks.mockRejectedValue(new Error("denied"));
  mount(); await waitFor(() => expect(screen.getByRole("alert").textContent).toContain("summaries unavailable"));
  expect(screen.queryByText("No blocked tasks visible")).toBeNull(); expect(screen.queryByText("No visible project tasks.")).toBeNull();
});
it("does not infer department scope for unclassified tasks", async () => {
  reads.departments.mockResolvedValue([{ id: "dep-1", name: "Hardware" }]); reads.tasks.mockResolvedValue([{ id: "t1", title: "Unclassified", department_id: null, department: "hardware", status: "blocked", assignee_id: null }]);
  mount(); await screen.findByText(/Tasks without a canonical department/);
  expect(screen.getByText(/Hardware/).textContent).toContain("0 visible tasks");
  expect(screen.getAllByText("Unclassified")).toHaveLength(2);
});



it("shows recorded project context and permits only ordinary external design references", async () => {
  reads.departments.mockResolvedValue([]); reads.tasks.mockResolvedValue([]);
  mount({ ...project, project_type: "CUSTOM_PROJECT", revision: "TEST-01", design_link: "https://example.com/design/revision-1" });
  expect(screen.getByText("CUSTOM PROJECT · Revision TEST-01")).toBeTruthy();
  const reference = screen.getByRole("link", { name: "Open design reference" });
  expect(reference.getAttribute("href")).toBe("https://example.com/design/revision-1");
  expect(reference.getAttribute("rel")).toBe("noopener noreferrer");
});
it.each(["javascript:alert(1)", "data:text/html,test", "https://user:password@example.com/design", "", "/internal-path"])("does not turn an unsupported recorded design URL into a link: %s", design_link => {
  reads.departments.mockResolvedValue([]); reads.tasks.mockResolvedValue([]);
  mount({ ...project, revision: null, design_link });
  expect(screen.queryByRole("link", { name: "Open design reference" })).toBeNull();
  expect(screen.getByText("Design reference unavailable")).toBeTruthy();
  expect(screen.getByText(/Revision not recorded/)).toBeTruthy();
});
