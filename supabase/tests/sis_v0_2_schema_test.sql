begin;
create extension if not exists pgtap with schema extensions;
select plan(28);

select has_table('public', 'students', 'students exists');
select has_table('public', 'guardians', 'guardians exists');
select has_table('public', 'student_guardians', 'student guardians exists');
select has_table('public', 'student_identifiers', 'student identifiers exists');
select has_table('public', 'student_addresses', 'student addresses exists');
select has_table('public', 'student_emergency_contacts', 'emergency contacts exists');
select has_table('public', 'student_documents', 'student documents exists');

select ok((select relrowsecurity and relforcerowsecurity from pg_class where oid = 'public.students'::regclass), 'students forces RLS');
select ok((select relrowsecurity and relforcerowsecurity from pg_class where oid = 'public.guardians'::regclass), 'guardians forces RLS');
select ok((select relrowsecurity and relforcerowsecurity from pg_class where oid = 'public.student_guardians'::regclass), 'student guardians forces RLS');
select ok((select relrowsecurity and relforcerowsecurity from pg_class where oid = 'public.student_identifiers'::regclass), 'identifiers force RLS');
select ok((select relrowsecurity and relforcerowsecurity from pg_class where oid = 'public.student_addresses'::regclass), 'addresses force RLS');
select ok((select relrowsecurity and relforcerowsecurity from pg_class where oid = 'public.student_emergency_contacts'::regclass), 'emergency contacts force RLS');
select ok((select relrowsecurity and relforcerowsecurity from pg_class where oid = 'public.student_documents'::regclass), 'documents force RLS');

select has_index('public', 'students', 'students_scope_status_idx', 'student policy scope is indexed');
select has_index('public', 'guardians', 'guardians_user_org_status_idx', 'guardian identity path is indexed');
select has_index('public', 'student_guardians', 'student_guardians_guardian_access_idx', 'guardian relationship path is indexed');
select has_index('public', 'student_documents', 'student_documents_student_visibility_idx', 'document visibility path is indexed');
select has_index('public', 'students', 'students_org_campus_idx', 'organization-campus foreign key path is indexed');
select has_index('public', 'students', 'students_school_campus_idx', 'school-campus foreign key path is indexed');

select is(
  (select count(*)::integer from public.permissions where module = 'students'),
  6,
  'SIS permission catalog is seeded'
);
select function_returns('app_auth', 'can_view_student', array['uuid','uuid'], 'boolean', 'student access helper returns boolean');
select function_returns('app_auth', 'can_edit_student', array['uuid','uuid'], 'boolean', 'student edit helper returns boolean');
select function_returns('app_auth', 'is_linked_guardian', array['uuid'], 'boolean', 'guardian helper returns boolean');
select function_returns('app_auth', 'can_view_student_sensitive', array['uuid','uuid'], 'boolean', 'sensitive helper returns boolean');
select function_returns('app_auth', 'can_manage_student_documents', array['uuid','uuid'], 'boolean', 'document helper returns boolean');
select function_returns('app_auth', 'archive_student', array['uuid','text'], 'uuid', 'archive command returns the archived student id');
select function_returns('public', 'archive_student', array['uuid','text'], 'uuid', 'public archive RPC returns the archived student id');

select * from finish();
rollback;
