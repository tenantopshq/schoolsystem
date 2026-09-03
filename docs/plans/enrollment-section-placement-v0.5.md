# Enrollment & Section Placement v0.5 Plan

Status: implemented and locally verified. The coordinator approved all recommended
defaults on 2026-08-29, with the explicit cross-school non-overlap rule recorded in
the final section and the lower-risk single-placement replacement clarification
approved on 2026-09-04. Migration 006, public TypeScript contracts, documentation,
and focused adversarial tests now implement this contract.

## Objective and boundary

v0.5 introduces the academic record that a student is enrolled in a school for an
academic year and the immutable history of placement in that year's sections. It
supports enrollment, section placement, transfer, withdrawal, completion, and
explicit correction without making browser clients trusted database writers.

In scope:

- one academic-year enrollment aggregate per student/school/year history chain;
- effective-dated section placement episodes;
- atomic placement, transfer, withdrawal, completion, and correction commands;
- capacity, date, parent-status, grade, tenant, and school consistency;
- application RBAC plus forced RLS and contextual student/guardian reads;
- deterministic locking with explicit retryable concurrency failures;
- command-correlated audit and event-outbox records;
- generated database types and strict TypeScript/Zod public contracts; and
- comprehensive adversarial pgTAP coverage.

Explicitly out of scope:

- attendance, grading, transcripts, report cards, billing, tuition, and fees;
- timetable generation, meeting patterns, teacher assignment, broad scheduling,
  course/subject registration, and waitlists;
- admissions, applications, offers, acceptance, and onboarding workflow;
- changing `students.school_id`, `students.campus_id`, or identity links;
- changing academic structure or period records through enrollment commands; and
- hard deletion, bulk import, automatic year rollover, and promotion automation.

The enrollment module consumes public SIS student and academics structure contracts.
It must not import either module's private persistence adapter. PostgreSQL composite
foreign keys enforce the relational boundary, public service types are used by the
application, and integration consumers react through the event outbox.

## Existing foundation and migration posture

Migrations `202608190001` through `202608190005` are immutable. Migration 006 will
be additive and named `202608190006_enrollment_section_placement_v0_5.sql` only
after the decisions below are approved.

The existing schema already provides:

- tenant/school/campus scope, memberships, scoped role assignments, permissions,
  `app_auth.has_permission`, forced RLS, audit, and outbox;
- students whose school/campus is administrative scope rather than academic history;
- academic years, optional terms, grade levels, and sections with immutable tenant,
  school, campus, year, and grade scope;
- section capacity and effective dates bounded by year/optional term;
- composite tenant/scope keys needed by new foreign keys;
- command-only academic and SIS writes, deliberate grants, generated types, and
  empty-search-path security-definer conventions; and
- multi-row command correlation indexes on audit/outbox from v0.4.

Migration 006 must not repair unrelated foundation behavior. Any newly discovered
foundation defect that is necessary for v0.5 must be called out as an explicit,
minimal additive correction with matching regression tests.

## Proposed relational model

Use dedicated enums rather than overloading `record_status`:

```sql
create type enrollment_status as enum
  ('active', 'withdrawn', 'completed', 'corrected');

create type section_placement_status as enum
  ('active', 'withdrawn', 'completed', 'transferred', 'corrected');
```

`corrected` is terminal and means the row was superseded because the recorded fact
was wrong. It is not an ordinary cancellation or withdrawal. No draft/pending state
is proposed because admissions is outside this milestone.

### `student_enrollments`

```text
id uuid primary key
organization_id uuid not null
school_id uuid not null
academic_year_id uuid not null
student_id uuid not null
grade_level_id uuid not null
enrolled_on date not null
ended_on date null
status enrollment_status not null default active
end_reason text null
supersedes_enrollment_id uuid null
correction_reason text null
created_at / updated_at timestamptz
created_by / updated_by uuid
```

Required composite foreign keys:

- `(organization_id, student_id) -> students(organization_id, id)`;
- `(organization_id, school_id, academic_year_id) -> academic_years(...)`;
- `(organization_id, school_id, grade_level_id) -> grade_levels(...)`; and
- `(organization_id, supersedes_enrollment_id) -> student_enrollments(...)`.

Constraints:

- `enrolled_on` is within the academic year inclusive;
- `ended_on` is null only for active rows and otherwise is between `enrolled_on`
  and the year end;
- active rows have no end/correction reason;
- withdrawn/completed rows require nonblank `end_reason` and no correction reason;
- corrected rows require nonblank `correction_reason`;
- a row cannot supersede itself; and
- organization, school, year, student, grade, and original creation metadata are
  immutable after insert. Lifecycle commands may set only terminal fields.

Recommended uniqueness is one active enrollment per `(student_id,
academic_year_id)`. Completed/withdrawn history remains; correction creates a new
row linked to the corrected predecessor. A partial unique index enforces the active
rule, and a history index supports `(organization_id, student_id, academic_year_id,
enrolled_on, id)` reads.

### `student_section_placements`

```text
id uuid primary key
organization_id uuid not null
school_id uuid not null
campus_id uuid not null
academic_year_id uuid not null
student_enrollment_id uuid not null
student_id uuid not null
section_id uuid not null
starts_on date not null
ends_on date null
status section_placement_status not null default active
end_reason text null
transfer_to_placement_id uuid null
supersedes_placement_id uuid null
correction_reason text null
created_at / updated_at timestamptz
created_by / updated_by uuid
```

Use composite foreign keys so tenant, school, year, enrollment, student, section,
and campus cannot be mixed. Migration 006 may add only the minimum supporting
unique composite key to `student_enrollments` needed by those references. The
section reference must bind `(organization_id, school_id, campus_id,
academic_year_id, section_id)`; the enrollment reference must bind organization,
school, year, student, and enrollment ID.

Constraints:

- placement dates are inside the enrollment, section, year, and optional term;
- active placements have null `ends_on` and no terminal/correction fields;
- withdrawn/completed/transferred placements require `ends_on` and a nonblank
  reason; transferred rows also reference the atomically created destination;
- corrected rows require a correction reason; an optional replacement points back
  through `supersedes_placement_id` rather than rewriting the corrected row;
- the section grade equals the enrollment grade;
- endpoint and effective-scope columns never change after creation; and
- terminal placements are immutable.

Recommended uniqueness is one active placement per enrollment because current
sections model grade/homeroom cohorts, not subject/course registration. A student
may have sequential placements in a year. History indexes cover enrollment,
student/year, section/status/date, and all foreign-key/RLS traversals.

No `DELETE` or cascade-delete relationship is allowed. All new foreign keys use
`ON DELETE RESTRICT`.

## Lifecycle and workflow invariants

### Enrollment

`enroll_student` creates an active enrollment. It requires an active student,
organization, destination school, academic year, and grade level. The enrollment
date must be inside the active academic year. The command does not move the SIS
student record.

`withdraw_student_enrollment` and `complete_student_enrollment` are terminal
transitions. They require a nonblank reason and effective end date. Before ending
the enrollment, the same command locks and terminates all active section placements
with the matching outcome and date, producing audit/events for every affected row.
This prevents stranded active placements.

Completion means the student finished the enrollment as recorded; withdrawal means
the enrollment ended early. Neither implies promotion, transcript generation, or
SIS archival. Terminal enrollment rows cannot be reactivated.

`correct_student_enrollment` is a privileged append-and-supersede command. It marks
the erroneous enrollment corrected, terminates/corrects its active placements, and
optionally creates one replacement enrollment with corrected school/year/grade/date
facts in the same transaction. It returns both corrected and replacement IDs, with
the replacement nullable when the fact should be voided. It never rewrites the old
row. A replacement cannot create a duplicate active enrollment.

### Section placement

`place_student_in_section` creates an active episode against an active enrollment
and active section. The effective start is inside all parent date ranges, section
grade matches enrollment grade, and capacity is available.

`transfer_student_section` atomically ends the current placement as `transferred`
and creates the destination placement. It requires authority over source and
destination scope, validates the destination at the transfer date, reserves capacity
under lock, links both rows, and returns `{ from_placement_id, to_placement_id }`.
No transient state may leave two active placements or no destination after a
successful transfer.

`withdraw_student_section_placement` ends only the placement; the enrollment remains
active. `complete_student_section_placement` records successful section completion
without completing the enrollment. Both require a reason and effective end date.

`correct_student_section_placement` marks an erroneous episode corrected and may
create at most one replacement placement episode atomically. When the source is one
half of a transfer, both original halves are corrected as one unit, but the optional
replacement remains a single ordinary placement. It returns corrected and nullable
replacement IDs. Replacement facts must pass the same scope/date/grade/capacity
checks as ordinary placement. Recreating a complete corrected transfer is outside
v0.5 and requires a future dedicated workflow. Correction never mutates a
historical endpoint.

All no-op transitions, future-invalid transitions, changes to terminal rows, empty
reasons, and mixed lifecycle/business-field updates fail with deliberate SQLSTATE
`22023`. Missing authoritative rows use `P0002`, permission failures `42501`, and
uniqueness/constraint conflicts retain deliberate `23505`/`23503` behavior.

## Proposed public command contract

Nine narrow, typed `public` RPCs are implemented:

```text
enroll_student(student_id uuid, academic_year_id uuid, grade_level_id uuid,
               enrolled_on date) -> uuid
withdraw_student_enrollment(id uuid, ended_on date, reason text) -> uuid
complete_student_enrollment(id uuid, ended_on date, reason text) -> uuid
correct_student_enrollment(id uuid, replacement_academic_year_id uuid,
                           replacement_grade_level_id uuid,
                           replacement_enrolled_on date,
                           replacement_status enrollment_status,
                           replacement_ended_on date,
                           replacement_end_reason text,
                           create_replacement boolean,
                           correction_reason text)
  -> table(corrected_enrollment_id uuid, replacement_enrollment_id uuid)

place_student_in_section(student_enrollment_id uuid, section_id uuid,
                         starts_on date) -> uuid
transfer_student_section(id uuid, destination_section_id uuid,
                         transfer_on date, reason text)
  -> table(from_placement_id uuid, to_placement_id uuid)
withdraw_student_section_placement(id uuid, ended_on date, reason text) -> uuid
complete_student_section_placement(id uuid, ended_on date, reason text) -> uuid
correct_student_section_placement(id uuid, replacement_section_id uuid,
                                  replacement_starts_on date,
                                  replacement_ends_on date,
                                  replacement_status section_placement_status,
                                  replacement_end_reason text,
                                  create_replacement boolean,
                                  correction_reason text)
  -> table(corrected_placement_id uuid, replacement_placement_id uuid)
```

These are **nine** recommended public RPCs. A tenth command,
`void_student_section_placement(id uuid,
correction_reason text) -> uuid` only if the coordinator chooses separate correction
and void operations. The recommended contract instead folds void into
`correct_student_section_placement(create_replacement = false)`, leaving **nine**
public RPCs. This count must be finalized with the correction decision and asserted
in catalog tests.

No RPC accepts organization, school, campus, student duplication, actor, command ID,
status, audit snapshot, event type/payload, arbitrary JSON, or caller-created row ID.
Nullable replacement values use an explicit boolean rather than interpreting null
ambiguously. Exact PostgreSQL signatures, owner, grants, comments, and generated
return shapes will be frozen in the implementation plan review.

## RBAC, RLS, and read relationships

Seed three permissions:

| Permission | Purpose |
|---|---|
| `enrollments.view` | Staff read of enrollments and placements in assigned scope |
| `enrollments.manage` | Enrollment and ordinary placement workflows |
| `enrollments.correct` | Append-only correction/void workflows; also requires manage |

Every mutation requires active membership, active role, effective role-assignment
dates, and `enrollments.manage` in authoritative scope. Corrections require both
`enrollments.manage` and `enrollments.correct`. Cross-school/campus transfer or
correction requires authorization over every old and new scope. Organization roles
may operate throughout their tenant; school/campus assignments remain constrained.

Recommended read policies allow:

- staff with `enrollments.view` or `enrollments.manage` in stored school/campus;
- the student whose `students.user_id = auth.uid()`; and
- an active guardian link with portal access for that student.

Guardian/student reads grant no mutation authority. Placement reads derive through
the stored enrollment and section scope. Historical terminal rows remain readable
from their stored scope even when a student, school, campus, year, section, guardian
link, or membership later becomes inactive, subject to a currently valid actor
relationship/role.

Both tables enable and force RLS. Authenticated receives SELECT only. Remove no
existing read policies. New tables have operation-specific SELECT policies and no
client INSERT/UPDATE/DELETE policy. Revoke all direct writes/truncate from PUBLIC,
`anon`, and `authenticated`; no hard-delete RPC exists. Service role receives no
ordinary domain-table mutation grant. Public commands are executable only by
`authenticated` and explicitly `service_role`; `anon` and PUBLIC are revoked.

## Private command architecture

Typed public wrappers call small private `app_auth` functions with schema-qualified
references and `SET search_path = ''`. Recommended helpers:

- `assert_enrollment_actor()` derives and validates `auth.uid()`;
- `lock_enrollment_scope(...)` discovers IDs without trusting them, locks parents in
  global order, and re-reads authoritative rows;
- `assert_enrollment_permission(...)` evaluates stored and destination scope;
- `assert_enrollment_dates(...)` validates year/enrollment/section/term ranges;
- `assert_section_capacity(...)` counts capacity under the locked section;
- private enrollment and placement command dispatchers accept only operation enums
  selected by typed wrappers, never caller JSON; and
- `write_enrollment_change(...)` appends reviewed audit/outbox rows using one
  server-generated command ID supplied by the enclosing command.

Private helpers and dispatchers are owned by `postgres` and executable by no browser
role or service role. Public wrappers are `SECURITY DEFINER`, owner `postgres`, have
empty search paths, and explicitly revoke/grant every exact signature. Add comments
for table sensitivity, history, command intent, lock order, retry contract, and why
security definer is safe.

## Locking and concurrency

Extend the existing global order rather than introducing a competing order:

```text
organization
  -> sorted schools
  -> sorted campuses
  -> sorted students
  -> sorted academic years
  -> sorted grade levels
  -> sorted academic terms
  -> sorted sections
  -> enrollment
  -> sorted placements
```

For moves/corrections, discover source and destination without locks, compute the
union of parent IDs, lock every level in ascending UUID order, then re-read all
source/destination rows. If scope, relevant placement set, section capacity inputs,
or enrollment state changed during discovery, abort with SQLSTATE `40001` and a
stable retry message. Clients retry the entire command with bounded jitter/backoff;
validation, permission, and uniqueness errors are not retryable.

Enrollment termination locks the enrollment and all active placements before its
invariant decision. Placement create/transfer locks the destination section before
counting active reservations and then locks enrollment/placements in consistent
order. Correction locks the complete predecessor/replacement chain. Sorted peer
locks prevent reversed source/destination transfers from deadlocking. Partial unique
indexes and composite constraints remain the final authority.

True two-session tests should cover: two final seats, reversed transfers, placement
versus enrollment withdrawal/completion, section closure/capacity reduction versus
placement, and correction versus transfer. Where the local pgTAP harness cannot
coordinate sessions safely, add catalog/body lock-order assertions and a documented
external race harness; do not claim those assertions are equivalent to a real race.

## Capacity and date rules

Recommended capacity semantics reserve one seat for every active placement,
including a future-effective active placement. This is deterministic and avoids
oversubscription when the start date arrives. Transfer releases the source and
reserves the destination in one transaction; when source and destination are the
same section, reject the no-op.

Section capacity reductions and archive/inactivation commands in the academics
module must become aware of active placements. Migration 006 may use additive
`CREATE OR REPLACE FUNCTION` changes to the existing academic command bodies, with
regression tests, but must not edit migration 004. An active placement blocks
section archive/inactivation and capacity below the reserved count. Year/term close
or archive and date-range reductions must likewise reject active or historical rows
that would become invalid, unless the approved lifecycle policy explicitly permits
terminal history under closed parents.

Recommended date semantics use inclusive dates. `starts_on` may equal section/year
start; `ends_on` may equal start or parent end. A transfer on date D ends the source
on D-1 and starts the destination on D, so no day is double-booked. This requires D
to be later than the source start. Same-day erroneous placements use correction,
not transfer.

## Audit and outbox contract

Every successful command creates one server-side `command_id`. Domain writes,
audit rows, and outbox rows are one transaction. One-row commands emit exactly one
audit and one event. Transfer emits two audit rows and two events under one command
ID. Enrollment termination emits one enrollment change plus one change for every
automatically terminated placement under one command ID. Correction emits rows for
the corrected record, its linked original transfer half when present, and at most
one optional replacement placement, all correlated.

Audit snapshots contain reviewed before/after relational data and reserved
`_changed_fields`, `_reason`, and `_correction_reason` context. Actors cannot provide
those keys. Avoid student names, guardian details, or unrelated SIS snapshots;
foreign IDs are enough. Existing global uniqueness indexes support multiple entity
rows per command and must not be weakened.

Proposed events:

- `student.enrolled`, `student.enrollment_withdrawn`,
  `student.enrollment_completed`, `student.enrollment_corrected`;
- `student.section_placed`, `student.section_transferred_out`,
  `student.section_transferred_in`, `student.section_withdrawn`,
  `student.section_completed`, `student.section_placement_corrected`.

Payloads contain only `command_id`, actor/organization IDs, aggregate/entity ID,
student ID, enrollment ID, academic year, derived school/campus, grade/section IDs,
effective dates, before/after lifecycle state, and reason for terminal/correction
events. They contain no student names, birth dates, identifiers, guardian/contact
data, documents/storage data, arbitrary snapshots, or caller-supplied event fields.
Transfer events include both placement and source/destination section IDs. Exact
event cardinality and payload denylist tests are mandatory. Any audit/outbox failure
must roll back every domain row and state transition.

## TypeScript integration

After migration approval and implementation:

1. run a fresh local reset and regenerate
   `src/platform/database/database.types.ts` from the migrated schema;
2. add an enrollment module public index without importing private academics/SIS
   persistence code;
3. export the finalized RPC-name, event-name, permission, lifecycle, result, and
   retryable-error unions derived against generated `Database` function types;
4. define `.strict()` Zod schemas for every command with UUID, ISO-date, bounded
   nonblank reason, enum, nullable replacement, and cross-field refinements;
5. expose camelCase DTOs and explicitly map to snake_case RPC arguments; and
6. expose `isRetryableEnrollmentCommandError` only for SQLSTATE `40001`.

Application types must make tenant, actor, status, student duplication, audit/event
content, and arbitrary JSON impossible to supply. Composite/table results for
transfer/correction must expose only necessary created/affected IDs. Type-level
tests should catch generated signature drift and forbidden fields; PostgreSQL remains
the authorization authority.

## Adversarial pgTAP matrix

### Schema, constraints, indexes, and catalog

- tables/enums/columns/defaults/checks/composite FKs and `ON DELETE RESTRICT`;
- forced RLS on both tables and operation-specific SELECT-only policies;
- every FK/RLS/capacity/history traversal indexed;
- one-active-enrollment and finalized active-placement uniqueness;
- exact normalized permission seeds, RPC count/signatures/return columns;
- exact owner, `prosecdef`, empty search path, comments, and grants;
- private helpers not executable by PUBLIC/anon/authenticated/service role;
- no direct write/delete/truncate grants or policies; and
- migrations 001–005 byte-for-byte unchanged and existing public RPCs preserved.

### Authentication, RBAC, RLS, and spoof resistance

- anonymous and null-actor denial for every RPC family;
- missing, wrong, inactive, suspended, invited, left, future, and expired membership/
  assignment denial;
- organization-, school-, and campus-scoped success in exact scope;
- cross-tenant, cross-school, and cross-campus denial;
- old-and-new authorization for transfers and corrections;
- `enrollments.correct` without manage and manage without correct both denied;
- caller cannot spoof tenant, scope, student, status, actor, command, event, or IDs;
- direct writes denied even when a caller has manage permission; and
- staff, student-self, linked guardian, inactive/unlinked guardian, portal-disabled
  guardian, and unrelated student read cases.

### Enrollment behavior

- valid enrollment for every permitted scope;
- inactive/archived student, school, year, or grade denied;
- mismatched tenant/school/year/grade denied;
- dates before/after year denied and inclusive boundaries accepted;
- duplicate active enrollment denied while terminal history remains;
- withdrawal/completion reason/date rules and terminal immutability;
- enrollment end atomically ends all active placements with exact outcomes;
- correction void and replacement, duplicate prevention, chain integrity, and
  original row immutability; and
- no SIS administrative-scope mutation as a side effect.

### Placement behavior

- valid placement, grade match, scope match, date and optional-term boundaries;
- inactive/archived section/enrollment/parents denied;
- one-active-placement rule and sequential history;
- final seat succeeds, over-capacity fails with no side effects;
- transfer success, no-op rejection, source/destination authorization, capacity,
  atomic links, dates, and two-ID result;
- withdrawal/completion terminal behavior and enrollment independence;
- correction with/without replacement, chain integrity, capacity rollback, and
  immutable original facts; and
- academic section/year/term changes cannot strand valid history or active rows.

### Concurrency, audit, outbox, and rollback

- deterministic lock-order/body assertions and genuine two-session cases listed
  above where supported;
- changed discovery state produces retryable `40001` and no partial side effects;
- exact audit/outbox count and shared command ID for every single/multi-row command;
- exact event names, aggregate IDs, derived scope/effective dates, and changed fields;
- denylisted PII/SIS identifier/document fields absent from every payload;
- actor and organization always server-derived;
- forced audit failure and forced outbox failure roll back enrollment, placements,
  transfers, corrections, and cascaded terminal transitions; and
- uniqueness, capacity, permission, validation, and 40001 failures append neither
  audit nor outbox records.

Run a fresh `npm run db:reset`, focused v0.5 pgTAP, full database suite, generated
type drift check, strict typecheck, affected application tests, production build,
and `git diff --check` before implementation handoff.

## Approved product decisions

All decisions below are binding for v0.5.

1. **Concurrent section model.** Recommend one active section placement per academic-
   year enrollment because current sections represent grade/homeroom cohorts. If
   sections are intended as subject/course sections, the schema needs grouping or
   subject dimensions and simultaneous placements; that is materially larger.
2. **Cross-school academic enrollment.** Same-tenant enrollment may use a school
   different from the SIS administrative school. Commands require authority over
   the student's stored scope and destination school/campus and never mutate SIS.
3. **Enrollment uniqueness.** Non-corrected enrollment date ranges for the same
   student may not overlap across schools. Migration 006 models the authoritative
   range and enforces the rule transactionally; future dual-enrollment support
   requires an explicit design rather than an override.
4. **Lifecycle states.** Recommend active plus terminal withdrawn/completed/corrected,
   with no draft/pending/reactivation. Draft/pending belongs to admissions and would
   add approval transitions.
5. **Correction model.** Recommend append-and-supersede with optional replacement,
   handled by the correction RPC boolean; never update historical scope/business
   facts in place. Approval also finalizes nine RPCs rather than a separate tenth
   void RPC.
6. **Enrollment ending active placements.** Recommend atomic automatic termination
   of all active placements using the enrollment outcome. Requiring callers to
   clean them first is simpler internally but creates avoidable partial workflows.
7. **Capacity reservation.** Recommend every active placement reserves capacity,
   including future-effective rows. Counting only currently effective dates needs
   overlap/exclusion rules and can silently oversubscribe future sections.
8. **Transfer date convention.** Recommend destination starts on D and source ends
   on D-1, with inclusive dates. An alternative same-day overlap needs half-open
   timestamp/date semantics throughout.
9. **Placement grade rule.** Recommend exact equality between enrollment grade and
   section grade. Mixed-grade sections would require an explicit join table or flag
   on sections, outside current schema.
10. **Read relationships.** Recommend scoped staff plus student-self and active,
    portal-enabled linked guardians. If enrollment history is staff-only, contextual
    RLS and related tests should be omitted deliberately.
11. **Backdating.** Recommend allowing dates anywhere inside still-active parent
    ranges, with ordinary manage permission; correction permission is required only
    to supersede an existing fact. A configurable backdate window or special backdate
    permission would add policy/configuration schema.
12. **Parent closure/history.** Recommend terminal placement/enrollment history may
    remain under closed academic periods, while parent date changes may never make
    existing history invalid and active children block close/archive. Decide whether
    completing all enrollments should be required before year close.
13. **Reasons.** Recommend nonblank bounded free text (1–500 characters) for every
    terminal/correction operation. Coded reason catalogs are useful but constitute a
    separate managed-reference-data decision.
14. **Capacity override.** Recommend no override in v0.5. If authorized overbooking
    is required, add a distinct permission, explicit override reason, audit/event
    fields, and tests rather than a generic boolean.
15. **Correction of transfers.** Treat a transfer's linked source and destination as
    one correction unit: lock, authorize, and correct both original halves
    atomically. The existing correction RPC may append at most one replacement
    placement episode and returns that single nullable ID. It does not recreate a
    source/destination transfer pair. Recreating a complete corrected transfer is
    outside v0.5 and requires a future dedicated workflow and contract.
