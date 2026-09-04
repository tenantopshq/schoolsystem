begin;

create type public.attendance_session_status as enum ('open','submitted','finalized','corrected');
create type public.attendance_mark_status as enum ('present','absent','late','excused');
create type public.attendance_mark_input as (
 student_id uuid, mark public.attendance_mark_status, arrival_time time,
 absence_reason_id uuid, note text
);

-- Additional composite keys let attendance prove provenance without changing prior rows.
create unique index student_section_placements_attendance_provenance_key on public.student_section_placements
 (organization_id,school_id,campus_id,academic_year_id,section_id,student_id,student_enrollment_id,id);

create table public.attendance_absence_reasons (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null, school_id uuid not null, campus_id uuid,
 code text not null check(length(btrim(code)) between 1 and 32),
 name text not null check(length(btrim(name)) between 1 and 100),
 description text check(description is null or length(btrim(description)) between 1 and 500),
 status public.record_status not null default 'active',
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 created_by uuid not null references auth.users(id) on delete restrict,
 updated_by uuid not null references auth.users(id) on delete restrict,
 foreign key(organization_id,school_id) references public.schools(organization_id,id) on delete restrict,
 foreign key(organization_id,campus_id) references public.campuses(organization_id,id) on delete restrict,
 foreign key(school_id,campus_id) references public.campuses(school_id,id) on delete restrict,
 unique(organization_id,id), unique(organization_id,school_id,id),
 check(campus_id is null or school_id is not null)
);
create unique index attendance_reasons_scope_code_key on public.attendance_absence_reasons
 (school_id,coalesce(campus_id,'00000000-0000-0000-0000-000000000000'::uuid),lower(btrim(code)));
create unique index attendance_reasons_scope_name_key on public.attendance_absence_reasons
 (school_id,coalesce(campus_id,'00000000-0000-0000-0000-000000000000'::uuid),lower(btrim(name)));
create index attendance_reasons_scope_idx on public.attendance_absence_reasons(organization_id,school_id,campus_id,status);
create index attendance_reasons_created_by_idx on public.attendance_absence_reasons(created_by);
create index attendance_reasons_updated_by_idx on public.attendance_absence_reasons(updated_by);
create trigger attendance_reasons_updated_at before update on public.attendance_absence_reasons
 for each row execute function public.set_updated_at();

create table public.attendance_sessions (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null, school_id uuid not null,
 campus_id uuid not null, academic_year_id uuid not null, section_id uuid not null, session_date date not null,
 status public.attendance_session_status not null default 'open',
 submitted_at timestamptz, finalized_at timestamptz,
 submitted_by uuid references auth.users(id) on delete restrict,
 finalized_by uuid references auth.users(id) on delete restrict,
 supersedes_session_id uuid, correction_reason text
  check(correction_reason is null or length(btrim(correction_reason)) between 1 and 500),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 created_by uuid not null references auth.users(id) on delete restrict,
 updated_by uuid not null references auth.users(id) on delete restrict,
 foreign key(organization_id,school_id,campus_id,academic_year_id,section_id)
  references public.sections(organization_id,school_id,campus_id,academic_year_id,id) on delete restrict,
 foreign key(organization_id,supersedes_session_id)
  references public.attendance_sessions(organization_id,id) on delete restrict,
 unique(organization_id,id),
 unique(organization_id,school_id,campus_id,academic_year_id,section_id,id),
 check(supersedes_session_id is null or supersedes_session_id<>id),
 check((status='open' and submitted_at is null and submitted_by is null and finalized_at is null and finalized_by is null and correction_reason is null)
  or (status='submitted' and submitted_at is not null and submitted_by is not null and finalized_at is null and finalized_by is null and correction_reason is null)
  or (status='finalized' and submitted_at is not null and submitted_by is not null and finalized_at is not null and finalized_by is not null and correction_reason is null)
  or (status='corrected' and submitted_at is not null and submitted_by is not null and finalized_at is not null and finalized_by is not null and correction_reason is not null))
);
create unique index attendance_sessions_live_section_date_key on public.attendance_sessions(section_id,session_date)
 where status<>'corrected';
create unique index attendance_sessions_one_successor_key on public.attendance_sessions(supersedes_session_id)
 where supersedes_session_id is not null;
create index attendance_sessions_scope_idx on public.attendance_sessions(organization_id,school_id,campus_id,academic_year_id,section_id,session_date,status);
create index attendance_sessions_created_by_idx on public.attendance_sessions(created_by);
create index attendance_sessions_updated_by_idx on public.attendance_sessions(updated_by);
create index attendance_sessions_submitted_by_idx on public.attendance_sessions(submitted_by) where submitted_by is not null;
create index attendance_sessions_finalized_by_idx on public.attendance_sessions(finalized_by) where finalized_by is not null;
create trigger attendance_sessions_updated_at before update on public.attendance_sessions
 for each row execute function public.set_updated_at();

create table public.attendance_session_students (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null, school_id uuid not null,
 campus_id uuid not null, academic_year_id uuid not null, section_id uuid not null, session_id uuid not null,
 student_id uuid not null, student_enrollment_id uuid not null, student_section_placement_id uuid not null,
 created_at timestamptz not null default now(), created_by uuid not null references auth.users(id) on delete restrict,
 foreign key(organization_id,school_id,campus_id,academic_year_id,section_id,session_id)
  references public.attendance_sessions(organization_id,school_id,campus_id,academic_year_id,section_id,id) on delete restrict,
 foreign key(organization_id,student_id) references public.students(organization_id,id) on delete restrict,
 foreign key(organization_id,school_id,academic_year_id,student_id,student_enrollment_id)
  references public.student_enrollments(organization_id,school_id,academic_year_id,student_id,id) on delete restrict,
 foreign key(organization_id,school_id,campus_id,academic_year_id,section_id,student_id,student_enrollment_id,student_section_placement_id)
  references public.student_section_placements(organization_id,school_id,campus_id,academic_year_id,section_id,student_id,student_enrollment_id,id) on delete restrict,
 unique(organization_id,id), unique(session_id,student_id), unique(session_id,student_section_placement_id),
 unique(organization_id,school_id,campus_id,academic_year_id,section_id,session_id,student_id,id)
);
create index attendance_session_students_session_idx on public.attendance_session_students(organization_id,session_id,student_id);
create index attendance_session_students_student_idx on public.attendance_session_students(organization_id,student_id,session_id);
create index attendance_session_students_enrollment_idx on public.attendance_session_students(organization_id,student_enrollment_id);
create index attendance_session_students_placement_idx on public.attendance_session_students(organization_id,student_section_placement_id);
create index attendance_session_students_created_by_idx on public.attendance_session_students(created_by);

create table public.attendance_marks (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null, school_id uuid not null,
 campus_id uuid not null, academic_year_id uuid not null, section_id uuid not null, session_id uuid not null,
 session_student_id uuid not null, student_id uuid not null, mark public.attendance_mark_status not null,
 arrival_time time, absence_reason_id uuid,
 note text check(note is null or length(btrim(note)) between 1 and 500),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 created_by uuid not null references auth.users(id) on delete restrict,
 updated_by uuid not null references auth.users(id) on delete restrict,
 foreign key(organization_id,school_id,campus_id,academic_year_id,section_id,session_id)
  references public.attendance_sessions(organization_id,school_id,campus_id,academic_year_id,section_id,id) on delete restrict,
 foreign key(organization_id,school_id,campus_id,academic_year_id,section_id,session_id,student_id,session_student_id)
  references public.attendance_session_students(organization_id,school_id,campus_id,academic_year_id,section_id,session_id,student_id,id) on delete restrict,
 foreign key(organization_id,school_id,absence_reason_id)
  references public.attendance_absence_reasons(organization_id,school_id,id) on delete restrict,
 unique(organization_id,id), unique(session_id,student_id),
 check((mark='late' and absence_reason_id is null and note is null)
  or (mark='present' and arrival_time is null and absence_reason_id is null and note is null)
  or (mark in ('absent','excused') and arrival_time is null and absence_reason_id is not null))
);
create index attendance_marks_session_idx on public.attendance_marks(organization_id,session_id,student_id);
create index attendance_marks_session_student_idx on public.attendance_marks(organization_id,session_student_id);
create index attendance_marks_reason_idx on public.attendance_marks(organization_id,school_id,absence_reason_id) where absence_reason_id is not null;
create index attendance_marks_created_by_idx on public.attendance_marks(created_by);
create index attendance_marks_updated_by_idx on public.attendance_marks(updated_by);

create function app_auth.enforce_attendance_session_immutability() returns trigger
language plpgsql set search_path='' as $$ begin
 if new.organization_id is distinct from old.organization_id or new.school_id is distinct from old.school_id
  or new.campus_id is distinct from old.campus_id or new.academic_year_id is distinct from old.academic_year_id
  or new.section_id is distinct from old.section_id or new.session_date is distinct from old.session_date
  or new.supersedes_session_id is distinct from old.supersedes_session_id
  or new.created_at is distinct from old.created_at or new.created_by is distinct from old.created_by
 then raise exception using errcode='22023',message='attendance session immutable fields cannot change'; end if;
 if old.status='corrected' then raise exception using errcode='22023',message='corrected attendance session is terminal'; end if;
 return new;
end $$;
create trigger attendance_sessions_immutable before update on public.attendance_sessions
 for each row execute function app_auth.enforce_attendance_session_immutability();

create function app_auth.enforce_attendance_reason_scope_immutability() returns trigger
language plpgsql set search_path='' as $$ begin
 if new.organization_id is distinct from old.organization_id or new.school_id is distinct from old.school_id
  or new.campus_id is distinct from old.campus_id or new.created_at is distinct from old.created_at
  or new.created_by is distinct from old.created_by then
  raise exception using errcode='22023',message='attendance reason scope cannot change'; end if;
 if old.status='archived' then raise exception using errcode='22023',message='archived attendance reason is terminal'; end if;
 return new;
end $$;
create trigger attendance_reasons_immutable before update on public.attendance_absence_reasons
 for each row execute function app_auth.enforce_attendance_reason_scope_immutability();

create function app_auth.assert_attendance_mark_reason() returns trigger
language plpgsql security definer set search_path='' as $$ declare r public.attendance_absence_reasons%rowtype; begin
 if new.absence_reason_id is not null then
  select * into r from public.attendance_absence_reasons ar where ar.id=new.absence_reason_id;
  if r.id is null or r.organization_id<>new.organization_id or r.school_id<>new.school_id
   or (r.campus_id is not null and r.campus_id<>new.campus_id) then
   raise exception using errcode='22023',message='applicable attendance absence reason is required';
  end if;
 end if;
 return new;
end $$;
create trigger attendance_marks_reason_scope before insert or update on public.attendance_marks
 for each row execute function app_auth.assert_attendance_mark_reason();

insert into public.permissions(code,module,description) values
 ('attendance.view','attendance','View attendance within assigned scope'),
 ('attendance.manage','attendance','Manage attendance sessions and absence reasons within assigned scope'),
 ('attendance.correct','attendance','Correct finalized attendance within assigned scope');

create function app_auth.has_attendance_assignment_on(p_section uuid,p_date date,p_roles public.teaching_assignment_role[]) returns boolean
language sql stable security definer set search_path='' as $$
 select p_date=current_date and exists(
  select 1 from public.teaching_assignments t
  join public.staff_profiles sp on (sp.organization_id,sp.id)=(t.organization_id,t.staff_profile_id) and sp.status='active'
  join public.organization_memberships m on (m.organization_id,m.id)=(sp.organization_id,sp.organization_membership_id)
   and m.status='active' and m.left_at is null
  where t.section_id=p_section and t.status='active' and current_date<@t.effective_range
   and t.role=any(p_roles) and m.user_id=auth.uid());
$$;

create function app_auth.can_read_attendance_session(p_session uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.attendance_sessions s where s.id=p_session and (
  app_auth.has_permission(s.organization_id,'attendance.view',s.school_id,s.campus_id)
  or app_auth.has_permission(s.organization_id,'attendance.manage',s.school_id,s.campus_id)
  or app_auth.has_permission(s.organization_id,'attendance.correct',s.school_id,s.campus_id)
  or app_auth.has_attendance_assignment_on(s.section_id,s.session_date,array['lead','co_teacher','assistant','substitute']::public.teaching_assignment_role[])));
$$;

create function app_auth.can_read_attendance_reason(p_org uuid,p_school uuid,p_campus uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select app_auth.has_permission(p_org,'attendance.view',p_school,p_campus)
  or app_auth.has_permission(p_org,'attendance.manage',p_school,p_campus)
  or app_auth.has_permission(p_org,'attendance.correct',p_school,p_campus)
  or exists(select 1 from public.teaching_assignments t where t.organization_id=p_org and t.school_id=p_school
    and (p_campus is null or t.campus_id=p_campus) and t.status='active' and current_date<@t.effective_range
    and t.role in ('lead','co_teacher','assistant','substitute')
    and app_auth.has_attendance_assignment_on(t.section_id,current_date,array[t.role]));
$$;

alter table public.attendance_absence_reasons enable row level security; alter table public.attendance_absence_reasons force row level security;
alter table public.attendance_sessions enable row level security; alter table public.attendance_sessions force row level security;
alter table public.attendance_session_students enable row level security; alter table public.attendance_session_students force row level security;
alter table public.attendance_marks enable row level security; alter table public.attendance_marks force row level security;
create policy attendance_reasons_select on public.attendance_absence_reasons for select to authenticated using(
 app_auth.can_read_attendance_reason(organization_id,school_id,campus_id));
create policy attendance_sessions_select on public.attendance_sessions for select to authenticated using(app_auth.can_read_attendance_session(id));
create policy attendance_session_students_select on public.attendance_session_students for select to authenticated using(app_auth.can_read_attendance_session(session_id));
create policy attendance_marks_select on public.attendance_marks for select to authenticated using(app_auth.can_read_attendance_session(session_id));
revoke all on public.attendance_absence_reasons,public.attendance_sessions,public.attendance_session_students,public.attendance_marks from public,anon,authenticated;
grant select on public.attendance_absence_reasons,public.attendance_sessions,public.attendance_session_students,public.attendance_marks to authenticated;

create function app_auth.assert_attendance_actor() returns uuid language plpgsql security definer set search_path='' as $$
declare a uuid:=auth.uid(); begin if a is null then raise exception using errcode='42501',message='authentication required'; end if; return a; end $$;

create function app_auth.assert_attendance_manager(o uuid,s uuid,c uuid,p_correct boolean default false) returns void
language plpgsql security definer set search_path='' as $$ begin
 if not app_auth.has_permission(o,'attendance.manage',s,c) then raise exception using errcode='42501',message='attendance.manage permission is required'; end if;
 if p_correct and not app_auth.has_permission(o,'attendance.correct',s,c) then raise exception using errcode='42501',message='attendance.correct permission is required'; end if;
end $$;

create function app_auth.write_attendance_change(p_cmd uuid,p_org uuid,p_actor uuid,p_action text,p_type text,p_id uuid,p_before jsonb,p_after jsonb,p_payload jsonb,p_emit boolean default true) returns void
language plpgsql security definer set search_path='' as $$ begin
 insert into public.audit_log(command_id,organization_id,actor_user_id,action,entity_type,entity_id,before_data,after_data)
 values(p_cmd,p_org,p_actor,p_action,p_type,p_id,p_before,p_after);
 if p_emit then insert into public.event_outbox(command_id,organization_id,event_type,aggregate_type,aggregate_id,payload)
  values(p_cmd,p_org,p_action,p_type,p_id,jsonb_strip_nulls(coalesce(p_payload,'{}')||jsonb_build_object('command_id',p_cmd,'actor_user_id',p_actor,'organization_id',p_org,'aggregate_id',p_id))); end if;
end $$;

create function app_auth.assert_attendance_write_authority(s public.sections,p_date date) returns void
language plpgsql security definer set search_path='' as $$ begin
 if p_date>current_date then raise exception using errcode='22023',message='future attendance sessions are prohibited'; end if;
 if app_auth.has_permission(s.organization_id,'attendance.manage',s.school_id,s.campus_id) then return; end if;
 if p_date<>current_date or not app_auth.has_attendance_assignment_on(s.id,p_date,array['lead','co_teacher','substitute']::public.teaching_assignment_role[]) then
  raise exception using errcode='42501',message='current teaching assignment or attendance.manage permission is required'; end if;
end $$;

create function app_auth.write_roster_snapshot(p_session public.attendance_sessions,p_actor uuid,p_cmd uuid) returns integer
language plpgsql security definer set search_path='' as $$ declare q record; r uuid; n integer:=0; begin
 for q in select p.id placement_id,p.student_id,p.student_enrollment_id
  from public.student_section_placements p join public.student_enrollments e on e.id=p.student_enrollment_id
  where p.section_id=p_session.section_id and p.status<>'corrected' and e.status<>'corrected'
   and p_session.session_date between p.starts_on and coalesce(p.ends_on,p_session.session_date)
   and p_session.session_date<@e.enrollment_range order by p.student_id,p.id
 loop
  if exists(select 1 from public.attendance_session_students x where x.session_id=p_session.id and x.student_id=q.student_id) then
   raise exception using errcode='22023',message='multiple roster placements exist for one student'; end if;
  r:=gen_random_uuid();
  insert into public.attendance_session_students(id,organization_id,school_id,campus_id,academic_year_id,section_id,session_id,student_id,student_enrollment_id,student_section_placement_id,created_by)
  values(r,p_session.organization_id,p_session.school_id,p_session.campus_id,p_session.academic_year_id,p_session.section_id,p_session.id,q.student_id,q.student_enrollment_id,q.placement_id,p_actor);
  perform app_auth.write_attendance_change(p_cmd,p_session.organization_id,p_actor,'attendance.roster_snapshotted','attendance_session_student',r,null,
   (select to_jsonb(x) from public.attendance_session_students x where x.id=r),null,false); n:=n+1;
 end loop; return n;
end $$;

create function public.create_attendance_absence_reason(school_id uuid,campus_id uuid,code text,name text,description text) returns uuid
language plpgsql security definer set search_path='' as $$ declare a uuid:=app_auth.assert_attendance_actor(); s public.schools%rowtype; c public.campuses%rowtype; r uuid:=gen_random_uuid(); j jsonb; cmd uuid:=gen_random_uuid(); begin
 select * into s from public.schools ps where ps.id=create_attendance_absence_reason.school_id for update; if not found or s.status<>'active' then raise exception using errcode='P0002',message='active school not found'; end if;
 if create_attendance_absence_reason.campus_id is not null then select * into c from public.campuses pc where pc.id=create_attendance_absence_reason.campus_id for update; if not found or c.status<>'active' or (c.organization_id,c.school_id)<>(s.organization_id,s.id) then raise exception using errcode='22023',message='active campus in school is required'; end if; end if;
 perform app_auth.assert_attendance_manager(s.organization_id,s.id,create_attendance_absence_reason.campus_id,false);
 if create_attendance_absence_reason.campus_id is null and not (app_auth.has_permission(s.organization_id,'attendance.manage',s.id,null)) then raise exception using errcode='42501',message='school authority is required for school-wide reason'; end if;
 insert into public.attendance_absence_reasons(id,organization_id,school_id,campus_id,code,name,description,created_by,updated_by)
 values(r,s.organization_id,s.id,create_attendance_absence_reason.campus_id,btrim(create_attendance_absence_reason.code),btrim(create_attendance_absence_reason.name),case when create_attendance_absence_reason.description is null then null else btrim(create_attendance_absence_reason.description) end,a,a)
 returning to_jsonb(attendance_absence_reasons.*) into j;
 perform app_auth.write_attendance_change(cmd,s.organization_id,a,'attendance_reason.created','attendance_absence_reason',r,null,j,jsonb_build_object('school_id',s.id,'campus_id',create_attendance_absence_reason.campus_id,'reason_id',r)); return r;
end $$;

create function public.update_attendance_absence_reason(id uuid,code text,name text,description text,status public.record_status,set_description boolean default false) returns uuid
language plpgsql security definer set search_path='' as $$ declare a uuid:=app_auth.assert_attendance_actor(); r public.attendance_absence_reasons%rowtype; oldj jsonb; newj jsonb; cmd uuid:=gen_random_uuid(); begin
 select * into r from public.attendance_absence_reasons where attendance_absence_reasons.id=update_attendance_absence_reason.id for update; if not found then raise exception using errcode='P0002',message='attendance reason not found'; end if;
 perform app_auth.assert_attendance_manager(r.organization_id,r.school_id,r.campus_id,false);
 if r.campus_id is null and not app_auth.has_permission(r.organization_id,'attendance.manage',r.school_id,null) then raise exception using errcode='42501',message='school authority is required for school-wide reason'; end if;
 if update_attendance_absence_reason.status='archived' then raise exception using errcode='22023',message='use archive attendance reason command'; end if;
 oldj:=to_jsonb(r); update public.attendance_absence_reasons set
  code=btrim(update_attendance_absence_reason.code),name=btrim(update_attendance_absence_reason.name),
  description=case when set_description then case when update_attendance_absence_reason.description is null then null else btrim(update_attendance_absence_reason.description) end else r.description end,
  status=update_attendance_absence_reason.status,updated_by=a
  where attendance_absence_reasons.id=r.id returning to_jsonb(attendance_absence_reasons.*) into newj;
 perform app_auth.write_attendance_change(cmd,r.organization_id,a,'attendance_reason.updated','attendance_absence_reason',r.id,oldj,newj,jsonb_build_object('school_id',r.school_id,'campus_id',r.campus_id,'reason_id',r.id)); return r.id;
end $$;

create function public.archive_attendance_absence_reason(id uuid) returns uuid
language plpgsql security definer set search_path='' as $$ declare a uuid:=app_auth.assert_attendance_actor(); r public.attendance_absence_reasons%rowtype; oldj jsonb; newj jsonb; cmd uuid:=gen_random_uuid(); begin
 select * into r from public.attendance_absence_reasons where attendance_absence_reasons.id=archive_attendance_absence_reason.id for update; if not found then raise exception using errcode='P0002',message='attendance reason not found'; end if;
 perform app_auth.assert_attendance_manager(r.organization_id,r.school_id,r.campus_id,false); if r.status='archived' then raise exception using errcode='22023',message='attendance reason already archived'; end if;
 oldj:=to_jsonb(r); update public.attendance_absence_reasons set status='archived',updated_by=a where attendance_absence_reasons.id=r.id returning to_jsonb(attendance_absence_reasons.*) into newj;
 perform app_auth.write_attendance_change(cmd,r.organization_id,a,'attendance_reason.archived','attendance_absence_reason',r.id,oldj,newj,jsonb_build_object('school_id',r.school_id,'campus_id',r.campus_id,'reason_id',r.id)); return r.id;
end $$;

create function public.open_attendance_session(section_id uuid,session_date date) returns uuid
language plpgsql security definer set search_path='' as $$ declare a uuid:=app_auth.assert_attendance_actor(); s public.sections%rowtype; y public.academic_years%rowtype; x public.attendance_sessions%rowtype; cmd uuid:=gen_random_uuid(); j jsonb; n integer; begin
 select * into s from public.sections ps where ps.id=open_attendance_session.section_id; if not found then raise exception using errcode='P0002',message='section not found'; end if;
 perform 1 from public.organizations po where po.id=s.organization_id for update; perform 1 from public.schools psc where psc.id=s.school_id for update; perform 1 from public.campuses pc where pc.id=s.campus_id for update; perform 1 from public.academic_years py where py.id=s.academic_year_id for update; select * into s from public.sections ps where ps.id=s.id for update; select * into y from public.academic_years py where py.id=s.academic_year_id;
 if s.status<>'active' or y.status<>'active' or open_attendance_session.session_date not between s.start_date and s.end_date or open_attendance_session.session_date not between y.start_date and y.end_date then raise exception using errcode='22023',message='active section/year and in-range date are required'; end if;
 perform app_auth.assert_attendance_write_authority(s,open_attendance_session.session_date);
 perform 1 from public.students st join public.student_section_placements p on p.student_id=st.id join public.student_enrollments e on e.id=p.student_enrollment_id where p.section_id=s.id and p.status<>'corrected' and e.status<>'corrected' and open_attendance_session.session_date between p.starts_on and coalesce(p.ends_on,open_attendance_session.session_date) and open_attendance_session.session_date<@e.enrollment_range order by st.id for update of st,e,p;
 insert into public.attendance_sessions(organization_id,school_id,campus_id,academic_year_id,section_id,session_date,created_by,updated_by)
 values(s.organization_id,s.school_id,s.campus_id,s.academic_year_id,s.id,open_attendance_session.session_date,a,a) returning * into x;
 n:=app_auth.write_roster_snapshot(x,a,cmd); j:=to_jsonb(x);
 perform app_auth.write_attendance_change(cmd,s.organization_id,a,'attendance.session_opened','attendance_session',x.id,null,j,jsonb_build_object('school_id',s.school_id,'campus_id',s.campus_id,'academic_year_id',s.academic_year_id,'section_id',s.id,'session_date',open_attendance_session.session_date,'roster_count',n)); return x.id;
end $$;

create function app_auth.insert_attendance_marks(p_session public.attendance_sessions,p_marks public.attendance_mark_input[],p_actor uuid,p_cmd uuid,p_action text) returns integer
language plpgsql security definer set search_path='' as $$ declare m public.attendance_mark_input; ss public.attendance_session_students%rowtype; r public.attendance_absence_reasons%rowtype; mid uuid; j jsonb; n integer:=0; begin
 if p_marks is null or cardinality(p_marks)>10000 or exists(select 1 from unnest(p_marks) z where z is null) then raise exception using errcode='22023',message='valid bounded marks array is required'; end if;
 if (select count(*) from unnest(p_marks) z)<>(select count(distinct (z).student_id) from unnest(p_marks) z) then raise exception using errcode='22023',message='duplicate attendance student'; end if;
 if cardinality(p_marks)<>(select count(*) from public.attendance_session_students x where x.session_id=p_session.id) then raise exception using errcode='22023',message='complete roster marks are required'; end if;
 for m in select (z).* from unnest(p_marks) as z order by (z).student_id loop
  select * into ss from public.attendance_session_students x where x.session_id=p_session.id and x.student_id=m.student_id for update; if not found then raise exception using errcode='22023',message='mark student is outside roster'; end if;
  if m.mark in ('absent','excused') then select * into r from public.attendance_absence_reasons ar where ar.id=m.absence_reason_id for update; if not found or r.status<>'active' or r.organization_id<>p_session.organization_id or r.school_id<>p_session.school_id or (r.campus_id is not null and r.campus_id<>p_session.campus_id) then raise exception using errcode='22023',message='active applicable absence reason is required'; end if; end if;
  mid:=gen_random_uuid(); insert into public.attendance_marks(id,organization_id,school_id,campus_id,academic_year_id,section_id,session_id,session_student_id,student_id,mark,arrival_time,absence_reason_id,note,created_by,updated_by)
   values(mid,p_session.organization_id,p_session.school_id,p_session.campus_id,p_session.academic_year_id,p_session.section_id,p_session.id,ss.id,m.student_id,m.mark,m.arrival_time,m.absence_reason_id,case when m.note is null then null else btrim(m.note) end,p_actor,p_actor) returning to_jsonb(attendance_marks.*) into j;
  perform app_auth.write_attendance_change(p_cmd,p_session.organization_id,p_actor,p_action,'attendance_mark',mid,null,j,jsonb_build_object('school_id',p_session.school_id,'campus_id',p_session.campus_id,'section_id',p_session.section_id,'session_id',p_session.id,'student_id',m.student_id,'mark',m.mark,'arrival_time',m.arrival_time,'absence_reason_id',m.absence_reason_id)); n:=n+1;
 end loop; return n;
end $$;

create function public.submit_attendance_session(id uuid,marks public.attendance_mark_input[]) returns uuid
language plpgsql security definer set search_path='' as $$ declare a uuid:=app_auth.assert_attendance_actor(); x public.attendance_sessions%rowtype; s public.sections%rowtype; oldj jsonb; newj jsonb; cmd uuid:=gen_random_uuid(); n integer; begin
 select * into x from public.attendance_sessions where attendance_sessions.id=submit_attendance_session.id; if not found then raise exception using errcode='P0002',message='attendance session not found'; end if;
 select * into s from public.sections ps where ps.id=x.section_id for update; select * into x from public.attendance_sessions ats where ats.id=x.id for update;
 if x.status<>'open' then raise exception using errcode='22023',message='open attendance session is required'; end if; perform app_auth.assert_attendance_write_authority(s,x.session_date); oldj:=to_jsonb(x);
 n:=app_auth.insert_attendance_marks(x,submit_attendance_session.marks,a,cmd,'attendance.student_marked');
 update public.attendance_sessions set status='submitted',submitted_at=now(),submitted_by=a,updated_by=a where attendance_sessions.id=x.id returning to_jsonb(attendance_sessions.*) into newj;
 perform app_auth.write_attendance_change(cmd,x.organization_id,a,'attendance.session_submitted','attendance_session',x.id,oldj,newj,jsonb_build_object('school_id',x.school_id,'campus_id',x.campus_id,'academic_year_id',x.academic_year_id,'section_id',x.section_id,'session_date',x.session_date,'mark_count',n)); return x.id;
end $$;

create function public.finalize_attendance_session(id uuid) returns uuid
language plpgsql security definer set search_path='' as $$ declare a uuid:=app_auth.assert_attendance_actor(); x public.attendance_sessions%rowtype; oldj jsonb; newj jsonb; cmd uuid:=gen_random_uuid(); begin
 select * into x from public.attendance_sessions where attendance_sessions.id=finalize_attendance_session.id for update; if not found then raise exception using errcode='P0002',message='attendance session not found'; end if;
 perform app_auth.assert_attendance_manager(x.organization_id,x.school_id,x.campus_id,false); if x.status<>'submitted' then raise exception using errcode='22023',message='submitted attendance session is required'; end if;
 if (select count(*) from public.attendance_marks m where m.session_id=x.id)<>(select count(*) from public.attendance_session_students ss where ss.session_id=x.id) then raise exception using errcode='22023',message='complete marks are required'; end if;
 oldj:=to_jsonb(x); update public.attendance_sessions set status='finalized',finalized_at=now(),finalized_by=a,updated_by=a where attendance_sessions.id=x.id returning to_jsonb(attendance_sessions.*) into newj;
 perform app_auth.write_attendance_change(cmd,x.organization_id,a,'attendance.session_finalized','attendance_session',x.id,oldj,newj,jsonb_build_object('school_id',x.school_id,'campus_id',x.campus_id,'section_id',x.section_id,'session_date',x.session_date)); return x.id;
end $$;

create function public.correct_attendance_session(id uuid,marks public.attendance_mark_input[],correction_reason text)
returns table(corrected_session_id uuid,replacement_session_id uuid)
language plpgsql security definer set search_path='' as $$ declare a uuid:=app_auth.assert_attendance_actor(); x public.attendance_sessions%rowtype; y public.attendance_sessions%rowtype; ss public.attendance_session_students%rowtype; rid uuid; oldj jsonb; newj jsonb; cmd uuid:=gen_random_uuid(); n integer; begin
 if length(btrim(coalesce(correct_attendance_session.correction_reason,''))) not between 1 and 500 then raise exception using errcode='22023',message='bounded correction reason is required'; end if;
 select * into x from public.attendance_sessions where attendance_sessions.id=correct_attendance_session.id for update; if not found then raise exception using errcode='P0002',message='attendance session not found'; end if;
 perform app_auth.assert_attendance_manager(x.organization_id,x.school_id,x.campus_id,true); if x.status<>'finalized' then raise exception using errcode='22023',message='finalized attendance session is required'; end if;
 perform 1 from public.attendance_sessions q where q.supersedes_session_id=x.id order by q.id for update; if found then raise exception using errcode='40001',message='attendance correction head changed; retry'; end if;
 oldj:=to_jsonb(x); update public.attendance_sessions set status='corrected',correction_reason=btrim(correct_attendance_session.correction_reason),updated_by=a where attendance_sessions.id=x.id returning to_jsonb(attendance_sessions.*) into newj;
 perform app_auth.write_attendance_change(cmd,x.organization_id,a,'attendance.session_corrected','attendance_session',x.id,oldj,newj,jsonb_build_object('school_id',x.school_id,'campus_id',x.campus_id,'section_id',x.section_id,'session_date',x.session_date,'correction_reason',btrim(correct_attendance_session.correction_reason)));
 insert into public.attendance_sessions(organization_id,school_id,campus_id,academic_year_id,section_id,session_date,status,submitted_at,submitted_by,finalized_at,finalized_by,supersedes_session_id,created_by,updated_by)
 values(x.organization_id,x.school_id,x.campus_id,x.academic_year_id,x.section_id,x.session_date,'finalized',now(),a,now(),a,x.id,a,a) returning * into y;
 for ss in select * from public.attendance_session_students q where q.session_id=x.id order by q.student_id loop
  rid:=gen_random_uuid(); insert into public.attendance_session_students(id,organization_id,school_id,campus_id,academic_year_id,section_id,session_id,student_id,student_enrollment_id,student_section_placement_id,created_by)
  values(rid,y.organization_id,y.school_id,y.campus_id,y.academic_year_id,y.section_id,y.id,ss.student_id,ss.student_enrollment_id,ss.student_section_placement_id,a);
  perform app_auth.write_attendance_change(cmd,y.organization_id,a,'attendance.roster_snapshotted','attendance_session_student',rid,null,(select to_jsonb(q) from public.attendance_session_students q where q.id=rid),null,false);
 end loop;
 n:=app_auth.insert_attendance_marks(y,correct_attendance_session.marks,a,cmd,'attendance.student_mark_corrected');
 perform app_auth.write_attendance_change(cmd,y.organization_id,a,'attendance.session_finalized','attendance_session',y.id,null,to_jsonb(y),jsonb_build_object('school_id',y.school_id,'campus_id',y.campus_id,'section_id',y.section_id,'session_date',y.session_date,'mark_count',n,'supersedes_session_id',x.id));
 return query select x.id,y.id;
end $$;

-- Attendance history constrains academic structure, but roster snapshots never constrain append-only enrollment/placement correction.
create or replace function public.update_section(id uuid,code text,name text,capacity integer,start_date date,end_date date,academic_term_id uuid,homeroom_room_id uuid,status public.record_status,set_academic_term_id boolean default false,set_homeroom_room_id boolean default false) returns uuid
language plpgsql security definer set search_path='' as $$ declare r uuid; begin
 r:=app_auth.update_section_v0_3_impl(id,code,name,capacity,start_date,end_date,academic_term_id,homeroom_room_id,status,set_academic_term_id,set_homeroom_room_id);
 if exists(select 1 from public.student_section_placements p where p.section_id=update_section.id and p.status='active') and (update_section.status<>'active' or update_section.capacity<(select count(*) from public.student_section_placements p where p.section_id=update_section.id and p.status='active') or exists(select 1 from public.student_section_placements p where p.section_id=update_section.id and p.status<>'corrected' and (p.starts_on<update_section.start_date or coalesce(p.ends_on,p.starts_on)>update_section.end_date))) then raise exception using errcode='22023',message='section change conflicts with placement history or capacity'; end if;
 if exists(select 1 from public.teaching_assignments t where t.section_id=update_section.id and t.status='active') and update_section.status<>'active' then raise exception using errcode='22023',message='section has active teaching assignments'; end if;
 if exists(select 1 from public.teaching_assignments t where t.section_id=update_section.id and t.status<>'corrected' and (t.starts_on<update_section.start_date or t.scheduled_ends_on>update_section.end_date)) then raise exception using errcode='22023',message='section dates exclude teaching assignment history'; end if;
 if exists(select 1 from public.attendance_sessions a where a.section_id=update_section.id and a.status<>'corrected' and (a.session_date<update_section.start_date or a.session_date>update_section.end_date or update_section.status<>'active')) then raise exception using errcode='22023',message='section change conflicts with attendance history'; end if; return r;
end $$;
create or replace function public.archive_section(id uuid) returns uuid language plpgsql security definer set search_path='' as $$ declare r uuid; begin
 r:=app_auth.archive_section_v0_3_impl(archive_section.id); if exists(select 1 from public.student_section_placements p where p.section_id=archive_section.id and p.status='active') then raise exception using errcode='22023',message='section has active placements'; end if;
 if exists(select 1 from public.teaching_assignments t where t.section_id=archive_section.id and t.status='active') then raise exception using errcode='22023',message='section has active teaching assignments'; end if;
 if exists(select 1 from public.attendance_sessions a where a.section_id=archive_section.id and a.status<>'corrected') then raise exception using errcode='22023',message='section has attendance history'; end if; return r;
end $$;

-- Extend the v0.6 academic hook with attendance checks while retaining every prior predicate.
create or replace function app_auth.write_academic_change(o uuid,actor uuid,action_name text,entity_name text,entity uuid,before_row jsonb,after_row jsonb) returns void
language plpgsql security definer set search_path='' as $$
declare cmd uuid:=gen_random_uuid(); row_data jsonb:=coalesce(after_row,before_row,'{}'); changed jsonb;
 school uuid:=(row_data->>'school_id')::uuid; campus uuid:=(row_data->>'campus_id')::uuid;
 academic_year uuid:=coalesce((row_data->>'academic_year_id')::uuid,case when entity_name='academic_year' then entity end);
 academic_term uuid:=coalesce((row_data->>'academic_term_id')::uuid,case when entity_name='academic_term' then entity end); event_payload jsonb;
begin
 if entity_name='academic_year' and action_name='academic_year.status_changed' and after_row->>'status' in ('closed','archived') and exists(select 1 from public.student_enrollments e where e.academic_year_id=entity and e.status='active') then raise exception using errcode='22023',message='academic year has active enrollments'; end if;
 if entity_name='academic_year' and action_name='academic_year.updated' and exists(select 1 from public.student_enrollments e where e.academic_year_id=entity and e.status<>'corrected' and (e.enrolled_on<(after_row->>'start_date')::date or e.scheduled_end_on>(after_row->>'end_date')::date)) then raise exception using errcode='22023',message='academic year dates exclude enrollment history'; end if;
 if entity_name='academic_year' and action_name='academic_year.status_changed' and after_row->>'status' in ('closed','archived') and exists(select 1 from public.teaching_assignments t where t.academic_year_id=entity and t.status='active') then raise exception using errcode='22023',message='academic year has active teaching assignments'; end if;
 if entity_name='academic_year' and action_name='academic_year.updated' and exists(select 1 from public.teaching_assignments t where t.academic_year_id=entity and t.status<>'corrected' and (t.starts_on<(after_row->>'start_date')::date or t.scheduled_ends_on>(after_row->>'end_date')::date)) then raise exception using errcode='22023',message='academic year dates exclude teaching assignment history'; end if;
 if entity_name='academic_year' and action_name='academic_year.status_changed' and after_row->>'status' in ('closed','archived') and exists(select 1 from public.attendance_sessions a where a.academic_year_id=entity and a.status in ('open','submitted')) then raise exception using errcode='22023',message='academic year has unfinished attendance sessions'; end if;
 if entity_name='academic_year' and action_name='academic_year.updated' and exists(select 1 from public.attendance_sessions a where a.academic_year_id=entity and a.status<>'corrected' and (a.session_date<(after_row->>'start_date')::date or a.session_date>(after_row->>'end_date')::date)) then raise exception using errcode='22023',message='academic year dates exclude attendance history'; end if;
 if school is null and academic_year is not null then select y.school_id into school from public.academic_years y where y.id=academic_year; end if;
 select coalesce(jsonb_agg(k order by k),'[]') into changed from(select x.key k from jsonb_object_keys(coalesce(before_row,'{}')||coalesce(after_row,'{}')) x(key) where before_row->x.key is distinct from after_row->x.key) q;
 event_payload:=jsonb_strip_nulls(jsonb_build_object('command_id',cmd,'actor_user_id',actor,'organization_id',o,'entity_id',entity,'aggregate_id',entity,'school_id',school,'campus_id',campus,'academic_year_id',academic_year,'academic_term_id',academic_term,'changed_fields',changed,'before_status',before_row->>'status','after_status',after_row->>'status'));
 insert into public.audit_log(command_id,organization_id,actor_user_id,action,entity_type,entity_id,before_data,after_data) values(cmd,o,actor,action_name,entity_name,entity,before_row,after_row);
 insert into public.event_outbox(command_id,organization_id,event_type,aggregate_type,aggregate_id,payload) values(cmd,o,action_name,entity_name,entity,event_payload);
end $$;

alter table public.attendance_absence_reasons owner to postgres;
alter table public.attendance_sessions owner to postgres;
alter table public.attendance_session_students owner to postgres;
alter table public.attendance_marks owner to postgres;

do $$ declare p regprocedure; begin foreach p in array array[
 'public.create_attendance_absence_reason(uuid,uuid,text,text,text)'::regprocedure,
 'public.update_attendance_absence_reason(uuid,text,text,text,public.record_status,boolean)'::regprocedure,
 'public.archive_attendance_absence_reason(uuid)'::regprocedure,
 'public.open_attendance_session(uuid,date)'::regprocedure,
 'public.submit_attendance_session(uuid,public.attendance_mark_input[])'::regprocedure,
 'public.finalize_attendance_session(uuid)'::regprocedure,
 'public.correct_attendance_session(uuid,public.attendance_mark_input[],text)'::regprocedure,
 'public.update_section(uuid,text,text,integer,date,date,uuid,uuid,public.record_status,boolean,boolean)'::regprocedure,
 'public.archive_section(uuid)'::regprocedure]
 loop execute format('alter function %s owner to postgres',p); execute format('revoke all on function %s from public,anon',p); execute format('grant execute on function %s to authenticated,service_role',p); end loop; end $$;

do $$ declare p regprocedure; begin foreach p in array array[
 'app_auth.enforce_attendance_session_immutability()'::regprocedure,
 'app_auth.enforce_attendance_reason_scope_immutability()'::regprocedure,
 'app_auth.assert_attendance_mark_reason()'::regprocedure,
 'app_auth.assert_attendance_actor()'::regprocedure,
 'app_auth.assert_attendance_manager(uuid,uuid,uuid,boolean)'::regprocedure,
 'app_auth.write_attendance_change(uuid,uuid,uuid,text,text,uuid,jsonb,jsonb,jsonb,boolean)'::regprocedure,
 'app_auth.assert_attendance_write_authority(public.sections,date)'::regprocedure,
 'app_auth.write_roster_snapshot(public.attendance_sessions,uuid,uuid)'::regprocedure,
 'app_auth.insert_attendance_marks(public.attendance_sessions,public.attendance_mark_input[],uuid,uuid,text)'::regprocedure,
 'app_auth.has_attendance_assignment_on(uuid,date,public.teaching_assignment_role[])'::regprocedure,
 'app_auth.can_read_attendance_session(uuid)'::regprocedure,
 'app_auth.can_read_attendance_reason(uuid,uuid,uuid)'::regprocedure]
 loop execute format('alter function %s owner to postgres',p); execute format('revoke all on function %s from public,anon,authenticated,service_role',p); end loop; end $$;
grant execute on function app_auth.has_attendance_assignment_on(uuid,date,public.teaching_assignment_role[]),app_auth.can_read_attendance_session(uuid),app_auth.can_read_attendance_reason(uuid,uuid,uuid) to authenticated;

comment on table public.attendance_sessions is 'Daily section attendance lifecycle with append-and-supersede finalized correction.';
comment on table public.attendance_session_students is 'Immutable snapshot of the roster recorded when an attendance session opened.';
comment on table public.attendance_marks is 'Immutable submitted/finalized student attendance marks; writes use typed commands.';
comment on function public.correct_attendance_session(uuid,public.attendance_mark_input[],text) is 'Whole-session mark correction using the original immutable roster snapshot.';

commit;
