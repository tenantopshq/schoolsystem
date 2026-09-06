# Student Information System v0.4

## Boundary

The SIS module owns students, guardians and family relationships, identifiers,
addresses, emergency contacts, and student-document metadata. It does not own
authentication linkage, academic placement, or storage upload authorization.
`students.user_id` and `guardians.user_id` are intentionally immutable in v0.4.
School/campus fields on students are administrative security scope; enrollment owns
historical academic placement.

Authenticated clients have SELECT-only table access through forced RLS. All writes
use one of 21 typed `public` RPCs. The RPCs derive `auth.uid()`, organization, school,
and campus from locked authoritative rows; clients cannot provide tenant,
attribution, audit, event, command, or storage-path fields. Private `app_auth`
dispatchers and helpers are not executable by browser roles.

## Permissions and reads

| Permission | Capability |
|---|---|
| `students.view` | Read ordinary student profiles in assigned scope |
| `students.create` | Create students in assigned active school/campus scope |
| `students.edit` | Mutate ordinary SIS records through commands in student scope |
| `students.archive` | Archive students in scope after active children are cleared |
| `students.sensitive_view` | Read identifiers for an otherwise visible student |
| `students.sensitive_manage` | Mutate identifiers; also requires `students.edit` |
| `student_documents.manage` | Mutate document metadata; also requires `students.edit` |

Linked guardians with portal access can read linked students; logged-in students can
read themselves. Identifier reads retain their separate sensitive-view relationship
rules. Document reads also apply visibility. None of these read relationships grants
mutation authority.

Inactive, suspended, invited, left, not-yet-started, or expired membership/role
assignments do not authorize commands. Organization-, school-, and campus-scoped
roles operate only inside their authoritative scope. Student moves require
`students.edit` over both old and new scope. Guardian updates require edit authority
over every active linked student; guardian archive uses every historical linked
student's stored scope after active links are cleared.

## Public command inventory

| Aggregate | RPCs |
|---|---|
| Student | `create_student`, `update_student`, `archive_student` |
| Guardian | `create_guardian_for_student`, `update_guardian`, `archive_guardian` |
| Guardian link | `link_guardian_to_student`, `update_student_guardian`, `archive_student_guardian` |
| Identifier | `create_student_identifier`, `update_student_identifier`, `archive_student_identifier` |
| Address | `create_student_address`, `update_student_address`, `archive_student_address` |
| Emergency contact | `create_student_emergency_contact`, `update_student_emergency_contact`, `archive_student_emergency_contact` |
| Document metadata | `create_student_document`, `update_student_document`, `archive_student_document` |

`create_guardian_for_student` atomically creates the guardian and initial link and
returns `{ guardian_id, student_guardian_id }`. `archive_student(uuid,text)` retains
its published signature. Archive commands require a nonblank reason and expose no
hard-delete or reactivation-from-archived path.

The generated database types in `src/platform/database/database.types.ts` are the
adapter-level RPC contract. `src/modules/students/index.ts` exports strict camelCase
Zod command schemas, inferred application input types, the 21-name RPC union, typed
RPC argument/result aliases, event and permission unions, and `SisCommandService`.

## Lifecycle and concurrency

Active and inactive are reversible; archived is terminal. A status transition must
leave every business and scope field equal to the locked current row. Inactive links
and child rows may only reactivate or archive. Reactivation and new child creation
require active authoritative parents. Deactivation never cascades. Cleanup archives
remain available from stored student scope even when a parent is inactive or
archived, so history cannot become stranded.

Commands lock in this order:

```text
organization -> sorted schools -> sorted campuses -> sorted students
  -> guardian -> sorted links/children
```

Guardian commands discover, lock, and re-read their complete relevant link set. If
scope or links change concurrently, the command aborts with SQLSTATE `40001`; callers
may retry the complete command with bounded backoff. Constraint conflicts and
validation/authorization errors are not automatically retryable.

## Document upload capability

Document commands manage metadata only. A trusted storage service creates a
single-use, expiring upload intent after separate upload authorization. The create
RPC accepts only `upload_intent_id`, locks and consumes it atomically, and derives
the student, tenant, and immutable `storage_path`. Browser roles cannot create,
read, change, or reuse intents. The SIS command never uploads, probes, moves, signs,
or deletes storage objects.

`upload_intent_id`, `storage_path`, title, MIME type, and file size never appear in
document outbox payloads. The protected document audit snapshot may retain the
immutable storage path; the capability ID is not part of the domain snapshot.

## Audit and public events

Every successful single-aggregate command writes the domain row, exactly one
actor-attributed `audit_log` row, and exactly one `event_outbox` row in one
transaction. Guardian-plus-initial-link creation writes two audit rows and two
events sharing one server-generated `command_id`. Any failure rolls back domain,
audit, outbox, and upload-intent consumption effects.

Identifier audit snapshots replace `identifier_value` with `[REDACTED]`; neither
audit nor outbox contains raw, partial, encoded, hashed, or fingerprinted identifier
values. Outbox payloads contain identifiers and minimal lifecycle/scope facts, not
personal record snapshots.

Public events:

- `student.created`, `student.updated`, `student.archived`
- `guardian.created`, `guardian.updated`, `guardian.archived`
- `student.guardian_linked`, `student.guardian_updated`, `student.guardian_unlinked`
- `student.identifier_added`, `student.identifier_updated`, `student.identifier_archived`
- `student.address_added`, `student.address_updated`, `student.address_archived`
- `student.emergency_contact_added`, `student.emergency_contact_updated`, `student.emergency_contact_archived`
- `student.document_added`, `student.document_updated`, `student.document_archived`

## Core invariants

- Student numbers are normalized and unique within an organization.
- A login maps to at most one student and guardian profile per organization; v0.4
  cannot change those links.
- Every tenant relationship is enforced by composite foreign keys.
- Student/guardian relationships cannot cross tenants; one active primary guardian
  exists per student, and endpoint IDs are immutable.
- Guardian creation always includes its initial student link. Guardian updates lock
  and authorize the complete active linked-student set.
- Non-archived identifiers are unique by normalized type/value per student.
- One active primary address exists per normalized type and one active emergency
  priority exists per student.
- Emergency-contact guardian references use the effective stored/requested guardian
  and require an active same-tenant link whenever the contact is active.
- Document storage paths are organization-unique and immutable across metadata
  history; archived paths and consumed intents cannot be rebound.
- No SIS hard-delete RPC exists; archived history is immutable.

Teaching Assignments v0.6 adds a read-only contextual path to ordinary `students`
rows for currently effective rosters. It does not extend access to identifiers,
guardians or links, addresses, emergency contacts, documents, or any SIS mutation
command.

Assessment Foundation v0.8 snapshots student, enrollment, and placement provenance
at the assessment date. Later student or guardian lifecycle changes do not rewrite
assessment history. Active students and active linked guardians with portal access
may read only the applicable student's live published assessment result and teacher
comment; this relationship grants no broader SIS or assessment mutation access.

Term-grade portal visibility reuses those active relationships and exposes only the
applicable current published grade child, never provenance or classmates.
