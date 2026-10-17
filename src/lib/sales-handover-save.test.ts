import { describe, expect, it, vi } from "vitest";
import { handoverOutcomeUncertain, submitSalesHandoverAcknowledgement } from "./sales-handover-save";
const id = (n: number) => `00000000-0000-4000-8000-${String(n).padStart(12,"0")}`;
const input = { enquiryId:id(1), opportunityId:id(2), customerId:id(3), masterSpecificationVersionId:id(4), expectedEnquiryUpdatedAt:"2026-10-15T00:00:00Z", requestKey:id(5), title:"Feasibility", customerReference:null, summary:null, teams:[{departmentId:id(6),reviewerUserId:id(7)},{departmentId:id(8),reviewerUserId:id(9)}] };
const receipt = {requirement_id:id(10),review_ids:[id(11),id(12)],replayed:false};
describe("handover acknowledgement safeguards",()=>{
  it.each([false,true])("preserves a complete acknowledgement and replay=%s",async replayed=>{
    const rpc=vi.fn().mockResolvedValue({data:[{...receipt,replayed}],error:null});
    expect(await submitSalesHandoverAcknowledgement({rpc},input)).toEqual({...receipt,replayed});
    expect(rpc).toHaveBeenCalledTimes(1);
    expect(rpc.mock.calls[0][1].p_request_key).toBe(input.requestKey);
  });
  it.each([[],[receipt,receipt],[{...receipt,review_ids:[id(11)]}],[{...receipt,review_ids:[id(11),id(11)]}],[{...receipt,review_ids:[id(10),id(12)]}]].map(data => ({data})))("does not confirm an incomplete or contradictory acknowledgement %j",async ({data})=>{
    const rpc=vi.fn().mockResolvedValue({data,error:null});
    await expect(submitSalesHandoverAcknowledgement({rpc},input)).rejects.toThrow(handoverOutcomeUncertain);
    expect(rpc).toHaveBeenCalledTimes(1);
  });
  it.each([{}, {code:"08006",message:"connection lost"}])("treats unproven server outcomes as uncertain",async error=>{
    const rpc=vi.fn().mockResolvedValue({data:null,error});
    await expect(submitSalesHandoverAcknowledgement({rpc},input)).rejects.toThrow(handoverOutcomeUncertain);
    expect(rpc).toHaveBeenCalledTimes(1);
  });
  it("does not retry a lost response",async()=>{
    const rpc=vi.fn().mockRejectedValue(new Error("network"));
    await expect(submitSalesHandoverAcknowledgement({rpc},input)).rejects.toThrow(handoverOutcomeUncertain);
    expect(rpc).toHaveBeenCalledTimes(1);
  });
  it("preserves explicit transactional denial",async()=>{
    const rpc=vi.fn().mockResolvedValue({data:null,error:{code:"42501",message:"Assignment denied"}});
    await expect(submitSalesHandoverAcknowledgement({rpc},input)).rejects.toThrow("Assignment denied");
  });
  it("rejects invalid source scope before contacting the backend",async()=>{
    const rpc=vi.fn();
    await expect(submitSalesHandoverAcknowledgement({rpc},{...input,requestKey:"invalid"})).rejects.toThrow();
    expect(rpc).not.toHaveBeenCalled();
  });
});
