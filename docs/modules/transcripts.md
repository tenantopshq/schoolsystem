# Transcripts

The transcripts module owns one permanent lineage per student and issuing school,
immutable transcript versions, school-scoped issue numbering, optional versioned
credit/GPA policy, and stable relational read models for later renderers.

Only the live `published` report-card head is eligible. Creation copies subject-grade
snapshots and exact report-card provenance; it never recalculates grades. Attendance,
comments, sign-offs, and assessment-level provenance are not copied. Selected terms
must be complete across each selected academic-year interval unless an administrator
records a bounded term or subject exclusion.

## Lifecycle

`draft -> reviewed -> issued` is the normal path. Reviewer and issuer must be
different active administrators. Draft or reviewed versions may be cancelled. A
rebuild appends a draft while the prior issue remains current. Issuing a successor
marks the predecessor `superseded`; correction requires manage plus correct and marks
it `corrected`. Issued history is immutable. Report-card correction derives
`is_stale`; it never rewrites a transcript.

## Authorization and privacy

Permissions are `transcripts.view`, `transcripts.manage`, and
`transcripts.correct`. Teaching assignments confer no access. Active students and
active portal-enabled guardians see only their current `issued` version. Every tenant
table forces RLS and browser roles receive SELECT-only table grants.

Issue-time identity includes school code/name, student number/name, and date of
birth. DOB is absent from read models, stored as `[REDACTED]` in protected audit
snapshots, and excluded from outbox payloads. Outbox payloads never contain names,
DOB, grades, GPA, credits, exclusions, reasons, or fingerprints.

## Calculation policy and commands

A school may have one active immutable policy version. GPA bands cover 0–100 and
subject rules explicitly define credits. Without an active policy, credit/GPA values
are null. Revision appends a draft policy successor.

Typed RPCs create/rebuild, review/return, issue/cancel/correct transcripts and manage
policy versions. Commands use the shared academic-snapshot mutex followed by
deterministic parent, source, lineage, policy, and counter locks. Discovery drift and
concurrent winners normalize to SQLSTATE `40001`. Domain, protected audit, and
minimal outbox effects commit atomically under one server-generated command ID.
