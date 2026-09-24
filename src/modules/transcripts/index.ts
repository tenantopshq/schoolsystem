import { z } from "zod";

import type { Database } from "../../platform/database/database.types";

const uuid = z.string().uuid();
const reason = z.string().trim().min(1).max(500);
const name = z.string().trim().min(1).max(120);
const fourDecimal = z.number().finite().nonnegative().refine(
  (value) => Number.isInteger(value * 10_000),
  "value allows at most four decimal places",
);
const percentage = z.number().finite().min(0).max(100).refine(
  (value) => Number.isInteger(value * 10_000),
  "percentage allows at most four decimal places",
);

export const transcriptTermSchema = z.object({ academicTermId: uuid }).strict();
export const transcriptExclusionSchema = z.object({
  academicTermId: uuid,
  subjectId: uuid.nullable(),
  reason,
}).strict();

const uniqueTerms = z.array(transcriptTermSchema).min(1).max(100).superRefine((items, context) => {
  const ids = new Set<string>();
  items.forEach((item, index) => {
    if (ids.has(item.academicTermId)) context.addIssue({ code: "custom", path: [index, "academicTermId"], message: "duplicate academic term" });
    ids.add(item.academicTermId);
  });
});

const uniqueExclusions = z.array(transcriptExclusionSchema).max(1_000).superRefine((items, context) => {
  const keys = new Set<string>();
  items.forEach((item, index) => {
    const key = `${item.academicTermId}:${item.subjectId ?? "term"}`;
    if (keys.has(key)) context.addIssue({ code: "custom", path: [index], message: "duplicate exclusion" });
    keys.add(key);
  });
});

export const createTranscriptSchema = z.object({ studentId: uuid, schoolId: uuid, terms: uniqueTerms, exclusions: uniqueExclusions.default([]) }).strict();
export const rebuildTranscriptSchema = z.object({ transcriptId: uuid, terms: uniqueTerms, exclusions: uniqueExclusions.default([]), rebuildReason: reason }).strict();
export const reviewTranscriptSchema = z.object({ transcriptId: uuid, reviewReason: reason }).strict();
export const returnTranscriptToDraftSchema = z.object({ transcriptId: uuid, reason }).strict();
export const issueTranscriptSchema = z.object({ transcriptId: uuid, issuanceReason: reason }).strict();
export const cancelTranscriptSchema = z.object({ transcriptId: uuid, cancellationReason: reason }).strict();
export const correctTranscriptSchema = z.object({ transcriptId: uuid, correctionReason: reason }).strict();

export const transcriptGpaBandSchema = z.object({
  sequence: z.number().int().min(1),
  lowerBound: percentage,
  upperBound: percentage,
  resultState: z.enum(["pass", "fail", "incomplete", "withdrawn", "transferred", "non_credit"]),
  gradePoints: fourDecimal,
}).strict();

export const transcriptSubjectCreditSchema = z.object({
  subjectId: uuid,
  attemptedCredits: fourDecimal,
  earnedCredits: fourDecimal,
}).strict().refine((value) => value.earnedCredits <= value.attemptedCredits, { message: "earned credits cannot exceed attempted credits" });

const policyContent = {
  name,
  gpaScale: fourDecimal.refine((value) => value > 0, "GPA scale must be positive"),
  decimalPlaces: z.number().int().min(0).max(4),
  includeFailInGpa: z.boolean(),
  includeIncompleteInGpa: z.boolean(),
  includeWithdrawnInGpa: z.boolean(),
  bands: z.array(transcriptGpaBandSchema).min(1).max(100),
  subjectCredits: z.array(transcriptSubjectCreditSchema).max(1_000),
} as const;

const validatePolicy = <T extends z.ZodRawShape>(shape: T) => z.object(shape).strict().superRefine((value, context) => {
  const bands = value.bands as z.infer<typeof transcriptGpaBandSchema>[];
  const scale = value.gpaScale as number;
  const subjects = value.subjectCredits as z.infer<typeof transcriptSubjectCreditSchema>[];
  const subjectIds = new Set<string>();
  subjects.forEach((credit, index) => {
    if (subjectIds.has(credit.subjectId)) context.addIssue({ code: "custom", path: ["subjectCredits", index], message: "duplicate subject credit" });
    subjectIds.add(credit.subjectId);
  });
  bands.forEach((band, index) => {
    if (band.sequence !== index + 1) context.addIssue({ code: "custom", path: ["bands", index, "sequence"], message: "band sequences must be dense" });
    if (band.lowerBound >= band.upperBound) context.addIssue({ code: "custom", path: ["bands", index], message: "lower bound must precede upper bound" });
    if (band.gradePoints > scale) context.addIssue({ code: "custom", path: ["bands", index, "gradePoints"], message: "grade points exceed GPA scale" });
    if (band.resultState === "non_credit" && band.gradePoints !== 0) context.addIssue({ code: "custom", path: ["bands", index, "gradePoints"], message: "non-credit band must have zero points" });
    if (index === 0 && band.lowerBound !== 0) context.addIssue({ code: "custom", path: ["bands", index, "lowerBound"], message: "bands must start at zero" });
    if (index > 0 && band.lowerBound !== bands[index - 1]!.upperBound) context.addIssue({ code: "custom", path: ["bands", index, "lowerBound"], message: "bands must be contiguous" });
  });
  if (bands.at(-1)?.upperBound !== 100) context.addIssue({ code: "custom", path: ["bands"], message: "bands must end at 100" });
});

export const createTranscriptCalculationPolicySchema = validatePolicy({ schoolId: uuid, ...policyContent });
export const updateDraftTranscriptCalculationPolicySchema = validatePolicy({ id: uuid, ...policyContent });
export const reviseTranscriptCalculationPolicySchema = validatePolicy({ id: uuid, ...policyContent });
const transcriptPolicyIdSchema = z.object({ id: uuid }).strict();
export const activateTranscriptCalculationPolicySchema = transcriptPolicyIdSchema.extend({}).strict();
export const retireTranscriptCalculationPolicySchema = transcriptPolicyIdSchema.extend({}).strict();

export type CreateTranscriptInput = z.infer<typeof createTranscriptSchema>;
export type RebuildTranscriptInput = z.infer<typeof rebuildTranscriptSchema>;
export type ReviewTranscriptInput = z.infer<typeof reviewTranscriptSchema>;
export type ReturnTranscriptToDraftInput = z.infer<typeof returnTranscriptToDraftSchema>;
export type IssueTranscriptInput = z.infer<typeof issueTranscriptSchema>;
export type CancelTranscriptInput = z.infer<typeof cancelTranscriptSchema>;
export type CorrectTranscriptInput = z.infer<typeof correctTranscriptSchema>;
export type CreateTranscriptCalculationPolicyInput = z.infer<typeof createTranscriptCalculationPolicySchema>;
export type UpdateDraftTranscriptCalculationPolicyInput = z.infer<typeof updateDraftTranscriptCalculationPolicySchema>;
export type ReviseTranscriptCalculationPolicyInput = z.infer<typeof reviseTranscriptCalculationPolicySchema>;

type PublicFunctions = Database["public"]["Functions"];
export const transcriptRpcNames = [
  "create_transcript", "rebuild_transcript", "review_transcript", "return_transcript_to_draft",
  "issue_transcript", "cancel_transcript", "correct_transcript",
  "create_transcript_calculation_policy", "update_draft_transcript_calculation_policy",
  "activate_transcript_calculation_policy", "revise_transcript_calculation_policy",
  "retire_transcript_calculation_policy",
] as const satisfies readonly (keyof PublicFunctions)[];

export type TranscriptRpcName = (typeof transcriptRpcNames)[number];
export type TranscriptRpcArgs<Name extends TranscriptRpcName> = PublicFunctions[Name]["Args"];
export type TranscriptRpcResult<Name extends TranscriptRpcName> = PublicFunctions[Name]["Returns"];
export type CorrectTranscriptResult = TranscriptRpcResult<"correct_transcript">[number];

export const transcriptStatuses = ["draft", "reviewed", "issued", "superseded", "corrected", "cancelled"] as const;
export const transcriptResultStates = ["pass", "fail", "incomplete", "withdrawn", "transferred", "non_credit"] as const;
export const transcriptPermissionCodes = ["transcripts.view", "transcripts.manage", "transcripts.correct"] as const;
export const transcriptEventTypes = [
  "transcript.draft_created", "transcript.rebuild_started", "transcript.reviewed",
  "transcript.returned_to_draft", "transcript.issued", "transcript.superseded",
  "transcript.corrected", "transcript.cancelled", "transcript_policy.draft_created",
  "transcript_policy.draft_updated", "transcript_policy.activated",
  "transcript_policy.revision_created", "transcript_policy.retired",
] as const;

export type TranscriptStatus = (typeof transcriptStatuses)[number];
export type TranscriptResultState = (typeof transcriptResultStates)[number];
export type TranscriptPermissionCode = (typeof transcriptPermissionCodes)[number];
export type TranscriptEventType = (typeof transcriptEventTypes)[number];
export type TranscriptCommandErrorCode = "22023" | "23503" | "23505" | "40001" | "42501" | "P0002";
export const isRetryableTranscriptCommandError = (error: { code?: string } | null | undefined) => error?.code === "40001";

export interface TranscriptCommandService {
  createTranscript(input: CreateTranscriptInput): Promise<string>;
  rebuildTranscript(input: RebuildTranscriptInput): Promise<string>;
  reviewTranscript(input: ReviewTranscriptInput): Promise<string>;
  returnTranscriptToDraft(input: ReturnTranscriptToDraftInput): Promise<string>;
  issueTranscript(input: IssueTranscriptInput): Promise<string>;
  cancelTranscript(input: CancelTranscriptInput): Promise<string>;
  correctTranscript(input: CorrectTranscriptInput): Promise<CorrectTranscriptResult>;
}

export interface TranscriptPolicyCommandService {
  createPolicy(input: CreateTranscriptCalculationPolicyInput): Promise<string>;
  updateDraftPolicy(input: UpdateDraftTranscriptCalculationPolicyInput): Promise<string>;
  revisePolicy(input: ReviseTranscriptCalculationPolicyInput): Promise<string>;
  activatePolicy(id: string): Promise<string>;
  retirePolicy(id: string): Promise<string>;
}

export const transcriptsModule = {
  name: "transcripts",
  rpcNames: transcriptRpcNames,
  permissionCodes: transcriptPermissionCodes,
  eventTypes: transcriptEventTypes,
} as const;
