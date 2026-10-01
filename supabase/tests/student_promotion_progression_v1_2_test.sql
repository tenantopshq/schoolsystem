begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

select has_type('public','progression_disposition','disposition enum exists');
select has_type('public','progression_decision_status','decision status exists');
select has_type('public','progression_eligibility_state','eligibility state exists');
select has_type('public','progression_batch_status','batch status exists');
select is(enum_range(null::public.progression_disposition)::text,'{promotion,retention,graduation,transfer,withdrawal}','dispositions are exact');
select is(enum_range(null::public.progression_decision_status)::text,'{pending,approved,executed,cancelled,corrected}','decision lifecycle is exact');
select is(enum_range(null::public.progression_batch_status)::text,'{draft,approved,completed}','stored batch lifecycle is minimal');
select has_table('public','progression_decisions','decisions exist');
select has_table('public','progression_eligibility_evaluations','immutable evaluations exist');
select has_table('public','progression_decision_evidence','immutable evidence exists');
select has_table('public','progression_batches','batches exist');
select has_table('public','progression_batch_items','batch items exist');
select has_view('public','progression_batch_progress','batch progress view exists');
select has_view('public','student_progression_outcomes','safe family view exists');
select is((select count(*)::int from public.permissions where code like 'progression.%'),6,'six scoped permissions exist');
select ok((select bool_and(c.relrowsecurity and c.relforcerowsecurity) from pg_class c where c.oid=any(array[
 'public.progression_decisions'::regclass,'public.progression_eligibility_evaluations'::regclass,
 'public.progression_decision_evidence'::regclass,'public.progression_batches'::regclass,'public.progression_batch_items'::regclass])),'all public progression tables force RLS');
select ok(not has_table_privilege('authenticated','public.progression_decisions','INSERT,UPDATE,DELETE,TRUNCATE'),'decisions are SELECT-only');
select ok(not has_table_privilege('authenticated','public.progression_decision_evidence','INSERT,UPDATE,DELETE,TRUNCATE'),'evidence is SELECT-only');
select ok(not has_table_privilege('authenticated','app_auth.progression_command_receipts','SELECT,INSERT,UPDATE,DELETE'),'receipts are private');
select ok(not has_table_privilege('anon','public.progression_decisions','SELECT'),'anonymous base read denied');
select has_index('public','progression_decisions','progression_one_root_per_source','one unresolved root guard exists');
select has_index('public','progression_decisions','progression_one_successor','correction cannot branch');

create temp table expected_progression_rpcs(signature text) on commit drop;
insert into expected_progression_rpcs values
 ('public.create_progression_decision(uuid,uuid,uuid,progression_disposition,date,uuid,uuid,uuid,uuid,uuid,date,text)'),
 ('public.refresh_progression_eligibility(uuid,uuid)'),('public.approve_progression_decision(uuid,uuid,text)'),
 ('public.execute_progression_decision(uuid,uuid)'),('public.cancel_progression_decision(uuid,uuid,text)'),
 ('public.create_progression_correction(uuid,uuid,progression_disposition,date,uuid,uuid,uuid,uuid,uuid,date,text,text)'),
 ('public.create_progression_batch(uuid,uuid,uuid,progression_batch_decision_input[])'),
 ('public.approve_progression_batch(uuid,uuid,text)'),('public.execute_progression_batch_item(uuid,uuid,uuid)'),
 ('public.cancel_progression_batch(uuid,uuid,text)');
select ok(not exists(select 1 from expected_progression_rpcs where to_regprocedure(signature)is null),'all typed RPCs exist');
select ok(not exists(select 1 from expected_progression_rpcs e join pg_proc p on p.oid=to_regprocedure(e.signature)
 where not p.prosecdef or pg_get_userbyid(p.proowner)<>'postgres' or not exists(select 1 from unnest(p.proconfig)c where c like 'search_path=%')),'RPC security attributes are exact');
select ok(not exists(select 1 from expected_progression_rpcs e join pg_proc p on p.oid=to_regprocedure(e.signature)
 where has_function_privilege('anon',p.oid,'EXECUTE') or has_function_privilege('service_role',p.oid,'EXECUTE') or not has_function_privilege('authenticated',p.oid,'EXECUTE')),'RPC grants are exact');
select ok(not has_function_privilege('authenticated','app_auth.execute_progression_enrollment_effect(uuid,uuid,uuid)','EXECUTE'),'enrollment execution service is private');
select ok(not has_function_privilege('authenticated','app_auth.claim_progression_receipt(uuid,uuid,text,uuid,bytea)','EXECUTE'),'receipt claim is private');

set local role anon;
select throws_ok($$select public.refresh_progression_eligibility(gen_random_uuid(),gen_random_uuid())$$,'42501','permission denied for function refresh_progression_eligibility','anonymous command denied');
reset role;
select throws_ok($$insert into public.progression_decisions(id)values(gen_random_uuid())$$,'23502',null,'forged decision rejected');

-- Three separated actors plus a limited cross-school actor and a portal student.
insert into auth.users(id,instance_id,aud,role,email,encrypted_password,created_at,updated_at) values
 ('a1100000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','creator@progress.test','',now(),now()),
 ('a1100000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','approver@progress.test','',now(),now()),
 ('a1100000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000000','authenticated','authenticated','executor@progress.test','',now(),now()),
 ('a1100000-0000-0000-0000-000000000004','00000000-0000-0000-0000-000000000000','authenticated','authenticated','limited@progress.test','',now(),now()),
 ('a1100000-0000-0000-0000-000000000005','00000000-0000-0000-0000-000000000000','authenticated','authenticated','student@progress.test','',now(),now());
insert into public.organizations(id,name,slug) values('a1200000-0000-0000-0000-000000000001','Progress Tenant','progress-tenant');
insert into public.schools(id,organization_id,name,code) values
 ('a1300000-0000-0000-0000-000000000001','a1200000-0000-0000-0000-000000000001','Source School','SRC'),
 ('a1300000-0000-0000-0000-000000000002','a1200000-0000-0000-0000-000000000001','Other School','DST');
insert into public.campuses(id,organization_id,school_id,name,code) values
 ('a1400000-0000-0000-0000-000000000001','a1200000-0000-0000-0000-000000000001','a1300000-0000-0000-0000-000000000001','Source Campus','SC'),
 ('a1400000-0000-0000-0000-000000000002','a1200000-0000-0000-0000-000000000001','a1300000-0000-0000-0000-000000000002','Other Campus','DC');
insert into public.organization_memberships(id,organization_id,user_id,status,joined_at) values
 ('a1500000-0000-0000-0000-000000000001','a1200000-0000-0000-0000-000000000001','a1100000-0000-0000-0000-000000000001','active',now()),
 ('a1500000-0000-0000-0000-000000000002','a1200000-0000-0000-0000-000000000001','a1100000-0000-0000-0000-000000000002','active',now()),
 ('a1500000-0000-0000-0000-000000000003','a1200000-0000-0000-0000-000000000001','a1100000-0000-0000-0000-000000000003','active',now()),
 ('a1500000-0000-0000-0000-000000000004','a1200000-0000-0000-0000-000000000001','a1100000-0000-0000-0000-000000000004','active',now());
insert into public.roles(id,organization_id,code,name) values
 ('a1600000-0000-0000-0000-000000000001','a1200000-0000-0000-0000-000000000001','PROGRESSION_ADMIN','Progression Admin'),
 ('a1600000-0000-0000-0000-000000000002','a1200000-0000-0000-0000-000000000001','PROGRESSION_LIMITED','Progression Limited');
insert into public.role_permissions(organization_id,role_id,permission_id)
 select 'a1200000-0000-0000-0000-000000000001','a1600000-0000-0000-0000-000000000001',id from public.permissions where code like 'progression.%';
insert into public.role_permissions(organization_id,role_id,permission_id)
 select 'a1200000-0000-0000-0000-000000000001','a1600000-0000-0000-0000-000000000002',id from public.permissions where code in('progression.view','progression.manage');
insert into public.role_assignments(organization_id,organization_membership_id,role_id) values
 ('a1200000-0000-0000-0000-000000000001','a1500000-0000-0000-0000-000000000001','a1600000-0000-0000-0000-000000000001'),
 ('a1200000-0000-0000-0000-000000000001','a1500000-0000-0000-0000-000000000002','a1600000-0000-0000-0000-000000000001'),
 ('a1200000-0000-0000-0000-000000000001','a1500000-0000-0000-0000-000000000003','a1600000-0000-0000-0000-000000000001');
insert into public.role_assignments(organization_id,organization_membership_id,role_id,school_id) values
 ('a1200000-0000-0000-0000-000000000001','a1500000-0000-0000-0000-000000000004','a1600000-0000-0000-0000-000000000002','a1300000-0000-0000-0000-000000000001');

insert into public.academic_years(id,organization_id,school_id,name,start_date,end_date,status) values
 ('a1700000-0000-0000-0000-000000000001','a1200000-0000-0000-0000-000000000001','a1300000-0000-0000-0000-000000000001','2026-27','2026-01-01','2026-12-31','active'),
 ('a1700000-0000-0000-0000-000000000002','a1200000-0000-0000-0000-000000000001','a1300000-0000-0000-0000-000000000001','2027-28','2027-01-01','2027-12-31','active'),
 ('a1700000-0000-0000-0000-000000000003','a1200000-0000-0000-0000-000000000001','a1300000-0000-0000-0000-000000000002','2027-28','2027-01-01','2027-12-31','active');
insert into public.grade_levels(id,organization_id,school_id,code,name,sequence,status) values
 ('a1800000-0000-0000-0000-000000000001','a1200000-0000-0000-0000-000000000001','a1300000-0000-0000-0000-000000000001','G1','Grade 1',1,'active'),
 ('a1800000-0000-0000-0000-000000000002','a1200000-0000-0000-0000-000000000001','a1300000-0000-0000-0000-000000000001','G2','Grade 2',2,'active'),
 ('a1800000-0000-0000-0000-000000000003','a1200000-0000-0000-0000-000000000001','a1300000-0000-0000-0000-000000000002','G2','Grade 2',2,'active');
insert into public.sections(id,organization_id,school_id,campus_id,academic_year_id,grade_level_id,code,name,capacity,start_date,end_date,status) values
 ('a1900000-0000-0000-0000-000000000001','a1200000-0000-0000-0000-000000000001','a1300000-0000-0000-0000-000000000001','a1400000-0000-0000-0000-000000000001','a1700000-0000-0000-0000-000000000001','a1800000-0000-0000-0000-000000000001','1A','Grade 1 A',20,'2026-01-01','2026-12-31','active'),
 ('a1900000-0000-0000-0000-000000000002','a1200000-0000-0000-0000-000000000001','a1300000-0000-0000-0000-000000000001','a1400000-0000-0000-0000-000000000001','a1700000-0000-0000-0000-000000000002','a1800000-0000-0000-0000-000000000002','2A','Grade 2 A',20,'2027-01-01','2027-12-31','active'),
 ('a1900000-0000-0000-0000-000000000003','a1200000-0000-0000-0000-000000000001','a1300000-0000-0000-0000-000000000002','a1400000-0000-0000-0000-000000000002','a1700000-0000-0000-0000-000000000003','a1800000-0000-0000-0000-000000000003','2B','Grade 2 B',1,'2027-01-01','2027-12-31','active');
insert into public.students(id,organization_id,school_id,campus_id,user_id,student_number,first_name,last_name,date_of_birth,status) values
 ('a2000000-0000-0000-0000-000000000001','a1200000-0000-0000-0000-000000000001','a1300000-0000-0000-0000-000000000001','a1400000-0000-0000-0000-000000000001','a1100000-0000-0000-0000-000000000005','P1','Portal','Student','2018-01-01','active'),
 ('a2000000-0000-0000-0000-000000000002','a1200000-0000-0000-0000-000000000001','a1300000-0000-0000-0000-000000000001','a1400000-0000-0000-0000-000000000001',null,'P2','Batch','Two','2018-01-01','active'),
 ('a2000000-0000-0000-0000-000000000003','a1200000-0000-0000-0000-000000000001','a1300000-0000-0000-0000-000000000001','a1400000-0000-0000-0000-000000000001',null,'P3','Batch','Three','2018-01-01','active');
insert into public.student_enrollments(id,organization_id,school_id,academic_year_id,student_id,grade_level_id,enrolled_on,scheduled_end_on,enrollment_range,status,created_by,updated_by) values
 ('a2100000-0000-0000-0000-000000000001','a1200000-0000-0000-0000-000000000001','a1300000-0000-0000-0000-000000000001','a1700000-0000-0000-0000-000000000001','a2000000-0000-0000-0000-000000000001','a1800000-0000-0000-0000-000000000001','2026-01-01','2026-12-31',daterange('2026-01-01','2026-12-31','[]'),'active','a1100000-0000-0000-0000-000000000001','a1100000-0000-0000-0000-000000000001'),
 ('a2100000-0000-0000-0000-000000000002','a1200000-0000-0000-0000-000000000001','a1300000-0000-0000-0000-000000000001','a1700000-0000-0000-0000-000000000001','a2000000-0000-0000-0000-000000000002','a1800000-0000-0000-0000-000000000001','2026-01-01','2026-12-31',daterange('2026-01-01','2026-12-31','[]'),'active','a1100000-0000-0000-0000-000000000001','a1100000-0000-0000-0000-000000000001'),
 ('a2100000-0000-0000-0000-000000000003','a1200000-0000-0000-0000-000000000001','a1300000-0000-0000-0000-000000000001','a1700000-0000-0000-0000-000000000001','a2000000-0000-0000-0000-000000000003','a1800000-0000-0000-0000-000000000001','2026-01-01','2026-12-31',daterange('2026-01-01','2026-12-31','[]'),'active','a1100000-0000-0000-0000-000000000001','a1100000-0000-0000-0000-000000000001');
insert into public.student_section_placements(organization_id,school_id,campus_id,academic_year_id,student_enrollment_id,student_id,section_id,starts_on,status,created_by,updated_by)
 select 'a1200000-0000-0000-0000-000000000001','a1300000-0000-0000-0000-000000000001','a1400000-0000-0000-0000-000000000001','a1700000-0000-0000-0000-000000000001',e.id,e.student_id,'a1900000-0000-0000-0000-000000000001','2026-01-01','active','a1100000-0000-0000-0000-000000000001','a1100000-0000-0000-0000-000000000001' from public.student_enrollments e where e.id in('a2100000-0000-0000-0000-000000000001','a2100000-0000-0000-0000-000000000002','a2100000-0000-0000-0000-000000000003');

create function app_auth.test_set_progression_actor(p uuid) returns void language plpgsql security definer set search_path='' as $$begin perform set_config('request.jwt.claims',jsonb_build_object('sub',p,'role','authenticated')::text,true);end$$;
revoke all on function app_auth.test_set_progression_actor(uuid) from public,anon,authenticated,service_role;

select app_auth.test_set_progression_actor('a1100000-0000-0000-0000-000000000004');
select throws_ok($$select public.create_progression_decision('b0000000-0000-0000-0000-000000000001','a2000000-0000-0000-0000-000000000001','a2100000-0000-0000-0000-000000000001','transfer','2026-12-31','a1300000-0000-0000-0000-000000000002','a1400000-0000-0000-0000-000000000002','a1700000-0000-0000-0000-000000000003','a1800000-0000-0000-0000-000000000003','a1900000-0000-0000-0000-000000000003','2027-01-01','manual review')$$,'42501',null,'cross-school transfer requires destination authority');

select app_auth.test_set_progression_actor('a1100000-0000-0000-0000-000000000001');
create temp table decision_result(id uuid);
insert into decision_result select public.create_progression_decision('b0000000-0000-0000-0000-000000000002','a2000000-0000-0000-0000-000000000001','a2100000-0000-0000-0000-000000000001','promotion','2026-12-31','a1300000-0000-0000-0000-000000000001','a1400000-0000-0000-0000-000000000001','a1700000-0000-0000-0000-000000000002','a1800000-0000-0000-0000-000000000002','a1900000-0000-0000-0000-000000000002','2027-01-01','approved exception');
select is((select state::text from public.progression_eligibility_evaluations where progression_decision_id=(select id from decision_result)),'incomplete','missing final report-card set is advisory incomplete');
select is(public.create_progression_decision('b0000000-0000-0000-0000-000000000002','a2000000-0000-0000-0000-000000000001','a2100000-0000-0000-0000-000000000001','promotion','2026-12-31','a1300000-0000-0000-0000-000000000001','a1400000-0000-0000-0000-000000000001','a1700000-0000-0000-0000-000000000002','a1800000-0000-0000-0000-000000000002','a1900000-0000-0000-0000-000000000002','2027-01-01','approved exception'),(select id from decision_result),'exact create replay returns original decision');
select throws_ok(format('select public.approve_progression_decision(%L,%L,%L)','b0000000-0000-0000-0000-000000000003',(select id from decision_result),'self approval'), '22023',null,'creator cannot approve');
select app_auth.test_set_progression_actor('a1100000-0000-0000-0000-000000000002');
select is(public.approve_progression_decision('b0000000-0000-0000-0000-000000000004',(select id from decision_result),'reviewed exception'),(select id from decision_result),'different actor approves');
select is(public.approve_progression_decision('b0000000-0000-0000-0000-000000000004',(select id from decision_result),'reviewed exception'),(select id from decision_result),'approval replay is exact after transition');
select throws_ok(format('select public.execute_progression_decision(%L,%L)','b0000000-0000-0000-0000-000000000005',(select id from decision_result)),'22023',null,'approver cannot execute');
select app_auth.test_set_progression_actor('a1100000-0000-0000-0000-000000000003');
select lives_ok(format('select public.execute_progression_decision(%L,%L)','b0000000-0000-0000-0000-000000000006',(select id from decision_result)),'different actor executes atomically');
select lives_ok(format('select public.execute_progression_decision(%L,%L)','b0000000-0000-0000-0000-000000000006',(select id from decision_result)),'execution replay has no duplicate effects');
select is((select count(*)::int from public.student_enrollments where student_id='a2000000-0000-0000-0000-000000000001' and status='active'),1,'execution creates one active destination enrollment');
select is((select count(*)::int from public.event_outbox where aggregate_id=(select id from decision_result) and event_type='student.progression_executed'),1,'execution emits one event despite replay');
select is((select count(*)::int from public.audit_log where entity_id=(select id from decision_result) and action='student.progression_executed'),1,'execution writes one audit despite replay');
select ok(not exists(select 1 from public.event_outbox where aggregate_id=(select id from decision_result) and (payload ? 'eligibility_override_reason' or payload ? 'student_display_name' or payload ? 'source_fingerprint')),'outbox omits private evidence and PII');

-- Forward-only correction preserves both executed histories and appends enrollment repair.
select app_auth.test_set_progression_actor('a1100000-0000-0000-0000-000000000001');
create temp table correction_result(id uuid);
insert into correction_result select public.create_progression_correction('b0000000-0000-0000-0000-000000000007',(select id from decision_result),'graduation','2026-12-31',null,null,null,null,null,null,'approved correction exception','destination was erroneous');
select app_auth.test_set_progression_actor('a1100000-0000-0000-0000-000000000002');
select lives_ok(format('select public.approve_progression_decision(%L,%L,%L)','b0000000-0000-0000-0000-000000000008',(select id from correction_result),'correction reviewed'),'correction successor approves independently');
select app_auth.test_set_progression_actor('a1100000-0000-0000-0000-000000000003');
select lives_ok(format('select public.execute_progression_decision(%L,%L)','b0000000-0000-0000-0000-000000000009',(select id from correction_result)),'correction executes append-only repair');
select is((select status::text from public.progression_decisions where id=(select id from decision_result)),'corrected','executed predecessor becomes corrected');
select is((select status::text from public.progression_decisions where id=(select id from correction_result)),'executed','correction successor is live executed head');
select is((select count(*)::int from public.progression_decisions where lineage_id=(select id from decision_result)),2,'correction lineage preserves both decisions');

select app_auth.test_set_progression_actor('a1100000-0000-0000-0000-000000000005');
set local role authenticated;
select is((select count(*)::int from public.progression_decisions),0,'portal cannot read base decisions');
select is((select count(*)::int from public.student_progression_outcomes),1,'student sees own executed safe outcome');
reset role;

update public.organization_memberships set status='suspended' where user_id='a1100000-0000-0000-0000-000000000004';
select app_auth.test_set_progression_actor('a1100000-0000-0000-0000-000000000004');
set local role authenticated;
select is((select count(*)::int from public.progression_decisions),0,'inactive membership cannot read progression');
reset role;

-- Batch with one execution and one terminal cancellation completes with exceptions.
select app_auth.test_set_progression_actor('a1100000-0000-0000-0000-000000000001');
create temp table batch_result(id uuid,decision_ids uuid[]);
insert into batch_result select (r).batch_id,(r).decision_ids from(select public.create_progression_batch('b0000000-0000-0000-0000-000000000010','a1300000-0000-0000-0000-000000000001','a1700000-0000-0000-0000-000000000001',array[
 row('a2000000-0000-0000-0000-000000000002','a2100000-0000-0000-0000-000000000002','graduation','2026-12-31',null,null,null,null,null,null,'manual completion')::public.progression_batch_decision_input,
 row('a2000000-0000-0000-0000-000000000003','a2100000-0000-0000-0000-000000000003','withdrawal','2026-12-31',null,null,null,null,null,null,'manual completion')::public.progression_batch_decision_input]) r)s;
select app_auth.test_set_progression_actor('a1100000-0000-0000-0000-000000000002');
select lives_ok(format('select public.approve_progression_batch(%L,%L,%L)','b0000000-0000-0000-0000-000000000011',(select id from batch_result),'batch reviewed'),'batch approval succeeds atomically');
select app_auth.test_set_progression_actor('a1100000-0000-0000-0000-000000000003');
select lives_ok(format('select public.execute_progression_batch_item(%L,%L,%L)','b0000000-0000-0000-0000-000000000012',(select id from batch_result),(select decision_ids[1] from batch_result)),'first batch child executes');
select is((select status::text from public.progression_batches where id=(select id from batch_result)),'approved','partial batch remains approved');
select app_auth.test_set_progression_actor('a1100000-0000-0000-0000-000000000001');
select lives_ok(format('select public.cancel_progression_decision(%L,%L,%L)','b0000000-0000-0000-0000-000000000013',(select decision_ids[2] from batch_result),'approved exception'),'remaining child can be cancelled');
select is((select status::text from public.progression_batches where id=(select id from batch_result)),'completed','all-terminal children complete parent');
select is((select outcome::text from public.progression_batch_progress where id=(select id from batch_result)),'completed_with_exceptions','mixed terminal children derive exceptions outcome');
select is((select count(*)::int from public.event_outbox where aggregate_id=(select id from batch_result) and event_type='student.progression_batch_completed'),1,'terminal child emits one correlated batch completion event');

-- Parent lifecycle, history immutability, and rollback.
select throws_ok($$update public.progression_eligibility_evaluations set sequence=99 where progression_decision_id=(select id from decision_result)$$,'22023','progression evidence and batch membership are immutable','evaluation history is immutable');
select is((select count(*)::int from public.student_enrollments where student_id='a2000000-0000-0000-0000-000000000003' and status='active'),1,'cancelled batch child has no enrollment side effect');

select * from finish();
rollback;
