/** @vitest-environment jsdom */

import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { createMemoryHistory, createRootRoute, createRoute, createRouter, RouterProvider } from "@tanstack/react-router";
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
  priority: "medium", status: "todo", assignee_id: "member-1", due_date: null, estimated_hours: null, logged_hours: null,
  ppap_element: null, drive_node_id: null, pcb_task_id: null, purchase_request_id: null, qms_capa_id: null, customer_complaint_id: null,
  sort_order: 1, created_by: null, created_at: "2026-10-09T00:00:00Z", updated_at: "2026-10-09T00:00:00Z",
  assignee: { id: "member-1", name: "Ada", email: "ada@example.test", department: "hardware", department_id: null },
  project: { id: "project-123", name: "Project One", code: "PROJECT-2026-0005", color: "blue" },
}];

function renderBoard(initialEntry: string, embedded: boolean) {
  fetchTasks.mockResolvedValue(tasks);
  const root = createRootRoute({ component: () => <RouterProvider router={router} /> });
  const globalTasks = createRoute({ getParentRoute: () => root, path: "/tasks", validateSearch: (search) => search as { assignee?: string; task?: string }, component: () => <TaskBoard /> });
  const projectTasks = createRoute({ getParentRoute: () => root, path: "/projects/$projectId", component: () => embedded ? <TaskBoard projectId="project-123" compact /> : null });
  const router = createRouter({ routeTree: root.addChildren([globalTasks, projectTasks]), history: createMemoryHistory({ initialEntries: [initialEntry] }) });
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  render(<QueryClientProvider client={client}><RouterProvider router={router} /></QueryClientProvider>);
  return router;
}

afterEach(() => {
  cleanup();
  fetchTasks.mockReset();
});

describe("TaskBoard route ownership", () => {
  it("opens and closes a project task without changing the embedded project route", async () => {
    const user = userEvent.setup();
    const router = renderBoard("/projects/project-123", true);
    await user.click(await screen.findByText("Project route task"));
    expect(router.state.location.pathname).toBe("/projects/project-123");
    expect(router.state.location.search).toEqual({});
    await user.click(screen.getByRole("button", { name: "Close task" }));
    expect(router.state.location.pathname).toBe("/projects/project-123");
    expect(router.state.location.search).toEqual({});
  });

  it("preserves standalone task deep links and clears only the assignee filter", async () => {
    const user = userEvent.setup();
    const router = renderBoard("/tasks?assignee=member-1&task=task-1", false);
    await screen.findByText("Clear assignee");
    expect(router.state.location.search).toEqual({ assignee: "member-1", task: "task-1" });
    await user.click(screen.getByRole("button", { name: "Clear assignee" }));
    await waitFor(() => expect(router.state.location.search).toEqual({ task: "task-1" }));
    expect(router.state.location.pathname).toBe("/tasks");
    expect(screen.getByRole("dialog")).toBeTruthy();
  });
});