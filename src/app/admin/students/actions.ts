"use server";
import { revalidatePath } from "next/cache";
import { z } from "zod";
import { createStudentSchema,updateStudentSchema,archiveStudentSchema } from "@/modules/students";
import { SupabaseStudentService } from "@/modules/students/infrastructure/supabase-student-service";
import { resolveSelectedContextAuthorization } from "@/modules/organizations/application/context";
import { targetHasPermission } from "@/modules/organizations/application/scope";
import { runReplaySafe,safeFailure,validationState,type SafeActionState } from "@/modules/students/application/action-support";

export type StudentActionState=SafeActionState;
const text=(f:FormData,k:string)=>String(f.get(k)??"").trim();
const nullable=(f:FormData,k:string)=>text(f,k)||null;
const values=(f:FormData)=>Object.fromEntries([...f.entries()].filter((entry):entry is [string,string]=>typeof entry[1]==="string"&&entry[0]!=="requestId"));


export async function createStudent(_previous:StudentActionState,f:FormData):Promise<StudentActionState>{
  const submitted=values(f),requestId=text(f,"requestId");
  if(!z.string().uuid().safeParse(requestId).success)return{status:"error",message:"The form expired. Reload and try again.",fieldErrors:{},values:submitted};
  const parsed=createStudentSchema.safeParse({schoolId:text(f,"schoolId"),campusId:nullable(f,"campusId"),studentNumber:text(f,"studentNumber"),firstName:text(f,"firstName"),middleName:nullable(f,"middleName"),lastName:text(f,"lastName"),preferredName:nullable(f,"preferredName"),dateOfBirth:text(f,"dateOfBirth"),gender:nullable(f,"gender"),nationalityCode:nullable(f,"nationalityCode"),primaryLanguage:nullable(f,"primaryLanguage"),photoPath:null,admissionDate:nullable(f,"admissionDate"),exitDate:null,status:"active"});
  if(!parsed.success)return validationState(parsed.error,submitted);
  try{const authorization=await resolveSelectedContextAuthorization();if(!authorization||!authorization.selected.schoolId||!targetHasPermission(authorization.selected,authorization.contexts,{organizationId:authorization.selected.organizationId,schoolId:parsed.data.schoolId,campusId:parsed.data.campusId},"students.create"))throw{code:"42501"};const service=new SupabaseStudentService();const id=await runReplaySafe(requestId,stableId=>service.create(stableId,parsed.data));revalidatePath("/admin/students");return{status:"success",message:"Student created.",fieldErrors:{},values:{},resultId:id};}catch(error){return safeFailure(error,submitted);}
}
export async function updateStudent(_previous:StudentActionState,f:FormData):Promise<StudentActionState>{
  const submitted=values(f),requestId=text(f,"requestId");
  if(!z.string().uuid().safeParse(requestId).success)return{status:"error",message:"The form expired. Reload and try again.",fieldErrors:{},values:submitted};
  const parsed=updateStudentSchema.safeParse({id:text(f,"id"),studentNumber:text(f,"studentNumber"),firstName:text(f,"firstName"),middleName:nullable(f,"middleName"),setMiddleName:true,lastName:text(f,"lastName"),preferredName:nullable(f,"preferredName"),setPreferredName:true,dateOfBirth:text(f,"dateOfBirth"),gender:nullable(f,"gender"),setGender:true,nationalityCode:nullable(f,"nationalityCode"),setNationalityCode:true,primaryLanguage:nullable(f,"primaryLanguage"),setPrimaryLanguage:true,photoPath:null,setPhotoPath:false,admissionDate:nullable(f,"admissionDate"),setAdmissionDate:true,exitDate:nullable(f,"exitDate"),setExitDate:true,status:text(f,"status"),schoolId:null,setSchoolId:false,campusId:null,setCampusId:false});
  if(!parsed.success)return validationState(parsed.error,submitted);
  try{const service=new SupabaseStudentService(),[authorization,target]=await Promise.all([resolveSelectedContextAuthorization(),service.get(parsed.data.id)]);if(!authorization||!target||!targetHasPermission(authorization.selected,authorization.contexts,{organizationId:authorization.selected.organizationId,schoolId:target.schoolId,campusId:target.campusId},"students.edit"))throw{code:"42501"};const id=await runReplaySafe(requestId,stableId=>service.update(stableId,parsed.data));revalidatePath("/admin/students");revalidatePath(`/admin/students/${id}`);return{status:"success",message:"Student updated.",fieldErrors:{},values:{},resultId:id};}catch(error){return safeFailure(error,submitted);}
}
export async function archiveStudent(_previous:StudentActionState,f:FormData):Promise<StudentActionState>{
  const submitted=values(f),requestId=text(f,"requestId"),parsed=archiveStudentSchema.safeParse({targetStudentId:text(f,"id"),archiveReason:text(f,"reason")});
  if(!z.string().uuid().safeParse(requestId).success)return{status:"error",message:"The form expired. Reload and try again.",fieldErrors:{},values:submitted};
  if(!parsed.success)return validationState(parsed.error,submitted);
  try{const service=new SupabaseStudentService(),[authorization,target]=await Promise.all([resolveSelectedContextAuthorization(),service.get(parsed.data.targetStudentId)]);if(!authorization||!target||!targetHasPermission(authorization.selected,authorization.contexts,{organizationId:authorization.selected.organizationId,schoolId:target.schoolId,campusId:target.campusId},"students.archive"))throw{code:"42501"};const id=await runReplaySafe(requestId,stableId=>service.archive(stableId,parsed.data));revalidatePath("/admin/students");revalidatePath(`/admin/students/${id}`);return{status:"success",message:"Student archived.",fieldErrors:{},values:{},resultId:id};}catch(error){return safeFailure(error,submitted);}
}
