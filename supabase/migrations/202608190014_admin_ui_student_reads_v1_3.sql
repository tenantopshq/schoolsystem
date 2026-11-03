begin;

create extension if not exists pg_trgm with schema extensions;

create table app_auth.sis_command_receipts (
  organization_id uuid not null references public.organizations(id) on delete restrict,
  actor_user_id uuid not null references auth.users(id) on delete restrict,
  command_name text not null,
  request_id uuid not null,
  argument_hash bytea not null check (octet_length(argument_hash) = 32),
  completed boolean not null default false,
  result_id uuid,
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  primary key (organization_id, actor_user_id, command_name, request_id)
);

create function app_auth.claim_sis_receipt(o uuid,a uuid,n text,r uuid,h bytea)
returns table(replayed boolean,result_id uuid)
language plpgsql security definer set search_path='' as $$
declare x app_auth.sis_command_receipts;
begin
  if a is null then raise exception using errcode='42501',message='authenticated actor required'; end if;
  if r is null then raise exception using errcode='22023',message='request_id is required'; end if;
  insert into app_auth.sis_command_receipts(organization_id,actor_user_id,command_name,request_id,argument_hash)
  values(o,a,n,r,h) on conflict do nothing;
  if found then return query select false,null::uuid; return; end if;
  select * into x from app_auth.sis_command_receipts
   where organization_id=o and actor_user_id=a and command_name=n and request_id=r for update;
  if x.argument_hash<>h then raise exception using errcode='22023',message='request_id was reused with different arguments'; end if;
  if not x.completed then raise exception using errcode='40001',message='matching command is in progress'; end if;
  return query select true,x.result_id;
end $$;

create function app_auth.complete_sis_receipt(o uuid,a uuid,n text,r uuid,result uuid)
returns void language sql security definer set search_path='' as $$
 update app_auth.sis_command_receipts set completed=true,result_id=result,completed_at=now()
 where organization_id=o and actor_user_id=a and command_name=n and request_id=r;
$$;

create function public.get_my_admin_contexts()
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
   'students.sensitive_view','students.sensitive_manage','student_documents.manage']) p
   where app_auth.has_permission(c.organization_id,p,c.school_id,c.campus_id) order by p) codes from candidates c
 )
 select membership_id,organization_id,organization_name,organization_slug,school_id,school_name,school_code,
  campus_id,campus_name,campus_code,scope_level,codes from permitted where cardinality(codes)>0;
$$;

create function public.search_students(p_organization_id uuid,p_school_id uuid default null,p_campus_id uuid default null,
 p_query text default null,p_status public.record_status default 'active',p_sort text default 'name',
 p_direction text default 'asc',p_after_value text default null,p_after_id uuid default null,p_limit integer default 25)
returns table(student_id uuid,student_number text,first_name text,last_name text,preferred_name text,
 status public.record_status,school_id uuid,school_name text,campus_id uuid,campus_name text,
 updated_at timestamptz,sort_cursor_value text,total_count bigint)
language plpgsql stable security definer set search_path='' as $$
declare lim int:=greatest(1,least(coalesce(p_limit,25),50)); q text:=nullif(btrim(p_query),''); q_literal text;
begin
 if auth.uid() is null then raise exception using errcode='42501',message='authenticated actor required'; end if;
 if p_campus_id is not null and p_school_id is null then raise exception using errcode='22023',message='campus requires school'; end if;
 if p_sort not in ('name','student_number','updated') or p_direction not in ('asc','desc') then raise exception using errcode='22023',message='invalid sort'; end if;
 if (p_after_value is null)<>(p_after_id is null) then raise exception using errcode='22023',message='invalid cursor'; end if;
 if not app_auth.has_permission(p_organization_id,'students.view',p_school_id,p_campus_id) then raise exception using errcode='42501',message='students.view permission is required'; end if;
 q_literal:=replace(replace(replace(q,'\','\\'),'%','\%'),'_','\_');
 return query with scoped as (
  select s.*,sc.name sc_name,c.name c_name,
   case p_sort when 'name' then lower(coalesce(s.last_name,'')||chr(31)||coalesce(s.first_name,'')||chr(31)||coalesce(s.preferred_name,'')||chr(31)||s.student_number)
    when 'student_number' then lower(s.student_number) else to_char(s.updated_at at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"') end cursor_value
  from public.students s join public.schools sc on (sc.organization_id,sc.id)=(s.organization_id,s.school_id)
  left join public.campuses c on (c.organization_id,c.id)=(s.organization_id,s.campus_id)
  where s.organization_id=p_organization_id and (p_school_id is null or s.school_id=p_school_id)
   and (p_campus_id is null or s.campus_id=p_campus_id) and (p_status is null or s.status=p_status)
   and (q is null or s.student_number ilike '%'||q_literal||'%' escape '\' or
    (coalesce(s.first_name,'')||' '||coalesce(s.middle_name,'')||' '||coalesce(s.last_name,'')||' '||coalesce(s.preferred_name,'')) ilike '%'||q_literal||'%' escape '\')
 ), counted as (select scoped.*,count(*) over() n from scoped), paged as (
  select * from counted where p_after_value is null or
   (p_direction='asc' and (cursor_value,id)>(p_after_value,p_after_id)) or
   (p_direction='desc' and (cursor_value,id)<(p_after_value,p_after_id))
 ) select p.id,p.student_number,p.first_name,p.last_name,p.preferred_name,p.status,p.school_id,p.sc_name,p.campus_id,p.c_name,
   p.updated_at,p.cursor_value,p.n from paged p
  order by case when p_direction='asc' then p.cursor_value end asc,
   case when p_direction='asc' then p.id end asc,case when p_direction='desc' then p.cursor_value end desc,
   case when p_direction='desc' then p.id end desc limit lim;
end $$;

create function public.get_student_admin_detail(p_student_id uuid)
returns table(student_id uuid,student_number text,first_name text,middle_name text,last_name text,preferred_name text,
 date_of_birth date,gender text,nationality_code character(2),primary_language text,admission_date date,exit_date date,
 status public.record_status,school_id uuid,school_name text,campus_id uuid,campus_name text,created_at timestamptz,
 updated_at timestamptz,enrollments jsonb,guardian_links jsonb,documents jsonb)
language plpgsql stable security definer set search_path='' as $$
declare s public.students; enr jsonb; gl jsonb; docs jsonb;
begin
 if auth.uid() is null then raise exception using errcode='42501',message='authenticated actor required'; end if;
 select * into s from public.students where id=p_student_id;
 if not found or not app_auth.has_permission(s.organization_id,'students.view',s.school_id,s.campus_id) then return; end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',e.id,'academic_year_id',e.academic_year_id,'academic_year_name',y.name,
  'grade_level_id',e.grade_level_id,'grade_level_name',g.name,'enrolled_on',e.enrolled_on,'scheduled_end_on',e.scheduled_end_on,
  'ended_on',e.ended_on,'status',e.status,'end_reason',e.end_reason,'supersedes_enrollment_id',e.supersedes_enrollment_id,
  'placements',coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'campus_id',p.campus_id,'campus_name',pc.name,
   'section_id',p.section_id,'section_name',sec.name,'starts_on',p.starts_on,'ends_on',p.ends_on,'status',p.status,
   'end_reason',p.end_reason,'transfer_to_placement_id',p.transfer_to_placement_id,'supersedes_placement_id',p.supersedes_placement_id) order by p.starts_on,p.id)
   from public.student_section_placements p join public.campuses pc on pc.id=p.campus_id join public.sections sec on sec.id=p.section_id
   where p.student_enrollment_id=e.id and app_auth.can_view_enrollment(p.organization_id,p.student_id,p.school_id,p.campus_id)),'[]'::jsonb)) order by e.enrolled_on,e.id),'[]'::jsonb)
 into enr from public.student_enrollments e join public.academic_years y on y.id=e.academic_year_id
 join public.grade_levels g on g.id=e.grade_level_id where e.student_id=s.id and app_auth.can_view_enrollment(e.organization_id,e.student_id,e.school_id,null);
 select case when app_auth.can_staff_view_student(s.organization_id,s.id) then coalesce(jsonb_agg(jsonb_build_object(
  'link_id',sg.id,'guardian_id',g.id,'first_name',g.first_name,'middle_name',g.middle_name,'last_name',g.last_name,
  'relationship_type',sg.relationship_type,'is_primary',sg.is_primary,'has_portal_access',sg.has_portal_access,'status',sg.status)
  order by sg.is_primary desc,g.last_name,g.first_name),'[]'::jsonb) else '[]'::jsonb end into gl
 from public.student_guardians sg join public.guardians g on g.id=sg.guardian_id where sg.student_id=s.id;
 select coalesce(jsonb_agg(jsonb_build_object('id',d.id,'document_type',d.document_type,'title',d.title,'mime_type',d.mime_type,
  'file_size',d.file_size,'issued_at',d.issued_at,'expires_at',d.expires_at,'visibility',d.visibility,'status',d.status)
  order by d.issued_at desc nulls last,d.id),'[]'::jsonb) into docs from public.student_documents d where d.student_id=s.id and
  (app_auth.can_manage_student_documents(d.organization_id,d.student_id) or
   (d.visibility in ('staff','guardian','student') and app_auth.can_staff_view_student(d.organization_id,d.student_id)) or
   (d.visibility in ('guardian','student') and app_auth.is_linked_guardian(d.student_id)) or
   (d.visibility='student' and app_auth.is_student_self(d.student_id)));
 return query select s.id,s.student_number,s.first_name,s.middle_name,s.last_name,s.preferred_name,s.date_of_birth,s.gender,
  s.nationality_code,s.primary_language,s.admission_date,s.exit_date,s.status,s.school_id,sc.name,s.campus_id,c.name,
  s.created_at,s.updated_at,enr,gl,docs from public.schools sc left join public.campuses c on c.id=s.campus_id where sc.id=s.school_id;
end $$;

create function public.create_student_v1_3(request_id uuid,school_id uuid,campus_id uuid,student_number text,first_name text,
 middle_name text,last_name text,preferred_name text,date_of_birth date,gender text,nationality_code character(2),
 primary_language text,photo_path text,admission_date date,exit_date date,status public.record_status default 'active')
returns uuid language plpgsql security definer set search_path='' as $$
declare a uuid:=auth.uid();o uuid;h bytea;q record;rid uuid;
begin
 if a is null then raise exception using errcode='42501',message='authenticated actor required'; end if;
 select sc.organization_id into o from public.schools sc where sc.id=create_student_v1_3.school_id and sc.status='active';
 if o is null or (create_student_v1_3.campus_id is not null and not exists(select 1 from public.campuses c where c.id=create_student_v1_3.campus_id and c.organization_id=o and c.school_id=create_student_v1_3.school_id and c.status='active'))
  or not app_auth.has_permission(o,'students.create',create_student_v1_3.school_id,create_student_v1_3.campus_id) then
  raise exception using errcode='42501',message='student command target is unavailable';
 end if;
 h:=extensions.digest(convert_to(jsonb_build_array(school_id,campus_id,student_number,first_name,middle_name,last_name,preferred_name,date_of_birth,gender,nationality_code,primary_language,photo_path,admission_date,exit_date,status)::text,'UTF8'),'sha256');
 select * into q from app_auth.claim_sis_receipt(o,a,'create_student_v1_3',request_id,h);
 if q.replayed then if not app_auth.has_permission(o,'students.create',school_id,campus_id) then raise exception using errcode='42501',message='students.create permission is required'; end if; return q.result_id; end if;
 rid:=app_auth.create_sis_student(school_id,campus_id,jsonb_build_object('student_number',student_number,'first_name',first_name,'middle_name',middle_name,'last_name',last_name,'preferred_name',preferred_name,'date_of_birth',date_of_birth,'gender',gender,'nationality_code',nationality_code,'primary_language',primary_language,'photo_path',photo_path,'admission_date',admission_date,'exit_date',exit_date,'status',status));
 perform app_auth.complete_sis_receipt(o,a,'create_student_v1_3',request_id,rid); return rid; end $$;

create function public.update_student_v1_3(request_id uuid,id uuid,student_number text,first_name text,middle_name text,set_middle_name boolean,
 last_name text,preferred_name text,set_preferred_name boolean,date_of_birth date,gender text,set_gender boolean,nationality_code character(2),
 set_nationality_code boolean,primary_language text,set_primary_language boolean,photo_path text,set_photo_path boolean,
 admission_date date,set_admission_date boolean,exit_date date,set_exit_date boolean,status public.record_status,
 school_id uuid,set_school_id boolean,campus_id uuid,set_campus_id boolean)
returns uuid language plpgsql security definer set search_path='' as $$
declare a uuid:=auth.uid();s public.students;h bytea;q record;rid uuid;dest_school uuid;dest_campus uuid;dest_org uuid;
begin
 if a is null then raise exception using errcode='42501',message='authenticated actor required'; end if;
 select * into s from public.students where students.id=update_student_v1_3.id;
 if not found or not app_auth.has_permission(s.organization_id,'students.edit',s.school_id,s.campus_id) then
  raise exception using errcode='42501',message='student command target is unavailable';
 end if;
 dest_school:=case when set_school_id then school_id else s.school_id end;
 dest_campus:=case when set_campus_id then campus_id else s.campus_id end;
 select sc.organization_id into dest_org from public.schools sc where sc.id=dest_school and sc.status='active';
 if dest_org is distinct from s.organization_id
  or (dest_campus is not null and not exists(select 1 from public.campuses c where c.id=dest_campus and c.organization_id=s.organization_id and c.school_id=dest_school and c.status='active'))
  or not app_auth.has_permission(s.organization_id,'students.edit',dest_school,dest_campus) then
  raise exception using errcode='42501',message='student command target is unavailable';
 end if;
 h:=extensions.digest(convert_to(jsonb_build_array(id,student_number,first_name,middle_name,set_middle_name,last_name,preferred_name,set_preferred_name,date_of_birth,gender,set_gender,nationality_code,set_nationality_code,primary_language,set_primary_language,photo_path,set_photo_path,admission_date,set_admission_date,exit_date,set_exit_date,status,school_id,set_school_id,campus_id,set_campus_id)::text,'UTF8'),'sha256');
 select * into q from app_auth.claim_sis_receipt(s.organization_id,a,'update_student_v1_3',request_id,h);
 if q.replayed then if not app_auth.has_permission(s.organization_id,'students.edit',s.school_id,s.campus_id) then raise exception using errcode='42501',message='students.edit permission is required'; end if; return q.result_id; end if;
 rid:=app_auth.update_sis_student(id,jsonb_build_object('student_number',student_number,'first_name',first_name,'middle_name',middle_name,'set_middle_name',set_middle_name,'last_name',last_name,'preferred_name',preferred_name,'set_preferred_name',set_preferred_name,'date_of_birth',date_of_birth,'gender',gender,'set_gender',set_gender,'nationality_code',nationality_code,'set_nationality_code',set_nationality_code,'primary_language',primary_language,'set_primary_language',set_primary_language,'photo_path',photo_path,'set_photo_path',set_photo_path,'admission_date',admission_date,'set_admission_date',set_admission_date,'exit_date',exit_date,'set_exit_date',set_exit_date,'status',status,'school_id',school_id,'set_school_id',set_school_id,'campus_id',campus_id,'set_campus_id',set_campus_id));
 perform app_auth.complete_sis_receipt(s.organization_id,a,'update_student_v1_3',request_id,rid); return rid; end $$;

create function public.archive_student_v1_3(request_id uuid,target_student_id uuid,archive_reason text)
returns uuid language plpgsql security definer set search_path='' as $$
declare a uuid:=auth.uid();s public.students;h bytea;q record;rid uuid;
begin
 if a is null then raise exception using errcode='42501',message='authenticated actor required'; end if;
 select * into s from public.students where id=target_student_id;
 if not found or not app_auth.has_permission(s.organization_id,'students.archive',s.school_id,s.campus_id) then
  raise exception using errcode='42501',message='student command target is unavailable';
 end if;
 h:=extensions.digest(convert_to(jsonb_build_array(target_student_id,archive_reason)::text,'UTF8'),'sha256');
 select * into q from app_auth.claim_sis_receipt(s.organization_id,a,'archive_student_v1_3',request_id,h);
 if q.replayed then if not app_auth.has_permission(s.organization_id,'students.archive',s.school_id,s.campus_id) then raise exception using errcode='42501',message='students.archive permission is required'; end if; return q.result_id; end if;
 rid:=app_auth.archive_student(target_student_id,archive_reason);
 perform app_auth.complete_sis_receipt(s.organization_id,a,'archive_student_v1_3',request_id,rid); return rid; end $$;

create index students_directory_number_trgm_idx on public.students using gin(lower(student_number) extensions.gin_trgm_ops);
create index students_directory_name_trgm_idx on public.students using gin
 (lower(coalesce(first_name,'')||' '||coalesce(middle_name,'')||' '||coalesce(last_name,'')||' '||coalesce(preferred_name,'')) extensions.gin_trgm_ops);
create index students_directory_name_cursor_idx on public.students(organization_id,school_id,status,(lower(coalesce(last_name,'')||chr(31)||coalesce(first_name,'')||chr(31)||coalesce(preferred_name,'')||chr(31)||student_number)),id);
create index students_directory_number_cursor_idx on public.students(organization_id,school_id,status,(lower(student_number)),id);
create index students_directory_updated_cursor_idx on public.students(organization_id,school_id,status,updated_at,id);
create index students_directory_campus_name_cursor_idx on public.students(organization_id,school_id,campus_id,status,(lower(coalesce(last_name,'')||chr(31)||coalesce(first_name,'')||chr(31)||coalesce(preferred_name,'')||chr(31)||student_number)),id);
create index students_directory_campus_number_cursor_idx on public.students(organization_id,school_id,campus_id,status,(lower(student_number)),id);
create index students_directory_campus_updated_cursor_idx on public.students(organization_id,school_id,campus_id,status,updated_at,id);

alter function app_auth.claim_sis_receipt(uuid,uuid,text,uuid,bytea) owner to postgres;
alter function app_auth.complete_sis_receipt(uuid,uuid,text,uuid,uuid) owner to postgres;
revoke all on table app_auth.sis_command_receipts from public,anon,authenticated,service_role;
revoke all on function app_auth.claim_sis_receipt(uuid,uuid,text,uuid,bytea),
 app_auth.complete_sis_receipt(uuid,uuid,text,uuid,uuid) from public,anon,authenticated,service_role;

do $$ declare r record; begin for r in select p.oid::regprocedure sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='public' and p.proname in ('get_my_admin_contexts','search_students','get_student_admin_detail','create_student_v1_3','update_student_v1_3','archive_student_v1_3') loop
 execute format('alter function %s owner to postgres',r.sig); execute format('revoke all on function %s from public,anon,authenticated,service_role',r.sig); execute format('grant execute on function %s to authenticated',r.sig); end loop; end $$;

do $$ declare r record; begin for r in select p.oid::regprocedure sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='public' and p.proname in ('create_student','update_student','archive_student') loop
 execute format('revoke all on function %s from public,anon,authenticated,service_role',r.sig); execute format('grant execute on function %s to service_role',r.sig); end loop; end $$;

comment on table app_auth.sis_command_receipts is 'Private replay receipts for v1.3 SIS commands.';
comment on function public.get_my_admin_contexts() is 'Current actor administrative contexts and effective SIS permissions.';

commit;
