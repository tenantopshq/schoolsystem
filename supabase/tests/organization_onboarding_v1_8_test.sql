begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

select has_column('public','roles','system_role_key','roles have protected system key');
select has_function('public','bootstrap_organization_v1_8',array['uuid','text','text'],'bootstrap command exists');
select has_function('public','create_onboarding_school_v1_8',array['uuid','uuid','text','text'],'school command exists');
select has_function('public','create_onboarding_campus_v1_8',array['uuid','uuid','uuid','text','text'],'campus command exists');
select ok(not has_function_privilege('anon','public.bootstrap_organization_v1_8(uuid,text,text)','EXECUTE'),'anonymous bootstrap execution revoked');
select ok(has_function_privilege('authenticated','public.bootstrap_organization_v1_8(uuid,text,text)','EXECUTE'),'authenticated bootstrap exposed');
select ok(not exists(select 1 from aclexplode(coalesce((select relacl from pg_class where oid='public.roles'::regclass),acldefault('r',(select relowner from pg_class where oid='public.roles'::regclass))))x where x.grantee=0 and x.privilege_type=any(array['INSERT','UPDATE','DELETE','TRUNCATE'])),'PUBLIC role mutation revoked');
select ok(not exists(select 1 from aclexplode(coalesce((select relacl from pg_class where oid='public.role_permissions'::regclass),acldefault('r',(select relowner from pg_class where oid='public.role_permissions'::regclass))))x where x.grantee=0 and x.privilege_type=any(array['INSERT','UPDATE','DELETE','TRUNCATE'])),'PUBLIC role-permission mutation revoked');
select ok(not has_table_privilege('anon','public.roles','INSERT,UPDATE,DELETE,TRUNCATE') and not has_table_privilege('anon','public.role_permissions','INSERT,UPDATE,DELETE,TRUNCATE'),'anon protected role writes revoked');
select ok(not has_table_privilege('authenticated','public.roles','INSERT,UPDATE,DELETE,TRUNCATE') and not has_table_privilege('authenticated','public.role_permissions','INSERT,UPDATE,DELETE,TRUNCATE'),'authenticated protected role writes revoked');
select ok(not has_table_privilege('service_role','public.roles','INSERT,UPDATE,DELETE,TRUNCATE') and not has_table_privilege('service_role','public.role_permissions','INSERT,UPDATE,DELETE,TRUNCATE'),'service role protected role writes revoked');
select ok(not has_table_privilege('authenticated','public.schools','INSERT,UPDATE,DELETE'),'direct school writes revoked');
select ok(not has_table_privilege('authenticated','public.campuses','INSERT,UPDATE,DELETE'),'direct campus writes revoked');

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,created_at,updated_at) values
 ('a1800000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','owner-one@test','',now(),now()),
 ('a1800000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','owner-two@test','',now(),now()),
 ('a1800000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000000','authenticated','authenticated','co-owner@test','',now(),now());

set local role anon;
select throws_ok($$select public.bootstrap_organization_v1_8('a2800000-0000-0000-0000-000000000001','Denied Org','denied-org')$$,'42501','permission denied for function bootstrap_organization_v1_8','anonymous bootstrap denied');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a1800000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.bootstrap_organization_v1_8('a2800000-0000-0000-0000-000000000001','X',E' --- ')$$,'22023','valid organization name and slug are required','malformed bootstrap denied');
reset role;
select is((select count(*)::int from app_auth.onboarding_command_receipts where actor_user_id='a1800000-0000-0000-0000-000000000001'),0,'invalid input claims no receipt');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a1800000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select lives_ok($$select public.bootstrap_organization_v1_8('a2800000-0000-0000-0000-000000000002','  Alpha School Group  ',' Alpha   School Group ')$$,'owner bootstrap succeeds');
select lives_ok($$select public.bootstrap_organization_v1_8('a2800000-0000-0000-0000-000000000002','Alpha School Group','alpha-school-group')$$,'canonical replay succeeds');
select throws_ok($$select public.bootstrap_organization_v1_8('a2800000-0000-0000-0000-000000000002','Different Group','alpha-school-group')$$,'22023','request_id was reused with different arguments','mismatched replay denied');
select throws_ok($$select public.bootstrap_organization_v1_8('a2800000-0000-0000-0000-000000000003','Duplicate Group','alpha-school-group')$$,'23505','organization slug already exists','normalized slug uniqueness enforced');
reset role;

select is((select count(*)::int from public.organizations where slug='alpha-school-group'),1,'bootstrap creates one normalized organization');
select is((select count(*)::int from public.organization_memberships m join public.organizations o on o.id=m.organization_id where o.slug='alpha-school-group' and m.user_id='a1800000-0000-0000-0000-000000000001' and m.status='active'),1,'creator has one active membership');
select is((select count(*)::int from public.roles r join public.organizations o on o.id=r.organization_id where o.slug='alpha-school-group' and r.system_role_key='ORGANIZATION_OWNER'),1,'one protected owner role created');
select is((select count(*)::int from public.role_permissions rp join public.roles r on r.id=rp.role_id join public.organizations o on o.id=r.organization_id where o.slug='alpha-school-group' and r.system_role_key='ORGANIZATION_OWNER'),49,'owner has exact 49 permissions');
select is((select count(*)::int from public.audit_log a join public.organizations o on o.id=a.organization_id where o.slug='alpha-school-group' and a.action='organization.bootstrapped'),1,'bootstrap writes one audit row');
select is((select count(*)::int from public.event_outbox e join public.organizations o on o.id=e.organization_id where o.slug='alpha-school-group' and e.event_type='organization.bootstrapped'),1,'bootstrap writes one outbox row');
select is((select count(*)::int from public.organizations where name='Duplicate Group'),0,'failed duplicate bootstrap is atomic');

select throws_ok($q$do $b$ declare o uuid:=gen_random_uuid(); begin
 insert into public.organizations(id,name,slug)values(o,'Incomplete Owner Fixture','incomplete-owner-fixture');
 insert into public.roles(organization_id,code,name,description,is_system_role,status,system_role_key)
 values(o,'ORGANIZATION_OWNER','Organization Owner','System-managed organization owner',true,'active','ORGANIZATION_OWNER');
 set constraints all immediate;
end $b$$q$,'22023','protected organization owner role must have the fixed permission set','protected role cannot commit without permissions');

select throws_ok($$update public.roles set name='Weakened Owner' where system_role_key='ORGANIZATION_OWNER' and organization_id=(select id from public.organizations where slug='alpha-school-group')$$,'22023','protected organization owner role is immutable','protected owner cannot be renamed');
select throws_ok($$update public.roles set status='archived' where system_role_key='ORGANIZATION_OWNER' and organization_id=(select id from public.organizations where slug='alpha-school-group')$$,'22023','protected organization owner role is immutable','protected owner cannot be archived');
select throws_ok($$delete from public.roles where system_role_key='ORGANIZATION_OWNER' and organization_id=(select id from public.organizations where slug='alpha-school-group')$$,'22023','protected organization owner role is immutable','protected owner cannot be deleted');
select throws_ok($$delete from public.role_permissions where role_id=(select r.id from public.roles r join public.organizations o on o.id=r.organization_id where o.slug='alpha-school-group' and r.system_role_key='ORGANIZATION_OWNER') and permission_id=(select id from public.permissions where code='staff_profiles.manage')$$,'22023','protected organization owner permissions are immutable','required owner permission cannot be removed');
insert into public.permissions(code,module,description)values('test.extra','test','Test-only non-owner permission');
select throws_ok($$insert into public.role_permissions(organization_id,role_id,permission_id)
 select o.id,r.id,p.id from public.organizations o join public.roles r on r.organization_id=o.id cross join public.permissions p
 where o.slug='alpha-school-group' and r.system_role_key='ORGANIZATION_OWNER' and p.code='test.extra'$$,'22023','protected organization owner permission is not allowed','extra owner permission cannot be injected');
insert into public.roles(organization_id,code,name)select id,'CUSTOM_ADMIN','Custom Admin'from public.organizations where slug='alpha-school-group';
select lives_ok($$update public.roles set name='Renamed Custom Admin' where code='CUSTOM_ADMIN'$$,'ordinary custom role remains mutable');
select throws_ok($$update public.role_permissions set role_id=(select id from public.roles where code='CUSTOM_ADMIN')
 where role_id=(select r.id from public.roles r join public.organizations o on o.id=r.organization_id where o.slug='alpha-school-group' and r.system_role_key='ORGANIZATION_OWNER')
 and permission_id=(select id from public.permissions where code='staff_profiles.manage')$$,'22023','protected organization owner permissions are immutable','owner permission cannot be moved to a custom role');
select is((select count(*)::int from public.role_permissions rp join public.roles r on r.id=rp.role_id join public.organizations o on o.id=r.organization_id where o.slug='alpha-school-group' and r.system_role_key='ORGANIZATION_OWNER'),49,'failed relationship move preserves all 49 owner permissions');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a1800000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select lives_ok($$select public.create_onboarding_school_v1_8('a2800000-0000-0000-0000-000000000010',(select id from public.organizations where slug='alpha-school-group'),' Alpha Academy ',' aa ')$$,'owner creates school');
select lives_ok($$select public.create_onboarding_school_v1_8('a2800000-0000-0000-0000-000000000010',(select id from public.organizations where slug='alpha-school-group'),'Alpha Academy','AA')$$,'school replay succeeds');
select throws_ok($$select public.create_onboarding_school_v1_8('a2800000-0000-0000-0000-000000000011',(select id from public.organizations where slug='alpha-school-group'),'Duplicate Academy','aa')$$,'23505','school code already exists','organization-scoped school code unique');
select lives_ok($$select public.create_onboarding_campus_v1_8('a2800000-0000-0000-0000-000000000020',(select id from public.organizations where slug='alpha-school-group'),(select id from public.schools where code='AA' and organization_id=(select id from public.organizations where slug='alpha-school-group')),' Main Campus ',' main ')$$,'owner creates campus');
select lives_ok($$select public.create_onboarding_campus_v1_8('a2800000-0000-0000-0000-000000000020',(select id from public.organizations where slug='alpha-school-group'),(select id from public.schools where code='AA' and organization_id=(select id from public.organizations where slug='alpha-school-group')),'Main Campus','MAIN')$$,'campus replay succeeds');
select lives_ok($$select public.create_staff_profile_v1_7('a2800000-0000-0000-0000-000000000030',(select id from public.organizations where slug='alpha-school-group'),null,(select id from public.schools where code='AA' and organization_id=(select id from public.organizations where slug='alpha-school-group')),(select id from public.campuses where code='MAIN' and organization_id=(select id from public.organizations where slug='alpha-school-group')),'OWNER-STAFF','Owner',null,'Created',null,null,null,'employee','Administrator','Operations',null,'active')$$,'owner can create staff after onboarding');
reset role;
select is((select count(*)::int from public.schools s join public.organizations o on o.id=s.organization_id where o.slug='alpha-school-group' and s.code='AA'),1,'school replay creates no duplicate');
select is((select count(*)::int from public.campuses c join public.organizations o on o.id=c.organization_id where o.slug='alpha-school-group' and c.code='MAIN'),1,'campus replay creates no duplicate');
select is((select count(*)::int from public.audit_log a join public.organizations o on o.id=a.organization_id where o.slug='alpha-school-group' and a.action in('school.created','campus.created')),2,'school and campus each write one audit row');
select is((select count(*)::int from public.event_outbox e join public.organizations o on o.id=e.organization_id where o.slug='alpha-school-group' and e.event_type in('school.created','campus.created')),2,'school and campus each write one outbox row');

create temp table onboarding_test_ids as select id organization_id from public.organizations where slug='alpha-school-group';
grant select on onboarding_test_ids to authenticated;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a1800000-0000-0000-0000-000000000002","role":"authenticated"}',true);
select lives_ok($$select public.bootstrap_organization_v1_8('a2800000-0000-0000-0000-000000000040','Other Owner Group','other-owner-group')$$,'second owner bootstraps separate organization');
select throws_ok($$select * from public.get_my_organization_onboarding_state_v1_8((select organization_id from onboarding_test_ids))$$,'42501','active organization owner required','cannot resume another owner organization');
select throws_ok($$select public.create_onboarding_school_v1_8('a2800000-0000-0000-0000-000000000041',(select organization_id from onboarding_test_ids),'Attack School','ATTACK')$$,'42501','active organization owner required','cannot mutate another owner organization');
reset role;

insert into public.organization_memberships(id,organization_id,user_id,status,joined_at) select 'a3800000-0000-0000-0000-000000000003',id,'a1800000-0000-0000-0000-000000000003','active',now() from public.organizations where slug='alpha-school-group';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a1800000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select lives_ok($$select public.assign_access_role_v1_6('a2800000-0000-0000-0000-000000000050','a3800000-0000-0000-0000-000000000003',(select r.id from public.roles r join public.organizations o on o.id=r.organization_id where o.slug='alpha-school-group' and r.system_role_key='ORGANIZATION_OWNER'),null,null,now(),null)$$,'authorized owner may add co-owner');
reset role;
select ok(app_auth.is_active_organization_owner_v1_8((select id from public.organizations where slug='alpha-school-group'),'a1800000-0000-0000-0000-000000000003'),'co-owner assignment is effective');

update public.organization_memberships set status='suspended' where user_id='a1800000-0000-0000-0000-000000000003';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a1800000-0000-0000-0000-000000000003","role":"authenticated"}',true);
select throws_ok($$select * from public.get_my_organization_onboarding_state_v1_8((select id from public.organizations where slug='alpha-school-group'))$$,'42501','active organization owner required','inactive owner membership denied');
reset role;

select * from finish();
rollback;
