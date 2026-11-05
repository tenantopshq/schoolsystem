begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

select col_is_null('public','staff_profiles','organization_membership_id','membership link is nullable');
select has_column('public','staff_profiles','first_name','staff owns first name');
select col_not_null('public','staff_profiles','first_name','staff first name is database-required');
select col_not_null('public','staff_profiles','last_name','staff last name is database-required');
select has_column('public','staff_profiles','work_email','staff owns work email');
select has_index('public','staff_profiles','staff_profiles_org_membership_linked_key','linked memberships have a partial unique index');
select ok(not has_table_privilege('authenticated','public.staff_profiles','INSERT'),'browser cannot insert staff directly');
select ok(not has_table_privilege('authenticated','public.staff_profiles','UPDATE'),'browser cannot update staff directly');
select ok(not has_function_privilege('anon','public.create_staff_profile_v1_7(uuid,uuid,uuid,uuid,uuid,text,text,text,text,text,text,text,text,text,text,date,record_status)','EXECUTE'),'anonymous create denied');
select ok(has_function_privilege('authenticated','public.create_staff_profile_v1_7(uuid,uuid,uuid,uuid,uuid,text,text,text,text,text,text,text,text,text,text,date,record_status)','EXECUTE'),'authenticated create command exposed');
select ok(not has_function_privilege('anon','public.create_staff_profile_v1_5(uuid,uuid,uuid,uuid,text,text,text,text,date,record_status)','EXECUTE'),'anonymous cannot execute legacy create');
select ok(not has_function_privilege('authenticated','public.create_staff_profile_v1_5(uuid,uuid,uuid,uuid,text,text,text,text,date,record_status)','EXECUTE'),'authenticated cannot execute legacy create');
select ok(not has_function_privilege('service_role','public.create_staff_profile_v1_5(uuid,uuid,uuid,uuid,text,text,text,text,date,record_status)','EXECUTE'),'service role cannot execute legacy create');
select ok(not exists(select 1 from pg_proc p cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) x where p.oid='public.create_staff_profile_v1_5(uuid,uuid,uuid,uuid,text,text,text,text,date,record_status)'::regprocedure and x.grantee=0 and x.privilege_type='EXECUTE'),'PUBLIC cannot execute legacy create');
select ok(not has_function_privilege('anon','public.update_staff_profile_v1_5(uuid,uuid,text,text,record_status,uuid,boolean,uuid,boolean,text,boolean,text,boolean,date,boolean,date,boolean)','EXECUTE'),'anonymous cannot execute legacy update');
select ok(not has_function_privilege('authenticated','public.update_staff_profile_v1_5(uuid,uuid,text,text,record_status,uuid,boolean,uuid,boolean,text,boolean,text,boolean,date,boolean,date,boolean)','EXECUTE'),'authenticated cannot execute legacy update');
select ok(not has_function_privilege('service_role','public.update_staff_profile_v1_5(uuid,uuid,text,text,record_status,uuid,boolean,uuid,boolean,text,boolean,text,boolean,date,boolean,date,boolean)','EXECUTE'),'service role cannot execute legacy update');
select ok(not exists(select 1 from pg_proc p cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) x where p.oid='public.update_staff_profile_v1_5(uuid,uuid,text,text,record_status,uuid,boolean,uuid,boolean,text,boolean,text,boolean,date,boolean,date,boolean)'::regprocedure and x.grantee=0 and x.privilege_type='EXECUTE'),'PUBLIC cannot execute legacy update');
select ok(has_function_privilege('authenticated','public.archive_staff_profile_v1_5(uuid,uuid,text)','EXECUTE'),'supported archive command remains executable');

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,created_at,updated_at) values
 ('c1000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','v17-manager@test','',now(),now()),
 ('c1000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','v17-none@test','',now(),now()),
 ('c1000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000000','authenticated','authenticated','v17-inactive@test','',now(),now()),
 ('c1000000-0000-0000-0000-000000000011','00000000-0000-0000-0000-000000000000','authenticated','authenticated','v17-link1@test','',now(),now()),
 ('c1000000-0000-0000-0000-000000000012','00000000-0000-0000-0000-000000000000','authenticated','authenticated','v17-link2@test','',now(),now()),
 ('c1000000-0000-0000-0000-000000000013','00000000-0000-0000-0000-000000000000','authenticated','authenticated','v17-invited@test','',now(),now()),
 ('c1000000-0000-0000-0000-000000000014','00000000-0000-0000-0000-000000000000','authenticated','authenticated','v17-suspended@test','',now(),now()),
 ('c1000000-0000-0000-0000-000000000015','00000000-0000-0000-0000-000000000000','authenticated','authenticated','v17-null-names@test','',now(),now());
update public.profiles set first_name='Old',last_name='Identity',display_name='Old Display',phone='old-phone' where user_id='c1000000-0000-0000-0000-000000000011';

insert into public.organizations(id,name,slug) values
 ('c2000000-0000-0000-0000-000000000001','V17 Tenant','v17-tenant'),
 ('c2000000-0000-0000-0000-000000000002','V17 Other','v17-other');
insert into public.schools(id,organization_id,name,code) values
 ('c3000000-0000-0000-0000-000000000001','c2000000-0000-0000-0000-000000000001','V17 School','V17'),
 ('c3000000-0000-0000-0000-000000000002','c2000000-0000-0000-0000-000000000002','Other School','OTH');
insert into public.campuses(id,organization_id,school_id,name,code) values
 ('c4000000-0000-0000-0000-000000000001','c2000000-0000-0000-0000-000000000001','c3000000-0000-0000-0000-000000000001','Managed Campus','M'),
 ('c4000000-0000-0000-0000-000000000002','c2000000-0000-0000-0000-000000000001','c3000000-0000-0000-0000-000000000001','Denied Campus','D'),
 ('c4000000-0000-0000-0000-000000000003','c2000000-0000-0000-0000-000000000002','c3000000-0000-0000-0000-000000000002','Other Campus','O');
insert into public.organization_memberships(id,organization_id,user_id,status,joined_at) values
 ('c5000000-0000-0000-0000-000000000001','c2000000-0000-0000-0000-000000000001','c1000000-0000-0000-0000-000000000001','active',now()),
 ('c5000000-0000-0000-0000-000000000002','c2000000-0000-0000-0000-000000000001','c1000000-0000-0000-0000-000000000002','active',now()),
 ('c5000000-0000-0000-0000-000000000003','c2000000-0000-0000-0000-000000000001','c1000000-0000-0000-0000-000000000003','suspended',now()),
 ('c5000000-0000-0000-0000-000000000011','c2000000-0000-0000-0000-000000000001','c1000000-0000-0000-0000-000000000011','active',now()),
 ('c5000000-0000-0000-0000-000000000012','c2000000-0000-0000-0000-000000000002','c1000000-0000-0000-0000-000000000012','active',now()),
 ('c5000000-0000-0000-0000-000000000013','c2000000-0000-0000-0000-000000000001','c1000000-0000-0000-0000-000000000013','invited',null),
 ('c5000000-0000-0000-0000-000000000014','c2000000-0000-0000-0000-000000000001','c1000000-0000-0000-0000-000000000014','suspended',now()),
 ('c5000000-0000-0000-0000-000000000015','c2000000-0000-0000-0000-000000000001','c1000000-0000-0000-0000-000000000015','active',now());
insert into public.roles(id,organization_id,code,name) values ('c6000000-0000-0000-0000-000000000001','c2000000-0000-0000-0000-000000000001','V17_MANAGER','V17 Manager');
insert into public.role_permissions(organization_id,role_id,permission_id)
 select 'c2000000-0000-0000-0000-000000000001','c6000000-0000-0000-0000-000000000001',id from public.permissions where code in('staff_profiles.view','staff_profiles.manage');
insert into public.role_assignments(id,organization_id,organization_membership_id,role_id,school_id,campus_id) values
 ('c7000000-0000-0000-0000-000000000001','c2000000-0000-0000-0000-000000000001','c5000000-0000-0000-0000-000000000001','c6000000-0000-0000-0000-000000000001','c3000000-0000-0000-0000-000000000001','c4000000-0000-0000-0000-000000000001'),
 ('c7000000-0000-0000-0000-000000000003','c2000000-0000-0000-0000-000000000001','c5000000-0000-0000-0000-000000000003','c6000000-0000-0000-0000-000000000001','c3000000-0000-0000-0000-000000000001','c4000000-0000-0000-0000-000000000001');

-- Rows model pre-existing linked data after migration backfill and access-state variants.
insert into public.staff_profiles(id,organization_id,organization_membership_id,school_id,campus_id,staff_number,first_name,last_name,display_name,work_email,phone,employment_type) values
 ('c8000000-0000-0000-0000-000000000011','c2000000-0000-0000-0000-000000000001','c5000000-0000-0000-0000-000000000011','c3000000-0000-0000-0000-000000000001','c4000000-0000-0000-0000-000000000001','BACKFILL','Old','Identity','Old Display','v17-link1@test','old-phone','employee'),
 ('c8000000-0000-0000-0000-000000000013','c2000000-0000-0000-0000-000000000001','c5000000-0000-0000-0000-000000000013','c3000000-0000-0000-0000-000000000001','c4000000-0000-0000-0000-000000000001','INVITED','Invite','Person',null,'invite@school.test',null,'employee'),
 ('c8000000-0000-0000-0000-000000000014','c2000000-0000-0000-0000-000000000001','c5000000-0000-0000-0000-000000000014','c3000000-0000-0000-0000-000000000001','c4000000-0000-0000-0000-000000000001','SUSPEND','Suspended','Person',null,'suspended@school.test',null,'employee'),
 ('c8000000-0000-0000-0000-000000000015','c2000000-0000-0000-0000-000000000001','c5000000-0000-0000-0000-000000000015','c3000000-0000-0000-0000-000000000001','c4000000-0000-0000-0000-000000000001','NULLNAMES','Staff','NULLNAMES',null,'v17-null-names@test',null,'employee');
update public.profiles set first_name='Changed',last_name='Profile',display_name='Changed Profile',phone='changed-phone' where user_id='c1000000-0000-0000-0000-000000000011';
select is((select first_name||' '||last_name||':'||phone from public.staff_profiles where staff_number='BACKFILL'),'Old Identity:old-phone','backfilled staff identity is preserved independently');
select ok((select pr.first_name is null and pr.last_name is null from public.profiles pr where pr.user_id='c1000000-0000-0000-0000-000000000015'),'legacy linked profile fixture has null names');
select is((select first_name||':'||last_name from public.staff_profiles where staff_number='NULLNAMES'),'Staff:NULLNAMES','legacy linked staff with null profile names receives deterministic fallbacks');

set local role authenticated;
select set_config('request.jwt.claims','{}',true);
select throws_ok($$select * from public.search_staff_profiles('c2000000-0000-0000-0000-000000000001')$$,'42501','authenticated actor required','anonymous read denied');
select set_config('request.jwt.claims','{"sub":"c1000000-0000-0000-0000-000000000002","role":"authenticated"}',true);
select throws_ok($$select * from public.search_staff_profiles('c2000000-0000-0000-0000-000000000001','c3000000-0000-0000-0000-000000000001','c4000000-0000-0000-0000-000000000001')$$,'42501','staff_profiles.view permission is required','missing permission read denied');
select throws_ok($$select public.create_staff_profile_v1_7('c9000000-0000-0000-0000-000000000001','c2000000-0000-0000-0000-000000000001',null,'c3000000-0000-0000-0000-000000000001','c4000000-0000-0000-0000-000000000001','DENIED','No',null,'Permission',null,null,null,'employee',null,null,null,'active')$$,'42501','staff command target is unavailable','missing permission create denied');
select set_config('request.jwt.claims','{"sub":"c1000000-0000-0000-0000-000000000003","role":"authenticated"}',true);
select throws_ok($$select * from public.search_staff_profiles('c2000000-0000-0000-0000-000000000001','c3000000-0000-0000-0000-000000000001','c4000000-0000-0000-0000-000000000001')$$,'42501','staff_profiles.view permission is required','inactive membership denied');
select set_config('request.jwt.claims','{"sub":"c1000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select * from public.search_staff_profiles('c2000000-0000-0000-0000-000000000002')$$,'42501','staff_profiles.view permission is required','cross-tenant read denied');
select throws_ok($$select public.create_staff_profile_v1_7('c9000000-0000-0000-0000-000000000002','c2000000-0000-0000-0000-000000000001',null,'c3000000-0000-0000-0000-000000000001','c4000000-0000-0000-0000-000000000002','WRONGCAMPUS','Wrong',null,'Campus',null,null,null,'employee',null,null,null,'active')$$,'42501','staff command target is unavailable','wrong-campus create denied');
select lives_ok($$select public.create_staff_profile_v1_7('c9000000-0000-0000-0000-000000000003','c2000000-0000-0000-0000-000000000001',null,'c3000000-0000-0000-0000-000000000001','c4000000-0000-0000-0000-000000000001','UNLINKED','Ada',null,'Lovelace','Dr Ada','ada@school.test','+1 555','employee','Teacher','Math','2026-08-01','active')$$,'authorized unlinked staff create succeeds');
select is((select organization_membership_id from public.staff_profiles where staff_number='UNLINKED'),null,'unlinked staff stores null membership');
select is((select access_state from public.get_staff_admin_detail((select id from public.staff_profiles where staff_number='UNLINKED'),'c2000000-0000-0000-0000-000000000001','c3000000-0000-0000-0000-000000000001','c4000000-0000-0000-0000-000000000001')),'no_access','unlinked staff reads no_access');
select is((select access_state from public.get_staff_admin_detail('c8000000-0000-0000-0000-000000000013','c2000000-0000-0000-0000-000000000001','c3000000-0000-0000-0000-000000000001','c4000000-0000-0000-0000-000000000001')),'invited','invited membership reads invited');
select is((select access_state from public.get_staff_admin_detail('c8000000-0000-0000-0000-000000000014','c2000000-0000-0000-0000-000000000001','c3000000-0000-0000-0000-000000000001','c4000000-0000-0000-0000-000000000001')),'suspended','suspended membership reads suspended');
select throws_ok(format($q$select public.update_staff_profile_v1_7('c9000000-0000-0000-0000-000000000004',%L,'c5000000-0000-0000-0000-000000000012',true,'UNLINKED','Ada',null,'Lovelace','Dr Ada','ada@school.test','+1 555','employee','active','Teacher','Math','2026-08-01',null)$q$,(select id from public.staff_profiles where staff_number='UNLINKED')),'22023','linked membership must be active and compatible','cross-tenant membership link denied');
select lives_ok(format($q$select public.update_staff_profile_v1_7('c9000000-0000-0000-0000-000000000005',%L,'c5000000-0000-0000-0000-000000000001',true,'UNLINKED','Ada',null,'Lovelace','Dr Ada','ada@school.test','+1 555','employee','active','Teacher','Math','2026-08-01',null)$q$,(select id from public.staff_profiles where staff_number='UNLINKED')),'unlinked staff can link to compatible active membership');
select lives_ok(format($q$select public.update_staff_profile_v1_7('c9000000-0000-0000-0000-000000000005',%L,'c5000000-0000-0000-0000-000000000001',true,'UNLINKED','Ada',null,'Lovelace','Dr Ada','ada@school.test','+1 555','employee','active','Teacher','Math','2026-08-01',null)$q$,(select id from public.staff_profiles where staff_number='UNLINKED')),'matching membership-link replay returns original result');
select is((select access_state from public.get_staff_admin_detail((select id from public.staff_profiles where staff_number='UNLINKED'),'c2000000-0000-0000-0000-000000000001','c3000000-0000-0000-0000-000000000001','c4000000-0000-0000-0000-000000000001')),'active','linked staff reads active');
select throws_ok($$select public.create_staff_profile_v1_7('c9000000-0000-0000-0000-000000000006','c2000000-0000-0000-0000-000000000001','c5000000-0000-0000-0000-000000000001','c3000000-0000-0000-0000-000000000001','c4000000-0000-0000-0000-000000000001','DUPLINK','Duplicate',null,'Link',null,null,null,'employee',null,null,null,'active')$$,'23505',null,'duplicate membership link denied');
select throws_ok(format($q$select public.update_staff_profile_v1_7('c9000000-0000-0000-0000-000000000007',%L,'c5000000-0000-0000-0000-000000000011',true,'UNLINKED','Ada',null,'Lovelace','Dr Ada','ada@school.test','+1 555','employee','active','Teacher','Math','2026-08-01',null)$q$,(select id from public.staff_profiles where staff_number='UNLINKED')),'22023','membership link may only be added once','linked staff cannot be relinked');
select lives_ok($$select public.create_staff_profile_v1_7('c9000000-0000-0000-0000-000000000003','c2000000-0000-0000-0000-000000000001',null,'c3000000-0000-0000-0000-000000000001','c4000000-0000-0000-0000-000000000001','UNLINKED','Ada',null,'Lovelace','Dr Ada','ada@school.test','+1 555','employee','Teacher','Math','2026-08-01','active')$$,'matching create replay succeeds');
reset role;

select is((select count(*)::int from public.staff_profiles where staff_number='UNLINKED'),1,'replay creates no duplicate');
select is((select count(*)::int from public.audit_log where entity_id=(select id from public.staff_profiles where staff_number='UNLINKED') and action in('staff_profile.created','staff_profile.access_linked')),2,'create and link are audited atomically');
select is((select count(*)::int from public.event_outbox where aggregate_id=(select id from public.staff_profiles where staff_number='UNLINKED') and event_type in('staff_profile.created','staff_profile.access_linked')),2,'create and link emit atomic outbox events');
select is((select count(*)::int from public.audit_log where entity_id=(select id from public.staff_profiles where staff_number='UNLINKED') and action='staff_profile.access_linked'),1,'membership-link replay writes exactly one audit record');
select is((select count(*)::int from public.event_outbox where aggregate_id=(select id from public.staff_profiles where staff_number='UNLINKED') and event_type='staff_profile.access_linked'),1,'membership-link replay writes exactly one outbox event');
select ok((select count(*)=0 from public.staff_profiles where staff_number in('BACKFILL','INVITED','SUSPEND') and organization_membership_id is not null and first_name is null and last_name is null),'linked backfill leaves no fixture identity missing');

select * from finish();
rollback;
