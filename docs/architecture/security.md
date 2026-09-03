# Security model

Authorization combines:

1. membership in an organization;
2. an active role assignment at organization, school, or campus scope;
3. a permission granted to that role;
4. contextual relationships added by each later domain; and
5. PostgreSQL RLS for every tenant-owned table.

RLS policies are operation-specific. Helper functions live in the private `app_auth` schema, use an empty `search_path`, and are not executable by anonymous users. Functions that bypass caller RLS must be small, stable, reviewed, and covered by adversarial tests.

The initial policies intentionally give only platform-management permissions access to foundation records. Teacher, guardian, and student relationship policies arrive with their domain tables.

No deletes are allowed through ordinary RLS policies for foundational records. Status transitions preserve history. `audit_log` and `event_outbox` are append-only to authenticated clients.

Academic Foundation v0.3 makes academic structure and academic-period tables
command-only for mutation. Eighteen typed public wrappers call two private generic
dispatchers (create and update/archive); the dispatchers are not executable by
`authenticated`, `anon`, or the implicit `public` role. Six typed period commands
implement their boundary directly. Exposing neither arbitrary JSON nor generic
operation names prevents clients from bypassing reviewed signatures.

Commands derive the actor from `auth.uid()`, resolve and lock authoritative scope
rows, check scoped RBAC, validate/write, and append exactly one correlated audit row
and outbox event atomically. Public functions and private helpers have deliberate
owners, empty search paths, schema-qualified references, and explicit signature
grants. Authenticated users retain SELECT-only table access through forced,
operation-specific RLS and cannot mutate academic tables directly.

SIS Command Layer v0.4 applies the command-only boundary to students, guardians,
relationships, identifiers, addresses, emergency contacts, and document metadata.
Its 21 typed public RPCs accept no organization, actor, identity-link, audit/event,
arbitrary JSON, or storage-path authority. Student scope is derived from locked
authoritative rows. Identifier mutation requires both `students.edit` and
`students.sensitive_manage`; document metadata mutation requires both
`students.edit` and `student_documents.manage`.

The SIS lock order is organization, sorted schools, sorted campuses, sorted
students, guardian, then sorted links/children. Guardian commands re-read the locked
link set and raise SQLSTATE `40001` if it changed concurrently; callers may retry the
complete command with bounded backoff. Status transitions cannot be combined with
business/scope edits. Archived records are terminal, hard deletes are not exposed,
and cleanup remains authorized from stored scope so parent lifecycle does not strand
history.

Document creation consumes a locked server-created upload intent. Browser roles
have no intent-table access and cannot assert a storage path. `upload_intent_id` and
document storage/sensitive metadata are excluded from outbox payloads. Identifier
values are replaced with `[REDACTED]` before audit serialization and excluded from
outbox payloads. Every successful SIS command writes its domain change, protected
audit record, and minimal outbox event atomically; failure rolls back all effects,
including intent consumption.

Enrollment v0.5 adds forced-RLS, SELECT-only enrollment and placement tables. Nine
typed security-definer RPCs derive student and academic scope from locked rows and
require `enrollments.manage`; corrections additionally require
`enrollments.correct`. Cross-school commands check administrative source and
academic destination authority. Student and active portal-guardian relationships
grant reads only. Domain, audit, and minimal outbox writes share one transaction and
server-generated command ID; discovery drift raises retryable SQLSTATE `40001`.
