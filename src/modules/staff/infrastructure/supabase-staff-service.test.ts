import { describe,expect,it,vi } from "vitest";
import { SupabaseStaffService } from "./supabase-staff-service";

const context={membershipId:"10000000-0000-4000-8000-000000000001",organizationId:"20000000-0000-4000-8000-000000000001",organizationName:"School Org",organizationSlug:"school-org",schoolId:null,schoolName:null,schoolCode:null,campusId:null,campusName:null,campusCode:null,scopeLevel:"organization" as const,permissionCodes:["staff_profiles.manage"]};
const row=(access_state:"no_access"|"active",organization_membership_id:string|null)=>({staff_profile_id:crypto.randomUUID(),staff_number:"S1",first_name:"Ada",middle_name:null,last_name:"Lovelace",display_name:null,work_email:"ada@school.test",phone:null,access_state,organization_membership_id,job_title:"Teacher",department:null,employment_type:"employee",status:"active" as const,school_id:null,school_name:null,campus_id:null,campus_name:null,updated_at:"2026-11-06T00:00:00.000Z",sort_cursor_value:"ada",total_count:2});

describe("SupabaseStaffService v1.7",()=>{
  it("maps linked and unlinked access state from the typed read RPC",async()=>{
    const linked="30000000-0000-4000-8000-000000000001";
    const rpc=vi.fn().mockResolvedValue([row("no_access",null),row("active",linked)]);
    const page=await new SupabaseStaffService(rpc as never).search(context,{q:"",status:"active",after:null});
    expect(page.items.map(item=>[item.accessState,item.organizationMembershipId])).toEqual([["no_access",null],["active",linked]]);
  });

  it("sends staff-owned identity and an optional null membership on create",async()=>{
    const rpc=vi.fn().mockResolvedValue("40000000-0000-4000-8000-000000000001");
    await new SupabaseStaffService(rpc as never).create("50000000-0000-4000-8000-000000000001",context,{membershipId:null,schoolId:null,campusId:null,firstName:"Ada",middleName:null,lastName:"Lovelace",displayName:null,workEmail:"ada@school.test",phone:null,staffNumber:"S1",employmentType:"employee",jobTitle:null,department:null,hireDate:null,status:"active"});
    expect(rpc).toHaveBeenCalledWith("create_staff_profile_v1_7",expect.objectContaining({organization_id:context.organizationId,membership_id:null,first_name:"Ada",work_email:"ada@school.test"}));
  });
});
