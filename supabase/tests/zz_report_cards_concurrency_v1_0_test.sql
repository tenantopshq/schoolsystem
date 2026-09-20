begin;
create extension if not exists pgtap with schema extensions;
create extension if not exists dblink with schema extensions;
select no_plan();

create function app_auth.test_capture_report_card_sql(p_actor uuid,p_sql text) returns text
language plpgsql security definer set search_path='' as $$
begin
 perform pg_catalog.set_config('request.jwt.claims',jsonb_build_object('sub',p_actor,'role','authenticated')::text,true);
 execute p_sql;
 return '00000';
exception when others then return sqlstate;
end $$;
revoke all on function app_auth.test_capture_report_card_sql(uuid,text) from public,anon,authenticated,service_role;

-- Five additional students share the finalized assessment, term-grade generation,
-- and finalized attendance session committed by the foundation fixture.
insert into public.students(id,organization_id,school_id,campus_id,student_number,first_name,last_name,date_of_birth,status)
select ('d75'||lpad(n::text,5,'0')||'-0000-0000-0000-00000000000'||n)::uuid,
 'd2000000-0000-0000-0000-000000000001','d3000000-0000-0000-0000-000000000001','d4000000-0000-0000-0000-000000000001',
 'CS-'||n,'Concurrent',n::text,'2018-01-01','active' from generate_series(2,6) n;
insert into public.student_enrollments(id,organization_id,school_id,academic_year_id,student_id,grade_level_id,enrolled_on,scheduled_end_on,enrollment_range,status,created_by,updated_by)
select ('d76'||lpad(n::text,5,'0')||'-0000-0000-0000-00000000000'||n)::uuid,'d2000000-0000-0000-0000-000000000001',
 'd3000000-0000-0000-0000-000000000001','d7000000-0000-0000-0000-000000000001',
 ('d75'||lpad(n::text,5,'0')||'-0000-0000-0000-00000000000'||n)::uuid,'d7200000-0000-0000-0000-000000000001',
 '2026-01-01','2026-12-31',daterange('2026-01-01','2026-12-31','[]'),'active',
 'd1000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000001' from generate_series(2,6) n;
insert into public.student_section_placements(id,organization_id,school_id,campus_id,academic_year_id,student_enrollment_id,student_id,section_id,starts_on,status,created_by,updated_by)
select ('d77'||lpad(n::text,5,'0')||'-0000-0000-0000-00000000000'||n)::uuid,'d2000000-0000-0000-0000-000000000001',
 'd3000000-0000-0000-0000-000000000001','d4000000-0000-0000-0000-000000000001','d7000000-0000-0000-0000-000000000001',
 ('d76'||lpad(n::text,5,'0')||'-0000-0000-0000-00000000000'||n)::uuid,
 ('d75'||lpad(n::text,5,'0')||'-0000-0000-0000-00000000000'||n)::uuid,'d7400000-0000-0000-0000-000000000001',
 '2026-01-01','active','d1000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000001' from generate_series(2,6) n;
insert into public.assessment_students(id,organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,assessment_id,student_id,student_enrollment_id,student_section_placement_id,created_by)
select ('d7f7'||lpad(n::text,4,'0')||'-0000-0000-0000-00000000000'||n)::uuid,'d2000000-0000-0000-0000-000000000001',
 'd3000000-0000-0000-0000-000000000001','d4000000-0000-0000-0000-000000000001','d7000000-0000-0000-0000-000000000001',
 'd7100000-0000-0000-0000-000000000001','d7400000-0000-0000-0000-000000000001','d7f60000-0000-0000-0000-000000000001',
 ('d75'||lpad(n::text,5,'0')||'-0000-0000-0000-00000000000'||n)::uuid,
 ('d76'||lpad(n::text,5,'0')||'-0000-0000-0000-00000000000'||n)::uuid,
 ('d77'||lpad(n::text,5,'0')||'-0000-0000-0000-00000000000'||n)::uuid,'d1000000-0000-0000-0000-000000000001' from generate_series(2,6) n;
insert into public.assessment_results(id,organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,assessment_id,assessment_student_id,student_id,score,created_by,updated_by)
select ('d7f8'||lpad(n::text,4,'0')||'-0000-0000-0000-00000000000'||n)::uuid,'d2000000-0000-0000-0000-000000000001',
 'd3000000-0000-0000-0000-000000000001','d4000000-0000-0000-0000-000000000001','d7000000-0000-0000-0000-000000000001',
 'd7100000-0000-0000-0000-000000000001','d7400000-0000-0000-0000-000000000001','d7f60000-0000-0000-0000-000000000001',
 ('d7f7'||lpad(n::text,4,'0')||'-0000-0000-0000-00000000000'||n)::uuid,
 ('d75'||lpad(n::text,5,'0')||'-0000-0000-0000-00000000000'||n)::uuid,88,
 'd1000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000001' from generate_series(2,6) n;
insert into public.term_grade_records(id,organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,subject_id,term_grading_configuration_id,term_grade_set_id,student_id,calculation_sequence,created_by)
select ('d7f4'||lpad(n::text,4,'0')||'-0000-0000-0000-00000000000'||n)::uuid,'d2000000-0000-0000-0000-000000000001',
 'd3000000-0000-0000-0000-000000000001','d4000000-0000-0000-0000-000000000001','d7000000-0000-0000-0000-000000000001',
 'd7100000-0000-0000-0000-000000000001','d7400000-0000-0000-0000-000000000001','d7300000-0000-0000-0000-000000000001',
 'd7f20000-0000-0000-0000-000000000001','d7f30000-0000-0000-0000-000000000001',
 ('d75'||lpad(n::text,5,'0')||'-0000-0000-0000-00000000000'||n)::uuid,1,'d1000000-0000-0000-0000-000000000001' from generate_series(2,6) n;
insert into public.term_grade_calculations(id,organization_id,term_grade_set_id,term_grade_record_id,student_id,calculation_sequence,raw_percentage,rounded_percentage,grade_scale_id,grade_scale_band_id,grade_label,result_state,contributing_assessment_count,weight_total,calculated_by)
select ('d7f5'||lpad(n::text,4,'0')||'-0000-0000-0000-00000000000'||n)::uuid,'d2000000-0000-0000-0000-000000000001',
 'd7f30000-0000-0000-0000-000000000001',('d7f4'||lpad(n::text,4,'0')||'-0000-0000-0000-00000000000'||n)::uuid,
 ('d75'||lpad(n::text,5,'0')||'-0000-0000-0000-00000000000'||n)::uuid,1,88,88,
 'd7f00000-0000-0000-0000-000000000001','d7f10000-0000-0000-0000-000000000001','Pass','pass',1,100,
 'd1000000-0000-0000-0000-000000000001' from generate_series(2,6) n;
insert into public.term_grade_calculation_sources(id,organization_id,term_grade_calculation_id,student_id,assessment_root_id,assessment_version_id,assessment_id,assessment_student_id,assessment_result_id,score,maximum_score,assessment_weight,score_ratio,effective_weight,weighted_points,created_by)
select ('d7f9'||lpad(n::text,4,'0')||'-0000-0000-0000-00000000000'||n)::uuid,'d2000000-0000-0000-0000-000000000001',
 ('d7f5'||lpad(n::text,4,'0')||'-0000-0000-0000-00000000000'||n)::uuid,
 ('d75'||lpad(n::text,5,'0')||'-0000-0000-0000-00000000000'||n)::uuid,
 'd7f60000-0000-0000-0000-000000000001','d7f60000-0000-0000-0000-000000000001','d7f60000-0000-0000-0000-000000000001',
 ('d7f7'||lpad(n::text,4,'0')||'-0000-0000-0000-00000000000'||n)::uuid,
 ('d7f8'||lpad(n::text,4,'0')||'-0000-0000-0000-00000000000'||n)::uuid,88,100,100,0.88,100,88,
 'd1000000-0000-0000-0000-000000000001' from generate_series(2,6) n;
insert into public.attendance_session_students(id,organization_id,school_id,campus_id,academic_year_id,section_id,session_id,student_id,student_enrollment_id,student_section_placement_id,created_by)
select ('d7fb'||lpad(n::text,4,'0')||'-0000-0000-0000-00000000000'||n)::uuid,'d2000000-0000-0000-0000-000000000001',
 'd3000000-0000-0000-0000-000000000001','d4000000-0000-0000-0000-000000000001','d7000000-0000-0000-0000-000000000001',
 'd7400000-0000-0000-0000-000000000001','d7fa0000-0000-0000-0000-000000000001',
 ('d75'||lpad(n::text,5,'0')||'-0000-0000-0000-00000000000'||n)::uuid,
 ('d76'||lpad(n::text,5,'0')||'-0000-0000-0000-00000000000'||n)::uuid,
 ('d77'||lpad(n::text,5,'0')||'-0000-0000-0000-00000000000'||n)::uuid,'d1000000-0000-0000-0000-000000000001' from generate_series(2,6) n;
insert into public.attendance_marks(id,organization_id,school_id,campus_id,academic_year_id,section_id,session_id,session_student_id,student_id,mark,created_by,updated_by)
select ('d7fc'||lpad(n::text,4,'0')||'-0000-0000-0000-00000000000'||n)::uuid,'d2000000-0000-0000-0000-000000000001',
 'd3000000-0000-0000-0000-000000000001','d4000000-0000-0000-0000-000000000001','d7000000-0000-0000-0000-000000000001',
 'd7400000-0000-0000-0000-000000000001','d7fa0000-0000-0000-0000-000000000001',
 ('d7fb'||lpad(n::text,4,'0')||'-0000-0000-0000-00000000000'||n)::uuid,
 ('d75'||lpad(n::text,5,'0')||'-0000-0000-0000-00000000000'||n)::uuid,'present',
 'd1000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000001' from generate_series(2,6) n;
commit;

select extensions.dblink_connect('rc_block','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');
select extensions.dblink_connect('rc_one','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');
select extensions.dblink_connect('rc_two','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');

-- Distinct-student creation serializes school numbering and both commands succeed.
select extensions.dblink_exec('rc_block','begin; do $do$begin perform app_auth.lock_academic_snapshot_domain(''d2000000-0000-0000-0000-000000000001''); end$do$');
select is(extensions.dblink_send_query('rc_one',format('select app_auth.test_capture_report_card_sql(%L,%L)','d1000000-0000-0000-0000-000000000001','select public.create_report_card(''d7500002-0000-0000-0000-000000000002'',''d7400000-0000-0000-0000-000000000001'',''d7100000-0000-0000-0000-000000000001'')')),1,'first create dispatched');
select is(extensions.dblink_send_query('rc_two',format('select app_auth.test_capture_report_card_sql(%L,%L)','d1000000-0000-0000-0000-000000000001','select public.create_report_card(''d7500003-0000-0000-0000-000000000003'',''d7400000-0000-0000-0000-000000000001'',''d7100000-0000-0000-0000-000000000001'')')),1,'second create dispatched');
select pg_sleep(0.2); select extensions.dblink_exec('rc_block','commit');
create temp table create_results(status text);
insert into create_results select status from extensions.dblink_get_result('rc_one') as t(status text);
insert into create_results select status from extensions.dblink_get_result('rc_two') as t(status text);
select is((select array_agg(status order by status)::text from create_results),'{00000,00000}','concurrent distinct-student creates both succeed');
select is((select count(distinct report_card_number)::int from public.report_cards where student_id in('d7500002-0000-0000-0000-000000000002','d7500003-0000-0000-0000-000000000003')),2,'school numbers are unique');
select is((select max(report_card_number)-min(report_card_number) from public.report_cards where student_id in('d7500002-0000-0000-0000-000000000002','d7500003-0000-0000-0000-000000000003')),1::bigint,'concurrent school numbers are contiguous');
select extensions.dblink_disconnect('rc_one'); select extensions.dblink_disconnect('rc_two');
select extensions.dblink_connect('rc_one','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');
select extensions.dblink_connect('rc_two','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');

-- Same-student creation has one winner and one normalized retryable loser.
truncate create_results;
select extensions.dblink_exec('rc_block','begin; do $do$begin perform app_auth.lock_academic_snapshot_domain(''d2000000-0000-0000-0000-000000000001''); end$do$');
select extensions.dblink_send_query('rc_one',format('select app_auth.test_capture_report_card_sql(%L,%L)','d1000000-0000-0000-0000-000000000001','select public.create_report_card(''d7500004-0000-0000-0000-000000000004'',''d7400000-0000-0000-0000-000000000001'',''d7100000-0000-0000-0000-000000000001'')'));
select extensions.dblink_send_query('rc_two',format('select app_auth.test_capture_report_card_sql(%L,%L)','d1000000-0000-0000-0000-000000000001','select public.create_report_card(''d7500004-0000-0000-0000-000000000004'',''d7400000-0000-0000-0000-000000000001'',''d7100000-0000-0000-0000-000000000001'')'));
select pg_sleep(0.2); select extensions.dblink_exec('rc_block','commit');
insert into create_results select status from extensions.dblink_get_result('rc_one') as t(status text);
insert into create_results select status from extensions.dblink_get_result('rc_two') as t(status text);
select is((select array_agg(status order by status)::text from create_results),'{00000,40001}','same-student creation yields one winner and one retryable conflict');
select extensions.dblink_disconnect('rc_one'); select extensions.dblink_disconnect('rc_two');
select extensions.dblink_connect('rc_one','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');
select extensions.dblink_connect('rc_two','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');

-- Create and sign a two-card batch before racing review and finalization.
select is(app_auth.test_capture_report_card_sql('d1000000-0000-0000-0000-000000000001',$q$select * from public.create_report_card_batch('d7400000-0000-0000-0000-000000000001','d7100000-0000-0000-0000-000000000001',array[row('d7500005-0000-0000-0000-000000000005')::public.report_card_batch_student_input,row('d7500006-0000-0000-0000-000000000006')::public.report_card_batch_student_input])$q$),'00000','batch fixture created');
do $$declare c uuid;begin for c in select r.id from public.report_cards r where r.student_id in('d7500005-0000-0000-0000-000000000005','d7500006-0000-0000-0000-000000000006') loop
 perform app_auth.test_capture_report_card_sql('d1000000-0000-0000-0000-000000000002',format('select public.sign_report_card(%L,%L,%L)',c,'subject_teacher','d7300000-0000-0000-0000-000000000001'));
 perform app_auth.test_capture_report_card_sql('d1000000-0000-0000-0000-000000000003',format('select public.sign_report_card(%L,%L,null)',c,'homeroom_teacher'));
 perform app_auth.test_capture_report_card_sql('d1000000-0000-0000-0000-000000000001',format('select public.sign_report_card(%L,%L,null)',c,'administrator_reviewer'));
end loop;end$$;
create temp table race_target as select b.id batch_id,(array_agg(r.id order by r.id))[1] card_id from public.report_card_batches b join public.report_card_batch_items i on i.report_card_batch_id=b.id join public.report_cards r on r.id=i.report_card_id where r.student_id in('d7500005-0000-0000-0000-000000000005','d7500006-0000-0000-0000-000000000006') group by b.id;
create temp table race_results(status text);
select extensions.dblink_exec('rc_block','begin; do $do$begin perform app_auth.lock_academic_snapshot_domain(''d2000000-0000-0000-0000-000000000001''); end$do$');
select extensions.dblink_send_query('rc_one',format('select app_auth.test_capture_report_card_sql(%L,%L)','d1000000-0000-0000-0000-000000000001',format('select public.review_report_card_batch(%L)',(select batch_id from race_target))));
select extensions.dblink_send_query('rc_two',format('select app_auth.test_capture_report_card_sql(%L,%L)','d1000000-0000-0000-0000-000000000001',format('select public.review_report_card_batch(%L)',(select batch_id from race_target))));
select pg_sleep(0.2); select extensions.dblink_exec('rc_block','commit');
insert into race_results select status from extensions.dblink_get_result('rc_one') as t(status text); insert into race_results select status from extensions.dblink_get_result('rc_two') as t(status text);
select is((select array_agg(status order by status)::text from race_results),'{00000,40001}','concurrent batch review yields one winner and one retryable conflict');
select extensions.dblink_disconnect('rc_one'); select extensions.dblink_disconnect('rc_two');
select extensions.dblink_connect('rc_one','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');
select extensions.dblink_connect('rc_two','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');

truncate race_results;
select extensions.dblink_exec('rc_block','begin; do $do$begin perform app_auth.lock_academic_snapshot_domain(''d2000000-0000-0000-0000-000000000001''); end$do$');
select extensions.dblink_send_query('rc_one',format('select app_auth.test_capture_report_card_sql(%L,%L)','d1000000-0000-0000-0000-000000000001',format('select public.finalize_report_card(%L)',(select card_id from race_target))));
select extensions.dblink_send_query('rc_two',format('select app_auth.test_capture_report_card_sql(%L,%L)','d1000000-0000-0000-0000-000000000001',format('select public.finalize_report_card(%L)',(select card_id from race_target))));
select pg_sleep(0.2); select extensions.dblink_exec('rc_block','commit');
insert into race_results select status from extensions.dblink_get_result('rc_one') as t(status text); insert into race_results select status from extensions.dblink_get_result('rc_two') as t(status text);
select is((select array_agg(status order by status)::text from race_results),'{00000,40001}','concurrent finalization yields one winner and one retryable conflict');
select extensions.dblink_disconnect('rc_one'); select extensions.dblink_disconnect('rc_two');
select extensions.dblink_connect('rc_one','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');
select extensions.dblink_connect('rc_two','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');

truncate race_results;
create temp table correction_target as select id from public.report_cards where student_id='d7500000-0000-0000-0000-000000000001' and status='published';
select extensions.dblink_exec('rc_block','begin; do $do$begin perform app_auth.lock_academic_snapshot_domain(''d2000000-0000-0000-0000-000000000001''); end$do$');
select extensions.dblink_send_query('rc_one',format('select app_auth.test_capture_report_card_sql(%L,%L)','d1000000-0000-0000-0000-000000000001',format('select * from public.correct_report_card(%L,%L)',(select id from correction_target),'concurrent correction one')));
select extensions.dblink_send_query('rc_two',format('select app_auth.test_capture_report_card_sql(%L,%L)','d1000000-0000-0000-0000-000000000001',format('select * from public.correct_report_card(%L,%L)',(select id from correction_target),'concurrent correction two')));
select pg_sleep(0.2); select extensions.dblink_exec('rc_block','commit');
insert into race_results select status from extensions.dblink_get_result('rc_one') as t(status text); insert into race_results select status from extensions.dblink_get_result('rc_two') as t(status text);
select is((select array_agg(status order by status)::text from race_results),'{00000,40001}','double correction yields one successor and one retryable conflict');
select is((select count(*)::int from public.report_cards where supersedes_report_card_id=(select id from correction_target)),1,'double correction creates exactly one successor');

select extensions.dblink_disconnect('rc_one'); select extensions.dblink_disconnect('rc_two'); select extensions.dblink_disconnect('rc_block');
drop function app_auth.test_capture_report_card_sql(uuid,text);
select * from finish();
