begin;
create extension if not exists pgtap with schema extensions;
select plan(24);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, created_at, updated_at)
values
  ('31000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'sis-admin@example.test', '', now(), now()),
  ('32000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'sis-guardian@example.test', '', now(), now()),
  ('33000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'sis-student@example.test', '', now(), now()),
  ('34000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'sis-other@example.test', '', now(), now());

insert into public.organizations (id, name, slug) values
  ('c0000000-0000-0000-0000-000000000001', 'SIS Tenant A', 'sis-tenant-a'),
  ('d0000000-0000-0000-0000-000000000002', 'SIS Tenant B', 'sis-tenant-b');
insert into public.schools (id, organization_id, name, code) values
  ('c1000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 'School A', 'A'),
  ('d1000000-0000-0000-0000-000000000002', 'd0000000-0000-0000-0000-000000000002', 'School B', 'B');
insert into public.campuses (id, organization_id, school_id, name, code) values
  ('c2000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 'c1000000-0000-0000-0000-000000000001', 'Campus A', 'MAIN'),
  ('d2000000-0000-0000-0000-000000000002', 'd0000000-0000-0000-0000-000000000002', 'd1000000-0000-0000-0000-000000000002', 'Campus B', 'MAIN');

insert into public.organization_memberships (id, organization_id, user_id, status, joined_at)
values ('c3000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', '31000000-0000-0000-0000-000000000001', 'active', now());
insert into public.roles (id, organization_id, code, name)
values ('c4000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 'SIS_ADMIN', 'SIS Administrator');
insert into public.role_permissions (organization_id, role_id, permission_id)
select 'c0000000-0000-0000-0000-000000000001', 'c4000000-0000-0000-0000-000000000001', id
from public.permissions
where code in ('students.view', 'students.create', 'students.edit', 'student_documents.manage');
insert into public.role_assignments (
  organization_id, organization_membership_id, role_id, school_id, campus_id
) values (
  'c0000000-0000-0000-0000-000000000001',
  'c3000000-0000-0000-0000-000000000001',
  'c4000000-0000-0000-0000-000000000001',
  'c1000000-0000-0000-0000-000000000001',
  'c2000000-0000-0000-0000-000000000001'
);

insert into public.students (
  id, organization_id, school_id, campus_id, user_id, student_number,
  first_name, last_name, date_of_birth
) values
  ('c5000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 'c1000000-0000-0000-0000-000000000001', 'c2000000-0000-0000-0000-000000000001', '33000000-0000-0000-0000-000000000003', 'A-001', 'Ada', 'Student', '2014-01-01'),
  ('c5000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000001', 'c1000000-0000-0000-0000-000000000001', 'c2000000-0000-0000-0000-000000000001', null, 'A-002', 'Ben', 'Student', '2014-02-01'),
  ('d5000000-0000-0000-0000-000000000003', 'd0000000-0000-0000-0000-000000000002', 'd1000000-0000-0000-0000-000000000002', 'd2000000-0000-0000-0000-000000000002', null, 'B-001', 'Cross', 'Tenant', '2014-03-01');
insert into public.guardians (
  id, organization_id, user_id, first_name, last_name, email
) values (
  'c6000000-0000-0000-0000-000000000001',
  'c0000000-0000-0000-0000-000000000001',
  '32000000-0000-0000-0000-000000000002',
  'Grace', 'Guardian', 'sis-guardian@example.test'
);
insert into public.student_guardians (
  id, organization_id, student_id, guardian_id, relationship_type, is_primary
) values (
  'c7000000-0000-0000-0000-000000000001',
  'c0000000-0000-0000-0000-000000000001',
  'c5000000-0000-0000-0000-000000000001',
  'c6000000-0000-0000-0000-000000000001',
  'parent', true
);
insert into public.student_identifiers (
  organization_id, student_id, identifier_type, identifier_value
) values (
  'c0000000-0000-0000-0000-000000000001',
  'c5000000-0000-0000-0000-000000000001',
  'passport', 'TEST-PASSPORT-001'
);
insert into public.student_addresses (
  organization_id, student_id, address_type, line_1, city, country_code, is_primary
) values (
  'c0000000-0000-0000-0000-000000000001',
  'c5000000-0000-0000-0000-000000000001',
  'home', '1 Test Street', 'Test City', 'BD', true
);
insert into public.student_emergency_contacts (
  organization_id, student_id, guardian_id, name, relationship, phone, priority
) values (
  'c0000000-0000-0000-0000-000000000001',
  'c5000000-0000-0000-0000-000000000001',
  'c6000000-0000-0000-0000-000000000001',
  'Grace Guardian', 'parent', '+8801000000000', 1
);
insert into public.student_documents (
  organization_id, student_id, document_type, title, storage_path, visibility
) values
  ('c0000000-0000-0000-0000-000000000001', 'c5000000-0000-0000-0000-000000000001', 'internal', 'Admin document', 'sis/a/admin.pdf', 'admin_only'),
  ('c0000000-0000-0000-0000-000000000001', 'c5000000-0000-0000-0000-000000000001', 'note', 'Staff document', 'sis/a/staff.pdf', 'staff'),
  ('c0000000-0000-0000-0000-000000000001', 'c5000000-0000-0000-0000-000000000001', 'family', 'Guardian document', 'sis/a/guardian.pdf', 'guardian'),
  ('c0000000-0000-0000-0000-000000000001', 'c5000000-0000-0000-0000-000000000001', 'student', 'Student document', 'sis/a/student.pdf', 'student');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"31000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
select is((select count(*)::integer from public.students), 2, 'scoped staff sees only own tenant and campus students');
select is((select count(*)::integer from public.student_identifiers), 0, 'staff without sensitive permission cannot see identifiers');
select ok(app_auth.can_edit_student('c0000000-0000-0000-0000-000000000001', 'c5000000-0000-0000-0000-000000000001'), 'scoped editor can edit assigned student');
select ok(not app_auth.can_edit_student('d0000000-0000-0000-0000-000000000002', 'd5000000-0000-0000-0000-000000000003'), 'staff cannot edit cross-tenant student');
select is((select count(*)::integer from public.student_documents), 4, 'document manager sees all assigned student documents');
select lives_ok(
  $$insert into public.guardians (id, organization_id, first_name, last_name, created_by) values ('c6000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000001', 'New', 'Guardian', '31000000-0000-0000-0000-000000000001')$$,
  'scoped editor can create guardian for later linking'
);
select is((select count(*)::integer from public.guardians), 2, 'creator can read newly created unlinked guardian');
select lives_ok(
  $$update public.students set preferred_name = 'Ada Updated' where id = 'c5000000-0000-0000-0000-000000000001'$$,
  'scoped staff update succeeds'
);
select is((select preferred_name from public.students where id = 'c5000000-0000-0000-0000-000000000001'), 'Ada Updated', 'staff update persisted');
select throws_ok(
  $$insert into public.students (organization_id, school_id, campus_id, student_number, first_name, last_name, date_of_birth) values ('d0000000-0000-0000-0000-000000000002', 'd1000000-0000-0000-0000-000000000002', 'd2000000-0000-0000-0000-000000000002', 'B-002', 'Blocked', 'Insert', '2014-04-01')$$,
  '42501',
  'new row violates row-level security policy for table "students"',
  'cross-tenant insert is rejected'
);

select set_config('request.jwt.claims', '{"sub":"32000000-0000-0000-0000-000000000002","role":"authenticated"}', true);
select is((select count(*)::integer from public.students), 1, 'guardian sees only linked child');
select is((select student_number from public.students), 'A-001', 'guardian sees expected child');
select is((select count(*)::integer from public.guardians), 1, 'guardian sees own profile');
select is((select count(*)::integer from public.student_identifiers), 1, 'guardian sees linked child identifier');
select is((select count(*)::integer from public.student_addresses), 1, 'guardian sees linked child address');
select is((select count(*)::integer from public.student_emergency_contacts), 1, 'guardian sees linked child emergency contact');
select is((select count(*)::integer from public.student_documents), 2, 'guardian sees only guardian and student documents');
select ok(not app_auth.can_view_student('c0000000-0000-0000-0000-000000000001', 'c5000000-0000-0000-0000-000000000002'), 'guardian cannot access unrelated child');

select set_config('request.jwt.claims', '{"sub":"33000000-0000-0000-0000-000000000003","role":"authenticated"}', true);
select is((select count(*)::integer from public.students), 1, 'student sees only self');
select is((select count(*)::integer from public.student_identifiers), 1, 'student sees own identifier');
select is((select count(*)::integer from public.student_documents), 1, 'student sees only student-visible document');

select set_config('request.jwt.claims', '{"sub":"34000000-0000-0000-0000-000000000004","role":"authenticated"}', true);
select is((select count(*)::integer from public.students), 0, 'unrelated authenticated user sees no students');

reset role;
update public.student_guardians set status = 'inactive' where id = 'c7000000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"32000000-0000-0000-0000-000000000002","role":"authenticated"}', true);
select is((select count(*)::integer from public.students), 0, 'inactive guardian relationship denies child access');

set local role anon;
select throws_ok(
  $$select * from public.students$$,
  '42501',
  'permission denied for table students',
  'anonymous student access is denied'
);

select * from finish();
rollback;
