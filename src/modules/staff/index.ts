import { z } from "zod";
import type { AdminContextSelection } from "@/modules/organizations";

const recordStatusSchema = z.enum(["active", "inactive", "archived"]);
export const staffProfileIdSchema = z.string().uuid();

export const staffDirectoryQuerySchema = z.object({
  q: z.string().trim().max(100).catch(""),
  status: z.enum(["active", "inactive", "archived", "all"]).catch("active"),
  after: z.string().max(1000).nullable().catch(null),
}).strict();

export const staffDirectoryItemSchema = z.object({
  id: z.string().uuid(),
  staffNumber: z.string(),
  firstName: z.string().nullable(),
  middleName: z.string().nullable(),
  lastName: z.string().nullable(),
  displayName: z.string().nullable(),
  jobTitle: z.string().nullable(),
  department: z.string().nullable(),
  employmentType: z.string(),
  status: recordStatusSchema,
  schoolId: z.string().uuid().nullable(),
  schoolName: z.string().nullable(),
  campusId: z.string().uuid().nullable(),
  campusName: z.string().nullable(),
  updatedAt: z.iso.datetime(),
}).strict();

export const staffAdminDetailSchema = staffDirectoryItemSchema.omit({ updatedAt: true }).extend({
  hireDate: z.iso.date().nullable(),
  terminationDate: z.iso.date().nullable(),
  createdAt: z.iso.datetime(),
  updatedAt: z.iso.datetime(),
}).strict();

export type StaffDirectoryQuery = z.infer<typeof staffDirectoryQuerySchema>;
export type StaffDirectoryItem = z.infer<typeof staffDirectoryItemSchema>;
export type StaffAdminDetail = z.infer<typeof staffAdminDetailSchema>;
export type StaffDirectoryPage = { items: StaffDirectoryItem[]; totalCount: number; nextCursor: string | null };

export interface StaffReadService {
  search(context: AdminContextSelection, query: StaffDirectoryQuery): Promise<StaffDirectoryPage>;
  get(context: AdminContextSelection, id: string): Promise<StaffAdminDetail | null>;
}

export function parseStaffDirectoryQuery(value: Record<string, string | undefined>): StaffDirectoryQuery {
  return staffDirectoryQuerySchema.parse({ q: value.q ?? "", status: value.status ?? "active", after: value.after ?? null });
}

export function formatStaffName(staff: Pick<StaffDirectoryItem, "displayName" | "firstName" | "middleName" | "lastName" | "staffNumber">) {
  return staff.displayName?.trim() || [staff.firstName, staff.middleName, staff.lastName].filter(Boolean).join(" ") || staff.staffNumber;
}

export const staffModule = { name: "staff" } as const;
