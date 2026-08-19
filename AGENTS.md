# School Platform engineering rules

## Architecture

- Build a modular monolith. Business logic belongs in domain modules, not React components, route handlers, or database triggers.
- Modules communicate through public service interfaces or the event outbox. Do not import another module's private persistence code.
- Keep TypeScript strict. Validate all external input with Zod.

## Database and security

- PostgreSQL migrations under `supabase/migrations` are the schema source of truth. Never make unrecorded dashboard changes.
- Every tenant-owned table must contain or unambiguously derive tenant scope, enable and force RLS in its creation migration, and have operation-specific policies.
- Authorization requires application RBAC plus database RLS. Never trust a browser-supplied `organization_id` without deriving authorization from `auth.uid()`.
- Never expose or use the service-role key in browser code. Do not use it for ordinary user requests.
- Add indexes for foreign keys and every relationship traversed by RLS.
- Important writes must append an audit record and, when other modules react, an event-outbox record in the same transaction.
- Preserve academic history. Use status transitions and new records instead of destructive updates or hard deletes.
- Database migrations include schema, constraints, indexes, grants, RLS, seeds, and relevant pgTAP tests.

## Testing

- Every domain must test anonymous denial, cross-tenant denial, missing-permission denial, permitted same-tenant access, and inactive membership denial.
- Add contextual tests when teacher, guardian, student, course, or campus relationships are introduced.
- Run typecheck, affected tests, and production build before declaring work complete.

## Change discipline

- Keep migrations immutable after they have reached a shared environment; add a new migration for corrections.
- Avoid JSONB for core relational records. It is acceptable for event payloads, audit snapshots, and template/configuration data.
- Update architecture and module documentation when a public interface, permission, event, or invariant changes.

