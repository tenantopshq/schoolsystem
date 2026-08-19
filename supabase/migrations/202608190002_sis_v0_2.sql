begin;

create type public.student_document_visibility as enum (
  'admin_only',
  'staff',
  'guardian',
  'student'
);

create table public.students (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  school_id uuid not null,
  campus_id uuid,
  user_id uuid references auth.users(id) on delete restrict,
  student_number text not null check (length(btrim(student_number)) between 1 and 48),
  first_name text not null check (length(btrim(first_name)) between 1 and 100),
  middle_name text,
  last_name text not null check (length(btrim(last_name)) between 1 and 100),
  preferred_name text,
  date_of_birth date not null check (date_of_birth <= current_date),
  gender text check (gender is null or length(btrim(gender)) between 1 and 40),
  nationality_code char(2),
  primary_language text,
  photo_path text,
  admission_date date,
  exit_date date,
  status public.record_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  foreign key (organization_id, school_id)
    references public.schools(organization_id, id) on delete restrict,
  foreign key (organization_id, campus_id)
    references public.campuses(organization_id, id) on delete restrict,
  foreign key (school_id, campus_id)
    references public.campuses(school_id, id) on delete restrict,
  unique (organization_id, student_number),
  unique (organization_id, id),
  check (campus_id is null or school_id is not null),
  check (exit_date is null or admission_date is null or exit_date >= admission_date)
);
create unique index students_org_user_unique_idx
  on public.students(organization_id, user_id) where user_id is not null;
create index students_scope_status_idx
  on public.students(organization_id, school_id, campus_id, status);
create index students_name_search_idx
  on public.students(organization_id, lower(last_name), lower(first_name));

create table public.guardians (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  user_id uuid references auth.users(id) on delete restrict,
  first_name text not null check (length(btrim(first_name)) between 1 and 100),
  middle_name text,
  last_name text not null check (length(btrim(last_name)) between 1 and 100),
  email text,
  phone text,
  alternate_phone text,
  occupation text,
  preferred_language text,
  status public.record_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  unique (organization_id, id)
);
create unique index guardians_org_user_unique_idx
  on public.guardians(organization_id, user_id) where user_id is not null;
create index guardians_user_org_status_idx
  on public.guardians(user_id, organization_id, status);
create index guardians_name_search_idx
  on public.guardians(organization_id, lower(last_name), lower(first_name));

create table public.student_guardians (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  student_id uuid not null,
  guardian_id uuid not null,
  relationship_type text not null check (length(btrim(relationship_type)) between 1 and 40),
  is_primary boolean not null default false,
  has_portal_access boolean not null default true,
  receives_academic_updates boolean not null default true,
  receives_attendance_alerts boolean not null default true,
  financial_responsibility boolean not null default false,
  pickup_authorized boolean not null default false,
  status public.record_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  foreign key (organization_id, student_id)
    references public.students(organization_id, id) on delete restrict,
  foreign key (organization_id, guardian_id)
    references public.guardians(organization_id, id) on delete restrict,
  unique (student_id, guardian_id)
);
create unique index student_guardians_one_primary_idx
  on public.student_guardians(student_id) where is_primary and status = 'active';
create index student_guardians_guardian_access_idx
  on public.student_guardians(guardian_id, status, has_portal_access, student_id);
create index student_guardians_student_status_idx
  on public.student_guardians(student_id, status, guardian_id);

create table public.student_identifiers (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  student_id uuid not null,
  identifier_type text not null check (length(btrim(identifier_type)) between 1 and 40),
  identifier_value text not null check (length(btrim(identifier_value)) between 1 and 160),
  country_code char(2),
  issued_at date,
  expires_at date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  foreign key (organization_id, student_id)
    references public.students(organization_id, id) on delete restrict,
  unique (student_id, identifier_type, identifier_value),
  check (expires_at is null or issued_at is null or expires_at >= issued_at)
);
create index student_identifiers_student_idx
  on public.student_identifiers(student_id, identifier_type);

create table public.student_addresses (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  student_id uuid not null,
  address_type text not null check (length(btrim(address_type)) between 1 and 40),
  line_1 text not null check (length(btrim(line_1)) between 1 and 200),
  line_2 text,
  city text not null check (length(btrim(city)) between 1 and 100),
  state_region text,
  postal_code text,
  country_code char(2) not null,
  is_primary boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  foreign key (organization_id, student_id)
    references public.students(organization_id, id) on delete restrict
);
create unique index student_addresses_one_primary_type_idx
  on public.student_addresses(student_id, address_type) where is_primary;
create index student_addresses_student_idx on public.student_addresses(student_id);

create table public.student_emergency_contacts (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  student_id uuid not null,
  guardian_id uuid,
  name text not null check (length(btrim(name)) between 1 and 160),
  relationship text not null check (length(btrim(relationship)) between 1 and 40),
  phone text not null check (length(btrim(phone)) between 3 and 40),
  alternate_phone text,
  priority smallint not null check (priority between 1 and 20),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  foreign key (organization_id, student_id)
    references public.students(organization_id, id) on delete restrict,
  foreign key (organization_id, guardian_id)
    references public.guardians(organization_id, id) on delete restrict,
  unique (student_id, priority)
);
create index student_emergency_contacts_student_idx
  on public.student_emergency_contacts(student_id, priority);
create index student_emergency_contacts_guardian_idx
  on public.student_emergency_contacts(guardian_id) where guardian_id is not null;

create table public.student_documents (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  student_id uuid not null,
  document_type text not null check (length(btrim(document_type)) between 1 and 60),
  title text not null check (length(btrim(title)) between 1 and 160),
  storage_path text not null check (length(btrim(storage_path)) between 1 and 500),
  mime_type text,
  file_size bigint check (file_size is null or file_size >= 0),
  issued_at date,
  expires_at date,
  visibility public.student_document_visibility not null default 'admin_only',
  status public.record_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  foreign key (organization_id, student_id)
    references public.students(organization_id, id) on delete restrict,
  unique (organization_id, storage_path),
  check (expires_at is null or issued_at is null or expires_at >= issued_at)
);
create index student_documents_student_visibility_idx
  on public.student_documents(student_id, visibility, status);
create index student_documents_expiry_idx
  on public.student_documents(organization_id, expires_at)
  where expires_at is not null and status = 'active';

create trigger students_updated_at before update on public.students
  for each row execute function public.set_updated_at();
create trigger guardians_updated_at before update on public.guardians
  for each row execute function public.set_updated_at();
create trigger student_guardians_updated_at before update on public.student_guardians
  for each row execute function public.set_updated_at();
create trigger student_identifiers_updated_at before update on public.student_identifiers
  for each row execute function public.set_updated_at();
create trigger student_addresses_updated_at before update on public.student_addresses
  for each row execute function public.set_updated_at();
create trigger student_emergency_contacts_updated_at before update on public.student_emergency_contacts
  for each row execute function public.set_updated_at();
create trigger student_documents_updated_at before update on public.student_documents
  for each row execute function public.set_updated_at();

insert into public.permissions (code, module, description) values
  ('students.view', 'students', 'View student directory and profiles within assigned scope'),
  ('students.create', 'students', 'Create students within assigned scope'),
  ('students.edit', 'students', 'Edit student and guardian records within assigned scope'),
  ('students.archive', 'students', 'Archive student records within assigned scope'),
  ('students.sensitive_view', 'students', 'View sensitive student identifiers within assigned scope'),
  ('student_documents.manage', 'students', 'Create and manage student document metadata within assigned scope');

create or replace function app_auth.is_student_self(target_student_id uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.students s
    where s.id = target_student_id
      and s.user_id = auth.uid()
      and s.status <> 'archived'
  );
$$;

create or replace function app_auth.has_permission_in_org(
  target_organization_id uuid,
  permission_code text
)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1
    from public.organization_memberships m
    join public.role_assignments ra
      on ra.organization_id = m.organization_id and ra.organization_membership_id = m.id
    join public.roles r
      on r.organization_id = ra.organization_id and r.id = ra.role_id
    join public.role_permissions rp
      on rp.organization_id = r.organization_id and rp.role_id = r.id
    join public.permissions p on p.id = rp.permission_id
    where m.organization_id = target_organization_id
      and m.user_id = auth.uid()
      and m.status = 'active' and m.left_at is null
      and r.status = 'active'
      and ra.status = 'active'
      and ra.starts_at <= now()
      and (ra.ends_at is null or ra.ends_at > now())
      and p.code = permission_code
  );
$$;

create or replace function app_auth.is_linked_guardian(target_student_id uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1
    from public.student_guardians sg
    join public.guardians g
      on g.organization_id = sg.organization_id and g.id = sg.guardian_id
    where sg.student_id = target_student_id
      and sg.status = 'active'
      and sg.has_portal_access
      and g.user_id = auth.uid()
      and g.status = 'active'
  );
$$;

create or replace function app_auth.can_view_student(
  target_organization_id uuid,
  target_student_id uuid
)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.students s
    where s.organization_id = target_organization_id
      and s.id = target_student_id
      and (
        s.user_id = auth.uid()
        or app_auth.is_linked_guardian(s.id)
        or app_auth.has_permission(s.organization_id, 'students.view', s.school_id, s.campus_id)
        or app_auth.has_permission(s.organization_id, 'students.edit', s.school_id, s.campus_id)
      )
  );
$$;

create or replace function app_auth.can_edit_student(
  target_organization_id uuid,
  target_student_id uuid
)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.students s
    where s.organization_id = target_organization_id
      and s.id = target_student_id
      and app_auth.has_permission(s.organization_id, 'students.edit', s.school_id, s.campus_id)
  );
$$;

create or replace function app_auth.can_staff_view_student(
  target_organization_id uuid,
  target_student_id uuid
)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.students s
    where s.organization_id = target_organization_id
      and s.id = target_student_id
      and (
        app_auth.has_permission(s.organization_id, 'students.view', s.school_id, s.campus_id)
        or app_auth.has_permission(s.organization_id, 'students.edit', s.school_id, s.campus_id)
      )
  );
$$;

create or replace function app_auth.can_view_student_sensitive(
  target_organization_id uuid,
  target_student_id uuid
)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.students s
    where s.organization_id = target_organization_id
      and s.id = target_student_id
      and (
        s.user_id = auth.uid()
        or app_auth.is_linked_guardian(s.id)
        or app_auth.has_permission(s.organization_id, 'students.sensitive_view', s.school_id, s.campus_id)
      )
  );
$$;

create or replace function app_auth.can_view_guardian(
  target_organization_id uuid,
  target_guardian_id uuid
)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.guardians g
    where g.organization_id = target_organization_id
      and g.id = target_guardian_id
      and (
        g.user_id = auth.uid()
        or (
          g.created_by = auth.uid()
          and app_auth.has_permission_in_org(g.organization_id, 'students.edit')
        )
        or exists (
          select 1 from public.student_guardians sg
          where sg.organization_id = g.organization_id
            and sg.guardian_id = g.id
            and app_auth.can_view_student(sg.organization_id, sg.student_id)
        )
      )
  );
$$;

create or replace function app_auth.can_edit_guardian(
  target_organization_id uuid,
  target_guardian_id uuid
)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1
    from public.student_guardians sg
    where sg.organization_id = target_organization_id
      and sg.guardian_id = target_guardian_id
      and app_auth.can_edit_student(sg.organization_id, sg.student_id)
  );
$$;

create or replace function app_auth.can_manage_student_documents(
  target_organization_id uuid,
  target_student_id uuid
)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.students s
    where s.organization_id = target_organization_id
      and s.id = target_student_id
      and app_auth.has_permission(
        s.organization_id,
        'student_documents.manage',
        s.school_id,
        s.campus_id
      )
  );
$$;

revoke all on function app_auth.is_student_self(uuid) from public, anon;
revoke all on function app_auth.has_permission_in_org(uuid, text) from public, anon;
revoke all on function app_auth.is_linked_guardian(uuid) from public, anon;
revoke all on function app_auth.can_view_student(uuid, uuid) from public, anon;
revoke all on function app_auth.can_edit_student(uuid, uuid) from public, anon;
revoke all on function app_auth.can_staff_view_student(uuid, uuid) from public, anon;
revoke all on function app_auth.can_view_student_sensitive(uuid, uuid) from public, anon;
revoke all on function app_auth.can_view_guardian(uuid, uuid) from public, anon;
revoke all on function app_auth.can_edit_guardian(uuid, uuid) from public, anon;
revoke all on function app_auth.can_manage_student_documents(uuid, uuid) from public, anon;
grant execute on function app_auth.is_student_self(uuid) to authenticated, service_role;
grant execute on function app_auth.has_permission_in_org(uuid, text) to authenticated, service_role;
grant execute on function app_auth.is_linked_guardian(uuid) to authenticated, service_role;
grant execute on function app_auth.can_view_student(uuid, uuid) to authenticated, service_role;
grant execute on function app_auth.can_edit_student(uuid, uuid) to authenticated, service_role;
grant execute on function app_auth.can_staff_view_student(uuid, uuid) to authenticated, service_role;
grant execute on function app_auth.can_view_student_sensitive(uuid, uuid) to authenticated, service_role;
grant execute on function app_auth.can_view_guardian(uuid, uuid) to authenticated, service_role;
grant execute on function app_auth.can_edit_guardian(uuid, uuid) to authenticated, service_role;
grant execute on function app_auth.can_manage_student_documents(uuid, uuid) to authenticated, service_role;

alter table public.students enable row level security;
alter table public.students force row level security;
alter table public.guardians enable row level security;
alter table public.guardians force row level security;
alter table public.student_guardians enable row level security;
alter table public.student_guardians force row level security;
alter table public.student_identifiers enable row level security;
alter table public.student_identifiers force row level security;
alter table public.student_addresses enable row level security;
alter table public.student_addresses force row level security;
alter table public.student_emergency_contacts enable row level security;
alter table public.student_emergency_contacts force row level security;
alter table public.student_documents enable row level security;
alter table public.student_documents force row level security;

create policy students_select on public.students for select to authenticated
  using (app_auth.can_view_student(organization_id, id));
create policy students_insert on public.students for insert to authenticated
  with check (app_auth.has_permission(organization_id, 'students.create', school_id, campus_id));
create policy students_update on public.students for update to authenticated
  using (app_auth.has_permission(organization_id, 'students.edit', school_id, campus_id))
  with check (app_auth.has_permission(organization_id, 'students.edit', school_id, campus_id));

create policy guardians_select on public.guardians for select to authenticated
  using (app_auth.can_view_guardian(organization_id, id));
create policy guardians_insert on public.guardians for insert to authenticated
  with check (
    created_by = auth.uid()
    and app_auth.has_permission_in_org(organization_id, 'students.edit')
  );
create policy guardians_update on public.guardians for update to authenticated
  using (app_auth.can_edit_guardian(organization_id, id))
  with check (app_auth.can_edit_guardian(organization_id, id));

create policy student_guardians_select on public.student_guardians for select to authenticated
  using (app_auth.can_view_student(organization_id, student_id));
create policy student_guardians_insert on public.student_guardians for insert to authenticated
  with check (app_auth.can_edit_student(organization_id, student_id));
create policy student_guardians_update on public.student_guardians for update to authenticated
  using (app_auth.can_edit_student(organization_id, student_id))
  with check (app_auth.can_edit_student(organization_id, student_id));

create policy student_identifiers_select on public.student_identifiers for select to authenticated
  using (app_auth.can_view_student_sensitive(organization_id, student_id));
create policy student_identifiers_insert on public.student_identifiers for insert to authenticated
  with check (app_auth.can_edit_student(organization_id, student_id));
create policy student_identifiers_update on public.student_identifiers for update to authenticated
  using (app_auth.can_edit_student(organization_id, student_id))
  with check (app_auth.can_edit_student(organization_id, student_id));

create policy student_addresses_select on public.student_addresses for select to authenticated
  using (app_auth.can_view_student(organization_id, student_id));
create policy student_addresses_insert on public.student_addresses for insert to authenticated
  with check (app_auth.can_edit_student(organization_id, student_id));
create policy student_addresses_update on public.student_addresses for update to authenticated
  using (app_auth.can_edit_student(organization_id, student_id))
  with check (app_auth.can_edit_student(organization_id, student_id));

create policy student_emergency_contacts_select on public.student_emergency_contacts for select to authenticated
  using (app_auth.can_view_student(organization_id, student_id));
create policy student_emergency_contacts_insert on public.student_emergency_contacts for insert to authenticated
  with check (app_auth.can_edit_student(organization_id, student_id));
create policy student_emergency_contacts_update on public.student_emergency_contacts for update to authenticated
  using (app_auth.can_edit_student(organization_id, student_id))
  with check (app_auth.can_edit_student(organization_id, student_id));

create policy student_documents_select on public.student_documents for select to authenticated
  using (
    app_auth.can_manage_student_documents(organization_id, student_id)
    or (visibility in ('staff', 'guardian', 'student') and app_auth.can_staff_view_student(organization_id, student_id))
    or (visibility in ('guardian', 'student') and app_auth.is_linked_guardian(student_id))
    or (visibility = 'student' and app_auth.is_student_self(student_id))
  );
create policy student_documents_insert on public.student_documents for insert to authenticated
  with check (
    app_auth.can_edit_student(organization_id, student_id)
    and app_auth.can_manage_student_documents(organization_id, student_id)
  );
create policy student_documents_update on public.student_documents for update to authenticated
  using (
    app_auth.can_edit_student(organization_id, student_id)
    and app_auth.can_manage_student_documents(organization_id, student_id)
  )
  with check (
    app_auth.can_edit_student(organization_id, student_id)
    and app_auth.can_manage_student_documents(organization_id, student_id)
  );

grant select, insert, update on public.students to authenticated;
grant select, insert, update on public.guardians to authenticated;
grant select, insert, update on public.student_guardians to authenticated;
grant select, insert, update on public.student_identifiers to authenticated;
grant select, insert, update on public.student_addresses to authenticated;
grant select, insert, update on public.student_emergency_contacts to authenticated;
grant select, insert, update on public.student_documents to authenticated;
revoke all on public.students, public.guardians, public.student_guardians,
  public.student_identifiers, public.student_addresses,
  public.student_emergency_contacts, public.student_documents from anon;

commit;
