# Teaching Assignments v0.6

## Boundary

The teaching-assignments module owns effective-dated staff responsibility for an
academic section and optional subject. It does not own staff employment, academic
structure, enrollment, timetables, attendance, grading, or substitute scheduling.

Assignments use lead, co-teacher, assistant, and manually recorded substitute
roles. A null subject is the section's homeroom/general context. Multiple teachers
may overlap, but exclusion constraints permit only one overlapping active lead per
section and subject context, including the null-subject context.

## Commands and history

Four typed RPCs create, end, reassign, and correct assignments. Reassignment ends
the source on D-1 and creates its successor on D atomically. Corrections append an
optional replacement and never rewrite immutable facts. Neither side of a
reassignment link can be corrected; erroneous facts must be corrected first.

Direct table writes and hard deletion are unavailable. Successful changes append
correlated audit and minimal outbox records in the same transaction.

## Authorization and contextual reads

`teaching_assignments.view`, `.manage`, and `.correct` use the destination section's
school/campus scope. Assignees require active staff profiles and active organization
memberships; staff home placement is descriptive.

A teacher relationship grants read-only access only while the assignment is
currently effective. It covers the assignment, section/year, optional subject, and
currently effective non-corrected placement, enrollment, and ordinary student rows.
It grants no mutation authority and no identifier, guardian, address, emergency
contact, document, audit, or outbox access. Future and ended assignments grant no
roster access.

Three non-recursive security-definer relationship helpers support these RLS paths.
Only their exact signatures are executable by `authenticated`; all command
implementation helpers remain inaccessible.

## Parent compatibility

Assignment dates are inclusive and bounded by both section and academic year.
Active assignments block section archival/inactivation and academic-year
close/archive. Parent date changes cannot exclude non-corrected assignment history.

Attendance Foundation v0.7 uses currently effective lead, co-teacher, and
substitute assignments to authorize opening and submitting today's daily session.
Assistants receive contextual attendance reads only. Assignment end, reassignment,
or correction ends relationship-derived attendance access without rewriting stored
attendance attribution or history.
