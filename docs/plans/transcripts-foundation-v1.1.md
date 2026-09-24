# Transcripts Foundation v1.1 plan

## Status and review gate

Status: proposed for independent product, architecture, security, database, and
privacy review. This document plans additive migration
`202608190012_transcripts_foundation_v1_1.sql` and a dedicated `transcripts` domain
module. It does not authorize implementation. Migrations 001–011 remain immutable.

The plan is based on the checked-in migrations, pgTAP suites, generated public
database types, domain documentation, and architecture/security rules through
Report Cards v1.0. In particular, it preserves these established contracts:

- tenant scope is derived from authoritative rows and enforced by scoped RBAC plus
  forced RLS;
- authenticated clients have SELECT-only table grants and mutate through typed
  `SECURITY DEFINER` RPCs with `search_path = ''`;
- enrollment, attendance, assessment, term-grade, and report-card history is
  append-preserving;
- a published report card is the deliberate family-visible term record and already
  contains immutable grade and attendance snapshots with full provenance;
- corrections append successors rather than rewriting finalized academic facts;
- important commands atomically correlate protected audit rows and minimal outbox
  events with one server-generated `command_id`; and
- SQLSTATE `40001` alone means that a client may retry the complete command with
  bounded backoff.

Implementation must stop for an independent review of this plan and every decision
in the final section.

## Scope and product contract

One transcript lineage is a permanent record for exactly one student and one issuing
school. It is not owned by an academic year. Every transcript version is a frozen,
ordered snapshot of explicitly selected eligible academic terms and their subject
grades. It may span multiple academic years and campuses within the issuing school.

Only live published report cards may contribute. A report card is live when its
status is `published`, it is the unique live head of its report-card lineage, and it
has not been corrected or cancelled. Transcript construction copies subject-grade
snapshots from those cards; it never recalculates grades from assessments or term
grades and never copies comments, sign-offs, attendance, or grade-calculation source
rows. This makes report-card publication the sole academic-release boundary.

Administrators explicitly select academic terms. Selection is all-or-nothing by
term: each selected term must resolve to exactly one eligible live published report
card for the student and issuing school. The selected terms must be unique, ordered
chronologically, and complete for the selected range: no earlier eligible term
between the first and last selected term in an included academic year may be silently
omitted. An administrator may explicitly exclude such a term, or an individual
subject, only with a trimmed 1–500 character reason. Exclusion is snapshot evidence,
not deletion.

The foundation supports optional credit and GPA snapshots only under an active,
versioned school policy. It does not infer policy from grade labels. Without a policy,
credit and GPA columns are null and the transcript remains valid. Policy versions are
immutable after activation. Existing `pass`/`fail` term-grade results can be mapped;
future `incomplete`, `withdrawn`, `transferred`, and `non_credit` transcript results
are modeled but cannot be synthesized by v1.1 commands without an eligible source or
explicit policy rule.

Drafts may be reviewed and issued. Issuance is one-way. A stale issued transcript
remains a valid immutable historical record; staleness is derived when any source
report card is no longer the live published head. Rebuilding creates a draft successor
and does not disturb the current issued version. Issuing the rebuilt successor marks
the old version `superseded`. An explicit correction instead atomically appends and
issues a successor and marks the predecessor `corrected`. No command unissues or
rewrites an issued version.

Out of scope: promotion, retention, graduation, rank, honors, class position,
automatic next-year enrollment, external/transfer equivalency records, PDF or other
rendering, templates, seals, signatures/images, QR verification, notifications,
delivery tracking, translations, UI, bulk import, and production deployment.

## Migration 012 schema

### Enums and input composites

Create exactly these public types:

```sql
public.transcript_status =
  ('draft','reviewed','issued','superseded','corrected','cancelled')
public.transcript_result_state =
  ('pass','fail','incomplete','withdrawn','transferred','non_credit')
public.transcript_exclusion_type = ('term','subject')
public.transcript_policy_status = ('draft','active','retired')
public.transcript_term_input = (academic_term_id uuid)
public.transcript_exclusion_input =
  (academic_term_id uuid, subject_id uuid, reason text)
public.transcript_gpa_band_input =
  (sequence integer, lower_bound numeric, upper_bound numeric,
   result_state public.transcript_result_state, grade_points numeric)
public.transcript_subject_credit_input =
  (subject_id uuid, attempted_credits numeric, earned_credits numeric)
```

`subject_id is null` means a whole-term exclusion; non-null means a subject
exclusion. Inputs contain no organization, actor, student, school snapshot,
lineage/version/number, status, calculated total, audit/event, or provenance field.

### `public.transcript_calculation_policies`

Versioned school policy header. This table is configuration, not a transcript.

| Column group | Exact columns |
|---|---|
| identity/scope | `id uuid primary key default gen_random_uuid()`, `organization_id uuid not null`, `school_id uuid not null` |
| lineage/version | `policy_lineage_id uuid not null`, `version integer not null check (version >= 1)`, `supersedes_policy_id uuid` |
| configuration | `name text not null` trimmed 1–120, `status transcript_policy_status not null default 'draft'`, `gpa_scale numeric(7,4) not null check (gpa_scale > 0)`, `decimal_places smallint not null check (decimal_places between 0 and 4)`, `include_fail_in_gpa boolean not null`, `include_incomplete_in_gpa boolean not null default false`, `include_withdrawn_in_gpa boolean not null default false` |
| lifecycle | `activated_at`, `activated_by`, `retired_at`, `retired_by` |
| audit | `created_at`, `updated_at`, `created_by`, `updated_by` |

Require exact school FK `(organization_id,school_id)`, self predecessor FK
`(organization_id,supersedes_policy_id)`, `unique(organization_id,id)`,
`unique(organization_id,policy_lineage_id,version)`, one active policy per school,
one successor per predecessor, root/successor version checks, and exact lifecycle
metadata checks. Draft policy content may be replaced through its typed command;
active/retired versions are immutable. Revision appends a draft successor. Retiring
does not affect transcript versions that snapshot the policy.

Indexes: `(organization_id,school_id,status,id)`, lineage/version descending, and
partial actor indexes. Do not create a default policy in seed data.

### `public.transcript_gpa_bands`

Ordered grade-percentage mapping owned by one policy version:
`id`, `organization_id`, `school_id`, `transcript_calculation_policy_id`, `sequence`,
`lower_bound numeric(7,4)`, `upper_bound numeric(7,4)`, `result_state`,
`grade_points numeric(9,4)`, `created_at`, `created_by`.

Use an exact policy scope FK, `unique(policy_id,sequence)`, non-overlapping contiguous
half-open percentage bands covering 0 through 100, distinct bounds, and grade points
between zero and the policy's `gpa_scale`. The final upper bound includes 100.
`non_credit` bands must have zero points. Activation validates dense ordering and
complete coverage. Rows become immutable with their active parent.

### `public.transcript_subject_credits`

Optional per-subject credit rule owned by one policy version:
`id`, `organization_id`, `school_id`, `transcript_calculation_policy_id`,
`subject_id`, `attempted_credits numeric(9,4)`, `earned_credits numeric(9,4)`,
`created_at`, `created_by`.

Use exact policy and subject FKs, `unique(policy_id,subject_id)`, non-negative values,
and `earned_credits <= attempted_credits`. A passing entry earns the configured
earned credits; a failing entry attempts but earns zero; incomplete and withdrawn
attempt credit only when the policy flags include them in GPA and always earn zero;
transferred is unsupported in v1.1; non-credit attempts and earns zero. Absence of a
subject rule means both credit values are null and that entry is excluded from credit
and GPA summaries. Rows become immutable with their active parent.

### `public.transcript_lineages`

Permanent aggregate identity for one student and issuing school:

| Column group | Exact columns |
|---|---|
| identity/scope | `id uuid primary key default gen_random_uuid()`, `organization_id uuid not null`, `school_id uuid not null`, `student_id uuid not null` |
| audit | `created_at timestamptz not null default now()`, `created_by uuid not null references auth.users on delete restrict` |

Require exact FKs to school and student, `unique(organization_id,id)`,
`unique(organization_id,school_id,student_id)`, and a composite unique key containing
organization, school, student, and ID for transcript FKs. A lineage cannot be updated
or deleted. The student's current SIS school/campus is not authoritative for historic
lineage ownership; eligibility comes from report-card school provenance.

### `public.transcripts`

Immutable version header and issuance record:

| Column group | Exact columns |
|---|---|
| identity/scope | `id uuid primary key default gen_random_uuid()`, `organization_id`, `school_id`, `student_id`, `transcript_lineage_id` all `uuid not null` |
| lineage | `version integer not null check (version >= 1)`, `supersedes_transcript_id uuid`, `replaces_issued_transcript_id uuid`, `status transcript_status not null default 'draft'` |
| numbering | `transcript_number bigint`, null before issue and positive when present |
| policy | `transcript_calculation_policy_id uuid`, `policy_lineage_id uuid`, `policy_version integer`, `policy_name text`, `gpa_scale numeric(7,4)`, `gpa_decimal_places smallint` |
| totals | `attempted_credits numeric(12,4)`, `earned_credits numeric(12,4)`, `cumulative_gpa numeric(12,4)`, `gpa_quality_points numeric(20,8)` |
| source | `source_fingerprint bytea not null check(octet_length(source_fingerprint)=32)`, `snapshot_taken_at timestamptz not null default now()` |
| review | `reviewed_at timestamptz`, `reviewed_by uuid`, `review_reason text` |
| issue | `issued_at timestamptz`, `issued_by uuid`, `issuance_reason text` |
| terminal | `superseded_at`, `superseded_by`, `supersession_reason`, `corrected_at`, `corrected_by`, `correction_reason`, `cancelled_at`, `cancelled_by`, `cancellation_reason` |
| identity snapshot | `school_code text`, `school_name text`, `student_number text`, `student_display_name text` all non-null and bounded to source maxima; `student_date_of_birth date` nullable |
| audit | `created_at`, `updated_at`, `created_by`, `updated_by` |

Date of birth is the only demographic field in v1.1 and is copied at issuance, not
shown to teachers, and not placed in outbox payloads. Exclude gender, nationality,
address, guardian information, photos, government identifiers, and document data.

Required FKs and constraints:

- exact lineage FK `(organization_id,school_id,student_id,transcript_lineage_id)`;
- student FK `(organization_id,student_id)` and school FK
  `(organization_id,school_id)`;
- self FKs `(organization_id,supersedes_transcript_id)` and
  `(organization_id,replaces_issued_transcript_id)`;
- nullable exact policy FK and snapshot consistency trigger; all policy snapshot
  columns are either jointly null or jointly non-null;
- `unique(organization_id,id)`, `unique(organization_id,transcript_lineage_id,version)`,
  one successor per predecessor, and one live draft/reviewed candidate per lineage;
- one current issued head per lineage, defined as status `issued`; terminal issued
  predecessors are `superseded` or `corrected`;
- root has `version=1` and both self references null. Every later version points
  `supersedes_transcript_id` to the immediately preceding lineage version and has
  `version = predecessor.version + 1`. A rebuild/correction candidate also points
  `replaces_issued_transcript_id` to the current issued head; this may differ from
  the immediate predecessor when an earlier candidate was cancelled;
- number is null for draft/reviewed/cancelled, non-null for issued/superseded/corrected;
- exact lifecycle metadata checks: draft has no review/issue/terminal metadata;
  reviewed has review only; issued has review and issue only; superseded/corrected
  retain review/issue and add their matching terminal fields; cancelled contains only
  cancellation metadata plus any earlier review metadata;
- totals are jointly null without a policy. With a policy, attempted/earned credits
  are non-negative, earned does not exceed attempted, GPA/quality points are null
  when no GPA-eligible attempted credits exist, and otherwise are non-negative with
  GPA not above `gpa_scale`.

Indexes: lineage/version descending; portal lookup
`(organization_id,student_id,status,issued_at desc,id)`; administrative school/status;
both self-reference FKs; policy FK; and partial indexes for every lifecycle actor. A trigger
allows only the exact command-owned lifecycle columns to change and rejects changes
to issued snapshot, numbering, provenance, totals, identity, or lineage fields.

### `public.transcript_period_snapshots`

One row per included report card/term:

`id`; `organization_id`, `school_id`, `student_id`, `transcript_id`,
`sequence integer >= 1`; `report_card_id`, `report_card_lineage_id`,
`report_card_version`, `report_card_number`; `academic_year_id`, `academic_term_id`,
`campus_id`, `section_id`, `grade_level_id`; snapshot strings
`academic_year_name`, `academic_term_name`, `campus_code`, `campus_name`,
`section_code`, `section_name`, `grade_level_code`, `grade_level_name`; term sequence,
start/end dates; `source_report_card_fingerprint bytea`; `created_at`, `created_by`.

Use an exact transcript scope FK and exact report-card FK proving organization,
school, student, term, section, and card. Migration 012 may add only the minimum
missing unique key to `report_cards` needed by that FK. Require
`unique(transcript_id,sequence)`, `unique(transcript_id,report_card_id)`, and
`unique(organization_id,transcript_id,academic_term_id,id)`. Period order is dense
and chronological by year start, term sequence, term start, then IDs. All display
fields must equal the locked report-card snapshots at insertion. Rows are immutable.

### `public.transcript_entry_snapshots`

One row per included subject-grade snapshot:

`id`; transcript scope IDs; `transcript_id`, `transcript_period_snapshot_id`,
`sequence integer >= 1`; `report_card_id`, `report_card_grade_snapshot_id`;
`subject_id`, `subject_code`, `subject_name`; `raw_percentage numeric(20,10)`,
`rounded_percentage numeric(7,4)`, `grade_label`, `result_state
transcript_result_state`; source IDs `term_grading_configuration_id`,
`term_grade_set_id`, `term_grade_record_id`, `term_grade_calculation_id`,
`grade_scale_id`, `grade_scale_band_id`; `source_term_grade_fingerprint bytea`;
nullable policy snapshots `attempted_credits`, `earned_credits`, `grade_points`,
`quality_points`; `created_at`, `created_by`.

The exact period FK proves transcript/card/term/student context. The exact grade
snapshot FK proves the report-card grade source. The exact subject FK proves school
scope. Require one entry per `(transcript_id,report_card_grade_snapshot_id)`, dense
subject ordering by normalized subject code/name/ID, and arithmetic constraints:
quality points equal attempted credits times grade points at policy precision; fail,
incomplete, withdrawn, and non-credit earn zero; null policy values are all null.
The row copies the report-card grade and provenance columns exactly and is immutable.
Do not copy `report_card_grade_sources`; the exact snapshot FK retains the complete
provenance chain without duplicating assessment-level sensitive detail.

### `public.transcript_exclusions`

Immutable evidence for an eligible term or subject deliberately omitted:
`id`, transcript scope IDs, `transcript_id`, `exclusion_type`, `academic_term_id`,
nullable `subject_id`, nullable `report_card_id`, nullable
`report_card_grade_snapshot_id`, `reason text` trimmed 1–500, `excluded_by uuid`,
`created_at`.

Term exclusions require null subject/grade snapshot; subject exclusions require all
subject/report-card/grade references. Exact FKs prove student, school, and term
context. Unique term and subject exclusion indexes prevent duplicates. Exclusions
are copied afresh when rebuilding; old evidence remains with the old version. Rows
are immutable and administrator-only under RLS.

### `public.transcript_number_counters`

One row per school: `organization_id`, `school_id`, `next_number bigint not null
check(next_number >= 1)`, `updated_at`; primary key `(organization_id,school_id)` and
exact school FK. No client grants or RLS policy. The issuance command upserts and
locks this row, allocates `next_number`, increments it, and never reuses a number,
including after correction. This avoids repeated `max()+1` scans while school-row
locking still coordinates first-row creation. The public display format is outside
v1.1; the stored immutable number is the canonical numeric component.

### Stable read model

Create security-invoker views with no mutation grants:

- `public.transcript_current_versions`: one row per lineage's current `issued`
  version plus `is_stale`, `stale_source_count`, first/last academic year and term,
  and totals. `is_stale` is true if any period source is no longer the live published
  report-card head or if its stored source fingerprint differs.
- `public.transcript_period_read_model`: RLS-filtered header/period rows in display
  order.
- `public.transcript_entry_read_model`: RLS-filtered header/period/entry rows in
  display order, excluding internal actor IDs and policy/source fingerprints.

Views must rely on underlying forced RLS and `security_invoker = true`; do not use a
materialized view or a security-definer view. Students and guardians receive only
the current-issued read model, never full lineage, exclusions, or provenance.

## Eligibility, completeness, summaries, and staleness

1. The actor supplies a non-empty, duplicate-free list of at most 100 term IDs.
2. Every term belongs to the issuing school through its academic year and resolves
   to exactly one live published report card for the student. Cards from another
   school, student, tenant, or a corrected/cancelled lineage member are rejected.
3. The current report-card successor replaces its corrected predecessor. A new
   transcript version always snapshots the live successor; callers cannot select an
   older corrected card.
4. Each included card must contain at least one non-null-subject grade snapshot.
   Overall/null-subject report-card grades are not transcript entries.
5. Within each selected academic year, every eligible published term between the
   earliest and latest selected term must be included or have an explicit term
   exclusion. No unpublished term is treated as eligible or silently required.
6. A subject exclusion is valid only for a subject present on that term's eligible
   card. Excluding every subject from an included term is rejected; use a term
   exclusion instead.
7. Source IDs, rows, status, fingerprints, and exclusion targets are rediscovered
   after locking. Drift aborts with `40001`.
8. Review and issue recompute the source fingerprint and completeness. A stale draft
   cannot be reviewed or issued; rebuild it from current sources.
9. Issued versions are never modified merely because a report card is corrected.
   Staleness is derived in the current-version view. The old issued version remains
   readable and valid until an authorized successor is issued.
10. Credit/GPA calculations use only snapshotted entry values and the snapshotted
    active policy version. Cumulative totals are stored on the transcript header and
    can be reproduced from its entries. No policy means no totals.
11. `pass` contributes configured attempted and earned credits and grade points;
    `fail` contributes attempted credits and zero earned; inclusion in GPA follows
    the policy. `incomplete` and `withdrawn` earn zero and are excluded unless the
    versioned policy explicitly includes them. `transferred` is rejected in v1.1
    because external equivalency is out of scope. `non_credit` contributes neither
    credits nor GPA.

The fingerprint uses deterministic `digest(string_agg(... order by ...),'sha256')`
over included live report-card IDs, versions, fingerprints, grade snapshot IDs and
values, exclusion targets/reasons, and policy/version/rules. It contains no names,
comments, dates of birth, or free-form audit data.

## Public command surface

All functions are `SECURITY DEFINER SET search_path = ''`, owned by the migration
owner, revoked from `public` and `anon`, and granted only by exact signature to
`authenticated`. Private mutation helpers are executable only by their owner.

```sql
public.create_transcript(
  student_id uuid,
  school_id uuid,
  terms public.transcript_term_input[],
  exclusions public.transcript_exclusion_input[] default '{}'
) returns uuid

public.rebuild_transcript(
  transcript_id uuid,
  terms public.transcript_term_input[],
  exclusions public.transcript_exclusion_input[] default '{}',
  rebuild_reason text
) returns uuid

public.review_transcript(transcript_id uuid, review_reason text) returns uuid
public.return_transcript_to_draft(transcript_id uuid, reason text) returns uuid
public.issue_transcript(transcript_id uuid, issuance_reason text) returns uuid
public.cancel_transcript(transcript_id uuid, cancellation_reason text) returns uuid
public.correct_transcript(
  transcript_id uuid,
  correction_reason text
) returns table(corrected_transcript_id uuid,replacement_transcript_id uuid)

public.create_transcript_calculation_policy(
  school_id uuid, name text, gpa_scale numeric, decimal_places smallint,
  include_fail_in_gpa boolean, include_incomplete_in_gpa boolean,
  include_withdrawn_in_gpa boolean,
  bands public.transcript_gpa_band_input[],
  subject_credits public.transcript_subject_credit_input[]
) returns uuid
public.update_draft_transcript_calculation_policy(
  id uuid, name text, gpa_scale numeric, decimal_places smallint,
  include_fail_in_gpa boolean, include_incomplete_in_gpa boolean,
  include_withdrawn_in_gpa boolean,
  bands public.transcript_gpa_band_input[],
  subject_credits public.transcript_subject_credit_input[]
) returns uuid
public.activate_transcript_calculation_policy(id uuid) returns uuid
public.revise_transcript_calculation_policy(
  id uuid, replacement_name text, replacement_gpa_scale numeric,
  replacement_decimal_places smallint,
  replacement_include_fail_in_gpa boolean,
  replacement_include_incomplete_in_gpa boolean,
  replacement_include_withdrawn_in_gpa boolean,
  replacement_bands public.transcript_gpa_band_input[],
  replacement_subject_credits public.transcript_subject_credit_input[]
) returns uuid
public.retire_transcript_calculation_policy(id uuid) returns uuid
```

All reason strings are trimmed and 1–500 characters. Creation uses the school's
single active policy, if any; the client cannot choose an older policy. Rebuild
requires the target be the lineage's current issued head and creates one draft
successor. `correct_transcript` accepts the reviewed successor's ID, requires its
`replaces_issued_transcript_id` to be the current issued head, and atomically marks
that issued version corrected and issues the successor. `return_transcript_to_draft`
is allowed only from `reviewed`. `cancel_transcript` is allowed only for draft or
reviewed versions.

## TypeScript and Zod surface

Add `src/modules/transcripts/index.ts` with strict schemas and inferred types:

- `transcriptTermSchema`, `transcriptExclusionSchema` and duplicate/cross-field
  refinements;
- `createTranscriptSchema`, `rebuildTranscriptSchema`, `reviewTranscriptSchema`,
  `returnTranscriptToDraftSchema`, `issueTranscriptSchema`,
  `cancelTranscriptSchema`, and `correctTranscriptSchema`;
- policy band/credit schemas plus create, update, revise, activate, and retire
  schemas. Numeric inputs must be finite, non-negative, and limited to four decimal
  places; term arrays contain 1–100 unique UUIDs; exclusion and reason bounds mirror
  SQL exactly.

Export `TranscriptCommandService`, `TranscriptPolicyCommandService`, inferred RPC
argument/result aliases from `Database["public"]["Functions"]`, RPC-name unions,
status/result/permission/event unions, and:

```ts
export type TranscriptCommandErrorCode =
  "22023" | "23503" | "23505" | "40001" | "42501" | "P0002";
export const isRetryableTranscriptCommandError =
  (error: { code?: string } | null | undefined) => error?.code === "40001";
```

Regenerate `src/platform/database/database.types.ts` only during implementation and
ensure all RPC name arrays use `satisfies readonly (keyof PublicFunctions)[]`.

## Lifecycle transitions

| Current | Command | Next/new state | Authority and conditions |
|---|---|---|---|
| none | create | draft v1 | `transcripts.manage`; eligible complete sources |
| issued head | rebuild | old remains issued; draft v+1 | `transcripts.manage`; stale or deliberate reissue; bounded reason |
| draft | review | reviewed | `transcripts.manage`; sources/policy still current and complete |
| reviewed | return to draft | draft | `transcripts.manage`; bounded reason; review metadata cleared only by command |
| reviewed | issue | issued | `transcripts.manage`; reviewed by a different active authorized user; sources current |
| issued predecessor + reviewed successor | issue | predecessor superseded; successor issued | one transaction; new school number |
| draft/reviewed | cancel | cancelled | `transcripts.manage`; bounded reason |
| reviewed successor of issued head | correct | predecessor corrected; successor issued | both `transcripts.manage` and `transcripts.correct`; bounded reason; issuer differs from recorded reviewer |
| issued | source changes | issued, derived stale | no write to transcript; history remains valid |
| superseded/corrected/cancelled | any | forbidden | terminal |

Reviewer and issuer must be different users. The correction command records the
correcting administrator as issuer and requires a different active authorized
reviewer recorded by the prior review command; therefore correction is implemented
as `rebuild -> review -> correct`, not a single-user shortcut.

## RBAC, grants, and RLS

Seed permissions `transcripts.view`, `transcripts.manage`, and
`transcripts.correct`. Management implies administrative reads; correction requires
both manage and correct. Policy commands require `transcripts.manage` at school
scope. No teacher contextual mutation exists.

| Actor | Headers/current view | Periods/entries | Full lineage, exclusions, policy | Commands |
|---|---|---|---|---|
| scoped administrator with `transcripts.view` | all in scope | all in scope | lineage yes; exclusions/protected policy details no | none |
| scoped administrator with `transcripts.manage` | all in scope | all in scope | yes | create/rebuild/review/issue/cancel/policy |
| scoped administrator with manage + correct | all in scope | all in scope | yes | all, including correction |
| teacher/assistant/substitute | none through assignment alone | none | none | none |
| active student linked by `students.user_id` | own current issued only | own current issued only | none | none |
| active guardian with active link and `has_portal_access` | linked student's current issued only | same | none | none |
| inactive/former student | none | none | none | none |
| inactive/historical guardian link | none | none | none | none |
| authenticated without relationship/permission | none | none | none | none |
| unauthenticated | none | none | none | none |

Every tenant table enables and forces RLS in its creation migration. Create SELECT
policies only; grant authenticated users SELECT only on deliberately readable base
tables/views. Do not grant base-table INSERT/UPDATE/DELETE. Counter tables, protected
audit/outbox, and private helpers have no browser access. Portal predicates require
the transcript status to be exactly `issued`; superseded/corrected versions remain
available only to authorized administrators. Active student means student status
`active`; guardian access additionally requires guardian status active, active
student-guardian link, portal flag, and the linked student active. Current
organization-membership state is irrelevant to student/guardian portal identity but
mandatory for administrative RBAC.

## Parent lifecycle compatibility

| Parent/domain action | Draft/reviewed transcript | Issued transcript |
|---|---|---|
| report-card correction | permitted; transcript becomes stale and cannot review/issue | permitted; issued version remains immutable and derives stale |
| report-card cancellation/unpublish | no such operation exists for published cards | unchanged; preserve prohibition |
| term-grade/assessment/attendance correction | permitted; affects transcript only after a new published report-card successor | no direct effect |
| student SIS name/number/DOB change | permitted; new version snapshots current values at issuance | existing identity snapshot unchanged |
| student archive/inactivation | permitted only under existing SIS rules | record remains administrator-readable; self-service ends |
| guardian/link inactivation | permitted | historical guardian self-service ends immediately |
| enrollment/placement end or correction | permitted; report-card provenance remains authoritative | snapshot unchanged |
| subject/section/term/year/school rename | permitted only where existing commands permit; draft issue revalidates snapshot | issued snapshot unchanged |
| subject/section/term/year/school archive | existing report-card restrictive FKs and lifecycle guards remain; add no transcript-specific destructive bypass | restrictive FKs preserve source history |
| active policy revision/retirement | draft/reviewed becomes stale and must rebuild under the active successor or no policy | issued policy snapshot unchanged |

Active drafts do not lock or block correct append-only parent changes. Parent
commands must not import transcript-private persistence. Transcript readiness detects
changed public source contracts under lock. Issued transcripts add no new ability to
edit historical report cards or term grades and no promotion/graduation semantics.

## Locking and concurrency

All transcript and affected parent commands follow this global order, skipping
levels they do not use:

```text
organization
-> sorted schools
-> sorted students
-> sorted academic years
-> sorted academic terms
-> sorted sections
-> sorted report-card lineages
-> sorted report-card heads
-> transcript lineage
-> sorted transcript versions
-> policy lineage/version
-> school number-counter row
-> sorted transcript child rows
```

Never lock report cards before their academic parents, never lock the number counter
before the transcript lineage, and never rely on caller array order. Discovery occurs
before locks only to identify candidates; after acquiring locks, re-read the complete
source set, live heads, active policy, exclusions, and lineage state. If any set or
fingerprint differs, raise `40001` with a stable retry message. Unique violations for
live drafts, lineage versions, successors, or issued heads that indicate a concurrent
winner are normalized to `40001`; invalid input, authorization failures, ordinary FK
errors, and policy validation errors retain their non-retryable SQLSTATE.

Issuance holds the lineage/version locks before the counter. It allocates the number,
transitions the predecessor if any, and transitions the reviewed successor in one
transaction. A rollback restores the counter and all lifecycle/audit/outbox effects.

Parent report-card correction already uses deterministic aggregate locking. Migration
012 must replace only the narrow helper necessary to honor the global order if a
genuine two-session test proves an inversion; do not broadly rewrite migration 011.

## Audit, outbox, and cardinality

Every command uses one server-generated `command_id`. Protected audit snapshots may
contain full row state and bounded reasons except date of birth must be redacted as
`[REDACTED]`. Outbox payloads contain only IDs, school scope, lineage/version/number,
status, term count, and `has_policy`; never names, DOB, grade values, GPA, credits,
exclusion reasons, comments, fingerprints, or assessment provenance.

| Successful command | Audit rows | Outbox rows/events |
|---|---:|---|
| create transcript | 1 header + 1 per period + 1 per entry + 1 per exclusion | 1 `transcript.draft_created` |
| rebuild transcript | same for new version | 1 `transcript.rebuild_started` |
| review | 1 header | 1 `transcript.reviewed` |
| return to draft | 1 header | 1 `transcript.returned_to_draft` |
| issue root | 1 header | 1 `transcript.issued` |
| issue successor | 2 headers | 1 `transcript.superseded` + 1 `transcript.issued` |
| cancel | 1 header | 1 `transcript.cancelled` |
| correction completion | 2 headers | 1 `transcript.corrected` + 1 `transcript.issued` |
| create/update draft policy | 1 policy header + 1 per band + 1 per credit rule | 1 `transcript_policy.draft_created` or `.draft_updated` |
| activate/retire policy | 1 policy header | 1 `transcript_policy.activated` or `.retired` |
| revise policy | 1 new policy header + child rows | 1 `transcript_policy.revision_created` |

Child snapshots are audit-only facts within a transcript command and do not each
emit integration events. Policy draft update replaces draft child rows inside one
transaction; audit must preserve before/after snapshots and row cardinality for
removed and inserted children. Any failure rolls back domain, counter, audit, and
outbox writes together.

## Adversarial pgTAP plan

Add `supabase/tests/transcripts_foundation_v1_1_test.sql` and a lexically last
`supabase/tests/zz_transcripts_concurrency_v1_1_test.sql`. Cover at minimum:

### Schema, grants, and contract

- exact enum order, composite attributes, tables, columns, nullability, checks,
  composite FKs, unique/partial indexes, FK/RLS traversal indexes, comments, and
  security-invoker views;
- RLS enabled and forced on every tenant table; SELECT-only authenticated grants;
  no anon grants; no direct DML; no sequence/counter access;
- exact public RPC signatures and grants; no browser execution on private helpers;
  function owner/search path/security mode; generated-type expectations;
- policy band coverage, overlap/gap, duplicate subject, precision, and lifecycle
  immutability tests.

### Authorization and isolation

- anonymous denial for every RPC and read family;
- cross-tenant, cross-school, cross-student, and cross-campus-source denial;
- missing-permission and inactive/expired membership denial;
- manage without correct cannot correct; correct without manage cannot correct;
- teachers in all assignment roles have no transcript access by assignment alone;
- students see only their own current issued version, never drafts, history,
  exclusions, provenance, or classmates;
- guardians require active guardian, active linked student, active link, and portal
  flag; historical/inactive links and other children are isolated;
- former/inactive students lose self-service while administrators retain history.

### Eligibility, provenance, and immutability

- reject unpublished, finalized-only, corrected, cancelled, wrong-student, wrong-
  school, duplicate, and forged report-card sources;
- corrected report-card successor is selected and predecessor cannot be forced;
- incomplete selected history and unexplained gaps fail; valid bounded term/subject
  exclusions succeed and remain auditable; unbounded/blank/forged exclusions fail;
- subject grades exactly equal report-card snapshots and are never recalculated;
- attendance, comments, sign-offs, and grade-source rows are not copied;
- no policy yields null credit/GPA; active policy produces reproducible entry and
  cumulative snapshots; retired/changed policy cannot rewrite issued totals;
- pass/fail/incomplete/withdrawn/non-credit arithmetic and transferred rejection;
- attempts to update/delete immutable children, identity snapshots, source IDs,
  number, totals, lineage, or issued history fail even as table owner where the
  defense trigger is intended to apply;
- source change makes draft readiness fail with `40001` and makes issued read model
  stale without mutating issued rows;
- rebuilding stale history snapshots live corrected report cards and leaves old
  version readable; cancellation never reopens a predecessor.

### Lifecycle, audit, rollback, and numbering

- every allowed and forbidden transition in the table above;
- different reviewer/issuer enforcement and inactive reviewer revalidation;
- correction requires both permissions and preserves a linear one-successor chain;
- numbering is school-scoped, allocated only at successful issuance, immutable and
  monotonic; correction never reuses a committed number, a rolled-back attempt
  consumes no number, and different schools may use the same numeric value;
- exact audit and event names/cardinalities, common command IDs, actor attribution,
  privacy-safe payload allowlists, DOB redaction, and absence of grade/GPA/credit/
  reason/name/fingerprint data in outbox;
- induced late failures roll back transcript rows, predecessor state, number counter,
  audit, and outbox atomically.

### Genuine two-session races

Use `dblink` (or the repository's established equivalent) with barriers/lock
timeouts, not sequential approximations. Prove:

- two root creates produce one lineage/draft winner and one normalized `40001`;
- two rebuilds produce one successor draft and one `40001`;
- issue versus issue allocates one number and one current head;
- numbering for two lineages in one school is serialized without duplicates, while
  different schools do not share a counter;
- review/issue versus report-card correction never issues stale sources;
- rebuild versus report-card correction either snapshots the complete old live set
  or retries and snapshots the complete successor set, never a mixture;
- issue versus policy revision/retirement is coherent;
- correction versus correction yields one successor and one `40001`;
- issue-successor versus correction preserves one linear head and no half-transition;
- opposing multi-term requests do not deadlock because IDs are sorted.

Tests must assert final domain rows, lineage head, counter, audit/outbox cardinality,
and SQLSTATE, not merely that one connection errored.

## Documentation and implementation deliverables

Implementation, if approved, must update:

- additive migration `supabase/migrations/202608190012_transcripts_foundation_v1_1.sql`;
- the two pgTAP suites above;
- generated `src/platform/database/database.types.ts`;
- `src/modules/transcripts/index.ts` and `src/modules/README.md`;
- new `docs/modules/transcripts.md` documenting ownership, commands, read model,
  lifecycle, policy, privacy, and events;
- `docs/modules/report-cards.md` with the public consumer/staleness contract;
- `docs/modules/sis.md` with identity snapshot and portal-lifecycle behavior;
- `docs/architecture/system-overview.md` and `docs/architecture/security.md` with
  dependency, locking, RLS, and portal-read rules.

No React UI, route handler, PDF renderer, storage integration, notification worker,
or cross-module private import belongs in v1.1.

## Definition of done

- Independent reviewers approve this plan and resolve every decision below.
- Migration 012 is additive, rerunnable only through a clean reset, and migrations
  001–011 remain byte-for-byte unchanged.
- All schema, policies, grants, typed commands, composite provenance, immutability,
  deterministic locks, atomic audit/outbox effects, counter behavior, and stable read
  models match the approved plan.
- Every tenant-owned table has explicit forced RLS, operation-specific policies, and
  indexes for FKs and RLS traversals.
- Browser roles have SELECT-only intended reads and exact RPC execution; no direct
  mutation, private helper, counter, audit, or outbox access exists.
- Generated database types and strict Zod/module contracts compile without casts that
  weaken the generated RPC surface.
- All existing and new pgTAP tests pass, including genuine two-session races;
  typecheck and production build pass.
- Documentation reflects public interfaces, permissions, events, invariants,
  staleness, policy, privacy, and lock order.
- No promotion/graduation, external equivalency, rendering, delivery, or deployment
  behavior is introduced.

## Unresolved product decisions and recommended defaults

Every item below requires independent approval before migration 012 begins.

1. **Record scope:** permanent student-plus-issuing-school lineage, not one lineage
   per academic year. **Recommended: approve.**
2. **Eligible source:** only live published report cards. Finalized term grades alone
   are insufficient. **Recommended: approve.**
3. **Completeness:** require every eligible published term between the first and last
   selected term within each included year, unless explicitly excluded. Do not require
   unpublished history. **Recommended: approve.**
4. **Selection:** administrators explicitly select terms; the system validates gaps
   rather than silently including all history. **Recommended: approve.**
5. **Corrected source choice:** new versions always use the live corrected report-card
   successor. **Recommended: approve.**
6. **Grade derivation:** copy report-card subject-grade snapshots; never recalculate
   from term grades or assessments. **Recommended: approve.**
7. **Attendance:** exclude attendance summaries from transcript v1.1. They remain on
   report cards and can be added later by explicit policy. **Recommended: approve.**
8. **Narrative/sign-offs:** exclude comments and teacher/administrator sign-offs.
   **Recommended: approve.**
9. **Credits:** optional per subject and policy version; never infer them. Missing
   configuration yields null, not zero. **Recommended: approve.**
10. **GPA:** prohibit GPA unless an active versioned policy defines bands, precision,
    inclusion rules, and subject credits. **Recommended: approve.**
11. **Stored summaries:** snapshot attempted credits, earned credits, quality points,
    and cumulative GPA with entry-level reproducibility. **Recommended: approve.**
12. **Special results:** pass/fail follow policy; incomplete/withdrawn default to no
    earned credit and GPA exclusion; non-credit contributes neither; transferred is
    rejected until external equivalency exists. **Recommended: approve.**
13. **Exclusions:** permit term or subject exclusions only with a 1–500 character
    reason and immutable actor/target evidence. **Recommended: approve.**
14. **Review/issue separation:** require a reviewer distinct from issuer. Correction
    uses rebuild, independent review, then correction issuance. **Recommended:
    approve**, despite the extra workflow step, because transcripts are high-value
    records.
15. **Issuance direction:** one-way; use supersession/correction, never unissue.
    **Recommended: approve.**
16. **Correction authority:** require both `transcripts.manage` and
    `transcripts.correct`. **Recommended: approve.**
17. **Administrative history:** administrators with manage see complete lineage;
    ordinary view permission sees scoped versions but not protected exclusions/policy
    internals. **Recommended: approve.**
18. **Student access:** active students see only their own current issued version.
    Former/inactive students do not retain v1.1 self-service. **Recommended: approve**
    pending a later alumni identity/recovery design.
19. **Guardian access:** only active guardians with an active portal-enabled link to
    an active student see the current issued version; historical access ends
    immediately with the relationship. **Recommended: approve.**
20. **Numbering:** immutable school-scoped numeric sequence, allocated only on issue,
    never reused; formatting is deferred. **Recommended: approve.**
21. **Identity snapshot:** school code/name and student number/name on construction;
    date of birth copied at issuance for identity matching, protected from teachers
    and events. **Recommended: approve**, subject to privacy review of DOB.
22. **External records:** exclude transfer-origin/external records until a dedicated
    import/equivalency module exists. **Recommended: approve.**
23. **Staleness:** source correction makes an issued version derived-stale but does
    not invalidate or mutate it. **Recommended: approve.**
24. **Rebuild:** rebuilding creates a draft successor; the old issued version remains
    current until the successor is issued, then becomes superseded. **Recommended:
    approve.**
25. **Draft versus parents:** drafts do not block append-only parent corrections;
    changed sources make review/issue retry or fail readiness. **Recommended:
    approve.**
26. **Issued versus parents:** issued versions do not block append-only correction and
    already-restricted parent history cannot be destructively removed. **Recommended:
    approve.**
27. **Reasons:** trimmed 1–500 character free text is sufficient initially for review,
    issue, rebuild, correction, cancellation, and exclusion; reason-code catalogs are
    deferred. **Recommended: approve.**
28. **Events/privacy:** emit only lifecycle-level transcript/policy events with IDs
    and counts; keep grade, credit, GPA, DOB, names, reasons, exclusions, and source
    detail audit-only. **Recommended: approve.**
29. **Read model:** expose security-invoker relational views, not JSON documents or a
    rendering-specific schema. **Recommended: approve.**
30. **Policy ownership:** one active versioned calculation policy per school, with no
    seeded default. **Recommended: approve.**

Stop here for independent plan review. Do not implement migration 012 until all 30
decisions are explicitly approved or amended.
