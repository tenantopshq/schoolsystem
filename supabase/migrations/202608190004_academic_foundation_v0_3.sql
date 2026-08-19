begin;

-- =============================================================================
-- Parent keys, aggregate tables, constraints, and indexes
-- =============================================================================
-- Composite parent keys prove tenant, school, and campus consistency in storage.
alter table public.academic_years add constraint academic_years_org_school_id_key unique (organization_id, school_id, id);
alter table public.academic_terms add constraint academic_terms_org_year_id_key unique (organization_id, academic_year_id, id);
create unique index academic_terms_year_normalized_name_key on public.academic_terms(academic_year_id,lower(btrim(name)));

create table public.staff_profiles (
  id uuid primary key default gen_random_uuid(), organization_id uuid not null,
  organization_membership_id uuid not null, school_id uuid, campus_id uuid,
  staff_number text not null check (length(btrim(staff_number)) between 1 and 48),
  employment_type text not null check (length(btrim(employment_type)) between 1 and 40),
  job_title text check (job_title is null or length(btrim(job_title)) between 1 and 120),
  department text check (department is null or length(btrim(department)) between 1 and 120),
  hire_date date, termination_date date, status public.record_status not null default 'active',
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null, updated_by uuid references auth.users(id) on delete set null,
  foreign key (organization_id, organization_membership_id) references public.organization_memberships(organization_id, id) on delete restrict,
  foreign key (organization_id, school_id) references public.schools(organization_id, id) on delete restrict,
  foreign key (organization_id, campus_id) references public.campuses(organization_id, id) on delete restrict,
  foreign key (school_id, campus_id) references public.campuses(school_id, id) on delete restrict,
  unique (organization_id, organization_membership_id), unique (organization_id, staff_number), unique (organization_id, id),
  check (campus_id is null or school_id is not null), check (termination_date is null or hire_date is null or termination_date >= hire_date)
);

create table public.buildings (
  id uuid primary key default gen_random_uuid(), organization_id uuid not null, school_id uuid not null, campus_id uuid not null,
  code text not null check (length(btrim(code)) between 1 and 32), name text not null check (length(btrim(name)) between 2 and 160),
  opened_on date, closed_on date, status public.record_status not null default 'active',
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null, updated_by uuid references auth.users(id) on delete set null,
  foreign key (organization_id, school_id) references public.schools(organization_id, id) on delete restrict,
  foreign key (organization_id, campus_id) references public.campuses(organization_id, id) on delete restrict,
  foreign key (school_id, campus_id) references public.campuses(school_id, id) on delete restrict,
  unique (campus_id, code), unique (organization_id, school_id, campus_id, id), unique (organization_id, id),
  check (closed_on is null or opened_on is null or closed_on >= opened_on)
);

create table public.rooms (
  id uuid primary key default gen_random_uuid(), organization_id uuid not null, school_id uuid not null, campus_id uuid not null, building_id uuid not null,
  code text not null check (length(btrim(code)) between 1 and 32), name text not null check (length(btrim(name)) between 1 and 160),
  room_type text not null check (length(btrim(room_type)) between 1 and 40), capacity integer not null check (capacity between 1 and 10000),
  floor_label text check (floor_label is null or length(btrim(floor_label)) between 1 and 40), status public.record_status not null default 'active',
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null, updated_by uuid references auth.users(id) on delete set null,
  foreign key (organization_id, school_id, campus_id, building_id) references public.buildings(organization_id, school_id, campus_id, id) on delete restrict,
  unique (building_id, code), unique (organization_id, school_id, campus_id, id), unique (organization_id, id)
);

create table public.grade_levels (
  id uuid primary key default gen_random_uuid(), organization_id uuid not null, school_id uuid not null,
  code text not null check (length(btrim(code)) between 1 and 32), name text not null check (length(btrim(name)) between 1 and 100),
  sequence smallint not null check (sequence > 0), minimum_age smallint check (minimum_age between 0 and 30), maximum_age smallint check (maximum_age between 0 and 30),
  status public.record_status not null default 'active', created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null, updated_by uuid references auth.users(id) on delete set null,
  foreign key (organization_id, school_id) references public.schools(organization_id, id) on delete restrict,
  unique (school_id, sequence), unique (organization_id, school_id, id), unique (organization_id, id),
  check (maximum_age is null or minimum_age is null or maximum_age >= minimum_age)
);

create table public.subjects (
  id uuid primary key default gen_random_uuid(), organization_id uuid not null, school_id uuid not null,
  code text not null check (length(btrim(code)) between 1 and 32), name text not null check (length(btrim(name)) between 1 and 120), description text,
  status public.record_status not null default 'active', created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null, updated_by uuid references auth.users(id) on delete set null,
  foreign key (organization_id, school_id) references public.schools(organization_id, id) on delete restrict,
  unique (organization_id, school_id, id), unique (organization_id, id)
);

create table public.sections (
  id uuid primary key default gen_random_uuid(), organization_id uuid not null, school_id uuid not null, campus_id uuid not null,
  academic_year_id uuid not null, academic_term_id uuid, grade_level_id uuid not null, homeroom_room_id uuid,
  code text not null check (length(btrim(code)) between 1 and 32), name text not null check (length(btrim(name)) between 1 and 120),
  capacity integer not null check (capacity between 1 and 10000), start_date date not null, end_date date not null,
  status public.record_status not null default 'inactive', created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null, updated_by uuid references auth.users(id) on delete set null,
  foreign key (organization_id, school_id) references public.schools(organization_id, id) on delete restrict,
  foreign key (organization_id, campus_id) references public.campuses(organization_id, id) on delete restrict,
  foreign key (school_id, campus_id) references public.campuses(school_id, id) on delete restrict,
  foreign key (organization_id, school_id, academic_year_id) references public.academic_years(organization_id, school_id, id) on delete restrict,
  foreign key (organization_id, academic_year_id, academic_term_id) references public.academic_terms(organization_id, academic_year_id, id) on delete restrict,
  foreign key (organization_id, school_id, grade_level_id) references public.grade_levels(organization_id, school_id, id) on delete restrict,
  foreign key (organization_id, school_id, campus_id, homeroom_room_id) references public.rooms(organization_id, school_id, campus_id, id) on delete restrict,
  unique (organization_id, id), check (end_date >= start_date)
);

create index staff_profiles_membership_idx on public.staff_profiles(organization_membership_id);
create index staff_profiles_scope_idx on public.staff_profiles(organization_id, school_id, campus_id, status);
create index staff_profiles_org_campus_idx on public.staff_profiles(organization_id, campus_id);
create index staff_profiles_school_campus_idx on public.staff_profiles(school_id, campus_id);
create unique index staff_profiles_org_staff_number_normalized_idx on public.staff_profiles(organization_id,lower(btrim(staff_number)));
create index buildings_org_school_idx on public.buildings(organization_id, school_id);
create index buildings_org_campus_idx on public.buildings(organization_id, campus_id);
create index buildings_school_campus_idx on public.buildings(school_id, campus_id);
create index buildings_scope_idx on public.buildings(organization_id, school_id, campus_id, status);
create index rooms_building_idx on public.rooms(organization_id, school_id, campus_id, building_id);
create index rooms_scope_idx on public.rooms(organization_id, school_id, campus_id, status);
create index grade_levels_scope_idx on public.grade_levels(organization_id, school_id, status);
create index subjects_scope_idx on public.subjects(organization_id, school_id, status);
create unique index grade_levels_school_code_normalized_idx on public.grade_levels(school_id,lower(btrim(code)));
create unique index grade_levels_school_name_normalized_idx on public.grade_levels(school_id,lower(btrim(name)));
create unique index subjects_school_code_normalized_idx on public.subjects(school_id,lower(btrim(code)));
create unique index subjects_school_name_normalized_idx on public.subjects(school_id,lower(btrim(name)));
create unique index sections_year_campus_code_normalized_idx on public.sections(academic_year_id,campus_id,lower(btrim(code)));
create unique index sections_year_campus_name_normalized_idx on public.sections(academic_year_id,campus_id,lower(btrim(name)));
create index sections_school_idx on public.sections(organization_id, school_id);
create index sections_campus_idx on public.sections(organization_id, campus_id);
create index sections_school_campus_idx on public.sections(school_id, campus_id);
create index sections_year_idx on public.sections(organization_id, school_id, academic_year_id);
create index sections_term_idx on public.sections(organization_id, academic_year_id, academic_term_id) where academic_term_id is not null;
create index sections_grade_idx on public.sections(organization_id, school_id, grade_level_id);
create index sections_room_idx on public.sections(organization_id, school_id, campus_id, homeroom_room_id, status) where homeroom_room_id is not null;
create index sections_scope_idx on public.sections(organization_id, school_id, campus_id, status);
alter table public.audit_log add column command_id uuid;
alter table public.event_outbox add column command_id uuid;
create unique index audit_log_academic_command_id_key on public.audit_log(command_id) where command_id is not null;
create unique index event_outbox_academic_command_id_key on public.event_outbox(command_id) where command_id is not null;
create index staff_profiles_created_by_idx on public.staff_profiles(created_by); create index staff_profiles_updated_by_idx on public.staff_profiles(updated_by);
create index buildings_created_by_idx on public.buildings(created_by); create index buildings_updated_by_idx on public.buildings(updated_by);
create index rooms_created_by_idx on public.rooms(created_by); create index rooms_updated_by_idx on public.rooms(updated_by);
create index grade_levels_created_by_idx on public.grade_levels(created_by); create index grade_levels_updated_by_idx on public.grade_levels(updated_by);
create index subjects_created_by_idx on public.subjects(created_by); create index subjects_updated_by_idx on public.subjects(updated_by);
create index sections_created_by_idx on public.sections(created_by); create index sections_updated_by_idx on public.sections(updated_by);

create trigger staff_profiles_updated_at before update on public.staff_profiles for each row execute function public.set_updated_at();
create trigger buildings_updated_at before update on public.buildings for each row execute function public.set_updated_at();
create trigger rooms_updated_at before update on public.rooms for each row execute function public.set_updated_at();
create trigger grade_levels_updated_at before update on public.grade_levels for each row execute function public.set_updated_at();
create trigger subjects_updated_at before update on public.subjects for each row execute function public.set_updated_at();
create trigger sections_updated_at before update on public.sections for each row execute function public.set_updated_at();

-- =============================================================================
-- Permissions
-- =============================================================================
insert into public.permissions(code,module,description) values
 ('staff_profiles.view','academics','View staff employment profiles within assigned scope'),
 ('staff_profiles.manage','academics','Manage staff employment profiles within assigned scope'),
 ('academic_structure.view','academics','View academic structure within assigned scope'),
 ('academic_structure.manage','academics','Manage academic structure within assigned scope');

-- =============================================================================
-- Authorization and atomic audit/outbox helpers
-- =============================================================================
create or replace function app_auth.can_read_catalog(o uuid, s uuid, permission_code text) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.organization_memberships m join public.role_assignments ra on (ra.organization_id,ra.organization_membership_id)=(m.organization_id,m.id)
 join public.roles r on (r.organization_id,r.id)=(ra.organization_id,ra.role_id) join public.role_permissions rp on (rp.organization_id,rp.role_id)=(r.organization_id,r.id)
 join public.permissions p on p.id=rp.permission_id left join public.campuses c on c.id=ra.campus_id and c.organization_id=ra.organization_id
 where m.organization_id=o and m.user_id=auth.uid() and m.status='active' and m.left_at is null and r.status='active' and ra.status='active'
 and ra.starts_at<=now() and (ra.ends_at is null or ra.ends_at>now()) and p.code=permission_code and (ra.school_id is null or ra.school_id=s or c.school_id=s)); $$;

create or replace function app_auth.can_manage_catalog(o uuid,s uuid) returns boolean language sql stable security definer set search_path='' as $$
 select app_auth.has_permission(o,'academic_structure.manage',s,null); $$;

create or replace function app_auth.write_academic_change(o uuid, actor uuid, action_name text, entity_name text, entity uuid, before_row jsonb, after_row jsonb) returns void
language plpgsql security definer set search_path='' as $$
declare
 cmd uuid:=gen_random_uuid();
 row_data jsonb:=coalesce(after_row,before_row,'{}'::jsonb);
 changed jsonb;
 school uuid:=(row_data->>'school_id')::uuid;
 campus uuid:=(row_data->>'campus_id')::uuid;
 academic_year uuid:=coalesce((row_data->>'academic_year_id')::uuid,case when entity_name='academic_year' then entity end);
 academic_term uuid:=coalesce((row_data->>'academic_term_id')::uuid,case when entity_name='academic_term' then entity end);
 event_payload jsonb;
begin
 if school is null and academic_year is not null then
  select y.school_id
  into school
  from public.academic_years y
  where y.id = academic_year;
 end if;
 select coalesce(jsonb_agg(k order by k),'[]'::jsonb) into changed
 from (select keys.key k from jsonb_object_keys(coalesce(before_row,'{}'::jsonb)||coalesce(after_row,'{}'::jsonb)) as keys(key)
       where (before_row -> keys.key) is distinct from (after_row -> keys.key)) changed_keys;
 event_payload:=jsonb_strip_nulls(jsonb_build_object(
  'command_id',cmd,'actor_user_id',actor,'organization_id',o,'entity_id',entity,'aggregate_id',entity,
  'school_id',school,'campus_id',campus,'academic_year_id',academic_year,'academic_term_id',academic_term,
  'changed_fields',changed,'before_status',before_row->>'status','after_status',after_row->>'status'));
 insert into public.audit_log(command_id,organization_id,actor_user_id,action,entity_type,entity_id,before_data,after_data)
 values(cmd,o,actor,action_name,entity_name,entity,before_row,after_row);
 insert into public.event_outbox(command_id,organization_id,event_type,aggregate_type,aggregate_id,payload)
 values(cmd,o,action_name,entity_name,entity,event_payload);
end $$;

-- Lock order for academic structure writes is parent before child:
-- organization -> school -> campus -> building -> academic year -> grade -> term -> room -> section.
-- Multiple rows at one level are locked by id. Parent archives and capacity changes retain
-- the same parent locks used by child creates/updates until their child checks and writes finish.
-- One guarded dispatcher keeps lifecycle rules identical across the narrow typed RPCs.
create or replace function app_auth.academic_foundation_command(command_name text, target_id uuid, args jsonb) returns uuid
language plpgsql security definer set search_path='' as $$
declare a uuid:=auth.uid(); o uuid; s uuid; c uuid; oldj jsonb; newj jsonb; rid uuid:=coalesce(target_id,gen_random_uuid()); ystatus public.academic_period_status; ystart date; yend date; st public.record_status; entity_name text;
begin
 if a is null then
  raise exception using
   errcode = '42501',
   message = 'an authenticated actor is required';
 end if;
 if command_name='building.create' then
  c := (args->>'campus_id')::uuid;
  select ca.organization_id,ca.school_id into o,s
  from public.campuses ca
  join public.schools sc on (sc.organization_id,sc.id)=(ca.organization_id,ca.school_id)
  join public.organizations org on org.id=ca.organization_id
  where ca.id=c and ca.status='active' and sc.status='active' and org.status='active'
  for update of ca,sc,org;
  if not found then
   raise exception using
    errcode = 'P0002',
    message = 'active building organization, school, and campus are required';
  end if;
  if not app_auth.has_permission(o,'academic_structure.manage',s,c) then
   raise exception using
    errcode = '42501',
    message = 'academic_structure.manage permission is required';
  end if;
  if coalesce((args->>'status')::public.record_status,'active')='archived' then
   raise exception using errcode='22023',message='building initial status cannot be archived';
  end if;
  insert into public.buildings(
   id,organization_id,school_id,campus_id,code,name,opened_on,status,created_by,updated_by
  ) values(
   rid,o,s,c,args->>'code',args->>'name',(args->>'opened_on')::date,
   coalesce((args->>'status')::public.record_status,'active'),a,a
  ) returning to_jsonb(buildings.*) into newj;
  entity_name:='building';
 elsif command_name='room.create' then
  select b.organization_id,b.school_id,b.campus_id into o,s,c from public.buildings b where b.id=(args->>'building_id')::uuid;
  if not found then
   raise exception using
    errcode = 'P0002',
    message = 'active room organization, school, campus, and building are required';
  end if;
  perform 1 from public.organizations org where org.id=o and org.status='active' for update;
  if found then
   perform 1 from public.schools sc where (sc.organization_id,sc.id)=(o,s) and sc.status='active' for update;
  end if;
  if found then
   perform 1 from public.campuses ca where (ca.organization_id,ca.school_id,ca.id)=(o,s,c) and ca.status='active' for update;
  end if;
  if found then
   perform 1 from public.buildings b where (b.organization_id,b.school_id,b.campus_id,b.id)=(o,s,c,(args->>'building_id')::uuid) and b.status='active' for update;
  end if;
  if not found then
   raise exception using
    errcode = 'P0002',
    message = 'active room organization, school, campus, and building are required';
  end if;
  if not app_auth.has_permission(o,'academic_structure.manage',s,c) then
   raise exception using
    errcode = '42501',
    message = 'academic_structure.manage permission is required';
  end if;
  if coalesce((args->>'status')::public.record_status,'active')='archived' then
   raise exception using errcode='22023',message='room initial status cannot be archived';
  end if;
  insert into public.rooms(
   id,organization_id,school_id,campus_id,building_id,code,name,room_type,capacity,status,created_by,updated_by
  ) values(
   rid,o,s,c,(args->>'building_id')::uuid,args->>'code',args->>'name',args->>'room_type',
   (args->>'capacity')::int,coalesce((args->>'status')::public.record_status,'active'),a,a
  ) returning to_jsonb(rooms.*) into newj;
  entity_name:='room';
 elsif command_name='grade_level.create' or command_name='subject.create' then
  s := (args->>'school_id')::uuid;
  select sc.organization_id into o
  from public.schools sc
  join public.organizations org on org.id=sc.organization_id
  where sc.id=s and sc.status='active' and org.status='active'
  for update of sc,org;
  if not found then
   raise exception using errcode='P0002',message='active catalog organization and school are required';
  end if;
  if not app_auth.can_manage_catalog(o,s) then
   raise exception using errcode='42501',message='school-scoped academic_structure.manage permission is required';
  end if;
  if command_name='grade_level.create' then
   if coalesce((args->>'status')::public.record_status,'active')='archived' then
    raise exception using errcode='22023',message='grade level initial status cannot be archived';
   end if;
   if exists (
    select 1 from public.grade_levels g
    where g.school_id=s and lower(btrim(g.code))=lower(btrim(args->>'code'))
   ) then
    raise exception using errcode='23505',message='grade level normalized code already exists';
   end if;
   if exists (
    select 1 from public.grade_levels g
    where g.school_id=s and lower(btrim(g.name))=lower(btrim(args->>'name'))
   ) then
    raise exception using errcode='23505',message='grade level normalized name already exists';
   end if;
   insert into public.grade_levels(
    id,organization_id,school_id,code,name,sequence,minimum_age,maximum_age,status,created_by,updated_by
   ) values(
    rid,o,s,args->>'code',args->>'name',(args->>'sequence')::smallint,
    (args->>'minimum_age')::smallint,(args->>'maximum_age')::smallint,
    coalesce((args->>'status')::public.record_status,'active'),a,a
   ) returning to_jsonb(grade_levels.*) into newj;
   entity_name:='grade_level';
  else
   if coalesce((args->>'status')::public.record_status,'active')='archived' then
    raise exception using errcode='22023',message='subject initial status cannot be archived';
   end if;
   if exists (
    select 1 from public.subjects u
    where u.school_id=s and lower(btrim(u.code))=lower(btrim(args->>'code'))
   ) then
    raise exception using errcode='23505',message='subject normalized code already exists';
   end if;
   if exists (
    select 1 from public.subjects u
    where u.school_id=s and lower(btrim(u.name))=lower(btrim(args->>'name'))
   ) then
    raise exception using errcode='23505',message='subject normalized name already exists';
   end if;
   insert into public.subjects(
    id,organization_id,school_id,code,name,description,status,created_by,updated_by
   ) values(
    rid,o,s,args->>'code',args->>'name',args->>'description',
    coalesce((args->>'status')::public.record_status,'active'),a,a
   ) returning to_jsonb(subjects.*) into newj;
   entity_name:='subject';
  end if;
 elsif command_name='staff_profile.create' then
  select m.organization_id into o
  from public.organization_memberships m join public.organizations org on org.id=m.organization_id
  where m.id=(args->>'membership_id')::uuid and m.status='active' and m.left_at is null and org.status='active'
  for update of m,org;
  if not found then
   raise exception using
    errcode = 'P0002',
    message = 'active staff organization and membership are required';
  end if;
  s:=(args->>'school_id')::uuid; c:=(args->>'campus_id')::uuid;
  if s is not null then
   perform 1 from public.schools x where (x.organization_id,x.id)=(o,s) and x.status='active' for update;
   if not found then
    raise exception using
     errcode = 'P0002',
     message = 'active home school in membership organization is required';
   end if;
   end if;
  if c is not null then
   perform 1 from public.campuses x where (x.organization_id,x.school_id,x.id)=(o,s,c) and x.status='active' for update;
   if not found then
    raise exception using
     errcode = 'P0002',
     message = 'active home campus in home school is required';
   end if;
   end if;
  if not app_auth.has_permission(o,'staff_profiles.manage',s,c) then
   raise exception using
    errcode = '42501',
    message = 'staff_profiles.manage permission is required';
  end if;
  if coalesce((args->>'status')::public.record_status,'active')='archived' then
   raise exception using errcode='22023',message='staff profile initial status cannot be archived';
  end if;
  insert into public.staff_profiles(
   id,organization_id,organization_membership_id,school_id,campus_id,staff_number,
   employment_type,job_title,department,hire_date,status,created_by,updated_by
  ) values(
   rid,o,(args->>'membership_id')::uuid,s,c,args->>'staff_number',args->>'employment_type',
   args->>'job_title',args->>'department',(args->>'hire_date')::date,
   coalesce((args->>'status')::public.record_status,'active'),a,a
  ) returning to_jsonb(staff_profiles.*) into newj;
  entity_name:='staff_profile';
 elsif command_name='section.create' then
  select y.organization_id,y.school_id,y.status,y.start_date,y.end_date into o,s,ystatus,ystart,yend
  from public.academic_years y where y.id=(args->>'academic_year_id')::uuid;
  if not found then
   raise exception using
    errcode = 'P0002',
    message = 'active section organization, school, and academic year are required';
  end if;
  c:=(args->>'campus_id')::uuid;
  perform 1 from public.organizations org where org.id=o and org.status='active' for update;
  if found then
   perform 1 from public.schools sc where (sc.organization_id,sc.id)=(o,s) and sc.status='active' for update;
  end if;
  if not found then
   raise exception using
    errcode = 'P0002',
    message = 'active section organization, school, and academic year are required';
  end if;
  perform 1 from public.campuses x where (x.organization_id,x.school_id,x.id)=(o,s,c) and x.status='active' for update;
  if not found then
   raise exception using
    errcode = 'P0002',
    message = 'active section campus in academic-year school is required';
  end if;
  select y.status,y.start_date,y.end_date into ystatus,ystart,yend from public.academic_years y
   where (y.organization_id,y.school_id,y.id)=(o,s,(args->>'academic_year_id')::uuid) for update;
  if not found then
   raise exception using
    errcode = 'P0002',
    message = 'active section organization, school, and academic year are required';
  end if;
  perform 1 from public.grade_levels x where (x.organization_id,x.school_id,x.id)=(o,s,(args->>'grade_level_id')::uuid) and x.status='active' for update;
  if not found then
   raise exception using
    errcode = 'P0002',
    message = 'active section grade level in academic-year school is required';
  end if;
  st:=coalesce((args->>'status')::public.record_status,'inactive');
  if ystatus in ('closed','archived') or (st='active' and ystatus<>'active') then
   raise exception using
    errcode = '22023',
    message = 'academic year status does not permit section use';
  end if;
  if (args->>'start_date')::date<ystart or (args->>'end_date')::date>yend then
   raise exception using
    errcode = '22023',
    message = 'section dates must be within academic year';
  end if;
  if args->>'academic_term_id' is not null then
   perform 1 from public.academic_terms t where (t.organization_id,t.academic_year_id,t.id)=(o,(args->>'academic_year_id')::uuid,(args->>'academic_term_id')::uuid)
    and t.status in ('draft','active') and (st<>'active' or t.status='active') and (args->>'start_date')::date>=t.start_date and (args->>'end_date')::date<=t.end_date for update;
   if not found then
    raise exception using
     errcode = '22023',
     message = 'academic term scope, status, or dates do not permit section use';
   end if;
   end if;
  if args->>'homeroom_room_id' is not null then
   perform 1 from public.rooms x where (x.organization_id,x.school_id,x.campus_id,x.id)=(o,s,c,(args->>'homeroom_room_id')::uuid)
    and x.status='active' and x.capacity>=(args->>'capacity')::int for update;
   if not found then
    raise exception using
     errcode = '22023',
     message = 'active homeroom in section campus with sufficient capacity is required';
   end if;
   end if;
  if not app_auth.has_permission(o,'academic_structure.manage',s,c) then
   raise exception using
    errcode = '42501',
    message = 'academic_structure.manage permission is required';
  end if;
  if st='archived' then
   raise exception using errcode='22023',message='section initial status cannot be archived';
  end if;
  if exists (
   select 1 from public.sections x
   where x.academic_year_id=(args->>'academic_year_id')::uuid
    and x.campus_id=c
    and lower(btrim(x.code))=lower(btrim(args->>'code'))
  ) then
   raise exception using errcode='23505',message='section normalized code already exists';
  end if;
  if exists (
   select 1 from public.sections x
   where x.academic_year_id=(args->>'academic_year_id')::uuid
    and x.campus_id=c
    and lower(btrim(x.name))=lower(btrim(args->>'name'))
  ) then
   raise exception using errcode='23505',message='section normalized name already exists';
  end if;
  insert into public.sections(
   id,organization_id,school_id,campus_id,academic_year_id,academic_term_id,
   grade_level_id,homeroom_room_id,code,name,capacity,start_date,end_date,status,created_by,updated_by
  ) values(
   rid,o,s,c,(args->>'academic_year_id')::uuid,(args->>'academic_term_id')::uuid,
   (args->>'grade_level_id')::uuid,(args->>'homeroom_room_id')::uuid,
   args->>'code',args->>'name',(args->>'capacity')::int,
   (args->>'start_date')::date,(args->>'end_date')::date,st,a,a
  ) returning to_jsonb(sections.*) into newj;
  entity_name:='section';
 else
  raise exception 'unsupported command %',command_name;
 end if;
 perform app_auth.write_academic_change(o,a,regexp_replace(command_name,'\.create$','.created'),entity_name,rid,oldj,newj); return rid;
end $$;

-- Create command wrappers. Tenant and actor values are never wrapper inputs; the
-- private command derives both before authorization and insertion.
create function public.create_building(
 campus_id uuid, code text, name text, opened_on date default null,
 status public.record_status default 'active'
) returns uuid language sql security definer set search_path='' as $$
 select app_auth.academic_foundation_command(
  'building.create',null,
  jsonb_build_object('campus_id',campus_id,'code',code,'name',name,'opened_on',opened_on,'status',status)
 );
$$;
create function public.create_room(
 building_id uuid, code text, name text, room_type text, capacity int,
 status public.record_status default 'active'
) returns uuid language sql security definer set search_path='' as $$
 select app_auth.academic_foundation_command(
  'room.create',null,
  jsonb_build_object('building_id',building_id,'code',code,'name',name,'room_type',room_type,'capacity',capacity,'status',status)
 );
$$;
create function public.create_grade_level(
 school_id uuid, code text, name text, sequence smallint,
 minimum_age smallint default null, maximum_age smallint default null,
 status public.record_status default 'active'
) returns uuid language sql security definer set search_path='' as $$
 select app_auth.academic_foundation_command(
  'grade_level.create',null,
  jsonb_build_object('school_id',school_id,'code',code,'name',name,'sequence',sequence,
                     'minimum_age',minimum_age,'maximum_age',maximum_age,'status',status)
 );
$$;
create function public.create_subject(
 school_id uuid, code text, name text, description text default null,
 status public.record_status default 'active'
) returns uuid language sql security definer set search_path='' as $$
 select app_auth.academic_foundation_command(
  'subject.create',null,
  jsonb_build_object('school_id',school_id,'code',code,'name',name,'description',description,'status',status)
 );
$$;
create function public.create_staff_profile(
 membership_id uuid, school_id uuid, campus_id uuid, staff_number text,
 employment_type text, job_title text default null, department text default null,
 hire_date date default null, status public.record_status default 'active'
) returns uuid language sql security definer set search_path='' as $$
 select app_auth.academic_foundation_command(
  'staff_profile.create',null,
  jsonb_build_object('membership_id',membership_id,'school_id',school_id,'campus_id',campus_id,
                     'staff_number',staff_number,'employment_type',employment_type,'job_title',job_title,
                     'department',department,'hire_date',hire_date,'status',status)
 );
$$;
create function public.create_section(
 campus_id uuid, academic_year_id uuid, academic_term_id uuid, grade_level_id uuid,
 homeroom_room_id uuid, code text, name text, capacity int, start_date date,
 end_date date, status public.record_status default 'inactive'
) returns uuid language sql security definer set search_path='' as $$
 select app_auth.academic_foundation_command(
  'section.create',null,
  jsonb_build_object('campus_id',campus_id,'academic_year_id',academic_year_id,
                     'academic_term_id',academic_term_id,'grade_level_id',grade_level_id,
                     'homeroom_room_id',homeroom_room_id,'code',code,'name',name,
                     'capacity',capacity,'start_date',start_date,'end_date',end_date,'status',status)
 );
$$;

-- Generic private mutation function powers narrow update/archive wrappers and enforces lifecycle.
create or replace function app_auth.assert_active_academic_parents(
 entity_name text,
 target uuid
) returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
 if entity_name = 'building' and not exists (
  select 1
  from public.buildings b
  join public.campuses c
   on (c.organization_id, c.school_id, c.id) =
      (b.organization_id, b.school_id, b.campus_id)
  join public.schools s
   on (s.organization_id, s.id) = (b.organization_id, b.school_id)
  join public.organizations o on o.id = b.organization_id
  where b.id = target
   and o.status = 'active'
   and s.status = 'active'
   and c.status = 'active'
 ) then
  raise exception using
   errcode = 'P0002',
   message = 'active building organization, school, and campus are required';
 elsif entity_name = 'room' and not exists (
  select 1
  from public.rooms r
  join public.buildings b
   on (b.organization_id, b.school_id, b.campus_id, b.id) =
      (r.organization_id, r.school_id, r.campus_id, r.building_id)
  join public.campuses c
   on (c.organization_id, c.school_id, c.id) =
      (r.organization_id, r.school_id, r.campus_id)
  join public.schools s
   on (s.organization_id, s.id) = (r.organization_id, r.school_id)
  join public.organizations o on o.id = r.organization_id
  where r.id = target
   and o.status = 'active'
   and s.status = 'active'
   and c.status = 'active'
   and b.status = 'active'
 ) then
  raise exception using
   errcode = 'P0002',
   message = 'active room organization, school, campus, and building are required';
 elsif entity_name in ('grade_level', 'subject') and not exists (
  select 1
  from public.schools s
  join public.organizations o on o.id = s.organization_id
  where s.id = case
   when entity_name = 'grade_level' then (
    select school_id from public.grade_levels where id = target
   )
   else (
    select school_id from public.subjects where id = target
   )
  end
   and s.status = 'active'
   and o.status = 'active'
 ) then
  raise exception using
   errcode = 'P0002',
   message = 'active catalog organization and school are required';
 elsif entity_name = 'staff_profile' and not exists (
  select 1
  from public.staff_profiles p
  join public.organization_memberships m
   on (m.organization_id, m.id) =
      (p.organization_id, p.organization_membership_id)
  join public.organizations o on o.id = p.organization_id
  left join public.schools s
   on (s.organization_id, s.id) = (p.organization_id, p.school_id)
  left join public.campuses c
   on (c.organization_id, c.school_id, c.id) =
      (p.organization_id, p.school_id, p.campus_id)
  where p.id = target
   and o.status = 'active'
   and m.status = 'active'
   and m.left_at is null
   and (p.school_id is null or s.status = 'active')
   and (p.campus_id is null or c.status = 'active')
 ) then
  raise exception using
   errcode = 'P0002',
   message = 'active staff organization, membership, school, and campus are required';
 elsif entity_name = 'section' and not exists (
  select 1
  from public.sections x
  join public.organizations o on o.id = x.organization_id
  join public.schools s
   on (s.organization_id, s.id) = (x.organization_id, x.school_id)
  join public.campuses c
   on (c.organization_id, c.school_id, c.id) =
      (x.organization_id, x.school_id, x.campus_id)
  join public.grade_levels g
   on (g.organization_id, g.school_id, g.id) =
      (x.organization_id, x.school_id, x.grade_level_id)
  join public.academic_years y
   on (y.organization_id, y.school_id, y.id) =
      (x.organization_id, x.school_id, x.academic_year_id)
  left join public.academic_terms t
   on (t.organization_id, t.academic_year_id, t.id) =
      (x.organization_id, x.academic_year_id, x.academic_term_id)
  left join public.rooms r
   on (r.organization_id, r.school_id, r.campus_id, r.id) =
      (x.organization_id, x.school_id, x.campus_id, x.homeroom_room_id)
  where x.id = target
   and o.status = 'active'
   and s.status = 'active'
   and c.status = 'active'
   and g.status = 'active'
   and y.status in ('draft', 'active')
   and (x.status <> 'active' or y.status = 'active')
   and (
    x.academic_term_id is null
    or (
     t.status in ('draft', 'active')
     and (x.status <> 'active' or t.status = 'active')
    )
   )
   and (x.homeroom_room_id is null or r.status = 'active')
 ) then
  raise exception using
   errcode = 'P0002',
   message = 'active section parents in the immutable composite scope are required';
 end if;
end
$$;

create or replace function app_auth.mutate_academic(
 entity_name text, target uuid, changes jsonb, archive boolean default false
) returns uuid language plpgsql security definer set search_path='' as $$
declare
 a uuid:=auth.uid();
 o uuid;
 s uuid;
 c uuid;
 oldj jsonb;
 newj jsonb;
 cap int;
 ns uuid;
 nc uuid;
 nstatus public.record_status;
 current_status public.record_status;
 new_opened_on date;
 new_closed_on date;
 new_floor_label text;
 new_minimum_age smallint;
 new_maximum_age smallint;
 new_description text;
 new_term_id uuid;
 new_room_id uuid;
 new_start_date date;
 new_end_date date;
begin
 if a is null then
  raise exception using errcode='42501',message='an authenticated actor is required';
 end if;

 -- Resolve and lock the target before parent validation or authorization. This
 -- prevents absent rows from falling through to NULL-derived scope checks.
 case entity_name
  when 'staff_profile' then
   select status into current_status
   from public.staff_profiles
   where id=target
   for update;
  when 'building' then
   select status into current_status
   from public.buildings
   where id=target
   for update;
  when 'room' then
   select status into current_status
   from public.rooms
   where id=target
   for update;
  when 'grade_level' then
   select status into current_status
   from public.grade_levels
   where id=target
   for update;
  when 'subject' then
   select status into current_status
   from public.subjects
   where id=target
   for update;
  when 'section' then
   select status into current_status
   from public.sections
   where id=target
   for update;
  else
   raise exception 'unsupported entity';
 end case;

 if not found then
  raise exception using
   errcode = 'P0002',
   message = case entity_name
    when 'staff_profile' then 'staff profile not found'
    when 'building' then 'building not found'
    when 'room' then 'room not found'
    when 'grade_level' then 'grade level not found'
    when 'subject' then 'subject not found'
    when 'section' then 'section not found'
   end;
 end if;

 if current_status = 'archived' then
  raise exception using errcode='22023',message=entity_name||' is archived and immutable';
 end if;
 if not archive then
  perform app_auth.assert_active_academic_parents(entity_name, target);
 end if;

 -- Building scope is immutable. Parent locks precede authorization and mutation.
 if entity_name='building' then
  select organization_id,school_id,campus_id into o,s,c from public.buildings b where id=target;
  perform 1 from public.organizations org where org.id=o and org.status='active' for update;
  if found then
   perform 1 from public.schools sc where (sc.organization_id,sc.id)=(o,s) and sc.status='active' for update;
  end if;
  if found then
   perform 1 from public.campuses ca where (ca.organization_id,ca.school_id,ca.id)=(o,s,c) and ca.status='active' for update;
  end if;
  if found then
   select to_jsonb(b.*)
   into oldj
   from public.buildings b
   where (b.organization_id,b.school_id,b.campus_id,b.id)=(o,s,c,target)
   for update;
  end if;
  if not found then
   raise exception using
    errcode = 'P0002',
    message = 'active building organization, school, and campus are required';
  end if;
  if oldj->>'status'='archived' then
   raise exception using
    errcode = '22023',
    message = 'building is archived and immutable';
  end if;
  if not app_auth.has_permission(o,'academic_structure.manage',s,c) then
   raise exception using
    errcode = '42501',
    message = 'permission denied';
  end if;
  if not archive and changes->>'status'='archived' then
   raise exception using
    errcode = '22023',
    message = 'use archive_building to archive a building';
  end if;
  perform 1 from public.rooms where building_id=target order by id for update;
  if archive and exists (
   select 1 from public.rooms where building_id=target and status='active'
  ) then
   raise exception 'building has active rooms';
  end if;
  new_opened_on:=case when coalesce((changes->>'set_opened_on')::boolean,false) then (changes->>'opened_on')::date else (oldj->>'opened_on')::date end;
  new_closed_on:=case when coalesce((changes->>'set_closed_on')::boolean,false) then (changes->>'closed_on')::date else (oldj->>'closed_on')::date end;
  if new_opened_on is not null and new_closed_on is not null and new_closed_on<new_opened_on then
   raise exception using errcode='22023',message='building closed date must not precede opened date';
  end if;
  update public.buildings set code=coalesce(changes->>'code',code),name=coalesce(changes->>'name',name),
   opened_on=new_opened_on,closed_on=new_closed_on,
   status=case when archive then 'archived' else coalesce((changes->>'status')::public.record_status,status) end,updated_by=a
   where id=target returning to_jsonb(buildings.*) into newj;
 -- Room scope and building identity are immutable.
 elsif entity_name='room' then
  select organization_id,school_id,campus_id,to_jsonb(x.*) into o,s,c,oldj from public.rooms x where id=target;
  if oldj->>'status'='archived' then
   raise exception using
    errcode = '22023',
    message = 'room is archived and immutable';
  end if;
  perform 1 from public.organizations org where org.id=o and org.status='active' for update;
  if found then
   perform 1 from public.schools sc where (sc.organization_id,sc.id)=(o,s) and sc.status='active' for update;
  end if;
  if found then
   perform 1 from public.campuses ca where (ca.organization_id,ca.school_id,ca.id)=(o,s,c) and ca.status='active' for update;
  end if;
  if found then
   perform 1 from public.buildings b where (b.organization_id,b.school_id,b.campus_id,b.id)=(o,s,c,(oldj->>'building_id')::uuid) and b.status='active' for update;
  end if;
  if found then
   select to_jsonb(x.*)
   into oldj
   from public.rooms x
   where (x.organization_id,x.school_id,x.campus_id,x.id)=(o,s,c,target)
   for update;
  end if;
  if not found then
   raise exception using
    errcode = 'P0002',
    message = 'active room organization, school, campus, and building are required';
  end if;
  if not app_auth.has_permission(o,'academic_structure.manage',s,c) then
   raise exception using
    errcode = '42501',
    message = 'permission denied';
  end if;
  if not archive and changes->>'status'='archived' then
   raise exception using
    errcode = '22023',
    message = 'use archive_room to archive a room';
  end if;
  cap:=coalesce((changes->>'capacity')::int,(oldj->>'capacity')::int);
  if cap<=0 then
   raise exception using
    errcode = '22023',
    message = 'room capacity must be positive';
  end if;
  new_floor_label:=case when coalesce((changes->>'set_floor_label')::boolean,false) then changes->>'floor_label' else oldj->>'floor_label' end;
  perform 1 from public.sections where homeroom_room_id=target order by id for update;
  if exists (
   select 1
   from public.sections
   where homeroom_room_id=target
    and status='active'
    and (archive or capacity>cap)
  ) then
   raise exception 'active section prevents room archive/capacity reduction';
  end if;
  update public.rooms set code=coalesce(changes->>'code',code),name=coalesce(changes->>'name',name),
   room_type=coalesce(changes->>'room_type',room_type),capacity=cap,floor_label=new_floor_label,
   status=case when archive then 'archived' else coalesce((changes->>'status')::public.record_status,status) end,updated_by=a
   where id=target returning to_jsonb(rooms.*) into newj;
 -- Catalog mutations require organization- or school-scoped authorization.
 elsif entity_name='grade_level' then
  select organization_id,school_id into o,s from public.grade_levels x where id=target;
  perform 1 from public.organizations org where org.id=o and org.status='active' for update;
  if found then
   perform 1 from public.schools sc where (sc.organization_id,sc.id)=(o,s) and sc.status='active' for update;
  end if;
  if found then
   select to_jsonb(x.*)
   into oldj
   from public.grade_levels x
   where (x.organization_id,x.school_id,x.id)=(o,s,target)
   for update;
  end if;
  if not found then
   raise exception using
    errcode = 'P0002',
    message = 'active catalog organization and school are required';
  end if;
  if not app_auth.can_manage_catalog(o,s) then
   raise exception using
    errcode = '42501',
    message = 'permission denied';
  end if;
  if not archive and changes->>'status'='archived' then
   raise exception using
    errcode = '22023',
    message = 'use archive_grade_level to archive a grade level';
  end if;
  perform 1 from public.sections where grade_level_id=target order by id for update;
  if archive and exists (
   select 1
   from public.sections
   where grade_level_id=target and status='active'
  ) then
   raise exception 'grade level has active sections';
  end if;
  new_minimum_age:=case when coalesce((changes->>'set_minimum_age')::boolean,false) then (changes->>'minimum_age')::smallint else (oldj->>'minimum_age')::smallint end;
  new_maximum_age:=case when coalesce((changes->>'set_maximum_age')::boolean,false) then (changes->>'maximum_age')::smallint else (oldj->>'maximum_age')::smallint end;
  if coalesce(
   (changes->>'sequence')::smallint,
   (oldj->>'sequence')::smallint
  ) <= 0 then
   raise exception using
    errcode = '22023',
    message = 'grade level sequence must be positive';
  end if;
  if new_minimum_age is not null
   and (new_minimum_age < 0 or new_minimum_age > 30) then
   raise exception using
    errcode = '22023',
    message = 'grade level minimum age must be between 0 and 30';
  end if;
  if new_maximum_age is not null
   and (new_maximum_age < 0 or new_maximum_age > 30) then
   raise exception using
    errcode = '22023',
    message = 'grade level maximum age must be between 0 and 30';
  end if;
  if new_minimum_age is not null
   and new_maximum_age is not null
   and new_maximum_age < new_minimum_age then
   raise exception using
    errcode = '22023',
    message = 'grade level maximum age must not be below minimum age';
  end if;
  if exists (
   select 1
   from public.grade_levels g
   where g.school_id = s
    and g.id <> target
    and lower(btrim(g.code)) = lower(btrim(coalesce(changes->>'code', oldj->>'code')))
  ) then
   raise exception using
    errcode = '23505',
    message = 'grade level normalized code already exists';
  end if;
  if exists (
   select 1
   from public.grade_levels g
   where g.school_id = s
    and g.id <> target
    and lower(btrim(g.name)) = lower(btrim(coalesce(changes->>'name', oldj->>'name')))
  ) then
   raise exception using
    errcode = '23505',
    message = 'grade level normalized name already exists';
  end if;
  if exists (
   select 1
   from public.grade_levels g
   where g.school_id = s
    and g.id <> target
    and g.sequence = coalesce(
     (changes->>'sequence')::smallint,
     (oldj->>'sequence')::smallint
    )
  ) then
   raise exception using
    errcode = '23505',
    message = 'grade level sequence already exists';
  end if;
  update public.grade_levels set code=btrim(coalesce(changes->>'code',oldj->>'code')),name=btrim(coalesce(changes->>'name',oldj->>'name')),sequence=coalesce((changes->>'sequence')::smallint,(oldj->>'sequence')::smallint),
   minimum_age=new_minimum_age,maximum_age=new_maximum_age,status=case when archive then 'archived' else coalesce((changes->>'status')::public.record_status,status) end,updated_by=a
   where id=target returning to_jsonb(grade_levels.*) into newj;
 -- Subject organization and school are immutable.
 elsif entity_name='subject' then
  select organization_id,school_id,to_jsonb(x.*) into o,s,oldj from public.subjects x where id=target for update;
  perform 1 from public.schools sc join public.organizations org on org.id=sc.organization_id
   where (sc.organization_id,sc.id)=(o,s) and sc.status='active' and org.status='active' for update of sc,org;
  if not found then
   raise exception using
    errcode = 'P0002',
    message = 'active catalog organization and school are required';
  end if;
  if not app_auth.can_manage_catalog(o,s) then
   raise exception using
    errcode = '42501',
    message = 'permission denied';
  end if;
  if not archive and changes->>'status'='archived' then
   raise exception using
    errcode = '22023',
    message = 'use archive_subject to archive a subject';
  end if;
  new_description:=case when coalesce((changes->>'set_description')::boolean,false) then changes->>'description' else oldj->>'description' end;
  if exists (
   select 1
   from public.subjects u
   where u.school_id = s
    and u.id <> target
    and lower(btrim(u.code)) = lower(btrim(coalesce(changes->>'code', oldj->>'code')))
  ) then
   raise exception using
    errcode = '23505',
    message = 'subject normalized code already exists';
  end if;
  if exists (
   select 1
   from public.subjects u
   where u.school_id = s
    and u.id <> target
    and lower(btrim(u.name)) = lower(btrim(coalesce(changes->>'name', oldj->>'name')))
  ) then
   raise exception using
    errcode = '23505',
    message = 'subject normalized name already exists';
  end if;
  update public.subjects set code=btrim(coalesce(changes->>'code',oldj->>'code')),name=btrim(coalesce(changes->>'name',oldj->>'name')),description=new_description,
   status=case when archive then 'archived' else coalesce((changes->>'status')::public.record_status,status) end,updated_by=a
   where id=target returning to_jsonb(subjects.*) into newj;
 -- Section structural scope is immutable; optional term and room remain movable.
 elsif entity_name='section' then
  select organization_id,school_id,campus_id,to_jsonb(x.*) into o,s,c,oldj from public.sections x where id=target;
  if oldj->>'status'='archived' then
   raise exception using
    errcode = '22023',
    message = 'section is archived and immutable';
  end if;
  if archive then
   select to_jsonb(x.*) into oldj from public.sections x where id=target for update;
   if not app_auth.has_permission(o,'academic_structure.manage',s,c) then
    raise exception using
     errcode = '42501',
     message = 'permission denied';
   end if;
   update public.sections set status='archived',updated_by=a where id=target returning to_jsonb(sections.*) into newj;
  else
   perform 1 from public.organizations org where org.id=o and org.status='active' for update;
   if found then
    perform 1 from public.schools sc where (sc.organization_id,sc.id)=(o,s) and sc.status='active' for update;
   end if;
   if found then
    perform 1 from public.campuses ca where (ca.organization_id,ca.school_id,ca.id)=(o,s,c) and ca.status='active' for update;
   end if;
   if found then
    perform 1 from public.academic_years y where (y.organization_id,y.school_id,y.id)=(o,s,(oldj->>'academic_year_id')::uuid) and y.status in ('draft','active') for update;
   end if;
   if found then
    perform 1 from public.grade_levels g where (g.organization_id,g.school_id,g.id)=(o,s,(oldj->>'grade_level_id')::uuid) and g.status='active' for update;
   end if;
   if not found then
    raise exception using
     errcode = 'P0002',
     message = 'active section parents in the immutable composite scope are required';
   end if;
   select to_jsonb(x.*) into oldj from public.sections x where id=target;
   if not app_auth.has_permission(o,'academic_structure.manage',s,c) then
    raise exception using
     errcode = '42501',
     message = 'permission denied';
   end if;
   nstatus:=coalesce((changes->>'status')::public.record_status,(oldj->>'status')::public.record_status);
   if nstatus='archived' then
    raise exception using
     errcode = '22023',
     message = 'use archive_section to archive a section';
   end if;
   cap:=coalesce((changes->>'capacity')::int,(oldj->>'capacity')::int);
   if cap<1 or cap>10000 then
    raise exception using
     errcode = '22023',
     message = 'section capacity must be between 1 and 10000';
   end if;
   new_start_date:=coalesce((changes->>'start_date')::date,(oldj->>'start_date')::date);
   new_end_date:=coalesce((changes->>'end_date')::date,(oldj->>'end_date')::date);
   if new_end_date<new_start_date then
    raise exception using
     errcode = '22023',
     message = 'section end date must not precede start date';
   end if;
   if not exists(select 1 from public.academic_years y where (y.organization_id,y.school_id,y.id)=(o,s,(oldj->>'academic_year_id')::uuid)
      and y.status in ('draft','active') and (nstatus<>'active' or y.status='active') and new_start_date>=y.start_date and new_end_date<=y.end_date) then
    raise exception using errcode='22023',message='academic year status or dates do not permit section update';
   end if;
   new_term_id:=case when coalesce((changes->>'set_academic_term_id')::boolean,false) then (changes->>'academic_term_id')::uuid else (oldj->>'academic_term_id')::uuid end;
   if new_term_id is not null then
    perform 1 from public.academic_terms t where (t.organization_id,t.academic_year_id,t.id)=(o,(oldj->>'academic_year_id')::uuid,new_term_id)
     and t.status in ('draft','active') and (nstatus<>'active' or t.status='active') and new_start_date>=t.start_date and new_end_date<=t.end_date for update;
    if not found then
     raise exception using
      errcode = '22023',
      message = 'academic term scope, status, or dates do not permit section update';
    end if;
    end if;
   new_room_id:=case when coalesce((changes->>'set_homeroom_room_id')::boolean,false) then (changes->>'homeroom_room_id')::uuid else (oldj->>'homeroom_room_id')::uuid end;
   perform 1 from public.rooms r
    where (r.organization_id,r.school_id,r.campus_id)=(o,s,c)
     and r.id in (new_room_id,(oldj->>'homeroom_room_id')::uuid)
    order by r.id for update;
   if new_room_id is not null then
    if not exists(select 1 from public.rooms r where (r.organization_id,r.school_id,r.campus_id,r.id)=(o,s,c,new_room_id) and r.status='active' and r.capacity>=cap) then
     raise exception using errcode='22023',message='active homeroom in immutable campus with sufficient capacity is required';
    end if;
   end if;
   if exists (
    select 1
    from public.sections x
    where x.academic_year_id = (oldj->>'academic_year_id')::uuid
     and x.campus_id = c
     and x.id <> target
     and lower(btrim(x.code)) = lower(btrim(coalesce(changes->>'code', oldj->>'code')))
   ) then
    raise exception using
     errcode = '23505',
     message = 'section normalized code already exists';
   end if;
   if exists (
    select 1
    from public.sections x
    where x.academic_year_id = (oldj->>'academic_year_id')::uuid
     and x.campus_id = c
     and x.id <> target
     and lower(btrim(x.name)) = lower(btrim(coalesce(changes->>'name', oldj->>'name')))
   ) then
    raise exception using
     errcode = '23505',
     message = 'section normalized name already exists';
   end if;
   select to_jsonb(x.*) into oldj from public.sections x where id=target for update;
   update public.sections set code=btrim(coalesce(changes->>'code',oldj->>'code')),name=btrim(coalesce(changes->>'name',oldj->>'name')),
    capacity=cap,start_date=new_start_date,end_date=new_end_date,academic_term_id=new_term_id,homeroom_room_id=new_room_id,status=nstatus,updated_by=a
    where id=target returning to_jsonb(sections.*) into newj;
  end if;
 -- Staff identity is immutable; home placement moves require both-scope authority.
 elsif entity_name='staff_profile' then
  select organization_id,school_id,campus_id,to_jsonb(x.*) into o,s,c,oldj from public.staff_profiles x where id=target for update;
  if oldj->>'status'='archived' then
   raise exception using
    errcode = '22023',
    message = 'staff_profile is archived and immutable';
  end if;
  perform 1 from public.organization_memberships m join public.organizations org on org.id=m.organization_id
   where (m.organization_id,m.id)=(o,(oldj->>'organization_membership_id')::uuid) and m.status='active' and m.left_at is null and org.status='active'
   for update of m,org;
  if not found then
   raise exception using
    errcode = 'P0002',
    message = 'active staff organization and membership are required';
  end if;
  if s is not null then
   perform 1
   from public.schools sc
   where (sc.organization_id, sc.id) = (o, s)
    and sc.status = 'active'
   for update;
   if not found then
    raise exception using
     errcode = 'P0002',
     message = 'active old home school is required';
   end if;
  end if;
  if c is not null then
   perform 1
   from public.campuses ca
   where (ca.organization_id, ca.school_id, ca.id) = (o, s, c)
    and ca.status = 'active'
   for update;
   if not found then
    raise exception using
     errcode = 'P0002',
     message = 'active old home campus is required';
   end if;
  end if;
  if not app_auth.has_permission(o,'staff_profiles.manage',s,c) then
   raise exception using
    errcode = '42501',
    message = 'permission denied over old home scope';
  end if;
  ns:=case when coalesce((changes->>'set_school_id')::boolean,false) then (changes->>'school_id')::uuid else s end;
  nc:=case when coalesce((changes->>'set_campus_id')::boolean,false) then (changes->>'campus_id')::uuid else c end;
  if ns is null and nc is not null then
   raise exception using
    errcode = '22023',
    message = 'home campus requires a home school';
  end if;
  if ns is not null then
   perform 1
   from public.schools sc
   where (sc.organization_id, sc.id) = (o, ns)
    and sc.status = 'active'
   for update;
   if not found then
    raise exception using
     errcode = 'P0002',
     message = 'active new home school is required';
   end if;
  end if;
  if nc is not null then
   perform 1
   from public.campuses ca
   where (ca.organization_id, ca.school_id, ca.id) = (o, ns, nc)
    and ca.status = 'active'
   for update;
   if not found then
    raise exception using
     errcode = 'P0002',
     message = 'active new home campus is required';
   end if;
  end if;
  if not archive and not app_auth.has_permission(o,'staff_profiles.manage',ns,nc) then
   raise exception using
    errcode = '42501',
    message = 'permission denied over new home scope';
  end if;
  if not archive and changes->>'status'='archived' then
   raise exception using
    errcode = '22023',
    message = 'use archive_staff_profile to archive a staff profile';
  end if;
  new_opened_on:=case when coalesce((changes->>'set_hire_date')::boolean,false) then (changes->>'hire_date')::date else (oldj->>'hire_date')::date end;
  new_closed_on:=case when coalesce((changes->>'set_termination_date')::boolean,false) then (changes->>'termination_date')::date else (oldj->>'termination_date')::date end;
  if new_opened_on is not null
   and new_closed_on is not null
   and new_closed_on < new_opened_on then
   raise exception using
    errcode = '22023',
    message = 'staff termination date must not precede hire date';
  end if;
  if exists (
   select 1
   from public.staff_profiles p
   where p.organization_id = o
    and p.id <> target
    and lower(btrim(p.staff_number)) =
        lower(btrim(coalesce(changes->>'staff_number', oldj->>'staff_number')))
  ) then
   raise exception using
    errcode = '23505',
    message = 'normalized staff number already exists';
  end if;
  update public.staff_profiles set school_id=ns,campus_id=nc,
   staff_number=btrim(coalesce(changes->>'staff_number',oldj->>'staff_number')),employment_type=coalesce(changes->>'employment_type',oldj->>'employment_type'),
   job_title=case when coalesce((changes->>'set_job_title')::boolean,false) then changes->>'job_title' else oldj->>'job_title' end,
   department=case when coalesce((changes->>'set_department')::boolean,false) then changes->>'department' else oldj->>'department' end,
   hire_date=new_opened_on,termination_date=new_closed_on,
   status=case when archive then 'archived' else coalesce((changes->>'status')::public.record_status,status) end,updated_by=a
   where id=target returning to_jsonb(staff_profiles.*) into newj;
 else
  raise exception 'unsupported entity';
 end if;
 if oldj is null then
  raise exception using errcode='P0002',message='record not found';
 end if;
 -- The private writer appends one audit row and one outbox row in this transaction.
 perform app_auth.write_academic_change(
  o,a,entity_name||case when archive then '.archived' else '.updated' end,
  entity_name,target,oldj,newj
 );
 return target;
end $$;

-- Update wrappers expose only mutable fields. For nullable values, set_* = false
-- preserves the stored value; set_* = true writes the supplied value, including null.
create function public.update_building(
 id uuid, code text, name text, status public.record_status,
 opened_on date default null, set_opened_on boolean default false,
 closed_on date default null, set_closed_on boolean default false
) returns uuid language sql security definer set search_path='' as $$
 select app_auth.mutate_academic(
  'building',id,
  jsonb_build_object('code',code,'name',name,'status',status,'opened_on',opened_on,
                     'set_opened_on',set_opened_on,'closed_on',closed_on,'set_closed_on',set_closed_on)
 );
$$;
create function public.archive_building(id uuid) returns uuid
language sql security definer set search_path='' as $$
 select app_auth.mutate_academic('building',id,'{}',true);
$$;
create function public.update_room(
 id uuid, code text, name text, room_type text, capacity int, status public.record_status,
 floor_label text default null, set_floor_label boolean default false
) returns uuid language sql security definer set search_path='' as $$
 select app_auth.mutate_academic(
  'room',id,jsonb_build_object('code',code,'name',name,'room_type',room_type,
                               'capacity',capacity,'status',status,'floor_label',floor_label,
                               'set_floor_label',set_floor_label)
 );
$$;
create function public.archive_room(id uuid) returns uuid
language sql security definer set search_path='' as $$
 select app_auth.mutate_academic('room',id,'{}',true);
$$;
create function public.update_grade_level(
 id uuid, code text, name text, sequence smallint, status public.record_status,
 minimum_age smallint default null, set_minimum_age boolean default false,
 maximum_age smallint default null, set_maximum_age boolean default false
) returns uuid language sql security definer set search_path='' as $$
 select app_auth.mutate_academic(
  'grade_level',id,
  jsonb_build_object('code',code,'name',name,'sequence',sequence,'status',status,
                     'minimum_age',minimum_age,'set_minimum_age',set_minimum_age,
                     'maximum_age',maximum_age,'set_maximum_age',set_maximum_age)
 );
$$;
create function public.archive_grade_level(id uuid) returns uuid
language sql security definer set search_path='' as $$
 select app_auth.mutate_academic('grade_level',id,'{}',true);
$$;
create function public.update_subject(
 id uuid, code text, name text, description text, status public.record_status,
 set_description boolean default true
) returns uuid language sql security definer set search_path='' as $$
 select app_auth.mutate_academic(
  'subject',id,jsonb_build_object('code',code,'name',name,'description',description,
                                  'set_description',set_description,'status',status)
 );
$$;
create function public.archive_subject(id uuid) returns uuid
language sql security definer set search_path='' as $$
 select app_auth.mutate_academic('subject',id,'{}',true);
$$;
create function public.update_section(
 id uuid, code text, name text, capacity int, start_date date, end_date date,
 academic_term_id uuid, homeroom_room_id uuid, status public.record_status,
 set_academic_term_id boolean default false, set_homeroom_room_id boolean default false
) returns uuid language sql security definer set search_path='' as $$
 select app_auth.mutate_academic(
  'section',id,
  jsonb_build_object('code',code,'name',name,'capacity',capacity,'start_date',start_date,
                     'end_date',end_date,'academic_term_id',academic_term_id,
                     'set_academic_term_id',set_academic_term_id,'homeroom_room_id',homeroom_room_id,
                     'set_homeroom_room_id',set_homeroom_room_id,'status',status)
 );
$$;
create function public.archive_section(id uuid) returns uuid
language sql security definer set search_path='' as $$
 select app_auth.mutate_academic('section',id,'{}',true);
$$;
create function public.update_staff_profile(
 id uuid, staff_number text, employment_type text, status public.record_status,
 school_id uuid default null, set_school_id boolean default false,
 campus_id uuid default null, set_campus_id boolean default false,
 job_title text default null, set_job_title boolean default false,
 department text default null, set_department boolean default false,
 hire_date date default null, set_hire_date boolean default false,
 termination_date date default null, set_termination_date boolean default false
) returns uuid language sql security definer set search_path='' as $$
 select app_auth.mutate_academic(
  'staff_profile',id,
  jsonb_build_object('staff_number',staff_number,'employment_type',employment_type,'status',status,
                     'school_id',school_id,'set_school_id',set_school_id,
                     'campus_id',campus_id,'set_campus_id',set_campus_id,
                     'job_title',job_title,'set_job_title',set_job_title,
                     'department',department,'set_department',set_department,
                     'hire_date',hire_date,'set_hire_date',set_hire_date,
                     'termination_date',termination_date,'set_termination_date',set_termination_date)
 );
$$;
create function public.archive_staff_profile(id uuid) returns uuid
language sql security definer set search_path='' as $$
 select app_auth.mutate_academic('staff_profile',id,'{}',true);
$$;

-- =============================================================================
-- Academic-period commands
-- =============================================================================
-- Close the v0.1 academic-period direct-write boundary. Period changes are audited.
drop policy academic_years_write on public.academic_years; drop policy academic_terms_write on public.academic_terms;
revoke insert,update,delete on public.academic_years,public.academic_terms from authenticated;
create function public.create_academic_year(school_id uuid,name text,start_date date,end_date date,status public.academic_period_status default 'draft') returns uuid
language plpgsql security definer set search_path='' as $$
declare
 a uuid:=auth.uid(); o uuid; r uuid:=gen_random_uuid(); j jsonb;
begin
 if a is null then
  raise exception using
   errcode = '42501',
   message = 'an authenticated actor is required';
 end if;
 select s.organization_id into o from public.schools s join public.organizations org on org.id=s.organization_id
 where s.id=school_id and s.status='active' and org.status='active' for update of s,org;
 if not found then
  raise exception using
   errcode = 'P0002',
   message = 'active academic-year organization and school are required';
 end if;
 if not app_auth.has_permission(o,'academic_periods.manage',school_id,null) then
  raise exception using
   errcode = '42501',
   message = 'academic_periods.manage permission is required';
 end if;
 if status not in ('draft','active') then
  raise exception using errcode='22023',message='academic year initial status must be draft or active';
 end if;
 insert into public.academic_years(id,organization_id,school_id,name,start_date,end_date,status,created_by,updated_by)
 values(r,o,school_id,name,start_date,end_date,status,a,a) returning to_jsonb(academic_years.*) into j;
 perform app_auth.write_academic_change(o,a,'academic_year.created','academic_year',r,null,j); return r;
end $$;
create function public.update_academic_year(id uuid,name text,start_date date,end_date date) returns uuid
language plpgsql security definer set search_path='' as $$
declare a uuid:=auth.uid(); x public.academic_years%rowtype; j jsonb;
begin
 if a is null then
  raise exception using
   errcode = '42501',
   message = 'an authenticated actor is required';
 end if;
 select * into x from public.academic_years y where y.id=update_academic_year.id for update;
 if not found then
  raise exception using
   errcode = 'P0002',
   message = 'academic year not found';
 end if;
 perform 1 from public.schools s join public.organizations o on o.id=s.organization_id
 where (s.organization_id,s.id)=(x.organization_id,x.school_id) and s.status='active' and o.status='active' for update of s,o;
 if not found then
  raise exception using
   errcode = 'P0002',
   message = 'active academic-year organization and school are required';
 end if;
 if end_date<=start_date then
  raise exception using
   errcode = '22023',
   message = 'academic year end date must be after start date';
 end if;
 if exists(select 1 from public.sections s where s.academic_year_id=x.id and s.status<>'archived' and (s.start_date<update_academic_year.start_date or s.end_date>update_academic_year.end_date))
  or exists(select 1 from public.academic_terms t where t.academic_year_id=x.id and t.status<>'archived' and (t.start_date<update_academic_year.start_date or t.end_date>update_academic_year.end_date))
 then
  raise exception using
   errcode = '22023',
   message = 'academic year dates exclude non-archived sections or terms';
 end if;
 if not app_auth.has_permission(x.organization_id,'academic_periods.manage',x.school_id,null) then
  raise exception using
   errcode = '42501',
   message = 'academic_periods.manage permission is required';
 end if;
 update public.academic_years set name=update_academic_year.name,start_date=update_academic_year.start_date,end_date=update_academic_year.end_date,updated_by=a
 where academic_years.id=x.id returning to_jsonb(academic_years.*) into j;
 perform app_auth.write_academic_change(x.organization_id,a,'academic_year.updated','academic_year',x.id,to_jsonb(x),j); return x.id;
end $$;
create function public.transition_academic_year_status(id uuid,status public.academic_period_status) returns uuid
language plpgsql security definer set search_path='' as $$
declare
 a uuid:=auth.uid();
 x public.academic_years%rowtype;
 j jsonb;
begin
 if a is null then
  raise exception using
   errcode = '42501',
   message = 'an authenticated actor is required';
 end if;
 select * into x from public.academic_years y where y.id=transition_academic_year_status.id for update;
 if not found then
  raise exception using
   errcode = 'P0002',
   message = 'academic year not found';
 end if;
 perform 1 from public.schools s join public.organizations o on o.id=s.organization_id
 where (s.organization_id,s.id)=(x.organization_id,x.school_id) and s.status='active' and o.status='active'
 for update of s,o;
 if not found then
  raise exception using
   errcode = 'P0002',
   message = 'active academic-year organization and school are required';
 end if;
 if not app_auth.has_permission(x.organization_id,'academic_periods.manage',x.school_id,null) then
  raise exception using errcode='42501',message='academic_periods.manage permission is required';
 end if;
 if not ((x.status='draft' and status in ('active','archived'))
      or (x.status='active' and status='closed')
      or (x.status='closed' and status='archived')) then
  raise exception using errcode='22023',message='illegal academic year status transition';
 end if;
 perform 1 from public.academic_terms t where t.academic_year_id=x.id order by t.id for update;
 perform 1 from public.sections s where s.academic_year_id=x.id order by s.id for update;
 if status in ('closed','archived') and exists(
  select 1 from public.sections s where s.academic_year_id=x.id and s.status='active'
 ) then
  raise exception using errcode='22023',message='academic year has active sections';
 end if;
 if status in ('closed','archived') and exists(
  select 1 from public.academic_terms t where t.academic_year_id=x.id and t.status='active'
 ) then
  raise exception using errcode='22023',message='academic year has active terms';
 end if;
 update public.academic_years
 set status=transition_academic_year_status.status,updated_by=a
 where academic_years.id=x.id returning to_jsonb(academic_years.*) into j;
 perform app_auth.write_academic_change(x.organization_id,a,'academic_year.status_changed','academic_year',x.id,to_jsonb(x),j);
 return x.id;
end $$;
create function public.create_academic_term(academic_year_id uuid,name text,sequence smallint,start_date date,end_date date,status public.academic_period_status default 'draft') returns uuid
language plpgsql security definer set search_path='' as $$
declare
 a uuid:=auth.uid();
 y public.academic_years%rowtype;
 r uuid:=gen_random_uuid();
 j jsonb;
begin
 if a is null then
  raise exception using
   errcode = '42501',
   message = 'an authenticated actor is required';
 end if;
 select * into y from public.academic_years where id=create_academic_term.academic_year_id for update;
 if not found then
  raise exception using
   errcode = 'P0002',
   message = 'academic year not found';
 end if;
 perform 1 from public.schools s join public.organizations o on o.id=s.organization_id
 where (s.organization_id,s.id)=(y.organization_id,y.school_id) and s.status='active' and o.status='active'
 for update of s,o;
 if not found then
  raise exception using
   errcode = 'P0002',
   message = 'active academic-term organization and school are required';
 end if;
 if not app_auth.has_permission(y.organization_id,'academic_periods.manage',y.school_id,null) then
  raise exception using errcode='42501',message='academic_periods.manage permission is required';
 end if;
 if y.status not in ('draft','active') then
  raise exception using errcode='22023',message='academic year status does not permit term creation';
 end if;
 if status not in ('draft','active') or (status='active' and y.status<>'active') then
  raise exception using errcode='22023',message='academic term initial status is incompatible with academic year';
 end if;
 if end_date<start_date then
  raise exception using
   errcode = '22023',
   message = 'academic term end date must not precede start date';
 end if;
 if start_date<y.start_date or end_date>y.end_date then
  raise exception using errcode='22023',message='academic term dates must be within academic year';
 end if;
 if sequence<=0 then
  raise exception using
   errcode = '22023',
   message = 'academic term sequence must be positive';
 end if;
 if exists(select 1 from public.academic_terms t where t.academic_year_id=y.id and t.sequence=create_academic_term.sequence) then
  raise exception using errcode='23505',message='academic term sequence already exists';
 end if;
 if exists(select 1 from public.academic_terms t where t.academic_year_id=y.id and lower(btrim(t.name))=lower(btrim(create_academic_term.name))) then
  raise exception using errcode='23505',message='academic term normalized name already exists';
 end if;
 insert into public.academic_terms(id,organization_id,academic_year_id,name,sequence,start_date,end_date,status,created_by,updated_by)
 values(r,y.organization_id,y.id,btrim(name),sequence,start_date,end_date,status,a,a)
 returning to_jsonb(academic_terms.*) into j;
 perform app_auth.write_academic_change(y.organization_id,a,'academic_term.created','academic_term',r,null,j);
 return r;
end $$;
create function public.update_academic_term(id uuid,name text,sequence smallint,start_date date,end_date date) returns uuid
language plpgsql security definer set search_path='' as $$
declare
 a uuid:=auth.uid();
 x public.academic_terms%rowtype;
 y public.academic_years%rowtype;
 j jsonb;
begin
 if a is null then
  raise exception using
   errcode = '42501',
   message = 'an authenticated actor is required';
 end if;
 select * into x from public.academic_terms t where t.id=update_academic_term.id for update;
 if not found then
  raise exception using
   errcode = 'P0002',
   message = 'academic term not found';
 end if;
 select * into y from public.academic_years where academic_years.id=x.academic_year_id for update;
 if not found or y.organization_id<>x.organization_id then
  raise exception using errcode='P0002',message='authoritative academic year not found';
 end if;
 perform 1 from public.schools s join public.organizations o on o.id=s.organization_id
 where (s.organization_id,s.id)=(y.organization_id,y.school_id) and s.status='active' and o.status='active'
 for update of s,o;
 if not found then
  raise exception using
   errcode = 'P0002',
   message = 'active academic-term organization and school are required';
 end if;
 if not app_auth.has_permission(y.organization_id,'academic_periods.manage',y.school_id,null) then
  raise exception using errcode='42501',message='academic_periods.manage permission is required';
 end if;
 if y.status not in ('draft','active') or (x.status='active' and y.status<>'active') then
  raise exception using errcode='22023',message='academic year status does not permit term editing';
 end if;
 if sequence<=0 then
  raise exception using
   errcode = '22023',
   message = 'academic term sequence must be positive';
 end if;
 if end_date<start_date then
  raise exception using
   errcode = '22023',
   message = 'academic term end date must not precede start date';
 end if;
 if start_date<y.start_date or end_date>y.end_date then
  raise exception using errcode='22023',message='academic term dates must be within academic year';
 end if;
 perform 1 from public.sections s where s.academic_term_id=x.id order by s.id for update;
 if exists(select 1 from public.sections s where s.academic_term_id=x.id and s.status<>'archived'
           and (s.start_date<update_academic_term.start_date or s.end_date>update_academic_term.end_date)) then
  raise exception using errcode='22023',message='academic term dates exclude non-archived sections';
 end if;
 if exists(select 1 from public.academic_terms t where t.academic_year_id=y.id and t.id<>x.id and t.sequence=update_academic_term.sequence) then
  raise exception using errcode='23505',message='academic term sequence already exists';
 end if;
 if exists(select 1 from public.academic_terms t where t.academic_year_id=y.id and t.id<>x.id
           and lower(btrim(t.name))=lower(btrim(update_academic_term.name))) then
  raise exception using errcode='23505',message='academic term normalized name already exists';
 end if;
 update public.academic_terms
 set name=btrim(update_academic_term.name),sequence=update_academic_term.sequence,
     start_date=update_academic_term.start_date,end_date=update_academic_term.end_date,updated_by=a
 where academic_terms.id=x.id returning to_jsonb(academic_terms.*) into j;
 perform app_auth.write_academic_change(x.organization_id,a,'academic_term.updated','academic_term',x.id,to_jsonb(x),j);
 return x.id;
end $$;
create function public.transition_academic_term_status(id uuid,status public.academic_period_status) returns uuid
language plpgsql security definer set search_path='' as $$
declare
 a uuid:=auth.uid();
 x public.academic_terms%rowtype;
 y public.academic_years%rowtype;
 j jsonb;
begin
 if a is null then
  raise exception using
   errcode = '42501',
   message = 'an authenticated actor is required';
 end if;
 select * into x from public.academic_terms t where t.id=transition_academic_term_status.id for update;
 if not found then
  raise exception using
   errcode = 'P0002',
   message = 'academic term not found';
 end if;
 select * into y from public.academic_years where academic_years.id=x.academic_year_id for update;
 if not found or y.organization_id<>x.organization_id then
  raise exception using errcode='P0002',message='authoritative academic year not found';
 end if;
 perform 1 from public.schools s join public.organizations o on o.id=s.organization_id
 where (s.organization_id,s.id)=(y.organization_id,y.school_id) and s.status='active' and o.status='active'
 for update of s,o;
 if not found then
  raise exception using
   errcode = 'P0002',
   message = 'active academic-term organization and school are required';
 end if;
 if not app_auth.has_permission(y.organization_id,'academic_periods.manage',y.school_id,null) then
  raise exception using errcode='42501',message='academic_periods.manage permission is required';
 end if;
 if not ((x.status='draft' and status in ('active','archived'))
      or (x.status='active' and status='closed')
      or (x.status='closed' and status='archived')) then
  raise exception using errcode='22023',message='illegal academic term status transition';
 end if;
 if (status='active' and y.status<>'active')
    or (status='closed' and y.status not in ('active','closed')) then
  raise exception using errcode='22023',message='academic term transition is incompatible with academic year status';
 end if;
 perform 1 from public.sections s where s.academic_term_id=x.id order by s.id for update;
 if status in ('closed','archived') and exists(
  select 1 from public.sections s where s.academic_term_id=x.id and s.status='active'
 ) then
  raise exception using errcode='22023',message='academic term has active sections';
 end if;
 update public.academic_terms
 set status=transition_academic_term_status.status,updated_by=a
 where academic_terms.id=x.id returning to_jsonb(academic_terms.*) into j;
 perform app_auth.write_academic_change(x.organization_id,a,'academic_term.status_changed','academic_term',x.id,to_jsonb(x),j);
 return x.id;
end $$;

-- =============================================================================
-- Row-level security
-- =============================================================================
alter table public.staff_profiles enable row level security;
alter table public.staff_profiles force row level security;
alter table public.buildings enable row level security;
alter table public.buildings force row level security;
alter table public.rooms enable row level security;
alter table public.rooms force row level security;
alter table public.grade_levels enable row level security;
alter table public.grade_levels force row level security;
alter table public.sections enable row level security;
alter table public.sections force row level security;
alter table public.subjects enable row level security;
alter table public.subjects force row level security;

create policy staff_profiles_select on public.staff_profiles for select to authenticated using(
 app_auth.has_permission(organization_id,'staff_profiles.view',school_id,campus_id)
 or app_auth.has_permission(organization_id,'staff_profiles.manage',school_id,campus_id)
);
create policy buildings_select on public.buildings for select to authenticated using(
 app_auth.has_permission(organization_id,'academic_structure.view',school_id,campus_id)
 or app_auth.has_permission(organization_id,'academic_structure.manage',school_id,campus_id)
);
create policy rooms_select on public.rooms for select to authenticated using(
 app_auth.has_permission(organization_id,'academic_structure.view',school_id,campus_id)
 or app_auth.has_permission(organization_id,'academic_structure.manage',school_id,campus_id)
);
create policy sections_select on public.sections for select to authenticated using(
 app_auth.has_permission(organization_id,'academic_structure.view',school_id,campus_id)
 or app_auth.has_permission(organization_id,'academic_structure.manage',school_id,campus_id)
);
create policy grade_levels_select on public.grade_levels for select to authenticated using(
 app_auth.can_read_catalog(organization_id,school_id,'academic_structure.view')
 or app_auth.can_read_catalog(organization_id,school_id,'academic_structure.manage')
);
create policy subjects_select on public.subjects for select to authenticated using(
 app_auth.can_read_catalog(organization_id,school_id,'academic_structure.view')
 or app_auth.can_read_catalog(organization_id,school_id,'academic_structure.manage')
);
grant select on public.staff_profiles,public.buildings,public.rooms,public.grade_levels,public.sections,public.subjects to authenticated;
revoke insert,update,delete,truncate on public.staff_profiles,public.buildings,public.rooms,public.grade_levels,public.sections,public.subjects from public,anon,authenticated;
revoke insert,update,delete,truncate on public.academic_years,public.academic_terms from public,anon,authenticated;

-- =============================================================================
-- Explicit ownership, grants, revocations, and comments
-- =============================================================================
-- No regex grants or schema-wide revokes.
alter function app_auth.can_read_catalog(uuid,uuid,text) owner to postgres;
alter function app_auth.can_manage_catalog(uuid,uuid) owner to postgres;
alter function app_auth.write_academic_change(uuid,uuid,text,text,uuid,jsonb,jsonb) owner to postgres;
alter function app_auth.academic_foundation_command(text,uuid,jsonb) owner to postgres;
alter function app_auth.assert_active_academic_parents(text,uuid) owner to postgres;
alter function app_auth.mutate_academic(text,uuid,jsonb,boolean) owner to postgres;
revoke all on function app_auth.can_read_catalog(uuid,uuid,text)
 from public,anon,authenticated,service_role;
revoke all on function app_auth.can_manage_catalog(uuid,uuid)
 from public,anon,authenticated,service_role;
revoke all on function app_auth.write_academic_change(uuid,uuid,text,text,uuid,jsonb,jsonb)
 from public,anon,authenticated,service_role;
revoke all on function app_auth.academic_foundation_command(text,uuid,jsonb)
 from public,anon,authenticated,service_role;
revoke all on function app_auth.assert_active_academic_parents(text,uuid)
 from public,anon,authenticated,service_role;
revoke all on function app_auth.mutate_academic(text,uuid,jsonb,boolean)
 from public,anon,authenticated,service_role;
grant execute on function app_auth.can_read_catalog(uuid,uuid,text) to authenticated,service_role;

alter function public.create_building(uuid,text,text,date,public.record_status) owner to postgres;
alter function public.update_building(uuid,text,text,public.record_status,date,boolean,date,boolean) owner to postgres;
alter function public.archive_building(uuid) owner to postgres;
alter function public.create_room(uuid,text,text,text,integer,public.record_status) owner to postgres;
alter function public.update_room(uuid,text,text,text,integer,public.record_status,text,boolean) owner to postgres;
alter function public.archive_room(uuid) owner to postgres;
alter function public.create_grade_level(uuid,text,text,smallint,smallint,smallint,public.record_status) owner to postgres;
alter function public.update_grade_level(uuid,text,text,smallint,public.record_status,smallint,boolean,smallint,boolean) owner to postgres;
alter function public.archive_grade_level(uuid) owner to postgres;
alter function public.create_subject(uuid,text,text,text,public.record_status) owner to postgres;
alter function public.update_subject(uuid,text,text,text,public.record_status,boolean) owner to postgres;
alter function public.archive_subject(uuid) owner to postgres;
alter function public.create_section(uuid,uuid,uuid,uuid,uuid,text,text,integer,date,date,public.record_status) owner to postgres;
alter function public.update_section(uuid,text,text,integer,date,date,uuid,uuid,public.record_status,boolean,boolean) owner to postgres;
alter function public.archive_section(uuid) owner to postgres;
alter function public.create_staff_profile(uuid,uuid,uuid,text,text,text,text,date,public.record_status) owner to postgres;
alter function public.update_staff_profile(uuid,text,text,public.record_status,uuid,boolean,uuid,boolean,text,boolean,text,boolean,date,boolean,date,boolean) owner to postgres;
alter function public.archive_staff_profile(uuid) owner to postgres;
alter function public.create_academic_year(uuid,text,date,date,public.academic_period_status) owner to postgres;
alter function public.update_academic_year(uuid,text,date,date) owner to postgres;
alter function public.transition_academic_year_status(uuid,public.academic_period_status) owner to postgres;
alter function public.create_academic_term(uuid,text,smallint,date,date,public.academic_period_status) owner to postgres;
alter function public.update_academic_term(uuid,text,smallint,date,date) owner to postgres;
alter function public.transition_academic_term_status(uuid,public.academic_period_status) owner to postgres;

revoke all on function
 public.create_building(uuid,text,text,date,public.record_status),public.update_building(uuid,text,text,public.record_status,date,boolean,date,boolean),public.archive_building(uuid),
 public.create_room(uuid,text,text,text,integer,public.record_status),public.update_room(uuid,text,text,text,integer,public.record_status,text,boolean),public.archive_room(uuid),
 public.create_grade_level(uuid,text,text,smallint,smallint,smallint,public.record_status),public.update_grade_level(uuid,text,text,smallint,public.record_status,smallint,boolean,smallint,boolean),public.archive_grade_level(uuid),
 public.create_subject(uuid,text,text,text,public.record_status),public.update_subject(uuid,text,text,text,public.record_status,boolean),public.archive_subject(uuid),
 public.create_section(uuid,uuid,uuid,uuid,uuid,text,text,integer,date,date,public.record_status),public.update_section(uuid,text,text,integer,date,date,uuid,uuid,public.record_status,boolean,boolean),public.archive_section(uuid),
 public.create_staff_profile(uuid,uuid,uuid,text,text,text,text,date,public.record_status),
 public.update_staff_profile(uuid,text,text,public.record_status,uuid,boolean,uuid,boolean,text,boolean,text,boolean,date,boolean,date,boolean),
 public.archive_staff_profile(uuid),
 public.create_academic_year(uuid,text,date,date,public.academic_period_status),public.update_academic_year(uuid,text,date,date),public.transition_academic_year_status(uuid,public.academic_period_status),
 public.create_academic_term(uuid,text,smallint,date,date,public.academic_period_status),public.update_academic_term(uuid,text,smallint,date,date),public.transition_academic_term_status(uuid,public.academic_period_status)
 from public,anon,authenticated,service_role;
grant execute on function
 public.create_building(uuid,text,text,date,public.record_status),public.update_building(uuid,text,text,public.record_status,date,boolean,date,boolean),public.archive_building(uuid),
 public.create_room(uuid,text,text,text,integer,public.record_status),public.update_room(uuid,text,text,text,integer,public.record_status,text,boolean),public.archive_room(uuid),
 public.create_grade_level(uuid,text,text,smallint,smallint,smallint,public.record_status),public.update_grade_level(uuid,text,text,smallint,public.record_status,smallint,boolean,smallint,boolean),public.archive_grade_level(uuid),
 public.create_subject(uuid,text,text,text,public.record_status),public.update_subject(uuid,text,text,text,public.record_status,boolean),public.archive_subject(uuid),
 public.create_section(uuid,uuid,uuid,uuid,uuid,text,text,integer,date,date,public.record_status),public.update_section(uuid,text,text,integer,date,date,uuid,uuid,public.record_status,boolean,boolean),public.archive_section(uuid),
 public.create_staff_profile(uuid,uuid,uuid,text,text,text,text,date,public.record_status),
 public.update_staff_profile(uuid,text,text,public.record_status,uuid,boolean,uuid,boolean,text,boolean,text,boolean,date,boolean,date,boolean),
 public.archive_staff_profile(uuid),
 public.create_academic_year(uuid,text,date,date,public.academic_period_status),public.update_academic_year(uuid,text,date,date),public.transition_academic_year_status(uuid,public.academic_period_status),
 public.create_academic_term(uuid,text,smallint,date,date,public.academic_period_status),public.update_academic_term(uuid,text,smallint,date,date),public.transition_academic_term_status(uuid,public.academic_period_status)
 to authenticated,service_role;

commit;
