# Admin UI staff directory v1.4

## Outcome

Add the smallest safe staff UI slice after the v1.3 student directory: staff-aware
context selection, a searchable and paginated staff directory, and a read-only
employment detail page inside the reusable admin shell.

## Scope

- Additive migration 015; migrations 001–014 remain immutable.
- Extend `get_my_admin_contexts()` with `staff_profiles.view` and
  `staff_profiles.manage` effective permissions.
- Add `search_staff_profiles` and `get_staff_admin_detail` authenticated,
  definer-owned read RPCs.
- Allowlist ordinary display-name and employment fields only.
- Add strict Zod/TypeScript contracts, a private Supabase adapter, permission-aware
  navigation, directory/detail routes, generated database types, module docs, and
  adversarial pgTAP tests.

## Exclusions

Staff invitations, authentication provisioning, membership lifecycle, role or
permission management, staff creation/edit/archive UI, teaching assignments,
payroll, workload, contact details, avatars, document storage, deployment, and
production mutation are excluded.

## Decisions

1. The slice is read-only because creating a staff profile without an explicit
   identity and membership workflow would expose a partial lifecycle.
2. Home school/campus determines administrative directory scope; cross-campus
   teaching assignments do not change employment-profile visibility.
3. Display name, first/middle/last name, staff number, employment type, title,
   department, home placement, employment dates, and record status are visible.
4. Email, phone, avatar path, user and membership IDs, roles, and permissions are excluded.
5. Detail reads are authorized by the database and narrowed again by the signed selected context.
6. Pagination is deterministic ascending keyset pagination; additional sort modes are deferred.

## Verification

Fresh migration application, the full pgTAP suite, generated-type validation,
frontend unit tests, strict typecheck, production build, and `git diff --check` are
required before review.
