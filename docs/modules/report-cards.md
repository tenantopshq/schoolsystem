# Report Cards Foundation v1.0

## Boundary

Report Cards owns term-based student report-card lineages, immutable finalized-grade
and finalized-attendance snapshots, authored comments, attribution-only sign-offs,
and synchronous review batches. Rendering, templates, PDF generation, delivery,
notifications, transcripts, credits, GPA, promotion, and graduation are outside this
module.

Comment and sign-off authorship stores the actor's organization membership and, when
teacher-authored, exact staff profile and teaching-assignment provenance. Composite
foreign keys plus an exact null-safe subject/context constraint prevent an assignment,
staff profile, membership, or user from being substituted across contexts.

Required subject contexts come from active term-grading configurations. The unique
live finalized grade set in each context retains its actual immutable configuration
version; the card snapshots that version and its complete calculation provenance.
Source-grade publication is not required. Attendance uses exact inclusive term dates,
stores present/absent/late/excused/total counts, and represents no history as zeros.
The canonical SHA-256 card fingerprint also includes all approved display snapshot
values, enrollment/placement provenance, calculated grade and ordered grade-source
values, and ordered finalized attendance provenance.

## Commands, history, and access

Twelve typed RPCs create individual or bounded atomic batch drafts, append/withdraw
comments, sign/revoke draft attribution, review batches, finalize, publish, cancel,
and correct. Tables are forced-RLS and SELECT-only for clients. Commands derive actor
and scope, lock parents deterministically, and atomically append audit/outbox effects.
Report-card commands, attendance-session correction, and term-grade-set correction
first take the same organization-scoped academic-snapshot advisory lock, then follow
their documented parent-to-child row-lock order. Competing head/state changes return
retryable SQLSTATE `40001`.

Lifecycle is `draft -> finalized -> published`; publication is one-way. Correction
requires `report_cards.manage` plus `.correct`, preserves predecessor sign-offs only
on the predecessor, copies eligible comments with original attribution, copies no
sign-offs, and creates one immutable administrator correction certification on the
successor. Draft source drift returns `40001`; issued snapshots never change.

A non-null subject assignment reads the header, exact subject children, and matching
grade provenance only. A null-subject lead/co homeroom teacher reads the full card and
its provenance. Assistants are read-only; null-subject assistants see only the header.
Students and active portal guardians see only their own live published card without
provenance or batches. Ordinary finalization requires subject, applicable homeroom,
and administrator-review sign-offs; teachers cannot finalize or publish.

Existing academic, section, and SIS command signatures are preserved by additive
wrappers. Draft work blocks incompatible close/archive operations, issued cards block
scope/date destruction, and term dates remain fixed while any non-cancelled card
references them. Parent corrections remain append-only and make drafts stale rather
than rewriting snapshots.

Transcripts v1.1 consume only the live `published` head and its immutable subject
grade snapshots. Report-card correction makes an issued transcript derived-stale;
it never mutates that transcript. New transcript versions select the corrected live
successor.
