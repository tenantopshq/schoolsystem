import type { AdminContext } from "../index";

export type ContextTarget = { organizationId: string; schoolId: string; campusId: string | null };

export function selectedContextContains(selected: AdminContext, target: ContextTarget): boolean {
  if (target.organizationId !== selected.organizationId) return false;
  if (selected.schoolId !== null && target.schoolId !== selected.schoolId) return false;
  if (selected.campusId !== null && target.campusId !== selected.campusId) return false;
  return true;
}

function matchingContext(contexts: AdminContext[], organizationId: string, schoolId: string, campusId: string | null) {
  return contexts.find((context) =>
    context.organizationId === organizationId && context.schoolId === schoolId && context.campusId === campusId,
  );
}

export function targetHasPermission(
  selected: AdminContext,
  contexts: AdminContext[],
  target: ContextTarget,
  permission: string,
): boolean {
  if (!selectedContextContains(selected, target) || !selected.permissionCodes.includes(permission)) return false;
  const exact = matchingContext(contexts, target.organizationId, target.schoolId, target.campusId);
  const school = matchingContext(contexts, target.organizationId, target.schoolId, null);
  return [exact, school].some((context) => context?.permissionCodes.includes(permission));
}
