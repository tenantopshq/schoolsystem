import { z } from "zod";
import type { AdminContextSelection } from "@/modules/organizations";

const recordStatusSchema = z.enum(["active", "inactive", "archived"]);
const accessStateSchema = z.enum(["no_access", "invited", "active", "suspended"]);
export const staffProfileIdSchema = z.string().uuid();
const nullableText = (max: number) => z.string().trim().min(1).max(max).nullable();
const identityFields = {
  firstName: z.string().trim().min(1).max(100),
  middleName: nullableText(100),
  lastName: z.string().trim().min(1).max(100),
  displayName: nullableText(200),
  workEmail: z.string().trim().email().max(320).nullable(),
  phone: nullableText(40),
};

export const createStaffProfileSchema = z.object({
  membershipId: z.string().uuid().nullable(),
  schoolId: z.string().uuid().nullable(),
  campusId: z.string().uuid().nullable(),
  ...identityFields,
  staffNumber: z.string().trim().min(1).max(48),
  employmentType: z.string().trim().min(1).max(40),
  jobTitle: nullableText(120),
  department: nullableText(120),
  hireDate: z.iso.date().nullable(),
  status: z.enum(["active", "inactive"]).default("active"),
}).strict().refine((value) => !value.campusId || value.schoolId, { path: ["campusId"], message: "Campus requires a school." });

export const updateStaffProfileSchema = z.object({
  id: z.string().uuid(),
  membershipId: z.string().uuid().nullable(),
  linkMembership: z.boolean(),
  ...identityFields,
  staffNumber: z.string().trim().min(1).max(48),
  employmentType: z.string().trim().min(1).max(40),
  jobTitle: nullableText(120),
  department: nullableText(120),
  hireDate: z.iso.date().nullable(),
  terminationDate: z.iso.date().nullable(),
  status: z.enum(["active", "inactive"]),
}).strict().refine((value) => !value.hireDate || !value.terminationDate || value.terminationDate >= value.hireDate, { path: ["terminationDate"], message: "Termination date cannot precede the hire date." });

export const archiveStaffProfileSchema = z.object({
  targetStaffProfileId: z.string().uuid(),
  archiveReason: z.string().trim().min(1).max(500),
}).strict();

export const eligibleStaffMemberSchema = z.object({
  membershipId: z.string().uuid(),
  firstName: z.string().nullable(),
  middleName: z.string().nullable(),
  lastName: z.string().nullable(),
  displayName: z.string().nullable(),
}).strict();

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
  workEmail: z.string().nullable(),
  phone: z.string().nullable(),
  accessState: accessStateSchema,
  organizationMembershipId: z.string().uuid().nullable(),
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
export type CreateStaffProfileInput = z.infer<typeof createStaffProfileSchema>;
export type UpdateStaffProfileInput = z.infer<typeof updateStaffProfileSchema>;
export type ArchiveStaffProfileInput = z.infer<typeof archiveStaffProfileSchema>;
export type EligibleStaffMember = z.infer<typeof eligibleStaffMemberSchema>;
export type StaffAccessState = z.infer<typeof accessStateSchema>;

export interface StaffReadService {
  search(context: AdminContextSelection, query: StaffDirectoryQuery): Promise<StaffDirectoryPage>;
  get(context: AdminContextSelection, id: string): Promise<StaffAdminDetail | null>;
}

export interface StaffCommandService {
  eligibleMembers(context: AdminContextSelection, query?: string): Promise<EligibleStaffMember[]>;
  create(requestId: string, context: AdminContextSelection, input: CreateStaffProfileInput): Promise<string>;
  update(requestId: string, input: UpdateStaffProfileInput): Promise<string>;
  archive(requestId: string, input: ArchiveStaffProfileInput): Promise<string>;
}

export function parseStaffDirectoryQuery(value: Record<string, string | undefined>): StaffDirectoryQuery {
  return staffDirectoryQuerySchema.parse({ q: value.q ?? "", status: value.status ?? "active", after: value.after ?? null });
}

export function formatStaffName(staff: Pick<StaffDirectoryItem, "displayName" | "firstName" | "middleName" | "lastName" | "staffNumber">) {
  return staff.displayName?.trim() || [staff.firstName, staff.middleName, staff.lastName].filter(Boolean).join(" ") || staff.staffNumber;
}

export function formatEligibleMemberName(member: EligibleStaffMember) {
  return member.displayName?.trim() || [member.firstName, member.middleName, member.lastName].filter(Boolean).join(" ") || member.membershipId;
}

export const staffModule = { name: "staff" } as const;
