# Term Grades & Grade Scales Foundation v0.9

Status: approved for local implementation. The 20 product decisions below are binding. Deployment and production mutation remain unauthorized.

## Purpose and boundaries

v0.9 adds a `term-grades` domain to the modular monolith. It owns school-managed percentage grade scales, section/subject/term calculation configuration, immutable calculation attempts and their source provenance, term-grade publication/finalization, and append-and-supersede correction.

The module consumes public contracts owned by academics, assessments, enrollment/placement, teaching assignments, SIS relationships, RBAC, audit, and the event outbox. It must not import another module's private persistence interface. The database command layer is the authoritative transaction boundary; TypeScript exposes narrow validated services.

Out of scope: GPA, credits, transcripts, promotion, graduation, rank, report-card rendering/comments/signatures/distribution, rubrics, standards, outcomes, moderation, curves, analytics, manual bonus points, attendance-derived grades, cross-term calculations, UI, notifications, bulk import, deployment, and production changes.

## Established baseline (migrations 001–009)

The following are facts, not new calculation decisions:

- A section belongs to one organization, school, campus, and academic year and may optionally name a term. An assessment always names a section and a non-null term; its optional subject is an exact context, where `NULL` is a real homeroom/general context rather than a wildcard.
- Assessments have `maximum_score numeric(12,4)` and optional `weight numeric(7,4)` in `(0,100]`. v0.8 expressly does not define weight sums or aggregate-grade calculation.
- Assessment results have `score numeric(12,4)`. Publication and finalization are independent. A complete unpublished finalized assessment is valid and may later be published.
- Publication/finalization require a numeric result for every assessment snapshot student. Cancelled drafts never contribute. Corrected assessments are terminal; the finalized successor is the live head and preserves the original roster. A correction successor inherits publication state.
- Assessment snapshots preserve exact student, enrollment, and section-placement provenance. Later enrollment/placement correction does not rewrite them.
- Effective lead and co-teacher relationships manage the exact section/subject assessment context. Substitutes do so only while effective. Assistants are contextual readers. Relationships never confer correction authority.
- Student self-access and active portal-guardian access are provided by `app_auth.is_student_self` and `app_auth.is_linked_guardian`; inactive students/guardians/links and lost portal access remove relationship reads.
- Commands derive `auth.uid()`, lock authoritative parents in deterministic order, use SQLSTATE `40001` for retryable discovery/head drift, and atomically correlate audit/outbox effects by server-generated `command_id`.

Therefore migration 010 must not silently treat v0.8's optional weight as an already-approved formula. The choices in “Product decisions requiring approval” are prerequisites to implementation.

## Proposed database vocabulary

### Enums and composite inputs

```sql
create type public.grade_scale_status as enum ('draft','active','retired');
create type public.grade_result_state as enum ('pass','fail');
create type public.term_grading_configuration_status as enum ('draft','active','retired');
create type public.term_grade_lifecycle_status as enum
  ('draft','finalized','corrected','cancelled');
create type public.term_grade_publication_state as enum ('unpublished','published');

create type public.grade_scale_band_input as (
  sequence integer,
  lower_bound numeric,
  upper_bound numeric,
  label text,
  result_state public.grade_result_state
);
```

`incomplete` is not a scale-band result. If product approves blocking incomplete inputs, no grade exists until calculation is possible. If product instead approves an incomplete outcome, add it deliberately to a separate term-grade outcome enum; do not overload scale bands.

### `grade_scales`

One immutable versioned scale aggregate:

| Column | Type and rule |
|---|---|
| `id` | UUID primary key, generated |
| `organization_id`, `school_id` | UUID, non-null, composite FK to school |
| `academic_year_id` | UUID nullable; when set, composite FK to same organization/school year |
| `name` | text, trimmed length 1–120 |
| `description` | text nullable, trimmed length 1–1000 |
| `status` | `grade_scale_status`, default `draft` |
| `supersedes_grade_scale_id` | UUID nullable, same organization/school self-FK, never self |
| `activated_at/by`, `retired_at/by` | paired nullable lifecycle attribution |
| `created_at/by`, `updated_at/by` | standard attribution |

Constraints and indexes:

- `unique (organization_id, school_id, id)` and `unique (organization_id, school_id, academic_year_id, id)` are FK targets.
- Active-name uniqueness uses two partial unique indexes: `(school_id, lower(btrim(name))) where status='active' and academic_year_id is null`, and `(school_id, academic_year_id, lower(btrim(name))) where status='active' and academic_year_id is not null`.
- Draft-name uniqueness uses the same two index keys with `status='draft'`. The separate status predicates permit one active scale and one same-name draft revision to coexist, while preventing two unrelated active heads or two unrelated draft heads in the same school/year applicability scope.
- Partial unique `supersedes_grade_scale_id where supersedes_grade_scale_id is not null and status='draft'` prevents multiple draft successors of one version. A draft with a predecessor must reference the current active/retired head in the same school/year applicability scope. A new root draft is allowed only when no active or draft scale with its normalized name exists in that scope. Revision commands recheck those rules while the chain and name peers are locked.
- Scope index `(organization_id, school_id, academic_year_id, status, id)`; FK/actor indexes for year, predecessor, and actor columns.
- Draft has no activation/retirement attribution; active has activation only; retired has both. A retired row is terminal.
- Structural scope and predecessor are immutable. Once active, name, description, and bands are immutable. Revisions are new draft scales that supersede only an active or retired chain head, then activation retires the prior active version atomically.

### `grade_scale_bands`

| Column | Type and rule |
|---|---|
| `id` | UUID primary key |
| `organization_id`, `school_id`, `grade_scale_id` | non-null composite FK to scale |
| `sequence` | integer, non-null, `>= 1` |
| `lower_units`, `upper_units` | integer, non-null; four-decimal percentage units in `0..1_000_000`, with `lower_units < upper_units` |
| `percentage_range` | generated `int8range(lower_units, upper_units, '[)')`, non-null |
| `label` | text, trimmed length 1–32 |
| `result_state` | `grade_result_state` |
| `created_at/by` | immutable attribution |

Constraints and indexes:

- Unique `(grade_scale_id, sequence)` and case-insensitive unique `(grade_scale_id, lower(btrim(label)))`.
- Exclusion constraint `exclude using gist (grade_scale_id with =, percentage_range with &&)` prevents overlap; migration 010 must explicitly create `btree_gist` if migrations 001–009 have not already done so.
- Index `(organization_id, school_id, grade_scale_id, sequence)` plus actor FK index.
- RPC numeric bounds are converted exactly by `round(bound * 10000)` only after rejecting more than four decimal places. Activation validates a contiguous cover: first lower `0`, last upper `1_000_000`, dense sequences, and each next lower equal to the prior upper.
- Lookup uses `rounded_percentage * 10000`. Values below `100.0000` use `percentage_range @> units`; exactly `1_000_000` maps to the unique final band whose `upper_units=1_000_000`. Thus every shared boundary belongs to the band beginning at that boundary, and 100 belongs to the final band.

### `term_grading_configurations`

One versioned configuration for an exact section/subject/term context:

| Column | Type and rule |
|---|---|
| `id` | UUID primary key |
| scope | non-null `organization_id`, `school_id`, `campus_id`, `academic_year_id`, `academic_term_id`, `section_id`; nullable `subject_id` |
| `grade_scale_id` | non-null FK to same school and compatible optional year |
| `status` | `term_grading_configuration_status`, default `draft` |
| `require_weights_total_100` | boolean, proposed true |
| `include_unpublished_finalized` | boolean, proposed false |
| `supersedes_configuration_id` | nullable same-context self-FK |
| lifecycle/actor columns | activation/retirement and create/update attribution |

Rules:

- Exact null-safe subject matching is part of context identity.
- Active-context uniqueness uses two partial unique indexes: `(section_id, academic_term_id) where status='active' and subject_id is null`, and `(section_id, academic_term_id, subject_id) where status='active' and subject_id is not null`.
- Draft-context uniqueness uses the same two keys with `status='draft'`. The separate predicates permit exactly one active configuration and its one draft successor to coexist in a null-safe context.
- Partial unique `supersedes_configuration_id where supersedes_configuration_id is not null and status='draft'` prevents multiple draft successors. When an active configuration exists in a context, any draft in that context must directly supersede that active chain head; a root draft is valid only when the context has neither an active nor another draft. Commands enforce this after locking the context/chain rows.
- Only active same-school scale versions may be selected at configuration activation. A year-specific scale must match `academic_year_id`; a school-wide scale has null year.
- Section, term, year, school, campus, and subject must match the assessment-context rules in migration 009. A term-specific section must name the same term; a year-long section with null term may be configured for any same-year term whose dates fall within section dates.
- Active configurations are immutable. Revision appends a draft successor. Activating it retires the prior active head. Historical calculations keep their configuration and scale version references.
- Scope, scale, calculation-rule booleans, and predecessor become immutable once activated. No JSONB stores calculation rules.

### `term_grade_sets`

One context-wide lifecycle aggregate prevents mixed publication/finalization and mixed source vintages, and represents an empty roster:

| Column | Type and rule |
|---|---|
| `id` | UUID primary key |
| scope/configuration | full non-null organization/school/campus/year/term/section/configuration; nullable subject |
| `lifecycle_status`, `publication_state` | term-grade lifecycle/publication enums |
| `calculation_sequence` | integer non-null, starts at 1 and increments on draft recalculation |
| `source_fingerprint` | `bytea` non-null, exactly 32 bytes (SHA-256 of canonical ordered inputs) |
| lifecycle attribution | paired publish/finalize/cancel/correction timestamps, actors, and bounded reasons |
| `supersedes_term_grade_set_id` | nullable same-context self-FK, never self |
| create/update attribution | standard |

Use two partial unique live-context indexes for null and non-null subject, plus a unique non-null predecessor index, scope/configuration indexes, and every actor/FK index. Lifecycle checks mirror v0.8. The set owns the source fingerprint; all child grades in a sequence necessarily use that same contributor/configuration/scale snapshot.

### `term_grade_records`

These are immutable student children of a `term_grade_set`. Lifecycle, publication, cancellation, and correction exist exclusively on the owning set.

| Column | Type and rule |
|---|---|
| `id` | UUID primary key |
| scope/configuration | denormalized tenant/school/campus/year/term/section/subject plus `term_grading_configuration_id` and `term_grade_set_id` |
| `student_id` | non-null same-tenant FK |
| `calculation_sequence` | integer non-null, `>= 1`, matching a calculation sequence reached by the set |
| create attribution | immutable `created_at/by`; no update columns |

Unique `(term_grade_set_id, calculation_sequence, student_id)` gives one immutable grade snapshot per student per set calculation sequence. The set's current `calculation_sequence` selects the current record generation; recalculation inserts a complete new generation and never updates old records. A corrected set's successor contains entirely new children; records never supersede or correct one another. Full composite FKs prove child scope/configuration equals its set.

### `term_grade_calculations`

Each row is an immutable calculation attempt belonging one-to-one to an immutable term-grade record. Recalculation appends a new record/calculation generation and advances only the set's `calculation_sequence`; prior generations remain byte-identical. This preserves every reviewed draft calculation without a mutable calculation status.

| Column | Type and rule |
|---|---|
| `id`, scope, `term_grade_record_id`, `student_id` | UUIDs with exact composite FKs |
| `calculation_sequence` | integer >=1, unique per term-grade record |
| `raw_percentage` | `numeric(20,10)` |
| `rounded_percentage` | `numeric(7,4)`, range 0–100 |
| `grade_scale_id`, `grade_scale_band_id` | exact immutable versions used |
| snapshots | `grade_label` text and `result_state` enum copied from band |
| `contributing_assessment_count`, `weight_total` | non-negative exact summaries |
| `calculated_at/by` | immutable attribution |

Unique `term_grade_record_id` makes the relationship one-to-one, and the calculation's sequence/student/set must match its record. The band FK must belong to the scale. Store both references and snapshots so presentation remains exact even if an impossible privileged mutation later damages catalog history. No teacher override columns are proposed.

The database enforces that match with a composite FK over organization, set, student, sequence, and record ID. Sources likewise use composite FKs to the exact calculation/student, assessment snapshot/student, and result/snapshot/student; `assessment_version_id` equals `assessment_id`, both version and root are assessment FKs, and a provenance trigger verifies the declared root is the actual append-and-supersede chain root.

### `term_grade_calculation_sources`

One immutable row per contributing live assessment result:

| Column | Type and rule |
|---|---|
| identifiers | `id`, full scope, `term_grade_calculation_id`, `student_id` |
| source provenance | `assessment_id`, `assessment_student_id`, `assessment_result_id` |
| correction head | `assessment_root_id` and `assessment_version_id` (the contributing `assessment_id`) |
| exact inputs | `score numeric(12,4)`, `maximum_score numeric(12,4)`, `assessment_weight numeric(7,4)` |
| exact contribution | `score_ratio numeric(20,10)`, `effective_weight numeric(20,10)`, `weighted_points numeric(20,10)` |
| `created_at/by` | immutable attribution |

Composite FKs prove all three assessment records share assessment, student, and scope. Unique `(term_grade_calculation_id, assessment_id)` prevents duplicate contribution. Index every FK/RLS traversal: calculation, student, assessment, assessment result, snapshot, and root/version lookup.

`assessment_root_id` is derived by walking `supersedes_assessment_id` to the chain root while locks are held. The selected contributor is exactly the unique live finalized head in that chain. Provenance never follows a future correction automatically.

## Proposed exact calculation

Subject to explicit approval, recommended behavior is:

1. Select assessments whose live chain head is `finalized`, not corrected/cancelled, in the exact organization/school/campus/year/term/section/null-safe-subject context. Exclude unpublished finalized assessments. Drafts never contribute even when published.
2. Every contributing assessment must have a non-null weight. The distinct contributing assessments' weights must total exactly `100.0000`. Otherwise the whole context calculation fails atomically with `22023`; no partial drafts are created.
3. The candidate roster is the union of students in the immutable snapshots of those contributing assessments. Empty contributing assessment set is an error. An empty union is valid: create an empty `term_grade_set` and emit exactly one set-level audit row and one `term_grade_set.calculated` event. This remains a product decision requiring approval.
4. A student must occur in every contributing assessment snapshot and have a numeric result. Although finalized assessments are complete for their own snapshots, cross-assessment roster differences are possible. Any difference blocks the entire context calculation as incomplete; it is not silently reweighted.
5. For assessment `i`, compute with PostgreSQL `numeric`, never floating point:

   `ratio_i = score_i / maximum_score_i`

   `weighted_points_i = ratio_i * weight_i`

   `raw_percentage = sum(weighted_points_i)` because approved weights total 100.

6. Do not round ratios or per-assessment contributions. Sum at at least `numeric(30,14)` working precision. Round once, after the sum, with PostgreSQL `round(raw_percentage, 4)` (half away from zero; inputs are non-negative). Persist raw at 10 decimal places and the final at 4. Grade-band lookup uses the rounded four-decimal percentage.
7. Boundary ownership is `[lower, upper)` with exactly `100.0000` assigned to the final band. The scale must yield exactly one band or the command fails.

This formula deliberately rejects null or incomplete weighting, roster drift, drafts, cancelled assessments, corrected predecessors, and unpublished finalized assessments. It permits unequal positive weights whose total is exactly 100. It makes no manual override. Those are recommendations, not facts established by v0.8.

## Lifecycle commands

### Grade scales

- Create draft with its complete ordered band array in one transaction.
- Update replaces the complete band set only while draft. Every deleted old band and inserted replacement band receives its own audit row; band rows have no individual outbox events.
- Activate validates scope, coverage, adjacency, order, uniqueness, and lifecycle, then freezes the version.
- Retire prevents new configuration activation but never invalidates existing configurations or calculations.
- Revise creates a draft successor with an explicit complete replacement band array; no in-place active edit.

### Configurations

- Create draft for exact context and selected scale/rules.
- Update only the draft's scale/rules.
- Activate freezes it after parent and scale validation.
- Revise appends a draft successor; activating retires the old active configuration.
- Retire blocks new calculations but preserves all records/history. A configuration with any draft term grades cannot be retired until those drafts are cancelled/finalized; published/finalized history does not block retirement.

### Term grades

- `calculate` against one active configuration creates one draft set, one immutable record per eligible student, and each record's first immutable calculation. An existing live set in the context makes creation fail; callers use recalculate.
- `recalculate` is set-draft-only. It locks the whole set/context, requires the student roster to remain identical, inserts one complete new immutable record/calculation/source generation, then advances only the set sequence/fingerprint, and detects roster/source-head drift with `40001`. Prior generations remain immutable. It does not alter set publication because published drafts remain live and auditable like v0.8.
- `publish` requires the set to be draft or finalized, a complete child/calculation generation matching the set fingerprint/sequence, and the set not already published. It is one-way. Students/guardians then see only their own child in the current generation through the live published set.
- `finalize` requires a complete internally consistent set and freezes its academic content. It may occur before or after publication. A finalized unpublished set may later be published as visibility-only.
- `cancel` applies only to an entire unpublished draft set and preserves all records, attempts, and provenance.
- `correct` is permission-only and whole-set-only. It marks one finalized live set corrected, appends one finalized successor set with a complete new child/calculation/source snapshot from the then-current approved source heads, preserves every old row, inherits publication, and writes a linear set chain.

All lifecycle commands act on the set. Correction appends a whole-set successor, matching assessment correction and preventing mixed source vintages.

## Typed public RPC surface

Names and exact proposed SQL signatures (argument names are part of the public contract):

```sql
create_grade_scale(
  school_id uuid, academic_year_id uuid, name text, description text,
  bands public.grade_scale_band_input[]
) returns uuid

update_draft_grade_scale(
  id uuid, name text, description text, set_description boolean,
  bands public.grade_scale_band_input[]
) returns uuid

activate_grade_scale(id uuid) returns uuid
retire_grade_scale(id uuid) returns uuid
revise_grade_scale(
  id uuid, replacement_name text, replacement_description text,
  replacement_bands public.grade_scale_band_input[]
) returns uuid

create_term_grading_configuration(
  section_id uuid, academic_term_id uuid, subject_id uuid,
  grade_scale_id uuid, require_weights_total_100 boolean,
  include_unpublished_finalized boolean
) returns uuid

update_draft_term_grading_configuration(
  id uuid, grade_scale_id uuid, require_weights_total_100 boolean,
  include_unpublished_finalized boolean
) returns uuid

activate_term_grading_configuration(id uuid) returns uuid
retire_term_grading_configuration(id uuid) returns uuid
revise_term_grading_configuration(
  id uuid, replacement_grade_scale_id uuid,
  replacement_require_weights_total_100 boolean,
  replacement_include_unpublished_finalized boolean
) returns uuid

calculate_term_grades(term_grading_configuration_id uuid) returns table(
  term_grade_set_id uuid, grade_count integer
)
recalculate_draft_term_grades(id uuid) returns table(
  term_grade_set_id uuid, calculation_sequence integer, grade_count integer
)
publish_term_grades(term_grade_set_id uuid) returns uuid
finalize_term_grades(term_grade_set_id uuid) returns uuid
cancel_draft_term_grades(term_grade_set_id uuid, cancellation_reason text) returns uuid
correct_term_grades(
  term_grade_set_id uuid, correction_reason text
) returns table(corrected_term_grade_set_id uuid, replacement_term_grade_set_id uuid)
```

This signature list assumes the recommended `term_grade_sets` aggregate. `subject_id uuid` accepts SQL null and uses exact null-safe matching. No RPC accepts organization, school/campus derivation (except the grade-scale school's authoritative parent ID), actor, timestamps, status, calculated values, source IDs, command ID, audit/event content, arbitrary JSON, override values, or publication/finalization attribution.

All wrappers are `security definer set search_path=''`, owned deliberately, executable only by `authenticated`, and call private typed helpers. Revoke public/anon/authenticated/service-role execution from every private mutation/helper except the minimum stable relationship read helpers needed by RLS. Tables are SELECT-only for authenticated; no direct insert/update/delete/truncate.

## Authorization and RLS matrix

All permission paths also require active organization membership, active role/assignment, active authoritative scope, and tenant/school/campus compatibility.

| Actor/path | Scales/configuration read | Scale/config manage | Draft calculate/recalculate/publish | Finalize | Correct | Student-grade read |
|---|---:|---:|---:|---:|---:|---:|
| Scoped `term_grades.view` | yes | no | no | no | no | all authorized scope/history |
| Scoped `term_grades.manage` | yes | yes | yes | yes (recommended) | no | all authorized scope/history |
| Scoped `term_grades.correct` alone | read only as needed, no mutation | no | no | no | no | authorized history only if RLS explicitly treats correct as view; recommended yes, matching v0.8 |
| Scoped manage + correct | yes | yes | yes | yes | yes | yes |
| Current exact lead/co-teacher | active scale/config context | no scale/config mutation | yes | yes (product decision) | no | exact context/history |
| Current exact substitute | active scale/config context | no scale/config mutation | yes only while effective | yes only while effective (product decision) | no | exact context while effective |
| Current exact assistant | read only | no | no | no | no | exact context while effective |
| Student self | no catalog/config enumeration | no | no | no | no | own live published grade only |
| Active linked portal guardian | no catalog/config enumeration | no | no | no | no | linked student's live published grade only |
| Anonymous/inactive/unrelated | no | no | no | no | no | no |

Recommended authority details:

- Grade-scale/configuration mutation requires scoped `term_grades.manage`; teaching relationships cannot change shared policy.
- Lead/co-teacher/substitute contextual management applies to calculation, recalculation, publication, and finalization only, with null-safe exact subject match. Assistants can gain those capabilities only through explicit scoped RBAC.
- Correction requires both `term_grades.manage` and `term_grades.correct`; no relationship grants it.
- RLS student/guardian path requires the owning set to be published and live (`draft` or `finalized`, never corrected/cancelled), an active student, and own/linked student. It exposes the child's current percentage, label, result state, and public set header fields, but not provenance/source rows, classmates, prior calculations, actors, correction reasons, audit, or outbox.
- Teachers/admins may read source provenance only where they can read the owning term-grade context and the underlying assessment context. Student/guardian RLS gets no source-table access.

## Locking and retry contract

Every command first discovers IDs without trusting them, then locks in this global order, each peer collection sorted by UUID:

1. organization;
2. school;
3. campus;
4. academic year;
5. academic term;
6. section;
7. subject (if non-null);
8. grade-scale chain rows, then bands by sequence/id;
9. configuration chain rows;
10. assessment chain roots/versions by root then version ID;
11. assessment snapshot students by student/id;
12. assessment results by student/id;
13. students by ID;
14. enrollment rows by student/id;
15. placement rows by student/id;
16. term-grade set chain;
17. term-grade rows by student/id;
18. calculation attempts and source rows by student/assessment/id.

After locking, re-read all discovered heads, contributor IDs, roster IDs, weights, results, scale/config heads, and assignment authority. If any differs, raise `40001` with a stable retry message. Unique/exclusion conflicts caused by a concurrent command that changed a live head should be normalized to `40001`; deterministic business duplicates remain `23505`/`23P01` as documented. Callers retry the entire RPC with bounded exponential backoff and jitter; never retry a partial statement or reuse returned IDs. Recommended maximum: 3 retries after the initial attempt.

No command holds one context lock and then reaches backward in the order. Assessment correction must follow the same shared parent-before-assessment order introduced here to avoid cross-module deadlock; migration 010 must wrap/replace only public hooks additively and preserve prior signatures.

## Audit and outbox inventory

Every successful state-changing command uses one server-generated `command_id`. Audit contains reviewed before/after snapshots; outbox contains only IDs, scope, state changes, counts, and calculation metadata—never student names, raw scores, teacher comments, full band definitions, or source result values. Every inserted `term_grade_calculation_source` receives its own protected audit row with action `term_grade.calculation_source_recorded`, entity type `term_grade_calculation_source`, null before-data, and the exact inserted row as after-data. Source rows never emit individual outbox events.

For cardinality, `N` is the number of student grade records in the new/current set, `C` is the total number of source rows inserted across those students, `B_old` is the number of draft band rows removed by a full replacement, and `B_new` is the number inserted. Exact cardinality is:

| Command | Audit rows | Outbox rows/events |
|---|---:|---|
| create scale with `B_new` bands | `1 + B_new` | 1 `grade_scale.created`; no band events |
| update draft scale by replacing `B_old` with `B_new` bands | `1 + B_old + B_new` | 1 `grade_scale.updated`; no band events |
| revise scale with `B_new` copied/replacement bands | `1 + B_new` | 1 `grade_scale.created`; no band events |
| activate root scale | 1 | 1 `grade_scale.activated` |
| activate revision and retire predecessor | 2 | 1 `grade_scale.activated` + 1 `grade_scale.retired` |
| retire active scale directly | 1 | 1 `grade_scale.retired` |
| create/update/activate/retire/revise config | 1 per affected configuration version (revision creation: 1; activation retiring predecessor: 2) | same row cardinality using `term_grading_configuration.created`, `.updated`, `.activated`, `.retired` |
| calculate | `1 + 2N + C` (set + records + calculations + sources) | 1 `term_grade_set.calculated` + N `term_grade.calculated`; no source events |
| recalculate | `1 + 2N + C` (set + new immutable records + new calculations + sources) | 1 `term_grade_set.recalculated` + N `term_grade.recalculated`; no source events |
| publish | 1 set | 1 `term_grade_set.published` |
| finalize | 1 set | 1 `term_grade_set.finalized` |
| cancel draft | 1 set | 1 `term_grade_set.cancelled` |
| correct finalized set | `2 + 2N + C` (old/new sets + successor records + calculations + sources) | 1 `term_grade_set.corrected` + 1 `.finalized` + N `term_grade.calculated`; no source events |

Band row audit actions are `grade_scale.band_created` and `grade_scale.band_deleted`; band updates are represented by the full-replacement delete/insert convention and never hidden inside the scale audit alone. Exact implementation must test `N=0`, `N=1`, multiple students, `C=0`, `C=N`, `C>N`, and zero/one/many bands. All audit/outbox rows for one command are correlated to its command ID using the established multi-row writer convention; migration 010 must not assume the partial unique command-ID indexes permit the same non-null value on every child row.

## Compatibility rules

- **Assessment correction:** existing term-grade calculations never change. A draft set becomes stale when a contributing chain head changes; recalculation is required before publish/finalize. A published draft stays visible at its prior calculation until explicitly recalculated; recommended alternative is to prohibit correcting a source used by a published draft. This is unresolved.
- **Assessment publication:** recommended formula excludes unpublished finalized assessments. Publishing one can change the contributor set, marks draft sets stale, and requires recalculation. Finalized term grades remain frozen.
- **Assessment lifecycle/content:** draft assessments do not contribute and do not stale a set until finalized (and, if approved, published). Cancellation of a draft has no effect. Finalized source metadata is immutable; finalized correction creates a new head.
- **Roster/enrollment/placement/student changes:** calculations use assessment snapshot provenance only. Later lifecycle/corrections do not rewrite calculations. Active student status gates portal visibility, not historical administrative access.
- **Teaching assignment changes:** affect present authority only and never rewrite grades.
- **Configuration changes:** active configuration is immutable; successor applies only to new sets. Activating a successor changes the canonical active-head fingerprint, making every older draft in the same null-safe context stale; publish and finalize return `40001` until that draft is cancelled and recreated under the successor.
- **Grade-scale changes:** active scales cannot change. Retirement blocks new configuration activation but not calculation under an already-active configuration. New scale versions never relabel history. Scale deletion is unavailable.
- **Section/subject/term/year changes:** non-cancelled draft term-grade sets block incompatible deactivation/archive/date/scope changes. Published/finalized history blocks date/scope changes that would invalidate stored relationships but does not prevent ordinary period close. Section archival is blocked by live term-grade history; corrected/cancelled-only history does not authorize deletion. Subjects/scales/configurations with history are never hard-deleted.
- **Period close:** unfinished draft sets block term/year close. Finalized sets do not. Whether published-but-unfinalized drafts block close: recommended yes.
- **Exact context:** no cross-term, cross-section, cross-subject, cross-campus, cross-school, or cross-year source can enter a calculation. Null subject remains exact, never wildcard.

## TypeScript and Zod public contract

Create `src/modules/term-grades/index.ts` only during implementation. It should export strict schemas and inferred inputs for all RPCs, RPC name/result aliases from generated `Database`, enums/constants, service interfaces, event/permission constants, error codes, and `isRetryableTermGradeCommandError` for `40001`.

Validation requirements:

- UUID/date primitives; trimmed bounded names/descriptions/reasons/labels.
- Decimal inputs use finite JS numbers only if four-place values remain within safe intended bounds; preferred public application representation is decimal strings matching `^(0|[1-9]\d{0,2})(\.\d{1,4})?$` and database `numeric` RPC arguments. Do not use binary floating point for formula execution.
- Band arrays: 1–100 entries, dense unique sequence, unique normalized labels, bounds in 0–100 with at most four decimals, exact adjacency and coverage checked in Zod for feedback and again in SQL authoritatively.
- `.strict()` on every object; duplicate array entries rejected; null subject explicitly allowed; no undefined/null ambiguity for clearable description (`set_description`).
- Reason length 1–500; names 1–120; description 1–1000; labels 1–32.
- Generated `database.types.ts` is regenerated, never hand-edited. SQL composite arrays must be verified against generated Supabase types.
- Error union at least `22023 | 23503 | 23505 | 23P01 | 40001 | 42501 | P0002`; only `40001` is retryable.

## Adversarial pgTAP matrix

### Catalog/schema/security

- Exact enum values, columns, defaults, checks, composite FKs, exclusion/unique constraints, indexes for every FK/RLS traversal, triggers, comments, owners, and function signatures.
- Forced RLS on every tenant table; authenticated SELECT only; anonymous denial; direct insert/update/delete/truncate denial; private helper execution denial including service role; exact public grants.
- Cross-tenant composite-FK swaps, browser-supplied scope/actor/status/timestamp/source/calculated-value attempts, spoofed auth IDs, and hostile `search_path` fail.
- Migration 010 is additive and migrations/signatures 001–009 remain byte-for-byte unchanged.

### Grade scales and configurations

- Organization/school/year scope, year-specific versus school-wide scale, active/inactive/closed/archived parents, normalized names, lifecycle pairs, predecessor cycles/forks/non-head revision.
- Band count and text boundaries; zero/100 boundaries; gap, overlap, reversed range, duplicate order/label, non-dense sequence, excess precision, NaN/infinity/overflow; exact single band and many-band lookup at every shared edge.
- Active/history immutability through direct and command paths; retirement/revision behavior; configuration exact null-subject behavior and duplicate live contexts.
- Scale/config reads and mutations across org/school/campus scopes with inactive memberships/roles and assistant/teacher non-authority.

### Calculation and provenance

- Known vectors including zero, 100, thirds, repeating decimals, half-rounding boundaries, maximum numeric values, and a band boundary changed only by final rounding.
- Total weights 99.9999, 100, 100.0001; null/mixed/all-null weights; unequal valid weights; one/many assessments; unpublished finalized, published finalized, published draft, unpublished draft, cancelled, corrected predecessor, live correction successor.
- Missing student from one snapshot, differing roster over time, duplicate student/source, empty assessment set, finalized empty assessment rosters, inactive/currently corrected enrollment/placement, and exact preserved snapshot use.
- Provenance references exact assessment version/result/snapshot and exact copied inputs/contributions; future source correction does not mutate old bytes.
- Atomic rollback on one bad student/band/source, audit failure, or outbox failure.

### Lifecycle, authority, and RLS

- Create/recalculate draft; multiple recalculations preserve all generations and the set selects exactly one current generation; published-draft recalculation behavior; stale-source detection.
- Publish/finalize in both approved orders, repeats/no-ops rejected, finalized content immutable, finalized-unpublished later publish visibility-only, terminal cancellation constraints.
- Lead/co-teacher exact management, substitute current-only, assistant read-only, wrong subject/section, expired/future/reassigned/corrected assignment, inactive staff/member/section/subject/year.
- Scoped view/manage/correct combinations; correction requires manage+correct and never relationship-derived.
- Student/guardian see nothing unpublished, only own live published row after publish, no classmates/provenance/actors/reasons; inactive student/guardian/link and portal loss revoke access; multi-child guardian isolation.
- Correction chain linearity, inherited publication, old byte preservation, no correction of draft/corrected/non-head, concurrent double correction.

### Locking, events, compatibility, regression

- Concurrent calculate/recalculate/publish/finalize/cancel/correct and source-assessment correction yield one head or `40001`, never partial/mixed sources or deadlock.
- Discovery drift for source heads, contributor set, weights, roster, results, scale/config head, band set, and relationship authority returns `40001`.
- Exact audit/outbox names, cardinality for zero/one/many students, common command IDs, allow-listed payloads, and sensitive-field exclusion.
- Parent lifecycle wrappers preserve all earlier checks and add the documented blockers without rewriting assessment/grade history.
- Focused v0.9 tests and the full pre-existing suite are implementation gates only, not planning actions.

## Binding product decisions

Migrations 001–009 did not settle these choices. Product has approved all 20 recommended defaults below as the binding v0.9 contract:

1. **Weight total:** require contributing weights to total exactly 100.0000. Recommended because it makes the configured percentage interpretable and prevents accidental partial grading.
2. **Null weights:** reject calculation if any contributor has null weight. Recommended; null in v0.8 means unspecified, not zero or equal weight.
3. **Unequal weights:** permit unequal positive weights when the total is 100. Recommended; weighting is their purpose.
4. **Rounding:** calculate in PostgreSQL decimal, do not round components, round once to four percentage decimals after summation, then select the band. Recommended to match source precision and make boundaries deterministic.
5. **Incomplete/missing results:** block the entire context when a student is absent from any contributing assessment snapshot; never silently renormalize. Recommended for predictability, but this makes transfers/late enrollments a product workflow problem.
6. **Finalized-only:** only finalized assessment heads contribute. Recommended; published drafts are editable and cannot be stable provenance.
7. **Unpublished finalized:** exclude them. Recommended because publication is the teacher's visibility/approval signal, though v0.8 permits valid finalized-unpublished work.
8. **Teacher overrides:** no manual percentage, label, or result-state override in v0.9. Recommended; override governance and provenance are not defined and manual bonus points are out of scope.
9. **Publish/finalize order:** mirror assessments: either order; publish is one-way; finalized-unpublished may later publish. Recommended for baseline consistency.
10. **Who may finalize:** allow currently effective lead/co-teachers and substitutes under contextual manage authority, not only administrators. Recommended for consistency with assessment finalization; correction remains permission-only.
11. **Source correction after draft:** mark the draft stale and require explicit recalculation before publish/finalize. Recommended; never mutate automatically.
12. **Source correction after published draft:** keep the visible prior draft until explicit recalculation, while blocking finalization. Recommended for history continuity, but temporarily exposes a known-stale draft; the stricter alternative is to prohibit assessment correction until the draft is unpublished/cancelled, which conflicts with one-way publication.
13. **Source correction after a finalized term-grade set:** preserve the finalized set unchanged; correction is an explicit `term_grades.correct` command that recalculates and supersedes the whole set. Recommended.
14. **Grade-scale change after history:** active scale versions and bands are immutable; revisions append; historical grades snapshot label/state and retain old references. Recommended.
15. **Roster rule:** require the same student set across all contributors. Recommended as the safest foundation; alternatively define per-student eligibility/renormalization, which needs substantially more policy.
16. **Empty roster:** calculation succeeds with an empty set and one set-level audit/outbox event. Recommended so the attempted, reviewable calculation is represented consistently.
17. **Aggregate shape:** use a context-wide `term_grade_sets` parent and correct/finalize/publish whole sets. Recommended to prevent mixed lifecycle/source vintages and to represent empty rosters.
18. **Configuration rules:** store both `require_weights_total_100` and `include_unpublished_finalized`, but v0.9 should activate configurations only with the approved fixed values (`true`, `false`) unless product intentionally supports alternatives. Recommended; avoid advertising unapproved modes.
19. **Staleness mechanism:** calculate and persist a deterministic SHA-256 fingerprint over ordered configuration, scale, assessment version/result, and roster identifiers/input values; rederive it before publish/finalize. Recommended to make stale checks explicit and testable.
20. **Scale coverage/result states:** require complete 0–100 coverage and only pass/fail states in v0.9. Recommended; an incomplete state is a calculation outcome, not a percentage band.

All 20 decisions are approved. Any later change requires a reviewed additive correction rather than silently changing calculation behavior.

## Definition of done (future implementation gate)

- Independent architecture/security/product review is complete and every unresolved decision above is recorded as approved or changed.
- Additive migration `202608190010_term_grades_grade_scales_v0_9.sql` implements only the approved contract; migrations 001–009 remain unchanged.
- Migration includes schema, constraints, indexes, grants, forced RLS, seeds for the three permission codes, narrow typed RPCs, audit/outbox behavior, lifecycle compatibility wrappers, comments, and pgTAP tests.
- `src/modules/term-grades/index.ts` provides strict Zod/public TypeScript contracts; public database types are locally regenerated rather than edited.
- Documentation adds `docs/modules/term-grades.md` and updates security, system overview, assessments, academics, enrollments, teaching assignments, and SIS compatibility notes.
- Focused adversarial v0.9 pgTAP, full database suite, strict TypeScript typecheck, production build, generated-type consistency, and whitespace checks pass at implementation verification time.
- No deployment, linked-project mutation, production change, UI, notification, import, stage, commit, push, merge, or PR occurs without a separate request.
