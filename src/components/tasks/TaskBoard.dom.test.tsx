/** @vitest-environment jsdom */

import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { createMemoryHistory, createRootRoute, createRoute, createRouter, Outlet, RouterProvider } from "@tanstack/react-router";
import { cleanup, render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";
import { TaskBoard } from "./TaskBoard";

const fetchTasks = vi.fn();

vi.mock("@/lib/tasks", async () => {
  const actual = await vi.importActual<typeof import("@/lib/tasks")>("@/lib/tasks");
  return { ...actual, fetchTasks: (...args: unknown[]) => fetchTasks(...args) };
});

vi.mock("./TaskDialog", () => ({ TaskDialog: () => null }));
vi.mock("./TaskDrawer", () => ({
  TaskDrawer: ({ task, onOpenChange }: { task: { title: string } | null; onOpenChange: (open: boolean) => void }) => task ? <div role="dialog"><span>{task.title}</span><button onClick={() => onOpenChange(false)}>Close task</button></div> : null,
}));

const tasks = [{
  id: "task-1", title: "Project route task", description: null, project_id: "project-123", department: "hardware", department_id: null,
  priority: "medium", status: "todo", assignee_id: "member-1", due_date: "2026-10-18", estimated_hours: null, logged_hours: null,
  ppap_element: null, drive_node_id: null, pcb_task_id: null, purchase_request_id: null, qms_capa_id: null, customer_complaint_id: null,
  sort_order: 1, created_by: null, created_at: "2026-10-09T00:00:00Z", updated_at: "2026-10-09T00:00:00Z",
  assignee: { id: "member-1", name: "Ada", email: "ada@example.test", department: "hardware", department_id: null },
  project: { id: "project-123", name: "Project One", code: "PROJECT-2026-0005", color: "blue" },
}];

function renderBoard(initialEntry: string, embedded: boolean, setupFetch: () => void = () => fetchTasks.mockResolvedValue(tasks), departmentId?: string) {
  setupFetch();
  const root = createRootRoute({ component: Outlet });
  const authenticated = createRoute({ getParentRoute: () => root, id: "_authenticated", component: Outlet });
  const tasksLayout = createRoute({ getParentRoute: () => authenticated, path: "tasks", component: Outlet });
  const globalTasks = createRoute({ getParentRoute: () => tasksLayout, path: "/", validateSearch: (search) => search as { assignee?: string; task?: string }, component: () => <TaskBoard /> });
  const projectTasks = createRoute({ getParentRoute: () => root, path: "projects/$projectId", component: () => embedded ? <TaskBoard projectId="project-123" compact departmentId={departmentId} /> : null });
  const router = createRouter({ routeTree: root.addChildren([authenticated.addChildren([tasksLayout.addChildren([globalTasks])]), projectTasks]), history: createMemoryHistory({ initialEntries: [initialEntry] }) });
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  render(<QueryClientProvider client={client}><RouterProvider router={router} /></QueryClientProvider>);
  return { client, router };
}

afterEach(() => {
  cleanup();
  fetchTasks.mockReset();
});

describe("TaskBoard route ownership", () => {
  it("opens and closes a project task without changing the embedded project route", async () => {
    const user = userEvent.setup();
    const { router } = renderBoard("/projects/project-123", true);
    await user.click((await screen.findAllByText("Project route task"))[1]);
    expect(router.state.location.pathname).toBe("/projects/project-123");
    expect(router.state.location.search).toEqual({});
    await user.click(screen.getByRole("button", { name: "Close task" }));
    expect(router.state.location.pathname).toBe("/projects/project-123");
    expect(router.state.location.search).toEqual({});
  });

  it("preserves standalone task deep links and clears only the assignee filter", async () => {
    const user = userEvent.setup();
    const { router } = renderBoard("/tasks?assignee=member-1&task=task-1", false);
    await screen.findByText("Clear assignee");
    expect(router.state.location.search).toEqual({ assignee: "member-1", task: "task-1" });
    await user.click(screen.getByRole("button", { name: "Clear assignee" }));
    await waitFor(() => expect(router.state.location.search).toEqual({ task: "task-1" }));
    expect(router.state.location.pathname).toBe("/tasks");
  });
});

describe("TaskBoard task reads", () => {
  it("summarizes only visible project task statuses, assignees, and due dates", async () => {
    renderBoard("/projects/project-123", true);

    expect((await screen.findAllByText("Visible project tasks")).length).toBeGreaterThan(0);
    expect(screen.getByText("1 task currently visible to you.")).toBeTruthy();
    expect(screen.getByText("To do: 1")).toBeTruthy();
    expect(screen.getByText("In progress: 0")).toBeTruthy();
    expect(screen.getAllByText("Ada").length).toBeGreaterThan(0);
    expect(screen.getByText("Due 2026-10-18")).toBeTruthy();
  });

  it("keeps an accessible project empty state distinct from a failed task read", async () => {
    renderBoard("/projects/project-123", true, () => fetchTasks.mockResolvedValue([]));

    expect(await screen.findByText("No project tasks are currently visible to you.")).toBeTruthy();
    expect(screen.queryByText("Project task summary unavailable")).toBeNull();
  });

  it("shows an initial read failure without an empty task count or empty-state message, then retries successfully", async () => {
    const user = userEvent.setup();
    renderBoard("/tasks", false, () => {
      fetchTasks.mockRejectedValueOnce(new Error("Read unavailable")).mockResolvedValueOnce(tasks);
    });

    expect((await screen.findByRole("alert")).textContent).toContain("These records could not be loaded. Read unavailable");
    expect(screen.queryByText("0 tasks")).toBeNull();
    expect(screen.queryByText("No tasks match.")).toBeNull();

    await user.click(screen.getByRole("button", { name: "Retry" }));

    expect((await screen.findByText("Project route task")).textContent).toBe("Project route task");
    expect(screen.queryByRole("alert")).toBeNull();
    expect(screen.getByText("1 task")).toBeTruthy();
  });

  it("shows a project summary failure without presenting an empty project state", async () => {
    renderBoard("/projects/project-123", true, () => fetchTasks.mockRejectedValue(new Error("Read unavailable")));

    expect(await screen.findByText("Project task summary unavailable")).toBeTruthy();
    expect(screen.getByText("Visible project tasks could not be loaded. Read unavailable")).toBeTruthy();
    expect(screen.queryByText("No project tasks are currently visible to you.")).toBeNull();
  });

  it("keeps cached tasks visible when a refresh fails", async () => {
    const { client } = renderBoard("/tasks", false, () => {
      fetchTasks.mockResolvedValueOnce(tasks).mockRejectedValueOnce(new Error("Refresh unavailable"));
    });

    expect((await screen.findByText("Project route task")).textContent).toBe("Project route task");

    await client.invalidateQueries({ queryKey: ["project_tasks", "all"] });

    await waitFor(() => expect(screen.getByRole("alert").textContent).toContain("These records could not be refreshed. Refresh unavailable"));
    expect(screen.getByText("Project route task")).toBeTruthy();
    expect(screen.getByText("1 task · refresh failed")).toBeTruthy();
  });
});
describe('TaskBoard canonical department scope', () => {
  it('excludes other and unassigned departments from the project workspace and summary', async () => {
    renderBoard('/projects/project-123', true, () => fetchTasks.mockResolvedValue([
      { ...tasks[0], department_id: 'department-hardware', title: 'Hardware scoped work' },
      { ...tasks[0], id: 'other', department_id: 'department-production', title: 'Other department work' },
      { ...tasks[0], id: 'legacy', department_id: null, title: 'Unresolved department work' },
    ]), 'department-hardware');
    await screen.findAllByText('Hardware scoped work');
    expect(screen.queryByText('Other department work')).toBeNull();
    expect(screen.queryByText('Unresolved department work')).toBeNull();
    expect(fetchTasks).toHaveBeenCalledWith('project-123');
  });
});