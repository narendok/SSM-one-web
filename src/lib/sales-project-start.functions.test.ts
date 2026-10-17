import { describe, expect, it, vi } from "vitest";
vi.mock("@tanstack/react-start", () => ({ createServerFn: () => {
 let validate: (data: unknown) => unknown = data => data;
 const builder = { middleware: () => builder, inputValidator: (fn: typeof validate) => { validate=fn; return builder; }, handler: (fn: (input: unknown) => Promise<unknown>) => ({data,context}: {data:unknown;context:unknown}) => fn({data:validate(data),context}) };
 return builder;
} }));
vi.mock("@/integrations/supabase/auth-middleware",()=>({requireSupabaseAuth:{}}));
import { initiateSalesHandover } from "./sales.functions";
import { salesProjectStartAvailability } from "./sales-project-start";
const id="00000000-0000-4000-8000-000000000001";
const invoke=(data:unknown,context:unknown)=>(initiateSalesHandover as unknown as (input:{data:unknown;context:unknown})=>Promise<unknown>)({data,context});
describe("legacy project start fails closed",()=>{
 it("cannot create a handover, alter baseline status or append a success audit even for Sales manage",async()=>{
  const supabase={rpc:vi.fn().mockResolvedValue({data:true,error:null}),from:vi.fn(()=>{throw new Error("No table writes allowed");})};
  await expect(invoke({baselineId:id,handoverNotes:null},{userId:id,supabase})).rejects.toThrow(salesProjectStartAvailability.reason);
  expect(supabase.rpc).toHaveBeenCalledTimes(1);
  expect(supabase.rpc).toHaveBeenCalledWith("has_permission",{_user_id:id,_permission_key:"sales.manage"});
  expect(supabase.from).not.toHaveBeenCalled();
  expect(salesProjectStartAvailability.available).toBe(false);
 });
 it.each([{data:false,error:null},{data:null,error:{message:"denied"}}])("retains permission denial without mutations",async result=>{
  const supabase={rpc:vi.fn().mockResolvedValue(result),from:vi.fn()};
  await expect(invoke({baselineId:id,handoverNotes:null},{userId:id,supabase})).rejects.toThrow("do not have permission");
  expect(supabase.from).not.toHaveBeenCalled();
 });
 it("rejects malformed identity before any backend call",async()=>{
  const supabase={rpc:vi.fn(),from:vi.fn()};
  expect(() => invoke({baselineId:"invalid",handoverNotes:null},{userId:id,supabase})).toThrow();
  expect(supabase.rpc).not.toHaveBeenCalled();expect(supabase.from).not.toHaveBeenCalled();
 });
});
