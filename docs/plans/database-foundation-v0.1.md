# Database Foundation v0.1

## Goal

Deliver the tenant, organization, identity, authorization, academic-period, audit, and integration primitives that every later school module can safely build upon.

## Included

- organizations, schools, campuses
- profiles and organization memberships
- roles, permissions, role permissions, and scoped role assignments
- academic years and academic terms
- append-only audit log and transactional event outbox
- timestamps, actor attribution, status constraints, uniqueness, foreign keys, and policy-path indexes
- RLS helpers and operation-specific policies
- a versioned permission catalog
- tenant-isolation and RBAC database tests

## Definition of done

- A fresh local environment rebuilds from Git without dashboard edits.
- RLS is enabled and forced on every tenant-owned table.
- Anonymous access and cross-tenant access fail.
- Active membership plus scoped permission allows the documented operation.
- Inactive/expired memberships and role assignments fail.
- Audit and outbox records cannot be updated or deleted by normal users.
- Permission-path indexes exist and database tests pass.
- Type checking and production web build pass.

## Delivery sequence

1. Run and review the baseline migration locally.
2. Execute pgTAP security tests with representative users and two tenants.
3. Generate TypeScript database types after the schema stabilizes.
4. Add application authorization services that call the same permission semantics.
5. Promote the identical migration to a disposable staging project.
6. Record an architecture decision before expanding to SIS v0.2.

## SIS v0.2 entry criteria

Foundation tests are green, access matrices are reviewed, backup/restore is exercised in staging, and no application path uses the service role to bypass user RLS.

