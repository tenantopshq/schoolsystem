begin;

create function public.search_eligible_staff_members(
  p_organization_id uuid,
  p_school_id uuid default null,
  p_campus_id uuid default null,
  p_query text default null,
  p_limit integer default 50
)
returns table(
  membership_id uuid,
  first_name text,
  middle_name text,
  last_name text,
  display_name text
)
language plpgsql stable security definer set search_path='' as $$
declare
  q text:=nullif(btrim(p_query),'');
  q_literal text;
  lim integer:=greatest(1,least(coalesce(p_limit,50),100));
begin
  if auth.uid() is null then
    raise exception using errcode='42501',message='authenticated actor required';
  end if;
  if p_campus_id is not null and p_school_id is null then
    raise exception using errcode='22023',message='campus requires school';
  end if;
  if length(coalesce(q,''))>100 then
    raise exception using errcode='22023',message='staff candidate query is too long';
  end if;
  if not app_auth.has_permission(p_organization_id,'staff_profiles.manage',p_school_id,p_campus_id) then
    raise exception using errcode='42501',message='staff_profiles.manage permission is required';
  end if;
  q_literal:=replace(replace(replace(q,'\','\\'),'%','\%'),'_','\_');
  return query
  select m.id,pr.first_name,pr.middle_name,pr.last_name,pr.display_name
  from public.organization_memberships m
  join public.profiles pr on pr.user_id=m.user_id
  where m.organization_id=p_organization_id and m.status='active' and m.left_at is null
    and pr.status='active'
    and not exists(select 1 from public.staff_profiles sp where sp.organization_id=m.organization_id and sp.organization_membership_id=m.id)
    and (q is null or lower(coalesce(pr.first_name,'')||' '||coalesce(pr.middle_name,'')||' '||coalesce(pr.last_name,'')||' '||coalesce(pr.display_name,''))
      like '%'||lower(q_literal)||'%' escape '\')
  order by lower(coalesce(pr.last_name,pr.display_name,'')),lower(coalesce(pr.first_name,'')),m.id
  limit lim;
end $$;

create function public.create_staff_profile_v1_5(
  request_id uuid,
  membership_id uuid,
  school_id uuid,
  campus_id uuid,
  staff_number text,
  employment_type text,
  job_title text default null,
  department text default null,
  hire_date date default null,
  status public.record_status default 'active'
)
returns uuid language plpgsql security definer set search_path='' as $$
declare
  a uuid:=auth.uid();o uuid;h bytea;q record;rid uuid;
begin
  if a is null then raise exception using errcode='42501',message='authenticated actor required'; end if;
  select m.organization_id into o from public.organization_memberships m
   where m.id=create_staff_profile_v1_5.membership_id and m.status='active' and m.left_at is null;
  if o is null or not app_auth.has_permission(o,'staff_profiles.manage',school_id,campus_id) then
    raise exception using errcode='42501',message='staff command target is unavailable';
  end if;
  h:=extensions.digest(convert_to(jsonb_build_array(membership_id,school_id,campus_id,staff_number,employment_type,job_title,department,hire_date,status)::text,'UTF8'),'sha256');
  select * into q from app_auth.claim_sis_receipt(o,a,'create_staff_profile_v1_5',request_id,h);
  if q.replayed then
    if not app_auth.has_permission(o,'staff_profiles.manage',school_id,campus_id) then raise exception using errcode='42501',message='staff_profiles.manage permission is required'; end if;
    return q.result_id;
  end if;
  rid:=public.create_staff_profile(membership_id,school_id,campus_id,staff_number,employment_type,job_title,department,hire_date,status);
  perform app_auth.complete_sis_receipt(o,a,'create_staff_profile_v1_5',request_id,rid);
  return rid;
end $$;

create function public.update_staff_profile_v1_5(
  request_id uuid,
  id uuid,
  staff_number text,
  employment_type text,
  status public.record_status,
  school_id uuid default null,
  set_school_id boolean default false,
  campus_id uuid default null,
  set_campus_id boolean default false,
  job_title text default null,
  set_job_title boolean default false,
  department text default null,
  set_department boolean default false,
  hire_date date default null,
  set_hire_date boolean default false,
  termination_date date default null,
  set_termination_date boolean default false
)
returns uuid language plpgsql security definer set search_path='' as $$
declare
  a uuid:=auth.uid();sp public.staff_profiles;h bytea;q record;rid uuid;dest_school uuid;dest_campus uuid;
begin
  if a is null then raise exception using errcode='42501',message='authenticated actor required'; end if;
  select * into sp from public.staff_profiles where staff_profiles.id=update_staff_profile_v1_5.id;
  if not found or not app_auth.has_permission(sp.organization_id,'staff_profiles.manage',sp.school_id,sp.campus_id) then
    raise exception using errcode='42501',message='staff command target is unavailable';
  end if;
  dest_school:=case when set_school_id then school_id else sp.school_id end;
  dest_campus:=case when set_campus_id then campus_id else sp.campus_id end;
  if not app_auth.has_permission(sp.organization_id,'staff_profiles.manage',dest_school,dest_campus) then
    raise exception using errcode='42501',message='staff command target is unavailable';
  end if;
  h:=extensions.digest(convert_to(jsonb_build_array(id,staff_number,employment_type,status,school_id,set_school_id,campus_id,set_campus_id,job_title,set_job_title,department,set_department,hire_date,set_hire_date,termination_date,set_termination_date)::text,'UTF8'),'sha256');
  select * into q from app_auth.claim_sis_receipt(sp.organization_id,a,'update_staff_profile_v1_5',request_id,h);
  if q.replayed then
    if not app_auth.has_permission(sp.organization_id,'staff_profiles.manage',sp.school_id,sp.campus_id) then raise exception using errcode='42501',message='staff_profiles.manage permission is required'; end if;
    return q.result_id;
  end if;
  rid:=public.update_staff_profile(id,staff_number,employment_type,status,school_id,set_school_id,campus_id,set_campus_id,
    job_title,set_job_title,department,set_department,hire_date,set_hire_date,termination_date,set_termination_date);
  perform app_auth.complete_sis_receipt(sp.organization_id,a,'update_staff_profile_v1_5',request_id,rid);
  return rid;
end $$;

create function public.archive_staff_profile_v1_5(request_id uuid,target_staff_profile_id uuid,archive_reason text)
returns uuid language plpgsql security definer set search_path='' as $$
declare
  a uuid:=auth.uid();sp public.staff_profiles;h bytea;q record;rid uuid;reason text:=btrim(archive_reason);cmd uuid:=gen_random_uuid();
begin
  if a is null then raise exception using errcode='42501',message='authenticated actor required'; end if;
  if length(reason) not between 1 and 500 then raise exception using errcode='22023',message='archive reason must be between 1 and 500 characters'; end if;
  select * into sp from public.staff_profiles where id=target_staff_profile_id;
  if not found or not app_auth.has_permission(sp.organization_id,'staff_profiles.manage',sp.school_id,sp.campus_id) then
    raise exception using errcode='42501',message='staff command target is unavailable';
  end if;
  h:=extensions.digest(convert_to(jsonb_build_array(target_staff_profile_id,reason)::text,'UTF8'),'sha256');
  select * into q from app_auth.claim_sis_receipt(sp.organization_id,a,'archive_staff_profile_v1_5',request_id,h);
  if q.replayed then
    if not app_auth.has_permission(sp.organization_id,'staff_profiles.manage',sp.school_id,sp.campus_id) then raise exception using errcode='42501',message='staff_profiles.manage permission is required'; end if;
    return q.result_id;
  end if;
  rid:=public.archive_staff_profile(target_staff_profile_id);
  insert into public.audit_log(command_id,organization_id,actor_user_id,action,entity_type,entity_id,before_data,after_data)
  values(cmd,sp.organization_id,a,'staff_profile.archive_reason_recorded','staff_profile',rid,null,jsonb_build_object('archive_reason',reason));
  insert into public.event_outbox(command_id,organization_id,event_type,aggregate_type,aggregate_id,payload)
  values(cmd,sp.organization_id,'staff_profile.archive_reason_recorded','staff_profile',rid,
    jsonb_build_object('command_id',cmd,'actor_user_id',a,'organization_id',sp.organization_id,'aggregate_id',rid,'archive_reason',reason));
  perform app_auth.complete_sis_receipt(sp.organization_id,a,'archive_staff_profile_v1_5',request_id,rid);
  return rid;
end $$;

do $$ declare r record; begin
  for r in select p.oid::regprocedure sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname in ('search_eligible_staff_members','create_staff_profile_v1_5','update_staff_profile_v1_5','archive_staff_profile_v1_5') loop
    execute format('alter function %s owner to postgres',r.sig);
    execute format('revoke all on function %s from public,anon,authenticated,service_role',r.sig);
    execute format('grant execute on function %s to authenticated',r.sig);
  end loop;
end $$;

comment on function public.search_eligible_staff_members(uuid,uuid,uuid,text,integer)
 is 'Active organization memberships without a staff profile, visible only to scoped staff managers.';
comment on function public.create_staff_profile_v1_5(uuid,uuid,uuid,uuid,text,text,text,text,date,public.record_status)
 is 'Replay-safe scoped staff employment profile creation.';
comment on function public.update_staff_profile_v1_5(uuid,uuid,text,text,public.record_status,uuid,boolean,uuid,boolean,text,boolean,text,boolean,date,boolean,date,boolean)
 is 'Replay-safe scoped staff employment profile update.';
comment on function public.archive_staff_profile_v1_5(uuid,uuid,text)
 is 'Replay-safe staff profile archival with a bounded audit reason.';

commit;
