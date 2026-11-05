import type { PostgrestError } from "@supabase/supabase-js";
import { z } from "zod";
import type { AdminContextSelection } from "@/modules/organizations";
import type { Database } from "@/platform/database/database.types";
import { createSupabaseServerClient } from "@/platform/database/supabase-server";
import {
  eligibleStaffMemberSchema,
  staffAdminDetailSchema,
  staffDirectoryItemSchema,
  type ArchiveStaffProfileInput,
  type CreateStaffProfileInput,
  type EligibleStaffMember,
  type StaffCommandService,
  type StaffAdminDetail,
  type StaffDirectoryPage,
  type StaffDirectoryQuery,
  type StaffReadService,
  type UpdateStaffProfileInput,
} from "../index";

type Functions = Database["public"]["Functions"];
type StaffRpcName = "search_staff_profiles" | "get_staff_admin_detail" | "search_eligible_staff_members" | "create_staff_profile_v1_5" | "update_staff_profile_v1_5" | "archive_staff_profile_v1_5";
type SearchArgs = Omit<Functions["search_staff_profiles"]["Args"], "p_status" | "p_school_id" | "p_campus_id" | "p_query" | "p_after_value" | "p_after_id"> & {
  p_status: Database["public"]["Enums"]["record_status"] | null;
  p_school_id: string | null;
  p_campus_id: string | null;
  p_query: string | null;
  p_after_value: string | null;
  p_after_id: string | null;
};
type DetailArgs = Omit<Functions["get_staff_admin_detail"]["Args"], "p_school_id" | "p_campus_id"> & {
  p_school_id: string | null;
  p_campus_id: string | null;
};
type CandidateArgs={p_organization_id:string;p_school_id:string|null;p_campus_id:string|null;p_query:string|null;p_limit:number};
type CreateArgs={request_id:string;membership_id:string;school_id:string|null;campus_id:string|null;staff_number:string;employment_type:string;job_title:string|null;department:string|null;hire_date:string|null;status:"active"|"inactive"};
type UpdateArgs={request_id:string;id:string;staff_number:string;employment_type:string;status:"active"|"inactive";school_id:string|null;set_school_id:boolean;campus_id:string|null;set_campus_id:boolean;job_title:string|null;set_job_title:boolean;department:string|null;set_department:boolean;hire_date:string|null;set_hire_date:boolean;termination_date:string|null;set_termination_date:boolean};
type ArchiveArgs={request_id:string;target_staff_profile_id:string;archive_reason:string};
type CandidateRow={membership_id:string;first_name:string|null;middle_name:string|null;last_name:string|null;display_name:string|null};
type StaffRpcArgs<Name extends StaffRpcName> = Name extends "search_staff_profiles"?SearchArgs:Name extends "get_staff_admin_detail"?DetailArgs:Name extends "search_eligible_staff_members"?CandidateArgs:Name extends "create_staff_profile_v1_5"?CreateArgs:Name extends "update_staff_profile_v1_5"?UpdateArgs:ArchiveArgs;
type StaffRpcResult<Name extends StaffRpcName> = Name extends "search_staff_profiles"?Functions["search_staff_profiles"]["Returns"]:Name extends "get_staff_admin_detail"?Functions["get_staff_admin_detail"]["Returns"]:Name extends "search_eligible_staff_members"?CandidateRow[]:string;
type RpcInvoker = <Name extends StaffRpcName>(name: Name, args: StaffRpcArgs<Name>) => Promise<{ data: StaffRpcResult<Name> | null; error: PostgrestError | null }>;

const cursorSchema = z.object({ value: z.string(), id: z.string().uuid() }).strict();
const directoryRowSchema = z.object({
  staff_profile_id: z.string().uuid(), staff_number: z.string(), first_name: z.string().nullable(), middle_name: z.string().nullable(),
  last_name: z.string().nullable(), display_name: z.string().nullable(), job_title: z.string().nullable(), department: z.string().nullable(),
  employment_type: z.string(), status: z.enum(["active", "inactive", "archived"]), school_id: z.string().uuid().nullable(),
  school_name: z.string().nullable(), campus_id: z.string().uuid().nullable(), campus_name: z.string().nullable(), updated_at: z.iso.datetime(),
  sort_cursor_value: z.string(), total_count: z.number(),
}).strict();
const detailRowSchema = directoryRowSchema.omit({ sort_cursor_value: true, total_count: true }).extend({
  hire_date: z.iso.date().nullable(), termination_date: z.iso.date().nullable(), created_at: z.iso.datetime(),
}).strict();

function encodeCursor(value: z.infer<typeof cursorSchema>) { return Buffer.from(JSON.stringify(value)).toString("base64url"); }
function decodeCursor(value: string | null) {
  if (!value) return null;
  try { return cursorSchema.parse(JSON.parse(Buffer.from(value, "base64url").toString("utf8"))); } catch { return null; }
}

export async function callStaffRpc<Name extends StaffRpcName>(name: Name, args: StaffRpcArgs<Name>): Promise<StaffRpcResult<Name>> {
  const db = await createSupabaseServerClient();
  const invoke = db.rpc.bind(db) as unknown as RpcInvoker;
  const { data, error } = await invoke(name, args);
  if (error) throw error;
  if (data === null) throw new Error(`RPC ${name} returned no result`);
  return data;
}

function mapDirectoryRow(row: z.infer<typeof directoryRowSchema>) {
  return staffDirectoryItemSchema.parse({
    id: row.staff_profile_id, staffNumber: row.staff_number, firstName: row.first_name, middleName: row.middle_name,
    lastName: row.last_name, displayName: row.display_name, jobTitle: row.job_title, department: row.department,
    employmentType: row.employment_type, status: row.status, schoolId: row.school_id, schoolName: row.school_name,
    campusId: row.campus_id, campusName: row.campus_name, updatedAt: row.updated_at,
  });
}

export class SupabaseStaffService implements StaffReadService,StaffCommandService {
  constructor(private readonly rpc: typeof callStaffRpc = callStaffRpc) {}

  async search(context: AdminContextSelection, query: StaffDirectoryQuery): Promise<StaffDirectoryPage> {
    const cursor = decodeCursor(query.after);
    if (query.after && !cursor) throw new Error("INVALID_CURSOR");
    const rows = directoryRowSchema.array().parse(await this.rpc("search_staff_profiles", {
      p_organization_id: context.organizationId, p_school_id: context.schoolId, p_campus_id: context.campusId,
      p_query: query.q || null, p_status: query.status === "all" ? null : query.status,
      p_after_value: cursor?.value ?? null, p_after_id: cursor?.id ?? null, p_limit: 26,
    }));
    let totalCount = Number(rows[0]?.total_count ?? 0);
    if (rows.length === 0 && cursor) {
      const firstPage = directoryRowSchema.array().parse(await this.rpc("search_staff_profiles", {
        p_organization_id: context.organizationId, p_school_id: context.schoolId, p_campus_id: context.campusId,
        p_query: query.q || null, p_status: query.status === "all" ? null : query.status,
        p_after_value: null, p_after_id: null, p_limit: 1,
      }));
      totalCount = Number(firstPage[0]?.total_count ?? 0);
    }
    const shown = rows.slice(0, 25);
    const last = shown.at(-1);
    return {
      items: shown.map(mapDirectoryRow),
      totalCount,
      nextCursor: rows.length > 25 && last ? encodeCursor({ value: last.sort_cursor_value, id: last.staff_profile_id }) : null,
    };
  }

  async get(context: AdminContextSelection, id: string): Promise<StaffAdminDetail | null> {
    const rows = detailRowSchema.array().parse(await this.rpc("get_staff_admin_detail", {
      p_staff_profile_id: id, p_organization_id: context.organizationId, p_school_id: context.schoolId, p_campus_id: context.campusId,
    }));
    const row = rows[0];
    if (!row) return null;
    return staffAdminDetailSchema.parse({ ...mapDirectoryRow({ ...row, sort_cursor_value: "", total_count: 0 }), hireDate: row.hire_date, terminationDate: row.termination_date, createdAt: row.created_at });
  }

  async eligibleMembers(context:AdminContextSelection,query=""):Promise<EligibleStaffMember[]> {
    const rows=await this.rpc("search_eligible_staff_members",{p_organization_id:context.organizationId,p_school_id:context.schoolId,p_campus_id:context.campusId,p_query:query||null,p_limit:100});
    return z.array(z.object({membership_id:z.string().uuid(),first_name:z.string().nullable(),middle_name:z.string().nullable(),last_name:z.string().nullable(),display_name:z.string().nullable()}).strict()).parse(rows).map(row=>eligibleStaffMemberSchema.parse({membershipId:row.membership_id,firstName:row.first_name,middleName:row.middle_name,lastName:row.last_name,displayName:row.display_name}));
  }

  async create(requestId:string,input:CreateStaffProfileInput):Promise<string>{
    return z.string().uuid().parse(await this.rpc("create_staff_profile_v1_5",{request_id:requestId,membership_id:input.membershipId,school_id:input.schoolId,campus_id:input.campusId,staff_number:input.staffNumber,employment_type:input.employmentType,job_title:input.jobTitle,department:input.department,hire_date:input.hireDate,status:input.status}));
  }

  async update(requestId:string,input:UpdateStaffProfileInput):Promise<string>{
    return z.string().uuid().parse(await this.rpc("update_staff_profile_v1_5",{request_id:requestId,id:input.id,staff_number:input.staffNumber,employment_type:input.employmentType,status:input.status,school_id:null,set_school_id:false,campus_id:null,set_campus_id:false,job_title:input.jobTitle,set_job_title:true,department:input.department,set_department:true,hire_date:input.hireDate,set_hire_date:true,termination_date:input.terminationDate,set_termination_date:true}));
  }

  async archive(requestId:string,input:ArchiveStaffProfileInput):Promise<string>{
    return z.string().uuid().parse(await this.rpc("archive_staff_profile_v1_5",{request_id:requestId,target_staff_profile_id:input.targetStaffProfileId,archive_reason:input.archiveReason}));
  }
}
