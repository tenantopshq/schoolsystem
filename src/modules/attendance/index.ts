import { z } from "zod";

import type { Database } from "../../platform/database/database.types";

const uuid = z.string().uuid();
const isoDate = z.string().date();
const boundedText = z.string().trim().min(1).max(500);
const localTime = z.string().regex(/^([01]\d|2[0-3]):[0-5]\d(?::[0-5]\d(?:\.\d{1,6})?)?$/);

const todayIso = () => {
  const now = new Date();
  const local = new Date(now.getTime() - now.getTimezoneOffset() * 60_000);
  return local.toISOString().slice(0, 10);
};

export const attendanceMarkSchema = z.discriminatedUnion("mark", [
  z.object({
    studentId: uuid,
    mark: z.literal("present"),
    arrivalTime: z.null(),
    absenceReasonId: z.null(),
    note: z.null(),
  }).strict(),
  z.object({
    studentId: uuid,
    mark: z.literal("late"),
    arrivalTime: localTime.nullable(),
    absenceReasonId: z.null(),
    note: z.null(),
  }).strict(),
  z.object({
    studentId: uuid,
    mark: z.literal("absent"),
    arrivalTime: z.null(),
    absenceReasonId: uuid,
    note: boundedText.nullable(),
  }).strict(),
  z.object({
    studentId: uuid,
    mark: z.literal("excused"),
    arrivalTime: z.null(),
    absenceReasonId: uuid,
    note: boundedText.nullable(),
  }).strict(),
]);

export const createAttendanceAbsenceReasonSchema = z.object({
  schoolId: uuid,
  campusId: uuid.nullable(),
  code: z.string().trim().min(1).max(32),
  name: z.string().trim().min(1).max(100),
  description: boundedText.nullable(),
}).strict();

export const updateAttendanceAbsenceReasonSchema = z.object({
  id: uuid,
  code: z.string().trim().min(1).max(32),
  name: z.string().trim().min(1).max(100),
  description: boundedText.nullable(),
  status: z.enum(["active", "inactive"]),
  setDescription: z.boolean(),
}).strict();

export const archiveAttendanceAbsenceReasonSchema = z.object({ id: uuid }).strict();

export const openAttendanceSessionSchema = z.object({
  sectionId: uuid,
  sessionDate: isoDate,
}).strict().superRefine((value, context) => {
  if (value.sessionDate > todayIso()) {
    context.addIssue({ code: "custom", path: ["sessionDate"], message: "future attendance sessions are prohibited" });
  }
});

const marks = z.array(attendanceMarkSchema).max(10_000);
export const submitAttendanceSessionSchema = z.object({ id: uuid, marks }).strict();
export const finalizeAttendanceSessionSchema = z.object({ id: uuid }).strict();
export const correctAttendanceSessionSchema = z.object({
  id: uuid,
  marks,
  correctionReason: boundedText,
}).strict();

export type AttendanceMarkInput = z.infer<typeof attendanceMarkSchema>;
export type CreateAttendanceAbsenceReasonInput = z.infer<typeof createAttendanceAbsenceReasonSchema>;
export type UpdateAttendanceAbsenceReasonInput = z.infer<typeof updateAttendanceAbsenceReasonSchema>;
export type ArchiveAttendanceAbsenceReasonInput = z.infer<typeof archiveAttendanceAbsenceReasonSchema>;
export type OpenAttendanceSessionInput = z.infer<typeof openAttendanceSessionSchema>;
export type SubmitAttendanceSessionInput = z.infer<typeof submitAttendanceSessionSchema>;
export type FinalizeAttendanceSessionInput = z.infer<typeof finalizeAttendanceSessionSchema>;
export type CorrectAttendanceSessionInput = z.infer<typeof correctAttendanceSessionSchema>;

type PublicFunctions = Database["public"]["Functions"];

export const attendanceRpcNames = [
  "create_attendance_absence_reason",
  "update_attendance_absence_reason",
  "archive_attendance_absence_reason",
  "open_attendance_session",
  "submit_attendance_session",
  "finalize_attendance_session",
  "correct_attendance_session",
] as const satisfies readonly (keyof PublicFunctions)[];

export type AttendanceRpcName = (typeof attendanceRpcNames)[number];
export type AttendanceRpcArgs<Name extends AttendanceRpcName> = PublicFunctions[Name]["Args"];
export type AttendanceRpcResult<Name extends AttendanceRpcName> = PublicFunctions[Name]["Returns"];
export type CorrectAttendanceSessionResult = AttendanceRpcResult<"correct_attendance_session">[number];

export const attendanceSessionStatuses = ["open", "submitted", "finalized", "corrected"] as const;
export const attendanceMarkStatuses = ["present", "absent", "late", "excused"] as const;
export const attendancePermissionCodes = ["attendance.view", "attendance.manage", "attendance.correct"] as const;
export const attendanceEventTypes = [
  "attendance_reason.created",
  "attendance_reason.updated",
  "attendance_reason.archived",
  "attendance.session_opened",
  "attendance.session_submitted",
  "attendance.session_finalized",
  "attendance.session_corrected",
  "attendance.student_marked",
  "attendance.student_mark_corrected",
] as const;

export type AttendanceSessionStatus = (typeof attendanceSessionStatuses)[number];
export type AttendanceMarkStatus = (typeof attendanceMarkStatuses)[number];
export type AttendancePermissionCode = (typeof attendancePermissionCodes)[number];
export type AttendanceEventType = (typeof attendanceEventTypes)[number];
export type AttendanceCommandErrorCode = "22023" | "23503" | "23505" | "40001" | "42501" | "P0002";

export const isRetryableAttendanceCommandError = (error: { code?: string } | null | undefined) =>
  error?.code === "40001";

export interface AttendanceCommandService {
  createAbsenceReason(input: CreateAttendanceAbsenceReasonInput): Promise<string>;
  updateAbsenceReason(input: UpdateAttendanceAbsenceReasonInput): Promise<string>;
  archiveAbsenceReason(input: ArchiveAttendanceAbsenceReasonInput): Promise<string>;
  openSession(input: OpenAttendanceSessionInput): Promise<string>;
  submitSession(input: SubmitAttendanceSessionInput): Promise<string>;
  finalizeSession(input: FinalizeAttendanceSessionInput): Promise<string>;
  correctSession(input: CorrectAttendanceSessionInput): Promise<CorrectAttendanceSessionResult>;
}

export const attendanceModule = {
  name: "attendance",
  rpcNames: attendanceRpcNames,
  eventTypes: attendanceEventTypes,
  permissionCodes: attendancePermissionCodes,
} as const;
