begin;

create extension if not exists pgcrypto with schema extensions;
create schema if not exists app_auth;
revoke all on schema app_auth from public, anon;
grant usage on schema app_auth to authenticated, service_role;

create type public.record_status as enum ('active', 'inactive', 'archived');
create type public.membership_status as enum ('invited', 'active', 'suspended', 'left');
create type public.role_assignment_status as enum ('active', 'inactive');
create type public.academic_period_status as enum ('draft', 'active', 'closed', 'archived');
create type public.outbox_status as enum ('pending', 'processing', 'processed', 'failed');

create or replace function public.set_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  parent_organization_id uuid references public.organizations(id) on delete restrict,
  name text not null check (length(btrim(name)) between 2 and 160),
  legal_name text,
  slug text not null check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  default_locale text not null default 'en',
  default_timezone text not null default 'UTC',
  default_currency char(3) not null default 'USD',
  status public.record_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  unique (slug),
  check (parent_organization_id is null or parent_organization_id <> id)
);

create table public.schools (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  name text not null check (length(btrim(name)) between 2 and 160),
  code text not null check (length(btrim(code)) between 1 and 32),
  legal_name text,
  email text,
  phone text,
  website text,
  timezone text,
  default_locale text,
  status public.record_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  unique (organization_id, code),
  unique (organization_id, id)
);

create table public.campuses (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  school_id uuid not null,
  name text not null check (length(btrim(name)) between 2 and 160),
  code text not null check (length(btrim(code)) between 1 and 32),
  address_line_1 text,
  address_line_2 text,
  city text,
  state_region text,
  postal_code text,
  country_code char(2),
  phone text,
  email text,
  status public.record_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  foreign key (organization_id, school_id) references public.schools(organization_id, id) on delete restrict,
  unique (school_id, code),
  unique (school_id, id),
  unique (organization_id, id)
);

create table public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  first_name text,
  middle_name text,
  last_name text,
  display_name text,
  phone text,
  avatar_path text,
  preferred_locale text not null default 'en',
  timezone text not null default 'UTC',
  status public.record_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.organization_memberships (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  user_id uuid not null references auth.users(id) on delete restrict,
  status public.membership_status not null default 'invited',
  joined_at timestamptz,
  left_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  unique (organization_id, user_id),
  unique (organization_id, id),
  check ((status = 'left' and left_at is not null) or status <> 'left')
);

create table public.permissions (
  id uuid primary key default gen_random_uuid(),
  code text not null unique check (code ~ '^[a-z][a-z0-9_]*\.[a-z][a-z0-9_]*$'),
  module text not null,
  description text not null,
  created_at timestamptz not null default now()
);

create table public.roles (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  code text not null check (code ~ '^[A-Z][A-Z0-9_]*$'),
  name text not null check (length(btrim(name)) between 2 and 80),
  description text,
  is_system_role boolean not null default false,
  status public.record_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  unique (organization_id, code),
  unique (organization_id, id)
);

create table public.role_permissions (
  organization_id uuid not null references public.organizations(id) on delete restrict,
  role_id uuid not null,
  permission_id uuid not null references public.permissions(id) on delete restrict,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null,
  primary key (role_id, permission_id),
  foreign key (organization_id, role_id) references public.roles(organization_id, id) on delete cascade
);

create table public.role_assignments (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  organization_membership_id uuid not null,
  role_id uuid not null,
  school_id uuid,
  campus_id uuid,
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  status public.role_assignment_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  foreign key (organization_id, organization_membership_id) references public.organization_memberships(organization_id, id) on delete cascade,
  foreign key (organization_id, role_id) references public.roles(organization_id, id) on delete restrict,
  foreign key (organization_id, school_id) references public.schools(organization_id, id) on delete restrict,
  foreign key (organization_id, campus_id) references public.campuses(organization_id, id) on delete restrict,
  foreign key (school_id, campus_id) references public.campuses(school_id, id) on delete restrict,
  check (ends_at is null or ends_at > starts_at),
  check (campus_id is null or school_id is not null)
);

create table public.academic_years (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  school_id uuid not null,
  name text not null check (length(btrim(name)) between 2 and 40),
  start_date date not null,
  end_date date not null,
  is_current boolean not null default false,
  status public.academic_period_status not null default 'draft',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  foreign key (organization_id, school_id) references public.schools(organization_id, id) on delete restrict,
  unique (school_id, name),
  unique (organization_id, id),
  check (end_date > start_date)
);
create unique index academic_years_one_current_per_school on public.academic_years(school_id) where is_current;

create table public.academic_terms (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  academic_year_id uuid not null,
  name text not null check (length(btrim(name)) between 1 and 60),
  sequence smallint not null check (sequence > 0),
  start_date date not null,
  end_date date not null,
  grading_start_at timestamptz,
  grading_end_at timestamptz,
  status public.academic_period_status not null default 'draft',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  foreign key (organization_id, academic_year_id) references public.academic_years(organization_id, id) on delete restrict,
  unique (academic_year_id, sequence),
  unique (academic_year_id, name),
  check (end_date >= start_date),
  check (grading_end_at is null or grading_start_at is null or grading_end_at > grading_start_at)
);

create table public.audit_log (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  actor_user_id uuid references auth.users(id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id uuid,
  before_data jsonb,
  after_data jsonb,
  ip_address inet,
  user_agent text,
  occurred_at timestamptz not null default now()
);

create table public.event_outbox (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  event_type text not null,
  aggregate_type text not null,
  aggregate_id uuid not null,
  payload jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now(),
  processed_at timestamptz,
  status public.outbox_status not null default 'pending',
  retry_count integer not null default 0 check (retry_count >= 0),
  last_error text
);

create index memberships_user_org_status_idx on public.organization_memberships(user_id, organization_id, status);
create index roles_org_status_idx on public.roles(organization_id, status);
create index role_permissions_permission_role_idx on public.role_permissions(permission_id, role_id);
create index role_assignments_membership_active_idx on public.role_assignments(organization_membership_id, status, starts_at, ends_at);
create index role_assignments_scope_idx on public.role_assignments(organization_id, school_id, campus_id);
create index campuses_school_idx on public.campuses(school_id);
create index academic_years_org_school_idx on public.academic_years(organization_id, school_id);
create index academic_terms_year_idx on public.academic_terms(academic_year_id, sequence);
create index audit_log_org_time_idx on public.audit_log(organization_id, occurred_at desc);
create index audit_log_entity_idx on public.audit_log(entity_type, entity_id);
create index event_outbox_pending_idx on public.event_outbox(status, occurred_at) where status in ('pending', 'failed');

create trigger organizations_updated_at before update on public.organizations for each row execute function public.set_updated_at();
create trigger schools_updated_at before update on public.schools for each row execute function public.set_updated_at();
create trigger campuses_updated_at before update on public.campuses for each row execute function public.set_updated_at();
create trigger profiles_updated_at before update on public.profiles for each row execute function public.set_updated_at();
create trigger memberships_updated_at before update on public.organization_memberships for each row execute function public.set_updated_at();
create trigger roles_updated_at before update on public.roles for each row execute function public.set_updated_at();
create trigger assignments_updated_at before update on public.role_assignments for each row execute function public.set_updated_at();
create trigger academic_years_updated_at before update on public.academic_years for each row execute function public.set_updated_at();
create trigger academic_terms_updated_at before update on public.academic_terms for each row execute function public.set_updated_at();

create or replace function public.handle_new_auth_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (user_id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'display_name', new.raw_user_meta_data ->> 'full_name'));
  return new;
end;
$$;
create trigger auth_user_created after insert on auth.users
for each row execute function public.handle_new_auth_user();

insert into public.permissions (code, module, description) values
  ('organizations.view', 'organizations', 'View organization settings'),
  ('organizations.manage', 'organizations', 'Manage organization settings'),
  ('schools.view', 'organizations', 'View schools and campuses'),
  ('schools.manage', 'organizations', 'Manage schools and campuses'),
  ('memberships.view', 'identity', 'View organization memberships'),
  ('memberships.manage', 'identity', 'Invite, suspend, and manage memberships'),
  ('roles.view', 'identity', 'View roles and permission grants'),
  ('roles.manage', 'identity', 'Create roles, grant permissions, and assign roles'),
  ('academic_periods.view', 'academics', 'View academic years and terms'),
  ('academic_periods.manage', 'academics', 'Manage academic years and terms'),
  ('audit.view', 'audit', 'View organization audit history');

create or replace function app_auth.is_org_member(target_organization_id uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.organization_memberships m
    where m.organization_id = target_organization_id
      and m.user_id = auth.uid()
      and m.status = 'active'
      and m.left_at is null
  );
$$;

create or replace function app_auth.has_permission(
  target_organization_id uuid,
  permission_code text,
  target_school_id uuid default null,
  target_campus_id uuid default null
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
      and (ra.school_id is null or ra.school_id = target_school_id)
      and (ra.campus_id is null or ra.campus_id = target_campus_id)
  );
$$;

revoke all on all functions in schema app_auth from public, anon;
grant execute on function app_auth.is_org_member(uuid) to authenticated, service_role;
grant execute on function app_auth.has_permission(uuid, text, uuid, uuid) to authenticated, service_role;

alter table public.organizations enable row level security; alter table public.organizations force row level security;
alter table public.schools enable row level security; alter table public.schools force row level security;
alter table public.campuses enable row level security; alter table public.campuses force row level security;
alter table public.profiles enable row level security; alter table public.profiles force row level security;
alter table public.organization_memberships enable row level security; alter table public.organization_memberships force row level security;
alter table public.permissions enable row level security; alter table public.permissions force row level security;
alter table public.roles enable row level security; alter table public.roles force row level security;
alter table public.role_permissions enable row level security; alter table public.role_permissions force row level security;
alter table public.role_assignments enable row level security; alter table public.role_assignments force row level security;
alter table public.academic_years enable row level security; alter table public.academic_years force row level security;
alter table public.academic_terms enable row level security; alter table public.academic_terms force row level security;
alter table public.audit_log enable row level security; alter table public.audit_log force row level security;
alter table public.event_outbox enable row level security; alter table public.event_outbox force row level security;

create policy profiles_select_self on public.profiles for select to authenticated using (user_id = auth.uid());
create policy profiles_update_self on public.profiles for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy permissions_read on public.permissions for select to authenticated using (true);

create policy organizations_select on public.organizations for select to authenticated
  using (app_auth.is_org_member(id));
create policy organizations_update on public.organizations for update to authenticated
  using (app_auth.has_permission(id, 'organizations.manage'))
  with check (app_auth.has_permission(id, 'organizations.manage'));

create policy schools_select on public.schools for select to authenticated
  using (app_auth.has_permission(organization_id, 'schools.view', id) or app_auth.has_permission(organization_id, 'schools.manage', id));
create policy schools_all_write on public.schools for all to authenticated
  using (app_auth.has_permission(organization_id, 'schools.manage', id))
  with check (app_auth.has_permission(organization_id, 'schools.manage', id));
create policy campuses_select on public.campuses for select to authenticated
  using (app_auth.has_permission(organization_id, 'schools.view', school_id, id) or app_auth.has_permission(organization_id, 'schools.manage', school_id, id));
create policy campuses_all_write on public.campuses for all to authenticated
  using (app_auth.has_permission(organization_id, 'schools.manage', school_id, id))
  with check (app_auth.has_permission(organization_id, 'schools.manage', school_id, id));

create policy memberships_select on public.organization_memberships for select to authenticated
  using (user_id = auth.uid() or app_auth.has_permission(organization_id, 'memberships.view') or app_auth.has_permission(organization_id, 'memberships.manage'));
create policy memberships_write on public.organization_memberships for all to authenticated
  using (app_auth.has_permission(organization_id, 'memberships.manage'))
  with check (app_auth.has_permission(organization_id, 'memberships.manage'));
create policy roles_select on public.roles for select to authenticated
  using (app_auth.has_permission(organization_id, 'roles.view') or app_auth.has_permission(organization_id, 'roles.manage'));
create policy roles_write on public.roles for all to authenticated
  using (app_auth.has_permission(organization_id, 'roles.manage'))
  with check (app_auth.has_permission(organization_id, 'roles.manage'));
create policy role_permissions_select on public.role_permissions for select to authenticated
  using (app_auth.has_permission(organization_id, 'roles.view') or app_auth.has_permission(organization_id, 'roles.manage'));
create policy role_permissions_write on public.role_permissions for all to authenticated
  using (app_auth.has_permission(organization_id, 'roles.manage'))
  with check (app_auth.has_permission(organization_id, 'roles.manage'));
create policy role_assignments_select on public.role_assignments for select to authenticated
  using (app_auth.has_permission(organization_id, 'roles.view') or app_auth.has_permission(organization_id, 'roles.manage'));
create policy role_assignments_write on public.role_assignments for all to authenticated
  using (app_auth.has_permission(organization_id, 'roles.manage'))
  with check (app_auth.has_permission(organization_id, 'roles.manage'));

create policy academic_years_select on public.academic_years for select to authenticated
  using (app_auth.has_permission(organization_id, 'academic_periods.view', school_id) or app_auth.has_permission(organization_id, 'academic_periods.manage', school_id));
create policy academic_years_write on public.academic_years for all to authenticated
  using (app_auth.has_permission(organization_id, 'academic_periods.manage', school_id))
  with check (app_auth.has_permission(organization_id, 'academic_periods.manage', school_id));
create policy academic_terms_select on public.academic_terms for select to authenticated
  using (exists (select 1 from public.academic_years y where y.id = academic_year_id));
create policy academic_terms_write on public.academic_terms for all to authenticated
  using (exists (select 1 from public.academic_years y where y.id = academic_year_id and app_auth.has_permission(organization_id, 'academic_periods.manage', y.school_id)))
  with check (exists (select 1 from public.academic_years y where y.id = academic_year_id and app_auth.has_permission(organization_id, 'academic_periods.manage', y.school_id)));

create policy audit_select on public.audit_log for select to authenticated
  using (app_auth.has_permission(organization_id, 'audit.view'));
create policy audit_insert on public.audit_log for insert to authenticated
  with check (actor_user_id = auth.uid() and app_auth.is_org_member(organization_id));
create policy outbox_insert on public.event_outbox for insert to authenticated
  with check (app_auth.is_org_member(organization_id));

grant select, insert, update, delete on all tables in schema public to authenticated;
revoke insert, update, delete on public.permissions from authenticated;
revoke update, delete on public.audit_log from authenticated;
revoke select, update, delete on public.event_outbox from authenticated;
revoke all on all tables in schema public from anon;

commit;
