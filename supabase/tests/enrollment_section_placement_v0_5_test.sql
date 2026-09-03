begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

select has_table('public','student_enrollments','enrollment history table exists');
select has_table('public','student_section_placements','placement history table exists');
select has_type('public','enrollment_status','enrollment lifecycle enum exists');
select has_type('public','section_placement_status','placement lifecycle enum exists');
select ok((select relrowsecurity and relforcerowsecurity from pg_class where oid='public.student_enrollments'::regclass),'enrollments force RLS');
select ok((select relrowsecurity and relforcerowsecurity from pg_class where oid='public.student_section_placements'::regclass),'placements force RLS');
select is((select count(*)::int from public.permissions where code like 'enrollments.%'),3,'three enrollment permissions seeded');
select has_index('public','student_enrollments','student_enrollments_no_overlap','cross-school overlap exclusion exists');
select has_index('public','student_section_placements','student_section_placements_one_active_idx','one active placement index exists');
select ok(not has_table_privilege('authenticated','public.student_enrollments','INSERT,UPDATE,DELETE,TRUNCATE'),'authenticated cannot write enrollment table');
select ok(not has_table_privilege('authenticated','public.student_section_placements','INSERT,UPDATE,DELETE,TRUNCATE'),'authenticated cannot write placement table');
select ok(not exists(select 1 from pg_policies where schemaname='public' and tablename in ('student_enrollments','student_section_placements') and cmd<>'SELECT'),'new tables have read-only policies');

create temp table expected_enrollment_rpcs(signature text) on commit drop;
insert into expected_enrollment_rpcs values
 ('public.enroll_student(uuid,uuid,uuid,date)'),
 ('public.withdraw_student_enrollment(uuid,date,text)'),
 ('public.complete_student_enrollment(uuid,date,text)'),
 ('public.correct_student_enrollment(uuid,uuid,uuid,date,enrollment_status,date,text,boolean,text)'),
 ('public.place_student_in_section(uuid,uuid,date)'),
 ('public.transfer_student_section(uuid,uuid,date,text)'),
 ('public.withdraw_student_section_placement(uuid,date,text)'),
 ('public.complete_student_section_placement(uuid,date,text)'),
 ('public.correct_student_section_placement(uuid,uuid,date,date,section_placement_status,text,boolean,text)');
select is((select count(*)::int from expected_enrollment_rpcs),9,'nine typed RPCs specified');
select ok(not exists(select 1 from expected_enrollment_rpcs e left join pg_proc p on p.oid=to_regprocedure(e.signature) where p.oid is null),'all nine RPC signatures exist');
select ok(not exists(select 1 from expected_enrollment_rpcs e join pg_proc p on p.oid=to_regprocedure(e.signature) where pg_get_userbyid(p.proowner)<>'postgres' or not p.prosecdef or not exists(select 1 from unnest(p.proconfig) c where c like 'search_path=%')),'RPCs have exact owner, security definer, and search path');
select ok(not exists(select 1 from expected_enrollment_rpcs e join pg_proc p on p.oid=to_regprocedure(e.signature) where has_function_privilege('anon',p.oid,'EXECUTE') or not has_function_privilege('authenticated',p.oid,'EXECUTE') or not has_function_privilege('service_role',p.oid,'EXECUTE')),'RPC grants are deliberate');
select ok(not has_function_privilege('authenticated','app_auth.transfer_placement(uuid,uuid,date,text)','EXECUTE'),'private dispatcher denied');
select ok(position('order by q' in lower(pg_get_functiondef('app_auth.lock_enrollment_parents(uuid,uuid[],uuid[],uuid[])'::regprocedure)))>0 and position('order by y.id' in lower(pg_get_functiondef('app_auth.lock_enrollment_parents(uuid,uuid[],uuid[],uuid[])'::regprocedure)))>0,'parent peers, years, and grades lock deterministically');
select ok(position('40001' in pg_get_functiondef('app_auth.end_enrollment(uuid,enrollment_status,date,text,uuid)'::regprocedure))>0,'concurrent placement-set drift is retryable');
select ok(position('p_date-1' in replace(pg_get_functiondef('app_auth.transfer_placement(uuid,uuid,date,text)'::regprocedure),' ',''))>0,'transfer uses inclusive D-1 convention');
select ok(position('mate.section_id' in pg_get_functiondef('app_auth.correct_placement(uuid,uuid,date,date,section_placement_status,text,boolean,text)'::regprocedure))>0,'transfer correction includes linked section in parent lock set');
select ok((length(pg_get_functiondef('app_auth.correct_placement(uuid,uuid,date,date,section_placement_status,text,boolean,text)'::regprocedure))-length(replace(pg_get_functiondef('app_auth.correct_placement(uuid,uuid,date,date,section_placement_status,text,boolean,text)'::regprocedure),'assert_enrollment_permission','')))/length('assert_enrollment_permission')=2,'transfer correction authorizes both placement scopes');

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,created_at,updated_at) values
 ('91000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','enroll-admin@test','',now(),now()),
 ('91000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','enroll-none@test','',now(),now()),
 ('91000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000000','authenticated','authenticated','enroll-inactive@test','',now(),now()),
 ('91000000-0000-0000-0000-000000000004','00000000-0000-0000-0000-000000000000','authenticated','authenticated','student-self@test','',now(),now()),
 ('91000000-0000-0000-0000-000000000005','00000000-0000-0000-0000-000000000000','authenticated','authenticated','guardian@test','',now(),now()),
 ('91000000-0000-0000-0000-000000000006','00000000-0000-0000-0000-000000000000','authenticated','authenticated','both-campuses@test','',now(),now()),
 ('91000000-0000-0000-0000-000000000007','00000000-0000-0000-0000-000000000000','authenticated','authenticated','one-campus@test','',now(),now());
insert into public.organizations(id,name,slug) values
 ('92000000-0000-0000-0000-000000000001','Enrollment Tenant','enrollment-tenant'),
 ('92000000-0000-0000-0000-000000000002','Other Enrollment Tenant','other-enrollment-tenant');
insert into public.schools(id,organization_id,name,code) values
 ('93000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000001','Administrative School','ADM'),
 ('93000000-0000-0000-0000-000000000002','92000000-0000-0000-0000-000000000001','Academic School','ACA'),
 ('93000000-0000-0000-0000-000000000003','92000000-0000-0000-0000-000000000002','Other School','OTH');
insert into public.campuses(id,organization_id,school_id,name,code) values
 ('94000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-000000000001','Admin Campus','ADM'),
 ('94000000-0000-0000-0000-000000000002','92000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-000000000002','Academic Campus','ACA'),
 ('94000000-0000-0000-0000-000000000004','92000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-000000000002','Second Academic Campus','ACB'),
 ('94000000-0000-0000-0000-000000000003','92000000-0000-0000-0000-000000000002','93000000-0000-0000-0000-000000000003','Other Campus','OTH');
insert into public.organization_memberships(id,organization_id,user_id,status,joined_at) values
 ('95000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000001','91000000-0000-0000-0000-000000000001','active',now()),
 ('95000000-0000-0000-0000-000000000002','92000000-0000-0000-0000-000000000001','91000000-0000-0000-0000-000000000002','active',now()),
 ('95000000-0000-0000-0000-000000000003','92000000-0000-0000-0000-000000000001','91000000-0000-0000-0000-000000000003','suspended',now()),
 ('95000000-0000-0000-0000-000000000004','92000000-0000-0000-0000-000000000001','91000000-0000-0000-0000-000000000006','active',now()),
 ('95000000-0000-0000-0000-000000000005','92000000-0000-0000-0000-000000000001','91000000-0000-0000-0000-000000000007','active',now());
insert into public.roles(id,organization_id,code,name) values
 ('96000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000001','ENROLL_ADMIN','Enrollment Admin'),
 ('96000000-0000-0000-0000-000000000002','92000000-0000-0000-0000-000000000001','ENROLL_NONE','No Enrollment');
insert into public.role_permissions(organization_id,role_id,permission_id) select '92000000-0000-0000-0000-000000000001','96000000-0000-0000-0000-000000000001',id from public.permissions where code in ('enrollments.view','enrollments.manage','enrollments.correct');
insert into public.role_assignments(organization_id,organization_membership_id,role_id) values
 ('92000000-0000-0000-0000-000000000001','95000000-0000-0000-0000-000000000001','96000000-0000-0000-0000-000000000001'),
 ('92000000-0000-0000-0000-000000000001','95000000-0000-0000-0000-000000000002','96000000-0000-0000-0000-000000000002'),
 ('92000000-0000-0000-0000-000000000001','95000000-0000-0000-0000-000000000003','96000000-0000-0000-0000-000000000001');
insert into public.role_assignments(organization_id,organization_membership_id,role_id,school_id,campus_id) values
 ('92000000-0000-0000-0000-000000000001','95000000-0000-0000-0000-000000000004','96000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-000000000001','94000000-0000-0000-0000-000000000001'),
 ('92000000-0000-0000-0000-000000000001','95000000-0000-0000-0000-000000000004','96000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-000000000002','94000000-0000-0000-0000-000000000002'),
 ('92000000-0000-0000-0000-000000000001','95000000-0000-0000-0000-000000000004','96000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-000000000002','94000000-0000-0000-0000-000000000004'),
 ('92000000-0000-0000-0000-000000000001','95000000-0000-0000-0000-000000000005','96000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-000000000002','94000000-0000-0000-0000-000000000002');
insert into public.students(id,organization_id,school_id,campus_id,user_id,student_number,first_name,last_name,date_of_birth) values
 ('97000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-000000000001','94000000-0000-0000-0000-000000000001','91000000-0000-0000-0000-000000000004','ENR-1','Student','One','2014-01-01'),
 ('97000000-0000-0000-0000-000000000002','92000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-000000000001','94000000-0000-0000-0000-000000000001',null,'ENR-2','Student','Two','2014-01-02'),
 ('97000000-0000-0000-0000-000000000004','92000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-000000000001','94000000-0000-0000-0000-000000000001',null,'ENR-4','Transfer','Failure Out','2014-01-04'),
 ('97000000-0000-0000-0000-000000000005','92000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-000000000001','94000000-0000-0000-0000-000000000001',null,'ENR-5','Transfer','Success Out','2014-01-05'),
 ('97000000-0000-0000-0000-000000000006','92000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-000000000001','94000000-0000-0000-0000-000000000001',null,'ENR-6','Transfer','Success In','2014-01-06'),
 ('97000000-0000-0000-0000-000000000007','92000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-000000000001','94000000-0000-0000-0000-000000000001',null,'ENR-7','Transfer','Failure In','2014-01-07'),
 ('97000000-0000-0000-0000-000000000003','92000000-0000-0000-0000-000000000002','93000000-0000-0000-0000-000000000003','94000000-0000-0000-0000-000000000003',null,'ENR-X','Other','Tenant','2014-01-03');
insert into public.guardians(id,organization_id,user_id,first_name,last_name) values('97100000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000001','91000000-0000-0000-0000-000000000005','Portal','Guardian');
insert into public.student_guardians(organization_id,student_id,guardian_id,relationship_type,has_portal_access) values('92000000-0000-0000-0000-000000000001','97000000-0000-0000-0000-000000000001','97100000-0000-0000-0000-000000000001','parent',true);
insert into public.academic_years(id,organization_id,school_id,name,start_date,end_date,status) values
 ('98000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-000000000002','2026-27','2026-09-01','2027-06-30','active'),
 ('98000000-0000-0000-0000-000000000002','92000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-000000000001','Overlap','2026-10-01','2027-05-30','active'),
 ('98000000-0000-0000-0000-000000000003','92000000-0000-0000-0000-000000000002','93000000-0000-0000-0000-000000000003','Other','2026-09-01','2027-06-30','active');
insert into public.grade_levels(id,organization_id,school_id,code,name,sequence) values
 ('98100000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-000000000002','G5','Grade 5',5),
 ('98100000-0000-0000-0000-000000000002','92000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-000000000002','G6','Grade 6',6),
 ('98100000-0000-0000-0000-000000000003','92000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-000000000001','G5','Grade 5',5),
 ('98100000-0000-0000-0000-000000000004','92000000-0000-0000-0000-000000000002','93000000-0000-0000-0000-000000000003','G5','Grade 5',5);
insert into public.sections(id,organization_id,school_id,campus_id,academic_year_id,grade_level_id,code,name,capacity,start_date,end_date,status) values
 ('99000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-000000000002','94000000-0000-0000-0000-000000000002','98000000-0000-0000-0000-000000000001','98100000-0000-0000-0000-000000000001','A','Section A',1,'2026-09-01','2027-06-30','active'),
 ('99000000-0000-0000-0000-000000000002','92000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-000000000002','94000000-0000-0000-0000-000000000002','98000000-0000-0000-0000-000000000001','98100000-0000-0000-0000-000000000001','B','Section B',2,'2026-09-01','2027-06-30','active'),
 ('99000000-0000-0000-0000-000000000003','92000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-000000000002','94000000-0000-0000-0000-000000000002','98000000-0000-0000-0000-000000000001','98100000-0000-0000-0000-000000000002','C','Wrong Grade',2,'2026-09-01','2027-06-30','active'),
 ('99000000-0000-0000-0000-000000000004','92000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-000000000002','94000000-0000-0000-0000-000000000002','98000000-0000-0000-0000-000000000001','98100000-0000-0000-0000-000000000001','D','Transfer Campus A',20,'2026-09-01','2027-06-30','active'),
 ('99000000-0000-0000-0000-000000000005','92000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-000000000002','94000000-0000-0000-0000-000000000004','98000000-0000-0000-0000-000000000001','98100000-0000-0000-0000-000000000001','E','Transfer Campus B',20,'2026-09-01','2027-06-30','active');

insert into public.student_enrollments(id,organization_id,school_id,academic_year_id,student_id,grade_level_id,enrolled_on,scheduled_end_on,enrollment_range,created_by,updated_by) values
 ('98200000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-000000000002','98000000-0000-0000-0000-000000000001','97000000-0000-0000-0000-000000000004','98100000-0000-0000-0000-000000000001','2026-09-01','2027-06-30',daterange('2026-09-01','2027-06-30','[]'),'91000000-0000-0000-0000-000000000001','91000000-0000-0000-0000-000000000001'),
 ('98200000-0000-0000-0000-000000000002','92000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-000000000002','98000000-0000-0000-0000-000000000001','97000000-0000-0000-0000-000000000005','98100000-0000-0000-0000-000000000001','2026-09-01','2027-06-30',daterange('2026-09-01','2027-06-30','[]'),'91000000-0000-0000-0000-000000000001','91000000-0000-0000-0000-000000000001'),
 ('98200000-0000-0000-0000-000000000003','92000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-000000000002','98000000-0000-0000-0000-000000000001','97000000-0000-0000-0000-000000000006','98100000-0000-0000-0000-000000000001','2026-09-01','2027-06-30',daterange('2026-09-01','2027-06-30','[]'),'91000000-0000-0000-0000-000000000001','91000000-0000-0000-0000-000000000001'),
 ('98200000-0000-0000-0000-000000000004','92000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-000000000002','98000000-0000-0000-0000-000000000001','97000000-0000-0000-0000-000000000007','98100000-0000-0000-0000-000000000001','2026-09-01','2027-06-30',daterange('2026-09-01','2027-06-30','[]'),'91000000-0000-0000-0000-000000000001','91000000-0000-0000-0000-000000000001');
insert into public.student_section_placements(id,organization_id,school_id,campus_id,academic_year_id,student_enrollment_id,student_id,section_id,starts_on,created_by,updated_by) values
 ('98300000-0000-0000-0000-000000000002','92000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-000000000002','94000000-0000-0000-0000-000000000004','98000000-0000-0000-0000-000000000001','98200000-0000-0000-0000-000000000001','97000000-0000-0000-0000-000000000004','99000000-0000-0000-0000-000000000005','2026-10-01','91000000-0000-0000-0000-000000000001','91000000-0000-0000-0000-000000000001'),
 ('98300000-0000-0000-0000-000000000004','92000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-000000000002','94000000-0000-0000-0000-000000000004','98000000-0000-0000-0000-000000000001','98200000-0000-0000-0000-000000000002','97000000-0000-0000-0000-000000000005','99000000-0000-0000-0000-000000000005','2026-10-01','91000000-0000-0000-0000-000000000001','91000000-0000-0000-0000-000000000001'),
 ('98300000-0000-0000-0000-000000000006','92000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-000000000002','94000000-0000-0000-0000-000000000004','98000000-0000-0000-0000-000000000001','98200000-0000-0000-0000-000000000003','97000000-0000-0000-0000-000000000006','99000000-0000-0000-0000-000000000005','2026-10-01','91000000-0000-0000-0000-000000000001','91000000-0000-0000-0000-000000000001'),
 ('98300000-0000-0000-0000-000000000008','92000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-000000000002','94000000-0000-0000-0000-000000000002','98000000-0000-0000-0000-000000000001','98200000-0000-0000-0000-000000000004','97000000-0000-0000-0000-000000000007','99000000-0000-0000-0000-000000000004','2026-10-01','91000000-0000-0000-0000-000000000001','91000000-0000-0000-0000-000000000001');
insert into public.student_section_placements(id,organization_id,school_id,campus_id,academic_year_id,student_enrollment_id,student_id,section_id,starts_on,ends_on,status,end_reason,transfer_to_placement_id,created_by,updated_by) values
 ('98300000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-000000000002','94000000-0000-0000-0000-000000000002','98000000-0000-0000-0000-000000000001','98200000-0000-0000-0000-000000000001','97000000-0000-0000-0000-000000000004','99000000-0000-0000-0000-000000000004','2026-09-01','2026-09-30','transferred','campus transfer','98300000-0000-0000-0000-000000000002','91000000-0000-0000-0000-000000000001','91000000-0000-0000-0000-000000000001'),
 ('98300000-0000-0000-0000-000000000003','92000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-000000000002','94000000-0000-0000-0000-000000000002','98000000-0000-0000-0000-000000000001','98200000-0000-0000-0000-000000000002','97000000-0000-0000-0000-000000000005','99000000-0000-0000-0000-000000000004','2026-09-01','2026-09-30','transferred','campus transfer','98300000-0000-0000-0000-000000000004','91000000-0000-0000-0000-000000000001','91000000-0000-0000-0000-000000000001'),
 ('98300000-0000-0000-0000-000000000005','92000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-000000000002','94000000-0000-0000-0000-000000000002','98000000-0000-0000-0000-000000000001','98200000-0000-0000-0000-000000000003','97000000-0000-0000-0000-000000000006','99000000-0000-0000-0000-000000000004','2026-09-01','2026-09-30','transferred','campus transfer','98300000-0000-0000-0000-000000000006','91000000-0000-0000-0000-000000000001','91000000-0000-0000-0000-000000000001'),
 ('98300000-0000-0000-0000-000000000007','92000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-000000000002','94000000-0000-0000-0000-000000000004','98000000-0000-0000-0000-000000000001','98200000-0000-0000-0000-000000000004','97000000-0000-0000-0000-000000000007','99000000-0000-0000-0000-000000000005','2026-09-01','2026-09-30','transferred','campus transfer','98300000-0000-0000-0000-000000000008','91000000-0000-0000-0000-000000000001','91000000-0000-0000-0000-000000000001');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"91000000-0000-0000-0000-000000000007","role":"authenticated"}',true);
select throws_ok($$select * from public.correct_student_section_placement('98300000-0000-0000-0000-000000000001',null,null,null,null,null,false,'reject imported transfer')$$,'42501','enrollments.manage permission is required','transferred-out correction requires linked campus authorization');
reset role;
select is((select string_agg(id::text||':'||status::text,',' order by id) from public.student_section_placements where id in ('98300000-0000-0000-0000-000000000001','98300000-0000-0000-0000-000000000002')),'98300000-0000-0000-0000-000000000001:transferred,98300000-0000-0000-0000-000000000002:active','failed transferred-out correction changes neither transfer row');
select is((select count(*)::int from public.audit_log where entity_id in ('98300000-0000-0000-0000-000000000001','98300000-0000-0000-0000-000000000002')),0,'failed transferred-out correction writes no audit');
select is((select count(*)::int from public.event_outbox where aggregate_id in ('98300000-0000-0000-0000-000000000001','98300000-0000-0000-0000-000000000002')),0,'failed transferred-out correction writes no outbox');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"91000000-0000-0000-0000-000000000007","role":"authenticated"}',true);
select throws_ok($$select * from public.correct_student_section_placement('98300000-0000-0000-0000-000000000008',null,null,null,null,null,false,'reject reverse transfer')$$,'42501','enrollments.manage permission is required','transferred-in correction requires linked campus authorization');
reset role;
select is((select string_agg(id::text||':'||status::text,',' order by id) from public.student_section_placements where id in ('98300000-0000-0000-0000-000000000007','98300000-0000-0000-0000-000000000008')),'98300000-0000-0000-0000-000000000007:transferred,98300000-0000-0000-0000-000000000008:active','failed transferred-in correction changes neither transfer row');
select is((select count(*)::int from public.audit_log where entity_id in ('98300000-0000-0000-0000-000000000007','98300000-0000-0000-0000-000000000008')),0,'failed transferred-in correction writes no audit');
select is((select count(*)::int from public.event_outbox where aggregate_id in ('98300000-0000-0000-0000-000000000007','98300000-0000-0000-0000-000000000008')),0,'failed transferred-in correction writes no outbox');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"91000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select lives_ok($$select * from public.correct_student_section_placement('98300000-0000-0000-0000-000000000003','99000000-0000-0000-0000-000000000004','2026-10-01',null,'active',null,true,'correct both from source')$$,'transferred-out correction creates one replacement atomically');
select set_config('request.jwt.claims','{"sub":"91000000-0000-0000-0000-000000000006","role":"authenticated"}',true);
select lives_ok($$select * from public.correct_student_section_placement('98300000-0000-0000-0000-000000000006',null,null,null,null,null,false,'correct both from destination')$$,'transferred-in correction succeeds with both campus scopes');
reset role;
select is((select count(*)::int from public.student_section_placements where id in ('98300000-0000-0000-0000-000000000003','98300000-0000-0000-0000-000000000004','98300000-0000-0000-0000-000000000005','98300000-0000-0000-0000-000000000006') and status='corrected'),4,'authorized corrections supersede both halves in both directions');
select is((select count(*)::int from public.student_section_placements where student_enrollment_id='98200000-0000-0000-0000-000000000002' and supersedes_placement_id is not null),1,'transfer correction creates only the requested single replacement placement');
select is((select count(*)::int from public.audit_log where entity_id in (select id from public.student_section_placements where student_enrollment_id='98200000-0000-0000-0000-000000000002')),3,'both original transfer halves and one replacement are audited');
select is((select count(distinct command_id)::int from public.audit_log where entity_id in (select id from public.student_section_placements where student_enrollment_id='98200000-0000-0000-0000-000000000002')),1,'transfer correction audit rows are atomically correlated');
select is((select count(*)::int from public.event_outbox where aggregate_id in (select id from public.student_section_placements where student_enrollment_id='98200000-0000-0000-0000-000000000002')),3,'both original transfer halves and one replacement emit events');
select is((select count(distinct command_id)::int from public.event_outbox where aggregate_id in (select id from public.student_section_placements where student_enrollment_id='98200000-0000-0000-0000-000000000002')),1,'transfer correction outbox rows are atomically correlated');

set local role anon;
select throws_ok($$select public.enroll_student('97000000-0000-0000-0000-000000000001','98000000-0000-0000-0000-000000000001','98100000-0000-0000-0000-000000000001','2026-09-01')$$,'42501','permission denied for function enroll_student','anonymous denied');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"91000000-0000-0000-0000-000000000002","role":"authenticated"}',true);
select throws_ok($$select public.enroll_student('97000000-0000-0000-0000-000000000001','98000000-0000-0000-0000-000000000001','98100000-0000-0000-0000-000000000001','2026-09-01')$$,'42501','enrollments.manage permission is required','missing permission denied');
select set_config('request.jwt.claims','{"sub":"91000000-0000-0000-0000-000000000003","role":"authenticated"}',true);
select throws_ok($$select public.enroll_student('97000000-0000-0000-0000-000000000001','98000000-0000-0000-0000-000000000001','98100000-0000-0000-0000-000000000001','2026-09-01')$$,'42501','enrollments.manage permission is required','inactive membership denied');
select set_config('request.jwt.claims','{"sub":"91000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.enroll_student('97000000-0000-0000-0000-000000000003','98000000-0000-0000-0000-000000000003','98100000-0000-0000-0000-000000000004','2026-09-01')$$,'42501','enrollments.manage permission is required','cross-tenant denied');
select lives_ok($$select public.enroll_student('97000000-0000-0000-0000-000000000001','98000000-0000-0000-0000-000000000001','98100000-0000-0000-0000-000000000001','2026-09-01')$$,'same-tenant cross-school enrollment succeeds');
select is((select school_id from public.student_enrollments where student_id='97000000-0000-0000-0000-000000000001'),'93000000-0000-0000-0000-000000000002'::uuid,'academic school does not mutate SIS scope');
reset role;
select is((select school_id from public.students where id='97000000-0000-0000-0000-000000000001'),'93000000-0000-0000-0000-000000000001'::uuid,'SIS administrative school remains unchanged');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"91000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.enroll_student('97000000-0000-0000-0000-000000000001','98000000-0000-0000-0000-000000000002','98100000-0000-0000-0000-000000000003','2026-10-01')$$,'23P01',null,'overlapping cross-school enrollment rejected');
select throws_ok($$select public.enroll_student('97000000-0000-0000-0000-000000000002','98000000-0000-0000-0000-000000000001','98100000-0000-0000-0000-000000000001','2026-08-31')$$,'22023','enrollment date must be inside academic year','date outside year rejected');
select lives_ok($$select public.enroll_student('97000000-0000-0000-0000-000000000002','98000000-0000-0000-0000-000000000001','98100000-0000-0000-0000-000000000001','2026-09-01')$$,'second enrollment succeeds');
select lives_ok($$select public.place_student_in_section((select id from public.student_enrollments where student_id='97000000-0000-0000-0000-000000000001' and status='active'),'99000000-0000-0000-0000-000000000001','2026-09-01')$$,'placement succeeds');
select throws_ok($$select public.place_student_in_section((select id from public.student_enrollments where student_id='97000000-0000-0000-0000-000000000002' and status='active'),'99000000-0000-0000-0000-000000000001','2027-01-01')$$,'22023','section capacity is full','future placement reserves capacity');
select throws_ok($$select public.place_student_in_section((select id from public.student_enrollments where student_id='97000000-0000-0000-0000-000000000002' and status='active'),'99000000-0000-0000-0000-000000000003','2026-09-01')$$,'22023','active section with matching enrollment grade and scope is required','grade mismatch denied');
select lives_ok($$select * from public.transfer_student_section((select id from public.student_section_placements where section_id='99000000-0000-0000-0000-000000000001'),'99000000-0000-0000-0000-000000000002','2026-10-01','cohort move')$$,'atomic transfer succeeds');
select is((select ends_on from public.student_section_placements where section_id='99000000-0000-0000-0000-000000000001'),'2026-09-30'::date,'source ends D-1');
select is((select starts_on from public.student_section_placements where section_id='99000000-0000-0000-0000-000000000002' and status='active'),'2026-10-01'::date,'destination starts D');
reset role;
select is((select count(distinct command_id)::int from public.event_outbox where event_type in ('student.section_transferred_out','student.section_transferred_in')),1,'transfer events share command ID');
select is((select count(*)::int from public.event_outbox where event_type in ('student.section_transferred_out','student.section_transferred_in')),2,'transfer emits two minimal events');
select ok(not exists(select 1 from public.event_outbox where event_type like 'student.%' and (payload ? 'first_name' or payload ? 'date_of_birth' or payload ? 'identifier_value' or payload ? 'storage_path')),'events denylist PII and sensitive fields');

reset role;
select lives_ok($$set local role authenticated; select set_config('request.jwt.claims','{"sub":"91000000-0000-0000-0000-000000000004","role":"authenticated"}',true); select count(*) from public.student_enrollments$$,'student self can read enrollment');
reset role;
select lives_ok($$set local role authenticated; select set_config('request.jwt.claims','{"sub":"91000000-0000-0000-0000-000000000005","role":"authenticated"}',true); select count(*) from public.student_section_placements$$,'active portal guardian can read placement');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"91000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select lives_ok($$select public.withdraw_student_enrollment((select id from public.student_enrollments where student_id='97000000-0000-0000-0000-000000000001' and status='active'),'2026-12-01','left school')$$,'enrollment withdrawal succeeds');
select is((select status from public.student_section_placements where section_id='99000000-0000-0000-0000-000000000002'),'withdrawn'::public.section_placement_status,'enrollment ending terminates active placement');
reset role;
select is((select count(distinct command_id)::int from public.audit_log where action in ('student.enrollment_withdrawn','student.section_withdrawn') and entity_id in (select id from public.student_enrollments union select id from public.student_section_placements)),1,'cascaded termination is command-correlated');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"91000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.withdraw_student_enrollment((select id from public.student_enrollments where student_id='97000000-0000-0000-0000-000000000001'),'2026-12-02','again')$$,'22023','active enrollment and parents are required','terminal enrollment immutable');
select lives_ok($$select * from public.correct_student_enrollment((select id from public.student_enrollments where student_id='97000000-0000-0000-0000-000000000001'),'98000000-0000-0000-0000-000000000001','98100000-0000-0000-0000-000000000001','2026-09-01','active',null,null,true,'source record wrong')$$,'append-and-supersede enrollment correction succeeds');
select is((select count(*)::int from public.student_enrollments where student_id='97000000-0000-0000-0000-000000000001' and status='corrected'),1,'original enrollment retained as corrected');
select is((select count(*)::int from public.student_enrollments where student_id='97000000-0000-0000-0000-000000000001' and supersedes_enrollment_id is not null),1,'replacement links to predecessor');
select lives_ok($$select * from public.correct_student_enrollment((select id from public.student_enrollments where student_id='97000000-0000-0000-0000-000000000002' and status='active'),'98000000-0000-0000-0000-000000000001','98100000-0000-0000-0000-000000000001','2026-09-01','completed','2027-06-30','year completed',true,'correct imported outcome')$$,'terminal replacement enrollment is created in one correlated command');
select is((select status from public.student_enrollments where student_id='97000000-0000-0000-0000-000000000002' and supersedes_enrollment_id is not null),'completed'::public.enrollment_status,'terminal replacement enrollment persists directly');
select lives_ok($$select public.place_student_in_section((select id from public.student_enrollments where student_id='97000000-0000-0000-0000-000000000001' and status='active'),'99000000-0000-0000-0000-000000000002','2027-01-01')$$,'placement for terminal correction exists');
select lives_ok($$select * from public.correct_student_section_placement((select id from public.student_section_placements where student_id='97000000-0000-0000-0000-000000000001' and status='active'),'99000000-0000-0000-0000-000000000002','2027-01-01','2027-06-30','completed','section completed',true,'correct placement outcome')$$,'terminal replacement placement is created without duplicate audit correlation');
select is((select status from public.student_section_placements where student_id='97000000-0000-0000-0000-000000000001' and supersedes_placement_id is not null),'completed'::public.section_placement_status,'terminal replacement placement persists directly');

reset role;
create function pg_temp.reject_enrollment_event() returns trigger language plpgsql as $$begin raise exception 'forced outbox failure'; end$$;
create trigger reject_enrollment_event before insert on public.event_outbox for each row when(new.event_type='student.section_placed') execute function pg_temp.reject_enrollment_event();
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"91000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.place_student_in_section((select id from public.student_enrollments where student_id='97000000-0000-0000-0000-000000000001' and status='active'),'99000000-0000-0000-0000-000000000002','2027-01-01')$$,'P0001','forced outbox failure','outbox failure aborts command');
reset role;
select is((select count(*)::int from public.student_section_placements where student_id='97000000-0000-0000-0000-000000000001' and status='active'),0,'outbox failure rolls back placement');
drop trigger reject_enrollment_event on public.event_outbox;

select * from finish();
rollback;
