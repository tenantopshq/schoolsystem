# Term Grades

## Boundary

Term Grades owns school grade-scale versions and bands, exact section/subject/term configurations, whole-set term-grade lifecycle, immutable student calculation generations, and exact assessment-result provenance. It does not own assessments, rosters, teaching assignments, student/guardian relationships, GPA, transcripts, or report cards.

## Calculation and history

Only live published finalized assessment heads in the exact null-safe context contribute. Every weight must be non-null and weights total exactly 100. Student rosters must match across contributors. PostgreSQL numeric arithmetic sums unrounded weighted contributions, rounds once to four percentage decimals, then resolves the half-open scale band; 100 belongs to the final band.

Draft recalculation appends a complete immutable record/calculation/source generation and advances the set sequence. Publication and finalization are independent and one-way. Correction requires scoped manage plus correct permissions and appends a whole finalized successor set; prior rows are never rewritten or deleted. Active scales/configurations are immutable and revised by append-and-supersede versions.

## Authorization and data access

All seven tables use forced RLS and authenticated SELECT-only grants. Scoped `term_grades.view`, `.manage`, and `.correct` provide administrative reads; manage mutates scale/configuration and grade workflows. Effective exact-context lead/co-teachers and substitutes may calculate, recalculate, publish, and finalize. Assistants are contextual readers. Relationship authority never corrects.

Students and active portal guardians see only the student's current generation through a live published set. They cannot read provenance. Every command derives tenant, scope, actor, lifecycle attribution, calculations, and event content from locked authoritative rows.

## Events and retry behavior

Aggregate events are `grade_scale.*`, `term_grading_configuration.*`, `term_grade_set.*`, and `term_grade.calculated|recalculated`. Band and source rows are audited individually but emit no per-row event. Commands lock parents, source chains, rosters, results, and grade rows deterministically; discovery/head drift raises retryable SQLSTATE `40001`.

The complete approved schema, RPC signatures, event cardinality, compatibility rules, and adversarial matrix are in `docs/plans/term-grades-foundation-v0.9.md`.
