begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

select has_table('public','teaching_assignments','teaching assignments table exists');
select has_type('public','teaching_assignment_role','assignment role enum exists');
select has_type('public','teaching_assignment_status','assignment status enum exists');
select ok((select relrowsecurity and relforcerowsecurity from pg_class where oid='public.teaching_assignments'::regclass),'teaching assignments force RLS');
select is((select count(*)::int from public.permissions where code like 'teaching_assignments.%'),3,'three assignment permissions seeded');
select has_index('public','teaching_assignments','teaching_assignments_one_homeroom_lead','homeroom lead exclusion exists');
select has_index('public','teaching_assignments','teaching_assignments_one_subject_lead','subject lead exclusion exists');
select ok(not has_table_privilege('authenticated','public.teaching_assignments','INSERT,UPDATE,DELETE,TRUNCATE'),'authenticated has no direct writes');

create temp table expected_teaching_rpcs(signature text) on commit drop;
insert into expected_teaching_rpcs values
 ('public.create_teaching_assignment(uuid,uuid,uuid,teaching_assignment_role,date,date)'),
 ('public.end_teaching_assignment(uuid,date,text)'),
 ('public.reassign_teaching_assignment(uuid,uuid,teaching_assignment_role,date,date,text)'),
 ('public.correct_teaching_assignment(uuid,uuid,uuid,uuid,teaching_assignment_role,date,date,boolean,text)');
select ok(not exists(select 1 from expected_teaching_rpcs e where to_regprocedure(e.signature) is null),'all four typed RPCs exist');
select ok(not exists(select 1 from expected_teaching_rpcs e join pg_proc p on p.oid=to_regprocedure(e.signature) where pg_get_userbyid(p.proowner)<>'postgres' or not p.prosecdef or not exists(select 1 from unnest(p.proconfig) c where c like 'search_path=%')),'RPC ownership and security configuration are exact');
select ok(not exists(select 1 from expected_teaching_rpcs e join pg_proc p on p.oid=to_regprocedure(e.signature) where has_function_privilege('anon',p.oid,'EXECUTE') or not has_function_privilege('authenticated',p.oid,'EXECUTE') or not has_function_privilege('service_role',p.oid,'EXECUTE')),'public RPC grants are deliberate');

create temp table relationship_helpers(signature text) on commit drop;
insert into relationship_helpers values
 ('app_auth.is_current_assigned_teacher_for_section(uuid,uuid)'),
 ('app_auth.is_current_assigned_teacher_for_enrollment(uuid)'),
 ('app_auth.is_current_assigned_teacher_for_student(uuid)');
select ok(not exists(select 1 from relationship_helpers h join pg_proc p on p.oid=to_regprocedure(h.signature) where pg_get_userbyid(p.proowner)<>'postgres' or not p.prosecdef or not exists(select 1 from unnest(p.proconfig) c where c like 'search_path=%')),'relationship helpers have exact owner and configuration');
select ok(not exists(select 1 from relationship_helpers h join pg_proc p on p.oid=to_regprocedure(h.signature) where not has_function_privilege('authenticated',p.oid,'EXECUTE') or has_function_privilege('anon',p.oid,'EXECUTE') or has_function_privilege('service_role',p.oid,'EXECUTE')),'only authenticated receives relationship-helper execution');
select ok(not has_function_privilege('authenticated','app_auth.create_teaching_assignment_impl(uuid,uuid,uuid,teaching_assignment_role,date,date,uuid,uuid,uuid,text)','EXECUTE'),'authenticated cannot execute create implementation');
select ok(not has_function_privilege('service_role','app_auth.correct_teaching_assignment_impl(uuid,uuid,uuid,uuid,teaching_assignment_role,date,date,boolean,text)','EXECUTE'),'service role cannot execute correction implementation');

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,created_at,updated_at) values
 ('a1000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','ta-admin@test','',now(),now()),
 ('a1000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','ta-teacher@test','',now(),now()),
 ('a1000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000000','authenticated','authenticated','ta-teacher2@test','',now(),now()),
 ('a1000000-0000-0000-0000-000000000004','00000000-0000-0000-0000-000000000000','authenticated','authenticated','ta-none@test','',now(),now()),
 ('a1000000-0000-0000-0000-000000000005','00000000-0000-0000-0000-000000000000','authenticated','authenticated','ta-student@test','',now(),now());
insert into public.organizations(id,name,slug) values
 ('a2000000-0000-0000-0000-000000000001','Teaching Tenant','teaching-tenant'),
 ('a2000000-0000-0000-0000-000000000002','Other Teaching Tenant','other-teaching-tenant');
insert into public.schools(id,organization_id,name,code) values
 ('a3000000-0000-0000-0000-000000000001','a2000000-0000-0000-0000-000000000001','Teaching School','TS'),
 ('a3000000-0000-0000-0000-000000000002','a2000000-0000-0000-0000-000000000002','Other School','OS');
insert into public.campuses(id,organization_id,school_id,name,code) values
 ('a4000000-0000-0000-0000-000000000001','a2000000-0000-0000-0000-000000000001','a3000000-0000-0000-0000-000000000001','Main Campus','MAIN'),
 ('a4000000-0000-0000-0000-000000000002','a2000000-0000-0000-0000-000000000002','a3000000-0000-0000-0000-000000000002','Other Campus','OTHER');
insert into public.organization_memberships(id,organization_id,user_id,status,joined_at) values
 ('a5000000-0000-0000-0000-000000000001','a2000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001','active',now()),
 ('a5000000-0000-0000-0000-000000000002','a2000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000002','active',now()),
 ('a5000000-0000-0000-0000-000000000003','a2000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000003','active',now()),
 ('a5000000-0000-0000-0000-000000000004','a2000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000004','active',now());
insert into public.roles(id,organization_id,code,name) values
 ('a6000000-0000-0000-0000-000000000001','a2000000-0000-0000-0000-000000000001','TEACHING_ADMIN','Teaching Admin');
insert into public.role_permissions(organization_id,role_id,permission_id)
 select 'a2000000-0000-0000-0000-000000000001','a6000000-0000-0000-0000-000000000001',id from public.permissions
 where code like 'teaching_assignments.%' or code='academic_structure.manage';
insert into public.role_assignments(organization_id,organization_membership_id,role_id,school_id,campus_id) values
 ('a2000000-0000-0000-0000-000000000001','a5000000-0000-0000-0000-000000000001','a6000000-0000-0000-0000-000000000001','a3000000-0000-0000-0000-000000000001','a4000000-0000-0000-0000-000000000001');
insert into public.staff_profiles(id,organization_id,organization_membership_id,staff_number,employment_type,status) values
 ('a7000000-0000-0000-0000-000000000001','a2000000-0000-0000-0000-000000000001','a5000000-0000-0000-0000-000000000002','T-1','teacher','active'),
 ('a7000000-0000-0000-0000-000000000002','a2000000-0000-0000-0000-000000000001','a5000000-0000-0000-0000-000000000003','T-2','teacher','active');
insert into public.academic_years(id,organization_id,school_id,name,start_date,end_date,status) values
 ('a8000000-0000-0000-0000-000000000001','a2000000-0000-0000-0000-000000000001','a3000000-0000-0000-0000-000000000001','2026-27','2026-01-01','2026-12-31','active');
insert into public.grade_levels(id,organization_id,school_id,code,name,sequence,status) values
 ('a8100000-0000-0000-0000-000000000001','a2000000-0000-0000-0000-000000000001','a3000000-0000-0000-0000-000000000001','G1','Grade 1',1,'active');
insert into public.subjects(id,organization_id,school_id,code,name,status) values
 ('a8200000-0000-0000-0000-000000000001','a2000000-0000-0000-0000-000000000001','a3000000-0000-0000-0000-000000000001','MATH','Mathematics','active');
insert into public.sections(id,organization_id,school_id,campus_id,academic_year_id,grade_level_id,code,name,capacity,start_date,end_date,status) values
 ('a8300000-0000-0000-0000-000000000001','a2000000-0000-0000-0000-000000000001','a3000000-0000-0000-0000-000000000001','a4000000-0000-0000-0000-000000000001','a8000000-0000-0000-0000-000000000001','a8100000-0000-0000-0000-000000000001','1A','Grade 1 A',30,'2026-01-01','2026-12-31','active');
insert into public.students(id,organization_id,school_id,campus_id,user_id,student_number,first_name,last_name,date_of_birth) values
 ('a8400000-0000-0000-0000-000000000001','a2000000-0000-0000-0000-000000000001','a3000000-0000-0000-0000-000000000001','a4000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000005','S-1','Roster','Student','2018-01-01');
insert into public.student_enrollments(id,organization_id,school_id,academic_year_id,student_id,grade_level_id,enrolled_on,scheduled_end_on,enrollment_range,status,created_by,updated_by) values
 ('a8500000-0000-0000-0000-000000000001','a2000000-0000-0000-0000-000000000001','a3000000-0000-0000-0000-000000000001','a8000000-0000-0000-0000-000000000001','a8400000-0000-0000-0000-000000000001','a8100000-0000-0000-0000-000000000001','2026-01-01','2026-12-31',daterange('2026-01-01','2026-12-31','[]'),'active','a1000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001');
insert into public.student_section_placements(id,organization_id,school_id,campus_id,academic_year_id,student_enrollment_id,student_id,section_id,starts_on,status,created_by,updated_by) values
 ('a8600000-0000-0000-0000-000000000001','a2000000-0000-0000-0000-000000000001','a3000000-0000-0000-0000-000000000001','a4000000-0000-0000-0000-000000000001','a8000000-0000-0000-0000-000000000001','a8500000-0000-0000-0000-000000000001','a8400000-0000-0000-0000-000000000001','a8300000-0000-0000-0000-000000000001','2026-01-01','active','a1000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001');

set local role anon;
select throws_ok($$select public.create_teaching_assignment('a8300000-0000-0000-0000-000000000001','a7000000-0000-0000-0000-000000000001',null,'lead','2026-01-01','2026-12-31')$$,'42501','permission denied for function create_teaching_assignment','anonymous command denied');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a1000000-0000-0000-0000-000000000004","role":"authenticated"}',true);
select throws_ok($$select public.create_teaching_assignment('a8300000-0000-0000-0000-000000000001','a7000000-0000-0000-0000-000000000001',null,'lead','2026-01-01','2026-12-31')$$,'42501','teaching_assignments.manage permission is required','missing permission denied');
select set_config('request.jwt.claims','{"sub":"a1000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select lives_ok($$select public.create_teaching_assignment('a8300000-0000-0000-0000-000000000001','a7000000-0000-0000-0000-000000000001',null,'lead','2026-01-01','2026-12-31')$$,'homeroom lead created');
select throws_ok($$select public.create_teaching_assignment('a8300000-0000-0000-0000-000000000001','a7000000-0000-0000-0000-000000000002',null,'lead','2026-06-01','2026-10-01')$$,'23P01',null,'overlapping null-subject lead rejected');
select lives_ok($$select public.create_teaching_assignment('a8300000-0000-0000-0000-000000000001','a7000000-0000-0000-0000-000000000002',null,'co_teacher','2026-01-01','2026-12-31')$$,'overlapping co-teacher allowed');
select lives_ok($$select public.create_teaching_assignment('a8300000-0000-0000-0000-000000000001','a7000000-0000-0000-0000-000000000002','a8200000-0000-0000-0000-000000000001','lead','2026-01-01','2026-12-31')$$,'subject lead allowed beside homeroom lead');
reset role;

select is((select count(*)::int from public.audit_log where action='teaching_assignment.created'),3,'successful creates are audited');
select is((select count(*)::int from public.event_outbox where event_type='teaching_assignment.created'),3,'successful creates emit events');
select ok(not exists(select 1 from public.event_outbox where event_type like 'teaching_assignment.%' and (payload?'first_name' or payload?'user_id' or payload?'student_id')),'assignment events contain no identity or roster data');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a1000000-0000-0000-0000-000000000002","role":"authenticated"}',true);
select is((select count(*)::int from public.teaching_assignments),1,'teacher sees only own current assignment');
select ok(not exists(select 1 from public.teaching_assignments where staff_profile_id='a7000000-0000-0000-0000-000000000002'),'same-section relationship does not expose another teacher assignment');
select is((select count(*)::int from public.student_enrollments),1,'current teacher sees current enrollment');
select is((select count(*)::int from public.student_section_placements),1,'current teacher sees current placement');
select is((select count(*)::int from public.students),1,'current teacher sees ordinary roster student');
select is((select count(*)::int from public.student_identifiers),0,'assignment does not expose identifiers');
select throws_ok($$select public.end_teaching_assignment((select id from public.teaching_assignments limit 1),'2026-09-04','unauthorized')$$,'42501','teaching_assignments.manage permission is required','relationship grants no mutation authority');
reset role;

-- The immutable trigger applies even to privileged direct writes. Lifecycle fields
-- remain command-mutable, while each identity/scope/business creation fact is fixed.
select throws_ok($$update public.teaching_assignments set organization_id='a2000000-0000-0000-0000-000000000002' where staff_profile_id='a7000000-0000-0000-0000-000000000001'$$,'22023','teaching assignment immutable fields cannot change','organization is immutable');
select throws_ok($$update public.teaching_assignments set school_id='a3000000-0000-0000-0000-000000000002' where staff_profile_id='a7000000-0000-0000-0000-000000000001'$$,'22023','teaching assignment immutable fields cannot change','school is immutable');
select throws_ok($$update public.teaching_assignments set campus_id='a4000000-0000-0000-0000-000000000002' where staff_profile_id='a7000000-0000-0000-0000-000000000001'$$,'22023','teaching assignment immutable fields cannot change','campus is immutable');
select throws_ok($$update public.teaching_assignments set academic_year_id=gen_random_uuid() where staff_profile_id='a7000000-0000-0000-0000-000000000001'$$,'22023','teaching assignment immutable fields cannot change','year is immutable');
select throws_ok($$update public.teaching_assignments set section_id=gen_random_uuid() where staff_profile_id='a7000000-0000-0000-0000-000000000001'$$,'22023','teaching assignment immutable fields cannot change','section is immutable');
select throws_ok($$update public.teaching_assignments set subject_id='a8200000-0000-0000-0000-000000000001' where staff_profile_id='a7000000-0000-0000-0000-000000000001'$$,'22023','teaching assignment immutable fields cannot change','subject is immutable');
select throws_ok($$update public.teaching_assignments set staff_profile_id='a7000000-0000-0000-0000-000000000002' where staff_profile_id='a7000000-0000-0000-0000-000000000001'$$,'22023','teaching assignment immutable fields cannot change','staff is immutable');
select throws_ok($$update public.teaching_assignments set role='assistant' where staff_profile_id='a7000000-0000-0000-0000-000000000001'$$,'22023','teaching assignment immutable fields cannot change','role is immutable');
select throws_ok($$update public.teaching_assignments set starts_on='2026-01-02' where staff_profile_id='a7000000-0000-0000-0000-000000000001'$$,'22023','teaching assignment immutable fields cannot change','start is immutable');
select throws_ok($$update public.teaching_assignments set scheduled_ends_on='2026-12-30' where staff_profile_id='a7000000-0000-0000-0000-000000000001'$$,'22023','teaching assignment immutable fields cannot change','scheduled end is immutable');
select throws_ok($$update public.teaching_assignments set created_by='a1000000-0000-0000-0000-000000000003' where staff_profile_id='a7000000-0000-0000-0000-000000000001'$$,'22023','teaching assignment immutable fields cannot change','creator is immutable');
select throws_ok($$update public.teaching_assignments set created_at=created_at-interval '1 second' where staff_profile_id='a7000000-0000-0000-0000-000000000001'$$,'22023','teaching assignment immutable fields cannot change','creation time is immutable');
select is((select count(*)::int from public.audit_log where action like 'teaching_assignment.%'),3,'immutable-field rejections write no audit');
select is((select count(*)::int from public.event_outbox where event_type like 'teaching_assignment.%'),3,'immutable-field rejections write no outbox');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a1000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select * from public.reassign_teaching_assignment((select id from public.teaching_assignments where staff_profile_id='a7000000-0000-0000-0000-000000000001'),'a7000000-0000-0000-0000-000000000002','lead','2026-10-01','2027-01-01','too long')$$,'22023','assignment dates must be inside section and academic year','reassignment beyond section and year rejected');
reset role;
select is((select count(*)::int from public.audit_log where action like 'teaching_assignment.%'),3,'date-rejected reassignment writes no audit');
select is((select count(*)::int from public.event_outbox where event_type like 'teaching_assignment.%'),3,'date-rejected reassignment writes no outbox');
update public.sections set status='inactive' where id='a8300000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a1000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select * from public.reassign_teaching_assignment((select id from public.teaching_assignments where staff_profile_id='a7000000-0000-0000-0000-000000000001'),'a7000000-0000-0000-0000-000000000002','lead','2026-10-01','2026-12-31','inactive section')$$,'22023','active section and academic year are required','inactive section blocks reassignment');
reset role;
update public.sections set status='active' where id='a8300000-0000-0000-0000-000000000001';
update public.academic_years set status='draft' where id='a8000000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a1000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select * from public.reassign_teaching_assignment((select id from public.teaching_assignments where staff_profile_id='a7000000-0000-0000-0000-000000000001'),'a7000000-0000-0000-0000-000000000002','lead','2026-10-01','2026-12-31','inactive year')$$,'22023','active section and academic year are required','inactive academic year blocks reassignment');
reset role;
update public.academic_years set status='active' where id='a8000000-0000-0000-0000-000000000001';
update public.subjects set status='inactive' where id='a8200000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a1000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select * from public.reassign_teaching_assignment((select id from public.teaching_assignments where subject_id='a8200000-0000-0000-0000-000000000001'),'a7000000-0000-0000-0000-000000000001','lead','2026-10-01','2026-12-31','inactive subject')$$,'22023','active subject in the section school is required','inactive subject blocks reassignment');
reset role;
update public.subjects set status='active' where id='a8200000-0000-0000-0000-000000000001';
select is((select count(*)::int from public.audit_log where action like 'teaching_assignment.%'),3,'inactive-parent rejections write no audit');
select is((select count(*)::int from public.event_outbox where event_type like 'teaching_assignment.%'),3,'inactive-parent rejections write no outbox');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a1000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select lives_ok($$select * from public.reassign_teaching_assignment((select id from public.teaching_assignments where staff_profile_id='a7000000-0000-0000-0000-000000000001'),'a7000000-0000-0000-0000-000000000002','lead','2026-10-01','2026-12-31','teacher changed')$$,'reassignment succeeds atomically');
select throws_ok($$select * from public.correct_teaching_assignment((select id from public.teaching_assignments where status='reassigned'),null,null,null,null,null,null,false,'wrong source')$$,'22023','reassigned assignment history cannot be corrected','reassigned source correction rejected');
select throws_ok($$select * from public.correct_teaching_assignment((select reassigned_to_assignment_id from public.teaching_assignments where status='reassigned'),null,null,null,null,null,null,false,'wrong destination')$$,'22023','reassigned assignment history cannot be corrected','reassignment destination correction rejected');
reset role;
select is((select count(*)::int from public.teaching_assignments where status='reassigned'),1,'source retained as reassigned');
select is((select count(*)::int from public.teaching_assignments where status='active' and staff_profile_id='a7000000-0000-0000-0000-000000000002' and role='lead' and subject_id is null),1,'replacement is active homeroom lead');
select is((select count(distinct command_id)::int from public.event_outbox where event_type in ('teaching_assignment.reassigned_out','teaching_assignment.reassigned_in')),1,'reassignment events share command ID');

update public.student_section_placements set status='completed',ends_on='2026-09-04',end_reason='test cleanup',updated_by='a1000000-0000-0000-0000-000000000001'
where id='a8600000-0000-0000-0000-000000000001';

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a1000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.archive_section('a8300000-0000-0000-0000-000000000001')$$,'22023','section has active teaching assignments','active assignments block section archive');
reset role;

select * from finish();
rollback;
