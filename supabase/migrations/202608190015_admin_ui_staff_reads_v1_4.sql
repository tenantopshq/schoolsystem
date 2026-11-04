begin;

create or replace function public.get_my_admin_contexts()
returns table(membership_id uuid,organization_id uuid,organization_name text,organization_slug text,
 school_id uuid,school_name text,school_code text,campus_id uuid,campus_name text,campus_code text,
 scope_level text,permission_codes text[])
language sql stable security definer set search_path='' as $$
 with actor as (select auth.uid() uid), memberships as (
  select m.id membership_id,o.id organization_id,o.name organization_name,o.slug organization_slug
  from public.organization_memberships m join public.organizations o on o.id=m.organization_id,actor
  where actor.uid is not null and m.user_id=actor.uid and m.status='active' and m.left_at is null and o.status='active'
 ), candidates as (
  select m.*,null::uuid school_id,null::text school_name,null::text school_code,
   null::uuid campus_id,null::text campus_name,null::text campus_code,'organization'::text scope_level from memberships m
  union all
  select m.*,s.id,s.name,s.code,null::uuid,null::text,null::text,'school' from memberships m
   join public.schools s on s.organization_id=m.organization_id and s.status='active'
  union all
  select m.*,s.id,s.name,s.code,c.id,c.name,c.code,'campus' from memberships m
   join public.schools s on s.organization_id=m.organization_id and s.status='active'
   join public.campuses c on c.organization_id=s.organization_id and c.school_id=s.id and c.status='active'
 ), permitted as (
  select c.*,array(select p from unnest(array['students.view','students.create','students.edit','students.archive',
   'students.sensitive_view','students.sensitive_manage','student_documents.manage',
   'staff_profiles.view','staff_profiles.manage']) p
   where app_auth.has_permission(c.organization_id,p,c.school_id,c.campus_id) order by p) codes from candidates c
 )
 select membership_id,organization_id,organization_name,organization_slug,school_id,school_name,school_code,
  campus_id,campus_name,campus_code,scope_level,codes from permitted where cardinality(codes)>0;
$$;

create function public.search_staff_profiles(
 p_organization_id uuid,p_school_id uuid default null,p_campus_id uuid default null,
 p_query text default null,p_status public.record_status default 'active',
 p_after_value text default null,p_after_id uuid default null,p_limit integer default 25)
returns table(staff_profile_id uuid,staff_number text,first_name text,middle_name text,last_name text,display_name text,
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
  select sp.*,pr.first_name,pr.middle_name,pr.last_name,pr.display_name,sc.name sc_name,c.name c_name,
   lower(coalesce(pr.last_name,'')||chr(31)||coalesce(pr.first_name,'')||chr(31)||
    coalesce(pr.display_name,'')||chr(31)||sp.staff_number) cursor_value
  from public.staff_profiles sp
  join public.organization_memberships m on (m.organization_id,m.id)=(sp.organization_id,sp.organization_membership_id)
  join public.profiles pr on pr.user_id=m.user_id
  left join public.schools sc on (sc.organization_id,sc.id)=(sp.organization_id,sp.school_id)
  left join public.campuses c on (c.organization_id,c.id)=(sp.organization_id,sp.campus_id)
  where sp.organization_id=p_organization_id and (p_school_id is null or sp.school_id=p_school_id)
   and (p_campus_id is null or sp.campus_id=p_campus_id) and (p_status is null or sp.status=p_status)
   and (q is null or sp.staff_number ilike '%'||q_literal||'%' escape '\' or
    lower(coalesce(pr.first_name,'')||' '||coalesce(pr.middle_name,'')||' '||coalesce(pr.last_name,'')||' '||coalesce(pr.display_name,''))
     like '%'||lower(q_literal)||'%' escape '\' or coalesce(sp.job_title,'') ilike '%'||q_literal||'%' escape '\'
     or coalesce(sp.department,'') ilike '%'||q_literal||'%' escape '\')
 ), counted as (select scoped.*,count(*) over() n from scoped), paged as (
  select * from counted where p_after_value is null or (cursor_value,id)>(p_after_value,p_after_id)
 )
 select p.id,p.staff_number,p.first_name,p.middle_name,p.last_name,p.display_name,p.job_title,p.department,
  p.employment_type,p.status,p.school_id,p.sc_name,p.campus_id,p.c_name,p.updated_at,p.cursor_value,p.n
 from paged p order by p.cursor_value,p.id limit lim;
end $$;

create function public.get_staff_admin_detail(p_staff_profile_id uuid,p_organization_id uuid,p_school_id uuid default null,p_campus_id uuid default null)
returns table(staff_profile_id uuid,staff_number text,first_name text,middle_name text,last_name text,display_name text,
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
 return query select sp.id,sp.staff_number,pr.first_name,pr.middle_name,pr.last_name,pr.display_name,
  sp.job_title,sp.department,sp.employment_type,sp.hire_date,sp.termination_date,sp.status,
  sp.school_id,sc.name,sp.campus_id,c.name,sp.created_at,sp.updated_at
 from public.organization_memberships m join public.profiles pr on pr.user_id=m.user_id
 left join public.schools sc on (sc.organization_id,sc.id)=(sp.organization_id,sp.school_id)
 left join public.campuses c on (c.organization_id,c.id)=(sp.organization_id,sp.campus_id)
 where (m.organization_id,m.id)=(sp.organization_id,sp.organization_membership_id);
end $$;

create index staff_profiles_directory_number_trgm_idx on public.staff_profiles
 using gin(lower(staff_number) extensions.gin_trgm_ops);
create index profiles_directory_name_trgm_idx on public.profiles using gin
 (lower(coalesce(first_name,'')||' '||coalesce(middle_name,'')||' '||coalesce(last_name,'')||' '||coalesce(display_name,'')) extensions.gin_trgm_ops);

alter function public.get_my_admin_contexts() owner to postgres;
alter function public.search_staff_profiles(uuid,uuid,uuid,text,public.record_status,text,uuid,integer) owner to postgres;
alter function public.get_staff_admin_detail(uuid,uuid,uuid,uuid) owner to postgres;

revoke all on function public.get_my_admin_contexts(),
 public.search_staff_profiles(uuid,uuid,uuid,text,public.record_status,text,uuid,integer),
 public.get_staff_admin_detail(uuid,uuid,uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function public.get_my_admin_contexts(),
 public.search_staff_profiles(uuid,uuid,uuid,text,public.record_status,text,uuid,integer),
 public.get_staff_admin_detail(uuid,uuid,uuid,uuid) to authenticated;

comment on function public.search_staff_profiles(uuid,uuid,uuid,text,public.record_status,text,uuid,integer)
 is 'Scoped administrative staff directory with an allowlisted identity projection.';
comment on function public.get_staff_admin_detail(uuid,uuid,uuid,uuid)
 is 'Scoped administrative staff employment detail with an allowlisted identity projection.';

commit;
