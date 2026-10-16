import { beforeEach, describe, expect, it, vi } from 'vitest';
const mocks = vi.hoisted(() => ({ from: vi.fn(), getUser: vi.fn() }));
vi.mock('@/integrations/supabase/client', () => ({ supabase: { from: mocks.from, auth: { getUser: mocks.getUser } } }));
import { createTask, updateTask, fetchTaskMembers, fetchTasks } from './tasks';
const result = vi.fn();
const select = vi.fn(() => ({ single: result, maybeSingle: result }));
const eq = vi.fn(() => ({ select }));
const update = vi.fn(() => ({ eq }));
const insert = vi.fn(() => ({ select }));
beforeEach(() => { vi.clearAllMocks(); mocks.from.mockReturnValue({ update, insert }); mocks.getUser.mockResolvedValue({ data: { user: { id: 'actor' } }, error: null }); });
describe('task mutation acknowledgements', () => {
 it('rejects a zero-row update rather than reporting saved', async () => { result.mockResolvedValue({ data: null, error: null }); await expect(updateTask('task-1', { status: 'in_review' })).rejects.toThrow('not confirmed'); });
 it('returns the acknowledged task and strips joined display fields', async () => { result.mockResolvedValue({ data: { id: 'task-1' }, error: null }); await expect(updateTask('task-1', { due_date: '2026-10-23', assignee: null })).resolves.toEqual({ id: 'task-1' }); expect(update).toHaveBeenCalledWith({ due_date: '2026-10-23' }); expect(eq).toHaveBeenCalledWith('id', 'task-1'); });
 it('propagates backend denial', async () => { result.mockResolvedValue({ data: null, error: new Error('denied') }); await expect(updateTask('task-1', { priority: 'high' })).rejects.toThrow('denied'); });
 it('does not insert without an authenticated actor', async () => { mocks.getUser.mockResolvedValue({ data: { user: null }, error: null }); await expect(createTask({ title: 'Example' })).rejects.toThrow('Sign in'); expect(insert).not.toHaveBeenCalled(); });
 it('requires a returned creation identity and pins the authenticated actor', async () => { result.mockResolvedValue({ data: { id: 'new-task' }, error: null }); await expect(createTask({ title: 'Example', created_by: 'spoof' })).resolves.toEqual({ id: 'new-task' }); expect(insert).toHaveBeenCalledWith({ title: 'Example', created_by: 'actor' }); });
 it('rejects an unconfirmed creation', async () => { result.mockResolvedValue({ data: null, error: null }); await expect(createTask({ title: 'Example' })).rejects.toThrow('not confirmed'); });
});

describe('task member catalogue', () => {
 it('propagates denied reads instead of returning an empty team', async () => {
   mocks.from.mockReturnValue({ select: () => ({ eq: () => ({ order: async () => ({ data: null, error: new Error('member read denied') }) }) }) });
   await expect(fetchTaskMembers()).rejects.toThrow('member read denied');
 });
 it('returns permitted member identities', async () => {
   mocks.from.mockReturnValue({ select: () => ({ eq: () => ({ order: async () => ({ data: [{ id: 'member-1', name: 'Example' }], error: null }) }) }) });
   await expect(fetchTaskMembers()).resolves.toEqual([{ id: 'member-1', name: 'Example' }]);
 });
});
describe('department task reads', () => {
 it('binds project and canonical department to the existing caller query', async () => {
   const query: any = { order: vi.fn(), eq: vi.fn(), then: (resolve: any) => resolve({ data: [], error: null }) };
   query.order.mockReturnValue(query); query.eq.mockReturnValue(query);
   mocks.from.mockReturnValue({ select: () => query });
   await expect(fetchTasks('project-1', 'department-1')).resolves.toEqual([]);
   expect(query.eq.mock.calls).toEqual([['project_id', 'project-1'], ['department_id', 'department-1']]);
 });
 it('preserves common task reads without inventing a department', async () => {
   const query: any = { order: vi.fn(), eq: vi.fn(), then: (resolve: any) => resolve({ data: [], error: null }) };
   query.order.mockReturnValue(query); query.eq.mockReturnValue(query);
   mocks.from.mockReturnValue({ select: () => query });
   await fetchTasks('project-1');
   expect(query.eq.mock.calls).toEqual([['project_id', 'project-1']]);
 });
});