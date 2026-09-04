# Attendance Foundation v0.7

## Status and boundary

This is the implementation contract for independent review. It does not authorize
migration 008. Migration 008 must be additive and must leave migrations 001–007
unchanged.

The attendance module owns one daily attendance session per section and date, the
roster snapshot used by that session, student marks, absence-reason configuration,
and attendance correction history. It does not own academic structure, enrollment,
placement, teaching assignment, SIS, timetables, periods, lessons, rooms, meeting
patterns, grading, behavior, health, transport, payroll, notifications, analytics,
UI, or import. There is no guardian or student attendance access in v0.7.

All dates below are inclusive. A “rostered student” is a non-corrected enrollment
and non-corrected section placement whose stored ranges contain `session_date`.
Future sessions are prohibited. Relationship-authorized teachers may open or
submit only when `session_date = current_date` and their assignment is currently
effective. Scoped administrators with `attendance.manage` may open or submit past
or current dates inside the section and academic year, but never a future date.

## Relational schema

Migration `202608190008_attendance_foundation_v0_7.sql` adds these enums:

```sql
create type public.attendance_session_status as enum
  ('open', 'submitted', 'finalized', 'corrected');

create type public.attendance_mark_status as enum
  ('present', 'absent', 'late', 'excused');
```

### `attendance_absence_reasons`

The catalog is school-scoped because administrative authority and academic
meaning follow the section's school; a campus-scoped role may manage only rows for
its own campus through `campus_id`, while a null campus means school-wide.

| Column | Type and rule |
|---|---|
| `id` | UUID primary key, generated |
| `organization_id` | UUID, not null |
| `school_id` | UUID, not null |
| `campus_id` | UUID, nullable |
| `code` | text, trimmed length 1–32 |
| `name` | text, trimmed length 1–100 |
| `description` | text, nullable, trimmed length 1–500 |
| `status` | existing `record_status`, default `active`; create permits active/inactive, archive is terminal |
| `created_at`, `updated_at` | timestamptz, not null, server managed |
| `created_by`, `updated_by` | UUID references `auth.users`, not null |

Composite restrictive foreign keys prove organization/school/campus consistency.
Add `unique (organization_id,id)`, normalized unique indexes on
`(school_id, coalesce(campus_id, '00000000-0000-0000-0000-000000000000'::uuid), lower(btrim(code)))` and the equivalent
name key, plus indexes for every parent, RLS, and scope traversal. A reason may not
move scope. Code and name may be edited while active/inactive. Archive is by typed
command; there is no delete or reactivation command. Existing marks may retain any
inactive or archived reason.

### `attendance_sessions`

| Column | Type and rule |
|---|---|
| `id` | UUID primary key, generated |
| `organization_id`, `school_id`, `campus_id`, `academic_year_id`, `section_id` | UUIDs, not null, one composite FK to `sections` |
| `session_date` | date, not null |
| `status` | `attendance_session_status`, default `open` |
| `submitted_at`, `finalized_at` | timestamptz, nullable |
| `submitted_by`, `finalized_by` | UUID references `auth.users`, nullable |
| `supersedes_session_id` | UUID, nullable, same-organization restrictive self-FK |
| `correction_reason` | text, nullable, trimmed length 1–500 |
| `created_at`, `updated_at` | timestamptz, not null |
| `created_by`, `updated_by` | UUID references `auth.users`, not null |

Add `unique (organization_id,id)` and a partial unique index on
`(section_id,session_date) where status <> 'corrected'`. A replacement points to
exactly one corrected session; one partial unique index on
`supersedes_session_id where supersedes_session_id is not null` prevents branching.
State checks require:

- open: no submission/finalization/correction fields;
- submitted: submission fields only;
- finalized: submission and finalization fields, no correction fields; and
- corrected: previously finalized timestamps remain, and a correction reason is
  present.

The immutable trigger rejects changes to scope, section/date, creator facts, and
`supersedes_session_id`. Only reviewed lifecycle columns may change. A corrected
row is terminal. Date validity is enforced inside every command against the locked
database `current_date`; it is not implemented as a time-dependent table check.

### `attendance_session_students`

This is the immutable roster snapshot of what the system recorded when the session
was opened. It is observational provenance, not a continuing assertion that the
underlying enrollment or placement fact was correct. Later append-only enrollment
or placement corrections neither rewrite nor invalidate attendance history.

| Column | Type and rule |
|---|---|
| `id` | UUID primary key, generated |
| session scope columns | organization, school, campus, academic year, section and session IDs, all not null |
| student provenance | `student_id`, `student_enrollment_id`, `student_section_placement_id`, all not null |
| `created_at`, `created_by` | server managed, not null |

Use composite restrictive FKs to the session, enrollment, placement, and student
keys. Add `unique(session_id,student_id)`, `unique(session_id,student_section_placement_id)`,
`unique(organization_id,id)`, and indexes for all FK and RLS traversals. Rows are
insert-only inside `open_attendance_session` and never updated or deleted. Existing
provenance IDs remain attached when a referenced enrollment or placement later
becomes `corrected`; restrictive foreign keys continue to prohibit destructive
deletion.

### `attendance_marks`

| Column | Type and rule |
|---|---|
| `id` | UUID primary key, generated |
| session scope columns | organization, school, campus, academic year, section, session and session-student IDs, all not null |
| `student_id` | UUID, not null and proven through the session-student FK |
| `mark` | `attendance_mark_status`, not null |
| `arrival_time` | `time without time zone`, nullable |
| `absence_reason_id` | UUID, nullable |
| `note` | text, nullable, trimmed length 1–500 |
| `created_at`, `updated_at` | timestamptz, not null |
| `created_by`, `updated_by` | UUID references `auth.users`, not null |

Add `unique(session_id,student_id)` and `unique(organization_id,id)`. Composite FKs
prove session scope, snapshot membership, and reason organization/school. A trigger
additionally proves that a campus-specific reason matches the session campus.
`late` alone permits an arrival time; every other mark requires it to be null.
`absent` and `excused` require an active applicable absence reason at submission;
only those two statuses permit the optional note. Present and late marks require
both reason and note to be null. Marks may be inserted or replaced only while the
session is open, through the submit command; after submission they are immutable.

All four tables are owned by `postgres`, enable and force RLS, grant authenticated
SELECT only, revoke direct INSERT/UPDATE/DELETE/TRUNCATE, and expose no DELETE
policy. Updated-at triggers are added only to mutable lifecycle/configuration rows.

## Lifecycle and immutable history

```text
open --submit--> submitted --finalize--> finalized --correct--> corrected
                                                        |
                                                        +--> finalized replacement
```

Opening atomically creates an open session and its complete roster snapshot.
Submitting atomically replaces the open session's entire mark set and changes the
session to submitted; every roster row must have exactly one mark. Finalizing only
accepts a submitted, complete session and freezes it.

Correction accepts a finalized session and a complete replacement mark set. It
marks the original corrected without rewriting its roster or marks, then appends a
new finalized session for the same section/date, linked by `supersedes_session_id`.
The replacement copies the original roster snapshot and records new marks. A
correction of a correction targets the currently non-corrected replacement and
forms a linear chain. Open and submitted sessions cannot be corrected. There is no
reopen, unsubmit, unfinalize, in-place finalized edit, hard delete, partial
correction, or generic mutation RPC.

Correction is whole-session mark correction only. It always uses the original
roster snapshot. Adding, removing, or replacing historical roster members is not
supported in v0.7, and this limitation must not block a legitimate append-only
enrollment or placement correction.

Open sessions are operational drafts: repeated submit is not exposed. If submit
fails, the session remains open with no marks because the mark write and transition
are one transaction. This intentionally avoids persisting incomplete drafts.

## Session, roster, and mark invariants

- Exactly one non-corrected daily session exists per section/date.
- The organization, school, campus, and academic year derive from the locked
  section; callers cannot provide them.
- Session date lies within both section and academic-year dates and must satisfy
  `session_date <= current_date`. Section and year must be active when opening. A
  historical correction revalidates stored scope and date but does not require
  parents still active.
- A relationship-authorized lead, co-teacher, or substitute may open or submit only
  for `session_date = current_date` while the assignment is currently effective.
  An actor with scoped `attendance.manage` may open or submit for any past or
  current in-range date without a teaching relationship. No actor may open or
  submit a future session.
- Opening discovers, locks, and re-reads every qualifying placement and enrollment.
  Discovery drift raises `40001`; the caller retries the whole command.
- A roster member's enrollment must match organization, school, academic year, and
  student. Its placement must match that enrollment, student, section, and session
  date. Corrected rows never qualify.
- A student with no qualifying placement is absent from the snapshot. Multiple
  qualifying placements for the same student are invariant corruption and abort;
  they are never silently deduplicated.
- Submission input is a set: no duplicate student IDs, no omissions, and no extras.
  Server comparison is against the locked snapshot, not browser roster data.
- One mark exists per snapshot row after submission and throughout finalized
  history. Arrival time is a local wall-clock time; v0.7 stores no inferred zone or
  date-time because the section already fixes the calendar date.
- Reason applicability and active status are checked at submission/correction.
  Later reason changes never alter historical marks.
- Enrollment and placement validity is checked only while constructing the opening
  snapshot. Later correction of either referenced row is valid and does not cause
  attendance revalidation, rewriting, correction, or deletion.
- Every UUID, timestamp, actor, scope, status, linkage, and audit/outbox fact is
  server-derived unless explicitly present in a public signature below.

## Absence-reason management

`attendance.manage` administers the catalog in the reason's stored scope. A
school-wide reason (`campus_id is null`) requires organization- or school-scoped
authority; campus-scoped actors cannot create or mutate it. A campus reason may be
managed by an actor scoped to that campus or above. Creation requires active
organization/school and, when present, campus. Archival is allowed while referenced
and does not cascade. Archived is terminal. Commands preserve normalized uniqueness
and append exactly one audit/outbox pair.

## Exact public RPC signatures

All wrappers are `SECURITY DEFINER`, owned by `postgres`, have empty search paths,
schema-qualified bodies, and exact EXECUTE grants to `authenticated` and
`service_role`; PUBLIC and anon are denied. All implementation, validation,
locking, and write helpers deny PUBLIC, anon, authenticated, and service_role.

```sql
public.create_attendance_absence_reason(
  school_id uuid, campus_id uuid, code text, name text, description text
) returns uuid

public.update_attendance_absence_reason(
  id uuid, code text, name text, description text,
  status public.record_status, set_description boolean default false
) returns uuid

public.archive_attendance_absence_reason(id uuid) returns uuid

public.open_attendance_session(
  section_id uuid, session_date date
) returns uuid

create type public.attendance_mark_input as (
  student_id uuid,
  mark public.attendance_mark_status,
  arrival_time time without time zone,
  absence_reason_id uuid,
  note text
);

public.submit_attendance_session(
  id uuid, marks public.attendance_mark_input[]
) returns uuid

public.finalize_attendance_session(id uuid) returns uuid

public.correct_attendance_session(
  id uuid,
  marks public.attendance_mark_input[],
  correction_reason text
) returns table(
  corrected_session_id uuid,
  replacement_session_id uuid
)
```

Arrays are bounded to the locked roster count and 10,000 entries before unnesting.
Empty arrays are valid only for an empty roster. Null arrays/elements and duplicate
student IDs fail with `22023`. RPCs accept no organization, school/campus/year,
actor, row ID, status, timestamp, roster provenance, command ID, audit/event data,
arbitrary JSON, or teaching-assignment identity. `open_attendance_session` rejects
`session_date > current_date`. `submit_attendance_session` rechecks the stored date:
scoped managers may submit past/current sessions, while relationship-only teachers
may submit only a session dated `current_date` under a currently effective
assignment.

## Permissions and role matrix

Add versioned permission catalog entries `attendance.view`, `attendance.manage`,
and `attendance.correct` in module `attendance`. Migration 008 does not seed grants
to organization roles; deployments assign permissions deliberately.

| Actor relationship | Read sessions, snapshots, marks/reasons | Open | Submit | Finalize | Correct | Manage reasons |
|---|---:|---:|---:|---:|---:|---:|
| Scoped admin with `attendance.view` | yes | no | no | no | no | no |
| Scoped admin with `attendance.manage` | yes | past/current | past/current | yes | no | yes |
| Scoped admin with manage + correct | yes | past/current | past/current | yes | yes | yes |
| Currently effective lead/co-teacher | today's assigned section only | today only | today only | no | no | no |
| Currently effective substitute | today's assigned section only | today only | today only | no | no | no |
| Currently effective assistant | today's assigned section read only | no | no | no | no | no |
| Any assignee with explicit scoped admin permission | permission capability plus contextual read | per permission | per permission | per permission | per permission | per permission |
| Student, guardian, unrelated staff, anonymous | no | no | no | no | no | no |

`attendance.manage` deliberately authorizes finalization, but teacher relationship
alone does not. Correction always requires both `attendance.manage` and
`attendance.correct`; no teaching relationship satisfies either check.

## Authorization and RLS relationships

Administrative checks always call `has_permission(organization_id, code,
school_id, campus_id)` using the section/reason's authoritative scope. Reads allow
view, manage, or correct (correct never stands alone for mutation). Reason reads
are limited to school-wide reasons or the actor's permitted campus; contextual
teachers may read active reasons applicable to their assigned session's campus.

Add two non-recursive, stable, security-definer helpers with authenticated-only
EXECUTE grants:

```text
app_auth.has_attendance_assignment_on(section_id, session_date,
  allowed_roles public.teaching_assignment_role[])
app_auth.can_read_attendance_session(session_id)
```

The first directly joins teaching assignments, staff profiles, and organization
memberships. It requires `session_date = current_date`, a non-corrected active
assignment whose inclusive `effective_range` contains `current_date`, an active
staff profile and membership, and role membership in the supplied allow-list.
Command code calls it with `{lead,co_teacher,substitute}` for open/submit; assistant
is excluded. The read helper allows all four roles for today's stored section/date,
or administrative attendance permissions for authorized historical reads. When an
assignment ceases to be currently effective, all relationship-derived attendance
access ends; explicit scoped attendance permissions remain available.

Policies on sessions, snapshot rows, and marks reduce to the session helper without
recursive references. The reason policy uses direct RBAC or existence of an
already-readable session to which the reason applies. Do not modify SIS,
enrollment, placement, or teaching-assignment policies to grant attendance access;
attendance rows carry the safe IDs necessary for their own reads. No path reveals
student profiles or sensitive SIS data beyond access already granted by v0.6.

## Deterministic locking and concurrency

Global order for attendance commands is:

```text
organization
-> school
-> campus
-> academic year
-> section
-> sorted organization memberships
-> sorted staff profiles
-> sorted teaching assignments
-> sorted students
-> sorted student enrollments
-> sorted student section placements
-> session for (section,date), then sorted session-chain rows
-> sorted session-student rows
-> sorted absence reasons
-> sorted marks
```

Reason commands use the applicable prefix and then the reason row. Opening first
discovers candidate roster/assignment IDs, acquires the ordered locks, and re-runs
discovery. On the relationship path, open and submit lock and revalidate the
currently effective assignment and require the authoritative session date to equal
the locked transaction's `current_date`. On the administrative path, they lock and
revalidate scoped `attendance.manage` authority and require the date to be no later
than `current_date`; no teaching-assignment lock is required. If opening roster
membership, relationship eligibility, scope, or session-chain head differs from
discovery, raise SQLSTATE `40001` with no effects. Callers retry the complete
command with bounded exponential backoff and jitter.

Enrollment and placement rows are locked and re-read only when opening a session
and materializing its snapshot. Submit, finalize, and attendance correction lock
the immutable snapshot and marks, not the current enrollment/placement state.
Enrollment or placement correction does not lock attendance rows, and attendance
commands do not make those parent corrections wait on or validate against a
historical roster snapshot.

The partial session unique index arbitrates concurrent opens; after locking the
section, the loser receives the existing-session validation error. Concurrent
submit/finalize/correct operations serialize on the session/chain. A stale
lifecycle or duplicate-open request is `22023`, not silently idempotent. FK,
normalized-unique, and check/exclusion conflicts are ordinary constraint errors,
not retryable discovery drift. Every failure rolls back domain, audit, and outbox
writes.

## Audit and outbox inventory

One server-generated command ID correlates every effect. Protected audit snapshots
may contain attendance status, arrival time, reason ID, and note; public outbox
payloads omit notes and student/profile names. Payloads contain only command/actor,
scope and aggregate IDs, session date/status, counts, mark status, arrival time,
reason ID, linkage, and correction reason where relevant.

| Command | Audit rows | Outbox events |
|---|---:|---|
| reason create/update/archive | 1 | 1: `attendance_reason.created`, `.updated`, or `.archived` |
| open session with N roster rows | 1 + N | 1 `attendance.session_opened`; no per-student public event |
| submit N marks | 1 + N | 1 `attendance.session_submitted` plus N `attendance.student_marked` |
| finalize | 1 | 1 `attendance.session_finalized` |
| correct finalized session with N roster rows/marks | 2 + 2N | 1 `attendance.session_corrected`, 1 `attendance.session_finalized`, and N `attendance.student_mark_corrected` |

Roster snapshot audit rows use entity type `attendance_session_student`; marks use
`attendance_mark`; sessions use `attendance_session`; reasons use
`attendance_absence_reason`. Correction audit pairs include the original session
transition, replacement session, copied snapshot rows, and replacement marks.
Every event aggregate ID identifies the session, mark, or reason described, and
the existing command/event/aggregate uniqueness contract supports shared command
IDs. Exactly these counts are asserted, including zero-roster sessions.

## Compatibility changes to existing domains

Migration 008 wraps published functions without changing their signatures, grants,
ownership, existing validation, or existing audit/outbox behavior:

- `update_section` and `archive_section` reject inactivation, archival, or date
  changes that conflict with any non-corrected attendance session date;
- `update_academic_year` rejects dates excluding non-corrected attendance history;
- `transition_academic_year_status` may close/archive with finalized attendance,
  but rejects while an open or submitted attendance session exists;
- enrollment termination, placement end/transfer/correction, and enrollment
  correction remain unchanged by migration 008. They may proceed even when the
  corrected fact differs from an attendance roster snapshot. The snapshot records
  what the system selected at open time; it is not rewritten, invalidated, or used
  as a blocker. Restrictive FKs retain the original provenance IDs, corrected rows
  remain stored, and destructive deletion remains prohibited;
- teaching-assignment end, reassignment, and correction do not rewrite attendance
  history. They may end relationship-derived access immediately, while stored
  submitter/finalizer attribution remains valid immutable history.

Compatibility checks execute in the same transaction so failure rolls back the
underlying domain change and its audit/outbox. Where an existing function cannot be
safely wrapped without relying on its function-name-qualified body, use the v0.5/
v0.6 established rename-and-wrapper pattern and catalog-test every hidden helper's
ACL. Migration 008 must not wrap enrollment or placement commands merely to compare
their corrections with attendance snapshots. Attendance does not add columns to
existing tables.

## TypeScript and Zod public contract

After implementation approval and a fresh local reset, regenerate public database
types locally; never hand-edit them or generate against the linked project. Add
`src/modules/attendance/index.ts` with:

- strict camelCase Zod schemas for the seven RPCs;
- `attendanceMarkSchema` as a discriminated union enforcing mark-specific nulls;
- ISO date validation, UUID validation, `HH:mm` or `HH:mm:ss` local-time validation,
  trimmed 1–500 notes/reasons/descriptions, trimmed bounded codes/names, and a
  10,000-item maximum mark array;
- `openAttendanceSessionSchema` rejects a client-known future ISO date, while the
  database remains authoritative for `current_date`; submit has no caller-supplied
  date and the RPC applies the manager-versus-relationship date rules to the stored
  session;
- absent/excused variants require `absenceReasonId` and permit an optional bounded
  note; present/late require both fields to be null; only late permits nullable
  arrival time and every other variant requires it null;
- inferred command inputs and exact generated RPC Args/Returns aliases;
- role, session-status, mark-status, permission, event, and RPC-name literal unions;
- `AttendanceCommandErrorCode = '22023' | '23503' | '23505' | '40001' | '42501' | 'P0002'`;
- `isRetryableAttendanceCommandError`, true only for `40001`; and
- a narrow `AttendanceCommandService` interface matching all commands.

The adapter performs camelCase-to-SQL mapping and converts each mark into the
generated composite input. No React component or route handler owns attendance
business rules.

## Adversarial pgTAP matrix

### Catalog, schema, and immutability

- exact enums, composite input type, columns, defaults, checks, composite FKs,
  restrictive delete actions, normalized uniqueness, partial session/chain keys,
  indexes, triggers, comments, and immutable-field enforcement;
- forced RLS, authenticated SELECT-only grants, no write/delete policies, exact
  wrapper signatures, owners, security-definer flags, empty search paths, wrapper
  ACLs, exact contextual-helper ACLs, and denial of every private command helper;
- direct insert/update/delete/truncate and spoofed tenant/actor/status/timestamp/
  linkage/roster IDs fail; migrations 001–007 and their published signatures remain
  byte-for-byte unchanged.

### Authentication, RBAC, and contextual roles

- anonymous, cross-tenant, wrong school/campus, missing-permission, inactive/
  invited/suspended/left membership, inactive/expired role assignment, inactive
  role, and parent-scope denial for every read and command family;
- organization-, school-, and campus-scoped view/manage/correct successes and
  school-wide reason denial to campus-only managers;
- currently effective lead/co-teacher/substitute can open and submit only today's
  assigned section; yesterday/tomorrow, future, ended, reassigned, corrected,
  wrong-section, inactive-profile, and inactive-membership cases cannot;
- scoped managers can open and submit valid past or current sessions without a
  teaching assignment, but every actor is denied future sessions;
- assistant has contextual read only; any teaching role with explicit scoped admin
  permissions gets only those permission capabilities;
- teacher relationships cannot finalize/correct/manage reasons or invoke SIS,
  enrollment, placement, or teaching-assignment mutation;
- students and guardians have no attendance or reason reads.

### Open, roster, and parent invariants

- valid empty and populated roster snapshots; exact provenance and attribution;
- section/year/date, tenant/school/campus/year/grade/enrollment/placement/date
  mismatch, corrected rows, duplicate active placements, and inactive open parents;
- boundary dates for section, year, enrollment, and placement;
- server-side future-date rejection for managers and teachers, teacher rejection
  for past dates, and manager success for both current and past dates;
- concurrent roster/assignment discovery drift returns `40001`; concurrent open
  creates only one non-corrected session; audit/outbox failure rolls back all rows.

### Marks, submission, and finalization

- every mark value; late with/without arrival and non-late arrival rejection;
- absent/excused active applicable reason requirement; wrong tenant/school/campus,
  inactive/archived/missing reason; note status and 1/500/501 boundaries;
- null/empty/oversized arrays, null elements, duplicate/missing/extra students;
- submit only from open and finalize only from complete submitted; repeat/stale
  commands fail with zero side effects;
- post-submit direct or command mutation is impossible; reason archival preserves
  history; exact timestamps/actors/counts and transaction rollback.

### Correction and concurrency

- valid whole-session correction, unchanged-value correction, linear second
  correction, chain linkage and one live head;
- open/submitted/already-corrected target, blank/oversized reason, incomplete or
  invalid replacement marks, and non-correct authority fail atomically;
- correction uses the original immutable roster even when current enrollment or
  placement differs; concurrent correction leaves one head; stale chain discovery
  is `40001`;
- attempted attendance correction cannot add/remove roster members, while later
  append-only enrollment and placement corrections succeed without touching or
  invalidating session, snapshot, mark, audit, or outbox history;
- original finalized session, roster, and marks remain byte-identical except for
  the allowed session status/correction metadata.

### RLS, events, compatibility, and regression

- admins and date-effective assignees see only authorized sessions/snapshots/marks/
  applicable reasons; assistant sees but cannot mutate; unrelated and cross-scope
  actors see zero rows;
- contextual teacher reads require a currently effective assignment and a session
  dated today; scoped administrators retain authorized historical reads;
  no attendance relationship broadens student/SIS/sensitive/audit/outbox access;
- exact audit/outbox event names, aggregate IDs, counts, shared command IDs,
  payload allow-list, and absence of note or personal data from public events;
- section/year/assignment compatibility checks and rollback, plus proof that no
  attendance rule blocks enrollment or placement correction and provenance FKs
  remain valid after referenced rows become corrected;
  all prior domain behavior remains intact outside the documented restrictions;
- focused attendance tests pass, followed at final implementation gate by all prior
  database suites.

## Documentation deliverables

Implementation updates `docs/architecture/security.md`,
`docs/architecture/system-overview.md`, affected academics/enrollments/teaching-
assignments module docs, and adds `docs/modules/attendance.md`. Documentation must
describe public interfaces, permissions, contextual relationships, event contracts,
locking, immutable correction, and parent compatibility.

## Definition of done after independent plan approval

- additive migration 008 implements only this reviewed contract and 001–007 remain
  unchanged;
- adversarial `supabase/tests/attendance_foundation_v0_7_test.sql` passes, including
  exact catalog, security, concurrency, rollback, compatibility, and cardinality
  assertions;
- strict Zod/TypeScript attendance contracts agree with locally regenerated public
  database types;
- module and architecture documentation is current;
- implementation verification runs a fresh local reset, focused and full database
  suites, strict TypeScript typecheck, production build, and whitespace checks;
- no deployment, production mutation, stage, commit, push, merge, UI, import,
  analytics, notification, or out-of-scope domain work occurs.

## Genuinely unresolved product decisions

None identified. The plan treats “currently effective” consistently with v0.6:
relationship-derived access ends with the assignment, while scoped administrators
retain the permissions needed to review and correct preserved history.
