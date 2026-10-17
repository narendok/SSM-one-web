/** @vitest-environment jsdom */
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { render, screen, cleanup } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { DepartmentsPage } from "@/routes/_authenticated/tasks.departments";
const mocks=vi.hoisted(()=>({departments:vi.fn(),tasks:vi.fn(),members:vi.fn()}));
vi.mock("@tanstack/react-router",()=>({createFileRoute:()=>()=>({}),Link:({children}:any)=><a>{children}</a>}));
vi.mock("@/lib/tasks",async()=>({...await vi.importActual<typeof import("@/lib/tasks")>("@/lib/tasks"),fetchCanonicalDepartments:mocks.departments,fetchTasks:mocks.tasks}));
vi.mock("@/integrations/supabase/client",()=>({supabase:{from:()=>({select:()=>({order:()=>mocks.members()})})}}));
const mount=()=>render(<QueryClientProvider client={new QueryClient({defaultOptions:{queries:{retry:false}}})}><DepartmentsPage /></QueryClientProvider>);
beforeEach(()=>{mocks.departments.mockResolvedValue([{id:"canonical-1",name:"Operations",code:"OPS",aliases:[]},{id:"canonical-2",name:"Engineering",code:"ENG",aliases:[]}]);mocks.tasks.mockResolvedValue([{department_id:"canonical-1",department:"hardware",status:"in_review"},{department_id:null,department:"hardware",status:"todo"}]);mocks.members.mockResolvedValue({data:[{id:"member-1",name:"Assigned engineer",department_id:"canonical-2",department:"hardware"}],error:null});});
afterEach(()=>{cleanup();vi.clearAllMocks();});
describe("canonical department workload projection",()=>{
 it("uses canonical IDs despite conflicting legacy labels and retains in_review",async()=>{mount();await screen.findByText("In review: 1");expect(screen.getByText("1 tasks")).toBeTruthy();expect(screen.getByText("Assigned engineer")).toBeTruthy();expect(screen.getByText("Tasks without a canonical department are excluded from these totals.")).toBeTruthy();});
 it("does not show denied task reads as zero workload",async()=>{mocks.tasks.mockRejectedValue(new Error("denied"));mount();await screen.findByText("Task workload could not be loaded. Counts are unavailable.");expect(screen.queryByText("0 tasks")).toBeNull();expect(screen.getAllByText("Tasks unavailable")).toHaveLength(2);});
 it("does not treat failed member reads as an invitation to create a member",async()=>{mocks.members.mockResolvedValue({data:null,error:{message:"denied"}});mount();await screen.findByText("Responsible member records could not be loaded.");expect(screen.getAllByText("Members unavailable")).toHaveLength(2);expect(screen.queryByText("Create a responsible member")).toBeNull();});
 it("does not fall back to seven legacy department groups on canonical read failure",async()=>{mocks.departments.mockRejectedValue(new Error("denied"));mount();await screen.findByText("Department records could not be loaded.");expect(screen.queryByText("Operations")).toBeNull();expect(screen.queryByText("Hardware")).toBeNull();});
});
