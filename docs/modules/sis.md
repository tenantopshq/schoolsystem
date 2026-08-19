# Student Information System v0.2

## Boundary

The SIS module owns student identity records, guardians and family relationships, identifiers, addresses, emergency contacts, and student-document metadata. It does not own academic placement. School and campus fields on `students` are administrative security scope; historical grade and section placement will be represented by enrollment records.

## Access matrix

| Actor | Student profile | Identifier | Address/contact | Document |
|---|---|---|---|---|
| Scoped staff with `students.view` | Read | No | Read | Read staff-visible |
| Scoped staff with `students.edit` | Read; mutation requires an implemented audited command | No direct write | Read; mutation requires an implemented audited command | Requires a document command and permission |
| Scoped staff with ordinary visibility plus `students.sensitive_view` | Read | Read | Read | Visibility still applies |
| Linked guardian with portal access | Linked children | Read | Read | Guardian/student-visible |
| Student with login | Self | Read | Read | Student-visible |
| Unrelated or cross-tenant user | Denied | Denied | Denied | Denied |

Authenticated clients have read-only access to SIS tables, governed by RLS. They cannot insert, update, or hard-delete SIS records directly. A permission such as `students.edit` describes authorization scope but does not itself make a mutation available: every mutation also requires an implemented audited command, and operations without one are denied.

Archival is currently the only implemented SIS mutation command. PostgREST exposes the narrow `public.archive_student` RPC wrapper, which invokes the private `app_auth.archive_student` implementation. The command requires scoped `students.archive`, owns actor attribution, and appends `audit_log` and `event_outbox` records atomically. The `app_auth` schema remains outside the exposed PostgREST schema list.

## Public events

- `student.created`
- `student.updated`
- `student.archived`
- `student.guardian_linked`
- `student.document_added`

Events are contracts for later modules; the database migration creates no business-logic triggers.

## Invariants

- Student numbers are unique within an organization.
- A login maps to at most one student and one guardian profile per organization.
- Student/guardian links cannot cross tenants.
- A student has at most one active primary guardian.
- Identifiers, addresses, contacts, and documents inherit tenant scope through composite foreign keys.
- Campus-leading student indexes support both composite campus foreign-key paths and scoped campus lookups.
- Document metadata is relational; file bytes remain in protected storage.
