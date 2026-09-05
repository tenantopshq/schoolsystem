import { z } from "zod";

import type { Database } from "../../platform/database/database.types";

const uuid = z.string().uuid();
const isoDate = z.string().date();
const nullableDescription = z.string().trim().min(1).max(2_000).nullable();
const nullableComment = z.string().trim().min(1).max(1_000).nullable();
const reason = z.string().trim().min(1).max(500);
const decimal = z.number().finite();
const maximumScore = decimal.positive().max(1_000_000);
const weight = decimal.positive().max(100).nullable();
const assessmentType = z.enum(["assignment", "quiz", "exam", "project", "participation"]);

export const assessmentResultSchema = z.object({
  studentId: uuid,
  score: decimal.min(0).nullable(),
  teacherComment: nullableComment,
}).strict().superRefine((value, context) => {
  if (value.score === null && value.teacherComment !== null) {
    context.addIssue({ code: "custom", path: ["teacherComment"], message: "teacher comment requires a score" });
  }
});

const resultArray = z.array(assessmentResultSchema).max(10_000).superRefine((results, context) => {
  const seen = new Set<string>();
  results.forEach((result, index) => {
    if (seen.has(result.studentId)) {
      context.addIssue({ code: "custom", path: [index, "studentId"], message: "duplicate result student" });
    }
    seen.add(result.studentId);
  });
});

export const createAssessmentSchema = z.object({
  sectionId: uuid,
  academicTermId: uuid,
  subjectId: uuid.nullable(),
  assessmentType,
  title: z.string().trim().min(1).max(160),
  description: nullableDescription,
  assessmentDate: isoDate,
  dueDate: isoDate.nullable(),
  maximumScore,
  weight,
}).strict().superRefine((value, context) => {
  if (value.dueDate !== null && value.dueDate < value.assessmentDate) {
    context.addIssue({ code: "custom", path: ["dueDate"], message: "due date cannot precede assessment date" });
  }
});

export const updateAssessmentSchema = z.object({
  id: uuid,
  assessmentType,
  title: z.string().trim().min(1).max(160),
  description: nullableDescription,
  dueDate: isoDate.nullable(),
  setDescription: z.boolean(),
  setDueDate: z.boolean(),
}).strict();

export const recordAssessmentResultsSchema = z.object({
  id: uuid,
  results: resultArray.refine((results) => results.length > 0, "at least one result is required"),
}).strict();
export const publishAssessmentSchema = z.object({ id: uuid }).strict();
export const finalizeAssessmentSchema = z.object({ id: uuid }).strict();
export const cancelDraftAssessmentSchema = z.object({ id: uuid, cancellationReason: reason }).strict();

export const correctAssessmentSchema = z.object({
  id: uuid,
  replacementSubjectId: uuid.nullable(),
  replacementAssessmentType: assessmentType,
  replacementTitle: z.string().trim().min(1).max(160),
  replacementDescription: nullableDescription,
  replacementAssessmentDate: isoDate,
  replacementDueDate: isoDate.nullable(),
  replacementMaximumScore: maximumScore,
  replacementWeight: weight,
  replacementResults: resultArray,
  correctionReason: reason,
}).strict().superRefine((value, context) => {
  if (value.replacementDueDate !== null && value.replacementDueDate < value.replacementAssessmentDate) {
    context.addIssue({ code: "custom", path: ["replacementDueDate"], message: "due date cannot precede assessment date" });
  }
});

export type AssessmentResultInput = z.infer<typeof assessmentResultSchema>;
export type CreateAssessmentInput = z.infer<typeof createAssessmentSchema>;
export type UpdateAssessmentInput = z.infer<typeof updateAssessmentSchema>;
export type RecordAssessmentResultsInput = z.infer<typeof recordAssessmentResultsSchema>;
export type PublishAssessmentInput = z.infer<typeof publishAssessmentSchema>;
export type FinalizeAssessmentInput = z.infer<typeof finalizeAssessmentSchema>;
export type CancelDraftAssessmentInput = z.infer<typeof cancelDraftAssessmentSchema>;
export type CorrectAssessmentInput = z.infer<typeof correctAssessmentSchema>;

type PublicFunctions = Database["public"]["Functions"];

export const assessmentRpcNames = [
  "create_assessment",
  "update_assessment",
  "record_assessment_results",
  "publish_assessment",
  "finalize_assessment",
  "cancel_draft_assessment",
  "correct_assessment",
] as const satisfies readonly (keyof PublicFunctions)[];

export type AssessmentRpcName = (typeof assessmentRpcNames)[number];
export type AssessmentRpcArgs<Name extends AssessmentRpcName> =
  PublicFunctions[Name]["Args"];
export type AssessmentRpcResult<Name extends AssessmentRpcName> =
  PublicFunctions[Name]["Returns"];
export type CorrectAssessmentResult = AssessmentRpcResult<"correct_assessment">[number];

export const assessmentTypes = ["assignment", "quiz", "exam", "project", "participation"] as const;
export const assessmentLifecycleStatuses = ["draft", "finalized", "corrected", "cancelled"] as const;
export const assessmentPublicationStates = ["unpublished", "published"] as const;
export const assessmentPermissionCodes = ["assessments.view", "assessments.manage", "assessments.correct"] as const;
export const assessmentEventTypes = [
  "assessment.created",
  "assessment.updated",
  "assessment.result_recorded",
  "assessment.published",
  "assessment.finalized",
  "assessment.cancelled",
  "assessment.corrected",
  "assessment.result_corrected",
] as const;

export type AssessmentType = (typeof assessmentTypes)[number];
export type AssessmentLifecycleStatus = (typeof assessmentLifecycleStatuses)[number];
export type AssessmentPublicationState = (typeof assessmentPublicationStates)[number];
export type AssessmentPermissionCode = (typeof assessmentPermissionCodes)[number];
export type AssessmentEventType = (typeof assessmentEventTypes)[number];
export type AssessmentCommandErrorCode = "22023" | "23503" | "23505" | "40001" | "42501" | "P0002";

export const isRetryableAssessmentCommandError = (error: { code?: string } | null | undefined) =>
  error?.code === "40001";

export interface AssessmentCommandService {
  create(input: CreateAssessmentInput): Promise<string>;
  update(input: UpdateAssessmentInput): Promise<string>;
  recordResults(input: RecordAssessmentResultsInput): Promise<string>;
  publish(input: PublishAssessmentInput): Promise<string>;
  finalize(input: FinalizeAssessmentInput): Promise<string>;
  cancelDraft(input: CancelDraftAssessmentInput): Promise<string>;
  correct(input: CorrectAssessmentInput): Promise<CorrectAssessmentResult>;
}

export const assessmentsModule = {
  name: "assessments",
  rpcNames: assessmentRpcNames,
  eventTypes: assessmentEventTypes,
  permissionCodes: assessmentPermissionCodes,
} as const;
