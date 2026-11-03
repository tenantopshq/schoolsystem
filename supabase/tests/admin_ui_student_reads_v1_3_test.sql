begin;
create extension if not exists pgtap with schema extensions;
select no_plan();
select has_table('app_auth','sis_command_receipts','private replay receipts exist');
select ok(not has_table_privilege('authenticated','app_auth.sis_command_receipts','SELECT,INSERT,UPDATE,DELETE'),'browser cannot access receipts');
select function_returns('public','get_my_admin_contexts',array[]::text[],'setof record','context read contract exists');
select function_returns('public','get_student_admin_detail',array['uuid'],'setof record','detail contract exists');
select function_returns('public','archive_student_v1_3',array['uuid','uuid','text'],'uuid','replay-safe archive exists');
select ok(has_function_privilege('authenticated','public.get_my_admin_contexts()','EXECUTE'),'authenticated context read granted');
select ok(not has_function_privilege('anon','public.get_my_admin_contexts()','EXECUTE'),'anonymous context access denied');
select ok(not has_function_privilege('authenticated','public.archive_student(uuid,text)','EXECUTE'),'legacy archive unavailable to browser');
select ok(not has_function_privilege('authenticated','public.create_student(uuid,uuid,text,text,text,text,text,date,text,character,text,text,date,date,record_status)','EXECUTE'),'legacy create unavailable to browser');
select ok(not has_function_privilege('authenticated','public.update_student(uuid,text,text,text,boolean,text,text,boolean,date,text,boolean,character,boolean,text,boolean,text,boolean,date,boolean,date,boolean,record_status,uuid,boolean,uuid,boolean)','EXECUTE'),'legacy update unavailable to browser');
select ok(has_function_privilege('service_role','public.archive_student(uuid,text)','EXECUTE'),'legacy trusted bridge retained');
select ok(has_function_privilege('authenticated','public.archive_student_v1_3(uuid,uuid,text)','EXECUTE'),'v1.3 archive granted');
select has_index('public','students','students_directory_name_trgm_idx','name search index exists');
select has_index('public','students','students_directory_campus_updated_cursor_idx','campus cursor index exists');
set local role anon;
select throws_ok($$select * from public.get_my_admin_contexts()$$,'42501','permission denied for function get_my_admin_contexts','anonymous denied');
reset role;

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,created_at,updated_at) values
 ('91000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','v13-admin@test','',now(),now()),
 ('91000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','v13-no-permission@test','',now(),now()),
 ('91000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000000','authenticated','authenticated','v13-inactive@test','',now(),now());
insert into public.organizations(id,name,slug) values
 ('92000000-0000-0000-0000-000000000001','V13 Tenant','v13-tenant'),
 ('92000000-0000-0000-0000-000000000002','Other V13 Tenant','other-v13-tenant');
insert into public.schools(id,organization_id,name,code) values
 ('93000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000001','V13 School','V13'),
 ('93000000-0000-0000-0000-000000000002','92000000-0000-0000-0000-000000000002','Other School','OTH');
insert into public.campuses(id,organization_id,school_id,name,code) values
 ('94000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-000000000001','Allowed Campus','A'),
 ('94000000-0000-0000-0000-000000000002','92000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-000000000001','Denied Campus','D'),
 ('94000000-0000-0000-0000-000000000003','92000000-0000-0000-0000-000000000002','93000000-0000-0000-0000-000000000002','Other Campus','O');
insert into public.organization_memberships(id,organization_id,user_id,status,joined_at) values
 ('95000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000001','91000000-0000-0000-0000-000000000001','active',now()),
 ('95000000-0000-0000-0000-000000000002','92000000-0000-0000-0000-000000000001','91000000-0000-0000-0000-000000000002','active',now()),
 ('95000000-0000-0000-0000-000000000003','92000000-0000-0000-0000-000000000001','91000000-0000-0000-0000-000000000003','suspended',now());
insert into public.roles(id,organization_id,code,name) values ('96000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000001','V13_ADMIN','V13 Admin');
insert into public.role_permissions(organization_id,role_id,permission_id)
 select '92000000-0000-0000-0000-000000000001','96000000-0000-0000-0000-000000000001',id from public.permissions
 where code in ('students.view','students.create','students.edit','students.archive','student_documents.manage');
insert into public.role_assignments(id,organization_id,organization_membership_id,role_id,school_id,campus_id) values
 ('97000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000001','95000000-0000-0000-0000-000000000001','96000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-000000000001','94000000-0000-0000-0000-000000000001'),
 ('97000000-0000-0000-0000-000000000002','92000000-0000-0000-0000-000000000001','95000000-0000-0000-0000-000000000003','96000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-000000000001','94000000-0000-0000-0000-000000000001');
insert into public.students(id,organization_id,school_id,campus_id,student_number,first_name,last_name,date_of_birth,status) values
 ('98000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-000000000001','94000000-0000-0000-0000-000000000001','LIT%01','Allowed','Student','2014-01-01','active'),
 ('98000000-0000-0000-0000-000000000002','92000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-000000000001','94000000-0000-0000-0000-000000000002','LITX01','Denied','Campus','2014-01-01','active'),
 ('98000000-0000-0000-0000-000000000003','92000000-0000-0000-0000-000000000002','93000000-0000-0000-0000-000000000002','94000000-0000-0000-0000-000000000003','OTHER','Other','Tenant','2014-01-01','active');
insert into public.guardians(id,organization_id,first_name,last_name,email,status) values
 ('99000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000001','Private','Guardian','secret-guardian@test','active');
insert into public.student_guardians(id,organization_id,student_id,guardian_id,relationship_type,is_primary,status) values
 ('99100000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000001','98000000-0000-0000-0000-000000000001','99000000-0000-0000-0000-000000000001','parent',true,'active');
insert into public.student_documents(id,organization_id,student_id,document_type,title,storage_path,visibility,status) values
 ('99200000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000001','98000000-0000-0000-0000-000000000001','consent','Consent','private/secret.pdf','staff','active');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"91000000-0000-0000-0000-000000000002","role":"authenticated"}',true);
select is((select count(*)::int from public.get_my_admin_contexts()),0,'missing-permission actor has no contexts');
select throws_ok($$select * from public.search_students('92000000-0000-0000-0000-000000000001')$$,'42501','students.view permission is required','missing permission denied');
select set_config('request.jwt.claims','{"sub":"91000000-0000-0000-0000-000000000003","role":"authenticated"}',true);
select is((select count(*)::int from public.get_my_admin_contexts()),0,'inactive membership has no contexts');
select throws_ok($$select * from public.search_students('92000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-000000000001','94000000-0000-0000-0000-000000000001')$$,'42501','students.view permission is required','inactive membership denied');
select set_config('request.jwt.claims','{"sub":"91000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select is((select count(*)::int from public.get_my_admin_contexts()),1,'context is limited to assigned campus');
select is((select scope_level from public.get_my_admin_contexts()),'campus','context scope is campus');
select ok((select to_jsonb(c)-array['membership_id','organization_id','organization_name','organization_slug','school_id','school_name','school_code','campus_id','campus_name','campus_code','scope_level','permission_codes'] = '{}'::jsonb from public.get_my_admin_contexts() c),'context exposes only allowlisted fields');
select throws_ok($$select * from public.search_students('92000000-0000-0000-0000-000000000002','93000000-0000-0000-0000-000000000002','94000000-0000-0000-0000-000000000003')$$,'42501','students.view permission is required','cross-tenant search denied');
select throws_ok($$select * from public.search_students('92000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-000000000001','94000000-0000-0000-0000-000000000002')$$,'42501','students.view permission is required','wrong-campus search denied');
select is((select count(*)::int from public.search_students('92000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-000000000001','94000000-0000-0000-0000-000000000001','%',null)),1,'literal percent search is escaped and scoped');
select ok((select to_jsonb(s)-array['student_id','student_number','first_name','last_name','preferred_name','status','school_id','school_name','campus_id','campus_name','updated_at','sort_cursor_value','total_count'] = '{}'::jsonb from public.search_students('92000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-000000000001','94000000-0000-0000-0000-000000000001') s limit 1),'search exposes only allowlisted fields');
select ok((select position('secret-guardian@test' in to_jsonb(d)::text)=0 and position('private/secret.pdf' in to_jsonb(d)::text)=0 from public.get_student_admin_detail('98000000-0000-0000-0000-000000000001') d),'detail omits guardian contact and storage path');
select ok((select (guardian_links->0)-array['link_id','guardian_id','first_name','middle_name','last_name','relationship_type','is_primary','has_portal_access','status']='{}'::jsonb and (documents->0)-array['id','document_type','title','mime_type','file_size','issued_at','expires_at','visibility','status']='{}'::jsonb from public.get_student_admin_detail('98000000-0000-0000-0000-000000000001')),'detail child objects use exact allowlists');
select is((select count(*)::int from public.get_student_admin_detail('98000000-0000-0000-0000-000000000002')),0,'detail campus boundary enforced');
select throws_ok($$insert into public.students(organization_id,school_id,student_number,first_name,last_name,date_of_birth) values('92000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-000000000001','DIRECT','Direct','Write','2014-01-01')$$,'42501','permission denied for table students','direct browser mutation denied');
select throws_ok($$select public.create_student('93000000-0000-0000-0000-000000000001','94000000-0000-0000-0000-000000000001','LEGACY','Legacy',null,'Write',null,'2014-01-01',null,null,null,null,null,null,'active')$$,'42501','permission denied for function create_student','legacy browser command denied');
create temp table v13_result(id uuid);
insert into v13_result select public.create_student_v1_3('99300000-0000-0000-0000-000000000001','93000000-0000-0000-0000-000000000001','94000000-0000-0000-0000-000000000001','REPLAY-1','Replay',null,'Student',null,'2014-02-01',null,null,null,null,null,null,'active');
select lives_ok($$select public.create_student_v1_3('99300000-0000-0000-0000-000000000001','93000000-0000-0000-0000-000000000001','94000000-0000-0000-0000-000000000001','REPLAY-1','Replay',null,'Student',null,'2014-02-01',null,null,null,null,null,null,'active')$$,'identical request replays successfully');
reset role;
select is((select count(*)::int from public.students where student_number='REPLAY-1'),1,'replay creates one student');
select is((select count(*)::int from public.audit_log where entity_id=(select id from v13_result)),1,'replay writes one audit row');
select is((select count(*)::int from public.event_outbox where aggregate_id=(select id from v13_result)),1,'replay writes one outbox row');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"91000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.create_student_v1_3('99300000-0000-0000-0000-000000000001','93000000-0000-0000-0000-000000000001','94000000-0000-0000-0000-000000000001','DIFFERENT','Replay',null,'Student',null,'2014-02-01',null,null,null,null,null,null,'active')$$,'22023','request_id was reused with different arguments','conflicting request reuse denied');
select throws_ok($$select public.create_student_v1_3('99300000-0000-0000-0000-000000000009','93000000-0000-0000-0000-000000000099',null,'MISSING','Missing',null,'School',null,'2014-02-01',null,null,null,null,null,null,'active')$$,'42501','student command target is unavailable','missing create target is normalized');
select throws_ok($$select public.create_student_v1_3('99300000-0000-0000-0000-000000000010','93000000-0000-0000-0000-000000000001','94000000-0000-0000-0000-000000000002','DENIED','Denied',null,'Campus',null,'2014-02-01',null,null,null,null,null,null,'active')$$,'42501','student command target is unavailable','unauthorized create scope is normalized');
reset role;
update public.role_assignments set status='inactive' where id='97000000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"91000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.create_student_v1_3('99300000-0000-0000-0000-000000000001','93000000-0000-0000-0000-000000000001','94000000-0000-0000-0000-000000000001','REPLAY-1','Replay',null,'Student',null,'2014-02-01',null,null,null,null,null,null,'active')$$,'42501','student command target is unavailable','create permission revocation blocks replay');
reset role;
update public.role_assignments set status='active' where id='97000000-0000-0000-0000-000000000001';

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"91000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select lives_ok($$select public.update_student_v1_3('99300000-0000-0000-0000-000000000002',(select id from v13_result),'REPLAY-1','Replay Updated',null,true,'Student',null,true,'2014-02-01',null,true,null,true,null,true,null,false,null,true,null,true,'active',null,false,null,false)$$,'update succeeds');
select lives_ok($$select public.update_student_v1_3('99300000-0000-0000-0000-000000000002',(select id from v13_result),'REPLAY-1','Replay Updated',null,true,'Student',null,true,'2014-02-01',null,true,null,true,null,true,null,false,null,true,null,true,'active',null,false,null,false)$$,'identical update replays');
select throws_ok($$select public.update_student_v1_3('99300000-0000-0000-0000-000000000002',(select id from v13_result),'REPLAY-1','Conflict',null,true,'Student',null,true,'2014-02-01',null,true,null,true,null,true,null,false,null,true,null,true,'active',null,false,null,false)$$,'22023','request_id was reused with different arguments','conflicting update request reuse denied');
select throws_ok($$select public.update_student_v1_3('99300000-0000-0000-0000-000000000011','98000000-0000-0000-0000-000000000099','X','Missing',null,true,'Student',null,true,'2014-02-01',null,true,null,true,null,true,null,false,null,true,null,true,'active',null,false,null,false)$$,'42501','student command target is unavailable','missing update target is normalized');
select throws_ok($$select public.update_student_v1_3('99300000-0000-0000-0000-000000000012','98000000-0000-0000-0000-000000000002','LITX01','Denied',null,true,'Campus',null,true,'2014-01-01',null,true,null,true,null,true,null,false,null,true,null,true,'active',null,false,null,false)$$,'42501','student command target is unavailable','unauthorized update target is normalized');
reset role;
select is((select first_name from public.students where id=(select id from v13_result)),'Replay Updated','update mutates once to requested value');
select is((select count(*)::int from public.audit_log where entity_id=(select id from v13_result) and action='student.updated'),1,'update replay writes one audit row');
select is((select count(*)::int from public.event_outbox where aggregate_id=(select id from v13_result) and event_type='student.updated'),1,'update replay writes one outbox row');
update public.role_assignments set status='inactive' where id='97000000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"91000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.update_student_v1_3('99300000-0000-0000-0000-000000000002',(select id from v13_result),'REPLAY-1','Replay Updated',null,true,'Student',null,true,'2014-02-01',null,true,null,true,null,true,null,false,null,true,null,true,'active',null,false,null,false)$$,'42501','student command target is unavailable','update permission revocation blocks replay');
reset role;
update public.role_assignments set status='active' where id='97000000-0000-0000-0000-000000000001';

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"91000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select lives_ok($$select public.archive_student_v1_3('99300000-0000-0000-0000-000000000003',(select id from v13_result),'completed test lifecycle')$$,'archive succeeds');
select lives_ok($$select public.archive_student_v1_3('99300000-0000-0000-0000-000000000003',(select id from v13_result),'completed test lifecycle')$$,'identical archive replays');
select throws_ok($$select public.archive_student_v1_3('99300000-0000-0000-0000-000000000003',(select id from v13_result),'different reason')$$,'22023','request_id was reused with different arguments','conflicting archive request reuse denied');
select throws_ok($$select public.archive_student_v1_3('99300000-0000-0000-0000-000000000013','98000000-0000-0000-0000-000000000099','missing')$$,'42501','student command target is unavailable','missing archive target is normalized');
select throws_ok($$select public.archive_student_v1_3('99300000-0000-0000-0000-000000000014','98000000-0000-0000-0000-000000000002','denied')$$,'42501','student command target is unavailable','unauthorized archive target is normalized');
reset role;
select is((select status::text from public.students where id=(select id from v13_result)),'archived','archive mutates once');
select is((select count(*)::int from public.audit_log where entity_id=(select id from v13_result) and action='student.archived'),1,'archive replay writes one audit row');
select is((select count(*)::int from public.event_outbox where aggregate_id=(select id from v13_result) and event_type='student.archived'),1,'archive replay writes one outbox row');
update public.role_assignments set status='inactive' where id='97000000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"91000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.archive_student_v1_3('99300000-0000-0000-0000-000000000003',(select id from v13_result),'completed test lifecycle')$$,'42501','student command target is unavailable','archive permission revocation blocks replay');
reset role;
select * from finish();
rollback;
