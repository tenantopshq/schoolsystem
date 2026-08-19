# System overview

The platform starts as a modular monolith: one deployable Next.js application and one PostgreSQL database, with business domains isolated behind TypeScript module boundaries. This keeps transactions and operations simple while preserving a path to extract workers or services if measured scale requires it.

## Dependency direction

`app → modules → platform/shared`

- `app` owns routing and presentation.
- `modules` own domain rules and expose deliberate public interfaces.
- `platform` owns cross-cutting capabilities: authentication, authorization, database access, audit, events, files, notifications, and localization.
- `shared` contains domain-neutral types and utilities only.

Modules never query another module's private tables as an integration shortcut. Cross-domain effects are invoked through public services or recorded in the transactional event outbox.

## Security boundary

Access requires both an application permission check and a database RLS decision. Tenant identity is derived from authenticated membership; client-supplied organization identifiers are never trusted on their own. Service-role credentials are server-only and may not be used for ordinary user requests.

## Source of truth

All schema, grants, RLS policies, functions, seeds, and database tests are committed under `supabase/`. Dashboard-only schema changes are prohibited.

