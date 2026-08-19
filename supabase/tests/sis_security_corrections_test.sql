begin;
create extension if not exists pgtap with schema extensions;
select plan(27);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, created_at, updated_at)
values
  ('41000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'sis-editor@example.test', '', now(), now()),
  ('42000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'sis-archiver@example.test', '', now(), now()),
  ('43000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'spoofed-actor@example.test', '', now(), now());

insert into public.organizations (id, name, slug)
values ('e0000000-0000-0000-0000-000000000001', 'SIS Security Tenant', 'sis-security-tenant');
insert into public.schools (id, organization_id, name, code)
values ('e1000000-0000-0000-0000-000000000001', 'e0000000-0000-0000-0000-000000000001', 'Security School', 'SEC');
insert into public.campuses (id, organization_id, school_id, name, code)
values (
  'e2000000-0000-0000-0000-000000000001',
  'e0000000-0000-0000-0000-000000000001',
  'e1000000-0000-0000-0000-000000000001',
  'Security Campus',
  'MAIN'
);

insert into public.organization_memberships (id, organization_id, user_id, status, joined_at)
values
  ('e3000000-0000-0000-0000-000000000001', 'e0000000-0000-0000-0000-000000000001', '41000000-0000-0000-0000-000000000001', 'active', now()),
  ('e3000000-0000-0000-0000-000000000002', 'e0000000-0000-0000-0000-000000000001', '42000000-0000-0000-0000-000000000002', 'active', now());
insert into public.roles (id, organization_id, code, name)
values
  ('e4000000-0000-0000-0000-000000000001', 'e0000000-0000-0000-0000-000000000001', 'SIS_EDITOR', 'SIS Editor'),
  ('e4000000-0000-0000-0000-000000000002', 'e0000000-0000-0000-0000-000000000001', 'SIS_ARCHIVER', 'SIS Archiver');
insert into public.role_permissions (organization_id, role_id, permission_id)
select 'e0000000-0000-0000-0000-000000000001', 'e4000000-0000-0000-0000-000000000001', id
from public.permissions
where code in ('students.view', 'students.edit');
insert into public.role_permissions (organization_id, role_id, permission_id)
select 'e0000000-0000-0000-0000-000000000001', 'e4000000-0000-0000-0000-000000000002', id
from public.permissions
where code in ('students.view', 'students.archive');
insert into public.role_assignments (
  organization_id, organization_membership_id, role_id, school_id, campus_id
) values
  (
    'e0000000-0000-0000-0000-000000000001',
    'e3000000-0000-0000-0000-000000000001',
    'e4000000-0000-0000-0000-000000000001',
    'e1000000-0000-0000-0000-000000000001',
    'e2000000-0000-0000-0000-000000000001'
  ),
  (
    'e0000000-0000-0000-0000-000000000001',
    'e3000000-0000-0000-0000-000000000002',
    'e4000000-0000-0000-0000-000000000002',
    'e1000000-0000-0000-0000-000000000001',
    'e2000000-0000-0000-0000-000000000001'
  );

insert into public.students (
  id,
  organization_id,
  school_id,
  campus_id,
  student_number,
  first_name,
  last_name,
  date_of_birth,
  created_by,
  updated_at
) values (
  'e5000000-0000-0000-0000-000000000001',
  'e0000000-0000-0000-0000-000000000001',
  'e1000000-0000-0000-0000-000000000001',
  'e2000000-0000-0000-0000-000000000001',
  'SEC-001',
  'Secure',
  'Student',
  '2014-01-01',
  '41000000-0000-0000-0000-000000000001',
  '2026-01-01 00:00:00+00'
);

select ok(not has_table_privilege('authenticated', 'public.students', 'INSERT'), 'authenticated cannot insert students');
select ok(not has_table_privilege('authenticated', 'public.students', 'UPDATE'), 'authenticated cannot update students');
select ok(not has_table_privilege('authenticated', 'public.guardians', 'INSERT'), 'authenticated cannot insert guardians');
select ok(not has_table_privilege('authenticated', 'public.guardians', 'UPDATE'), 'authenticated cannot update guardians');
select ok(not has_table_privilege('authenticated', 'public.student_guardians', 'INSERT'), 'authenticated cannot insert student guardians');
select ok(not has_table_privilege('authenticated', 'public.student_guardians', 'UPDATE'), 'authenticated cannot update student guardians');
select ok(not has_table_privilege('authenticated', 'public.student_identifiers', 'INSERT'), 'authenticated cannot insert identifiers');
select ok(not has_table_privilege('authenticated', 'public.student_identifiers', 'UPDATE'), 'authenticated cannot update identifiers');
select ok(not has_table_privilege('authenticated', 'public.student_addresses', 'INSERT'), 'authenticated cannot insert addresses');
select ok(not has_table_privilege('authenticated', 'public.student_addresses', 'UPDATE'), 'authenticated cannot update addresses');
select ok(not has_table_privilege('authenticated', 'public.student_emergency_contacts', 'INSERT'), 'authenticated cannot insert emergency contacts');
select ok(not has_table_privilege('authenticated', 'public.student_emergency_contacts', 'UPDATE'), 'authenticated cannot update emergency contacts');
select ok(not has_table_privilege('authenticated', 'public.student_documents', 'INSERT'), 'authenticated cannot insert documents');
select ok(not has_table_privilege('authenticated', 'public.student_documents', 'UPDATE'), 'authenticated cannot update documents');
select ok(
  has_function_privilege('authenticated', 'public.archive_student(uuid,text)', 'EXECUTE'),
  'authenticated can execute the public archive RPC wrapper'
);
select ok(
  has_function_privilege('service_role', 'public.archive_student(uuid,text)', 'EXECUTE'),
  'service role can execute the public archive RPC wrapper'
);
select ok(
  not has_function_privilege('anon', 'public.archive_student(uuid,text)', 'EXECUTE'),
  'anonymous cannot execute the public archive RPC wrapper'
);

set local role anon;
select throws_ok(
  $$select public.archive_student('e5000000-0000-0000-0000-000000000001', 'anonymous attempted archive')$$,
  '42501',
  'permission denied for function archive_student',
  'anonymous archive RPC execution is denied'
);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"41000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
select throws_ok(
  $$insert into public.students (organization_id, school_id, campus_id, student_number, first_name, last_name, date_of_birth, created_by) values ('e0000000-0000-0000-0000-000000000001', 'e1000000-0000-0000-0000-000000000001', 'e2000000-0000-0000-0000-000000000001', 'SEC-002', 'Spoofed', 'Creator', '2014-02-01', '43000000-0000-0000-0000-000000000003')$$,
  '42501',
  'permission denied for table students',
  'direct insert cannot spoof created_by'
);
select throws_ok(
  $$update public.students set updated_by = '43000000-0000-0000-0000-000000000003' where id = 'e5000000-0000-0000-0000-000000000001'$$,
  '42501',
  'permission denied for table students',
  'direct update cannot spoof updated_by'
);
select throws_ok(
  $$select public.archive_student('e5000000-0000-0000-0000-000000000001', 'editor attempted archive')$$,
  '42501',
  'students.archive permission is required',
  'students.edit alone cannot archive a student'
);

select set_config('request.jwt.claims', '{"sub":"42000000-0000-0000-0000-000000000002","role":"authenticated"}', true);
select throws_ok(
  $$select public.archive_student('e5000000-0000-0000-0000-000000000001', '   ')$$,
  '22023',
  'archive reason must not be empty',
  'archive command rejects an empty reason'
);
select lives_ok(
  $$select public.archive_student('e5000000-0000-0000-0000-000000000001', 'Transferred to another school')$$,
  'scoped archive permission can archive a student'
);
select is(
  (select status::text from public.students where id = 'e5000000-0000-0000-0000-000000000001'),
  'archived',
  'archive command changes status'
);
select ok(
  (
    select created_by = '41000000-0000-0000-0000-000000000001'
      and updated_by = '42000000-0000-0000-0000-000000000002'
      and updated_at > '2026-01-01 00:00:00+00'
    from public.students
    where id = 'e5000000-0000-0000-0000-000000000001'
  ),
  'archive command preserves creator and owns update attribution'
);

reset role;
select is(
  (
    select count(*)::integer
    from public.audit_log
    where entity_id = 'e5000000-0000-0000-0000-000000000001'
      and action = 'student.archived'
      and actor_user_id = '42000000-0000-0000-0000-000000000002'
      and after_data ->> 'reason' = 'Transferred to another school'
  ),
  1,
  'archive command atomically appends the attributed audit record'
);
select is(
  (
    select count(*)::integer
    from public.event_outbox
    where aggregate_id = 'e5000000-0000-0000-0000-000000000001'
      and event_type = 'student.archived'
      and payload ->> 'actor_user_id' = '42000000-0000-0000-0000-000000000002'
      and payload ->> 'reason' = 'Transferred to another school'
  ),
  1,
  'archive command atomically appends the outbox event'
);

select * from finish();
rollback;
