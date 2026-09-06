begin;
select plan(61);

select has_type('public','grade_scale_status','grade scale status exists');
select enum_has_labels('public','grade_scale_status',array['draft','active','retired'],'grade scale lifecycle exact');
select has_type('public','grade_result_state','grade result state exists');
select enum_has_labels('public','grade_result_state',array['pass','fail'],'result states exact');
select enum_has_labels('public','term_grade_lifecycle_status',array['draft','finalized','corrected','cancelled'],'set lifecycle exact');
select enum_has_labels('public','term_grade_publication_state',array['unpublished','published'],'publication exact');

select has_table('public','grade_scales','grade scales exists');
select has_table('public','grade_scale_bands','grade bands exists');
select has_table('public','term_grading_configurations','configuration exists');
select has_table('public','term_grade_sets','sets exists');
select has_table('public','term_grade_records','records exists');
select has_table('public','term_grade_calculations','calculations exists');
select has_table('public','term_grade_calculation_sources','sources exists');

select ok(relrowsecurity and relforcerowsecurity,'grade scales force RLS') from pg_class where oid='public.grade_scales'::regclass;
select ok(relrowsecurity and relforcerowsecurity,'bands force RLS') from pg_class where oid='public.grade_scale_bands'::regclass;
select ok(relrowsecurity and relforcerowsecurity,'config force RLS') from pg_class where oid='public.term_grading_configurations'::regclass;
select ok(relrowsecurity and relforcerowsecurity,'sets force RLS') from pg_class where oid='public.term_grade_sets'::regclass;
select ok(relrowsecurity and relforcerowsecurity,'records force RLS') from pg_class where oid='public.term_grade_records'::regclass;
select ok(relrowsecurity and relforcerowsecurity,'calculations force RLS') from pg_class where oid='public.term_grade_calculations'::regclass;
select ok(relrowsecurity and relforcerowsecurity,'sources force RLS') from pg_class where oid='public.term_grade_calculation_sources'::regclass;

select has_function('public','create_grade_scale',array['uuid','uuid','text','text','grade_scale_band_input[]'],'create scale signature');
select has_function('public','update_draft_grade_scale',array['uuid','text','text','boolean','grade_scale_band_input[]'],'update scale signature');
select has_function('public','activate_grade_scale',array['uuid'],'activate scale signature');
select has_function('public','retire_grade_scale',array['uuid'],'retire scale signature');
select has_function('public','revise_grade_scale',array['uuid','text','text','grade_scale_band_input[]'],'revise scale signature');
select has_function('public','create_term_grading_configuration',array['uuid','uuid','uuid','uuid','boolean','boolean'],'create config signature');
select has_function('public','update_draft_term_grading_configuration',array['uuid','uuid','boolean','boolean'],'update config signature');
select has_function('public','activate_term_grading_configuration',array['uuid'],'activate config signature');
select has_function('public','retire_term_grading_configuration',array['uuid'],'retire config signature');
select has_function('public','revise_term_grading_configuration',array['uuid','uuid','boolean','boolean'],'revise config signature');
select has_function('public','calculate_term_grades',array['uuid'],'calculate signature');
select has_function('public','recalculate_draft_term_grades',array['uuid'],'recalculate signature');
select has_function('public','publish_term_grades',array['uuid'],'publish signature');
select has_function('public','finalize_term_grades',array['uuid'],'finalize signature');
select has_function('public','cancel_draft_term_grades',array['uuid','text'],'cancel signature');
select has_function('public','correct_term_grades',array['uuid','text'],'correct signature');

select is((select count(*)::int from public.permissions where code like 'term_grades.%'),3,'three permissions seeded');
select ok(exists(select 1 from public.permissions where code='term_grades.view'),'view permission');
select ok(exists(select 1 from public.permissions where code='term_grades.manage'),'manage permission');
select ok(exists(select 1 from public.permissions where code='term_grades.correct'),'correct permission');

select has_index('public','grade_scales','grade_scales_active_global_name_key','active global scale uniqueness');
select has_index('public','grade_scales','grade_scales_draft_global_name_key','draft global scale uniqueness');
select has_index('public','grade_scales','grade_scales_one_draft_successor_key','one scale successor');
select has_index('public','term_grading_configurations','term_configs_active_null_key','active null config uniqueness');
select has_index('public','term_grading_configurations','term_configs_draft_null_key','draft null config uniqueness');
select has_index('public','term_grading_configurations','term_configs_one_draft_successor_key','one config successor');
select has_index('public','term_grade_sets','term_grade_sets_one_successor_key','whole-set correction linear');
select ok(to_regclass('public.term_grade_records')=(select conrelid from pg_constraint where conname='term_grade_records_exact_calculation_identity_key'),'record exposes exact calculation identity');
select ok(to_regclass('public.term_grade_calculations')=(select conrelid from pg_constraint where conname='term_grade_calculations_exact_record_fk'),'calculation is tied to exact record/set/student/sequence');
select ok(to_regclass('public.term_grade_calculation_sources')=(select conrelid from pg_constraint where conname='term_grade_sources_exact_calculation_fk'),'source is tied to exact calculation student');
select ok(to_regclass('public.term_grade_calculation_sources')=(select conrelid from pg_constraint where conname='term_grade_sources_exact_snapshot_fk'),'source is tied to exact assessment snapshot');
select ok(to_regclass('public.term_grade_calculation_sources')=(select conrelid from pg_constraint where conname='term_grade_sources_exact_result_fk'),'source is tied to exact assessment result');
select ok(to_regclass('public.term_grade_calculation_sources')=(select conrelid from pg_constraint where conname='term_grade_sources_root_fk'),'source root is an assessment');
select ok(to_regclass('public.term_grade_calculation_sources')=(select conrelid from pg_constraint where conname='term_grade_sources_version_fk'),'source version is an assessment');

set local role anon;
select throws_ok($$select public.activate_grade_scale(gen_random_uuid())$$,'42501','permission denied for function activate_grade_scale','anonymous command denied');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$insert into public.term_grade_sets(id) values(gen_random_uuid())$$,'42501','permission denied for table term_grade_sets','direct set insert denied');
select throws_ok($$delete from public.term_grade_records$$,'42501','permission denied for table term_grade_records','direct record delete denied');
select throws_ok($$select public.calculate_term_grades(gen_random_uuid())$$,'P0002','configuration not found','unknown calculation denied');
reset role;

select ok(not has_table_privilege('anon','public.term_grade_calculation_sources','SELECT'),'anonymous cannot select sources');
select ok(not has_table_privilege('authenticated','public.term_grade_sets','INSERT'),'authenticated cannot insert sets');
select ok(has_table_privilege('authenticated','public.term_grade_sets','SELECT'),'authenticated has select subject to RLS');
select * from finish();
rollback;
