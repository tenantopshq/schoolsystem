import { describe,expect,it,vi } from "vitest";
import { z } from "zod";
import { runReplaySafe,safeFailure,validationState } from "./action-support";

describe("student action safety",()=>{
  it.each(["40001","40P01"])("retries %s exactly once with a stable request id",async(code)=>{const operation=vi.fn().mockRejectedValueOnce({code}).mockResolvedValue("ok");await expect(runReplaySafe("request-1",operation,async()=>{})).resolves.toBe("ok");expect(operation.mock.calls).toEqual([["request-1"],["request-1"]]);});
  it("does not retry non-retryable failures",async()=>{const operation=vi.fn().mockRejectedValue({code:"42501",detail:"private"});await expect(runReplaySafe("request-2",operation,async()=>{})).rejects.toMatchObject({code:"42501"});expect(operation).toHaveBeenCalledOnce();});
  it("maps expected failures without leaking database details and preserves values",()=>{const values={firstName:"Submitted"};const result=safeFailure({code:"42501",message:"secret relation name"},values);expect(result).toMatchObject({status:"error",message:"You no longer have permission for this action.",values});expect(result.message).not.toContain("secret");});
  it("returns field errors while preserving submitted values",()=>{const parsed=z.object({firstName:z.string().min(2)}).safeParse({firstName:""});if(parsed.success)throw new Error("expected invalid fixture");expect(validationState(parsed.error,{firstName:""})).toMatchObject({status:"error",values:{firstName:""},fieldErrors:{firstName:expect.any(Array)}});});
});
