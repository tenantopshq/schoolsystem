# Academic Foundation v0.3 — Verification Crosswalk

This checklist maps the independent security review to migration 004 and
`academic_foundation_v0_3_test.sql`. The latest reviewed runs completed 531 focused
assertions and 634 full database assertions. Exact catalog/function assertions live
beside the adversarial fixtures so future signature changes fail the same suite.

| Finding | Implemented and verified contract |
|---|---|
| 1. Adversarial coverage | Anonymous, tenant/school/campus boundary, permission, membership, RLS read, command denial, direct-write, and attribution-spoof matrices cover all aggregates and 24 public RPCs. |
| 2. Archived terminal state | Each of the six new aggregates rejects archived creation, update, reactivation, and repeat archive after archival; periods reject closed/archived initial state. |
| 3. Authoritative parents | Create/update/period commands lock and validate active composite-scope parents before scoped authorization; missing and inactive cases have deliberate errors. |
| 4. Immutable structure | Building, room, grade, subject, section, year, and term scope is immutable; staff home moves require permission over old and new scope. |
| 5. Complete updates | All reviewed mutable fields and nullable set flags are exercised, including explicit clearing and validation failures. |
| 6. Normalized uniqueness | Catalog checks and collision tests prove scoped `lower(btrim(...))` uniqueness for grade, subject, section, staff number, and term name where applicable. |
| 7. Composite section scope | Section commands bind and lock authoritative organization, school, campus, year, grade, optional term, and optional room; cross-scope fixtures are denied. |
| 8. Concurrency locks | Function-definition checks and invariant tests verify the shared parent-first lock order and room/section capacity locking paths. |
| 9. Audit/outbox | Every successful command produces exactly one correlated audit and event; payload/event contracts and forced audit/outbox rollback tests prove atomicity. |
| 10. Ownership and grants | Catalog-driven tests cover owner, security mode, empty search path, explicit wrapper grants, private denial, table write denial, and legacy SIS privilege preservation. |
| 11. Maintainability | Migration 004 is sectioned and commented around derivation, authorization, immutable fields, nullable flags, locking, and atomic writes. |
| 12. Missing targets | Update/archive missing-target tests for all six aggregates assert aggregate-specific `P0002` errors and zero side effects. |
| 13. Legacy preservation | Migrations 001–003 remain unchanged; the v0.1 seed assertion checks the original seed codes exactly. |

## Release checklist

- `npm run db:reset`: passed in the accepted verification cycle.
- `npm run db:test`: 634/634 assertions passed.
- Focused academic-foundation pgTAP: 531/531 assertions passed.
- `npm run typecheck` and `npm run build`: required again before final publication.
- Generated Supabase TypeScript database types are checked in at
  `src/platform/database/database.types.ts`. Reproduce them from a reset local
  database with `npm run db:reset` and `npm run db:types`; never generate this file
  from a remote project.
- Migration 004 remains undeployed and unmerged pending final independent review.
