import { z } from "zod";

import type { Database } from "../../platform/database/database.types";

const uuid = z.string().uuid();
const date = z.string().date();
const reason = z.string().trim().min(1).max(500);
const terminalEnrollmentStatus = z.enum(["withdrawn", "completed"]);
const replacementEnrollmentStatus = z.enum(["active", "withdrawn", "completed"]);
const terminalPlacementStatus = z.enum(["withdrawn", "completed"]);
const replacementPlacementStatus = z.enum(["active", "withdrawn", "completed"]);

export const enrollStudentSchema = z.object({
  studentId: uuid,
  academicYearId: uuid,
  gradeLevelId: uuid,
  enrolledOn: date,
}).strict();

const endEnrollmentSchema = z.object({ id: uuid, endedOn: date, reason }).strict();
export const withdrawStudentEnrollmentSchema = endEnrollmentSchema;
export const completeStudentEnrollmentSchema = endEnrollmentSchema;

export const correctStudentEnrollmentSchema = z.object({
  id: uuid,
  createReplacement: z.boolean(),
  replacementAcademicYearId: uuid.nullable(),
  replacementGradeLevelId: uuid.nullable(),
  replacementEnrolledOn: date.nullable(),
  replacementStatus: replacementEnrollmentStatus.nullable(),
  replacementEndedOn: date.nullable(),
  replacementEndReason: reason.nullable(),
  correctionReason: reason,
}).strict().superRefine((value, context) => {
  if (value.createReplacement && (!value.replacementAcademicYearId ||
      !value.replacementGradeLevelId || !value.replacementEnrolledOn ||
      !value.replacementStatus)) {
    context.addIssue({ code: "custom", message: "replacement enrollment fields are required" });
  }
  const terminal = value.replacementStatus && terminalEnrollmentStatus.safeParse(value.replacementStatus).success;
  if (value.createReplacement && terminal && (!value.replacementEndedOn || !value.replacementEndReason)) {
    context.addIssue({ code: "custom", message: "terminal replacement outcome is required" });
  }
  if (value.replacementStatus === "active" && (value.replacementEndedOn || value.replacementEndReason)) {
    context.addIssue({ code: "custom", message: "active replacement cannot have terminal fields" });
  }
});

export const placeStudentInSectionSchema = z.object({
  studentEnrollmentId: uuid,
  sectionId: uuid,
  startsOn: date,
}).strict();

export const transferStudentSectionSchema = z.object({
  id: uuid,
  destinationSectionId: uuid,
  transferOn: date,
  reason,
}).strict();

const endPlacementSchema = z.object({ id: uuid, endedOn: date, reason }).strict();
export const withdrawStudentSectionPlacementSchema = endPlacementSchema;
export const completeStudentSectionPlacementSchema = endPlacementSchema;

/**
 * Corrects the requested placement and its linked original transfer half, if any.
 * createReplacement appends at most one placement episode; it cannot recreate a
 * complete transfer pair. That requires a future dedicated workflow.
 */
export const correctStudentSectionPlacementSchema = z.object({
  id: uuid,
  createReplacement: z.boolean(),
  replacementSectionId: uuid.nullable(),
  replacementStartsOn: date.nullable(),
  replacementEndsOn: date.nullable(),
  replacementStatus: replacementPlacementStatus.nullable(),
  replacementEndReason: reason.nullable(),
  correctionReason: reason,
}).strict().superRefine((value, context) => {
  if (value.createReplacement && (!value.replacementSectionId ||
      !value.replacementStartsOn || !value.replacementStatus)) {
    context.addIssue({ code: "custom", message: "replacement placement fields are required" });
  }
  const terminal = value.replacementStatus && terminalPlacementStatus.safeParse(value.replacementStatus).success;
  if (value.createReplacement && terminal && (!value.replacementEndsOn || !value.replacementEndReason)) {
    context.addIssue({ code: "custom", message: "terminal replacement outcome is required" });
  }
  if (value.replacementStatus === "active" && (value.replacementEndsOn || value.replacementEndReason)) {
    context.addIssue({ code: "custom", message: "active replacement cannot have terminal fields" });
  }
});

export type EnrollStudentInput = z.infer<typeof enrollStudentSchema>;
export type EndStudentEnrollmentInput = z.infer<typeof endEnrollmentSchema>;
export type CorrectStudentEnrollmentInput = z.infer<typeof correctStudentEnrollmentSchema>;
export type PlaceStudentInSectionInput = z.infer<typeof placeStudentInSectionSchema>;
export type TransferStudentSectionInput = z.infer<typeof transferStudentSectionSchema>;
export type EndStudentSectionPlacementInput = z.infer<typeof endPlacementSchema>;
export type CorrectStudentSectionPlacementInput = z.infer<typeof correctStudentSectionPlacementSchema>;

type PublicFunctions = Database["public"]["Functions"];

export const enrollmentRpcNames = [
  "enroll_student",
  "withdraw_student_enrollment",
  "complete_student_enrollment",
  "correct_student_enrollment",
  "place_student_in_section",
  "transfer_student_section",
  "withdraw_student_section_placement",
  "complete_student_section_placement",
  "correct_student_section_placement",
] as const satisfies readonly (keyof PublicFunctions)[];

export type EnrollmentRpcName = (typeof enrollmentRpcNames)[number];
export type EnrollmentRpcArgs<Name extends EnrollmentRpcName> = PublicFunctions[Name]["Args"];
export type EnrollmentRpcResult<Name extends EnrollmentRpcName> = PublicFunctions[Name]["Returns"];
export type CorrectEnrollmentResult = EnrollmentRpcResult<"correct_student_enrollment">[number];
export type TransferPlacementResult = EnrollmentRpcResult<"transfer_student_section">[number];
/** One corrected input ID and at most one newly appended placement episode ID. */
export type CorrectPlacementResult = EnrollmentRpcResult<"correct_student_section_placement">[number];

export const enrollmentEventTypes = [
  "student.enrolled",
  "student.enrollment_withdrawn",
  "student.enrollment_completed",
  "student.enrollment_corrected",
  "student.section_placed",
  "student.section_transferred_out",
  "student.section_transferred_in",
  "student.section_withdrawn",
  "student.section_completed",
  "student.section_placement_corrected",
] as const;

export const enrollmentPermissionCodes = [
  "enrollments.view",
  "enrollments.manage",
  "enrollments.correct",
] as const;

export type EnrollmentEventType = (typeof enrollmentEventTypes)[number];
export type EnrollmentPermissionCode = (typeof enrollmentPermissionCodes)[number];
export type EnrollmentCommandErrorCode = "22023" | "23503" | "23505" | "23P01" | "40001" | "42501" | "P0002";

export const isRetryableEnrollmentCommandError = (error: { code?: string } | null | undefined) =>
  error?.code === "40001";

export interface EnrollmentCommandService {
  enrollStudent(input: EnrollStudentInput): Promise<string>;
  withdrawStudentEnrollment(input: EndStudentEnrollmentInput): Promise<string>;
  completeStudentEnrollment(input: EndStudentEnrollmentInput): Promise<string>;
  correctStudentEnrollment(input: CorrectStudentEnrollmentInput): Promise<CorrectEnrollmentResult>;
  placeStudentInSection(input: PlaceStudentInSectionInput): Promise<string>;
  transferStudentSection(input: TransferStudentSectionInput): Promise<TransferPlacementResult>;
  withdrawStudentSectionPlacement(input: EndStudentSectionPlacementInput): Promise<string>;
  completeStudentSectionPlacement(input: EndStudentSectionPlacementInput): Promise<string>;
  /** Correct both original transfer halves, with at most one replacement episode. */
  correctStudentSectionPlacement(input: CorrectStudentSectionPlacementInput): Promise<CorrectPlacementResult>;
}

export const enrollmentsModule = {
  name: "enrollments",
  rpcNames: enrollmentRpcNames,
  eventTypes: enrollmentEventTypes,
  permissionCodes: enrollmentPermissionCodes,
} as const;
