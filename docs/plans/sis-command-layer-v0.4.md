# SIS Command Layer v0.4 — Architecture Plan

## Review status

This approved plan is implemented locally by the additive migration
`202608190005_sis_command_layer_v0_4.sql`, its focused pgTAP suite, regenerated
database types, and the SIS TypeScript/documentation contracts. The five product
decisions in **Resolved product decisions** remain binding. Implementation is
unstaged and uncommitted pending coordinator review.

Migrations `202608190001` through `202608190004` remain immutable. No migration has
been deployed, no remote Supabase environment changed, and no pull request merged.

## Goal and module boundary

v0.4 completes audited, tenant-safe mutation boundaries for the SIS-owned records:

- students;
- guardians and student/guardian relationships;
- student identifiers;
- student addresses;
- student emergency contacts; and
- student-document metadata.

All ordinary clients retain read-only table access through forced RLS. Every write
is made through a narrow typed RPC which derives the actor and tenant scope, checks
application RBAC, locks authoritative rows, enforces lifecycle rules, and appends
audit and outbox records in the same transaction.

The following remain outside the v0.4 boundary:

- authentication-account creation and changes to `students.user_id` or
  `guardians.user_id`, which require a later higher-trust identity-link workflow;
- document upload authorization, storage-object creation, malware scanning,
  retention, download signing, and deletion, which belong to the storage service;
  SIS accepts only a server-created upload-intent capability after that external
  authorization, never a caller-supplied storage path;
- enrollment, grade/section placement, attendance, health, safeguarding, billing,
  and communications workflows; and
- self-service mutations by students or guardians.

The SIS module owns its command services and public event contracts. Other modules
must call those public services or react through the event outbox; they must not
import private SIS persistence code.

## Existing schema corrections in migration 005

Migration 005 will correct the v0.2 schema additively; it will not rewrite migrations
002 or 003.

### Lifecycle columns

Add `status public.record_status not null default 'active'` to:

- `public.student_identifiers`;
- `public.student_addresses`; and
- `public.student_emergency_contacts`.

Existing rows become active. Archived is terminal. New records may be created as
active or inactive but never archived; archive is reached only through a dedicated
command. Active and inactive are reversible only under the parent and permission
rules below. Update commands reject archived targets and cannot reactivate them.

Partial uniqueness must describe current operational state without erasing history:

- replace the all-history student/guardian pair constraint with non-archived
  uniqueness for `(student_id, guardian_id)` so an explicitly archived relationship
  can later be represented by a new link without rewriting history;
- replace the identifier uniqueness rule with active/non-archived uniqueness for
  `(student_id, normalized identifier_type, normalized identifier_value)`;
- make the one-primary-address-per-type index apply only to active rows; and
- make emergency-contact priority unique only among active rows for a student.

Normalization is `lower(btrim(...))` for case-insensitive business keys. Historical
archived values may recur in a new active row. Exact constraint/index names and the
safe dependency order will be asserted in pgTAP.

### Document upload intents

Add the minimal private capability table `public.student_document_upload_intents`:

```text
id uuid primary key
organization_id uuid not null
student_id uuid not null
storage_path text not null
expires_at timestamptz not null
consumed_at timestamptz null
consumed_by uuid null
created_at timestamptz not null
created_by uuid not null
```

The tenant/student relationship uses the same composite foreign key as document
metadata. `(organization_id, storage_path)` is unique among intents, and the document
command also checks the document table's existing unique constraint so a stored path
cannot be rebound. `expires_at` must be
after `created_at`, and `consumed_at`/`consumed_by` are both null or both non-null.
Indexes cover `(organization_id, student_id, id)`, unconsumed expiry lookup, creator,
and consumer foreign-key/traversal paths.

The table is an internal handoff between the storage service and SIS, not a browser
API. RLS is enabled and forced. `PUBLIC`, `anon`, and `authenticated` receive no
table privileges or policies. There is no authenticated RPC that creates, edits,
refreshes, or lists intents. The trusted storage service, after its own upload
authorization and path allocation, inserts an unconsumed intent through a separately
controlled server credential; explicit minimum `service_role` privileges are
limited to intent creation/inspection needed by that integration. It records the
end-user `created_by` as storage-service provenance, but SIS never treats that field
as command authority.

`create_student_document` accepts only the unguessable intent UUID. It locks the
intent, requires it to be unconsumed and unexpired, requires its student to equal the
locked command student, derives `organization_id` and immutable `storage_path` from
the intent, checks ordinary SIS permissions for `auth.uid()`, inserts metadata, and
sets `consumed_at`/`consumed_by` in the same transaction. A failed metadata, audit,
or outbox write rolls back consumption. Consumed or expired intents are terminal and
cannot be reused or revived. They are retained as capability provenance; no browser
cleanup command or hard-delete path is added in v0.4. Expired-intent retention is an
operational storage-service concern and does not authorize a document command.

### Relationship and traversal indexes

Migration 005 will inventory every foreign key and every authorization traversal.
It will add any missing leading indexes, including organization-leading access paths
where the current child-only indexes are insufficient. At minimum the review covers:

- student scope and old/new school/campus authorization;
- guardian-to-active-link and link-to-student traversals;
- organization/student/status paths for all student children;
- active primary link/address checks;
- emergency-contact guardian validation; and
- document organization/student/storage-path lookups.

pgTAP will compare foreign-key column order with leading index columns and separately
assert indexes used by RLS and guardian all-linked-students authorization.

### Multi-aggregate command correlation

Migration 004 introduced unique partial indexes on `audit_log.command_id` and
`event_outbox.command_id`, which correctly enforce its one-aggregate/one-event
academic commands but cannot represent the approved atomic guardian-plus-initial-
link command. Migration 005 will replace those two global single-column unique
indexes with uniqueness at the record identity level:

- audit: `(command_id, entity_type, entity_id)` where `command_id is not null`;
- outbox: `(command_id, event_type, aggregate_type, aggregate_id)` where
  `command_id is not null`.

This remains backward-compatible with academic commands, which continue to produce
exactly one audit and one event per command. It permits a deliberately reviewed
multi-aggregate command to share one server-generated correlation ID without
allowing duplicate audit/event records for the same changed aggregate. Regression
tests will prove both contracts.

### Permission catalog

Add:

```text
students.sensitive_manage
```

The permission authorizes identifier create/update/archive only when the actor also
has ordinary edit authority over the student at the same scope. It never implies
`students.sensitive_view`, `students.edit`, or `students.view`; roles requiring both
read and mutation must be granted each permission deliberately.

Existing permissions retain these meanings:

- `students.create`: create a student in assigned school/campus scope;
- `students.edit`: mutate student profiles, guardians, links, addresses, and
  emergency contacts in assigned student scope;
- `students.archive`: archive a student in assigned scope;
- `students.sensitive_view`: read identifiers for an otherwise visible student;
- `student_documents.manage`: manage document metadata for an otherwise editable
  student.

### Legacy policy cleanup and grants

Migration 003 already revoked authenticated table `INSERT` and `UPDATE`, but v0.2
write policies remain. Migration 005 will drop all SIS insert/update policies and
leave operation-specific authenticated select policies only. It will explicitly
revoke `INSERT`, `UPDATE`, `DELETE`, and `TRUNCATE` on every SIS table from
`PUBLIC`, `anon`, and `authenticated`; `anon` receives no table privileges.
Authenticated receives only the existing deliberate `SELECT` grants.

The existing `public.archive_student(uuid,text)` signature remains supported and is
reimplemented or routed through the v0.4 private command boundary without weakening
its current authorization, audit, outbox, or error behavior.

## Aggregate and lifecycle invariants

Across aggregates, status transitions are deliberate state changes. A transition
request may not also change business fields or structural scope; update arguments
for those fields must equal the locked current values. Active/inactive parent
records themselves may receive authorized content corrections. Inactive links and
inactive child rows may only be reactivated or archived, not content-edited. Archive
commands accept active or inactive targets and remain authorized from authoritative
stored scope even when a parent is inactive or archived. This is the cleanup path;
parent inactivity never converts into an authorization bypass or an unmanageable
orphan.

### Students

- `organization_id` is derived from the locked school/campus and never accepted as
  command input.
- Student number is normalized and unique within the organization.
- School is mandatory; campus is optional and, when supplied, must be an active
  campus in the selected active school and organization.
- A student may be created active or inactive, never archived.
- The legal student transitions are `active -> inactive`, `inactive -> active`, and
  `active|inactive -> archived`; no-op transitions and every transition out of
  archived are invalid. Reactivation requires active organization, school, and
  optional campus parents.
- A student may become inactive while active children or links exist. Inactivation
  disables new child/link creation and reactivation beneath that student but does
  not silently change existing children. Existing active children may be explicitly
  moved to inactive or archived, and inactive children may be archived, using the
  student's authoritative stored organization/school/campus scope even while the
  student is inactive or archived. This guarantees cleanup is not stranded.
- `organization_id` is immutable. A school/campus move is explicit in
  `update_student` and requires `students.edit` over both old and new scope.
- `user_id`, creator, updater, timestamps, tenant, audit data, and event data are
  never client-settable. `user_id` is unchanged by every v0.4 command.
- Date and bounded-text checks from v0.2 remain enforced. Exit date cannot precede
  admission date.
- Archived students are historical: profile updates, new child records, new links,
  child reactivation, and child content updates are rejected. Existing children
  remain readable according to RLS and may be archived for historical cleanup.
- `archive_student` is idempotency-rejecting: an already archived target is an
  error. The nonblank archive reason is audit/event context, not a column mutation.
- Student archival is blocked while active guardian links, identifiers, addresses,
  emergency contacts, or documents remain. Callers must explicitly archive those
  records first, producing a complete audit history; there is no hidden cascade.

### Guardians and student/guardian links

- A guardian cannot be created independently. `create_guardian_for_student` locks
  the student, derives its organization and scope, authorizes the actor, then creates
  the guardian and initial `student_guardians` link atomically.
- `guardians.organization_id` is derived from the student. `guardians.user_id` is
  always null on v0.4 creation and is immutable in all v0.4 commands.
- The guardian and initial link are created active. An archived student cannot be
  the context for creation.
- The legal guardian transitions are `active -> inactive`, `inactive -> active`, and
  `active|inactive -> archived`; archived is terminal and no-op transitions are
  invalid. A guardian may become inactive while active links exist; those links
  remain stored, but no new link may be added and portal access is ineffective while
  the guardian is inactive. Reactivation requires at least one active link to an
  active student and full authorization over every active link.
- Every guardian update must lock all active links and their students in
  deterministic student-ID order and require `students.edit` over every linked
  student's current scope. Authorization over one child is insufficient.
- A guardian with no active links cannot be updated through ordinary student
  context. Such orphan remediation is reserved for an administrative repair
  workflow, not organization-wide `students.edit` inference.
- Guardian archival is blocked until every link is inactive or archived and never
  silently changes links. To avoid stranding cleanup after the last link is no
  longer active, archive authorization is derived from every distinct historically
  linked student, including inactive/archived links, and requires `students.edit`
  over each student's authoritative stored scope. A v0.4 guardian always has at
  least one historical link because creation is atomic; missing history is treated
  as repair-only corruption and denied.
- Adding an existing guardian to another student derives the tenant from both locked
  records, requires an exact tenant match, active parents, and `students.edit` for
  the target student. The actor must also be authorized over every active student
  already linked to the guardian; this prevents an actor from discovering or
  extending a family identity they do not fully administer.
- Link updates and archive require edit authority over the linked student's stored
  scope, even if that student is inactive or archived. Reassigning a link to another
  student or guardian is forbidden; archive the old link and create a new one.
- The legal link transitions are `active -> inactive`, `inactive -> active`, and
  `active|inactive -> archived`. Deactivation and archive remain available for
  cleanup when a parent is inactive/archived. Reactivation requires both parents to
  be active and revalidates duplicate-link and primary-guardian rules. An inactive
  link may otherwise only be reactivated or archived; relationship metadata is
  changed while active.
- At most one active link exists for a student/guardian pair and at most one active
  primary guardian exists per student. Setting a new primary is rejected while a
  different active primary exists; callers explicitly update/archive the old link.
- Archived guardians and links are terminal. New links require active guardian and
  student parents.
- Portal access and notification/pickup flags are relationship metadata only; they
  do not grant staff command authority.

### Identifiers

- Parent student and tenant are derived from the locked student.
- Create, update, and archive require both `students.edit` and
  `students.sensitive_manage` at the student's scope.
- Identifier reads continue to require the existing sensitive-view rules; mutation
  permission does not silently grant read access.
- Identifier type/value are normalized for uniqueness. Issue/expiry dates retain
  their order constraint.
- `student_id` and `organization_id` are immutable. Archived identifiers cannot be
  changed or restored.
- The legal transitions are `active -> inactive`, `inactive -> active`, and
  `active|inactive -> archived`. Create/reactivate and content updates require an
  active parent student. Deactivation is allowed while the student is non-archived;
  archive remains allowed when the parent is active, inactive, or archived, using
  the student's stored scope.
- Neither audit nor outbox JSON may contain the raw identifier value, any substring
  of it, a reversible encoding, a hash, or a fingerprint. Audit snapshots replace
  `identifier_value` with the constant `"[REDACTED]"` and record only sorted changed
  field names plus non-secret metadata. A one-way fingerprint is deliberately not
  used because low-entropy government IDs can be brute-forced and the base table
  already enforces uniqueness.

### Addresses

- Create/update/archive require `students.edit` at the locked student's scope.
- Student/tenant are immutable. Create/reactivate and content updates require an
  active parent student. Deactivation is allowed under a non-archived parent;
  archive remains available under any parent status using stored student scope.
- Only one active primary address per normalized address type is allowed. Commands
  serialize on the parent student before checking or changing primary state.
- Archived rows remain historical and may not be updated or reactivated.
- Legal status transitions match identifiers: active/inactive are reversible only
  with an active parent for reactivation, and either state may be archived.

### Emergency contacts

- Create/update/archive require `students.edit` at the locked student's scope.
- Student/tenant are immutable. Optional `guardian_id` must identify an active
  same-tenant guardian actively linked to that student; an unrelated guardian UUID
  is rejected.
- Contact priority is unique among active contacts for a student. Commands serialize
  on the parent student before validating priority.
- Changing or clearing the optional guardian association is explicit through a
  nullable value plus `set_guardian_id`; it never changes the guardian record.
- Archived rows cannot be updated or reactivated.
- Legal status transitions and cleanup authorization match addresses. Reactivation
  revalidates the active student, optional active guardian/link, and priority.

### Student-document metadata

- Commands create, update, and archive relational metadata only. File bytes and
  storage authorization remain outside SIS.
- Create requires a server-created, unexpired, unconsumed upload-intent ID. The
  command locks and consumes the intent and derives `student_id`, tenant, and
  `storage_path`; no public caller can supply or override the path. SIS does not
  mint storage paths or upload, move, sign, delete, or probe storage objects.
- `storage_path`, `organization_id`, and `student_id` are immutable after creation.
  Correcting a path requires archiving the metadata row and creating a new one after
  separate storage authorization.
- Storage path remains unique per organization across all statuses so an archived
  metadata path cannot be rebound to a different record.
- Create/update/archive require both `students.edit` and
  `student_documents.manage` at the student's scope.
- Visibility is validated against the existing enum. Date order and nonnegative file
  size remain enforced. Archived metadata is terminal.
- Document metadata uses the same active/inactive/archive transition rules as other
  children: create/reactivate and content updates require an active student;
  deactivation is available under a non-archived student; archive remains available
  under any parent status using stored scope.
- Outbox events contain the metadata ID, type, visibility, and status but not the
  storage path, title, MIME details, or other potentially sensitive file metadata.

## Authorization and scope derivation

Authorization combines application RBAC and forced RLS:

- RLS governs reads and denies all direct ordinary writes.
- RPC commands are the sole mutation boundary and independently validate RBAC.
- `auth.uid()` is the only actor source. Null actor is rejected before mutation.
- Tenant and structural scope come only from locked authoritative rows.
- A client UUID is a lookup key, not proof of organization or scope.
- Membership must be active and not left; role, assignment, and assignment dates
  must be active/current as enforced by `app_auth.has_permission`.

Student create locks the active organization, school, and optional campus and derives
scope from them. Every child create locks the student and derives tenant/school/
campus from it. Updates and archives first lock the target, then lock its student or
other authoritative parents. Student moves validate both old and new scope.
Guardian updates calculate the complete active linked-student set under lock and
require permission for every row; an empty set is denied. Guardian archive instead
uses every historical linked student's authoritative stored scope so cleanup remains
possible after links/students become inactive or archived.

Permission matrix:

| Mutation | Required permission and scope |
|---|---|
| Create student | `students.create` at authoritative new school/campus |
| Update student profile or scope | `students.edit` at old scope; also new scope for a move |
| Archive student | `students.archive` at current scope |
| Create guardian | `students.edit` at the active initial student |
| Update/reactivate guardian | `students.edit` over every active linked student; empty set denied |
| Archive guardian | `students.edit` over every historically linked student's stored scope; active links must first be inactive/archived |
| Create/update/archive guardian link | `students.edit` at linked student, plus full guardian-linked scope for adding an existing guardian |
| Create/update/archive identifier | `students.edit` and `students.sensitive_manage` at student scope |
| Create/update/archive address | `students.edit` at student scope |
| Create/update/archive emergency contact | `students.edit` at student scope |
| Create/update/archive document metadata | `students.edit` and `student_documents.manage` at student scope |

No organization-wide fallback helper may turn a browser-supplied organization ID
into authority. `app_auth.has_permission_in_org` is not sufficient for SIS commands
whose target has a student scope.

## Private command architecture

Migration 005 will use private `app_auth` helpers and narrow public wrappers. The
preferred architecture is:

```text
public typed RPC
  -> app_auth.sis_command(command_name, target_id, args jsonb)
       -> target/parent locks and authoritative scope derivation
       -> permission and lifecycle assertions
       -> domain write
       -> app_auth.write_sis_change(...)
            -> audit_log + event_outbox with one command_id
```

Guardian creation uses a dedicated private helper because it writes two aggregates,
returns their two IDs, and writes two audit/event pairs. The public surface never exposes generic
operation names or arbitrary JSON. Private dispatchers accept JSON only as an
internal implementation detail behind reviewed typed wrappers.

All command/helper functions:

- are owned explicitly by `postgres`;
- use `SECURITY DEFINER` only where required to cross forced RLS/direct-grant
  boundaries;
- set `search_path = ''` and schema-qualify every relation, function, type, and
  built-in where practical;
- derive actor with `auth.uid()` and reject anonymous execution;
- expose no tenant, attribution, audit, event, or command-ID inputs;
- reject unknown operations and unexpected state transitions; and
- are revoked from `PUBLIC`, `anon`, `authenticated`, and `service_role` before the
  minimum deliberate grants are reapplied.

Only typed functions in `public` are executable by `authenticated` and explicitly
by `service_role`. Ordinary application requests must use the authenticated role;
the service role is not a shortcut around RBAC because the commands still require a
non-null actor and the same permission checks. Private mutation dispatchers and
audit writers are not executable by client roles. Read-only authorization helpers
receive only the execution grants required by RLS policies.

## Typed public RPC contract

The contract contains 21 public RPCs. Exact PostgreSQL parameter types and defaults will be frozen in migration 005 and
catalog-tested. No RPC accepts `organization_id`, `user_id`, actor fields,
timestamps, audit/event content, arbitrary JSON, or mutable storage paths.

```text
create_student(school_id uuid, campus_id uuid, student_number text,
  first_name text, middle_name text, last_name text, preferred_name text,
  date_of_birth date, gender text, nationality_code char(2),
  primary_language text, photo_path text, admission_date date, exit_date date,
  status record_status default 'active') returns uuid

update_student(id uuid, student_number text, first_name text, middle_name text,
  set_middle_name boolean, last_name text, preferred_name text,
  set_preferred_name boolean, date_of_birth date, gender text,
  set_gender boolean, nationality_code char(2), set_nationality_code boolean,
  primary_language text, set_primary_language boolean, photo_path text,
  set_photo_path boolean, admission_date date, set_admission_date boolean,
  exit_date date, set_exit_date boolean, status record_status,
  school_id uuid, set_school_id boolean, campus_id uuid,
  set_campus_id boolean) returns uuid

archive_student(target_student_id uuid, archive_reason text) returns uuid

create_guardian_for_student(student_id uuid, first_name text, middle_name text,
  last_name text, email text, phone text, alternate_phone text, occupation text,
  preferred_language text, relationship_type text, is_primary boolean,
  has_portal_access boolean, receives_academic_updates boolean,
  receives_attendance_alerts boolean, financial_responsibility boolean,
  pickup_authorized boolean)
  returns table(guardian_id uuid, student_guardian_id uuid)

update_guardian(id uuid, first_name text, middle_name text,
  set_middle_name boolean, last_name text, email text, set_email boolean,
  phone text, set_phone boolean, alternate_phone text,
  set_alternate_phone boolean, occupation text, set_occupation boolean,
  preferred_language text, set_preferred_language boolean,
  status record_status) returns uuid
archive_guardian(id uuid, archive_reason text) returns uuid

link_guardian_to_student(student_id uuid, guardian_id uuid,
  relationship_type text, is_primary boolean, has_portal_access boolean,
  receives_academic_updates boolean, receives_attendance_alerts boolean,
  financial_responsibility boolean, pickup_authorized boolean) returns uuid
update_student_guardian(id uuid, relationship_type text, is_primary boolean,
  has_portal_access boolean, receives_academic_updates boolean,
  receives_attendance_alerts boolean, financial_responsibility boolean,
  pickup_authorized boolean, status record_status) returns uuid
archive_student_guardian(id uuid, archive_reason text) returns uuid

create_student_identifier(student_id uuid, identifier_type text,
  identifier_value text, country_code char(2), issued_at date,
  expires_at date, status record_status default 'active') returns uuid
update_student_identifier(id uuid, identifier_type text, identifier_value text,
  country_code char(2), set_country_code boolean, issued_at date,
  set_issued_at boolean, expires_at date, set_expires_at boolean,
  status record_status) returns uuid
archive_student_identifier(id uuid, archive_reason text) returns uuid

create_student_address(student_id uuid, address_type text, line_1 text,
  line_2 text, city text, state_region text, postal_code text,
  country_code char(2), is_primary boolean,
  status record_status default 'active') returns uuid
update_student_address(id uuid, address_type text, line_1 text, line_2 text,
  set_line_2 boolean, city text, state_region text,
  set_state_region boolean, postal_code text, set_postal_code boolean,
  country_code char(2), is_primary boolean, status record_status) returns uuid
archive_student_address(id uuid, archive_reason text) returns uuid

create_student_emergency_contact(student_id uuid, guardian_id uuid,
  name text, relationship text, phone text, alternate_phone text,
  priority smallint, status record_status default 'active') returns uuid
update_student_emergency_contact(id uuid, guardian_id uuid,
  set_guardian_id boolean, name text, relationship text, phone text,
  alternate_phone text, set_alternate_phone boolean, priority smallint,
  status record_status) returns uuid
archive_student_emergency_contact(id uuid, archive_reason text) returns uuid

create_student_document(upload_intent_id uuid, document_type text, title text,
  mime_type text, file_size bigint, issued_at date,
  expires_at date, visibility student_document_visibility,
  status record_status default 'active') returns uuid
update_student_document(id uuid, document_type text, title text,
  mime_type text, set_mime_type boolean, file_size bigint,
  set_file_size boolean, issued_at date, set_issued_at boolean,
  expires_at date, set_expires_at boolean,
  visibility student_document_visibility, status record_status) returns uuid
archive_student_document(id uuid, archive_reason text) returns uuid
```

Nullable updates use an adjacent `set_<field>` flag: false preserves the stored
value; true applies the supplied value, including null to clear it. Required scalar
inputs are always applied. Commands reject `status = 'archived'` on create/update;
only archive RPCs produce that state. The implementation may split private
dispatchers for maintainability, but it must not change this typed public contract
without plan review.

`create_guardian_for_student` returns exactly one typed row containing the two
server-generated aggregate IDs. It exposes no command ID, tenant, actor, audit/event
fields, or caller-selected IDs. `create_student_document` exposes only the upload
intent capability ID; student, organization, and immutable storage path are derived
from the locked intent.

## Lock order and concurrency rules

The global SIS lock order is:

```text
organization -> school -> campus -> student -> guardian -> student_guardian
  -> identifier -> address -> emergency_contact -> document_upload_intent
  -> student_document
```

Rules:

- Targets are resolved before permission decisions but locked in the global parent-
  first order. If initial lookup is needed to discover parents, commands perform an
  unlocked lookup, then acquire locks in order and re-read/revalidate the target.
- Multiple rows at the same level are locked by ascending UUID.
- Guardian commands lock all active linked student IDs in ascending order, then the
  guardian and links consistently. Adding an existing guardian uses the union of the
  new student and existing active linked students, sorted by ID.
- Student create/move locks organization, old/new schools, and old/new campuses in
  ascending UUID within each level before checking status and permission.
- Address primary changes and emergency priority changes lock the parent student
  before uniqueness checks. Competing commands therefore serialize before partial
  unique indexes provide the final safety net.
- Student archive locks the student, then checks active children using the same
  parent lock acquired by child creates. Guardian archive and link creation share
  the guardian/student lock discipline. This closes check/write races.
- Emergency-contact commands lock the optional guardian and matching active link
  before accepting the association.
- Document creation performs an initial non-authoritative intent lookup to discover
  its student, then locks/revalidates the student before locking the intent. It
  rejects expired, consumed, mismatched, or replaced intent state and consumes it
  before inserting the document in the same transaction. Storage objects are never
  locked or queried by the SIS transaction.
- Unique/check/foreign-key constraints remain authoritative under concurrency.
  Expected constraint violations are mapped to stable, deliberate database errors
  where the public contract requires them.

Concurrency pgTAP tests will use two database sessions where supported, or catalog/
function-definition assertions plus transactional race harnesses, to prove that
concurrent primary-address, primary-guardian, priority, duplicate identifier,
student-archive/child-create, and guardian-link/update operations cannot violate
invariants or deadlock under the documented order.

## Audit and event-outbox contract

Every successful command generates a server-side `command_id`. The domain write,
audit write, and outbox write occur in one transaction. A single-row command writes
exactly one `audit_log` row and one `event_outbox` row. The atomic guardian creation
writes two audit rows and two outbox rows—one for the guardian and one for the
initial link—all sharing the same `command_id`. No command accepts a command ID from
the client.

Audit records contain derived organization and actor IDs, action, entity type/ID,
sorted changed-field names, and reviewed redacted before/after snapshots. Archive
reasons are included in the audit context. Identifier audit serialization is a
dedicated helper which removes the source value before JSON construction and emits
the constant `"[REDACTED]"`; generic `to_jsonb(student_identifiers.*)` is forbidden.
The sorted field list is stored under a reserved `_changed_fields` key in
`after_data`, and archive context under `_archive_reason`; neither key is accepted
from callers or copied from a domain row.
No raw, partial, encoded, hashed, or fingerprinted identifier value may enter
`audit_log` or `event_outbox`. Server-controlled `created_by`/`updated_by` always
equal `auth.uid()` for successful commands.

Outbox payloads are minimal integration contracts, not snapshots. Every payload
contains:

- `command_id`, `actor_user_id`, `organization_id`;
- `aggregate_id` and the applicable `student_id`/`guardian_id`/relationship ID;
- derived `school_id` and `campus_id` when student scope is relevant;
- sorted `changed_fields` for updates;
- `before_status` and `after_status` for lifecycle changes; and
- archive reason only for archive events.

Events:

| Aggregate | Events |
|---|---|
| Student | `student.created`, `student.updated`, `student.archived` |
| Guardian | `guardian.created`, `guardian.updated`, `guardian.archived` |
| Student guardian | `student.guardian_linked`, `student.guardian_updated`, `student.guardian_unlinked` |
| Identifier | `student.identifier_added`, `student.identifier_updated`, `student.identifier_archived` |
| Address | `student.address_added`, `student.address_updated`, `student.address_archived` |
| Emergency contact | `student.emergency_contact_added`, `student.emergency_contact_updated`, `student.emergency_contact_archived` |
| Document metadata | `student.document_added`, `student.document_updated`, `student.document_archived` |

Identifier values and any derivative representations never appear in outbox
payloads or audit snapshots. Document storage paths, titles,
MIME details, and file sizes never appear in outbox payloads. Guardian contact
details, addresses, contact phone numbers, birth dates, and other personal data are
also excluded; consumers receive IDs, scope, changed-field names, visibility/status,
and lifecycle facts only.

Any domain, audit, or outbox failure rolls back all effects. Tests will force audit
and outbox failures inside savepoints and assert absence of domain changes and
partial side effects, including both records from guardian-plus-initial-link create.
Upload-intent consumption is operational state supporting the document command, not
a separate domain event. The capability ID is excluded from both audit snapshots and
outbox payloads; rollback tests prove the intent remains unconsumed on failure.

## RLS, ownership, grants, and comments

- All eight SIS tables, including the private upload-intent table, are RLS-enabled
  and forced.
- Authenticated select policies continue to enforce staff scope, student self,
  linked-guardian access, sensitive identifier visibility, and document visibility.
- No insert/update/delete policy or ordinary table mutation grant remains.
- The upload-intent table has no client policy or grant; its explicit server-only
  integration grants do not extend to SIS domain tables or public intent creation.
- No hard-delete RPC exists.
- Every new function receives explicit owner, revoke, and grant statements using
  exact signatures; there are no regex grants, default-privilege assumptions, or
  schema-wide grants.
- Public RPCs are revoked from `PUBLIC` and `anon`, then granted only to
  `authenticated` and explicitly `service_role`.
- Private command, locking, authorization, audit, and outbox helpers are not granted
  to `authenticated`. RLS read helpers receive only necessary execute privileges.
- Function and table comments document security-definer intent, immutability,
  sensitive fields, storage-boundary assumptions, and lock order.
- Tests assert owners, `prosecdef`, empty search paths, exact execute privileges,
  absence of client table writes, and continued access to the pre-existing academic
  public RPCs.

## TypeScript integration

After migration and pgTAP implementation—not during this plan-only step—the local
database will be reset and `npm run db:types` will regenerate
`src/platform/database/database.types.ts` from the local schema. Generated database
types are never hand-maintained as a substitute for regeneration.

`src/modules/students/index.ts` will expose strict Zod schemas and inferred input
types for every public command. The application boundary will:

- use camelCase application DTOs and map explicitly to generated snake_case RPC
  arguments;
- reject unknown keys with strict schemas;
- validate UUIDs, ISO dates, enums, bounded/nonblank strings, country-code length,
  nonnegative file size, priority range, and nullable `set_` semantics;
- omit organization, actor, user-link, audit, event, and command-ID inputs entirely;
- accept a storage-service-issued upload-intent ID for document creation and expose
  neither `storagePath` nor an upload-authorization promise;
- use generated `Database["public"]["Functions"]` argument/return contracts so
  signature drift fails typecheck; and
- export a public SIS service interface while keeping Supabase persistence adapters
  private to the module.

Type-level or unit coverage will assert the typed two-ID guardian-create result and
that `userId`, `organizationId`, actor fields, document storage paths, and arbitrary
command payloads cannot enter the service contract. Runtime authorization remains
in PostgreSQL; TypeScript validation is defense in depth, not a replacement for
RBAC/RLS.

## Complete adversarial pgTAP matrix

### Schema and catalog

- lifecycle columns, defaults, nullability, enum types, terminal-state behavior;
- upload-intent columns, composite tenant/student foreign key, expiry/consumption
  checks, indexes, forced RLS, and server-only privileges;
- corrected partial uniqueness and normalized-key indexes;
- non-archived student/guardian pair uniqueness and archived re-link history;
- all composite tenant foreign keys and leading indexes;
- RLS enabled and forced on every SIS table;
- select-only authenticated grants and absence of anon/direct-write privileges;
- exact public/private function signatures, return types, owners, security mode,
  search paths, execute grants, and comments;
- permission seed uniqueness and preservation of existing permissions/functions.

### Baseline denial matrix for every aggregate and command family

- anonymous execution denied;
- unauthenticated/null actor denied even through an operational role;
- cross-tenant target/parent denied;
- same-tenant cross-school denied for school-scoped assignments;
- same-school cross-campus denied for campus-scoped assignments;
- missing permission denied;
- wrong permission denied (view does not edit, edit does not archive, sensitive view
  does not manage, document manage alone does not edit);
- inactive organization, school, campus, student, guardian, membership, role, or
  assignment denied where it is an active parent/actor prerequisite;
- invited, suspended, left, not-yet-started, and expired assignments denied;
- permitted same-tenant organization-, school-, and campus-scoped success;
- direct insert/update/delete/truncate denied even for a scoped manager;
- client attribution, organization, scope, status-archive, and event spoofing absent
  from or rejected by the public contract.

### Students

- active/inactive create success and archived initial status denial;
- active-to-inactive with active children succeeds without cascade; inactive-to-
  active revalidates active structural parents; no-op/archived transitions fail;
- authoritative organization derivation and mismatched campus/school rejection;
- normalized student-number collision, bounded fields, date rules;
- profile update, nullable clearing, and server attribution;
- old-only, new-only, neither, and both-scope authorization for school/campus moves;
- organization/user linkage immutability and absence from RPC signatures;
- archived target update/rearchive rejection;
- archive rejection for each active child type and success after explicit child
  archives;
- archive reason blank/null denial;
- child-create versus student-archive race safety.
- deactivation/archive of children remains possible under inactive/archived students
  from authoritative stored scope, while content update/reactivation is denied.

### Guardians and links

- guardian cannot be created without initial student context/link;
- guardian creation returns exactly `guardian_id` and `student_guardian_id`; both
  rows commit atomically with a shared command ID;
- duplicate link and second active primary rejection;
- cross-tenant guardian/link rejection;
- guardian update succeeds only with authority over every active linked student;
- denial when authority is missing over any one of multiple linked students;
- orphan guardian update denial;
- adding an existing guardian requires authority over the new student and all
  existing active linked students;
- deterministic multi-student locking and concurrent link/update safety;
- immutable guardian/student link endpoints and immutable guardian user linkage;
- portal-access flags affect guardian reads but not staff command authorization;
- guardian archive blocked by active links, link archive history preserved, archived
  parent/target terminal behavior.
- guardian active/inactive transitions with active links do not cascade; portal/new-
  link behavior follows guardian status; reactivation revalidates active links;
- inactive link content-update denial, active/inactive transition rules, and cleanup
  archive under inactive/archived student scope;
- guardian archive authorization succeeds from all historical linked-student scopes
  after links are inactive/archived, and fails if any historical scope is missing.

### Identifiers

- each of edit-only, sensitive-view-only, and sensitive-manage-only denied;
- combined edit plus sensitive-manage success at exact student scope;
- mutation permission does not grant identifier SELECT;
- normalized active duplicate rejection and archived-value reuse success;
- issue/expiry validation, immutable parent/tenant, terminal archive;
- audit before/after JSON uses the constant redaction marker and changed-field names;
  neither audit nor outbox contains the raw value, any substring, encoded form,
  digest, hash, or fingerprint.

### Addresses

- active primary uniqueness by normalized type;
- inactive/archived rows do not block a new active primary;
- concurrent primary changes serialize safely;
- nullable field clearing, immutable parent/tenant, archived terminal behavior;
- active-parent and scoped-edit enforcement.
- active/inactive transition, inactive content-update denial, reactivation-parent
  validation, and archive cleanup under inactive/archived student scope.

### Emergency contacts

- active priority uniqueness and archived-priority reuse;
- optional guardian must be active, same tenant, and actively linked to student;
- unrelated/cross-tenant/archived guardian denial;
- explicit guardian set/clear semantics and immutable student/tenant;
- concurrent priority mutation safety and archived terminal behavior.
- active/inactive transition, inactive content-update denial, reactivation-parent/
  guardian validation, and archive cleanup under inactive/archived student scope.

### Document metadata and storage boundary

- edit-only and document-manage-only denied; combined permissions succeed;
- authenticated callers cannot create/list/alter upload intents or supply a storage
  path to any document RPC;
- trusted server-created intent is locked, must match the derived student/tenant,
  must be unexpired/unconsumed, and yields the immutable path;
- expired, consumed, wrong-student, cross-tenant, missing, and concurrently consumed
  intent denial;
- successful document creation consumes exactly once; permission/validation/audit/
  outbox failures roll back consumption;
- storage path absent from update signature and unchanged by update/archive;
- organization-wide storage-path uniqueness includes archived rows;
- no storage API/object lookup occurs in the command definition;
- visibility/date/file-size validation and archived terminal behavior;
- active/inactive transition and cleanup behavior matches other child records;
- document visibility RLS remains correct for staff, guardian, student, unrelated,
  and cross-tenant actors;
- storage path and sensitive metadata absent from outbox.

### Audit, outbox, and regression

- exact audit/outbox counts per successful command;
- shared command ID and correct actor/organization/aggregate/scope attribution;
- changed-field sorting and event-specific payload allowlists;
- audit and outbox denylist assertions recursively inspect keys and values for raw,
  partial, encoded, hashed, or fingerprinted identifiers and inspect outbox for all
  forbidden personal/document fields;
- forced audit failure rolls back domain and outbox writes;
- forced outbox failure rolls back domain and audit writes;
- failed permission, invariant, uniqueness, and concurrency commands write no audit
  or event rows;
- existing SIS RLS self/guardian/staff behavior and `archive_student` contract remain
  compatible;
- all migration 001–004 pgTAP suites remain green, including Academic Foundation
  RPC grants and command behavior.

## Documentation and verification work after plan approval

Implementation will update:

- `docs/modules/sis.md` with the final command/access/event contract;
- architecture security/system-overview documentation if public interfaces,
  permissions, or invariants change;
- `src/modules/students/index.ts` with strict schemas and typed services;
- locally generated `src/platform/database/database.types.ts`;
- a focused `supabase/tests/sis_command_layer_v0_4_test.sql`; and
- existing regression tests only where additive assertions are needed.

Before implementation is declared complete, run:

```text
npm run db:reset
npm run db:test
npm run typecheck
npm run build
git diff --check
```

No remote migration deployment, production change, merge, or destructive operation
is part of v0.4 implementation without separate explicit authorization.

## Definition of done

- Coordinator approves this plan before migration 005 is created.
- Migration 005 is additive, transactional, and leaves migrations 001–004 unchanged.
- Every SIS mutation is available only through a reviewed typed RPC with derived
  tenant/scope and server-owned attribution.
- Guardian creation/linking and all-linked-student authorization follow the approved
  family safety boundary.
- Identifier/address/emergency-contact history is preserved through terminal archive
  states and status-aware uniqueness.
- Identity linkage is absent from v0.4 commands.
- Identifier mutations require both ordinary edit scope and
  `students.sensitive_manage`.
- Document creation consumes a locked, server-created, single-use upload intent and
  derives the immutable storage path; browsers cannot self-assert preauthorization,
  and upload authorization remains separate.
- Forced RLS plus select-only grants govern reads, while application RBAC is checked
  again inside every command.
- Lock order and constraints prevent cross-tenant, duplicate-primary, duplicate-
  priority, archive/create, and multi-student guardian races.
- Every successful important write produces complete audit history and a minimal,
  non-sensitive outbox event atomically; failures produce none.
- Exact ownership and grants expose only typed public RPCs.
- TypeScript schemas/services consume regenerated database RPC types under strict
  compilation.
- All adversarial pgTAP, regression, typecheck, and production-build checks pass.

## Resolved product decisions

1. Guardians are created through student context with the initial link atomically.
   Guardian updates require authorization over every active linked student.
2. Student identifiers, addresses, and emergency contacts receive lifecycle status
   and use audited archive-with-history rather than hard deletion.
3. Changes to `students.user_id` and `guardians.user_id` are excluded and reserved
   for a higher-trust identity workflow.
4. Sensitive identifier mutations require the new
   `students.sensitive_manage` permission in addition to ordinary student scope.
5. Document commands manage metadata only after consuming a storage-service-created,
   single-use upload intent from which immutable `storage_path` is derived; upload
   authorization remains a separate storage-service boundary.
