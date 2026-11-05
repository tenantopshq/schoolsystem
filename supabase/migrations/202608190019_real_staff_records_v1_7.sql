begin;

alter table public.staff_profiles
  add column first_name text,
  add column middle_name text,
  add column last_name text,
  add column display_name text,
  add column work_email text,
  add column phone text;

update public.staff_profiles sp set
  first_name=coalesce(nullif(btrim(pr.first_name),''),'Staff'),
  middle_name=pr.middle_name,
  last_name=coalesce(nullif(btrim(pr.last_name),''),sp.staff_number),
  display_name=pr.display_name,
  work_email=u.email,
  phone=pr.phone
from public.organization_memberships m
join public.profiles pr on pr.user_id=m.user_id
join auth.users u on u.id=m.user_id
where (m.organization_id,m.id)=(sp.organization_id,sp.organization_membership_id);

-- A legacy row can outlive an identity row or can point at a profile with no
-- names. Deterministic staff-owned fallbacks make every historical row valid.
update public.staff_profiles set
  first_name=coalesce(nullif(btrim(first_name),''),'Staff'),
  last_name=coalesce(nullif(btrim(last_name),''),staff_number);

alter table public.staff_profiles
  alter column first_name set not null,
  alter column last_name set not null,
  add constraint staff_profiles_first_name_length check(length(btrim(first_name)) between 1 and 100),
  add constraint staff_profiles_middle_name_length check(middle_name is null or length(btrim(middle_name)) between 1 and 100),
  add constraint staff_profiles_last_name_length check(length(btrim(last_name)) between 1 and 100),
  add constraint staff_profiles_display_name_length check(display_name is null or length(btrim(display_name)) between 1 and 200),
  add constraint staff_profiles_work_email_length check(work_email is null or length(btrim(work_email)) between 3 and 320),
  add constraint staff_profiles_phone_length check(phone is null or length(btrim(phone)) between 1 and 40);

-- Older server-side academic commands do not accept staff identity fields. Keep
-- those trusted compatibility paths valid while still enforcing stored names.
create function app_auth.populate_legacy_staff_identity()
returns trigger language plpgsql security definer set search_path='' as $$
declare profile_first text;profile_middle text;profile_last text;profile_display text;profile_phone text;membership_email text;
begin
 if new.first_name is not null and new.last_name is not null then return new; end if;
 select p.first_name,p.middle_name,p.last_name,p.display_name,p.phone,u.email
 into profile_first,profile_middle,profile_last,profile_display,profile_phone,membership_email
 from public.organization_memberships m
 join public.profiles p on p.user_id=m.user_id
 left join auth.users u on u.id=m.user_id
 where (m.organization_id,m.id)=(new.organization_id,new.organization_membership_id);
 new.first_name:=coalesce(nullif(btrim(new.first_name),''),nullif(btrim(profile_first),''),'Staff');
 new.last_name:=coalesce(nullif(btrim(new.last_name),''),nullif(btrim(profile_last),''),new.staff_number);
 new.middle_name:=coalesce(new.middle_name,profile_middle);
 new.display_name:=coalesce(new.display_name,profile_display);
 new.work_email:=coalesce(new.work_email,membership_email);
 new.phone:=coalesce(new.phone,profile_phone);
 return new;
end $$;
create trigger staff_profiles_legacy_identity_before_insert
 before insert on public.staff_profiles for each row execute function app_auth.populate_legacy_staff_identity();
alter function app_auth.populate_legacy_staff_identity() owner to postgres;
revoke all on function app_auth.populate_legacy_staff_identity() from public,anon,authenticated,service_role;

alter table public.staff_profiles drop constraint staff_profiles_organization_id_organization_membership_id_key;
alter table public.staff_profiles alter column organization_membership_id drop not null;
create unique index staff_profiles_org_membership_linked_key
  on public.staff_profiles(organization_id,organization_membership_id)
  where organization_membership_id is not null;
create index staff_profiles_identity_trgm_idx on public.staff_profiles using gin
  (lower(coalesce(first_name,'')||' '||coalesce(middle_name,'')||' '||coalesce(last_name,'')||' '||coalesce(display_name,'')||' '||coalesce(work_email,'')) extensions.gin_trgm_ops);

drop function public.search_staff_profiles(uuid,uuid,uuid,text,public.record_status,text,uuid,integer);
create function public.search_staff_profiles(
 p_organization_id uuid,p_school_id uuid default null,p_campus_id uuid default null,
 p_query text default null,p_status public.record_status default 'active',
 p_after_value text default null,p_after_id uuid default null,p_limit integer default 25)
returns table(staff_profile_id uuid,staff_number text,first_name text,middle_name text,last_name text,display_name text,
 work_email text,phone text,access_state text,organization_membership_id uuid,
 job_title text,department text,employment_type text,status public.record_status,
 school_id uuid,school_name text,campus_id uuid,campus_name text,updated_at timestamptz,
 sort_cursor_value text,total_count bigint)
language plpgsql stable security definer set search_path='' as $$
declare lim int:=greatest(1,least(coalesce(p_limit,25),50));q text:=nullif(btrim(p_query),'');q_literal text;
begin
 if auth.uid() is null then raise exception using errcode='42501',message='authenticated actor required'; end if;
 if p_campus_id is not null and p_school_id is null then raise exception using errcode='22023',message='campus requires school'; end if;
 if (p_after_value is null)<>(p_after_id is null) then raise exception using errcode='22023',message='invalid cursor'; end if;
 if length(coalesce(q,''))>100 then raise exception using errcode='22023',message='staff search query is too long'; end if;
 if length(coalesce(p_after_value,''))>1000 then raise exception using errcode='22023',message='staff cursor is too long'; end if;
 if not (app_auth.has_permission(p_organization_id,'staff_profiles.view',p_school_id,p_campus_id)
  or app_auth.has_permission(p_organization_id,'staff_profiles.manage',p_school_id,p_campus_id)) then
  raise exception using errcode='42501',message='staff_profiles.view permission is required';
 end if;
 q_literal:=replace(replace(replace(q,'\','\\'),'%','\%'),'_','\_');
 return query with scoped as (
  select sp.*,sc.name sc_name,c.name c_name,
   case when m.id is null then 'no_access' when m.status='invited' then 'invited'
    when m.status='active' and m.left_at is null then 'active' else 'suspended' end access_value,
   lower(coalesce(sp.last_name,'')||chr(31)||coalesce(sp.first_name,'')||chr(31)||
    coalesce(sp.display_name,'')||chr(31)||sp.staff_number) cursor_value
  from public.staff_profiles sp
  left join public.organization_memberships m on (m.organization_id,m.id)=(sp.organization_id,sp.organization_membership_id)
  left join public.schools sc on (sc.organization_id,sc.id)=(sp.organization_id,sp.school_id)
  left join public.campuses c on (c.organization_id,c.id)=(sp.organization_id,sp.campus_id)
  where sp.organization_id=p_organization_id and (p_school_id is null or sp.school_id=p_school_id)
   and (p_campus_id is null or sp.campus_id=p_campus_id) and (p_status is null or sp.status=p_status)
   and (q is null or sp.staff_number ilike '%'||q_literal||'%' escape '\' or
    lower(coalesce(sp.first_name,'')||' '||coalesce(sp.middle_name,'')||' '||coalesce(sp.last_name,'')||' '||coalesce(sp.display_name,'')||' '||coalesce(sp.work_email,''))
     like '%'||lower(q_literal)||'%' escape '\' or coalesce(sp.job_title,'') ilike '%'||q_literal||'%' escape '\'
     or coalesce(sp.department,'') ilike '%'||q_literal||'%' escape '\')
 ), counted as (select scoped.*,count(*) over() n from scoped), paged as (
  select * from counted where p_after_value is null or (cursor_value,id)>(p_after_value,p_after_id)
 )
 select p.id,p.staff_number,p.first_name,p.middle_name,p.last_name,p.display_name,p.work_email,p.phone,
  p.access_value,p.organization_membership_id,p.job_title,p.department,p.employment_type,p.status,
  p.school_id,p.sc_name,p.campus_id,p.c_name,p.updated_at,p.cursor_value,p.n
 from paged p order by p.cursor_value,p.id limit lim;
end $$;

drop function public.get_staff_admin_detail(uuid,uuid,uuid,uuid);
create function public.get_staff_admin_detail(p_staff_profile_id uuid,p_organization_id uuid,p_school_id uuid default null,p_campus_id uuid default null)
returns table(staff_profile_id uuid,staff_number text,first_name text,middle_name text,last_name text,display_name text,
 work_email text,phone text,access_state text,organization_membership_id uuid,
 job_title text,department text,employment_type text,hire_date date,termination_date date,status public.record_status,
 school_id uuid,school_name text,campus_id uuid,campus_name text,created_at timestamptz,updated_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
declare sp public.staff_profiles;
begin
 if auth.uid() is null then raise exception using errcode='42501',message='authenticated actor required'; end if;
 if p_campus_id is not null and p_school_id is null then raise exception using errcode='22023',message='campus requires school'; end if;
 select * into sp from public.staff_profiles where id=p_staff_profile_id;
 if not found or sp.organization_id<>p_organization_id or (p_school_id is not null and sp.school_id is distinct from p_school_id)
  or (p_campus_id is not null and sp.campus_id is distinct from p_campus_id)
  or not (app_auth.has_permission(p_organization_id,'staff_profiles.view',p_school_id,p_campus_id)
   or app_auth.has_permission(p_organization_id,'staff_profiles.manage',p_school_id,p_campus_id)) then return; end if;
 return query select sp.id,sp.staff_number,sp.first_name,sp.middle_name,sp.last_name,sp.display_name,
  sp.work_email,sp.phone,case when m.id is null then 'no_access' when m.status='invited' then 'invited'
   when m.status='active' and m.left_at is null then 'active' else 'suspended' end,sp.organization_membership_id,
  sp.job_title,sp.department,sp.employment_type,sp.hire_date,sp.termination_date,sp.status,
  sp.school_id,sc.name,sp.campus_id,c.name,sp.created_at,sp.updated_at
 from (select 1) x
 left join public.organization_memberships m on (m.organization_id,m.id)=(sp.organization_id,sp.organization_membership_id)
 left join public.schools sc on (sc.organization_id,sc.id)=(sp.organization_id,sp.school_id)
 left join public.campuses c on (c.organization_id,c.id)=(sp.organization_id,sp.campus_id);
end $$;

create function public.create_staff_profile_v1_7(
 request_id uuid,organization_id uuid,membership_id uuid,school_id uuid,campus_id uuid,
 staff_number text,first_name text,middle_name text,last_name text,display_name text,work_email text,phone text,
 employment_type text,job_title text default null,department text default null,hire_date date default null,
 status public.record_status default 'active')
returns uuid language plpgsql security definer set search_path='' as $$
declare a uuid:=auth.uid();h bytea;q record;rid uuid:=gen_random_uuid();afterj jsonb;cmd uuid:=gen_random_uuid();
begin
 if a is null then raise exception using errcode='42501',message='authenticated actor required'; end if;
 if create_staff_profile_v1_7.campus_id is not null and create_staff_profile_v1_7.school_id is null then raise exception using errcode='22023',message='campus requires school'; end if;
 if create_staff_profile_v1_7.status='archived' then raise exception using errcode='22023',message='staff profile initial status cannot be archived'; end if;
 if not app_auth.has_permission(create_staff_profile_v1_7.organization_id,'staff_profiles.manage',create_staff_profile_v1_7.school_id,create_staff_profile_v1_7.campus_id) then raise exception using errcode='42501',message='staff command target is unavailable'; end if;
 perform 1 from public.organizations o where o.id=create_staff_profile_v1_7.organization_id and o.status='active' for update;
 if not found then raise exception using errcode='P0002',message='active staff organization is required'; end if;
 if create_staff_profile_v1_7.school_id is not null then perform 1 from public.schools s where (s.organization_id,s.id)=(create_staff_profile_v1_7.organization_id,create_staff_profile_v1_7.school_id) and s.status='active' for update; if not found then raise exception using errcode='P0002',message='active staff school is required'; end if; end if;
 if create_staff_profile_v1_7.campus_id is not null then perform 1 from public.campuses c where (c.organization_id,c.school_id,c.id)=(create_staff_profile_v1_7.organization_id,create_staff_profile_v1_7.school_id,create_staff_profile_v1_7.campus_id) and c.status='active' for update; if not found then raise exception using errcode='P0002',message='active staff campus is required'; end if; end if;
 if create_staff_profile_v1_7.membership_id is not null then perform 1 from public.organization_memberships m where (m.organization_id,m.id)=(create_staff_profile_v1_7.organization_id,create_staff_profile_v1_7.membership_id) and m.status='active' and m.left_at is null for update; if not found then raise exception using errcode='22023',message='linked membership must be active and compatible'; end if; end if;
 h:=extensions.digest(convert_to(jsonb_build_array(create_staff_profile_v1_7.organization_id,create_staff_profile_v1_7.membership_id,create_staff_profile_v1_7.school_id,create_staff_profile_v1_7.campus_id,create_staff_profile_v1_7.staff_number,create_staff_profile_v1_7.first_name,create_staff_profile_v1_7.middle_name,create_staff_profile_v1_7.last_name,create_staff_profile_v1_7.display_name,create_staff_profile_v1_7.work_email,create_staff_profile_v1_7.phone,create_staff_profile_v1_7.employment_type,create_staff_profile_v1_7.job_title,create_staff_profile_v1_7.department,create_staff_profile_v1_7.hire_date,create_staff_profile_v1_7.status)::text,'UTF8'),'sha256');
 select * into q from app_auth.claim_sis_receipt(create_staff_profile_v1_7.organization_id,a,'create_staff_profile_v1_7',create_staff_profile_v1_7.request_id,h);
 if q.replayed then return q.result_id; end if;
 insert into public.staff_profiles(id,organization_id,organization_membership_id,school_id,campus_id,staff_number,
  first_name,middle_name,last_name,display_name,work_email,phone,employment_type,job_title,department,hire_date,status,created_by,updated_by)
 values(rid,create_staff_profile_v1_7.organization_id,create_staff_profile_v1_7.membership_id,create_staff_profile_v1_7.school_id,create_staff_profile_v1_7.campus_id,create_staff_profile_v1_7.staff_number,create_staff_profile_v1_7.first_name,create_staff_profile_v1_7.middle_name,create_staff_profile_v1_7.last_name,create_staff_profile_v1_7.display_name,create_staff_profile_v1_7.work_email,create_staff_profile_v1_7.phone,
  create_staff_profile_v1_7.employment_type,create_staff_profile_v1_7.job_title,create_staff_profile_v1_7.department,create_staff_profile_v1_7.hire_date,create_staff_profile_v1_7.status,a,a) returning to_jsonb(staff_profiles.*) into afterj;
 insert into public.audit_log(command_id,organization_id,actor_user_id,action,entity_type,entity_id,before_data,after_data)
 values(cmd,create_staff_profile_v1_7.organization_id,a,'staff_profile.created','staff_profile',rid,null,afterj);
 insert into public.event_outbox(command_id,organization_id,event_type,aggregate_type,aggregate_id,payload)
 values(cmd,create_staff_profile_v1_7.organization_id,'staff_profile.created','staff_profile',rid,jsonb_build_object('command_id',cmd,'actor_user_id',a,'organization_id',create_staff_profile_v1_7.organization_id,'aggregate_id',rid));
 perform app_auth.complete_sis_receipt(create_staff_profile_v1_7.organization_id,a,'create_staff_profile_v1_7',create_staff_profile_v1_7.request_id,rid); return rid;
end $$;

create function public.update_staff_profile_v1_7(
 request_id uuid,id uuid,membership_id uuid,set_membership_id boolean,staff_number text,
 first_name text,middle_name text,last_name text,display_name text,work_email text,phone text,
 employment_type text,status public.record_status,job_title text default null,department text default null,
 hire_date date default null,termination_date date default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare a uuid:=auth.uid();sp public.staff_profiles;h bytea;q record;beforej jsonb;afterj jsonb;cmd uuid:=gen_random_uuid();target_membership uuid;
begin
 if a is null then raise exception using errcode='42501',message='authenticated actor required'; end if;
 select * into sp from public.staff_profiles x where x.id=update_staff_profile_v1_7.id for update;
 if not found or not app_auth.has_permission(sp.organization_id,'staff_profiles.manage',sp.school_id,sp.campus_id) then raise exception using errcode='42501',message='staff command target is unavailable'; end if;
 h:=extensions.digest(convert_to(jsonb_build_array(update_staff_profile_v1_7.id,update_staff_profile_v1_7.membership_id,update_staff_profile_v1_7.set_membership_id,update_staff_profile_v1_7.staff_number,update_staff_profile_v1_7.first_name,update_staff_profile_v1_7.middle_name,update_staff_profile_v1_7.last_name,update_staff_profile_v1_7.display_name,update_staff_profile_v1_7.work_email,update_staff_profile_v1_7.phone,update_staff_profile_v1_7.employment_type,update_staff_profile_v1_7.status,update_staff_profile_v1_7.job_title,update_staff_profile_v1_7.department,update_staff_profile_v1_7.hire_date,update_staff_profile_v1_7.termination_date)::text,'UTF8'),'sha256');
 select * into q from app_auth.claim_sis_receipt(sp.organization_id,a,'update_staff_profile_v1_7',update_staff_profile_v1_7.request_id,h);
 if q.replayed then return q.result_id; end if;
 if sp.status='archived' or update_staff_profile_v1_7.status='archived' then raise exception using errcode='22023',message='archived staff profile cannot be edited'; end if;
 target_membership:=case when update_staff_profile_v1_7.set_membership_id then update_staff_profile_v1_7.membership_id else sp.organization_membership_id end;
 if update_staff_profile_v1_7.set_membership_id and (update_staff_profile_v1_7.membership_id is null or sp.organization_membership_id is not null) then raise exception using errcode='22023',message='membership link may only be added once'; end if;
 if update_staff_profile_v1_7.set_membership_id then perform 1 from public.organization_memberships m where (m.organization_id,m.id)=(sp.organization_id,update_staff_profile_v1_7.membership_id) and m.status='active' and m.left_at is null for update; if not found then raise exception using errcode='22023',message='linked membership must be active and compatible'; end if; end if;
 if update_staff_profile_v1_7.termination_date is not null and update_staff_profile_v1_7.hire_date is not null and update_staff_profile_v1_7.termination_date<update_staff_profile_v1_7.hire_date then raise exception using errcode='22023',message='termination date cannot precede hire date'; end if;
 beforej:=to_jsonb(sp);
 update public.staff_profiles x set organization_membership_id=target_membership,staff_number=update_staff_profile_v1_7.staff_number,
  first_name=update_staff_profile_v1_7.first_name,middle_name=update_staff_profile_v1_7.middle_name,last_name=update_staff_profile_v1_7.last_name,
  display_name=update_staff_profile_v1_7.display_name,work_email=update_staff_profile_v1_7.work_email,phone=update_staff_profile_v1_7.phone,
  employment_type=update_staff_profile_v1_7.employment_type,status=update_staff_profile_v1_7.status,job_title=update_staff_profile_v1_7.job_title,
  department=update_staff_profile_v1_7.department,hire_date=update_staff_profile_v1_7.hire_date,termination_date=update_staff_profile_v1_7.termination_date,
  updated_at=now(),updated_by=a where x.id=sp.id returning to_jsonb(x.*) into afterj;
 insert into public.audit_log(command_id,organization_id,actor_user_id,action,entity_type,entity_id,before_data,after_data)
 values(cmd,sp.organization_id,a,case when update_staff_profile_v1_7.set_membership_id then 'staff_profile.access_linked' else 'staff_profile.updated' end,'staff_profile',sp.id,beforej,afterj);
 insert into public.event_outbox(command_id,organization_id,event_type,aggregate_type,aggregate_id,payload)
 values(cmd,sp.organization_id,case when update_staff_profile_v1_7.set_membership_id then 'staff_profile.access_linked' else 'staff_profile.updated' end,'staff_profile',sp.id,
  jsonb_build_object('command_id',cmd,'actor_user_id',a,'organization_id',sp.organization_id,'aggregate_id',sp.id,'membership_id',target_membership));
 perform app_auth.complete_sis_receipt(sp.organization_id,a,'update_staff_profile_v1_7',update_staff_profile_v1_7.request_id,sp.id); return sp.id;
end $$;

alter function public.search_staff_profiles(uuid,uuid,uuid,text,public.record_status,text,uuid,integer) owner to postgres;
alter function public.get_staff_admin_detail(uuid,uuid,uuid,uuid) owner to postgres;
alter function public.create_staff_profile_v1_7(uuid,uuid,uuid,uuid,uuid,text,text,text,text,text,text,text,text,text,text,date,public.record_status) owner to postgres;
alter function public.update_staff_profile_v1_7(uuid,uuid,uuid,boolean,text,text,text,text,text,text,text,text,public.record_status,text,text,date,date) owner to postgres;

revoke all on function public.search_staff_profiles(uuid,uuid,uuid,text,public.record_status,text,uuid,integer),
 public.get_staff_admin_detail(uuid,uuid,uuid,uuid),
 public.create_staff_profile_v1_7(uuid,uuid,uuid,uuid,uuid,text,text,text,text,text,text,text,text,text,text,date,public.record_status),
 public.update_staff_profile_v1_7(uuid,uuid,uuid,boolean,text,text,text,text,text,text,text,text,public.record_status,text,text,date,date)
 from public,anon,authenticated,service_role;
grant execute on function public.search_staff_profiles(uuid,uuid,uuid,text,public.record_status,text,uuid,integer),
 public.get_staff_admin_detail(uuid,uuid,uuid,uuid),
 public.create_staff_profile_v1_7(uuid,uuid,uuid,uuid,uuid,text,text,text,text,text,text,text,text,text,text,date,public.record_status),
 public.update_staff_profile_v1_7(uuid,uuid,uuid,boolean,text,text,text,text,text,text,text,text,public.record_status,text,text,date,date)
 to authenticated;

revoke all on function
 public.create_staff_profile_v1_5(uuid,uuid,uuid,uuid,text,text,text,text,date,public.record_status),
 public.update_staff_profile_v1_5(uuid,uuid,text,text,public.record_status,uuid,boolean,uuid,boolean,text,boolean,text,boolean,date,boolean,date,boolean)
 from public,anon,authenticated,service_role;

comment on function public.create_staff_profile_v1_7(uuid,uuid,uuid,uuid,uuid,text,text,text,text,text,text,text,text,text,text,date,public.record_status)
 is 'Replay-safe scoped staff creation with staff-owned identity and optional active membership.';
comment on function public.update_staff_profile_v1_7(uuid,uuid,uuid,boolean,text,text,text,text,text,text,text,text,public.record_status,text,text,date,date)
 is 'Replay-safe scoped staff update with one-time optional active membership linking.';

commit;
