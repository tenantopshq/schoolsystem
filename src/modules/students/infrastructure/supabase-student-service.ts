import type { PostgrestError } from "@supabase/supabase-js";
import { z } from "zod";
import type { Database } from "@/platform/database/database.types";
import { createSupabaseServerClient } from "@/platform/database/supabase-server";
import {
  studentAdminDetailSchema,
  studentDirectoryItemSchema,
  studentDocumentMetadataSchema,
  studentEnrollmentSchema,
  studentGuardianLinkSchema,
  type ArchiveStudentInput,
  type CreateStudentInput,
  type ReplaySafeStudentCommandService,
  type StudentAdminDetail,
  type StudentDirectoryPage,
  type StudentDirectoryQuery,
  type StudentReadService,
  type UpdateStudentInput,
} from "../index";

type Functions = Database["public"]["Functions"];
type V13RpcName = "search_students" | "get_student_admin_detail" | "create_student_v1_3" | "update_student_v1_3" | "archive_student_v1_3";
type SearchArgs = Omit<Functions["search_students"]["Args"], "p_status"> & { p_status: Database["public"]["Enums"]["record_status"] | null };
type CreateArgs=Omit<Functions["create_student_v1_3"]["Args"],"campus_id"|"middle_name"|"preferred_name"|"gender"|"nationality_code"|"primary_language"|"photo_path"|"admission_date"|"exit_date">&{campus_id:string|null;middle_name:string|null;preferred_name:string|null;gender:string|null;nationality_code:string|null;primary_language:string|null;photo_path:string|null;admission_date:string|null;exit_date:string|null};
type UpdateArgs=Omit<Functions["update_student_v1_3"]["Args"],"middle_name"|"preferred_name"|"gender"|"nationality_code"|"primary_language"|"photo_path"|"admission_date"|"exit_date"|"school_id"|"campus_id">&{middle_name:string|null;preferred_name:string|null;gender:string|null;nationality_code:string|null;primary_language:string|null;photo_path:string|null;admission_date:string|null;exit_date:string|null;school_id:string|null;campus_id:string|null};
type V13Args<Name extends V13RpcName> = Name extends "search_students" ? SearchArgs : Name extends "create_student_v1_3"?CreateArgs:Name extends "update_student_v1_3"?UpdateArgs:Functions[Name]["Args"];
type V13Result<Name extends V13RpcName> = Functions[Name]["Returns"];
type RpcResponse<Name extends V13RpcName> = { data: V13Result<Name> | null; error: PostgrestError | null };
type RpcInvoker = <Name extends V13RpcName>(name: Name, args: V13Args<Name>) => Promise<RpcResponse<Name>>;

const cursorSchema = z.object({ sort:z.enum(["name","student_number","updated"]),dir:z.enum(["asc","desc"]),value:z.string(),id:z.string().uuid() }).strict();
const directoryRowSchema = z.object({student_id:z.string().uuid(),student_number:z.string(),first_name:z.string(),last_name:z.string(),preferred_name:z.string().nullable(),status:z.enum(["active","inactive","archived"]),school_id:z.string().uuid(),school_name:z.string(),campus_id:z.string().uuid().nullable(),campus_name:z.string().nullable(),updated_at:z.iso.datetime(),sort_cursor_value:z.string(),total_count:z.number()}).strict();
const detailRowSchema = z.object({student_id:z.string().uuid(),student_number:z.string(),first_name:z.string(),middle_name:z.string().nullable(),last_name:z.string(),preferred_name:z.string().nullable(),date_of_birth:z.string(),gender:z.string().nullable(),nationality_code:z.string().nullable(),primary_language:z.string().nullable(),admission_date:z.string().nullable(),exit_date:z.string().nullable(),status:z.enum(["active","inactive","archived"]),school_id:z.string().uuid(),school_name:z.string(),campus_id:z.string().uuid().nullable(),campus_name:z.string().nullable(),created_at:z.iso.datetime(),updated_at:z.iso.datetime(),enrollments:z.json(),guardian_links:z.json(),documents:z.json()}).strict();
const uuidResultSchema=z.string().uuid();

function encodeCursor(value:z.infer<typeof cursorSchema>){return Buffer.from(JSON.stringify(value)).toString("base64url");}
function decodeCursor(value:string|null){if(!value)return null;try{return cursorSchema.parse(JSON.parse(Buffer.from(value,"base64url").toString("utf8")));}catch{return null;}}

export async function callStudentRpc<Name extends V13RpcName>(name:Name,args:V13Args<Name>):Promise<V13Result<Name>>{
  const db=await createSupabaseServerClient();
  const invoke=db.rpc.bind(db) as unknown as RpcInvoker;
  const {data,error}=await invoke(name,args);
  if(error)throw error;
  if(data===null)throw new Error(`RPC ${name} returned no result`);
  return data;
}

function searchArgs(c:{organizationId:string;schoolId:string|null;campusId:string|null},q:StudentDirectoryQuery,cursor:ReturnType<typeof decodeCursor>):SearchArgs{
  return {p_organization_id:c.organizationId,p_status:q.status==="all"?null:q.status,p_sort:q.sort,p_direction:q.dir,p_limit:26,...(q.school??c.schoolId?{p_school_id:q.school??c.schoolId!}:{}),...(q.campus??c.campusId?{p_campus_id:q.campus??c.campusId!}:{}),...(q.q?{p_query:q.q}:{}),...(cursor?{p_after_value:cursor.value,p_after_id:cursor.id}:{})};
}

export class SupabaseStudentService implements StudentReadService,ReplaySafeStudentCommandService{
  constructor(private readonly rpc:typeof callStudentRpc=callStudentRpc){}
  async search(c:{organizationId:string;schoolId:string|null;campusId:string|null},q:StudentDirectoryQuery):Promise<StudentDirectoryPage>{
    const cursor=decodeCursor(q.after);
    if(q.after&&!cursor)throw new Error("INVALID_CURSOR");
    if(cursor&&(cursor.sort!==q.sort||cursor.dir!==q.dir))throw new Error("INVALID_CURSOR");
    const rows=directoryRowSchema.array().parse(await this.rpc("search_students",searchArgs(c,q,cursor)));
    let totalCount=Number(rows[0]?.total_count??0);
    if(rows.length===0&&cursor){const first=directoryRowSchema.array().parse(await this.rpc("search_students",searchArgs(c,{...q,after:null},null)));totalCount=Number(first[0]?.total_count??0);}
    const shown=rows.slice(0,25),last=shown.at(-1);
    return {items:shown.map(r=>studentDirectoryItemSchema.parse({id:r.student_id,studentNumber:r.student_number,firstName:r.first_name,lastName:r.last_name,preferredName:r.preferred_name,status:r.status,schoolId:r.school_id,schoolName:r.school_name,campusId:r.campus_id,campusName:r.campus_name,updatedAt:r.updated_at})),totalCount,nextCursor:rows.length>25&&last?encodeCursor({sort:q.sort,dir:q.dir,value:last.sort_cursor_value,id:last.student_id}):null};
  }
  async get(id:string):Promise<StudentAdminDetail|null>{
    const rows=detailRowSchema.array().parse(await this.rpc("get_student_admin_detail",{p_student_id:id}));const r=rows[0];if(!r)return null;
    return studentAdminDetailSchema.parse({id:r.student_id,studentNumber:r.student_number,firstName:r.first_name,middleName:r.middle_name,lastName:r.last_name,preferredName:r.preferred_name,dateOfBirth:r.date_of_birth,gender:r.gender,nationalityCode:r.nationality_code,primaryLanguage:r.primary_language,admissionDate:r.admission_date,exitDate:r.exit_date,status:r.status,schoolId:r.school_id,schoolName:r.school_name,campusId:r.campus_id,campusName:r.campus_name,createdAt:r.created_at,updatedAt:r.updated_at,enrollments:studentEnrollmentSchema.array().parse(r.enrollments),guardianLinks:studentGuardianLinkSchema.array().parse(r.guardian_links),documents:studentDocumentMetadataSchema.array().parse(r.documents)});
  }
  async create(requestId:string,i:CreateStudentInput){return uuidResultSchema.parse(await this.rpc("create_student_v1_3",{request_id:requestId,school_id:i.schoolId,campus_id:i.campusId,student_number:i.studentNumber,first_name:i.firstName,middle_name:i.middleName,last_name:i.lastName,preferred_name:i.preferredName,date_of_birth:i.dateOfBirth,gender:i.gender,nationality_code:i.nationalityCode,primary_language:i.primaryLanguage,photo_path:i.photoPath,admission_date:i.admissionDate,exit_date:i.exitDate,status:i.status}));}
  async update(requestId:string,i:UpdateStudentInput){return uuidResultSchema.parse(await this.rpc("update_student_v1_3",{request_id:requestId,id:i.id,student_number:i.studentNumber,first_name:i.firstName,middle_name:i.middleName,set_middle_name:i.setMiddleName,last_name:i.lastName,preferred_name:i.preferredName,set_preferred_name:i.setPreferredName,date_of_birth:i.dateOfBirth,gender:i.gender,set_gender:i.setGender,nationality_code:i.nationalityCode,set_nationality_code:i.setNationalityCode,primary_language:i.primaryLanguage,set_primary_language:i.setPrimaryLanguage,photo_path:i.photoPath,set_photo_path:i.setPhotoPath,admission_date:i.admissionDate,set_admission_date:i.setAdmissionDate,exit_date:i.exitDate,set_exit_date:i.setExitDate,status:i.status,school_id:i.schoolId,set_school_id:i.setSchoolId,campus_id:i.campusId,set_campus_id:i.setCampusId}));}
  async archive(requestId:string,i:ArchiveStudentInput){return uuidResultSchema.parse(await this.rpc("archive_student_v1_3",{request_id:requestId,target_student_id:i.targetStudentId,archive_reason:i.archiveReason}));}
}
