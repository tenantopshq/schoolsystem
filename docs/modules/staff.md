# Staff administration

## Public UI boundary (v1.4)

The staff administration UI is read-only. `search_staff_profiles` and
`get_staff_admin_detail` are definer-owned, authenticated RPCs that enforce
`staff_profiles.view` or `staff_profiles.manage` at the requested or authoritative
staff home scope. They return an allowlisted projection of employment data and
ordinary display-name fields.

The projection deliberately excludes user IDs, membership IDs, email, phone,
avatar paths, role assignments, permissions, audit attribution, and authentication
data. The selected signed application context further narrows directory and detail
access; it never expands database authorization.

Staff creation and mutation remain on the existing academic command boundary and
are not exposed through v1.4. A future write UI must coordinate identity invitation,
membership lifecycle, and employment-profile creation rather than treating those as
independent browser operations.

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
- No audit or outbox record is created because v1.4 adds no write operation.
