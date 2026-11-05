begin;

-- Existing student administrators need read-only access to the staff directory
-- introduced in v1.4. Their existing role-assignment scope continues to bound
-- access through app_auth.has_permission.
insert into public.role_permissions (
  organization_id,
  role_id,
  permission_id
)
select
  r.organization_id,
  r.id,
  p.id
from public.roles r
join public.permissions p on p.code = 'staff_profiles.view'
where r.code = 'STUDENT_ADMIN'
  and r.status = 'active'
on conflict (role_id, permission_id) do nothing;

commit;
