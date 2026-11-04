begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

select function_returns('public','search_staff_profiles',array['uuid','uuid','uuid','text','record_status','text','uuid','integer'],'setof record','staff directory contract exists');
select function_returns('public','get_staff_admin_detail',array['uuid','uuid','uuid','uuid'],'setof record','staff detail contract exists');
select ok(has_function_privilege('authenticated','public.search_staff_profiles(uuid,uuid,uuid,text,record_status,text,uuid,integer)','EXECUTE'),'authenticated staff search granted');
select ok(not has_function_privilege('anon','public.search_staff_profiles(uuid,uuid,uuid,text,record_status,text,uuid,integer)','EXECUTE'),'anonymous staff search denied');
select has_index('public','staff_profiles','staff_profiles_directory_number_trgm_idx','staff number search index exists');
select has_index('public','profiles','profiles_directory_name_trgm_idx','staff name search index exists');

set local role anon;
select throws_ok($$select * from public.search_staff_profiles('a2000000-0000-0000-0000-000000000001')$$,'42501','permission denied for function search_staff_profiles','anonymous cannot search staff');
reset role;

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,created_at,updated_at) values
 ('a1000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','v14-admin@test','',now(),now()),
 ('a1000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','v14-none@test','',now(),now()),
 ('a1000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000000','authenticated','authenticated','v14-inactive@test','',now(),now()),
 ('a1000000-0000-0000-0000-000000000011','00000000-0000-0000-0000-000000000000','authenticated','authenticated','allowed-staff@test','',now(),now()),
 ('a1000000-0000-0000-0000-000000000012','00000000-0000-0000-0000-000000000000','authenticated','authenticated','denied-staff@test','',now(),now()),
 ('a1000000-0000-0000-0000-000000000013','00000000-0000-0000-0000-000000000000','authenticated','authenticated','other-staff@test','',now(),now());
update public.profiles set first_name='Alice',middle_name='Private',last_name='Allowed',display_name='Alice A',phone='secret',avatar_path='private/avatar.jpg' where user_id='a1000000-0000-0000-0000-000000000011';
update public.profiles set first_name='Dana',last_name='Denied',display_name='Dana D' where user_id='a1000000-0000-0000-0000-000000000012';
update public.profiles set first_name='Other',last_name='Tenant',display_name='Other T' where user_id='a1000000-0000-0000-0000-000000000013';

insert into public.organizations(id,name,slug) values
 ('a2000000-0000-0000-0000-000000000001','V14 Tenant','v14-tenant'),
 ('a2000000-0000-0000-0000-000000000002','Other V14 Tenant','other-v14-tenant');
insert into public.schools(id,organization_id,name,code) values
 ('a3000000-0000-0000-0000-000000000001','a2000000-0000-0000-0000-000000000001','V14 School','V14'),
 ('a3000000-0000-0000-0000-000000000002','a2000000-0000-0000-0000-000000000002','Other V14 School','OV14');
insert into public.campuses(id,organization_id,school_id,name,code) values
 ('a4000000-0000-0000-0000-000000000001','a2000000-0000-0000-0000-000000000001','a3000000-0000-0000-0000-000000000001','Allowed Campus','A'),
 ('a4000000-0000-0000-0000-000000000002','a2000000-0000-0000-0000-000000000001','a3000000-0000-0000-0000-000000000001','Denied Campus','D'),
 ('a4000000-0000-0000-0000-000000000003','a2000000-0000-0000-0000-000000000002','a3000000-0000-0000-0000-000000000002','Other Campus','O');
insert into public.organization_memberships(id,organization_id,user_id,status,joined_at) values
 ('a5000000-0000-0000-0000-000000000001','a2000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001','active',now()),
 ('a5000000-0000-0000-0000-000000000002','a2000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000002','active',now()),
 ('a5000000-0000-0000-0000-000000000003','a2000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000003','suspended',now()),
 ('a5000000-0000-0000-0000-000000000011','a2000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000011','active',now()),
 ('a5000000-0000-0000-0000-000000000012','a2000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000012','active',now()),
 ('a5000000-0000-0000-0000-000000000013','a2000000-0000-0000-0000-000000000002','a1000000-0000-0000-0000-000000000013','active',now());
insert into public.roles(id,organization_id,code,name) values ('a6000000-0000-0000-0000-000000000001','a2000000-0000-0000-0000-000000000001','V14_STAFF_VIEW','V14 Staff Viewer');
insert into public.role_permissions(organization_id,role_id,permission_id)
 select 'a2000000-0000-0000-0000-000000000001','a6000000-0000-0000-0000-000000000001',id from public.permissions where code='staff_profiles.view';
insert into public.role_assignments(id,organization_id,organization_membership_id,role_id,school_id,campus_id) values
 ('a7000000-0000-0000-0000-000000000001','a2000000-0000-0000-0000-000000000001','a5000000-0000-0000-0000-000000000001','a6000000-0000-0000-0000-000000000001','a3000000-0000-0000-0000-000000000001','a4000000-0000-0000-0000-000000000001'),
 ('a7000000-0000-0000-0000-000000000003','a2000000-0000-0000-0000-000000000001','a5000000-0000-0000-0000-000000000003','a6000000-0000-0000-0000-000000000001','a3000000-0000-0000-0000-000000000001','a4000000-0000-0000-0000-000000000001');
insert into public.staff_profiles(id,organization_id,organization_membership_id,school_id,campus_id,staff_number,employment_type,job_title,department,status) values
 ('a8000000-0000-0000-0000-000000000001','a2000000-0000-0000-0000-000000000001','a5000000-0000-0000-0000-000000000011','a3000000-0000-0000-0000-000000000001','a4000000-0000-0000-0000-000000000001','STAFF%01','employee','Teacher','Science','active'),
 ('a8000000-0000-0000-0000-000000000002','a2000000-0000-0000-0000-000000000001','a5000000-0000-0000-0000-000000000012','a3000000-0000-0000-0000-000000000001','a4000000-0000-0000-0000-000000000002','STAFFX01','contractor','Teacher','Math','active'),
 ('a8000000-0000-0000-0000-000000000003','a2000000-0000-0000-0000-000000000002','a5000000-0000-0000-0000-000000000013','a3000000-0000-0000-0000-000000000002','a4000000-0000-0000-0000-000000000003','OTHER01','employee','Principal','Admin','active');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a1000000-0000-0000-0000-000000000002","role":"authenticated"}',true);
select is((select count(*)::int from public.get_my_admin_contexts()),0,'missing-permission actor has no context');
select throws_ok($$select * from public.search_staff_profiles('a2000000-0000-0000-0000-000000000001')$$,'42501','staff_profiles.view permission is required','missing permission denied');
select set_config('request.jwt.claims','{"sub":"a1000000-0000-0000-0000-000000000003","role":"authenticated"}',true);
select is((select count(*)::int from public.get_my_admin_contexts()),0,'inactive membership has no context');
select set_config('request.jwt.claims','{"sub":"a1000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select is((select count(*)::int from public.get_my_admin_contexts()),1,'staff-only context is available');
select is((select permission_codes from public.get_my_admin_contexts()),array['staff_profiles.view']::text[],'context includes staff permission');
select throws_ok($$select * from public.search_staff_profiles('a2000000-0000-0000-0000-000000000002','a3000000-0000-0000-0000-000000000002','a4000000-0000-0000-0000-000000000003')$$,'42501','staff_profiles.view permission is required','cross-tenant search denied');
select throws_ok($$select * from public.search_staff_profiles('a2000000-0000-0000-0000-000000000001','a3000000-0000-0000-0000-000000000001','a4000000-0000-0000-0000-000000000002')$$,'42501','staff_profiles.view permission is required','wrong-campus search denied');
select throws_ok($$select * from public.search_staff_profiles('a2000000-0000-0000-0000-000000000001','a3000000-0000-0000-0000-000000000001','a4000000-0000-0000-0000-000000000001',repeat('x',101))$$,'22023','staff search query is too long','direct RPC query length is bounded');
select throws_ok($$select * from public.search_staff_profiles('a2000000-0000-0000-0000-000000000001','a3000000-0000-0000-0000-000000000001','a4000000-0000-0000-0000-000000000001',null,'active',repeat('x',1001),'a8000000-0000-0000-0000-000000000001')$$,'22023','staff cursor is too long','direct RPC cursor length is bounded');
select is((select count(*)::int from public.search_staff_profiles('a2000000-0000-0000-0000-000000000001','a3000000-0000-0000-0000-000000000001','a4000000-0000-0000-0000-000000000001','%',null)),1,'literal percent is escaped and results are scoped');
select ok((select to_jsonb(s)-array['staff_profile_id','staff_number','first_name','middle_name','last_name','display_name','job_title','department','employment_type','status','school_id','school_name','campus_id','campus_name','updated_at','sort_cursor_value','total_count']='{}'::jsonb from public.search_staff_profiles('a2000000-0000-0000-0000-000000000001','a3000000-0000-0000-0000-000000000001','a4000000-0000-0000-0000-000000000001') s),'directory uses exact allowlist');
select ok((select position('secret' in to_jsonb(d)::text)=0 and position('private/avatar.jpg' in to_jsonb(d)::text)=0 and position('a1000000-0000-0000-0000-000000000011' in to_jsonb(d)::text)=0 from public.get_staff_admin_detail('a8000000-0000-0000-0000-000000000001','a2000000-0000-0000-0000-000000000001','a3000000-0000-0000-0000-000000000001','a4000000-0000-0000-0000-000000000001') d),'detail excludes phone, avatar, and user id');
select is((select count(*)::int from public.get_staff_admin_detail('a8000000-0000-0000-0000-000000000002','a2000000-0000-0000-0000-000000000001','a3000000-0000-0000-0000-000000000001','a4000000-0000-0000-0000-000000000001')),0,'detail campus boundary enforced');
select is((select count(*)::int from public.get_staff_admin_detail('a8000000-0000-0000-0000-000000000003','a2000000-0000-0000-0000-000000000001',null,null)),0,'detail tenant boundary enforced');
reset role;

select * from finish();
rollback;
