begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

select has_type('public','attendance_session_status','attendance session status exists');
select has_type('public','attendance_mark_status','attendance mark status exists');
select has_type('public','attendance_mark_input','typed mark input exists');
select has_table('public','attendance_absence_reasons','absence reasons table exists');
select has_table('public','attendance_sessions','attendance sessions table exists');
select has_table('public','attendance_session_students','attendance roster snapshot exists');
select has_table('public','attendance_marks','attendance marks table exists');
select ok(exists(
 select 1 from pg_constraint c
 where c.conrelid='public.attendance_absence_reasons'::regclass and c.contype='u'
  and (select array_agg(a.attname order by k.ordinality)
       from unnest(c.conkey) with ordinality k(attnum,ordinality)
       join pg_attribute a on a.attrelid=c.conrelid and a.attnum=k.attnum)
      =array['organization_id','school_id','id']::name[]
),'absence reason exposes exact organization/school/id composite parent key');
select is((select count(*)::int from public.permissions where code like 'attendance.%'),3,'three attendance permissions seeded');
select ok((select bool_and(c.relrowsecurity and c.relforcerowsecurity) from pg_class c where c.oid=any(array['public.attendance_absence_reasons'::regclass,'public.attendance_sessions'::regclass,'public.attendance_session_students'::regclass,'public.attendance_marks'::regclass])),'all attendance tables force RLS');
select ok(not has_table_privilege('authenticated','public.attendance_sessions','INSERT,UPDATE,DELETE,TRUNCATE'),'sessions are SELECT-only');
select ok(not has_table_privilege('authenticated','public.attendance_marks','INSERT,UPDATE,DELETE,TRUNCATE'),'marks are SELECT-only');
select has_index('public','attendance_sessions','attendance_sessions_live_section_date_key','one live session per section/date');
select has_index('public','attendance_sessions','attendance_sessions_one_successor_key','correction history cannot branch');

create temp table expected_attendance_rpcs(signature text) on commit drop;
insert into expected_attendance_rpcs values
 ('public.create_attendance_absence_reason(uuid,uuid,text,text,text)'),
 ('public.update_attendance_absence_reason(uuid,text,text,text,record_status,boolean)'),
 ('public.archive_attendance_absence_reason(uuid)'),
 ('public.open_attendance_session(uuid,date)'),
 ('public.submit_attendance_session(uuid,attendance_mark_input[])'),
 ('public.finalize_attendance_session(uuid)'),
 ('public.correct_attendance_session(uuid,attendance_mark_input[],text)');
select ok(not exists(select 1 from expected_attendance_rpcs e where to_regprocedure(e.signature) is null),'all seven typed attendance RPCs exist');
select ok(not exists(select 1 from expected_attendance_rpcs e join pg_proc p on p.oid=to_regprocedure(e.signature) where pg_get_userbyid(p.proowner)<>'postgres' or not p.prosecdef or not exists(select 1 from unnest(p.proconfig) c where c like 'search_path=%')),'RPC owner, security definer, and empty search path are exact');
select ok(not exists(select 1 from expected_attendance_rpcs e join pg_proc p on p.oid=to_regprocedure(e.signature) where has_function_privilege('anon',p.oid,'EXECUTE') or not has_function_privilege('authenticated',p.oid,'EXECUTE') or not has_function_privilege('service_role',p.oid,'EXECUTE')),'RPC grants are deliberate');
select ok(has_function_privilege('authenticated','app_auth.can_read_attendance_session(uuid)','EXECUTE') and not has_function_privilege('service_role','app_auth.can_read_attendance_session(uuid)','EXECUTE'),'relationship helper is authenticated-only');
select ok(not has_function_privilege('authenticated','app_auth.insert_attendance_marks(attendance_sessions,attendance_mark_input[],uuid,uuid,text)','EXECUTE'),'private mark writer denied');

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,created_at,updated_at) values
 ('b1000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','attendance-admin@test','',now(),now()),
 ('b1000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','attendance-teacher@test','',now(),now()),
 ('b1000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000000','authenticated','authenticated','attendance-none@test','',now(),now()),
 ('b1000000-0000-0000-0000-000000000004','00000000-0000-0000-0000-000000000000','authenticated','authenticated','attendance-student@test','',now(),now());
insert into public.organizations(id,name,slug) values('b2000000-0000-0000-0000-000000000001','Attendance Tenant','attendance-tenant');
insert into public.schools(id,organization_id,name,code) values('b3000000-0000-0000-0000-000000000001','b2000000-0000-0000-0000-000000000001','Attendance School','ATT');
insert into public.campuses(id,organization_id,school_id,name,code) values('b4000000-0000-0000-0000-000000000001','b2000000-0000-0000-0000-000000000001','b3000000-0000-0000-0000-000000000001','Attendance Campus','MAIN');
insert into public.organization_memberships(id,organization_id,user_id,status,joined_at) values
 ('b5000000-0000-0000-0000-000000000001','b2000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001','active',now()),
 ('b5000000-0000-0000-0000-000000000002','b2000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000002','active',now()),
 ('b5000000-0000-0000-0000-000000000003','b2000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000003','active',now());
insert into public.roles(id,organization_id,code,name) values('b6000000-0000-0000-0000-000000000001','b2000000-0000-0000-0000-000000000001','ATTENDANCE_ADMIN','Attendance Admin');
insert into public.role_permissions(organization_id,role_id,permission_id)
 select 'b2000000-0000-0000-0000-000000000001','b6000000-0000-0000-0000-000000000001',id from public.permissions where code like 'attendance.%';
insert into public.role_assignments(organization_id,organization_membership_id,role_id,school_id,campus_id) values
 ('b2000000-0000-0000-0000-000000000001','b5000000-0000-0000-0000-000000000001','b6000000-0000-0000-0000-000000000001','b3000000-0000-0000-0000-000000000001','b4000000-0000-0000-0000-000000000001');
insert into public.staff_profiles(id,organization_id,organization_membership_id,staff_number,employment_type,status) values
 ('b7000000-0000-0000-0000-000000000001','b2000000-0000-0000-0000-000000000001','b5000000-0000-0000-0000-000000000002','AT-1','teacher','active');
insert into public.academic_years(id,organization_id,school_id,name,start_date,end_date,status) values
 ('b8000000-0000-0000-0000-000000000001','b2000000-0000-0000-0000-000000000001','b3000000-0000-0000-0000-000000000001','Attendance Year',current_date-100,current_date+100,'active');
insert into public.grade_levels(id,organization_id,school_id,code,name,sequence,status) values
 ('b8100000-0000-0000-0000-000000000001','b2000000-0000-0000-0000-000000000001','b3000000-0000-0000-0000-000000000001','AG1','Attendance Grade',1,'active');
insert into public.sections(id,organization_id,school_id,campus_id,academic_year_id,grade_level_id,code,name,capacity,start_date,end_date,status) values
 ('b8200000-0000-0000-0000-000000000001','b2000000-0000-0000-0000-000000000001','b3000000-0000-0000-0000-000000000001','b4000000-0000-0000-0000-000000000001','b8000000-0000-0000-0000-000000000001','b8100000-0000-0000-0000-000000000001','AT1','Attendance One',30,current_date-100,current_date+100,'active'),
 ('b8200000-0000-0000-0000-000000000002','b2000000-0000-0000-0000-000000000001','b3000000-0000-0000-0000-000000000001','b4000000-0000-0000-0000-000000000001','b8000000-0000-0000-0000-000000000001','b8100000-0000-0000-0000-000000000001','AT2','Attendance Two',30,current_date-100,current_date+100,'active');
insert into public.students(id,organization_id,school_id,campus_id,user_id,student_number,first_name,last_name,date_of_birth) values
 ('b8300000-0000-0000-0000-000000000001','b2000000-0000-0000-0000-000000000001','b3000000-0000-0000-0000-000000000001','b4000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000004','ATT-1','Attendance','Student','2015-01-01');
insert into public.student_enrollments(id,organization_id,school_id,academic_year_id,student_id,grade_level_id,enrolled_on,scheduled_end_on,enrollment_range,status,created_by,updated_by) values
 ('b8400000-0000-0000-0000-000000000001','b2000000-0000-0000-0000-000000000001','b3000000-0000-0000-0000-000000000001','b8000000-0000-0000-0000-000000000001','b8300000-0000-0000-0000-000000000001','b8100000-0000-0000-0000-000000000001',current_date-100,current_date+100,daterange(current_date-100,current_date+100,'[]'),'active','b1000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001');
insert into public.student_section_placements(id,organization_id,school_id,campus_id,academic_year_id,student_enrollment_id,student_id,section_id,starts_on,status,created_by,updated_by) values
 ('b8500000-0000-0000-0000-000000000001','b2000000-0000-0000-0000-000000000001','b3000000-0000-0000-0000-000000000001','b4000000-0000-0000-0000-000000000001','b8000000-0000-0000-0000-000000000001','b8400000-0000-0000-0000-000000000001','b8300000-0000-0000-0000-000000000001','b8200000-0000-0000-0000-000000000001',current_date-100,'active','b1000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001');
insert into public.teaching_assignments(id,organization_id,school_id,campus_id,academic_year_id,section_id,staff_profile_id,role,starts_on,scheduled_ends_on,effective_range,status,created_by,updated_by) values
 ('b8600000-0000-0000-0000-000000000001','b2000000-0000-0000-0000-000000000001','b3000000-0000-0000-0000-000000000001','b4000000-0000-0000-0000-000000000001','b8000000-0000-0000-0000-000000000001','b8200000-0000-0000-0000-000000000002','b7000000-0000-0000-0000-000000000001','lead',current_date-10,current_date+10,daterange(current_date-10,current_date+10,'[]'),'active','b1000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001');

set local role anon;
select throws_ok($$select public.open_attendance_session('b8200000-0000-0000-0000-000000000001',current_date)$$,'42501','permission denied for function open_attendance_session','anonymous open denied');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"b1000000-0000-0000-0000-000000000003","role":"authenticated"}',true);
select throws_ok($$select public.open_attendance_session('b8200000-0000-0000-0000-000000000001',current_date)$$,'42501','current teaching assignment or attendance.manage permission is required','missing permission denied');
select set_config('request.jwt.claims','{"sub":"b1000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.open_attendance_session('b8200000-0000-0000-0000-000000000001',current_date+1)$$,'22023','future attendance sessions are prohibited','future session denied to manager');
select lives_ok($$select public.create_attendance_absence_reason('b3000000-0000-0000-0000-000000000001','b4000000-0000-0000-0000-000000000001','ILL','Illness',null)$$,'manager creates reason');
select lives_ok($$select public.update_attendance_absence_reason((select id from public.attendance_absence_reasons),'ILL','Illness or medical appointment','Managed reason', 'active',true)$$,'manager updates reason');
select lives_ok($$select public.open_attendance_session('b8200000-0000-0000-0000-000000000001',current_date-1)$$,'manager opens past session');
select is((select count(*)::int from public.attendance_session_students),1,'open captures exact roster');
select lives_ok($$select public.submit_attendance_session((select id from public.attendance_sessions),array[row('b8300000-0000-0000-0000-000000000001','absent',null,(select id from public.attendance_absence_reasons),'bounded note')::public.attendance_mark_input])$$,'manager submits complete past session');
select lives_ok($$select public.finalize_attendance_session((select id from public.attendance_sessions))$$,'manager finalizes session');
select is((select status::text from public.attendance_sessions),'finalized','session finalized');
select is((select mark::text from public.attendance_marks),'absent','absence mark stored');
select throws_ok($$insert into public.attendance_marks(id) values(gen_random_uuid())$$,'42501','permission denied for table attendance_marks','direct mark insert denied');
reset role;

select is((select count(*)::int from public.audit_log where action like 'attendance.%' or action like 'attendance_reason.%'),7,'reason/open/submit/finalize session effects audited alongside roster and mark');
select is((select count(*)::int from public.event_outbox where event_type like 'attendance.%' or event_type like 'attendance_reason.%'),6,'reason/open/submit/mark/finalize events emitted');
select ok(not exists(select 1 from public.event_outbox where (event_type like 'attendance.%' or event_type like 'attendance_reason.%') and payload?'note'),'attendance outbox omits notes');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"b1000000-0000-0000-0000-000000000002","role":"authenticated"}',true);
select throws_ok($$select public.open_attendance_session('b8200000-0000-0000-0000-000000000002',current_date-1)$$,'42501','current teaching assignment or attendance.manage permission is required','teacher cannot open past session');
select lives_ok($$select public.open_attendance_session('b8200000-0000-0000-0000-000000000002',current_date)$$,'current lead opens today');
select is((select count(*)::int from public.attendance_sessions),1,'teacher sees only today assigned session');
reset role;

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"b1000000-0000-0000-0000-000000000004","role":"authenticated"}',true);
select is((select count(*)::int from public.attendance_sessions),0,'student has no attendance read');
reset role;

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"b1000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select lives_ok($$select * from public.correct_attendance_session((select id from public.attendance_sessions where section_id='b8200000-0000-0000-0000-000000000001'),array[row('b8300000-0000-0000-0000-000000000001','present',null,null,null)::public.attendance_mark_input],'recorded mark was wrong')$$,'whole-session correction succeeds');
reset role;
select is((select count(*)::int from public.attendance_sessions where section_id='b8200000-0000-0000-0000-000000000001'),2,'correction appends replacement session');
select is((select count(*)::int from public.attendance_session_students where section_id='b8200000-0000-0000-0000-000000000001'),2,'correction copies original roster');
select is((select count(*)::int from public.attendance_marks where section_id='b8200000-0000-0000-0000-000000000001'),2,'original and replacement marks preserved');
select is((select count(*)::int from public.attendance_sessions where status='corrected'),1,'original becomes corrected');
select is((select count(*)::int from public.attendance_sessions where status='finalized'),1,'replacement is finalized');

-- Correcting enrollment history does not consult, rewrite, or invalidate attendance snapshots.
update public.student_section_placements set status='corrected',correction_reason='placement record was wrong',updated_by='b1000000-0000-0000-0000-000000000001' where id='b8500000-0000-0000-0000-000000000001';
select is((select count(*)::int from public.attendance_session_students where student_section_placement_id='b8500000-0000-0000-0000-000000000001'),2,'corrected placement provenance remains attached');
select is((select count(*)::int from public.attendance_marks where section_id='b8200000-0000-0000-0000-000000000001'),2,'placement correction leaves attendance marks untouched');
select throws_ok($$delete from public.student_section_placements where id='b8500000-0000-0000-0000-000000000001'$$,'23503',null,'restrictive provenance FK prevents destructive deletion');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"b1000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select lives_ok($$select public.archive_attendance_absence_reason((select id from public.attendance_absence_reasons))$$,'manager archives referenced reason without rewriting history');
reset role;
select is((select status::text from public.attendance_absence_reasons),'archived','archive reason RPC executed');

select * from finish();
rollback;
