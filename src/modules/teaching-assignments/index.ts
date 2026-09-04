import { z } from "zod";

import type { Database } from "../../platform/database/database.types";

const uuid = z.string().uuid();
const date = z.string().date();
const reason = z.string().trim().min(1).max(500);
const role = z.enum(["lead", "co_teacher", "assistant", "substitute"]);

export const createTeachingAssignmentSchema = z.object({
  sectionId: uuid,
  staffProfileId: uuid,
  subjectId: uuid.nullable(),
  role,
  startsOn: date,
  scheduledEndsOn: date,
}).strict();

export const endTeachingAssignmentSchema = z.object({
  id: uuid,
  endedOn: date,
  reason,
}).strict();

export const reassignTeachingAssignmentSchema = z.object({
  id: uuid,
  replacementStaffProfileId: uuid,
  replacementRole: role,
  reassignOn: date,
  replacementScheduledEndsOn: date,
  reason,
}).strict();

export const correctTeachingAssignmentSchema = z.object({
  id: uuid,
  createReplacement: z.boolean(),
  replacementSectionId: uuid.nullable(),
  replacementStaffProfileId: uuid.nullable(),
  replacementSubjectId: uuid.nullable(),
  replacementRole: role.nullable(),
  replacementStartsOn: date.nullable(),
  replacementScheduledEndsOn: date.nullable(),
  correctionReason: reason,
}).strict().superRefine((value, context) => {
  if (value.createReplacement && (!value.replacementSectionId ||
      !value.replacementStaffProfileId || !value.replacementRole ||
      !value.replacementStartsOn || !value.replacementScheduledEndsOn)) {
    context.addIssue({
      code: "custom",
      message: "replacement teaching-assignment fields are required",
    });
  }
});

export type CreateTeachingAssignmentInput = z.infer<typeof createTeachingAssignmentSchema>;
export type EndTeachingAssignmentInput = z.infer<typeof endTeachingAssignmentSchema>;
export type ReassignTeachingAssignmentInput = z.infer<typeof reassignTeachingAssignmentSchema>;
export type CorrectTeachingAssignmentInput = z.infer<typeof correctTeachingAssignmentSchema>;

type PublicFunctions = Database["public"]["Functions"];

export const teachingAssignmentRpcNames = [
  "create_teaching_assignment",
  "end_teaching_assignment",
  "reassign_teaching_assignment",
  "correct_teaching_assignment",
] as const satisfies readonly (keyof PublicFunctions)[];

export type TeachingAssignmentRpcName = (typeof teachingAssignmentRpcNames)[number];
export type TeachingAssignmentRpcArgs<Name extends TeachingAssignmentRpcName> = PublicFunctions[Name]["Args"];
export type TeachingAssignmentRpcResult<Name extends TeachingAssignmentRpcName> = PublicFunctions[Name]["Returns"];
export type ReassignTeachingAssignmentResult = TeachingAssignmentRpcResult<"reassign_teaching_assignment">[number];
export type CorrectTeachingAssignmentResult = TeachingAssignmentRpcResult<"correct_teaching_assignment">[number];

export const teachingAssignmentRoles = ["lead", "co_teacher", "assistant", "substitute"] as const;
export const teachingAssignmentStatuses = ["active", "ended", "reassigned", "corrected"] as const;
export const teachingAssignmentPermissionCodes = [
  "teaching_assignments.view",
  "teaching_assignments.manage",
  "teaching_assignments.correct",
] as const;
export const teachingAssignmentEventTypes = [
  "teaching_assignment.created",
  "teaching_assignment.ended",
  "teaching_assignment.reassigned_out",
  "teaching_assignment.reassigned_in",
  "teaching_assignment.corrected",
] as const;

export type TeachingAssignmentRole = (typeof teachingAssignmentRoles)[number];
export type TeachingAssignmentStatus = (typeof teachingAssignmentStatuses)[number];
export type TeachingAssignmentPermissionCode = (typeof teachingAssignmentPermissionCodes)[number];
export type TeachingAssignmentEventType = (typeof teachingAssignmentEventTypes)[number];
export type TeachingAssignmentCommandErrorCode = "22023" | "23503" | "23P01" | "40001" | "42501" | "P0002";

export const isRetryableTeachingAssignmentCommandError = (
  error: { code?: string } | null | undefined,
) => error?.code === "40001";

export interface TeachingAssignmentCommandService {
  createTeachingAssignment(input: CreateTeachingAssignmentInput): Promise<string>;
  endTeachingAssignment(input: EndTeachingAssignmentInput): Promise<string>;
  reassignTeachingAssignment(input: ReassignTeachingAssignmentInput): Promise<ReassignTeachingAssignmentResult>;
  /** Reassignment participants must be corrected before they are reassigned. */
  correctTeachingAssignment(input: CorrectTeachingAssignmentInput): Promise<CorrectTeachingAssignmentResult>;
}

export const teachingAssignmentsModule = {
  name: "teaching-assignments",
  rpcNames: teachingAssignmentRpcNames,
  eventTypes: teachingAssignmentEventTypes,
  permissionCodes: teachingAssignmentPermissionCodes,
} as const;
