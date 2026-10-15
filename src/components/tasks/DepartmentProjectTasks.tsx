import { TaskBoard } from './TaskBoard';

/** Caller supplies verified context. This component never resolves or grants membership. */
export function DepartmentProjectTasks({ projectId, departmentId }: {
  projectId: string;
  departmentId: string;
}) {
  if (!projectId || !departmentId) return <p>Project and verified department context are required.</p>;
  return <TaskBoard key={`${projectId}:${departmentId}`} projectId={projectId} departmentId={departmentId} initialView="board" compact />;
}