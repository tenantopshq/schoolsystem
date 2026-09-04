# Attendance Foundation v0.7

## Boundary

Attendance owns daily section sessions, immutable open-time roster snapshots,
student marks, absence reasons, and append-and-supersede correction history. It
does not own periods, lessons, timetables, guardian access, notifications,
analytics, or UI.

## Commands and history

Seven typed RPCs manage reasons and open, submit, finalize, or correct sessions.
Future sessions are prohibited. Scoped `attendance.manage` actors may open and
submit past or current in-range dates. A current lead, co-teacher, or substitute
may open or submit only today's assigned section. Assistants have contextual read
only. Finalization requires manage; correction requires manage plus
`attendance.correct`.

Submission records exactly one present, absent, late, or excused mark for every
snapshot student. Absent and excused require an active applicable reason and may
carry a bounded note. Present and late carry neither; late alone may carry an
arrival time.

Finalized correction marks the prior session corrected and appends a finalized
replacement with the original roster and a complete replacement mark set. Roster
membership cannot be corrected in v0.7. Enrollment and placement corrections may
proceed independently: snapshot provenance records what the system observed at
opening and remains attached through restrictive foreign keys.

## Security and concurrency

All attendance tables force RLS and grant authenticated users SELECT only. Small
non-recursive relationship helpers support current-assignment reads. Writes cross
narrow security-definer commands, derive scope and actor, lock parents and children
in deterministic order, and atomically append audit and outbox effects. Discovery
drift uses retryable SQLSTATE `40001`; validation and constraint failures are not
automatically retryable.
