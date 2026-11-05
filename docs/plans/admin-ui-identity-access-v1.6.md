# Admin UI identity and access v1.6

## Outcome

Add a secure organization-level UI for reviewing memberships and assigning existing
roles. This closes the access-management gap needed by staff administration without
introducing a service-role credential into ordinary application requests.

## Approved implementation scope

- Organization-context membership directory and member detail.
- Allowlisted identity projection: membership id, name, email, membership status,
  staff number, and current role assignments.
- Activate invited or suspended memberships, suspend active memberships, and end
  memberships permanently with a bounded reason.
- Assign an existing active role at organization, school, or campus scope and end an
  assignment with a bounded reason.
- Preview the permissions carried by a role before assignment.
- Replay-safe commands, deterministic locks, atomic audit/outbox records, strict
  Zod contracts, generated database types, and adversarial pgTAP tests.

## Security decisions

1. Membership management requires organization-scoped `memberships.manage`.
2. Role assignment requires `roles.manage` at the target scope.
3. An actor may assign a role only when they currently hold every permission in that
   role at the target scope. Client-supplied organization and role contents are never
   trusted.
4. School and campus scope are derived and validated against active parents in the
   target organization.
5. The final active organization-wide administrator cannot be suspended, ended, or
   stripped of the assignment carrying `organizations.manage`.
6. A membership in `left` is terminal. Suspended memberships may be reactivated;
   invited memberships may be activated only after the Auth user already exists.
7. Direct browser writes to membership and role-assignment tables are revoked. New
   UI code uses command RPCs only.
8. Read RPCs return explicit allowlisted columns. Auth metadata other than email is
   never returned.

## Deferred

Email invitations and Auth-user provisioning, custom role/permission editing, bulk
operations, password administration, SSO/SCIM, guardian/student accounts, and
production deployment. Invitation delivery needs a separately reviewed trusted
backend boundary; it must not expose or use a service-role key in browser code.

## Verification

Fresh reset, full pgTAP, generated types, frontend tests, strict typecheck,
production build, `git diff --check`, and an independent security review.
