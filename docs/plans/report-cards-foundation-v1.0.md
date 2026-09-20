# Report Cards Foundation v1.0 plan

## Status and approval

Independent product, architecture, security, database, and privacy review approved
this plan and all 29 decisions on 2026-09-07. This document governs additive migration
`202608190011_report_cards_foundation_v1_0.sql` and a dedicated
`report-cards` domain module. Migrations 001–010 remain immutable.

The plan is based on the checked-in migrations, pgTAP suites, generated public
database types, module contracts, and architecture/security documentation through
Term Grades v0.9. In particular, it extends these existing contracts:

- tenant scope is derived from authoritative rows and checked by scoped RBAC plus
  forced RLS;
- browser roles receive SELECT-only table grants and mutate through narrow typed
  `SECURITY DEFINER` RPCs with `search_path = ''`;
- enrollment, placement, teaching-assignment, attendance, assessment, and term-grade
  history is append-preserving;
- attendance correction replaces a whole finalized session while retaining the
  original roster and marks;
- term-grade correction replaces a whole finalized set and retains exact assessment,
  result, scale, and calculation provenance;
- contextual lead/co-teacher/substitute authority is exact-section and null-safe
  subject scoped, while assistants are read-only; and
- successful commands atomically correlate protected audit rows and minimal outbox
  events by one server-generated `command_id`; SQLSTATE `40001` alone means retry the
  complete command.

## Scope and product contract

v1.0 is term-based only. One report-card aggregate represents one student, section,
academic term, and linear publication lineage. It snapshots grades and attendance;
renderers never calculate either from mutable current state. The stable read model
is relational and supports future PDF/UI consumers without defining templates or
rendering.

Creation is allowed only when the section/term has at least one active term-grading
configuration and every null-safe subject context represented by those active
configurations has exactly one live finalized term-grade set whose current generation
contains the student. The active configurations define required context keys only;
the selected finalized set may legitimately retain an older, now-retired immutable
configuration version. The snapshot always records the selected set's actual
`term_grading_configuration_id`, scale, band, and calculation provenance and never
rewrites them to the currently active configuration version. Missing any required
context blocks the whole card. Source term-grade sets do not also need to be
published: finalization supplies academic immutability, while report-card publication
is the deliberate portal release boundary.

Attendance covers the academic term's exact inclusive `[start_date, end_date]` range,
further constrained to the section and student's snapshotted placement/enrollment
eligibility. It includes only live `finalized` attendance-session heads; corrected
predecessors, drafts/open sessions, and submitted sessions do not count. The summary
stores `total_session_count`, `present_count`, `absent_count`, `late_count`, and
`excused_count`, with the four marks summing to total. No qualifying attendance is a
valid zero summary, not missing data.

Cards support at most one overall comment and at most one comment for each snapshotted
subject context. Lead/co-teachers and effective substitutes may author comments only
for an exact subject assignment; lead/co-teachers with a null-subject assignment may
author the overall comment. Assistants are read-only. Substitutes cannot author the
overall comment. Scoped administrators with `report_cards.manage` may author either
kind, but authorship always records the actual user and applicable staff profile.

Teachers can prepare comments and subject sign-offs but cannot finalize or publish a
whole card through contextual authority. Whole-card finalization, publication,
cancellation, batch review, and correction are administrative commands. Finalization
requires `report_cards.manage`; correction requires both `report_cards.manage` and
`report_cards.correct`. Publication strictly follows finalization and is one-way.

Correction atomically marks the live finalized/published predecessor `corrected` and
appends a fully snapshotted successor. A successor of a published card is created
`published` in the same transaction so authorized families never lose the live card;
a successor of an unpublished finalized card is `finalized`. The predecessor is never
rewritten except for terminal correction metadata. Predecessor sign-offs stay only on
the predecessor. Active predecessor comments are copied with their original author,
staff, assignment, and creation attribution when they are overall comments or when
the successor still contains the same non-null subject context; removed-subject
comments are not copied. No
teacher, homeroom, or administrator-review sign-off is copied. The correcting
administrator instead certifies the successor atomically. Draft cards may be
cancelled; finalized or published cards must use correction and cannot be cancelled
or unpublished.

Names and other display identity are snapshotted so later SIS edits cannot silently
change an issued card. The approved minimal display snapshot is student number,
student display name, section code/name, grade-level code/name, academic-year name,
term name/sequence/start/end, school name/code, and campus name/code. Date of birth,
gender, nationality, addresses, guardian data, photos, and identifiers are neither
copied nor exposed; a later renderer needing them must use separately authorized SIS
reads. Signatures are attribution records only—no signature image, blob, path, hash,
or upload capability exists in v1.0.

## Migration 011 schema

### Enums and command composites

Create these public types with exactly the listed values and order:

```sql
public.report_card_status = ('draft','finalized','published','corrected','cancelled')
public.report_card_comment_type = ('overall','subject')
public.report_card_comment_status = ('active','withdrawn')
public.report_card_signoff_type = ('subject_teacher','homeroom_teacher','administrator_reviewer','administrator_correction_certification')
public.report_card_signoff_status = ('active','revoked')
public.report_card_batch_status = ('draft','reviewed','cancelled')
public.report_card_batch_student_input = (student_id uuid)
```

The batch input composite is intentionally ID-only. No RPC accepts tenant, actor,
scope snapshot, status, version, number, audit/event, grade, attendance total, display
text, or provenance values from the caller.

In the table definitions below, “root scope IDs” means exactly
`organization_id`, `school_id`, `campus_id`, `academic_year_id`,
`academic_term_id`, and `section_id`, each `uuid not null`. “Card scope IDs” means
those six columns plus `student_id uuid not null`. This shorthand never permits a
column to be omitted.

### `public.report_card_batches`

Administrative generation/review envelope; it is not the report-card aggregate and
does not override individual card lifecycle.

| Column | Definition |
|---|---|
| `id` | `uuid primary key default gen_random_uuid()` |
| scope | `organization_id`, `school_id`, `campus_id`, `academic_year_id`, `academic_term_id`, `section_id` all `uuid not null` |
| lifecycle | `status report_card_batch_status not null default 'draft'` |
| review | `reviewed_at timestamptz`, `reviewed_by uuid references auth.users on delete restrict` |
| cancellation | `cancelled_at timestamptz`, `cancelled_by uuid references auth.users on delete restrict`, `cancellation_reason text` bounded trimmed 1–500 when present |
| audit metadata | `created_at`, `updated_at` non-null timestamptz defaults; `created_by`, `updated_by` non-null auth-user restrictive FKs |

Constraints and keys:

- composite FK `(organization_id,school_id,campus_id,academic_year_id,section_id)`
  to the exact section;
- composite FK `(organization_id,academic_year_id,academic_term_id)` to the term;
- `unique (organization_id,id)` and
  `unique (organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,id)`;
- `draft` has no review/cancellation metadata, `reviewed` has review metadata only,
  and `cancelled` has cancellation metadata only; reviewed and cancelled are terminal.

Indexes: scope/status
`(organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,status,id)`,
plus partial indexes on `reviewed_by`, `cancelled_by`, and ordinary indexes on
`created_by`, `updated_by`.

### `public.report_cards`

Aggregate root and stable card header.

| Column group | Exact columns |
|---|---|
| identity/scope | `id uuid primary key default gen_random_uuid()`, `organization_id`, `school_id`, `campus_id`, `academic_year_id`, `academic_term_id`, `section_id`, `student_id`, `student_enrollment_id`, `student_section_placement_id` as `uuid not null` |
| lineage/number | `lineage_id uuid not null`, `version integer not null check(version >= 1)`, `report_card_number bigint not null check(report_card_number >= 1)`, `supersedes_report_card_id uuid` |
| batch | `report_card_batch_id uuid` nullable |
| lifecycle | `status report_card_status not null default 'draft'`, `finalized_at`, `finalized_by`, `published_at`, `published_by`, `corrected_at`, `corrected_by`, `correction_reason`, `cancelled_at`, `cancelled_by`, `cancellation_reason` |
| source/staleness | `source_fingerprint bytea not null check(octet_length(source_fingerprint)=32)`, `snapshot_taken_at timestamptz not null default now()` |
| display snapshot | `school_code text`, `school_name text`, `campus_code text`, `campus_name text`, `academic_year_name text`, `academic_term_name text`, `academic_term_sequence smallint`, `term_start_date date`, `term_end_date date`, `section_code text`, `section_name text`, `grade_level_code text`, `grade_level_name text`, `student_number text`, `student_display_name text`, all non-null and bounded to their source maxima; display name max 302 |
| audit metadata | `created_at`, `updated_at` non-null timestamptz defaults; `created_by`, `updated_by` non-null auth-user restrictive FKs |

Composite provenance FKs are mandatory:

- exact section `(organization_id,school_id,campus_id,academic_year_id,section_id)`;
- exact term `(organization_id,academic_year_id,academic_term_id)`;
- student `(organization_id,student_id)`;
- exact enrollment
  `(organization_id,school_id,academic_year_id,student_id,student_enrollment_id)`;
- exact placement
  `(organization_id,school_id,campus_id,academic_year_id,section_id,student_id,
  student_enrollment_id,student_section_placement_id)`;
- predecessor `(organization_id,supersedes_report_card_id)`;
- optional exact batch context using the batch's seven-part composite key.

Keys and checks:

- `unique (organization_id,id)` and an exact aggregate composite key containing all
  scope IDs, student ID, and `id` for child FKs;
- `unique (organization_id,lineage_id,version)`;
- school-scoped immutable number: `unique (school_id,report_card_number)`;
- exactly one live lineage head:
  `unique (organization_id,lineage_id) where status not in ('corrected','cancelled')`;
- one successor per predecessor with a partial unique index;
- root requires `version=1`, `lineage_id=id`, and null predecessor; successor requires
  `version>1`, non-null predecessor, and a different ID;
- predecessor must share organization, school, section, term, student, and lineage,
  and have `version = successor.version - 1`; enforce the cross-row portion with a
  deferred constraint trigger because a plain FK cannot prove arithmetic;
- display strings are trimmed/nonempty and dates/sequence exactly equal locked source
  parents when inserted;
- lifecycle metadata is exact: draft has none; finalized has finalization only;
  published has finalization and publication; corrected retains its original
  finalization/publication metadata and adds correction metadata; cancelled has only
  bounded cancellation metadata and must have originated as a draft.

Indexes: portal lookup
`(organization_id,student_id,status,academic_term_id,section_id,id)`, contextual scope
`(organization_id,school_id,campus_id,section_id,academic_term_id,status,student_id,id)`,
lineage `(organization_id,lineage_id,version desc)`, batch
`(organization_id,report_card_batch_id,id)` partial, enrollment and placement FK
indexes, and partial actor indexes for every lifecycle actor.

School numbering is allocated inside the locked school row as
`max(report_card_number)+1` for that school in v1.0. It is immutable, never reused,
and every successor receives a new number; lineage/version conveys correction
history. This avoids adding a mutable counter table. Concurrency is serialized by the
school lock and the unique constraint is a final guard.

### `public.report_card_grade_snapshots`

One immutable current-calculation snapshot for each required null-safe subject
context on a card.

Columns: `id`; all root scope IDs; `report_card_id`; `student_id`; nullable
`subject_id`; `subject_code`, `subject_name`; `term_grading_configuration_id`,
`term_grade_set_id`, `term_grade_record_id`, `term_grade_calculation_id`,
`grade_scale_id`, `grade_scale_band_id`; `term_grade_calculation_sequence integer`;
`raw_percentage numeric(20,10)`, `rounded_percentage numeric(7,4)` constrained 0–100;
`grade_label` bounded 1–32; `result_state grade_result_state`;
`contributing_assessment_count integer >= 0`; `weight_total numeric(7,4)`;
`source_term_grade_fingerprint bytea` length 32; `created_at`; `created_by`.

Required keys/FKs:

- exact card composite FK proving scope and student;
- exact subject FK `(organization_id,school_id,subject_id)` when non-null;
- exact term-grade set FK proving organization/school/campus/year/term/section/set;
- add an immutable unique key to `term_grade_records` over
  `(organization_id,term_grade_set_id,student_id,calculation_sequence,id)` if not
  already present (it is present in migration 010) and reference it exactly;
- add unique key
  `(organization_id,term_grade_set_id,student_id,calculation_sequence,
  term_grade_record_id,id)` to `term_grade_calculations`, then reference all six
  columns exactly from the snapshot;
- exact band FK `(organization_id,grade_scale_id,grade_scale_band_id)`;
- null-safe uniqueness with two partial indexes: one overall/null-subject row per card
  and one row per `(report_card_id,subject_id)` for non-null subjects.

Indexes cover report card ordering, subject/context lookup, every provenance FK, and
student RLS traversal. Snapshot rows have no update/delete path and an always-reject
trigger provides defense in depth against owner mistakes.

### `public.report_card_grade_sources`

Complete copied provenance for each grade snapshot. One row is copied from every
`term_grade_calculation_sources` row belonging to the selected calculation.

Columns: `id`, `organization_id`, `report_card_id`, `report_card_grade_snapshot_id`,
`student_id`, `term_grade_calculation_source_id`, `assessment_root_id`,
`assessment_version_id`, `assessment_id`, `assessment_student_id`,
`assessment_result_id`, and copied numeric inputs `score`, `maximum_score`,
`assessment_weight`, `score_ratio`, `effective_weight`, `weighted_points`, plus
`created_at`, `created_by`.

Use an exact composite FK to the grade snapshot proving card/student, an FK to the
original source, and the same exact assessment root/version/snapshot/result composite
FKs established by migration 010. Unique
`(report_card_grade_snapshot_id,term_grade_calculation_source_id)`. Index every FK
and `(organization_id,assessment_result_id,student_id)`. Rows are immutable and never
available to student/guardian RLS.

### `public.report_card_attendance_snapshots`

Exactly one immutable summary per card.

Columns: `id`, all card scope IDs, `report_card_id`, `student_id`,
`range_start_date`, `range_end_date`, five non-negative integer counts
`total_session_count`, `present_count`, `absent_count`, `late_count`,
`excused_count`, `source_fingerprint bytea` length 32, `calculated_at`,
`created_at`, `created_by`.

Constraints require the range to equal the snapshotted term dates, the four mark
counts to sum exactly to total, `unique(report_card_id)`, and an exact card
scope/student FK. Index `(organization_id,student_id,report_card_id)` and all FK
columns. Rows are immutable.

### `public.report_card_attendance_sources`

One immutable row per live finalized session/mark counted in the summary.

Columns: `id`, `organization_id`, `report_card_id`,
`report_card_attendance_snapshot_id`, `student_id`, `attendance_session_id`,
`attendance_session_student_id`, `attendance_mark_id`, `session_date`,
`mark attendance_mark_status`, `absence_reason_id` nullable, `created_at`,
`created_by`.

Migration 011 adds unique keys
`attendance_sessions(organization_id,school_id,campus_id,academic_year_id,section_id,id)`,
`attendance_session_students(organization_id,school_id,campus_id,academic_year_id,
section_id,session_id,student_id,id)`, and
`attendance_marks(organization_id,school_id,campus_id,academic_year_id,section_id,
session_id,student_id,session_student_id,id)` only where migration 008 does not
already provide the exact key. The source table references those complete identities,
so a session, roster student, and mark cannot be mixed. Reference absence reason by
`(organization_id,school_id,absence_reason_id)` when present. Unique
`(report_card_attendance_snapshot_id,attendance_session_id)` and indexes on the
session, mark, student, and reason FKs. Do not copy attendance notes, arrival times,
or absence-reason text. Rows are immutable and hidden from portal roles.

### `public.report_card_comments`

Append-preserving authored comment records.

Columns: `id`, all card scope IDs, `report_card_id`, `student_id`,
`comment_type`, nullable `subject_id`, `body text` trimmed length 1–2,000,
`author_user_id uuid not null`, `author_membership_id uuid not null`, `author_staff_profile_id uuid`,
`author_teaching_assignment_id uuid`, `status` default active,
`withdrawn_at`, `withdrawn_by`, `withdrawal_reason` bounded 1–500,
`created_at`, `created_by`.

Checks require overall => null subject and subject => non-null subject. Teacher-authored
rows require both exact active/effective staff and assignment provenance at command
time; administrator-authored rows may have both null. Exact FKs prove card scope,
subject, staff/member/user, and assignment section/subject/role context. Membership
is composite-bound to organization and user; staff is composite-bound to that
membership; assignment is composite-bound to organization, school, campus, year,
section, null-safe subject, and staff. Partial
unique indexes allow one active overall comment and one active comment per subject;
replacement first withdraws the old draft comment, then inserts a new row. Withdrawn
rows are terminal. Comments freeze once the card leaves draft. Index card/subject,
author, staff, assignment, and active-row RLS paths.

### `public.report_card_signoffs`

Append-preserving attribution—not an image signature.

Columns: `id`, all card scope IDs, `report_card_id`, `student_id`,
`signoff_type`, nullable `subject_id`, `signer_user_id`, `signer_membership_id`, nullable
`signer_staff_profile_id`, nullable `teaching_assignment_id`,
`status` default active, `signed_at default now()`, `revoked_at`, `revoked_by`,
`revocation_reason` bounded 1–500, `created_at`, `created_by`.

Subject sign-off requires a non-null subject and exact lead/co-teacher/substitute
assignment. Homeroom sign-off requires null subject and exact lead/co-teacher
null-subject assignment. Administrator review requires null subject, no teaching
assignment, and scoped `report_cards.manage` on a root draft. Administrator correction
certification requires null subject, no teaching assignment, a non-null predecessor,
and the correcting actor to hold both scoped `report_cards.manage` and
`report_cards.correct`; it is inserted only by `correct_report_card`, never by the
general sign command. Active/revoked metadata must match. Partial unique indexes
enforce one active sign-off per card/type/null-safe subject, one active administrator
review, and one active administrator correction certification. Revocation is allowed
only while the card is draft, so correction certifications on already finalized or
published successors are immutable. Revoked rows are terminal. Exact provenance FKs
and indexes mirror comments.

### `public.report_card_batch_items`

Columns: `id`, batch scope IDs, `report_card_batch_id`, `report_card_id`,
`student_id`, `created_at`, `created_by`. Exact composite FKs prove that batch and card
share organization/school/campus/year/term/section and that the card belongs to the
student. Unique `(report_card_batch_id,student_id)` and
`(report_card_batch_id,report_card_id)`. Index card and student traversal. Immutable.

### Immutability and grants

All nine tables enable and force RLS. Revoke all table privileges from `public`,
`anon`, and `authenticated`, then grant `SELECT` only to `authenticated`. Grant no
sequence privileges. No INSERT/UPDATE/DELETE/TRUNCATE policies exist. Reject all hard
deletes. Child snapshot/source/batch-item rows are absolutely immutable. Root updates
may change only the exact lifecycle fields allowed by a command; comments/sign-offs
may only transition active to withdrawn/revoked while their card is draft. Scope,
identity, display snapshot, numbering, lineage, provenance, content, authorship,
timestamps, and prior terminal rows cannot change. All triggers are private and
unexecutable by browser or service roles.

RLS helpers are table-specific. `can_read_report_card_header(card_id)` is not reused as
sufficient authority for a child row. Grade snapshots, comments, and sign-offs require
either scoped RBAC, portal ownership of a published card, null-subject lead/co
homeroom breadth, or an exact non-null subject relationship matching the child row.
Grade-source policy additionally joins through its owning grade snapshot and repeats
that exact-subject test. Attendance summary/source policy permits only scoped RBAC,
portal ownership of a published summary (summary only, never sources), or null-subject
lead/co homeroom breadth. Batch and batch-item policies are scoped-RBAC only.

## Public command API

All signatures are exact, owned by `postgres`, `SECURITY DEFINER`, and set an empty
search path. Revoke execute from implicit `public` and `anon`; grant only the listed
public wrappers to `authenticated` (and, following current repository convention,
explicitly decide during review whether `service_role` also needs execute; the
recommended default is no ordinary service-role execution).

```sql
public.create_report_card(student_id uuid, section_id uuid, academic_term_id uuid)
  returns uuid

public.create_report_card_batch(section_id uuid, academic_term_id uuid,
  students public.report_card_batch_student_input[])
  returns table(report_card_batch_id uuid, report_card_count integer)

public.save_report_card_comment(report_card_id uuid,
  comment_type public.report_card_comment_type, subject_id uuid, body text)
  returns uuid

public.withdraw_report_card_comment(id uuid, reason text)
  returns uuid

public.sign_report_card(report_card_id uuid,
  signoff_type public.report_card_signoff_type, subject_id uuid)
  returns uuid

public.revoke_report_card_signoff(id uuid, reason text)
  returns uuid

public.review_report_card_batch(report_card_batch_id uuid)
  returns uuid

public.finalize_report_card(report_card_id uuid)
  returns uuid

public.publish_report_card(report_card_id uuid)
  returns uuid

public.cancel_draft_report_card(report_card_id uuid, cancellation_reason text)
  returns uuid

public.correct_report_card(report_card_id uuid, correction_reason text)
  returns table(corrected_report_card_id uuid, replacement_report_card_id uuid)

public.cancel_report_card_batch(report_card_batch_id uuid, cancellation_reason text)
  returns uuid
```

`sign_report_card` rejects `administrator_correction_certification`; that type can be
created only as an internal, atomic effect of `correct_report_card`. It also rejects
administrator review on a correction successor, whose certification is the sole
administrative authorization record.

Individual creation is contextual only for an exact current lead/co-teacher/substitute
relationship that can author at least one required subject, or administrative
`report_cards.manage`; batch creation is administrator-only. The creation command
derives the student enrollment/placement effective during the term and requires one
unambiguous non-corrected enrollment/placement for the section. If a student changed
placements during the term, creation is allowed only when exactly one placement in
the target section intersects the term; otherwise v1.0 rejects ambiguity rather than
merging section contexts.

Batch creation requires 1–500 distinct non-null student IDs, sorts them, and executes
the same per-card validation/snapshot rules atomically. It creates one batch, N cards,
N items, and all card children. A failure for one student rolls back the whole batch.
Review requires every card still be draft, have all required active comments/sign-offs
defined below, and have fresh grade/attendance fingerprints. Review does not finalize
cards. Cards may then be finalized individually; batch review is an optional workflow,
not a prerequisite. Batch cancellation is allowed only while draft and only when all
member cards are still draft/cancelled; it does not implicitly cancel cards.

Private helpers include actor assertion, contextual read/write checks, parent locking,
coverage discovery, deterministic grade and attendance fingerprints, snapshot
population, readiness validation, lifecycle transition, and atomic audit/outbox
writing. Revoke every private helper from all browser roles and `service_role`; grant
only narrowly reviewed stable RLS relationship helpers to `authenticated`.

## Read model and RLS/RBAC matrix

Portal-visible tables are card headers, grade snapshots, attendance summaries,
comments, and sign-offs. Batch rows/items and grade/attendance provenance sources are
staff-only. A corrected/cancelled card is never a live portal card.

| Principal | Header and child rows | Provenance/batches | Draft comment/sign-off | Create | Batch/review | Finalize/publish/cancel | Correct |
|---|---|---|---|---|---|---|---|
| Scoped administrator with `report_cards.view` only | all cards in scope, read only | read provenance; batches in scope | no | no | no | no | no |
| Scoped administrator with `report_cards.manage` | all in scope | all in scope | any allowed type; admin review | individual | create/review/cancel batch | yes | no unless also correct |
| Scoped administrator with manage + correct | all in scope | all in scope | yes | yes | yes | yes | yes |
| Current lead/co-teacher with non-null exact subject | card header plus only that subject's grade snapshot, comments, and sign-offs | only matching grade provenance; no attendance summary/source, other subjects, overall rows, or batches | that subject's comment/sign-off | individual | no | no | no |
| Current substitute with non-null exact subject | same subject-limited rows, only while effective | only matching grade provenance | that subject's comment/sign-off | individual while effective | no | no | no |
| Current null-subject lead/co homeroom teacher | full contextual card: header, attendance summary, every subject snapshot/comment/sign-off, and overall rows | all matching grade and attendance provenance for the card; no unrelated batches | overall comment/homeroom sign-off; subject authoring still requires an exact subject assignment | individual | no | no | no |
| Assistant with non-null exact subject | header plus that subject's snapshot/comment/sign-off, read only | matching grade provenance only; no attendance/batches | no | no | no | no | no |
| Null-subject assistant | header only, read only | none | no | no | no | no | no |
| Student self, active student | own live `published` card only | none | no | no | no | no | no |
| Active linked portal guardian | linked active student's live `published` card only | none | no | no | no | no | no |
| Anonymous, inactive member/staff/student/guardian/link, unrelated user | none | none | no | no | no | no | no |

`report_cards.view`, `report_cards.manage`, and `report_cards.correct` are seeded in
the `report_cards` module. Manage and correct imply RLS read but remain distinct
permission checks. Relationship helpers revalidate active organization membership,
active staff profile, assignment status/effective range, exact section, and null-safe
subject. Header access is the common minimum. Child policies distinguish non-null
subject access from null-subject homeroom breadth: a subject assignment can traverse
only rows whose `subject_id` equals its own and provenance below that grade snapshot;
it never inherits card-wide access merely because it can see the header. A null-subject
lead/co-teacher receives the documented card-wide read relationship, including
attendance and every subject. Student access uses `is_student_self`; guardian access
uses the existing active `has_portal_access` relationship. Both additionally require
active student status and the unique live card status `published`.

Students/guardians can select only live published rows from the five portal-visible
tables and never receive provenance-source or batch rows. Correction/cancellation
metadata is null on a live published head by lifecycle constraint; attribution IDs on
live comment/sign-off rows are intentionally visible. A future presentation API may
expose a smaller projection, but v1.0 must not use a definer view that bypasses
underlying RLS.

## Lifecycle and readiness

| Current state | Command | Next state | Authority | Preconditions/effect |
|---|---|---|---|---|
| none | create | draft | contextual teacher or manage | complete grade coverage, exact enrollment/placement, grade and attendance snapshots |
| draft | save/withdraw comment | draft | exact author role or manage | append new comment/withdraw old; snapshot fingerprints are unchanged |
| draft | sign/revoke | draft | exact signer role or manage | append attribution/revoke; no image |
| draft batch | review | reviewed | manage | every member draft is ready and fresh; batch metadata only |
| draft | finalize | finalized | manage | fresh sources; all required sign-offs; immutable thereafter |
| finalized | publish | published | manage | one-way visibility transition; still fresh by immutable snapshot definition |
| draft | cancel | cancelled | manage | bounded reason; terminal |
| finalized | correct | corrected + finalized successor | manage + correct | atomic append/supersede; fresh snapshots, eligible comments copied, no prior sign-offs copied, new correction certification |
| published | correct | corrected + published successor | manage + correct | same certification rule; atomic replacement preserves uninterrupted live visibility |
| corrected/cancelled | any | none | none | terminal |

No publication before finalization, no unpublish, no reopen, no no-op transition, and
no correction of a non-head. Finalization readiness requires:

- required null-safe context keys still equal those derived from active configurations,
  and each snapshotted source remains the same live finalized set for its context;
  the source set's immutable configuration version need not be the active version;
- attendance fingerprint still equals the current finalized live session/mark set;
- one active subject-teacher sign-off for every non-null subject snapshot;
- one active homeroom sign-off when the section has an effective null-subject lead or
  co-teacher during the term; otherwise no homeroom sign-off is required;
- exactly one active administrator-review sign-off for ordinary draft finalization;
- comments are optional; missing comments never block finalization; and
- source/display/card invariants remain valid.

A correction successor does not re-run ordinary draft sign-off readiness. No teacher,
homeroom, or administrator-review sign-off is copied. Instead, the correction command
inserts exactly one active `administrator_correction_certification` by the correcting
actor in the same transaction; that certification, fresh snapshots, and preserved
eligible comment attribution authorize the successor's immediate finalized or
published state.

There is deliberately no implicit refresh command: if a draft is stale, cancel it and
create a new draft. This preserves review provenance and avoids mutating grade or
attendance child snapshots. Correction creates a new immutable version instead.

## Snapshot, provenance, and staleness

Grade snapshots copy the exact current `term_grade_records` generation and its one
calculation, grade scale/band, and every calculation source. They store both source
IDs and display/calculated values. Future assessment, term-grade, scale, enrollment,
placement, or SIS correction cannot alter snapshot bytes.

The grade fingerprint is SHA-256 over a versioned canonical serialization ordered by
null-subject first, then subject UUID. It includes the required context-key set derived
from active configurations but not those active configuration version IDs. For each
context it includes the selected finalized set's actual immutable configuration/set/
record/calculation IDs, set fingerprint and calculation sequence, student ID,
scale/band, calculated values, and ordered calculation-source IDs and values. Thus an
active configuration revision that preserves the same subject context does not by
itself stale a draft; adding/removing a required context or changing its live finalized
set does. The attendance fingerprint is
SHA-256 over a versioned canonical serialization ordered by session date/session ID,
including live finalized session, roster, mark, student, date, status, and reason ID.
The card fingerprint hashes the schema version, authoritative scope/lineage IDs,
display snapshot, grade fingerprint, and attendance fingerprint. Hashes detect drift;
FKs and locked re-reads remain authoritative.

An attendance correction makes every draft card whose attendance source range
contains that session stale. Nothing updates the card automatically. Finalize and
batch-review rederive the fingerprint and raise `40001` with
`report-card sources changed; recreate draft and retry`. Finalized/published cards
remain frozen; administrators use report-card correction if the issued summary must
change. New sessions finalized later within the term likewise stale drafts.

Term-grade correction or a different finalized live set makes affected drafts stale.
An active-configuration change stales drafts only when it adds or removes a required
null-safe context; changing the active version inside an unchanged context does not
invalidate a finalized set that retains its actual older configuration version.
Published/finalized cards remain unchanged. Term-grade publication changes alone do
not stale a report card because publication is not a snapshot eligibility input.

Enrollment/placement correction never rewrites a card. It makes a draft stale if
current authoritative lineage/eligibility differs from the recorded provenance;
finalized history remains valid. Student/guardian/staff/assignment lifecycle changes
affect current access/authority only. SIS display edits stale drafts because display
fields are part of the fingerprint; finalized cards retain the old display snapshot.

## Parent lifecycle compatibility

Migration 011 must wrap current public parent commands additively, preserve their
signatures and all v0.1–v0.9 checks, and call the prior implementation before adding
these rules:

- a draft report card blocks term/year close or archive, section inactivation/archive,
  section term/date changes, relevant subject inactivation/archive, and student
  archive;
- a live finalized/published card blocks destructive scope/date reassignment that
  would make its composite provenance false, but does not block ordinary term/year
  close; corrected/cancelled history remains attached and never authorizes deletion;
- term dates cannot change when any non-cancelled report card references them because
  attendance range and display snapshot would cease to match;
- section, term, year, student, enrollment, placement, term-grade set/record/
  calculation/source, attendance session/roster/mark, subject, scale, band,
  configuration, school, campus, and grade-level rows referenced by a card remain
  protected by `ON DELETE RESTRICT`;
- enrollment/placement corrections remain allowed and append-only; they do not mutate
  cards. Draft freshness catches the change, while finalized cards preserve history;
- attendance correction and term-grade correction remain allowed. They stale drafts
  and preserve finalized cards as described above;
- teaching-assignment changes never rewrite cards or attribution; they affect new
  authoring/current reads and may make an unsigned draft impossible to complete; and
- guardian-link/portal changes affect access only, never card content.

No report-card trigger reaches into another module to perform business work. Parent
wrappers enforce compatibility; report-card commands consume public relational
contracts and emit outbox events for later reactions.

## Deterministic locking and retry behavior

All affected modules must converge on this global parent-first order, sorting every
peer collection by UUID unless another stable order is stated:

1. organization;
2. school;
3. campus;
4. academic year;
5. academic term;
6. grade level;
7. section;
8. subjects (null first, then UUID);
9. students;
10. enrollments by student/ID;
11. placements by student/ID;
12. teaching assignments by section/subject/ID;
13. grade scales then bands by scale/sequence/ID;
14. term-grading configurations by subject/ID;
15. term-grade set chains by lineage/version/ID;
16. term-grade records/calculations/sources by student/subject/source ID;
17. attendance sessions by date/ID, roster rows by student/ID, then marks by student/ID;
18. report-card batches/items by batch/student/ID;
19. report-card lineages by lineage/version/ID;
20. grade snapshots/sources, attendance snapshot/sources, comments, then sign-offs.

Commands discover candidate IDs without trusting their scope, lock authoritative
parents in this order, re-read every discovered head, membership/assignment,
configuration coverage, grade generation/source, attendance head/mark, and card head,
then write. Batch commands sort/deduplicate student IDs before locking. No helper may
hold a later lock and acquire an earlier one; migration 011 must replace/wrap shared
locking hooks where necessary so attendance/term-grade correction obeys the same
order.

Discovery drift, stale fingerprints, changed authority while locking, concurrent live
head creation, school-number collision caused by a racing command, batch membership
drift, and double correction normalize to SQLSTATE `40001` with stable messages.
Invalid static input remains `22023`; missing rows `P0002`; permission failures
`42501`; deterministic constraint conflicts retain `23503`, `23505`, or `23P01`.
Clients retry only `40001`, retry the entire RPC with exponential backoff and jitter,
and make at most three retries after the initial call. They never reuse IDs or retry a
partial statement.

## Audit and outbox contract

Outbox payloads contain only `command_id`, `actor_user_id`, `organization_id`,
`aggregate_id`, school/campus/year/term/section IDs, student ID, lineage ID, version,
status before/after, counts, successor/predecessor IDs, and batch ID/count where
applicable. They exclude names, student number, comment bodies, grade labels/scores/
percentages, attendance marks/reasons/notes, fingerprints, staff/signature details,
authorship prose, correction/cancellation reasons, and all source-row IDs. Full
reviewed before/after rows stay in protected audit only; audit serialization of
comments must replace `body` with `[REDACTED]` to reduce sensitive duplication.

Let `G` be grade snapshots, `GS` copied grade-source rows, `AS` attendance-source
rows, and `C_copy` active predecessor overall comments plus active subject comments
whose non-null subject still exists on the successor. Predecessor sign-offs are not
mutated and zero sign-offs are copied.
Every command has one server-generated command ID.

| Command | Exact audit rows | Exact outbox rows/events |
|---|---:|---|
| create individual | `2 + G + GS + AS` (card, attendance summary, grades, sources) | 1 `report_card.created`; no child events |
| create batch of N | `1 + N + sum(2 + G + GS + AS)` (batch, items, then card + attendance summary + grade/source children per student) | 1 `report_card_batch.created` + N `report_card.created`; no child events |
| save comment, no active predecessor | 1 | 1 `report_card.comment_saved` |
| replace active comment | 2 | 1 `report_card.comment_withdrawn` + 1 `.comment_saved` |
| withdraw comment | 1 | 1 `report_card.comment_withdrawn` |
| sign | 1 | 1 `report_card.signed` |
| revoke sign-off | 1 | 1 `report_card.signoff_revoked` |
| review batch | 1 | 1 `report_card_batch.reviewed` |
| finalize | 1 | 1 `report_card.finalized` |
| publish | 1 | 1 `report_card.published` |
| cancel draft card | 1 | 1 `report_card.cancelled` |
| cancel batch | 1 | 1 `report_card_batch.cancelled` |
| correct finalized/published | `4 + G + GS + AS + C_copy` (old/new roots, new attendance summary, fresh snapshots/sources, eligible copied comments, one correction certification) | 1 `report_card.corrected` + 1 `report_card.finalized` or `.published`; no child/copy/certification events |

The correction successor copies eligible active comments with original attribution
and copies no sign-offs of any type. Every predecessor sign-off remains byte-stable on
the predecessor. The correcting administrator creates exactly one successor
`administrator_correction_certification` atomically for either predecessor state;
this makes the successor immediately correction-certified. The event indicates copied
comment count and certification presence only.

Copied-comment audit action is `report_card.comment_copied`; its redacted after-data
retains original author/staff/assignment/created attribution plus the new row/card ID.
The certification audit action is `report_card.correction_certified`. Neither emits a
separate outbox event; both share the correction command ID.

Every snapshot/source/batch-item row receives an audit row with exact inserted
after-data and no individual outbox event. Audit actions are
`report_card.grade_snapshotted`, `.grade_source_snapshotted`,
`.attendance_snapshotted`, `.attendance_source_snapshotted`, and
`report_card_batch.item_created`. Atomic rollback tests must prove that domain,
audit, and outbox cardinalities are all-or-nothing.

## TypeScript and Zod module contract

Implementation creates `src/modules/report-cards/index.ts` and no cross-module private
persistence imports. It exports:

- strict schemas and inferred inputs for all 12 RPCs;
- `reportCardRpcNames` checked with
  `satisfies readonly (keyof Database["public"]["Functions"])[]`;
- generic `ReportCardRpcArgs<Name>` and `ReportCardRpcResult<Name>` plus batch and
  correction result aliases;
- constants/types for all lifecycle, comment, sign-off, and batch enum values;
- `reportCardPermissionCodes` for the three exact permissions;
- `reportCardEventTypes` for every event named above;
- `ReportCardCommandErrorCode = "22023" | "23503" | "23505" | "23P01" |
  "40001" | "42501" | "P0002"`;
- `isRetryableReportCardCommandError`, true only for `40001`; and
- a `ReportCardCommandService` with one camelCase method per RPC and a read-service
  interface for the portal-safe stable read model.

Zod rules: UUIDs; date strings only where returned read models require them; trimmed
reason 1–500; trimmed comment body 1–2,000; strict objects; explicit nullable subject;
batch arrays 1–500, non-null, unique student IDs; discriminated refinements for
overall/subject comment and sign-off combinations; no unknown keys. Database-derived
values are not accepted in create inputs. Generated
`src/platform/database/database.types.ts` is regenerated from the fully migrated local
database with the existing scripts and never hand-edited.

## Adversarial pgTAP plan

### Schema, grants, and immutability

- exact enum order, tables, columns, defaults, nullability, checks, comments, owners,
  composite keys/FKs, partial uniqueness, triggers, and every FK/RLS index;
- exact 12 public signatures, postgres ownership, definer mode, empty search path,
  explicit authenticated grant, anonymous denial, and private-helper denial including
  service role;
- all nine tables force RLS; authenticated is SELECT-only; direct
  insert/update/delete/truncate and sequence access fail;
- hostile search path, forged organization/scope/actor/version/number/status/timestamp,
  cross-tenant composite-FK swaps, lineage cycles/forks/skips, and source-ID mixing;
- update attempts against snapshot/source/history fields and hard deletes fail,
  including as table owner where the immutability trigger is the intended defense;
- migrations 001–010 and existing public signatures remain unchanged.

### Creation, coverage, and snapshots

- zero/one/many active configurations; null-subject and subject configurations;
  duplicate or retired configs; exact complete context coverage; missing one grade
  blocks the whole card; extra/wrong term/section/student/subject grade cannot enter;
- active configuration version A defines a context while its unique live finalized
  term-grade set retains immutable configuration version B: creation succeeds,
  snapshots B exactly, and never substitutes A; changing A to another version in the
  same context does not stale a draft, while adding/removing a context does;
- draft, cancelled, corrected, finalized-unpublished, and finalized-published
  term-grade sets: only live finalized heads qualify, regardless of publication;
- current calculation generation only; exact scale/band/calculation and all source
  IDs/values copied; a later source correction leaves finalized card bytes unchanged;
- no enrollment, multiple enrollment, wrong school/year, no placement, ambiguous
  intersecting placement, corrected lineage, transfer boundaries, partial-term
  enrollment, and exact student/section provenance;
- attendance at both term boundaries; outside range excluded; open/submitted excluded;
  corrected predecessor excluded and finalized successor included; present/absent/
  late/excused totals; empty history produces five zeros; no note/reason text copied;
- display fields copied exactly and bounded; sensitive SIS fields absent;
- individual and 1/500-member batch creation, duplicates/nulls/501 rejected,
  deterministic ordering, one bad student rolls back all.

### Lifecycle, comments, sign-off, and staleness

- complete transition table; publication-before-finalization, unpublish, repeat/no-op,
  cancel-after-finalization, correct-draft/cancelled/corrected/non-head all fail;
- comment length boundaries, normalized empty body, overall/subject mismatch, duplicate
  active comment replacement, immutable withdrawn rows, and finalized-card freeze;
- exact lead/co/substitute subject authoring, lead/co overall authoring, substitute
  overall denial, assistant denial, wrong/null subject, wrong section, future/expired/
  ended/reassigned/corrected assignment, inactive staff/member;
- exact sign-off requirements, revocation only in draft, administrator review, optional
  comments, and ordinary finalization readiness;
- attendance correction/new finalization, grade correction/new head, configuration
  change, SIS display change, enrollment/placement correction, and assignment drift
  each exercise the documented stale/authority behavior;
- stale draft batch review/finalize returns `40001`; cancellation/recreation succeeds;
  finalized and published bytes remain stable;
- published correction atomically leaves exactly one live published successor;
  unpublished finalized correction leaves a finalized successor; numbering increases,
  version increments, and predecessor history is byte-stable except correction fields;
- correction copies only active comments whose null-safe subject survives, preserving
  original attribution; removed-context comments are absent; every predecessor sign-off
  remains only on the predecessor, zero sign-offs are copied, and exactly one immutable
  administrator correction certification is inserted on the successor atomically.

### RBAC and RLS

- anonymous denial; cross-tenant denial; missing-permission denial; inactive membership
  and inactive role-assignment denial; organization/school/campus scope boundaries;
- view-only, manage-only, correct-only, and manage+correct combinations; correction
  requires both permissions and cannot be relationship-derived;
- non-null subject lead/co/substitute/assistant can see the header, only their exact
  subject snapshot/comment/sign-off, and only provenance beneath that snapshot; they
  cannot read attendance, overall rows, or another subject;
- null-subject lead/co homeroom teachers can read the full contextual card and all
  matching grade/attendance provenance; null-subject assistants remain header-only;
  wrong subject/section and inactive/future/expired relationships receive no contextual
  access;
- active student self and active portal guardian see only own/linked unique live
  published rows; no draft/finalized-unpublished/corrected/cancelled card,
  sibling/classmate, provenance sources, batch, reasons, audit, or outbox leakage;
- inactive student, guardian, link, portal flag, or membership immediately revokes
  access; multi-child/multi-guardian isolation is exact.

### Concurrency, cardinality, and compatibility

- genuine two-session pgTAP/dblink races for same-student create, school numbering,
  create versus source correction, batch overlap, comment replacement, sign/revoke,
  batch review versus member change, finalize versus attendance/grade correction,
  publish versus correction, and double correction;
- expected outcome is one legal head/winner and one `40001`, never duplicate number,
  branched lineage, mixed snapshot, partial batch, lost update, or deadlock;
- discovery drift of configuration set, grade head/generation/source, attendance head/
  mark, enrollment/placement, display parent, assignment/member, batch items, and card
  head normalizes to `40001`;
- exact audit/outbox names, allow-listed keys, redacted comment audit, forbidden
  privacy keys, shared command IDs, and formula cardinalities for zero/one/many grade
  and attendance sources and batch sizes;
- injected child/audit/outbox failure rolls back every domain effect;
- parent close/archive/update/correction commands preserve all pre-v1.0 behavior plus
  new blockers, do not rewrite card history, and do not introduce cross-module
  deadlocks;
- all existing pgTAP suites remain regression gates at implementation time.

## Documentation and generated artifacts

Implementation must add `docs/modules/report-cards.md`; update
`docs/architecture/security.md` and `docs/architecture/system-overview.md`; and add
compatibility notes to academics, SIS, enrollments, teaching assignments, attendance,
assessments, and term-grades module docs. Document the public boundary, lifecycle,
portal read model, role rules, snapshot semantics, staleness, correction,
numbering, locking, retry, event privacy, and explicit exclusions.

Regenerate the checked-in public database types after migration/test completion and
make the browser client and report-cards module compile against them. Do not expose
private `app_auth` functions in the generated public contract.

## Explicit exclusions

Transcripts, credits, GPA, rank, promotion, graduation, PDF generation, templates or
layout, image signatures, notifications, delivery tracking, translations, bulk
import, UI, deployment, linked-project/production changes, and general batch job
infrastructure are outside v1.0. Batch creation here is a bounded synchronous review
envelope, not a background-job system.

## Definition of done for a future implementation turn

- Independent product, architecture, security, database, and privacy review approves
  or explicitly changes every decision below.
- Additive migration 011 implements only the approved design; migrations 001–010 are
  unchanged and all prior public signatures remain compatible.
- Schema, constraints, exact composite FKs, indexes, grants, forced RLS, permissions,
  typed commands, immutability triggers, compatibility wrappers, comments, audit, and
  outbox behavior are all in the migration.
- The dedicated module exports strict Zod/TypeScript contracts and generated types are
  regenerated rather than edited.
- Focused adversarial and genuine concurrency pgTAP tests pass, followed by the full
  existing database suite, strict TypeScript typecheck, production build, generated
  type consistency, and whitespace checks.
- No deployment, production mutation, UI, staging, commit, push, merge, or pull
  request occurs without a separate instruction.

## Approved product decisions

Independent review approved every decision below as the binding v1.0 contract on
2026-09-07. Any change requires a separately reviewed additive correction.

1. **Period basis:** term-based only in v1.0; no semester/custom-range cards.
2. **Creation grade prerequisite:** derive required null-safe context keys from active
   section/term configurations, then require exactly one live finalized term-grade set
   per context; allow that set to retain and snapshot its actual older immutable
   configuration version.
3. **Source publication:** do not require term grades to be published before
   snapshotting; finalization is the stability boundary.
4. **Attendance fields:** include present, absent, late, excused, and total-session
   counts, with exact sum equality.
5. **Attendance correction:** make drafts stale and require cancellation/recreation;
   never mutate finalized/published cards.
6. **Attendance range:** use the academic term's exact inclusive date range, with
   student section/enrollment eligibility also enforced.
7. **Comment shape:** allow one optional overall comment and one optional comment per
   snapshotted subject.
8. **Comment authors:** exact lead/co/substitute subject teachers may write subject
   comments; only null-subject lead/co teachers may write overall comments; scoped
   managers may write either; assistants remain read-only.
9. **Finalization authority:** administrators with scoped `report_cards.manage` only;
   teachers sign their subject portions but do not finalize the whole card.
10. **Order:** require `draft -> finalized -> published`; never publish a draft.
11. **Unpublication:** publication is one-way; correction is the only issued-card
    replacement path.
12. **Correction permission:** require both scoped `report_cards.manage` and
    `report_cards.correct`; teaching relationships never confer correction.
13. **Successor publication:** inherit state—published predecessor gets an atomically
    published successor; finalized-unpublished predecessor gets a finalized successor;
    in both cases a new administrator correction certification is the authorization.
14. **Empty attendance:** valid and represented by explicit zero counts and an empty
    provenance set.
15. **Missing grades:** block the whole card; never issue partial subject coverage.
16. **Provenance:** persist complete grade configuration/set/record/calculation/source/
    scale/band IDs and attendance session/roster/mark IDs plus copied values.
17. **Display identity:** snapshot the minimal stable rendering fields; resolve any
    additional sensitive demographics later through authorized SIS reads.
18. **Signatures:** attribution rows only; exclude signature images/files in v1.0 and
    include an explicit administrator correction-certification attribution type.
19. **Number/version:** immutable school-scoped monotonically allocated report-card
    number per version plus immutable lineage UUID and contiguous version integer.
20. **Generation mode:** support individual creation and synchronous reviewed batches
    of 1–500; batch review is optional and does not replace per-card lifecycle.
21. **Draft refresh:** do not mutate snapshot children; cancel and recreate stale
    drafts.
22. **Comments requiredness:** comments are optional; subject, homeroom when
    applicable, and administrator-review sign-offs—not prose—gate ordinary draft
    finalization; correction successors use correction certification instead.
23. **Partial-term placement:** permit one unambiguous target-section placement that
    intersects the term; reject multiple target placement records as ambiguous.
24. **Batch atomicity:** all students succeed or the whole batch rolls back; no partial
    batch generation in v1.0.
25. **Portal read model:** allow base-table reads only for live published header,
    snapshots, comments, and sign-offs under forced RLS; provenance-source and batch
    tables remain staff-only. A narrower presentation projection is deferred.
26. **Service role:** do not grant service role ordinary report-card command execution;
    use authenticated actor-bearing workflows only unless a separately reviewed
    backend use case is approved.
27. **Teacher read breadth:** non-null subject assignments get header plus exact-subject
    snapshot/comment/sign-off and matching grade provenance only; null-subject
    lead/co homeroom teachers and scoped administrators get the broader card access
    documented in the RLS matrix.
28. **Correction sign-offs:** preserve all predecessor sign-offs only on the
    predecessor and copy none to the successor; insert exactly one immutable
    administrator correction certification atomically.
29. **Correction comments:** copy active overall comments and active subject comments
    whose subject still exists on the successor, preserving original attribution; do
    not copy comments for removed subjects.

Approval is complete; implementation must remain additive and conform to these
decisions.
