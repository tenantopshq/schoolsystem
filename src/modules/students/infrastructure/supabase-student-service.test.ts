import { describe,expect,it,vi } from "vitest";
import { SupabaseStudentService,callStudentRpc } from "./supabase-student-service";

const organizationId="10000000-0000-4000-8000-000000000001",schoolId="20000000-0000-4000-8000-000000000001",campusId="30000000-0000-4000-8000-000000000001";
const context={organizationId,schoolId,campusId};
const query={q:"",status:"active" as const,school:schoolId,campus:campusId,sort:"name" as const,dir:"asc" as const,after:null};
const row=(index:number,total=30)=>({student_id:`40000000-0000-4000-8000-${String(index).padStart(12,"0")}`,student_number:`S-${index}`,first_name:"First",last_name:`Last ${index}`,preferred_name:null,status:"active",school_id:schoolId,school_name:"School",campus_id:campusId,campus_name:"Campus",updated_at:"2026-01-01T00:00:00.000Z",sort_cursor_value:`last ${index}`,total_count:total});

describe("Supabase student boundary",()=>{
  it("rejects invalid and mismatched cursors",async()=>{const rpc=vi.fn().mockResolvedValue([]) as unknown as typeof callStudentRpc;const service=new SupabaseStudentService(rpc);await expect(service.search(context,{...query,after:"not-a-cursor"})).rejects.toThrow("INVALID_CURSOR");const firstRpc=vi.fn().mockResolvedValue(Array.from({length:26},(_,i)=>row(i+1))) as unknown as typeof callStudentRpc;const first=await new SupabaseStudentService(firstRpc).search(context,query);await expect(service.search(context,{...query,sort:"updated",after:first.nextCursor})).rejects.toThrow("INVALID_CURSOR");});
  it("retains total count when a later cursor page is empty",async()=>{const firstRpc=vi.fn().mockResolvedValue(Array.from({length:26},(_,i)=>row(i+1,30))) as unknown as typeof callStudentRpc;const first=await new SupabaseStudentService(firstRpc).search(context,query);const laterRpc=vi.fn().mockResolvedValueOnce([]).mockResolvedValueOnce([row(1,30)]) as unknown as typeof callStudentRpc;const later=await new SupabaseStudentService(laterRpc).search(context,{...query,after:first.nextCursor});expect(later).toMatchObject({items:[],totalCount:30,nextCursor:null});expect(laterRpc).toHaveBeenCalledTimes(2);});
  it("rejects malformed RPC results at the infrastructure boundary",async()=>{const rpc=vi.fn().mockResolvedValue([{student_id:"private malformed row"}]) as unknown as typeof callStudentRpc;await expect(new SupabaseStudentService(rpc).search(context,query)).rejects.toThrow();});
});
