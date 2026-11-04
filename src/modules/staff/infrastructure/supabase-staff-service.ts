import type { PostgrestError } from "@supabase/supabase-js";
import { z } from "zod";
import type { AdminContextSelection } from "@/modules/organizations";
import type { Database } from "@/platform/database/database.types";
import { createSupabaseServerClient } from "@/platform/database/supabase-server";
import {
  staffAdminDetailSchema,
  staffDirectoryItemSchema,
  type StaffAdminDetail,
  type StaffDirectoryPage,
  type StaffDirectoryQuery,
  type StaffReadService,
} from "../index";

type Functions = Database["public"]["Functions"];
type StaffRpcName = "search_staff_profiles" | "get_staff_admin_detail";
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
type StaffRpcArgs<Name extends StaffRpcName> = Name extends "search_staff_profiles"
  ? SearchArgs
  : DetailArgs;
type StaffRpcResult<Name extends StaffRpcName> = Functions[Name]["Returns"];
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

export class SupabaseStaffService implements StaffReadService {
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
}
