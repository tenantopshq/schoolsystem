# Organization Onboarding v1.8

## Outcome

An authenticated user can create and resume one or more organization onboarding
flows. Bootstrap creates the organization, active creator membership, protected
organization-owner role, fixed permission grants, organization-wide owner
assignment, audit record, and outbox event in one transaction. The selected owner
then creates or selects the first school and creates or selects that school's first
campus. Completion reauthorizes the campus context, writes the signed context
cookie, and redirects to `/admin`.

This release does not add academic-year setup, billing, invitations, branding,
staff creation, or service-role use in browser or ordinary request code.

## Fixed organization-owner permission set

`ORGANIZATION_OWNER` is an organization-scoped, system-managed role. Migration 020
grants exactly the following 49 permission codes already present in migrations
001-013; it neither invents permissions nor grants contextual teacher, student,
guardian, or portal access:

- Organization and school/campus: `organizations.view`, `organizations.manage`,
  `schools.view`, `schools.manage`.
- Membership and roles: `memberships.view`, `memberships.manage`, `roles.view`,
  `roles.manage`.
- Academic setup: `academic_periods.view`, `academic_periods.manage`,
  `academic_structure.view`, `academic_structure.manage`.
- Students: `students.view`, `students.create`, `students.edit`,
  `students.archive`, `students.sensitive_view`, `students.sensitive_manage`,
  `student_documents.manage`.
- Enrollment: `enrollments.view`, `enrollments.manage`, `enrollments.correct`.
- Staff: `staff_profiles.view`, `staff_profiles.manage`.
- Teaching: `teaching_assignments.view`, `teaching_assignments.manage`,
  `teaching_assignments.correct`.
- Attendance: `attendance.view`, `attendance.manage`, `attendance.correct`.
- Assessments: `assessments.view`, `assessments.manage`, `assessments.correct`.
- Term grades: `term_grades.view`, `term_grades.manage`, `term_grades.correct`.
- Report cards: `report_cards.view`, `report_cards.manage`,
  `report_cards.correct`.
- Transcripts: `transcripts.view`, `transcripts.manage`, `transcripts.correct`.
- Promotion/progression: `progression.view`, `progression.manage`,
  `progression.approve`, `progression.execute`, `progression.correct`,
  `progression.cancel`.
- Audit: `audit.view`.

The organization-wide assignment makes scoped permissions effective for schools and
campuses in that organization through the existing `app_auth.has_permission`
contract. Relationship-based portal access remains separate and is not implied by
this role.

## Additive migration 020

The only schema migration is
`supabase/migrations/202608190020_organization_onboarding_v1_8.sql`. Shared
migrations remain immutable.

### Protected-role schema and guards

1. Add nullable `roles.system_role_key text`, with a check allowing only
   `ORGANIZATION_OWNER`, and a unique partial index on
   `(organization_id, system_role_key)` where the key is non-null. Add a check that
   a keyed role has `is_system_role = true`, `code = 'ORGANIZATION_OWNER'`, and
   `status = 'active'`.
2. Add a `BEFORE INSERT OR UPDATE OR DELETE` trigger on `roles`. A protected insert
   must have the fixed code, name, description, system flag, and active status;
   transition of an existing custom role into or out of the protected key is
   forbidden. For an existing protected row, reject deletion and any change to
   organization, key, code, name, description, system flag, or status. This blocks
   renaming, archiving, reassignment, or weakening even if a future grant or
   security-definer RPC reaches the table. Ordinary custom roles remain mutable.
3. Add `BEFORE INSERT OR UPDATE OR DELETE` guards on `role_permissions`. Resolve
   the role under lock. For the protected owner role, reject deletion, reject an
   update away from the role or permission, and reject insertion of any permission
   outside the fixed 49-code allowlist. Deferred constraint triggers are attached
   to both protected-role insert/update mutations and protected role-permission
   insert/update/delete mutations. At transaction end they verify that every
   affected protected owner role has exactly the allowlist—no missing and no extra
   grants. Attaching validation to the role itself ensures a protected role cannot
   commit with zero role-permission rows. This permits bootstrap to insert the fixed
   set in one transaction but prevents missing grants, required-permission removal,
   and caller-controlled additions.
4. Keep the v1.6 revocation of browser `INSERT`, `UPDATE`, `DELETE`, and `TRUNCATE`
   on roles and role-permission tables. Explicitly revoke again in migration 020.
   Trigger functions are owned by `postgres`, use `SECURITY DEFINER SET
   search_path = ''`, and are non-executable by `public`, `anon`, `authenticated`,
   and `service_role`. Existing role-assignment RPCs may reference a protected role
   but cannot alter its definition or permission set.
5. Add indexes needed by onboarding authorization and traversal:
   `roles(organization_id, system_role_key)` via the unique partial index,
   `role_assignments(organization_id, organization_membership_id, role_id,
   school_id, campus_id, status)`, and school/campus normalized-code lookup indexes
   where existing unique indexes do not already cover the exact path. No duplicate
   index will be added when an existing leading-key index satisfies the query.

### Private replay receipts

Add `app_auth.onboarding_command_receipts` with:

- `actor_user_id uuid NOT NULL REFERENCES auth.users(id)`;
- `command_name text NOT NULL`;
- `request_id uuid NOT NULL`;
- `argument_hash bytea NOT NULL CHECK (octet_length(argument_hash) = 32)`;
- nullable `organization_id`, nullable `result_id`, `completed boolean`, and
  timestamps;
- primary key `(actor_user_id, command_name, request_id)`.

The receipt key deliberately does not require a pre-existing organization. Each
command first normalizes and validates every argument, then calculates the SHA-256
hash of its canonical `jsonb_build_array(...)`, and only then claims the replay
receipt. No receipt is claimed for malformed or non-canonicalizable input. Reuse
with identical arguments returns the stored result; reuse with
different arguments raises `22023`; an observed incomplete matching receipt raises
retryable `40001`. The receipt and domain/audit/outbox writes share the same
transaction, so failed commands leave no durable partial receipt.

Private claim/complete helpers are `SECURITY DEFINER SET search_path = ''`, owned by
`postgres`, and revoked from all client roles.

## Exact public database interfaces

All functions below are owned by `postgres`, use `SECURITY DEFINER SET search_path
= ''`, are revoked from `public`, `anon`, `authenticated`, and `service_role`, then
granted `EXECUTE` only to `authenticated`. No function accepts an actor, membership,
role, permission list, role assignment, audit/outbox payload, or service credential.

```sql
public.bootstrap_organization_v1_8(
  request_id uuid,
  organization_name text,
  organization_slug text
) returns uuid

public.create_onboarding_school_v1_8(
  request_id uuid,
  organization_id uuid,
  school_name text,
  school_code text
) returns uuid

public.create_onboarding_campus_v1_8(
  request_id uuid,
  organization_id uuid,
  school_id uuid,
  campus_name text,
  campus_code text
) returns uuid

public.list_my_owned_onboarding_organizations_v1_8()
returns table (
  organization_id uuid,
  organization_name text,
  organization_slug text,
  school_count bigint,
  campus_count bigint,
  is_complete boolean,
  updated_at timestamptz
)

public.list_my_owned_onboarding_schools_v1_8(
  p_organization_id uuid
)
returns table (
  school_id uuid,
  school_name text,
  school_code text,
  campus_count bigint,
  updated_at timestamptz
)

public.get_my_organization_onboarding_state_v1_8(
  p_organization_id uuid,
  p_school_id uuid default null
)
returns table (
  organization_id uuid,
  organization_name text,
  organization_slug text,
  membership_id uuid,
  selected_school_id uuid,
  selected_school_name text,
  selected_school_code text,
  selected_campus_id uuid,
  selected_campus_name text,
  selected_campus_code text,
  stage text
)

-- Existing signature, replaced only to expand its closed administrative
-- permission projection to the current 49-code catalog:
public.get_my_admin_contexts()
returns table (
  membership_id uuid,
  organization_id uuid,
  organization_name text,
  organization_slug text,
  school_id uuid,
  school_name text,
  school_code text,
  campus_id uuid,
  campus_name text,
  campus_code text,
  scope_level text,
  permission_codes text[]
)
```

`stage` is one of `school`, `school_selection`, `campus`, or `complete` and is
validated by the TypeScript adapter. The state RPC returns at most one row. A null
row is treated as unauthorized/unavailable, never as evidence that the supplied ID
exists.

### Validation and normalization

- `auth.uid()` is required for every interface.
- Names are `btrim`-normalized, must be 2-160 characters, and may not contain
  control characters.
- Slugs are lowercased; every run of characters outside `[a-z0-9]` becomes `-`;
  leading/trailing hyphens are removed. The result must be 2-63 characters and
  match `^[a-z0-9]+(?:-[a-z0-9]+)*$`.
- School and campus codes are uppercased; every run outside `[A-Z0-9]` becomes `-`;
  leading/trailing hyphens are removed. The result must be 1-32 characters and
  match `^[A-Z0-9]+(?:-[A-Z0-9]+)*$`.
- Organization slugs remain globally unique, school codes are unique within an
  organization, and campus codes are unique within a school. Comparisons use the
  stored normalized values.
- Bootstrap uses database defaults `en`, `UTC`, and `USD`; v1.8 does not accept
  caller-selected locale, timezone, or currency.
- Strict Zod contracts apply the same rules before RPC invocation, but PostgreSQL
  repeats all validation and authorization.

### Stable errors

- `42501`: anonymous caller, inactive owner membership/assignment, missing owner
  authority, or an organization/school outside the actor's owned scope. Missing and
  unauthorized supplied IDs intentionally share this result.
- `22023`: malformed normalized input, null request ID, request-ID argument
  mismatch, incompatible school/campus selection, or protected-role mutation.
- `23505`: stable messages `organization slug already exists`, `school code already
  exists`, or `campus code already exists` after the command owns the corresponding
  deterministic lock.
- `40001`: matching command in progress or lock/discovery drift that is safe to
  retry with the same request ID.

Application actions map these codes to allowlisted user messages and never surface
database details.

## Authorization, replay, and deterministic locks

### Organization bootstrap

1. Read `auth.uid()`, normalize and validate name/slug, and hash those canonical
   values.
2. Claim/lock receipt `(actor, 'bootstrap_organization_v1_8', request_id)` with the
   canonical hash.
3. Acquire advisory transaction locks in namespace order: actor UUID, then
   normalized slug. Recheck slug uniqueness.
4. Insert organization, active creator membership, protected role, exactly 49 role
   permissions, and an organization-wide active assignment. The caller supplies
   none of their IDs or contents.
5. Insert one correlated audit record and one outbox event for the organization
   bootstrap and complete the receipt. A single command ID is stored in both
   records; unique command/entity indexes prevent duplication.

Multiple organizations per actor are allowed. A replay of one request returns only
that request's organization and does not infer completion from another organization
the actor owns.

### School creation

1. Claim the actor/command/request receipt and include normalized organization ID,
   name, and code in the argument hash.
2. Lock in this order: organization row, actor's membership row, protected owner
   role, active organization-wide owner assignment, then the normalized
   organization/code advisory key.
3. Reauthorize every supplied organization ID from `auth.uid()`, an active
   membership, and an active organization-wide assignment to that organization's
   protected `ORGANIZATION_OWNER` role. Also require scoped `schools.manage`.
4. Insert the school plus one correlated audit and outbox record, then complete the
   receipt.

### Campus creation

1. Claim the receipt and hash normalized organization ID, school ID, name, and code.
2. Lock organization, actor membership, protected role, active organization-wide
   owner assignment, selected school, then the normalized school/code advisory key.
3. Reauthorize the supplied organization as above and require the supplied school
   to be active and belong to that organization. Require `schools.manage` for that
   exact school.
4. Insert the campus plus one correlated audit and outbox record, then complete the
   receipt.

Parent rows always precede children; UUID sets are sorted before any future
multi-row lock. No authorization decision trusts a browser-supplied tenant or parent
identifier by itself.

## Multi-organization selection and resumability

- `/onboarding` calls `list_my_owned_onboarding_organizations_v1_8`. It shows each
  reauthorized owned organization separately, including incomplete/complete state,
  and offers “Create another organization.” It never silently chooses the most
  recent organization.
- Choosing an organization navigates with its UUID. Each subsequent route calls
  `get_my_organization_onboarding_state_v1_8`; the UUID is only a lookup hint and is
  reauthorized from `auth.uid()` plus active protected-owner membership and
  assignment on every request.
- School choices come only from
  `list_my_owned_onboarding_schools_v1_8(selected_organization_id)`, which repeats
  the same protected-owner authorization and cannot enumerate another tenant.
- If the selected organization has no active school, the school stage creates one.
  If it has exactly one, that school may complete the stage. If it has multiple,
  the user must explicitly select one before continuing.
- A supplied school UUID is reauthorized as an active child of the explicitly
  selected, reauthorized organization. Only an active campus belonging to that
  explicitly selected school completes the campus stage. Records in another owned
  organization, another school, or merely visible through a different role never
  satisfy onboarding.
- `/onboarding/complete` re-fetches state, requires the exact selected campus to be
  complete, calls the existing signed-cookie setter (which independently resolves
  current administrative contexts), and redirects to `/admin`. Stale or revoked
  ownership returns to `/onboarding` without setting a cookie.

Routes are `/onboarding`, `/onboarding/organization`, `/onboarding/school`,
`/onboarding/campus`, and `/onboarding/complete`. Server actions use strict Zod
contracts and replay request IDs. `/admin` sends an authenticated user with no valid
context to onboarding when they have no contexts, while `/select-context` remains
the switcher for established contexts.

## Module and integration work

1. Extend the organizations public module with strict schemas, onboarding state and
   command types, and an `OrganizationOnboardingService` interface. Put Supabase RPC
   calls and generated database types only in its infrastructure adapter.
2. Add server actions and accessible route UI for organization selection/creation,
   school selection/creation, campus creation, resumable errors, and completion.
3. Extend `get_my_admin_contexts` additively in migration 020 so the owner permission
   set is projected for organization, school, and campus contexts; continue
   reauthorizing the signed cookie on every request.
4. Regenerate `database.types.ts` after the migration is validated. Update the
   organization, identity-access, security, system-overview, and module-boundary
   documentation.

## Verification plan

Add adversarial pgTAP coverage for:

- anonymous denial; inactive membership/assignment denial; foreign-owner and
  cross-tenant organization/school/campus denial;
- malformed names/slugs/codes, normalization, global slug uniqueness,
  organization-scoped school-code uniqueness, and school-scoped campus-code
  uniqueness;
- same-argument replay, mismatched replay, concurrent requests, deterministic lock
  behavior, and absence of duplicate organizations, memberships, roles,
  assignments, audit rows, or outbox rows;
- exact owner bootstrap, all 49 permissions, no portal-only authority, atomic
  rollback, and correlated audit/outbox records;
- rejection of caller-injected role IDs, permission codes, membership IDs, actor
  IDs, organization IDs during bootstrap, or audit/outbox payloads;
- rejection of owner-role rename, archive, delete, system-flag change, permission
  removal, and extra permission insertion through direct SQL and every existing
  role-related RPC, while equivalent operations on ordinary custom roles remain
  available where authorized;
- inability to resume or mutate another user's organization even when its UUID,
  school UUID, or campus UUID is known;
- successful creation of a staff profile by the bootstrapped owner after school and
  campus onboarding, proving `staff_profiles.manage` is effective at the selected
  campus.

Add frontend/service tests for strict validation, stable error mapping,
multi-organization choice, every resumable stage, stale selection, revoked owner
access, foreign identifiers, context-cookie reauthorization, and successful
`/admin` redirect.

Implementation verification will use focused tests during development, then one
clean local reset, complete pgTAP and frontend suites, typecheck, production build,
and `git diff --check`. It will not deploy, commit, push, or modify remote Supabase.

## Approved co-owner decision

An existing owner may assign the protected `ORGANIZATION_OWNER` role to another
active member through the v1.6 role-assignment RPC. Multiple owners reduce lockout
risk, while the existing anti-escalation and last-administrator guards continue to
apply. Assignment never permits mutation of the protected role definition or its
fixed permissions.
