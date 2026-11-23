# Identity and access administration

The v1.6 administrative boundary exposes allowlisted organization-membership and
role-assignment reads. It never exposes authentication metadata other than the
member email required for administrator identification.

Membership lifecycle and role assignment changes use replay-safe definer-owned
commands. Browser roles cannot mutate membership, role, permission, or assignment
tables directly. Commands derive tenant and current state from authoritative rows,
enforce organization-level membership management, scoped role management,
anti-escalation rules, compatible active school/campus parents, and protection for
the final organization administrator. Every successful change writes audit and
outbox records atomically.

The v1.8 `ORGANIZATION_OWNER` role is system-managed by the database and cannot be
edited through identity administration. An authorized owner may assign that
existing role to another active member only through the v1.6 assignment command,
which retains its no-escalation and last-administrator protections.

Auth invitation delivery and user provisioning remain outside this module until a
separate trusted backend boundary is approved. Service-role credentials are never
sent to or used by browser code.
