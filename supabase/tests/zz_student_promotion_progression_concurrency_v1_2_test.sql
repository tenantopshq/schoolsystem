begin;
create extension if not exists pgtap with schema extensions;
create extension if not exists dblink with schema extensions;
select no_plan();

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,created_at,updated_at) values
 ('d3100000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','approver@race.test','',now(),now()),
 ('d3100000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','executor@race.test','',now(),now());
insert into public.organizations(id,name,slug) values('d3200000-0000-0000-0000-000000000001','Progress Race','progress-race');
insert into public.schools(id,organization_id,name,code) values('d3300000-0000-0000-0000-000000000001','d3200000-0000-0000-0000-000000000001','Race School','RACE');
insert into public.campuses(id,organization_id,school_id,name,code) values('d3400000-0000-0000-0000-000000000001','d3200000-0000-0000-0000-000000000001','d3300000-0000-0000-0000-000000000001','Race Campus','RC');
insert into public.organization_memberships(id,organization_id,user_id,status,joined_at) values
 ('d3500000-0000-0000-0000-000000000001','d3200000-0000-0000-0000-000000000001','d3100000-0000-0000-0000-000000000001','active',now()),
 ('d3500000-0000-0000-0000-000000000002','d3200000-0000-0000-0000-000000000001','d3100000-0000-0000-0000-000000000002','active',now());
insert into public.roles(id,organization_id,code,name) values('d3600000-0000-0000-0000-000000000001','d3200000-0000-0000-0000-000000000001','RACE_ADMIN','Race Admin');
insert into public.role_permissions(organization_id,role_id,permission_id) select 'd3200000-0000-0000-0000-000000000001','d3600000-0000-0000-0000-000000000001',id from public.permissions where code like 'progression.%';
insert into public.role_assignments(organization_id,organization_membership_id,role_id) values
 ('d3200000-0000-0000-0000-000000000001','d3500000-0000-0000-0000-000000000001','d3600000-0000-0000-0000-000000000001'),
 ('d3200000-0000-0000-0000-000000000001','d3500000-0000-0000-0000-000000000002','d3600000-0000-0000-0000-000000000001');
insert into public.academic_years(id,organization_id,school_id,name,start_date,end_date,status) values
 ('d3700000-0000-0000-0000-000000000001','d3200000-0000-0000-0000-000000000001','d3300000-0000-0000-0000-000000000001','2026-27','2026-01-01','2026-12-31','active'),
 ('d3700000-0000-0000-0000-000000000002','d3200000-0000-0000-0000-000000000001','d3300000-0000-0000-0000-000000000001','2027-28','2027-01-01','2027-12-31','active');
insert into public.grade_levels(id,organization_id,school_id,code,name,sequence,status) values
 ('d3800000-0000-0000-0000-000000000001','d3200000-0000-0000-0000-000000000001','d3300000-0000-0000-0000-000000000001','G1','Grade 1',1,'active'),
 ('d3800000-0000-0000-0000-000000000002','d3200000-0000-0000-0000-000000000001','d3300000-0000-0000-0000-000000000001','G2','Grade 2',2,'active');
insert into public.sections(id,organization_id,school_id,campus_id,academic_year_id,grade_level_id,code,name,capacity,start_date,end_date,status) values
 ('91900000-0000-0000-0000-000000000001','d3200000-0000-0000-0000-000000000001','d3300000-0000-0000-0000-000000000001','d3400000-0000-0000-0000-000000000001','d3700000-0000-0000-0000-000000000001','d3800000-0000-0000-0000-000000000001','1A','Grade 1',10,'2026-01-01','2026-12-31','active'),
 ('91900000-0000-0000-0000-000000000002','d3200000-0000-0000-0000-000000000001','d3300000-0000-0000-0000-000000000001','d3400000-0000-0000-0000-000000000001','d3700000-0000-0000-0000-000000000002','d3800000-0000-0000-0000-000000000002','2A','Last Seat',1,'2027-01-01','2027-12-31','active');
insert into public.students(id,organization_id,school_id,campus_id,student_number,first_name,last_name,date_of_birth,status) values
 ('92000000-0000-0000-0000-000000000001','d3200000-0000-0000-0000-000000000001','d3300000-0000-0000-0000-000000000001','d3400000-0000-0000-0000-000000000001','R1','Race','One','2018-01-01','active'),
 ('92000000-0000-0000-0000-000000000002','d3200000-0000-0000-0000-000000000001','d3300000-0000-0000-0000-000000000001','d3400000-0000-0000-0000-000000000001','R2','Race','Two','2018-01-01','active'),
 ('92000000-0000-0000-0000-000000000003','d3200000-0000-0000-0000-000000000001','d3300000-0000-0000-0000-000000000001','d3400000-0000-0000-0000-000000000001','R3','Replay','Three','2018-01-01','active');
insert into public.student_enrollments(id,organization_id,school_id,academic_year_id,student_id,grade_level_id,enrolled_on,scheduled_end_on,enrollment_range,status,created_by,updated_by) values
 ('92100000-0000-0000-0000-000000000001','d3200000-0000-0000-0000-000000000001','d3300000-0000-0000-0000-000000000001','d3700000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000001','d3800000-0000-0000-0000-000000000001','2026-01-01','2026-12-31',daterange('2026-01-01','2026-12-31','[]'),'active','d3100000-0000-0000-0000-000000000001','d3100000-0000-0000-0000-000000000001'),
 ('92100000-0000-0000-0000-000000000002','d3200000-0000-0000-0000-000000000001','d3300000-0000-0000-0000-000000000001','d3700000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000002','d3800000-0000-0000-0000-000000000001','2026-01-01','2026-12-31',daterange('2026-01-01','2026-12-31','[]'),'active','d3100000-0000-0000-0000-000000000001','d3100000-0000-0000-0000-000000000001'),
 ('92100000-0000-0000-0000-000000000003','d3200000-0000-0000-0000-000000000001','d3300000-0000-0000-0000-000000000001','d3700000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000003','d3800000-0000-0000-0000-000000000001','2026-01-01','2026-12-31',daterange('2026-01-01','2026-12-31','[]'),'active','d3100000-0000-0000-0000-000000000001','d3100000-0000-0000-0000-000000000001');
insert into public.student_section_placements(organization_id,school_id,campus_id,academic_year_id,student_enrollment_id,student_id,section_id,starts_on,status,created_by,updated_by)
 select 'd3200000-0000-0000-0000-000000000001','d3300000-0000-0000-0000-000000000001','d3400000-0000-0000-0000-000000000001','d3700000-0000-0000-0000-000000000001',e.id,e.student_id,'91900000-0000-0000-0000-000000000001','2026-01-01','active','d3100000-0000-0000-0000-000000000001','d3100000-0000-0000-0000-000000000001' from public.student_enrollments e where e.id::text like '921%';

-- Approved decisions and immutable incomplete evaluations are fixture state.
insert into public.progression_decisions(id,organization_id,student_id,source_school_id,source_campus_id,source_academic_year_id,source_grade_level_id,source_enrollment_id,source_placement_id,disposition,source_end_on,destination_school_id,destination_campus_id,destination_academic_year_id,destination_grade_level_id,destination_section_id,destination_enrolled_on,lineage_id,version,status,eligibility_override_reason,approved_at,approved_by,approval_reason,created_by,updated_by)
select ('93000000-0000-0000-0000-00000000000'||n)::uuid,'d3200000-0000-0000-0000-000000000001',('92000000-0000-0000-0000-00000000000'||n)::uuid,'d3300000-0000-0000-0000-000000000001','d3400000-0000-0000-0000-000000000001','d3700000-0000-0000-0000-000000000001','d3800000-0000-0000-0000-000000000001',('92100000-0000-0000-0000-00000000000'||n)::uuid,p.id,
 case when n=3 then 'graduation'::public.progression_disposition else 'promotion'::public.progression_disposition end,'2026-12-31',
 case when n=3 then null else 'd3300000-0000-0000-0000-000000000001'::uuid end,case when n=3 then null else 'd3400000-0000-0000-0000-000000000001'::uuid end,
 case when n=3 then null else 'd3700000-0000-0000-0000-000000000002'::uuid end,case when n=3 then null else 'd3800000-0000-0000-0000-000000000002'::uuid end,
 case when n=3 then null else '91900000-0000-0000-0000-000000000002'::uuid end,case when n=3 then null else '2027-01-01'::date end,
 ('93000000-0000-0000-0000-00000000000'||n)::uuid,1,'approved','manual race exception',now(),'d3100000-0000-0000-0000-000000000001','race approved','d3100000-0000-0000-0000-000000000001','d3100000-0000-0000-0000-000000000001'
from generate_series(1,3)n join public.student_section_placements p on p.student_id=('92000000-0000-0000-0000-00000000000'||n)::uuid;
insert into public.progression_eligibility_evaluations(id,organization_id,progression_decision_id,student_id,sequence,state,source_fingerprint,evaluated_by)
select ('93100000-0000-0000-0000-00000000000'||n)::uuid,'d3200000-0000-0000-0000-000000000001',('93000000-0000-0000-0000-00000000000'||n)::uuid,('92000000-0000-0000-0000-00000000000'||n)::uuid,1,'incomplete',app_auth.progression_source_fingerprint(('93000000-0000-0000-0000-00000000000'||n)::uuid),'d3100000-0000-0000-0000-000000000001' from generate_series(1,3)n;
update public.progression_decisions d set current_eligibility_evaluation_id=('93100000-0000-0000-0000-00000000000'||right(d.id::text,1))::uuid;

create function app_auth.test_capture_progression(p_actor uuid,p_sql text) returns text language plpgsql security definer set search_path='' as $$begin perform set_config('request.jwt.claims',jsonb_build_object('sub',p_actor,'role','authenticated')::text,true);execute p_sql;return '00000';exception when others then return sqlstate;end$$;
revoke all on function app_auth.test_capture_progression(uuid,text) from public,anon,authenticated,service_role;
create function app_auth.test_hold_progression(p_actor uuid,p_organization uuid,p_sql text) returns text language plpgsql security definer set search_path='' as $$begin
	perform set_config('request.jwt.claims',jsonb_build_object('sub',p_actor,'role','authenticated')::text,true);
	perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('school-platform:progression:'||p_organization::text,0));
	perform 1 from public.organizations where id=p_organization for update;
 perform pg_sleep(.5);
 execute p_sql;
 return '00000';
exception when others then return sqlstate;end$$;
revoke all on function app_auth.test_hold_progression(uuid,uuid,text) from public,anon,authenticated,service_role;
commit;

select extensions.dblink_connect('pr_one','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');
select extensions.dblink_connect('pr_two','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');

-- Two independent sessions compete for the final destination seat.
select is(extensions.dblink_send_query('pr_one',format('select app_auth.test_capture_progression(%L,%L)','d3100000-0000-0000-0000-000000000002','select public.execute_progression_decision(''94000000-0000-0000-0000-000000000001'',''93000000-0000-0000-0000-000000000001'')')),1,'first capacity command dispatched');
select is(extensions.dblink_send_query('pr_two',format('select app_auth.test_capture_progression(%L,%L)','d3100000-0000-0000-0000-000000000002','select public.execute_progression_decision(''94000000-0000-0000-0000-000000000002'',''93000000-0000-0000-0000-000000000002'')')),1,'second capacity command dispatched');
select lives_ok($$select pg_sleep(0.2)$$,'capacity commands overlap');
create temp table capacity_race(status text);
insert into capacity_race select status from extensions.dblink_get_result('pr_one')as t(status text);
insert into capacity_race select status from extensions.dblink_get_result('pr_two')as t(status text);
select is((select array_agg(status order by status)::text from capacity_race),'{00000,22023}','capacity race has one atomic winner');
select is((select count(*)::int from public.student_section_placements where section_id='91900000-0000-0000-0000-000000000002' and status='active'),1,'capacity remains exact');
select is((select count(*)::int from public.progression_decisions where id in('93000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-000000000002') and status='executed'),1,'only winning decision executes');
select is((select count(*)::int from public.student_enrollments where student_id in('92000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000002') and status='active'),2,'loser source and winner destination remain active without partial effects');
select extensions.dblink_disconnect('pr_one'); select extensions.dblink_disconnect('pr_two');
select extensions.dblink_connect('pr_one','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');
select extensions.dblink_connect('pr_two','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');

-- Same request and decision execute concurrently: one effect, exact replay.
select is(extensions.dblink_send_query('pr_one',format('select app_auth.test_capture_progression(%L,%L)','d3100000-0000-0000-0000-000000000002','select public.execute_progression_decision(''94000000-0000-0000-0000-000000000003'',''93000000-0000-0000-0000-000000000003'')')),1,'first idempotent command dispatched');
select is(extensions.dblink_send_query('pr_two',format('select app_auth.test_capture_progression(%L,%L)','d3100000-0000-0000-0000-000000000002','select public.execute_progression_decision(''94000000-0000-0000-0000-000000000003'',''93000000-0000-0000-0000-000000000003'')')),1,'second idempotent command dispatched');
select lives_ok($$select pg_sleep(0.2)$$,'idempotent commands overlap');
create temp table replay_race(status text);
insert into replay_race select status from extensions.dblink_get_result('pr_one')as t(status text);
insert into replay_race select status from extensions.dblink_get_result('pr_two')as t(status text);
select is((select array_agg(status order by status)::text from replay_race),'{00000,00000}','concurrent exact replay succeeds twice');
select is((select count(*)::int from public.event_outbox where aggregate_id='93000000-0000-0000-0000-000000000003' and event_type='student.progression_executed'),1,'concurrent replay emits one event');
select is((select count(*)::int from public.audit_log where entity_id='93000000-0000-0000-0000-000000000003' and action='student.progression_executed'),1,'concurrent replay writes one audit');
select is((select count(*)::int from public.student_enrollments where student_id='92000000-0000-0000-0000-000000000003'),1,'graduation replay creates no duplicate enrollment');

select extensions.dblink_disconnect('pr_one'); select extensions.dblink_disconnect('pr_two');

-- Opposite-direction transfers use sorted shared-parent locks and cannot deadlock.
begin;
insert into public.schools(id,organization_id,name,code) values('b1000000-0000-0000-0000-000000000001','d3200000-0000-0000-0000-000000000001','Race School B','RACEB');
insert into public.campuses(id,organization_id,school_id,name,code) values('b1000000-0000-0000-0000-000000000002','d3200000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001','Race Campus B','RCB');
insert into public.academic_years(id,organization_id,school_id,name,start_date,end_date,status) values
 ('b1000000-0000-0000-0000-000000000003','d3200000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001','2026-27 B','2026-01-01','2026-12-31','active'),
 ('b1000000-0000-0000-0000-000000000004','d3200000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001','2027-28 B','2027-01-01','2027-12-31','active');
insert into public.grade_levels(id,organization_id,school_id,code,name,sequence,status) values
 ('b1000000-0000-0000-0000-000000000005','d3200000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001','G1','Grade 1',1,'active'),
 ('b1000000-0000-0000-0000-000000000006','d3200000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001','G2','Grade 2',2,'active');
insert into public.sections(id,organization_id,school_id,campus_id,academic_year_id,grade_level_id,code,name,capacity,start_date,end_date,status) values
 ('b1000000-0000-0000-0000-000000000007','d3200000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000002','b1000000-0000-0000-0000-000000000003','b1000000-0000-0000-0000-000000000005','B1','B source',10,'2026-01-01','2026-12-31','active'),
 ('b1000000-0000-0000-0000-000000000008','d3200000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000002','b1000000-0000-0000-0000-000000000004','b1000000-0000-0000-0000-000000000006','B2','B destination',10,'2027-01-01','2027-12-31','active');
insert into public.students(id,organization_id,school_id,campus_id,student_number,first_name,last_name,date_of_birth,status) values
 ('b1000000-0000-0000-0000-000000000009','d3200000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000002','BX','Cross','Back','2018-01-01','active'),
 ('b1000000-0000-0000-0000-00000000000e','d3200000-0000-0000-0000-000000000001','d3300000-0000-0000-0000-000000000001','d3400000-0000-0000-0000-000000000001','AX','Cross','Forward','2018-01-01','active');
insert into public.student_enrollments(id,organization_id,school_id,academic_year_id,student_id,grade_level_id,enrolled_on,scheduled_end_on,enrollment_range,status,created_by,updated_by) values
 ('b1000000-0000-0000-0000-00000000000a','d3200000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000003','b1000000-0000-0000-0000-000000000009','b1000000-0000-0000-0000-000000000005','2026-01-01','2026-12-31',daterange('2026-01-01','2026-12-31','[]'),'active','d3100000-0000-0000-0000-000000000001','d3100000-0000-0000-0000-000000000001'),
 ('b1000000-0000-0000-0000-00000000000f','d3200000-0000-0000-0000-000000000001','d3300000-0000-0000-0000-000000000001','d3700000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-00000000000e','d3800000-0000-0000-0000-000000000001','2026-01-01','2026-12-31',daterange('2026-01-01','2026-12-31','[]'),'active','d3100000-0000-0000-0000-000000000001','d3100000-0000-0000-0000-000000000001');
insert into public.student_section_placements(id,organization_id,school_id,campus_id,academic_year_id,student_enrollment_id,student_id,section_id,starts_on,status,created_by,updated_by) values('b1000000-0000-0000-0000-00000000000b','d3200000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000002','b1000000-0000-0000-0000-000000000003','b1000000-0000-0000-0000-00000000000a','b1000000-0000-0000-0000-000000000009','b1000000-0000-0000-0000-000000000007','2026-01-01','active','d3100000-0000-0000-0000-000000000001','d3100000-0000-0000-0000-000000000001');
insert into public.student_section_placements(id,organization_id,school_id,campus_id,academic_year_id,student_enrollment_id,student_id,section_id,starts_on,status,created_by,updated_by) values('b1000000-0000-0000-0000-000000000010','d3200000-0000-0000-0000-000000000001','d3300000-0000-0000-0000-000000000001','d3400000-0000-0000-0000-000000000001','d3700000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-00000000000f','b1000000-0000-0000-0000-00000000000e','91900000-0000-0000-0000-000000000001','2026-01-01','active','d3100000-0000-0000-0000-000000000001','d3100000-0000-0000-0000-000000000001');
-- Use fresh students in both schools so this race is independent of the capacity race.
insert into public.progression_decisions(id,organization_id,student_id,source_school_id,source_campus_id,source_academic_year_id,source_grade_level_id,source_enrollment_id,source_placement_id,disposition,source_end_on,destination_school_id,destination_campus_id,destination_academic_year_id,destination_grade_level_id,destination_section_id,destination_enrolled_on,lineage_id,version,status,eligibility_override_reason,approved_at,approved_by,approval_reason,created_by,updated_by) values
 ('b1000000-0000-0000-0000-00000000000c','d3200000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-00000000000e','d3300000-0000-0000-0000-000000000001','d3400000-0000-0000-0000-000000000001','d3700000-0000-0000-0000-000000000001','d3800000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-00000000000f','b1000000-0000-0000-0000-000000000010','transfer','2026-12-31','b1000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000002','b1000000-0000-0000-0000-000000000004','b1000000-0000-0000-0000-000000000006','b1000000-0000-0000-0000-000000000008','2027-01-01','b1000000-0000-0000-0000-00000000000c',1,'approved','race override',now(),'d3100000-0000-0000-0000-000000000001','approved','d3100000-0000-0000-0000-000000000001','d3100000-0000-0000-0000-000000000001'),
 ('b1000000-0000-0000-0000-00000000000d','d3200000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000009','b1000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000002','b1000000-0000-0000-0000-000000000003','b1000000-0000-0000-0000-000000000005','b1000000-0000-0000-0000-00000000000a','b1000000-0000-0000-0000-00000000000b','transfer','2026-12-31','d3300000-0000-0000-0000-000000000001','d3400000-0000-0000-0000-000000000001','d3700000-0000-0000-0000-000000000002','d3800000-0000-0000-0000-000000000002',null,'2027-01-01','b1000000-0000-0000-0000-00000000000d',1,'approved','race override',now(),'d3100000-0000-0000-0000-000000000001','approved','d3100000-0000-0000-0000-000000000001','d3100000-0000-0000-0000-000000000001');
insert into public.progression_eligibility_evaluations(id,organization_id,progression_decision_id,student_id,sequence,state,source_fingerprint,evaluated_by) select gen_random_uuid(),organization_id,id,student_id,1,'incomplete',app_auth.progression_source_fingerprint(id),'d3100000-0000-0000-0000-000000000001' from public.progression_decisions where id in('b1000000-0000-0000-0000-00000000000c','b1000000-0000-0000-0000-00000000000d');
update public.progression_decisions d set current_eligibility_evaluation_id=e.id from public.progression_eligibility_evaluations e where e.progression_decision_id=d.id and d.id in('b1000000-0000-0000-0000-00000000000c','b1000000-0000-0000-0000-00000000000d');
commit;
select extensions.dblink_connect('pr_one','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');
select extensions.dblink_connect('pr_two','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');
select is(extensions.dblink_send_query('pr_one',format('select app_auth.test_hold_progression(%L,%L,%L)','d3100000-0000-0000-0000-000000000002','d3200000-0000-0000-0000-000000000001','select public.execute_progression_decision(''b1000000-0000-0000-0000-000000000101'',''b1000000-0000-0000-0000-00000000000c'')')),1,'outbound transfer dispatched');
select lives_ok($$select pg_sleep(.1)$$,'outbound transfer holds shared parent lock');
select is(extensions.dblink_send_query('pr_two',format('select app_auth.test_capture_progression(%L,%L)','d3100000-0000-0000-0000-000000000002','select public.execute_progression_decision(''b1000000-0000-0000-0000-000000000102'',''b1000000-0000-0000-0000-00000000000d'')')),1,'inbound transfer dispatched');
select lives_ok($$select pg_sleep(.1)$$,'opposite transfer overlaps');
select is(extensions.dblink_is_busy('pr_two'),1,'opposite transfer blocks before release');
create temp table transfer_race(status text);
insert into transfer_race select status from extensions.dblink_get_result('pr_one') as t(status text);
insert into transfer_race select status from extensions.dblink_get_result('pr_two') as t(status text);
select is((select array_agg(status order by status)::text from transfer_race),'{00000,00000}','opposite transfers both succeed without deadlock');
select is((select count(*)::int from public.progression_decisions where id in('b1000000-0000-0000-0000-00000000000c','b1000000-0000-0000-0000-00000000000d') and status='executed'),2,'both transfer decisions execute');
select is((select count(*)::int from public.student_enrollments where student_id in('b1000000-0000-0000-0000-00000000000e','b1000000-0000-0000-0000-000000000009') and status='active'),2,'each student has one active destination enrollment');
select is((select count(*)::int from public.event_outbox where aggregate_id in('b1000000-0000-0000-0000-00000000000c','b1000000-0000-0000-0000-00000000000d') and event_type='student.progression_executed'),2,'transfer commands emit one aggregate event each');
select is((select count(*)::int from public.audit_log where entity_id in('b1000000-0000-0000-0000-00000000000c','b1000000-0000-0000-0000-00000000000d') and action='student.progression_executed'),2,'transfer commands write one aggregate audit each');
select extensions.dblink_disconnect('pr_one'); select extensions.dblink_disconnect('pr_two');

-- Parent lifecycle changes and progression commands serialize on the same context parents.
begin;
create function app_auth.test_hold_command(p_actor uuid,p_sql text) returns text language plpgsql security definer set search_path='' as $$begin
 perform set_config('request.jwt.claims',jsonb_build_object('sub',p_actor,'role','authenticated')::text,true);
 execute p_sql;
 perform pg_sleep(.5);
 return '00000';
exception when others then return sqlstate;end$$;
revoke all on function app_auth.test_hold_command(uuid,text) from public,anon,authenticated,service_role;
insert into public.role_permissions(organization_id,role_id,permission_id)
 select 'd3200000-0000-0000-0000-000000000001','d3600000-0000-0000-0000-000000000001',id from public.permissions where code='academic_periods.manage'
 on conflict do nothing;
insert into public.academic_years(id,organization_id,school_id,name,start_date,end_date,status) values
 ('b2000000-0000-0000-0000-000000000001','d3200000-0000-0000-0000-000000000001','d3300000-0000-0000-0000-000000000001','Parent approval source','2028-01-01','2028-12-31','active'),
 ('b2000000-0000-0000-0000-000000000002','d3200000-0000-0000-0000-000000000001','d3300000-0000-0000-0000-000000000001','Parent approval destination','2029-01-01','2029-12-31','active'),
 ('b2000000-0000-0000-0000-000000000003','d3200000-0000-0000-0000-000000000001','d3300000-0000-0000-0000-000000000001','Parent execution source','2030-01-01','2030-12-31','active'),
 ('b2000000-0000-0000-0000-000000000004','d3200000-0000-0000-0000-000000000001','d3300000-0000-0000-0000-000000000001','Parent execution destination','2031-01-01','2031-12-31','active');
insert into public.grade_levels(id,organization_id,school_id,code,name,sequence,status) values
 ('b2000000-0000-0000-0000-000000000005','d3200000-0000-0000-0000-000000000001','d3300000-0000-0000-0000-000000000001','PA1','Parent approval 1',11,'active'),
 ('b2000000-0000-0000-0000-000000000006','d3200000-0000-0000-0000-000000000001','d3300000-0000-0000-0000-000000000001','PA2','Parent approval 2',12,'active'),
 ('b2000000-0000-0000-0000-000000000007','d3200000-0000-0000-0000-000000000001','d3300000-0000-0000-0000-000000000001','PE1','Parent execution 1',13,'active'),
 ('b2000000-0000-0000-0000-000000000008','d3200000-0000-0000-0000-000000000001','d3300000-0000-0000-0000-000000000001','PE2','Parent execution 2',14,'active');
insert into public.sections(id,organization_id,school_id,campus_id,academic_year_id,grade_level_id,code,name,capacity,start_date,end_date,status) values
 ('b2000000-0000-0000-0000-000000000009','d3200000-0000-0000-0000-000000000001','d3300000-0000-0000-0000-000000000001','d3400000-0000-0000-0000-000000000001','b2000000-0000-0000-0000-000000000001','b2000000-0000-0000-0000-000000000005','PAS','Parent approval source',10,'2028-01-01','2028-12-31','active'),
 ('b2000000-0000-0000-0000-00000000000a','d3200000-0000-0000-0000-000000000001','d3300000-0000-0000-0000-000000000001','d3400000-0000-0000-0000-000000000001','b2000000-0000-0000-0000-000000000003','b2000000-0000-0000-0000-000000000007','PES','Parent execution source',10,'2030-01-01','2030-12-31','active');
insert into public.students(id,organization_id,school_id,campus_id,student_number,first_name,last_name,date_of_birth,status) values
 ('b2000000-0000-0000-0000-00000000000b','d3200000-0000-0000-0000-000000000001','d3300000-0000-0000-0000-000000000001','d3400000-0000-0000-0000-000000000001','PARENT-A','Parent','Approval','2018-01-01','active'),
 ('b2000000-0000-0000-0000-00000000000c','d3200000-0000-0000-0000-000000000001','d3300000-0000-0000-0000-000000000001','d3400000-0000-0000-0000-000000000001','PARENT-E','Parent','Execution','2018-01-01','active');
insert into public.student_enrollments(id,organization_id,school_id,academic_year_id,student_id,grade_level_id,enrolled_on,scheduled_end_on,enrollment_range,status,created_by,updated_by) values
 ('b2000000-0000-0000-0000-00000000000d','d3200000-0000-0000-0000-000000000001','d3300000-0000-0000-0000-000000000001','b2000000-0000-0000-0000-000000000001','b2000000-0000-0000-0000-00000000000b','b2000000-0000-0000-0000-000000000005','2028-01-01','2028-12-31',daterange('2028-01-01','2028-12-31','[]'),'active','d3100000-0000-0000-0000-000000000002','d3100000-0000-0000-0000-000000000002'),
 ('b2000000-0000-0000-0000-00000000000e','d3200000-0000-0000-0000-000000000001','d3300000-0000-0000-0000-000000000001','b2000000-0000-0000-0000-000000000003','b2000000-0000-0000-0000-00000000000c','b2000000-0000-0000-0000-000000000007','2030-01-01','2030-12-31',daterange('2030-01-01','2030-12-31','[]'),'active','d3100000-0000-0000-0000-000000000001','d3100000-0000-0000-0000-000000000001');
insert into public.student_section_placements(id,organization_id,school_id,campus_id,academic_year_id,student_enrollment_id,student_id,section_id,starts_on,status,created_by,updated_by) values
 ('b2000000-0000-0000-0000-00000000000f','d3200000-0000-0000-0000-000000000001','d3300000-0000-0000-0000-000000000001','d3400000-0000-0000-0000-000000000001','b2000000-0000-0000-0000-000000000001','b2000000-0000-0000-0000-00000000000d','b2000000-0000-0000-0000-00000000000b','b2000000-0000-0000-0000-000000000009','2028-01-01','active','d3100000-0000-0000-0000-000000000002','d3100000-0000-0000-0000-000000000002'),
 ('b2000000-0000-0000-0000-000000000010','d3200000-0000-0000-0000-000000000001','d3300000-0000-0000-0000-000000000001','d3400000-0000-0000-0000-000000000001','b2000000-0000-0000-0000-000000000003','b2000000-0000-0000-0000-00000000000e','b2000000-0000-0000-0000-00000000000c','b2000000-0000-0000-0000-00000000000a','2030-01-01','active','d3100000-0000-0000-0000-000000000001','d3100000-0000-0000-0000-000000000001');
insert into public.progression_decisions(id,organization_id,student_id,source_school_id,source_campus_id,source_academic_year_id,source_grade_level_id,source_enrollment_id,source_placement_id,disposition,source_end_on,destination_school_id,destination_campus_id,destination_academic_year_id,destination_grade_level_id,destination_section_id,destination_enrolled_on,lineage_id,version,status,eligibility_override_reason,approved_at,approved_by,approval_reason,created_by,updated_by) values
 ('b2000000-0000-0000-0000-000000000011','d3200000-0000-0000-0000-000000000001','b2000000-0000-0000-0000-00000000000b','d3300000-0000-0000-0000-000000000001','d3400000-0000-0000-0000-000000000001','b2000000-0000-0000-0000-000000000001','b2000000-0000-0000-0000-000000000005','b2000000-0000-0000-0000-00000000000d','b2000000-0000-0000-0000-00000000000f','promotion','2028-12-31','d3300000-0000-0000-0000-000000000001','d3400000-0000-0000-0000-000000000001','b2000000-0000-0000-0000-000000000002','b2000000-0000-0000-0000-000000000006',null,'2029-01-01','b2000000-0000-0000-0000-000000000011',1,'pending','parent race override',null,null,null,'d3100000-0000-0000-0000-000000000002','d3100000-0000-0000-0000-000000000002'),
 ('b2000000-0000-0000-0000-000000000012','d3200000-0000-0000-0000-000000000001','b2000000-0000-0000-0000-00000000000c','d3300000-0000-0000-0000-000000000001','d3400000-0000-0000-0000-000000000001','b2000000-0000-0000-0000-000000000003','b2000000-0000-0000-0000-000000000007','b2000000-0000-0000-0000-00000000000e','b2000000-0000-0000-0000-000000000010','promotion','2030-12-31','d3300000-0000-0000-0000-000000000001','d3400000-0000-0000-0000-000000000001','b2000000-0000-0000-0000-000000000004','b2000000-0000-0000-0000-000000000008',null,'2031-01-01','b2000000-0000-0000-0000-000000000012',1,'approved','parent race override',now(),'d3100000-0000-0000-0000-000000000001','approved','d3100000-0000-0000-0000-000000000001','d3100000-0000-0000-0000-000000000001');
insert into public.progression_eligibility_evaluations(id,organization_id,progression_decision_id,student_id,sequence,state,source_fingerprint,evaluated_by) select gen_random_uuid(),organization_id,id,student_id,1,'incomplete',app_auth.progression_source_fingerprint(id),'d3100000-0000-0000-0000-000000000001' from public.progression_decisions where id in('b2000000-0000-0000-0000-000000000011','b2000000-0000-0000-0000-000000000012');
update public.progression_decisions d set current_eligibility_evaluation_id=e.id from public.progression_eligibility_evaluations e where e.progression_decision_id=d.id and d.id in('b2000000-0000-0000-0000-000000000011','b2000000-0000-0000-0000-000000000012');
commit;

-- Parent invalidation commits first; approval waits, then rejects the inactive destination context.
select extensions.dblink_connect('pr_one','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');
select extensions.dblink_connect('pr_two','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');
select is(extensions.dblink_send_query('pr_one',format('select app_auth.test_hold_command(%L,%L)','d3100000-0000-0000-0000-000000000001','select public.transition_academic_year_status(''b2000000-0000-0000-0000-000000000002'',''closed'')')),1,'parent-first lifecycle command dispatched');
select lives_ok($$select pg_sleep(.1)$$,'parent lifecycle command holds destination year');
select is(extensions.dblink_send_query('pr_two',format('select app_auth.test_capture_progression(%L,%L)','d3100000-0000-0000-0000-000000000001','select public.approve_progression_decision(''b2000000-0000-0000-0000-000000000101'',''b2000000-0000-0000-0000-000000000011'',''reviewed'')')),1,'competing approval dispatched');
select lives_ok($$select pg_sleep(.1)$$,'approval reaches locked parent');
select is(extensions.dblink_is_busy('pr_two'),1,'approval blocks until parent invalidation releases');
create temp table parent_first(status text);
insert into parent_first select status from extensions.dblink_get_result('pr_one') as t(status text);
insert into parent_first select status from extensions.dblink_get_result('pr_two') as t(status text);
select is((select array_agg(status order by status)::text from parent_first),'{00000,22023}','parent invalidation wins and approval fails validation');
select is((select status::text from public.academic_years where id='b2000000-0000-0000-0000-000000000002'),'closed','destination parent remains closed');
select is((select status::text from public.progression_decisions where id='b2000000-0000-0000-0000-000000000011'),'pending','failed approval leaves decision pending');
select is((select batch_id is null from public.progression_decisions where id='b2000000-0000-0000-0000-000000000011'),true,'parent-first decision remains an individual decision');
select is((select count(*)::int from public.student_enrollments where student_id='b2000000-0000-0000-0000-00000000000b'),1,'failed approval creates no enrollment effect');
select is((select status::text from public.student_enrollments where id='b2000000-0000-0000-0000-00000000000d'),'active','failed approval leaves source enrollment active');
select is((select count(*)::int from public.student_section_placements where student_id='b2000000-0000-0000-0000-00000000000b'),1,'failed approval creates no placement effect');
select is((select status::text from public.student_section_placements where id='b2000000-0000-0000-0000-00000000000f'),'active','failed approval leaves source placement active');
select is((select count(*)::int from public.audit_log where entity_id='b2000000-0000-0000-0000-000000000011' and action='student.progression_decision_approved'),0,'failed approval writes no progression audit');
select is((select count(*)::int from public.event_outbox where aggregate_id='b2000000-0000-0000-0000-000000000011' and event_type='student.progression_decision_approved'),0,'failed approval emits no progression event');
select extensions.dblink_disconnect('pr_one'); select extensions.dblink_disconnect('pr_two');

-- Execution commits first; the lifecycle command waits, then rejects the active destination enrollment.
select extensions.dblink_connect('pr_one','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');
select extensions.dblink_connect('pr_two','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');
select is(extensions.dblink_send_query('pr_one',format('select app_auth.test_hold_command(%L,%L)','d3100000-0000-0000-0000-000000000002','select public.execute_progression_decision(''b2000000-0000-0000-0000-000000000102'',''b2000000-0000-0000-0000-000000000012'')')),1,'progression-first execution dispatched');
select lives_ok($$select pg_sleep(.1)$$,'execution holds destination parent after applying effects');
select is(extensions.dblink_send_query('pr_two',format('select app_auth.test_capture_progression(%L,%L)','d3100000-0000-0000-0000-000000000001','select public.transition_academic_year_status(''b2000000-0000-0000-0000-000000000004'',''closed'')')),1,'competing parent close dispatched');
select lives_ok($$select pg_sleep(.1)$$,'parent close reaches locked destination year');
select is(extensions.dblink_is_busy('pr_two'),1,'parent close blocks until execution releases');
create temp table progression_first(status text);
insert into progression_first select status from extensions.dblink_get_result('pr_one') as t(status text);
insert into progression_first select status from extensions.dblink_get_result('pr_two') as t(status text);
select is((select array_agg(status order by status)::text from progression_first),'{00000,22023}','execution wins and incompatible parent close fails');
select is((select status::text from public.progression_decisions where id='b2000000-0000-0000-0000-000000000012'),'executed','winning decision is executed');
select is((select batch_id is null from public.progression_decisions where id='b2000000-0000-0000-0000-000000000012'),true,'progression-first decision remains an individual decision');
select is((select status::text from public.academic_years where id='b2000000-0000-0000-0000-000000000004'),'active','failed close leaves destination parent active');
select is((select count(*)::int from public.student_enrollments where student_id='b2000000-0000-0000-0000-00000000000c' and status='active'),1,'execution leaves exactly one active destination enrollment');
select is((select count(*)::int from public.student_enrollments where student_id='b2000000-0000-0000-0000-00000000000c'),2,'execution creates exactly one destination enrollment');
select is((select count(*)::int from public.student_section_placements where student_id='b2000000-0000-0000-0000-00000000000c'),1,'execution without destination section creates no extra placement');
select is((select status::text from public.student_section_placements where id='b2000000-0000-0000-0000-000000000010'),'completed','execution completes the source placement atomically');
select is((select count(*)::int from app_auth.progression_command_receipts where request_id='b2000000-0000-0000-0000-000000000102' and completed),1,'winning execution has one completed receipt');
select is((select count(*)::int from public.audit_log a join app_auth.progression_command_receipts r on r.command_id=a.command_id where r.request_id='b2000000-0000-0000-0000-000000000102' and a.entity_id='b2000000-0000-0000-0000-000000000012' and a.action='student.progression_executed'),1,'winning command writes one aggregate-scoped audit');
select is((select count(*)::int from public.event_outbox o join app_auth.progression_command_receipts r on r.command_id=o.command_id where r.request_id='b2000000-0000-0000-0000-000000000102' and o.aggregate_id='b2000000-0000-0000-0000-000000000012' and o.event_type='student.progression_executed'),1,'winning command emits one aggregate-scoped event');
select extensions.dblink_disconnect('pr_one'); select extensions.dblink_disconnect('pr_two');

-- Batch-item execution and batch cancellation serialize on the batch row.
begin;
insert into auth.users(id,instance_id,aud,role,email,encrypted_password,created_at,updated_at) values
 ('b3000000-0000-0000-0000-0000000000a1','00000000-0000-0000-0000-000000000000','authenticated','authenticated','batch-creator@race.test','',now(),now()),
 ('b3000000-0000-0000-0000-0000000000a2','00000000-0000-0000-0000-000000000000','authenticated','authenticated','batch-canceller@race.test','',now(),now());
insert into public.organization_memberships(id,organization_id,user_id,status,joined_at) values
 ('b3000000-0000-0000-0000-0000000000b1','d3200000-0000-0000-0000-000000000001','b3000000-0000-0000-0000-0000000000a1','active',now()),
 ('b3000000-0000-0000-0000-0000000000b2','d3200000-0000-0000-0000-000000000001','b3000000-0000-0000-0000-0000000000a2','active',now());
insert into public.role_assignments(organization_id,organization_membership_id,role_id) values
 ('d3200000-0000-0000-0000-000000000001','b3000000-0000-0000-0000-0000000000b1','d3600000-0000-0000-0000-000000000001'),
 ('d3200000-0000-0000-0000-000000000001','b3000000-0000-0000-0000-0000000000b2','d3600000-0000-0000-0000-000000000001');
insert into public.academic_years(id,organization_id,school_id,name,start_date,end_date,status) values
 ('b3000000-0000-0000-0000-000000000001','d3200000-0000-0000-0000-000000000001','d3300000-0000-0000-0000-000000000001','Batch source','2032-01-01','2032-12-31','active'),
 ('b3000000-0000-0000-0000-000000000002','d3200000-0000-0000-0000-000000000001','d3300000-0000-0000-0000-000000000001','Batch destination','2033-01-01','2033-12-31','active');
insert into public.grade_levels(id,organization_id,school_id,code,name,sequence,status) values
 ('b3000000-0000-0000-0000-000000000003','d3200000-0000-0000-0000-000000000001','d3300000-0000-0000-0000-000000000001','B31','Batch grade 1',21,'active'),
 ('b3000000-0000-0000-0000-000000000004','d3200000-0000-0000-0000-000000000001','d3300000-0000-0000-0000-000000000001','B32','Batch grade 2',22,'active');
insert into public.sections(id,organization_id,school_id,campus_id,academic_year_id,grade_level_id,code,name,capacity,start_date,end_date,status) values
 ('b3000000-0000-0000-0000-000000000005','d3200000-0000-0000-0000-000000000001','d3300000-0000-0000-0000-000000000001','d3400000-0000-0000-0000-000000000001','b3000000-0000-0000-0000-000000000001','b3000000-0000-0000-0000-000000000003','B3S','Batch source',10,'2032-01-01','2032-12-31','active'),
 ('b3000000-0000-0000-0000-000000000006','d3200000-0000-0000-0000-000000000001','d3300000-0000-0000-0000-000000000001','d3400000-0000-0000-0000-000000000001','b3000000-0000-0000-0000-000000000002','b3000000-0000-0000-0000-000000000004','B3D','Batch destination',10,'2033-01-01','2033-12-31','active');
insert into public.students(id,organization_id,school_id,campus_id,student_number,first_name,last_name,date_of_birth,status)
select ('b3000000-0000-0000-0000-'||lpad((10+n)::text,12,'0'))::uuid,'d3200000-0000-0000-0000-000000000001','d3300000-0000-0000-0000-000000000001','d3400000-0000-0000-0000-000000000001','B3-'||n,'Batch',n::text,'2018-01-01','active' from generate_series(1,4)n;
insert into public.student_enrollments(id,organization_id,school_id,academic_year_id,student_id,grade_level_id,enrolled_on,scheduled_end_on,enrollment_range,status,created_by,updated_by)
select ('b3000000-0000-0000-0000-'||lpad((20+n)::text,12,'0'))::uuid,'d3200000-0000-0000-0000-000000000001','d3300000-0000-0000-0000-000000000001','b3000000-0000-0000-0000-000000000001',('b3000000-0000-0000-0000-'||lpad((10+n)::text,12,'0'))::uuid,'b3000000-0000-0000-0000-000000000003','2032-01-01','2032-12-31',daterange('2032-01-01','2032-12-31','[]'),'active','b3000000-0000-0000-0000-0000000000a1','b3000000-0000-0000-0000-0000000000a1' from generate_series(1,4)n;
insert into public.student_section_placements(id,organization_id,school_id,campus_id,academic_year_id,student_enrollment_id,student_id,section_id,starts_on,status,created_by,updated_by)
select ('b3000000-0000-0000-0000-'||lpad((30+n)::text,12,'0'))::uuid,'d3200000-0000-0000-0000-000000000001','d3300000-0000-0000-0000-000000000001','d3400000-0000-0000-0000-000000000001','b3000000-0000-0000-0000-000000000001',('b3000000-0000-0000-0000-'||lpad((20+n)::text,12,'0'))::uuid,('b3000000-0000-0000-0000-'||lpad((10+n)::text,12,'0'))::uuid,'b3000000-0000-0000-0000-000000000005','2032-01-01','active','b3000000-0000-0000-0000-0000000000a1','b3000000-0000-0000-0000-0000000000a1' from generate_series(1,4)n;
insert into public.progression_batches(id,organization_id,source_school_id,source_academic_year_id,status,approved_at,approved_by,approval_reason,created_by,updated_by) values
 ('b3000000-0000-0000-0000-000000000061','d3200000-0000-0000-0000-000000000001','d3300000-0000-0000-0000-000000000001','b3000000-0000-0000-0000-000000000001','approved',now(),'d3100000-0000-0000-0000-000000000001','approved','b3000000-0000-0000-0000-0000000000a1','d3100000-0000-0000-0000-000000000001'),
 ('b3000000-0000-0000-0000-000000000062','d3200000-0000-0000-0000-000000000001','d3300000-0000-0000-0000-000000000001','b3000000-0000-0000-0000-000000000001','approved',now(),'d3100000-0000-0000-0000-000000000001','approved','b3000000-0000-0000-0000-0000000000a1','d3100000-0000-0000-0000-000000000001');
insert into public.progression_decisions(id,organization_id,student_id,source_school_id,source_campus_id,source_academic_year_id,source_grade_level_id,source_enrollment_id,source_placement_id,disposition,source_end_on,destination_school_id,destination_campus_id,destination_academic_year_id,destination_grade_level_id,destination_section_id,destination_enrolled_on,lineage_id,version,status,eligibility_override_reason,approved_at,approved_by,approval_reason,batch_id,created_by,updated_by)
select ('b3000000-0000-0000-0000-'||lpad((40+n)::text,12,'0'))::uuid,'d3200000-0000-0000-0000-000000000001',('b3000000-0000-0000-0000-'||lpad((10+n)::text,12,'0'))::uuid,'d3300000-0000-0000-0000-000000000001','d3400000-0000-0000-0000-000000000001','b3000000-0000-0000-0000-000000000001','b3000000-0000-0000-0000-000000000003',('b3000000-0000-0000-0000-'||lpad((20+n)::text,12,'0'))::uuid,('b3000000-0000-0000-0000-'||lpad((30+n)::text,12,'0'))::uuid,'promotion','2032-12-31','d3300000-0000-0000-0000-000000000001','d3400000-0000-0000-0000-000000000001','b3000000-0000-0000-0000-000000000002','b3000000-0000-0000-0000-000000000004','b3000000-0000-0000-0000-000000000006','2033-01-01',('b3000000-0000-0000-0000-'||lpad((40+n)::text,12,'0'))::uuid,1,'approved','batch race override',now(),'d3100000-0000-0000-0000-000000000001','approved',case when n<=2 then 'b3000000-0000-0000-0000-000000000061'::uuid else 'b3000000-0000-0000-0000-000000000062'::uuid end,'b3000000-0000-0000-0000-0000000000a1','d3100000-0000-0000-0000-000000000001' from generate_series(1,4)n;
insert into public.progression_eligibility_evaluations(id,organization_id,progression_decision_id,student_id,sequence,state,source_fingerprint,evaluated_by)
select gen_random_uuid(),organization_id,id,student_id,1,'incomplete',app_auth.progression_source_fingerprint(id),'d3100000-0000-0000-0000-000000000001' from public.progression_decisions where id in('b3000000-0000-0000-0000-000000000041','b3000000-0000-0000-0000-000000000042','b3000000-0000-0000-0000-000000000043','b3000000-0000-0000-0000-000000000044');
update public.progression_decisions d set current_eligibility_evaluation_id=e.id from public.progression_eligibility_evaluations e where e.progression_decision_id=d.id and d.id in('b3000000-0000-0000-0000-000000000041','b3000000-0000-0000-0000-000000000042','b3000000-0000-0000-0000-000000000043','b3000000-0000-0000-0000-000000000044');
insert into public.progression_batch_items(id,organization_id,batch_id,decision_id,student_id,source_enrollment_id,created_by)
select ('b3000000-0000-0000-0000-'||lpad((50+q.n)::text,12,'0'))::uuid,d.organization_id,d.batch_id,d.id,d.student_id,d.source_enrollment_id,'b3000000-0000-0000-0000-0000000000a1'
from public.progression_decisions d
cross join lateral (select right(d.id::text,2)::integer-40 as n) q
where d.id in('b3000000-0000-0000-0000-000000000041','b3000000-0000-0000-0000-000000000042','b3000000-0000-0000-0000-000000000043','b3000000-0000-0000-0000-000000000044');
commit;

-- Item execution wins; batch cancellation waits and then cancels only the remaining item.
select extensions.dblink_connect('pr_one','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');
select extensions.dblink_connect('pr_two','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');
select is(extensions.dblink_send_query('pr_one',format('select app_auth.test_hold_command(%L,%L)','d3100000-0000-0000-0000-000000000002','select public.execute_progression_batch_item(''b3000000-0000-0000-0000-000000000101'',''b3000000-0000-0000-0000-000000000061'',''b3000000-0000-0000-0000-000000000041'')')),1,'batch-item execution dispatched');
select lives_ok($$select pg_sleep(.1)$$,'batch-item execution holds batch lock');
select is(extensions.dblink_send_query('pr_two',format('select app_auth.test_capture_progression(%L,%L)','b3000000-0000-0000-0000-0000000000a2','select public.cancel_progression_batch(''b3000000-0000-0000-0000-000000000102'',''b3000000-0000-0000-0000-000000000061'',''operator cancellation'')')),1,'remaining-item cancellation dispatched');
select lives_ok($$select pg_sleep(.1)$$,'cancellation reaches locked batch');
select is(extensions.dblink_is_busy('pr_two'),1,'cancellation blocks behind winning execution');
create temp table execution_first_batch(status text);
insert into execution_first_batch select status from extensions.dblink_get_result('pr_one') as t(status text);
insert into execution_first_batch select status from extensions.dblink_get_result('pr_two') as t(status text);
select is((select array_agg(status order by status)::text from execution_first_batch),'{00000,00000}','execution and remaining-item cancellation both succeed');
select is((select string_agg(status::text,',' order by id) from public.progression_decisions where batch_id='b3000000-0000-0000-0000-000000000061'),'executed,cancelled','winning item executes and only remaining item cancels');
select is((select status::text from public.progression_batches where id='b3000000-0000-0000-0000-000000000061'),'completed','mixed batch reaches terminal stored state');
select is((select outcome::text from public.progression_batch_progress where id='b3000000-0000-0000-0000-000000000061'),'completed_with_exceptions','mixed batch derives completed-with-exceptions');
select is((select count(*)::int from public.student_enrollments where student_id='b3000000-0000-0000-0000-000000000011'),2,'executed item creates exactly one destination enrollment');
select is((select count(*)::int from public.student_section_placements where student_id='b3000000-0000-0000-0000-000000000011'),2,'executed item creates exactly one destination placement');
select is((select count(*)::int from public.student_enrollments where student_id='b3000000-0000-0000-0000-000000000012'),1,'cancelled item creates no enrollment effect');
select is((select count(*)::int from public.student_section_placements where student_id='b3000000-0000-0000-0000-000000000012'),1,'cancelled item creates no placement effect');
select is((select attempt_count from public.progression_batch_items where decision_id='b3000000-0000-0000-0000-000000000041'),1,'executed item records one successful attempt');
select is((select last_error_code is null and last_error_category is null from public.progression_batch_items where decision_id='b3000000-0000-0000-0000-000000000041'),true,'successful attempt retains no error diagnostics');
select is((select attempt_count from public.progression_batch_items where decision_id='b3000000-0000-0000-0000-000000000042'),0,'cancelled remainder records no execution attempt');
select is((select count(*)::int from public.audit_log where entity_id='b3000000-0000-0000-0000-000000000042' and action='student.progression_executed'),0,'cancelled remainder has no execution audit');
select is((select count(*)::int from public.event_outbox where aggregate_id='b3000000-0000-0000-0000-000000000042' and event_type='student.progression_executed'),0,'cancelled remainder has no execution event');
select is((select count(*)::int from app_auth.progression_command_receipts where request_id in('b3000000-0000-0000-0000-000000000101','b3000000-0000-0000-0000-000000000102') and completed),2,'both winning commands have one completed receipt');
select is((select count(*)::int from public.audit_log a join app_auth.progression_command_receipts r on r.command_id=a.command_id where r.request_id='b3000000-0000-0000-0000-000000000101' and a.entity_id='b3000000-0000-0000-0000-000000000041' and a.action='student.progression_executed'),1,'execution command writes one decision audit');
select is((select count(*)::int from public.event_outbox o join app_auth.progression_command_receipts r on r.command_id=o.command_id where r.request_id='b3000000-0000-0000-0000-000000000101' and o.aggregate_id='b3000000-0000-0000-0000-000000000041' and o.event_type='student.progression_executed'),1,'execution command emits one decision event');
select is((select count(*)::int from public.audit_log a join app_auth.progression_command_receipts r on r.command_id=a.command_id where r.request_id='b3000000-0000-0000-0000-000000000102' and a.entity_id='b3000000-0000-0000-0000-000000000061' and a.action='student.progression_batch_completed'),1,'cancellation command writes one terminal batch audit');
select is((select count(*)::int from public.event_outbox o join app_auth.progression_command_receipts r on r.command_id=o.command_id where r.request_id='b3000000-0000-0000-0000-000000000102' and o.aggregate_id='b3000000-0000-0000-0000-000000000061' and o.event_type='student.progression_batch_completed'),1,'cancellation command emits one terminal batch event');
select extensions.dblink_disconnect('pr_one'); select extensions.dblink_disconnect('pr_two');

-- Cancellation wins; item execution waits and then rejects the completed batch nonretryably.
select extensions.dblink_connect('pr_one','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');
select extensions.dblink_connect('pr_two','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');
select is(extensions.dblink_send_query('pr_one',format('select app_auth.test_hold_command(%L,%L)','b3000000-0000-0000-0000-0000000000a2','select public.cancel_progression_batch(''b3000000-0000-0000-0000-000000000103'',''b3000000-0000-0000-0000-000000000062'',''operator cancellation wins'')')),1,'winning batch cancellation dispatched');
select lives_ok($$select pg_sleep(.1)$$,'cancellation holds batch and decision locks');
select is(extensions.dblink_send_query('pr_two',format('select app_auth.test_capture_progression(%L,%L)','d3100000-0000-0000-0000-000000000002','select public.execute_progression_batch_item(''b3000000-0000-0000-0000-000000000104'',''b3000000-0000-0000-0000-000000000062'',''b3000000-0000-0000-0000-000000000043'')')),1,'losing batch-item execution dispatched');
select lives_ok($$select pg_sleep(.1)$$,'execution reaches locked batch');
select is(extensions.dblink_is_busy('pr_two'),1,'execution blocks behind winning cancellation');
create temp table cancellation_first_batch(status text);
insert into cancellation_first_batch select status from extensions.dblink_get_result('pr_one') as t(status text);
insert into cancellation_first_batch select status from extensions.dblink_get_result('pr_two') as t(status text);
select is((select array_agg(status order by status)::text from cancellation_first_batch),'{00000,22023}','cancellation wins and execution receives nonretryable lifecycle rejection');
select is((select count(*)::int from public.progression_decisions where batch_id='b3000000-0000-0000-0000-000000000062' and status='cancelled'),2,'winning cancellation leaves both decisions cancelled');
select is((select status::text from public.progression_batches where id='b3000000-0000-0000-0000-000000000062'),'completed','cancelled batch reaches terminal stored state');
select is((select outcome::text from public.progression_batch_progress where id='b3000000-0000-0000-0000-000000000062'),'completed_with_exceptions','all-cancelled batch derives completed-with-exceptions');
select is((select coalesce(sum(attempt_count),0)::int from public.progression_batch_items where batch_id='b3000000-0000-0000-0000-000000000062'),0,'lifecycle rejection records no execution attempt');
select is((select bool_and(last_error_code is null and last_error_category is null) from public.progression_batch_items where batch_id='b3000000-0000-0000-0000-000000000062'),true,'nonattempted cancelled items retain empty diagnostics');
select is((select count(*)::int from public.student_enrollments where student_id in('b3000000-0000-0000-0000-000000000013','b3000000-0000-0000-0000-000000000014')),2,'cancelled batch creates no enrollment effects');
select is((select count(*)::int from public.student_section_placements where student_id in('b3000000-0000-0000-0000-000000000013','b3000000-0000-0000-0000-000000000014')),2,'cancelled batch creates no placement effects');
select is((select count(*)::int from app_auth.progression_command_receipts where request_id='b3000000-0000-0000-0000-000000000103' and completed),1,'winning cancellation has one completed receipt');
select is((select count(*)::int from app_auth.progression_command_receipts where request_id='b3000000-0000-0000-0000-000000000104'),0,'losing execution rolls back its receipt');
select is((select count(*)::int from public.audit_log where entity_id in('b3000000-0000-0000-0000-000000000043','b3000000-0000-0000-0000-000000000044') and action='student.progression_executed'),0,'cancelled batch and losing execution write no decision audit');
select is((select count(*)::int from public.event_outbox where aggregate_id in('b3000000-0000-0000-0000-000000000043','b3000000-0000-0000-0000-000000000044') and event_type='student.progression_executed'),0,'cancelled batch and losing execution emit no decision event');
select is((select count(*)::int from public.audit_log a join app_auth.progression_command_receipts r on r.command_id=a.command_id where r.request_id='b3000000-0000-0000-0000-000000000103' and a.entity_id='b3000000-0000-0000-0000-000000000062' and a.action='student.progression_batch_completed'),1,'winning cancellation writes one terminal batch audit');
select is((select count(*)::int from public.event_outbox o join app_auth.progression_command_receipts r on r.command_id=o.command_id where r.request_id='b3000000-0000-0000-0000-000000000103' and o.aggregate_id='b3000000-0000-0000-0000-000000000062' and o.event_type='student.progression_batch_completed'),1,'winning cancellation emits one terminal batch event');
select extensions.dblink_disconnect('pr_one'); select extensions.dblink_disconnect('pr_two');
select * from finish();
