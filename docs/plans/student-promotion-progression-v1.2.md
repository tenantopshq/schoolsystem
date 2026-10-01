# Student Promotion & Progression v1.2 plan

Status: proposed for external product and architecture review; no implementation is
authorized by this document.

## Outcome

v1.2 adds the smallest production-ready decision and execution boundary for moving a
student out of one academic-year enrollment and, when applicable, into a destination
academic-year enrollment. It covers promotion, retention, graduation/completion,
transfer, and withdrawal dispositions. It does not recalculate academic results or
rewrite any report card, transcript, enrollment, or placement history.

The progression module owns the decision, approval, batch-control, execution receipt,
and correction lineage. The enrollment module continues to own enrollment and section
placement records. Progression executes enrollment effects through one narrow,
private, typed enrollment service in the same database transaction. This preserves
the modular-monolith boundary while allowing the decision, enrollment effects, audit,
and outbox records to commit or roll back together.

## Existing architecture reviewed through v1.1

- Database Foundation v0.1 supplies tenant membership, scoped RBAC, forced RLS,
  append-only audit, and transactional outbox foundations.
- SIS v0.2/v0.4 owns students and their administrative school/campus scope. Active SIS
  status is required for ordinary child-record creation. SIS administrative scope is
  not the same thing as academic enrollment scope and is not silently moved by an
  enrollment or progression command.
- Academic Foundation v0.3 owns academic years, grade levels, sections, and their
  school/campus/date/status invariants. Grade order is school-local `sequence`; there
  is no cross-school canonical next-grade mapping.
- Enrollment & Section Placement v0.5 owns effective-dated academic-year enrollment
  and homeroom-style placement history. Non-corrected enrollment ranges cannot
  overlap; one active placement is allowed per enrollment; placement must match the
  enrollment grade; active placements reserve capacity. Completion, withdrawal,
  transfer, and append-and-supersede correction already exist.
- Term Grades v0.9 owns finalized whole-set grade results, including `pass`/`fail`,
  but does not define a school promotion policy.
- Report Cards v1.0 snapshot finalized term-grade heads and attendance, preserve
  correction lineages, and publish a family-facing academic artifact. A report card
  is term-scoped, not by itself an annual promotion policy result.
- Transcripts v1.1 consume live published report-card heads into immutable issued
  versions. Transcript issuance and correction must remain independent of progression.
- Existing command conventions use narrow typed `security definer` RPCs, derive actor
  and tenant from authoritative rows, lock parents before children in deterministic
  order, expose SELECT-only tables, correlate atomic audit/outbox writes with a
  server-generated `command_id`, and reserve SQLSTATE `40001` for retryable discovery
  drift or concurrency conflicts.

## Scope

Included:

- individual promotion/progression decisions;
- controlled batches containing individually addressable decisions;
- explicit `pending`, `approved`, `executed`, `cancelled`, and `corrected` states;
- promotion, retention, graduation/completion, transfer, and withdrawal outcomes;
- advisory academic eligibility evidence;
- destination year, grade, school, campus, and optional section selection;
- atomic execution through enrollment-owned behavior;
- immutable decision facts and linear append-and-supersede correction;
- idempotent execution, deterministic locking, bounded retry semantics, audit, outbox,
  RBAC, RLS, contracts, documentation, pgTAP, and real concurrency tests.

Excluded:

- UI, admissions, scheduling, attendance changes, grading or promotion-policy engines,
  diploma generation, transcript/report-card mutation, notification delivery,
  deployment, production data mutation, and automatic SIS administrative-scope moves.

## Numbered product decisions and recommended defaults

1. **Eligibility authority.** Recommended default: eligibility is advisory in v1.2.
   Approval and execution require a recorded evidence evaluation, but a final
   grade/report card does not mechanically choose or block an outcome. A scoped
   approver may approve an exception with a mandatory reason. This avoids inventing a
   school promotion policy from term-scoped `pass`/`fail` data. Enforcement can be
   added later through a versioned policy module without changing decision history.

2. **Evidence source.** Recommended default: evaluate the live finalized report-card
   heads for all terms in the source academic year; published is not required. Store
   references and fingerprints, not copied grades or comments. If the year has no
   complete final-card set, record `incomplete`; if all referenced grade snapshots are
   `pass`, record `eligible`; any `fail` records `not_eligible`. The calculation is an
   advisory summary only and is revalidated for staleness at approval and execution.

3. **Eligibility exceptions.** Recommended default: `not_eligible`, `incomplete`, or
   stale evidence may be approved only with nonempty `eligibility_override_reason`.
   The permission remains `progression.approve`; do not introduce a broad bypass
   permission until a demonstrated policy need exists.

4. **Destination academic year.** Recommended default: the caller explicitly selects
   a destination year for promotion, retention, and transfer. It must be active or
   draft, belong to the selected destination school, start after the source year, and
   not overlap the source enrollment range. Do not infer “next” from names or current
   flags.

5. **Destination grade.** Recommended default: the caller explicitly selects it.
   Promotion requires a higher school-local sequence than the source grade; retention
   requires the same grade when school is unchanged. Cross-school transfer does not
   compare sequences because grade catalogs are school-local. No automatic `sequence
   + 1` rule is safe across schools.

6. **Destination school and campus.** Recommended default: ordinary promotion and
   retention remain in the source school; campus may be selected within that school.
   A changed school uses disposition `transfer` and requires authority over both
   source and destination scopes. Progression does not mutate the student's SIS
   administrative school/campus.

7. **Destination section.** Recommended default: section placement is optional at
   decision creation, approval, and execution. Execution may create the destination
   enrollment without a placement. If supplied, the section must exactly match the
   destination organization/school/campus/year/grade, be active, cover the enrollment
   start date, and have capacity under the existing placement rules. A later v0.5
   placement command can place the student.

8. **Effective dates.** Recommended default: source completion/withdrawal date and
   destination enrollment date are explicit. Promotion/retention default in clients
   to source year end and destination year start, but the database never invents
   dates. Source end must fall within the source enrollment, destination start within
   the destination year, and destination start must be after source end.

9. **Graduation.** Recommended default: graduation is a progression disposition that
   completes the source placement/enrollment and creates no destination enrollment or
   placement. It records completion/graduation semantics on the decision only; it does
   not archive the SIS student, issue a diploma, or modify a transcript.

10. **Withdrawal and transfer.** Recommended default: withdrawal ends the source
    placement/enrollment with no destination. Transfer ends the source and creates a
    destination enrollment, optionally in another school and optionally with a
    placement. It is not the same as the v0.5 within-enrollment section transfer.

11. **Approval separation.** Recommended default: the creator may not approve their
    own decision, and the approver may not execute it. Execution therefore has a
    two-person minimum and normally a three-actor path. Correction approval/execution
    follows the same separation. This is stricter than earlier modules because a
    progression command changes two academic-year records at once.

12. **Lifecycle.** Recommended default: `pending -> approved -> executed`;
    `pending|approved -> cancelled`; `executed -> corrected` only as part of successful
    execution of an approved successor correction. `cancelled` and `corrected` are
    terminal. No return-to-pending, unapproval, unexecution, or reactivation exists.

13. **Duplicate decisions.** Recommended default: allow exactly one unresolved
    lineage per source enrollment. The sole exception inside that lineage is an
    executed predecessor plus its one pending/approved correction successor. A
    cancelled root releases the slot; an executed root retains it through correction.
    Partial indexes plus a deferred cross-row constraint trigger are final guards;
    commands return the existing ID only when the same idempotency key and request
    fingerprint are replayed.

14. **Conflicts.** Recommended default: a different concurrent decision for the same
    source enrollment is rejected, even when its proposed outcome matches. Conflicting
    destination enrollment, date overlap, destination capacity, or source lifecycle
    state is also rejected; commands never silently merge or replace records.

15. **Batch semantics.** Recommended default: batches are controlled envelopes, not a
    single all-or-nothing transaction across all students. Creation/approval validates
    every item atomically. Execution occurs one item per transaction through an
    idempotent item command, so a failure leaves that item retryable and preserves
    already executed items. A failed attempt is operational history, not a child
    lifecycle state: the decision remains approved and retryable. The stored batch
    becomes `completed` exactly when every child decision is terminal (`executed` or
    `cancelled`). Its derived outcome is `completed_successfully` when every child
    executed, otherwise `completed_with_exceptions` when at least one child was
    cancelled and every remaining child executed. This bounds locks and avoids one
    student blocking an entire cohort.

16. **Batch cancellation.** Recommended default: cancellation is a child operation,
    not a separate stored batch terminal state. Individual pending/approved decisions
    may be cancelled. The batch cancellation command atomically cancels every remaining
    pending/approved child, even when other children already executed, and never alters
    executed children. After any individual or batch cancellation/execution, the same
    helper marks the parent `completed` if and only if all children are terminal. Batch
    parent state never overrides child lifecycle.

17. **Correction after execution.** Recommended default: correction is forward-only.
    `create_progression_correction` appends a pending successor carrying corrected
    facts and a mandatory reason. After independent approval, executing it uses the
    enrollment module's correction operations to mark erroneous enrollment/placement
    episodes corrected and append required replacements. Only that successful atomic
    transaction marks the predecessor decision `corrected` and successor `executed`.

18. **Correction before execution.** Recommended default: do not use correction
    lineage for pending or approved mistakes; cancel and create a new root decision.
    This keeps correction semantics reserved for historical effects that actually
    occurred.

19. **Idempotency.** Recommended default: every mutating progression RPC requires a
    caller-generated UUID `request_id`. A private receipt table uniquely keys
    `(organization_id, actor_user_id, command_name, request_id)`, stores a canonical
    argument hash and completed result IDs, and rejects reuse with different arguments.
    In-progress collision raises `40001`; exact completed replay returns the original
    result without a second audit/event/effect.

20. **Visibility.** Recommended default: staff need scoped `progression.view`.
    Students and active portal-enabled guardians may see only the current student's
    executed live decision through a narrow safe view; they cannot see pending,
    approved, cancelled, corrected predecessors, evidence internals, staff IDs,
    reasons, overrides, audit, batch metadata, or source fingerprints.

21. **Privacy.** Recommended default: audit may contain decision IDs, scope IDs,
    lifecycle transitions, dates, disposition, reasons, and enrollment/placement IDs,
    but no names, student numbers, grades, comments, guardian data, or report-card
    display snapshots. Outbox payloads are smaller: IDs, disposition/status, effective
    dates, source/destination scope IDs, and changed-field names; exclude all free-text
    reasons, eligibility state/evidence/fingerprints, and PII.

22. **Parent lifecycle.** Recommended default: pending decisions do not block parent
    changes; approval and execution require all authoritative parents to be non-
    archived and compatible, and execution revalidates them. Approved decisions block
    archive/close changes that would invalidate their source/destination context.
    Executed/corrected history never blocks lifecycle changes and remains readable.

## Domain model and proposed migration

Proposed migration: `supabase/migrations/202608190013_student_promotion_progression_v1_2.sql`.
It is inventory only; this plan does not create it.

### Enums and composites

- `progression_disposition`: `promotion`, `retention`, `graduation`, `transfer`,
  `withdrawal`.
- `progression_decision_status`: `pending`, `approved`, `executed`, `cancelled`,
  `corrected`.
- `progression_eligibility_state`: `eligible`, `not_eligible`, `incomplete`, `stale`.
- `progression_batch_status`: `draft`, `approved`, `completed`. There is no stored
  failed or cancelled batch state; child lifecycle determines the terminal outcome.
- `progression_batch_decision_input`: explicit student/source enrollment,
  disposition, dates, destination IDs, optional section, and nullable override reason.
  Cap input arrays at 500 and reject duplicate source enrollments.
- typed result composites for create correction, execute decision, create batch, and
  execute batch item; return IDs only.

### `progression_decisions`

Aggregate root and immutable decision facts:

- identity/scope: `id`, `organization_id`, `student_id`, source `school_id`, nullable
  source `campus_id`, `source_academic_year_id`, `source_grade_level_id`,
  `source_enrollment_id`, nullable `source_placement_id`;
- proposed outcome: `disposition`, `source_end_on`, nullable destination
  `school_id`, `campus_id`, `academic_year_id`, `grade_level_id`, `section_id`, and
  `destination_enrolled_on`;
- execution provenance: nullable `result_source_enrollment_id`,
  `result_source_placement_id`, `destination_enrollment_id`, and
  `destination_placement_id`;
- lineage: `lineage_id`, `version >= 1`, nullable `supersedes_decision_id`, mandatory
  `correction_reason` only on a successor;
- lifecycle: status plus exact actor/time columns for approval, execution,
  cancellation, correction, and bounded reasons where applicable;
- advisory eligibility: `current_eligibility_evaluation_id` and nullable bounded
  override reason; evaluation facts themselves are append-only children;
- optional `batch_id`; created/updated metadata.

Use complete composite FKs to prove organization, student, source enrollment/placement,
academic years, grade levels, optional destination section, predecessor, and optional
batch context. Cross-row deferred triggers enforce a single linear lineage, version
increment, invariant student/source lineage, and predecessor/successor consistency.

Checks encode disposition shapes:

- promotion/retention/transfer require all destination IDs except section;
- graduation/withdrawal require every destination field null;
- same-school promotion requires destination grade sequence greater than source;
- same-school retention requires equal grade;
- graduation completes source; withdrawal withdraws source; promotion, retention, and
  transfer complete source and create destination enrollment;
- source/destination dates are ordered and within locked enrollment/year ranges;
- result IDs are null before execution and exact after execution;
- lifecycle actor/time/reason columns exactly match status.

Indexes/constraints:

- `unique (organization_id,id)` and full scope keys for children;
- `unique (organization_id,lineage_id,version)`;
- one successor per predecessor;
- one unresolved lineage per source enrollment, enforced by a lineage-root partial
  unique index plus a deferred trigger that permits only the executed-predecessor /
  pending-or-approved-correction pair;
- one live lineage head (not cancelled/corrected);
- source/destination scope, student history, batch, actor, result enrollment, result
  placement, and predecessor indexes, including every FK/RLS traversal.

Decision business fields are immutable after insert. Narrow commands may update only
lifecycle and execution-result columns. A defense-in-depth trigger rejects direct or
accidental changes to immutable fields.

### `progression_eligibility_evaluations` and `progression_decision_evidence`

Each eligibility refresh appends an immutable evaluation header with `id`, decision,
dense sequence, state, evaluated time/actor, and 32-byte fingerprint. The decision's
`current_eligibility_evaluation_id` advances only while pending. Old evaluations are
retained.

Relational advisory evidence contains one row per selected source report card per
evaluation:

- `id`, `organization_id`, `progression_decision_id`, `eligibility_evaluation_id`,
  `student_id`,
  `academic_year_id`, `academic_term_id`, `report_card_id`, `report_card_lineage_id`,
  `report_card_version`, `source_fingerprint`, and creation metadata;
- exact composite FK proves report-card scope/student/year/term;
- unique `(eligibility_evaluation_id,academic_term_id)` and
  `(eligibility_evaluation_id,report_card_id)`;
- immutable, no update/delete path, indexed for report-card and decision traversal.

This table stores references and fingerprints only. It does not copy grades, grade
labels, comments, attendance, identity display fields, or report-card numbers.

### `progression_batches` and `progression_batch_items`

`progression_batches` stores `id`, organization/source school/source academic year,
status, approval/completion metadata, and audit metadata. The only transitions are
`draft -> approved -> completed` and `draft -> completed` when all pending children
are cancelled before approval. `completed_at` and `completed_by_command_id` identify
the child execution/cancellation command that made the last child terminal. A deferred
constraint trigger requires `completed` if and only if every child is `executed` or
`cancelled`; no caller chooses the stored terminal outcome.

`progression_batch_items` maps a batch to a decision and student/source enrollment,
with immutable creation data and nullable operational diagnostics:
`last_attempted_at`, `attempt_count`, `last_error_code`, and a bounded sanitized
`last_error_category`. Do not store raw database messages. Decision lifecycle remains
authoritative. Unique batch/decision, batch/source-enrollment, and batch/student keys
prevent duplicates. The item execution RPC uses a PL/pgSQL exception subtransaction:
nonretryable domain failure rolls back the attempted decision effects, then records a
sanitized item failure and returns a typed failed result; `40001` is re-raised so the
entire call rolls back and can be retried safely. Diagnostics are excluded from family
reads.

### `progression_command_receipts`

Private execution support table (no authenticated table access): organization, actor,
command name, request UUID, canonical SHA-256 argument hash, status `in_progress` or
`completed`, server command ID, result entity IDs, timestamps. Unique
`(organization_id,actor_user_id,command_name,request_id)`. Receipt insertion and domain
work share one transaction, so ordinary failures leave no receipt; completed replay
is deterministic. No arbitrary JSON result is necessary.

### Read views

- `progression_decision_heads`: security-invoker staff view of live lineage heads with
  scope and status, but no evidence fingerprints.
- `student_progression_outcomes`: security-invoker portal-safe view exposing only the
  authenticated student's/linked guardian's executed live outcome: disposition,
  source/destination year/grade/school/campus IDs, effective dates, and public-safe
  labels joined under RLS. It excludes reasons, eligibility, actors, internal result
  IDs, batch, lineage internals, and fingerprints.
- `progression_batch_progress`: security-invoker scoped staff view deriving total,
  pending, approved, executed, cancelled, and retryable-failed-last-attempt counts.
  When stored status is `completed`, it derives exactly
  `completed_successfully` if `executed_count = total_count`, or
  `completed_with_exceptions` if `cancelled_count > 0` and
  `executed_count + cancelled_count = total_count`. An approved batch with a failed
  attempt remains `approved`; failure diagnostics never count as terminal children.

All base tables enable and force RLS, revoke all privileges from `public`, `anon`, and
`authenticated`, grant authenticated SELECT only where required, define no client
INSERT/UPDATE/DELETE policies, grant no sequence access, and reject hard deletes.
Evidence and command receipts have no student/guardian access.

## Permission inventory

- `progression.view`: scoped staff read of decisions, safe evidence metadata, batches,
  and progress.
- `progression.manage`: create pending individual decisions/batches and cancel pending
  decisions in scope.
- `progression.approve`: approve decisions/batches and cancel approved decisions; also
  requires view over source and destination.
- `progression.execute`: execute an approved individual or batch item.
- `progression.correct`: create and execute correction lineages; execution also
  requires `progression.execute`.
- `progression.cancel`: cancel pending/approved decisions and eligible batches. Keep it
  separate from manage so operational cancellation can be delegated narrowly.

Every command checks active organization membership plus permission at every affected
scope. Same-school/campus commands require source and destination authority when they
differ. Cross-school transfer requires organization- or school-scoped authority over
both schools; a campus-only role cannot authorize it. Execution also invokes the
enrollment service under the progression-authorized command context; it does not grant
the caller a hidden general `enrollments.manage` capability.

Suggested default role grants are deliberately conservative: organization admin all
six; school admin all six within school; campus admin view/manage/cancel and optionally
execute within campus; registrar view/manage/approve/execute/cancel; auditor view only.
No teacher, student, or guardian mutation permission is seeded. Seed mappings must
follow existing role codes actually present at implementation time rather than assume
new roles.

## Command inventory

All public RPCs are narrow `security definer` functions with empty `search_path`, exact
signature grants to `authenticated`, derived actor/tenant/scope, a required
`request_id`, no arbitrary JSON, no caller-supplied actor/status/command ID/audit/event
payload, and no caller-created entity ID.

1. `create_progression_decision(request_id, student_id, source_enrollment_id,
   disposition, source_end_on, destination_school_id, destination_campus_id,
   destination_academic_year_id, destination_grade_level_id,
   destination_section_id, destination_enrolled_on, eligibility_override_reason)`.
2. `refresh_progression_eligibility(request_id, progression_decision_id)`; pending
   only, replaces evidence by cancelling/recreating the pending decision is too heavy,
   so this command may update only the advisory state/fingerprint and append immutable
   evidence evaluation rows grouped by a new `evaluation_id`. Implementation should
   therefore add `progression_eligibility_evaluations` as a header and make evidence
   reference it; old evaluations remain immutable. The decision points to the current
   evaluation ID.
3. `approve_progression_decision(request_id, progression_decision_id,
   approval_reason)`.
4. `execute_progression_decision(request_id, progression_decision_id)`; when the
   decision belongs to a batch, successful execution also invokes the shared parent-
   completion helper.
5. `cancel_progression_decision(request_id, progression_decision_id,
   cancellation_reason)`.
6. `create_progression_correction(request_id, executed_decision_id, corrected outcome
   fields, correction_reason)` returning predecessor and pending successor IDs.
7. `create_progression_batch(request_id, source_school_id,
   source_academic_year_id, items[])` returning batch ID and decision IDs.
8. `approve_progression_batch(request_id, batch_id, approval_reason)`; locks and
   validates every decision, then approves all or none.
9. `execute_progression_batch_item(request_id, batch_id, decision_id)`; exactly one
   student transaction and the same implementation path as individual execution. On
   success it invokes the shared parent-completion helper. On nonretryable failure it
   records a sanitized retryable attempt result but leaves the child approved and the
   parent uncompleted; `40001` propagates and records nothing.
10. `cancel_progression_batch(request_id, batch_id, cancellation_reason)`; cancels all
    pending/approved children atomically, preserves executed children, and invokes the
    shared parent-completion helper. It is idempotent for an already completed batch
    only when the same request receipt is replayed.

`cancel_progression_decision` also invokes the shared parent-completion helper when
the decision belongs to a batch. Thus the parent reaches `completed` deterministically
whether its last terminal child was executed, cancelled individually, or cancelled by
the batch command.

Private module services/helpers:

- progression actor, scoped authorization, canonical hash, receipt, lock, discovery
  re-read, eligibility evaluation, lifecycle transition, audit/outbox, and batch
  completion helpers;
- enrollment-owned
  `app_auth.execute_progression_enrollment_effect(...)`, callable only by the exact
  progression execution implementation owner. It accepts resolved authoritative IDs,
  dates, disposition, actor, and command ID—not JSON—and returns source/destination
  enrollment/placement IDs. It applies the same v0.5 constraints, capacity behavior,
  append-only correction semantics, and enrollment audit/events. It is revoked from
  `public`, `anon`, `authenticated`, and `service_role`.

## Execution semantics

For promotion, retention, and transfer, one transaction:

1. locks/revalidates the approved decision and current evidence;
2. completes the active source placement, if any, and source enrollment on
   `source_end_on` using outcome-specific reasons generated from the decision ID;
3. creates the destination enrollment on `destination_enrolled_on` with scheduled end
   equal to the destination academic year end;
4. optionally creates the destination placement;
5. writes result IDs to the decision and marks it executed;
6. appends enrollment and progression audits/outbox events and completes the receipt.

Graduation completes source placement/enrollment and creates no destination.
Withdrawal withdraws them and creates no destination. No command edits a report card,
transcript, term grade, prior corrected enrollment/placement, or SIS student.

Correction execution uses enrollment correction, not destructive compensation. If the
original destination enrollment/placement was wrong, it is marked corrected and an
appropriate replacement is appended. If the corrected outcome changes whether a
destination exists, the service performs the minimum append-only correction graph and
validates that no later dependent non-corrected enrollment conflicts. If downstream
history makes an automatic correction unsafe, reject with `22023` for manual review;
never cascade or silently rewrite later history.

## Deterministic locking and retryable concurrency

Acquire locks in this global order, sorting every set by UUID (and child ordering as
shown) before `FOR UPDATE`:

1. transaction-scoped advisory lock keyed by organization progression namespace;
2. organization;
3. schools by ID;
4. campuses by ID;
5. academic years by `(school_id,id)`;
6. academic terms needed for evidence by `(academic_year_id,sequence,id)`;
7. grade levels by `(school_id,sequence,id)`;
8. sections by `(academic_year_id,campus_id,id)`;
9. students by ID;
10. source and potentially conflicting enrollments by `(student_id,enrolled_on,id)`;
11. placements by `(student_enrollment_id,starts_on,id)`;
12. report-card lineages/heads by `(student_id,academic_term_id,lineage_id,version,id)`;
13. progression batches by ID, then decisions by `(student_id,source_enrollment_id,id)`;
14. eligibility evaluations/evidence by `(decision_id,sequence,academic_term_id,id)`;
15. batch items by `(student_id,decision_id,id)`;
16. command receipt last.

The implementation must align this order with existing enrollment/report-card lock
helpers; where existing helpers take a broader lock earlier, the stricter existing
order wins and is documented in one shared comment/test fixture. Discover candidate
IDs, lock parents/children, re-run discovery, and raise `40001` if the set changed.
Unique/exclusion violations remain nonretryable unless explicitly caused by a proven
discovery drift. Client adapters retry only `40001`, with bounded exponential backoff
and the same request ID. A retry with a completed receipt returns the original result.

Concurrency cases requiring genuine independent database sessions include:

- two different decisions for one source enrollment;
- approval racing eligibility source correction;
- two executions of one decision with same and different request IDs;
- execution racing source enrollment completion/correction;
- two students competing for the final section seat;
- batch item execution racing batch cancellation;
- correction racing a new downstream enrollment;
- parent archive/close racing approval/execution;
- cross-school transfers in opposite directions (deadlock-order proof).

## Audit inventory

Progression audit actions:

- `progression.decision_created`, `.eligibility_evaluated`, `.approved`, `.executed`,
  `.cancelled`, `.correction_created`, `.corrected`;
- `progression.batch_created`, `.approved`, `.item_attempt_failed`,
  `.remaining_items_cancelled`, `.completed`.

Audit rows use the shared server command ID. Before/after data may include IDs,
disposition, lifecycle metadata, dates, scope, override/correction/cancellation reason,
result enrollment/placement IDs, and changed fields. Do not serialize report-card
rows, grades, comments, identity snapshots, student/guardian PII, raw errors, request
hashes, or receipt internals. A failed transaction cannot persist an audit row; a
sanitized failed batch-item diagnostic is an explicit successful operational command
with its own audit action and no outbox event.

## Event inventory

- `student.progression_decision_created`
- `student.progression_eligibility_evaluated`
- `student.progression_decision_approved`
- `student.progression_executed`
- `student.progression_decision_cancelled`
- `student.progression_correction_created`
- `student.progression_corrected`
- `student.progression_batch_created`
- `student.progression_batch_approved`
- `student.progression_batch_completed`

`student.progression_batch_completed` includes the derived terminal outcome
`completed_successfully` or `completed_with_exceptions` and executed/cancelled/total
counts. The cancellation event reports IDs and counts only. Failed attempts emit no
integration event because they are retryable operational diagnostics, not domain
outcomes.

Enrollment-owned execution continues to emit its existing granular events such as
`student.enrollment_completed`, `student.enrollment_withdrawn`, `student.enrolled`,
and placement completion/withdrawal/placement events. The shared command ID correlates
them with the progression event. Progression events do not duplicate full enrollment
rows. Payloads include command/aggregate/decision/student IDs, source and destination
scope IDs, disposition, status, effective dates, batch ID when applicable, result
record IDs, and changed-field names. They exclude all free text, names, student
numbers, grade facts, eligibility details, fingerprints, guardian data, and actor
display data.

## TypeScript and Zod inventory

Create `src/modules/progression/index.ts` as the public module boundary:

- strict Zod schemas for every command, UUID request IDs, ISO dates, enum values,
  1–500-character reasons, nullable destination shape, and batch size/duplicate checks;
- `superRefine` mirrors disposition-specific destination requirements but database
  constraints remain authoritative;
- RPC name tuple checked against generated `Database["public"]["Functions"]`;
- typed argument/result aliases, lifecycle/disposition/eligibility constants,
  permission and event constants;
- `ProgressionCommandService` and narrow read-service interfaces;
- `ProgressionCommandErrorCode` containing known SQLSTATEs and an
  `isRetryableProgressionCommandError` that returns true only for `40001`.

Regenerate `src/platform/database/database.types.ts` from a fully reset local database;
never hand-edit it. Update `src/modules/README.md` to register the boundary. No React,
route handler, or UI work is part of v1.2.

## Documentation inventory

- Update `docs/architecture/system-overview.md` with progression ownership and the
  atomic enrollment service boundary.
- Update `docs/architecture/security.md` with forced RLS, permissions, family-safe
  view, separation of duties, receipts, and retry behavior.
- Add `docs/modules/progression.md` with commands, lifecycle, correction, eligibility,
  batch behavior, lock order, audit/events, and exclusions.
- Update `docs/modules/enrollments.md` to document the private progression execution
  service and confirm enrollment remains the source of truth.
- Add a v1.2 verification record only during implementation, after tests/build pass.

## Test inventory

Proposed pgTAP files:

- `supabase/tests/student_promotion_progression_v1_2_test.sql` for schema, enums,
  constraints, FKs, indexes, grants, forced RLS, function ownership/search paths,
  exact signature grants, private-helper denial, lifecycle, dispositions, dates,
  eligibility, separation of duties, idempotency, execution, batch behavior,
  corrections, audit, and payload privacy;
- `supabase/tests/student_promotion_progression_v1_2_rls_test.sql` for anonymous denial,
  cross-tenant denial, missing-permission denial, inactive membership denial,
  same-tenant scoped access, source/destination scope intersection, and student/
  guardian safe-view visibility;
- `supabase/tests/zz_student_promotion_progression_concurrency_v1_2_test.sql` as a
  shell-driven or dblink/two-connection harness proving the independent-session cases
  listed above. It must assert blocking/release behavior, final rows, retryable
  `40001`, no deadlock, no duplicate effects, and capacity correctness—not merely call
  commands sequentially in one session.

Required behavioral coverage:

- every disposition with and without a source placement;
- promotion, retention, and cross-school grade mapping rules;
- optional destination placement and later placement compatibility;
- complete, failed, missing, corrected, and stale report-card evidence;
- override required and privacy protected;
- duplicate/live decision and one-successor constraints;
- approval/execution actor separation;
- cancellation restrictions and all parent lifecycle restrictions;
- partial batch execution; retryable failed attempts that leave child and parent
  nonterminal; individual cancellation after partial execution; whole-batch remaining-
  item cancellation; deterministic parent completion; and both derived terminal
  outcomes;
- correction variants, including refusal when downstream history makes repair unsafe;
- exact audit/outbox counts, shared command ID, enrollment plus progression event
  correlation, rollback on every injected failure, and exact replay behavior;
- no change to source report cards, term grades, transcripts, or pre-existing history.

Verification commands during implementation:

1. `npm run db:reset`
2. `npm run db:types`
3. `supabase test db` (or the repository's `npm run db:test` wrapper)
4. run the genuine two-session concurrency harness explicitly if not included by the
   default pgTAP runner;
5. `npm run typecheck`
6. affected unit/module tests;
7. `npm run build`
8. `git diff --check`

Verification must also compare generated types for an expected-only diff and inspect
function/table ACLs directly. A passing production build without database concurrency
and adversarial RLS tests is insufficient.

## Core invariants

1. Progression never updates or deletes report cards, transcripts, term grades, prior
   enrollment/placement facts, or SIS identity records.
2. Tenant scope is derived and proven by composite FKs; no caller-supplied organization
   or actor is trusted.
3. One source enrollment has at most one live decision and one executed effect graph.
4. Every correction is a linear successor; no branching and no in-place fact edits.
5. An executed predecessor becomes corrected only in the transaction that executes
   its approved successor and completes enrollment correction effects.
6. Source and destination enrollment ranges never overlap and all dates lie within
   their authoritative years/records.
7. Destination placement, when present, exactly matches destination enrollment grade,
   school, campus, year, date, and capacity rules.
8. Graduation/withdrawal has no destination; promotion/retention/transfer does.
9. Approval and execution revalidate evidence, scope, parent status, dates, duplicates,
   and actor separation under lock.
10. Each non-replay command has one receipt and server command ID; every domain write,
    audit, and outbox effect is atomic. Exact replay creates nothing new.
11. Batch parent state never makes an invalid child transition valid. A batch is
    completed if and only if every child is executed or cancelled; its derived outcome
    is successful only when all executed, otherwise completed with exceptions. Failed
    attempts remain visible, retryable, and nonterminal.
12. Portal users see only a live executed safe outcome for themselves/their linked
    student and no operational or academic evidence details.
13. SQLSTATE `40001` alone signals safe whole-command retry.

## Risks and mitigations

- **No formal annual promotion policy.** Advisory evidence plus mandatory override
  reason avoids encoding an accidental policy. A future versioned policy can enforce
  school-specific rules.
- **Report cards are term/section scoped.** Completeness evaluation must use locked
  year terms and exactly one live finalized card head per required term, and must mark
  ambiguity/missing data incomplete rather than guess.
- **Grade catalogs are school-local.** Explicit destination grade and no cross-school
  sequence comparison prevent false mappings.
- **Enrollment v0.5 correction may not express every executed progression repair.**
  Implementation must extend the enrollment-owned private service with narrowly tested
  append-only repair variants; it must not make progression write private enrollment
  tables ad hoc.
- **Batch error persistence versus rollback.** Use an exception subtransaction so all
  attempted domain effects roll back before a sanitized diagnostic is committed by the
  outer command. Retryable `40001` must escape and roll back everything; tests must
  prove diagnostics never coexist with partial enrollment/progression effects.
- **Large batch locks.** Cap 500 at creation/approval and execute one item per
  transaction. A later worker can paginate without changing domain semantics.
- **Parent close/archive blockers can surprise administrators.** Restrict blockers to
  approved decisions and expose them in scoped views; pending drafts do not block.
- **Idempotency privacy and retention.** Receipts store only hashes and IDs. Define a
  retention job later; do not delete receipts within v1.2 because that could weaken
  replay guarantees.
- **Cross-module deadlocks.** Reconcile and test one global order, serialize the narrow
  academic snapshot namespace where necessary, and use two-session opposite-direction
  tests.
- **Family interpretation of corrected history.** Safe view exposes only the live
  executed head. Historical corrected decisions remain staff/audit records.

## External-review questions

The recommended defaults above are implementable as one coherent foundation. External
review should explicitly accept or change decisions 1 (advisory eligibility), 7
(optional section), 11 (separation of duties), 15 (per-item batch transactions), 17
(forward-only correction), and 20 (portal visibility) before migration design begins.
Changes to those choices materially affect schema and command contracts; wording or
role-seed refinements do not.

## Stop point

This document and its numbered product decisions are the complete v1.2 planning
deliverable. No migration, module, generated type, test, documentation implementation,
Git staging, commit, push, merge, deployment, or production mutation is included.
