begin;
create extension if not exists pgtap with schema extensions;
select plan(6);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, created_at, updated_at)
values
  ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'owner-a@example.test', '', now(), now()),
  ('20000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'user-b@example.test', '', now(), now());

insert into public.organizations (id, name, slug) values
  ('a0000000-0000-0000-0000-000000000001', 'Tenant A', 'tenant-a'),
  ('b0000000-0000-0000-0000-000000000002', 'Tenant B', 'tenant-b');
insert into public.organization_memberships (id, organization_id, user_id, status, joined_at) values
  ('a1000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'active', now()),
  ('b2000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000002', 'active', now());
insert into public.roles (id, organization_id, code, name) values
  ('a3000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'OWNER', 'Owner');
insert into public.role_permissions (organization_id, role_id, permission_id)
select 'a0000000-0000-0000-0000-000000000001', 'a3000000-0000-0000-0000-000000000001', id from public.permissions where code = 'organizations.manage';
insert into public.role_assignments (organization_id, organization_membership_id, role_id)
values ('a0000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001', 'a3000000-0000-0000-0000-000000000001');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"10000000-0000-0000-0000-000000000001","role":"authenticated"}', true);

select is((select count(*)::integer from public.organizations), 1, 'member sees only own tenant');
select is((select slug from public.organizations), 'tenant-a', 'cross-tenant row is hidden');
select ok(app_auth.is_org_member('a0000000-0000-0000-0000-000000000001'), 'active membership recognized');
select ok(not app_auth.is_org_member('b0000000-0000-0000-0000-000000000002'), 'foreign membership denied');
select ok(app_auth.has_permission('a0000000-0000-0000-0000-000000000001', 'organizations.manage'), 'granted permission recognized');
select ok(not app_auth.has_permission('a0000000-0000-0000-0000-000000000001', 'roles.manage'), 'missing permission denied');

select * from finish();
rollback;

