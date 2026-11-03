import type { AdminContext } from "@/modules/organizations";
import type { StudentDirectoryQuery } from "../index";

export function constrainDirectoryQuery(
  selected: AdminContext,
  contexts: AdminContext[],
  query: StudentDirectoryQuery,
): StudentDirectoryQuery {
  if (selected.campusId) return { ...query, school: selected.schoolId, campus: selected.campusId };
  if (selected.schoolId) {
    const requestedCampus = query.school === null || query.school === selected.schoolId ? query.campus : null;
    const campusAllowed = requestedCampus !== null && contexts.some((context) =>
      context.organizationId === selected.organizationId && context.schoolId === selected.schoolId &&
      context.campusId === requestedCampus && context.permissionCodes.includes("students.view"),
    );
    return { ...query, school: selected.schoolId, campus: campusAllowed ? requestedCampus : null };
  }
  if (!query.school) return { ...query, campus: null };
  const requestedCampus = query.campus;
  const targetAllowed = contexts.some((context) =>
    context.organizationId === selected.organizationId && context.schoolId === query.school &&
    context.campusId === requestedCampus && context.permissionCodes.includes("students.view"),
  );
  return targetAllowed ? query : { ...query, school: null, campus: null };
}
