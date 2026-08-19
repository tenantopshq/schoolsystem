# Security model

Authorization combines:

1. membership in an organization;
2. an active role assignment at organization, school, or campus scope;
3. a permission granted to that role;
4. contextual relationships added by each later domain; and
5. PostgreSQL RLS for every tenant-owned table.

RLS policies are operation-specific. Helper functions live in the private `app_auth` schema, use an empty `search_path`, and are not executable by anonymous users. Functions that bypass caller RLS must be small, stable, reviewed, and covered by adversarial tests.

The initial policies intentionally give only platform-management permissions access to foundation records. Teacher, guardian, and student relationship policies arrive with their domain tables.

No deletes are allowed through ordinary RLS policies for foundational records. Status transitions preserve history. `audit_log` and `event_outbox` are append-only to authenticated clients.

