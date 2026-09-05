# Enrollment & Section Placement v0.5

## Boundary

The enrollment module owns academic-year enrollment and effective-dated section
placement history. SIS school/campus remains administrative security scope;
academics owns years, grades, terms, and sections. Attendance, grading, billing,
admissions, timetables, course registration, waitlists, and rollover are out of
scope.

## Commands, permissions, and reads

Nine typed RPCs implement enroll, enrollment withdrawal/completion/correction,
placement, transfer, and placement withdrawal/completion/correction. Staff reads use
`enrollments.view`; ordinary commands require `enrollments.manage`; corrections also
require `enrollments.correct`. Same-tenant cross-school enrollment checks both the
student's administrative scope and academic destination without moving the SIS row.

Forced RLS gives scoped staff, the student, and active portal-enabled guardians
contextual SELECT access. Direct client writes and hard deletes are denied. RPCs
accept no tenant, actor, command ID, event/audit content, arbitrary JSON, or caller-
created row ID. Generated types and `src/modules/enrollments/index.ts` define the
strict adapter/application boundary.

## History and invariants

- Non-corrected enrollment ranges for one student cannot overlap across schools.
- Scope facts are immutable; correction retains the original and optionally appends
  a replacement through `supersedes_*`.
- Both original halves of a transfer are corrected as one unit. The correction may
  append at most one replacement placement episode; recreating a complete corrected
  transfer requires a future dedicated workflow and is outside v0.5.
- One active homeroom-style placement exists per enrollment, with exact grade match.
- Dates are inclusive; transfer on D ends source D−1 and starts destination D.
- Every active placement, including a future placement, reserves capacity.
- Ending enrollment atomically ends every active placement with the same outcome.
- Active children block invalid parent state/date/capacity changes.
- There is no reactivation, capacity override, hard delete, or in-place correction.

## Concurrency, audit, and events

Commands discover, lock, and re-read organization, sorted schools/campuses, student,
year, sorted grade/term/section parents, enrollment, and placements. Discovery drift
raises retryable SQLSTATE `40001`.

Domain, audit, and outbox rows commit under one server-generated `command_id`.
Payloads contain IDs, scope, dates, outcomes, reasons, and changed fields, never
student/guardian PII, identifiers, or document/storage metadata.

Events: `student.enrolled`, `student.enrollment_withdrawn`,
`student.enrollment_completed`, `student.enrollment_corrected`,
`student.section_placed`, `student.section_transferred_out`,
`student.section_transferred_in`, `student.section_withdrawn`,
`student.section_completed`, and `student.section_placement_corrected`.

Teaching Assignments v0.6 adds no enrollment mutation path. Its current-assignee
relationship may read only currently effective, non-corrected enrollment and
placement rows for the assigned section. Future or ended assignments and historical
roster rows do not qualify.

Attendance Foundation v0.7 snapshots the qualifying enrollment and placement IDs
when a daily session opens. That snapshot records what the system observed; it is
not a continuing assertion that the source facts are correct. Later append-only
enrollment or placement correction proceeds normally, retains referenced corrected
rows through restrictive foreign keys, and never rewrites attendance history.

Assessment Foundation v0.8 snapshots the same enrollment and placement provenance
at `assessment_date`. Later append-only withdrawal, transfer, completion, or
correction does not rewrite, invalidate, or get blocked by an assessment snapshot.
