# Assessment & Gradebook Foundation v0.8

## Status and boundary

This document is the proposed implementation contract for independent review. It
does not authorize migration 009. The six previously recommended product decisions
are now approved as binding below. Implementation may begin only after another
independent review of this revision.
Migration 009 must be additive and migrations 001–008 must remain unchanged.

The assessments module owns section assessments, their immutable eligible-roster
snapshots, per-student results, publication, finalization, and append-and-supersede
correction history. It consumes academics, enrollment, placement, teaching-
assignment, SIS relationship, RBAC, audit, and outbox contracts through their
published database interfaces and stable relational keys.

The following remain outside v0.8: GPA, report cards, transcripts, credits,
promotion, graduation, class rank, rubrics, standards, outcomes, moderation,
curves, analytics, attendance-derived grades, automatic aggregation across
assessments, timetables, UI, notifications, bulk import, deployment, and production
changes.

All dates and effective ranges below are inclusive. `current_date` is the database
date. A live assessment is any assessment whose lifecycle status is neither
`corrected` nor `cancelled`. A roster snapshot is an observation made by the create command using
the assessment date; later enrollment or placement correction does not rewrite or
invalidate it.

## Existing contracts migration 009 must preserve

- Tenant RBAC is `organization_memberships -> role_assignments -> roles ->
  role_permissions -> permissions`. `app_auth.has_permission` requires active
  membership, role, and role assignment, observes role-assignment time bounds, and
  applies organization/school/campus scope.
- Sections carry organization, school, campus, academic year, optional term, grade,
  inclusive dates, capacity, and status. Terms belong to an academic year; their
  school is derived through that year.
- Non-corrected enrollment `enrollment_range` and placement effective dates define
  roster eligibility. Placement proves organization, school, campus, year, section,
  student, and enrollment provenance through the composite key added by v0.7.
- Teaching assignments carry section and optional subject context, inclusive
  `effective_range`, role (`lead`, `co_teacher`, `assistant`, `substitute`), and
  immutable history. Active staff profile plus active organization membership is
  required for relationship access.
- `app_auth.is_student_self` resolves `students.user_id = auth.uid()` and excludes
  archived students. `app_auth.is_linked_guardian` requires an active guardian,
  active student-guardian link, portal access, and matching guardian user.
- Domain tables added since v0.3 force RLS, expose SELECT only to authenticated
  users, and route writes through typed, empty-search-path security-definer RPCs.
- Parent-first locks and sorted peer locks are mandatory. Discovery drift uses
  SQLSTATE `40001`; validation, authorization, uniqueness, exclusion, and FK
  failures are not retryable.
- Each command generates one server-side command ID. Every changed domain row has
  an audit row. Outbox rows are allow-listed, minimal, and correlated by that
  command ID. Multi-row commands intentionally share a command ID.

## Relational schema

Migration `202608190009_assessment_gradebook_foundation_v0_8.sql` adds:

```sql
create type public.assessment_type as enum
  ('assignment', 'quiz', 'exam', 'project', 'participation');

create type public.assessment_lifecycle_status as enum
  ('draft', 'finalized', 'corrected', 'cancelled');

create type public.assessment_publication_state as enum
  ('unpublished', 'published');

create type public.assessment_result_input as (
  student_id uuid,
  score numeric,
  teacher_comment text
);
```

### `public.assessments`

| Column | Type and rule |
|---|---|
| `id` | UUID PK, generated |
| `organization_id` | UUID, not null |
| `school_id` | UUID, not null |
| `campus_id` | UUID, not null |
| `academic_year_id` | UUID, not null |
| `academic_term_id` | UUID, not null |
| `section_id` | UUID, not null |
| `subject_id` | UUID, nullable; null means homeroom/general context |
| `assessment_type` | `public.assessment_type`, not null |
| `title` | text, trimmed length 1–160 |
| `description` | text, nullable, trimmed length 1–2,000 |
| `assessment_date` | date, not null |
| `due_date` | date, nullable |
| `maximum_score` | `numeric(12,4)`, greater than zero and at most 1,000,000 |
| `weight` | `numeric(7,4)`, nullable, greater than zero and at most 100 |
| `lifecycle_status` | status enum, default `draft` |
| `publication_state` | publication enum, default `unpublished` |
| `published_at/by` | nullable timestamp/user FK |
| `finalized_at/by` | nullable timestamp/user FK |
| `supersedes_assessment_id` | nullable same-tenant restrictive self-FK |
| `correction_reason` | nullable trimmed text length 1–500 |
| `cancellation_reason` | nullable trimmed text length 1–500 |
| `cancelled_at/by` | nullable timestamp/user FK |
| `created_at`, `updated_at` | timestamps, not null, standard defaults |
| `created_by`, `updated_by` | user FKs, not null, restrictive delete |

Composite FKs prove:

- `(organization_id, school_id, campus_id, academic_year_id, section_id)` references
  the v0.6 section scope key;
- `(organization_id, academic_year_id, academic_term_id)` references
  `academic_terms`;
- `(organization_id, school_id, subject_id)` references `subjects` when present;
  and
- `(organization_id, supersedes_assessment_id)` references `assessments`.

Required unique keys and indexes:

- `unique (organization_id, id)`;
- `unique (organization_id, school_id, campus_id, academic_year_id,
  academic_term_id, section_id, id)` for child provenance;
- partial unique `(supersedes_assessment_id)` where non-null, allowing exactly one
  successor per version;
- partial unique `(section_id, lower(btrim(title)), assessment_date)` where
  `lifecycle_status not in ('corrected','cancelled')`, preventing an accidental
  duplicate live assessment without imposing an assessment-number feature;
- scope/read indexes on `(organization_id, school_id, campus_id,
  academic_year_id, academic_term_id, section_id, lifecycle_status,
  publication_state)` and `(organization_id, school_id, subject_id,
  lifecycle_status)` where subject is non-null;
- indexes for `created_by`, `updated_by`, `published_by`, `finalized_by`,
  `cancelled_by`, and `supersedes_assessment_id`.

The state check is exact:

- draft + unpublished: publication/finalization/cancellation actors and timestamps
  are null;
- draft + published: `published_at/by` are non-null and finalization fields and
  correction/cancellation fields are null;
- finalized + either publication state: `finalized_at/by` are non-null; publication
  fields agree with its publication state; correction/cancellation fields are null;
- corrected: finalization fields remain non-null, correction reason is non-null,
  cancellation fields are null, and publication fields retain their prior values;
- cancelled: publication and finalization fields are null, cancellation reason and
  `cancelled_at/by` are non-null, and publication state is `unpublished`;
- `supersedes_assessment_id <> id`; due date, when present, is not earlier than the
  assessment date.

An immutability trigger rejects changes to tenant/scope, section, term, subject,
assessment date, maximum score, weight, supersedes link, creation attribution, or
creation timestamp after insertion. The command layer may edit the remaining draft
metadata and result rows. Once finalized, academic content is frozen; only
publication of a complete unpublished final and the one-way transition to corrected
remain possible. An unpublished draft may transition one way to cancelled.
Corrected and cancelled are terminal.

### `public.assessment_students`

This is the immutable roster snapshot.

| Column | Type and rule |
|---|---|
| `id` | UUID PK, generated |
| scope columns | organization, school, campus, year, term, section; all not null |
| `assessment_id` | UUID, not null |
| `student_id` | UUID, not null |
| `student_enrollment_id` | UUID, not null |
| `student_section_placement_id` | UUID, not null |
| `created_at` | timestamp, not null |
| `created_by` | user FK, not null, restrictive delete |

Composite restrictive FKs prove the row belongs to its assessment, student,
enrollment, and placement using the existing assessment, student, enrollment, and
v0.7 placement provenance keys. Add `unique (organization_id, id)`, `unique
(assessment_id, student_id)`, `unique (assessment_id,
student_section_placement_id)`, and a composite unique key ending in
`(assessment_id, student_id, id)` for result provenance. Index assessment/student,
student/assessment, enrollment, placement, and `created_by` paths used by RLS and
compatibility checks. No update timestamp exists because snapshot rows never
change.

### `public.assessment_results`

One result row is created for every snapshot row in the same create transaction.

| Column | Type and rule |
|---|---|
| `id` | UUID PK, generated |
| scope columns | organization, school, campus, year, term, section; all not null |
| `assessment_id` | UUID, not null |
| `assessment_student_id` | UUID, not null |
| `student_id` | UUID, not null |
| `score` | `numeric(12,4)`, nullable while draft; `0 <= score <= maximum_score` is command/trigger enforced |
| `teacher_comment` | nullable trimmed text length 1–1,000 |
| `created_at`, `updated_at` | timestamps, not null |
| `created_by`, `updated_by` | user FKs, not null, restrictive delete |

Composite restrictive FKs prove assessment and snapshot/student scope. Add `unique
(organization_id, id)`, `unique (assessment_id, student_id)`, and `unique
(assessment_student_id)`, plus assessment/student, student/publication-read,
snapshot, creator, and updater indexes. A narrow trigger validates score against the
locked parent maximum as defense in depth; command code remains the owner of the
business rule. Results cannot be inserted or deleted after the create/correction
transaction, cannot be edited after finalization, and cannot change identity or
scope fields.

All three tables use `ON DELETE RESTRICT`, enable and force RLS, revoke all table
privileges from `PUBLIC`, `anon`, and `authenticated`, and grant authenticated users
SELECT only. There are no INSERT, UPDATE, DELETE, or TRUNCATE policies.

## Creation, roster, and result invariants

The create command requires active organization, school, campus, academic year,
term, section, and optional subject. The term must belong to the section's academic
year. If the section has an `academic_term_id`, it must equal the requested term; a
year-long section with null term may use any active term in its year.

Assessment and due dates must lie inside the intersection of section, term, and
academic-year dates. `due_date` may be null and otherwise must be on or after
`assessment_date`. Future assessment and due dates are allowed. Maximum score and
weight obey the schema bounds.

The eligible roster is selected with:

```text
placement.section_id = assessment.section_id
and placement.status <> 'corrected'
and enrollment.status <> 'corrected'
and assessment_date between placement.starts_on
                        and coalesce(placement.ends_on, assessment_date)
and assessment_date <@ enrollment.enrollment_range
and placement.student_id = enrollment.student_id
```

Organization, school, campus, year, section, enrollment, and student consistency is
also proven by composite FKs. Candidate students, enrollments, and placements are
locked in student-ID then placement-ID order before the snapshot is written. More
than one eligible placement for a student is a domain error. Empty rosters are
valid. Creation writes exactly one snapshot and one initially unscored result per
eligible student. The roster is immutable even while the assessment is draft.

Publication and finalization require every snapshot result to have a non-null score;
an empty roster satisfies completeness vacuously. A teacher comment cannot exist
without a score. Score is inclusive from zero through the stored maximum. There is
no exempt, missing, late, absent, letter-grade, percentage, rounding, or calculated
grade state in v0.8.

## Lifecycle, publication, and correction

```text
create -> draft/unpublished
draft/unpublished -> draft/published             publish
draft/unpublished -> finalized/unpublished       finalize
draft/published   -> finalized/published         finalize
finalized/unpublished -> finalized/published     publish
draft/unpublished -> cancelled/unpublished        cancel
finalized/*       -> corrected/* + finalized/* successor  correct
```

- Metadata and results are editable only while draft. Publishing is one-way; there
  is no unpublish command. A published draft remains editable, and each changed
  result is immediately visible through RLS and independently audited/evented.
- Finalization freezes all academic content: assessment metadata, scope, roster,
  scores, and comments. Finalization does not imply publication. A complete
  finalized unpublished assessment may be published later; that command changes
  only publication state and server attribution/timestamp, never academic content.
- Cancellation requires an unpublished draft and a bounded reason. It preserves the
  assessment, snapshot, initialized/recorded results, audit, and outbox history;
  cancelled rows cannot be published, finalized, edited, graded, corrected, or
  reactivated. Cancellation is not deletion.
- Correction requires a finalized target and both `assessments.manage` and
  `assessments.correct`. The old row becomes corrected and a new finalized row is
  appended. The successor copies the exact roster provenance, accepts a complete
  replacement result set, and may correct metadata, subject, dates, maximum score,
  and weight while retaining section, term, and year identity. Every copied roster
  member must also be eligible on the replacement assessment date; if a date
  correction would change eligibility, v0.8 rejects it because roster correction is
  out of scope.
- The replacement inherits publication state. A correction of a published result
  therefore remains continuously readable; a correction of an unpublished result
  remains private. The successor points directly to the corrected version. Repeated
  corrections form a linear chain, and only the live head is readable to students
  and guardians.
- Correction never mutates old snapshot or result rows. Apart from the allowed old
  assessment lifecycle/correction fields, every original row remains byte-identical.
- Draft assessments are not correctable; they are edited in place or, while
  unpublished, cancelled. No archive, delete, restore, reactivation, or
  roster-refresh operation exists in v0.8.

## Exact public RPC signatures

The module exposes exactly seven public RPCs. No public RPC accepts organization ID,
actor, command ID, audit/event data, arbitrary JSON, caller-created row IDs, roster
provenance, lifecycle status, publication timestamps, or finalization timestamps.

```sql
public.create_assessment(
  section_id uuid,
  academic_term_id uuid,
  subject_id uuid,
  assessment_type public.assessment_type,
  title text,
  description text,
  assessment_date date,
  due_date date,
  maximum_score numeric,
  weight numeric
) returns uuid

public.update_assessment(
  id uuid,
  assessment_type public.assessment_type,
  title text,
  description text,
  due_date date,
  set_description boolean default false,
  set_due_date boolean default false
) returns uuid

public.record_assessment_results(
  id uuid,
  results public.assessment_result_input[]
) returns uuid

public.publish_assessment(id uuid) returns uuid

public.finalize_assessment(id uuid) returns uuid

public.cancel_draft_assessment(
  id uuid,
  cancellation_reason text
) returns uuid

public.correct_assessment(
  id uuid,
  replacement_subject_id uuid,
  replacement_assessment_type public.assessment_type,
  replacement_title text,
  replacement_description text,
  replacement_assessment_date date,
  replacement_due_date date,
  replacement_maximum_score numeric,
  replacement_weight numeric,
  replacement_results public.assessment_result_input[],
  correction_reason text
) returns table (
  corrected_assessment_id uuid,
  replacement_assessment_id uuid
)
```

`subject_id`, descriptions, due dates, weight, comments, and corresponding
replacement parameters are nullable. The update flags distinguish preserve from
clear. Correction is a full replacement contract, so null directly means null and
no flags are needed. Result arrays are limited to 10,000 non-null elements, ordered
and locked by student ID, and reject duplicate or non-roster students. Ordinary
recording may be a non-empty partial set; correction requires exactly one result for
every copied snapshot student and requires every score. An empty ordinary result
array is rejected as a no-op; an empty correction array is valid only for an empty
roster.

`publish_assessment` accepts either a draft/unpublished or finalized/unpublished
target and requires complete scores. On a finalized target it updates only
`publication_state`, `published_at/by`, and standard update attribution. It never
changes metadata, roster, scores, comments, finalization attribution, or lifecycle
status. `cancel_draft_assessment` accepts only a draft/unpublished target, trims and
requires a 1–500-character reason, and changes only lifecycle/cancellation and
standard update attribution.

Public wrappers are owned by `postgres`, are `SECURITY DEFINER`, have empty search
paths, revoke execute from implicit `PUBLIC` and `anon`, and grant exact-signature
execute to `authenticated` and `service_role`, consistent with existing published
commands. Service-role availability does not authorize ordinary application use.
Every implementation helper is separately revoked from `PUBLIC`, `anon`,
`authenticated`, and `service_role` except the exact RLS relationship helpers named
below.

## Permissions and contextual access

Add versioned catalog rows:

| Permission | Capability |
|---|---|
| `assessments.view` | Read assessments and all results in assigned RBAC scope |
| `assessments.manage` | Create, edit, grade, publish, finalize, and cancel eligible drafts in assigned RBAC scope |
| `assessments.correct` | Correct finalized history; also requires manage |

Authority is always resolved from stored assessment/section scope. Browser-supplied
scope is never trusted.

| Actor/context | Read all roster/results | Create/update/results/publish/finalize/cancel | Correct |
|---|---:|---:|---:|
| scoped `assessments.view` | yes | no | no |
| scoped `assessments.manage` | yes | yes | no |
| scoped manage + correct | yes | yes | yes |
| effective lead or co-teacher, exact section/subject | yes | yes | no |
| effective substitute, exact section/subject | yes, only while effective | yes, only while effective | no |
| effective assistant | yes, only while effective | no, unless scoped manage | no, unless scoped manage + correct |
| student | own published, non-cancelled live result and comment only | no | no |
| active portal guardian | linked student's published, non-cancelled live result and comment only | no | no |
| unrelated/cross-tenant actor | no | no | no |

Teacher relationship authority requires current-date effectiveness, active
assignment, section, year, optional subject, staff profile, and organization
membership. Subject context matches with `assignment.subject_id IS NOT DISTINCT
FROM assessment.subject_id`; null is a real homeroom/general context and is not a
wildcard. The relationship is checked at command time, not assessment date. It ends
as soon as the assignment ceases to be effective. Scoped administrators retain
historical access. Correction is deliberately permission-only.

The private helpers are small, stable, non-recursive, owned by `postgres`, use empty
search paths, join base relations directly, and receive exact authenticated-only
execute grants:

```text
app_auth.has_assessment_assignment(assessment_id, allowed_roles[])
app_auth.can_read_assessment(assessment_id)
app_auth.can_read_assessment_student(assessment_student_id)
app_auth.can_read_assessment_result(result_id)
```

Header RLS permits scoped view/manage/correct actors, effective assigned teaching
roles, or a student/guardian for whom the live assessment has a published result.
Snapshot and result policies call their row-specific helper so students/guardians
never see classmates. A student's or guardian's own result requires:

- assessment publication state `published` and lifecycle neither `corrected` nor
  `cancelled`;
- matching snapshot/result student ID;
- `app_auth.is_student_self(student_id)` or
  `app_auth.is_linked_guardian(student_id)`; and
- the result score is non-null (also guaranteed by publication).

For an applicable student or linked guardian, the selected published result
includes both `score` and `teacher_comment`; a non-null published teacher comment is
explicitly visible to both. Comments for every other student remain invisible.

Assessment access must not broaden access to students, guardian links, identifiers,
documents, attendance, enrollments, placements, teaching assignments, staff
profiles, audit, outbox, roles, or permissions. Existing policies need no expansion.

## Deterministic locking and retry behavior

Every command performs a non-authoritative discovery read, obtains locks in the
global order below, re-reads all authoritative rows, then validates and writes:

```text
organization
-> school
-> campus
-> academic year
-> academic term
-> section
-> subject (when present)
-> sorted teaching-assignment candidates needed for relationship authority
-> sorted students
-> sorted student enrollments
-> sorted student section placements
-> assessment chain, oldest requested/target before successor, then UUID
-> sorted assessment snapshot rows
-> sorted assessment result rows
```

Create locks roster candidates before inserting the assessment, snapshot, or result
rows. Update, result recording, publish, finalize, and cancel lock the target chain
head and children. Cancellation does not modify children. Correction locks the
target, existing successor candidate, all original children, corrected replacement
parents, and result inputs before changing the old head or inserting the successor.

After locking, changed roster discovery, changed teaching-assignment discovery,
changed scope/parent identity, or a newly discovered successor raises `40001` with a
stable retry message. Clients retry the whole RPC only, with bounded exponential
backoff and jitter (recommended: at most three retries, starting around 50 ms).
Unique/FK/check errors (`23505`, `23503`, `22023`), authorization (`42501`), and not
found (`P0002`) are not retryable. A concurrent duplicate create may resolve as
`23505`; a concurrent correction must resolve to one successor and return `40001`
for stale chain discovery. All domain/audit/outbox effects roll back on failure.

## Audit and outbox inventory

Audit snapshots may contain full reviewed assessment/result rows, including teacher
comments. Outbox payloads never include description, score, teacher comment,
student/guardian names, contact data, identifiers, membership user IDs, or arbitrary
row JSON. Result events may contain `student_id` because consumers need aggregate
routing, but contain only `score_recorded`/`comment_present` booleans, not values.

Event inventory:

| Event | Aggregate type | Required minimal payload beyond correlation fields |
|---|---|---|
| `assessment.created` | `assessment` | school/campus/year/term/section/subject IDs, type, dates, max score, nullable weight, roster count |
| `assessment.updated` | `assessment` | scope IDs and sorted changed-field names |
| `assessment.result_recorded` | `assessment_result` | assessment/result/student IDs, score-recorded and comment-present booleans |
| `assessment.published` | `assessment` | scope IDs, published timestamp, result count |
| `assessment.finalized` | `assessment` | scope IDs, publication state, finalized timestamp, result count, nullable supersedes ID |
| `assessment.cancelled` | `assessment` | scope IDs, cancellation reason and cancelled timestamp |
| `assessment.corrected` | `assessment` | scope IDs, correction reason, successor ID |
| `assessment.result_corrected` | `assessment_result` | replacement assessment/result/student IDs, superseded result ID, booleans only |

All payloads also contain `command_id`, `actor_user_id`, `organization_id`, and
`aggregate_id`. Timestamps are server values. Roster snapshot insertions use action
`assessment.roster_snapshotted`, entity type `assessment_student`, and audit only.
Initial placeholder result insertions use action `assessment.result_initialized`,
entity type `assessment_result`, and audit only.

Exact successful-command cardinality for roster size N and changed-result count K:

| Command | Audit rows | Outbox rows |
|---|---:|---:|
| create | `1 + 2N` | 1 `assessment.created` |
| metadata update | 1 | 1 `assessment.updated` |
| record K results | K | K `assessment.result_recorded` |
| publish | 1 | 1 `assessment.published` |
| finalize | 1 | 1 `assessment.finalized` |
| cancel unpublished draft | 1 | 1 `assessment.cancelled` |
| correct finalized assessment with N students | `2 + 2N` | `2 + N`: corrected old assessment, finalized successor, N corrected results |

Correction audit rows are: old assessment transition, successor assessment,
N copied snapshots, and N replacement results. All rows in a command share one
server-generated command ID. Zero-roster cardinalities are tested explicitly.

## Parent lifecycle compatibility

Migration 009 must preserve every v0.8 predecessor predicate when it wraps an
existing command:

- `update_section` rejects date, status, term, or scope-compatible changes that
  would exclude any live assessment date/due date or detach its term. A section
  with a non-cancelled draft assessment cannot be inactivated; non-cancelled
  assessment history blocks archival. Cancelled drafts do not block inactivation,
  archival, date changes, or term changes. Capacity changes remain governed by
  placements and are unaffected.
- `update_academic_term` rejects dates that exclude a live assessment or its due
  date. Closing/archiving a term is blocked by non-cancelled draft assessments but
  allowed when every live assessment is finalized. Cancelled drafts do not block
  term lifecycle or date changes. Finalized history remains attached.
- `update_academic_year` rejects dates excluding any live assessment or due date.
  Closing/archiving a year is blocked by non-cancelled draft assessments but allowed
  by finalized assessment history. Cancelled drafts do not block year lifecycle or
  date changes. All existing enrollment, assignment, and attendance rules still
  apply.
- Subject inactivation/archive is blocked while a non-cancelled draft assessment
  references it; finalized, corrected, or cancelled history does not block lifecycle
  transition and remains readable through the restrictive FK.
- Enrollment termination/transfer/correction, placement termination/transfer/
  correction, teaching-assignment end/reassignment/correction, student archival,
  and guardian-link changes do not rewrite or invalidate assessment snapshots or
  results. Snapshot provenance is historical observation, not a blocker. Restrictive
  FKs are safe because those domains preserve rows rather than delete them.
- Teaching-assignment changes may immediately end relationship-derived assessment
  access without changing creator, updater, publisher, finalizer, or correction
  history.

Compatibility checks run inside the existing command transaction before its
audit/outbox commit so rejection rolls back all predecessor-domain effects. Use the
established rename/private-implementation plus signature-preserving wrapper pattern
where direct wrapping would be unsafe. Catalog tests must prove existing public
signatures, ownership, grants, and prior validations remain intact. Migration 009
adds no columns to predecessor domain tables.

## TypeScript and Zod public contract

After implementation approval and a fresh local reset, regenerate
`src/platform/database/database.types.ts` from the local public schema with the
existing `npm run db:types`; never hand-edit it or generate against the linked
project. Add `src/modules/assessments/index.ts` containing:

- strict camelCase Zod schemas for all seven RPCs;
- UUID and ISO-date validation;
- literal enums for the five assessment types, four lifecycle states, and two
  publication states;
- trimmed title 1–160, description 1–2,000 nullable, reason 1–500, and teacher
  comment 1–1,000 nullable;
- finite decimal score/max/weight validation matching database bounds, without
  JavaScript-side rounding; the database remains authoritative for score versus
  the stored maximum;
- due-date versus assessment-date refinement where both values are in one input;
- `assessmentResultSchema`, a maximum 10,000-element array, duplicate-student
  refinement, and correction completeness left authoritative to the database;
- inferred command input types plus exact generated RPC Args/Returns aliases;
- `assessmentRpcNames`, `assessmentTypes`, `assessmentLifecycleStatuses`,
  `assessmentPublicationStates`, `assessmentPermissionCodes`, and
  `assessmentEventTypes` literal arrays; these include
  `cancel_draft_assessment`, `cancelled`, and `assessment.cancelled` respectively;
- `AssessmentCommandErrorCode = '22023' | '23503' | '23505' | '40001' | '42501' |
  'P0002'` and `isRetryableAssessmentCommandError`, true only for `40001`; and
- a narrow `AssessmentCommandService` with create, update, recordResults, publish,
  finalize, cancelDraft, and correct methods. The cancel input schema requires a
  trimmed 1–500-character `cancellationReason`.

The adapter maps camelCase to exact generated SQL arguments and composite result
inputs. Business rules do not move into React components or route handlers. The
module exports only public schemas/types/service metadata, not private persistence
queries from academics, enrollments, teaching assignments, or SIS.

## Adversarial pgTAP matrix

### Catalog, schema, and command boundary

- exact enum/composite values, columns, numeric precision, nullability, defaults,
  checks, keys, restrictive composite FKs, normalized partial uniqueness, indexes,
  triggers, and comments;
- forced RLS, authenticated SELECT-only grants, absence of write/delete policies,
  and denial of direct insert/update/delete/truncate and spoofed scope, actor,
  timestamps, state, provenance, and correction links;
- exact seven RPC signatures, returns, owners, security-definer flags, empty search
  paths, ACLs, exact relationship-helper ACLs, and denial of every other private
  helper to browser and service roles;
- migrations 001–008 and all their published signatures remain unchanged.

### Authentication, RBAC, and contextual authority

- anonymous, cross-tenant, wrong school/campus, missing permission, inactive/
  invited/suspended/left membership, inactive/expired role assignment, inactive
  role, and parent-scope denial for every command/read family;
- organization-, school-, and campus-scoped view/manage/correct success and proof
  that correct alone cannot mutate;
- effective lead and co-teacher exact section/subject management; substitute success
  only while effective; assistant read-only; null subject exact-match behavior;
- future, ended, reassigned, corrected, wrong-section, wrong-subject, inactive staff,
  inactive membership, section, subject, and year cases;
- explicit scoped administrative permission gives assistants/substitutes only that
  permission's capability and does not depend on teaching role;
- teaching relationships cannot correct or mutate academics, enrollment, SIS,
  assignments, attendance, audit, or outbox.

### Parent, date, roster, and score invariants

- active same-scope organization/school/campus/year/term/section/subject checks;
  term/year and section/term match, including year-long null-term sections;
- section/year/term boundary assessment and due dates, future-date acceptance,
  due-before-assessment rejection, max-score and weight boundaries;
- title/description/comment/reason 0/1/max/max+1 boundaries and trimming;
- empty and populated rosters, exact provenance/attribution, duplicate placement
  detection, corrected enrollment/placement exclusion, and all inclusive date
  boundaries;
- score zero/max accepted; negative, over-max, null-comment mismatch, non-finite/
  overflow, duplicate/non-roster student, null element, empty/no-op, and oversized
  array rejection;
- concurrent roster or authority discovery drift returns `40001`; duplicate create
  produces one live assessment; audit/outbox failure rolls back every row.

### Lifecycle, publication, and immutability

- valid metadata update and partial/multiple result recording while draft;
- publish requires complete scores and is one-way; it succeeds from unpublished
  draft and unpublished finalized states. Finalized publication changes only
  publication metadata. Repeat publish, cancelled/corrected publish, and incomplete
  publication have zero side effects;
- students and guardians see nothing before publication and see only their own
  assessment header/snapshot/result after publication, never classmates or comments
  on other results;
- published-draft edits become visible and produce exact audit/events;
- finalize from published/unpublished complete draft, empty-roster finalize, repeat
  or incomplete finalize rejection, exact actors/timestamps; finalized academic
  content remains byte-identical when later published;
- cancel only an unpublished draft with reason length 1/500 accepted and 0/501
  rejected; published draft, finalized, corrected, cancelled, repeat cancellation,
  and every reactivation attempt fail atomically; snapshot/results remain
  byte-identical and preserved; a replacement draft with the same normalized live
  uniqueness tuple can be created after cancellation;
- direct or command mutation of finalized scope/metadata/results/snapshot fails.

### Correction and concurrency

- valid published and unpublished whole-assessment correction; corrected old row,
  finalized successor, inherited publication, exact copied roster provenance,
  complete replacement results, and linear second correction;
- correction of draft/already-corrected/non-head, blank/oversized reason, wrong
  parent/scope/date/score, duplicate/missing/extra result, and correction without
  both permissions fails atomically;
- concurrent correction leaves exactly one successor; stale successor discovery is
  `40001`; old finalized snapshot/results remain byte-identical;
- current enrollment/placement may differ and correction still uses the original
  roster, validating eligibility from the preserved provenance rows rather than
  current non-corrected heads; a replacement assessment date that changes roster
  eligibility is rejected; later append-only enrollment/placement correction
  succeeds without changing assessment history.

### RLS, compatibility, events, and regression

- scoped administrators see authorized history; current teachers/assistants see
  only exact currently effective contexts; access ends with assignment; unrelated
  actors see zero rows;
- cancelled rows never appear through student/guardian contextual RLS, cancelled
  drafts no longer occupy live uniqueness, and administrators/authorized teachers
  retain the documented historical read behavior;
- published teacher comments are visible to exactly the applicable student and
  linked guardian and never to classmates or unrelated guardians;
- inactive/archived student, guardian, link, or lost portal access removes
  relationship reads; a guardian linked to multiple students sees only those
  students' published rows;
- assessment RLS does not broaden any predecessor-domain, audit, or outbox read;
- exact event names, payload allow-list, aggregate IDs, cardinalities, shared command
  IDs, and exclusion of scores/comments/descriptions and unrelated personal data;
- section/term/year/subject compatibility and rollback, explicit proof that
  cancelled drafts block none of those parent lifecycle changes, plus proof that
  enrollment, placement, teaching, student, and guardian lifecycle operations do
  not rewrite snapshots/results;
- focused v0.8 tests pass during implementation and all prior suites remain green at
  the final implementation gate.

## Documentation deliverables

Implementation adds `docs/modules/assessments.md` and updates
`docs/architecture/security.md`, `docs/architecture/system-overview.md`, and affected
academics, enrollments, teaching-assignments, and SIS module documentation. The docs
must state the public interfaces, permissions, RLS relationships, event payloads,
locking/retry contract, snapshot semantics, correction model, and parent lifecycle
rules. They must also document visibility-only publication of finalized unpublished
assessments, terminal draft cancellation, and student/guardian visibility of their
applicable published teacher comments.

## Definition of done after another independent review

- additive migration 009 implements only the approved contract; migrations 001–008
  remain unchanged;
- `supabase/tests/assessment_gradebook_foundation_v0_8_test.sql` covers the complete
  adversarial matrix, catalog security, concurrency, rollback, compatibility, and
  exact audit/outbox cardinality;
- locally regenerated public database types and strict Zod/TypeScript assessment
  contracts agree;
- module and architecture documentation is current;
- at the implementation verification gate only: fresh local reset/application,
  focused and full database suites, strict TypeScript typecheck, production build,
  and whitespace checks pass;
- no deployment, linked-project mutation, production change, UI, import,
  notification, analytics, stage, commit, push, or merge occurs without a separate
  request.

## Binding product decisions

No unresolved product decisions remain in this revision. The six prior
recommendations are approved with the reviewed lifecycle clarifications:

1. Roster eligibility is anchored to `assessment_date`; the snapshot remains fixed
   after creation.
2. Score is nullable only while drafting. Every roster student requires a numeric
   score before publication or finalization; missing/exempt outcome states remain
   deferred.
3. Weight is optional percentage points in `(0,100]`, stored without sum or grade
   calculation in v0.8.
4. Published drafts remain auditable/editable until finalization. Finalization
   freezes academic content, but a complete finalized unpublished assessment may
   subsequently be published without changing that content. There is no unpublish.
5. A finalized correction successor inherits publication state, preserving a
   continuous single live result for published chains.
6. Teaching-assignment subject context uses exact null-safe matching; null is a real
   homeroom/general context, never a wildcard. Broader authority requires scoped
   RBAC.

The added cancellation decision is binding: only unpublished drafts may be
cancelled; cancellation is terminal, preserves all rows/history, removes the row
from live uniqueness, grants no student/guardian visibility, and does not block
parent lifecycle changes.
