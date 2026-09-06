import { z } from "zod";

import type { Database } from "../../platform/database/database.types";

const uuid = z.string().uuid();
const nullableDescription = z.string().trim().min(1).max(1_000).nullable();
const reason = z.string().trim().min(1).max(500);
const percentage = z.number().finite().min(0).max(100).refine(
  (value) => Number.isInteger(value * 10_000),
  "percentage allows at most four decimal places",
);

export const gradeScaleBandSchema = z.object({
  sequence: z.number().int().min(1),
  lowerBound: percentage,
  upperBound: percentage,
  label: z.string().trim().min(1).max(32),
  resultState: z.enum(["pass", "fail"]),
}).strict();

const bands = z.array(gradeScaleBandSchema).min(1).max(100).superRefine((items, context) => {
  const labels = new Set<string>();
  items.forEach((band, index) => {
    if (band.sequence !== index + 1) context.addIssue({ code: "custom", path: [index, "sequence"], message: "sequences must be dense" });
    if (band.lowerBound >= band.upperBound) context.addIssue({ code: "custom", path: [index], message: "lower bound must precede upper bound" });
    if (index === 0 && band.lowerBound !== 0) context.addIssue({ code: "custom", path: [index, "lowerBound"], message: "scale must start at zero" });
    if (index > 0 && band.lowerBound !== items[index - 1]!.upperBound) context.addIssue({ code: "custom", path: [index, "lowerBound"], message: "bands must be contiguous" });
    const label = band.label.trim().toLocaleLowerCase("en-US");
    if (labels.has(label)) context.addIssue({ code: "custom", path: [index, "label"], message: "duplicate label" });
    labels.add(label);
  });
  if (items.at(-1)?.upperBound !== 100) context.addIssue({ code: "custom", message: "scale must end at 100" });
});

export const createGradeScaleSchema = z.object({ schoolId: uuid, academicYearId: uuid.nullable(), name: z.string().trim().min(1).max(120), description: nullableDescription, bands }).strict();
export const updateDraftGradeScaleSchema = z.object({ id: uuid, name: z.string().trim().min(1).max(120), description: nullableDescription, setDescription: z.boolean(), bands }).strict();
export const reviseGradeScaleSchema = z.object({ id: uuid, replacementName: z.string().trim().min(1).max(120), replacementDescription: nullableDescription, replacementBands: bands }).strict();
export const gradeScaleIdSchema = z.object({ id: uuid }).strict();

export const createTermGradingConfigurationSchema = z.object({ sectionId: uuid, academicTermId: uuid, subjectId: uuid.nullable(), gradeScaleId: uuid, requireWeightsTotal100: z.literal(true), includeUnpublishedFinalized: z.literal(false) }).strict();
export const updateTermGradingConfigurationSchema = z.object({ id: uuid, gradeScaleId: uuid, requireWeightsTotal100: z.literal(true), includeUnpublishedFinalized: z.literal(false) }).strict();
export const reviseTermGradingConfigurationSchema = z.object({ id: uuid, replacementGradeScaleId: uuid, replacementRequireWeightsTotal100: z.literal(true), replacementIncludeUnpublishedFinalized: z.literal(false) }).strict();
export const configurationIdSchema = z.object({ id: uuid }).strict();
export const termGradeSetIdSchema = z.object({ termGradeSetId: uuid }).strict();
export const cancelDraftTermGradesSchema = z.object({ termGradeSetId: uuid, cancellationReason: reason }).strict();
export const correctTermGradesSchema = z.object({ termGradeSetId: uuid, correctionReason: reason }).strict();

type PublicFunctions = Database["public"]["Functions"];
export const termGradeRpcNames = ["create_grade_scale", "update_draft_grade_scale", "activate_grade_scale", "retire_grade_scale", "revise_grade_scale", "create_term_grading_configuration", "update_draft_term_grading_configuration", "activate_term_grading_configuration", "retire_term_grading_configuration", "revise_term_grading_configuration", "calculate_term_grades", "recalculate_draft_term_grades", "publish_term_grades", "finalize_term_grades", "cancel_draft_term_grades", "correct_term_grades"] as const satisfies readonly (keyof PublicFunctions)[];
export type TermGradeRpcName = (typeof termGradeRpcNames)[number];
export type TermGradeRpcArgs<Name extends TermGradeRpcName> = PublicFunctions[Name]["Args"];
export type TermGradeRpcResult<Name extends TermGradeRpcName> = PublicFunctions[Name]["Returns"];
export const gradeScaleStatuses = ["draft", "active", "retired"] as const;
export const gradeResultStates = ["pass", "fail"] as const;
export const termGradeLifecycleStatuses = ["draft", "finalized", "corrected", "cancelled"] as const;
export const termGradePublicationStates = ["unpublished", "published"] as const;
export const termGradePermissionCodes = ["term_grades.view", "term_grades.manage", "term_grades.correct"] as const;
export type TermGradeCommandErrorCode = "22023" | "23503" | "23505" | "23P01" | "40001" | "42501" | "P0002";
export const isRetryableTermGradeCommandError = (error: { code?: string } | null | undefined) => error?.code === "40001";
export const termGradesModule = { name: "term-grades", rpcNames: termGradeRpcNames, permissionCodes: termGradePermissionCodes } as const;
