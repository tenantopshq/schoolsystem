# Academic Foundation v0.3 — Architecture Plan

## Review status

The table model, permission matrix, RLS matrix, and command/event inventory are
approved for implementation in migration
`202608190004_academic_foundation_v0_3.sql`. Implementation will be maintained in a
draft pull request until final review.

The migration is additive and immutable. It does not edit migrations
`202608190001`, `202608190002`, or `202608190003`.

## Goal and module boundary

The academics module will own the stable school structure used later by scheduling,
enrollment, attendance, and grading:

- staff employment profiles (not authentication profiles or role assignments);
- campus buildings and rooms;
- school grade levels and subjects; and
- academic-year, campus, grade-level sections.

Authentication identity remains owned by `profiles`; tenant membership and access
scope remain owned by `organization_memberships` and `role_assignments`. This
migration will not model teaching assignments, enrollment, timetables, or course
offerings. A teacher therefore receives no implicit access merely because a
`staff_profiles` row exists: access is granted only by an active membership, an
active/in-date scoped role assignment, and the relevant permission.

## Table relationship design

All six tables carry `organization_id`, actor/timestamp columns, and a status. Every
tenant relationship uses a composite foreign key so a browser-supplied UUID cannot
move a row across an organization, school, or campus boundary.

```text
organizations
├── schools
│   ├── academic_years
│   ├── grade_levels
│   ├── subjects
│   └── campuses
│       ├── buildings
│       │   └── rooms
│       └── sections ── academic_years
│                      ├── grade_levels
│                      └── rooms (optional homeroom)
└── organization_memberships
    └── staff_profiles ── schools (optional home school)
                       └── campuses (optional home campus)
```

### `staff_profiles`

One employment profile per organization membership. Proposed columns:
`id`, `organization_id`, `organization_membership_id`, optional `school_id`, optional
`campus_id`, `staff_number`, `employment_type`, optional `job_title`, optional
`department`, optional `hire_date`, optional `termination_date`, `status`, timestamps,
and actors.

Invariants:

- unique `(organization_id, organization_membership_id)` and
  `(organization_id, staff_number)`;
- membership must belong to the same organization;
- optional school must belong to the same organization;
- optional campus requires a school and must belong to the same organization and
  school;
- termination date cannot precede hire date;
- an archived profile is historical and is never hard-deleted or reactivated;
- `staff_number`, job data, and dates have bounded/nonblank checks where applicable.

Names are not duplicated or validated here; person names remain owned by the
existing `profiles` table.

The optional school/campus is the employee's home placement, not authorization.
Authorization continues to come solely from role assignments. Organization-wide
staff use both values as null; school staff set only `school_id`; campus staff set
both. Staff-profile create/update commands require the target organization
membership and any home school/campus parents to be active. A later membership
suspension does not erase the historical staff profile, but RLS immediately removes
the suspended actor's access.

### `buildings`

Campus-owned physical building: `id`, `organization_id`, `school_id`, `campus_id`,
`code`, `name`, optional `opened_on`, optional `closed_on`, `status`, timestamps, and
actors.

Invariants: campus is mandatory and consistent with both organization and school;
code is unique per campus; close date cannot precede open date; archived records are
preserved. Organization, school, and campus are immutable after creation. A building
cannot be archived while any active room belongs to it, and building create/update
operations may reference only active organization, school, and campus parents.

### `rooms`

Building-owned room: `id`, `organization_id`, `school_id`, `campus_id`,
`building_id`, `code`, `name`, `room_type`, `capacity`, optional `floor_label`,
`status`, timestamps, and actors.

Invariants: building must belong to the same organization/school/campus; room code
is unique per building; capacity is an integer from 1 through 10,000; nonblank
bounded names/codes/types; archived records are preserved. Organization, school,
campus, and building are immutable after creation. A room cannot be archived while
an active section uses it as its homeroom. A room capacity cannot be reduced below
the capacity of any active linked section. Room create/update operations may
reference only active organization, school, campus, and building parents.

### `grade_levels`

School-owned ordered grade definition: `id`, `organization_id`, `school_id`, `code`,
`name`, `sequence`, optional `minimum_age`, optional `maximum_age`, `status`,
timestamps, and actors.

Invariants: school is tenant-consistent; normalized code and name are unique per
school; sequence is positive and unique per school; ages, if supplied, are between
0 and 30 and maximum is not below minimum. Organization and school are immutable
after creation. A grade level cannot be archived while an active section references
it. Grade-level create/update operations may reference only active organization and
school parents.

### `subjects`

School-owned subject catalog entry: `id`, `organization_id`, `school_id`, `code`,
`name`, optional `description`, `status`, timestamps, and actors.

Invariants: school is tenant-consistent; normalized code and name are unique per
school; nonblank bounded values; archived records are preserved. Subjects are not
linked directly to sections in v0.3 because that relationship belongs to the later
course-offering/scheduling module. Organization and school are immutable after
creation, and subject create/update operations may reference only active
organization and school parents.

### `sections`

An academic-year cohort at one campus and grade level: `id`, `organization_id`,
`school_id`, `campus_id`, `academic_year_id`, `grade_level_id`, optional
`academic_term_id`, optional `homeroom_room_id`, `code`, `name`, `capacity`,
`start_date`, `end_date`, `status`, timestamps, and actors.

Invariants:

- campus, academic year, optional academic term, grade level, and optional homeroom
  room all belong to the same organization and school; the term belongs to the
  selected year and the homeroom room belongs to the selected campus;
- section code and name are unique within `(academic_year_id, campus_id)`;
- capacity is an integer from 1 through 10,000 and, when a homeroom room is present,
  cannot exceed the room capacity;
- `end_date >= start_date`, and both dates must fall inside the academic year;
- when `academic_term_id` is present, both dates must also fall inside that term;
- organization, school, campus, academic year, and grade level are immutable after
  creation. The optional term and homeroom room may be changed only within those
  immutable boundaries and only after validating both old and new parents;
- archived records are preserved.

Cross-row capacity and academic-period date bounds cannot be expressed as PostgreSQL
`CHECK` constraints. The private create/update section commands will lock and read
the referenced rows, validate those rules, and then write. Room update commands will
lock active linked sections before reducing capacity. Direct table mutation is
revoked, so these command boundaries are authoritative. Scalar positivity and date
order remain table `CHECK` constraints.

### Parent lifecycle and academic-period eligibility

All referenced structural parents must have `status = 'active'` when a child is
created or updated. Existing historical children may remain linked after their own
status becomes inactive or archived, but an inactive/archived parent cannot receive
a new or moved child. Archive commands lock and reject the parent transition when
the active-child rules above would be violated.

Structural and staff aggregates may be created as `active` or `inactive`, but never
as `archived`. Archived is a terminal historical state reached only through the
aggregate's dedicated archive command.

Academic periods use the existing `draft`, `active`, `closed`, and `archived`
statuses:

- years and terms may be created as `draft` or `active`; direct active creation is a
  deliberate administrative workflow for importing or immediately opening a
  validated period, while closed/archived are never valid initial states;
- an active term may be created only under an active parent year;
- an inactive section may be created or edited against a `draft` or `active`
  academic year and, when supplied, a `draft` or `active` academic term;
- an active section requires both its academic year and optional term to be
  `active`;
- `closed` and `archived` years/terms cannot be selected by section create/update;
- activating a section revalidates period status and date containment;
- closing or archiving a year/term is rejected while it has active sections; and
- shrinking year/term dates is rejected if any linked non-archived section would
  fall outside the new bounds.

The optional term supports year-long sections while making term-bound sections
explicit. Changing a section's term is permitted only within its immutable academic
year and requires authorization over the same section scope.

### Composite keys and indexes

The migration will add only the composite candidate keys missing from the existing
schema that are necessary for these foreign keys (for example a school-leading key
on `academic_years`). Each new table will expose candidate keys needed by children,
including organization-, school-, campus-, and building-leading variants.

Every foreign-key column set will have a matching leading index. Additional RLS
indexes will cover:

- membership/user/status and staff home scope;
- `(organization_id, school_id, campus_id, status)` for scoped reads;
- building-to-room and campus-to-building paths;
- academic year/campus/grade/status section lookup; and
- school/status/code paths for grade levels and subjects.

pgTAP will compare `pg_constraint` foreign-key columns with `pg_index` leading
columns, rather than checking only a hand-picked list.

## Permission matrix

The catalog will add four permissions. A manage permission implies read in RLS, but
does not imply direct table writes.

| Permission | Staff profiles | Buildings/rooms | Grades/sections/subjects | Mutation path |
|---|---|---|---|---|
| `staff_profiles.view` | Read in assigned scope | None | None | None |
| `staff_profiles.manage` | Read and invoke staff commands in assigned scope | None | None | Private command via public RPC |
| `academic_structure.view` | None | Read in assigned scope | Read in assigned scope | None |
| `academic_structure.manage` | None | Read and invoke structure commands in assigned scope | Read and invoke structure commands in assigned scope | Private command via public RPC |

Scope semantics are inherited from `app_auth.has_permission`:

| Role assignment | Target allowed |
|---|---|
| Organization (`school_id` and `campus_id` null) | Every school and campus in that organization |
| School (`school_id` set, `campus_id` null) | School-owned rows and all campus rows in that school |
| Campus (both set) | Campus-owned rows at that campus, plus read-only access to the parent school's grade-level and subject catalogs |

Campus-scoped users can read and mutate buildings, rooms, and sections at their
campus. They may read the parent school's complete grade-level and subject catalogs,
but catalog mutation requires a school- or organization-scoped assignment. Separate
private helpers will encode catalog-read scope and catalog-manage scope so a campus
assignment cannot be promoted into school-wide mutation authority.

## RLS access matrix

RLS is enabled and forced in the migration transaction before grants and commit. Tables receive
authenticated `SELECT` grants only. `anon` receives no table or function access;
authenticated clients receive no `INSERT`, `UPDATE`, `DELETE`, `TRUNCATE`, or
sequence privileges.

| Actor/context | Staff profiles | Buildings | Rooms | Grade levels | Sections | Subjects |
|---|---|---|---|---|---|---|
| Anonymous | Deny | Deny | Deny | Deny | Deny | Deny |
| No active membership | Deny | Deny | Deny | Deny | Deny | Deny |
| Suspended/left membership | Deny | Deny | Deny | Deny | Deny | Deny |
| Active membership, missing permission | Deny | Deny | Deny | Deny | Deny | Deny |
| Org-scoped matching view/manage | All in organization | All in organization | All in organization | All in organization | All in organization | All in organization |
| School-scoped matching view/manage | Profiles home-scoped to school/campuses | School campuses | School campuses | School | School campuses | School |
| Campus-scoped matching view/manage | Profiles home-scoped to campus | Campus | Campus | Parent-school catalog read | Campus | Parent-school catalog read |
| Same organization, other school | Deny | Deny | Deny | Deny | Deny | Deny |
| Same school, other campus (campus role) | Deny | Deny | Deny | Parent-school catalog read | Deny | Parent-school catalog read |
| Other organization | Deny | Deny | Deny | Deny | Deny | Deny |
| Matching scoped manager, direct write | Deny | Deny | Deny | Deny | Deny | Deny |

Self-service staff-profile access is deliberately not implicit in v0.3. A future
personnel module can expose a safe self-view projection after deciding which fields
are personally visible. This table may contain employment metadata, so access
requires `staff_profiles.view` or `.manage`.

RLS helper functions remain in `app_auth`, use `SECURITY DEFINER` only where
caller RLS must be bypassed, set `search_path = ''`, schema-qualify every object, and
are executable only by the minimum required roles. New-aggregate public wrappers
contain no authorization or business logic; they forward typed arguments to the two
private dispatchers under tightly revoked `SECURITY DEFINER` ownership. The period
commands are typed public implementations of the same security sequence.

Policies are operation-specific. The six new tables receive authenticated `SELECT`
policies only; they receive no insert/update/delete policies or grants. The migration
will also remove the existing authenticated write policies and revoke ordinary
mutation privileges on `academic_years` and `academic_terms`. Their read policies
remain permission-scoped. Consequently neither permissive legacy RLS nor a table
grant can bypass the audited period commands.

For school catalogs, the read helper will require an active membership and an active,
in-date role assignment carrying `academic_structure.view` or `.manage`, where the
assignment is organization-scoped, scoped to the target school, or scoped to a
campus whose authoritative parent is the target school. The mutation helper will
accept only organization- or exact-school-scoped assignments. Both derive the actor
from `auth.uid()` and validate scope through authoritative school/campus rows.

## Command and event inventory

The database owner owns all command functions; no client-controlled role may own or
alter them. The 18 mutations for the six new aggregates are narrow, typed
`SECURITY DEFINER` functions in `public`. Create wrappers forward to the private
`app_auth.academic_foundation_command(text, uuid, jsonb)` dispatcher, while update
and archive wrappers forward to
`app_auth.mutate_academic(text, uuid, jsonb, boolean)`. These two generic
dispatchers are deliberately private: exposing their operation name or arbitrary
JSON payload would enlarge the client contract, weaken signature-level spoofing
protection, and permit combinations not represented by a reviewed wrapper.

The six academic-period RPCs are typed public `SECURITY DEFINER` commands with their
validation implemented directly; they do not use the generic dispatchers. Every
public command and private dispatcher has an empty `search_path` and schema-qualified
references. `anon` and the implicit `public` role have no execution rights.
`authenticated` can execute only the 24 typed public commands, not either private
dispatcher or private mutation helpers. `service_role` retains explicit operational
execution but is not used for ordinary requests.

Parameters are typed business inputs. No command accepts `organization_id`,
`created_by`, `updated_by`, `actor_user_id`, audit data, or event payload from the
client when those values can be derived. Commands obtain the actor from `auth.uid()`,
require the actor's active organization membership, derive tenant/school/campus from
locked authoritative parent or target rows, and then check the operation's scoped
permission. A supplied entity or parent UUID is only a lookup key, never trusted as
tenant authority.

| Aggregate | Commands | Permission | Events |
|---|---|---|---|
| Staff profile | `create_staff_profile`, `update_staff_profile`, `archive_staff_profile` | `staff_profiles.manage` at requested/locked home scope | `staff_profile.created`, `.updated`, `.archived` |
| Building | `create_building`, `update_building`, `archive_building` | `academic_structure.manage` at campus | `building.created`, `.updated`, `.archived` |
| Room | `create_room`, `update_room`, `archive_room` | `academic_structure.manage` at campus | `room.created`, `.updated`, `.archived` |
| Grade level | `create_grade_level`, `update_grade_level`, `archive_grade_level` | `academic_structure.manage` at school (organization/school assignments only) | `grade_level.created`, `.updated`, `.archived` |
| Section | `create_section`, `update_section`, `archive_section` | `academic_structure.manage` at campus | `section.created`, `.updated`, `.archived` |
| Subject | `create_subject`, `update_subject`, `archive_subject` | `academic_structure.manage` at school (organization/school assignments only) | `subject.created`, `.updated`, `.archived` |
| Academic year | `create_academic_year`, `update_academic_year`, `transition_academic_year_status` | `academic_periods.manage` at school | `academic_year.created`, `.updated`, `.status_changed` |
| Academic term | `create_academic_term`, `update_academic_term`, `transition_academic_term_status` | `academic_periods.manage` at the term's year/school | `academic_term.created`, `.updated`, `.status_changed` |

### Public RPC signatures

The public contract contains no arbitrary `jsonb` input and accepts no tenant,
actor, audit, event, or attribution fields.

```text
create_staff_profile(membership_id, school_id, campus_id, staff_number,
  employment_type, job_title, department, hire_date, status)
update_staff_profile(id, staff_number, employment_type, status,
  school_id, set_school_id, campus_id, set_campus_id,
  job_title, set_job_title, department, set_department,
  hire_date, set_hire_date, termination_date, set_termination_date)
archive_staff_profile(id)
create_building(campus_id, code, name, opened_on, status)
update_building(id, code, name, status,
  opened_on, set_opened_on, closed_on, set_closed_on)
archive_building(id)
create_room(building_id, code, name, room_type, capacity, status)
update_room(id, code, name, room_type, capacity, status,
  floor_label, set_floor_label)
archive_room(id)
create_grade_level(school_id, code, name, sequence,
  minimum_age, maximum_age, status)
update_grade_level(id, code, name, sequence, status,
  minimum_age, set_minimum_age, maximum_age, set_maximum_age)
archive_grade_level(id)
create_subject(school_id, code, name, description, status)
update_subject(id, code, name, description, status, set_description)
archive_subject(id)
create_section(campus_id, academic_year_id, academic_term_id, grade_level_id,
  homeroom_room_id, code, name, capacity, start_date, end_date, status)
update_section(id, code, name, capacity, start_date, end_date,
  academic_term_id, homeroom_room_id, status,
  set_academic_term_id, set_homeroom_room_id)
archive_section(id)
create_academic_year(school_id, name, start_date, end_date, status)
update_academic_year(id, name, start_date, end_date)
transition_academic_year_status(id, status)
create_academic_term(academic_year_id, name, sequence, start_date, end_date, status)
update_academic_term(id, name, sequence, start_date, end_date)
transition_academic_term_status(id, status)
```

Nullable update fields use an adjacent `set_<field>` flag. `false` preserves the
stored value; `true` applies the supplied value, including `NULL` to clear it.
`update_subject` retains its published default of `set_description = true`, so its
description argument is applied unless callers explicitly request preservation.
The wrappers expose no structural-scope inputs on aggregates whose scope is
immutable.

Every command follows this security order: resolve and lock the target and
authoritative parents; derive tenant and structural scope; check the scoped
permission for `auth.uid()`; validate command-specific invariants and write; then
append audit and outbox records atomically. Missing targets and inactive or
scope-inconsistent parents produce deliberate errors before authorization where the
reviewed information-disclosure policy permits it, avoiding NULL-derived permission
decisions. Update/archive commands `SELECT ... FOR UPDATE` the target first.
Building, room, grade-level, subject,
and section structural scope columns cannot be changed by update commands. Academic
year organization/school and academic term organization/year are likewise immutable.
Staff home placement is the sole supported structural move: its command requires
`staff_profiles.manage` over both the locked old scope and authoritative new scope.
Archived aggregates reject further update or archive operations. No hard-delete
command is provided.

Academic-period commands close the legacy direct-write boundary introduced in v0.1.
They enforce legal status transitions, current-year uniqueness, term containment in
its year, section date containment, and active-section close/archive restrictions.
Migration 004 itself performs the revocations and policy cleanup; no separate
prerequisite correction migration is planned.

The academic-year transition graph is `draft -> active|archived`, `active ->
closed`, and `closed -> archived`; archived is terminal and no-op transitions are
invalid. The academic-term graph is identical. An active term requires an active
parent year, and term transitions must remain compatible with the parent-year
state. Active linked sections block period close/archive transitions as applicable.

Commands acquire authoritative rows in the documented order: organization, school,
campus, building, academic year, grade level, academic term, room, then section.
Operations touching peers use deterministic identifier order. Thus child creation
and parent archival lock the same parent first; section create/update locks the room
before capacity validation, while room capacity reduction locks the room and then
the relevant active sections.

Effective normalized uniqueness uses `lower(btrim(...))`: grade-level code/name and
subject code/name per school; section code/name per academic year and campus;
staff number per organization; and academic-term name per year. Sequence and
candidate-key constraints remain relational uniqueness constraints where required.

Every successful command, in one transaction:

1. resolves and locks the target and authoritative parents;
2. derives scope and validates the authenticated actor's scoped permission;
3. validates invariants and writes with server-owned attribution;
4. appends one `audit_log` row with reviewed before/after snapshots; and
5. appends one `event_outbox` row with aggregate ID, derived scope identifiers,
   actor ID, and event-specific fields.

Important writes include every create, update, archive, and academic-period status
transition listed above. A server-generated `command_id` correlates the audit and
outbox rows. The outbox payload contains actor, organization, entity/aggregate ID,
derived school/campus/year/term identifiers where relevant, changed-field names,
and before/after status metadata, without sensitive full records. Each command
appends exactly one actor-attributed audit record and one event-outbox record in the
same database transaction as the domain write. Any failure rolls back all three
writes. Tests force an audit or outbox failure
inside a savepoint and assert that the aggregate change is absent, proving atomicity
rather than merely counting successful side effects.

## Migration and test plan

The single migration contains, in dependency order: missing composite candidate
keys on existing parents; types (only if a constrained enum is justified); tables;
constraints; indexes; update timestamp triggers; permission catalog seeds; private
access helpers and commands; RLS enable/force and operation-specific select policies;
academic-period legacy write-policy removal; explicit table/function grants and
revocations; public RPC wrappers; comments; and transaction commit. Deployed
migrations 001–003 remain byte-for-byte unchanged.

Implemented pgTAP coverage:

- schema/constraint/index catalog tests for all six tables;
- organization-, school-, and campus-role permitted read and command tests;
- anonymous, cross-tenant, cross-school, cross-campus, missing-permission, and
  non-active membership (`invited`, `suspended`, or `left`) denial tests;
- direct insert/update/delete and actor-attribution spoofing denial tests;
- command ownership, wrapper/private-function grants, RBAC checks, tenant derivation,
  and staff old/new scope authorization tests;
- immutable building, room, grade-level, subject, section, academic-year, and
  academic-term structural-scope tests;
- parent archive rejection for buildings with active rooms, rooms with active linked
  sections, grade levels with active sections, and periods with active sections;
- create/update rejection for inactive or archived organization, school, campus,
  building, room, grade-level, academic-year, and academic-term parents;
- audit/outbox attribution and rollback atomicity tests;
- room and section scalar capacity checks, section-versus-room capacity checks, and
  room-capacity reduction rejection when any active linked section would exceed it;
- section date order plus academic-year and optional academic-term containment,
  including draft/active/closed/archived period eligibility;
- campus-role grade-level/subject catalog read, plus campus-role catalog mutation
  denial;
- duplicate normalized subject, grade-level, and section code checks; and
- generic foreign-key leading-index coverage.

## Definition of done

- This architecture and both access matrices are reviewed and approved.
- `202608190004_academic_foundation_v0_3.sql` is additive, transactional, and applies
  cleanly after migrations 001–003 without modifying them.
- All tenant/school/campus relationships are enforced by composite foreign keys;
  every foreign key and RLS traversal has a supporting leading index.
- All six tables enable and force RLS and expose read-only table privileges to
  authenticated users through operation-specific policies.
- Existing ordinary authenticated writes to `academic_years` and `academic_terms`
  are revoked in migration 004; audited permission-checked period RPCs are the only
  supported mutation path.
- Organization-, school-, and campus-scoped permissions behave exactly as the
  matrices specify, including suspended membership and cross-boundary denial.
- Campus roles can read their parent-school grade/subject catalogs but cannot mutate
  those school-wide catalogs.
- Parent lifecycle, inactive-parent, immutable-scope, period eligibility/date, and
  forward/reverse capacity rules are enforced at the command boundary and covered
  by adversarial pgTAP tests.
- All mutations use reviewed typed public RPCs; new-aggregate wrappers call two
  unexposed generic dispatchers, while period commands implement the same boundary
  directly. Actor and tenant scope are derived, never trusted from browser input.
- Every successful mutation writes exactly one attributed audit row and one outbox
  event atomically; failed commands write none.
- Academic history is preserved through status transitions; no hard-delete RPC is
  exposed.
- Module/security documentation and local-schema-generated database types are
  current; the browser client and academics RPC aliases consume the generated
  `Database` contract without changing runtime credentials or behavior.
- `npm run db:reset`, `npm run db:test`, `npm run typecheck`, and `npm run build` all
  pass locally.
- The migration is not deployed or merged; implementation and review are maintained
  in a draft pull request.

## Resolved review decisions

1. `staff_profiles` home school/campus describes employment placement; role
   assignments remain the sole authorization source. Null home placement is
   organization scope, and moves require manage authorization over both old and new
   scopes.
2. v0.3 exposes the full create/update/archive command set for all six aggregates,
   plus audited academic-year/term commands that close the legacy write boundary.
3. `academic_term_id` is optional for year-long sections; when present, section
   dates must also lie within that term.
4. Inactive sections may use draft or active periods, active sections require active
   periods, and closed/archived periods reject section create/update.
