begin;

create extension if not exists btree_gist with schema extensions;

create type public.teaching_assignment_role as enum ('lead','co_teacher','assistant','substitute');
create type public.teaching_assignment_status as enum ('active','ended','reassigned','corrected');

create table public.teaching_assignments (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null, school_id uuid not null,
 campus_id uuid not null, academic_year_id uuid not null, section_id uuid not null, subject_id uuid,
 staff_profile_id uuid not null, role public.teaching_assignment_role not null,
 starts_on date not null, scheduled_ends_on date not null, ended_on date,
 effective_range daterange not null, status public.teaching_assignment_status not null default 'active',
 end_reason text check(end_reason is null or length(btrim(end_reason)) between 1 and 500),
 reassigned_to_assignment_id uuid, supersedes_assignment_id uuid,
 correction_reason text check(correction_reason is null or length(btrim(correction_reason)) between 1 and 500),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 created_by uuid not null references auth.users(id) on delete restrict,
 updated_by uuid not null references auth.users(id) on delete restrict,
 foreign key(organization_id,school_id,campus_id,academic_year_id,section_id)
  references public.sections(organization_id,school_id,campus_id,academic_year_id,id) on delete restrict,
 foreign key(organization_id,school_id,subject_id)
  references public.subjects(organization_id,school_id,id) on delete restrict,
 foreign key(organization_id,staff_profile_id)
  references public.staff_profiles(organization_id,id) on delete restrict,
 foreign key(organization_id,reassigned_to_assignment_id)
  references public.teaching_assignments(organization_id,id) on delete restrict deferrable initially deferred,
 foreign key(organization_id,supersedes_assignment_id)
  references public.teaching_assignments(organization_id,id) on delete restrict,
 unique(organization_id,id),
 check(starts_on<=scheduled_ends_on),
 check(ended_on is null or ended_on between starts_on and scheduled_ends_on),
 check(effective_range=daterange(starts_on,coalesce(ended_on,scheduled_ends_on),'[]')),
 check((status='active' and ended_on is null and end_reason is null and correction_reason is null and reassigned_to_assignment_id is null)
    or (status='ended' and ended_on is not null and end_reason is not null and correction_reason is null and reassigned_to_assignment_id is null)
    or (status='reassigned' and ended_on is not null and end_reason is not null and correction_reason is null and reassigned_to_assignment_id is not null)
    or (status='corrected' and correction_reason is not null)),
 check(reassigned_to_assignment_id is null or reassigned_to_assignment_id<>id),
 check(supersedes_assignment_id is null or supersedes_assignment_id<>id)
);

alter table public.teaching_assignments add constraint teaching_assignments_one_homeroom_lead
 exclude using gist(section_id with =,effective_range with &&)
 where(status='active' and role='lead' and subject_id is null);
alter table public.teaching_assignments add constraint teaching_assignments_one_subject_lead
 exclude using gist(section_id with =,subject_id with =,effective_range with &&)
 where(status='active' and role='lead' and subject_id is not null);

create index teaching_assignments_scope_idx on public.teaching_assignments(organization_id,school_id,campus_id,academic_year_id,section_id,status);
create index teaching_assignments_staff_idx on public.teaching_assignments(organization_id,staff_profile_id,status,starts_on,scheduled_ends_on);
create index teaching_assignments_subject_idx on public.teaching_assignments(organization_id,school_id,subject_id,status) where subject_id is not null;
create index teaching_assignments_reassigned_to_idx on public.teaching_assignments(organization_id,reassigned_to_assignment_id) where reassigned_to_assignment_id is not null;
create index teaching_assignments_supersedes_idx on public.teaching_assignments(organization_id,supersedes_assignment_id) where supersedes_assignment_id is not null;
create index teaching_assignments_created_by_idx on public.teaching_assignments(created_by);
create index teaching_assignments_updated_by_idx on public.teaching_assignments(updated_by);
create trigger teaching_assignments_updated_at before update on public.teaching_assignments for each row execute function public.set_updated_at();

create function app_auth.enforce_teaching_assignment_immutability() returns trigger
language plpgsql set search_path='' as $$ begin
 if new.organization_id is distinct from old.organization_id
  or new.school_id is distinct from old.school_id or new.campus_id is distinct from old.campus_id
  or new.academic_year_id is distinct from old.academic_year_id or new.section_id is distinct from old.section_id
  or new.subject_id is distinct from old.subject_id or new.staff_profile_id is distinct from old.staff_profile_id
  or new.role is distinct from old.role or new.starts_on is distinct from old.starts_on
  or new.scheduled_ends_on is distinct from old.scheduled_ends_on
  or new.created_by is distinct from old.created_by or new.created_at is distinct from old.created_at
 then raise exception using errcode='22023',message='teaching assignment immutable fields cannot change'; end if;
 return new;
end $$;
create trigger teaching_assignments_immutable before update on public.teaching_assignments
for each row execute function app_auth.enforce_teaching_assignment_immutability();

alter table public.teaching_assignments enable row level security;
alter table public.teaching_assignments force row level security;

insert into public.permissions(code,module,description) values
 ('teaching_assignments.view','teaching_assignments','View teaching assignments within assigned scope'),
 ('teaching_assignments.manage','teaching_assignments','Create, end, and reassign teaching assignments within assigned scope'),
 ('teaching_assignments.correct','teaching_assignments','Correct teaching assignment history within assigned scope');

create function app_auth.is_current_assigned_teacher_for_section(p_section uuid,p_staff uuid default null) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(
  select 1 from public.teaching_assignments t
  join public.staff_profiles sp on sp.organization_id=t.organization_id and sp.id=t.staff_profile_id and sp.status='active'
  join public.organization_memberships m on m.organization_id=sp.organization_id and m.id=sp.organization_membership_id and m.status='active'
  join public.sections s on s.id=t.section_id and s.status='active'
  join public.academic_years y on y.id=t.academic_year_id and y.status='active'
  left join public.subjects u on u.id=t.subject_id and u.organization_id=t.organization_id and u.school_id=t.school_id
  where t.section_id=p_section and (p_staff is null or t.staff_profile_id=p_staff)
   and t.status='active' and current_date <@ t.effective_range
   and m.user_id=auth.uid() and (t.subject_id is null or u.status='active')
 );
$$;

create function app_auth.is_current_assigned_teacher_for_enrollment(p_enrollment uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(
  select 1 from public.student_enrollments e
  join public.student_section_placements p on p.student_enrollment_id=e.id and p.status<>'corrected'
  join public.sections s on s.id=p.section_id
  where e.id=p_enrollment and e.status<>'corrected' and current_date <@ e.enrollment_range
   and current_date between p.starts_on and coalesce(p.ends_on,s.end_date)
   and app_auth.is_current_assigned_teacher_for_section(p.section_id,null)
 );
$$;

create function app_auth.is_current_assigned_teacher_for_student(p_student uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(
  select 1 from public.student_enrollments e
  where e.student_id=p_student and app_auth.is_current_assigned_teacher_for_enrollment(e.id)
 );
$$;

create policy teaching_assignments_select on public.teaching_assignments for select to authenticated using(
 app_auth.has_permission(organization_id,'teaching_assignments.view',school_id,campus_id)
 or app_auth.has_permission(organization_id,'teaching_assignments.manage',school_id,campus_id)
 or app_auth.is_current_assigned_teacher_for_section(section_id,staff_profile_id)
);
revoke all on public.teaching_assignments from public,anon,authenticated;
grant select on public.teaching_assignments to authenticated;

drop policy sections_select on public.sections;
create policy sections_select on public.sections for select to authenticated using(
 app_auth.has_permission(organization_id,'academic_structure.view',school_id,campus_id)
 or app_auth.has_permission(organization_id,'academic_structure.manage',school_id,campus_id)
 or app_auth.is_current_assigned_teacher_for_section(id,null));

drop policy student_enrollments_select on public.student_enrollments;
create policy student_enrollments_select on public.student_enrollments for select to authenticated using(
 app_auth.can_view_enrollment(organization_id,student_id,school_id,null)
 or exists(select 1 from public.student_section_placements p where p.student_enrollment_id=id
  and app_auth.can_view_enrollment(organization_id,student_id,school_id,p.campus_id))
 or app_auth.is_current_assigned_teacher_for_enrollment(id));

drop policy student_section_placements_select on public.student_section_placements;
create policy student_section_placements_select on public.student_section_placements for select to authenticated using(
 app_auth.can_view_enrollment(organization_id,student_id,school_id,campus_id)
 or (status<>'corrected' and app_auth.is_current_assigned_teacher_for_enrollment(student_enrollment_id)));

drop policy students_select on public.students;
create policy students_select on public.students for select to authenticated using(
 app_auth.can_view_student(organization_id,id) or app_auth.is_current_assigned_teacher_for_student(id));

-- Academic-year and subject policies use already-filtered section/assignment rows;
-- they add no new helper grants or mutation authority.
drop policy academic_years_select on public.academic_years;
create policy academic_years_select on public.academic_years for select to authenticated using(
 app_auth.has_permission(organization_id,'academic_periods.view',school_id)
 or app_auth.has_permission(organization_id,'academic_periods.manage',school_id)
 or exists(select 1 from public.sections s where s.academic_year_id=id and app_auth.is_current_assigned_teacher_for_section(s.id,null)));

drop policy subjects_select on public.subjects;
create policy subjects_select on public.subjects for select to authenticated using(
 app_auth.can_read_catalog(organization_id,school_id,'academic_structure.view')
 or app_auth.can_read_catalog(organization_id,school_id,'academic_structure.manage')
 or exists(select 1 from public.teaching_assignments t where t.subject_id=id));

create function app_auth.assert_teaching_actor() returns uuid
language plpgsql security definer set search_path='' as $$
declare a uuid:=auth.uid(); begin if a is null then raise exception using errcode='42501',message='authentication required'; end if; return a; end $$;

create function app_auth.assert_teaching_permission(o uuid,s uuid,c uuid,p_correct boolean default false) returns void
language plpgsql security definer set search_path='' as $$ begin
 if not app_auth.has_permission(o,'teaching_assignments.manage',s,c) then raise exception using errcode='42501',message='teaching_assignments.manage permission is required'; end if;
 if p_correct and not app_auth.has_permission(o,'teaching_assignments.correct',s,c) then raise exception using errcode='42501',message='teaching_assignments.correct permission is required'; end if;
end $$;

create function app_auth.write_teaching_change(p_cmd uuid,p_org uuid,p_actor uuid,p_action text,p_id uuid,p_before jsonb,p_after jsonb,p_payload jsonb) returns void
language plpgsql security definer set search_path='' as $$ begin
 insert into public.audit_log(command_id,organization_id,actor_user_id,action,entity_type,entity_id,before_data,after_data)
 values(p_cmd,p_org,p_actor,p_action,'teaching_assignment',p_id,p_before,p_after);
 insert into public.event_outbox(command_id,organization_id,event_type,aggregate_type,aggregate_id,payload)
 values(p_cmd,p_org,p_action,'teaching_assignment',p_id,p_payload||jsonb_build_object('command_id',p_cmd,'actor_user_id',p_actor,'organization_id',p_org,'assignment_id',p_id,'aggregate_id',p_id));
end $$;

create function app_auth.lock_teaching_parents(p_section_ids uuid[],p_subject_ids uuid[],p_staff_ids uuid[]) returns void
language plpgsql security definer set search_path='' as $$
declare v_orgs uuid[]; v_schools uuid[]; v_campuses uuid[]; v_years uuid[]; v_memberships uuid[]; begin
 select array_agg(distinct organization_id),array_agg(distinct school_id),array_agg(distinct campus_id),array_agg(distinct academic_year_id)
 into v_orgs,v_schools,v_campuses,v_years from public.sections where id=any(p_section_ids);
 perform 1 from public.organizations where id=any(coalesce(v_orgs,'{}')) order by id for update;
 perform 1 from public.schools where id=any(coalesce(v_schools,'{}')) order by id for update;
 perform 1 from public.campuses where id=any(coalesce(v_campuses,'{}')) order by id for update;
 perform 1 from public.academic_years where id=any(coalesce(v_years,'{}')) order by id for update;
 perform 1 from public.sections where id=any(p_section_ids) order by id for update;
 perform 1 from public.subjects where id=any(coalesce(p_subject_ids,'{}')) order by id for update;
 select array_agg(distinct organization_membership_id) into v_memberships from public.staff_profiles where id=any(p_staff_ids);
 perform 1 from public.organization_memberships where id=any(coalesce(v_memberships,'{}')) order by id for update;
 perform 1 from public.staff_profiles where id=any(p_staff_ids) order by id for update;
end $$;

create function app_auth.assert_teaching_assignment_insert(p_section uuid,p_staff uuid,p_subject uuid,p_start date,p_scheduled_end date,p_supersedes uuid default null) returns public.sections
language plpgsql security definer set search_path='' as $$
declare s public.sections%rowtype; y public.academic_years%rowtype; sp public.staff_profiles%rowtype; m public.organization_memberships%rowtype; u public.subjects%rowtype; begin
 perform app_auth.lock_teaching_parents(array[p_section],case when p_subject is null then '{}'::uuid[] else array[p_subject] end,array[p_staff]);
 select * into s from public.sections where id=p_section; if not found then raise exception using errcode='P0002',message='section not found'; end if;
 select * into y from public.academic_years where id=s.academic_year_id;
 select * into sp from public.staff_profiles where id=p_staff; if not found then raise exception using errcode='P0002',message='staff profile not found'; end if;
 select * into m from public.organization_memberships where id=sp.organization_membership_id;
 if s.status<>'active' or y.status<>'active' then raise exception using errcode='22023',message='active section and academic year are required'; end if;
 if sp.organization_id<>s.organization_id or sp.status<>'active' or m.status<>'active' then raise exception using errcode='22023',message='active same-tenant staff profile and membership are required'; end if;
 if p_subject is not null then select * into u from public.subjects where id=p_subject; if not found or u.organization_id<>s.organization_id or u.school_id<>s.school_id or u.status<>'active' then raise exception using errcode='22023',message='active subject in the section school is required'; end if; end if;
 if p_start is null or p_scheduled_end is null or p_start<s.start_date or p_scheduled_end>s.end_date or p_start<y.start_date or p_scheduled_end>y.end_date then raise exception using errcode='22023',message='assignment dates must be inside section and academic year'; end if;
 if p_start>p_scheduled_end then raise exception using errcode='22023',message='assignment start must not follow scheduled end'; end if;
 perform app_auth.assert_teaching_permission(s.organization_id,s.school_id,s.campus_id,false);
 if p_supersedes is not null and not exists(select 1 from public.teaching_assignments q where q.id=p_supersedes and q.status='corrected') then raise exception using errcode='22023',message='replacement must supersede a corrected assignment'; end if;
 perform 1 from public.teaching_assignments q where q.section_id=s.id and q.status='active' and q.role='lead' and q.subject_id is not distinct from p_subject and q.effective_range&&daterange(p_start,p_scheduled_end,'[]') order by q.id for update;
 return s;
end $$;

create function app_auth.create_teaching_assignment_impl(p_section uuid,p_staff uuid,p_subject uuid,p_role public.teaching_assignment_role,p_start date,p_scheduled_end date,p_supersedes uuid default null,p_cmd uuid default null,p_id uuid default null,p_action text default 'teaching_assignment.created') returns uuid
language plpgsql security definer set search_path='' as $$
declare a uuid:=app_auth.assert_teaching_actor(); s public.sections%rowtype; sp public.staff_profiles%rowtype; r uuid:=coalesce(p_id,gen_random_uuid()); j jsonb; cmd uuid:=coalesce(p_cmd,gen_random_uuid()); begin
 s:=app_auth.assert_teaching_assignment_insert(p_section,p_staff,p_subject,p_start,p_scheduled_end,p_supersedes);
 select * into sp from public.staff_profiles where id=p_staff;
 insert into public.teaching_assignments(id,organization_id,school_id,campus_id,academic_year_id,section_id,subject_id,staff_profile_id,role,starts_on,scheduled_ends_on,effective_range,supersedes_assignment_id,created_by,updated_by)
 values(r,s.organization_id,s.school_id,s.campus_id,s.academic_year_id,s.id,p_subject,sp.id,p_role,p_start,p_scheduled_end,daterange(p_start,p_scheduled_end,'[]'),p_supersedes,a,a) returning to_jsonb(teaching_assignments.*) into j;
 if p_action not in ('teaching_assignment.created','teaching_assignment.reassigned_in') then raise exception using errcode='22023',message='invalid assignment creation action'; end if;
 perform app_auth.write_teaching_change(cmd,s.organization_id,a,p_action,r,null,j,jsonb_strip_nulls(jsonb_build_object('school_id',s.school_id,'campus_id',s.campus_id,'academic_year_id',s.academic_year_id,'section_id',s.id,'subject_id',p_subject,'staff_profile_id',sp.id,'role',p_role,'starts_on',p_start,'scheduled_ends_on',p_scheduled_end,'supersedes_assignment_id',p_supersedes)));
 return r;
end $$;

create function app_auth.end_teaching_assignment_impl(p_id uuid,p_end date,p_reason text,p_status public.teaching_assignment_status default 'ended',p_cmd uuid default null,p_to uuid default null) returns uuid
language plpgsql security definer set search_path='' as $$
declare a uuid:=app_auth.assert_teaching_actor(); t public.teaching_assignments%rowtype; oldj jsonb; newj jsonb; cmd uuid:=coalesce(p_cmd,gen_random_uuid()); action text; begin
 select * into t from public.teaching_assignments where id=p_id; if not found then raise exception using errcode='P0002',message='teaching assignment not found'; end if;
 perform app_auth.lock_teaching_parents(array[t.section_id],case when t.subject_id is null then '{}'::uuid[] else array[t.subject_id] end,array[t.staff_profile_id]);
 perform 1 from public.teaching_assignments where id=t.id or reassigned_to_assignment_id=t.id order by id for update; select * into t from public.teaching_assignments where id=t.id;
 if t.status<>'active' then raise exception using errcode='22023',message='active teaching assignment is required'; end if;
 if p_status not in ('ended','reassigned') then raise exception using errcode='22023',message='invalid assignment outcome'; end if;
 if p_end is null or p_end<t.starts_on or p_end>t.scheduled_ends_on then raise exception using errcode='22023',message='end date must be inside assignment'; end if;
 if length(btrim(coalesce(p_reason,''))) not between 1 and 500 then raise exception using errcode='22023',message='bounded reason is required'; end if;
 if (p_status='reassigned')<>(p_to is not null) then raise exception using errcode='22023',message='reassignment destination is required only for reassignment'; end if;
 perform app_auth.assert_teaching_permission(t.organization_id,t.school_id,t.campus_id,false); oldj:=to_jsonb(t); action:=case when p_status='ended' then 'teaching_assignment.ended' else 'teaching_assignment.reassigned_out' end;
 update public.teaching_assignments set status=p_status,ended_on=p_end,end_reason=btrim(p_reason),reassigned_to_assignment_id=p_to,effective_range=daterange(starts_on,p_end,'[]'),updated_by=a where id=t.id returning to_jsonb(teaching_assignments.*) into newj;
 perform app_auth.write_teaching_change(cmd,t.organization_id,a,action,t.id,oldj,newj,jsonb_strip_nulls(jsonb_build_object('school_id',t.school_id,'campus_id',t.campus_id,'academic_year_id',t.academic_year_id,'section_id',t.section_id,'subject_id',t.subject_id,'staff_profile_id',t.staff_profile_id,'role',t.role,'ended_on',p_end,'reason',btrim(p_reason),'to_assignment_id',p_to)));
 return t.id;
end $$;

create function app_auth.reassign_teaching_assignment_impl(p_id uuid,p_staff uuid,p_role public.teaching_assignment_role,p_on date,p_scheduled_end date,p_reason text)
returns table(from_assignment_id uuid,to_assignment_id uuid) language plpgsql security definer set search_path='' as $$
declare t public.teaching_assignments%rowtype; r uuid:=gen_random_uuid(); cmd uuid:=gen_random_uuid(); a uuid:=app_auth.assert_teaching_actor(); begin
 select * into t from public.teaching_assignments where id=p_id; if not found then raise exception using errcode='P0002',message='teaching assignment not found'; end if;
 perform app_auth.lock_teaching_parents(array[t.section_id],case when t.subject_id is null then '{}'::uuid[] else array[t.subject_id] end,array[t.staff_profile_id,p_staff]);
 perform 1 from public.teaching_assignments where id=t.id or reassigned_to_assignment_id=t.id order by id for update;
 select * into t from public.teaching_assignments where id=t.id;
 if t.status<>'active' then raise exception using errcode='22023',message='active teaching assignment is required'; end if;
 if p_on<=t.starts_on or p_on>t.scheduled_ends_on or p_scheduled_end<p_on then raise exception using errcode='22023',message='reassignment dates are invalid'; end if;
 -- Validate every replacement parent and date before mutating the source. The real
 -- insertion below uses the same validator again after releasing the old lead range.
 perform app_auth.assert_teaching_assignment_insert(t.section_id,p_staff,t.subject_id,p_on,p_scheduled_end,null);
 perform app_auth.end_teaching_assignment_impl(t.id,p_on-1,p_reason,'reassigned',cmd,r);
 perform app_auth.create_teaching_assignment_impl(t.section_id,p_staff,t.subject_id,p_role,p_on,p_scheduled_end,null,cmd,r,'teaching_assignment.reassigned_in');
 return query select t.id,r;
end $$;

create function app_auth.correct_teaching_assignment_impl(p_id uuid,p_section uuid,p_staff uuid,p_subject uuid,p_role public.teaching_assignment_role,p_start date,p_scheduled_end date,p_create boolean,p_reason text)
returns table(corrected_assignment_id uuid,replacement_assignment_id uuid) language plpgsql security definer set search_path='' as $$
declare a uuid:=app_auth.assert_teaching_actor(); t public.teaching_assignments%rowtype; s public.sections%rowtype; oldj jsonb; newj jsonb; r uuid; cmd uuid:=gen_random_uuid(); begin
 if length(btrim(coalesce(p_reason,''))) not between 1 and 500 then raise exception using errcode='22023',message='bounded correction reason is required'; end if;
 select * into t from public.teaching_assignments where id=p_id; if not found then raise exception using errcode='P0002',message='teaching assignment not found'; end if;
 perform app_auth.lock_teaching_parents(array[t.section_id,p_section],case when t.subject_id is null and p_subject is null then '{}'::uuid[] else array_remove(array[t.subject_id,p_subject],null) end,array_remove(array[t.staff_profile_id,p_staff],null));
 perform 1 from public.teaching_assignments where id=t.id or reassigned_to_assignment_id=t.id order by id for update; select * into t from public.teaching_assignments where id=t.id;
 if t.status='corrected' then raise exception using errcode='22023',message='corrected assignment is terminal'; end if;
 if t.reassigned_to_assignment_id is not null or exists(select 1 from public.teaching_assignments q where q.reassigned_to_assignment_id=t.id) then raise exception using errcode='22023',message='reassigned assignment history cannot be corrected'; end if;
 perform app_auth.assert_teaching_permission(t.organization_id,t.school_id,t.campus_id,true);
 if p_create then select * into s from public.sections where id=p_section; if not found then raise exception using errcode='P0002',message='replacement section not found'; end if; perform app_auth.assert_teaching_permission(s.organization_id,s.school_id,s.campus_id,true); end if;
 oldj:=to_jsonb(t); update public.teaching_assignments set status='corrected',correction_reason=btrim(p_reason),updated_by=a where id=t.id returning to_jsonb(teaching_assignments.*) into newj;
 perform app_auth.write_teaching_change(cmd,t.organization_id,a,'teaching_assignment.corrected',t.id,oldj,newj,jsonb_strip_nulls(jsonb_build_object('school_id',t.school_id,'campus_id',t.campus_id,'academic_year_id',t.academic_year_id,'section_id',t.section_id,'subject_id',t.subject_id,'staff_profile_id',t.staff_profile_id,'role',t.role,'correction_reason',btrim(p_reason))));
 if p_create then r:=app_auth.create_teaching_assignment_impl(p_section,p_staff,p_subject,p_role,p_start,p_scheduled_end,t.id,cmd); end if;
 return query select t.id,r;
end $$;

create function public.create_teaching_assignment(section_id uuid,staff_profile_id uuid,subject_id uuid,role public.teaching_assignment_role,starts_on date,scheduled_ends_on date) returns uuid
language sql security definer set search_path='' as $$ select app_auth.create_teaching_assignment_impl(section_id,staff_profile_id,subject_id,role,starts_on,scheduled_ends_on); $$;
create function public.end_teaching_assignment(id uuid,ended_on date,reason text) returns uuid
language sql security definer set search_path='' as $$ select app_auth.end_teaching_assignment_impl(id,ended_on,reason); $$;
create function public.reassign_teaching_assignment(id uuid,replacement_staff_profile_id uuid,replacement_role public.teaching_assignment_role,reassign_on date,replacement_scheduled_ends_on date,reason text)
returns table(from_assignment_id uuid,to_assignment_id uuid) language sql security definer set search_path='' as $$ select * from app_auth.reassign_teaching_assignment_impl(id,replacement_staff_profile_id,replacement_role,reassign_on,replacement_scheduled_ends_on,reason); $$;
create function public.correct_teaching_assignment(id uuid,replacement_section_id uuid,replacement_staff_profile_id uuid,replacement_subject_id uuid,replacement_role public.teaching_assignment_role,replacement_starts_on date,replacement_scheduled_ends_on date,create_replacement boolean,correction_reason text)
returns table(corrected_assignment_id uuid,replacement_assignment_id uuid) language sql security definer set search_path='' as $$ select * from app_auth.correct_teaching_assignment_impl(id,replacement_section_id,replacement_staff_profile_id,replacement_subject_id,replacement_role,replacement_starts_on,replacement_scheduled_ends_on,create_replacement,correction_reason); $$;

-- Preserve v0.5 section behavior and add assignment compatibility checks.
create or replace function public.update_section(id uuid,code text,name text,capacity integer,start_date date,end_date date,academic_term_id uuid,homeroom_room_id uuid,status public.record_status,set_academic_term_id boolean default false,set_homeroom_room_id boolean default false) returns uuid
language plpgsql security definer set search_path='' as $$ declare r uuid; begin
 r:=app_auth.update_section_v0_3_impl(id,code,name,capacity,start_date,end_date,academic_term_id,homeroom_room_id,status,set_academic_term_id,set_homeroom_room_id);
 if exists(select 1 from public.student_section_placements p where p.section_id=update_section.id and p.status='active') and (update_section.status<>'active' or update_section.capacity<(select count(*) from public.student_section_placements p where p.section_id=update_section.id and p.status='active') or exists(select 1 from public.student_section_placements p where p.section_id=update_section.id and p.status<>'corrected' and (p.starts_on<update_section.start_date or coalesce(p.ends_on,p.starts_on)>update_section.end_date))) then raise exception using errcode='22023',message='section change conflicts with placement history or capacity'; end if;
 if exists(select 1 from public.teaching_assignments t where t.section_id=update_section.id and t.status='active') and update_section.status<>'active' then raise exception using errcode='22023',message='section has active teaching assignments'; end if;
 if exists(select 1 from public.teaching_assignments t where t.section_id=update_section.id and t.status<>'corrected' and (t.starts_on<update_section.start_date or t.scheduled_ends_on>update_section.end_date)) then raise exception using errcode='22023',message='section dates exclude teaching assignment history'; end if;
 return r;
end $$;
create or replace function public.archive_section(id uuid) returns uuid language plpgsql security definer set search_path='' as $$ declare r uuid; begin
 r:=app_auth.archive_section_v0_3_impl(id);
 if exists(select 1 from public.student_section_placements p where p.section_id=archive_section.id and p.status='active') then raise exception using errcode='22023',message='section has active placements'; end if;
 if exists(select 1 from public.teaching_assignments t where t.section_id=archive_section.id and t.status='active') then raise exception using errcode='22023',message='section has active teaching assignments'; end if;
 return r;
end $$;

-- Extend the existing academic audit hook so year changes fail in the same transaction.
create or replace function app_auth.write_academic_change(o uuid,actor uuid,action_name text,entity_name text,entity uuid,before_row jsonb,after_row jsonb) returns void
language plpgsql security definer set search_path='' as $$
declare cmd uuid:=gen_random_uuid(); row_data jsonb:=coalesce(after_row,before_row,'{}'); changed jsonb;
 school uuid:=(row_data->>'school_id')::uuid; campus uuid:=(row_data->>'campus_id')::uuid;
 academic_year uuid:=coalesce((row_data->>'academic_year_id')::uuid,case when entity_name='academic_year' then entity end);
 academic_term uuid:=coalesce((row_data->>'academic_term_id')::uuid,case when entity_name='academic_term' then entity end); event_payload jsonb;
begin
 if entity_name='academic_year' and action_name='academic_year.status_changed' and after_row->>'status' in ('closed','archived')
  and exists(select 1 from public.student_enrollments e where e.academic_year_id=entity and e.status='active') then raise exception using errcode='22023',message='academic year has active enrollments'; end if;
 if entity_name='academic_year' and action_name='academic_year.updated' and exists(select 1 from public.student_enrollments e where e.academic_year_id=entity and e.status<>'corrected' and (e.enrolled_on<(after_row->>'start_date')::date or e.scheduled_end_on>(after_row->>'end_date')::date)) then raise exception using errcode='22023',message='academic year dates exclude enrollment history'; end if;
 if entity_name='academic_year' and action_name='academic_year.status_changed' and after_row->>'status' in ('closed','archived') and exists(select 1 from public.teaching_assignments t where t.academic_year_id=entity and t.status='active') then raise exception using errcode='22023',message='academic year has active teaching assignments'; end if;
 if entity_name='academic_year' and action_name='academic_year.updated' and exists(select 1 from public.teaching_assignments t where t.academic_year_id=entity and t.status<>'corrected' and (t.starts_on<(after_row->>'start_date')::date or t.scheduled_ends_on>(after_row->>'end_date')::date)) then raise exception using errcode='22023',message='academic year dates exclude teaching assignment history'; end if;
 if school is null and academic_year is not null then select y.school_id into school from public.academic_years y where y.id=academic_year; end if;
 select coalesce(jsonb_agg(k order by k),'[]') into changed from(select x.key k from jsonb_object_keys(coalesce(before_row,'{}')||coalesce(after_row,'{}')) x(key) where before_row->x.key is distinct from after_row->x.key) q;
 event_payload:=jsonb_strip_nulls(jsonb_build_object('command_id',cmd,'actor_user_id',actor,'organization_id',o,'entity_id',entity,'aggregate_id',entity,'school_id',school,'campus_id',campus,'academic_year_id',academic_year,'academic_term_id',academic_term,'changed_fields',changed,'before_status',before_row->>'status','after_status',after_row->>'status'));
 insert into public.audit_log(command_id,organization_id,actor_user_id,action,entity_type,entity_id,before_data,after_data) values(cmd,o,actor,action_name,entity_name,entity,before_row,after_row);
 insert into public.event_outbox(command_id,organization_id,event_type,aggregate_type,aggregate_id,payload) values(cmd,o,action_name,entity_name,entity,event_payload);
end $$;

alter table public.teaching_assignments owner to postgres;
do $$ declare p regprocedure; begin foreach p in array array[
 'public.create_teaching_assignment(uuid,uuid,uuid,public.teaching_assignment_role,date,date)'::regprocedure,
 'public.end_teaching_assignment(uuid,date,text)'::regprocedure,
 'public.reassign_teaching_assignment(uuid,uuid,public.teaching_assignment_role,date,date,text)'::regprocedure,
 'public.correct_teaching_assignment(uuid,uuid,uuid,uuid,public.teaching_assignment_role,date,date,boolean,text)'::regprocedure]
 loop execute format('alter function %s owner to postgres',p); execute format('revoke all on function %s from public,anon',p); execute format('grant execute on function %s to authenticated,service_role',p); end loop; end $$;

do $$ declare p regprocedure; begin foreach p in array array[
 'app_auth.is_current_assigned_teacher_for_section(uuid,uuid)'::regprocedure,'app_auth.is_current_assigned_teacher_for_enrollment(uuid)'::regprocedure,'app_auth.is_current_assigned_teacher_for_student(uuid)'::regprocedure,
 'app_auth.enforce_teaching_assignment_immutability()'::regprocedure,
 'app_auth.assert_teaching_actor()'::regprocedure,'app_auth.assert_teaching_permission(uuid,uuid,uuid,boolean)'::regprocedure,
 'app_auth.write_teaching_change(uuid,uuid,uuid,text,uuid,jsonb,jsonb,jsonb)'::regprocedure,'app_auth.lock_teaching_parents(uuid[],uuid[],uuid[])'::regprocedure,
 'app_auth.assert_teaching_assignment_insert(uuid,uuid,uuid,date,date,uuid)'::regprocedure,
 'app_auth.create_teaching_assignment_impl(uuid,uuid,uuid,public.teaching_assignment_role,date,date,uuid,uuid,uuid,text)'::regprocedure,
 'app_auth.end_teaching_assignment_impl(uuid,date,text,public.teaching_assignment_status,uuid,uuid)'::regprocedure,
 'app_auth.reassign_teaching_assignment_impl(uuid,uuid,public.teaching_assignment_role,date,date,text)'::regprocedure,
 'app_auth.correct_teaching_assignment_impl(uuid,uuid,uuid,uuid,public.teaching_assignment_role,date,date,boolean,text)'::regprocedure]
 loop execute format('alter function %s owner to postgres',p); execute format('revoke all on function %s from public,anon,authenticated,service_role',p); end loop; end $$;
grant execute on function app_auth.is_current_assigned_teacher_for_section(uuid,uuid),app_auth.is_current_assigned_teacher_for_enrollment(uuid),app_auth.is_current_assigned_teacher_for_student(uuid) to authenticated;

comment on table public.teaching_assignments is 'Immutable effective-dated teaching responsibility history; writes use typed commands.';
comment on function app_auth.is_current_assigned_teacher_for_section(uuid,uuid) is 'Non-recursive contextual RLS relationship helper; optional staff discriminator binds assignment-row reads to the assignee.';
comment on function public.correct_teaching_assignment(uuid,uuid,uuid,uuid,public.teaching_assignment_role,date,date,boolean,text) is 'Append-only correction; rejects every assignment participating in a reassignment link.';

commit;
