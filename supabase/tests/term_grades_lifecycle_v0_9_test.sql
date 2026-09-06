begin;
create extension if not exists pgtap with schema extensions;
create extension if not exists dblink with schema extensions;
select no_plan();

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,created_at,updated_at) values
 ('f1000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','term-admin@test','',now(),now()),
 ('f1000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','term-teacher@test','',now(),now()),
 ('f1000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000000','authenticated','authenticated','term-assistant@test','',now(),now()),
 ('f1000000-0000-0000-0000-000000000004','00000000-0000-0000-0000-000000000000','authenticated','authenticated','term-student@test','',now(),now()),
 ('f1000000-0000-0000-0000-000000000005','00000000-0000-0000-0000-000000000000','authenticated','authenticated','term-guardian@test','',now(),now());
insert into public.organizations(id,name,slug) values('f2000000-0000-0000-0000-000000000001','Term Tenant','term-tenant');
insert into public.schools(id,organization_id,name,code) values('f3000000-0000-0000-0000-000000000001','f2000000-0000-0000-0000-000000000001','Term School','TRM');
insert into public.campuses(id,organization_id,school_id,name,code) values('f4000000-0000-0000-0000-000000000001','f2000000-0000-0000-0000-000000000001','f3000000-0000-0000-0000-000000000001','Term Campus','MAIN');
insert into public.organization_memberships(id,organization_id,user_id,status,joined_at) values
 ('f5000000-0000-0000-0000-000000000001','f2000000-0000-0000-0000-000000000001','f1000000-0000-0000-0000-000000000001','active',now()),
 ('f5000000-0000-0000-0000-000000000002','f2000000-0000-0000-0000-000000000001','f1000000-0000-0000-0000-000000000002','active',now()),
 ('f5000000-0000-0000-0000-000000000003','f2000000-0000-0000-0000-000000000001','f1000000-0000-0000-0000-000000000003','active',now());
insert into public.roles(id,organization_id,code,name) values('f6000000-0000-0000-0000-000000000001','f2000000-0000-0000-0000-000000000001','TERM_ADMIN','Term Admin');
insert into public.role_permissions(organization_id,role_id,permission_id)
 select 'f2000000-0000-0000-0000-000000000001','f6000000-0000-0000-0000-000000000001',id from public.permissions
 where code like 'term_grades.%' or code like 'assessments.%' or code='academic_structure.manage';
insert into public.role_assignments(organization_id,organization_membership_id,role_id,school_id,campus_id) values
 ('f2000000-0000-0000-0000-000000000001','f5000000-0000-0000-0000-000000000001','f6000000-0000-0000-0000-000000000001','f3000000-0000-0000-0000-000000000001',null);
insert into public.staff_profiles(id,organization_id,organization_membership_id,staff_number,employment_type,status) values
 ('f7000000-0000-0000-0000-000000000002','f2000000-0000-0000-0000-000000000001','f5000000-0000-0000-0000-000000000002','TRM-T','teacher','active'),
 ('f7000000-0000-0000-0000-000000000003','f2000000-0000-0000-0000-000000000001','f5000000-0000-0000-0000-000000000003','TRM-A','assistant','active');
insert into public.academic_years(id,organization_id,school_id,name,start_date,end_date,status) values('f8000000-0000-0000-0000-000000000001','f2000000-0000-0000-0000-000000000001','f3000000-0000-0000-0000-000000000001','Term Year',current_date-100,current_date+100,'active');
insert into public.academic_terms(id,organization_id,academic_year_id,name,sequence,start_date,end_date,status) values('f8100000-0000-0000-0000-000000000001','f2000000-0000-0000-0000-000000000001','f8000000-0000-0000-0000-000000000001','Term One',1,current_date-80,current_date+80,'active');
insert into public.grade_levels(id,organization_id,school_id,code,name,sequence,status) values('f8200000-0000-0000-0000-000000000001','f2000000-0000-0000-0000-000000000001','f3000000-0000-0000-0000-000000000001','G1','Grade One',1,'active');
insert into public.subjects(id,organization_id,school_id,code,name,status) values('f8300000-0000-0000-0000-000000000001','f2000000-0000-0000-0000-000000000001','f3000000-0000-0000-0000-000000000001','MATH','Mathematics','active');
insert into public.sections(id,organization_id,school_id,campus_id,academic_year_id,academic_term_id,grade_level_id,code,name,capacity,start_date,end_date,status) values('f8400000-0000-0000-0000-000000000001','f2000000-0000-0000-0000-000000000001','f3000000-0000-0000-0000-000000000001','f4000000-0000-0000-0000-000000000001','f8000000-0000-0000-0000-000000000001','f8100000-0000-0000-0000-000000000001','f8200000-0000-0000-0000-000000000001','T1','Term One',30,current_date-80,current_date+80,'active');
insert into public.students(id,organization_id,school_id,campus_id,user_id,student_number,first_name,last_name,date_of_birth) values('f8500000-0000-0000-0000-000000000001','f2000000-0000-0000-0000-000000000001','f3000000-0000-0000-0000-000000000001','f4000000-0000-0000-0000-000000000001','f1000000-0000-0000-0000-000000000004','TRM-1','Term','Student','2015-01-01');
insert into public.guardians(id,organization_id,user_id,first_name,last_name,status) values('f8600000-0000-0000-0000-000000000001','f2000000-0000-0000-0000-000000000001','f1000000-0000-0000-0000-000000000005','Term','Guardian','active');
insert into public.student_guardians(id,organization_id,student_id,guardian_id,relationship_type,has_portal_access,status) values('f8700000-0000-0000-0000-000000000001','f2000000-0000-0000-0000-000000000001','f8500000-0000-0000-0000-000000000001','f8600000-0000-0000-0000-000000000001','parent',true,'active');
insert into public.student_enrollments(id,organization_id,school_id,academic_year_id,student_id,grade_level_id,enrolled_on,scheduled_end_on,enrollment_range,status,created_by,updated_by) values('f8800000-0000-0000-0000-000000000001','f2000000-0000-0000-0000-000000000001','f3000000-0000-0000-0000-000000000001','f8000000-0000-0000-0000-000000000001','f8500000-0000-0000-0000-000000000001','f8200000-0000-0000-0000-000000000001',current_date-80,current_date+80,daterange(current_date-80,current_date+80,'[]'),'active','f1000000-0000-0000-0000-000000000001','f1000000-0000-0000-0000-000000000001');
insert into public.student_section_placements(id,organization_id,school_id,campus_id,academic_year_id,student_enrollment_id,student_id,section_id,starts_on,status,created_by,updated_by) values('f8900000-0000-0000-0000-000000000001','f2000000-0000-0000-0000-000000000001','f3000000-0000-0000-0000-000000000001','f4000000-0000-0000-0000-000000000001','f8000000-0000-0000-0000-000000000001','f8800000-0000-0000-0000-000000000001','f8500000-0000-0000-0000-000000000001','f8400000-0000-0000-0000-000000000001',current_date-80,'active','f1000000-0000-0000-0000-000000000001','f1000000-0000-0000-0000-000000000001');
insert into public.teaching_assignments(id,organization_id,school_id,campus_id,academic_year_id,section_id,subject_id,staff_profile_id,role,starts_on,scheduled_ends_on,effective_range,status,created_by,updated_by) values
 ('fa000000-0000-0000-0000-000000000002','f2000000-0000-0000-0000-000000000001','f3000000-0000-0000-0000-000000000001','f4000000-0000-0000-0000-000000000001','f8000000-0000-0000-0000-000000000001','f8400000-0000-0000-0000-000000000001','f8300000-0000-0000-0000-000000000001','f7000000-0000-0000-0000-000000000002','lead',current_date-10,current_date+10,daterange(current_date-10,current_date+10,'[]'),'active','f1000000-0000-0000-0000-000000000001','f1000000-0000-0000-0000-000000000001'),
 ('fa000000-0000-0000-0000-000000000003','f2000000-0000-0000-0000-000000000001','f3000000-0000-0000-0000-000000000001','f4000000-0000-0000-0000-000000000001','f8000000-0000-0000-0000-000000000001','f8400000-0000-0000-0000-000000000001','f8300000-0000-0000-0000-000000000001','f7000000-0000-0000-0000-000000000003','assistant',current_date-10,current_date+10,daterange(current_date-10,current_date+10,'[]'),'active','f1000000-0000-0000-0000-000000000001','f1000000-0000-0000-0000-000000000001');

create temp table term_ids(kind text primary key,id uuid);
grant select,insert,update on term_ids to authenticated;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"f1000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
with x as (select public.create_grade_scale('f3000000-0000-0000-0000-000000000001','f8000000-0000-0000-0000-000000000001','Standard',null,array[
 row(1,0,60,'F','fail')::public.grade_scale_band_input,row(2,60,80,'C','pass')::public.grade_scale_band_input,
 row(3,80,90,'B','pass')::public.grade_scale_band_input,row(4,90,100,'A','pass')::public.grade_scale_band_input]) id)
 insert into term_ids select 'scale',id from x;
reset role;
select is((select count(*)::int from public.audit_log where command_id=(select command_id from public.audit_log where action='grade_scale.created' and entity_id=(select id from term_ids where kind='scale'))),5,'scale create audits one scale plus four exact band rows');
select is((select count(*)::int from public.event_outbox where command_id=(select command_id from public.audit_log where action='grade_scale.created' and entity_id=(select id from term_ids where kind='scale'))),1,'scale create emits no per-band events');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"f1000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select lives_ok($$select public.activate_grade_scale((select id from term_ids where kind='scale'))$$,'complete scale activates');
with x as (select public.revise_grade_scale((select id from term_ids where kind='scale'),'Standard',null,array[
 row(1,0,60,'F','fail')::public.grade_scale_band_input,row(2,60,80,'C','pass')::public.grade_scale_band_input,
 row(3,80,90,'B','pass')::public.grade_scale_band_input,row(4,90,100,'A','pass')::public.grade_scale_band_input]) id)
 insert into term_ids select 'scale_revision',id from x;
select is((select count(*)::int from public.grade_scales where name='Standard' and status in('active','draft')),2,'same-name active scale and its draft revision coexist');
reset role;
select is((select after_data->>'supersedes_grade_scale_id' from public.audit_log where action='grade_scale.created' and entity_id=(select id from term_ids where kind='scale_revision')),(select id::text from term_ids where kind='scale'),'scale revision audit captures its predecessor');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"f1000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.revise_grade_scale((select id from term_ids where kind='scale'),'Standard',null,array[row(1,0,100,'A','pass')::public.grade_scale_band_input])$$,'23505',null,'a second same-name draft head is rejected');
select throws_ok($$select public.update_draft_grade_scale((select id from term_ids where kind='scale_revision'),'Standard',null,false,array[]::public.grade_scale_band_input[])$$,'22023','one to 100 bands with four-decimal bounds are required','draft scale replacement rejects an empty band array');
select throws_ok($$select public.update_draft_grade_scale((select id from term_ids where kind='scale_revision'),'Standard',null,false,array[row(1,0.00001,100,'A','pass')::public.grade_scale_band_input])$$,'22023','one to 100 bands with four-decimal bounds are required','draft scale replacement rejects bounds beyond four decimals');
select throws_ok($$select public.update_draft_grade_scale((select id from term_ids where kind='scale_revision'),'Standard',null,false,array(select row(g,g-1,g,'B'||g,'pass')::public.grade_scale_band_input from generate_series(1,101) g))$$,'22023','one to 100 bands with four-decimal bounds are required','draft scale replacement rejects more than 100 bands');

with x as (select public.create_term_grading_configuration('f8400000-0000-0000-0000-000000000001','f8100000-0000-0000-0000-000000000001','f8300000-0000-0000-0000-000000000001',(select id from term_ids where kind='scale'),true,false) id)
 insert into term_ids select 'config',id from x;
select lives_ok($$select public.activate_term_grading_configuration((select id from term_ids where kind='config'))$$,'configuration activates');
with x as (select public.revise_term_grading_configuration((select id from term_ids where kind='config'),(select id from term_ids where kind='scale'),true,false) id)
 insert into term_ids select 'config_revision',id from x;
select is((select count(*)::int from public.term_grading_configurations where section_id='f8400000-0000-0000-0000-000000000001' and academic_term_id='f8100000-0000-0000-0000-000000000001' and subject_id='f8300000-0000-0000-0000-000000000001' and status in('active','draft')),2,'one active configuration and its draft successor coexist');
select throws_ok($$select public.revise_term_grading_configuration((select id from term_ids where kind='config'),(select id from term_ids where kind='scale'),true,false)$$,'23505',null,'multiple draft configuration successors are rejected');
reset role;
update public.subjects set status='inactive' where id='f8300000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"f1000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.update_draft_term_grading_configuration((select id from term_ids where kind='config_revision'),(select id from term_ids where kind='scale'),true,false)$$,'22023','active scope-compatible parents and dates are required','draft configuration update revalidates active subject');
select throws_ok($$select public.activate_term_grading_configuration((select id from term_ids where kind='config_revision'))$$,'22023','active scope-compatible parents and dates are required','configuration activation revalidates active subject');
reset role;
update public.subjects set status='active' where id='f8300000-0000-0000-0000-000000000001';
update public.campuses set status='inactive' where id='f4000000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"f1000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.create_term_grading_configuration('f8400000-0000-0000-0000-000000000001','f8100000-0000-0000-0000-000000000001',null,(select id from term_ids where kind='scale'),true,false)$$,'22023','active scope-compatible parents and dates are required','configuration creation revalidates active campus');
reset role;
update public.campuses set status='active' where id='f4000000-0000-0000-0000-000000000001';
update public.organizations set status='inactive' where id='f2000000-0000-0000-0000-000000000001';
select throws_ok($$select app_auth.assert_term_grading_configuration_context('f8400000-0000-0000-0000-000000000001','f8100000-0000-0000-0000-000000000001','f8300000-0000-0000-0000-000000000001',(select id from term_ids where kind='scale'))$$,'22023','active scope-compatible parents and dates are required','inactive organization is rejected');
update public.organizations set status='active' where id='f2000000-0000-0000-0000-000000000001';
update public.schools set status='inactive' where id='f3000000-0000-0000-0000-000000000001';
select throws_ok($$select app_auth.assert_term_grading_configuration_context('f8400000-0000-0000-0000-000000000001','f8100000-0000-0000-0000-000000000001','f8300000-0000-0000-0000-000000000001',(select id from term_ids where kind='scale'))$$,'22023','active scope-compatible parents and dates are required','inactive school is rejected');
update public.schools set status='active' where id='f3000000-0000-0000-0000-000000000001';
update public.academic_years set status='closed' where id='f8000000-0000-0000-0000-000000000001';
select throws_ok($$select app_auth.assert_term_grading_configuration_context('f8400000-0000-0000-0000-000000000001','f8100000-0000-0000-0000-000000000001','f8300000-0000-0000-0000-000000000001',(select id from term_ids where kind='scale'))$$,'22023','active scope-compatible parents and dates are required','closed academic year is rejected');
update public.academic_years set status='active' where id='f8000000-0000-0000-0000-000000000001';
update public.academic_terms set status='closed' where id='f8100000-0000-0000-0000-000000000001';
select throws_ok($$select app_auth.assert_term_grading_configuration_context('f8400000-0000-0000-0000-000000000001','f8100000-0000-0000-0000-000000000001','f8300000-0000-0000-0000-000000000001',(select id from term_ids where kind='scale'))$$,'22023','active scope-compatible parents and dates are required','closed academic term is rejected');
update public.academic_terms set status='active',start_date=current_date-81 where id='f8100000-0000-0000-0000-000000000001';
select throws_ok($$select app_auth.assert_term_grading_configuration_context('f8400000-0000-0000-0000-000000000001','f8100000-0000-0000-0000-000000000001','f8300000-0000-0000-0000-000000000001',(select id from term_ids where kind='scale'))$$,'22023','active scope-compatible parents and dates are required','term dates outside section dates are rejected');
update public.academic_terms set start_date=current_date-80 where id='f8100000-0000-0000-0000-000000000001';
update public.sections set status='inactive' where id='f8400000-0000-0000-0000-000000000001';
select throws_ok($$select app_auth.assert_term_grading_configuration_context('f8400000-0000-0000-0000-000000000001','f8100000-0000-0000-0000-000000000001','f8300000-0000-0000-0000-000000000001',(select id from term_ids where kind='scale'))$$,'22023','active scope-compatible parents and dates are required','inactive section is rejected');
update public.sections set status='active' where id='f8400000-0000-0000-0000-000000000001';
select throws_ok($$select app_auth.assert_term_grading_configuration_context('f8400000-0000-0000-0000-000000000001','f8100000-0000-0000-0000-000000000001','f8300000-0000-0000-0000-000000000001',(select id from term_ids where kind='scale_revision'))$$,'22023','active scope-compatible parents and dates are required','draft grade scale is rejected');
insert into public.academic_terms(id,organization_id,academic_year_id,name,sequence,start_date,end_date,status) values('f8100000-0000-0000-0000-000000000002','f2000000-0000-0000-0000-000000000001','f8000000-0000-0000-0000-000000000001','Other Term',2,current_date-70,current_date+70,'active');
select throws_ok($$select app_auth.assert_term_grading_configuration_context('f8400000-0000-0000-0000-000000000001','f8100000-0000-0000-0000-000000000002','f8300000-0000-0000-0000-000000000001',(select id from term_ids where kind='scale'))$$,'22023','active scope-compatible parents and dates are required','section-bound term mismatch is rejected');
delete from public.academic_terms where id='f8100000-0000-0000-0000-000000000002';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"f1000000-0000-0000-0000-000000000001","role":"authenticated"}',true);

with x as (select public.create_assessment('f8400000-0000-0000-0000-000000000001','f8100000-0000-0000-0000-000000000001','f8300000-0000-0000-0000-000000000001','exam','Term exam 1',null,current_date,current_date,100,40) id) insert into term_ids select 'assessment1',id from x;
select public.record_assessment_results((select id from term_ids where kind='assessment1'),array[row('f8500000-0000-0000-0000-000000000001',80,null)::public.assessment_result_input]);
select public.publish_assessment((select id from term_ids where kind='assessment1'));
select public.finalize_assessment((select id from term_ids where kind='assessment1'));
with x as (select public.create_assessment('f8400000-0000-0000-0000-000000000001','f8100000-0000-0000-0000-000000000001','f8300000-0000-0000-0000-000000000001','exam','Term exam 2',null,current_date+1,current_date+1,100,60) id) insert into term_ids select 'assessment2',id from x;
select public.record_assessment_results((select id from term_ids where kind='assessment2'),array[row('f8500000-0000-0000-0000-000000000001',90,null)::public.assessment_result_input]);
select public.publish_assessment((select id from term_ids where kind='assessment2'));
select public.finalize_assessment((select id from term_ids where kind='assessment2'));
with x as (select * from public.calculate_term_grades((select id from term_ids where kind='config'))) insert into term_ids select 'set',term_grade_set_id from x;
select throws_ok($$select * from public.calculate_term_grades((select id from term_ids where kind='config'))$$,'40001','term-grade set head changed; retry','competing live-head creation is normalized to retryable 40001');
select is((select rounded_percentage from public.term_grade_calculations where term_grade_set_id=(select id from term_ids where kind='set')),86.0000::numeric,'weighted formula rounds once to four decimals');
select is((select grade_label from public.term_grade_calculations where term_grade_set_id=(select id from term_ids where kind='set')),'B','rounded boundary selects deterministic band');
select is((select count(*)::int from public.term_grade_calculation_sources),2,'every contributing result has immutable provenance');
select ok((select bool_and(assessment_root_id=assessment_id and assessment_version_id=assessment_id) from public.term_grade_calculation_sources),'initial provenance roots are complete');
reset role;
select is(app_auth.term_grade_fingerprint((select id from term_ids where kind='config')),app_auth.term_grade_fingerprint((select id from term_ids where kind='config')),'canonical fingerprint is deterministic');
select is((select count(*)::int from public.audit_log where command_id=(select command_id from public.audit_log where action='term_grade_set.calculated' and entity_id=(select id from term_ids where kind='set'))),5,'calculate audit cardinality is 1 + 2N + C');
select is((select count(*)::int from public.event_outbox where command_id=(select command_id from public.audit_log where action='term_grade_set.calculated' and entity_id=(select id from term_ids where kind='set'))),2,'calculate emits set plus one record events only');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"f1000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select lives_ok($$select * from public.recalculate_draft_term_grades((select id from term_ids where kind='set'))$$,'draft recalculation appends a generation');
select is((select count(*)::int from public.term_grade_records where term_grade_set_id=(select id from term_ids where kind='set')),2,'recalculation preserves prior immutable record generation');
reset role;
select is((select count(*)::int from public.audit_log where command_id=(select command_id from public.audit_log where action='term_grade_set.recalculated' and entity_id=(select id from term_ids where kind='set'))),5,'recalculate audit cardinality is 1 + 2N + C');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"f1000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
with x as (select * from public.correct_assessment((select id from term_ids where kind='assessment1'),'f8300000-0000-0000-0000-000000000001','exam','Term exam 1 corrected',null,current_date,current_date,100,40,array[row('f8500000-0000-0000-0000-000000000001',85,null)::public.assessment_result_input],'verified score'))
 insert into term_ids select 'assessment1_replacement',replacement_assessment_id from x;
select throws_ok($$select public.publish_term_grades((select id from term_ids where kind='set'))$$,'40001','term-grade sources changed; recalculate and retry','source correction makes draft stale at publication');
select lives_ok($$select * from public.recalculate_draft_term_grades((select id from term_ids where kind='set'))$$,'stale draft can be explicitly recalculated');
select ok(exists(select 1 from public.term_grade_calculation_sources s join public.term_grade_records r on r.id=(select term_grade_record_id from public.term_grade_calculations c where c.id=s.term_grade_calculation_id) where r.term_grade_set_id=(select id from term_ids where kind='set') and r.calculation_sequence=3 and s.assessment_id=(select id from term_ids where kind='assessment1_replacement') and s.assessment_root_id=(select id from term_ids where kind='assessment1')),'recalculation preserves complete correction-root provenance');
select lives_ok($$select public.activate_term_grading_configuration((select id from term_ids where kind='config_revision'))$$,'successor configuration activates and retires its predecessor');
select throws_ok($$select public.publish_term_grades((select id from term_ids where kind='set'))$$,'40001','term-grade sources changed; recalculate and retry','successor configuration activation stales an older draft at publish');
select throws_ok($$select public.finalize_term_grades((select id from term_ids where kind='set'))$$,'40001','term-grade sources changed; recalculate and retry','successor configuration activation stales an older draft at finalize');
select lives_ok($$select public.cancel_draft_term_grades((select id from term_ids where kind='set'),'superseded configuration')$$,'stale unpublished draft can be cancelled');
with x as (select * from public.calculate_term_grades((select id from term_ids where kind='config_revision')))
 update term_ids set id=x.term_grade_set_id from x where kind='set';
select lives_ok($$select public.publish_term_grades((select id from term_ids where kind='set'))$$,'draft publishes before finalization');
reset role;
select is((select count(*)::int from public.audit_log where command_id=(select command_id from public.audit_log where action='term_grade_set.published' and entity_id=(select id from term_ids where kind='set'))),1,'publish has exactly one transition audit');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"f1000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select lives_ok($$select public.finalize_term_grades((select id from term_ids where kind='set'))$$,'published draft finalizes');
reset role;
select is((select count(*)::int from public.audit_log where command_id=(select command_id from public.audit_log where action='term_grade_set.finalized' and entity_id=(select id from term_ids where kind='set'))),1,'finalize has exactly one transition audit');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"f1000000-0000-0000-0000-000000000002","role":"authenticated"}',true);
select is((select count(*)::int from public.grade_scales where id=(select id from term_ids where kind='scale')),1,'contextual teacher can read the configured scale');
select throws_ok($$select * from public.correct_term_grades((select id from term_ids where kind='set'),'teacher correction')$$,'42501','term_grades.manage and term_grades.correct permissions are required','relationship-derived teacher cannot correct');
reset role;
commit;

select extensions.dblink_connect('term_grade_race_1','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');
select extensions.dblink_connect('term_grade_race_2','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');
select extensions.dblink_exec('term_grade_race_1','begin');
with raced as (
 select * from extensions.dblink('term_grade_race_1',format($q$
  with claims as (select set_config('request.jwt.claims','{"sub":"f1000000-0000-0000-0000-000000000001","role":"authenticated"}',false))
  select c.* from claims cross join lateral public.correct_term_grades(%L,'approved whole-set correction') c
 $q$,(select id from term_ids where kind='set'))) as x(corrected_term_grade_set_id uuid,replacement_term_grade_set_id uuid)
), normalized as (
 select corrected_term_grade_set_id,replacement_term_grade_set_id from raced
)
insert into term_ids
select 'replacement_set',replacement_term_grade_set_id from normalized;
select is(extensions.dblink_send_query('term_grade_race_2',format($q$
 with claims as (select set_config('request.jwt.claims','{"sub":"f1000000-0000-0000-0000-000000000001","role":"authenticated"}',false))
 select c.* from claims cross join lateral public.correct_term_grades(%L,'competing correction') c
$q$,(select id from term_ids where kind='set'))),1,'second correction command is issued from a genuinely separate session');
select extensions.dblink_exec('term_grade_race_1','commit');
select throws_ok(format($q$select * from extensions.dblink_get_result('term_grade_race_2') as x(corrected_term_grade_set_id uuid,replacement_term_grade_set_id uuid)$q$),
 '40001','term-grade correction head changed; retry','concurrent whole-set correction loser receives retryable 40001');
select extensions.dblink_disconnect('term_grade_race_1');
select extensions.dblink_disconnect('term_grade_race_2');

begin;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"f1000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select is((select lifecycle_status::text from public.term_grade_sets where id=(select id from term_ids where kind='set')),'corrected','correction marks the whole predecessor set corrected');
select is((select lifecycle_status::text from public.term_grade_sets where id=(select id from term_ids where kind='replacement_set')),'finalized','correction appends one finalized whole-set successor');
select is((select count(*)::int from public.term_grade_sets where supersedes_term_grade_set_id=(select id from term_ids where kind='set')),1,'whole-set correction history cannot branch');
reset role;
select is((select count(*)::int from public.audit_log where command_id=(select command_id from public.audit_log where action='term_grade_set.corrected' and entity_id=(select id from term_ids where kind='set'))),6,'correction audit cardinality is 2 + 2N + C');
select is((select count(*)::int from public.event_outbox where command_id=(select command_id from public.audit_log where action='term_grade_set.corrected' and entity_id=(select id from term_ids where kind='set'))),3,'correction emits two set and one record events without source events');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"f1000000-0000-0000-0000-000000000004","role":"authenticated"}',true);
select is((select count(*)::int from public.term_grade_records),1,'student sees only own current published record');
select is((select count(*)::int from public.term_grade_calculation_sources),0,'student cannot read calculation provenance');
select set_config('request.jwt.claims','{"sub":"f1000000-0000-0000-0000-000000000005","role":"authenticated"}',true);
select is((select count(*)::int from public.term_grade_records),1,'guardian sees only linked current published record');
select is((select count(*)::int from public.term_grade_calculation_sources),0,'guardian cannot read calculation provenance');
select set_config('request.jwt.claims','{"sub":"f1000000-0000-0000-0000-000000000003","role":"authenticated"}',true);
select ok((select count(*) from public.term_grade_records)>0,'assistant has contextual read access');
select throws_ok($$select * from public.calculate_term_grades((select id from term_ids where kind='config_revision'))$$,'42501','term grade management authority required','assistant remains unable to manage');
select set_config('request.jwt.claims','{"sub":"f1000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.update_subject('f8300000-0000-0000-0000-000000000001','MATH','Mathematics',null,'inactive',true)$$,'22023','subject has live term-grade configuration or drafts','parent subject lifecycle cannot invalidate live configuration');
select throws_ok($$select public.archive_section('f8400000-0000-0000-0000-000000000001')$$,'22023',null,'parent section lifecycle cannot invalidate live term-grade history');
reset role;

select throws_ok($$update public.term_grade_calculation_sources set student_id=gen_random_uuid() where id=(select id from public.term_grade_calculation_sources limit 1)$$,'23503',null,'source cannot drift from its exact calculation student');
select throws_ok($$update public.term_grade_calculation_sources set assessment_root_id=(select id from public.assessments where id<>assessment_root_id limit 1) where id=(select id from public.term_grade_calculation_sources limit 1)$$,'23514','assessment root/version provenance mismatch','source cannot falsify its correction root');
select throws_ok($$update public.term_grade_calculations set calculation_sequence=calculation_sequence+20 where id=(select id from public.term_grade_calculations limit 1)$$,'23503',null,'calculation cannot drift from its exact set/record/student/sequence identity');

select * from finish();
delete from public.event_outbox where organization_id='f2000000-0000-0000-0000-000000000001';
delete from public.audit_log where organization_id='f2000000-0000-0000-0000-000000000001';
delete from public.term_grade_calculation_sources where organization_id='f2000000-0000-0000-0000-000000000001';
delete from public.term_grade_calculations where organization_id='f2000000-0000-0000-0000-000000000001';
delete from public.term_grade_records where organization_id='f2000000-0000-0000-0000-000000000001';
delete from public.term_grade_sets where organization_id='f2000000-0000-0000-0000-000000000001';
delete from public.term_grading_configurations where organization_id='f2000000-0000-0000-0000-000000000001';
delete from public.grade_scale_bands where organization_id='f2000000-0000-0000-0000-000000000001';
delete from public.grade_scales where organization_id='f2000000-0000-0000-0000-000000000001';
delete from public.assessment_results where organization_id='f2000000-0000-0000-0000-000000000001';
delete from public.assessment_students where organization_id='f2000000-0000-0000-0000-000000000001';
delete from public.assessments where organization_id='f2000000-0000-0000-0000-000000000001';
delete from public.teaching_assignments where organization_id='f2000000-0000-0000-0000-000000000001';
delete from public.student_section_placements where organization_id='f2000000-0000-0000-0000-000000000001';
delete from public.student_enrollments where organization_id='f2000000-0000-0000-0000-000000000001';
delete from public.student_guardians where organization_id='f2000000-0000-0000-0000-000000000001';
delete from public.guardians where organization_id='f2000000-0000-0000-0000-000000000001';
delete from public.students where organization_id='f2000000-0000-0000-0000-000000000001';
delete from public.sections where organization_id='f2000000-0000-0000-0000-000000000001';
delete from public.subjects where organization_id='f2000000-0000-0000-0000-000000000001';
delete from public.grade_levels where organization_id='f2000000-0000-0000-0000-000000000001';
delete from public.academic_terms where organization_id='f2000000-0000-0000-0000-000000000001';
delete from public.academic_years where organization_id='f2000000-0000-0000-0000-000000000001';
delete from public.staff_profiles where organization_id='f2000000-0000-0000-0000-000000000001';
delete from public.role_assignments where organization_id='f2000000-0000-0000-0000-000000000001';
delete from public.role_permissions where organization_id='f2000000-0000-0000-0000-000000000001';
delete from public.roles where organization_id='f2000000-0000-0000-0000-000000000001';
delete from public.organization_memberships where organization_id='f2000000-0000-0000-0000-000000000001';
delete from public.campuses where organization_id='f2000000-0000-0000-0000-000000000001';
delete from public.schools where organization_id='f2000000-0000-0000-0000-000000000001';
delete from public.organizations where id='f2000000-0000-0000-0000-000000000001';
delete from auth.users where id::text like 'f1000000-0000-0000-0000-00000000000%';
commit;
