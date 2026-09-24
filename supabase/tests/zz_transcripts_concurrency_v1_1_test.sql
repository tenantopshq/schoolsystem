begin;
create extension if not exists pgtap with schema extensions;
create extension if not exists dblink with schema extensions;
select no_plan();

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,created_at,updated_at) values
 ('f1100000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','race-reviewer@test','',now(),now()),
 ('f1100000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','race-issuer1@test','',now(),now()),
 ('f1100000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000000','authenticated','authenticated','race-issuer2@test','',now(),now());
insert into public.organizations(id,name,slug) values('f1200000-0000-0000-0000-000000000001','Transcript Race Tenant','transcript-race-tenant');
insert into public.schools(id,organization_id,name,code) values('f1300000-0000-0000-0000-000000000001','f1200000-0000-0000-0000-000000000001','Transcript Race School','TRR');
insert into public.campuses(id,organization_id,school_id,name,code) values('f1400000-0000-0000-0000-000000000001','f1200000-0000-0000-0000-000000000001','f1300000-0000-0000-0000-000000000001','Main Campus','MAIN');
insert into public.organization_memberships(id,organization_id,user_id,status,joined_at) values
 ('f1500000-0000-0000-0000-000000000001','f1200000-0000-0000-0000-000000000001','f1100000-0000-0000-0000-000000000001','active',now()),
 ('f1500000-0000-0000-0000-000000000002','f1200000-0000-0000-0000-000000000001','f1100000-0000-0000-0000-000000000002','active',now()),
 ('f1500000-0000-0000-0000-000000000003','f1200000-0000-0000-0000-000000000001','f1100000-0000-0000-0000-000000000003','active',now());
insert into public.roles(id,organization_id,code,name) values('f1600000-0000-0000-0000-000000000001','f1200000-0000-0000-0000-000000000001','TRANSCRIPT_RACE','Transcript Race');
insert into public.role_permissions(organization_id,role_id,permission_id) select 'f1200000-0000-0000-0000-000000000001','f1600000-0000-0000-0000-000000000001',id from public.permissions where code in('transcripts.manage','transcripts.correct');
insert into public.role_assignments(organization_id,organization_membership_id,role_id,school_id) values
 ('f1200000-0000-0000-0000-000000000001','f1500000-0000-0000-0000-000000000001','f1600000-0000-0000-0000-000000000001','f1300000-0000-0000-0000-000000000001'),
 ('f1200000-0000-0000-0000-000000000001','f1500000-0000-0000-0000-000000000002','f1600000-0000-0000-0000-000000000001','f1300000-0000-0000-0000-000000000001'),
 ('f1200000-0000-0000-0000-000000000001','f1500000-0000-0000-0000-000000000003','f1600000-0000-0000-0000-000000000001','f1300000-0000-0000-0000-000000000001');
insert into public.students(id,organization_id,school_id,campus_id,student_number,first_name,last_name,date_of_birth,status) values('f1700000-0000-0000-0000-000000000001','f1200000-0000-0000-0000-000000000001','f1300000-0000-0000-0000-000000000001','f1400000-0000-0000-0000-000000000001','RACE-1','Race','Student','2018-01-01','active');
insert into public.transcript_lineages(id,organization_id,school_id,student_id,created_by) values('f1800000-0000-0000-0000-000000000001','f1200000-0000-0000-0000-000000000001','f1300000-0000-0000-0000-000000000001','f1700000-0000-0000-0000-000000000001','f1100000-0000-0000-0000-000000000001');
insert into public.transcripts(id,organization_id,school_id,student_id,transcript_lineage_id,version,status,source_fingerprint,reviewed_at,reviewed_by,review_reason,school_code,school_name,student_number,student_display_name,created_by,updated_by)
values('f1800000-0000-0000-0000-000000000001','f1200000-0000-0000-0000-000000000001','f1300000-0000-0000-0000-000000000001','f1700000-0000-0000-0000-000000000001','f1800000-0000-0000-0000-000000000001',1,'reviewed',extensions.digest('|policy:none','sha256'),now(),'f1100000-0000-0000-0000-000000000001','race reviewed','TRR','Transcript Race School','RACE-1','Race Student','f1100000-0000-0000-0000-000000000001','f1100000-0000-0000-0000-000000000001');

-- A complete eligible academic source used by the command-level races below.
insert into auth.users(id,instance_id,aud,role,email,encrypted_password,created_at,updated_at) values
 ('e1100000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','race-create-admin@test','',now(),now());
insert into public.organizations(id,name,slug) values('e1200000-0000-0000-0000-000000000001','Transcript Tenant','transcript-race-create-tenant');
insert into public.schools(id,organization_id,name,code) values('e1300000-0000-0000-0000-000000000001','e1200000-0000-0000-0000-000000000001','Transcript School','TRS');
insert into public.organization_memberships(id,organization_id,user_id,status,joined_at) values('e1400000-0000-0000-0000-000000000001','e1200000-0000-0000-0000-000000000001','e1100000-0000-0000-0000-000000000001','active',now());
insert into public.roles(id,organization_id,code,name) values('e1500000-0000-0000-0000-000000000001','e1200000-0000-0000-0000-000000000001','TRANSCRIPT_ADMIN','Transcript Admin');
insert into public.role_permissions(organization_id,role_id,permission_id) select 'e1200000-0000-0000-0000-000000000001','e1500000-0000-0000-0000-000000000001',id from public.permissions where code in('transcripts.view','transcripts.manage','transcripts.correct','report_cards.manage','report_cards.correct');
insert into public.role_assignments(organization_id,organization_membership_id,role_id,school_id) values('e1200000-0000-0000-0000-000000000001','e1400000-0000-0000-0000-000000000001','e1500000-0000-0000-0000-000000000001','e1300000-0000-0000-0000-000000000001');
insert into public.subjects(id,organization_id,school_id,code,name,status) values('e1600000-0000-0000-0000-000000000001','e1200000-0000-0000-0000-000000000001','e1300000-0000-0000-0000-000000000001','MATH','Mathematics','active');
insert into auth.users(id,instance_id,aud,role,email,encrypted_password,created_at,updated_at) values('e1100000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','race-create-issuer@test','',now(),now());
insert into auth.users(id,instance_id,aud,role,email,encrypted_password,created_at,updated_at) values
 ('e1100000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000000','authenticated','authenticated','race-create-student@test','',now(),now()),
 ('e1100000-0000-0000-0000-000000000004','00000000-0000-0000-0000-000000000000','authenticated','authenticated','race-create-guardian@test','',now(),now()),
 ('e1100000-0000-0000-0000-000000000005','00000000-0000-0000-0000-000000000000','authenticated','authenticated','race-create-teacher@test','',now(),now());
insert into public.organization_memberships(id,organization_id,user_id,status,joined_at) values('e1400000-0000-0000-0000-000000000002','e1200000-0000-0000-0000-000000000001','e1100000-0000-0000-0000-000000000002','active',now());
insert into public.role_assignments(organization_id,organization_membership_id,role_id,school_id) values('e1200000-0000-0000-0000-000000000001','e1400000-0000-0000-0000-000000000002','e1500000-0000-0000-0000-000000000001','e1300000-0000-0000-0000-000000000001');
insert into public.campuses(id,organization_id,school_id,name,code) values('e1700000-0000-0000-0000-000000000001','e1200000-0000-0000-0000-000000000001','e1300000-0000-0000-0000-000000000001','Main Campus','MAIN');
insert into public.academic_years(id,organization_id,school_id,name,start_date,end_date,status) values('e1800000-0000-0000-0000-000000000001','e1200000-0000-0000-0000-000000000001','e1300000-0000-0000-0000-000000000001','2026-27','2026-01-01','2026-12-31','active');
insert into public.academic_terms(id,organization_id,academic_year_id,name,sequence,start_date,end_date,status) values
 ('e1900000-0000-0000-0000-000000000001','e1200000-0000-0000-0000-000000000001','e1800000-0000-0000-0000-000000000001','Term 1',1,'2026-01-01','2026-06-30','active'),
 ('e1900000-0000-0000-0000-000000000002','e1200000-0000-0000-0000-000000000001','e1800000-0000-0000-0000-000000000001','Term 2',2,'2026-07-01','2026-12-31','active');
insert into public.grade_levels(id,organization_id,school_id,code,name,sequence,status) values('e1a00000-0000-0000-0000-000000000001','e1200000-0000-0000-0000-000000000001','e1300000-0000-0000-0000-000000000001','G1','Grade 1',1,'active');
insert into public.sections(id,organization_id,school_id,campus_id,academic_year_id,academic_term_id,grade_level_id,code,name,capacity,start_date,end_date,status) values('e1b00000-0000-0000-0000-000000000001','e1200000-0000-0000-0000-000000000001','e1300000-0000-0000-0000-000000000001','e1700000-0000-0000-0000-000000000001','e1800000-0000-0000-0000-000000000001','e1900000-0000-0000-0000-000000000001','e1a00000-0000-0000-0000-000000000001','1A','Grade 1 A',30,'2026-01-01','2026-12-31','active');
insert into public.students(id,organization_id,school_id,campus_id,user_id,student_number,first_name,last_name,date_of_birth,status) values('e1c00000-0000-0000-0000-000000000001','e1200000-0000-0000-0000-000000000001','e1300000-0000-0000-0000-000000000001','e1700000-0000-0000-0000-000000000001','e1100000-0000-0000-0000-000000000003','S1','Transcript','Student','2018-01-01','active');
insert into public.student_enrollments(id,organization_id,school_id,academic_year_id,student_id,grade_level_id,enrolled_on,scheduled_end_on,enrollment_range,status,created_by,updated_by) values('e1d00000-0000-0000-0000-000000000001','e1200000-0000-0000-0000-000000000001','e1300000-0000-0000-0000-000000000001','e1800000-0000-0000-0000-000000000001','e1c00000-0000-0000-0000-000000000001','e1a00000-0000-0000-0000-000000000001','2026-01-01','2026-12-31',daterange('2026-01-01','2026-12-31','[]'),'active','e1100000-0000-0000-0000-000000000001','e1100000-0000-0000-0000-000000000001');
insert into public.student_section_placements(id,organization_id,school_id,campus_id,academic_year_id,student_enrollment_id,student_id,section_id,starts_on,status,created_by,updated_by) values('e1e00000-0000-0000-0000-000000000001','e1200000-0000-0000-0000-000000000001','e1300000-0000-0000-0000-000000000001','e1700000-0000-0000-0000-000000000001','e1800000-0000-0000-0000-000000000001','e1d00000-0000-0000-0000-000000000001','e1c00000-0000-0000-0000-000000000001','e1b00000-0000-0000-0000-000000000001','2026-01-01','active','e1100000-0000-0000-0000-000000000001','e1100000-0000-0000-0000-000000000001');
insert into public.grade_scales(id,organization_id,school_id,academic_year_id,name,status,activated_at,activated_by,created_by,updated_by) values('e1f00000-0000-0000-0000-000000000001','e1200000-0000-0000-0000-000000000001','e1300000-0000-0000-0000-000000000001','e1800000-0000-0000-0000-000000000001','Scale','active',now(),'e1100000-0000-0000-0000-000000000001','e1100000-0000-0000-0000-000000000001','e1100000-0000-0000-0000-000000000001');
insert into public.grade_scale_bands(id,organization_id,school_id,grade_scale_id,sequence,lower_units,upper_units,label,result_state,created_by) values('e2000000-0000-0000-0000-000000000001','e1200000-0000-0000-0000-000000000001','e1300000-0000-0000-0000-000000000001','e1f00000-0000-0000-0000-000000000001',1,0,1000000,'Pass','pass','e1100000-0000-0000-0000-000000000001');
insert into public.term_grading_configurations(id,organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,subject_id,grade_scale_id,status,activated_at,activated_by,created_by,updated_by) values('e2100000-0000-0000-0000-000000000001','e1200000-0000-0000-0000-000000000001','e1300000-0000-0000-0000-000000000001','e1700000-0000-0000-0000-000000000001','e1800000-0000-0000-0000-000000000001','e1900000-0000-0000-0000-000000000001','e1b00000-0000-0000-0000-000000000001','e1600000-0000-0000-0000-000000000001','e1f00000-0000-0000-0000-000000000001','active',now(),'e1100000-0000-0000-0000-000000000001','e1100000-0000-0000-0000-000000000001','e1100000-0000-0000-0000-000000000001');
insert into public.term_grade_sets(id,organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,subject_id,term_grading_configuration_id,lifecycle_status,publication_state,calculation_sequence,source_fingerprint,finalized_at,finalized_by,published_at,published_by,created_by,updated_by) values('e2200000-0000-0000-0000-000000000001','e1200000-0000-0000-0000-000000000001','e1300000-0000-0000-0000-000000000001','e1700000-0000-0000-0000-000000000001','e1800000-0000-0000-0000-000000000001','e1900000-0000-0000-0000-000000000001','e1b00000-0000-0000-0000-000000000001','e1600000-0000-0000-0000-000000000001','e2100000-0000-0000-0000-000000000001','finalized','published',1,extensions.digest('set','sha256'),now(),'e1100000-0000-0000-0000-000000000001',now(),'e1100000-0000-0000-0000-000000000001','e1100000-0000-0000-0000-000000000001','e1100000-0000-0000-0000-000000000001');
insert into public.term_grade_records(id,organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,subject_id,term_grading_configuration_id,term_grade_set_id,student_id,calculation_sequence,created_by) values('e2300000-0000-0000-0000-000000000001','e1200000-0000-0000-0000-000000000001','e1300000-0000-0000-0000-000000000001','e1700000-0000-0000-0000-000000000001','e1800000-0000-0000-0000-000000000001','e1900000-0000-0000-0000-000000000001','e1b00000-0000-0000-0000-000000000001','e1600000-0000-0000-0000-000000000001','e2100000-0000-0000-0000-000000000001','e2200000-0000-0000-0000-000000000001','e1c00000-0000-0000-0000-000000000001',1,'e1100000-0000-0000-0000-000000000001');
insert into public.term_grade_calculations(id,organization_id,term_grade_set_id,term_grade_record_id,student_id,calculation_sequence,raw_percentage,rounded_percentage,grade_scale_id,grade_scale_band_id,grade_label,result_state,contributing_assessment_count,weight_total,calculated_by) values('e2400000-0000-0000-0000-000000000001','e1200000-0000-0000-0000-000000000001','e2200000-0000-0000-0000-000000000001','e2300000-0000-0000-0000-000000000001','e1c00000-0000-0000-0000-000000000001',1,88,88,'e1f00000-0000-0000-0000-000000000001','e2000000-0000-0000-0000-000000000001','Pass','pass',1,100,'e1100000-0000-0000-0000-000000000001');
insert into public.report_cards(id,organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,student_id,student_enrollment_id,student_section_placement_id,lineage_id,version,report_card_number,status,finalized_at,finalized_by,published_at,published_by,source_fingerprint,school_code,school_name,campus_code,campus_name,academic_year_name,academic_term_name,academic_term_sequence,term_start_date,term_end_date,section_code,section_name,grade_level_code,grade_level_name,student_number,student_display_name,created_by,updated_by) values('e2500000-0000-0000-0000-000000000001','e1200000-0000-0000-0000-000000000001','e1300000-0000-0000-0000-000000000001','e1700000-0000-0000-0000-000000000001','e1800000-0000-0000-0000-000000000001','e1900000-0000-0000-0000-000000000001','e1b00000-0000-0000-0000-000000000001','e1c00000-0000-0000-0000-000000000001','e1d00000-0000-0000-0000-000000000001','e1e00000-0000-0000-0000-000000000001','e2500000-0000-0000-0000-000000000001',1,1,'published',now(),'e1100000-0000-0000-0000-000000000001',now(),'e1100000-0000-0000-0000-000000000001',extensions.digest('card','sha256'),'TRS','Transcript School','MAIN','Main Campus','2026-27','Term 1',1,'2026-01-01','2026-12-31','1A','Grade 1 A','G1','Grade 1','S1','Transcript Student','e1100000-0000-0000-0000-000000000001','e1100000-0000-0000-0000-000000000001');
insert into public.report_card_grade_snapshots(id,organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,report_card_id,student_id,subject_id,subject_code,subject_name,term_grading_configuration_id,term_grade_set_id,term_grade_record_id,term_grade_calculation_id,grade_scale_id,grade_scale_band_id,term_grade_calculation_sequence,raw_percentage,rounded_percentage,grade_label,result_state,contributing_assessment_count,weight_total,source_term_grade_fingerprint,created_by) values('e2600000-0000-0000-0000-000000000001','e1200000-0000-0000-0000-000000000001','e1300000-0000-0000-0000-000000000001','e1700000-0000-0000-0000-000000000001','e1800000-0000-0000-0000-000000000001','e1900000-0000-0000-0000-000000000001','e1b00000-0000-0000-0000-000000000001','e2500000-0000-0000-0000-000000000001','e1c00000-0000-0000-0000-000000000001','e1600000-0000-0000-0000-000000000001','MATH','Mathematics','e2100000-0000-0000-0000-000000000001','e2200000-0000-0000-0000-000000000001','e2300000-0000-0000-0000-000000000001','e2400000-0000-0000-0000-000000000001','e1f00000-0000-0000-0000-000000000001','e2000000-0000-0000-0000-000000000001',1,88,88,'Pass','pass',1,100,extensions.digest('grade','sha256'),'e1100000-0000-0000-0000-000000000001');

-- Synthetic reviewed aggregates isolate school-scoped numbering behavior. They
-- deliberately contain no periods, so readiness fingerprints are deterministic.
insert into public.schools(id,organization_id,name,code) values
 ('a1300000-0000-0000-0000-000000000001','f1200000-0000-0000-0000-000000000001','Number School A','NSA'),
 ('b1300000-0000-0000-0000-000000000001','f1200000-0000-0000-0000-000000000001','Number School B','NSB'),
 ('c1300000-0000-0000-0000-000000000001','f1200000-0000-0000-0000-000000000001','Policy Race School','PRS');
insert into public.campuses(id,organization_id,school_id,name,code) values
 ('a1400000-0000-0000-0000-000000000001','f1200000-0000-0000-0000-000000000001','a1300000-0000-0000-0000-000000000001','A Campus','A'),
 ('b1400000-0000-0000-0000-000000000001','f1200000-0000-0000-0000-000000000001','b1300000-0000-0000-0000-000000000001','B Campus','B'),
 ('c1400000-0000-0000-0000-000000000001','f1200000-0000-0000-0000-000000000001','c1300000-0000-0000-0000-000000000001','Policy Campus','P');
insert into public.role_assignments(organization_id,organization_membership_id,role_id,school_id) select 'f1200000-0000-0000-0000-000000000001',m,'f1600000-0000-0000-0000-000000000001',s from unnest(array['f1500000-0000-0000-0000-000000000001'::uuid,'f1500000-0000-0000-0000-000000000002','f1500000-0000-0000-0000-000000000003'])m cross join unnest(array['a1300000-0000-0000-0000-000000000001'::uuid,'b1300000-0000-0000-0000-000000000001','c1300000-0000-0000-0000-000000000001'])s;
insert into public.students(id,organization_id,school_id,campus_id,student_number,first_name,last_name,date_of_birth,status) values
 ('a1700000-0000-0000-0000-000000000001','f1200000-0000-0000-0000-000000000001','a1300000-0000-0000-0000-000000000001','a1400000-0000-0000-0000-000000000001','A-1','A','One','2018-01-01','active'),
 ('a1700000-0000-0000-0000-000000000002','f1200000-0000-0000-0000-000000000001','a1300000-0000-0000-0000-000000000001','a1400000-0000-0000-0000-000000000001','A-2','A','Two','2018-01-02','active'),
 ('a1700000-0000-0000-0000-000000000003','f1200000-0000-0000-0000-000000000001','a1300000-0000-0000-0000-000000000001','a1400000-0000-0000-0000-000000000001','A-3','A','Three','2018-01-03','active'),
 ('b1700000-0000-0000-0000-000000000001','f1200000-0000-0000-0000-000000000001','b1300000-0000-0000-0000-000000000001','b1400000-0000-0000-0000-000000000001','B-1','B','One','2018-02-01','active'),
 ('b1700000-0000-0000-0000-000000000002','f1200000-0000-0000-0000-000000000001','b1300000-0000-0000-0000-000000000001','b1400000-0000-0000-0000-000000000001','B-2','B','Two','2018-02-02','active'),
 ('c1700000-0000-0000-0000-000000000001','f1200000-0000-0000-0000-000000000001','c1300000-0000-0000-0000-000000000001','c1400000-0000-0000-0000-000000000001','P-1','Policy','One','2018-03-01','active'),
 ('c1700000-0000-0000-0000-000000000002','f1200000-0000-0000-0000-000000000001','c1300000-0000-0000-0000-000000000001','c1400000-0000-0000-0000-000000000001','P-2','Policy','Two','2018-03-02','active');
insert into public.transcript_lineages(id,organization_id,school_id,student_id,created_by) select id,'f1200000-0000-0000-0000-000000000001',school_id,student_id,'f1100000-0000-0000-0000-000000000001' from(values
 ('a1800000-0000-0000-0000-000000000001'::uuid,'a1300000-0000-0000-0000-000000000001'::uuid,'a1700000-0000-0000-0000-000000000001'::uuid),
 ('a1800000-0000-0000-0000-000000000002','a1300000-0000-0000-0000-000000000001','a1700000-0000-0000-0000-000000000002'),
 ('a1800000-0000-0000-0000-000000000003','a1300000-0000-0000-0000-000000000001','a1700000-0000-0000-0000-000000000003'),
 ('b1800000-0000-0000-0000-000000000001','b1300000-0000-0000-0000-000000000001','b1700000-0000-0000-0000-000000000001'),
 ('b1800000-0000-0000-0000-000000000002','b1300000-0000-0000-0000-000000000001','b1700000-0000-0000-0000-000000000002'),
 ('c1800000-0000-0000-0000-000000000001','c1300000-0000-0000-0000-000000000001','c1700000-0000-0000-0000-000000000001'),
 ('c1800000-0000-0000-0000-000000000002','c1300000-0000-0000-0000-000000000001','c1700000-0000-0000-0000-000000000002'))v(id,school_id,student_id);
insert into public.transcripts(id,organization_id,school_id,student_id,transcript_lineage_id,version,status,source_fingerprint,reviewed_at,reviewed_by,review_reason,school_code,school_name,student_number,student_display_name,created_by,updated_by) select l.id,l.organization_id,l.school_id,l.student_id,l.id,1,'reviewed',extensions.digest('|policy:none','sha256'),now(),'f1100000-0000-0000-0000-000000000001','number race review',s.code,s.name,st.student_number,st.first_name||' '||st.last_name,'f1100000-0000-0000-0000-000000000001','f1100000-0000-0000-0000-000000000001' from public.transcript_lineages l join public.schools s on s.id=l.school_id join public.students st on st.id=l.student_id where l.school_id in('a1300000-0000-0000-0000-000000000001','b1300000-0000-0000-0000-000000000001');
insert into public.transcript_calculation_policies(id,organization_id,school_id,policy_lineage_id,version,name,status,gpa_scale,decimal_places,include_fail_in_gpa,include_incomplete_in_gpa,include_withdrawn_in_gpa,created_by,updated_by) values('c1900000-0000-0000-0000-000000000001','f1200000-0000-0000-0000-000000000001','c1300000-0000-0000-0000-000000000001','c1900000-0000-0000-0000-000000000001',1,'Policy Race','draft',4,2,true,false,false,'f1100000-0000-0000-0000-000000000001','f1100000-0000-0000-0000-000000000001');
insert into public.transcript_gpa_bands(organization_id,school_id,transcript_calculation_policy_id,sequence,lower_bound,upper_bound,result_state,grade_points,created_by) values('f1200000-0000-0000-0000-000000000001','c1300000-0000-0000-0000-000000000001','c1900000-0000-0000-0000-000000000001',1,0,100,'pass',4,'f1100000-0000-0000-0000-000000000001');
update public.transcript_calculation_policies set status='active',activated_at=now(),activated_by='f1100000-0000-0000-0000-000000000001' where id='c1900000-0000-0000-0000-000000000001';
insert into public.transcripts(id,organization_id,school_id,student_id,transcript_lineage_id,version,status,transcript_calculation_policy_id,policy_lineage_id,policy_version,policy_name,gpa_scale,gpa_decimal_places,attempted_credits,earned_credits,cumulative_gpa,gpa_quality_points,source_fingerprint,reviewed_at,reviewed_by,review_reason,school_code,school_name,student_number,student_display_name,created_by,updated_by) values('c1800000-0000-0000-0000-000000000001','f1200000-0000-0000-0000-000000000001','c1300000-0000-0000-0000-000000000001','c1700000-0000-0000-0000-000000000001','c1800000-0000-0000-0000-000000000001',1,'reviewed','c1900000-0000-0000-0000-000000000001','c1900000-0000-0000-0000-000000000001',1,'Policy Race',4,2,0,0,null,0,app_auth.transcript_source_fingerprint('c1700000-0000-0000-0000-000000000001','c1300000-0000-0000-0000-000000000001','{}','{}','c1900000-0000-0000-0000-000000000001'),now(),'f1100000-0000-0000-0000-000000000001','policy race review','PRS','Policy Race School','P-1','Policy Student','f1100000-0000-0000-0000-000000000001','f1100000-0000-0000-0000-000000000001');
insert into public.transcripts(id,organization_id,school_id,student_id,transcript_lineage_id,version,status,transcript_calculation_policy_id,policy_lineage_id,policy_version,policy_name,gpa_scale,gpa_decimal_places,attempted_credits,earned_credits,cumulative_gpa,gpa_quality_points,source_fingerprint,reviewed_at,reviewed_by,review_reason,school_code,school_name,student_number,student_display_name,created_by,updated_by) values('c1800000-0000-0000-0000-000000000002','f1200000-0000-0000-0000-000000000001','c1300000-0000-0000-0000-000000000001','c1700000-0000-0000-0000-000000000002','c1800000-0000-0000-0000-000000000002',1,'reviewed','c1900000-0000-0000-0000-000000000001','c1900000-0000-0000-0000-000000000001',1,'Policy Race',4,2,0,0,null,0,app_auth.transcript_source_fingerprint('c1700000-0000-0000-0000-000000000002','c1300000-0000-0000-0000-000000000001','{}','{}','c1900000-0000-0000-0000-000000000001'),now(),'f1100000-0000-0000-0000-000000000001','policy race review','PRS','Policy Race School','P-2','Policy Two','f1100000-0000-0000-0000-000000000001','f1100000-0000-0000-0000-000000000001');

create function app_auth.test_capture_transcript_sql(p_actor uuid,p_sql text) returns text language plpgsql security definer set search_path='' as $$
begin perform pg_catalog.set_config('request.jwt.claims',jsonb_build_object('sub',p_actor,'role','authenticated')::text,true); execute p_sql; return '00000'; exception when others then return sqlstate; end $$;
revoke all on function app_auth.test_capture_transcript_sql(uuid,text) from public,anon,authenticated,service_role;
commit;

-- These are genuine independent sessions. They prove that the shared academic
-- snapshot mutex serializes transcript/report-card source writers and that the
-- school counter uses row-level serialization. End-to-end lineage races are covered
-- by the foundation fixture once eligible published report cards are present.
select extensions.dblink_connect('tr_block','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');
select extensions.dblink_connect('tr_one','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');
select extensions.dblink_connect('tr_two','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');

-- Different schools maintain independent counters: concurrent first issues both
-- receive school-local number 1.
select is(extensions.dblink_send_query('tr_one',format('select app_auth.test_capture_transcript_sql(%L,%L)','f1100000-0000-0000-0000-000000000002','select public.issue_transcript(''a1800000-0000-0000-0000-000000000001'',''different-school A'')')),1,'different-school A issue dispatched');
select is(extensions.dblink_send_query('tr_two',format('select app_auth.test_capture_transcript_sql(%L,%L)','f1100000-0000-0000-0000-000000000003','select public.issue_transcript(''b1800000-0000-0000-0000-000000000001'',''different-school B'')')),1,'different-school B issue dispatched');
select lives_ok($$select pg_sleep(0.2)$$,'different-school issues overlap in independent sessions');
create temp table transcript_number_race(status text);
insert into transcript_number_race select status from extensions.dblink_get_result('tr_one')as t(status text);
insert into transcript_number_race select status from extensions.dblink_get_result('tr_two')as t(status text);
select is((select array_agg(status order by status)::text from transcript_number_race),'{00000,00000}','different-school issue commands both succeed');
select is((select array_agg(transcript_number order by school_id)::text from public.transcripts where id in('a1800000-0000-0000-0000-000000000001','b1800000-0000-0000-0000-000000000001')),'{1,1}','different schools independently allocate number one');
select extensions.dblink_disconnect('tr_one'); select extensions.dblink_disconnect('tr_two');
select extensions.dblink_connect('tr_one','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');
select extensions.dblink_connect('tr_two','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');

-- Two distinct lineages in the same school serialize through one counter row and
-- receive unique consecutive values without a retryable failure.
select is(extensions.dblink_send_query('tr_one',format('select app_auth.test_capture_transcript_sql(%L,%L)','f1100000-0000-0000-0000-000000000002','select public.issue_transcript(''a1800000-0000-0000-0000-000000000002'',''same-school issue two'')')),1,'same-school issue two dispatched');
select is(extensions.dblink_send_query('tr_two',format('select app_auth.test_capture_transcript_sql(%L,%L)','f1100000-0000-0000-0000-000000000003','select public.issue_transcript(''a1800000-0000-0000-0000-000000000003'',''same-school issue three'')')),1,'same-school issue three dispatched');
select lives_ok($$select pg_sleep(0.2)$$,'same-school numbering commands overlap');
truncate transcript_number_race;
insert into transcript_number_race select status from extensions.dblink_get_result('tr_one')as t(status text);
insert into transcript_number_race select status from extensions.dblink_get_result('tr_two')as t(status text);
select is((select array_agg(status order by status)::text from transcript_number_race),'{00000,00000}','same-school distinct-lineage issues both succeed');
select is((select array_agg(transcript_number order by transcript_number)::text from public.transcripts where id in('a1800000-0000-0000-0000-000000000002','a1800000-0000-0000-0000-000000000003')),'{2,3}','same-school counter allocates unique consecutive numbers');
select is((select next_number from public.transcript_number_counters where school_id='a1300000-0000-0000-0000-000000000001'),4::bigint,'same-school counter advances exactly once per issue');
select extensions.dblink_disconnect('tr_one'); select extensions.dblink_disconnect('tr_two');
select extensions.dblink_connect('tr_one','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');
select extensions.dblink_connect('tr_two','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');

-- A revision appends a draft policy without changing the active version, so an
-- issue racing that revision remains valid and both commands commit.
select is(extensions.dblink_send_query('tr_one',format('select app_auth.test_capture_transcript_sql(%L,%L)','f1100000-0000-0000-0000-000000000002','select public.issue_transcript(''c1800000-0000-0000-0000-000000000001'',''policy revision race issue'')')),1,'policy-revision issue dispatched');
select is(extensions.dblink_send_query('tr_two',format('select app_auth.test_capture_transcript_sql(%L,%L)','f1100000-0000-0000-0000-000000000003','select public.revise_transcript_calculation_policy(''c1900000-0000-0000-0000-000000000001'',''Policy Revision'',4::numeric,2::smallint,true,false,false,array[row(1,0,100,''pass'',4)::public.transcript_gpa_band_input],''{}''::public.transcript_subject_credit_input[])')),1,'policy revision dispatched');
select lives_ok($$select pg_sleep(0.2)$$,'issue and policy revision overlap');
create temp table transcript_policy_race(side text,status text);
insert into transcript_policy_race select 'issue',status from extensions.dblink_get_result('tr_one')as t(status text);
insert into transcript_policy_race select 'revise',status from extensions.dblink_get_result('tr_two')as t(status text);
select is((select array_agg(status order by status)::text from transcript_policy_race),'{00000,00000}','issue and immutable policy revision both succeed coherently');
select is((select status::text from public.transcripts where id='c1800000-0000-0000-0000-000000000001'),'issued','revision race issues against the still-active snapshotted policy');
select extensions.dblink_disconnect('tr_one'); select extensions.dblink_disconnect('tr_two');
select extensions.dblink_connect('tr_one','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');
select extensions.dblink_connect('tr_two','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');

-- Retirement changes readiness. The racing issue either commits first or rolls
-- back completely with retryable 40001 after retirement wins.
select is(extensions.dblink_send_query('tr_one',format('select app_auth.test_capture_transcript_sql(%L,%L)','f1100000-0000-0000-0000-000000000002','select public.issue_transcript(''c1800000-0000-0000-0000-000000000002'',''policy retirement race issue'')')),1,'policy-retirement issue dispatched');
select is(extensions.dblink_send_query('tr_two',format('select app_auth.test_capture_transcript_sql(%L,%L)','f1100000-0000-0000-0000-000000000003','select public.retire_transcript_calculation_policy(''c1900000-0000-0000-0000-000000000001'')')),1,'policy retirement dispatched');
select lives_ok($$select pg_sleep(0.2)$$,'issue and policy retirement overlap');
truncate transcript_policy_race;
insert into transcript_policy_race select 'issue',status from extensions.dblink_get_result('tr_one')as t(status text);
insert into transcript_policy_race select 'retire',status from extensions.dblink_get_result('tr_two')as t(status text);
select is((select status from transcript_policy_race where side='retire'),'00000','policy retirement succeeds');
select ok((select status in('00000','40001') from transcript_policy_race where side='issue'),'retirement-racing issue succeeds coherently or returns retryable 40001');
select ok((select (status='00000' and exists(select 1 from public.transcripts where id='c1800000-0000-0000-0000-000000000002' and status='issued' and transcript_number=2)and exists(select 1 from public.transcript_number_counters where school_id='c1300000-0000-0000-0000-000000000001' and next_number=3))or(status='40001' and exists(select 1 from public.transcripts where id='c1800000-0000-0000-0000-000000000002' and status='reviewed' and transcript_number is null)and exists(select 1 from public.transcript_number_counters where school_id='c1300000-0000-0000-0000-000000000001' and next_number=2)) from transcript_policy_race where side='issue'),'retirement race leaves complete issued state or complete numbering rollback');
select extensions.dblink_disconnect('tr_one'); select extensions.dblink_disconnect('tr_two');
select extensions.dblink_connect('tr_one','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');
select extensions.dblink_connect('tr_two','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');

-- Simultaneous root creation for the same student/school is serialized by the
-- organization snapshot mutex and lineage lock. Exactly one command commits.
select extensions.dblink_exec('tr_block','begin; do $do$begin perform app_auth.lock_academic_snapshot_domain(''e1200000-0000-0000-0000-000000000001''); end$do$');
select is(extensions.dblink_send_query('tr_one',format('select app_auth.test_capture_transcript_sql(%L,%L)','e1100000-0000-0000-0000-000000000001','select public.create_transcript(''e1c00000-0000-0000-0000-000000000001'',''e1300000-0000-0000-0000-000000000001'',array[row(''e1900000-0000-0000-0000-000000000001'')::public.transcript_term_input],''{}'')')),1,'first root creation dispatched');
select is(extensions.dblink_send_query('tr_two',format('select app_auth.test_capture_transcript_sql(%L,%L)','e1100000-0000-0000-0000-000000000001','select public.create_transcript(''e1c00000-0000-0000-0000-000000000001'',''e1300000-0000-0000-0000-000000000001'',array[row(''e1900000-0000-0000-0000-000000000001'')::public.transcript_term_input],''{}'')')),1,'second root creation dispatched');
select lives_ok($$select pg_sleep(0.2)$$,'root creation commands genuinely overlap');
select extensions.dblink_exec('tr_block','commit');
create temp table transcript_root_race(status text);
insert into transcript_root_race select status from extensions.dblink_get_result('tr_one')as t(status text);
insert into transcript_root_race select status from extensions.dblink_get_result('tr_two')as t(status text);
select is((select array_agg(status order by status)::text from transcript_root_race),'{00000,40001}','simultaneous root creation has one winner and one retryable loser');
select is((select count(*)::int from public.transcript_lineages where student_id='e1c00000-0000-0000-0000-000000000001'),1,'root race leaves one lineage');
select is((select count(*)::int from public.transcripts where student_id='e1c00000-0000-0000-0000-000000000001'),1,'root race leaves one draft');
select is((select count(*)::int from public.event_outbox where event_type='transcript.draft_created' and aggregate_id in(select id from public.transcripts where student_id='e1c00000-0000-0000-0000-000000000001')),1,'root race emits one draft event');
select is((select count(*)::int from public.audit_log a join public.event_outbox e using(command_id) where e.event_type='transcript.draft_created' and e.aggregate_id in(select id from public.transcripts where student_id='e1c00000-0000-0000-0000-000000000001')),3,'root race winner alone audits its header, period, and entry');
select extensions.dblink_disconnect('tr_one'); select extensions.dblink_disconnect('tr_two');
select extensions.dblink_connect('tr_one','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');
select extensions.dblink_connect('tr_two','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');

-- Establish an issued head, then race two rebuilds against it.
select is((select status from extensions.dblink('tr_one',format('select app_auth.test_capture_transcript_sql(%L,%L)','e1100000-0000-0000-0000-000000000001',format('select public.review_transcript(%L,%L)',(select id from public.transcripts where student_id='e1c00000-0000-0000-0000-000000000001'),'race review')))as t(status text)),'00000','root winner can be reviewed');
select is((select status from extensions.dblink('tr_one',format('select app_auth.test_capture_transcript_sql(%L,%L)','e1100000-0000-0000-0000-000000000002',format('select public.issue_transcript(%L,%L)',(select id from public.transcripts where student_id='e1c00000-0000-0000-0000-000000000001'),'race issue')))as t(status text)),'00000','root winner can be issued');
select extensions.dblink_exec('tr_block','begin; do $do$begin perform app_auth.lock_academic_snapshot_domain(''e1200000-0000-0000-0000-000000000001''); end$do$');
select is(extensions.dblink_send_query('tr_one',format('select app_auth.test_capture_transcript_sql(%L,%L)','e1100000-0000-0000-0000-000000000001',format('select public.rebuild_transcript(%L,array[row(''e1900000-0000-0000-0000-000000000001'')::public.transcript_term_input],''{}'',''race rebuild one'')',(select id from public.transcripts where student_id='e1c00000-0000-0000-0000-000000000001' and status='issued')))),1,'first rebuild dispatched');
select is(extensions.dblink_send_query('tr_two',format('select app_auth.test_capture_transcript_sql(%L,%L)','e1100000-0000-0000-0000-000000000001',format('select public.rebuild_transcript(%L,array[row(''e1900000-0000-0000-0000-000000000001'')::public.transcript_term_input],''{}'',''race rebuild two'')',(select id from public.transcripts where student_id='e1c00000-0000-0000-0000-000000000001' and status='issued')))),1,'second rebuild dispatched');
select lives_ok($$select pg_sleep(0.2)$$,'rebuild commands genuinely overlap');
select extensions.dblink_exec('tr_block','commit');
truncate transcript_root_race;
insert into transcript_root_race select status from extensions.dblink_get_result('tr_one')as t(status text);
insert into transcript_root_race select status from extensions.dblink_get_result('tr_two')as t(status text);
select is((select array_agg(status order by status)::text from transcript_root_race),'{00000,40001}','simultaneous rebuild has one winner and one retryable loser');
select is((select count(*)::int from public.transcripts where student_id='e1c00000-0000-0000-0000-000000000001' and status='draft'),1,'rebuild race leaves one candidate');
select is((select count(*)::int from public.event_outbox where event_type='transcript.rebuild_started' and aggregate_id in(select id from public.transcripts where student_id='e1c00000-0000-0000-0000-000000000001')),1,'rebuild race loser emits no event');
select is((select count(*)::int from public.audit_log a join public.event_outbox e using(command_id) where e.event_type='transcript.rebuild_started' and e.aggregate_id in(select id from public.transcripts where student_id='e1c00000-0000-0000-0000-000000000001')),3,'rebuild race winner alone audits its header, period, and entry');
select extensions.dblink_disconnect('tr_one'); select extensions.dblink_disconnect('tr_two');
select extensions.dblink_connect('tr_one','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');
select extensions.dblink_connect('tr_two','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');

-- Review races the parent correction command under the shared academic mutex.
-- Correction always succeeds; review either precedes it or returns 40001. A
-- subsequent issue can never publish the now-stale candidate.
select is(extensions.dblink_send_query('tr_one',format('select app_auth.test_capture_transcript_sql(%L,%L)','e1100000-0000-0000-0000-000000000001',format('select public.review_transcript(%L,%L)',(select id from public.transcripts where student_id='e1c00000-0000-0000-0000-000000000001' and status='draft'),'review correction race'))),1,'review/source-correction review dispatched');
select is(extensions.dblink_send_query('tr_two',format('select app_auth.test_capture_transcript_sql(%L,%L)','e1100000-0000-0000-0000-000000000002','select * from public.correct_report_card(''e2500000-0000-0000-0000-000000000001'',''source correction race'')')),1,'review/source-correction correction dispatched');
select lives_ok($$select pg_sleep(0.2)$$,'review and report-card correction overlap');
create temp table transcript_source_race(side text,status text);
insert into transcript_source_race select 'review',status from extensions.dblink_get_result('tr_one')as t(status text);
insert into transcript_source_race select 'correction',status from extensions.dblink_get_result('tr_two')as t(status text);
select is((select status from transcript_source_race where side='correction'),'00000','report-card correction wins coherently');
select ok((select status in('00000','40001') from transcript_source_race where side='review'),'review is either serialized before correction or retryably rejected');
select is((select count(*)::int from public.event_outbox where event_type='transcript.reviewed' and aggregate_id=(select id from public.transcripts where student_id='e1c00000-0000-0000-0000-000000000001' order by version desc limit 1)),case when(select status from transcript_source_race where side='review')='00000' then 1 else 0 end,'review/correction race emits exactly the aggregate-scoped winning review effect');
select is((select count(*)::int from public.audit_log a join public.event_outbox e using(command_id) where e.event_type='transcript.reviewed' and e.aggregate_id=(select id from public.transcripts where student_id='e1c00000-0000-0000-0000-000000000001' order by version desc limit 1) and a.action='transcript.reviewed'),case when(select status from transcript_source_race where side='review')='00000' then 1 else 0 end,'review/correction race audit is scoped to the event command and aggregate');
select extensions.dblink_disconnect('tr_one'); select extensions.dblink_disconnect('tr_two');
select extensions.dblink_connect('tr_one','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');
select extensions.dblink_connect('tr_two','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');
select is((select status from extensions.dblink('tr_one',format('select app_auth.test_capture_transcript_sql(%L,%L)','e1100000-0000-0000-0000-000000000002',format('select public.issue_transcript(%L,%L)',(select id from public.transcripts where student_id='e1c00000-0000-0000-0000-000000000001' and status in('draft','reviewed')),'stale issue')))as t(status text)),'40001','issue after the correction is deterministically retryable and never stale');
select is((select status from extensions.dblink('tr_one',format('select app_auth.test_capture_transcript_sql(%L,%L)','e1100000-0000-0000-0000-000000000001',format('select public.cancel_transcript(%L,%L)',(select id from public.transcripts where student_id='e1c00000-0000-0000-0000-000000000001' and status in('draft','reviewed')),'discard stale race candidate')))as t(status text)),'00000','stale race candidate is cancelled before rebuild race');

-- Rebuild and a second parent correction both complete in a serial order. The
-- rebuild therefore snapshots either the complete old live head or its complete
-- successor, never a mixed report-card/grade set.
select is(extensions.dblink_send_query('tr_one',format('select app_auth.test_capture_transcript_sql(%L,%L)','e1100000-0000-0000-0000-000000000001',format('select public.rebuild_transcript(%L,array[row(''e1900000-0000-0000-0000-000000000001'')::public.transcript_term_input],''{}'',''rebuild correction race'')',(select id from public.transcripts where student_id='e1c00000-0000-0000-0000-000000000001' and status='issued')))),1,'rebuild/source-correction rebuild dispatched');
select is(extensions.dblink_send_query('tr_two',format('select app_auth.test_capture_transcript_sql(%L,%L)','e1100000-0000-0000-0000-000000000002',format('select * from public.correct_report_card(%L,%L)',(select id from public.report_cards where student_id='e1c00000-0000-0000-0000-000000000001' and status='published'),'second source correction race'))),1,'rebuild/source-correction correction dispatched');
select lives_ok($$select pg_sleep(0.2)$$,'rebuild and report-card correction overlap');
truncate transcript_source_race;
insert into transcript_source_race select 'rebuild',status from extensions.dblink_get_result('tr_one')as t(status text);
insert into transcript_source_race select 'correction',status from extensions.dblink_get_result('tr_two')as t(status text);
select is((select array_agg(status order by status)::text from transcript_source_race),'{00000,00000}','rebuild and report-card correction both serialize successfully');
select is((select count(*)::int from public.transcript_period_snapshots p join public.transcripts t on t.id=p.transcript_id where t.student_id='e1c00000-0000-0000-0000-000000000001' and t.status='draft'),1,'rebuild race stores one internally consistent period');
select ok((select p.source_report_card_fingerprint=r.source_fingerprint from public.transcript_period_snapshots p join public.transcripts t on t.id=p.transcript_id join public.report_cards r on r.id=p.report_card_id where t.student_id='e1c00000-0000-0000-0000-000000000001' and t.status='draft'),'rebuild race captures the exact selected report-card fingerprint');
select ok(not exists(select 1 from public.transcript_entry_snapshots e join public.transcripts t on t.id=e.transcript_id join public.transcript_period_snapshots p on p.id=e.transcript_period_snapshot_id left join public.report_card_grade_snapshots g on g.id=e.report_card_grade_snapshot_id and g.report_card_id=p.report_card_id where t.student_id='e1c00000-0000-0000-0000-000000000001' and t.status='draft' and g.id is null),'rebuild race entries all belong to the one complete captured source head');
select is((select count(*)::int from public.event_outbox where event_type='transcript.rebuild_started' and aggregate_id=(select id from public.transcripts where student_id='e1c00000-0000-0000-0000-000000000001' and status='draft')),1,'rebuild/source-correction winner emits one rebuild event');
select is((select count(*)::int from public.audit_log a join public.event_outbox e using(command_id) where e.event_type='transcript.rebuild_started' and e.aggregate_id=(select id from public.transcripts where student_id='e1c00000-0000-0000-0000-000000000001' and status='draft')),3,'rebuild/source-correction command shares one id across its complete snapshot audit');
select extensions.dblink_disconnect('tr_one'); select extensions.dblink_disconnect('tr_two');
select extensions.dblink_connect('tr_one','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');
select extensions.dblink_connect('tr_two','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');

-- Build a fresh reviewed candidate from the now-current source, then genuinely
-- race issue against another report-card correction.
select is((select status from extensions.dblink('tr_one',format('select app_auth.test_capture_transcript_sql(%L,%L)','e1100000-0000-0000-0000-000000000001',format('select public.cancel_transcript(%L,%L)',(select id from public.transcripts where student_id='e1c00000-0000-0000-0000-000000000001' and status='draft'),'replace race candidate')))as t(status text)),'00000','rebuild-race candidate is cancelled');
select is((select status from extensions.dblink('tr_one',format('select app_auth.test_capture_transcript_sql(%L,%L)','e1100000-0000-0000-0000-000000000001',format('select public.rebuild_transcript(%L,array[row(''e1900000-0000-0000-0000-000000000001'')::public.transcript_term_input],''{}'',''fresh issue correction race'')',(select id from public.transcripts where student_id='e1c00000-0000-0000-0000-000000000001' and status='issued'))))as t(status text)),'00000','fresh successor snapshots the current report-card head');
select is((select status from extensions.dblink('tr_one',format('select app_auth.test_capture_transcript_sql(%L,%L)','e1100000-0000-0000-0000-000000000001',format('select public.review_transcript(%L,%L)',(select id from public.transcripts where student_id='e1c00000-0000-0000-0000-000000000001' and status='draft'),'issue correction race review')))as t(status text)),'00000','fresh successor is reviewed before issue race');
select is(extensions.dblink_send_query('tr_one',format('select app_auth.test_capture_transcript_sql(%L,%L)','e1100000-0000-0000-0000-000000000002',format('select public.issue_transcript(%L,%L)',(select id from public.transcripts where student_id='e1c00000-0000-0000-0000-000000000001' and status='reviewed'),'issue correction race'))),1,'issue/source-correction issue dispatched');
select is(extensions.dblink_send_query('tr_two',format('select app_auth.test_capture_transcript_sql(%L,%L)','e1100000-0000-0000-0000-000000000001',format('select * from public.correct_report_card(%L,%L)',(select id from public.report_cards where student_id='e1c00000-0000-0000-0000-000000000001' and status='published'),'issue correction source race'))),1,'issue/source-correction correction dispatched by authorized actor');
select lives_ok($$select pg_sleep(0.2)$$,'issue and report-card correction genuinely overlap');
truncate transcript_source_race;
insert into transcript_source_race select 'issue',status from extensions.dblink_get_result('tr_one')as t(status text);
insert into transcript_source_race select 'correction',status from extensions.dblink_get_result('tr_two')as t(status text);
select is((select status from transcript_source_race where side='correction'),'00000','issue-racing report-card correction succeeds');
select ok((select status in('00000','40001') from transcript_source_race where side='issue'),'issue either precedes correction coherently or returns retryable 40001');
select is((select count(*)::int from public.transcripts where student_id='e1c00000-0000-0000-0000-000000000001' and status='issued'),1,'issue/correction race leaves exactly one issued transcript head');
select is((select count(*)::int from public.event_outbox where event_type='transcript.issued' and aggregate_id=(select id from public.transcripts where student_id='e1c00000-0000-0000-0000-000000000001' order by version desc limit 1)),case when(select status from transcript_source_race where side='issue')='00000' then 1 else 0 end,'issue/source-correction race records only the aggregate-scoped winning issue command');
select extensions.dblink_disconnect('tr_one'); select extensions.dblink_disconnect('tr_two');
select extensions.dblink_connect('tr_one','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');
select extensions.dblink_connect('tr_two','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');

-- Opposing caller order is normalized by lock_transcript_context. Both sessions
-- complete without deadlock after being released together from the domain mutex.
select extensions.dblink_exec('tr_block','begin; do $do$begin perform app_auth.lock_academic_snapshot_domain(''e1200000-0000-0000-0000-000000000001''); end$do$');
select is(extensions.dblink_send_query('tr_one',format('select app_auth.test_capture_transcript_sql(%L,%L)','e1100000-0000-0000-0000-000000000001','select app_auth.lock_transcript_context(''e1c00000-0000-0000-0000-000000000001'',''e1300000-0000-0000-0000-000000000001'',array[''e1900000-0000-0000-0000-000000000001''::uuid,''e1900000-0000-0000-0000-000000000002''::uuid])')),1,'ascending multi-term lock request dispatched');
select is(extensions.dblink_send_query('tr_two',format('select app_auth.test_capture_transcript_sql(%L,%L)','e1100000-0000-0000-0000-000000000001','select app_auth.lock_transcript_context(''e1c00000-0000-0000-0000-000000000001'',''e1300000-0000-0000-0000-000000000001'',array[''e1900000-0000-0000-0000-000000000002''::uuid,''e1900000-0000-0000-0000-000000000001''::uuid])')),1,'descending multi-term lock request dispatched');
select lives_ok($$select pg_sleep(0.2)$$,'opposing multi-term lock requests overlap');
select extensions.dblink_exec('tr_block','commit');
create temp table transcript_lock_order_race(status text);
insert into transcript_lock_order_race select status from extensions.dblink_get_result('tr_one')as t(status text);
insert into transcript_lock_order_race select status from extensions.dblink_get_result('tr_two')as t(status text);
select is((select array_agg(status order by status)::text from transcript_lock_order_race),'{00000,00000}','opposing multi-term input order is deadlock-free');
select extensions.dblink_disconnect('tr_one'); select extensions.dblink_disconnect('tr_two');
select extensions.dblink_connect('tr_one','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');
select extensions.dblink_connect('tr_two','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');

select extensions.dblink_exec('tr_block','begin; do $do$begin perform pg_advisory_xact_lock(hashtextextended(''school-platform:academic-snapshot:00000000-0000-0000-0000-000000000001'',0)); end$do$');
select is(extensions.dblink_send_query('tr_one',$q$select pg_try_advisory_xact_lock(hashtextextended('school-platform:academic-snapshot:00000000-0000-0000-0000-000000000001',0))$q$),1,'first competing session dispatched');
select is(extensions.dblink_send_query('tr_two',$q$select pg_try_advisory_xact_lock(hashtextextended('school-platform:academic-snapshot:00000000-0000-0000-0000-000000000001',0))$q$),1,'second competing session dispatched');
select lives_ok($$select pg_sleep(0.1)$$,'sessions genuinely overlap');
select extensions.dblink_exec('tr_block','commit');
select ok((select count(*)=2 from(select * from extensions.dblink_get_result('tr_one')as t(acquired boolean) union all select * from extensions.dblink_get_result('tr_two')as t(acquired boolean))q),'both independent session results returned');

select extensions.dblink_disconnect('tr_one');
select extensions.dblink_disconnect('tr_two');
select extensions.dblink_disconnect('tr_block');

select extensions.dblink_connect('tr_block','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');
select extensions.dblink_connect('tr_one','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');
select extensions.dblink_connect('tr_two','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');
select extensions.dblink_exec('tr_block','begin; do $do$begin perform app_auth.lock_academic_snapshot_domain(''f1200000-0000-0000-0000-000000000001''); end$do$');
select is(extensions.dblink_send_query('tr_one',format('select app_auth.test_capture_transcript_sql(%L,%L)','f1100000-0000-0000-0000-000000000002','select public.issue_transcript(''f1800000-0000-0000-0000-000000000001'',''race issue one'')')),1,'first issue dispatched');
select is(extensions.dblink_send_query('tr_two',format('select app_auth.test_capture_transcript_sql(%L,%L)','f1100000-0000-0000-0000-000000000003','select public.issue_transcript(''f1800000-0000-0000-0000-000000000001'',''race issue two'')')),1,'second issue dispatched');
select lives_ok($$select pg_sleep(0.2)$$,'issue commands overlap behind shared mutex');
select extensions.dblink_exec('tr_block','commit');
create temp table transcript_issue_race(status text);
insert into transcript_issue_race select status from extensions.dblink_get_result('tr_one')as t(status text);
insert into transcript_issue_race select status from extensions.dblink_get_result('tr_two')as t(status text);
select is((select array_agg(status order by status)::text from transcript_issue_race),'{00000,40001}','concurrent issue has one winner and one retryable loser');
select is((select count(*)::int from public.transcripts where school_id='f1300000-0000-0000-0000-000000000001' and status='issued'),1,'issue race leaves one issued head');
select is((select transcript_number from public.transcripts where school_id='f1300000-0000-0000-0000-000000000001' and status='issued'),1::bigint,'issue race allocates one number');
select is((select count(*)::int from public.audit_log where entity_id='f1800000-0000-0000-0000-000000000001' and action='transcript.issued'),1,'issue race writes one audit row');
select is((select count(*)::int from public.event_outbox where aggregate_id='f1800000-0000-0000-0000-000000000001' and event_type='transcript.issued'),1,'issue race writes one outbox row');
select extensions.dblink_disconnect('tr_one'); select extensions.dblink_disconnect('tr_two');
select extensions.dblink_connect('tr_one','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');
select extensions.dblink_connect('tr_two','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');
insert into public.transcripts(id,organization_id,school_id,student_id,transcript_lineage_id,version,supersedes_transcript_id,replaces_issued_transcript_id,status,source_fingerprint,reviewed_at,reviewed_by,review_reason,school_code,school_name,student_number,student_display_name,created_by,updated_by)
values('f1800000-0000-0000-0000-000000000002','f1200000-0000-0000-0000-000000000001','f1300000-0000-0000-0000-000000000001','f1700000-0000-0000-0000-000000000001','f1800000-0000-0000-0000-000000000001',2,'f1800000-0000-0000-0000-000000000001','f1800000-0000-0000-0000-000000000001','reviewed',extensions.digest('|policy:none','sha256'),now(),'f1100000-0000-0000-0000-000000000001','correction reviewed','TRR','Transcript Race School','RACE-1','Race Student','f1100000-0000-0000-0000-000000000001','f1100000-0000-0000-0000-000000000001');
truncate transcript_issue_race;
select extensions.dblink_exec('tr_block','begin; do $do$begin perform app_auth.lock_academic_snapshot_domain(''f1200000-0000-0000-0000-000000000001''); end$do$');
select is(extensions.dblink_send_query('tr_one',format('select app_auth.test_capture_transcript_sql(%L,%L)','f1100000-0000-0000-0000-000000000002','select public.issue_transcript(''f1800000-0000-0000-0000-000000000002'',''race successor issue'')')),1,'successor issue dispatched');
select is(extensions.dblink_send_query('tr_two',format('select app_auth.test_capture_transcript_sql(%L,%L)','f1100000-0000-0000-0000-000000000003','select * from public.correct_transcript(''f1800000-0000-0000-0000-000000000002'',''race successor correction'')')),1,'successor correction dispatched');
select lives_ok($$select pg_sleep(0.2)$$,'successor issue and correction commands overlap behind shared mutex');
select extensions.dblink_exec('tr_block','commit');
insert into transcript_issue_race select status from extensions.dblink_get_result('tr_one')as t(status text);
insert into transcript_issue_race select status from extensions.dblink_get_result('tr_two')as t(status text);
select is((select array_agg(status order by status)::text from transcript_issue_race),'{00000,40001}','successor issue versus correction has one winner and one retryable loser');
select is((select count(*)::int from public.transcripts where school_id='f1300000-0000-0000-0000-000000000001' and status in('corrected','superseded')),1,'successor race terminalizes one predecessor exactly once');
select is((select count(*)::int from public.transcripts where school_id='f1300000-0000-0000-0000-000000000001' and status='issued'),1,'successor race leaves one current issue');
select is((select transcript_number from public.transcripts where school_id='f1300000-0000-0000-0000-000000000001' and status='issued'),2::bigint,'successor race allocates exactly one successor number');
select is((select count(*)::int from public.event_outbox where aggregate_id='f1800000-0000-0000-0000-000000000002' and event_type='transcript.issued'),1,'successor race winner emits one issue event');
select is((select count(*)::int from public.audit_log a join public.event_outbox e using(command_id) where e.aggregate_id='f1800000-0000-0000-0000-000000000002' and e.event_type='transcript.issued' and a.action in('transcript.issued','transcript.corrected','transcript.superseded')),2,'successor race winner atomically audits predecessor and issue under one command');
select extensions.dblink_disconnect('tr_one'); select extensions.dblink_disconnect('tr_two');
select extensions.dblink_connect('tr_one','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');
select extensions.dblink_connect('tr_two','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');

-- A fresh reviewed successor is presented to two correction commands. Both
-- sessions are released from the same domain-mutex barrier, so this exercises
-- the aggregate lock rather than a sequential stale-state check.
insert into public.transcripts(id,organization_id,school_id,student_id,transcript_lineage_id,version,supersedes_transcript_id,replaces_issued_transcript_id,status,source_fingerprint,reviewed_at,reviewed_by,review_reason,school_code,school_name,student_number,student_display_name,created_by,updated_by)
select 'f1800000-0000-0000-0000-000000000003',organization_id,school_id,student_id,transcript_lineage_id,3,id,id,'reviewed',extensions.digest('|policy:none','sha256'),now(),'f1100000-0000-0000-0000-000000000001','double correction review',school_code,school_name,student_number,student_display_name,'f1100000-0000-0000-0000-000000000001','f1100000-0000-0000-0000-000000000001'
from public.transcripts where id='f1800000-0000-0000-0000-000000000002' and status='issued';
truncate transcript_issue_race;
select extensions.dblink_exec('tr_block','begin; do $do$begin perform app_auth.lock_academic_snapshot_domain(''f1200000-0000-0000-0000-000000000001''); end$do$');
select is(extensions.dblink_send_query('tr_one',format('select app_auth.test_capture_transcript_sql(%L,%L)','f1100000-0000-0000-0000-000000000002','select * from public.correct_transcript(''f1800000-0000-0000-0000-000000000003'',''first concurrent correction'')')),1,'first concurrent correction dispatched');
select is(extensions.dblink_send_query('tr_two',format('select app_auth.test_capture_transcript_sql(%L,%L)','f1100000-0000-0000-0000-000000000003','select * from public.correct_transcript(''f1800000-0000-0000-0000-000000000003'',''second concurrent correction'')')),1,'second concurrent correction dispatched');
select lives_ok($$select pg_sleep(0.2)$$,'two correction commands genuinely overlap behind shared mutex');
select extensions.dblink_exec('tr_block','commit');
insert into transcript_issue_race select status from extensions.dblink_get_result('tr_one')as t(status text);
insert into transcript_issue_race select status from extensions.dblink_get_result('tr_two')as t(status text);
select is((select array_agg(status order by status)::text from transcript_issue_race),'{00000,40001}','correction versus correction has one winner and one retryable loser');
select is((select count(*)::int from public.transcripts where id='f1800000-0000-0000-0000-000000000002' and status='corrected'),1,'double-correction race corrects the prior issue exactly once');
select is((select count(*)::int from public.transcripts where id='f1800000-0000-0000-0000-000000000003' and status='issued' and transcript_number=3),1,'double-correction race issues exactly one numbered replacement');
select is((select count(*)::int from public.event_outbox where aggregate_id='f1800000-0000-0000-0000-000000000003' and event_type='transcript.issued'),1,'double-correction loser leaves no duplicate issue event');
select is((select count(*)::int from public.event_outbox where aggregate_id='f1800000-0000-0000-0000-000000000002' and event_type='transcript.corrected'),1,'double-correction loser leaves no duplicate correction event');
select is((select count(*)::int from public.audit_log a join public.event_outbox e using(command_id) where e.aggregate_id='f1800000-0000-0000-0000-000000000003' and e.event_type='transcript.issued' and a.action in('transcript.issued','transcript.corrected')),2,'double-correction winner shares one command id across its two audit rows');
select extensions.dblink_disconnect('tr_one'); select extensions.dblink_disconnect('tr_two'); select extensions.dblink_disconnect('tr_block');
drop function app_auth.test_capture_transcript_sql(uuid,text);
select * from finish();
