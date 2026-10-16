/** @vitest-environment jsdom */
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
const mocks=vi.hoisted(()=>({members:vi.fn(),update:vi.fn(),create:vi.fn(),toast:vi.fn()}));
vi.mock('@tanstack/react-router',()=>({Link:({children}:any)=><span>{children}</span>}));
vi.mock('sonner',()=>({toast:{success:vi.fn(),error:mocks.toast}}));
vi.mock('@/integrations/supabase/client',()=>({supabase:{from:()=>({select:()=>({order:()=>({limit:async()=>({data:[],error:null})})})})}}));
vi.mock('@/lib/projects',()=>({fetchProjects:async()=>[]}));
vi.mock('@/lib/tasks',()=>({TASK_PRIORITIES:[{value:'medium',label:'Medium'}],TASK_STATUSES:[{value:'in_review',label:'In review'},{value:'todo',label:'To do'}],fetchCanonicalDepartments:async()=>[{id:'dept-1',name:'Hardware & R&D',code:'RND'}],fetchTaskMembers:mocks.members,updateTask:mocks.update,createTask:mocks.create}));
import {TaskDialog} from './TaskDialog';
const task:any={id:'task-1',title:'Existing review',description:'Keep context',project_id:'project-1',department:'hardware',department_id:'dept-1',status:'in_review',priority:'medium',assignee_id:'member-1',due_date:'2026-10-20'};
function show(){const close=vi.fn();const client=new QueryClient({defaultOptions:{queries:{retry:false},mutations:{retry:false}}});render(<QueryClientProvider client={client}><TaskDialog open onOpenChange={close} task={task} projectId="project-1"/></QueryClientProvider>);return close;}
beforeEach(()=>{vi.clearAllMocks();mocks.update.mockResolvedValue({id:'task-1'});mocks.members.mockResolvedValue([{id:'member-1',name:'Example member'}]);});
afterEach(cleanup);
describe('shared task form integration',()=>{
 it('saves the due date through the existing update with identity and review state preserved',async()=>{const close=show();await screen.findByText('Example member');fireEvent.change(document.querySelector('input[type=date]')!,{target:{value:'2026-10-23'}});fireEvent.click(screen.getByRole('button',{name:'Save task'}));await waitFor(()=>expect(mocks.update).toHaveBeenCalledWith('task-1',expect.objectContaining({due_date:'2026-10-23',assignee_id:'member-1',department_id:'dept-1',project_id:'project-1',status:'in_review'})));await waitFor(()=>expect(close).toHaveBeenCalledWith(false));});
 it('does not close or signal success when the write is unconfirmed',async()=>{mocks.update.mockRejectedValue(new Error('Task update was not confirmed'));const close=show();fireEvent.click(await screen.findByRole('button',{name:'Save task'}));await waitFor(()=>expect(mocks.toast).toHaveBeenCalledWith('Task update was not confirmed'));expect(close).not.toHaveBeenCalled();});
 it('distinguishes member read failure from an empty team and keeps existing assignment',async()=>{mocks.members.mockRejectedValue(new Error('denied'));show();await screen.findByRole('alert');expect(screen.queryByText('Create an R&D member')).toBeNull();fireEvent.click(screen.getByRole('button',{name:'Save task'}));await waitFor(()=>expect(mocks.update).toHaveBeenCalledWith('task-1',expect.objectContaining({assignee_id:'member-1'})));});
 it('cancels without writing',async()=>{const close=show();fireEvent.click(screen.getByRole('button',{name:'Cancel'}));expect(close).toHaveBeenCalledWith(false);expect(mocks.update).not.toHaveBeenCalled();});
});
