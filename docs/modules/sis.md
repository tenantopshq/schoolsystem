# Student Information System v0.2

## Boundary

The SIS module owns student identity records, guardians and family relationships, identifiers, addresses, emergency contacts, and student-document metadata. It does not own academic placement. School and campus fields on `students` are administrative security scope; historical grade and section placement will be represented by enrollment records.

## Access matrix

| Actor | Student profile | Identifier | Address/contact | Document |
|---|---|---|---|---|
| Scoped staff with `students.view` | Read | No | Read | Read staff-visible |
| Scoped staff with `students.edit` | Read/write | Write | Read/write | Requires document permission |
| Scoped staff with `students.sensitive_view` | Read | Read | Read | Visibility still applies |
| Linked guardian with portal access | Linked children | Read | Read | Guardian/student-visible |
| Student with login | Self | Read | Read | Student-visible |
| Unrelated or cross-tenant user | Denied | Denied | Denied | Denied |

Ordinary authenticated users cannot hard-delete SIS records. Archival uses status transitions. Every application service that mutates SIS data must append an `audit_log` row and the appropriate `event_outbox` record in the same transaction.

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
- Document metadata is relational; file bytes remain in protected storage.

