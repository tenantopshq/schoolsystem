# Admin UI staff management v1.5

## Outcome

Extend the v1.4 directory with the smallest secure employment-profile write flow:
create a profile for an existing active organization member, edit employment data,
and archive a profile with a reason.

## Decisions

1. `staff_profiles.manage` authorizes create, update, archive, and eligible-member lookup.
2. Staff creation consumes an existing active organization membership; it does not create authentication users, send invitations, or assign roles.
3. Identity names remain immutable from staff management.
4. Creation uses the selected school/campus as the staff home scope. v1.5 edit forms do not move scope.
5. Existing academic command functions remain the business-rule authority and are wrapped by replay-safe v1.5 RPCs.
6. Archive is terminal, requires a 1–500 character reason, and remains blocked by active dependencies such as teaching assignments.
7. The UI uses replay-safe v1.5 commands; legacy authorized RPCs remain temporarily available for backward compatibility and are not used by new application code.

## Included

- Additive migrations 016 and 017; earlier migrations remain immutable.
- Eligible active-member lookup with an allowlisted name projection.
- Replay-safe create, update, and archive commands.
- Permission-aware create/edit/archive UI and strict Zod contracts.
- Atomic audit/outbox history, generated database types, documentation, and adversarial pgTAP tests.

## Excluded

Identity invitations, authentication provisioning, membership activation, role
assignment, home-scope moves in the UI, contact details, documents, payroll,
workload, bulk import, deployment, and production staff creation.

## Verification

Fresh reset, the full pgTAP suite, generated types, frontend tests, strict typecheck,
production build, `git diff --check`, and an independent security review are required.
