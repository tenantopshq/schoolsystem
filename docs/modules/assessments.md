# Assessment & Gradebook Foundation v0.8

## Boundary

Assessments owns section assessments, assessment-date roster snapshots, one result
per snapshot student, publication, finalization, cancellation, and finalized
append-and-supersede correction. GPA, reports, transcripts, credits, rank, rubrics,
standards, curves, analytics, attendance grades, and cross-assessment totals remain
outside this foundation.

## Commands and history

Seven typed RPCs create and update drafts, record results, publish, finalize, cancel
unpublished drafts, and correct finalized assessments. A published draft remains
editable. Finalization freezes all academic content but does not publish it; a
complete finalized unpublished assessment may later be published through a
visibility-only transition.

Cancellation is terminal and available only for unpublished drafts. It preserves
the assessment, immutable roster snapshot, initialized or recorded results, audit,
and event history. Cancelled rows do not occupy live title/date uniqueness and do
not block section, term, year, or subject lifecycle changes.

Finalized correction marks the old version corrected and appends a finalized
successor with the exact original roster provenance and a complete replacement
result set. The successor inherits publication state. Corrected and cancelled rows
are terminal; no command deletes, restores, or rewrites their academic history.

## Authorization and reads

Scoped `assessments.view` reads authorized rows. `assessments.manage` creates,
grades, publishes, finalizes, and cancels. Correction requires both manage and
`assessments.correct`.

Currently effective lead teachers and co-teachers may manage assessments for their
exact section and null-safe subject context. Substitutes have that authority only
while effective. Assistants have contextual read access unless separately granted
scoped administrative permissions. Teaching relationships never grant correction.

Students and active portal guardians can read only the live published assessment,
snapshot, score, and teacher comment for the applicable student. Published teacher
comments are intentionally visible to that student and linked guardian. They never
see classmates, unpublished results, cancelled rows, or corrected predecessors.

All assessment tables force RLS and grant authenticated clients SELECT only. Writes
cross narrow security-definer commands that derive actor and scope, lock parents and
children deterministically, and append audit/outbox effects atomically. SQLSTATE
`40001` alone identifies retryable discovery drift.

## Invariants and integrations

Assessment and due dates lie inside section, academic-year, and term dates. Optional
subjects belong to the section school. Roster eligibility is snapshotted at
`assessment_date` from non-corrected enrollment and placement ranges. Every roster
student has one result row; score is nullable only while drafting, bounded by the
assessment maximum, and required before publication or finalization. Teacher
comment is optional and requires a score. A cancelled draft preserves any null
scores it had at cancellation.

Cancelled snapshots are retained but do not constrain parents. Live assessment
dates constrain section, term, and year date changes; non-cancelled drafts block
relevant parent closure or inactivation. Enrollment, placement, teaching-assignment,
student, and guardian lifecycle operations do not rewrite assessment history.

Every command uses a server-generated command ID. Changed domain rows receive audit
records; allow-listed events omit descriptions, scores, and comments. Roster and
placeholder-result initialization are audit-only. Multi-row result and correction
events share their command ID.
