begin;

alter table public.roles add column system_role_key text;
alter table public.roles add constraint roles_system_role_key_check check (
  system_role_key is null or (
    system_role_key='ORGANIZATION_OWNER' and is_system_role and code='ORGANIZATION_OWNER'
    and name='Organization Owner' and description='System-managed organization owner' and status='active'
  )
);
create unique index roles_organization_system_role_key_uidx
  on public.roles(organization_id,system_role_key) where system_role_key is not null;
create index role_assignments_owner_lookup_idx
  on public.role_assignments(organization_id,organization_membership_id,role_id,school_id,campus_id,status);

create function app_auth.organization_owner_permission_codes_v1_8()
returns text[] language sql immutable security definer set search_path='' as $$
 select array[
  'academic_periods.manage','academic_periods.view','academic_structure.manage','academic_structure.view',
  'assessments.correct','assessments.manage','assessments.view','attendance.correct','attendance.manage','attendance.view',
  'audit.view','enrollments.correct','enrollments.manage','enrollments.view','memberships.manage','memberships.view',
  'organizations.manage','organizations.view','progression.approve','progression.cancel','progression.correct',
  'progression.execute','progression.manage','progression.view','report_cards.correct','report_cards.manage','report_cards.view',
  'roles.manage','roles.view','schools.manage','schools.view','staff_profiles.manage','staff_profiles.view',
  'student_documents.manage','students.archive','students.create','students.edit','students.sensitive_manage',
  'students.sensitive_view','students.view','teaching_assignments.correct','teaching_assignments.manage',
  'teaching_assignments.view','term_grades.correct','term_grades.manage','term_grades.view',
  'transcripts.correct','transcripts.manage','transcripts.view'
 ]::text[];
$$;

create function app_auth.guard_system_role_v1_8()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if tg_op='INSERT' then
  if new.system_role_key is not null and (
    new.system_role_key<>'ORGANIZATION_OWNER' or not new.is_system_role or new.code<>'ORGANIZATION_OWNER'
    or new.name<>'Organization Owner' or new.description is distinct from 'System-managed organization owner'
    or new.status<>'active'
  ) then raise exception using errcode='22023',message='protected organization owner role is immutable'; end if;
  return new;
 end if;
 if tg_op='DELETE' then
  if old.system_role_key='ORGANIZATION_OWNER' then
   raise exception using errcode='22023',message='protected organization owner role is immutable';
  end if;
  return old;
 end if;
 if old.system_role_key is distinct from new.system_role_key then
  raise exception using errcode='22023',message='protected organization owner role key is immutable';
 end if;
 if old.system_role_key='ORGANIZATION_OWNER' and (
  old.organization_id is distinct from new.organization_id or old.code is distinct from new.code
  or old.name is distinct from new.name or old.description is distinct from new.description
  or old.is_system_role is distinct from new.is_system_role or old.status is distinct from new.status
 ) then raise exception using errcode='22023',message='protected organization owner role is immutable'; end if;
 return new;
end $$;
create trigger roles_guard_system_role_v1_8 before insert or update or delete on public.roles
for each row execute function app_auth.guard_system_role_v1_8();

create function app_auth.guard_system_role_permission_v1_8()
returns trigger language plpgsql security definer set search_path='' as $$
declare old_protected boolean:=false;new_protected boolean:=false;code text;x record;
begin
 for x in select r.id,r.system_role_key from public.roles r
  where r.id=any(case when tg_op='UPDATE' then array[old.role_id,new.role_id] when tg_op='DELETE' then array[old.role_id] else array[new.role_id] end)
  order by r.id for update loop
  if tg_op in('UPDATE','DELETE') and x.id=old.role_id and x.system_role_key='ORGANIZATION_OWNER' then old_protected:=true;end if;
  if tg_op in('UPDATE','INSERT') and x.id=new.role_id and x.system_role_key='ORGANIZATION_OWNER' then new_protected:=true;end if;
 end loop;
 if tg_op='DELETE' and old_protected then raise exception using errcode='22023',message='protected organization owner permissions are immutable';end if;
 if tg_op='UPDATE' and (old_protected or new_protected) and
  (old.role_id is distinct from new.role_id or old.permission_id is distinct from new.permission_id or old.organization_id is distinct from new.organization_id) then
   raise exception using errcode='22023',message='protected organization owner permissions are immutable';
 end if;
 if not new_protected then return case when tg_op='DELETE' then old else new end;end if;
 select p.code into code from public.permissions p where p.id=new.permission_id;
 if code is null or not (code=any(app_auth.organization_owner_permission_codes_v1_8())) then
  raise exception using errcode='22023',message='protected organization owner permission is not allowed';
 end if;
 return new;
end $$;
create trigger role_permissions_guard_system_role_v1_8 before insert or update or delete on public.role_permissions
for each row execute function app_auth.guard_system_role_permission_v1_8();

create function app_auth.validate_system_role_permissions_v1_8()
returns trigger language plpgsql security definer set search_path='' as $$
declare rid uuid;expected text[]:=app_auth.organization_owner_permission_codes_v1_8();actual text[];role_ids uuid[];
begin
 if tg_table_name='roles' then role_ids:=array[new.id];
 elsif tg_op='INSERT' then role_ids:=array[new.role_id];
 elsif tg_op='DELETE' then role_ids:=array[old.role_id];
 else role_ids:=array[old.role_id,new.role_id];end if;
 for rid in select distinct u from unnest(role_ids)u order by u loop
  if exists(select 1 from public.roles r where r.id=rid and r.system_role_key='ORGANIZATION_OWNER') then
   select coalesce(array_agg(p.code order by p.code),'{}'::text[]) into actual
   from public.role_permissions rp join public.permissions p on p.id=rp.permission_id where rp.role_id=rid;
   if actual is distinct from expected then
    raise exception using errcode='22023',message='protected organization owner role must have the fixed permission set';
   end if;
  end if;
 end loop;
 return null;
end $$;
create constraint trigger roles_validate_system_permissions_v1_8 after insert or update on public.roles
deferrable initially deferred for each row execute function app_auth.validate_system_role_permissions_v1_8();
create constraint trigger role_permissions_validate_system_permissions_v1_8 after insert or update or delete on public.role_permissions
deferrable initially deferred for each row execute function app_auth.validate_system_role_permissions_v1_8();

create table app_auth.onboarding_command_receipts(
 actor_user_id uuid not null references auth.users(id) on delete restrict,
 command_name text not null,
 request_id uuid not null,
 argument_hash bytea not null check(octet_length(argument_hash)=32),
 organization_id uuid references public.organizations(id) on delete restrict,
 result_id uuid,
 completed boolean not null default false,
 created_at timestamptz not null default now(),
 completed_at timestamptz,
 primary key(actor_user_id,command_name,request_id)
);

create function app_auth.claim_onboarding_receipt_v1_8(a uuid,n text,r uuid,h bytea)
returns table(replayed boolean,result_id uuid)
language plpgsql security definer set search_path='' as $$
declare x app_auth.onboarding_command_receipts;
begin
 if a is null then raise exception using errcode='42501',message='authenticated actor required'; end if;
 if r is null then raise exception using errcode='22023',message='request_id is required'; end if;
 insert into app_auth.onboarding_command_receipts(actor_user_id,command_name,request_id,argument_hash)
 values(a,n,r,h) on conflict do nothing;
 if found then return query select false,null::uuid; return; end if;
 select * into x from app_auth.onboarding_command_receipts
 where actor_user_id=a and command_name=n and request_id=r for update;
 if x.argument_hash<>h then raise exception using errcode='22023',message='request_id was reused with different arguments'; end if;
 if not x.completed then raise exception using errcode='40001',message='matching command is in progress'; end if;
 return query select true,x.result_id;
end $$;
create function app_auth.complete_onboarding_receipt_v1_8(a uuid,n text,r uuid,o uuid,result uuid)
returns void language sql security definer set search_path='' as $$
 update app_auth.onboarding_command_receipts set organization_id=o,result_id=result,completed=true,completed_at=now()
 where actor_user_id=a and command_name=n and request_id=r;
$$;

create function app_auth.normalize_onboarding_slug_v1_8(v text)
returns text language sql immutable security definer set search_path='' as $$
 select trim(both '-' from regexp_replace(lower(btrim(coalesce(v,''))),'[^a-z0-9]+','-','g'));
$$;
create function app_auth.normalize_onboarding_code_v1_8(v text)
returns text language sql immutable security definer set search_path='' as $$
 select trim(both '-' from regexp_replace(upper(btrim(coalesce(v,''))),'[^A-Z0-9]+','-','g'));
$$;
create function app_auth.is_active_organization_owner_v1_8(o uuid,a uuid default auth.uid())
returns boolean language sql stable security definer set search_path='' as $$
 select exists(
  select 1 from public.organization_memberships m
  join public.role_assignments ra on (ra.organization_id,ra.organization_membership_id)=(m.organization_id,m.id)
  join public.roles r on (r.organization_id,r.id)=(ra.organization_id,ra.role_id)
  where m.organization_id=o and m.user_id=a and m.status='active' and m.left_at is null
   and r.system_role_key='ORGANIZATION_OWNER' and r.status='active'
   and ra.status='active' and ra.school_id is null and ra.campus_id is null
   and ra.starts_at<=now() and (ra.ends_at is null or ra.ends_at>now())
 );
$$;

create function public.bootstrap_organization_v1_8(request_id uuid,organization_name text,organization_slug text)
returns uuid language plpgsql security definer set search_path='' as $$
declare a uuid:=auth.uid(); n text:=btrim(organization_name); s text:=app_auth.normalize_onboarding_slug_v1_8(organization_slug);
 h bytea; q record; oid uuid; mid uuid; rid uuid; cmd uuid:=gen_random_uuid();
begin
 if a is null then raise exception using errcode='42501',message='authenticated actor required'; end if;
 if request_id is null or length(n) not between 2 and 160 or n~'[[:cntrl:]]'
  or length(s) not between 2 and 63 or s!~'^[a-z0-9]+(?:-[a-z0-9]+)*$' then
  raise exception using errcode='22023',message='valid organization name and slug are required';
 end if;
 h:=extensions.digest(convert_to(jsonb_build_array(n,s)::text,'UTF8'),'sha256');
 select * into q from app_auth.claim_onboarding_receipt_v1_8(a,'bootstrap_organization_v1_8',request_id,h);
 if q.replayed then return q.result_id; end if;
 perform pg_advisory_xact_lock(hashtextextended('onboarding:actor:'||a::text,0));
 perform pg_advisory_xact_lock(hashtextextended('onboarding:slug:'||s,0));
 if exists(select 1 from public.organizations o where o.slug=s) then
  raise exception using errcode='23505',message='organization slug already exists';
 end if;
 insert into public.organizations(name,slug,created_by,updated_by) values(n,s,a,a) returning id into oid;
 insert into public.organization_memberships(organization_id,user_id,status,joined_at,created_by,updated_by)
 values(oid,a,'active',now(),a,a) returning id into mid;
 insert into public.roles(organization_id,code,name,description,is_system_role,status,created_by,updated_by,system_role_key)
 values(oid,'ORGANIZATION_OWNER','Organization Owner','System-managed organization owner',true,'active',a,a,'ORGANIZATION_OWNER') returning id into rid;
 insert into public.role_permissions(organization_id,role_id,permission_id,created_by)
 select oid,rid,p.id,a from public.permissions p where p.code=any(app_auth.organization_owner_permission_codes_v1_8());
 if (select count(*) from public.role_permissions rp where rp.role_id=rid)<>49 then
  raise exception using errcode='22023',message='owner permission catalog is incomplete';
 end if;
 insert into public.role_assignments(organization_id,organization_membership_id,role_id,created_by,updated_by)
 values(oid,mid,rid,a,a);
 insert into public.audit_log(command_id,organization_id,actor_user_id,action,entity_type,entity_id,after_data)
 values(cmd,oid,a,'organization.bootstrapped','organization',oid,jsonb_build_object('id',oid,'name',n,'slug',s,'owner_membership_id',mid,'owner_role_id',rid));
 insert into public.event_outbox(command_id,organization_id,event_type,aggregate_type,aggregate_id,payload)
 values(cmd,oid,'organization.bootstrapped','organization',oid,jsonb_build_object('command_id',cmd,'actor_user_id',a,'organization_id',oid,'aggregate_id',oid));
 perform app_auth.complete_onboarding_receipt_v1_8(a,'bootstrap_organization_v1_8',request_id,oid,oid);
 return oid;
end $$;

create function public.create_onboarding_school_v1_8(request_id uuid,organization_id uuid,school_name text,school_code text)
returns uuid language plpgsql security definer set search_path='' as $$
#variable_conflict use_variable
declare a uuid:=auth.uid(); n text:=btrim(school_name); c text:=app_auth.normalize_onboarding_code_v1_8(school_code);
 h bytea;q record;sid uuid;cmd uuid:=gen_random_uuid();
begin
 if a is null then raise exception using errcode='42501',message='authenticated actor required'; end if;
 if request_id is null or organization_id is null or length(n) not between 2 and 160 or n~'[[:cntrl:]]'
  or length(c) not between 1 and 32 or c!~'^[A-Z0-9]+(?:-[A-Z0-9]+)*$' then
  raise exception using errcode='22023',message='valid school name and code are required'; end if;
 h:=extensions.digest(convert_to(jsonb_build_array(organization_id,n,c)::text,'UTF8'),'sha256');
 select * into q from app_auth.claim_onboarding_receipt_v1_8(a,'create_onboarding_school_v1_8',request_id,h);
 if q.replayed then return q.result_id; end if;
 perform 1 from public.organizations o where o.id=organization_id and o.status='active' for update;
 if not found then raise exception using errcode='42501',message='active organization owner required'; end if;
 perform 1 from public.organization_memberships m where m.organization_id=organization_id and m.user_id=a and m.status='active' and m.left_at is null for update;
 perform 1 from public.roles r where r.organization_id=organization_id and r.system_role_key='ORGANIZATION_OWNER' for update;
 perform 1 from public.role_assignments ra join public.organization_memberships m on m.id=ra.organization_membership_id
  join public.roles r on r.id=ra.role_id where ra.organization_id=organization_id and m.user_id=a and m.status='active'
  and m.left_at is null and r.system_role_key='ORGANIZATION_OWNER' and ra.status='active' and ra.school_id is null and ra.campus_id is null
  and ra.starts_at<=now() and(ra.ends_at is null or ra.ends_at>now()) for update of ra;
 if not found or not app_auth.has_permission(organization_id,'schools.manage') then raise exception using errcode='42501',message='active organization owner required'; end if;
 perform pg_advisory_xact_lock(hashtextextended('onboarding:school:'||organization_id::text||':'||c,0));
 if exists(select 1 from public.schools s where s.organization_id=organization_id and s.code=c) then raise exception using errcode='23505',message='school code already exists'; end if;
 insert into public.schools(organization_id,name,code,created_by,updated_by) values(organization_id,n,c,a,a) returning id into sid;
 insert into public.audit_log(command_id,organization_id,actor_user_id,action,entity_type,entity_id,after_data)
 values(cmd,organization_id,a,'school.created','school',sid,jsonb_build_object('id',sid,'organization_id',organization_id,'name',n,'code',c));
 insert into public.event_outbox(command_id,organization_id,event_type,aggregate_type,aggregate_id,payload)
 values(cmd,organization_id,'school.created','school',sid,jsonb_build_object('command_id',cmd,'actor_user_id',a,'organization_id',organization_id,'aggregate_id',sid));
 perform app_auth.complete_onboarding_receipt_v1_8(a,'create_onboarding_school_v1_8',request_id,organization_id,sid);return sid;
end $$;

create function public.create_onboarding_campus_v1_8(request_id uuid,organization_id uuid,school_id uuid,campus_name text,campus_code text)
returns uuid language plpgsql security definer set search_path='' as $$
#variable_conflict use_variable
declare a uuid:=auth.uid();n text:=btrim(campus_name);c text:=app_auth.normalize_onboarding_code_v1_8(campus_code);
 h bytea;q record;cid uuid;cmd uuid:=gen_random_uuid();
begin
 if a is null then raise exception using errcode='42501',message='authenticated actor required'; end if;
 if request_id is null or organization_id is null or school_id is null or length(n) not between 2 and 160 or n~'[[:cntrl:]]'
  or length(c) not between 1 and 32 or c!~'^[A-Z0-9]+(?:-[A-Z0-9]+)*$' then raise exception using errcode='22023',message='valid campus name and code are required'; end if;
 h:=extensions.digest(convert_to(jsonb_build_array(organization_id,school_id,n,c)::text,'UTF8'),'sha256');
 select * into q from app_auth.claim_onboarding_receipt_v1_8(a,'create_onboarding_campus_v1_8',request_id,h);if q.replayed then return q.result_id;end if;
 perform 1 from public.organizations o where o.id=organization_id and o.status='active' for update;
 if not found then raise exception using errcode='42501',message='active organization owner required'; end if;
 perform 1 from public.organization_memberships m where m.organization_id=organization_id and m.user_id=a and m.status='active' and m.left_at is null for update;
 perform 1 from public.roles r where r.organization_id=organization_id and r.system_role_key='ORGANIZATION_OWNER' for update;
 perform 1 from public.role_assignments ra join public.organization_memberships m on m.id=ra.organization_membership_id
  join public.roles r on r.id=ra.role_id where ra.organization_id=organization_id and m.user_id=a and m.status='active'
  and m.left_at is null and r.system_role_key='ORGANIZATION_OWNER' and ra.status='active' and ra.school_id is null and ra.campus_id is null
  and ra.starts_at<=now() and(ra.ends_at is null or ra.ends_at>now()) for update of ra;
 if not found then raise exception using errcode='42501',message='active organization owner required'; end if;
 perform 1 from public.schools s where s.id=school_id and s.organization_id=organization_id and s.status='active' for update;
 if not found or not app_auth.has_permission(organization_id,'schools.manage',school_id,null) then raise exception using errcode='42501',message='active organization owner required'; end if;
 perform pg_advisory_xact_lock(hashtextextended('onboarding:campus:'||school_id::text||':'||c,0));
 if exists(select 1 from public.campuses x where x.school_id=school_id and x.code=c) then raise exception using errcode='23505',message='campus code already exists'; end if;
 insert into public.campuses(organization_id,school_id,name,code,created_by,updated_by) values(organization_id,school_id,n,c,a,a) returning id into cid;
 insert into public.audit_log(command_id,organization_id,actor_user_id,action,entity_type,entity_id,after_data)
 values(cmd,organization_id,a,'campus.created','campus',cid,jsonb_build_object('id',cid,'organization_id',organization_id,'school_id',school_id,'name',n,'code',c));
 insert into public.event_outbox(command_id,organization_id,event_type,aggregate_type,aggregate_id,payload)
 values(cmd,organization_id,'campus.created','campus',cid,jsonb_build_object('command_id',cmd,'actor_user_id',a,'organization_id',organization_id,'aggregate_id',cid,'school_id',school_id));
 perform app_auth.complete_onboarding_receipt_v1_8(a,'create_onboarding_campus_v1_8',request_id,organization_id,cid);return cid;
end $$;

create function public.list_my_owned_onboarding_organizations_v1_8()
returns table(organization_id uuid,organization_name text,organization_slug text,school_count bigint,campus_count bigint,is_complete boolean,updated_at timestamptz)
language sql stable security definer set search_path='' as $$
 select o.id,o.name,o.slug,(select count(*) from public.schools s where s.organization_id=o.id and s.status='active'),
  (select count(*) from public.campuses c where c.organization_id=o.id and c.status='active'),
  exists(select 1 from public.schools s join public.campuses c on(c.organization_id,c.school_id)=(s.organization_id,s.id)
   where s.organization_id=o.id and s.status='active' and c.status='active'),o.updated_at
 from public.organizations o where o.status='active' and app_auth.is_active_organization_owner_v1_8(o.id)
 order by o.updated_at desc,o.id;
$$;
create function public.list_my_owned_onboarding_schools_v1_8(p_organization_id uuid)
returns table(school_id uuid,school_name text,school_code text,campus_count bigint,updated_at timestamptz)
language plpgsql stable security definer set search_path='' as $$ begin
 if auth.uid() is null or not app_auth.is_active_organization_owner_v1_8(p_organization_id) then raise exception using errcode='42501',message='active organization owner required';end if;
 return query select s.id,s.name,s.code,(select count(*) from public.campuses c where c.school_id=s.id and c.status='active'),s.updated_at
 from public.schools s where s.organization_id=p_organization_id and s.status='active' order by s.created_at,s.id;
end $$;
create function public.get_my_organization_onboarding_state_v1_8(p_organization_id uuid,p_school_id uuid default null)
returns table(organization_id uuid,organization_name text,organization_slug text,membership_id uuid,
 selected_school_id uuid,selected_school_name text,selected_school_code text,selected_campus_id uuid,
 selected_campus_name text,selected_campus_code text,stage text)
language plpgsql stable security definer set search_path='' as $$
declare a uuid:=auth.uid();o public.organizations;m public.organization_memberships;s public.schools;c public.campuses;n bigint;
begin
 if a is null or not app_auth.is_active_organization_owner_v1_8(p_organization_id,a) then raise exception using errcode='42501',message='active organization owner required';end if;
 select * into o from public.organizations x where x.id=p_organization_id and x.status='active';
 select * into m from public.organization_memberships x where x.organization_id=p_organization_id and x.user_id=a and x.status='active' and x.left_at is null;
 if o.id is null or m.id is null then raise exception using errcode='42501',message='active organization owner required';end if;
 select count(*) into n from public.schools x where x.organization_id=p_organization_id and x.status='active';
 if p_school_id is not null then select * into s from public.schools x where x.id=p_school_id and x.organization_id=p_organization_id and x.status='active';if s.id is null then raise exception using errcode='42501',message='active organization owner required';end if;
 elsif n=1 then select * into s from public.schools x where x.organization_id=p_organization_id and x.status='active' order by x.created_at,x.id limit 1;end if;
 if s.id is not null then select * into c from public.campuses x where x.organization_id=p_organization_id and x.school_id=s.id and x.status='active' order by x.created_at,x.id limit 1;end if;
 return query select o.id,o.name,o.slug,m.id,s.id,s.name,s.code,c.id,c.name,c.code,
  case when n=0 then 'school' when s.id is null then 'school_selection' when c.id is null then 'campus' else 'complete' end;
end $$;

create or replace function public.get_my_admin_contexts()
returns table(membership_id uuid,organization_id uuid,organization_name text,organization_slug text,
 school_id uuid,school_name text,school_code text,campus_id uuid,campus_name text,campus_code text,
 scope_level text,permission_codes text[])
language sql stable security definer set search_path='' as $$
 with actor as(select auth.uid() uid),memberships as(
  select m.id membership_id,o.id organization_id,o.name organization_name,o.slug organization_slug
  from public.organization_memberships m join public.organizations o on o.id=m.organization_id,actor
  where actor.uid is not null and m.user_id=actor.uid and m.status='active' and m.left_at is null and o.status='active'),candidates as(
  select m.*,null::uuid school_id,null::text school_name,null::text school_code,null::uuid campus_id,null::text campus_name,null::text campus_code,'organization'::text scope_level from memberships m
  union all select m.*,s.id,s.name,s.code,null::uuid,null::text,null::text,'school' from memberships m join public.schools s on s.organization_id=m.organization_id and s.status='active'
  union all select m.*,s.id,s.name,s.code,c.id,c.name,c.code,'campus' from memberships m join public.schools s on s.organization_id=m.organization_id and s.status='active' join public.campuses c on c.organization_id=s.organization_id and c.school_id=s.id and c.status='active'),permitted as(
  select c.*,array(select p from unnest(app_auth.organization_owner_permission_codes_v1_8())p where app_auth.has_permission(c.organization_id,p,c.school_id,c.campus_id)order by p)codes from candidates c)
 select membership_id,organization_id,organization_name,organization_slug,school_id,school_name,school_code,campus_id,campus_name,campus_code,scope_level,codes from permitted where cardinality(codes)>0;
$$;

revoke insert,update,delete,truncate on public.organizations,public.schools,public.campuses,public.roles,public.role_permissions from public,anon,authenticated,service_role;
alter function app_auth.organization_owner_permission_codes_v1_8() owner to postgres;
alter function app_auth.guard_system_role_v1_8() owner to postgres;
alter function app_auth.guard_system_role_permission_v1_8() owner to postgres;
alter function app_auth.validate_system_role_permissions_v1_8() owner to postgres;
alter function app_auth.claim_onboarding_receipt_v1_8(uuid,text,uuid,bytea) owner to postgres;
alter function app_auth.complete_onboarding_receipt_v1_8(uuid,text,uuid,uuid,uuid) owner to postgres;
alter function app_auth.normalize_onboarding_slug_v1_8(text) owner to postgres;
alter function app_auth.normalize_onboarding_code_v1_8(text) owner to postgres;
alter function app_auth.is_active_organization_owner_v1_8(uuid,uuid) owner to postgres;
revoke all on table app_auth.onboarding_command_receipts from public,anon,authenticated,service_role;
revoke all on function app_auth.organization_owner_permission_codes_v1_8(),app_auth.guard_system_role_v1_8(),
 app_auth.guard_system_role_permission_v1_8(),app_auth.validate_system_role_permissions_v1_8(),
 app_auth.claim_onboarding_receipt_v1_8(uuid,text,uuid,bytea),app_auth.complete_onboarding_receipt_v1_8(uuid,text,uuid,uuid,uuid),
 app_auth.normalize_onboarding_slug_v1_8(text),app_auth.normalize_onboarding_code_v1_8(text),
 app_auth.is_active_organization_owner_v1_8(uuid,uuid) from public,anon,authenticated,service_role;
do $$declare x record;begin for x in select p.oid::regprocedure sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='public'and p.proname in('bootstrap_organization_v1_8','create_onboarding_school_v1_8','create_onboarding_campus_v1_8',
 'list_my_owned_onboarding_organizations_v1_8','list_my_owned_onboarding_schools_v1_8','get_my_organization_onboarding_state_v1_8','get_my_admin_contexts')loop
 execute format('alter function %s owner to postgres',x.sig);execute format('revoke all on function %s from public,anon,authenticated,service_role',x.sig);execute format('grant execute on function %s to authenticated',x.sig);end loop;end$$;

comment on column public.roles.system_role_key is 'Immutable database-controlled identity for protected system roles.';
comment on function public.bootstrap_organization_v1_8(uuid,text,text) is 'Replay-safe authenticated organization and protected owner bootstrap.';
commit;
