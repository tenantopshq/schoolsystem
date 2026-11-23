# Organizations and onboarding

The organizations module owns administrative context selection and the v1.8
organization onboarding boundary. Authenticated users may bootstrap multiple
organizations. Each bootstrap atomically creates an active creator membership, an
immutable system-managed `ORGANIZATION_OWNER` role, its fixed current
administrative permission set, an organization-wide assignment, and correlated
audit/outbox records.

Organization, school, and campus commands are typed, replay-safe RPCs. They derive
the actor from `auth.uid()`, normalize and validate inputs before claiming a replay
receipt, lock authoritative parents in deterministic order, and never accept role,
permission, membership, actor, or integration-payload authority from the caller.

The owner role is protected by database constraints and immediate/deferred triggers.
It cannot be renamed, archived, deleted, converted, weakened, or extended beyond
the fixed permission catalog. The deferred exact-set invariant fires for protected
role mutations as well as role-permission mutations, so a protected role cannot
commit without all required grants. Authorized owners may assign the existing role
to co-owners through the identity-access command; ordinary custom roles remain
independent.

Onboarding state is always derived for an explicitly selected organization and
school. Supplied identifiers are reauthorized against an active owner membership
and organization-wide protected assignment on every request. Completion selects an
existing authorized campus context through the signed-cookie context service.
