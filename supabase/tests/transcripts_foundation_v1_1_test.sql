begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

select has_type('public','transcript_status','transcript lifecycle enum exists');
select has_type('public','transcript_result_state','transcript result enum exists');
select has_type('public','transcript_exclusion_type','exclusion enum exists');
select has_type('public','transcript_policy_status','policy lifecycle enum exists');
select has_type('public','transcript_term_input','term input composite exists');
select has_type('public','transcript_exclusion_input','exclusion input composite exists');
select has_type('public','transcript_gpa_band_input','GPA band input composite exists');
select has_type('public','transcript_subject_credit_input','credit input composite exists');
select is(enum_range(null::public.transcript_status)::text,'{draft,reviewed,issued,superseded,corrected,cancelled}','transcript states are exact');
select is(enum_range(null::public.transcript_result_state)::text,'{pass,fail,incomplete,withdrawn,transferred,non_credit}','result states are exact');

select has_table('public','transcript_calculation_policies','policy table exists');
select has_table('public','transcript_gpa_bands','GPA bands exist');
select has_table('public','transcript_subject_credits','subject credits exist');
select has_table('public','transcript_lineages','permanent lineages exist');
select has_table('public','transcripts','transcript versions exist');
select has_table('public','transcript_period_snapshots','period snapshots exist');
select has_table('public','transcript_entry_snapshots','entry snapshots exist');
select has_table('public','transcript_exclusions','exclusion evidence exists');
select has_table('public','transcript_number_counters','issue counters exist');
select has_view('public','transcript_current_versions','current issued view exists');
select has_view('public','transcript_period_read_model','period read model exists');
select has_view('public','transcript_entry_read_model','entry read model exists');
select is((select count(*)::int from public.permissions where code like 'transcripts.%'),3,'three transcript permissions seeded');

select ok((select bool_and(c.relrowsecurity and c.relforcerowsecurity) from pg_class c where c.oid=any(array[
 'public.transcript_calculation_policies'::regclass,'public.transcript_gpa_bands'::regclass,
 'public.transcript_subject_credits'::regclass,'public.transcript_lineages'::regclass,
 'public.transcripts'::regclass,'public.transcript_period_snapshots'::regclass,
 'public.transcript_entry_snapshots'::regclass,'public.transcript_exclusions'::regclass,
 'public.transcript_number_counters'::regclass])),'all transcript tables force RLS');
select ok(not has_table_privilege('authenticated','public.transcripts','INSERT,UPDATE,DELETE,TRUNCATE'),'versions are SELECT-only');
select ok(not has_table_privilege('authenticated','public.transcript_entry_snapshots','INSERT,UPDATE,DELETE,TRUNCATE'),'entries are SELECT-only');
select ok(not has_table_privilege('authenticated','public.transcript_number_counters','SELECT,INSERT,UPDATE,DELETE'),'counter is private');
select ok(not has_table_privilege('anon','public.transcripts','SELECT'),'anonymous transcript read denied');
select has_index('public','transcripts','transcripts_open_candidate_key','one open candidate per lineage');
select has_index('public','transcripts','transcripts_current_issued_key','one current issue per lineage');
select has_index('public','transcripts','transcripts_one_successor_key','version history cannot branch');
select has_index('public','transcript_calculation_policies','transcript_policies_active_school_key','one active school policy');

create temp table expected_transcript_rpcs(signature text) on commit drop;
insert into expected_transcript_rpcs values
 ('public.create_transcript(uuid,uuid,transcript_term_input[],transcript_exclusion_input[])'),
 ('public.rebuild_transcript(uuid,transcript_term_input[],transcript_exclusion_input[],text)'),
 ('public.review_transcript(uuid,text)'),('public.return_transcript_to_draft(uuid,text)'),
 ('public.issue_transcript(uuid,text)'),('public.cancel_transcript(uuid,text)'),
 ('public.correct_transcript(uuid,text)'),
 ('public.create_transcript_calculation_policy(uuid,text,numeric,smallint,boolean,boolean,boolean,transcript_gpa_band_input[],transcript_subject_credit_input[])'),
 ('public.update_draft_transcript_calculation_policy(uuid,text,numeric,smallint,boolean,boolean,boolean,transcript_gpa_band_input[],transcript_subject_credit_input[])'),
 ('public.activate_transcript_calculation_policy(uuid)'),
 ('public.revise_transcript_calculation_policy(uuid,text,numeric,smallint,boolean,boolean,boolean,transcript_gpa_band_input[],transcript_subject_credit_input[])'),
 ('public.retire_transcript_calculation_policy(uuid)');
select ok(not exists(select 1 from expected_transcript_rpcs e where to_regprocedure(e.signature)is null),'all typed RPCs exist');
select ok(not exists(select 1 from expected_transcript_rpcs e join pg_proc p on p.oid=to_regprocedure(e.signature) where not p.prosecdef or pg_get_userbyid(p.proowner)<>'postgres' or not exists(select 1 from unnest(p.proconfig)c where c like 'search_path=%')),'RPC security attributes are exact');
select ok(not exists(select 1 from expected_transcript_rpcs e join pg_proc p on p.oid=to_regprocedure(e.signature) where has_function_privilege('anon',p.oid,'EXECUTE')or has_function_privilege('service_role',p.oid,'EXECUTE')or not has_function_privilege('authenticated',p.oid,'EXECUTE')),'RPC grants are exact');
select ok(not has_function_privilege('authenticated','app_auth.build_transcript(uuid,uuid,transcript_term_input[],transcript_exclusion_input[],uuid,uuid,uuid,text)','EXECUTE'),'private transcript builder denied');
select ok(position('lock_academic_snapshot_domain' in pg_get_functiondef('app_auth.lock_transcript_context(uuid,uuid,uuid[])'::regprocedure))>0,'transcript locks share the academic snapshot mutex');
select ok(position('published' in pg_get_functiondef('app_auth.build_transcript(uuid,uuid,transcript_term_input[],transcript_exclusion_input[],uuid,uuid,uuid,text)'::regprocedure))>0,'builder requires published source heads');
select ok(position('reviewed_by=a' in replace(pg_get_functiondef('app_auth.finish_transcript_issue(uuid,text,boolean)'::regprocedure),' ',''))>0,'issuance enforces distinct reviewer and issuer');
select ok(position('transcript_number_counters' in pg_get_functiondef('app_auth.finish_transcript_issue(uuid,text,boolean)'::regprocedure))>0,'number is allocated by issuance');
select ok(position('issued' in pg_get_viewdef('public.transcript_current_versions'::regclass))>0,'current view contains issued heads only');
select ok(position('student_date_of_birth' in pg_get_functiondef('app_auth.write_transcript_change(uuid,uuid,uuid,text,text,uuid,jsonb,jsonb,jsonb,boolean)'::regprocedure))>0,'audit writer removes date of birth');
select ok(position('grade_label' in pg_get_functiondef('app_auth.write_transcript_change(uuid,uuid,uuid,text,text,uuid,jsonb,jsonb,jsonb,boolean)'::regprocedure))=0,'outbox helper does not inject grades');

set local role anon;
select throws_ok($$select public.create_transcript(gen_random_uuid(),gen_random_uuid(),array[row(gen_random_uuid())::public.transcript_term_input],'{}')$$,'42501','permission denied for function create_transcript','anonymous command denied');
reset role;
select throws_ok($$insert into public.transcripts(id)values(gen_random_uuid())$$,'23502',null,'forged incomplete transcript rejected');
select throws_ok($$insert into public.transcript_entry_snapshots(id)values(gen_random_uuid())$$,'23502',null,'forged incomplete entry rejected');

-- Policy commands exercise scoped RBAC, strict validation, version immutability,
-- privacy-safe audit/outbox, and atomic command cardinality.
insert into auth.users(id,instance_id,aud,role,email,encrypted_password,created_at,updated_at) values
 ('e1100000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','transcript-admin@test','',now(),now());
insert into public.organizations(id,name,slug) values('e1200000-0000-0000-0000-000000000001','Transcript Tenant','transcript-tenant');
insert into public.schools(id,organization_id,name,code) values('e1300000-0000-0000-0000-000000000001','e1200000-0000-0000-0000-000000000001','Transcript School','TRS');
insert into public.organization_memberships(id,organization_id,user_id,status,joined_at) values('e1400000-0000-0000-0000-000000000001','e1200000-0000-0000-0000-000000000001','e1100000-0000-0000-0000-000000000001','active',now());
insert into public.roles(id,organization_id,code,name) values('e1500000-0000-0000-0000-000000000001','e1200000-0000-0000-0000-000000000001','TRANSCRIPT_ADMIN','Transcript Admin');
insert into public.role_permissions(organization_id,role_id,permission_id) select 'e1200000-0000-0000-0000-000000000001','e1500000-0000-0000-0000-000000000001',id from public.permissions where code in('transcripts.view','transcripts.manage','transcripts.correct');
insert into public.role_assignments(organization_id,organization_membership_id,role_id,school_id) values('e1200000-0000-0000-0000-000000000001','e1400000-0000-0000-0000-000000000001','e1500000-0000-0000-0000-000000000001','e1300000-0000-0000-0000-000000000001');
insert into public.subjects(id,organization_id,school_id,code,name,status) values('e1600000-0000-0000-0000-000000000001','e1200000-0000-0000-0000-000000000001','e1300000-0000-0000-0000-000000000001','MATH','Mathematics','active');
insert into auth.users(id,instance_id,aud,role,email,encrypted_password,created_at,updated_at) values('e1100000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','transcript-issuer@test','',now(),now());
insert into auth.users(id,instance_id,aud,role,email,encrypted_password,created_at,updated_at) values
 ('e1100000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000000','authenticated','authenticated','transcript-student@test','',now(),now()),
 ('e1100000-0000-0000-0000-000000000004','00000000-0000-0000-0000-000000000000','authenticated','authenticated','transcript-guardian@test','',now(),now()),
 ('e1100000-0000-0000-0000-000000000005','00000000-0000-0000-0000-000000000000','authenticated','authenticated','transcript-teacher@test','',now(),now());
insert into public.organization_memberships(id,organization_id,user_id,status,joined_at) values('e1400000-0000-0000-0000-000000000002','e1200000-0000-0000-0000-000000000001','e1100000-0000-0000-0000-000000000002','active',now());
insert into public.role_assignments(organization_id,organization_membership_id,role_id,school_id) values('e1200000-0000-0000-0000-000000000001','e1400000-0000-0000-0000-000000000002','e1500000-0000-0000-0000-000000000001','e1300000-0000-0000-0000-000000000001');
insert into public.campuses(id,organization_id,school_id,name,code) values('e1700000-0000-0000-0000-000000000001','e1200000-0000-0000-0000-000000000001','e1300000-0000-0000-0000-000000000001','Main Campus','MAIN');
insert into public.academic_years(id,organization_id,school_id,name,start_date,end_date,status) values('e1800000-0000-0000-0000-000000000001','e1200000-0000-0000-0000-000000000001','e1300000-0000-0000-0000-000000000001','2026-27','2026-01-01','2026-12-31','active');
insert into public.academic_terms(id,organization_id,academic_year_id,name,sequence,start_date,end_date,status) values('e1900000-0000-0000-0000-000000000001','e1200000-0000-0000-0000-000000000001','e1800000-0000-0000-0000-000000000001','Term 1',1,'2026-01-01','2026-12-31','active');
insert into public.grade_levels(id,organization_id,school_id,code,name,sequence,status) values('e1a00000-0000-0000-0000-000000000001','e1200000-0000-0000-0000-000000000001','e1300000-0000-0000-0000-000000000001','G1','Grade 1',1,'active');
insert into public.sections(id,organization_id,school_id,campus_id,academic_year_id,academic_term_id,grade_level_id,code,name,capacity,start_date,end_date,status) values('e1b00000-0000-0000-0000-000000000001','e1200000-0000-0000-0000-000000000001','e1300000-0000-0000-0000-000000000001','e1700000-0000-0000-0000-000000000001','e1800000-0000-0000-0000-000000000001','e1900000-0000-0000-0000-000000000001','e1a00000-0000-0000-0000-000000000001','1A','Grade 1 A',30,'2026-01-01','2026-12-31','active');
insert into public.students(id,organization_id,school_id,campus_id,user_id,student_number,first_name,last_name,date_of_birth,status) values('e1c00000-0000-0000-0000-000000000001','e1200000-0000-0000-0000-000000000001','e1300000-0000-0000-0000-000000000001','e1700000-0000-0000-0000-000000000001','e1100000-0000-0000-0000-000000000003','S1','Transcript','Student','2018-01-01','active');
insert into public.student_enrollments(id,organization_id,school_id,academic_year_id,student_id,grade_level_id,enrolled_on,scheduled_end_on,enrollment_range,status,created_by,updated_by) values('e1d00000-0000-0000-0000-000000000001','e1200000-0000-0000-0000-000000000001','e1300000-0000-0000-0000-000000000001','e1800000-0000-0000-0000-000000000001','e1c00000-0000-0000-0000-000000000001','e1a00000-0000-0000-0000-000000000001','2026-01-01','2026-12-31',daterange('2026-01-01','2026-12-31','[]'),'active','e1100000-0000-0000-0000-000000000001','e1100000-0000-0000-0000-000000000001');
insert into public.student_section_placements(id,organization_id,school_id,campus_id,academic_year_id,student_enrollment_id,student_id,section_id,starts_on,status,created_by,updated_by) values('e1e00000-0000-0000-0000-000000000001','e1200000-0000-0000-0000-000000000001','e1300000-0000-0000-0000-000000000001','e1700000-0000-0000-0000-000000000001','e1800000-0000-0000-0000-000000000001','e1d00000-0000-0000-0000-000000000001','e1c00000-0000-0000-0000-000000000001','e1b00000-0000-0000-0000-000000000001','2026-01-01','active','e1100000-0000-0000-0000-000000000001','e1100000-0000-0000-0000-000000000001');
insert into public.grade_scales(id,organization_id,school_id,academic_year_id,name,status,activated_at,activated_by,created_by,updated_by) values('e1f00000-0000-0000-0000-000000000001','e1200000-0000-0000-0000-000000000001','e1300000-0000-0000-0000-000000000001','e1800000-0000-0000-0000-000000000001','Scale','active',now(),'e1100000-0000-0000-0000-000000000001','e1100000-0000-0000-0000-000000000001','e1100000-0000-0000-0000-000000000001');
insert into public.grade_scale_bands(id,organization_id,school_id,grade_scale_id,sequence,lower_units,upper_units,label,result_state,created_by) values('e2000000-0000-0000-0000-000000000001','e1200000-0000-0000-0000-000000000001','e1300000-0000-0000-0000-000000000001','e1f00000-0000-0000-0000-000000000001',1,0,1000000,'Pass','pass','e1100000-0000-0000-0000-000000000001');
insert into public.term_grading_configurations(id,organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,subject_id,grade_scale_id,status,activated_at,activated_by,created_by,updated_by) values('e2100000-0000-0000-0000-000000000001','e1200000-0000-0000-0000-000000000001','e1300000-0000-0000-0000-000000000001','e1700000-0000-0000-0000-000000000001','e1800000-0000-0000-0000-000000000001','e1900000-0000-0000-0000-000000000001','e1b00000-0000-0000-0000-000000000001','e1600000-0000-0000-0000-000000000001','e1f00000-0000-0000-0000-000000000001','active',now(),'e1100000-0000-0000-0000-000000000001','e1100000-0000-0000-0000-000000000001','e1100000-0000-0000-0000-000000000001');
insert into public.term_grade_sets(id,organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,subject_id,term_grading_configuration_id,lifecycle_status,publication_state,calculation_sequence,source_fingerprint,finalized_at,finalized_by,created_by,updated_by) values('e2200000-0000-0000-0000-000000000001','e1200000-0000-0000-0000-000000000001','e1300000-0000-0000-0000-000000000001','e1700000-0000-0000-0000-000000000001','e1800000-0000-0000-0000-000000000001','e1900000-0000-0000-0000-000000000001','e1b00000-0000-0000-0000-000000000001','e1600000-0000-0000-0000-000000000001','e2100000-0000-0000-0000-000000000001','finalized','unpublished',1,extensions.digest('set','sha256'),now(),'e1100000-0000-0000-0000-000000000001','e1100000-0000-0000-0000-000000000001','e1100000-0000-0000-0000-000000000001');
insert into public.term_grade_records(id,organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,subject_id,term_grading_configuration_id,term_grade_set_id,student_id,calculation_sequence,created_by) values('e2300000-0000-0000-0000-000000000001','e1200000-0000-0000-0000-000000000001','e1300000-0000-0000-0000-000000000001','e1700000-0000-0000-0000-000000000001','e1800000-0000-0000-0000-000000000001','e1900000-0000-0000-0000-000000000001','e1b00000-0000-0000-0000-000000000001','e1600000-0000-0000-0000-000000000001','e2100000-0000-0000-0000-000000000001','e2200000-0000-0000-0000-000000000001','e1c00000-0000-0000-0000-000000000001',1,'e1100000-0000-0000-0000-000000000001');
insert into public.term_grade_calculations(id,organization_id,term_grade_set_id,term_grade_record_id,student_id,calculation_sequence,raw_percentage,rounded_percentage,grade_scale_id,grade_scale_band_id,grade_label,result_state,contributing_assessment_count,weight_total,calculated_by) values('e2400000-0000-0000-0000-000000000001','e1200000-0000-0000-0000-000000000001','e2200000-0000-0000-0000-000000000001','e2300000-0000-0000-0000-000000000001','e1c00000-0000-0000-0000-000000000001',1,88,88,'e1f00000-0000-0000-0000-000000000001','e2000000-0000-0000-0000-000000000001','Pass','pass',1,100,'e1100000-0000-0000-0000-000000000001');
insert into public.report_cards(id,organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,student_id,student_enrollment_id,student_section_placement_id,lineage_id,version,report_card_number,status,finalized_at,finalized_by,published_at,published_by,source_fingerprint,school_code,school_name,campus_code,campus_name,academic_year_name,academic_term_name,academic_term_sequence,term_start_date,term_end_date,section_code,section_name,grade_level_code,grade_level_name,student_number,student_display_name,created_by,updated_by) values('e2500000-0000-0000-0000-000000000001','e1200000-0000-0000-0000-000000000001','e1300000-0000-0000-0000-000000000001','e1700000-0000-0000-0000-000000000001','e1800000-0000-0000-0000-000000000001','e1900000-0000-0000-0000-000000000001','e1b00000-0000-0000-0000-000000000001','e1c00000-0000-0000-0000-000000000001','e1d00000-0000-0000-0000-000000000001','e1e00000-0000-0000-0000-000000000001','e2500000-0000-0000-0000-000000000001',1,1,'published',now(),'e1100000-0000-0000-0000-000000000001',now(),'e1100000-0000-0000-0000-000000000001',extensions.digest('card','sha256'),'TRS','Transcript School','MAIN','Main Campus','2026-27','Term 1',1,'2026-01-01','2026-12-31','1A','Grade 1 A','G1','Grade 1','S1','Transcript Student','e1100000-0000-0000-0000-000000000001','e1100000-0000-0000-0000-000000000001');
insert into public.report_card_grade_snapshots(id,organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,report_card_id,student_id,subject_id,subject_code,subject_name,term_grading_configuration_id,term_grade_set_id,term_grade_record_id,term_grade_calculation_id,grade_scale_id,grade_scale_band_id,term_grade_calculation_sequence,raw_percentage,rounded_percentage,grade_label,result_state,contributing_assessment_count,weight_total,source_term_grade_fingerprint,created_by) values('e2600000-0000-0000-0000-000000000001','e1200000-0000-0000-0000-000000000001','e1300000-0000-0000-0000-000000000001','e1700000-0000-0000-0000-000000000001','e1800000-0000-0000-0000-000000000001','e1900000-0000-0000-0000-000000000001','e1b00000-0000-0000-0000-000000000001','e2500000-0000-0000-0000-000000000001','e1c00000-0000-0000-0000-000000000001','e1600000-0000-0000-0000-000000000001','MATH','Mathematics','e2100000-0000-0000-0000-000000000001','e2200000-0000-0000-0000-000000000001','e2300000-0000-0000-0000-000000000001','e2400000-0000-0000-0000-000000000001','e1f00000-0000-0000-0000-000000000001','e2000000-0000-0000-0000-000000000001',1,88,88,'Pass','pass',1,100,extensions.digest('grade','sha256'),'e1100000-0000-0000-0000-000000000001');
insert into public.guardians(id,organization_id,user_id,first_name,last_name,status) values('e2700000-0000-0000-0000-000000000001','e1200000-0000-0000-0000-000000000001','e1100000-0000-0000-0000-000000000004','Portal','Guardian','active');
insert into public.student_guardians(id,organization_id,student_id,guardian_id,relationship_type,has_portal_access,status) values('e2800000-0000-0000-0000-000000000001','e1200000-0000-0000-0000-000000000001','e1c00000-0000-0000-0000-000000000001','e2700000-0000-0000-0000-000000000001','parent',true,'active');
insert into public.organization_memberships(id,organization_id,user_id,status,joined_at) values('e1400000-0000-0000-0000-000000000005','e1200000-0000-0000-0000-000000000001','e1100000-0000-0000-0000-000000000005','active',now());
insert into public.staff_profiles(id,organization_id,organization_membership_id,school_id,campus_id,staff_number,employment_type,status) values('e2900000-0000-0000-0000-000000000001','e1200000-0000-0000-0000-000000000001','e1400000-0000-0000-0000-000000000005','e1300000-0000-0000-0000-000000000001','e1700000-0000-0000-0000-000000000001','T1','teacher','active');
insert into public.teaching_assignments(id,organization_id,school_id,campus_id,academic_year_id,section_id,subject_id,staff_profile_id,role,starts_on,scheduled_ends_on,effective_range,status,created_by,updated_by) values('e2a00000-0000-0000-0000-000000000001','e1200000-0000-0000-0000-000000000001','e1300000-0000-0000-0000-000000000001','e1700000-0000-0000-0000-000000000001','e1800000-0000-0000-0000-000000000001','e1b00000-0000-0000-0000-000000000001','e1600000-0000-0000-0000-000000000001','e2900000-0000-0000-0000-000000000001','lead','2026-01-01','2026-12-31',daterange('2026-01-01','2026-12-31','[]'),'active','e1100000-0000-0000-0000-000000000001','e1100000-0000-0000-0000-000000000001');
select set_config('request.jwt.claims',jsonb_build_object('sub','e1100000-0000-0000-0000-000000000001','role','authenticated')::text,true);
select lives_ok($q$select public.create_transcript_calculation_policy('e1300000-0000-0000-0000-000000000001','Four point',4::numeric,2::smallint,true,false,false,array[row(1,0,100,'pass',4)::public.transcript_gpa_band_input],array[row('e1600000-0000-0000-0000-000000000001',1,1)::public.transcript_subject_credit_input])$q$,'authorized policy creation succeeds');
select is((select count(*)::int from public.transcript_calculation_policies where school_id='e1300000-0000-0000-0000-000000000001'),1,'policy root is stored once');
select is((select count(*)::int from public.transcript_gpa_bands),1,'policy band snapshot stored');
select is((select count(*)::int from public.transcript_subject_credits),1,'subject credit snapshot stored');
select is((select count(*)::int from public.event_outbox where event_type='transcript_policy.draft_created'),1,'policy creation emits exactly one event');
select is((select count(*)::int from public.audit_log a where a.command_id=(select command_id from public.event_outbox where event_type='transcript_policy.draft_created')),3,'policy creation shares one command across header, band, and credit audit evidence');
select lives_ok(format($q$select public.update_draft_transcript_calculation_policy(%L,'Four point revised',4::numeric,2::smallint,true,false,false,array[row(1,0,100,'pass',4)::public.transcript_gpa_band_input],array[row('e1600000-0000-0000-0000-000000000001',1,1)::public.transcript_subject_credit_input])$q$,(select id from public.transcript_calculation_policies where school_id='e1300000-0000-0000-0000-000000000001')),'draft policy replacement succeeds');
select is((select count(*)::int from public.audit_log a where a.command_id=(select command_id from public.event_outbox where event_type='transcript_policy.draft_updated')),5,'draft policy replacement audits removed and inserted band/credit rows plus header');
select is((select count(*)::int from public.event_outbox where event_type='transcript_policy.draft_updated'),1,'draft policy replacement emits exactly one event');
select lives_ok(format('select public.activate_transcript_calculation_policy(%L)',(select id from public.transcript_calculation_policies where school_id='e1300000-0000-0000-0000-000000000001')),'valid policy activates');
select is((select count(*)::int from public.audit_log a where a.command_id=(select command_id from public.event_outbox where event_type='transcript_policy.activated')),1,'policy activation has one audit row sharing its event command id');
select is((select status::text from public.transcript_calculation_policies where school_id='e1300000-0000-0000-0000-000000000001'),'active','policy is active');
select throws_ok($$update public.transcript_calculation_policies set activated_at=activated_at+interval '1 second' where status='active'$$,'22023','invalid transcript policy lifecycle transition','table owner cannot rewrite policy activation time');
select throws_ok($$update public.transcript_calculation_policies set activated_by='e1100000-0000-0000-0000-000000000002' where status='active'$$,'22023','invalid transcript policy lifecycle transition','table owner cannot rewrite policy activation actor');
select throws_ok($$update public.transcript_calculation_policies set name='owner rewrite' where status='active'$$,'22023','invalid transcript policy lifecycle transition','table owner cannot rewrite active policy content');
select throws_ok(format('select public.update_draft_transcript_calculation_policy(%L,%L,4::numeric,2::smallint,true,false,false,array[row(1,0,100,%L,4)::public.transcript_gpa_band_input],array[row(%L,1,1)::public.transcript_subject_credit_input])',(select id from public.transcript_calculation_policies where school_id='e1300000-0000-0000-0000-000000000001'),'Changed','pass','e1600000-0000-0000-0000-000000000001'),'22023','draft policy required','active policy content cannot be updated');
select throws_ok(format($q$insert into public.transcript_gpa_bands(organization_id,school_id,transcript_calculation_policy_id,sequence,lower_bound,upper_bound,result_state,grade_points,created_by) values('e1200000-0000-0000-0000-000000000001','e1300000-0000-0000-0000-000000000001',%L,2,0,1,'pass',1,'e1100000-0000-0000-0000-000000000001')$q$,(select id from public.transcript_calculation_policies where school_id='e1300000-0000-0000-0000-000000000001')),'22023','active and retired transcript policy rules are immutable','active policy cannot acquire forged child rules');
select is((select count(*)::int from public.event_outbox where event_type in('transcript_policy.draft_created','transcript_policy.draft_updated','transcript_policy.activated')),3,'policy lifecycle emits one event per command');
select ok(not exists(select 1 from public.event_outbox where event_type like 'transcript_policy.%' and(payload?'name'or payload?'gpa_scale'or payload?'subject_credits')),'policy events omit policy values');

-- Three-term history in one academic year, with two subjects in the middle term.
insert into public.academic_terms(id,organization_id,academic_year_id,name,sequence,start_date,end_date,status) values
 ('e1900000-0000-0000-0000-000000000002','e1200000-0000-0000-0000-000000000001','e1800000-0000-0000-0000-000000000001','Term 2',2,'2026-04-01','2026-06-30','active'),
 ('e1900000-0000-0000-0000-000000000003','e1200000-0000-0000-0000-000000000001','e1800000-0000-0000-0000-000000000001','Term 3',3,'2026-07-01','2026-09-30','active');
insert into public.subjects(id,organization_id,school_id,code,name,status) values('e1600000-0000-0000-0000-000000000002','e1200000-0000-0000-0000-000000000001','e1300000-0000-0000-0000-000000000001','SCI','Science','active');
insert into public.term_grading_configurations(id,organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,subject_id,grade_scale_id,status,activated_at,activated_by,created_by,updated_by) values
 ('e2100000-0000-0000-0000-000000000002','e1200000-0000-0000-0000-000000000001','e1300000-0000-0000-0000-000000000001','e1700000-0000-0000-0000-000000000001','e1800000-0000-0000-0000-000000000001','e1900000-0000-0000-0000-000000000002','e1b00000-0000-0000-0000-000000000001','e1600000-0000-0000-0000-000000000001','e1f00000-0000-0000-0000-000000000001','active',now(),'e1100000-0000-0000-0000-000000000001','e1100000-0000-0000-0000-000000000001','e1100000-0000-0000-0000-000000000001'),
 ('e2100000-0000-0000-0000-000000000003','e1200000-0000-0000-0000-000000000001','e1300000-0000-0000-0000-000000000001','e1700000-0000-0000-0000-000000000001','e1800000-0000-0000-0000-000000000001','e1900000-0000-0000-0000-000000000002','e1b00000-0000-0000-0000-000000000001','e1600000-0000-0000-0000-000000000002','e1f00000-0000-0000-0000-000000000001','active',now(),'e1100000-0000-0000-0000-000000000001','e1100000-0000-0000-0000-000000000001','e1100000-0000-0000-0000-000000000001'),
 ('e2100000-0000-0000-0000-000000000004','e1200000-0000-0000-0000-000000000001','e1300000-0000-0000-0000-000000000001','e1700000-0000-0000-0000-000000000001','e1800000-0000-0000-0000-000000000001','e1900000-0000-0000-0000-000000000003','e1b00000-0000-0000-0000-000000000001','e1600000-0000-0000-0000-000000000001','e1f00000-0000-0000-0000-000000000001','active',now(),'e1100000-0000-0000-0000-000000000001','e1100000-0000-0000-0000-000000000001','e1100000-0000-0000-0000-000000000001');
insert into public.term_grade_sets(id,organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,subject_id,term_grading_configuration_id,lifecycle_status,publication_state,calculation_sequence,source_fingerprint,finalized_at,finalized_by,created_by,updated_by) values
 ('e2200000-0000-0000-0000-000000000002','e1200000-0000-0000-0000-000000000001','e1300000-0000-0000-0000-000000000001','e1700000-0000-0000-0000-000000000001','e1800000-0000-0000-0000-000000000001','e1900000-0000-0000-0000-000000000002','e1b00000-0000-0000-0000-000000000001','e1600000-0000-0000-0000-000000000001','e2100000-0000-0000-0000-000000000002','finalized','unpublished',1,extensions.digest('set2m','sha256'),now(),'e1100000-0000-0000-0000-000000000001','e1100000-0000-0000-0000-000000000001','e1100000-0000-0000-0000-000000000001'),
 ('e2200000-0000-0000-0000-000000000003','e1200000-0000-0000-0000-000000000001','e1300000-0000-0000-0000-000000000001','e1700000-0000-0000-0000-000000000001','e1800000-0000-0000-0000-000000000001','e1900000-0000-0000-0000-000000000002','e1b00000-0000-0000-0000-000000000001','e1600000-0000-0000-0000-000000000002','e2100000-0000-0000-0000-000000000003','finalized','unpublished',1,extensions.digest('set2s','sha256'),now(),'e1100000-0000-0000-0000-000000000001','e1100000-0000-0000-0000-000000000001','e1100000-0000-0000-0000-000000000001'),
 ('e2200000-0000-0000-0000-000000000004','e1200000-0000-0000-0000-000000000001','e1300000-0000-0000-0000-000000000001','e1700000-0000-0000-0000-000000000001','e1800000-0000-0000-0000-000000000001','e1900000-0000-0000-0000-000000000003','e1b00000-0000-0000-0000-000000000001','e1600000-0000-0000-0000-000000000001','e2100000-0000-0000-0000-000000000004','finalized','unpublished',1,extensions.digest('set3m','sha256'),now(),'e1100000-0000-0000-0000-000000000001','e1100000-0000-0000-0000-000000000001','e1100000-0000-0000-0000-000000000001');
insert into public.term_grade_records(id,organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,subject_id,term_grading_configuration_id,term_grade_set_id,student_id,calculation_sequence,created_by) select 'e2300000-0000-0000-0000-000000000002',organization_id,school_id,campus_id,academic_year_id,'e1900000-0000-0000-0000-000000000002',section_id,subject_id,'e2100000-0000-0000-0000-000000000002','e2200000-0000-0000-0000-000000000002',student_id,1,created_by from public.term_grade_records where id='e2300000-0000-0000-0000-000000000001';
insert into public.term_grade_records(id,organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,subject_id,term_grading_configuration_id,term_grade_set_id,student_id,calculation_sequence,created_by) select 'e2300000-0000-0000-0000-000000000003',organization_id,school_id,campus_id,academic_year_id,'e1900000-0000-0000-0000-000000000002',section_id,'e1600000-0000-0000-0000-000000000002','e2100000-0000-0000-0000-000000000003','e2200000-0000-0000-0000-000000000003',student_id,1,created_by from public.term_grade_records where id='e2300000-0000-0000-0000-000000000001';
insert into public.term_grade_records(id,organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,subject_id,term_grading_configuration_id,term_grade_set_id,student_id,calculation_sequence,created_by) select 'e2300000-0000-0000-0000-000000000004',organization_id,school_id,campus_id,academic_year_id,'e1900000-0000-0000-0000-000000000003',section_id,subject_id,'e2100000-0000-0000-0000-000000000004','e2200000-0000-0000-0000-000000000004',student_id,1,created_by from public.term_grade_records where id='e2300000-0000-0000-0000-000000000001';
insert into public.term_grade_calculations(id,organization_id,term_grade_set_id,term_grade_record_id,student_id,calculation_sequence,raw_percentage,rounded_percentage,grade_scale_id,grade_scale_band_id,grade_label,result_state,contributing_assessment_count,weight_total,calculated_by) select 'e2400000-0000-0000-0000-000000000002',organization_id,'e2200000-0000-0000-0000-000000000002','e2300000-0000-0000-0000-000000000002',student_id,1,87,87,grade_scale_id,grade_scale_band_id,'Pass','pass',1,100,calculated_by from public.term_grade_calculations where id='e2400000-0000-0000-0000-000000000001';
insert into public.term_grade_calculations(id,organization_id,term_grade_set_id,term_grade_record_id,student_id,calculation_sequence,raw_percentage,rounded_percentage,grade_scale_id,grade_scale_band_id,grade_label,result_state,contributing_assessment_count,weight_total,calculated_by) select 'e2400000-0000-0000-0000-000000000003',organization_id,'e2200000-0000-0000-0000-000000000003','e2300000-0000-0000-0000-000000000003',student_id,1,86,86,grade_scale_id,grade_scale_band_id,'Pass','pass',1,100,calculated_by from public.term_grade_calculations where id='e2400000-0000-0000-0000-000000000001';
insert into public.term_grade_calculations(id,organization_id,term_grade_set_id,term_grade_record_id,student_id,calculation_sequence,raw_percentage,rounded_percentage,grade_scale_id,grade_scale_band_id,grade_label,result_state,contributing_assessment_count,weight_total,calculated_by) select 'e2400000-0000-0000-0000-000000000004',organization_id,'e2200000-0000-0000-0000-000000000004','e2300000-0000-0000-0000-000000000004',student_id,1,85,85,grade_scale_id,grade_scale_band_id,'Pass','pass',1,100,calculated_by from public.term_grade_calculations where id='e2400000-0000-0000-0000-000000000001';
insert into public.report_cards(id,organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,student_id,student_enrollment_id,student_section_placement_id,lineage_id,version,report_card_number,status,finalized_at,finalized_by,published_at,published_by,source_fingerprint,school_code,school_name,campus_code,campus_name,academic_year_name,academic_term_name,academic_term_sequence,term_start_date,term_end_date,section_code,section_name,grade_level_code,grade_level_name,student_number,student_display_name,created_by,updated_by) select 'e2500000-0000-0000-0000-000000000002',organization_id,school_id,campus_id,academic_year_id,'e1900000-0000-0000-0000-000000000002',section_id,student_id,student_enrollment_id,student_section_placement_id,'e2500000-0000-0000-0000-000000000002',1,2,'published',now(),created_by,now(),created_by,extensions.digest('card2','sha256'),school_code,school_name,campus_code,campus_name,academic_year_name,'Term 2',2,'2026-04-01','2026-06-30',section_code,section_name,grade_level_code,grade_level_name,student_number,student_display_name,created_by,updated_by from public.report_cards where id='e2500000-0000-0000-0000-000000000001';
insert into public.report_cards(id,organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,student_id,student_enrollment_id,student_section_placement_id,lineage_id,version,report_card_number,status,finalized_at,finalized_by,published_at,published_by,source_fingerprint,school_code,school_name,campus_code,campus_name,academic_year_name,academic_term_name,academic_term_sequence,term_start_date,term_end_date,section_code,section_name,grade_level_code,grade_level_name,student_number,student_display_name,created_by,updated_by) select 'e2500000-0000-0000-0000-000000000003',organization_id,school_id,campus_id,academic_year_id,'e1900000-0000-0000-0000-000000000003',section_id,student_id,student_enrollment_id,student_section_placement_id,'e2500000-0000-0000-0000-000000000003',1,3,'published',now(),created_by,now(),created_by,extensions.digest('card3','sha256'),school_code,school_name,campus_code,campus_name,academic_year_name,'Term 3',3,'2026-07-01','2026-09-30',section_code,section_name,grade_level_code,grade_level_name,student_number,student_display_name,created_by,updated_by from public.report_cards where id='e2500000-0000-0000-0000-000000000001';
insert into public.report_card_grade_snapshots(id,organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,report_card_id,student_id,subject_id,subject_code,subject_name,term_grading_configuration_id,term_grade_set_id,term_grade_record_id,term_grade_calculation_id,grade_scale_id,grade_scale_band_id,term_grade_calculation_sequence,raw_percentage,rounded_percentage,grade_label,result_state,contributing_assessment_count,weight_total,source_term_grade_fingerprint,created_by) select 'e2600000-0000-0000-0000-000000000002',organization_id,school_id,campus_id,academic_year_id,'e1900000-0000-0000-0000-000000000002',section_id,'e2500000-0000-0000-0000-000000000002',student_id,subject_id,subject_code,subject_name,'e2100000-0000-0000-0000-000000000002','e2200000-0000-0000-0000-000000000002','e2300000-0000-0000-0000-000000000002','e2400000-0000-0000-0000-000000000002',grade_scale_id,grade_scale_band_id,1,87,87,'Pass','pass',1,100,extensions.digest('grade2m','sha256'),created_by from public.report_card_grade_snapshots where id='e2600000-0000-0000-0000-000000000001';
insert into public.report_card_grade_snapshots(id,organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,report_card_id,student_id,subject_id,subject_code,subject_name,term_grading_configuration_id,term_grade_set_id,term_grade_record_id,term_grade_calculation_id,grade_scale_id,grade_scale_band_id,term_grade_calculation_sequence,raw_percentage,rounded_percentage,grade_label,result_state,contributing_assessment_count,weight_total,source_term_grade_fingerprint,created_by) select 'e2600000-0000-0000-0000-000000000003',organization_id,school_id,campus_id,academic_year_id,'e1900000-0000-0000-0000-000000000002',section_id,'e2500000-0000-0000-0000-000000000002',student_id,'e1600000-0000-0000-0000-000000000002','SCI','Science','e2100000-0000-0000-0000-000000000003','e2200000-0000-0000-0000-000000000003','e2300000-0000-0000-0000-000000000003','e2400000-0000-0000-0000-000000000003',grade_scale_id,grade_scale_band_id,1,86,86,'Pass','pass',1,100,extensions.digest('grade2s','sha256'),created_by from public.report_card_grade_snapshots where id='e2600000-0000-0000-0000-000000000001';
insert into public.report_card_grade_snapshots(id,organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,report_card_id,student_id,subject_id,subject_code,subject_name,term_grading_configuration_id,term_grade_set_id,term_grade_record_id,term_grade_calculation_id,grade_scale_id,grade_scale_band_id,term_grade_calculation_sequence,raw_percentage,rounded_percentage,grade_label,result_state,contributing_assessment_count,weight_total,source_term_grade_fingerprint,created_by) select 'e2600000-0000-0000-0000-000000000004',organization_id,school_id,campus_id,academic_year_id,'e1900000-0000-0000-0000-000000000003',section_id,'e2500000-0000-0000-0000-000000000003',student_id,subject_id,subject_code,subject_name,'e2100000-0000-0000-0000-000000000004','e2200000-0000-0000-0000-000000000004','e2300000-0000-0000-0000-000000000004','e2400000-0000-0000-0000-000000000004',grade_scale_id,grade_scale_band_id,1,85,85,'Pass','pass',1,100,extensions.digest('grade3m','sha256'),created_by from public.report_card_grade_snapshots where id='e2600000-0000-0000-0000-000000000001';

savepoint multi_term_contract;
select throws_ok($q$select public.create_transcript('e1c00000-0000-0000-0000-000000000001','e1300000-0000-0000-0000-000000000001',array[row('e1900000-0000-0000-0000-000000000001')::public.transcript_term_input,row('e1900000-0000-0000-0000-000000000003')::public.transcript_term_input],'{}')$q$,'22023','eligible published term gap requires explicit exclusion','multi-term selection cannot silently omit an eligible middle term');
select lives_ok($q$select public.create_transcript('e1c00000-0000-0000-0000-000000000001','e1300000-0000-0000-0000-000000000001',array[row('e1900000-0000-0000-0000-000000000003')::public.transcript_term_input,row('e1900000-0000-0000-0000-000000000001')::public.transcript_term_input],array[row('e1900000-0000-0000-0000-000000000002',null,'Approved whole-term omission')::public.transcript_exclusion_input])$q$,'explicit whole-term exclusion closes the selected-range gap');
select is((select array_agg(academic_term_id order by sequence)::text from public.transcript_period_snapshots),'{e1900000-0000-0000-0000-000000000001,e1900000-0000-0000-0000-000000000003}','period snapshots are chronological regardless of input order');
select lives_ok(format('select public.cancel_transcript(%L,%L)',(select id from public.transcripts),'fixture cleanup'),'multi-term draft can be cancelled');
select lives_ok($q$select public.create_transcript('e1c00000-0000-0000-0000-000000000001','e1300000-0000-0000-0000-000000000001',array[row('e1900000-0000-0000-0000-000000000002')::public.transcript_term_input],array[row('e1900000-0000-0000-0000-000000000002','e1600000-0000-0000-0000-000000000002','Approved subject omission')::public.transcript_exclusion_input])$q$,'subject exclusion succeeds when another subject remains');
select is((select count(*)::int from public.transcript_entry_snapshots e join public.transcripts t on t.id=e.transcript_id where t.status='draft'),1,'subject exclusion removes exactly the selected subject');
select is((select count(*)::int from public.transcript_exclusions e join public.transcripts t on t.id=e.transcript_id where t.status='draft' and e.exclusion_type='subject'),1,'subject exclusion evidence is retained');
rollback to savepoint multi_term_contract;

-- Command-boundary adversarial cases: malformed selections, tenant/scope RBAC,
-- inactive membership, and a deliberately late failure after all snapshots have
-- been inserted.  The late-failure assertion proves statement-level atomicity.
select throws_ok($q$select public.create_transcript('e1c00000-0000-0000-0000-000000000001','e1300000-0000-0000-0000-000000000001',array[row('e1900000-0000-0000-0000-000000000001')::public.transcript_term_input,row('e1900000-0000-0000-0000-000000000001')::public.transcript_term_input],'{}')$q$,'22023','one to 100 distinct academic terms are required','duplicate selected terms are rejected');
select throws_ok($q$select public.create_transcript('e1c00000-0000-0000-0000-000000000001','e1300000-0000-0000-0000-000000000001',array[row('00000000-0000-0000-0000-000000000099')::public.transcript_term_input],'{}')$q$,'22023','all terms must belong to the issuing school','unknown term selection is rejected');
select throws_ok($q$select public.create_transcript('e1c00000-0000-0000-0000-000000000001','e1300000-0000-0000-0000-000000000001',array[row('e1900000-0000-0000-0000-000000000001')::public.transcript_term_input],array[row('e1900000-0000-0000-0000-000000000001',null,'not both')::public.transcript_exclusion_input])$q$,'22023','an included term cannot also be excluded','whole-term exclusion cannot contradict inclusion');
select throws_ok($q$select public.create_transcript('e1c00000-0000-0000-0000-000000000001','e1300000-0000-0000-0000-000000000001',array[row('e1900000-0000-0000-0000-000000000001')::public.transcript_term_input],array[row('e1900000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000098','forged subject')::public.transcript_exclusion_input])$q$,'22023','subject exclusion must identify an eligible report-card subject','forged subject source is rejected');
insert into public.students(id,organization_id,school_id,campus_id,student_number,first_name,last_name,date_of_birth,status)
select 'e1c00000-0000-0000-0000-000000000002',organization_id,school_id,campus_id,'S2','Wrong','Student',date_of_birth,'active' from public.students where id='e1c00000-0000-0000-0000-000000000001';
select throws_ok($q$select public.create_transcript('e1c00000-0000-0000-0000-000000000002','e1300000-0000-0000-0000-000000000001',array[row('e1900000-0000-0000-0000-000000000001')::public.transcript_term_input],'{}')$q$,'22023','each included term requires exactly one live published report card','report card for a different student cannot be selected');

-- Commands discover the eligible head; callers cannot name or force an
-- unpublished, finalized-only, cancelled, or corrected predecessor. Replica
-- mode is used only to establish otherwise unreachable adversarial fixtures.
savepoint ineligible_report_card_status;
set local session_replication_role=replica;
update public.report_cards set status='draft',finalized_at=null,finalized_by=null,published_at=null,published_by=null where id='e2500000-0000-0000-0000-000000000001';
set local session_replication_role=origin;
select throws_ok($q$select public.create_transcript('e1c00000-0000-0000-0000-000000000001','e1300000-0000-0000-0000-000000000001',array[row('e1900000-0000-0000-0000-000000000001')::public.transcript_term_input],'{}')$q$,'22023','each included term requires exactly one live published report card','unpublished report card is ineligible');
rollback to savepoint ineligible_report_card_status;
savepoint finalized_report_card_status;
set local session_replication_role=replica;
update public.report_cards set status='finalized',published_at=null,published_by=null where id='e2500000-0000-0000-0000-000000000001';
set local session_replication_role=origin;
select throws_ok($q$select public.create_transcript('e1c00000-0000-0000-0000-000000000001','e1300000-0000-0000-0000-000000000001',array[row('e1900000-0000-0000-0000-000000000001')::public.transcript_term_input],'{}')$q$,'22023','each included term requires exactly one live published report card','finalized-only report card is ineligible');
rollback to savepoint finalized_report_card_status;
savepoint cancelled_report_card_status;
set local session_replication_role=replica;
update public.report_cards set status='cancelled',finalized_at=null,finalized_by=null,published_at=null,published_by=null,cancelled_at=now(),cancelled_by='e1100000-0000-0000-0000-000000000001',cancellation_reason='adversarial fixture' where id='e2500000-0000-0000-0000-000000000001';
set local session_replication_role=origin;
select throws_ok($q$select public.create_transcript('e1c00000-0000-0000-0000-000000000001','e1300000-0000-0000-0000-000000000001',array[row('e1900000-0000-0000-0000-000000000001')::public.transcript_term_input],'{}')$q$,'22023','each included term requires exactly one live published report card','cancelled report card is ineligible');
rollback to savepoint cancelled_report_card_status;
savepoint corrected_report_card_status;
set local session_replication_role=replica;
update public.report_cards set status='corrected',corrected_at=now(),corrected_by='e1100000-0000-0000-0000-000000000001',correction_reason='adversarial fixture' where id='e2500000-0000-0000-0000-000000000001';
set local session_replication_role=origin;
select throws_ok($q$select public.create_transcript('e1c00000-0000-0000-0000-000000000001','e1300000-0000-0000-0000-000000000001',array[row('e1900000-0000-0000-0000-000000000001')::public.transcript_term_input],'{}')$q$,'22023','each included term requires exactly one live published report card','corrected predecessor cannot be forced as a source');
rollback to savepoint corrected_report_card_status;

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,created_at,updated_at) values
 ('e1100000-0000-0000-0000-000000000006','00000000-0000-0000-0000-000000000000','authenticated','authenticated','inactive-transcript-admin@test','',now(),now()),
 ('e1100000-0000-0000-0000-000000000007','00000000-0000-0000-0000-000000000000','authenticated','authenticated','no-transcript-permission@test','',now(),now());
insert into public.organizations(id,name,slug) values('d1200000-0000-0000-0000-000000000001','Other Transcript Tenant','other-transcript-tenant');
insert into public.schools(id,organization_id,name,code) values('d1300000-0000-0000-0000-000000000001','d1200000-0000-0000-0000-000000000001','Other School','OTHER');
insert into public.campuses(id,organization_id,school_id,name,code) values('d1700000-0000-0000-0000-000000000001','d1200000-0000-0000-0000-000000000001','d1300000-0000-0000-0000-000000000001','Other Campus','OTHER');
insert into public.students(id,organization_id,school_id,campus_id,student_number,first_name,last_name,date_of_birth,status) values('d1c00000-0000-0000-0000-000000000001','d1200000-0000-0000-0000-000000000001','d1300000-0000-0000-0000-000000000001','d1700000-0000-0000-0000-000000000001','OTHER-1','Other','Student','2018-01-01','active');
insert into public.organization_memberships(id,organization_id,user_id,status,joined_at,left_at) values
 ('e1400000-0000-0000-0000-000000000006','e1200000-0000-0000-0000-000000000001','e1100000-0000-0000-0000-000000000006','left',now()-interval '2 days',now()-interval '1 day'),
 ('e1400000-0000-0000-0000-000000000007','e1200000-0000-0000-0000-000000000001','e1100000-0000-0000-0000-000000000007','active',now(),null);
select set_config('request.jwt.claims',jsonb_build_object('sub','e1100000-0000-0000-0000-000000000006','role','authenticated')::text,true);
select throws_ok($q$select public.create_transcript('e1c00000-0000-0000-0000-000000000001','e1300000-0000-0000-0000-000000000001',array[row('e1900000-0000-0000-0000-000000000001')::public.transcript_term_input],'{}')$q$,'42501','transcripts.manage permission is required','inactive administrative membership is denied');
select set_config('request.jwt.claims',jsonb_build_object('sub','e1100000-0000-0000-0000-000000000007','role','authenticated')::text,true);
select throws_ok($q$select public.create_transcript('e1c00000-0000-0000-0000-000000000001','e1300000-0000-0000-0000-000000000001',array[row('e1900000-0000-0000-0000-000000000001')::public.transcript_term_input],'{}')$q$,'42501','transcripts.manage permission is required','active membership without transcripts.manage is denied');
select set_config('request.jwt.claims',jsonb_build_object('sub','e1100000-0000-0000-0000-000000000001','role','authenticated')::text,true);
select throws_ok($q$select public.create_transcript('d1c00000-0000-0000-0000-000000000001','d1300000-0000-0000-0000-000000000001',array[row('e1900000-0000-0000-0000-000000000001')::public.transcript_term_input],'{}')$q$,'42501','transcripts.manage permission is required','cross-tenant transcript command is denied before source disclosure');
select throws_ok($q$select public.create_transcript('e1c00000-0000-0000-0000-000000000001','d1300000-0000-0000-0000-000000000001',array[row('e1900000-0000-0000-0000-000000000001')::public.transcript_term_input],'{}')$q$,'22023','student and school must share organization','wrong-school student/source pairing is rejected');
select throws_ok($q$update public.report_cards set campus_id='d1700000-0000-0000-0000-000000000001' where id='e2500000-0000-0000-0000-000000000001'$q$,'22023','report-card immutable fields cannot change','cross-campus source forgery stops at report-card immutability boundary');

create function app_auth.test_reject_late_transcript_audit() returns trigger language plpgsql set search_path='' as $$begin if new.action='transcript.draft_created' then raise exception using errcode='P0001',message='induced late audit failure'; end if; return new; end$$;
create trigger test_reject_late_transcript_audit before insert on public.audit_log for each row execute function app_auth.test_reject_late_transcript_audit();
select throws_ok($q$select public.create_transcript('e1c00000-0000-0000-0000-000000000001','e1300000-0000-0000-0000-000000000001',array[row('e1900000-0000-0000-0000-000000000001')::public.transcript_term_input],'{}')$q$,'P0001','induced late audit failure','late audit failure escapes the command');
select is((select count(*)::int from public.transcripts),0,'late failure rolls back transcript header');
select is((select count(*)::int from public.transcript_lineages),0,'late failure rolls back lineage');
select is((select count(*)::int from public.transcript_period_snapshots),0,'late failure rolls back periods');
select is((select count(*)::int from public.transcript_entry_snapshots),0,'late failure rolls back entries');
select is((select count(*)::int from public.event_outbox where event_type like 'transcript.%'),0,'late failure emits no transcript outbox event');
select is((select count(*)::int from public.audit_log where action like 'transcript.%'),0,'late failure retains no transcript audit rows');
drop trigger test_reject_late_transcript_audit on public.audit_log;
drop function app_auth.test_reject_late_transcript_audit();

savepoint no_policy_contract;
select lives_ok(format('select public.retire_transcript_calculation_policy(%L)',(select id from public.transcript_calculation_policies where status='active')),'active policy can be retired for no-policy fixture');
select throws_ok($$update public.transcript_calculation_policies set retired_at=retired_at+interval '1 second' where status='retired'$$,'22023','retired transcript policy is immutable','table owner cannot rewrite policy retirement time');
select throws_ok($$update public.transcript_calculation_policies set retired_by='e1100000-0000-0000-0000-000000000002' where status='retired'$$,'22023','retired transcript policy is immutable','table owner cannot rewrite policy retirement actor');
select throws_ok($$update public.transcript_calculation_policies set status='active',retired_at=null,retired_by=null where status='retired'$$,'22023','retired transcript policy is immutable','retired policy cannot be reactivated by table owner');
select lives_ok($q$select public.create_transcript('e1c00000-0000-0000-0000-000000000001','e1300000-0000-0000-0000-000000000001',array[row('e1900000-0000-0000-0000-000000000001')::public.transcript_term_input],'{}')$q$,'transcript can be constructed without a policy');
select ok((select attempted_credits is null and earned_credits is null and cumulative_gpa is null and gpa_quality_points is null and transcript_calculation_policy_id is null from public.transcripts),'no-policy transcript keeps every credit and GPA summary null');
select ok((select attempted_credits is null and earned_credits is null and grade_points is null and quality_points is null from public.transcript_entry_snapshots),'no-policy entry keeps every credit and GPA value null');
rollback to savepoint no_policy_contract;

select lives_ok($q$select public.create_transcript('e1c00000-0000-0000-0000-000000000001','e1300000-0000-0000-0000-000000000001',array[row('e1900000-0000-0000-0000-000000000001')::public.transcript_term_input],'{}')$q$,'eligible published history creates a draft');
select is((select count(*)::int from public.transcripts),1,'one transcript version created');
select is((select count(*)::int from public.transcript_period_snapshots),1,'one selected period snapshotted');
select is((select count(*)::int from public.transcript_entry_snapshots),1,'one subject grade snapshotted');
select is((select cumulative_gpa from public.transcripts),4.00::numeric,'active policy snapshots GPA');
select is((select earned_credits from public.transcripts),1.0000::numeric,'active policy snapshots earned credits');
select throws_ok(format('select public.return_transcript_to_draft(%L,%L)',(select id from public.transcripts),'invalid draft return'),'22023','reviewed transcript required','draft cannot transition to draft through return command');
select set_config('request.jwt.claims',jsonb_build_object('sub','e1100000-0000-0000-0000-000000000002','role','authenticated')::text,true);
select throws_ok(format('select public.issue_transcript(%L,%L)',(select id from public.transcripts),'invalid draft issue'),'40001','transcript issuance state changed; retry','draft cannot be issued without review');
select throws_ok(format('select * from public.correct_transcript(%L,%L)',(select id from public.transcripts),'invalid draft correction'),'40001','transcript issuance state changed; retry','draft cannot be corrected');
select set_config('request.jwt.claims',jsonb_build_object('sub','e1100000-0000-0000-0000-000000000001','role','authenticated')::text,true);
select throws_ok($q$update public.transcripts set student_id='d1c00000-0000-0000-0000-000000000001' where status='draft'$q$,'22023','draft transcript identity is immutable','transcript student provenance cannot be forged');
select throws_ok($q$update public.transcripts set school_id='d1300000-0000-0000-0000-000000000001' where status='draft'$q$,'22023','draft transcript identity is immutable','transcript school provenance cannot be forged');
select throws_ok($q$insert into public.transcript_period_snapshots select(jsonb_populate_record(null::public.transcript_period_snapshots,to_jsonb(p)||jsonb_build_object('id',gen_random_uuid(),'sequence',99,'student_id','d1c00000-0000-0000-0000-000000000001','report_card_id','e2500000-0000-0000-0000-000000000002'))).* from public.transcript_period_snapshots p limit 1$q$,'23503',null,'period student provenance cannot be forged');
select throws_ok($q$insert into public.transcript_period_snapshots select(jsonb_populate_record(null::public.transcript_period_snapshots,to_jsonb(p)||jsonb_build_object('id',gen_random_uuid(),'sequence',99,'school_id','d1300000-0000-0000-0000-000000000001','report_card_id','e2500000-0000-0000-0000-000000000002'))).* from public.transcript_period_snapshots p limit 1$q$,'23503',null,'period school provenance cannot be forged');
select throws_ok($q$insert into public.transcript_period_snapshots select(jsonb_populate_record(null::public.transcript_period_snapshots,to_jsonb(p)||jsonb_build_object('id',gen_random_uuid(),'sequence',99,'report_card_id','e2500000-0000-0000-0000-000000000002'))).* from public.transcript_period_snapshots p limit 1$q$,'23503',null,'period report-card provenance cannot be forged');
select throws_ok($q$insert into public.transcript_entry_snapshots select(jsonb_populate_record(null::public.transcript_entry_snapshots,to_jsonb(e)||jsonb_build_object('id',gen_random_uuid(),'sequence',99,'student_id','d1c00000-0000-0000-0000-000000000001','report_card_id','e2500000-0000-0000-0000-000000000002','report_card_grade_snapshot_id','e2600000-0000-0000-0000-000000000002'))).* from public.transcript_entry_snapshots e limit 1$q$,'23503',null,'entry student provenance cannot be forged');
select throws_ok($q$insert into public.transcript_entry_snapshots select(jsonb_populate_record(null::public.transcript_entry_snapshots,to_jsonb(e)||jsonb_build_object('id',gen_random_uuid(),'sequence',99,'report_card_id','e2500000-0000-0000-0000-000000000002','report_card_grade_snapshot_id','e2600000-0000-0000-0000-000000000002'))).* from public.transcript_entry_snapshots e limit 1$q$,'23503',null,'entry report-card provenance cannot be forged');
select throws_ok(format($q$insert into public.transcript_exclusions(organization_id,school_id,student_id,transcript_id,exclusion_type,academic_term_id,subject_id,report_card_id,report_card_grade_snapshot_id,reason,excluded_by) values('e1200000-0000-0000-0000-000000000001','e1300000-0000-0000-0000-000000000001','d1c00000-0000-0000-0000-000000000001',%L,'subject','e1900000-0000-0000-0000-000000000001','e1600000-0000-0000-0000-000000000001','e2500000-0000-0000-0000-000000000001','e2600000-0000-0000-0000-000000000001','forged provenance','e1100000-0000-0000-0000-000000000001')$q$,(select id from public.transcripts)),'23503',null,'exclusion student provenance cannot be forged');
select throws_ok(format($q$update public.transcripts set transcript_calculation_policy_id='00000000-0000-0000-0000-000000000099',policy_lineage_id='00000000-0000-0000-0000-000000000099' where id=%L$q$,(select id from public.transcripts)),'22023','draft transcript identity is immutable','transcript policy provenance cannot be forged');

savepoint stale_review_source;
update public.report_cards set status='corrected',published_at=null,published_by=null,corrected_at=now(),corrected_by='e1100000-0000-0000-0000-000000000001',correction_reason='stale before review',updated_by='e1100000-0000-0000-0000-000000000001' where id='e2500000-0000-0000-0000-000000000001';
select throws_ok(format('select public.review_transcript(%L,%L)',(select id from public.transcripts),'must reject stale review'),'40001','transcript sources changed; rebuild and retry','review rejects a corrected source report card');
rollback to savepoint stale_review_source;
select lives_ok(format('select public.review_transcript(%L,%L)',(select id from public.transcripts),'ready for issue'),'authorized review succeeds');
select throws_ok(format('select public.review_transcript(%L,%L)',(select id from public.transcripts),'invalid repeated review'),'40001','transcript review state changed; retry','reviewed transcript cannot be reviewed twice');
select throws_ok(format($q$select public.rebuild_transcript(%L,array[row('e1900000-0000-0000-0000-000000000001')::public.transcript_term_input],'{}','invalid reviewed rebuild')$q$,(select id from public.transcripts)),'22023','current issued transcript required','reviewed transcript cannot be rebuilt as an issued head');
select throws_ok(format('select public.issue_transcript(%L,%L)',(select id from public.transcripts),'issue now'),'42501','reviewer and issuer must be different users','same-user issuance denied');

savepoint stale_issue_source;
update public.report_cards set status='corrected',published_at=null,published_by=null,corrected_at=now(),corrected_by='e1100000-0000-0000-0000-000000000001',correction_reason='stale before issue',updated_by='e1100000-0000-0000-0000-000000000001' where id='e2500000-0000-0000-0000-000000000001';
select set_config('request.jwt.claims',jsonb_build_object('sub','e1100000-0000-0000-0000-000000000002','role','authenticated')::text,true);
select throws_ok(format('select public.issue_transcript(%L,%L)',(select id from public.transcripts),'must reject stale issue'),'40001','transcript sources changed; rebuild and retry','issue rejects a corrected source report card');
rollback to savepoint stale_issue_source;

-- Failure after counter allocation, predecessor checks, and transcript update must
-- roll back every state, number, audit, and outbox mutation.
select set_config('request.jwt.claims',jsonb_build_object('sub','e1100000-0000-0000-0000-000000000002','role','authenticated')::text,true);
create function app_auth.test_reject_late_transcript_issue_audit() returns trigger language plpgsql set search_path='' as $$begin if new.action='transcript.issued' then raise exception using errcode='P0001',message='induced late issue failure'; end if; return new; end$$;
create trigger test_reject_late_transcript_issue_audit before insert on public.audit_log for each row execute function app_auth.test_reject_late_transcript_issue_audit();
select throws_ok(format('select public.issue_transcript(%L,%L)',(select id from public.transcripts),'late failure'),'P0001','induced late issue failure','late issue failure is surfaced');
select is((select status::text from public.transcripts),'reviewed','late issue failure restores reviewed state');
select is((select transcript_number from public.transcripts),null::bigint,'late issue failure restores null transcript number');
select is((select count(*)::int from public.transcript_number_counters),0,'late issue failure rolls back school counter allocation');
select is((select count(*)::int from public.audit_log where action='transcript.issued'),0,'late issue failure writes no issue audit');
select is((select count(*)::int from public.event_outbox where event_type='transcript.issued'),0,'late issue failure writes no issue event');
drop trigger test_reject_late_transcript_issue_audit on public.audit_log;
drop function app_auth.test_reject_late_transcript_issue_audit();
select set_config('request.jwt.claims',jsonb_build_object('sub','e1100000-0000-0000-0000-000000000002','role','authenticated')::text,true);
select lives_ok(format('select public.issue_transcript(%L,%L)',(select id from public.transcripts),'official issue'),'different authorized issuer succeeds');
select is((select status::text from public.transcripts),'issued','transcript is issued');
select is((select transcript_number from public.transcripts),1::bigint,'first number allocated at issue');
select is((select student_date_of_birth from public.transcripts),'2018-01-01'::date,'DOB snapshotted only at issue');
select throws_ok(format('select public.review_transcript(%L,%L)',(select id from public.transcripts),'invalid issued review'),'40001','transcript review state changed; retry','issued transcript cannot return to review');
select throws_ok(format('select public.return_transcript_to_draft(%L,%L)',(select id from public.transcripts),'invalid issued return'),'22023','reviewed transcript required','issued transcript cannot return to draft');
select throws_ok(format('select public.cancel_transcript(%L,%L)',(select id from public.transcripts),'invalid issued cancellation'),'22023','draft or reviewed transcript required','issued transcript cannot be cancelled');
select throws_ok(format('select public.issue_transcript(%L,%L)',(select id from public.transcripts),'invalid repeated issue'),'40001','transcript issuance state changed; retry','issued transcript cannot be issued twice');
select throws_ok(format('select * from public.correct_transcript(%L,%L)',(select id from public.transcripts),'invalid direct correction'),'40001','transcript issuance state changed; retry','issued transcript cannot be corrected without a reviewed replacement');
select throws_ok($$update public.transcripts set school_name='forged history' where status='issued'$$,'22023','invalid transcript lifecycle transition','table owner cannot update issued transcript history');
select throws_ok($$update public.transcripts set reviewed_by='e1100000-0000-0000-0000-000000000002' where status='issued'$$,'22023','invalid transcript lifecycle transition','table owner cannot rewrite issued reviewer attribution');
select throws_ok($$update public.transcripts set issued_at=issued_at+interval '1 second' where status='issued'$$,'22023','invalid transcript lifecycle transition','table owner cannot rewrite issuance timestamp');
select throws_ok($$update public.transcripts set issuance_reason='owner rewrite' where status='issued'$$,'22023','invalid transcript lifecycle transition','table owner cannot rewrite issuance reason');
select throws_ok($$update public.transcripts set transcript_number=transcript_number+100 where status='issued'$$,'22023','invalid transcript lifecycle transition','table owner cannot rewrite transcript number');
select throws_ok($$update public.transcripts set student_date_of_birth=student_date_of_birth+1 where status='issued'$$,'22023','invalid transcript lifecycle transition','table owner cannot rewrite issued DOB snapshot');
select throws_ok($$update public.transcripts set status='superseded',superseded_at=now(),superseded_by='e1100000-0000-0000-0000-000000000002',supersession_reason='forged transition',issued_by='e1100000-0000-0000-0000-000000000001' where status='issued'$$,'22023','invalid transcript supersession transition','issued terminal transition cannot rewrite issuer attribution');
savepoint owner_superseded_terminal;
select lives_ok($$update public.transcripts set status='superseded',superseded_at=now(),superseded_by='e1100000-0000-0000-0000-000000000002',supersession_reason='exact owner transition fixture',updated_by='e1100000-0000-0000-0000-000000000002' where status='issued'$$,'exact issued-to-superseded metadata is the only permitted owner terminal transition');
select throws_ok($$update public.transcripts set supersession_reason='rewritten terminal reason' where status='superseded'$$,'22023','terminal transcript history is immutable','table owner cannot rewrite superseded rows');
rollback to savepoint owner_superseded_terminal;
select throws_ok($$delete from public.transcripts where status='issued'$$,'22023','transcript history rows are immutable','table owner cannot delete issued transcript history');
select throws_ok($$update public.transcript_period_snapshots set academic_term_name='forged history'$$,'22023','transcript snapshot rows are immutable','table owner cannot update immutable period history');
select throws_ok($$delete from public.transcript_entry_snapshots$$,'22023','transcript snapshot rows are immutable','table owner cannot delete immutable entry history');
select is((select first_academic_term from public.transcript_current_versions),'Term 1','current view exposes deterministic first academic term');
select is((select last_academic_term from public.transcript_current_versions),'Term 1','current view exposes deterministic last academic term');
select ok(not exists(select 1 from public.event_outbox where event_type like 'transcript.%' and(payload?'student_display_name'or payload?'student_date_of_birth'or payload?'grade_label'or payload?'cumulative_gpa'or payload?'earned_credits'or payload?'reason')),'transcript events exclude private academic and identity facts');
select ok(not exists(select 1 from public.event_outbox where event_type like 'transcript.%' and lower(payload::text)~'(date_of_birth|student_display_name|student_number|school_name|grade_label|raw_percentage|rounded_percentage|cumulative_gpa|quality_points|attempted_credits|earned_credits|exclusion|reason|fingerprint)'),'all transcript event payloads omit names, DOB, grades, GPA, credits, exclusions, reasons, and fingerprints');
select ok(not exists(select 1 from public.audit_log where entity_type='transcript' and(coalesce(before_data->>'student_date_of_birth','') not in('','[REDACTED]')or coalesce(after_data->>'student_date_of_birth','') not in('','[REDACTED]'))),'transcript audit redacts date of birth');
select is((select count(*)::int from public.event_outbox where event_type='transcript.draft_created'),1,'successful root creation emits exactly one outbox row');
select is((select count(*)::int from public.audit_log a where a.command_id=(select command_id from public.event_outbox where event_type='transcript.draft_created')),3,'root creation command has exact header, period, and entry audit cardinality');
select is((select count(*)::int from public.audit_log where action='transcript.reviewed'),1,'review command writes exactly one audit row');
select is((select count(*)::int from public.event_outbox where event_type='transcript.reviewed'),1,'review command emits exactly one outbox row');
select is((select count(*)::int from public.audit_log where action='transcript.issued'),1,'issue command writes exactly one audit row');
select is((select count(*)::int from public.event_outbox where event_type='transcript.issued'),1,'issue command emits exactly one outbox row');
select lives_ok(format($q$select public.rebuild_transcript(%L,array[row('e1900000-0000-0000-0000-000000000001')::public.transcript_term_input],'{}','routine rebuild')$q$,(select id from public.transcripts where status='issued')),'rebuild appends a draft while issue remains current');
select is((select count(*)::int from public.transcripts),2,'rebuild appends one version');
select is((select count(*)::int from public.transcripts where status='issued'),1,'rebuild does not displace current issue');
select lives_ok(format('select public.cancel_transcript(%L,%L)',(select id from public.transcripts where status='draft'),'cancel duplicate request'),'draft successor cancellation succeeds');
select is((select status::text from public.transcripts order by version desc limit 1),'cancelled','cancelled candidate is terminal');
select throws_ok($$update public.transcripts set cancellation_reason='rewritten terminal reason' where status='cancelled'$$,'22023','terminal transcript history is immutable','table owner cannot rewrite cancelled rows');
select lives_ok(format($q$select public.rebuild_transcript(%L,array[row('e1900000-0000-0000-0000-000000000001')::public.transcript_term_input],'{}','correction rebuild')$q$,(select id from public.transcripts where status='issued')),'rebuild after cancellation creates next linear version');
select is((select max(version) from public.transcripts),3,'cancelled candidates still preserve monotonic versions');
select lives_ok(format('select public.review_transcript(%L,%L)',(select id from public.transcripts where status='draft'),'correction reviewed'),'issuer account reviews correction candidate');
insert into auth.users(id,instance_id,aud,role,email,encrypted_password,created_at,updated_at) values('e1100000-0000-0000-0000-000000000008','00000000-0000-0000-0000-000000000000','authenticated','authenticated','transcript-manage-only@test','',now(),now());
insert into auth.users(id,instance_id,aud,role,email,encrypted_password,created_at,updated_at) values('e1100000-0000-0000-0000-000000000009','00000000-0000-0000-0000-000000000000','authenticated','authenticated','transcript-correct-only@test','',now(),now());
insert into public.organization_memberships(id,organization_id,user_id,status,joined_at) values('e1400000-0000-0000-0000-000000000008','e1200000-0000-0000-0000-000000000001','e1100000-0000-0000-0000-000000000008','active',now());
insert into public.organization_memberships(id,organization_id,user_id,status,joined_at) values('e1400000-0000-0000-0000-000000000009','e1200000-0000-0000-0000-000000000001','e1100000-0000-0000-0000-000000000009','active',now());
insert into public.roles(id,organization_id,code,name) values('e1500000-0000-0000-0000-000000000008','e1200000-0000-0000-0000-000000000001','TRANSCRIPT_MANAGE_ONLY','Transcript Manage Only');
insert into public.roles(id,organization_id,code,name) values('e1500000-0000-0000-0000-000000000009','e1200000-0000-0000-0000-000000000001','TRANSCRIPT_CORRECT_ONLY','Transcript Correct Only');
insert into public.role_permissions(organization_id,role_id,permission_id) select 'e1200000-0000-0000-0000-000000000001','e1500000-0000-0000-0000-000000000008',id from public.permissions where code='transcripts.manage';
insert into public.role_permissions(organization_id,role_id,permission_id) select 'e1200000-0000-0000-0000-000000000001','e1500000-0000-0000-0000-000000000009',id from public.permissions where code='transcripts.correct';
insert into public.role_assignments(organization_id,organization_membership_id,role_id,school_id) values('e1200000-0000-0000-0000-000000000001','e1400000-0000-0000-0000-000000000008','e1500000-0000-0000-0000-000000000008','e1300000-0000-0000-0000-000000000001');
insert into public.role_assignments(organization_id,organization_membership_id,role_id,school_id) values('e1200000-0000-0000-0000-000000000001','e1400000-0000-0000-0000-000000000009','e1500000-0000-0000-0000-000000000009','e1300000-0000-0000-0000-000000000001');
select set_config('request.jwt.claims',jsonb_build_object('sub','e1100000-0000-0000-0000-000000000008','role','authenticated')::text,true);
select throws_ok(format('select * from public.correct_transcript(%L,%L)',(select id from public.transcripts where status='reviewed'),'unauthorized correction'),'42501','transcripts.correct permission is required','correction requires transcripts.correct in addition to transcripts.manage');
select set_config('request.jwt.claims',jsonb_build_object('sub','e1100000-0000-0000-0000-000000000009','role','authenticated')::text,true);
select throws_ok(format('select * from public.correct_transcript(%L,%L)',(select id from public.transcripts where status='reviewed'),'unauthorized correction'),'42501','transcripts.manage permission is required','transcripts.correct alone cannot correct without transcripts.manage');
select set_config('request.jwt.claims',jsonb_build_object('sub','e1100000-0000-0000-0000-000000000001','role','authenticated')::text,true);
select lives_ok(format('select * from public.correct_transcript(%L,%L)',(select id from public.transcripts where status='reviewed'),'correct official record'),'separate correct-authorized issuer completes correction');
select is((select count(*)::int from public.transcripts where status='corrected'),1,'prior issue becomes corrected');
select throws_ok($$update public.transcripts set correction_reason='rewritten terminal reason' where status='corrected'$$,'22023','terminal transcript history is immutable','table owner cannot rewrite corrected rows');
select is((select transcript_number from public.transcripts where status='issued'),2::bigint,'correction receives a new school number');
select is((select count(*)::int from public.transcripts where status='issued'),1,'correction leaves one current issued head');
update public.report_cards set status='corrected',corrected_at=now(),corrected_by='e1100000-0000-0000-0000-000000000001',correction_reason='source corrected',updated_by='e1100000-0000-0000-0000-000000000001' where id='e2500000-0000-0000-0000-000000000001';
select is((select is_stale from public.transcript_current_versions),true,'source correction derives staleness without transcript mutation');
set local role authenticated;
select set_config('request.jwt.claims',jsonb_build_object('sub','e1100000-0000-0000-0000-000000000003','role','authenticated')::text,true);
select is((select count(*)::int from public.transcript_current_versions),1,'active student reads own current issue');
select is((select count(*)::int from public.transcripts),1,'student cannot read corrected or cancelled history');
select throws_ok($$select student_date_of_birth from public.transcripts$$,'42501','permission denied for table transcripts','student cannot select DOB column');
select set_config('request.jwt.claims',jsonb_build_object('sub','e1100000-0000-0000-0000-000000000004','role','authenticated')::text,true);
select is((select count(*)::int from public.transcript_current_versions),1,'active portal guardian reads linked current issue');
reset role;
savepoint inactive_student_portal;
update public.students set status='inactive' where id='e1c00000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims',jsonb_build_object('sub','e1100000-0000-0000-0000-000000000003','role','authenticated')::text,true);
select is((select count(*)::int from public.transcript_current_versions),0,'inactive student loses current-issued self-service');
reset role;
rollback to savepoint inactive_student_portal;
savepoint inactive_guardian_portal;
update public.guardians set status='inactive' where id='e2700000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims',jsonb_build_object('sub','e1100000-0000-0000-0000-000000000004','role','authenticated')::text,true);
select is((select count(*)::int from public.transcript_current_versions),0,'inactive guardian loses current-issued access');
reset role;
rollback to savepoint inactive_guardian_portal;
savepoint inactive_guardian_link;
update public.student_guardians set status='inactive' where id='e2800000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims',jsonb_build_object('sub','e1100000-0000-0000-0000-000000000004','role','authenticated')::text,true);
select is((select count(*)::int from public.transcript_current_versions),0,'inactive guardian link loses current-issued access');
reset role;
rollback to savepoint inactive_guardian_link;
savepoint disabled_guardian_portal;
update public.student_guardians set has_portal_access=false where id='e2800000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims',jsonb_build_object('sub','e1100000-0000-0000-0000-000000000004','role','authenticated')::text,true);
select is((select count(*)::int from public.transcript_current_versions),0,'portal-disabled guardian link loses current-issued access');
reset role;
rollback to savepoint disabled_guardian_portal;
set local role authenticated;
select set_config('request.jwt.claims',jsonb_build_object('sub','e1100000-0000-0000-0000-000000000005','role','authenticated')::text,true);
select is((select count(*)::int from public.transcripts),0,'teacher assignment alone grants no transcript access');
reset role;
select set_config('request.jwt.claims','',true);

select * from finish();
rollback;
