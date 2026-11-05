begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

select function_returns('public','search_eligible_staff_members',array['uuid','uuid','uuid','text','integer'],'setof record','eligible member search contract exists');
select function_returns('public','create_staff_profile_v1_5',array['uuid','uuid','uuid','uuid','text','text','text','text','date','record_status'],'uuid','create command contract exists');
select function_returns('public','update_staff_profile_v1_5',array['uuid','uuid','text','text','record_status','uuid','boolean','uuid','boolean','text','boolean','text','boolean','date','boolean','date','boolean'],'uuid','update command contract exists');
select function_returns('public','archive_staff_profile_v1_5',array['uuid','uuid','text'],'uuid','archive command contract exists');
select ok(has_function_privilege('authenticated','public.create_staff_profile_v1_5(uuid,uuid,uuid,uuid,text,text,text,text,date,record_status)','EXECUTE'),'authenticated create wrapper granted');
select ok(not has_function_privilege('anon','public.create_staff_profile_v1_5(uuid,uuid,uuid,uuid,text,text,text,text,date,record_status)','EXECUTE'),'anonymous create wrapper denied');
select ok(has_function_privilege('authenticated','public.create_staff_profile(uuid,uuid,uuid,text,text,text,text,date,record_status)','EXECUTE'),'legacy create command remains compatible');
select ok(has_function_privilege('authenticated','public.update_staff_profile(uuid,text,text,record_status,uuid,boolean,uuid,boolean,text,boolean,text,boolean,date,boolean,date,boolean)','EXECUTE'),'legacy update command remains compatible');
select ok(has_function_privilege('authenticated','public.archive_staff_profile(uuid)','EXECUTE'),'legacy archive command remains compatible');

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,created_at,updated_at) values
 ('b1000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','v15-manager@test','',now(),now()),
 ('b1000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','v15-none@test','',now(),now()),
 ('b1000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000000','authenticated','authenticated','v15-inactive@test','',now(),now()),
 ('b1000000-0000-0000-0000-000000000011','00000000-0000-0000-0000-000000000000','authenticated','authenticated','v15-target@test','',now(),now());
update public.profiles set first_name='Morgan',middle_name='Private',last_name='Manager',display_name='Morgan M' where user_id='b1000000-0000-0000-0000-000000000001';
update public.profiles set first_name='Taylor',last_name='Target',display_name='Taylor T',phone='private-phone',avatar_path='private/avatar' where user_id='b1000000-0000-0000-0000-000000000011';

insert into public.organizations(id,name,slug) values ('b2000000-0000-0000-0000-000000000001','V15 Tenant','v15-tenant');
insert into public.schools(id,organization_id,name,code) values ('b3000000-0000-0000-0000-000000000001','b2000000-0000-0000-0000-000000000001','V15 School','V15');
insert into public.campuses(id,organization_id,school_id,name,code) values
 ('b4000000-0000-0000-0000-000000000001','b2000000-0000-0000-0000-000000000001','b3000000-0000-0000-0000-000000000001','Managed Campus','M'),
 ('b4000000-0000-0000-0000-000000000002','b2000000-0000-0000-0000-000000000001','b3000000-0000-0000-0000-000000000001','Denied Campus','D');
insert into public.organization_memberships(id,organization_id,user_id,status,joined_at) values
 ('b5000000-0000-0000-0000-000000000001','b2000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001','active',now()),
 ('b5000000-0000-0000-0000-000000000002','b2000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000002','active',now()),
 ('b5000000-0000-0000-0000-000000000003','b2000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000003','suspended',now()),
 ('b5000000-0000-0000-0000-000000000011','b2000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000011','active',now());
insert into public.roles(id,organization_id,code,name) values ('b6000000-0000-0000-0000-000000000001','b2000000-0000-0000-0000-000000000001','V15_STAFF_MANAGER','V15 Staff Manager');
insert into public.role_permissions(organization_id,role_id,permission_id)
 select 'b2000000-0000-0000-0000-000000000001','b6000000-0000-0000-0000-000000000001',id from public.permissions where code in('staff_profiles.view','staff_profiles.manage');
insert into public.role_assignments(id,organization_id,organization_membership_id,role_id,school_id,campus_id) values
 ('b7000000-0000-0000-0000-000000000001','b2000000-0000-0000-0000-000000000001','b5000000-0000-0000-0000-000000000001','b6000000-0000-0000-0000-000000000001','b3000000-0000-0000-0000-000000000001','b4000000-0000-0000-0000-000000000001'),
 ('b7000000-0000-0000-0000-000000000003','b2000000-0000-0000-0000-000000000001','b5000000-0000-0000-0000-000000000003','b6000000-0000-0000-0000-000000000001','b3000000-0000-0000-0000-000000000001','b4000000-0000-0000-0000-000000000001');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"b1000000-0000-0000-0000-000000000002","role":"authenticated"}',true);
select throws_ok($$select * from public.search_eligible_staff_members('b2000000-0000-0000-0000-000000000001','b3000000-0000-0000-0000-000000000001','b4000000-0000-0000-0000-000000000001')$$,'42501','staff_profiles.manage permission is required','missing permission denied');
select set_config('request.jwt.claims','{"sub":"b1000000-0000-0000-0000-000000000003","role":"authenticated"}',true);
select throws_ok($$select * from public.search_eligible_staff_members('b2000000-0000-0000-0000-000000000001','b3000000-0000-0000-0000-000000000001','b4000000-0000-0000-0000-000000000001')$$,'42501','staff_profiles.manage permission is required','inactive membership denied');
select set_config('request.jwt.claims','{"sub":"b1000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select * from public.search_eligible_staff_members('b2000000-0000-0000-0000-000000000001','b3000000-0000-0000-0000-000000000001','b4000000-0000-0000-0000-000000000002')$$,'42501','staff_profiles.manage permission is required','wrong-campus candidate search denied');
select throws_ok($$select * from public.search_eligible_staff_members('b2000000-0000-0000-0000-000000000001','b3000000-0000-0000-0000-000000000001','b4000000-0000-0000-0000-000000000001',repeat('x',101))$$,'22023','staff candidate query is too long','candidate query length bounded');
select is((select count(*)::int from public.search_eligible_staff_members('b2000000-0000-0000-0000-000000000001','b3000000-0000-0000-0000-000000000001','b4000000-0000-0000-0000-000000000001','Taylor')),1,'eligible active member is found');
select ok((select to_jsonb(x)-array['membership_id','first_name','middle_name','last_name','display_name']='{}'::jsonb and position('private-phone' in to_jsonb(x)::text)=0 from public.search_eligible_staff_members('b2000000-0000-0000-0000-000000000001','b3000000-0000-0000-0000-000000000001','b4000000-0000-0000-0000-000000000001','Taylor') x),'candidate projection is allowlisted');
select throws_ok($$select public.create_staff_profile_v1_5('b9000000-0000-0000-0000-000000000001','b5000000-0000-0000-0000-000000000011','b3000000-0000-0000-0000-000000000001','b4000000-0000-0000-0000-000000000002','STAFF15','employee','Teacher','Science','2026-08-01','active')$$,'42501','staff command target is unavailable','cross-campus create denied');
select lives_ok($$select public.create_staff_profile_v1_5('b9000000-0000-0000-0000-000000000002','b5000000-0000-0000-0000-000000000011','b3000000-0000-0000-0000-000000000001','b4000000-0000-0000-0000-000000000001','STAFF15','employee','Teacher','Science','2026-08-01','active')$$,'same-campus create allowed');
select is((select count(*)::int from public.staff_profiles where staff_number='STAFF15'),1,'create inserts one staff profile');
select lives_ok($$select public.create_staff_profile_v1_5('b9000000-0000-0000-0000-000000000002','b5000000-0000-0000-0000-000000000011','b3000000-0000-0000-0000-000000000001','b4000000-0000-0000-0000-000000000001','STAFF15','employee','Teacher','Science','2026-08-01','active')$$,'matching create replay succeeds');
select is((select count(*)::int from public.staff_profiles where staff_number='STAFF15'),1,'replay does not duplicate staff');
select throws_ok($$select public.create_staff_profile_v1_5('b9000000-0000-0000-0000-000000000002','b5000000-0000-0000-0000-000000000011','b3000000-0000-0000-0000-000000000001','b4000000-0000-0000-0000-000000000001','CHANGED','employee','Teacher','Science','2026-08-01','active')$$,'22023','request_id was reused with different arguments','request reuse mismatch denied');
select is((select count(*)::int from public.search_eligible_staff_members('b2000000-0000-0000-0000-000000000001','b3000000-0000-0000-0000-000000000001','b4000000-0000-0000-0000-000000000001','Taylor')),0,'profiled member is no longer eligible');
select lives_ok(format($q$select public.update_staff_profile_v1_5('b9000000-0000-0000-0000-000000000003',%L,'STAFF15','employee','active',null,false,null,false,'Senior Teacher',true,'Science',true,'2026-08-01',true,null,true)$q$,(select id from public.staff_profiles where staff_number='STAFF15')),'update allowed');
select is((select job_title from public.staff_profiles where staff_number='STAFF15'),'Senior Teacher','update persists changes');
select throws_ok(format($q$select public.archive_staff_profile_v1_5('b9000000-0000-0000-0000-000000000004',%L,'')$q$,(select id from public.staff_profiles where staff_number='STAFF15')),'22023','archive reason must be between 1 and 500 characters','archive reason required');
select lives_ok(format($q$select public.archive_staff_profile_v1_5('b9000000-0000-0000-0000-000000000005',%L,'Employment ended')$q$,(select id from public.staff_profiles where staff_number='STAFF15')),'archive allowed');
select is((select status::text from public.staff_profiles where staff_number='STAFF15'),'archived','archive is terminal');
reset role;
select is((select count(*)::int from public.audit_log where action='staff_profile.archive_reason_recorded' and after_data->>'archive_reason'='Employment ended'),1,'archive reason audited atomically');
select is((select count(*)::int from public.event_outbox where event_type='staff_profile.archive_reason_recorded' and payload->>'archive_reason'='Employment ended'),1,'archive reason emitted atomically');

select * from finish();
rollback;
