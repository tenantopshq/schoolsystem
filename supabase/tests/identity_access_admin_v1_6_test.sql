begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

select has_function('public','search_access_members',array['uuid','text','membership_status','integer'],'membership search exists');
select has_function('public','transition_access_membership_v1_6',array['uuid','uuid','membership_status','text'],'membership command exists');
select has_function('public','assign_access_role_v1_6',array['uuid','uuid','uuid','uuid','uuid','timestamp with time zone','timestamp with time zone'],'role assignment command exists');
select has_function('public','end_access_role_assignment_v1_6',array['uuid','uuid','text'],'assignment end command exists');
select ok(not has_table_privilege('authenticated','public.organization_memberships','INSERT,UPDATE,DELETE'),'direct membership writes revoked');
select ok(not has_table_privilege('authenticated','public.role_assignments','INSERT,UPDATE,DELETE'),'direct assignment writes revoked');
select ok(not has_function_privilege('anon','public.search_access_members(uuid,text,membership_status,integer)','EXECUTE'),'anonymous RPC denied');

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,created_at,updated_at)values
('f8000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','access-manager@test','',now(),now()),
('f8000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','access-target@test','',now(),now()),
('f8000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000000','authenticated','authenticated','access-none@test','',now(),now()),
('f8000000-0000-0000-0000-000000000004','00000000-0000-0000-0000-000000000000','authenticated','authenticated','access-inactive@test','',now(),now()),
('f8000000-0000-0000-0000-000000000005','00000000-0000-0000-0000-000000000000','authenticated','authenticated','access-other@test','',now(),now());
update public.profiles set display_name=case user_id when'f8000000-0000-0000-0000-000000000001'then'Access Manager'else'Access Target'end where user_id in('f8000000-0000-0000-0000-000000000001','f8000000-0000-0000-0000-000000000002');
insert into public.organizations(id,name,slug)values('f8000000-0000-0000-0000-000000000001','Access Tenant','access-tenant'),('f8000000-0000-0000-0000-000000000002','Other Access Tenant','other-access-tenant');
insert into public.schools(id,organization_id,name,code)values('f8000000-0000-0000-0000-000000000001','f8000000-0000-0000-0000-000000000001','Access School','ACS');
insert into public.campuses(id,organization_id,school_id,name,code)values('f8000000-0000-0000-0000-000000000001','f8000000-0000-0000-0000-000000000001','f8000000-0000-0000-0000-000000000001','Access Campus','ACC');
insert into public.organization_memberships(id,organization_id,user_id,status,joined_at)values
('f8000000-0000-0000-0000-000000000001','f8000000-0000-0000-0000-000000000001','f8000000-0000-0000-0000-000000000001','active',now()),
('f8000000-0000-0000-0000-000000000002','f8000000-0000-0000-0000-000000000001','f8000000-0000-0000-0000-000000000002','active',now()),
('f8000000-0000-0000-0000-000000000003','f8000000-0000-0000-0000-000000000001','f8000000-0000-0000-0000-000000000003','active',now()),
('f8000000-0000-0000-0000-000000000004','f8000000-0000-0000-0000-000000000001','f8000000-0000-0000-0000-000000000004','suspended',now()),
('f8000000-0000-0000-0000-000000000005','f8000000-0000-0000-0000-000000000002','f8000000-0000-0000-0000-000000000005','active',now());
insert into public.roles(id,organization_id,code,name)values
('f8000000-0000-0000-0000-000000000001','f8000000-0000-0000-0000-000000000001','ACCESS_ADMIN','Access Admin'),
('f8000000-0000-0000-0000-000000000002','f8000000-0000-0000-0000-000000000001','STUDENT_VIEWER','Student Viewer'),
('f8000000-0000-0000-0000-000000000003','f8000000-0000-0000-0000-000000000001','STUDENT_EDITOR','Student Editor');
insert into public.role_permissions(organization_id,role_id,permission_id)
select 'f8000000-0000-0000-0000-000000000001','f8000000-0000-0000-0000-000000000001',id from public.permissions where code in('organizations.manage','memberships.view','memberships.manage','roles.view','roles.manage','students.view');
insert into public.role_permissions(organization_id,role_id,permission_id)select'f8000000-0000-0000-0000-000000000001','f8000000-0000-0000-0000-000000000002',id from public.permissions where code='students.view';
insert into public.role_permissions(organization_id,role_id,permission_id)select'f8000000-0000-0000-0000-000000000001','f8000000-0000-0000-0000-000000000003',id from public.permissions where code='students.edit';
insert into public.role_assignments(id,organization_id,organization_membership_id,role_id,created_by,updated_by)values('f8000000-0000-0000-0000-000000000001','f8000000-0000-0000-0000-000000000001','f8000000-0000-0000-0000-000000000001','f8000000-0000-0000-0000-000000000001','f8000000-0000-0000-0000-000000000001','f8000000-0000-0000-0000-000000000001');

set local role anon;
select throws_ok($$select*from public.search_access_members('f8000000-0000-0000-0000-000000000001')$$,'42501','permission denied for function search_access_members','anonymous search denied');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"f8000000-0000-0000-0000-000000000003","role":"authenticated"}',true);
select throws_ok($$select*from public.search_access_members('f8000000-0000-0000-0000-000000000001')$$,'42501','membership view permission is required','missing permission denied');
select set_config('request.jwt.claims','{"sub":"f8000000-0000-0000-0000-000000000004","role":"authenticated"}',true);
select throws_ok($$select*from public.search_access_members('f8000000-0000-0000-0000-000000000001')$$,'42501','membership view permission is required','inactive membership denied');
select set_config('request.jwt.claims','{"sub":"f8000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select is((select count(*)::int from public.search_access_members('f8000000-0000-0000-0000-000000000001','Target')),1,'same-tenant member visible');
select throws_ok($$select*from public.search_access_members('f8000000-0000-0000-0000-000000000002')$$,'42501','membership view permission is required','cross-tenant search denied');
select throws_ok($$select public.assign_access_role_v1_6('f8000000-0000-0000-0000-000000000001','f8000000-0000-0000-0000-000000000002','f8000000-0000-0000-0000-000000000003',null,null,now(),null)$$,'42501','cannot grant permissions the actor does not hold','privilege escalation denied');
select lives_ok($$select public.assign_access_role_v1_6('f8000000-0000-0000-0000-000000000002','f8000000-0000-0000-0000-000000000002','f8000000-0000-0000-0000-000000000002','f8000000-0000-0000-0000-000000000001','f8000000-0000-0000-0000-000000000001','2026-11-05T00:00:00Z',null)$$,'permitted scoped role assigned');
select lives_ok($$select public.assign_access_role_v1_6('f8000000-0000-0000-0000-000000000002','f8000000-0000-0000-0000-000000000002','f8000000-0000-0000-0000-000000000002','f8000000-0000-0000-0000-000000000001','f8000000-0000-0000-0000-000000000001','2026-11-05T00:00:00Z',null)$$,'matching replay succeeds');
select is((select count(*)::int from public.role_assignments where organization_membership_id='f8000000-0000-0000-0000-000000000002'),1,'replay creates one assignment');
select lives_ok(format($q$select public.end_access_role_assignment_v1_6('f8000000-0000-0000-0000-000000000003',%L,'Access removed')$q$,(select id from public.role_assignments where organization_membership_id='f8000000-0000-0000-0000-000000000002')),'assignment ended');
select lives_ok($$select public.transition_access_membership_v1_6('f8000000-0000-0000-0000-000000000004','f8000000-0000-0000-0000-000000000002','suspended','Leave')$$,'membership suspended');
select is((select status::text from public.organization_memberships where id='f8000000-0000-0000-0000-000000000002'),'suspended','membership transition persisted');
select throws_ok($$select public.transition_access_membership_v1_6('f8000000-0000-0000-0000-000000000005','f8000000-0000-0000-0000-000000000001','suspended','Unsafe')$$,'22023','last organization administrator cannot be removed','last administrator protected');
reset role;
select is((select count(*)::int from public.audit_log where action in('role_assignment.created','role_assignment.ended','membership.suspended')),3,'commands write audit history');
select is((select count(*)::int from public.event_outbox where event_type in('role_assignment.created','role_assignment.ended','membership.suspended')),3,'commands write outbox events');

select*from finish();rollback;
