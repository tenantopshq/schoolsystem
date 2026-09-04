# Academic Foundation v0.3

## Boundary

The academics module owns staff employment profiles, buildings, rooms, grade-level
and subject catalogs, and academic-year sections. Authentication profiles and role
assignments remain platform concerns; teaching assignments, enrollment, scheduling,
attendance, and grading are later modules.

## Access and mutation

Authenticated clients receive scoped read access only. Organization, school, and
campus role assignments are evaluated with active membership and permission checks.
Campus roles may read their parent school's grade and subject catalogs, but only
school- or organization-scoped managers may mutate them.

All important writes use 24 narrow, typed `public` RPCs. The 18 new-aggregate
wrappers forward to one private create dispatcher and one private update/archive
dispatcher in `app_auth`; neither dispatcher accepts direct client execution.
Academic-year and term direct writes are revoked, and their six typed public commands
implement the same security boundary directly. No public RPC accepts arbitrary
JSON, tenant identity, actor attribution, or audit/event content. No ordinary
request uses service-role access.

The checked-in `src/platform/database/database.types.ts` is generated from the
fully migrated local Supabase database and must not be hand-edited. Regenerate it
with `npm run db:reset` followed by `npm run db:types`; `db:types` uses the CLI's
`--local` mode and the public schema only. The browser client is parameterized with
the generated `Database` type, and the module exports narrow argument/result aliases
for the 24 academic mutation RPCs.

Commands resolve and lock authoritative targets and parents, derive scope, check the
scoped permission, validate and write, then append `audit_log` and `event_outbox`
atomically. Missing/inactive authoritative records use deliberate errors before
permission checks where the reviewed disclosure policy permits. Nullable update
fields use `set_<field>` flags: false preserves and true applies the value, including
NULL clearing. Structural scope fields are not exposed by update wrappers.

## Audit and event payloads

Each successful mutation generates a server-side `command_id` and writes exactly one
audit row and one outbox row carrying that same identifier in the command transaction.
Clients cannot supply the command identifier, actor, tenant, scope, event name, or
payload. Event names use `<aggregate>.created`, `.updated`, `.archived`, or
`.status_changed`; `aggregate_type` is the matching singular aggregate name.

Outbox payloads contain `command_id`, `actor_user_id`, `organization_id`, both
`entity_id` and `aggregate_id`, and derived `school_id`, `campus_id`,
`academic_year_id`, and `academic_term_id` when applicable. They include only the
names of changed fields plus before/after status metadata, not full records or staff
employment details. Full reviewed before/after snapshots remain confined to the
audit log.

Academic year and term transitions permit `draft -> active|archived`, `active ->
closed`, and `closed -> archived`. Archived is terminal and no-op transitions are
invalid. Active terms require active years; active linked sections prevent relevant
close/archive transitions.

New staff and structural records may start as active or inactive, never archived.
Years and terms may start as draft or active; direct active creation supports
validated import/immediate-opening workflows, and an active term still requires an
active year. Closed and archived period states are reached only through transition
commands.

## Invariants

- Structural scope is immutable after creation; staff home placement is the sole
  movable scope and requires authorization over both old and new scope.
- Active children block parent archival.
- Children cannot be created or updated against inactive structural parents.
- Section capacity cannot exceed its homeroom room, and room capacity cannot be
  reduced below active linked sections.
- Inactive sections may use draft or active periods; active sections require active
  periods. Section dates remain inside their year and optional term.
- Academic history is preserved with status transitions rather than hard deletion.
- Normalized uniqueness uses `lower(btrim(...))` for grade/subject code and name,
  section code and name, staff number, and term name in their documented scopes.
- Lock order is organization, school, campus, building, academic year, grade level,
  academic term, room, then section; peer rows use deterministic identifier order.

Teaching assignments are owned by their separate module. Academics continues to
own assignment parents. Active assignments block section archival/inactivation and
academic-year close/archive, and parent date changes cannot exclude non-corrected
assignment history.
