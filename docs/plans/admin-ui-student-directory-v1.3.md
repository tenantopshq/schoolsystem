# Admin UI foundation and student directory v1.3

## Outcome and scope

Deliver the smallest production-quality staff UI vertical slice: sign in, resolve an
authorized organization/school/campus context, browse a server-paginated student
directory, open a student record, and create, edit, change active/inactive status,
or archive a student through the SIS public boundary. The slice also establishes
the shell, accessibility patterns, read/command separation, error handling, and
test conventions reused by later administrative modules.

Included student detail is deliberately read-only outside the student profile:
ordinary profile fields, enrollment/section-placement history, permitted guardian
link summaries, and permitted document metadata. Guardian, enrollment, placement,
and document commands remain out of scope, as do uploads/downloads and every UI
listed as out of scope in the brief.

## Repository findings and required backend prerequisites

The repository currently has Next.js 16 App Router, React 19, strict TypeScript,
Zod, `@supabase/ssr`, a browser client, and a generated `Database` type. It has no
server Supabase client, auth routes, middleware/proxy, UI component library, or JS
test/browser-test setup. The only pages are the root layout and placeholder home.

Existing interfaces that can be retained:

| Need | Existing interface | Use in v1.3 |
| --- | --- | --- |
| Session | Supabase Auth | Server `auth.getUser()` on protected requests; password sign-in and sign-out |
| Student create/edit/archive | Existing private SIS helpers behind `create_student`, `update_student`, and `archive_student`, plus schemas in `src/modules/students/index.ts` | Reused internally by new `_v1_3` wrappers; the UI never calls legacy public RPCs |
| Student rows | `students` with `students_select` RLS | Underlying source for a new constrained read RPC |
| Enrollment history | `student_enrollments` with `student_enrollments_select` RLS | Underlying source for detail read model |
| Placement history | `student_section_placements` with its select RLS | Underlying source for detail read model |
| Guardian summary | `student_guardians` + `guardians`, each RLS protected | Return only permitted summary fields |
| Document metadata | `student_documents` select policy | Return metadata only; never `storage_path` |
| Scope and authorization | memberships, role assignments, role permissions, `app_auth.has_permission` | Underlying authority for a new self-context RPC |

Migration 014 is unavoidable before the UI is complete. It is **strictly additive**:
migrations 001–013 remain byte-for-byte immutable. It may add types, a private
receipt table/helpers, indexes, public read functions, and new named command
functions; it must not replace or change any existing function signature or table.

### Exact migration 014 database contract

All public functions below are `SECURITY DEFINER`, owned by `postgres`, and declare
`SET search_path = ''`. Migration 014 first revokes all execution from `PUBLIC`,
`anon`, `authenticated`, and `service_role`, then grants only the read and v1.3
command functions to `authenticated`. Private `app_auth` objects grant execution to
no browser role. Every function rejects a null `auth.uid()` with `42501`.

#### Authorized context read

```sql
public.get_my_admin_contexts()
returns table (
  membership_id uuid,
  organization_id uuid, organization_name text, organization_slug text,
  school_id uuid, school_name text, school_code text,
  campus_id uuid, campus_name text, campus_code text,
  scope_level text,
  permission_codes text[]
)
```

`scope_level` is exactly `organization`, `school`, or `campus`. Rows include only an
active organization, active membership with `left_at is null`, active roles, current
active role assignments, and active schools/campuses. A row exists only when
`app_auth.has_permission` is true at that exact scope for at least one of
`students.view`, `students.create`, `students.edit`, `students.archive`,
`students.sensitive_view`, `students.sensitive_manage`, or
`student_documents.manage`; `permission_codes` is the sorted distinct subset of
those seven codes effective at that tuple. Organization grants produce an
organization row; school grants produce an “all campuses” school row; campus grants
produce campus rows. Broader grants are also expanded to active descendant school
and campus rows so users can select a concrete creation/filter scope. No user ID is
accepted, and no profile, role name, assignment ID, or timestamps are returned.

#### Directory read

```sql
public.search_students(
  p_organization_id uuid,
  p_school_id uuid default null,
  p_campus_id uuid default null,
  p_query text default null,
  p_status public.record_status default 'active', -- null means all
  p_sort text default 'name',                     -- name|student_number|updated
  p_direction text default 'asc',                 -- asc|desc
  p_after_value text default null,
  p_after_id uuid default null,
  p_limit integer default 25
)
returns table (
  student_id uuid, student_number text,
  first_name text, last_name text, preferred_name text,
  status public.record_status,
  school_id uuid, school_name text,
  campus_id uuid, campus_name text,
  updated_at timestamptz,
  sort_cursor_value text,
  total_count bigint
)
```

The function requires `students.view` at the requested tuple, rejects a campus
without its parent school, rejects values outside the listed sort/direction set,
requires both cursor values or neither, and clamps `p_limit` to `1..50`. It applies
authorization and organization/school/campus/status predicates before search.
Search is case-insensitive across student number, first, middle, last, and preferred
name, but returns no middle name or DOB. `sort_cursor_value` is the exact lowercased
`last_name + U+001F + first_name + U+001F + preferred_name + U+001F + student_number`
key, lowercased student number, or UTC `updated_at` text for the selected sort.
Ordering is always the selected typed value followed by `students.id`, in the same
direction. The adapter requests 26 rows, exposes 25, and encodes the last exposed
`(sort, direction, sort_cursor_value, student_id)` as an opaque base64url cursor.
It rejects a cursor whose embedded sort/direction differs from the current query.
This is stable keyset pagination for all three approved sorts; bounded offset
pagination is therefore unnecessary. `total_count` is computed over the authorized
filtered set before the cursor predicate.

#### Student detail read

```sql
public.get_student_admin_detail(p_student_id uuid)
returns table (
  student_id uuid, student_number text,
  first_name text, middle_name text, last_name text, preferred_name text,
  date_of_birth date, gender text, nationality_code character(2),
  primary_language text, admission_date date, exit_date date,
  status public.record_status,
  school_id uuid, school_name text,
  campus_id uuid, campus_name text,
  created_at timestamptz, updated_at timestamptz,
  enrollments jsonb, guardian_links jsonb, documents jsonb
)
```

The top-level row requires `students.view` at the student's authoritative stored
scope. It returns exactly the listed scalar fields: notably no `organization_id`,
`user_id`, `photo_path`, or attribution IDs. `enrollments` is an ordered JSON array
of exactly `id`, `academic_year_id`, `academic_year_name`, `grade_level_id`,
`grade_level_name`, `enrolled_on`, `scheduled_end_on`, `ended_on`, `status`,
`end_reason`, `supersedes_enrollment_id`, and `placements`; each `placements` array
contains exactly `id`, `campus_id`, `campus_name`, `section_id`, `section_name`,
`starts_on`, `ends_on`, `status`, `end_reason`, `transfer_to_placement_id`, and
`supersedes_placement_id`. Enrollment items are included only where the existing
`app_auth.can_view_enrollment` check succeeds.

`guardian_links` is an ordered JSON array only when
`app_auth.can_staff_view_student` succeeds and contains exactly `link_id`,
`guardian_id`, `first_name`, `middle_name`, `last_name`, `relationship_type`,
`is_primary`, `has_portal_access`, and `status`; it contains no email, phone,
occupation, user ID, or alert/financial/pickup flags. `documents` contains a row
only when `can_manage_student_documents(organization_id, student_id)`, or when its
visibility is `staff|guardian|student` and `can_staff_view_student(...)`, or when
visibility is `guardian|student` and `is_linked_guardian(student_id)`, or when
visibility is `student` and `is_student_self(student_id)`. It contains exactly
`id`, `document_type`, `title`, `mime_type`, `file_size`, `issued_at`, `expires_at`,
`visibility`, and `status`; it never contains `storage_path`. Unauthorized and
nonexistent top-level students both return zero rows. Unavailable child sections
are empty JSON arrays, not an error.

#### Replay-safe commands and receipts

Migration 014 adds private table
`app_auth.sis_command_receipts(organization_id uuid, actor_user_id uuid,
command_name text, request_id uuid, argument_hash bytea, completed boolean,
result_id uuid, created_at timestamptz, completed_at timestamptz, primary key
(organization_id, actor_user_id, command_name, request_id))`. It has no public
grants and a 32-byte hash check. Private `app_auth.claim_sis_receipt(...)` and
`app_auth.complete_sis_receipt(...)` follow the migration-013 receipt protocol:
SHA-256 over an unambiguous canonical JSONB argument object, row locking, `22023`
for UUID reuse with different arguments, and `40001` for an identical in-flight
request.

The new public signatures are deliberately named, not overloads:

```sql
public.create_student_v1_3(
  request_id uuid, school_id uuid, campus_id uuid, student_number text,
  first_name text, middle_name text, last_name text, preferred_name text,
  date_of_birth date, gender text, nationality_code character(2),
  primary_language text, photo_path text, admission_date date, exit_date date,
  status public.record_status default 'active'
) returns uuid

public.update_student_v1_3(
  request_id uuid, id uuid, student_number text, first_name text,
  middle_name text, set_middle_name boolean, last_name text,
  preferred_name text, set_preferred_name boolean, date_of_birth date,
  gender text, set_gender boolean, nationality_code character(2),
  set_nationality_code boolean, primary_language text,
  set_primary_language boolean, photo_path text, set_photo_path boolean,
  admission_date date, set_admission_date boolean, exit_date date,
  set_exit_date boolean, status public.record_status,
  school_id uuid, set_school_id boolean, campus_id uuid, set_campus_id boolean
) returns uuid

public.archive_student_v1_3(
  request_id uuid, target_student_id uuid, archive_reason text
) returns uuid
```

Each wrapper validates/locks enough authoritative data to derive the organization,
actor, and permission context, claims the receipt, and on first execution calls the
existing private SIS helper exactly once in the same transaction. The existing
helper remains the sole business-rule writer and emits the existing audit row and
outbox event atomically. The wrapper completes the receipt with the result ID.
Identical replay returns that ID without another data mutation, audit row, or event.
Any failure rolls back the receipt with the command. Request IDs and hashes are not
copied into public audit snapshots; the receipt is the private replay correlation.
The inherited permission checks are exact: create requires `students.create` at the
derived school/campus; update requires `students.edit` at the stored scope and, for
a move, at the destination scope; archive requires `students.archive` at the stored
scope and retains the active-child/link precondition. Receipt lookup never turns a
previous result into authority: the wrapper verifies the current actor and target
scope before returning a replay, so revoked membership is denied.

#### RLS, indexes, grants, and pgTAP

The read functions are definer-owned and therefore do not rely on table RLS as their
only guard: they explicitly reproduce the existing `app_auth.has_permission`,
`can_view_enrollment`, `can_staff_view_student`, and document-visibility checks.
Existing RLS remains enabled and forced and all direct table grants remain unchanged.
The commands reuse existing private helpers, so their RBAC, locking, RLS-independent
authorization, audit, and outbox behavior remains authoritative.

Migration 014 adds exactly these indexes (existing
`students_scope_status_idx`, `students_name_search_idx`, and
`students_org_normalized_number_key` remain untouched):

```sql
create extension if not exists pg_trgm with schema extensions;

create index students_directory_number_trgm_idx on public.students
  using gin (lower(student_number) extensions.gin_trgm_ops);
create index students_directory_name_trgm_idx on public.students using gin
  (lower(coalesce(first_name,'') || ' ' || coalesce(middle_name,'') || ' ' ||
         coalesce(last_name,'') || ' ' || coalesce(preferred_name,''))
   extensions.gin_trgm_ops);
create index students_directory_name_cursor_idx on public.students
  (organization_id, school_id, status,
   (lower(coalesce(last_name,'') || E'\x1f' || coalesce(first_name,'') || E'\x1f' ||
          coalesce(preferred_name,'') || E'\x1f' || student_number)), id);
create index students_directory_number_cursor_idx on public.students
  (organization_id, school_id, status, (lower(student_number)), id);
create index students_directory_updated_cursor_idx on public.students
  (organization_id, school_id, status, updated_at, id);
create index students_directory_campus_name_cursor_idx on public.students
  (organization_id, school_id, campus_id, status,
   (lower(coalesce(last_name,'') || E'\x1f' || coalesce(first_name,'') || E'\x1f' ||
          coalesce(preferred_name,'') || E'\x1f' || student_number)), id);
create index students_directory_campus_number_cursor_idx on public.students
  (organization_id, school_id, campus_id, status, (lower(student_number)), id);
create index students_directory_campus_updated_cursor_idx on public.students
  (organization_id, school_id, campus_id, status, updated_at, id);
```

The school-level trio supports all-campus contexts without a gap after `school_id`;
the campus trio supports concrete-campus contexts. PostgreSQL can scan each B-tree
backward for descending order. Implementation must record `EXPLAIN (ANALYZE,
BUFFERS)` evidence for all three sorts at school and campus scope; failure to use an
index is a plan defect to correct, not permission to silently change this contract.

pgTAP must assert object/signature/owner/search-path/grant shape; anonymous denial;
cross-tenant, missing-permission, inactive-membership, expired-assignment, wrong
school, and wrong-campus denial; same-scope success; exact returned column sets;
absence of sensitive/context/`storage_path` fields; child-level visibility; all
sorts in both directions across duplicate values with no gaps/duplicates; cursor
tampering/mismatch rejection; limit clamping; identical command replay yielding one
student change, one audit row, and one outbox event; different-argument UUID reuse;
in-flight conflict; and authorization rechecked before command execution.

## Routes and user flow

| Route | Responsibility and server/client split |
| --- | --- |
| `/login` | Server redirects authenticated users; client form handles password sign-in, pending state, and safe field/form errors. Preserve only validated same-origin `next`. |
| `/select-context` | Server loads `get_my_admin_contexts`. Auto-select one usable context; show an explicit chooser for multiple; show revoked/inactive state for none. A small client form posts the selection. |
| `/admin` | Protected shell; redirects to `/admin/students`. Server resolves session and selected context on every request. |
| `/admin/students` | Server parses URL state, calls `search_students`, and renders table/cards, filters, count, and pagination. Client components only manage debounced search/filter navigation and focus. |
| `/admin/students/new` | Permission-gated server page with client-enhanced form; organization-level contexts must switch to a school or campus context before creation. The server action revalidates that exact selected scope, invokes `create_student_v1_3`, then invalidates and redirects to detail. |
| `/admin/students/[studentId]` | Server detail read; overview plus enrollment/placement timeline, permitted guardian links, and document metadata. Unauthorized and missing IDs both call `notFound()`. |
| `/admin/students/[studentId]/edit` | Permission-gated server page; validated update action. Status change to active/inactive is explicit and confirmed when consequential. |

Archive is a dialog launched from detail, not a separate page. It requires an
entered reason and clear warning that active child/link records block archival.
Authentication callback/error endpoints should be added only if the chosen Supabase
login method requires them; v1.3 defaults to email/password and no signup/reset UI.

## Boundaries and contracts

Keep React dependent only on public module services and presentation models:

```text
Server page/action -> SIS public service -> Supabase adapter -> typed RPC
                   -> identity public service -> self-context RPC/Auth
```

- Extend `src/modules/students/index.ts` with `StudentDirectoryQuery`,
  `StudentDirectoryPage`, `StudentAdminDetail`, command result/error types, strict
  query/form schemas, `StudentReadService`, and the request-ID-aware
  `SisCommandService`; that service exposes only the three `_v1_3` commands. Put Supabase implementations under a private `infrastructure`
  folder; no component imports generated database types or calls `.from()`/`.rpc()`.
- Extend identity/organizations public boundaries with `AdminContext`, effective
  permissions, context-selection schema, and `AdminContextService`.
- Server actions accept browser IDs as untrusted input, validate them, resolve the
  authenticated user and selected context again, and let the RPC re-derive final
  authorization. They never pass `organization_id` into a command.
- Store the selected context as a signed, HTTP-only, `Secure` in production,
  `SameSite=Lax` cookie containing only context IDs and a version. Revalidate it
  against `get_my_admin_contexts()` on every protected navigation/action. The fresh,
  signed selection is an application authorization boundary in addition to database
  RBAC: query parameters may narrow but never replace it, and every detail or command
  target must remain inside it. Clear it when membership is inactive/revoked.
- Use Server Components for reads and shell composition. Client Components are
  limited to menu/dialog behavior, toasts, URL filter controls, and progressively
  enhanced forms. Business rules, authorization, and RPC mapping stay in services.

Directory query schema: `q` (trimmed, max 100), `status` (`active|inactive|archived|all`,
default `active`), optional authorized `school`, optional authorized `campus`,
`sort` (`name|student_number|updated`, default `name`), `dir` (`asc|desc`), and an
optional opaque `after` cursor. Invalid non-cursor values canonicalize to defaults;
an invalid, tampered, or mismatched cursor returns a safe bad-request state rather
than silently changing position. Unknown keys are ignored. Search matches the five
approved fields, escapes SQL pattern characters, and applies scope before search.
Page size is 25 and pagination is forward keyset pagination; changing any filter or
sort removes `after`. Browser history provides Back rather than a server-generated
previous cursor.

Create/update forms use UI schemas derived from, but not weaker than, the existing
domain schemas. Empty optional fields normalize to `null`; update adapters set the
existing `set_*` flags explicitly. Generate and retain one `crypto.randomUUID()` per
submission attempt so network retry reuses it; generate a new UUID only after a
definitive validation/domain failure or successful new intent. Return a discriminated
action state containing field errors, a safe form error, and submitted values.

### Legacy RPC compatibility and deprecation

Migration 014 leaves the definitions and signatures of `create_student`,
`update_student`, and `archive_student` intact for schema and controlled server-side
compatibility. It does not use `CREATE OR REPLACE` on them. After the new wrappers
are installed and tested, it explicitly revokes execute on those three legacy
functions from `authenticated` and `anon`; `PUBLIC` remains revoked. It grants
legacy execution only to `service_role` as a temporary compatibility bridge for
trusted server integrations, never for ordinary UI traffic. The v1.3 application
contains no adapter or type path to a legacy command and never uses a service-role
key.

This is a deliberate access-level deprecation, not silent deletion: database
signatures remain discoverable, trusted integrations have one release to migrate to
the named `_v1_3` functions, and `docs/modules/sis.md` marks legacy RPCs deprecated
with removal of their service-role grants targeted for v1.4 after consumer audit.
Tests assert the legacy signatures still exist, `authenticated` receives `42501`,
`service_role` retains the documented bridge, and `_v1_3` is the only browser-role
write route. If repository-wide consumer discovery finds a real authenticated
legacy client before implementation, that is a release blocker requiring an
explicit migration window—not a reason to leave an undocumented bypass.

## Authorization, errors, and caching

The shell uses effective permissions only for presentation. `students.view` gates
directory/detail navigation, `students.create` gates New, `students.edit` gates Edit
and active/inactive transition, `students.archive` gates Archive, and document/
guardian sections render only when returned by the read model. RPC/RLS remains
authoritative for every operation and race.

Centralize error translation in the SIS adapter. Log a correlation ID and internal
error server-side; return no SQL text, identifiers, or policy details. Map:

| Code/condition | Safe result |
| --- | --- |
| `42501` | “You no longer have permission for this action.”; refresh context/navigation |
| `P0002` | Generic not found for reads; “This record is no longer available.” for actions |
| `23505` | Field conflict where known (student number), otherwise generic conflict |
| `23503` | Archive blocked by active related records; explain required cleanup without exposing hidden data |
| `22023` | Domain validation/status conflict; safe allowlisted message |
| `40001` / transient transport failure | Retry automatically once with the same request UUID, then offer retry |
| unknown | Generic failure plus correlation ID |

Use request-time authenticated reads (`cache: no-store` semantics); do not put
user-scoped data in shared Next.js caches. After successful commands call
`revalidatePath('/admin/students')` and the affected detail path, then redirect or
refresh. The browser does not hold an unrestricted student dataset. Static shell
assets may use normal framework caching.

## UI foundation and accessibility

Build semantic, dependency-light primitives: `Button`, `Field`, `Select`,
`StatusBadge`, `DataTable`, `Pagination`, `EmptyState`, `Alert`, `ConfirmDialog`,
`Toast`, and skeletons. The responsive shell contains skip link, landmark-based
navigation, context switcher, header, breadcrumb, and page title. Tables retain real
table semantics on wide screens and use labelled cards on narrow screens.

All controls have programmatic labels and visible focus; validation summary links
to fields; errors use `aria-describedby`; action results use an appropriate live
region; dialogs trap/restore focus and close on Escape; loading never erases the
page title; status is never color-only. Add route `loading.tsx`, `error.tsx`, and
`not-found.tsx` at the smallest useful boundaries.

## Test and verification strategy

- Add Vitest + Testing Library + jsdom + `jest-axe` for schemas, query parsing,
  error mapping, permission-derived presentation, actions, and components. Cover
  loading, empty, no-results, error, validation persistence, hidden/visible actions,
  revoked context, dialogs, keyboard/focus, labels, table semantics, and live errors.
- Add Supabase integration tests for each read RPC and request replay: anonymous,
  cross-tenant, missing permission, permitted same-tenant, inactive membership,
  school/campus scope, hidden guardian/document fields, identical replay, conflicting
  UUID reuse, and authorization revoked between render and submit.
- Add Playwright with deterministic local Supabase fixtures. One required path:
  login -> choose context -> search/filter directory -> create student -> land on
  detail. Also cover denied deep link and archive confirmation/blocked result.
- Before completion run database reset/tests and type generation for migration 014,
  then `npm run typecheck`, unit/component/integration/browser tests, accessibility
  checks, and `npm run build`.

## Implementation sequence and expected file inventory

1. Backend prerequisite: add only
   `supabase/migrations/202608190014_admin_ui_student_directory_v1_3.sql` and
   `supabase/tests/admin_ui_student_directory_v1_3_test.sql`; update generated
   `src/platform/database/database.types.ts`, `docs/modules/sis.md`,
   `docs/architecture/security.md`, and `docs/architecture/system-overview.md`.
   Migrations 001–013 are immutable.
2. Platform/auth: add `src/platform/database/supabase-server.ts` and
   `src/platform/database/supabase-middleware.ts`, root `proxy.ts`, public context
   contracts in `src/modules/identity/index.ts` and
   `src/modules/organizations/index.ts`, private adapters below those modules, and
   `src/app/login/` plus `src/app/select-context/` routes.
3. SIS boundary: update `src/modules/students/index.ts`; add private
   `src/modules/students/infrastructure/supabase-student-read-service.ts`,
   `supabase-sis-command-service.ts`, `mappers.ts`, and `errors.ts`, plus server
   actions under `src/modules/students/application/`. Only infrastructure imports
   generated database types; only the command adapter calls `_v1_3` RPCs.
4. UI: replace `src/app/page.tsx` with session-aware routing; extend
   `src/app/layout.tsx` and `src/app/styles.css`; add `src/app/admin/layout.tsx`,
   `src/app/admin/page.tsx`, the listed `src/app/admin/students/` pages and local
   `loading.tsx`/`error.tsx`/`not-found.tsx`; add primitives under
   `src/components/ui/` and shell/context components under `src/components/admin/`.
5. Tests/tooling: update `package.json` and lockfile; add Vitest/Testing Library/
   Playwright configs, unit/component tests beside modules/components, browser tests
   and fixtures under `tests/e2e/`, and only the environment keys required by the
   chosen auth test setup in `.env.example`.

Exact filenames below each feature folder may be adjusted during implementation,
but the public/private module boundary and the listed schema, migration, route,
documentation, and test artifacts are required.

## Screen-by-screen acceptance checklist

### Login and protected shell

- [ ] Anonymous protected requests redirect to login with a safe return target.
- [ ] Server validates the user; sign-out clears session/context and protected data.
- [ ] Shell is responsive and keyboard operable, with skip link, landmarks,
      breadcrumbs, title, loading, error, and not-found behavior.
- [ ] Navigation/actions reflect effective permissions without being an authority.

### Context selection

- [ ] Only active, currently authorized organization/school/campus combinations are shown.
- [ ] One context selects automatically; multiple require a clear explicit choice.
- [ ] Signed preference is revalidated on every protected read/action.
- [ ] Revocation/inactive membership clears context and shows a safe recovery state.

### Student directory

- [ ] Authorized rows only; search, status/school/campus filters, sort, and pagination
      are server-side and represented in canonical URL parameters.
- [ ] Loading, empty directory, no results, and recoverable error states are distinct.
- [ ] Desktop table and mobile presentation expose the same labelled information;
      pagination preserves filters and focus.
- [ ] No unrestricted dataset or sensitive detail/document storage path reaches the client.

### Create student

- [ ] Only users with `students.create` see the entry point, while the server/RPC
      independently authorizes submission.
- [ ] Strict validation, field errors, and entered values survive rejection.
- [ ] Double submit and transport retry reuse one request UUID and create one student.
- [ ] Success invalidates directory data and opens the new detail page.

### Student detail

- [ ] Missing and unauthorized IDs are indistinguishable to the user.
- [ ] Overview shows allowlisted ordinary fields, names for school/campus, and clear status.
- [ ] Enrollment/placement history is chronological and visibly distinguishes current,
      terminal, corrected, and transferred records.
- [ ] Guardian links and document metadata appear only when authorized; documents never
      expose storage paths or imply upload/download capability.

### Edit, status transition, and archive

- [ ] Form starts from fresh server data and submits only supported fields through RPCs.
- [ ] Permission loss or concurrent changes return safe actionable feedback and retain values.
- [ ] Archive requires confirmation and a nonblank reason.
- [ ] Blocked archive explains that active related records must first be resolved; no
      destructive cascade or direct table write occurs.
- [ ] Success invalidates both directory and detail and presents a focused confirmation.

## Approved product decisions

1. **Login method — email/password only for v1.3.** It is the smallest
   complete flow and does not pre-commit to SSO providers; signup and password reset
   remain administrator-managed/out of scope.
2. **Context granularity — select the most specific authorized tuple,
   with “All campuses” only when the effective school-level grant truly covers it.**
   Never synthesize broad scope by combining campus grants.
3. **Directory defaults — active students, name ascending, 25 per page.**
   Archived records remain discoverable through the status filter.
4. **Search fields — student number plus first, middle, last, and preferred
   name; case-insensitive prefix/word-friendly matching.** Do not search DOB or other
   sensitive fields.
5. **Detail sensitivity — date of birth remains visible to authorized staff
   on detail but not in directory; omit identifiers, addresses, emergency contacts,
   guardian contact data, and document storage paths in v1.3.** Guardian summary is
   name, relationship, primary flag, portal flag, and link status only.
6. **Lifecycle UX — profile Edit handles active/inactive, while Archive is
   a separate reasoned confirmation.** Do not build child-record cleanup workflows;
   show the backend block and defer cleanup UI.
7. **UI dependencies — custom semantic primitives and CSS for this slice,
   adding only testing dependencies.** Reconsider a component system when a broader
   design language is approved.
8. **Backend prerequisite — migration 014 precedes frontend work.**
   Context/permission discovery, coherent safe read models, and caller-keyed command
   replay are genuine contract gaps, not optional UI refinements.

No meaningful product decision remains. Implementation may make mechanical naming
or query-plan adjustments that preserve this contract; any change to returned data,
authorization semantics, legacy grants, routes, or approved UX returns for approval.
