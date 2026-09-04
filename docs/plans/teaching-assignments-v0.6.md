# Teaching Assignments v0.6 — Architecture Plan

Status: proposed for review. The scope and product decisions were approved on
2026-09-04, including the eleven binding clarifications recorded below. This plan
does not authorize implementation. Migration 007 must not be created until this
plan is reviewed.

## Objective and boundary

v0.6 adds immutable, effective-dated responsibility records connecting staff to
the existing homeroom-style sections. It establishes the contextual read boundary
needed by later attendance and grading modules without implementing either domain.

In scope:

- section-level homeroom/general and subject-specific teaching assignments;
- lead, co-teacher, assistant, and manually recorded substitute roles;
- future-effective assignments, ordinary ending, atomic reassignment, and
  append-and-supersede correction;
- scoped RBAC management plus current-assignment contextual reads;
- parent lifecycle compatibility checks for sections and academic years, plus
  immediate access revocation when an assignee or referenced parent becomes
  inactive;
- transactional audit/outbox, strict TypeScript/Zod contracts, and adversarial
  pgTAP coverage.

Out of scope:

- timetables, meeting patterns, rooms, periods, conflict detection, course
  offerings, and student subject registration;
- attendance, grading, assessments, transcripts, and report cards;
- workload limits, payroll, automatic assignment generation, and substitute
  scheduling;
- SIS/enrollment mutation authority, teacher access to identifiers, guardians,
  documents, audit, or outbox; and
- bulk import, UI, hard deletion, deployment, and production changes.

The new `teaching_assignments` module consumes public academics, identity, and
enrollment contracts. It does not import another module's private persistence.
Migrations 001–006 remain immutable; every schema and compatibility change below
belongs in additive migration `202608190007_teaching_assignments_v0_6.sql`.

## Relational model

### Enums

```sql
create type public.teaching_assignment_role as enum
  ('lead', 'co_teacher', 'assistant', 'substitute');

create type public.teaching_assignment_status as enum
  ('active', 'ended', 'reassigned', 'corrected');
```

`active` means the record has not been terminated. Calendar effectiveness is
separate: a record is currently effective only when `current_date` is within its
inclusive effective range. `ended`, `reassigned`, and `corrected` are terminal.

### `teaching_assignments`

```text
id uuid primary key default gen_random_uuid()
organization_id uuid not null
school_id uuid not null
campus_id uuid not null
academic_year_id uuid not null
section_id uuid not null
subject_id uuid null
staff_profile_id uuid not null
role teaching_assignment_role not null
starts_on date not null
scheduled_ends_on date not null
ended_on date null
effective_range daterange not null
status teaching_assignment_status not null default active
end_reason text null
reassigned_to_assignment_id uuid null
supersedes_assignment_id uuid null
correction_reason text null
created_at / updated_at timestamptz not null
created_by / updated_by uuid not null
```

Required keys and foreign keys:

- `(organization_id, school_id, campus_id, academic_year_id, section_id)` references
  the migration-006 section scope key;
- `(organization_id, school_id, subject_id)` references `subjects` when non-null;
- `(organization_id, staff_profile_id)` references the existing
  `staff_profiles(organization_id, id)` key;
- `(organization_id, reassigned_to_assignment_id)` and
  `(organization_id, supersedes_assignment_id)` self-reference assignments; and
- all foreign keys use `ON DELETE RESTRICT`.

The command layer derives all scope columns from the locked section. Clients never
supply organization, school, campus, year, actor, command, audit, event, or record
IDs.

Required row constraints:

- `starts_on <= scheduled_ends_on`;
- `ended_on` is null or between `starts_on` and `scheduled_ends_on`;
- `effective_range = daterange(starts_on,
  coalesce(ended_on, scheduled_ends_on), '[]')`;
- active rows have null `ended_on`, `end_reason`, `correction_reason`, and
  `reassigned_to_assignment_id`;
- ended rows require `ended_on` and a trimmed 1–500 character `end_reason`;
- reassigned rows require `ended_on`, a trimmed 1–500 character `end_reason`, and
  `reassigned_to_assignment_id`;
- corrected rows require a trimmed 1–500 character `correction_reason` and never
  become effective, regardless of their retained dates;
- only replacement rows created by the correction command may set
  `supersedes_assignment_id`, and the referenced original must be corrected;
- neither self-reference may point to the same row; and
- organization, school, campus, year, section, subject, staff, role, start,
  scheduled end, creator, and creation time are immutable after insert.

Commands additionally enforce facts that require locked parents:

- section and academic year scope must agree;
- dates are inclusively inside both the section and academic year;
- the section, year, staff profile, and staff membership are active at creation;
- a present subject belongs to the section's organization and school and is active;
- staff home school/campus is descriptive and is not an eligibility constraint;
- a replacement may reuse historical business values but must satisfy current
  parent rules; and
- terminal rows cannot be updated, reactivated, reassigned, or ended again; and
- correction is rejected when the target either points to a reassignment successor
  or is the target of another row's `reassigned_to_assignment_id`. A factual error
  must therefore be corrected before reassignment; v0.6 does not rewrite an atomic
  reassignment pair or chain.

### Lead-overlap enforcement

Install `btree_gist` only with `create extension if not exists` and add two partial
exclusion constraints over rows whose status is `active` and role is `lead`:

```text
homeroom: (section_id WITH =, effective_range WITH &&)
          WHERE subject_id IS NULL

subject:  (section_id WITH =, subject_id WITH =, effective_range WITH &&)
          WHERE subject_id IS NOT NULL
```

This deliberately treats null subject as one real homeroom context rather than
depending on PostgreSQL NULL equality. Multiple overlapping non-lead assignments
and leads for different non-null subjects remain valid. Corrected and terminated
rows do not reserve a lead slot after their actual end; future active rows reserve
their scheduled range.

### Indexes

Migration 007 adds indexes for every foreign key and authorization/RLS traversal:

- `(organization_id, id)` unique;
- `(organization_id, school_id, campus_id, academic_year_id, section_id, status)`;
- `(organization_id, staff_profile_id, status, starts_on, scheduled_ends_on)`;
- `(organization_id, school_id, subject_id, status)` where subject is non-null;
- `(organization_id, reassigned_to_assignment_id)` where non-null;
- `(organization_id, supersedes_assignment_id)` where non-null; and
- GiST support used by both lead exclusion constraints.

## Public command contract

All public functions are `SECURITY DEFINER`, owned deliberately, use an empty
`search_path`, schema-qualify references, and grant execution only to
`authenticated` and `service_role`. Private command implementation helpers are not
executable by PUBLIC, anon, authenticated, or service_role. The only exception is
the three contextual RLS relationship helpers explicitly granted to authenticated
below.

```sql
public.create_teaching_assignment(
  section_id uuid,
  staff_profile_id uuid,
  subject_id uuid,
  role public.teaching_assignment_role,
  starts_on date,
  scheduled_ends_on date
) returns uuid

public.end_teaching_assignment(
  id uuid,
  ended_on date,
  reason text
) returns uuid

public.reassign_teaching_assignment(
  id uuid,
  replacement_staff_profile_id uuid,
  replacement_role public.teaching_assignment_role,
  reassign_on date,
  replacement_scheduled_ends_on date,
  reason text
) returns table(
  from_assignment_id uuid,
  to_assignment_id uuid
)

public.correct_teaching_assignment(
  id uuid,
  replacement_section_id uuid,
  replacement_staff_profile_id uuid,
  replacement_subject_id uuid,
  replacement_role public.teaching_assignment_role,
  replacement_starts_on date,
  replacement_scheduled_ends_on date,
  create_replacement boolean,
  correction_reason text
) returns table(
  corrected_assignment_id uuid,
  replacement_assignment_id uuid
)
```

The four RPCs accept SQL null for a homeroom/general subject context. There is no
caller-supplied status. Create always creates active; end produces ended;
reassignment produces a terminal reassigned source and active destination; and
correction produces corrected plus at most one optional active replacement.

Reassignment preserves section and subject context, ends the source on
`reassign_on - 1`, and starts the replacement on `reassign_on`. It rejects
`reassign_on <= source.starts_on`, dates after the source scheduled end, or a
replacement scheduled end before `reassign_on`. Source scope/start facts are never
rewritten. Changing section or subject because the recorded fact was wrong uses
correction, not reassignment.

Correction locks the original and optional replacement parents, marks the original
corrected, and optionally inserts a replacement linked through
`supersedes_assignment_id`. It never mutates the original business or scope facts.
Before changing anything, it rejects a target that participates on either side of
a reassignment link. This applies even when the target is currently active as the
destination of an earlier reassignment. Atomic paired-history correction is outside
v0.6; operators must correct the source fact before performing reassignment.
No hard-delete, generic JSON, generic operation-name, update, reactivation, or bulk
RPC is exposed.

## Permissions and authorization

Add the versioned permission catalog entries:

| Permission | Capability |
|---|---|
| `teaching_assignments.view` | Read assignments within assigned section scope |
| `teaching_assignments.manage` | Create, end, and reassign assignments |
| `teaching_assignments.correct` | Correct assignment history; also requires manage |

Management authority is evaluated at the destination section's organization,
school, and campus. Create and ordinary reassignment require manage authority over
the destination. End requires manage authority over the stored section. Correction
requires both manage and correct over the original and, when different, replacement
section scopes. An organization-scoped role naturally covers all its sections.

The assignee does not need a teaching-assignment permission. Eligibility instead
requires an active staff profile whose authoritative organization membership is
active. The staff profile's home placement never grants or restricts assignment.
Role assignments continue to govern the actor's authority.

## Locking and concurrency

Every command discovers candidate scope, then locks and re-reads it. If discovered
assignment or parent scope changes before the authoritative re-read, raise SQLSTATE
`40001` so callers may retry the whole command with bounded backoff.

Global lock order:

```text
organization
-> sorted schools
-> sorted campuses
-> sorted academic years
-> sorted sections
-> sorted subjects
-> sorted organization memberships
-> sorted staff profiles
-> sorted teaching assignments
```

Create locks every overlapping active lead candidate in deterministic assignment-ID
order before insertion. End locks the target and any row that points to it.
Reassignment locks the source, destination parents/assignee, and all lead candidates
for both old and new effective ranges before updating/inserting. Correction locks
the original, locks and checks rows that point to it, rejects any discovered
reassignment participation, then locks replacement parents and all relevant lead
candidates. Exclusion-constraint conflicts remain ordinary constraint failures,
not retryable discovery drift.

Reassignment writes the source termination, destination creation, audit rows, and
events in one transaction under one server-generated command ID. Any failure rolls
back all effects.

## Audit and event-outbox contract

Each successful single-row create, end, or correction-without-replacement command
writes exactly one audit row and one event. Reassignment and correction with a
replacement write one audit/event pair per changed aggregate, sharing one command
ID. The existing command-ID indexes already permit correlated multi-row commands.

Events:

- `teaching_assignment.created`
- `teaching_assignment.ended`
- `teaching_assignment.reassigned_out`
- `teaching_assignment.reassigned_in`
- `teaching_assignment.corrected`

Every payload contains `command_id`, `actor_user_id`, `organization_id`,
`assignment_id`/`aggregate_id`, `school_id`, `campus_id`, `academic_year_id`,
`section_id`, nullable `subject_id`, `staff_profile_id`, role, relevant effective
dates and outcome/reason, and linkage IDs when applicable. Payloads contain no
profile names, membership user ID, SIS data, roster, guardian, identifier, document,
audit snapshot, or arbitrary record JSON. Protected audit rows retain reviewed
before/after assignment snapshots.

## RLS and contextual reads

The assignment table enables and forces RLS. `authenticated` receives SELECT only;
direct INSERT, UPDATE, and DELETE remain revoked. Its SELECT policy permits:

- scoped `teaching_assignments.view` or `teaching_assignments.manage`; or
- the assignee, while the assignment is active and `current_date` is inclusively
  within its effective range, resolved through staff profile -> active organization
  membership -> `auth.uid()`.

Migration 007 adds narrowly scoped contextual SELECT access for a currently
assigned teacher to:

- the assigned section and its academic year;
- the assignment's subject when non-null;
- currently effective, non-corrected section placements;
- the corresponding currently effective, non-corrected enrollment rows; and
- the ordinary `students` rows for those placements.

For these checks, assignment, placement, and enrollment effectiveness all include
`current_date`; corrected rows never qualify. Placement must belong to the assigned
section, and enrollment must be the placement's authoritative enrollment. A future
assignment grants no contextual access before `starts_on`; an ended, reassigned,
corrected, expired, inactive-parent, or inactive-membership assignment grants none.

No assignment relationship is added to identifier, guardian, guardian-link,
address, emergency-contact, document, upload-intent, audit, outbox, role, permission,
or mutation policies. Assignment-derived access is read-only and never satisfies an
SIS or enrollment command permission check.

Use these three small, stable, non-recursive `SECURITY DEFINER` relationship
helpers, owned by `postgres` and using empty search paths:

```text
app_auth.is_current_assigned_teacher_for_section(section_id, staff_profile_id default null)
app_auth.is_current_assigned_teacher_for_enrollment(enrollment_id)
app_auth.is_current_assigned_teacher_for_student(student_id)
```

Each helper joins base tables directly and never invokes a policy-bearing helper
that queries the same protected relation. They are private implementation functions
in schema `app_auth`, but their exact signatures require caller execution from the
new SELECT policies. Migration 007 therefore applies these exact ACLs:

```sql
revoke all on function
  app_auth.is_current_assigned_teacher_for_section(uuid,uuid),
  app_auth.is_current_assigned_teacher_for_enrollment(uuid),
  app_auth.is_current_assigned_teacher_for_student(uuid)
from public, anon, authenticated, service_role;

grant execute on function
  app_auth.is_current_assigned_teacher_for_section(uuid,uuid),
  app_auth.is_current_assigned_teacher_for_enrollment(uuid),
  app_auth.is_current_assigned_teacher_for_student(uuid)
to authenticated;
```

No other private v0.6 helper receives EXECUTE for `authenticated`, `anon`,
`service_role`, or implicit `PUBLIC`. In particular, actor/permission assertions,
parent lockers, validators, audit/outbox writers, and create/end/reassign/correct
implementation functions remain inaccessible to every browser and service role;
only the typed `public` command wrappers have the separately documented grants.
The `postgres` owner necessarily retains owner execution authority.

Catalog tests inspect `pg_proc`, `pg_namespace`, `proowner`, `prosecdef`,
`proconfig`, and `aclexplode(coalesce(proacl, acldefault('f', proowner)))` for each
exact signature. They prove: owner is `postgres`; `SECURITY DEFINER` is true;
`search_path` is empty; `authenticated` alone among non-owner roles has EXECUTE on
the three relationship helpers; `PUBLIC`, `anon`, and `service_role` do not; and no
command implementation helper is executable by any of those four roles. Behavioral
tests also prove the policy calls succeed for `authenticated` without recursion or
scope expansion.

## Compatibility changes in migration 007

Migration 007 wraps the currently published signatures without changing them:

- `public.update_section(...)` rejects a date or status change that excludes any
  non-corrected assignment and rejects making a section inactive while any active
  assignment record remains;
- `public.archive_section(uuid)` rejects archival while any active assignment
  remains;
- `public.update_academic_year(uuid,text,date,date)` rejects dates that exclude any
  non-corrected assignment;
- `public.transition_academic_year_status(uuid,academic_period_status)` rejects
  close/archive while any active assignment remains;
- existing subject, staff-profile, and membership commands are not wrapped: their
  later inactivation does not rewrite assignment history, and the contextual helper
  immediately stops granting access when the staff profile or membership is no
  longer active.

Wrappers preserve all existing v0.3–v0.5 validation, authorization, audit/event,
ownership, grants, signatures, and function-body naming assumptions. Checks run in
the same transaction, so a compatibility failure rolls back the underlying change
and its audit/outbox effects. Migration 007 records every renamed implementation
function and denies direct execution.

## TypeScript and module contract

After migration implementation and local reset, regenerate
`src/platform/database/database.types.ts`; never hand-edit it or generate it from a
remote project. Add `src/modules/teaching-assignments/index.ts` exporting:

- strict camelCase Zod schemas and inferred inputs for the four commands;
- `TeachingAssignmentRole`, `TeachingAssignmentStatus`, permission, event, and RPC
  name unions;
- exact generated RPC argument/result aliases; and
- a narrow `TeachingAssignmentCommandService` interface.

Date inputs use validated ISO calendar-date strings. IDs are UUIDs; reasons are
trimmed 1–500 characters. Nullable subject fields are explicit, and correction's
replacement fields are conditionally required only when `createReplacement` is
true. The application adapter maps camelCase only at the module boundary.

## Adversarial pgTAP matrix

### Schema, constraints, indexes, and catalog

- enums, exact table columns/types/defaults/nullability, composite keys, restrictive
  foreign keys, immutability, reason/state checks, and effective-range equality;
- both lead exclusion constraints, including overlapping null-subject leads,
  non-null subject leads, boundary-day overlap, different subjects, non-leads,
  terminal rows, and future rows;
- every foreign-key/RLS traversal index;
- forced RLS, SELECT-only grants, no DELETE policy, function owners, security mode,
  empty search paths, exact signatures, exact relationship-helper ACLs, wrapper
  grants, and command-helper denial; and
- unchanged migration 001–006 seed codes and published RPC signatures.

### Authentication, RBAC, and spoof resistance

For assignment reads and every command family, cover anonymous denial, cross-tenant
denial, wrong school/campus denial, missing permission, inactive/invited/suspended/
left membership, inactive/expired role assignment, permitted organization/school/
campus scope, and inactive role/organization/school/campus denial.

Prove clients cannot supply tenant, scope, actor, command ID, row ID, audit/event
data, arbitrary JSON, or a home-placement bypass. Direct table writes, generic
private helpers, implementation wrappers, and hard deletes fail.

### Create and parent invariants

- valid homeroom and subject assignments for every role;
- active future assignment without premature contextual access;
- missing/inactive/cross-tenant/cross-school subject rejection;
- missing/inactive staff profile or membership rejection;
- staff home school/campus mismatch succeeds when actor scope is valid;
- missing/inactive section/year and dates outside section/year rejection;
- same-context overlapping lead rejection, including null subject;
- allowed overlapping co-teacher/assistant/substitute and different-subject leads;
- exact actor attribution and rollback on forced audit/outbox failure.

### End, reassignment, and correction

- inclusive valid end and invalid before-start/after-scheduled-end dates;
- terminal/no-op/repeat-operation rejection and nonblank bounded reasons;
- reassignment D ends source D-1 and starts destination D atomically;
- reassignment at source start, after scheduled end, conflicting lead, inactive
  replacement staff, or unauthorized destination rolls back both halves;
- reassignment preserves section/subject and links both rows;
- correction without replacement and with valid replacement;
- replacement may change section/subject but requires authority over both scopes;
- corrected original is immutable and replacement points back exactly once;
- correction rejects a reassigned source, a reassignment destination, and every
  middle row in a longer reassignment chain with zero side effects;
- correcting before reassignment succeeds, while paired-history correction is not
  exposed by any public or private callable contract;
- missing target uses deliberate `P0002`; discovery drift uses `40001`; and
- concurrent competing lead creation/reassignment leaves at most one valid lead.

### Contextual RLS

- assignee can read the assignment, section/year, optional subject, current
  placement/enrollment, and ordinary student row only during the inclusive range;
- future, expired, ended, reassigned, and corrected assignments grant no access;
- inactive staff profile or membership grants no access;
- future, ended, corrected, wrong-section, and date-gap placement/enrollment rows
  grant no access;
- assignment does not reveal other sections, subjects, students, historical roster,
  identifiers, guardians/links, addresses, emergency contacts, documents/intents,
  audit, or outbox;
- teacher cannot call SIS/enrollment/assignment management RPCs without explicit
  scoped permissions; and
- helper execution neither recurses nor crosses tenant/school/campus boundaries.

### Compatibility and regression

- active assignments block section archive/inactivation, incompatible section/year
  dates, and year close/archive;
- terminal assignment history remains valid and does not block compatible parent
  lifecycle changes, while parent dates may never exclude non-corrected history;
- existing section capacity/placement and academic-period checks still execute;
- existing SIS/enrollment student and guardian contextual reads remain unchanged
  except for the deliberate current-teacher student read path;
- all prior database suites remain green; and
- command side effects retain exact audit/outbox counts and shared command IDs.

## Definition of done after plan approval

- additive migration 007 implements only this reviewed contract;
- focused v0.6 pgTAP passes during implementation;
- module, security, system-overview, and affected academics/enrollment/SIS docs are
  updated;
- generated public database types and TypeScript contracts agree;
- final gate runs one local database reset, the full database suite, strict
  typecheck, production build, and whitespace checks; and
- nothing is deployed, staged, committed, pushed, merged, or changed in production.

## Binding product decisions

1. Subject is nullable for homeroom/general context; a present subject is active and
   belongs to the section's organization and school.
2. Multiple overlapping teachers are allowed, but only one overlapping active lead
   exists per section and subject context; null is a real homeroom context.
3. Dates are inclusive and bounded by section and academic year.
4. Future assignments exist, but contextual access begins only on their effective
   date.
5. Teacher roster access includes only currently effective, non-corrected enrollment
   and placement records and ends with the assignment.
6. Assignment-derived access is read-only and excludes all listed sensitive and
   operational domains.
7. Creation authority follows destination-section scope; assignee eligibility uses
   active staff profile and membership, not home placement.
8. Active assignments block incompatible section and year lifecycle changes.
9. Reassignment is an atomic end-and-create operation; immutable facts are not
   rewritten.
10. Contextual RLS uses non-recursive private security-definer relationship helpers.
11. Substitute assignments are manually recorded; substitute scheduling is outside
    v0.6.
