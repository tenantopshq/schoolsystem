# Staff administration

## Real staff records (v1.7)

`staff_profiles` is the employment/person record and owns first, middle, last, and
display names plus work email and phone. `organization_membership_id` is an optional
access link, not the staff identity. Migration 019 copies existing linked
profile/auth values before relaxing the link, so earlier staff remain valid and
later identity-account changes do not rewrite employment history.
First and last name are database-required. Legacy inserts and migration backfill
copy profile names when available and otherwise use deterministic `Staff` and staff
number fallbacks.

Managers may create staff with no access or select an eligible active membership.
An unlinked record may later gain one active, same-organization membership. The
partial unique link prevents a membership from representing multiple staff records;
v1.7 commands never clear or replace an established link. Creating or linking staff
does not create an Auth user, send an invitation, activate membership, or assign a
role.

Reads derive access state: `no_access` when unlinked, `invited` for an invited
historical link, `active` for a current active membership, and `suspended` for a
suspended or left membership. This state is separate from employment status.

## Public UI boundary

The staff administration read boundary uses `search_staff_profiles` and
`get_staff_admin_detail` are definer-owned, authenticated RPCs that enforce
`staff_profiles.view` or `staff_profiles.manage` at the requested or authoritative
staff home scope. They return an allowlisted projection of employment data and
staff-owned identity/contact fields and derived access state.

The projection excludes user IDs, authentication data, private profile data, avatar
paths, role assignments, permissions, and audit attribution. The selected signed
application context further narrows directory and detail access; it never expands
database authorization.

Staff managers may create or update personal, contact, and employment fields and
archive the record. Identity invitation and membership lifecycle remain owned by
the identity module.

The v1.5 command RPCs wrap the existing academic command boundary with private,
actor-scoped replay receipts. Existing scope, parent-status, dependency, audit, and
outbox invariants continue to be enforced by the academic command layer. Archive
requires a bounded reason and records that reason in an additional atomic audit and
outbox event.

Migration 019 revokes the superseded v1.5 create and update wrappers from every
browser/service role; the supported reason-bearing v1.5 archive command remains.
The v1.7 update command claims its replay receipt after authoritative scope
authorization and argument hashing but before lifecycle/link transition checks, so
a matching successful membership-link replay returns its original result without
duplicating history.

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
- Creation may be unlinked; any supplied link must be an active compatible
  organization membership without another staff profile.
- A link may be added later but cannot be cleared or replaced by v1.7 commands.
- Updates require authority over the authoritative home scope; browser forms do not move scope.
- Archive remains terminal and is blocked by active dependent records.
- Write commands are replay-safe and emit audit/outbox records in the same transaction.

## Identity workflow boundary

Inviting a new person, creating an authentication user, activating a membership,
and assigning roles are separate identity-administration operations. Until that UI
exists, an organization member must already exist before a staff manager can create
their employment profile.
