begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

select has_column('public','student_identifiers','status','identifier lifecycle status exists');
select has_column('public','student_addresses','status','address lifecycle status exists');
select has_column('public','student_emergency_contacts','status','emergency-contact lifecycle status exists');
select has_table('public','student_document_upload_intents','upload intent capability table exists');
select ok((select relrowsecurity and relforcerowsecurity from pg_class where oid='public.student_document_upload_intents'::regclass),'upload intents force RLS');
select ok(not has_table_privilege('authenticated','public.student_document_upload_intents','SELECT,INSERT,UPDATE,DELETE'),'authenticated has no upload-intent table access');
select ok(has_table_privilege('service_role','public.student_document_upload_intents','SELECT,INSERT') and not has_table_privilege('service_role','public.student_document_upload_intents','UPDATE,DELETE'),'service role has deliberate intent create/read only');
select is((select count(*)::int from public.permissions where code='students.sensitive_manage'),1,'sensitive manage permission seeded once');
select has_index('public','student_identifiers','student_identifiers_non_archived_value_key','identifier history-aware uniqueness exists');
select has_index('public','student_addresses','student_addresses_one_active_primary_type_idx','active primary address uniqueness exists');
select has_index('public','student_emergency_contacts','student_emergency_contacts_one_active_priority_idx','active emergency priority uniqueness exists');
select has_index('public','audit_log','audit_log_command_entity_key','multi-aggregate audit correlation index exists');
select has_index('public','event_outbox','event_outbox_command_event_key','multi-aggregate event correlation index exists');
select ok(not exists(select 1 from pg_policies where schemaname='public' and tablename in ('students','guardians','student_guardians','student_identifiers','student_addresses','student_emergency_contacts','student_documents') and cmd in ('INSERT','UPDATE','DELETE')),'legacy SIS write policies removed');
select ok(not exists(select 1 from (values('students'),('guardians'),('student_guardians'),('student_identifiers'),('student_addresses'),('student_emergency_contacts'),('student_documents')) t(n) where has_table_privilege('authenticated','public.'||n,'INSERT,UPDATE,DELETE,TRUNCATE')),'authenticated has no SIS table writes');

select function_returns('public','archive_student',array['uuid','text'],'uuid','archive_student compatibility preserved');
select function_returns('public','create_guardian_for_student',array['uuid','text','text','text','text','text','text','text','text','text','boolean','boolean','boolean','boolean','boolean','boolean'],'setof record','guardian create has typed table result');
select ok((select (select count(*) from unnest(proargmodes) m where m='t')=2 and proargnames[array_length(proargnames,1)-1:array_length(proargnames,1)]=array['guardian_id','student_guardian_id'] from pg_proc where oid='public.create_guardian_for_student(uuid,text,text,text,text,text,text,text,text,text,boolean,boolean,boolean,boolean,boolean,boolean)'::regprocedure),'guardian result exposes exactly both aggregate IDs');
select ok(not has_function_privilege('anon','public.create_student(uuid,uuid,text,text,text,text,text,date,text,character,text,text,date,date,record_status)','EXECUTE'),'anonymous student create denied');
select ok(not has_function_privilege('authenticated','app_auth.sis_child_command(text,text,uuid,uuid,jsonb)','EXECUTE'),'private dispatcher not client executable');
select ok(has_function_privilege('authenticated','public.create_student_document(uuid,text,text,text,bigint,date,date,student_document_visibility,record_status)','EXECUTE'),'typed document command executable by authenticated');
select ok(position('storage_path' in pg_get_function_identity_arguments('public.create_student_document(uuid,text,text,text,bigint,date,date,student_document_visibility,record_status)'::regprocedure))=0,'document RPC has no storage path input');
create temp table expected_sis_wrappers(signature text) on commit drop;
insert into expected_sis_wrappers values
 ('public.create_student(uuid,uuid,text,text,text,text,text,date,text,character,text,text,date,date,record_status)'),('public.update_student(uuid,text,text,text,boolean,text,text,boolean,date,text,boolean,character,boolean,text,boolean,text,boolean,date,boolean,date,boolean,record_status,uuid,boolean,uuid,boolean)'),('public.archive_student(uuid,text)'),
 ('public.create_guardian_for_student(uuid,text,text,text,text,text,text,text,text,text,boolean,boolean,boolean,boolean,boolean,boolean)'),('public.update_guardian(uuid,text,text,boolean,text,text,boolean,text,boolean,text,boolean,text,boolean,text,boolean,record_status)'),('public.archive_guardian(uuid,text)'),
 ('public.link_guardian_to_student(uuid,uuid,text,boolean,boolean,boolean,boolean,boolean,boolean)'),('public.update_student_guardian(uuid,text,boolean,boolean,boolean,boolean,boolean,boolean,record_status)'),('public.archive_student_guardian(uuid,text)'),
 ('public.create_student_identifier(uuid,text,text,character,date,date,record_status)'),('public.update_student_identifier(uuid,text,text,character,boolean,date,boolean,date,boolean,record_status)'),('public.archive_student_identifier(uuid,text)'),
 ('public.create_student_address(uuid,text,text,text,text,text,text,character,boolean,record_status)'),('public.update_student_address(uuid,text,text,text,boolean,text,text,boolean,text,boolean,character,boolean,record_status)'),('public.archive_student_address(uuid,text)'),
 ('public.create_student_emergency_contact(uuid,uuid,text,text,text,text,smallint,record_status)'),('public.update_student_emergency_contact(uuid,uuid,boolean,text,text,text,text,boolean,smallint,record_status)'),('public.archive_student_emergency_contact(uuid,text)'),
 ('public.create_student_document(uuid,text,text,text,bigint,date,date,student_document_visibility,record_status)'),('public.update_student_document(uuid,text,text,text,boolean,bigint,boolean,date,boolean,date,boolean,student_document_visibility,record_status)'),('public.archive_student_document(uuid,text)');
select ok(not exists(select 1 from expected_sis_wrappers e left join pg_proc p on p.oid=to_regprocedure(e.signature) where p.oid is null or pg_get_userbyid(p.proowner)<>'postgres' or not p.prosecdef or not exists(select 1 from unnest(p.proconfig) c where c like 'search_path=%') or not has_function_privilege('authenticated',p.oid,'EXECUTE') or not has_function_privilege('service_role',p.oid,'EXECUTE') or has_function_privilege('anon',p.oid,'EXECUTE')),'all 21 typed RPCs have exact owner/security/search_path/grants');
select ok(position('from public.organizations' in pg_get_functiondef('app_auth.update_sis_student(uuid,jsonb)'::regprocedure)) < position('from public.schools' in pg_get_functiondef('app_auth.update_sis_student(uuid,jsonb)'::regprocedure)) and position('from public.schools' in pg_get_functiondef('app_auth.update_sis_student(uuid,jsonb)'::regprocedure)) < position('from public.campuses' in pg_get_functiondef('app_auth.update_sis_student(uuid,jsonb)'::regprocedure)) and position('from public.campuses' in pg_get_functiondef('app_auth.update_sis_student(uuid,jsonb)'::regprocedure)) < position('from public.students where id=p_id for update' in pg_get_functiondef('app_auth.update_sis_student(uuid,jsonb)'::regprocedure)),'student update locks organization, sorted destination parents, then target');
select ok(position('lock_sis_students' in pg_get_functiondef('app_auth.assert_guardian_scope(uuid,boolean)'::regprocedure))>0 and position('student_guardians' in pg_get_functiondef('app_auth.assert_guardian_scope(uuid,boolean)'::regprocedure))>0 and position('for update' in lower(pg_get_functiondef('app_auth.assert_guardian_scope(uuid,boolean)'::regprocedure)))>0,'guardian scope locks students, guardian, and links');
select ok(position('guardian links changed concurrently; retry' in pg_get_functiondef('app_auth.assert_guardian_scope(uuid,boolean)'::regprocedure))>0 and position('guardian links changed concurrently; retry' in pg_get_functiondef('app_auth.sis_guardian_link_command(text,uuid,uuid,uuid,jsonb)'::regprocedure))>0,'guardian commands re-read discovered link sets under lock');

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,created_at,updated_at) values
 ('81000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','sis-admin-v04@test','',now(),now()),
 ('81000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','sis-editor-v04@test','',now(),now()),
 ('81000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000000','authenticated','authenticated','sis-suspended-v04@test','',now(),now());
insert into public.organizations(id,name,slug) values
 ('82000000-0000-0000-0000-000000000001','SIS Command Tenant','sis-command-tenant'),
 ('82000000-0000-0000-0000-000000000002','Other SIS Tenant','other-sis-command-tenant');
insert into public.schools(id,organization_id,name,code) values
 ('83000000-0000-0000-0000-000000000001','82000000-0000-0000-0000-000000000001','Command School','CMD'),
 ('83000000-0000-0000-0000-000000000002','82000000-0000-0000-0000-000000000002','Other Command School','OCM');
insert into public.campuses(id,organization_id,school_id,name,code) values
 ('84000000-0000-0000-0000-000000000001','82000000-0000-0000-0000-000000000001','83000000-0000-0000-0000-000000000001','Command Campus','ONE'),
 ('84000000-0000-0000-0000-000000000002','82000000-0000-0000-0000-000000000002','83000000-0000-0000-0000-000000000002','Other Campus','TWO');
insert into public.organization_memberships(id,organization_id,user_id,status,joined_at) values
 ('85000000-0000-0000-0000-000000000001','82000000-0000-0000-0000-000000000001','81000000-0000-0000-0000-000000000001','active',now()),
 ('85000000-0000-0000-0000-000000000002','82000000-0000-0000-0000-000000000001','81000000-0000-0000-0000-000000000002','active',now()),
 ('85000000-0000-0000-0000-000000000003','82000000-0000-0000-0000-000000000001','81000000-0000-0000-0000-000000000003','suspended',now());
insert into public.roles(id,organization_id,code,name) values
 ('86000000-0000-0000-0000-000000000001','82000000-0000-0000-0000-000000000001','SIS_V04_ADMIN','SIS v04 Admin'),
 ('86000000-0000-0000-0000-000000000002','82000000-0000-0000-0000-000000000001','SIS_V04_EDITOR','SIS v04 Editor');
insert into public.role_permissions(organization_id,role_id,permission_id)
 select '82000000-0000-0000-0000-000000000001','86000000-0000-0000-0000-000000000001',id from public.permissions
 where code in ('students.view','students.create','students.edit','students.archive','students.sensitive_view','students.sensitive_manage','student_documents.manage');
insert into public.role_permissions(organization_id,role_id,permission_id)
 select '82000000-0000-0000-0000-000000000001','86000000-0000-0000-0000-000000000002',id from public.permissions where code in ('students.view','students.create','students.edit');
insert into public.role_assignments(organization_id,organization_membership_id,role_id,school_id,campus_id) values
 ('82000000-0000-0000-0000-000000000001','85000000-0000-0000-0000-000000000001','86000000-0000-0000-0000-000000000001',null,null),
 ('82000000-0000-0000-0000-000000000001','85000000-0000-0000-0000-000000000002','86000000-0000-0000-0000-000000000002','83000000-0000-0000-0000-000000000001','84000000-0000-0000-0000-000000000001'),
 ('82000000-0000-0000-0000-000000000001','85000000-0000-0000-0000-000000000003','86000000-0000-0000-0000-000000000001',null,null);

set local role anon;
select throws_ok($$select public.create_student('83000000-0000-0000-0000-000000000001',null,'ANON','A',null,'N',null,'2014-01-01',null,null,null,null,null,null,'active')$$,'42501','permission denied for function create_student','anonymous command denied');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"81000000-0000-0000-0000-000000000003","role":"authenticated"}',true);
select throws_ok($$select public.create_student('83000000-0000-0000-0000-000000000001','84000000-0000-0000-0000-000000000001','SUSP-1','Suspended',null,'Actor',null,'2014-01-01',null,null,null,null,null,null,'active')$$,'42501','students.create permission is required','suspended membership denied');

select set_config('request.jwt.claims','{"sub":"81000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select lives_ok($$select public.create_student('83000000-0000-0000-0000-000000000001','84000000-0000-0000-0000-000000000001','CMD-001','Ada',null,'Student',null,'2014-01-01',null,null,null,null,null,null,'active')$$,'authorized student create succeeds');
select is((select organization_id from public.students where student_number='CMD-001'),'82000000-0000-0000-0000-000000000001'::uuid,'student tenant derived from school');
select is((select created_by from public.students where student_number='CMD-001'),'81000000-0000-0000-0000-000000000001'::uuid,'student attribution derived from actor');
select throws_ok($$select public.create_student('83000000-0000-0000-0000-000000000002','84000000-0000-0000-0000-000000000002','XTEN','Cross',null,'Tenant',null,'2014-01-01',null,null,null,null,null,null,'active')$$,'42501','students.create permission is required','cross-tenant create denied');

select lives_ok($$select * from public.create_guardian_for_student((select id from public.students where student_number='CMD-001'),'Grace',null,'Guardian','guardian@test',null,null,null,null,'parent',true,true,true,true,false,true)$$,'guardian and initial link created atomically');
reset role;
select is((select count(*)::int from public.guardians where email='guardian@test'),1,'one guardian created');
select is((select count(*)::int from public.student_guardians sg join public.guardians g on g.id=sg.guardian_id where g.email='guardian@test'),1,'one initial link created');
select ok((select a.command_id=e.command_id from public.audit_log a join public.event_outbox e using(command_id) where a.action='guardian.created' and e.event_type='guardian.created' limit 1),'guardian event is command correlated');
select is((select count(distinct command_id)::int from public.audit_log where action in ('guardian.created','student.guardian_linked') and entity_id in ((select id from public.guardians where email='guardian@test'),(select id from public.student_guardians limit 1))),1,'guardian and link share one command ID');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"81000000-0000-0000-0000-000000000002","role":"authenticated"}',true);
select throws_ok($$select public.create_student_identifier((select id from public.students where student_number='CMD-001'),'passport','P-SECRET-7788','US',null,null,'active')$$,'42501','students.sensitive_manage permission is required','edit without sensitive manage denied');
select set_config('request.jwt.claims','{"sub":"81000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select lives_ok($$select public.create_student_identifier((select id from public.students where student_number='CMD-001'),'passport','P-SECRET-7788','US',null,null,'active')$$,'sensitive manager creates identifier');
reset role;
select is((select after_data->>'identifier_value' from public.audit_log where action='student.identifier_added' order by occurred_at desc limit 1),'[REDACTED]','identifier audit is redacted');
select ok(not exists(select 1 from public.audit_log where before_data::text like '%P-SECRET-7788%' or after_data::text like '%P-SECRET-7788%'),'raw identifier absent from audit JSON');
select ok(not exists(select 1 from public.event_outbox where payload::text like '%P-SECRET-7788%'),'raw identifier absent from outbox JSON');
select ok(not exists(select 1 from public.audit_log where before_data::text like '%'||encode(convert_to('P-SECRET-7788','UTF8'),'base64')||'%' or after_data::text like '%'||encode(convert_to('P-SECRET-7788','UTF8'),'base64')||'%'),'encoded identifier absent from audit JSON');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"81000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.archive_student_identifier((select id from public.student_identifiers where identifier_value='P-SECRET-7788'),'  ')$$,'22023','archive reason must not be empty','identifier archive requires a reason');
select lives_ok($$select public.archive_student_identifier((select id from public.student_identifiers where identifier_value='P-SECRET-7788'),'superseded')$$,'identifier archive succeeds');
select lives_ok($$select public.create_student_identifier((select id from public.students where student_number='CMD-001'),'passport','P-SECRET-7788','US',null,null,'active')$$,'archived identifier value may be reused');
reset role;

insert into public.student_document_upload_intents(id,organization_id,student_id,storage_path,expires_at,created_by)
 select '87000000-0000-0000-0000-000000000001',organization_id,id,'82000000/docs/authorized.pdf',now()+interval '1 hour','81000000-0000-0000-0000-000000000001' from public.students where student_number='CMD-001';
insert into public.student_document_upload_intents(id,organization_id,student_id,storage_path,expires_at,created_by)
 select '87000000-0000-0000-0000-000000000002',organization_id,id,'82000000/docs/editor-denied.pdf',now()+interval '1 hour','81000000-0000-0000-0000-000000000001' from public.students where student_number='CMD-001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"81000000-0000-0000-0000-000000000002","role":"authenticated"}',true);
select throws_ok($$select public.create_student_document('87000000-0000-0000-0000-000000000002','denied','Denied','application/pdf',10,null,null,'admin_only','active')$$,'42501','student_documents.manage permission is required','document manage permission is independently required');
reset role;
select ok((select consumed_at is null from public.student_document_upload_intents where id='87000000-0000-0000-0000-000000000002'),'denied document command does not consume intent');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"81000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select lives_ok($$select public.create_student_document('87000000-0000-0000-0000-000000000001','passport_copy','Passport copy','application/pdf',100,null,null,'admin_only','active')$$,'document consumes authorized intent');
select throws_ok($$select public.create_student_document('87000000-0000-0000-0000-000000000001','passport_copy','Reuse','application/pdf',100,null,null,'admin_only','active')$$,'22023','upload intent is already consumed','upload intent is single use');
reset role;
select ok((select consumed_at is not null and consumed_by='81000000-0000-0000-0000-000000000001' from public.student_document_upload_intents where id='87000000-0000-0000-0000-000000000001'),'intent consumption attributed atomically');
select is((select storage_path from public.student_documents where document_type='passport_copy'),'82000000/docs/authorized.pdf','document path derived from intent');
select ok(not exists(select 1 from public.event_outbox where event_type='student.document_added' and payload::text like '%authorized.pdf%'),'document path absent from outbox');
select ok(not exists(select 1 from public.event_outbox where event_type='student.document_added' and (payload::text like '%87000000-0000-0000-0000-000000000001%' or payload::text like '%Passport copy%' or payload::text like '%application/pdf%')),'document capability and sensitive metadata absent from outbox');

-- Transition-only requests cannot smuggle business edits.
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"81000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.update_guardian((select id from public.guardians where email='guardian@test'),'Changed',null,false,'Guardian',null,false,null,false,null,false,null,false,null,false,'inactive')$$,'22023','status transition cannot include business or scope changes','guardian transition rejects content mutation');
select lives_ok($$select public.update_guardian((select id from public.guardians where email='guardian@test'),'Grace',null,false,'Guardian','guardian@test',false,null,false,null,false,null,false,null,false,'inactive')$$,'guardian clean inactivation succeeds');
select lives_ok($$select public.update_guardian((select id from public.guardians where email='guardian@test'),'Grace',null,false,'Guardian','guardian@test',false,null,false,null,false,null,false,null,false,'active')$$,'guardian clean reactivation succeeds');
select throws_ok($$select public.update_student_guardian((select sg.id from public.student_guardians sg join public.guardians g on g.id=sg.guardian_id where g.email='guardian@test'),'changed',true,true,true,true,false,true,'inactive')$$,'22023','status transition cannot include business or scope changes','link transition rejects relationship mutation');
select lives_ok($$select public.update_student_guardian((select sg.id from public.student_guardians sg join public.guardians g on g.id=sg.guardian_id where g.email='guardian@test'),'parent',true,true,true,true,false,true,'inactive')$$,'link clean inactivation succeeds');
select lives_ok($$select public.update_student_guardian((select sg.id from public.student_guardians sg join public.guardians g on g.id=sg.guardian_id where g.email='guardian@test'),'parent',true,true,true,true,false,true,'active')$$,'link clean reactivation succeeds');
select throws_ok($$select public.update_student_identifier((select id from public.student_identifiers where identifier_value='P-SECRET-7788' and status='active'),'changed','P-SECRET-7788','US',false,null,false,null,false,'inactive')$$,'22023','status transition cannot include business or scope changes','identifier transition rejects content mutation');
select throws_ok($$select public.update_student_document((select id from public.student_documents where document_type='passport_copy'),'passport_copy','Changed title','application/pdf',false,100,false,null,false,null,false,'admin_only','inactive')$$,'22023','status transition cannot include business or scope changes','document transition rejects metadata mutation');
select is((select first_name from public.guardians where email='guardian@test'),'Grace','failed guardian transition has no row side effect');
select is((select title from public.student_documents where document_type='passport_copy'),'Passport copy','failed document transition has no row side effect');
reset role;
select is((select count(*)::int from public.audit_log where action in ('guardian.updated','student.guardian_updated','student.identifier_updated','student.document_updated') and after_data->>'first_name'='Changed'),0,'failed transitions have no matching audit side effects');
select is((select count(*)::int from public.event_outbox where event_type in ('guardian.updated','student.guardian_updated','student.identifier_updated','student.document_updated') and payload->'changed_fields' ? 'title'),0,'failed transitions have no matching outbox side effects');

-- Emergency contacts validate the effective guardian, not ignored input.
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"81000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select lives_ok($$select public.create_student_emergency_contact((select id from public.students where student_number='CMD-001'),(select id from public.guardians where email='guardian@test'),'Grace Guardian','parent','555-0100',null,1::smallint,'active')$$,'linked emergency guardian accepted');
select lives_ok($$select public.update_student_emergency_contact((select id from public.student_emergency_contacts where phone='555-0100'),'89000000-0000-0000-0000-000000000099',false,'Grace Guardian','parent','555-0100',null,false,1::smallint,'active')$$,'ignored spoof guardian input does not deny');
select lives_ok($$select public.update_student_emergency_contact((select id from public.student_emergency_contacts where phone='555-0100'),null,true,'Grace Guardian','parent','555-0100',null,false,1::smallint,'active')$$,'effective guardian can be cleared');
select lives_ok($$select public.update_student_emergency_contact((select id from public.student_emergency_contacts where phone='555-0100'),(select id from public.guardians where email='guardian@test'),true,'Grace Guardian','parent','555-0100',null,false,1::smallint,'active')$$,'effective guardian can be restored');
select lives_ok($$select public.update_student_emergency_contact((select id from public.student_emergency_contacts where phone='555-0100'),null,false,'Grace Guardian','parent','555-0100',null,false,1::smallint,'inactive')$$,'emergency contact clean inactivation succeeds');
reset role;
update public.student_guardians set status='inactive' where guardian_id=(select id from public.guardians where email='guardian@test');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"81000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.update_student_emergency_contact((select id from public.student_emergency_contacts where phone='555-0100'),'89000000-0000-0000-0000-000000000099',false,'Grace Guardian','parent','555-0100',null,false,1::smallint,'active')$$,'22023','active linked guardian is required','reactivation validates retained effective guardian');
reset role;

-- Independent lifecycle fixture proves inactive parents do not strand cleanup.
insert into public.students(id,organization_id,school_id,campus_id,student_number,first_name,last_name,date_of_birth,status)
 values('88000000-0000-0000-0000-000000000001','82000000-0000-0000-0000-000000000001','83000000-0000-0000-0000-000000000001','84000000-0000-0000-0000-000000000001','LIFE-1','Life','Cycle','2014-01-01','active');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"81000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select lives_ok($$select public.create_student_address('88000000-0000-0000-0000-000000000001','home','1 Main',null,'Town',null,null,'US',true,'active')$$,'active child created');
select throws_ok($$select public.create_student_address('88000000-0000-0000-0000-000000000001',' HOME ','2 Main',null,'Town',null,null,'US',true,'active')$$,'23505',null,'normalized active primary address is unique');
select throws_ok($$select public.create_student_emergency_contact('88000000-0000-0000-0000-000000000001','89000000-0000-0000-0000-000000000099','Unknown','neighbor','12345',null,1::smallint,'active')$$,'22023','active linked guardian is required','unrelated emergency guardian denied');
select throws_ok($$select public.update_student_address((select id from public.student_addresses where student_id='88000000-0000-0000-0000-000000000001'),'home','Changed',null,false,'Town',null,false,null,false,'US',true,'inactive')$$,'22023','status transition cannot include business or scope changes','address transition rejects content mutation');
select lives_ok($$select public.update_student_address((select id from public.student_addresses where student_id='88000000-0000-0000-0000-000000000001'),'home','1 Main',null,false,'Town',null,false,null,false,'US',true,'inactive')$$,'child can be inactivated');
select throws_ok($$select public.update_student('88000000-0000-0000-0000-000000000001','LIFE-1','Changed',null,false,'Cycle',null,false,'2014-01-01',null,false,null,false,null,false,null,false,null,false,null,false,'inactive',null,false,null,false)$$,'22023','status transition cannot include business or scope changes','student transition rejects profile mutation');
select lives_ok($$select public.update_student('88000000-0000-0000-0000-000000000001','LIFE-1','Life',null,false,'Cycle',null,false,'2014-01-01',null,false,null,false,null,false,null,false,null,false,null,false,'inactive',null,false,null,false)$$,'student can become inactive without cascade');
select lives_ok($$select public.archive_student_address((select id from public.student_addresses where student_id='88000000-0000-0000-0000-000000000001'),'cleanup')$$,'inactive child can be archived under inactive parent');
select lives_ok($$select public.archive_student('88000000-0000-0000-0000-000000000001','lifecycle complete')$$,'inactive student archives after active children cleared');
select throws_ok($$select public.update_student_address((select id from public.student_addresses where student_id='88000000-0000-0000-0000-000000000001'),'home','Changed',null,false,'Town',null,false,null,false,'US',true,'active')$$,'22023','archived address is terminal','archived child cannot reactivate');

reset role;
select * from finish();
rollback;
