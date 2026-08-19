import type { Database } from "@/platform/database/database.types";

/** Public boundary for academic years and terms. */
export const academicsModule = { name: "academics" } as const;

export const academicMutationRpcNames = [
  "create_staff_profile",
  "update_staff_profile",
  "archive_staff_profile",
  "create_building",
  "update_building",
  "archive_building",
  "create_room",
  "update_room",
  "archive_room",
  "create_grade_level",
  "update_grade_level",
  "archive_grade_level",
  "create_subject",
  "update_subject",
  "archive_subject",
  "create_section",
  "update_section",
  "archive_section",
  "create_academic_year",
  "update_academic_year",
  "transition_academic_year_status",
  "create_academic_term",
  "update_academic_term",
  "transition_academic_term_status",
] as const satisfies readonly (keyof Database["public"]["Functions"])[];

export type AcademicMutationRpcName = (typeof academicMutationRpcNames)[number];

export type AcademicMutationRpcArgs<Name extends AcademicMutationRpcName> =
  Database["public"]["Functions"][Name]["Args"];

export type AcademicMutationRpcResult<Name extends AcademicMutationRpcName> =
  Database["public"]["Functions"][Name]["Returns"];
