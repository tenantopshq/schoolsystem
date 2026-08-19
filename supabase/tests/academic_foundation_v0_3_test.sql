begin;
create extension if not exists pgtap with schema extensions;
select plan(551);

select has_table('public','staff_profiles','staff profiles exists'); select has_table('public','buildings','buildings exists');
select has_table('public','rooms','rooms exists'); select has_table('public','grade_levels','grade levels exists');
select has_table('public','sections','sections exists'); select has_table('public','subjects','subjects exists');
select ok((select bool_and(relrowsecurity and relforcerowsecurity) from pg_class where oid in ('public.staff_profiles'::regclass,'public.buildings'::regclass,'public.rooms'::regclass,'public.grade_levels'::regclass,'public.sections'::regclass,'public.subjects'::regclass)),'all academic tables force RLS');
select is((select count(*)::int from public.permissions where code in ('staff_profiles.view','staff_profiles.manage','academic_structure.view','academic_structure.manage')),4,'permission catalog seeded');
select ok(not has_table_privilege('authenticated','public.sections','INSERT'),'direct section inserts denied');
select ok(not has_table_privilege('authenticated','public.rooms','UPDATE'),'direct room updates denied');
select ok(not has_table_privilege('authenticated','public.academic_years','UPDATE'),'legacy academic-year writes revoked');
select ok(not has_table_privilege('authenticated','public.academic_terms','INSERT'),'legacy academic-term writes revoked');
select ok(has_function_privilege('authenticated','public.create_section(uuid,uuid,uuid,uuid,uuid,text,text,integer,date,date,record_status)','EXECUTE'),'public section command granted');
select ok(not has_function_privilege('authenticated','app_auth.academic_foundation_command(text,uuid,jsonb)','EXECUTE'),'private dispatcher not granted');
select ok(not has_function_privilege('anon','public.create_subject(uuid,text,text,text,record_status)','EXECUTE'),'anonymous RPC denied');
select ok(position('from public.organizations org where org.id=o and org.status=''active'' for update' in pg_get_functiondef('app_auth.academic_foundation_command(text,uuid,jsonb)'::regprocedure))>0,'child create dispatcher locks authoritative organization before descendants');
select ok(position('x.capacity>=(args->>''capacity'')::int for update' in pg_get_functiondef('app_auth.academic_foundation_command(text,uuid,jsonb)'::regprocedure))>0,'section create locks homeroom room during capacity validation');
select ok(position('from public.rooms where building_id=target order by id for update' in pg_get_functiondef('app_auth.mutate_academic(text,uuid,jsonb,boolean)'::regprocedure))>0,'building archive locks child rooms deterministically before checking activity');
select ok(position('from public.sections where homeroom_room_id=target order by id for update' in pg_get_functiondef('app_auth.mutate_academic(text,uuid,jsonb,boolean)'::regprocedure))>0,'room capacity and archive paths lock linked sections deterministically');
select ok(position('from public.sections where grade_level_id=target order by id for update' in pg_get_functiondef('app_auth.mutate_academic(text,uuid,jsonb,boolean)'::regprocedure))>0,'grade archive locks linked sections deterministically');
select ok((select i.indisunique and pg_get_indexdef(i.indexrelid) like '%(school_id, lower(btrim(code)))%' from pg_index i where i.indexrelid='public.grade_levels_school_code_normalized_idx'::regclass),'grade normalized-code index has school scope and lower/btrim expression');
select ok((select i.indisunique and pg_get_indexdef(i.indexrelid) like '%(school_id, lower(btrim(name)))%' from pg_index i where i.indexrelid='public.grade_levels_school_name_normalized_idx'::regclass),'grade normalized-name index has school scope and lower/btrim expression');
select ok((select i.indisunique and pg_get_indexdef(i.indexrelid) like '%(school_id, lower(btrim(code)))%' from pg_index i where i.indexrelid='public.subjects_school_code_normalized_idx'::regclass),'subject normalized-code index has school scope and lower/btrim expression');
select ok((select i.indisunique and pg_get_indexdef(i.indexrelid) like '%(school_id, lower(btrim(name)))%' from pg_index i where i.indexrelid='public.subjects_school_name_normalized_idx'::regclass),'subject normalized-name index has school scope and lower/btrim expression');
select ok((select i.indisunique and pg_get_indexdef(i.indexrelid) like '%(academic_year_id, campus_id, lower(btrim(code)))%' from pg_index i where i.indexrelid='public.sections_year_campus_code_normalized_idx'::regclass),'section normalized-code index has year/campus scope and lower/btrim expression');
select ok((select i.indisunique and pg_get_indexdef(i.indexrelid) like '%(academic_year_id, campus_id, lower(btrim(name)))%' from pg_index i where i.indexrelid='public.sections_year_campus_name_normalized_idx'::regclass),'section normalized-name index has year/campus scope and lower/btrim expression');
select ok(
 c.relrowsecurity and c.relforcerowsecurity
 and has_table_privilege('authenticated',c.oid,'SELECT')
 and not has_table_privilege('authenticated',c.oid,'INSERT,UPDATE,DELETE,TRUNCATE')
 and (select count(*)=1 and bool_and(p.polcmd='r') from pg_policy p where p.polrelid=c.oid),
 'SELECT-only authenticated grant, FORCE RLS, and SELECT-only policy: '||t.table_name
) from (values ('staff_profiles'),('buildings'),('rooms'),('grade_levels'),('sections'),('subjects')) t(table_name)
join pg_class c on c.oid=to_regclass('public.'||t.table_name)
order by t.table_name;
create temporary table expected_rls_path_indexes(index_name text primary key,index_fragment text not null) on commit drop;
insert into expected_rls_path_indexes values
 ('memberships_user_org_status_idx','(user_id, organization_id, status)'),
 ('role_assignments_membership_active_idx','(organization_membership_id, status, starts_at, ends_at)'),
 ('role_assignments_scope_idx','(organization_id, school_id, campus_id)'),
 ('roles_org_status_idx','(organization_id, status)'),
 ('permissions_code_key','(code)');
select ok(
 to_regclass('public.'||x.index_name) is not null
 and position(x.index_fragment in pg_get_indexdef(to_regclass('public.'||x.index_name)))>0,
 'RLS helper traversal has supporting index: '||x.index_name
) from expected_rls_path_indexes x order by x.index_name;
create temporary table expected_academic_functions(signature text primary key,exposure text not null) on commit drop;
insert into expected_academic_functions values
 ('app_auth.can_read_catalog(uuid,uuid,text)','rls'),('app_auth.can_manage_catalog(uuid,uuid)','private'),
 ('app_auth.write_academic_change(uuid,uuid,text,text,uuid,jsonb,jsonb)','private'),('app_auth.academic_foundation_command(text,uuid,jsonb)','private'),
 ('app_auth.assert_active_academic_parents(text,uuid)','private'),('app_auth.mutate_academic(text,uuid,jsonb,boolean)','private'),
 ('public.create_building(uuid,text,text,date,record_status)','wrapper'),('public.update_building(uuid,text,text,record_status,date,boolean,date,boolean)','wrapper'),('public.archive_building(uuid)','wrapper'),
 ('public.create_room(uuid,text,text,text,integer,record_status)','wrapper'),('public.update_room(uuid,text,text,text,integer,record_status,text,boolean)','wrapper'),('public.archive_room(uuid)','wrapper'),
 ('public.create_grade_level(uuid,text,text,smallint,smallint,smallint,record_status)','wrapper'),('public.update_grade_level(uuid,text,text,smallint,record_status,smallint,boolean,smallint,boolean)','wrapper'),('public.archive_grade_level(uuid)','wrapper'),
 ('public.create_subject(uuid,text,text,text,record_status)','wrapper'),('public.update_subject(uuid,text,text,text,record_status,boolean)','wrapper'),('public.archive_subject(uuid)','wrapper'),
 ('public.create_section(uuid,uuid,uuid,uuid,uuid,text,text,integer,date,date,record_status)','wrapper'),('public.update_section(uuid,text,text,integer,date,date,uuid,uuid,record_status,boolean,boolean)','wrapper'),('public.archive_section(uuid)','wrapper'),
 ('public.create_staff_profile(uuid,uuid,uuid,text,text,text,text,date,record_status)','wrapper'),('public.update_staff_profile(uuid,text,text,record_status,uuid,boolean,uuid,boolean,text,boolean,text,boolean,date,boolean,date,boolean)','wrapper'),('public.archive_staff_profile(uuid)','wrapper'),
 ('public.create_academic_year(uuid,text,date,date,academic_period_status)','wrapper'),('public.update_academic_year(uuid,text,date,date)','wrapper'),('public.transition_academic_year_status(uuid,academic_period_status)','wrapper'),
 ('public.create_academic_term(uuid,text,smallint,date,date,academic_period_status)','wrapper'),('public.update_academic_term(uuid,text,smallint,date,date)','wrapper'),('public.transition_academic_term_status(uuid,academic_period_status)','wrapper');
select ok(
 p.oid is not null and pg_get_userbyid(p.proowner)='postgres' and p.prosecdef
 and exists(select 1 from unnest(p.proconfig) cfg where cfg like 'search_path=%')
 and has_function_privilege('authenticated',p.oid,'EXECUTE')=(f.exposure in ('wrapper','rls'))
 and has_function_privilege('service_role',p.oid,'EXECUTE')=(f.exposure in ('wrapper','rls'))
 and not has_function_privilege('anon',p.oid,'EXECUTE')
 and not exists(select 1 from aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) acl where acl.grantee=0 and acl.privilege_type='EXECUTE'),
 'function exposure: '||f.signature
) from expected_academic_functions f left join pg_proc p on p.oid=to_regprocedure(f.signature) order by f.signature;
select ok(not exists(
 select 1
 from expected_academic_functions f
 join pg_proc p on p.oid=to_regprocedure(f.signature)
 where f.exposure='wrapper' and (
  coalesce(p.proargnames,'{}'::text[]) && array['organization_id','created_by','updated_by','actor_user_id','audit_data','event_payload','payload']
  or pg_get_function_identity_arguments(p.oid) ~ '(^|, )jsonb(,|$)'
 )
),'public mutation wrappers accept no tenant, attribution, audit/event, or arbitrary jsonb inputs');
select ok(not exists(select 1 from (values ('staff_profiles'),('buildings'),('rooms'),('grade_levels'),('subjects'),('sections'),('academic_years'),('academic_terms')) t(table_name) where has_table_privilege('authenticated','public.'||t.table_name,'INSERT,UPDATE,DELETE,TRUNCATE') or has_table_privilege('anon','public.'||t.table_name,'INSERT,UPDATE,DELETE,TRUNCATE')),'ordinary roles have no direct mutation privilege on academic tables');
select ok(has_function_privilege('authenticated','public.archive_student(uuid,text)','EXECUTE') and has_function_privilege('service_role','public.archive_student(uuid,text)','EXECUTE'),'existing SIS public RPC grants are preserved');
select ok(has_function_privilege('authenticated','app_auth.can_view_student(uuid,uuid)','EXECUTE') and has_function_privilege('service_role','app_auth.can_view_student(uuid,uuid)','EXECUTE'),'existing SIS helper grants are preserved');

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,created_at,updated_at) values
 ('71000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','academic-admin@test','',now(),now()),
 ('71000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','campus-reader@test','',now(),now()),
 ('71000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000000','authenticated','authenticated','suspended@test','',now(),now()),
 ('71000000-0000-0000-0000-000000000004','00000000-0000-0000-0000-000000000000','authenticated','authenticated','invited@test','',now(),now()),
 ('71000000-0000-0000-0000-000000000005','00000000-0000-0000-0000-000000000000','authenticated','authenticated','left@test','',now(),now()),
 ('71000000-0000-0000-0000-000000000006','00000000-0000-0000-0000-000000000000','authenticated','authenticated','school-manager@test','',now(),now()),
 ('71000000-0000-0000-0000-000000000007','00000000-0000-0000-0000-000000000000','authenticated','authenticated','campus-manager@test','',now(),now()),
 ('71000000-0000-0000-0000-000000000008','00000000-0000-0000-0000-000000000000','authenticated','authenticated','no-permission@test','',now(),now()),
 ('71000000-0000-0000-0000-000000000009','00000000-0000-0000-0000-000000000000','authenticated','authenticated','target@test','',now(),now());
insert into public.organizations(id,name,slug) values ('72000000-0000-0000-0000-000000000001','Academic Tenant','academic-tenant'),('72000000-0000-0000-0000-000000000002','Other Tenant','other-academic-tenant');
insert into public.schools(id,organization_id,name,code) values ('73000000-0000-0000-0000-000000000001','72000000-0000-0000-0000-000000000001','Academic School','AS'),('73000000-0000-0000-0000-000000000002','72000000-0000-0000-0000-000000000002','Other School','OS'),('73000000-0000-0000-0000-000000000003','72000000-0000-0000-0000-000000000001','Second School','SS');
insert into public.campuses(id,organization_id,school_id,name,code) values
 ('74000000-0000-0000-0000-000000000001','72000000-0000-0000-0000-000000000001','73000000-0000-0000-0000-000000000001','North','N'),
 ('74000000-0000-0000-0000-000000000002','72000000-0000-0000-0000-000000000001','73000000-0000-0000-0000-000000000001','South','S'),
 ('74000000-0000-0000-0000-000000000003','72000000-0000-0000-0000-000000000001','73000000-0000-0000-0000-000000000003','Other School Campus','OSC'),
 ('74000000-0000-0000-0000-000000000004','72000000-0000-0000-0000-000000000002','73000000-0000-0000-0000-000000000002','Other Tenant Campus','OT');
insert into public.organization_memberships(id,organization_id,user_id,status,joined_at) values
 ('75000000-0000-0000-0000-000000000001','72000000-0000-0000-0000-000000000001','71000000-0000-0000-0000-000000000001','active',now()),
 ('75000000-0000-0000-0000-000000000002','72000000-0000-0000-0000-000000000001','71000000-0000-0000-0000-000000000002','active',now()),
 ('75000000-0000-0000-0000-000000000003','72000000-0000-0000-0000-000000000001','71000000-0000-0000-0000-000000000003','suspended',now()),
 ('75000000-0000-0000-0000-000000000004','72000000-0000-0000-0000-000000000002','71000000-0000-0000-0000-000000000002','active',now()),
 ('75000000-0000-0000-0000-000000000005','72000000-0000-0000-0000-000000000001','71000000-0000-0000-0000-000000000004','invited',null),
 ('75000000-0000-0000-0000-000000000006','72000000-0000-0000-0000-000000000001','71000000-0000-0000-0000-000000000005','active',now()),
 ('75000000-0000-0000-0000-000000000007','72000000-0000-0000-0000-000000000001','71000000-0000-0000-0000-000000000006','active',now()),
 ('75000000-0000-0000-0000-000000000008','72000000-0000-0000-0000-000000000001','71000000-0000-0000-0000-000000000007','active',now()),
 ('75000000-0000-0000-0000-000000000009','72000000-0000-0000-0000-000000000001','71000000-0000-0000-0000-000000000008','active',now()),
 ('75000000-0000-0000-0000-000000000010','72000000-0000-0000-0000-000000000001','71000000-0000-0000-0000-000000000009','active',now());
update public.organization_memberships set status='left',left_at=now() where id='75000000-0000-0000-0000-000000000006';
insert into public.roles(id,organization_id,code,name) values
 ('76000000-0000-0000-0000-000000000001','72000000-0000-0000-0000-000000000001','ACADEMIC_ADMIN','Academic Admin'),
 ('76000000-0000-0000-0000-000000000002','72000000-0000-0000-0000-000000000001','CAMPUS_READER','Campus Reader'),
 ('76000000-0000-0000-0000-000000000003','72000000-0000-0000-0000-000000000001','SCHOOL_STAFF','School Staff Manager'),
 ('76000000-0000-0000-0000-000000000004','72000000-0000-0000-0000-000000000001','CAMPUS_STAFF','Campus Staff Manager'),
 ('76000000-0000-0000-0000-000000000005','72000000-0000-0000-0000-000000000001','NO_STAFF','No Staff Permission');
insert into public.role_permissions(organization_id,role_id,permission_id) select '72000000-0000-0000-0000-000000000001','76000000-0000-0000-0000-000000000001',id from public.permissions where code in ('academic_structure.view','academic_structure.manage','staff_profiles.view','staff_profiles.manage','academic_periods.view','academic_periods.manage');
insert into public.role_permissions(organization_id,role_id,permission_id) select '72000000-0000-0000-0000-000000000001','76000000-0000-0000-0000-000000000002',id from public.permissions where code in ('academic_structure.view','academic_structure.manage');
insert into public.role_permissions(organization_id,role_id,permission_id) select '72000000-0000-0000-0000-000000000001',r,id from public.permissions cross join (values('76000000-0000-0000-0000-000000000003'::uuid),('76000000-0000-0000-0000-000000000004'::uuid)) v(r) where code='staff_profiles.manage';
insert into public.role_permissions(organization_id,role_id,permission_id) select '72000000-0000-0000-0000-000000000001','76000000-0000-0000-0000-000000000003',id from public.permissions where code='academic_structure.manage';
insert into public.role_permissions(organization_id,role_id,permission_id) select '72000000-0000-0000-0000-000000000001','76000000-0000-0000-0000-000000000003',id from public.permissions where code='academic_periods.manage';
insert into public.role_assignments(organization_id,organization_membership_id,role_id,school_id,campus_id) values
 ('72000000-0000-0000-0000-000000000001','75000000-0000-0000-0000-000000000001','76000000-0000-0000-0000-000000000001',null,null),
 ('72000000-0000-0000-0000-000000000001','75000000-0000-0000-0000-000000000002','76000000-0000-0000-0000-000000000002','73000000-0000-0000-0000-000000000001','74000000-0000-0000-0000-000000000001'),
 ('72000000-0000-0000-0000-000000000001','75000000-0000-0000-0000-000000000003','76000000-0000-0000-0000-000000000001',null,null),
 ('72000000-0000-0000-0000-000000000001','75000000-0000-0000-0000-000000000007','76000000-0000-0000-0000-000000000003','73000000-0000-0000-0000-000000000001',null),
 ('72000000-0000-0000-0000-000000000001','75000000-0000-0000-0000-000000000008','76000000-0000-0000-0000-000000000004','73000000-0000-0000-0000-000000000001','74000000-0000-0000-0000-000000000001'),
 ('72000000-0000-0000-0000-000000000001','75000000-0000-0000-0000-000000000009','76000000-0000-0000-0000-000000000005',null,null);

set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
reset role;
insert into public.academic_years(id,organization_id,school_id,name,start_date,end_date,status) values
 ('77000000-0000-0000-0000-000000000001','72000000-0000-0000-0000-000000000001','73000000-0000-0000-0000-000000000001','Auth 2026','2026-01-01','2026-12-31','active'),
 ('77000000-0000-0000-0000-000000000003','72000000-0000-0000-0000-000000000002','73000000-0000-0000-0000-000000000002','Other 2026','2026-01-01','2026-12-31','active'),
 ('77000000-0000-0000-0000-000000000004','72000000-0000-0000-0000-000000000001','73000000-0000-0000-0000-000000000003','Second School 2026','2026-01-01','2026-12-31','active');
insert into public.grade_levels(id,organization_id,school_id,code,name,sequence) values
 ('78000000-0000-0000-0000-000000000001','72000000-0000-0000-0000-000000000001','73000000-0000-0000-0000-000000000001','AUTH-G1','Auth Grade 1',1),
 ('78000000-0000-0000-0000-000000000002','72000000-0000-0000-0000-000000000001','73000000-0000-0000-0000-000000000003','AUTH-G1','Auth Grade 1',1),
 ('78000000-0000-0000-0000-000000000003','72000000-0000-0000-0000-000000000002','73000000-0000-0000-0000-000000000002','AUTH-G1','Auth Grade 1',1);
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000008","role":"authenticated"}',true);
select throws_ok($$select public.create_section('74000000-0000-0000-0000-000000000001','77000000-0000-0000-0000-000000000001',null,'78000000-0000-0000-0000-000000000001',null,'AUTH-NOPERM','Denied',10,'2026-01-01','2026-12-31','inactive')$$,'42501','academic_structure.manage permission is required','active actor missing academic permission denied');
select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000002","role":"authenticated"}',true);
select throws_ok($$select public.create_section('74000000-0000-0000-0000-000000000004','77000000-0000-0000-0000-000000000003',null,'78000000-0000-0000-0000-000000000003',null,'AUTH-XTEN','Denied',10,'2026-01-01','2026-12-31','inactive')$$,'42501','academic_structure.manage permission is required','cross-tenant actor denied');
select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000003","role":"authenticated"}',true);
select throws_ok($$select public.create_section('74000000-0000-0000-0000-000000000001','77000000-0000-0000-0000-000000000001',null,'78000000-0000-0000-0000-000000000001',null,'AUTH-SUSP','Denied',10,'2026-01-01','2026-12-31','inactive')$$,'42501','academic_structure.manage permission is required','suspended membership denied');
select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000006","role":"authenticated"}',true);
select lives_ok($$select public.create_section('74000000-0000-0000-0000-000000000001','77000000-0000-0000-0000-000000000001',null,'78000000-0000-0000-0000-000000000001',null,'AUTH-SCHOOL-OK','School Allowed',10,'2026-01-01','2026-12-31','inactive')$$,'school-scoped manager allowed in assigned school');
select throws_ok($$select public.create_section('74000000-0000-0000-0000-000000000003','77000000-0000-0000-0000-000000000004',null,'78000000-0000-0000-0000-000000000002',null,'AUTH-SCHOOL-X','Denied',10,'2026-01-01','2026-12-31','inactive')$$,'42501','academic_structure.manage permission is required','school manager denied another school');
select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select lives_ok($$select public.create_section('74000000-0000-0000-0000-000000000003','77000000-0000-0000-0000-000000000004',null,'78000000-0000-0000-0000-000000000002',null,'AUTH-ORG-OK','Org Allowed',10,'2026-01-01','2026-12-31','inactive')$$,'organization manager allowed in another school in organization');
select throws_ok($$select public.create_section('74000000-0000-0000-0000-000000000004','77000000-0000-0000-0000-000000000003',null,'78000000-0000-0000-0000-000000000003',null,'AUTH-ORG-X','Denied',10,'2026-01-01','2026-12-31','inactive')$$,'42501','academic_structure.manage permission is required','organization manager denied another organization');
reset role;
select is((select count(*)::int from public.sections where code like 'AUTH-%' and code not in ('AUTH-SCHOOL-OK','AUTH-ORG-OK')),0,'denied authorization commands create no sections');
select is((select count(*)::int from public.audit_log where after_data->>'code' like 'AUTH-%' and after_data->>'code' not in ('AUTH-SCHOOL-OK','AUTH-ORG-OK')),0,'denied authorization commands create no audit rows');
select is((select count(*)::int from public.audit_log where actor_user_id in ('71000000-0000-0000-0000-000000000008','71000000-0000-0000-0000-000000000002','71000000-0000-0000-0000-000000000003') and action='section.created'),0,'denied actors have no section audit attribution');
select is((select count(*)::int from public.event_outbox where payload->>'actor_user_id' in ('71000000-0000-0000-0000-000000000008','71000000-0000-0000-0000-000000000002','71000000-0000-0000-0000-000000000003') and event_type='section.created'),0,'denied actors have no section outbox events');
set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.create_staff_profile('75000000-0000-0000-0000-000000000099',null,null,'MISS','employee')$$,'P0002','active staff organization and membership are required','staff create rejects missing membership');
select throws_ok($$select public.create_staff_profile('75000000-0000-0000-0000-000000000003',null,null,'SUSP','employee')$$,'P0002','active staff organization and membership are required','staff create rejects suspended membership');
select throws_ok($$select public.create_staff_profile('75000000-0000-0000-0000-000000000005',null,null,'INV','employee')$$,'P0002','active staff organization and membership are required','staff create rejects invited membership');
select throws_ok($$select public.create_staff_profile('75000000-0000-0000-0000-000000000006',null,null,'LEFT','employee')$$,'P0002','active staff organization and membership are required','staff create rejects left membership and left_at');
reset role; update public.schools set status='inactive' where id='73000000-0000-0000-0000-000000000001'; set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.create_staff_profile('75000000-0000-0000-0000-000000000010','73000000-0000-0000-0000-000000000001',null,'ISCH','employee')$$,'P0002','active home school in membership organization is required','staff create rejects inactive home school');
reset role; update public.schools set status='active' where id='73000000-0000-0000-0000-000000000001'; update public.campuses set status='inactive' where id='74000000-0000-0000-0000-000000000001'; set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.create_staff_profile('75000000-0000-0000-0000-000000000010','73000000-0000-0000-0000-000000000001','74000000-0000-0000-0000-000000000001','ICAM','employee')$$,'P0002','active home campus in home school is required','staff create rejects inactive home campus');
reset role; update public.campuses set status='active' where id='74000000-0000-0000-0000-000000000001'; set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.create_staff_profile('75000000-0000-0000-0000-000000000010','73000000-0000-0000-0000-000000000001','74000000-0000-0000-0000-000000000003','XSCH','employee')$$,'P0002','active home campus in home school is required','staff create rejects campus from another school');
select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000008","role":"authenticated"}',true);
select throws_ok($$select public.create_staff_profile('75000000-0000-0000-0000-000000000010',null,null,'NOPERM','employee')$$,'42501','staff_profiles.manage permission is required','active actor missing staff permission is denied');
select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000006","role":"authenticated"}',true);
select throws_ok($$select public.create_staff_profile('75000000-0000-0000-0000-000000000010','73000000-0000-0000-0000-000000000003','74000000-0000-0000-0000-000000000003','OTHER','employee')$$,'42501','staff_profiles.manage permission is required','school manager denied other school and campus');
reset role; update public.organization_memberships set status='active',left_at=null where id in ('75000000-0000-0000-0000-000000000005','75000000-0000-0000-0000-000000000006'); set local role authenticated;
select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000006","role":"authenticated"}',true); select lives_ok($$select public.create_staff_profile('75000000-0000-0000-0000-000000000005','73000000-0000-0000-0000-000000000001',null,'SCHOOL-OK','employee')$$,'school-scoped manager creates school-home staff');
select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000007","role":"authenticated"}',true); select lives_ok($$select public.create_staff_profile('75000000-0000-0000-0000-000000000006','73000000-0000-0000-0000-000000000001','74000000-0000-0000-0000-000000000001','CAMPUS-OK','employee')$$,'campus-scoped manager creates campus-home staff');
select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
reset role; update public.organizations set status='inactive' where id='72000000-0000-0000-0000-000000000001'; set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.create_staff_profile('75000000-0000-0000-0000-000000000002',null,null,'IORG','employee')$$,'P0002','active staff organization and membership are required','staff create rejects inactive organization');
reset role; update public.organizations set status='active' where id='72000000-0000-0000-0000-000000000001'; set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.create_staff_profile('75000000-0000-0000-0000-000000000002','73000000-0000-0000-0000-000000000099',null,'MSCH','employee')$$,'P0002','active home school in membership organization is required','staff create rejects missing home school');
select throws_ok($$select public.create_staff_profile('75000000-0000-0000-0000-000000000002','73000000-0000-0000-0000-000000000001','74000000-0000-0000-0000-000000000099','MCAM','employee')$$,'P0002','active home campus in home school is required','staff create rejects missing home campus');
select throws_ok($$select public.create_staff_profile('75000000-0000-0000-0000-000000000004',null,null,'XTEN','employee')$$,'42501','staff_profiles.manage permission is required','cross-tenant actor cannot create staff profile');
select lives_ok($$select public.create_staff_profile('75000000-0000-0000-0000-000000000002',null,null,'ORG-STAFF','employee')$$,'organization-scoped manager creates staff profile with tenant derived from membership');
select ok((select organization_id='72000000-0000-0000-0000-000000000001' and created_by='71000000-0000-0000-0000-000000000001' from public.staff_profiles where staff_number='ORG-STAFF'),'staff create derives tenant and owns attribution');
select throws_ok($$select public.create_grade_level('73000000-0000-0000-0000-000000000099','MISS','Missing Grade',99::smallint)$$,'P0002','active catalog organization and school are required','grade create rejects missing school deliberately');
select throws_ok($$select public.create_subject('73000000-0000-0000-0000-000000000099','MISS','Missing Subject')$$,'P0002','active catalog organization and school are required','subject create rejects missing school deliberately');
reset role; update public.schools set status='inactive' where id='73000000-0000-0000-0000-000000000001'; set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.create_grade_level('73000000-0000-0000-0000-000000000001','BLOCK-G','Blocked Grade',98::smallint)$$,'P0002','active catalog organization and school are required','grade create rejects inactive school');
select throws_ok($$select public.create_subject('73000000-0000-0000-0000-000000000001','BLOCK-S','Blocked Subject')$$,'P0002','active catalog organization and school are required','subject create rejects inactive school');
reset role; update public.schools set status='active' where id='73000000-0000-0000-0000-000000000001'; update public.organizations set status='inactive' where id='72000000-0000-0000-0000-000000000001'; set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.create_grade_level('73000000-0000-0000-0000-000000000001','BLOCK-OG','Blocked Org Grade',97::smallint)$$,'P0002','active catalog organization and school are required','grade create rejects inactive organization');
select throws_ok($$select public.create_subject('73000000-0000-0000-0000-000000000001','BLOCK-OS','Blocked Org Subject')$$,'P0002','active catalog organization and school are required','subject create rejects inactive organization');
reset role; update public.organizations set status='active' where id='72000000-0000-0000-0000-000000000001'; set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.create_academic_year('73000000-0000-0000-0000-000000000099','AUTH-MISSING','2030-01-01','2030-12-31','draft')$$,'P0002','active academic-year organization and school are required','year create rejects missing school deliberately');
reset role; update public.schools set status='inactive' where id='73000000-0000-0000-0000-000000000001'; set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.create_academic_year('73000000-0000-0000-0000-000000000001','AUTH-ISCH','2030-01-01','2030-12-31','draft')$$,'P0002','active academic-year organization and school are required','year create rejects inactive school');
reset role; update public.schools set status='active' where id='73000000-0000-0000-0000-000000000001'; update public.organizations set status='inactive' where id='72000000-0000-0000-0000-000000000001'; set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.create_academic_year('73000000-0000-0000-0000-000000000001','AUTH-IORG','2030-01-01','2030-12-31','draft')$$,'P0002','active academic-year organization and school are required','year create rejects inactive organization');
reset role; update public.organizations set status='active' where id='72000000-0000-0000-0000-000000000001'; set local role authenticated;
select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000008","role":"authenticated"}',true); select throws_ok($$select public.create_academic_year('73000000-0000-0000-0000-000000000001','AUTH-NOPERM-Y','2030-01-01','2030-12-31','draft')$$,'42501','academic_periods.manage permission is required','year create rejects missing permission');
select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000003","role":"authenticated"}',true); select throws_ok($$select public.create_academic_year('73000000-0000-0000-0000-000000000001','AUTH-SUSP-Y','2030-01-01','2030-12-31','draft')$$,'42501','academic_periods.manage permission is required','year create rejects suspended membership');
select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000002","role":"authenticated"}',true); select throws_ok($$select public.create_academic_year('73000000-0000-0000-0000-000000000002','AUTH-XTEN-Y','2030-01-01','2030-12-31','draft')$$,'42501','academic_periods.manage permission is required','cross-tenant actor cannot create year');
select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000006","role":"authenticated"}',true); select lives_ok($$select public.create_academic_year('73000000-0000-0000-0000-000000000001','AUTH-SCHOOL-Y','2031-01-01','2031-12-31','draft')$$,'school manager creates academic year');
reset role;
select is((select count(*)::int from public.academic_years where name like 'AUTH-%' and name<>'AUTH-SCHOOL-Y'),0,'denied year creates leave no periods');
select is((select count(*)::int from public.audit_log where after_data->>'name' like 'AUTH-%' and after_data->>'name'<>'AUTH-SCHOOL-Y'),0,'denied year creates leave no audit rows');
select is((select count(*)::int from public.event_outbox where event_type='academic_year.created' and payload->>'actor_user_id' in ('71000000-0000-0000-0000-000000000008','71000000-0000-0000-0000-000000000003','71000000-0000-0000-0000-000000000002')),0,'denied year creates leave no outbox events');
select ok((select organization_id='72000000-0000-0000-0000-000000000001' and created_by='71000000-0000-0000-0000-000000000006' from public.academic_years where name='AUTH-SCHOOL-Y'),'school-manager year derives organization and actor attribution');
set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select lives_ok($$select public.create_academic_year('73000000-0000-0000-0000-000000000001','2025','2025-01-01','2025-12-31','active')$$,'organization manager creates audited year');
reset role; update public.academic_years set id='77000000-0000-0000-0000-000000000005' where name='2025';
set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select lives_ok($$select public.create_grade_level('73000000-0000-0000-0000-000000000001','G0','Grade 0',10::smallint)$$,'create grade');
select lives_ok($$select public.create_subject('73000000-0000-0000-0000-000000000001','MATH','Mathematics')$$,'create subject');
select throws_ok($$select public.create_building('74000000-0000-0000-0000-000000000099','MISS','Missing Campus')$$,'P0002','active building organization, school, and campus are required','building create rejects missing campus deliberately');
select lives_ok($$select public.create_building('74000000-0000-0000-0000-000000000001','A','Building A')$$,'create building');
reset role; update public.grade_levels set id='78000000-0000-0000-0000-000000000005' where code='G0'; update public.buildings set id='79000000-0000-0000-0000-000000000001';
update public.campuses set status='inactive' where id='74000000-0000-0000-0000-000000000001';
set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.create_building('74000000-0000-0000-0000-000000000001','BLOCK','Inactive Campus')$$,'P0002','active building organization, school, and campus are required','building create rejects inactive authoritative campus');
reset role; update public.campuses set status='active' where id='74000000-0000-0000-0000-000000000001'; set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.create_room('79000000-0000-0000-0000-000000000099','MISS','Missing Building','classroom',10)$$,'P0002','active room organization, school, campus, and building are required','room create rejects missing building deliberately');
select lives_ok($$select public.create_room('79000000-0000-0000-0000-000000000001','101','Room 101','classroom',25)$$,'create room');
reset role; update public.rooms set id='7a000000-0000-0000-0000-000000000001';
update public.buildings set status='inactive' where id='79000000-0000-0000-0000-000000000001';
set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.create_room('79000000-0000-0000-0000-000000000001','BLOCK','Inactive Building','classroom',10)$$,'P0002','active room organization, school, campus, and building are required','room create rejects inactive authoritative building');
reset role; update public.buildings set status='active' where id='79000000-0000-0000-0000-000000000001'; set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
reset role;
insert into public.academic_years(id,organization_id,school_id,name,start_date,end_date,status) values('77000000-0000-0000-0000-000000000002','72000000-0000-0000-0000-000000000001','73000000-0000-0000-0000-000000000001','2027','2027-01-01','2027-12-31','draft');
insert into public.academic_terms(id,organization_id,academic_year_id,name,sequence,start_date,end_date,status) values
 ('77100000-0000-0000-0000-000000000001','72000000-0000-0000-0000-000000000001','77000000-0000-0000-0000-000000000001','Closed Term',1,'2026-01-01','2026-06-30','closed'),
 ('77100000-0000-0000-0000-000000000002','72000000-0000-0000-0000-000000000001','77000000-0000-0000-0000-000000000001','Archived Term',2,'2026-07-01','2026-12-31','archived'),
 ('77100000-0000-0000-0000-000000000003','72000000-0000-0000-0000-000000000001','77000000-0000-0000-0000-000000000001','Narrow Term',3,'2026-02-01','2026-03-31','active');
insert into public.academic_terms(id,organization_id,academic_year_id,name,sequence,start_date,end_date,status) values ('77100000-0000-0000-0000-000000000004','72000000-0000-0000-0000-000000000001','77000000-0000-0000-0000-000000000002','Other Year Term',1,'2027-01-01','2027-12-31','draft');
insert into public.buildings(id,organization_id,school_id,campus_id,code,name) values ('79100000-0000-0000-0000-000000000001','72000000-0000-0000-0000-000000000001','73000000-0000-0000-0000-000000000001','74000000-0000-0000-0000-000000000002','SOUTH','South Building');
insert into public.rooms(id,organization_id,school_id,campus_id,building_id,code,name,room_type,capacity) values ('7a100000-0000-0000-0000-000000000001','72000000-0000-0000-0000-000000000001','73000000-0000-0000-0000-000000000001','74000000-0000-0000-0000-000000000002','79100000-0000-0000-0000-000000000001','201','South Room','classroom',30);
insert into public.campuses(id,organization_id,school_id,name,code) values ('74000000-0000-0000-0000-000000000004','72000000-0000-0000-0000-000000000002','73000000-0000-0000-0000-000000000002','Other Tenant Campus','OT') on conflict do nothing;
insert into public.academic_years(id,organization_id,school_id,name,start_date,end_date,status) values('77000000-0000-0000-0000-000000000003','72000000-0000-0000-0000-000000000002','73000000-0000-0000-0000-000000000002','Other 2026','2026-01-01','2026-12-31','active') on conflict do nothing;
insert into public.academic_years(id,organization_id,school_id,name,start_date,end_date,status) values('77000000-0000-0000-0000-000000000004','72000000-0000-0000-0000-000000000001','73000000-0000-0000-0000-000000000003','Second School 2026','2026-01-01','2026-12-31','active') on conflict do nothing;
insert into public.grade_levels(id,organization_id,school_id,code,name,sequence) values
 ('78000000-0000-0000-0000-000000000002','72000000-0000-0000-0000-000000000001','73000000-0000-0000-0000-000000000003','G1','Grade 1',1),
 ('78000000-0000-0000-0000-000000000003','72000000-0000-0000-0000-000000000002','73000000-0000-0000-0000-000000000002','G1','Grade 1',1) on conflict do nothing;
insert into public.academic_terms(id,organization_id,academic_year_id,name,sequence,start_date,end_date,status) values('77100000-0000-0000-0000-000000000005','72000000-0000-0000-0000-000000000002','77000000-0000-0000-0000-000000000003','Other Term',1,'2026-01-01','2026-12-31','active');
insert into public.buildings(id,organization_id,school_id,campus_id,code,name) values ('79100000-0000-0000-0000-000000000002','72000000-0000-0000-0000-000000000002','73000000-0000-0000-0000-000000000002','74000000-0000-0000-0000-000000000004','OT','Other Building');
insert into public.rooms(id,organization_id,school_id,campus_id,building_id,code,name,room_type,capacity) values ('7a100000-0000-0000-0000-000000000002','72000000-0000-0000-0000-000000000002','73000000-0000-0000-0000-000000000002','74000000-0000-0000-0000-000000000004','79100000-0000-0000-0000-000000000002','OT1','Other Room','classroom',30);
set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.create_section('74000000-0000-0000-0000-000000000001','77000000-0000-0000-0000-000000000099',null,'78000000-0000-0000-0000-000000000001',null,'MY','Missing Year',10,'2026-01-01','2026-12-31','inactive')$$,'P0002','active section organization, school, and academic year are required','section create rejects missing year');
select throws_ok($$select public.create_section('74000000-0000-0000-0000-000000000099','77000000-0000-0000-0000-000000000001',null,'78000000-0000-0000-0000-000000000001',null,'MC','Missing Campus',10,'2026-01-01','2026-12-31','inactive')$$,'P0002','active section campus in academic-year school is required','section create rejects missing campus');
select throws_ok($$select public.create_section('74000000-0000-0000-0000-000000000003','77000000-0000-0000-0000-000000000001',null,'78000000-0000-0000-0000-000000000001',null,'XC','Cross School Campus',10,'2026-01-01','2026-12-31','inactive')$$,'P0002','active section campus in academic-year school is required','section create rejects cross-school campus');
select throws_ok($$select public.create_section('74000000-0000-0000-0000-000000000001','77000000-0000-0000-0000-000000000001',null,'78000000-0000-0000-0000-000000000099',null,'MG','Missing Grade',10,'2026-01-01','2026-12-31','inactive')$$,'P0002','active section grade level in academic-year school is required','section create rejects missing grade');
reset role; update public.organizations set status='inactive' where id='72000000-0000-0000-0000-000000000001'; set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.create_section('74000000-0000-0000-0000-000000000001','77000000-0000-0000-0000-000000000001',null,'78000000-0000-0000-0000-000000000001',null,'IORG-S','Inactive Org',10,'2026-01-01','2026-12-31','inactive')$$,'P0002','active section organization, school, and academic year are required','section create rejects inactive organization');
reset role; update public.organizations set status='active' where id='72000000-0000-0000-0000-000000000001'; update public.schools set status='inactive' where id='73000000-0000-0000-0000-000000000001'; set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.create_section('74000000-0000-0000-0000-000000000001','77000000-0000-0000-0000-000000000001',null,'78000000-0000-0000-0000-000000000001',null,'ISCH-S','Inactive School',10,'2026-01-01','2026-12-31','inactive')$$,'P0002','active section organization, school, and academic year are required','section create rejects inactive school');
reset role; update public.schools set status='active' where id='73000000-0000-0000-0000-000000000001'; update public.campuses set status='inactive' where id='74000000-0000-0000-0000-000000000001'; set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.create_section('74000000-0000-0000-0000-000000000001','77000000-0000-0000-0000-000000000001',null,'78000000-0000-0000-0000-000000000001',null,'ICAM-S','Inactive Campus',10,'2026-01-01','2026-12-31','inactive')$$,'P0002','active section campus in academic-year school is required','section create rejects inactive campus');
reset role; update public.campuses set status='active' where id='74000000-0000-0000-0000-000000000001'; update public.grade_levels set status='inactive' where id='78000000-0000-0000-0000-000000000001'; set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.create_section('74000000-0000-0000-0000-000000000001','77000000-0000-0000-0000-000000000001',null,'78000000-0000-0000-0000-000000000001',null,'IGRD-S','Inactive Grade',10,'2026-01-01','2026-12-31','inactive')$$,'P0002','active section grade level in academic-year school is required','section create rejects inactive grade');
reset role; update public.grade_levels set status='active' where id='78000000-0000-0000-0000-000000000001'; update public.academic_years set status='closed' where id='77000000-0000-0000-0000-000000000001'; set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.create_section('74000000-0000-0000-0000-000000000001','77000000-0000-0000-0000-000000000001',null,'78000000-0000-0000-0000-000000000001',null,'CYR','Closed Year',10,'2026-01-01','2026-12-31','inactive')$$,'22023','academic year status does not permit section use','section create rejects closed year');
reset role; update public.academic_years set status='archived' where id='77000000-0000-0000-0000-000000000001'; set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.create_section('74000000-0000-0000-0000-000000000001','77000000-0000-0000-0000-000000000001',null,'78000000-0000-0000-0000-000000000001',null,'AYR','Archived Year',10,'2026-01-01','2026-12-31','inactive')$$,'22023','academic year status does not permit section use','section create rejects archived year');
reset role; update public.academic_years set status='active' where id='77000000-0000-0000-0000-000000000001'; set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.create_section('74000000-0000-0000-0000-000000000001','77000000-0000-0000-0000-000000000001','77100000-0000-0000-0000-000000000099','78000000-0000-0000-0000-000000000001',null,'MT','Missing Term',10,'2026-01-01','2026-12-31','inactive')$$,'22023','academic term scope, status, or dates do not permit section use','section create rejects missing term');
select throws_ok($$select public.create_section('74000000-0000-0000-0000-000000000001','77000000-0000-0000-0000-000000000001','77100000-0000-0000-0000-000000000001','78000000-0000-0000-0000-000000000001',null,'CT','Closed Term',10,'2026-01-01','2026-06-30','inactive')$$,'22023','academic term scope, status, or dates do not permit section use','section create rejects closed term');
select throws_ok($$select public.create_section('74000000-0000-0000-0000-000000000001','77000000-0000-0000-0000-000000000001','77100000-0000-0000-0000-000000000002','78000000-0000-0000-0000-000000000001',null,'AT','Archived Term',10,'2026-07-01','2026-12-31','inactive')$$,'22023','academic term scope, status, or dates do not permit section use','section create rejects archived term');
select throws_ok($$select public.create_section('74000000-0000-0000-0000-000000000001','77000000-0000-0000-0000-000000000001','77100000-0000-0000-0000-000000000004','78000000-0000-0000-0000-000000000001',null,'XYT','Cross Year Term',10,'2026-01-01','2026-12-31','inactive')$$,'22023','academic term scope, status, or dates do not permit section use','section create rejects cross-year term');
select throws_ok($$select public.create_section('74000000-0000-0000-0000-000000000001','77000000-0000-0000-0000-000000000001','77100000-0000-0000-0000-000000000005','78000000-0000-0000-0000-000000000001',null,'XTT','Cross Tenant Term',10,'2026-01-01','2026-12-31','inactive')$$,'22023','academic term scope, status, or dates do not permit section use','section create rejects cross-tenant term');
select throws_ok($$select public.create_section('74000000-0000-0000-0000-000000000001','77000000-0000-0000-0000-000000000001','77100000-0000-0000-0000-000000000003','78000000-0000-0000-0000-000000000001',null,'TDATE','Term Date Escape',10,'2026-01-01','2026-04-01','inactive')$$,'22023','academic term scope, status, or dates do not permit section use','section create rejects dates outside term');
select throws_ok($$select public.create_section('74000000-0000-0000-0000-000000000001','77000000-0000-0000-0000-000000000001',null,'78000000-0000-0000-0000-000000000001','7a100000-0000-0000-0000-000000000099','MR','Missing Room',10,'2026-01-01','2026-12-31','inactive')$$,'22023','active homeroom in section campus with sufficient capacity is required','section create rejects missing room');
reset role; update public.rooms set status='inactive' where id='7a000000-0000-0000-0000-000000000001'; set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.create_section('74000000-0000-0000-0000-000000000001','77000000-0000-0000-0000-000000000001',null,'78000000-0000-0000-0000-000000000001','7a000000-0000-0000-0000-000000000001','IR','Inactive Room',10,'2026-01-01','2026-12-31','inactive')$$,'22023','active homeroom in section campus with sufficient capacity is required','section create rejects inactive room');
reset role; update public.rooms set status='active' where id='7a000000-0000-0000-0000-000000000001'; set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.create_section('74000000-0000-0000-0000-000000000001','77000000-0000-0000-0000-000000000001',null,'78000000-0000-0000-0000-000000000001','7a100000-0000-0000-0000-000000000001','OCR','Other Campus Room',10,'2026-01-01','2026-12-31','inactive')$$,'22023','active homeroom in section campus with sufficient capacity is required','section create rejects other-campus room');
select throws_ok($$select public.create_section('74000000-0000-0000-0000-000000000001','77000000-0000-0000-0000-000000000001',null,'78000000-0000-0000-0000-000000000001','7a100000-0000-0000-0000-000000000002','XTR','Cross Tenant Room',10,'2026-01-01','2026-12-31','inactive')$$,'22023','active homeroom in section campus with sufficient capacity is required','section create rejects cross-tenant room');
select throws_ok($$select public.create_section('74000000-0000-0000-0000-000000000001','77000000-0000-0000-0000-000000000001',null,'78000000-0000-0000-0000-000000000001',null,'DATE','Bad Dates',10,'2025-12-31','2026-12-31','inactive')$$,'22023','section dates must be within academic year','section create rejects dates outside year');
set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.create_section('74000000-0000-0000-0000-000000000001','77000000-0000-0000-0000-000000000002',null,'78000000-0000-0000-0000-000000000001',null,'DRAFT','Active Draft',10,'2027-01-01','2027-12-31','active')$$,'22023','academic year status does not permit section use','active section rejects draft year');
select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000002","role":"authenticated"}',true);
select lives_ok($$select public.create_section('74000000-0000-0000-0000-000000000001','77000000-0000-0000-0000-000000000001',null,'78000000-0000-0000-0000-000000000001',null,'CAMP-OK','Campus Allowed',10,'2026-01-01','2026-12-31','inactive')$$,'campus-scoped manager creates section at own campus');
select throws_ok($$select public.create_section('74000000-0000-0000-0000-000000000002','77000000-0000-0000-0000-000000000001',null,'78000000-0000-0000-0000-000000000001',null,'CAMP-X','Other Campus',10,'2026-01-01','2026-12-31','inactive')$$,'42501','academic_structure.manage permission is required','campus manager denied other campus');
select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select lives_ok($$select public.create_section('74000000-0000-0000-0000-000000000001','77000000-0000-0000-0000-000000000001',null,'78000000-0000-0000-0000-000000000001','7a000000-0000-0000-0000-000000000001','1A','Grade 1 A',20,'2026-01-01','2026-12-31','active')$$,'create capacity-valid section');
reset role;
create temporary table normalized_create_baseline(event_type text primary key,audit_count bigint,outbox_count bigint) on commit drop;
insert into normalized_create_baseline
select event_type,
 (select count(*) from public.audit_log where action=event_type),
 (select count(*) from public.event_outbox where public.event_outbox.event_type=events.event_type)
from (values ('grade_level.created'),('subject.created'),('section.created')) events(event_type);
set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.create_grade_level('73000000-0000-0000-0000-000000000001',' auth-g1 ','Unique Grade Code',91::smallint)$$,'23505','grade level normalized code already exists','grade create rejects case/whitespace code collision');
reset role; select ok((select audit_count=(select count(*) from public.audit_log where action='grade_level.created') and outbox_count=(select count(*) from public.event_outbox where event_type='grade_level.created') from normalized_create_baseline where event_type='grade_level.created'),'grade code collision creates no audit or outbox side effect');
set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.create_grade_level('73000000-0000-0000-0000-000000000001','UNIQUE-GRADE',' auth GRADE 1 ',92::smallint)$$,'23505','grade level normalized name already exists','grade create rejects case/whitespace name collision');
reset role; select ok((select audit_count=(select count(*) from public.audit_log where action='grade_level.created') and outbox_count=(select count(*) from public.event_outbox where event_type='grade_level.created') from normalized_create_baseline where event_type='grade_level.created'),'grade name collision creates no audit or outbox side effect');
set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.create_subject('73000000-0000-0000-0000-000000000001',' math ','Unique Subject Code')$$,'23505','subject normalized code already exists','subject create rejects case/whitespace code collision');
reset role; select ok((select audit_count=(select count(*) from public.audit_log where action='subject.created') and outbox_count=(select count(*) from public.event_outbox where event_type='subject.created') from normalized_create_baseline where event_type='subject.created'),'subject code collision creates no audit or outbox side effect');
set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.create_subject('73000000-0000-0000-0000-000000000001','UNIQUE-SUBJECT',' mathematics ')$$,'23505','subject normalized name already exists','subject create rejects case/whitespace name collision');
reset role; select ok((select audit_count=(select count(*) from public.audit_log where action='subject.created') and outbox_count=(select count(*) from public.event_outbox where event_type='subject.created') from normalized_create_baseline where event_type='subject.created'),'subject name collision creates no audit or outbox side effect');
set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.create_section('74000000-0000-0000-0000-000000000001','77000000-0000-0000-0000-000000000001',null,'78000000-0000-0000-0000-000000000001',null,' 1a ','Unique Section Code',10,'2026-01-01','2026-12-31','inactive')$$,'23505','section normalized code already exists','section create rejects case/whitespace code collision');
reset role; select ok((select audit_count=(select count(*) from public.audit_log where action='section.created') and outbox_count=(select count(*) from public.event_outbox where event_type='section.created') from normalized_create_baseline where event_type='section.created'),'section code collision creates no audit or outbox side effect');
set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.create_section('74000000-0000-0000-0000-000000000001','77000000-0000-0000-0000-000000000001',null,'78000000-0000-0000-0000-000000000001',null,'UNIQUE-SECTION',' grade 1 a ',10,'2026-01-01','2026-12-31','inactive')$$,'23505','section normalized name already exists','section create rejects case/whitespace name collision');
reset role; select ok((select audit_count=(select count(*) from public.audit_log where action='section.created') and outbox_count=(select count(*) from public.event_outbox where event_type='section.created') from normalized_create_baseline where event_type='section.created'),'section name collision creates no audit or outbox side effect');
set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.create_section('74000000-0000-0000-0000-000000000001','77000000-0000-0000-0000-000000000001',null,'78000000-0000-0000-0000-000000000001','7a000000-0000-0000-0000-000000000001','1B','Too Large',30,'2026-01-01','2026-12-31','active')$$,'22023','active homeroom in section campus with sufficient capacity is required','section capacity enforced');
select throws_ok($$select public.update_room('7a000000-0000-0000-0000-000000000001','101','Room 101','classroom',10,'active')$$,'P0001','active section prevents room archive/capacity reduction','reverse capacity enforced');
select throws_ok($$select public.archive_room('7a000000-0000-0000-0000-000000000001')$$,'P0001','active section prevents room archive/capacity reduction','room archive blocked');
select throws_ok($$select public.archive_grade_level('78000000-0000-0000-0000-000000000001')$$,'P0001','grade level has active sections','grade archive blocked');
select throws_ok($$insert into public.subjects(organization_id,school_id,code,name) values('72000000-0000-0000-0000-000000000001','73000000-0000-0000-0000-000000000001','SCI','Science')$$,'42501','permission denied for table subjects','direct write denied');

reset role; update public.campuses set status='inactive' where id='74000000-0000-0000-0000-000000000001'; set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.update_building('79000000-0000-0000-0000-000000000001','A','Blocked','active')$$,'P0002','active building organization, school, and campus are required','building update rejects inactive campus');
reset role; update public.campuses set status='active' where id='74000000-0000-0000-0000-000000000001'; update public.buildings set status='inactive' where id='79000000-0000-0000-0000-000000000001'; set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.update_room('7a000000-0000-0000-0000-000000000001','101','Blocked','classroom',25,'active')$$,'P0002','active room organization, school, campus, and building are required','room update rejects inactive building');
reset role; update public.buildings set status='active' where id='79000000-0000-0000-0000-000000000001'; update public.schools set status='inactive' where id='73000000-0000-0000-0000-000000000001'; set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.update_grade_level('78000000-0000-0000-0000-000000000001','G1','Blocked',1::smallint,'active')$$,'P0002','active catalog organization and school are required','grade update rejects inactive school');
select throws_ok($$select public.update_subject((select id from public.subjects where code='MATH'),'MATH','Blocked',null,'active')$$,'P0002','active catalog organization and school are required','subject update rejects inactive school');
reset role; update public.schools set status='active' where id='73000000-0000-0000-0000-000000000001'; update public.grade_levels set status='inactive' where id='78000000-0000-0000-0000-000000000001'; set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.update_section((select id from public.sections where code='1A'),'1A','Blocked',20,'2026-01-01','2026-12-31',null,'7a000000-0000-0000-0000-000000000001','active')$$,'P0002','active section parents in the immutable composite scope are required','section update rejects inactive grade');
reset role;
create temporary table inactive_staff_target on commit drop as
 select id from public.staff_profiles where organization_membership_id='75000000-0000-0000-0000-000000000002' limit 1;
grant select on inactive_staff_target to authenticated;
update public.grade_levels set status='active' where id='78000000-0000-0000-0000-000000000001';
update public.organization_memberships set status='suspended' where id='75000000-0000-0000-0000-000000000002';
set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.update_staff_profile((select id from inactive_staff_target),'Blocked','employee','active')$$,'P0002','active staff organization, membership, school, and campus are required','staff update rejects inactive membership');
reset role; update public.organization_memberships set status='active' where id='75000000-0000-0000-0000-000000000002';

reset role;
insert into public.buildings(id,organization_id,school_id,campus_id,code,name,opened_on,closed_on,status) values
 ('77a00000-0000-0000-0000-000000000001','72000000-0000-0000-0000-000000000001','73000000-0000-0000-0000-000000000001','74000000-0000-0000-0000-000000000001','MUT-B','Mutable Building','2039-01-01','2039-12-31','active');
insert into public.rooms(id,organization_id,school_id,campus_id,building_id,code,name,room_type,capacity,floor_label,status) values
 ('77a10000-0000-0000-0000-000000000001','72000000-0000-0000-0000-000000000001','73000000-0000-0000-0000-000000000001','74000000-0000-0000-0000-000000000001','77a00000-0000-0000-0000-000000000001','MUT-R','Mutable Room','classroom',20,'Ground','active');
set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select lives_ok($$select public.update_building('77a00000-0000-0000-0000-000000000001','MUT-B2','Mutable Building Two','inactive','2041-01-01',true,'2041-12-31',true)$$,'building update changes every mutable non-scope field');
reset role;
select ok((select code='MUT-B2' and name='Mutable Building Two' and opened_on='2041-01-01' and closed_on='2041-12-31' and status='inactive' from public.buildings where id='77a00000-0000-0000-0000-000000000001'),'building mutable fields persist');
set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select lives_ok($$select public.update_building('77a00000-0000-0000-0000-000000000001','MUT-B3','Mutable Building Three','active',null,false,null,false)$$,'building update can leave nullable dates unchanged explicitly');
reset role;
select ok((select opened_on='2041-01-01' and closed_on='2041-12-31' from public.buildings where id='77a00000-0000-0000-0000-000000000001'),'building nullable dates remain unchanged when set flags are false');
set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select lives_ok($$select public.update_building('77a00000-0000-0000-0000-000000000001','MUT-B3','Mutable Building Three','active',null,true,null,true)$$,'building update explicitly clears nullable dates');
reset role;
select ok((select opened_on is null and closed_on is null from public.buildings where id='77a00000-0000-0000-0000-000000000001'),'building nullable dates are explicitly cleared');
set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.update_building('77a00000-0000-0000-0000-000000000001','MUT-B3','Invalid Building Dates','active','2042-12-31',true,'2042-01-01',true)$$,'22023','building closed date must not precede opened date','building update rejects reversed lifecycle dates');
select throws_ok($$select public.update_building('77a00000-0000-0000-0000-000000000001','MUT-B3','Direct Archive','archived',null,false,null,false)$$,'22023','use archive_building to archive a building','building update cannot bypass archive command restrictions');
select throws_ok($$select public.archive_building('77a00000-0000-0000-0000-000000000001')$$,'P0001','building has active rooms','building archive remains blocked while an active room exists');
select lives_ok($$select public.update_room('77a10000-0000-0000-0000-000000000001','MUT-R2','Mutable Room Two','laboratory',30,'inactive','First',true)$$,'room update changes every mutable non-scope field');
reset role;
select ok((select code='MUT-R2' and name='Mutable Room Two' and room_type='laboratory' and capacity=30 and floor_label='First' and status='inactive' from public.rooms where id='77a10000-0000-0000-0000-000000000001'),'room mutable fields persist');
set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select lives_ok($$select public.update_room('77a10000-0000-0000-0000-000000000001','MUT-R3','Mutable Room Three','classroom',25,'active',null,false)$$,'room update can leave nullable floor unchanged explicitly');
reset role;
select is((select floor_label from public.rooms where id='77a10000-0000-0000-0000-000000000001'),'First','room floor remains unchanged when set flag is false');
set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select lives_ok($$select public.update_room('77a10000-0000-0000-0000-000000000001','MUT-R3','Mutable Room Three','classroom',25,'active',null,true)$$,'room update explicitly clears nullable floor');
reset role;
select ok((select floor_label is null from public.rooms where id='77a10000-0000-0000-0000-000000000001'),'room nullable floor is explicitly cleared');
set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.update_room('77a10000-0000-0000-0000-000000000001','MUT-R3','Invalid Capacity','classroom',0,'active',null,false)$$,'22023','room capacity must be positive','room update rejects non-positive capacity deliberately');
select throws_ok($$select public.update_room('77a10000-0000-0000-0000-000000000001','MUT-R3','Direct Archive','classroom',25,'archived',null,false)$$,'22023','use archive_room to archive a room','room update cannot bypass archive command restrictions');
reset role;
select ok((select organization_id='72000000-0000-0000-0000-000000000001' and school_id='73000000-0000-0000-0000-000000000001' and campus_id='74000000-0000-0000-0000-000000000001' and updated_by='71000000-0000-0000-0000-000000000001' from public.buildings where id='77a00000-0000-0000-0000-000000000001') and (select organization_id='72000000-0000-0000-0000-000000000001' and school_id='73000000-0000-0000-0000-000000000001' and campus_id='74000000-0000-0000-0000-000000000001' and building_id='77a00000-0000-0000-0000-000000000001' and updated_by='71000000-0000-0000-0000-000000000001' from public.rooms where id='77a10000-0000-0000-0000-000000000001'),'building and room updates preserve structural scope and attribute actor');
select ok((select name='Mutable Building Three' and opened_on is null and closed_on is null from public.buildings where id='77a00000-0000-0000-0000-000000000001') and (select name='Mutable Room Three' and capacity=25 and floor_label is null from public.rooms where id='77a10000-0000-0000-0000-000000000001'),'rejected building and room updates roll back all row changes');
select is((select count(*)::int from public.audit_log where action in ('building.updated','room.updated') and after_data->>'name' in ('Invalid Building Dates','Direct Archive','Invalid Capacity')),0,'rejected building and room updates leave no audit rows');
select is((select count(*)::int from public.event_outbox where event_type in ('building.updated','room.updated') and aggregate_id in ('77a00000-0000-0000-0000-000000000001','77a10000-0000-0000-0000-000000000001')),6,'successful building and room updates atomically emit one outbox event each');

insert into public.grade_levels(id,organization_id,school_id,code,name,sequence,minimum_age,maximum_age,status) values
 ('77b00000-0000-0000-0000-000000000001','72000000-0000-0000-0000-000000000001','73000000-0000-0000-0000-000000000001','MUT-G','Mutable Grade',20,8,9,'active'),
 ('77b00000-0000-0000-0000-000000000002','72000000-0000-0000-0000-000000000001','73000000-0000-0000-0000-000000000001','DUP-G','Duplicate Grade',21,9,10,'active');
insert into public.subjects(id,organization_id,school_id,code,name,description,status) values
 ('77b10000-0000-0000-0000-000000000001','72000000-0000-0000-0000-000000000001','73000000-0000-0000-0000-000000000001','MUT-S','Mutable Subject','Original description','active'),
 ('77b10000-0000-0000-0000-000000000002','72000000-0000-0000-0000-000000000001','73000000-0000-0000-0000-000000000001','DUP-S','Duplicate Subject','Duplicate description','active');
set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select lives_ok($$select public.update_grade_level('77b00000-0000-0000-0000-000000000001','MUT-G2','Mutable Grade Two',22::smallint,'inactive',10::smallint,true,12::smallint,true)$$,'grade update changes every mutable non-scope field');
reset role;
select ok((select code='MUT-G2' and name='Mutable Grade Two' and sequence=22 and minimum_age=10 and maximum_age=12 and status='inactive' from public.grade_levels where id='77b00000-0000-0000-0000-000000000001'),'grade mutable fields persist');
set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select lives_ok($$select public.update_grade_level('77b00000-0000-0000-0000-000000000001','MUT-G3','Mutable Grade Three',23::smallint,'active',null,false,null,false)$$,'grade update can leave nullable ages unchanged explicitly');
reset role;
select ok((select minimum_age=10 and maximum_age=12 from public.grade_levels where id='77b00000-0000-0000-0000-000000000001'),'grade ages remain unchanged when set flags are false');
set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select lives_ok($$select public.update_grade_level('77b00000-0000-0000-0000-000000000001','MUT-G3','Mutable Grade Three',23::smallint,'active',null,true,null,true)$$,'grade update explicitly clears nullable ages');
reset role;
select ok((select minimum_age is null and maximum_age is null from public.grade_levels where id='77b00000-0000-0000-0000-000000000001'),'grade nullable ages are explicitly cleared');
set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.update_grade_level('77b00000-0000-0000-0000-000000000001','MUT-G3','Bad Minimum',23::smallint,'active',31::smallint,true,null,false)$$,'22023','grade level minimum age must be between 0 and 30','grade update rejects minimum age outside range');
select throws_ok($$select public.update_grade_level('77b00000-0000-0000-0000-000000000001','MUT-G3','Bad Maximum',23::smallint,'active',null,false,-1::smallint,true)$$,'22023','grade level maximum age must be between 0 and 30','grade update rejects maximum age outside range');
select throws_ok($$select public.update_grade_level('77b00000-0000-0000-0000-000000000001','MUT-G3','Bad Age Order',23::smallint,'active',12::smallint,true,10::smallint,true)$$,'22023','grade level maximum age must not be below minimum age','grade update rejects reversed age range');
select throws_ok($$select public.update_grade_level('77b00000-0000-0000-0000-000000000001','MUT-G3','Bad Sequence',0::smallint,'active',null,false,null,false)$$,'22023','grade level sequence must be positive','grade update rejects non-positive sequence');
select throws_ok($$select public.update_grade_level('77b00000-0000-0000-0000-000000000001','  dup-g  ','Unique Grade',23::smallint,'active',null,false,null,false)$$,'23505','grade level normalized code already exists','grade update rejects normalized code collision');
select throws_ok($$select public.update_grade_level('77b00000-0000-0000-0000-000000000001','UNIQUE-G',' duplicate GRADE ',23::smallint,'active',null,false,null,false)$$,'23505','grade level normalized name already exists','grade update rejects normalized name collision');
select throws_ok($$select public.update_grade_level('77b00000-0000-0000-0000-000000000001','UNIQUE-G','Unique Grade',21::smallint,'active',null,false,null,false)$$,'23505','grade level sequence already exists','grade update rejects duplicate sequence');
select throws_ok($$select public.update_grade_level('77b00000-0000-0000-0000-000000000001','MUT-G3','Direct Archive',23::smallint,'archived',null,false,null,false)$$,'22023','use archive_grade_level to archive a grade level','grade update cannot bypass archive command');
select lives_ok($$select public.update_subject('77b10000-0000-0000-0000-000000000001','MUT-S2','Mutable Subject Two','Updated description','inactive',true)$$,'subject update changes every mutable non-scope field');
reset role;
select ok((select code='MUT-S2' and name='Mutable Subject Two' and description='Updated description' and status='inactive' from public.subjects where id='77b10000-0000-0000-0000-000000000001'),'subject mutable fields persist');
set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select lives_ok($$select public.update_subject('77b10000-0000-0000-0000-000000000001','MUT-S3','Mutable Subject Three',null,'active',false)$$,'subject update can leave description unchanged explicitly');
reset role;
select is((select description from public.subjects where id='77b10000-0000-0000-0000-000000000001'),'Updated description','subject description remains unchanged when set flag is false');
set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select lives_ok($$select public.update_subject('77b10000-0000-0000-0000-000000000001','MUT-S3','Mutable Subject Three',null,'active',true)$$,'subject update explicitly clears description');
reset role;
select ok((select description is null from public.subjects where id='77b10000-0000-0000-0000-000000000001'),'subject description is explicitly cleared');
set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.update_subject('77b10000-0000-0000-0000-000000000001','  dup-s ','Unique Subject',null,'active',false)$$,'23505','subject normalized code already exists','subject update rejects normalized code collision');
select throws_ok($$select public.update_subject('77b10000-0000-0000-0000-000000000001','UNIQUE-S',' duplicate SUBJECT ',null,'active',false)$$,'23505','subject normalized name already exists','subject update rejects normalized name collision');
select throws_ok($$select public.update_subject('77b10000-0000-0000-0000-000000000001','MUT-S3','Direct Archive',null,'archived',false)$$,'22023','use archive_subject to archive a subject','subject update cannot bypass archive command');
select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000002","role":"authenticated"}',true);
select throws_ok($$select public.update_grade_level('77b00000-0000-0000-0000-000000000001','MUT-G3','Campus Denied',23::smallint,'active',null,false,null,false)$$,'42501','permission denied','campus-scoped role remains read-only for grade catalog');
select throws_ok($$select public.update_subject('77b10000-0000-0000-0000-000000000001','MUT-S3','Campus Denied',null,'active',false)$$,'42501','permission denied','campus-scoped role remains read-only for subject catalog');
reset role;
select ok((select organization_id='72000000-0000-0000-0000-000000000001' and school_id='73000000-0000-0000-0000-000000000001' and updated_by='71000000-0000-0000-0000-000000000001' from public.grade_levels where id='77b00000-0000-0000-0000-000000000001') and (select organization_id='72000000-0000-0000-0000-000000000001' and school_id='73000000-0000-0000-0000-000000000001' and updated_by='71000000-0000-0000-0000-000000000001' from public.subjects where id='77b10000-0000-0000-0000-000000000001'),'catalog updates preserve structural scope and attribute actor');
select ok((select name='Mutable Grade Three' and sequence=23 and minimum_age is null and maximum_age is null from public.grade_levels where id='77b00000-0000-0000-0000-000000000001') and (select name='Mutable Subject Three' and description is null from public.subjects where id='77b10000-0000-0000-0000-000000000001'),'rejected catalog updates roll back all row changes');
select is((select count(*)::int from public.audit_log where action in ('grade_level.updated','subject.updated') and after_data->>'name' in ('Bad Minimum','Bad Maximum','Bad Age Order','Bad Sequence','Direct Archive','Campus Denied')),0,'rejected catalog updates leave no audit rows');
select is((select count(*)::int from public.event_outbox where event_type in ('grade_level.updated','subject.updated') and aggregate_id in ('77b00000-0000-0000-0000-000000000001','77b10000-0000-0000-0000-000000000001')),6,'successful catalog updates atomically emit one outbox event each');

set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select lives_ok($$select public.update_staff_profile(id=>(select id from public.staff_profiles where staff_number='CAMPUS-OK'),staff_number=>'STAFF-MUT',employment_type=>'contractor',status=>'inactive',job_title=>'Teacher',set_job_title=>true,department=>'Science',set_department=>true,hire_date=>'2041-01-01',set_hire_date=>true,termination_date=>'2041-12-31',set_termination_date=>true)$$,'staff update changes all non-placement mutable fields');
reset role;
select ok((select staff_number='STAFF-MUT' and employment_type='contractor' and job_title='Teacher' and department='Science' and hire_date='2041-01-01' and termination_date='2041-12-31' and status='inactive' from public.staff_profiles where organization_membership_id='75000000-0000-0000-0000-000000000006'),'staff mutable employment fields persist');
set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select lives_ok($$select public.update_staff_profile(id=>(select id from public.staff_profiles where staff_number='STAFF-MUT'),staff_number=>'STAFF-MUT',employment_type=>'employee',status=>'active',job_title=>null,set_job_title=>false,department=>null,set_department=>false,hire_date=>null,set_hire_date=>false,termination_date=>null,set_termination_date=>false)$$,'staff update can explicitly preserve nullable fields');
reset role;
select ok((select job_title='Teacher' and department='Science' and hire_date='2041-01-01' and termination_date='2041-12-31' from public.staff_profiles where staff_number='STAFF-MUT'),'staff nullable fields remain unchanged when set flags are false');
set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000007","role":"authenticated"}',true);
select throws_ok($$select public.update_staff_profile(id=>(select id from public.staff_profiles where staff_number='STAFF-MUT'),staff_number=>'STAFF-MUT',employment_type=>'employee',status=>'active',campus_id=>'74000000-0000-0000-0000-000000000002',set_campus_id=>true)$$,'42501','permission denied over new home scope','campus manager cannot move staff to an unauthorized campus');
select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000006","role":"authenticated"}',true);
select lives_ok($$select public.update_staff_profile(id=>(select id from public.staff_profiles where staff_number='STAFF-MUT'),staff_number=>'STAFF-MUT',employment_type=>'employee',status=>'active',campus_id=>'74000000-0000-0000-0000-000000000002',set_campus_id=>true)$$,'school manager moves staff between authorized campuses');
reset role;
select is((select campus_id from public.staff_profiles where staff_number='STAFF-MUT'),'74000000-0000-0000-0000-000000000002'::uuid,'authorized campus move persists');
set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000006","role":"authenticated"}',true);
select throws_ok($$select public.update_staff_profile(id=>(select id from public.staff_profiles where staff_number='STAFF-MUT'),staff_number=>'STAFF-MUT',employment_type=>'employee',status=>'active',school_id=>'73000000-0000-0000-0000-000000000003',set_school_id=>true,campus_id=>'74000000-0000-0000-0000-000000000003',set_campus_id=>true)$$,'42501','permission denied over new home scope','school manager cannot move staff to an unauthorized school and campus');
select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select lives_ok($$select public.update_staff_profile(id=>(select id from public.staff_profiles where staff_number='STAFF-MUT'),staff_number=>'STAFF-MUT',employment_type=>'employee',status=>'active',school_id=>'73000000-0000-0000-0000-000000000003',set_school_id=>true,campus_id=>'74000000-0000-0000-0000-000000000003',set_campus_id=>true)$$,'organization manager moves staff across schools in the organization');
reset role;
select ok((select school_id='73000000-0000-0000-0000-000000000003' and campus_id='74000000-0000-0000-0000-000000000003' from public.staff_profiles where staff_number='STAFF-MUT'),'authorized cross-school placement persists with composite consistency');
set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.update_staff_profile(id=>(select id from public.staff_profiles where staff_number='STAFF-MUT'),staff_number=>'STAFF-MUT',employment_type=>'employee',status=>'active',hire_date=>'2042-12-31',set_hire_date=>true,termination_date=>'2042-01-01',set_termination_date=>true)$$,'22023','staff termination date must not precede hire date','staff update rejects termination before hire');
select throws_ok($$select public.update_staff_profile(id=>(select id from public.staff_profiles where staff_number='STAFF-MUT'),staff_number=>'  org-staff ',employment_type=>'employee',status=>'active')$$,'23505','normalized staff number already exists','staff update rejects normalized staff-number collision');
select throws_ok($$select public.update_staff_profile(id=>(select id from public.staff_profiles where staff_number='STAFF-MUT'),staff_number=>'STAFF-MUT',employment_type=>'employee',status=>'archived')$$,'22023','use archive_staff_profile to archive a staff profile','staff update cannot bypass archive command');
select lives_ok($$select public.update_staff_profile(id=>(select id from public.staff_profiles where staff_number='STAFF-MUT'),staff_number=>'STAFF-MUT',employment_type=>'employee',status=>'active',school_id=>null,set_school_id=>true,campus_id=>null,set_campus_id=>true,job_title=>null,set_job_title=>true,department=>null,set_department=>true,hire_date=>null,set_hire_date=>true,termination_date=>null,set_termination_date=>true)$$,'organization manager explicitly clears placement and nullable staff fields');
reset role;
select ok((select school_id is null and campus_id is null and job_title is null and department is null and hire_date is null and termination_date is null from public.staff_profiles where staff_number='STAFF-MUT'),'staff nullable placement, text, and date fields are explicitly cleared');
select ok((select organization_id='72000000-0000-0000-0000-000000000001' and organization_membership_id='75000000-0000-0000-0000-000000000006' and updated_by='71000000-0000-0000-0000-000000000001' from public.staff_profiles where staff_number='STAFF-MUT'),'staff update preserves tenant and membership identity and attributes actor');
select ok((select staff_number='STAFF-MUT' and status='active' and school_id is null and campus_id is null from public.staff_profiles where organization_membership_id='75000000-0000-0000-0000-000000000006'),'rejected staff updates roll back all row changes');
select is((select count(*)::int from public.audit_log where action='staff_profile.updated' and after_data->>'staff_number'='ORG-STAFF'),0,'rejected staff-number collision leaves no audit row');
select is((select count(*)::int from public.event_outbox where event_type='staff_profile.updated' and aggregate_id=(select id from public.staff_profiles where staff_number='STAFF-MUT')),5,'successful staff updates atomically emit one outbox event each');

insert into public.academic_years(id,organization_id,school_id,name,start_date,end_date,status) values ('77c00000-0000-0000-0000-000000000001','72000000-0000-0000-0000-000000000001','73000000-0000-0000-0000-000000000001','Section Update 2042','2042-01-01','2042-12-31','active');
insert into public.academic_terms(id,organization_id,academic_year_id,name,sequence,start_date,end_date,status) values
 ('77c10000-0000-0000-0000-000000000001','72000000-0000-0000-0000-000000000001','77c00000-0000-0000-0000-000000000001','Active Section Term',1,'2042-03-01','2042-11-30','active'),
 ('77c10000-0000-0000-0000-000000000002','72000000-0000-0000-0000-000000000001','77c00000-0000-0000-0000-000000000001','Draft Section Term',2,'2042-03-01','2042-11-30','draft');
insert into public.rooms(id,organization_id,school_id,campus_id,building_id,code,name,room_type,capacity,status) values
 ('77c20000-0000-0000-0000-000000000001','72000000-0000-0000-0000-000000000001','73000000-0000-0000-0000-000000000001','74000000-0000-0000-0000-000000000001','79000000-0000-0000-0000-000000000001','SEC-UPD','Section Update Room','classroom',30,'active'),
 ('77c20000-0000-0000-0000-000000000002','72000000-0000-0000-0000-000000000001','73000000-0000-0000-0000-000000000001','74000000-0000-0000-0000-000000000001','79000000-0000-0000-0000-000000000001','SEC-SMALL','Small Section Room','classroom',5,'active');
insert into public.sections(id,organization_id,school_id,campus_id,academic_year_id,academic_term_id,grade_level_id,homeroom_room_id,code,name,capacity,start_date,end_date,status) values
 ('77c30000-0000-0000-0000-000000000001','72000000-0000-0000-0000-000000000001','73000000-0000-0000-0000-000000000001','74000000-0000-0000-0000-000000000001','77c00000-0000-0000-0000-000000000001','77c10000-0000-0000-0000-000000000001','78000000-0000-0000-0000-000000000001','77c20000-0000-0000-0000-000000000001','MUT-SEC','Mutable Section',20,'2042-04-01','2042-10-31','inactive'),
 ('77c30000-0000-0000-0000-000000000002','72000000-0000-0000-0000-000000000001','73000000-0000-0000-0000-000000000001','74000000-0000-0000-0000-000000000001','77c00000-0000-0000-0000-000000000001',null,'78000000-0000-0000-0000-000000000001',null,'DUP-SEC','Duplicate Section',10,'2042-01-01','2042-12-31','inactive');
set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select lives_ok($$select public.update_section('77c30000-0000-0000-0000-000000000001','MUT-SEC2','Mutable Section Two',25,'2042-04-15','2042-10-15',null,null,'active',false,false)$$,'section update changes every required mutable field and activates legally');
reset role;
select ok((select code='MUT-SEC2' and name='Mutable Section Two' and capacity=25 and start_date='2042-04-15' and end_date='2042-10-15' and status='active' from public.sections where id='77c30000-0000-0000-0000-000000000001'),'section required mutable fields persist');
set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select lives_ok($$select public.update_section('77c30000-0000-0000-0000-000000000001','MUT-SEC3','Mutable Section Three',24,'2042-04-15','2042-10-15',null,null,'active',false,false)$$,'section update explicitly preserves optional term and room');
reset role;
select ok((select academic_term_id='77c10000-0000-0000-0000-000000000001' and homeroom_room_id='77c20000-0000-0000-0000-000000000001' from public.sections where id='77c30000-0000-0000-0000-000000000001'),'section optional relationships remain when set flags are false');
set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select lives_ok($$select public.update_section('77c30000-0000-0000-0000-000000000001','MUT-SEC3','Mutable Section Three',24,'2042-04-15','2042-10-15',null,null,'inactive',true,true)$$,'section update explicitly clears optional term and room');
reset role;
select ok((select academic_term_id is null and homeroom_room_id is null and status='inactive' from public.sections where id='77c30000-0000-0000-0000-000000000001'),'section optional relationships are explicitly cleared');
update public.campuses set status='inactive' where id='74000000-0000-0000-0000-000000000001'; set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.update_section('77c30000-0000-0000-0000-000000000001','MUT-SEC3','Inactive Campus',24,'2042-04-15','2042-10-15',null,null,'inactive',false,false)$$,'P0002','active section parents in the immutable composite scope are required','section update rejects inactive immutable campus');
reset role; update public.campuses set status='active' where id='74000000-0000-0000-0000-000000000001'; update public.academic_years set status='closed' where id='77c00000-0000-0000-0000-000000000001'; set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.update_section('77c30000-0000-0000-0000-000000000001','MUT-SEC3','Closed Year',24,'2042-04-15','2042-10-15',null,null,'inactive',false,false)$$,'P0002','active section parents in the immutable composite scope are required','section update rejects closed immutable year');
reset role; update public.academic_years set status='active' where id='77c00000-0000-0000-0000-000000000001'; set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.update_section('77c30000-0000-0000-0000-000000000001','MUT-SEC3','Reverse Dates',24,'2042-10-15','2042-04-15',null,null,'inactive',false,false)$$,'22023','section end date must not precede start date','section update rejects reversed dates');
select throws_ok($$select public.update_section('77c30000-0000-0000-0000-000000000001','MUT-SEC3','Outside Year',24,'2041-12-31','2042-10-15',null,null,'inactive',false,false)$$,'22023','academic year status or dates do not permit section update','section update rejects dates outside immutable year');
select throws_ok($$select public.update_section('77c30000-0000-0000-0000-000000000001','MUT-SEC3','Draft Active Term',24,'2042-04-15','2042-10-15','77c10000-0000-0000-0000-000000000002',null,'active',true,false)$$,'22023','academic term scope, status, or dates do not permit section update','active section cannot use draft term');
select throws_ok($$select public.update_section('77c30000-0000-0000-0000-000000000001','MUT-SEC3','Outside Term',24,'2042-01-01','2042-10-15','77c10000-0000-0000-0000-000000000001',null,'inactive',true,false)$$,'22023','academic term scope, status, or dates do not permit section update','section update enforces selected term bounds');
select throws_ok($$select public.update_section('77c30000-0000-0000-0000-000000000001','MUT-SEC3','Cross Year Term',24,'2042-04-15','2042-10-15','77100000-0000-0000-0000-000000000004',null,'inactive',true,false)$$,'22023','academic term scope, status, or dates do not permit section update','section update rejects term outside immutable year');
select throws_ok($$select public.update_section('77c30000-0000-0000-0000-000000000001','MUT-SEC3','Small Room',24,'2042-04-15','2042-10-15',null,'77c20000-0000-0000-0000-000000000002','inactive',false,true)$$,'22023','active homeroom in immutable campus with sufficient capacity is required','section update rejects insufficient room capacity');
select throws_ok($$select public.update_section('77c30000-0000-0000-0000-000000000001','MUT-SEC3','Other Campus Room',24,'2042-04-15','2042-10-15',null,'7a100000-0000-0000-0000-000000000001','inactive',false,true)$$,'22023','active homeroom in immutable campus with sufficient capacity is required','section update rejects room outside immutable campus');
select throws_ok($$select public.update_section('77c30000-0000-0000-0000-000000000001','MUT-SEC3','Bad Capacity',0,'2042-04-15','2042-10-15',null,null,'inactive',false,false)$$,'22023','section capacity must be between 1 and 10000','section update rejects invalid capacity');
select throws_ok($$select public.update_section('77c30000-0000-0000-0000-000000000001',' dup-sec ','Unique Section',24,'2042-04-15','2042-10-15',null,null,'inactive',false,false)$$,'23505','section normalized code already exists','section update rejects normalized code collision');
select throws_ok($$select public.update_section('77c30000-0000-0000-0000-000000000001','UNIQUE-SEC',' duplicate SECTION ',24,'2042-04-15','2042-10-15',null,null,'inactive',false,false)$$,'23505','section normalized name already exists','section update rejects normalized name collision');
select throws_ok($$select public.update_section('77c30000-0000-0000-0000-000000000001','MUT-SEC3','Direct Archive',24,'2042-04-15','2042-10-15',null,null,'archived',false,false)$$,'22023','use archive_section to archive a section','section update cannot bypass archive command');
reset role;
select ok((select organization_id='72000000-0000-0000-0000-000000000001' and school_id='73000000-0000-0000-0000-000000000001' and campus_id='74000000-0000-0000-0000-000000000001' and academic_year_id='77c00000-0000-0000-0000-000000000001' and grade_level_id='78000000-0000-0000-0000-000000000001' and updated_by='71000000-0000-0000-0000-000000000001' from public.sections where id='77c30000-0000-0000-0000-000000000001'),'section update preserves all structural scope and attributes actor');
select ok((select code='MUT-SEC3' and name='Mutable Section Three' and capacity=24 and start_date='2042-04-15' and end_date='2042-10-15' and academic_term_id is null and homeroom_room_id is null and status='inactive' from public.sections where id='77c30000-0000-0000-0000-000000000001'),'rejected section updates roll back all row changes');
select is((select count(*)::int from public.audit_log where action='section.updated' and after_data->>'name' in ('Inactive Campus','Closed Year','Reverse Dates','Outside Year','Draft Active Term','Outside Term','Cross Year Term','Small Room','Other Campus Room','Bad Capacity','Direct Archive')),0,'rejected section updates leave no audit rows');
select is((select count(*)::int from public.event_outbox where event_type='section.updated' and aggregate_id='77c30000-0000-0000-0000-000000000001'),3,'successful section updates atomically emit one outbox event each');

-- Every aggregate update/archive resolves a missing target before parent or RBAC checks.
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.update_staff_profile('7ff00000-0000-0000-0000-000000000001','MISS','employee','active')$$,'P0002','staff profile not found','staff update rejects a missing target deliberately');
select throws_ok($$select public.archive_staff_profile('7ff00000-0000-0000-0000-000000000001')$$,'P0002','staff profile not found','staff archive rejects a missing target deliberately');
select throws_ok($$select public.update_building('7ff00000-0000-0000-0000-000000000002','MISS','Missing','active')$$,'P0002','building not found','building update rejects a missing target deliberately');
select throws_ok($$select public.archive_building('7ff00000-0000-0000-0000-000000000002')$$,'P0002','building not found','building archive rejects a missing target deliberately');
select throws_ok($$select public.update_room('7ff00000-0000-0000-0000-000000000003','MISS','Missing','classroom',10,'active')$$,'P0002','room not found','room update rejects a missing target deliberately');
select throws_ok($$select public.archive_room('7ff00000-0000-0000-0000-000000000003')$$,'P0002','room not found','room archive rejects a missing target deliberately');
select throws_ok($$select public.update_grade_level('7ff00000-0000-0000-0000-000000000004','MISS','Missing',99::smallint,'active')$$,'P0002','grade level not found','grade-level update rejects a missing target deliberately');
select throws_ok($$select public.archive_grade_level('7ff00000-0000-0000-0000-000000000004')$$,'P0002','grade level not found','grade-level archive rejects a missing target deliberately');
select throws_ok($$select public.update_subject('7ff00000-0000-0000-0000-000000000005','MISS','Missing',null,'active')$$,'P0002','subject not found','subject update rejects a missing target deliberately');
select throws_ok($$select public.archive_subject('7ff00000-0000-0000-0000-000000000005')$$,'P0002','subject not found','subject archive rejects a missing target deliberately');
select throws_ok($$select public.update_section('7ff00000-0000-0000-0000-000000000006','MISS','Missing',10,'2026-01-01','2026-12-31',null,null,'inactive')$$,'P0002','section not found','section update rejects a missing target deliberately');
select throws_ok($$select public.archive_section('7ff00000-0000-0000-0000-000000000006')$$,'P0002','section not found','section archive rejects a missing target deliberately');
reset role;
select is((select count(*)::int from public.audit_log where entity_id in ('7ff00000-0000-0000-0000-000000000001','7ff00000-0000-0000-0000-000000000002','7ff00000-0000-0000-0000-000000000003','7ff00000-0000-0000-0000-000000000004','7ff00000-0000-0000-0000-000000000005','7ff00000-0000-0000-0000-000000000006')),0,'missing-target commands create no audit rows');
select is((select count(*)::int from public.event_outbox where aggregate_id in ('7ff00000-0000-0000-0000-000000000001','7ff00000-0000-0000-0000-000000000002','7ff00000-0000-0000-0000-000000000003','7ff00000-0000-0000-0000-000000000004','7ff00000-0000-0000-0000-000000000005','7ff00000-0000-0000-0000-000000000006')),0,'missing-target commands create no outbox rows');
select ok(
 not exists(select 1 from public.staff_profiles where id='7ff00000-0000-0000-0000-000000000001')
 and not exists(select 1 from public.buildings where id='7ff00000-0000-0000-0000-000000000002')
 and not exists(select 1 from public.rooms where id='7ff00000-0000-0000-0000-000000000003')
 and not exists(select 1 from public.grade_levels where id='7ff00000-0000-0000-0000-000000000004')
 and not exists(select 1 from public.subjects where id='7ff00000-0000-0000-0000-000000000005')
 and not exists(select 1 from public.sections where id='7ff00000-0000-0000-0000-000000000006'),
 'missing-target commands leave every aggregate absent'
);

insert into public.buildings(id,organization_id,school_id,campus_id,code,name) values ('7b000000-0000-0000-0000-000000000001','72000000-0000-0000-0000-000000000001','73000000-0000-0000-0000-000000000001','74000000-0000-0000-0000-000000000001','ARCH','Archive Building');
insert into public.rooms(id,organization_id,school_id,campus_id,building_id,code,name,room_type,capacity) values ('7c000000-0000-0000-0000-000000000001','72000000-0000-0000-0000-000000000001','73000000-0000-0000-0000-000000000001','74000000-0000-0000-0000-000000000001','79000000-0000-0000-0000-000000000001','ARCH','Archive Room','classroom',20);
insert into public.grade_levels(id,organization_id,school_id,code,name,sequence) values ('7d000000-0000-0000-0000-000000000001','72000000-0000-0000-0000-000000000001','73000000-0000-0000-0000-000000000001','G2','Grade 2',2);
insert into public.subjects(id,organization_id,school_id,code,name) values ('7e000000-0000-0000-0000-000000000001','72000000-0000-0000-0000-000000000001','73000000-0000-0000-0000-000000000001','ENG','English');
insert into public.sections(id,organization_id,school_id,campus_id,academic_year_id,grade_level_id,code,name,capacity,start_date,end_date,status) values ('7f000000-0000-0000-0000-000000000001','72000000-0000-0000-0000-000000000001','73000000-0000-0000-0000-000000000001','74000000-0000-0000-0000-000000000001','77000000-0000-0000-0000-000000000001','78000000-0000-0000-0000-000000000001','ARCH','Archive Section',10,'2026-01-01','2026-12-31','inactive');
insert into public.staff_profiles(id,organization_id,organization_membership_id,staff_number,employment_type) values ('7f100000-0000-0000-0000-000000000001','72000000-0000-0000-0000-000000000001','75000000-0000-0000-0000-000000000001','ARCH-1','employee');
set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select public.archive_building('7b000000-0000-0000-0000-000000000001'); select public.archive_room('7c000000-0000-0000-0000-000000000001');
select public.archive_grade_level('7d000000-0000-0000-0000-000000000001'); select public.archive_subject('7e000000-0000-0000-0000-000000000001');
select public.archive_section('7f000000-0000-0000-0000-000000000001'); select public.archive_staff_profile('7f100000-0000-0000-0000-000000000001');
select throws_ok($$select public.update_building('7b000000-0000-0000-0000-000000000001','ARCH','Reactivated','active')$$,'22023','building is archived and immutable','archived building cannot update/reactivate');
select throws_ok($$select public.archive_building('7b000000-0000-0000-0000-000000000001')$$,'22023','building is archived and immutable','archived building cannot archive again');
select throws_ok($$select public.update_room('7c000000-0000-0000-0000-000000000001','ARCH','Reactivated','classroom',20,'active')$$,'22023','room is archived and immutable','archived room cannot update/reactivate');
select throws_ok($$select public.archive_room('7c000000-0000-0000-0000-000000000001')$$,'22023','room is archived and immutable','archived room cannot archive again');
select throws_ok($$select public.update_grade_level('7d000000-0000-0000-0000-000000000001','G2','Reactivated',2::smallint,'active')$$,'22023','grade_level is archived and immutable','archived grade cannot update/reactivate');
select throws_ok($$select public.archive_grade_level('7d000000-0000-0000-0000-000000000001')$$,'22023','grade_level is archived and immutable','archived grade cannot archive again');
select throws_ok($$select public.update_subject('7e000000-0000-0000-0000-000000000001','ENG','Reactivated',null,'active')$$,'22023','subject is archived and immutable','archived subject cannot update/reactivate');
select throws_ok($$select public.archive_subject('7e000000-0000-0000-0000-000000000001')$$,'22023','subject is archived and immutable','archived subject cannot archive again');
select throws_ok($$select public.update_section('7f000000-0000-0000-0000-000000000001','ARCH','Reactivated',10,'2026-01-01','2026-12-31',null,null,'active')$$,'22023','section is archived and immutable','archived section cannot update/reactivate');
select throws_ok($$select public.archive_section('7f000000-0000-0000-0000-000000000001')$$,'22023','section is archived and immutable','archived section cannot archive again');
select throws_ok($$select public.update_staff_profile('7f100000-0000-0000-0000-000000000001','ARCH-1','employee','active')$$,'22023','staff_profile is archived and immutable','archived staff profile cannot update/reactivate');
select throws_ok($$select public.archive_staff_profile('7f100000-0000-0000-0000-000000000001')$$,'22023','staff_profile is archived and immutable','archived staff profile cannot archive again');

select throws_ok($$select public.update_academic_year('77000000-0000-0000-0000-000000000099','UPD-MISSING','2025-01-01','2025-12-31')$$,'P0002','academic year not found','year update rejects a missing target deliberately');
reset role; update public.schools set status='inactive' where id='73000000-0000-0000-0000-000000000001'; set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.update_academic_year('77000000-0000-0000-0000-000000000005','UPD-INACTIVE-SCHOOL','2025-01-01','2025-12-31')$$,'P0002','active academic-year organization and school are required','year update rejects inactive authoritative school');
reset role; update public.schools set status='active' where id='73000000-0000-0000-0000-000000000001'; update public.organizations set status='inactive' where id='72000000-0000-0000-0000-000000000001'; set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.update_academic_year('77000000-0000-0000-0000-000000000005','UPD-INACTIVE-ORG','2025-01-01','2025-12-31')$$,'P0002','active academic-year organization and school are required','year update rejects inactive authoritative organization');
reset role; update public.organizations set status='active' where id='72000000-0000-0000-0000-000000000001'; set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.update_academic_year('77000000-0000-0000-0000-000000000005','UPD-BAD-DATES','2025-12-31','2025-01-01')$$,'22023','academic year end date must be after start date','year update rejects invalid date order');
select throws_ok($$select public.update_academic_year('77000000-0000-0000-0000-000000000001','UPD-EXCLUDES-CHILD','2026-02-01','2026-11-30')$$,'22023','academic year dates exclude non-archived sections or terms','year update cannot exclude non-archived terms or sections');
select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000008","role":"authenticated"}',true);
select throws_ok($$select public.update_academic_year('77000000-0000-0000-0000-000000000005','UPD-NOPERM','2025-01-01','2025-12-31')$$,'42501','academic_periods.manage permission is required','year update rejects missing permission');
select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000003","role":"authenticated"}',true);
select throws_ok($$select public.update_academic_year('77000000-0000-0000-0000-000000000005','UPD-SUSPENDED','2025-01-01','2025-12-31')$$,'42501','academic_periods.manage permission is required','year update rejects suspended membership');
select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000006","role":"authenticated"}',true);
select throws_ok($$select public.update_academic_year('77000000-0000-0000-0000-000000000004','UPD-CROSS-SCHOOL','2026-01-01','2026-12-31')$$,'42501','academic_periods.manage permission is required','school manager cannot update another school year');
select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.update_academic_year('77000000-0000-0000-0000-000000000003','UPD-CROSS-TENANT','2026-01-01','2026-12-31')$$,'42501','academic_periods.manage permission is required','organization manager cannot update another tenant year');
select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000006","role":"authenticated"}',true);
select lives_ok($$select public.update_academic_year('77000000-0000-0000-0000-000000000005','UPD-SCHOOL-OK','2025-01-01','2025-12-31')$$,'school manager updates own school year');
select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select lives_ok($$select public.update_academic_year('77000000-0000-0000-0000-000000000005','UPD-ORG-OK','2025-01-01','2025-12-31')$$,'organization manager updates year within organization');
reset role;
select ok((select organization_id='72000000-0000-0000-0000-000000000001' and school_id='73000000-0000-0000-0000-000000000001' and name='UPD-ORG-OK' and updated_by='71000000-0000-0000-0000-000000000001' from public.academic_years where id='77000000-0000-0000-0000-000000000005'),'year update preserves structural scope and attributes final actor');
select is((select count(*)::int from public.academic_years where name in ('UPD-INACTIVE-SCHOOL','UPD-INACTIVE-ORG','UPD-BAD-DATES','UPD-EXCLUDES-CHILD','UPD-NOPERM','UPD-SUSPENDED','UPD-CROSS-SCHOOL','UPD-CROSS-TENANT')),0,'denied year updates leave all year rows unchanged');
select is((select count(*)::int from public.audit_log where after_data->>'name' in ('UPD-INACTIVE-SCHOOL','UPD-INACTIVE-ORG','UPD-BAD-DATES','UPD-EXCLUDES-CHILD','UPD-NOPERM','UPD-SUSPENDED','UPD-CROSS-SCHOOL','UPD-CROSS-TENANT')),0,'denied year updates leave no audit rows');
select is((select count(*)::int from public.event_outbox where event_type='academic_year.updated' and payload->>'actor_user_id' in ('71000000-0000-0000-0000-000000000008','71000000-0000-0000-0000-000000000003')),0,'permission-denied year updates leave no outbox events');
select ok((select count(*)=2 from public.audit_log where action='academic_year.updated' and entity_id='77000000-0000-0000-0000-000000000005' and actor_user_id in ('71000000-0000-0000-0000-000000000006','71000000-0000-0000-0000-000000000001')),'permitted year updates are atomically audited with actor attribution');

insert into public.academic_years(id,organization_id,school_id,name,start_date,end_date,status) values
 ('77600000-0000-0000-0000-000000000001','72000000-0000-0000-0000-000000000001','73000000-0000-0000-0000-000000000001','Transition Draft','2032-01-01','2032-12-31','draft'),
 ('77600000-0000-0000-0000-000000000002','72000000-0000-0000-0000-000000000001','73000000-0000-0000-0000-000000000001','Transition Archived','2033-01-01','2033-12-31','archived'),
 ('77600000-0000-0000-0000-000000000003','72000000-0000-0000-0000-000000000001','73000000-0000-0000-0000-000000000001','Transition Active Term','2034-01-01','2034-12-31','active'),
 ('77600000-0000-0000-0000-000000000004','72000000-0000-0000-0000-000000000001','73000000-0000-0000-0000-000000000001','Transition Closed','2035-01-01','2035-12-31','closed');
insert into public.academic_terms(id,organization_id,academic_year_id,name,sequence,start_date,end_date,status)
values ('77610000-0000-0000-0000-000000000001','72000000-0000-0000-0000-000000000001','77600000-0000-0000-0000-000000000003','Active Term',1,'2034-01-01','2034-12-31','active');
set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.transition_academic_year_status('77600000-0000-0000-0000-000000000099','active')$$,'P0002','academic year not found','year transition rejects a missing target deliberately');
reset role; update public.schools set status='inactive' where id='73000000-0000-0000-0000-000000000001'; set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.transition_academic_year_status('77600000-0000-0000-0000-000000000001','active')$$,'P0002','active academic-year organization and school are required','year transition rejects inactive authoritative school');
reset role; update public.schools set status='active' where id='73000000-0000-0000-0000-000000000001'; update public.organizations set status='inactive' where id='72000000-0000-0000-0000-000000000001'; set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.transition_academic_year_status('77600000-0000-0000-0000-000000000001','active')$$,'P0002','active academic-year organization and school are required','year transition rejects inactive authoritative organization');
reset role; update public.organizations set status='active' where id='72000000-0000-0000-0000-000000000001'; set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.transition_academic_year_status('77600000-0000-0000-0000-000000000001','closed')$$,'22023','illegal academic year status transition','draft year cannot transition directly to closed');
select throws_ok($$select public.transition_academic_year_status('77000000-0000-0000-0000-000000000005','archived')$$,'22023','illegal academic year status transition','active year cannot transition directly to archived');
select throws_ok($$select public.transition_academic_year_status('77600000-0000-0000-0000-000000000004','active')$$,'22023','illegal academic year status transition','closed year cannot reactivate');
select throws_ok($$select public.transition_academic_year_status('77600000-0000-0000-0000-000000000002','active')$$,'22023','illegal academic year status transition','archived year is terminal');
select throws_ok($$select public.transition_academic_year_status('77600000-0000-0000-0000-000000000001','draft')$$,'22023','illegal academic year status transition','year transition rejects a no-op');
select throws_ok($$select public.transition_academic_year_status('77000000-0000-0000-0000-000000000001','closed')$$,'22023','academic year has active sections','year cannot close while active sections exist');
select throws_ok($$select public.transition_academic_year_status('77600000-0000-0000-0000-000000000003','closed')$$,'22023','academic year has active terms','year cannot close while active terms exist');
select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000008","role":"authenticated"}',true);
select throws_ok($$select public.transition_academic_year_status('77000000-0000-0000-0000-000000000005','closed')$$,'42501','academic_periods.manage permission is required','year transition rejects missing permission');
select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000003","role":"authenticated"}',true);
select throws_ok($$select public.transition_academic_year_status('77000000-0000-0000-0000-000000000005','closed')$$,'42501','academic_periods.manage permission is required','year transition rejects suspended membership');
select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000006","role":"authenticated"}',true);
select throws_ok($$select public.transition_academic_year_status('77000000-0000-0000-0000-000000000004','closed')$$,'42501','academic_periods.manage permission is required','school manager cannot transition another school year');
select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.transition_academic_year_status('77000000-0000-0000-0000-000000000003','closed')$$,'42501','academic_periods.manage permission is required','organization manager cannot transition another tenant year');
reset role;
select ok((select status='draft' from public.academic_years where id='77600000-0000-0000-0000-000000000001') and (select status='active' from public.academic_years where id='77000000-0000-0000-0000-000000000005'),'denied and illegal transitions leave year status unchanged');
select is((select count(*)::int from public.audit_log where action='academic_year.status_changed'),0,'denied transitions leave no audit rows');
select is((select count(*)::int from public.event_outbox where event_type='academic_year.status_changed'),0,'denied transitions leave no outbox events');
set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000006","role":"authenticated"}',true);
select lives_ok($$select public.transition_academic_year_status('77600000-0000-0000-0000-000000000001','active')$$,'school manager activates own school year');
select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select lives_ok($$select public.transition_academic_year_status('77600000-0000-0000-0000-000000000001','closed')$$,'organization manager closes year within organization');
select lives_ok($$select public.transition_academic_year_status('77600000-0000-0000-0000-000000000001','archived')$$,'organization manager archives closed year');
reset role;
select ok((select status='archived' and organization_id='72000000-0000-0000-0000-000000000001' and school_id='73000000-0000-0000-0000-000000000001' and updated_by='71000000-0000-0000-0000-000000000001' from public.academic_years where id='77600000-0000-0000-0000-000000000001'),'successful transitions preserve scope and attribute the server actor');
select is((select count(*)::int from public.audit_log where action='academic_year.status_changed' and entity_id='77600000-0000-0000-0000-000000000001'),3,'successful year transitions write one attributed audit row each');
select is((select count(*)::int from public.event_outbox where event_type='academic_year.status_changed' and aggregate_id='77600000-0000-0000-0000-000000000001'),3,'successful year transitions write one outbox event each');

insert into public.academic_years(id,organization_id,school_id,name,start_date,end_date,status) values
 ('77700000-0000-0000-0000-000000000001','72000000-0000-0000-0000-000000000001','73000000-0000-0000-0000-000000000001','Term Draft Parent','2036-01-01','2036-12-31','draft'),
 ('77700000-0000-0000-0000-000000000002','72000000-0000-0000-0000-000000000001','73000000-0000-0000-0000-000000000001','Term Active Parent','2037-01-01','2037-12-31','active');
insert into public.academic_terms(id,organization_id,academic_year_id,name,sequence,start_date,end_date,status)
values ('77710000-0000-0000-0000-000000000001','72000000-0000-0000-0000-000000000001','77700000-0000-0000-0000-000000000002','Existing Term',1,'2037-01-01','2037-06-30','draft');
set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.create_academic_term('77700000-0000-0000-0000-000000000099','Missing',1::smallint,'2036-01-01','2036-06-30','draft')$$,'P0002','academic year not found','term create rejects missing parent year deliberately');
reset role; update public.schools set status='inactive' where id='73000000-0000-0000-0000-000000000001'; set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.create_academic_term('77700000-0000-0000-0000-000000000001','Inactive School',2::smallint,'2036-01-01','2036-06-30','draft')$$,'P0002','active academic-term organization and school are required','term create rejects inactive authoritative school');
reset role; update public.schools set status='active' where id='73000000-0000-0000-0000-000000000001'; update public.organizations set status='inactive' where id='72000000-0000-0000-0000-000000000001'; set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.create_academic_term('77700000-0000-0000-0000-000000000001','Inactive Org',2::smallint,'2036-01-01','2036-06-30','draft')$$,'P0002','active academic-term organization and school are required','term create rejects inactive authoritative organization');
reset role; update public.organizations set status='active' where id='72000000-0000-0000-0000-000000000001'; set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.create_academic_term('77600000-0000-0000-0000-000000000004','Closed Parent',1::smallint,'2035-01-01','2035-06-30','draft')$$,'22023','academic year status does not permit term creation','term create rejects closed parent year');
select throws_ok($$select public.create_academic_term('77600000-0000-0000-0000-000000000002','Archived Parent',1::smallint,'2033-01-01','2033-06-30','draft')$$,'22023','academic year status does not permit term creation','term create rejects archived parent year');
select throws_ok($$select public.create_academic_term('77700000-0000-0000-0000-000000000001','Active Under Draft',2::smallint,'2036-01-01','2036-06-30','active')$$,'22023','academic term initial status is incompatible with academic year','active term requires an active parent year');
select throws_ok($$select public.create_academic_term('77700000-0000-0000-0000-000000000002','Bad Order',2::smallint,'2037-06-30','2037-01-01','draft')$$,'22023','academic term end date must not precede start date','term create rejects reversed dates');
select throws_ok($$select public.create_academic_term('77700000-0000-0000-0000-000000000002','Before Year',2::smallint,'2036-12-31','2037-06-30','draft')$$,'22023','academic term dates must be within academic year','term create rejects a start before its year');
select throws_ok($$select public.create_academic_term('77700000-0000-0000-0000-000000000002','After Year',2::smallint,'2037-07-01','2038-01-01','draft')$$,'22023','academic term dates must be within academic year','term create rejects an end after its year');
select throws_ok($$select public.create_academic_term('77700000-0000-0000-0000-000000000002','Duplicate Sequence',1::smallint,'2037-07-01','2037-12-31','draft')$$,'23505','academic term sequence already exists','term create rejects duplicate sequence');
select throws_ok($$select public.create_academic_term('77700000-0000-0000-0000-000000000002','  existing TERM  ',2::smallint,'2037-07-01','2037-12-31','draft')$$,'23505','academic term normalized name already exists','term create rejects normalized name collision');
select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000008","role":"authenticated"}',true);
select throws_ok($$select public.create_academic_term('77700000-0000-0000-0000-000000000002','No Permission',2::smallint,'2037-07-01','2037-12-31','draft')$$,'42501','academic_periods.manage permission is required','term create rejects missing permission');
select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000003","role":"authenticated"}',true);
select throws_ok($$select public.create_academic_term('77700000-0000-0000-0000-000000000002','Suspended',2::smallint,'2037-07-01','2037-12-31','draft')$$,'42501','academic_periods.manage permission is required','term create rejects suspended membership');
select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000006","role":"authenticated"}',true);
select throws_ok($$select public.create_academic_term('77000000-0000-0000-0000-000000000004','Cross School',2::smallint,'2026-01-01','2026-06-30','draft')$$,'42501','academic_periods.manage permission is required','school manager cannot create a term in another school');
select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.create_academic_term('77000000-0000-0000-0000-000000000003','Cross Tenant',2::smallint,'2026-01-01','2026-06-30','draft')$$,'42501','academic_periods.manage permission is required','organization manager cannot create a term in another tenant');
reset role;
select is((select count(*)::int from public.academic_terms where name in ('Inactive School','Inactive Org','Closed Parent','Archived Parent','Active Under Draft','Bad Order','Before Year','After Year','Duplicate Sequence','No Permission','Suspended','Cross School','Cross Tenant')),0,'denied term creates leave no term rows');
select is((select count(*)::int from public.audit_log where action='academic_term.created'),0,'denied term creates leave no audit rows');
select is((select count(*)::int from public.event_outbox where event_type='academic_term.created'),0,'denied term creates leave no outbox events');
set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000006","role":"authenticated"}',true);
select lives_ok($$select public.create_academic_term('77700000-0000-0000-0000-000000000001',' School Draft Term ',1::smallint,'2036-01-01','2036-06-30','draft')$$,'school manager creates a draft term under a draft year');
select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select lives_ok($$select public.create_academic_term('77700000-0000-0000-0000-000000000002','Org Active Term',2::smallint,'2037-07-01','2037-12-31','active')$$,'organization manager creates an active term under an active year');
reset role;
select ok((select organization_id='72000000-0000-0000-0000-000000000001' and name='School Draft Term' and created_by='71000000-0000-0000-0000-000000000006' and updated_by='71000000-0000-0000-0000-000000000006' from public.academic_terms where academic_year_id='77700000-0000-0000-0000-000000000001'),'school term derives tenant, normalizes name, and attributes actor');
select ok((select organization_id='72000000-0000-0000-0000-000000000001' and status='active' and created_by='71000000-0000-0000-0000-000000000001' from public.academic_terms where academic_year_id='77700000-0000-0000-0000-000000000002' and sequence=2),'organization term derives tenant and attributes actor');
select is((select count(*)::int from public.audit_log where action='academic_term.created' and entity_id in (select id from public.academic_terms where academic_year_id in ('77700000-0000-0000-0000-000000000001','77700000-0000-0000-0000-000000000002') and sequence in (1,2))),2,'successful term creates are atomically audited');
select is((select count(*)::int from public.event_outbox where event_type='academic_term.created' and aggregate_id in (select id from public.academic_terms where academic_year_id in ('77700000-0000-0000-0000-000000000001','77700000-0000-0000-0000-000000000002') and sequence in (1,2))),2,'successful term creates atomically emit outbox events');

insert into public.academic_terms(id,organization_id,academic_year_id,name,sequence,start_date,end_date,status) values
 ('77810000-0000-0000-0000-000000000001','72000000-0000-0000-0000-000000000001','77600000-0000-0000-0000-000000000004','Closed Year Child',1,'2035-01-01','2035-12-31','closed'),
 ('77810000-0000-0000-0000-000000000002','72000000-0000-0000-0000-000000000001','77600000-0000-0000-0000-000000000002','Archived Year Child',1,'2033-01-01','2033-12-31','archived'),
 ('77810000-0000-0000-0000-000000000003','72000000-0000-0000-0000-000000000001','77000000-0000-0000-0000-000000000004','Other School Child',1,'2026-01-01','2026-12-31','draft');
insert into public.sections(id,organization_id,school_id,campus_id,academic_year_id,academic_term_id,grade_level_id,code,name,capacity,start_date,end_date,status)
values ('77820000-0000-0000-0000-000000000001','72000000-0000-0000-0000-000000000001','73000000-0000-0000-0000-000000000001','74000000-0000-0000-0000-000000000002','77700000-0000-0000-0000-000000000002','77710000-0000-0000-0000-000000000001','78000000-0000-0000-0000-000000000001','TERM-CHILD','Term Child',10,'2037-02-01','2037-03-31','inactive');
set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.update_academic_term('77810000-0000-0000-0000-000000000099','Missing',1::smallint,'2037-01-01','2037-12-31')$$,'P0002','academic term not found','term update rejects missing target deliberately');
reset role; update public.schools set status='inactive' where id='73000000-0000-0000-0000-000000000001'; set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.update_academic_term('77710000-0000-0000-0000-000000000001','Inactive School',1::smallint,'2037-01-01','2037-06-30')$$,'P0002','active academic-term organization and school are required','term update rejects inactive authoritative school');
reset role; update public.schools set status='active' where id='73000000-0000-0000-0000-000000000001'; update public.organizations set status='inactive' where id='72000000-0000-0000-0000-000000000001'; set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.update_academic_term('77710000-0000-0000-0000-000000000001','Inactive Org',1::smallint,'2037-01-01','2037-06-30')$$,'P0002','active academic-term organization and school are required','term update rejects inactive authoritative organization');
reset role; update public.organizations set status='active' where id='72000000-0000-0000-0000-000000000001'; set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.update_academic_term('77810000-0000-0000-0000-000000000001','Closed Parent',1::smallint,'2035-01-01','2035-12-31')$$,'22023','academic year status does not permit term editing','term update rejects closed parent year');
select throws_ok($$select public.update_academic_term('77810000-0000-0000-0000-000000000002','Archived Parent',1::smallint,'2033-01-01','2033-12-31')$$,'22023','academic year status does not permit term editing','term update rejects archived parent year');
select throws_ok($$select public.update_academic_term('77710000-0000-0000-0000-000000000001','Bad Order',1::smallint,'2037-06-30','2037-01-01')$$,'22023','academic term end date must not precede start date','term update rejects reversed dates');
select throws_ok($$select public.update_academic_term('77710000-0000-0000-0000-000000000001','Before Parent',1::smallint,'2036-12-31','2037-06-30')$$,'22023','academic term dates must be within academic year','term update rejects start before parent year');
select throws_ok($$select public.update_academic_term('77710000-0000-0000-0000-000000000001','After Parent',1::smallint,'2037-01-01','2038-01-01')$$,'22023','academic term dates must be within academic year','term update rejects end after parent year');
select throws_ok($$select public.update_academic_term('77710000-0000-0000-0000-000000000001','Bad Sequence',0::smallint,'2037-01-01','2037-06-30')$$,'22023','academic term sequence must be positive','term update rejects non-positive sequence');
select throws_ok($$select public.update_academic_term('77710000-0000-0000-0000-000000000001','Duplicate Sequence',2::smallint,'2037-01-01','2037-06-30')$$,'23505','academic term sequence already exists','term update rejects duplicate sequence');
select throws_ok($$select public.update_academic_term('77710000-0000-0000-0000-000000000001','  org ACTIVE term ',3::smallint,'2037-01-01','2037-06-30')$$,'23505','academic term normalized name already exists','term update rejects normalized name collision');
select throws_ok($$select public.update_academic_term('77710000-0000-0000-0000-000000000001','Exclude Child',3::smallint,'2037-03-01','2037-06-30')$$,'22023','academic term dates exclude non-archived sections','term update cannot exclude a linked non-archived section');
select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000008","role":"authenticated"}',true);
select throws_ok($$select public.update_academic_term('77710000-0000-0000-0000-000000000001','No Permission',3::smallint,'2037-01-01','2037-06-30')$$,'42501','academic_periods.manage permission is required','term update rejects missing permission');
select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000003","role":"authenticated"}',true);
select throws_ok($$select public.update_academic_term('77710000-0000-0000-0000-000000000001','Suspended',3::smallint,'2037-01-01','2037-06-30')$$,'42501','academic_periods.manage permission is required','term update rejects suspended membership');
select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000006","role":"authenticated"}',true);
select throws_ok($$select public.update_academic_term('77810000-0000-0000-0000-000000000003','Cross School',1::smallint,'2026-01-01','2026-12-31')$$,'42501','academic_periods.manage permission is required','school manager cannot update another school term');
select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.update_academic_term('77100000-0000-0000-0000-000000000005','Cross Tenant',1::smallint,'2026-01-01','2026-12-31')$$,'42501','academic_periods.manage permission is required','organization manager cannot update another tenant term');
reset role;
select ok((select name='Existing Term' and sequence=1 and organization_id='72000000-0000-0000-0000-000000000001' and academic_year_id='77700000-0000-0000-0000-000000000002' from public.academic_terms where id='77710000-0000-0000-0000-000000000001'),'denied term updates preserve fields and immutable scope');
select is((select count(*)::int from public.audit_log where action='academic_term.updated'),0,'denied term updates leave no audit rows');
select is((select count(*)::int from public.event_outbox where event_type='academic_term.updated'),0,'denied term updates leave no outbox events');
set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000006","role":"authenticated"}',true);
select lives_ok($$select public.update_academic_term('77710000-0000-0000-0000-000000000001',' School Updated ',3::smallint,'2037-01-01','2037-06-30')$$,'school manager updates a term in own school');
select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select lives_ok($$select public.update_academic_term('77710000-0000-0000-0000-000000000001','Org Updated',4::smallint,'2037-01-01','2037-06-30')$$,'organization manager updates a term within organization');
reset role;
select ok((select name='Org Updated' and sequence=4 and organization_id='72000000-0000-0000-0000-000000000001' and academic_year_id='77700000-0000-0000-0000-000000000002' and updated_by='71000000-0000-0000-0000-000000000001' from public.academic_terms where id='77710000-0000-0000-0000-000000000001'),'term update changes mutable fields, preserves scope, and attributes actor');
select is((select count(*)::int from public.audit_log where action='academic_term.updated' and entity_id='77710000-0000-0000-0000-000000000001'),2,'successful term updates write one attributed audit row each');
select is((select count(*)::int from public.event_outbox where event_type='academic_term.updated' and aggregate_id='77710000-0000-0000-0000-000000000001'),2,'successful term updates write one outbox event each');

insert into public.academic_years(id,organization_id,school_id,name,start_date,end_date,status) values
 ('77900000-0000-0000-0000-000000000001','72000000-0000-0000-0000-000000000001','73000000-0000-0000-0000-000000000001','Term Transition Active','2038-01-01','2038-12-31','active'),
 ('77900000-0000-0000-0000-000000000002','72000000-0000-0000-0000-000000000001','73000000-0000-0000-0000-000000000001','Term Transition Draft','2039-01-01','2039-12-31','draft'),
 ('77900000-0000-0000-0000-000000000003','72000000-0000-0000-0000-000000000001','73000000-0000-0000-0000-000000000001','Term Transition Archived','2040-01-01','2040-12-31','archived');
insert into public.academic_terms(id,organization_id,academic_year_id,name,sequence,start_date,end_date,status) values
 ('77910000-0000-0000-0000-000000000001','72000000-0000-0000-0000-000000000001','77900000-0000-0000-0000-000000000001','Legal Draft Active',1,'2038-01-01','2038-03-31','draft'),
 ('77910000-0000-0000-0000-000000000002','72000000-0000-0000-0000-000000000001','77900000-0000-0000-0000-000000000001','Legal Draft Archive',2,'2038-04-01','2038-06-30','draft'),
 ('77910000-0000-0000-0000-000000000003','72000000-0000-0000-0000-000000000001','77900000-0000-0000-0000-000000000001','Legal Active Close',3,'2038-07-01','2038-09-30','active'),
 ('77910000-0000-0000-0000-000000000004','72000000-0000-0000-0000-000000000001','77900000-0000-0000-0000-000000000001','Legal Closed Archive',4,'2038-10-01','2038-12-31','closed'),
 ('77910000-0000-0000-0000-000000000005','72000000-0000-0000-0000-000000000001','77900000-0000-0000-0000-000000000001','Terminal Archived',5,'2038-01-01','2038-01-31','archived'),
 ('77910000-0000-0000-0000-000000000006','72000000-0000-0000-0000-000000000001','77900000-0000-0000-0000-000000000001','Illegal Draft',6,'2038-02-01','2038-02-28','draft'),
 ('77910000-0000-0000-0000-000000000007','72000000-0000-0000-0000-000000000001','77900000-0000-0000-0000-000000000001','Active Child',7,'2038-03-01','2038-03-31','active'),
 ('77910000-0000-0000-0000-000000000008','72000000-0000-0000-0000-000000000001','77900000-0000-0000-0000-000000000002','Active Under Draft',1,'2039-01-01','2039-06-30','active'),
 ('77910000-0000-0000-0000-000000000009','72000000-0000-0000-0000-000000000001','77900000-0000-0000-0000-000000000003','Active Under Archived',1,'2040-01-01','2040-06-30','active');
insert into public.sections(id,organization_id,school_id,campus_id,academic_year_id,academic_term_id,grade_level_id,code,name,capacity,start_date,end_date,status)
values ('77920000-0000-0000-0000-000000000001','72000000-0000-0000-0000-000000000001','73000000-0000-0000-0000-000000000001','74000000-0000-0000-0000-000000000002','77900000-0000-0000-0000-000000000001','77910000-0000-0000-0000-000000000007','78000000-0000-0000-0000-000000000001','TERM-ACTIVE-CHILD','Active Term Child',10,'2038-03-01','2038-03-31','active');
set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.transition_academic_term_status('77910000-0000-0000-0000-000000000099','active')$$,'P0002','academic term not found','term transition rejects missing target deliberately');
reset role; update public.schools set status='inactive' where id='73000000-0000-0000-0000-000000000001'; set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.transition_academic_term_status('77910000-0000-0000-0000-000000000001','active')$$,'P0002','active academic-term organization and school are required','term transition rejects inactive authoritative school');
reset role; update public.schools set status='active' where id='73000000-0000-0000-0000-000000000001'; update public.organizations set status='inactive' where id='72000000-0000-0000-0000-000000000001'; set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.transition_academic_term_status('77910000-0000-0000-0000-000000000001','active')$$,'P0002','active academic-term organization and school are required','term transition rejects inactive authoritative organization');
reset role; update public.organizations set status='active' where id='72000000-0000-0000-0000-000000000001'; set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.transition_academic_term_status('77910000-0000-0000-0000-000000000006','closed')$$,'22023','illegal academic term status transition','draft term cannot transition directly to closed');
select throws_ok($$select public.transition_academic_term_status('77910000-0000-0000-0000-000000000003','archived')$$,'22023','illegal academic term status transition','active term cannot transition directly to archived');
select throws_ok($$select public.transition_academic_term_status('77910000-0000-0000-0000-000000000004','active')$$,'22023','illegal academic term status transition','closed term cannot reactivate');
select throws_ok($$select public.transition_academic_term_status('77910000-0000-0000-0000-000000000005','active')$$,'22023','illegal academic term status transition','archived term is terminal');
select throws_ok($$select public.transition_academic_term_status('77910000-0000-0000-0000-000000000006','draft')$$,'22023','illegal academic term status transition','term transition rejects a no-op');
select throws_ok($$select public.transition_academic_term_status('77910000-0000-0000-0000-000000000008','closed')$$,'22023','academic term transition is incompatible with academic year status','term cannot close while parent year remains draft');
select throws_ok($$select public.transition_academic_term_status('77910000-0000-0000-0000-000000000009','closed')$$,'22023','academic term transition is incompatible with academic year status','term cannot close under archived parent year');
select throws_ok($$select public.transition_academic_term_status('77910000-0000-0000-0000-000000000007','closed')$$,'22023','academic term has active sections','term cannot close while active linked sections exist');
select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000008","role":"authenticated"}',true);
select throws_ok($$select public.transition_academic_term_status('77910000-0000-0000-0000-000000000003','closed')$$,'42501','academic_periods.manage permission is required','term transition rejects missing permission');
select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000003","role":"authenticated"}',true);
select throws_ok($$select public.transition_academic_term_status('77910000-0000-0000-0000-000000000003','closed')$$,'42501','academic_periods.manage permission is required','term transition rejects suspended membership');
select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000006","role":"authenticated"}',true);
select throws_ok($$select public.transition_academic_term_status('77810000-0000-0000-0000-000000000003','active')$$,'42501','academic_periods.manage permission is required','school manager cannot transition another school term');
select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.transition_academic_term_status('77100000-0000-0000-0000-000000000005','closed')$$,'42501','academic_periods.manage permission is required','organization manager cannot transition another tenant term');
reset role;
select ok((select status='draft' from public.academic_terms where id='77910000-0000-0000-0000-000000000001') and (select status='active' from public.academic_terms where id='77910000-0000-0000-0000-000000000003'),'denied and illegal term transitions preserve status');
select is((select count(*)::int from public.audit_log where action='academic_term.status_changed'),0,'denied term transitions leave no audit rows');
select is((select count(*)::int from public.event_outbox where event_type='academic_term.status_changed'),0,'denied term transitions leave no outbox events');
set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000006","role":"authenticated"}',true);
select lives_ok($$select public.transition_academic_term_status('77910000-0000-0000-0000-000000000001','active')$$,'school manager performs legal draft to active transition');
select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select lives_ok($$select public.transition_academic_term_status('77910000-0000-0000-0000-000000000002','archived')$$,'organization manager performs legal draft to archived transition');
select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000006","role":"authenticated"}',true);
select lives_ok($$select public.transition_academic_term_status('77910000-0000-0000-0000-000000000003','closed')$$,'school manager performs legal active to closed transition');
select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select lives_ok($$select public.transition_academic_term_status('77910000-0000-0000-0000-000000000004','archived')$$,'organization manager performs legal closed to archived transition');
reset role;
select ok((select status='active' and organization_id='72000000-0000-0000-0000-000000000001' and academic_year_id='77900000-0000-0000-0000-000000000001' and updated_by='71000000-0000-0000-0000-000000000006' from public.academic_terms where id='77910000-0000-0000-0000-000000000001'),'draft to active preserves scope and attributes school manager');
select ok((select status='archived' and updated_by='71000000-0000-0000-0000-000000000001' from public.academic_terms where id='77910000-0000-0000-0000-000000000002'),'draft to archived attributes organization manager');
select ok((select status='closed' and updated_by='71000000-0000-0000-0000-000000000006' from public.academic_terms where id='77910000-0000-0000-0000-000000000003'),'active to closed attributes school manager');
select ok((select status='archived' and updated_by='71000000-0000-0000-0000-000000000001' from public.academic_terms where id='77910000-0000-0000-0000-000000000004'),'closed to archived attributes organization manager');
select is((select count(*)::int from public.audit_log where action='academic_term.status_changed' and entity_id in ('77910000-0000-0000-0000-000000000001','77910000-0000-0000-0000-000000000002','77910000-0000-0000-0000-000000000003','77910000-0000-0000-0000-000000000004')),4,'legal term transitions each write one audit row');
select is((select count(*)::int from public.event_outbox where event_type='academic_term.status_changed' and aggregate_id in ('77910000-0000-0000-0000-000000000001','77910000-0000-0000-0000-000000000002','77910000-0000-0000-0000-000000000003','77910000-0000-0000-0000-000000000004')),4,'legal term transitions each emit one outbox event');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000002","role":"authenticated"}',true);
select is((select count(*)::int from public.grade_levels),5,'campus role reads parent grade catalog including history');
select is((select count(*)::int from public.subjects),4,'campus role reads parent subject catalog including history');
select throws_ok($$select public.create_grade_level('73000000-0000-0000-0000-000000000001','G3','Grade 3',3::smallint)$$,'42501','school-scoped academic_structure.manage permission is required','campus role cannot mutate grade catalog');
select throws_ok($$select public.create_subject('73000000-0000-0000-0000-000000000001','SCI','Science')$$,'42501','school-scoped academic_structure.manage permission is required','campus role cannot mutate catalog');
select is((select count(*)::int from public.sections),6,'campus role sees own campus sections including history');

select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000003","role":"authenticated"}',true);
select is((select count(*)::int from public.sections),0,'suspended membership denied');
set local role anon; select throws_ok($$select * from public.sections$$,'42501','permission denied for table sections','anonymous denied');
reset role;

-- Complete read-RLS matrix. Prefix-scoped fixtures isolate these assertions from
-- earlier command tests while exercising organization, school, and campus scope.
insert into auth.users(id,instance_id,aud,role,email,encrypted_password,created_at,updated_at) values
 ('71f00000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','rls-target-1@test','',now(),now()),
 ('71f00000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','rls-target-2@test','',now(),now()),
 ('71f00000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000000','authenticated','authenticated','rls-target-3@test','',now(),now()),
 ('71f00000-0000-0000-0000-000000000004','00000000-0000-0000-0000-000000000000','authenticated','authenticated','rls-target-4@test','',now(),now()),
 ('71f00000-0000-0000-0000-000000000005','00000000-0000-0000-0000-000000000000','authenticated','authenticated','rls-target-5@test','',now(),now()),
 ('71f00000-0000-0000-0000-000000000006','00000000-0000-0000-0000-000000000000','authenticated','authenticated','rls-target-6@test','',now(),now());
insert into public.organization_memberships(id,organization_id,user_id,status,joined_at) values
 ('75f00000-0000-0000-0000-000000000001','72000000-0000-0000-0000-000000000001','71f00000-0000-0000-0000-000000000001','active',now()),
 ('75f00000-0000-0000-0000-000000000002','72000000-0000-0000-0000-000000000001','71f00000-0000-0000-0000-000000000002','active',now()),
 ('75f00000-0000-0000-0000-000000000003','72000000-0000-0000-0000-000000000001','71f00000-0000-0000-0000-000000000003','active',now()),
 ('75f00000-0000-0000-0000-000000000004','72000000-0000-0000-0000-000000000001','71f00000-0000-0000-0000-000000000004','active',now()),
 ('75f00000-0000-0000-0000-000000000005','72000000-0000-0000-0000-000000000001','71f00000-0000-0000-0000-000000000005','active',now()),
 ('75f00000-0000-0000-0000-000000000006','72000000-0000-0000-0000-000000000002','71f00000-0000-0000-0000-000000000006','active',now());
insert into public.staff_profiles(id,organization_id,organization_membership_id,school_id,campus_id,staff_number,employment_type) values
 ('7f500000-0000-0000-0000-000000000001','72000000-0000-0000-0000-000000000001','75f00000-0000-0000-0000-000000000001',null,null,'RLS-ORG','employee'),
 ('7f500000-0000-0000-0000-000000000002','72000000-0000-0000-0000-000000000001','75f00000-0000-0000-0000-000000000002','73000000-0000-0000-0000-000000000001',null,'RLS-SCHOOL','employee'),
 ('7f500000-0000-0000-0000-000000000003','72000000-0000-0000-0000-000000000001','75f00000-0000-0000-0000-000000000003','73000000-0000-0000-0000-000000000001','74000000-0000-0000-0000-000000000001','RLS-CAMPUS-1','employee'),
 ('7f500000-0000-0000-0000-000000000004','72000000-0000-0000-0000-000000000001','75f00000-0000-0000-0000-000000000004','73000000-0000-0000-0000-000000000001','74000000-0000-0000-0000-000000000002','RLS-CAMPUS-2','employee'),
 ('7f500000-0000-0000-0000-000000000005','72000000-0000-0000-0000-000000000001','75f00000-0000-0000-0000-000000000005','73000000-0000-0000-0000-000000000003','74000000-0000-0000-0000-000000000003','RLS-OTHER-SCHOOL','employee'),
 ('7f500000-0000-0000-0000-000000000006','72000000-0000-0000-0000-000000000002','75f00000-0000-0000-0000-000000000006','73000000-0000-0000-0000-000000000002','74000000-0000-0000-0000-000000000004','RLS-OTHER-TENANT','employee');
insert into public.buildings(id,organization_id,school_id,campus_id,code,name) values
 ('7f510000-0000-0000-0000-000000000001','72000000-0000-0000-0000-000000000001','73000000-0000-0000-0000-000000000001','74000000-0000-0000-0000-000000000001','RLS-1','RLS Campus 1'),
 ('7f510000-0000-0000-0000-000000000002','72000000-0000-0000-0000-000000000001','73000000-0000-0000-0000-000000000001','74000000-0000-0000-0000-000000000002','RLS-2','RLS Campus 2'),
 ('7f510000-0000-0000-0000-000000000003','72000000-0000-0000-0000-000000000001','73000000-0000-0000-0000-000000000003','74000000-0000-0000-0000-000000000003','RLS-3','RLS Other School'),
 ('7f510000-0000-0000-0000-000000000004','72000000-0000-0000-0000-000000000002','73000000-0000-0000-0000-000000000002','74000000-0000-0000-0000-000000000004','RLS-4','RLS Other Tenant');
insert into public.rooms(id,organization_id,school_id,campus_id,building_id,code,name,room_type,capacity) values
 ('7f520000-0000-0000-0000-000000000001','72000000-0000-0000-0000-000000000001','73000000-0000-0000-0000-000000000001','74000000-0000-0000-0000-000000000001','7f510000-0000-0000-0000-000000000001','RLS-R','RLS Room Campus 1','classroom',20),
 ('7f520000-0000-0000-0000-000000000002','72000000-0000-0000-0000-000000000001','73000000-0000-0000-0000-000000000001','74000000-0000-0000-0000-000000000002','7f510000-0000-0000-0000-000000000002','RLS-R','RLS Room Campus 2','classroom',20),
 ('7f520000-0000-0000-0000-000000000003','72000000-0000-0000-0000-000000000001','73000000-0000-0000-0000-000000000003','74000000-0000-0000-0000-000000000003','7f510000-0000-0000-0000-000000000003','RLS-R','RLS Room Other School','classroom',20),
 ('7f520000-0000-0000-0000-000000000004','72000000-0000-0000-0000-000000000002','73000000-0000-0000-0000-000000000002','74000000-0000-0000-0000-000000000004','7f510000-0000-0000-0000-000000000004','RLS-R','RLS Room Other Tenant','classroom',20);
insert into public.grade_levels(id,organization_id,school_id,code,name,sequence) values
 ('7f530000-0000-0000-0000-000000000001','72000000-0000-0000-0000-000000000001','73000000-0000-0000-0000-000000000001','RLS-G1','RLS Grade School 1',71),
 ('7f530000-0000-0000-0000-000000000002','72000000-0000-0000-0000-000000000001','73000000-0000-0000-0000-000000000003','RLS-G3','RLS Grade School 3',71),
 ('7f530000-0000-0000-0000-000000000003','72000000-0000-0000-0000-000000000002','73000000-0000-0000-0000-000000000002','RLS-G2','RLS Grade Tenant 2',71);
insert into public.subjects(id,organization_id,school_id,code,name) values
 ('7f540000-0000-0000-0000-000000000001','72000000-0000-0000-0000-000000000001','73000000-0000-0000-0000-000000000001','RLS-S1','RLS Subject School 1'),
 ('7f540000-0000-0000-0000-000000000002','72000000-0000-0000-0000-000000000001','73000000-0000-0000-0000-000000000003','RLS-S3','RLS Subject School 3'),
 ('7f540000-0000-0000-0000-000000000003','72000000-0000-0000-0000-000000000002','73000000-0000-0000-0000-000000000002','RLS-S2','RLS Subject Tenant 2');
insert into public.sections(id,organization_id,school_id,campus_id,academic_year_id,grade_level_id,code,name,capacity,start_date,end_date,status) values
 ('7f550000-0000-0000-0000-000000000001','72000000-0000-0000-0000-000000000001','73000000-0000-0000-0000-000000000001','74000000-0000-0000-0000-000000000001','77000000-0000-0000-0000-000000000001','7f530000-0000-0000-0000-000000000001','RLS-C1','RLS Section Campus 1',10,'2026-01-01','2026-12-31','inactive'),
 ('7f550000-0000-0000-0000-000000000002','72000000-0000-0000-0000-000000000001','73000000-0000-0000-0000-000000000001','74000000-0000-0000-0000-000000000002','77000000-0000-0000-0000-000000000001','7f530000-0000-0000-0000-000000000001','RLS-C2','RLS Section Campus 2',10,'2026-01-01','2026-12-31','inactive'),
 ('7f550000-0000-0000-0000-000000000003','72000000-0000-0000-0000-000000000001','73000000-0000-0000-0000-000000000003','74000000-0000-0000-0000-000000000003','77000000-0000-0000-0000-000000000004','7f530000-0000-0000-0000-000000000002','RLS-C3','RLS Section Other School',10,'2026-01-01','2026-12-31','inactive'),
 ('7f550000-0000-0000-0000-000000000004','72000000-0000-0000-0000-000000000002','73000000-0000-0000-0000-000000000002','74000000-0000-0000-0000-000000000004','77000000-0000-0000-0000-000000000003','7f530000-0000-0000-0000-000000000003','RLS-C4','RLS Section Other Tenant',10,'2026-01-01','2026-12-31','inactive');
insert into public.role_permissions(organization_id,role_id,permission_id)
select '72000000-0000-0000-0000-000000000001','76000000-0000-0000-0000-000000000004',id from public.permissions where code='academic_structure.view';
insert into public.role_assignments(organization_id,organization_membership_id,role_id,school_id,campus_id)
values ('72000000-0000-0000-0000-000000000001','75000000-0000-0000-0000-000000000006','76000000-0000-0000-0000-000000000001',null,null);
update public.organization_memberships
set status='left',left_at=now()
where id='75000000-0000-0000-0000-000000000006';

set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select is((select array_agg(staff_number order by staff_number) from public.staff_profiles where staff_number like 'RLS-%'),array['RLS-CAMPUS-1','RLS-CAMPUS-2','RLS-ORG','RLS-OTHER-SCHOOL','RLS-SCHOOL']::text[],'org scope reads all in-tenant staff homes and denies other tenant');
select is((select count(*)::int from public.buildings where code like 'RLS-%'),3,'org scope reads all in-tenant buildings only');
select is((select count(*)::int from public.rooms where code='RLS-R'),3,'org scope reads all in-tenant rooms only');
select is((select count(*)::int from public.grade_levels where code like 'RLS-G%'),2,'org scope reads all in-tenant grade catalogs only');
select is((select count(*)::int from public.sections where code like 'RLS-C%'),3,'org scope reads all in-tenant sections only');
select is((select count(*)::int from public.subjects where code like 'RLS-S%'),2,'org scope reads all in-tenant subject catalogs only');

select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000006","role":"authenticated"}',true);
select is((select array_agg(staff_number order by staff_number) from public.staff_profiles where staff_number like 'RLS-%'),array['RLS-CAMPUS-1','RLS-CAMPUS-2','RLS-SCHOOL']::text[],'school scope reads school and child-campus staff homes only');
select is((select count(*)::int from public.buildings where code like 'RLS-%'),2,'school scope reads both school-campus buildings only');
select is((select count(*)::int from public.rooms where code='RLS-R'),2,'school scope reads both school-campus rooms only');
select is((select count(*)::int from public.grade_levels where code like 'RLS-G%'),1,'school scope reads own grade catalog only');
select is((select count(*)::int from public.sections where code like 'RLS-C%'),2,'school scope reads both school-campus sections only');
select is((select count(*)::int from public.subjects where code like 'RLS-S%'),1,'school scope reads own subject catalog only');

select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000007","role":"authenticated"}',true);
select is((select array_agg(staff_number order by staff_number) from public.staff_profiles where staff_number like 'RLS-%'),array['RLS-CAMPUS-1']::text[],'campus scope reads only its campus-home staff profile');
select is((select count(*)::int from public.buildings where code like 'RLS-%'),1,'campus scope reads own-campus building only');
select is((select count(*)::int from public.rooms where code='RLS-R'),1,'campus scope reads own-campus room only');
select is((select count(*)::int from public.grade_levels where code like 'RLS-G%'),1,'campus scope reads parent-school grade catalog but denies other school');
select is((select count(*)::int from public.sections where code like 'RLS-C%'),1,'campus scope reads own-campus section but denies other campus');
select is((select count(*)::int from public.subjects where code like 'RLS-S%'),1,'campus scope reads parent-school subject catalog but denies other school');

select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000008","role":"authenticated"}',true);
select is((select count(*)::int from public.staff_profiles where staff_number like 'RLS-%'),0,'active missing-permission actor reads no staff profiles');
select is((select count(*)::int from public.buildings where code like 'RLS-%'),0,'active missing-permission actor reads no buildings');
select is((select count(*)::int from public.rooms where code='RLS-R'),0,'active missing-permission actor reads no rooms');
select is((select count(*)::int from public.grade_levels where code like 'RLS-G%'),0,'active missing-permission actor reads no grade levels');
select is((select count(*)::int from public.sections where code like 'RLS-C%'),0,'active missing-permission actor reads no sections');
select is((select count(*)::int from public.subjects where code like 'RLS-S%'),0,'active missing-permission actor reads no subjects');

select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000003","role":"authenticated"}',true);
select is((select count(*)::int from public.staff_profiles where staff_number like 'RLS-%'),0,'suspended actor reads no staff profiles');
select is((select count(*)::int from public.buildings where code like 'RLS-%'),0,'suspended actor reads no buildings');
select is((select count(*)::int from public.rooms where code='RLS-R'),0,'suspended actor reads no rooms');
select is((select count(*)::int from public.grade_levels where code like 'RLS-G%'),0,'suspended actor reads no grade levels');
select is((select count(*)::int from public.sections where code like 'RLS-C%'),0,'suspended actor reads no sections');
select is((select count(*)::int from public.subjects where code like 'RLS-S%'),0,'suspended actor reads no subjects');

select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000005","role":"authenticated"}',true);
select is((select count(*)::int from public.staff_profiles where staff_number like 'RLS-%'),0,'left actor reads no staff profiles');
select is((select count(*)::int from public.buildings where code like 'RLS-%'),0,'left actor reads no buildings');
select is((select count(*)::int from public.rooms where code='RLS-R'),0,'left actor reads no rooms');
select is((select count(*)::int from public.grade_levels where code like 'RLS-G%'),0,'left actor reads no grade levels');
select is((select count(*)::int from public.sections where code like 'RLS-C%'),0,'left actor reads no sections');
select is((select count(*)::int from public.subjects where code like 'RLS-S%'),0,'left actor reads no subjects');

set local role anon;
select throws_ok($$select * from public.staff_profiles$$,'42501','permission denied for table staff_profiles','anonymous cannot read staff profiles');
select throws_ok($$select * from public.buildings$$,'42501','permission denied for table buildings','anonymous cannot read buildings');
select throws_ok($$select * from public.rooms$$,'42501','permission denied for table rooms','anonymous cannot read rooms');
select throws_ok($$select * from public.grade_levels$$,'42501','permission denied for table grade_levels','anonymous cannot read grade levels');
select throws_ok($$select * from public.sections$$,'42501','permission denied for table sections','anonymous cannot read sections');
select throws_ok($$select * from public.subjects$$,'42501','permission denied for table subjects','anonymous cannot read subjects');
reset role;

-- Attribution and tenant spoof attempts fail at function resolution because those
-- names are intentionally absent from every public command signature.
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.create_building(organization_id=>'72000000-0000-0000-0000-000000000002',campus_id=>'74000000-0000-0000-0000-000000000001',code=>'SPOOF-ORG',name=>'Spoof Org')$$,'42883',null,'organization_id named-argument spoof is not accepted');
select throws_ok($$select public.update_building(id=>'7f510000-0000-0000-0000-000000000001',code=>'RLS-1',name=>'Spoof Actor',status=>'active',actor_user_id=>'71000000-0000-0000-0000-000000000009')$$,'42883',null,'actor_user_id named-argument spoof is not accepted');
reset role;

-- Remaining command-adversarial gaps: building, room, grade, and subject. Every
-- referenced parent is valid so failures exercise RBAC rather than parent/FK checks.
create temporary table command_denial_baseline(event_type text primary key,audit_count bigint,outbox_count bigint) on commit drop;
insert into command_denial_baseline
select event_type,
 (select count(*) from public.audit_log where action=event_type),
 (select count(*) from public.event_outbox where public.event_outbox.event_type=e.event_type)
from (values ('building.created'),('room.created'),('grade_level.created'),('subject.created')) e(event_type);

set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000008","role":"authenticated"}',true);
select throws_ok($$select public.create_building('74000000-0000-0000-0000-000000000001','ADV-B-NP','Denied')$$,'42501','academic_structure.manage permission is required','building create denies active missing-permission actor');
select throws_ok($$select public.create_room('7f510000-0000-0000-0000-000000000001','ADV-R-NP','Denied','classroom',10)$$,'42501','academic_structure.manage permission is required','room create denies active missing-permission actor');
select throws_ok($$select public.create_grade_level('73000000-0000-0000-0000-000000000001','ADV-G-NP','Denied',81::smallint)$$,'42501','school-scoped academic_structure.manage permission is required','grade create denies active missing-permission actor');
select throws_ok($$select public.create_subject('73000000-0000-0000-0000-000000000001','ADV-S-NP','Denied')$$,'42501','school-scoped academic_structure.manage permission is required','subject create denies active missing-permission actor');

select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000003","role":"authenticated"}',true);
select throws_ok($$select public.create_building('74000000-0000-0000-0000-000000000001','ADV-B-IN','Denied')$$,'42501','academic_structure.manage permission is required','building create denies suspended membership');
select throws_ok($$select public.create_room('7f510000-0000-0000-0000-000000000001','ADV-R-IN','Denied','classroom',10)$$,'42501','academic_structure.manage permission is required','room create denies suspended membership');
select throws_ok($$select public.create_grade_level('73000000-0000-0000-0000-000000000001','ADV-G-IN','Denied',82::smallint)$$,'42501','school-scoped academic_structure.manage permission is required','grade create denies suspended membership');
select throws_ok($$select public.create_subject('73000000-0000-0000-0000-000000000001','ADV-S-IN','Denied')$$,'42501','school-scoped academic_structure.manage permission is required','subject create denies suspended membership');

select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000002","role":"authenticated"}',true);
select throws_ok($$select public.create_building('74000000-0000-0000-0000-000000000002','ADV-B-XC','Denied')$$,'42501','academic_structure.manage permission is required','campus actor cannot create building at other campus');
select throws_ok($$select public.create_room('7f510000-0000-0000-0000-000000000002','ADV-R-XC','Denied','classroom',10)$$,'42501','academic_structure.manage permission is required','campus actor cannot create room at other campus');
select throws_ok($$select public.create_grade_level('73000000-0000-0000-0000-000000000001','ADV-G-XC','Denied',83::smallint)$$,'42501','school-scoped academic_structure.manage permission is required','campus actor cannot mutate parent-school grade catalog');
select throws_ok($$select public.create_subject('73000000-0000-0000-0000-000000000001','ADV-S-XC','Denied')$$,'42501','school-scoped academic_structure.manage permission is required','campus actor cannot mutate parent-school subject catalog');

select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.create_building('74000000-0000-0000-0000-000000000004','ADV-B-XT','Denied')$$,'42501','academic_structure.manage permission is required','organization actor cannot create building cross-tenant');
select throws_ok($$select public.create_room('7f510000-0000-0000-0000-000000000004','ADV-R-XT','Denied','classroom',10)$$,'42501','academic_structure.manage permission is required','organization actor cannot create room cross-tenant');
select throws_ok($$select public.create_grade_level('73000000-0000-0000-0000-000000000002','ADV-G-XT','Denied',84::smallint)$$,'42501','school-scoped academic_structure.manage permission is required','organization actor cannot create grade cross-tenant');
select throws_ok($$select public.create_subject('73000000-0000-0000-0000-000000000002','ADV-S-XT','Denied')$$,'42501','school-scoped academic_structure.manage permission is required','organization actor cannot create subject cross-tenant');
reset role;

select is((select count(*)::int from public.buildings where code like 'ADV-B-%'),0,'denied building commands create no domain rows');
select ok((select audit_count=(select count(*) from public.audit_log where action='building.created') and outbox_count=(select count(*) from public.event_outbox where event_type='building.created') from command_denial_baseline where event_type='building.created'),'denied building commands create no audit/outbox rows');
select is((select count(*)::int from public.rooms where code like 'ADV-R-%'),0,'denied room commands create no domain rows');
select ok((select audit_count=(select count(*) from public.audit_log where action='room.created') and outbox_count=(select count(*) from public.event_outbox where event_type='room.created') from command_denial_baseline where event_type='room.created'),'denied room commands create no audit/outbox rows');
select is((select count(*)::int from public.grade_levels where code like 'ADV-G-%'),0,'denied grade commands create no domain rows');
select ok((select audit_count=(select count(*) from public.audit_log where action='grade_level.created') and outbox_count=(select count(*) from public.event_outbox where event_type='grade_level.created') from command_denial_baseline where event_type='grade_level.created'),'denied grade commands create no audit/outbox rows');
select is((select count(*)::int from public.subjects where code like 'ADV-S-%'),0,'denied subject commands create no domain rows');
select ok((select audit_count=(select count(*) from public.audit_log where action='subject.created') and outbox_count=(select count(*) from public.event_outbox where event_type='subject.created') from command_denial_baseline where event_type='subject.created'),'denied subject commands create no audit/outbox rows');

set local role authenticated; select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000002","role":"authenticated"}',true);
select lives_ok($$select public.create_building('74000000-0000-0000-0000-000000000001','ADV-B-OK','Permitted Building')$$,'campus-scoped manager creates building in own campus');
select lives_ok($$select public.update_building((select id from public.buildings where code='ADV-B-OK'),'ADV-B-OK','Permitted Building Updated','inactive')$$,'campus-scoped manager updates building in own campus');
select lives_ok($$select public.archive_building((select id from public.buildings where code='ADV-B-OK'))$$,'campus-scoped manager archives childless building in own campus');
select lives_ok($$select public.create_room('7f510000-0000-0000-0000-000000000001','ADV-R-OK','Permitted Room','classroom',10)$$,'campus-scoped manager creates room in own campus');
select lives_ok($$select public.update_room((select id from public.rooms where code='ADV-R-OK'),'ADV-R-OK','Permitted Room Updated','laboratory',12,'inactive')$$,'campus-scoped manager updates room in own campus');
select lives_ok($$select public.archive_room((select id from public.rooms where code='ADV-R-OK'))$$,'campus-scoped manager archives unused room in own campus');
select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000006","role":"authenticated"}',true);
select lives_ok($$select public.create_grade_level('73000000-0000-0000-0000-000000000001','ADV-G-OK','Permitted Grade',85::smallint)$$,'school-scoped manager creates grade in own school');
select lives_ok($$select public.update_grade_level((select id from public.grade_levels where code='ADV-G-OK'),'ADV-G-OK','Permitted Grade Updated',85::smallint,'inactive')$$,'school-scoped manager updates grade in own school');
select lives_ok($$select public.archive_grade_level((select id from public.grade_levels where code='ADV-G-OK'))$$,'school-scoped manager archives unused grade in own school');
select lives_ok($$select public.create_subject('73000000-0000-0000-0000-000000000001','ADV-S-OK','Permitted Subject')$$,'school-scoped manager creates subject in own school');
select lives_ok($$select public.update_subject((select id from public.subjects where code='ADV-S-OK'),'ADV-S-OK','Permitted Subject Updated',null,'inactive')$$,'school-scoped manager updates subject in own school');
select lives_ok($$select public.archive_subject((select id from public.subjects where code='ADV-S-OK'))$$,'school-scoped manager archives subject in own school');
reset role;

-- Archived is historical and terminal: it is reachable only through the dedicated
-- archive/status-transition commands, never as caller-selected initial state.
create temporary table initial_status_side_effect_baseline(audit_count bigint,outbox_count bigint) on commit drop;
insert into initial_status_side_effect_baseline
select count(*), (select count(*) from public.event_outbox) from public.audit_log;

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.create_building('74000000-0000-0000-0000-000000000001','INIT-ARCH-B','Initial Archived Building',null,'archived')$$,'22023','building initial status cannot be archived','building cannot be created archived');
select throws_ok($$select public.create_room('7f510000-0000-0000-0000-000000000001','INIT-ARCH-R','Initial Archived Room','classroom',10,'archived')$$,'22023','room initial status cannot be archived','room cannot be created archived');
select throws_ok($$select public.create_grade_level('73000000-0000-0000-0000-000000000001','INIT-ARCH-G','Initial Archived Grade',99::smallint,null,null,'archived')$$,'22023','grade level initial status cannot be archived','grade level cannot be created archived');
select throws_ok($$select public.create_subject('73000000-0000-0000-0000-000000000001','INIT-ARCH-S','Initial Archived Subject',null,'archived')$$,'22023','subject initial status cannot be archived','subject cannot be created archived');
select throws_ok($$select public.create_staff_profile('75000000-0000-0000-0000-000000000009',null,null,'INIT-ARCH-P','employee',null,null,null,'archived')$$,'22023','staff profile initial status cannot be archived','staff profile cannot be created archived');
select throws_ok($$select public.create_section('74000000-0000-0000-0000-000000000001','77000000-0000-0000-0000-000000000001',null,'78000000-0000-0000-0000-000000000001',null,'INIT-ARCH-C','Initial Archived Section',10,'2026-01-01','2026-12-31','archived')$$,'22023','section initial status cannot be archived','section cannot be created archived');
select throws_ok($$select public.create_academic_year('73000000-0000-0000-0000-000000000001','Initial Closed Year','2098-01-01','2098-12-31','closed')$$,'22023','academic year initial status must be draft or active','academic year cannot be created closed');
select throws_ok($$select public.create_academic_year('73000000-0000-0000-0000-000000000001','Initial Archived Year','2099-01-01','2099-12-31','archived')$$,'22023','academic year initial status must be draft or active','academic year cannot be created archived');
select throws_ok($$select public.create_academic_term('77700000-0000-0000-0000-000000000002','Initial Closed Term',98::smallint,'2037-07-01','2037-08-01','closed')$$,'22023','academic term initial status is incompatible with academic year','academic term cannot be created closed');
select throws_ok($$select public.create_academic_term('77700000-0000-0000-0000-000000000002','Initial Archived Term',99::smallint,'2037-08-02','2037-09-01','archived')$$,'22023','academic term initial status is incompatible with academic year','academic term cannot be created archived');
reset role;

select is((select count(*)::int from public.buildings where code='INIT-ARCH-B'),0,'rejected archived building create leaves no domain row');
select is((select count(*)::int from public.rooms where code='INIT-ARCH-R'),0,'rejected archived room create leaves no domain row');
select is((select count(*)::int from public.grade_levels where code='INIT-ARCH-G'),0,'rejected archived grade create leaves no domain row');
select is((select count(*)::int from public.subjects where code='INIT-ARCH-S'),0,'rejected archived subject create leaves no domain row');
select is((select count(*)::int from public.staff_profiles where staff_number='INIT-ARCH-P'),0,'rejected archived staff create leaves no domain row');
select is((select count(*)::int from public.sections where code='INIT-ARCH-C'),0,'rejected archived section create leaves no domain row');
select is((select count(*)::int from public.academic_years where name in ('Initial Closed Year','Initial Archived Year')),0,'rejected invalid academic-year initial states leave no domain rows');
select is((select count(*)::int from public.academic_terms where name in ('Initial Closed Term','Initial Archived Term')),0,'rejected invalid academic-term initial states leave no domain rows');
select ok((select audit_count=(select count(*) from public.audit_log) from initial_status_side_effect_baseline),'rejected initial lifecycle states create no audit rows');
select ok((select outbox_count=(select count(*) from public.event_outbox) from initial_status_side_effect_baseline),'rejected initial lifecycle states create no outbox rows');

-- Test-only trigger failures prove statement-level atomic rollback. Both trigger
-- functions and triggers are transaction-scoped because this pgTAP file rolls back.
insert into public.buildings(id,organization_id,school_id,campus_id,code,name,status) values
 ('7fa00000-0000-0000-0000-000000000001','72000000-0000-0000-0000-000000000001','73000000-0000-0000-0000-000000000001','74000000-0000-0000-0000-000000000001','ROLL-AUDIT','Audit Rollback Baseline','active'),
 ('7fa00000-0000-0000-0000-000000000002','72000000-0000-0000-0000-000000000001','73000000-0000-0000-0000-000000000001','74000000-0000-0000-0000-000000000001','ROLL-OUTBOX','Outbox Rollback Baseline','active');

create function pg_temp.fail_academic_audit_insert() returns trigger
language plpgsql as $$
begin
 raise exception using errcode='P9001',message='induced academic audit insertion failure';
end
$$;
create trigger test_fail_academic_audit_insert
before insert on public.audit_log
for each row execute function pg_temp.fail_academic_audit_insert();
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.update_building('7fa00000-0000-0000-0000-000000000001','ROLL-AUDIT','Audit Mutation Must Roll Back','active')$$,'P9001','induced academic audit insertion failure','induced audit insertion failure escapes with exact error');
reset role;
select is((select name from public.buildings where id='7fa00000-0000-0000-0000-000000000001'),'Audit Rollback Baseline','audit insertion failure rolls back the domain mutation');
select is((select count(*)::int from public.audit_log where entity_id='7fa00000-0000-0000-0000-000000000001' and action='building.updated'),0,'audit insertion failure leaves no correlated audit row');
select is((select count(*)::int from public.event_outbox where aggregate_id='7fa00000-0000-0000-0000-000000000001' and event_type='building.updated'),0,'audit insertion failure leaves no correlated outbox row');
drop trigger test_fail_academic_audit_insert on public.audit_log;

create function pg_temp.fail_academic_outbox_insert() returns trigger
language plpgsql as $$
begin
 raise exception using errcode='P9002',message='induced academic outbox insertion failure';
end
$$;
create trigger test_fail_academic_outbox_insert
before insert on public.event_outbox
for each row execute function pg_temp.fail_academic_outbox_insert();
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.update_building('7fa00000-0000-0000-0000-000000000002','ROLL-OUTBOX','Outbox Mutation Must Roll Back','active')$$,'P9002','induced academic outbox insertion failure','induced outbox insertion failure escapes with exact error');
reset role;
select is((select name from public.buildings where id='7fa00000-0000-0000-0000-000000000002'),'Outbox Rollback Baseline','outbox insertion failure rolls back the domain mutation');
select is((select count(*)::int from public.audit_log where entity_id='7fa00000-0000-0000-0000-000000000002' and action='building.updated'),0,'outbox insertion failure rolls back the correlated audit row');
select is((select count(*)::int from public.event_outbox where aggregate_id='7fa00000-0000-0000-0000-000000000002' and event_type='building.updated'),0,'outbox insertion failure leaves no correlated outbox row');
drop trigger test_fail_academic_outbox_insert on public.event_outbox;

create temporary table expected_academic_events(event_type text primary key,aggregate_type text not null) on commit drop;
insert into expected_academic_events values
 ('staff_profile.created','staff_profile'),('staff_profile.updated','staff_profile'),('staff_profile.archived','staff_profile'),
 ('building.created','building'),('building.updated','building'),('building.archived','building'),
 ('room.created','room'),('room.updated','room'),('room.archived','room'),
 ('grade_level.created','grade_level'),('grade_level.updated','grade_level'),('grade_level.archived','grade_level'),
 ('subject.created','subject'),('subject.updated','subject'),('subject.archived','subject'),
 ('section.created','section'),('section.updated','section'),('section.archived','section'),
 ('academic_year.created','academic_year'),('academic_year.updated','academic_year'),('academic_year.status_changed','academic_year'),
 ('academic_term.created','academic_term'),('academic_term.updated','academic_term'),('academic_term.status_changed','academic_term');
select ok(
 exists(select 1 from public.audit_log a where a.action=x.event_type and a.entity_type=x.aggregate_type)
 and not exists(
  select 1 from public.audit_log a
  left join public.event_outbox e on e.command_id=a.command_id
  cross join lateral (select coalesce(a.after_data,a.before_data,'{}'::jsonb) row_data) d
  where a.action=x.event_type and (
   a.command_id is null or e.command_id is null or e.event_type<>x.event_type or e.aggregate_type<>x.aggregate_type
   or e.aggregate_id<>a.entity_id or e.organization_id<>a.organization_id
   or e.payload->>'command_id'<>a.command_id::text or e.payload->>'actor_user_id'<>a.actor_user_id::text
   or e.payload->>'organization_id'<>a.organization_id::text or e.payload->>'entity_id'<>a.entity_id::text
   or e.payload->>'aggregate_id'<>a.entity_id::text or jsonb_typeof(e.payload->'changed_fields')<>'array'
   or e.payload->>'school_id' is distinct from coalesce(d.row_data->>'school_id',(select y.school_id::text from public.academic_years y where y.id=coalesce((d.row_data->>'academic_year_id')::uuid,case when x.aggregate_type='academic_year' then a.entity_id end)))
   or e.payload->>'campus_id' is distinct from d.row_data->>'campus_id'
   or e.payload->>'academic_year_id' is distinct from coalesce(d.row_data->>'academic_year_id',case when x.aggregate_type='academic_year' then a.entity_id::text end)
   or e.payload->>'academic_term_id' is distinct from coalesce(d.row_data->>'academic_term_id',case when x.aggregate_type='academic_term' then a.entity_id::text end)
   or (select count(*) from public.event_outbox one_e where one_e.command_id=a.command_id)<>1
  )
 ),
 'event contract: '||x.event_type
) from expected_academic_events x order by x.event_type;
select ok(not exists(select 1 from public.event_outbox e join expected_academic_events x on x.event_type=e.event_type where (select count(*) from public.audit_log a where a.command_id=e.command_id)<>1),'every academic outbox event has exactly one correlated audit row');
select ok(not exists(select 1 from public.event_outbox e join expected_academic_events x on x.event_type=e.event_type where e.payload ?| array['before_data','after_data','staff_number','employment_type','job_title','department']),'outbox payloads exclude full snapshots and sensitive staff fields');
select ok((select count(*)>=5 from public.audit_log where actor_user_id='71000000-0000-0000-0000-000000000001'),'important writes audited');
select ok((select count(*)>=5 from public.event_outbox where payload->>'actor_user_id'='71000000-0000-0000-0000-000000000001'),'important writes emit outbox events');
select is((select count(*)::int from pg_constraint c where c.contype='f' and c.conrelid in ('public.staff_profiles'::regclass,'public.buildings'::regclass,'public.rooms'::regclass,'public.grade_levels'::regclass,'public.sections'::regclass,'public.subjects'::regclass) and not exists(select 1 from pg_index i where i.indrelid=c.conrelid and array(select i.indkey[x] from generate_series(0,cardinality(c.conkey)-1) x)=c.conkey)),0,'every foreign key has a leading index');

select * from finish(); rollback;
