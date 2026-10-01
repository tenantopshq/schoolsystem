import { z } from "zod";

import type { Database } from "../../platform/database/database.types";

const uuid = z.string().uuid();
const date = z.string().date();
const reason = z.string().trim().min(1).max(500);

export const progressionDispositions = ["promotion", "retention", "graduation", "transfer", "withdrawal"] as const;
export const progressionDecisionStatuses = ["pending", "approved", "executed", "cancelled", "corrected"] as const;
export const progressionEligibilityStates = ["eligible", "not_eligible", "incomplete", "stale"] as const;
export const progressionBatchStatuses = ["draft", "approved", "completed"] as const;
export const progressionBatchOutcomes = ["completed_successfully", "completed_with_exceptions"] as const;

const destination = {
  destinationSchoolId: uuid.nullable(),
  destinationCampusId: uuid.nullable(),
  destinationAcademicYearId: uuid.nullable(),
  destinationGradeLevelId: uuid.nullable(),
  destinationSectionId: uuid.nullable(),
  destinationEnrolledOn: date.nullable(),
} as const;

const outcomeShape = {
  studentId: uuid,
  sourceEnrollmentId: uuid,
  disposition: z.enum(progressionDispositions),
  sourceEndOn: date,
  ...destination,
  eligibilityOverrideReason: reason.nullable().default(null),
} as const;

const validateOutcome = <T extends z.ZodRawShape>(shape: T) => z.object(shape).strict().superRefine((value, context) => {
  const outcome = value as unknown as z.infer<z.ZodObject<typeof outcomeShape>>;
  const needsDestination = ["promotion", "retention", "transfer"].includes(outcome.disposition);
  const required = [outcome.destinationSchoolId, outcome.destinationCampusId, outcome.destinationAcademicYearId,
    outcome.destinationGradeLevelId, outcome.destinationEnrolledOn];
  if (needsDestination && required.some((item) => item === null)) {
    context.addIssue({ code: "custom", message: "destination scope and date are required" });
  }
  if (!needsDestination && [...required, outcome.destinationSectionId].some((item) => item !== null)) {
    context.addIssue({ code: "custom", message: "terminal disposition cannot have a destination" });
  }
});

const outcomeSchema = validateOutcome(outcomeShape);

export const createProgressionDecisionSchema = validateOutcome({ requestId: uuid, ...outcomeShape });
export const refreshProgressionEligibilitySchema = z.object({ requestId: uuid, progressionDecisionId: uuid }).strict();
export const approveProgressionDecisionSchema = z.object({ requestId: uuid, progressionDecisionId: uuid, approvalReason: reason }).strict();
export const executeProgressionDecisionSchema = z.object({ requestId: uuid, progressionDecisionId: uuid }).strict();
export const cancelProgressionDecisionSchema = z.object({ requestId: uuid, progressionDecisionId: uuid, cancellationReason: reason }).strict();
export const createProgressionCorrectionSchema = validateOutcome({
  requestId: uuid, executedDecisionId: uuid, correctionReason: reason,
  disposition: outcomeShape.disposition, sourceEndOn: outcomeShape.sourceEndOn,
  ...destination, eligibilityOverrideReason: outcomeShape.eligibilityOverrideReason,
});
export const createProgressionBatchSchema = z.object({
  requestId: uuid, sourceSchoolId: uuid, sourceAcademicYearId: uuid,
  items: z.array(outcomeSchema).min(1).max(500),
}).strict().superRefine((value, context) => {
  const seen = new Set<string>();
  value.items.forEach((item, index) => {
    if (seen.has(item.sourceEnrollmentId)) context.addIssue({ code: "custom", path: ["items", index], message: "duplicate source enrollment" });
    seen.add(item.sourceEnrollmentId);
  });
});
export const approveProgressionBatchSchema = z.object({ requestId: uuid, batchId: uuid, approvalReason: reason }).strict();
export const executeProgressionBatchItemSchema = z.object({ requestId: uuid, batchId: uuid, decisionId: uuid }).strict();
export const cancelProgressionBatchSchema = z.object({ requestId: uuid, batchId: uuid, cancellationReason: reason }).strict();

export type CreateProgressionDecisionInput = z.infer<typeof createProgressionDecisionSchema>;
export type RefreshProgressionEligibilityInput = z.infer<typeof refreshProgressionEligibilitySchema>;
export type ApproveProgressionDecisionInput = z.infer<typeof approveProgressionDecisionSchema>;
export type ExecuteProgressionDecisionInput = z.infer<typeof executeProgressionDecisionSchema>;
export type CancelProgressionDecisionInput = z.infer<typeof cancelProgressionDecisionSchema>;
export type CreateProgressionCorrectionInput = z.infer<typeof createProgressionCorrectionSchema>;
export type CreateProgressionBatchInput = z.infer<typeof createProgressionBatchSchema>;
export type ApproveProgressionBatchInput = z.infer<typeof approveProgressionBatchSchema>;
export type ExecuteProgressionBatchItemInput = z.infer<typeof executeProgressionBatchItemSchema>;
export type CancelProgressionBatchInput = z.infer<typeof cancelProgressionBatchSchema>;

type PublicFunctions = Database["public"]["Functions"];
export const progressionRpcNames = [
  "create_progression_decision", "refresh_progression_eligibility", "approve_progression_decision",
  "execute_progression_decision", "cancel_progression_decision", "create_progression_correction",
  "create_progression_batch", "approve_progression_batch", "execute_progression_batch_item",
  "cancel_progression_batch",
] as const satisfies readonly (keyof PublicFunctions)[];

export type ProgressionRpcName = (typeof progressionRpcNames)[number];
export type ProgressionRpcArgs<Name extends ProgressionRpcName> = PublicFunctions[Name]["Args"];
export type ProgressionRpcResult<Name extends ProgressionRpcName> = PublicFunctions[Name]["Returns"];
export type ProgressionExecutionResult = ProgressionRpcResult<"execute_progression_decision">;
export type ProgressionBatchCreateResult = ProgressionRpcResult<"create_progression_batch">;
export type ProgressionBatchItemResult = ProgressionRpcResult<"execute_progression_batch_item">;

export const progressionPermissionCodes = [
  "progression.view", "progression.manage", "progression.approve", "progression.execute", "progression.correct", "progression.cancel",
] as const;
export const progressionEventTypes = [
  "student.progression_decision_created", "student.progression_eligibility_evaluated",
  "student.progression_decision_approved", "student.progression_executed",
  "student.progression_decision_cancelled", "student.progression_correction_created",
  "student.progression_corrected", "student.progression_batch_created",
  "student.progression_batch_approved",
  "student.progression_batch_completed",
] as const;

export type ProgressionCommandErrorCode = "22023" | "23503" | "23505" | "23P01" | "40001" | "42501" | "P0002";
export const isRetryableProgressionCommandError = (error: { code?: string } | null | undefined) => error?.code === "40001";

export interface ProgressionCommandService {
  createDecision(input: CreateProgressionDecisionInput): Promise<string>;
  refreshEligibility(input: RefreshProgressionEligibilityInput): Promise<string>;
  approveDecision(input: ApproveProgressionDecisionInput): Promise<string>;
  executeDecision(input: ExecuteProgressionDecisionInput): Promise<ProgressionExecutionResult>;
  cancelDecision(input: CancelProgressionDecisionInput): Promise<string>;
  createCorrection(input: CreateProgressionCorrectionInput): Promise<string>;
  createBatch(input: CreateProgressionBatchInput): Promise<ProgressionBatchCreateResult>;
  approveBatch(input: ApproveProgressionBatchInput): Promise<string>;
  executeBatchItem(input: ExecuteProgressionBatchItemInput): Promise<ProgressionBatchItemResult>;
  cancelBatch(input: CancelProgressionBatchInput): Promise<string>;
}

export const progressionModule = {
  name: "progression",
  rpcNames: progressionRpcNames,
  permissionCodes: progressionPermissionCodes,
  eventTypes: progressionEventTypes,
} as const;
