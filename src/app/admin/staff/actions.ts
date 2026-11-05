"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { resolveSelectedContextAuthorization } from "@/modules/organizations/application/context";
import { targetHasPermission } from "@/modules/organizations/application/scope";
import { archiveStaffProfileSchema,createStaffProfileSchema,updateStaffProfileSchema } from "@/modules/staff";
import { SupabaseStaffService } from "@/modules/staff/infrastructure/supabase-staff-service";
import { errorCode,runReplaySafe,validationState,type SafeActionState } from "@/modules/students/application/action-support";

export type StaffActionState=SafeActionState;
const text=(form:FormData,key:string)=>String(form.get(key)??"").trim();
const nullable=(form:FormData,key:string)=>text(form,key)||null;
const values=(form:FormData)=>Object.fromEntries([...form.entries()].filter((entry):entry is [string,string]=>typeof entry[1]==="string"&&entry[0]!=="requestId"));
const expired=(submitted:Record<string,string>):StaffActionState=>({status:"error",message:"The form expired. Reload and try again.",fieldErrors:{},values:submitted});
function safeStaffFailure(error:unknown,submitted:Record<string,string>):StaffActionState{const code=errorCode(error);const message=code==="42501"?"You no longer have permission for this action.":code==="23505"?"That staff number or membership already has a staff profile.":code==="23503"?"This staff profile cannot be archived while active related records remain.":code==="P0002"?"This member or staff profile is no longer available.":code==="22023"?"The requested change is not valid for the current staff profile.":"The action could not be completed. Try again or contact support.";return{status:"error",message,fieldErrors:{},values:submitted};}

export async function createStaffProfile(_previous:StaffActionState,form:FormData):Promise<StaffActionState>{
  const submitted=values(form),requestId=text(form,"requestId");
  if(!z.string().uuid().safeParse(requestId).success)return expired(submitted);
  const parsed=createStaffProfileSchema.safeParse({membershipId:text(form,"membershipId"),schoolId:nullable(form,"schoolId"),campusId:nullable(form,"campusId"),staffNumber:text(form,"staffNumber"),employmentType:text(form,"employmentType"),jobTitle:nullable(form,"jobTitle"),department:nullable(form,"department"),hireDate:nullable(form,"hireDate"),status:"active"});
  if(!parsed.success)return validationState(parsed.error,submitted);
  try{const authorization=await resolveSelectedContextAuthorization();if(!authorization||!targetHasPermission(authorization.selected,authorization.contexts,{organizationId:authorization.selected.organizationId,schoolId:parsed.data.schoolId,campusId:parsed.data.campusId},"staff_profiles.manage"))throw{code:"42501"};const id=await runReplaySafe(requestId,stable=>new SupabaseStaffService().create(stable,parsed.data));revalidatePath("/admin/staff");return{status:"success",message:"Staff profile created.",fieldErrors:{},values:{},resultId:id};}catch(error){return safeStaffFailure(error,submitted);}
}

export async function updateStaffProfile(_previous:StaffActionState,form:FormData):Promise<StaffActionState>{
  const submitted=values(form),requestId=text(form,"requestId");
  if(!z.string().uuid().safeParse(requestId).success)return expired(submitted);
  const parsed=updateStaffProfileSchema.safeParse({id:text(form,"id"),staffNumber:text(form,"staffNumber"),employmentType:text(form,"employmentType"),jobTitle:nullable(form,"jobTitle"),department:nullable(form,"department"),hireDate:nullable(form,"hireDate"),terminationDate:nullable(form,"terminationDate"),status:text(form,"status")});
  if(!parsed.success)return validationState(parsed.error,submitted);
  try{const service=new SupabaseStaffService();const authorization=await resolveSelectedContextAuthorization();if(!authorization)throw{code:"42501"};const target=await service.get(authorization.selected,parsed.data.id);if(!target||!targetHasPermission(authorization.selected,authorization.contexts,{organizationId:authorization.selected.organizationId,schoolId:target.schoolId,campusId:target.campusId},"staff_profiles.manage"))throw{code:"42501"};const id=await runReplaySafe(requestId,stable=>service.update(stable,parsed.data));revalidatePath("/admin/staff");revalidatePath(`/admin/staff/${id}`);return{status:"success",message:"Staff profile updated.",fieldErrors:{},values:{},resultId:id};}catch(error){return safeStaffFailure(error,submitted);}
}

export async function archiveStaffProfile(_previous:StaffActionState,form:FormData):Promise<StaffActionState>{
  const submitted=values(form),requestId=text(form,"requestId");
  if(!z.string().uuid().safeParse(requestId).success)return expired(submitted);
  const parsed=archiveStaffProfileSchema.safeParse({targetStaffProfileId:text(form,"id"),archiveReason:text(form,"reason")});
  if(!parsed.success)return validationState(parsed.error,submitted);
  try{const service=new SupabaseStaffService();const authorization=await resolveSelectedContextAuthorization();if(!authorization)throw{code:"42501"};const target=await service.get(authorization.selected,parsed.data.targetStaffProfileId);if(!target||!targetHasPermission(authorization.selected,authorization.contexts,{organizationId:authorization.selected.organizationId,schoolId:target.schoolId,campusId:target.campusId},"staff_profiles.manage"))throw{code:"42501"};const id=await runReplaySafe(requestId,stable=>service.archive(stable,parsed.data));revalidatePath("/admin/staff");revalidatePath(`/admin/staff/${id}`);return{status:"success",message:"Staff profile archived.",fieldErrors:{},values:{},resultId:id};}catch(error){return safeStaffFailure(error,submitted);}
}
