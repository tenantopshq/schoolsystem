# System overview

The platform starts as a modular monolith: one deployable Next.js application and one PostgreSQL database, with business domains isolated behind TypeScript module boundaries. This keeps transactions and operations simple while preserving a path to extract workers or services if measured scale requires it.

## Dependency direction

`app → modules → platform/shared`

- `app` owns routing and presentation.
- `modules` own domain rules and expose deliberate public interfaces.
- `platform` owns cross-cutting capabilities: authentication, authorization, database access, audit, events, files, notifications, and localization.
- `shared` contains domain-neutral types and utilities only.

Modules never query another module's private tables as an integration shortcut. Cross-domain effects are invoked through public services or recorded in the transactional event outbox.

The academics module owns staff employment profiles and academic structure
(buildings, rooms, grade levels, subjects, and sections). Academic periods remain a
shared academic primitive but now mutate through audited academics RPCs. Typed
public commands form the module boundary: new-aggregate wrappers use two unexposed
private dispatchers, while period commands implement equivalent validation directly.
Each successful mutation emits one correlated audit record and transactional outbox
event for downstream modules.

The SIS module exposes 21 typed student/guardian/child-record RPCs. Ordinary clients
retain SELECT-only table access; private command helpers derive tenant and actor,
lock authoritative scope parent-first, enforce transition-only lifecycle changes,
and write audit/outbox effects atomically. Guardian creation is the deliberate
multi-aggregate exception: guardian and initial-link audit/events share one command
ID. Concurrent guardian scope/link changes abort with retryable SQLSTATE `40001`.

Document upload authorization remains a storage-platform responsibility. That
service creates a single-use intent; SIS consumes the intent and derives the
immutable storage path when creating metadata. Capability IDs and storage details
are excluded from integration events.

## Security boundary

Access requires both an application permission check and a database RLS decision. Tenant identity is derived from authenticated membership; client-supplied organization identifiers are never trusted on their own. Service-role credentials are server-only and may not be used for ordinary user requests.

## Source of truth

All schema, grants, RLS policies, functions, seeds, and database tests are committed under `supabase/`. Dashboard-only schema changes are prohibited.

Enrollment & Section Placement v0.5 owns effective-dated academic enrollment and
homeroom-section history. Same-tenant enrollment can differ from SIS administrative
scope, while exclusion constraints prohibit overlapping non-corrected ranges.
Placement workflows preserve immutable history under capacity-aware deterministic
locks and transactional audit/outbox.
