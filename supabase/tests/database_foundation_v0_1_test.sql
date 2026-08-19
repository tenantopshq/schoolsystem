begin;
create extension if not exists pgtap with schema extensions;
select plan(13);

select has_table('public', 'organizations', 'organizations exists');
select has_table('public', 'organization_memberships', 'memberships exists');
select has_table('public', 'role_assignments', 'role assignments exist');
select has_table('public', 'audit_log', 'audit log exists');
select has_table('public', 'event_outbox', 'event outbox exists');

select ok((select relrowsecurity from pg_class where oid = 'public.organizations'::regclass), 'organizations has RLS');
select ok((select relforcerowsecurity from pg_class where oid = 'public.organizations'::regclass), 'organizations forces RLS');
select ok((select relrowsecurity from pg_class where oid = 'public.audit_log'::regclass), 'audit log has RLS');
select ok((select relforcerowsecurity from pg_class where oid = 'public.event_outbox'::regclass), 'outbox forces RLS');

select is(
  (
    select count(*)::integer
    from public.permissions
    where code in (
      'organizations.view','organizations.manage','schools.view','schools.manage',
      'memberships.view','memberships.manage','roles.view','roles.manage',
      'academic_periods.view','academic_periods.manage','audit.view'
    )
  ),
  11,
  'foundation permission catalog is seeded'
);
select has_index('public', 'organization_memberships', 'memberships_user_org_status_idx', 'membership policy path is indexed');
select has_index('public', 'role_assignments', 'role_assignments_membership_active_idx', 'assignment policy path is indexed');
select function_returns('app_auth', 'has_permission', array['uuid','text','uuid','uuid'], 'boolean', 'permission helper returns boolean');

select * from finish();
rollback;
