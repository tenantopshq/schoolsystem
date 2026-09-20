import { z } from "zod";

import type { Database } from "../../platform/database/database.types";

const uuid = z.string().uuid();
const reason = z.string().trim().min(1).max(500);

export const reportCardStatuses = ["draft", "finalized", "published", "corrected", "cancelled"] as const;
export const reportCardCommentTypes = ["overall", "subject"] as const;
export const reportCardCommentStatuses = ["active", "withdrawn"] as const;
export const reportCardSignoffTypes = [
  "subject_teacher", "homeroom_teacher", "administrator_reviewer", "administrator_correction_certification",
] as const;
export const reportCardSignoffStatuses = ["active", "revoked"] as const;
export const reportCardBatchStatuses = ["draft", "reviewed", "cancelled"] as const;

export const createReportCardSchema = z.object({ studentId: uuid, sectionId: uuid, academicTermId: uuid }).strict();
export const createReportCardBatchSchema = z.object({
  sectionId: uuid,
  academicTermId: uuid,
  students: z.array(z.object({ studentId: uuid }).strict()).min(1).max(500),
}).strict().superRefine((value, context) => {
  if (new Set(value.students.map((student) => student.studentId)).size !== value.students.length) {
    context.addIssue({ code: "custom", path: ["students"], message: "student IDs must be unique" });
  }
});
export const saveReportCardCommentSchema = z.object({
  reportCardId: uuid,
  commentType: z.enum(reportCardCommentTypes),
  subjectId: uuid.nullable(),
  body: z.string().trim().min(1).max(2_000),
}).strict().superRefine((value, context) => {
  if ((value.commentType === "overall") !== (value.subjectId === null)) {
    context.addIssue({ code: "custom", path: ["subjectId"], message: "overall comments require null subject; subject comments require a subject" });
  }
});
export const withdrawReportCardCommentSchema = z.object({ id: uuid, reason }).strict();
export const signReportCardSchema = z.object({
  reportCardId: uuid,
  signoffType: z.enum(["subject_teacher", "homeroom_teacher", "administrator_reviewer"]),
  subjectId: uuid.nullable(),
}).strict().superRefine((value, context) => {
  const subjectRequired = value.signoffType === "subject_teacher";
  if (subjectRequired !== (value.subjectId !== null)) {
    context.addIssue({ code: "custom", path: ["subjectId"], message: "subject-teacher sign-off requires a subject; other public sign-offs require null" });
  }
});
export const revokeReportCardSignoffSchema = z.object({ id: uuid, reason }).strict();
export const reportCardIdSchema = z.object({ reportCardId: uuid }).strict();
export const reportCardBatchIdSchema = z.object({ reportCardBatchId: uuid }).strict();
export const cancelDraftReportCardSchema = reportCardIdSchema.extend({ cancellationReason: reason }).strict();
export const correctReportCardSchema = reportCardIdSchema.extend({ correctionReason: reason }).strict();
export const cancelReportCardBatchSchema = reportCardBatchIdSchema.extend({ cancellationReason: reason }).strict();

export type CreateReportCardInput = z.infer<typeof createReportCardSchema>;
export type CreateReportCardBatchInput = z.infer<typeof createReportCardBatchSchema>;
export type SaveReportCardCommentInput = z.infer<typeof saveReportCardCommentSchema>;
export type WithdrawReportCardCommentInput = z.infer<typeof withdrawReportCardCommentSchema>;
export type SignReportCardInput = z.infer<typeof signReportCardSchema>;
export type RevokeReportCardSignoffInput = z.infer<typeof revokeReportCardSignoffSchema>;
export type ReportCardIdInput = z.infer<typeof reportCardIdSchema>;
export type ReportCardBatchIdInput = z.infer<typeof reportCardBatchIdSchema>;
export type CancelDraftReportCardInput = z.infer<typeof cancelDraftReportCardSchema>;
export type CorrectReportCardInput = z.infer<typeof correctReportCardSchema>;
export type CancelReportCardBatchInput = z.infer<typeof cancelReportCardBatchSchema>;

type PublicFunctions = Database["public"]["Functions"];
export const reportCardRpcNames = [
  "create_report_card", "create_report_card_batch", "save_report_card_comment", "withdraw_report_card_comment",
  "sign_report_card", "revoke_report_card_signoff", "review_report_card_batch", "finalize_report_card",
  "publish_report_card", "cancel_draft_report_card", "correct_report_card", "cancel_report_card_batch",
] as const satisfies readonly (keyof PublicFunctions)[];
export type ReportCardRpcName = (typeof reportCardRpcNames)[number];
export type ReportCardRpcArgs<Name extends ReportCardRpcName> = PublicFunctions[Name]["Args"];
export type ReportCardRpcResult<Name extends ReportCardRpcName> = PublicFunctions[Name]["Returns"];
export type CreateReportCardBatchResult = ReportCardRpcResult<"create_report_card_batch">[number];
export type CorrectReportCardResult = ReportCardRpcResult<"correct_report_card">[number];

export const reportCardPermissionCodes = ["report_cards.view", "report_cards.manage", "report_cards.correct"] as const;
export const reportCardEventTypes = [
  "report_card.created", "report_card.comment_saved", "report_card.comment_withdrawn", "report_card.signed",
  "report_card.signoff_revoked", "report_card.finalized", "report_card.published", "report_card.cancelled",
  "report_card.corrected", "report_card_batch.created", "report_card_batch.reviewed", "report_card_batch.cancelled",
] as const;

export type ReportCardCommandErrorCode = "22023" | "23503" | "23505" | "23P01" | "40001" | "42501" | "P0002";
export const isRetryableReportCardCommandError = (error: { code?: string } | null | undefined) => error?.code === "40001";

export interface ReportCardCommandService {
  createReportCard(input: CreateReportCardInput): Promise<string>;
  createReportCardBatch(input: CreateReportCardBatchInput): Promise<CreateReportCardBatchResult>;
  saveReportCardComment(input: SaveReportCardCommentInput): Promise<string>;
  withdrawReportCardComment(input: WithdrawReportCardCommentInput): Promise<string>;
  signReportCard(input: SignReportCardInput): Promise<string>;
  revokeReportCardSignoff(input: RevokeReportCardSignoffInput): Promise<string>;
  reviewReportCardBatch(input: ReportCardBatchIdInput): Promise<string>;
  finalizeReportCard(input: ReportCardIdInput): Promise<string>;
  publishReportCard(input: ReportCardIdInput): Promise<string>;
  cancelDraftReportCard(input: CancelDraftReportCardInput): Promise<string>;
  correctReportCard(input: CorrectReportCardInput): Promise<CorrectReportCardResult>;
  cancelReportCardBatch(input: CancelReportCardBatchInput): Promise<string>;
}

export interface ReportCardReadService {
  listStudentPublishedCards(studentId: string): Promise<readonly Database["public"]["Tables"]["report_cards"]["Row"][]>;
}

export const reportCardsModule = {
  name: "report-cards",
  rpcNames: reportCardRpcNames,
  permissionCodes: reportCardPermissionCodes,
  eventTypes: reportCardEventTypes,
} as const;
