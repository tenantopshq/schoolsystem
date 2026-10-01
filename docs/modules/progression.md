# Student Promotion & Progression v1.2

## Boundary

Progression owns immutable promotion, retention, graduation, transfer, and withdrawal
decisions, their approval/execution lifecycle, advisory eligibility evidence,
controlled batches, idempotency receipts, and correction lineages. Enrollment remains
the source of truth for enrollment and section-placement history. A private,
non-browser-callable enrollment service applies progression effects atomically.

Progression never changes report cards, transcripts, term grades, SIS identity, or
previous academic artifacts. Corrections append a successor and use enrollment's
append-preserving correction behavior.

## Lifecycle and batches

Decisions follow `pending -> approved -> executed`, `pending|approved -> cancelled`,
or `executed -> corrected` when an approved correction successor executes. Creator,
approver, and executor must be different at the relevant transitions.

Batches store only `draft`, `approved`, and `completed`. Execution is one child per
transaction. A batch completes when every child is executed or cancelled. The read
model derives `completed_successfully` when all executed and
`completed_with_exceptions` when at least one was cancelled. Failed item attempts are
sanitized, retryable diagnostics and do not make a child terminal.

## Eligibility

Eligibility is advisory. Each evaluation and its report-card references are immutable.
Approval and execution reject stale evidence. Incomplete or failing evidence requires
an explicit override reason, which remains staff-only and is excluded from events.

## Security and concurrency

Scoped permissions separate view, manage, approve, execute, correct, and cancel.
Cross-school transfer checks both scopes. Base tables force RLS and expose SELECT only;
families receive only the executed safe outcome read model. Public commands accept a
request UUID, derive actor/tenant/scope, and use private receipts for exact replay.
Only SQLSTATE `40001` is retryable.

Commands lock organization, sorted schools/campuses/years/grades/sections, student,
enrollment/placement, academic evidence, decision, and batch children in deterministic
order. Section capacity is checked under the locked section. Domain effects, audit,
and outbox writes share one transaction.

## Privacy

Events contain IDs, disposition, status, dates, and scope only. They exclude names,
student numbers, grades, comments, guardian data, evidence fingerprints, free-text
reasons, and raw errors. Portal reads exclude actors, reasons, batch data, evidence,
lineage internals, and result-record IDs.
