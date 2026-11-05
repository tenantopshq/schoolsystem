# Staff administration

## Public UI boundary (v1.5)

The staff administration UI is read-only. `search_staff_profiles` and
`get_staff_admin_detail` are definer-owned, authenticated RPCs that enforce
`staff_profiles.view` or `staff_profiles.manage` at the requested or authoritative
staff home scope. They return an allowlisted projection of employment data and
ordinary display-name fields.

The projection deliberately excludes user IDs, membership IDs, email, phone,
avatar paths, role assignments, permissions, audit attribution, and authentication
data. The selected signed application context further narrows directory and detail
access; it never expands database authorization.

Staff managers may create an employment profile for an existing active organization
membership, update its employment metadata, or archive it. Identity invitation and
membership lifecycle remain owned by the identity module and are deliberately not
performed by the staff module. Names are immutable from the staff UI.

The v1.5 command RPCs wrap the existing academic command boundary with private,
actor-scoped replay receipts. Existing scope, parent-status, dependency, audit, and
outbox invariants continue to be enforced by the academic command layer. Archive
requires a bounded reason and records that reason in an additional atomic audit and
outbox event.

## Pagination and filtering

The directory supports a bounded query, employment-record status, and ascending
keyset pagination by normalized name plus staff number and UUID. Query text is
escaped before `ILIKE` matching. The adapter exposes an opaque base64url cursor and
requests one extra row to determine whether another page exists.

## Security invariants

- Staff-only administrators receive selectable contexts without needing a student permission.
- Anonymous, inactive-membership, missing-permission, cross-tenant, and wrong-campus reads are denied.
- Directory and detail responses contain only documented columns.
- Direct table mutation remains unavailable to browser roles.
- `staff_profiles.manage` is required for eligible-member search and all writes.
- Creation is limited to active organization memberships without a staff profile.
- Updates require authority over the authoritative home scope; browser forms do not move scope.
- Archive remains terminal and is blocked by active dependent records.
- Write commands are replay-safe and emit audit/outbox records in the same transaction.

## Deferred identity workflow

Inviting a new person, creating an authentication user, activating a membership,
and assigning roles are separate identity-administration operations. Until that UI
exists, an organization member must already exist before a staff manager can create
their employment profile.
