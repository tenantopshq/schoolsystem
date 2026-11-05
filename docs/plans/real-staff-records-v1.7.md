# Real Staff Records v1.7

## Outcome

Make a staff employment record the source of its own identity and contact fields,
with an optional link to platform membership. Administrators can create staff
without provisioning authentication or sending an invitation, and can later link
the record to one compatible active membership.

## Implementation plan

1. Add migration 019 to add and backfill staff identity/contact columns before
   making the membership link nullable. Replace the old always-linked uniqueness
   constraint with a partial unique index and keep tenant/scope foreign keys, forced
   RLS, direct-write revocations, and relationship indexes intact.
2. Add v1.7 typed read and replay-safe command RPCs. Reads project identity from the
   staff row and derive `access_state` as `no_access`, `invited`, `active`, or
   `suspended`; creates accept an optional membership; updates can link an unlinked
   record only to an active same-organization membership. Every write emits audit
   and outbox records atomically.
3. Update generated database types, strict Zod/domain contracts, the Supabase
   adapter, and Server Actions. Keep authorization at the authoritative tenant,
   school, and campus scope and keep browser table mutation unavailable.
4. Update create/edit/detail/directory UI for direct personal/contact fields,
   optional membership selection, and access-state display. Do not provision Auth,
   invite users, or mutate identity membership lifecycle.
5. Add adversarial pgTAP coverage for migration backfill, nullable membership,
   linking and duplicate-link protection, read access states, authorization denials,
   direct-write denial, and atomic history. Add domain/adapter/UI tests for linked
   and unlinked staff, then update staff/module/architecture documentation.
6. Develop with focused tests. When ready, run exactly one clean database reset,
   the complete pgTAP suite, frontend tests, typecheck, production build, and
   `git diff --check`; report exact results without deploying or pushing.

## Reviewed invariants

- Existing linked rows remain linked and retain copied profile values after the
  backfill; future profile edits do not rewrite staff history.
- First and last names are `NOT NULL`; null legacy profile names receive stable
  `Staff` and staff-number fallbacks, including through trusted legacy insert paths.
- The optional foreign key remains tenant-composite. A partial unique index permits
  many unlinked rows while enforcing one staff record per non-null membership.
- A membership link is append-only in v1.7: null may become an active compatible
  membership, but a non-null link cannot be replaced or cleared through commands.
- Membership lifecycle remains owned by identity-access. `left` is exposed as
  `suspended` because it grants no current access while preserving the historical
  link.
- Existing downstream operations that require a platform actor continue to require
  a linked active membership; merely creating an unlinked employment record does
  not grant teaching, attendance, grading, or report-signing authority.
- Superseded v1.5 create/update wrappers are non-executable; the supported archive
  command remains available. Matching v1.7 update replays return before transition
  checks and never duplicate audit/outbox effects.
