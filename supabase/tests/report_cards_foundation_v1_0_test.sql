begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

select has_type('public','report_card_status','report-card lifecycle enum exists');
select has_type('public','report_card_comment_type','comment type exists');
select has_type('public','report_card_signoff_type','sign-off type exists');
select has_type('public','report_card_batch_status','batch status exists');
select has_type('public','report_card_batch_student_input','typed batch student input exists');
select is((select enum_range(null::public.report_card_status)::text),'{draft,finalized,published,corrected,cancelled}','card lifecycle is exact');
select is((select enum_range(null::public.report_card_signoff_type)::text),'{subject_teacher,homeroom_teacher,administrator_reviewer,administrator_correction_certification}','sign-off types are exact');

select has_table('public','report_card_batches','batch table exists');
select has_table('public','report_cards','aggregate root exists');
select has_table('public','report_card_grade_snapshots','grade snapshot exists');
select has_table('public','report_card_grade_sources','grade provenance exists');
select has_table('public','report_card_attendance_snapshots','attendance summary exists');
select has_table('public','report_card_attendance_sources','attendance provenance exists');
select has_table('public','report_card_comments','comment history exists');
select has_table('public','report_card_signoffs','sign-off history exists');
select has_table('public','report_card_batch_items','batch items exist');
select is((select count(*)::int from public.permissions where code like 'report_cards.%'),3,'three report-card permissions seeded');

select ok((select bool_and(c.relrowsecurity and c.relforcerowsecurity) from pg_class c where c.oid=any(array[
 'public.report_card_batches'::regclass,'public.report_cards'::regclass,'public.report_card_grade_snapshots'::regclass,
 'public.report_card_grade_sources'::regclass,'public.report_card_attendance_snapshots'::regclass,
 'public.report_card_attendance_sources'::regclass,'public.report_card_comments'::regclass,
 'public.report_card_signoffs'::regclass,'public.report_card_batch_items'::regclass])),'all nine tables force RLS');
select ok(not has_table_privilege('authenticated','public.report_cards','INSERT,UPDATE,DELETE,TRUNCATE'),'root is SELECT-only');
select ok(not has_table_privilege('authenticated','public.report_card_grade_snapshots','INSERT,UPDATE,DELETE,TRUNCATE'),'grade snapshots are SELECT-only');
select ok(not has_table_privilege('authenticated','public.report_card_signoffs','INSERT,UPDATE,DELETE,TRUNCATE'),'sign-offs are SELECT-only');
select ok(not has_table_privilege('anon','public.report_cards','SELECT'),'anonymous table read denied');
select has_index('public','report_cards','report_cards_live_lineage_key','one live lineage head');
select has_index('public','report_cards','report_cards_live_student_context_key','one live student context');
select has_index('public','report_cards','report_cards_one_successor_key','correction history cannot branch');

create temp table expected_report_card_rpcs(signature text) on commit drop;
insert into expected_report_card_rpcs values
 ('public.create_report_card(uuid,uuid,uuid)'),
 ('public.create_report_card_batch(uuid,uuid,report_card_batch_student_input[])'),
 ('public.save_report_card_comment(uuid,report_card_comment_type,uuid,text)'),
 ('public.withdraw_report_card_comment(uuid,text)'),
 ('public.sign_report_card(uuid,report_card_signoff_type,uuid)'),
 ('public.revoke_report_card_signoff(uuid,text)'),
 ('public.review_report_card_batch(uuid)'),
 ('public.finalize_report_card(uuid)'),
 ('public.publish_report_card(uuid)'),
 ('public.cancel_draft_report_card(uuid,text)'),
 ('public.correct_report_card(uuid,text)'),
 ('public.cancel_report_card_batch(uuid,text)');
select ok(not exists(select 1 from expected_report_card_rpcs e where to_regprocedure(e.signature) is null),'all twelve typed RPCs exist');
select ok(not exists(select 1 from expected_report_card_rpcs e join pg_proc p on p.oid=to_regprocedure(e.signature)
 where pg_get_userbyid(p.proowner)<>'postgres' or not p.prosecdef or not exists(select 1 from unnest(p.proconfig) c where c like 'search_path=%')),'RPC ownership and empty search path are exact');
select ok(not exists(select 1 from expected_report_card_rpcs e join pg_proc p on p.oid=to_regprocedure(e.signature)
 where has_function_privilege('anon',p.oid,'EXECUTE') or has_function_privilege('service_role',p.oid,'EXECUTE') or not has_function_privilege('authenticated',p.oid,'EXECUTE')),'public RPC grants are exact');
select ok(not has_function_privilege('authenticated','app_auth.build_report_card(uuid,uuid,uuid,uuid,uuid,uuid,uuid,report_card_status)','EXECUTE'),'private builder denied');
select ok(has_function_privilege('authenticated','app_auth.can_read_report_card_subject(uuid,uuid)','EXECUTE') and not has_function_privilege('anon','app_auth.can_read_report_card_subject(uuid,uuid)','EXECUTE'),'RLS helper is authenticated-only');

set local role anon;
select throws_ok($$select public.create_report_card(gen_random_uuid(),gen_random_uuid(),gen_random_uuid())$$,'42501','permission denied for function create_report_card','anonymous creation denied');
reset role;

select throws_ok($$insert into public.report_cards(id) values(gen_random_uuid())$$,'23502',null,'incomplete forged root rejected');
select throws_ok($$insert into public.report_card_signoffs(id) values(gen_random_uuid())$$,'23502',null,'incomplete forged sign-off rejected');

-- Exact provenance, wrapper, fingerprint, and lock contracts are independently visible.
select has_column('public','report_card_comments','author_membership_id','comments retain membership provenance');
select has_column('public','report_card_signoffs','signer_membership_id','sign-offs retain membership provenance');
select ok(exists(select 1 from pg_constraint where conrelid='public.report_card_comments'::regclass and contype='f'
 and pg_get_constraintdef(oid) like '%author_user_id, author_membership_id%'),'comment user and membership are composite-bound');
select ok(exists(select 1 from pg_constraint where conrelid='public.report_card_signoffs'::regclass and contype='f'
 and pg_get_constraintdef(oid) like '%signer_user_id, signer_membership_id%'),'sign-off user and membership are composite-bound');
select ok(position('sch.name' in pg_get_functiondef('app_auth.report_card_source_fingerprint(uuid,uuid,uuid)'::regprocedure))>0
 and position('st.student_number' in pg_get_functiondef('app_auth.report_card_source_fingerprint(uuid,uuid,uuid)'::regprocedure))>0
 and position('grade_scale_band_id' in pg_get_functiondef('app_auth.report_card_source_fingerprint(uuid,uuid,uuid)'::regprocedure))>0,
 'canonical fingerprint includes display and grade provenance');
select ok(position('lock_report_card_context' in pg_get_functiondef('app_auth.lock_report_card_aggregate(uuid)'::regprocedure))>0
 and position('FOR UPDATE' in upper(pg_get_functiondef('app_auth.lock_report_card_context(uuid,uuid,uuid[])'::regprocedure)))>0,
 'aggregate locking delegates to parent-first context locking before report-card locks');
select ok(position('lock_academic_snapshot_domain' in pg_get_functiondef('app_auth.lock_report_card_context(uuid,uuid,uuid[])'::regprocedure))>0,
 'report-card context takes the shared academic-snapshot advisory lock first');
select ok(position('lock_academic_snapshot_domain' in pg_get_functiondef('app_auth.lock_term_grade_context(uuid)'::regprocedure))>0,
 'term-grade correction context takes the shared academic-snapshot advisory lock first');
select ok(position('lock_academic_snapshot_domain' in pg_get_functiondef('public.correct_attendance_session(uuid,attendance_mark_input[],text)'::regprocedure))>0,
 'attendance correction takes the shared academic-snapshot advisory lock before row locks');
select ok(to_regprocedure('public.update_section(uuid,text,text,integer,date,date,uuid,uuid,record_status,boolean,boolean)') is not null
 and to_regprocedure('public.archive_section(uuid)') is not null,'parent command signatures are preserved');
select ok(not has_function_privilege('authenticated','app_auth.write_academic_change_v1_0_parent_impl(uuid,uuid,text,text,uuid,jsonb,jsonb)','EXECUTE')
 and not has_function_privilege('authenticated','app_auth.write_sis_change_v1_0_parent_impl(uuid,uuid,uuid,text,text,uuid,jsonb,jsonb,jsonb)','EXECUTE'),
 'prior parent implementations are private');

-- Isolated forced-RLS fixture. These rows represent an already issued read model;
-- command/snapshot creation receives separate end-to-end coverage below.
insert into auth.users(id,instance_id,aud,role,email,encrypted_password,created_at,updated_at) values
 ('d1000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','rc-admin@test','',now(),now()),
 ('d1000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','rc-subject@test','',now(),now()),
 ('d1000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000000','authenticated','authenticated','rc-home@test','',now(),now()),
 ('d1000000-0000-0000-0000-000000000004','00000000-0000-0000-0000-000000000000','authenticated','authenticated','rc-assistant@test','',now(),now()),
 ('d1000000-0000-0000-0000-000000000005','00000000-0000-0000-0000-000000000000','authenticated','authenticated','rc-student@test','',now(),now()),
 ('d1000000-0000-0000-0000-000000000006','00000000-0000-0000-0000-000000000000','authenticated','authenticated','rc-guardian@test','',now(),now()),
 ('d1000000-0000-0000-0000-000000000007','00000000-0000-0000-0000-000000000000','authenticated','authenticated','rc-inactive@test','',now(),now()),
 ('d1000000-0000-0000-0000-000000000008','00000000-0000-0000-0000-000000000000','authenticated','authenticated','rc-cross@test','',now(),now());
insert into public.organizations(id,name,slug) values
 ('d2000000-0000-0000-0000-000000000001','Report Tenant','report-tenant'),
 ('d2000000-0000-0000-0000-000000000002','Other Report Tenant','other-report-tenant');
insert into public.schools(id,organization_id,name,code) values
 ('d3000000-0000-0000-0000-000000000001','d2000000-0000-0000-0000-000000000001','Report School','RCS'),
 ('d3000000-0000-0000-0000-000000000002','d2000000-0000-0000-0000-000000000002','Other School','ORS');
insert into public.campuses(id,organization_id,school_id,name,code) values
 ('d4000000-0000-0000-0000-000000000001','d2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000001','Main','MAIN'),
 ('d4000000-0000-0000-0000-000000000002','d2000000-0000-0000-0000-000000000002','d3000000-0000-0000-0000-000000000002','Other','OTHER');
insert into public.organization_memberships(id,organization_id,user_id,status,joined_at) values
 ('d5000000-0000-0000-0000-000000000001','d2000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000001','active',now()),
 ('d5000000-0000-0000-0000-000000000002','d2000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000002','active',now()),
 ('d5000000-0000-0000-0000-000000000003','d2000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000003','active',now()),
 ('d5000000-0000-0000-0000-000000000004','d2000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000004','active',now()),
 ('d5000000-0000-0000-0000-000000000007','d2000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000007','suspended',null),
 ('d5000000-0000-0000-0000-000000000008','d2000000-0000-0000-0000-000000000002','d1000000-0000-0000-0000-000000000008','active',now());
insert into public.roles(id,organization_id,code,name) values
 ('d6000000-0000-0000-0000-000000000001','d2000000-0000-0000-0000-000000000001','REPORT_ADMIN','Report Admin'),
 ('d6000000-0000-0000-0000-000000000002','d2000000-0000-0000-0000-000000000002','OTHER_REPORT','Other Report');
insert into public.role_permissions(organization_id,role_id,permission_id)
 select 'd2000000-0000-0000-0000-000000000001','d6000000-0000-0000-0000-000000000001',id from public.permissions where code like 'report_cards.%';
insert into public.role_permissions(organization_id,role_id,permission_id)
 select 'd2000000-0000-0000-0000-000000000002','d6000000-0000-0000-0000-000000000002',id from public.permissions where code like 'report_cards.%';
insert into public.role_assignments(organization_id,organization_membership_id,role_id,school_id,campus_id) values
 ('d2000000-0000-0000-0000-000000000001','d5000000-0000-0000-0000-000000000001','d6000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000001','d4000000-0000-0000-0000-000000000001'),
 ('d2000000-0000-0000-0000-000000000001','d5000000-0000-0000-0000-000000000007','d6000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000001','d4000000-0000-0000-0000-000000000001'),
 ('d2000000-0000-0000-0000-000000000002','d5000000-0000-0000-0000-000000000008','d6000000-0000-0000-0000-000000000002','d3000000-0000-0000-0000-000000000002','d4000000-0000-0000-0000-000000000002');
insert into public.academic_years(id,organization_id,school_id,name,start_date,end_date,status) values
 ('d7000000-0000-0000-0000-000000000001','d2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000001','2026-27','2026-01-01','2026-12-31','active');
insert into public.academic_terms(id,organization_id,academic_year_id,name,sequence,start_date,end_date,status) values
 ('d7100000-0000-0000-0000-000000000001','d2000000-0000-0000-0000-000000000001','d7000000-0000-0000-0000-000000000001','Term 1',1,'2026-01-01','2026-12-31','active');
insert into public.grade_levels(id,organization_id,school_id,code,name,sequence,status) values
 ('d7200000-0000-0000-0000-000000000001','d2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000001','G1','Grade 1',1,'active');
insert into public.subjects(id,organization_id,school_id,code,name,status) values
 ('d7300000-0000-0000-0000-000000000001','d2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000001','MATH','Mathematics','active'),
 ('d7300000-0000-0000-0000-000000000002','d2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000001','SCI','Science','active');
insert into public.sections(id,organization_id,school_id,campus_id,academic_year_id,academic_term_id,grade_level_id,code,name,capacity,start_date,end_date,status) values
 ('d7400000-0000-0000-0000-000000000001','d2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000001','d4000000-0000-0000-0000-000000000001','d7000000-0000-0000-0000-000000000001','d7100000-0000-0000-0000-000000000001','d7200000-0000-0000-0000-000000000001','1A','Grade 1 A',30,'2026-01-01','2026-12-31','active');
insert into public.students(id,organization_id,school_id,campus_id,user_id,student_number,first_name,last_name,date_of_birth,status) values
 ('d7500000-0000-0000-0000-000000000001','d2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000001','d4000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000005','S1','Report','Student','2018-01-01','active');
insert into public.student_enrollments(id,organization_id,school_id,academic_year_id,student_id,grade_level_id,enrolled_on,scheduled_end_on,enrollment_range,status,created_by,updated_by) values
 ('d7600000-0000-0000-0000-000000000001','d2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000001','d7000000-0000-0000-0000-000000000001','d7500000-0000-0000-0000-000000000001','d7200000-0000-0000-0000-000000000001','2026-01-01','2026-12-31',daterange('2026-01-01','2026-12-31','[]'),'active','d1000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000001');
insert into public.student_section_placements(id,organization_id,school_id,campus_id,academic_year_id,student_enrollment_id,student_id,section_id,starts_on,status,created_by,updated_by) values
 ('d7700000-0000-0000-0000-000000000001','d2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000001','d4000000-0000-0000-0000-000000000001','d7000000-0000-0000-0000-000000000001','d7600000-0000-0000-0000-000000000001','d7500000-0000-0000-0000-000000000001','d7400000-0000-0000-0000-000000000001','2026-01-01','active','d1000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000001');
insert into public.staff_profiles(id,organization_id,organization_membership_id,staff_number,employment_type,status) values
 ('d7800000-0000-0000-0000-000000000002','d2000000-0000-0000-0000-000000000001','d5000000-0000-0000-0000-000000000002','T1','teacher','active'),
 ('d7800000-0000-0000-0000-000000000003','d2000000-0000-0000-0000-000000000001','d5000000-0000-0000-0000-000000000003','T2','teacher','active'),
 ('d7800000-0000-0000-0000-000000000004','d2000000-0000-0000-0000-000000000001','d5000000-0000-0000-0000-000000000004','T3','assistant','active');
insert into public.teaching_assignments(id,organization_id,school_id,campus_id,academic_year_id,section_id,subject_id,staff_profile_id,role,starts_on,scheduled_ends_on,effective_range,status,created_by,updated_by) values
 ('d7900000-0000-0000-0000-000000000002','d2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000001','d4000000-0000-0000-0000-000000000001','d7000000-0000-0000-0000-000000000001','d7400000-0000-0000-0000-000000000001','d7300000-0000-0000-0000-000000000001','d7800000-0000-0000-0000-000000000002','lead','2026-01-01','2026-12-31',daterange('2026-01-01','2026-12-31','[]'),'active','d1000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000001'),
 ('d7900000-0000-0000-0000-000000000003','d2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000001','d4000000-0000-0000-0000-000000000001','d7000000-0000-0000-0000-000000000001','d7400000-0000-0000-0000-000000000001',null,'d7800000-0000-0000-0000-000000000003','lead','2026-01-01','2026-12-31',daterange('2026-01-01','2026-12-31','[]'),'active','d1000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000001'),
 ('d7900000-0000-0000-0000-000000000004','d2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000001','d4000000-0000-0000-0000-000000000001','d7000000-0000-0000-0000-000000000001','d7400000-0000-0000-0000-000000000001','d7300000-0000-0000-0000-000000000001','d7800000-0000-0000-0000-000000000004','assistant','2026-01-01','2026-12-31',daterange('2026-01-01','2026-12-31','[]'),'active','d1000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000001');
insert into public.grade_scales(id,organization_id,school_id,academic_year_id,name,status,activated_at,activated_by,created_by,updated_by) values
 ('d7f00000-0000-0000-0000-000000000001','d2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000001','d7000000-0000-0000-0000-000000000001','Report Scale','active',now(),'d1000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000001');
insert into public.grade_scale_bands(id,organization_id,school_id,grade_scale_id,sequence,lower_units,upper_units,label,result_state,created_by) values
 ('d7f10000-0000-0000-0000-000000000001','d2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000001','d7f00000-0000-0000-0000-000000000001',1,0,1000000,'Pass','pass','d1000000-0000-0000-0000-000000000001');
insert into public.term_grading_configurations(id,organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,subject_id,grade_scale_id,status,activated_at,activated_by,created_by,updated_by) values
 ('d7f20000-0000-0000-0000-000000000001','d2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000001','d4000000-0000-0000-0000-000000000001','d7000000-0000-0000-0000-000000000001','d7100000-0000-0000-0000-000000000001','d7400000-0000-0000-0000-000000000001','d7300000-0000-0000-0000-000000000001','d7f00000-0000-0000-0000-000000000001','active',now(),'d1000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000001');
insert into public.term_grade_sets(id,organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,subject_id,term_grading_configuration_id,lifecycle_status,publication_state,calculation_sequence,source_fingerprint,finalized_at,finalized_by,created_by,updated_by) values
 ('d7f30000-0000-0000-0000-000000000001','d2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000001','d4000000-0000-0000-0000-000000000001','d7000000-0000-0000-0000-000000000001','d7100000-0000-0000-0000-000000000001','d7400000-0000-0000-0000-000000000001','d7300000-0000-0000-0000-000000000001','d7f20000-0000-0000-0000-000000000001','finalized','unpublished',1,extensions.digest('grade-set','sha256'),now(),'d1000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000001');
insert into public.term_grade_records(id,organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,subject_id,term_grading_configuration_id,term_grade_set_id,student_id,calculation_sequence,created_by) values
 ('d7f40000-0000-0000-0000-000000000001','d2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000001','d4000000-0000-0000-0000-000000000001','d7000000-0000-0000-0000-000000000001','d7100000-0000-0000-0000-000000000001','d7400000-0000-0000-0000-000000000001','d7300000-0000-0000-0000-000000000001','d7f20000-0000-0000-0000-000000000001','d7f30000-0000-0000-0000-000000000001','d7500000-0000-0000-0000-000000000001',1,'d1000000-0000-0000-0000-000000000001');
insert into public.term_grade_calculations(id,organization_id,term_grade_set_id,term_grade_record_id,student_id,calculation_sequence,raw_percentage,rounded_percentage,grade_scale_id,grade_scale_band_id,grade_label,result_state,contributing_assessment_count,weight_total,calculated_by) values
 ('d7f50000-0000-0000-0000-000000000001','d2000000-0000-0000-0000-000000000001','d7f30000-0000-0000-0000-000000000001','d7f40000-0000-0000-0000-000000000001','d7500000-0000-0000-0000-000000000001',1,88,88,'d7f00000-0000-0000-0000-000000000001','d7f10000-0000-0000-0000-000000000001','Pass','pass',1,100,'d1000000-0000-0000-0000-000000000001');
insert into public.assessments(id,organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,subject_id,assessment_type,title,assessment_date,maximum_score,weight,lifecycle_status,publication_state,published_at,published_by,finalized_at,finalized_by,created_by,updated_by) values
 ('d7f60000-0000-0000-0000-000000000001','d2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000001','d4000000-0000-0000-0000-000000000001','d7000000-0000-0000-0000-000000000001','d7100000-0000-0000-0000-000000000001','d7400000-0000-0000-0000-000000000001','d7300000-0000-0000-0000-000000000001','exam','Term Exam','2026-06-01',100,100,'finalized','published',now(),'d1000000-0000-0000-0000-000000000001',now(),'d1000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000001');
insert into public.assessment_students(id,organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,assessment_id,student_id,student_enrollment_id,student_section_placement_id,created_by) values
 ('d7f70000-0000-0000-0000-000000000001','d2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000001','d4000000-0000-0000-0000-000000000001','d7000000-0000-0000-0000-000000000001','d7100000-0000-0000-0000-000000000001','d7400000-0000-0000-0000-000000000001','d7f60000-0000-0000-0000-000000000001','d7500000-0000-0000-0000-000000000001','d7600000-0000-0000-0000-000000000001','d7700000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000001');
insert into public.assessment_results(id,organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,assessment_id,assessment_student_id,student_id,score,created_by,updated_by) values
 ('d7f80000-0000-0000-0000-000000000001','d2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000001','d4000000-0000-0000-0000-000000000001','d7000000-0000-0000-0000-000000000001','d7100000-0000-0000-0000-000000000001','d7400000-0000-0000-0000-000000000001','d7f60000-0000-0000-0000-000000000001','d7f70000-0000-0000-0000-000000000001','d7500000-0000-0000-0000-000000000001',88,'d1000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000001');
insert into public.term_grade_calculation_sources(id,organization_id,term_grade_calculation_id,student_id,assessment_root_id,assessment_version_id,assessment_id,assessment_student_id,assessment_result_id,score,maximum_score,assessment_weight,score_ratio,effective_weight,weighted_points,created_by) values
 ('d7f90000-0000-0000-0000-000000000001','d2000000-0000-0000-0000-000000000001','d7f50000-0000-0000-0000-000000000001','d7500000-0000-0000-0000-000000000001','d7f60000-0000-0000-0000-000000000001','d7f60000-0000-0000-0000-000000000001','d7f60000-0000-0000-0000-000000000001','d7f70000-0000-0000-0000-000000000001','d7f80000-0000-0000-0000-000000000001',88,100,100,0.88,100,88,'d1000000-0000-0000-0000-000000000001');
insert into public.attendance_sessions(id,organization_id,school_id,campus_id,academic_year_id,section_id,session_date,status,submitted_at,submitted_by,finalized_at,finalized_by,created_by,updated_by) values
 ('d7fa0000-0000-0000-0000-000000000001','d2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000001','d4000000-0000-0000-0000-000000000001','d7000000-0000-0000-0000-000000000001','d7400000-0000-0000-0000-000000000001','2026-05-01','finalized',now(),'d1000000-0000-0000-0000-000000000001',now(),'d1000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000001');
insert into public.attendance_session_students(id,organization_id,school_id,campus_id,academic_year_id,section_id,session_id,student_id,student_enrollment_id,student_section_placement_id,created_by) values
 ('d7fb0000-0000-0000-0000-000000000001','d2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000001','d4000000-0000-0000-0000-000000000001','d7000000-0000-0000-0000-000000000001','d7400000-0000-0000-0000-000000000001','d7fa0000-0000-0000-0000-000000000001','d7500000-0000-0000-0000-000000000001','d7600000-0000-0000-0000-000000000001','d7700000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000001');
insert into public.attendance_marks(id,organization_id,school_id,campus_id,academic_year_id,section_id,session_id,session_student_id,student_id,mark,created_by,updated_by) values
 ('d7fc0000-0000-0000-0000-000000000001','d2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000001','d4000000-0000-0000-0000-000000000001','d7000000-0000-0000-0000-000000000001','d7400000-0000-0000-0000-000000000001','d7fa0000-0000-0000-0000-000000000001','d7fb0000-0000-0000-0000-000000000001','d7500000-0000-0000-0000-000000000001','present','d1000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000001');
insert into public.guardians(id,organization_id,user_id,first_name,last_name,status) values
 ('d7a00000-0000-0000-0000-000000000001','d2000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000006','Portal','Guardian','active');
insert into public.student_guardians(id,organization_id,student_id,guardian_id,relationship_type,has_portal_access,status) values
 ('d7b00000-0000-0000-0000-000000000001','d2000000-0000-0000-0000-000000000001','d7500000-0000-0000-0000-000000000001','d7a00000-0000-0000-0000-000000000001','parent',true,'active');
insert into public.report_cards(id,organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,student_id,student_enrollment_id,student_section_placement_id,lineage_id,version,report_card_number,status,finalized_at,finalized_by,published_at,published_by,source_fingerprint,school_code,school_name,campus_code,campus_name,academic_year_name,academic_term_name,academic_term_sequence,term_start_date,term_end_date,section_code,section_name,grade_level_code,grade_level_name,student_number,student_display_name,created_by,updated_by) values
 ('d7c00000-0000-0000-0000-000000000001','d2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000001','d4000000-0000-0000-0000-000000000001','d7000000-0000-0000-0000-000000000001','d7100000-0000-0000-0000-000000000001','d7400000-0000-0000-0000-000000000001','d7500000-0000-0000-0000-000000000001','d7600000-0000-0000-0000-000000000001','d7700000-0000-0000-0000-000000000001','d7c00000-0000-0000-0000-000000000001',1,1,'published',now(),'d1000000-0000-0000-0000-000000000001',now(),'d1000000-0000-0000-0000-000000000001',extensions.digest('fixture','sha256'),'RCS','Report School','MAIN','Main','2026-27','Term 1',1,'2026-01-01','2026-12-31','1A','Grade 1 A','G1','Grade 1','S1','Report Student','d1000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000001');
insert into public.report_card_attendance_snapshots(id,organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,report_card_id,student_id,range_start_date,range_end_date,total_session_count,present_count,absent_count,late_count,excused_count,source_fingerprint,created_by) values
 ('d7d00000-0000-0000-0000-000000000001','d2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000001','d4000000-0000-0000-0000-000000000001','d7000000-0000-0000-0000-000000000001','d7100000-0000-0000-0000-000000000001','d7400000-0000-0000-0000-000000000001','d7c00000-0000-0000-0000-000000000001','d7500000-0000-0000-0000-000000000001','2026-01-01','2026-12-31',0,0,0,0,0,extensions.digest('','sha256'),'d1000000-0000-0000-0000-000000000001');
insert into public.report_card_comments(id,organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,report_card_id,student_id,comment_type,subject_id,body,author_user_id,author_membership_id,author_staff_profile_id,author_teaching_assignment_id,created_by) values
 ('d7e00000-0000-0000-0000-000000000001','d2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000001','d4000000-0000-0000-0000-000000000001','d7000000-0000-0000-0000-000000000001','d7100000-0000-0000-0000-000000000001','d7400000-0000-0000-0000-000000000001','d7c00000-0000-0000-0000-000000000001','d7500000-0000-0000-0000-000000000001','subject','d7300000-0000-0000-0000-000000000001','Subject comment','d1000000-0000-0000-0000-000000000002','d5000000-0000-0000-0000-000000000002','d7800000-0000-0000-0000-000000000002','d7900000-0000-0000-0000-000000000002','d1000000-0000-0000-0000-000000000002'),
 ('d7e00000-0000-0000-0000-000000000002','d2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000001','d4000000-0000-0000-0000-000000000001','d7000000-0000-0000-0000-000000000001','d7100000-0000-0000-0000-000000000001','d7400000-0000-0000-0000-000000000001','d7c00000-0000-0000-0000-000000000001','d7500000-0000-0000-0000-000000000001','overall',null,'Overall comment','d1000000-0000-0000-0000-000000000003','d5000000-0000-0000-0000-000000000003','d7800000-0000-0000-0000-000000000003','d7900000-0000-0000-0000-000000000003','d1000000-0000-0000-0000-000000000003');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"d1000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select is((select count(*)::int from public.report_cards),1,'scoped administrator reads card');
select is((select count(*)::int from public.report_card_comments),2,'scoped administrator reads all comments');
select is((select count(*)::int from public.report_card_attendance_snapshots),1,'scoped administrator reads attendance');
select set_config('request.jwt.claims','{"sub":"d1000000-0000-0000-0000-000000000002","role":"authenticated"}',true);
select is((select count(*)::int from public.report_cards),1,'subject teacher reads header');
select is((select count(*)::int from public.report_card_comments),1,'subject teacher reads only own subject rows');
select is((select count(*)::int from public.report_card_attendance_snapshots),0,'subject teacher cannot read attendance');
select set_config('request.jwt.claims','{"sub":"d1000000-0000-0000-0000-000000000003","role":"authenticated"}',true);
select is((select count(*)::int from public.report_card_comments),2,'homeroom teacher reads subject and overall rows');
select is((select count(*)::int from public.report_card_attendance_snapshots),1,'homeroom teacher reads attendance');
select set_config('request.jwt.claims','{"sub":"d1000000-0000-0000-0000-000000000004","role":"authenticated"}',true);
select is((select count(*)::int from public.report_card_comments),1,'subject assistant reads matching subject only');
select is((select count(*)::int from public.report_card_attendance_snapshots),0,'subject assistant cannot read attendance');
select throws_ok($$select public.save_report_card_comment('d7c00000-0000-0000-0000-000000000001','subject','d7300000-0000-0000-0000-000000000001','forbidden')$$,'22023','draft report card required','assistant cannot author issued card');
select set_config('request.jwt.claims','{"sub":"d1000000-0000-0000-0000-000000000005","role":"authenticated"}',true);
select is((select count(*)::int from public.report_cards),1,'active student reads own published card');
select is((select count(*)::int from public.report_card_comments),2,'student reads published comments');
select is((select count(*)::int from public.report_card_attendance_snapshots),1,'student reads published attendance summary');
select set_config('request.jwt.claims','{"sub":"d1000000-0000-0000-0000-000000000006","role":"authenticated"}',true);
select is((select count(*)::int from public.report_cards),1,'active portal guardian reads linked published card');
select set_config('request.jwt.claims','{"sub":"d1000000-0000-0000-0000-000000000007","role":"authenticated"}',true);
select is((select count(*)::int from public.report_cards),0,'inactive membership sees no cards');
select set_config('request.jwt.claims','{"sub":"d1000000-0000-0000-0000-000000000008","role":"authenticated"}',true);
select is((select count(*)::int from public.report_cards),0,'cross-tenant administrator sees no cards');
reset role;

select throws_ok($$update public.report_cards set student_display_name='Changed' where id='d7c00000-0000-0000-0000-000000000001'$$,'22023','report-card immutable fields cannot change','issued display snapshot is immutable');
select throws_ok($$delete from public.report_cards where id='d7c00000-0000-0000-0000-000000000001'$$,'22023','report-card history cannot be deleted','issued card cannot be deleted');
select throws_ok($$insert into public.report_card_comments(id,organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,report_card_id,student_id,comment_type,subject_id,body,author_user_id,author_membership_id,author_staff_profile_id,author_teaching_assignment_id,created_by) values
 ('d7e00000-0000-0000-0000-000000000003','d2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000001','d4000000-0000-0000-0000-000000000001','d7000000-0000-0000-0000-000000000001','d7100000-0000-0000-0000-000000000001','d7400000-0000-0000-0000-000000000001','d7c00000-0000-0000-0000-000000000001','d7500000-0000-0000-0000-000000000001','subject','d7300000-0000-0000-0000-000000000002','Forged','d1000000-0000-0000-0000-000000000002','d5000000-0000-0000-0000-000000000003','d7800000-0000-0000-0000-000000000002','d7900000-0000-0000-0000-000000000002','d1000000-0000-0000-0000-000000000002')$$,
 '23503',null,'cross-membership author provenance is rejected');
select ok(not exists(select 1 from public.event_outbox where event_type like 'report_card.%' and
 (payload?'body' or payload?'student_display_name' or payload?'grade_label' or payload?'score' or payload?'mark')),
 'report-card outbox payloads exclude comments, display values, grades, scores, and marks');

-- Correction is one transaction: predecessor is preserved, comments retain original
-- attribution, teacher sign-offs are not copied, and one admin certification authorizes
-- the atomically issued successor.
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"d1000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
create temp table correction_result as select * from public.correct_report_card('d7c00000-0000-0000-0000-000000000001','approved correction');
reset role;
select is((select status::text from public.report_cards where id='d7c00000-0000-0000-0000-000000000001'),'corrected','correction preserves predecessor as corrected');
select is((select status::text from public.report_cards where id=(select replacement_report_card_id from correction_result)),'published','published predecessor yields published successor');
select is((select count(*)::int from public.report_card_comments where report_card_id=(select replacement_report_card_id from correction_result)),2,'eligible comments are copied');
select ok(not exists(select 1 from public.report_card_comments n join public.report_card_comments o on o.report_card_id='d7c00000-0000-0000-0000-000000000001'
 where n.report_card_id=(select replacement_report_card_id from correction_result) and n.subject_id is not distinct from o.subject_id and
 (n.body,n.author_user_id,n.author_membership_id,n.author_staff_profile_id,n.author_teaching_assignment_id) is distinct from
 (o.body,o.author_user_id,o.author_membership_id,o.author_staff_profile_id,o.author_teaching_assignment_id)),
 'copied comments retain original attribution');
select is((select count(*)::int from public.report_card_signoffs where report_card_id=(select replacement_report_card_id from correction_result)
 and signoff_type in('subject_teacher','homeroom_teacher')),0,'teacher and homeroom sign-offs are never copied');
select is((select count(*)::int from public.report_card_signoffs where report_card_id=(select replacement_report_card_id from correction_result)
 and signoff_type='administrator_correction_certification'),1,'successor has exactly one correction certification');
select is((select count(*)::int from public.report_card_grade_sources where report_card_id=(select replacement_report_card_id from correction_result)),1,'correction snapshots nonempty grade-source provenance');
select is((select count(*)::int from public.report_card_attendance_sources where report_card_id=(select replacement_report_card_id from correction_result)),1,'correction snapshots nonzero attendance provenance');
select is((select row(total_session_count,present_count,absent_count,late_count,excused_count)::text from public.report_card_attendance_snapshots where report_card_id=(select replacement_report_card_id from correction_result)),'(1,1,0,0,0)','nonzero attendance totals are exact');
select is((select count(*)::int from public.event_outbox where command_id=(select command_id from public.event_outbox
 where aggregate_id='d7c00000-0000-0000-0000-000000000001' and event_type='report_card.corrected' limit 1)),2,
 'correction emits exactly predecessor-corrected and successor-issued events');
select is((select count(*)::int from public.audit_log where command_id=(select command_id from public.event_outbox
 where aggregate_id='d7c00000-0000-0000-0000-000000000001' and event_type='report_card.corrected' limit 1)),9,
 'correction audit cardinality includes nonempty grade and attendance provenance');

create temp table fingerprint_before as select app_auth.report_card_source_fingerprint(
 'd7400000-0000-0000-0000-000000000001','d7100000-0000-0000-0000-000000000001','d7500000-0000-0000-0000-000000000001') value;
update public.students set first_name='Display Changed' where id='d7500000-0000-0000-0000-000000000001';
select isnt((select encode(value,'hex') from fingerprint_before),encode(app_auth.report_card_source_fingerprint(
 'd7400000-0000-0000-0000-000000000001','d7100000-0000-0000-0000-000000000001','d7500000-0000-0000-0000-000000000001'),'hex'),
 'SIS display changes alter the canonical draft-staleness fingerprint');
select throws_ok($$select app_auth.write_academic_change(gen_random_uuid(),'d1000000-0000-0000-0000-000000000001','academic_term.updated','academic_term',
 'd7100000-0000-0000-0000-000000000001','{"start_date":"2026-01-01","end_date":"2026-12-31"}',
 '{"start_date":"2026-01-02","end_date":"2026-12-31"}')$$,'22023','academic term dates are preserved by report-card snapshots',
 'parent lifecycle wrapper blocks term-date drift for issued cards');

create temp table rollback_counts as select (select count(*) from public.audit_log) audits,(select count(*) from public.event_outbox) events;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"d1000000-0000-0000-0000-000000000008","role":"authenticated"}',true);
select throws_ok(format('select * from public.correct_report_card(%L,%L)',(select replacement_report_card_id from correction_result),'forbidden cross tenant'),
 '42501','report_cards.manage and report_cards.correct permissions are required','cross-tenant correction is denied');
reset role;
select is((select count(*) from public.audit_log),(select audits from rollback_counts),'denied correction writes no audit rows');
select is((select count(*) from public.event_outbox),(select events from rollback_counts),'denied correction writes no outbox rows');

select * from finish();
commit;
