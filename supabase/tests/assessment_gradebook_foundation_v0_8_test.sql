begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

select has_type('public','assessment_type','assessment type exists');
select has_type('public','assessment_lifecycle_status','assessment lifecycle exists');
select has_type('public','assessment_publication_state','assessment publication exists');
select has_type('public','assessment_result_input','typed assessment result input exists');
select has_table('public','assessments','assessments table exists');
select has_table('public','assessment_students','assessment roster snapshot exists');
select has_table('public','assessment_results','assessment results table exists');
select is((select enum_range(null::public.assessment_lifecycle_status)::text),'{draft,finalized,corrected,cancelled}','lifecycle enum is exact');
select is((select count(*)::int from public.permissions where code like 'assessments.%'),3,'three assessment permissions seeded');
select ok((select bool_and(c.relrowsecurity and c.relforcerowsecurity) from pg_class c
 where c.oid=any(array['public.assessments'::regclass,'public.assessment_students'::regclass,'public.assessment_results'::regclass])),
 'all assessment tables force RLS');
select ok(not has_table_privilege('authenticated','public.assessments','INSERT,UPDATE,DELETE,TRUNCATE'),'assessments are SELECT-only');
select ok(not has_table_privilege('authenticated','public.assessment_results','INSERT,UPDATE,DELETE,TRUNCATE'),'results are SELECT-only');
select has_index('public','assessments','assessments_live_title_date_key','live title/date uniqueness exists');
select has_index('public','assessments','assessments_one_successor_key','correction history cannot branch');

create temp table expected_assessment_rpcs(signature text) on commit drop;
insert into expected_assessment_rpcs values
 ('public.create_assessment(uuid,uuid,uuid,assessment_type,text,text,date,date,numeric,numeric)'),
 ('public.update_assessment(uuid,assessment_type,text,text,date,boolean,boolean)'),
 ('public.record_assessment_results(uuid,assessment_result_input[])'),
 ('public.publish_assessment(uuid)'),('public.finalize_assessment(uuid)'),
 ('public.cancel_draft_assessment(uuid,text)'),
 ('public.correct_assessment(uuid,uuid,assessment_type,text,text,date,date,numeric,numeric,assessment_result_input[],text)');
select ok(not exists(select 1 from expected_assessment_rpcs e where to_regprocedure(e.signature) is null),'all seven typed RPCs exist');
select ok(not exists(select 1 from expected_assessment_rpcs e join pg_proc p on p.oid=to_regprocedure(e.signature)
 where pg_get_userbyid(p.proowner)<>'postgres' or not p.prosecdef
  or not exists(select 1 from unnest(p.proconfig) c where c like 'search_path=%')),
 'RPC ownership, security definer, and empty search path are exact');
select ok(not exists(select 1 from expected_assessment_rpcs e join pg_proc p on p.oid=to_regprocedure(e.signature)
 where has_function_privilege('anon',p.oid,'EXECUTE') or not has_function_privilege('authenticated',p.oid,'EXECUTE')
  or not has_function_privilege('service_role',p.oid,'EXECUTE')),'RPC grants are deliberate');
select ok(has_function_privilege('authenticated','app_auth.can_read_assessment(uuid)','EXECUTE')
 and not has_function_privilege('service_role','app_auth.can_read_assessment(uuid)','EXECUTE'),'RLS helper is authenticated-only');
select ok(not has_function_privilege('authenticated','app_auth.write_assessment_change(uuid,uuid,uuid,text,text,uuid,jsonb,jsonb,jsonb,boolean)','EXECUTE'),
 'private writer is denied');
select ok(not has_function_privilege('authenticated','app_auth.has_assessment_assignment_context(uuid,uuid,teaching_assignment_role[])','EXECUTE'),
 'command-only context helper is denied');

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,created_at,updated_at) values
 ('c1000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','assessment-admin@test','',now(),now()),
 ('c1000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','assessment-teacher@test','',now(),now()),
 ('c1000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000000','authenticated','authenticated','assessment-assistant@test','',now(),now()),
 ('c1000000-0000-0000-0000-000000000004','00000000-0000-0000-0000-000000000000','authenticated','authenticated','assessment-student@test','',now(),now()),
 ('c1000000-0000-0000-0000-000000000005','00000000-0000-0000-0000-000000000000','authenticated','authenticated','assessment-guardian@test','',now(),now()),
 ('c1000000-0000-0000-0000-000000000006','00000000-0000-0000-0000-000000000000','authenticated','authenticated','assessment-none@test','',now(),now());
insert into public.organizations(id,name,slug) values('c2000000-0000-0000-0000-000000000001','Assessment Tenant','assessment-tenant');
insert into public.schools(id,organization_id,name,code) values('c3000000-0000-0000-0000-000000000001','c2000000-0000-0000-0000-000000000001','Assessment School','ASM');
insert into public.campuses(id,organization_id,school_id,name,code) values
 ('c4000000-0000-0000-0000-000000000001','c2000000-0000-0000-0000-000000000001','c3000000-0000-0000-0000-000000000001','Assessment Campus','MAIN');
insert into public.organization_memberships(id,organization_id,user_id,status,joined_at) values
 ('c5000000-0000-0000-0000-000000000001','c2000000-0000-0000-0000-000000000001','c1000000-0000-0000-0000-000000000001','active',now()),
 ('c5000000-0000-0000-0000-000000000002','c2000000-0000-0000-0000-000000000001','c1000000-0000-0000-0000-000000000002','active',now()),
 ('c5000000-0000-0000-0000-000000000003','c2000000-0000-0000-0000-000000000001','c1000000-0000-0000-0000-000000000003','active',now()),
 ('c5000000-0000-0000-0000-000000000006','c2000000-0000-0000-0000-000000000001','c1000000-0000-0000-0000-000000000006','active',now());
insert into public.roles(id,organization_id,code,name) values
 ('c6000000-0000-0000-0000-000000000001','c2000000-0000-0000-0000-000000000001','ASSESSMENT_ADMIN','Assessment Admin');
insert into public.role_permissions(organization_id,role_id,permission_id)
 select 'c2000000-0000-0000-0000-000000000001','c6000000-0000-0000-0000-000000000001',id
 from public.permissions where code like 'assessments.%' or code='academic_structure.manage';
insert into public.role_assignments(organization_id,organization_membership_id,role_id,school_id,campus_id) values
 ('c2000000-0000-0000-0000-000000000001','c5000000-0000-0000-0000-000000000001','c6000000-0000-0000-0000-000000000001','c3000000-0000-0000-0000-000000000001',null);
insert into public.staff_profiles(id,organization_id,organization_membership_id,staff_number,employment_type,status) values
 ('c7000000-0000-0000-0000-000000000002','c2000000-0000-0000-0000-000000000001','c5000000-0000-0000-0000-000000000002','ASM-T','teacher','active'),
 ('c7000000-0000-0000-0000-000000000003','c2000000-0000-0000-0000-000000000001','c5000000-0000-0000-0000-000000000003','ASM-A','assistant','active');
insert into public.academic_years(id,organization_id,school_id,name,start_date,end_date,status) values
 ('c8000000-0000-0000-0000-000000000001','c2000000-0000-0000-0000-000000000001','c3000000-0000-0000-0000-000000000001','Assessment Year',current_date-100,current_date+100,'active');
insert into public.academic_terms(id,organization_id,academic_year_id,name,sequence,start_date,end_date,status) values
 ('c8100000-0000-0000-0000-000000000001','c2000000-0000-0000-0000-000000000001','c8000000-0000-0000-0000-000000000001','Assessment Term',1,current_date-80,current_date+80,'active');
insert into public.grade_levels(id,organization_id,school_id,code,name,sequence,status) values
 ('c8200000-0000-0000-0000-000000000001','c2000000-0000-0000-0000-000000000001','c3000000-0000-0000-0000-000000000001','ASG','Assessment Grade',1,'active');
insert into public.subjects(id,organization_id,school_id,code,name,status) values
 ('c8300000-0000-0000-0000-000000000001','c2000000-0000-0000-0000-000000000001','c3000000-0000-0000-0000-000000000001','MATH','Mathematics','active');
insert into public.sections(id,organization_id,school_id,campus_id,academic_year_id,academic_term_id,grade_level_id,code,name,capacity,start_date,end_date,status) values
 ('c8400000-0000-0000-0000-000000000001','c2000000-0000-0000-0000-000000000001','c3000000-0000-0000-0000-000000000001','c4000000-0000-0000-0000-000000000001','c8000000-0000-0000-0000-000000000001','c8100000-0000-0000-0000-000000000001','c8200000-0000-0000-0000-000000000001','AS1','Assessment One',30,current_date-80,current_date+80,'active');
insert into public.students(id,organization_id,school_id,campus_id,user_id,student_number,first_name,last_name,date_of_birth) values
 ('c8500000-0000-0000-0000-000000000001','c2000000-0000-0000-0000-000000000001','c3000000-0000-0000-0000-000000000001','c4000000-0000-0000-0000-000000000001','c1000000-0000-0000-0000-000000000004','ASM-1','Assessment','Student','2015-01-01');
insert into public.guardians(id,organization_id,user_id,first_name,last_name,status) values
 ('c8600000-0000-0000-0000-000000000001','c2000000-0000-0000-0000-000000000001','c1000000-0000-0000-0000-000000000005','Assessment','Guardian','active');
insert into public.student_guardians(id,organization_id,student_id,guardian_id,relationship_type,has_portal_access,status) values
 ('c8700000-0000-0000-0000-000000000001','c2000000-0000-0000-0000-000000000001','c8500000-0000-0000-0000-000000000001','c8600000-0000-0000-0000-000000000001','parent',true,'active');
insert into public.student_enrollments(id,organization_id,school_id,academic_year_id,student_id,grade_level_id,enrolled_on,scheduled_end_on,enrollment_range,status,created_by,updated_by) values
 ('c8800000-0000-0000-0000-000000000001','c2000000-0000-0000-0000-000000000001','c3000000-0000-0000-0000-000000000001','c8000000-0000-0000-0000-000000000001','c8500000-0000-0000-0000-000000000001','c8200000-0000-0000-0000-000000000001',current_date-80,current_date+80,daterange(current_date-80,current_date+80,'[]'),'active','c1000000-0000-0000-0000-000000000001','c1000000-0000-0000-0000-000000000001');
insert into public.student_section_placements(id,organization_id,school_id,campus_id,academic_year_id,student_enrollment_id,student_id,section_id,starts_on,status,created_by,updated_by) values
 ('c8900000-0000-0000-0000-000000000001','c2000000-0000-0000-0000-000000000001','c3000000-0000-0000-0000-000000000001','c4000000-0000-0000-0000-000000000001','c8000000-0000-0000-0000-000000000001','c8800000-0000-0000-0000-000000000001','c8500000-0000-0000-0000-000000000001','c8400000-0000-0000-0000-000000000001',current_date-80,'active','c1000000-0000-0000-0000-000000000001','c1000000-0000-0000-0000-000000000001');
insert into public.teaching_assignments(id,organization_id,school_id,campus_id,academic_year_id,section_id,subject_id,staff_profile_id,role,starts_on,scheduled_ends_on,effective_range,status,created_by,updated_by) values
 ('ca000000-0000-0000-0000-000000000002','c2000000-0000-0000-0000-000000000001','c3000000-0000-0000-0000-000000000001','c4000000-0000-0000-0000-000000000001','c8000000-0000-0000-0000-000000000001','c8400000-0000-0000-0000-000000000001','c8300000-0000-0000-0000-000000000001','c7000000-0000-0000-0000-000000000002','lead',current_date-10,current_date+10,daterange(current_date-10,current_date+10,'[]'),'active','c1000000-0000-0000-0000-000000000001','c1000000-0000-0000-0000-000000000001'),
 ('ca000000-0000-0000-0000-000000000003','c2000000-0000-0000-0000-000000000001','c3000000-0000-0000-0000-000000000001','c4000000-0000-0000-0000-000000000001','c8000000-0000-0000-0000-000000000001','c8400000-0000-0000-0000-000000000001','c8300000-0000-0000-0000-000000000001','c7000000-0000-0000-0000-000000000003','assistant',current_date-10,current_date+10,daterange(current_date-10,current_date+10,'[]'),'active','c1000000-0000-0000-0000-000000000001','c1000000-0000-0000-0000-000000000001');

create temp table assessment_ids(kind text primary key,id uuid) on commit drop;
create temp table frozen_content(id uuid,title text,description text,assessment_date date,due_date date,
 maximum_score numeric,weight numeric,score numeric,teacher_comment text) on commit drop;
grant select,insert on assessment_ids,frozen_content to authenticated;

set local role anon;
select throws_ok($$select public.create_assessment('c8400000-0000-0000-0000-000000000001','c8100000-0000-0000-0000-000000000001','c8300000-0000-0000-0000-000000000001','exam','Anon',null,current_date,current_date,100,50)$$,
 '42501','permission denied for function create_assessment','anonymous create denied');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"c1000000-0000-0000-0000-000000000006","role":"authenticated"}',true);
select throws_ok($$select public.create_assessment('c8400000-0000-0000-0000-000000000001','c8100000-0000-0000-0000-000000000001','c8300000-0000-0000-0000-000000000001','exam','Denied',null,current_date,current_date,100,50)$$,
 '42501','effective teaching assignment or assessments.manage permission is required','missing permission denied');

select set_config('request.jwt.claims','{"sub":"c1000000-0000-0000-0000-000000000002","role":"authenticated"}',true);
with x as (select public.create_assessment('c8400000-0000-0000-0000-000000000001','c8100000-0000-0000-0000-000000000001','c8300000-0000-0000-0000-000000000001','participation','Teacher draft',null,current_date+5,current_date+5,5,null) id)
 insert into assessment_ids select 'teacher',id from x;
select lives_ok($$select public.cancel_draft_assessment((select id from assessment_ids where kind='teacher'),'not needed')$$,'effective exact-context lead creates and cancels draft');
select throws_ok($$select public.create_assessment('c8400000-0000-0000-0000-000000000001','c8100000-0000-0000-0000-000000000001',null,'participation','Wrong context',null,current_date+6,current_date+6,5,null)$$,
 '42501','effective teaching assignment or assessments.manage permission is required','subject teacher cannot manage null-subject context');

select set_config('request.jwt.claims','{"sub":"c1000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
with x as (select public.create_assessment('c8400000-0000-0000-0000-000000000001','c8100000-0000-0000-0000-000000000001','c8300000-0000-0000-0000-000000000001','exam','Midterm','Core assessment',current_date,current_date+1,100,50) id)
 insert into assessment_ids select 'published',id from x;
select is((select count(*)::int from public.assessment_students where assessment_id=(select id from assessment_ids where kind='published')),1,'create snapshots exact roster');
select is((select count(*)::int from public.assessment_results where assessment_id=(select id from assessment_ids where kind='published') and score is null),1,'create initializes one unscored result');
select throws_ok($$select public.publish_assessment((select id from assessment_ids where kind='published'))$$,'22023','complete scores are required for publication','incomplete publish denied');
select lives_ok($$select public.record_assessment_results((select id from assessment_ids where kind='published'),array[row('c8500000-0000-0000-0000-000000000001',88,'Strong work')::public.assessment_result_input])$$,'score and comment recorded');

select set_config('request.jwt.claims','{"sub":"c1000000-0000-0000-0000-000000000004","role":"authenticated"}',true);
select is((select count(*)::int from public.assessment_results),0,'student cannot read unpublished result');
select set_config('request.jwt.claims','{"sub":"c1000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select lives_ok($$select public.publish_assessment((select id from assessment_ids where kind='published'))$$,'complete draft publishes');
select lives_ok($$select public.finalize_assessment((select id from assessment_ids where kind='published'))$$,'published draft finalizes');

select set_config('request.jwt.claims','{"sub":"c1000000-0000-0000-0000-000000000004","role":"authenticated"}',true);
select is((select teacher_comment from public.assessment_results),'Strong work','student reads own published teacher comment');
select set_config('request.jwt.claims','{"sub":"c1000000-0000-0000-0000-000000000005","role":"authenticated"}',true);
select is((select teacher_comment from public.assessment_results),'Strong work','guardian reads linked published teacher comment');

select set_config('request.jwt.claims','{"sub":"c1000000-0000-0000-0000-000000000003","role":"authenticated"}',true);
select is((select count(*)::int from public.assessment_results),2,'assistant contextual read includes published and preserved cancelled-draft results');
select throws_ok($$select public.record_assessment_results((select id from assessment_ids where kind='published'),array[row('c8500000-0000-0000-0000-000000000001',90,null)::public.assessment_result_input])$$,
 '42501','effective teaching assignment or assessments.manage permission is required','assistant cannot grade');
reset role;
update public.organization_memberships set status='suspended' where id='c5000000-0000-0000-0000-000000000003';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"c1000000-0000-0000-0000-000000000003","role":"authenticated"}',true);
select is((select count(*)::int from public.assessment_results),0,'inactive assistant membership removes contextual read');

select set_config('request.jwt.claims','{"sub":"c1000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select lives_ok($$select * from public.correct_assessment((select id from assessment_ids where kind='published'),'c8300000-0000-0000-0000-000000000001','exam','Midterm corrected','Corrected metadata',current_date,current_date+1,100,50,array[row('c8500000-0000-0000-0000-000000000001',91,'Rechecked')::public.assessment_result_input],'score was rechecked')$$,'finalized assessment correction succeeds');
select is((select count(*)::int from public.assessments where lifecycle_status='corrected'),1,'correction preserves corrected predecessor');
select is((select count(*)::int from public.assessments where lifecycle_status='finalized' and publication_state='published'),1,'correction appends published finalized successor');

with x as (select public.create_assessment('c8400000-0000-0000-0000-000000000001','c8100000-0000-0000-0000-000000000001','c8300000-0000-0000-0000-000000000001','quiz','Cancelled quiz',null,current_date+2,current_date+2,10,null) id)
 insert into assessment_ids select 'cancelled',id from x;
select lives_ok($$select public.cancel_draft_assessment((select id from assessment_ids where kind='cancelled'),'duplicate draft')$$,'unpublished draft cancels');
select is((select count(*)::int from public.assessment_students where assessment_id=(select id from assessment_ids where kind='cancelled')),1,'cancel preserves snapshot');
select is((select count(*)::int from public.assessment_results where assessment_id=(select id from assessment_ids where kind='cancelled')),1,'cancel preserves result');
select lives_ok($$select public.create_assessment('c8400000-0000-0000-0000-000000000001','c8100000-0000-0000-0000-000000000001','c8300000-0000-0000-0000-000000000001','quiz','Cancelled quiz',null,current_date+2,current_date+2,10,null)$$,'cancelled row releases live uniqueness');
select throws_ok($$select public.publish_assessment((select id from assessment_ids where kind='cancelled'))$$,'22023','unpublished draft or finalized assessment is required','cancelled assessment cannot reactivate through publish');

with x as (select public.create_assessment('c8400000-0000-0000-0000-000000000001','c8100000-0000-0000-0000-000000000001','c8300000-0000-0000-0000-000000000001','project','Final unpublished',null,current_date+3,current_date+4,20,25) id)
 insert into assessment_ids select 'late_publish',id from x;
select lives_ok($$select public.record_assessment_results((select id from assessment_ids where kind='late_publish'),array[row('c8500000-0000-0000-0000-000000000001',17,'Complete')::public.assessment_result_input])$$,'late-publication score recorded');
select lives_ok($$select public.finalize_assessment((select id from assessment_ids where kind='late_publish'))$$,'assessment finalizes unpublished');
insert into frozen_content select a.id,a.title,a.description,a.assessment_date,a.due_date,a.maximum_score,a.weight,r.score,r.teacher_comment
 from public.assessments a join public.assessment_results r on r.assessment_id=a.id where a.id=(select id from assessment_ids where kind='late_publish');
select lives_ok($$select public.publish_assessment((select id from assessment_ids where kind='late_publish'))$$,'finalized unpublished assessment publishes');
select ok(not exists(select 1 from frozen_content f join public.assessments a on a.id=f.id join public.assessment_results r on r.assessment_id=a.id
 where (a.title,a.description,a.assessment_date,a.due_date,a.maximum_score,a.weight,r.score,r.teacher_comment)
  is distinct from (f.title,f.description,f.assessment_date,f.due_date,f.maximum_score,f.weight,f.score,f.teacher_comment)),
 'late publication leaves finalized academic content byte-equivalent');
select throws_ok($$insert into public.assessment_results(id) values(gen_random_uuid())$$,'42501','permission denied for table assessment_results','direct result insert denied');
reset role;

select ok(not exists(select 1 from public.event_outbox where event_type like 'assessment.%'
 and (payload?'score' or payload?'teacher_comment' or payload?'description')),'outbox omits scores, comments, and descriptions');
select is((select count(*)::int from public.event_outbox where event_type='assessment.cancelled'),2,'each cancellation emits exactly one event');
select is((select count(*)::int from public.audit_log where action='assessment.cancelled'),2,'each cancellation writes exactly one audit row');
select is((select count(*)::int from public.audit_log where command_id=(select command_id from public.audit_log
 where action='assessment.created' and entity_id=(select id from assessment_ids where kind='late_publish'))),3,
 'one-student create has one assessment, one snapshot, and one initialized-result audit');
select is((select count(*)::int from public.event_outbox where command_id=(select command_id from public.audit_log
 where action='assessment.created' and entity_id=(select id from assessment_ids where kind='late_publish'))),1,
 'create emits only the assessment event');
select is((select count(*)::int from public.audit_log where command_id=(select command_id from public.audit_log
 where action='assessment.corrected' limit 1)),4,'one-student correction has exact 2+2N audit cardinality');
select is((select count(*)::int from public.event_outbox where command_id=(select command_id from public.audit_log
 where action='assessment.corrected' limit 1)),3,'one-student correction has exact 2+N event cardinality');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"c1000000-0000-0000-0000-000000000004","role":"authenticated"}',true);
select is((select count(*)::int from public.assessments where lifecycle_status='cancelled'),0,'student cannot read cancelled assessment');
reset role;

-- Cancelled drafts do not block subject lifecycle; the live drafts still do.
update public.assessments set lifecycle_status='cancelled',cancellation_reason='test cleanup',cancelled_at=now(),cancelled_by='c1000000-0000-0000-0000-000000000001',updated_by='c1000000-0000-0000-0000-000000000001'
 where title='Cancelled quiz' and lifecycle_status='draft';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"c1000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select lives_ok($$select public.update_subject('c8300000-0000-0000-0000-000000000001','MATH','Mathematics',null,'inactive',true)$$,'cancelled drafts do not block subject inactivation');
reset role;
select throws_ok($$delete from public.student_section_placements where id='c8900000-0000-0000-0000-000000000001'$$,'23503',null,'assessment snapshot provenance prevents destructive placement delete');

select * from finish();
rollback;
