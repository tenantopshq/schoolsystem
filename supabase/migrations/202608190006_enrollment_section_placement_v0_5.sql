begin;

create extension if not exists btree_gist with schema extensions;

create type public.enrollment_status as enum ('active','withdrawn','completed','corrected');
create type public.section_placement_status as enum ('active','withdrawn','completed','transferred','corrected');
create unique index sections_enrollment_scope_key on public.sections(organization_id,school_id,campus_id,academic_year_id,id);

create table public.student_enrollments (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null, school_id uuid not null,
 academic_year_id uuid not null, student_id uuid not null, grade_level_id uuid not null,
 enrolled_on date not null, scheduled_end_on date not null, ended_on date,
 enrollment_range daterange not null, status public.enrollment_status not null default 'active',
 end_reason text check(end_reason is null or length(btrim(end_reason)) between 1 and 500),
 supersedes_enrollment_id uuid, correction_reason text check(correction_reason is null or length(btrim(correction_reason)) between 1 and 500),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 created_by uuid not null references auth.users(id) on delete restrict, updated_by uuid not null references auth.users(id) on delete restrict,
 foreign key(organization_id,student_id) references public.students(organization_id,id) on delete restrict,
 foreign key(organization_id,school_id,academic_year_id) references public.academic_years(organization_id,school_id,id) on delete restrict,
 foreign key(organization_id,school_id,grade_level_id) references public.grade_levels(organization_id,school_id,id) on delete restrict,
 foreign key(organization_id,supersedes_enrollment_id) references public.student_enrollments(organization_id,id) on delete restrict,
 unique(organization_id,id), unique(organization_id,school_id,academic_year_id,student_id,id),
 check(enrolled_on<=scheduled_end_on), check(ended_on is null or ended_on between enrolled_on and scheduled_end_on),
 check(enrollment_range=daterange(enrolled_on,coalesce(ended_on,scheduled_end_on),'[]')),
 check((status='active' and ended_on is null and end_reason is null and correction_reason is null)
    or (status in ('withdrawn','completed') and ended_on is not null and end_reason is not null and correction_reason is null)
    or (status='corrected' and correction_reason is not null)),
 check(supersedes_enrollment_id is null or supersedes_enrollment_id<>id)
);
alter table public.student_enrollments add constraint student_enrollments_no_overlap
 exclude using gist(student_id with =,enrollment_range with &&) where(status<>'corrected');

create table public.student_section_placements (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null, school_id uuid not null, campus_id uuid not null,
 academic_year_id uuid not null, student_enrollment_id uuid not null, student_id uuid not null, section_id uuid not null,
 starts_on date not null, ends_on date, status public.section_placement_status not null default 'active',
 end_reason text check(end_reason is null or length(btrim(end_reason)) between 1 and 500),
 transfer_to_placement_id uuid, supersedes_placement_id uuid,
 correction_reason text check(correction_reason is null or length(btrim(correction_reason)) between 1 and 500),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 created_by uuid not null references auth.users(id) on delete restrict, updated_by uuid not null references auth.users(id) on delete restrict,
 foreign key(organization_id,school_id,academic_year_id,student_id,student_enrollment_id)
  references public.student_enrollments(organization_id,school_id,academic_year_id,student_id,id) on delete restrict,
 foreign key(organization_id,school_id,campus_id,academic_year_id,section_id)
  references public.sections(organization_id,school_id,campus_id,academic_year_id,id) on delete restrict,
 foreign key(organization_id,transfer_to_placement_id) references public.student_section_placements(organization_id,id) on delete restrict,
 foreign key(organization_id,supersedes_placement_id) references public.student_section_placements(organization_id,id) on delete restrict,
 unique(organization_id,id),
 check(ends_on is null or ends_on>=starts_on),
 check((status='active' and ends_on is null and end_reason is null and correction_reason is null and transfer_to_placement_id is null)
    or (status in ('withdrawn','completed') and ends_on is not null and end_reason is not null and correction_reason is null and transfer_to_placement_id is null)
    or (status='transferred' and ends_on is not null and end_reason is not null and correction_reason is null and transfer_to_placement_id is not null)
    or (status='corrected' and correction_reason is not null)),
 check(transfer_to_placement_id is null or transfer_to_placement_id<>id),
 check(supersedes_placement_id is null or supersedes_placement_id<>id)
);
create unique index student_section_placements_one_active_idx on public.student_section_placements(student_enrollment_id) where status='active';
create index student_enrollments_student_history_idx on public.student_enrollments(organization_id,student_id,enrolled_on,id);
create index student_enrollments_scope_idx on public.student_enrollments(organization_id,school_id,status,academic_year_id);
create index student_enrollments_year_grade_idx on public.student_enrollments(organization_id,school_id,academic_year_id,grade_level_id);
create index student_enrollments_supersedes_idx on public.student_enrollments(organization_id,supersedes_enrollment_id) where supersedes_enrollment_id is not null;
create index student_section_placements_enrollment_idx on public.student_section_placements(organization_id,student_enrollment_id,status,id);
create index student_section_placements_student_year_idx on public.student_section_placements(organization_id,student_id,academic_year_id,starts_on,id);
create index student_section_placements_section_capacity_idx on public.student_section_placements(organization_id,section_id,status,id);
create index student_section_placements_scope_idx on public.student_section_placements(organization_id,school_id,campus_id,status);
create index student_section_placements_transfer_idx on public.student_section_placements(organization_id,transfer_to_placement_id) where transfer_to_placement_id is not null;
create index student_section_placements_supersedes_idx on public.student_section_placements(organization_id,supersedes_placement_id) where supersedes_placement_id is not null;
create trigger student_enrollments_updated_at before update on public.student_enrollments for each row execute function public.set_updated_at();
create trigger student_section_placements_updated_at before update on public.student_section_placements for each row execute function public.set_updated_at();

alter table public.student_enrollments enable row level security; alter table public.student_enrollments force row level security;
alter table public.student_section_placements enable row level security; alter table public.student_section_placements force row level security;

insert into public.permissions(code,module,description) values
 ('enrollments.view','enrollments','View student enrollment and section-placement history within assigned scope'),
 ('enrollments.manage','enrollments','Manage enrollment and section-placement workflows within assigned scope'),
 ('enrollments.correct','enrollments','Correct enrollment and placement history within assigned scope');

create function app_auth.can_view_enrollment(o uuid,student uuid,school uuid,campus uuid default null) returns boolean
language sql stable security definer set search_path='' as $$
 select app_auth.has_permission(o,'enrollments.view',school,campus)
     or app_auth.has_permission(o,'enrollments.manage',school,campus)
     or app_auth.is_student_self(student) or app_auth.is_linked_guardian(student); $$;

create policy student_enrollments_select on public.student_enrollments for select to authenticated using(
 app_auth.can_view_enrollment(organization_id,student_id,school_id,null)
 or exists(select 1 from public.student_section_placements p where p.student_enrollment_id=id
  and app_auth.can_view_enrollment(organization_id,student_id,school_id,p.campus_id)));
create policy student_section_placements_select on public.student_section_placements for select to authenticated using(
 app_auth.can_view_enrollment(organization_id,student_id,school_id,campus_id));

revoke all on public.student_enrollments,public.student_section_placements from public,anon,authenticated;
grant select on public.student_enrollments,public.student_section_placements to authenticated;

create function app_auth.assert_enrollment_actor() returns uuid language plpgsql security definer set search_path='' as $$
declare a uuid:=auth.uid(); begin if a is null then raise exception using errcode='42501',message='an authenticated actor is required'; end if; return a; end $$;

create function app_auth.assert_enrollment_permission(o uuid,s uuid,c uuid,correct boolean default false) returns void
language plpgsql security definer set search_path='' as $$ begin
 if not app_auth.has_permission(o,'enrollments.manage',s,c) then raise exception using errcode='42501',message='enrollments.manage permission is required'; end if;
 if correct and not app_auth.has_permission(o,'enrollments.correct',s,c) then raise exception using errcode='42501',message='enrollments.correct permission is required'; end if;
end $$;

create function app_auth.write_enrollment_change(cmd uuid,o uuid,actor uuid,action_name text,entity_name text,entity uuid,before_row jsonb,after_row jsonb,payload jsonb) returns void
language plpgsql security definer set search_path='' as $$
declare changed jsonb; begin
 select coalesce(jsonb_agg(k order by k),'[]'::jsonb) into changed from(
  select x.key k from jsonb_object_keys(coalesce(before_row,'{}'::jsonb)||coalesce(after_row,'{}'::jsonb)) x(key)
  where before_row->x.key is distinct from after_row->x.key) q;
 insert into public.audit_log(command_id,organization_id,actor_user_id,action,entity_type,entity_id,before_data,after_data)
 values(cmd,o,actor,action_name,entity_name,entity,before_row,
  case when after_row is null then null else after_row||jsonb_build_object('_changed_fields',changed) end);
 insert into public.event_outbox(command_id,organization_id,event_type,aggregate_type,aggregate_id,payload)
 values(cmd,o,action_name,entity_name,entity,coalesce(payload,'{}')||jsonb_build_object(
  'command_id',cmd,'actor_user_id',actor,'organization_id',o,'aggregate_id',entity,'changed_fields',changed));
end $$;

create function app_auth.lock_enrollment_parents(student_id uuid,year_ids uuid[],grade_ids uuid[],section_ids uuid[] default '{}') returns void
language plpgsql security definer set search_path='' as $$
declare o uuid; x uuid; begin
 select s.organization_id into o from public.students s where s.id=student_id;
 if o is null then raise exception using errcode='P0002',message='student not found'; end if;
 perform 1 from public.organizations where id=o for update;
 for x in select q from(
  select s.school_id q from public.students s where s.id=student_id union
  select y.school_id from public.academic_years y where y.id=any(year_ids) union
  select z.school_id from public.sections z where z.id=any(section_ids)) v where q is not null order by q
 loop perform 1 from public.schools where id=x for update; end loop;
 for x in select q from(
  select s.campus_id q from public.students s where s.id=student_id union
  select z.campus_id from public.sections z where z.id=any(section_ids)) v where q is not null order by q
 loop perform 1 from public.campuses where id=x for update; end loop;
 perform 1 from public.students where id=student_id for update;
 for x in select y.id from public.academic_years y where y.id=any(year_ids) order by y.id loop perform 1 from public.academic_years where id=x for update; end loop;
 for x in select q from(select unnest(grade_ids) q union select z.grade_level_id from public.sections z where z.id=any(section_ids)) v where q is not null order by q loop perform 1 from public.grade_levels where id=x for update; end loop;
 for x in select distinct z.academic_term_id from public.sections z where z.id=any(section_ids) and z.academic_term_id is not null order by 1 loop perform 1 from public.academic_terms where id=x for update; end loop;
 for x in select z.id from public.sections z where z.id=any(section_ids) order by z.id loop perform 1 from public.sections where id=x for update; end loop;
end $$;

create function app_auth.assert_enrollment_row(e public.student_enrollments,require_active boolean default true) returns void
language plpgsql security definer set search_path='' as $$
declare s public.students%rowtype; y public.academic_years%rowtype; g public.grade_levels%rowtype; begin
 select * into s from public.students where id=e.student_id;
 select * into y from public.academic_years where id=e.academic_year_id;
 select * into g from public.grade_levels where id=e.grade_level_id;
 if require_active and (e.status<>'active' or s.status<>'active' or y.status<>'active' or g.status<>'active') then raise exception using errcode='22023',message='active enrollment and parents are required'; end if;
 if (e.organization_id,e.school_id)<>(y.organization_id,y.school_id) or (e.organization_id,e.school_id)<>(g.organization_id,g.school_id) then raise exception using errcode='22023',message='enrollment parent scope mismatch'; end if;
 perform app_auth.assert_enrollment_permission(e.organization_id,s.school_id,s.campus_id,false);
 perform app_auth.assert_enrollment_permission(e.organization_id,e.school_id,null,false);
end $$;

create function app_auth.enroll_student(p_student uuid,p_year uuid,p_grade uuid,p_date date,p_supersedes uuid default null,p_correct boolean default false,p_cmd uuid default null,p_status public.enrollment_status default 'active',p_ended date default null,p_end_reason text default null) returns uuid
language plpgsql security definer set search_path='' as $$
declare a uuid:=app_auth.assert_enrollment_actor(); s public.students%rowtype; y public.academic_years%rowtype; g public.grade_levels%rowtype; r uuid:=gen_random_uuid(); j jsonb; cmd uuid:=coalesce(p_cmd,gen_random_uuid()); begin
 select * into s from public.students where id=p_student; select * into y from public.academic_years where id=p_year;
 if s.id is null or y.id is null then raise exception using errcode='P0002',message='student or academic year not found'; end if;
 perform app_auth.lock_enrollment_parents(s.id,array[y.id],array[p_grade],'{}');
 select * into s from public.students where id=p_student; select * into y from public.academic_years where id=p_year; select * into g from public.grade_levels where id=p_grade for update;
 if s.organization_id<>y.organization_id or (g.organization_id,g.school_id)<>(y.organization_id,y.school_id) then raise exception using errcode='22023',message='same-tenant academic year and grade are required'; end if;
 if s.status<>'active' or y.status<>'active' or g.status<>'active' then raise exception using errcode='22023',message='active student, year, and grade are required'; end if;
 if p_date not between y.start_date and y.end_date then raise exception using errcode='22023',message='enrollment date must be inside academic year'; end if;
 if p_status='active' and (p_ended is not null or p_end_reason is not null) then raise exception using errcode='22023',message='active enrollment cannot have terminal fields'; end if;
 if p_status in ('withdrawn','completed') and (p_ended not between p_date and y.end_date or length(btrim(coalesce(p_end_reason,''))) not between 1 and 500) then raise exception using errcode='22023',message='terminal enrollment requires valid date and reason'; end if;
 if p_status not in ('active','withdrawn','completed') then raise exception using errcode='22023',message='replacement enrollment status is invalid'; end if;
 perform app_auth.assert_enrollment_permission(s.organization_id,s.school_id,s.campus_id,p_correct);
 perform app_auth.assert_enrollment_permission(s.organization_id,y.school_id,null,p_correct);
 insert into public.student_enrollments(id,organization_id,school_id,academic_year_id,student_id,grade_level_id,enrolled_on,scheduled_end_on,ended_on,enrollment_range,status,end_reason,supersedes_enrollment_id,created_by,updated_by)
 values(r,s.organization_id,y.school_id,y.id,s.id,g.id,p_date,y.end_date,p_ended,daterange(p_date,coalesce(p_ended,y.end_date),'[]'),p_status,case when p_status='active' then null else btrim(p_end_reason) end,p_supersedes,a,a) returning to_jsonb(student_enrollments.*) into j;
 perform app_auth.write_enrollment_change(cmd,s.organization_id,a,'student.enrolled','student_enrollment',r,null,j,
  jsonb_build_object('student_id',s.id,'enrollment_id',r,'academic_year_id',y.id,'school_id',y.school_id,'grade_level_id',g.id,'enrolled_on',p_date)); return r;
end $$;

create function app_auth.end_enrollment(p_id uuid,p_status public.enrollment_status,p_date date,p_reason text,p_cmd uuid default null) returns uuid
language plpgsql security definer set search_path='' as $$
declare a uuid:=app_auth.assert_enrollment_actor(); e public.student_enrollments%rowtype; oldj jsonb; newj jsonb; p public.student_section_placements%rowtype; pj jsonb; cmd uuid:=coalesce(p_cmd,gen_random_uuid()); ids uuid[]; current_ids uuid[]; action text; begin
 if p_status not in ('withdrawn','completed') or length(btrim(coalesce(p_reason,''))) not between 1 and 500 then raise exception using errcode='22023',message='valid terminal status and bounded reason are required'; end if;
 select * into e from public.student_enrollments where id=p_id; if not found then raise exception using errcode='P0002',message='enrollment not found'; end if;
 select coalesce(array_agg(section_id order by section_id),'{}') into ids from public.student_section_placements where student_enrollment_id=e.id and status='active';
 perform app_auth.lock_enrollment_parents(e.student_id,array[e.academic_year_id],array[e.grade_level_id],ids);
 select * into e from public.student_enrollments where id=p_id for update; perform 1 from public.student_section_placements where student_enrollment_id=e.id order by id for update;
 select coalesce(array_agg(section_id order by section_id),'{}') into current_ids from public.student_section_placements where student_enrollment_id=e.id and status='active';
 if current_ids is distinct from ids then raise exception using errcode='40001',message='active placements changed concurrently; retry'; end if;
 perform app_auth.assert_enrollment_row(e,true); if p_date not between e.enrolled_on and e.scheduled_end_on then raise exception using errcode='22023',message='enrollment end date is outside enrollment'; end if;
 oldj:=to_jsonb(e); action:=case p_status when 'withdrawn' then 'student.enrollment_withdrawn' else 'student.enrollment_completed' end;
 for p in select * from public.student_section_placements where student_enrollment_id=e.id and status='active' order by id loop
  if p_date<p.starts_on then raise exception using errcode='22023',message='enrollment end precedes active placement'; end if;
  update public.student_section_placements set status=case p_status when 'withdrawn' then 'withdrawn'::public.section_placement_status else 'completed'::public.section_placement_status end,
   ends_on=p_date,end_reason=btrim(p_reason),updated_by=a where id=p.id returning to_jsonb(student_section_placements.*) into pj;
  perform app_auth.write_enrollment_change(cmd,e.organization_id,a,case p_status when 'withdrawn' then 'student.section_withdrawn' else 'student.section_completed' end,
   'student_section_placement',p.id,to_jsonb(p),pj,jsonb_build_object('student_id',e.student_id,'enrollment_id',e.id,'placement_id',p.id,'section_id',p.section_id,'school_id',p.school_id,'campus_id',p.campus_id,'ended_on',p_date,'reason',btrim(p_reason)));
 end loop;
 update public.student_enrollments set status=p_status,ended_on=p_date,end_reason=btrim(p_reason),enrollment_range=daterange(enrolled_on,p_date,'[]'),updated_by=a where id=e.id returning to_jsonb(student_enrollments.*) into newj;
 perform app_auth.write_enrollment_change(cmd,e.organization_id,a,action,'student_enrollment',e.id,oldj,newj,jsonb_build_object('student_id',e.student_id,'enrollment_id',e.id,'academic_year_id',e.academic_year_id,'school_id',e.school_id,'ended_on',p_date,'reason',btrim(p_reason))); return e.id;
end $$;

create function app_auth.correct_enrollment(p_id uuid,p_year uuid,p_grade uuid,p_date date,p_status public.enrollment_status,p_ended date,p_end_reason text,p_create boolean,p_reason text)
returns table(corrected_enrollment_id uuid,replacement_enrollment_id uuid) language plpgsql security definer set search_path='' as $$
declare a uuid:=app_auth.assert_enrollment_actor(); e public.student_enrollments%rowtype; oldj jsonb; newj jsonb; p public.student_section_placements%rowtype; pj jsonb; cmd uuid:=gen_random_uuid(); r uuid; begin
 if length(btrim(coalesce(p_reason,''))) not between 1 and 500 then raise exception using errcode='22023',message='bounded correction reason is required'; end if;
 select * into e from public.student_enrollments where id=p_id; if not found then raise exception using errcode='P0002',message='enrollment not found'; end if;
 perform app_auth.lock_enrollment_parents(e.student_id,array[e.academic_year_id,p_year],array[e.grade_level_id,p_grade],array(select section_id from public.student_section_placements where student_enrollment_id=e.id));
 select * into e from public.student_enrollments where id=p_id for update; perform 1 from public.student_section_placements where student_enrollment_id=e.id order by id for update;
 if e.status='corrected' then raise exception using errcode='22023',message='corrected enrollment is terminal'; end if;
 perform app_auth.assert_enrollment_permission(e.organization_id,e.school_id,null,true); oldj:=to_jsonb(e);
 for p in select * from public.student_section_placements where student_enrollment_id=e.id and status<>'corrected' order by id loop
  update public.student_section_placements set status='corrected',correction_reason=btrim(p_reason),updated_by=a where id=p.id returning to_jsonb(student_section_placements.*) into pj;
  perform app_auth.write_enrollment_change(cmd,e.organization_id,a,'student.section_placement_corrected','student_section_placement',p.id,to_jsonb(p),pj,jsonb_build_object('student_id',e.student_id,'enrollment_id',e.id,'placement_id',p.id,'section_id',p.section_id,'school_id',p.school_id,'campus_id',p.campus_id,'correction_reason',btrim(p_reason)));
 end loop;
 update public.student_enrollments set status='corrected',correction_reason=btrim(p_reason),updated_by=a where id=e.id returning to_jsonb(student_enrollments.*) into newj;
 perform app_auth.write_enrollment_change(cmd,e.organization_id,a,'student.enrollment_corrected','student_enrollment',e.id,oldj,newj,jsonb_build_object('student_id',e.student_id,'enrollment_id',e.id,'academic_year_id',e.academic_year_id,'school_id',e.school_id,'correction_reason',btrim(p_reason)));
 if p_create then
  r:=app_auth.enroll_student(e.student_id,p_year,p_grade,p_date,e.id,true,cmd,p_status,p_ended,p_end_reason);
 end if; return query select e.id,r;
end $$;

create function app_auth.assert_placement_context(e public.student_enrollments,z public.sections,p_start date) returns void
language plpgsql security definer set search_path='' as $$
declare t public.academic_terms%rowtype; begin
 perform app_auth.assert_enrollment_row(e,true);
 if (z.organization_id,z.school_id,z.academic_year_id,z.grade_level_id)<>(e.organization_id,e.school_id,e.academic_year_id,e.grade_level_id) or z.status<>'active' then raise exception using errcode='22023',message='active section with matching enrollment grade and scope is required'; end if;
 if p_start not between z.start_date and z.end_date or p_start not between e.enrolled_on and e.scheduled_end_on then raise exception using errcode='22023',message='placement date is outside enrollment or section'; end if;
 if z.academic_term_id is not null then select * into t from public.academic_terms where id=z.academic_term_id; if t.status<>'active' or p_start not between t.start_date and t.end_date then raise exception using errcode='22023',message='active academic term and date are required'; end if; end if;
 perform app_auth.assert_enrollment_permission(e.organization_id,z.school_id,z.campus_id,false);
end $$;

create function app_auth.place_student(p_enrollment uuid,p_section uuid,p_start date,p_supersedes uuid default null,p_correct boolean default false,p_cmd uuid default null,p_status public.section_placement_status default 'active',p_end date default null,p_end_reason text default null) returns uuid
language plpgsql security definer set search_path='' as $$
declare a uuid:=app_auth.assert_enrollment_actor(); e public.student_enrollments%rowtype; z public.sections%rowtype; r uuid:=gen_random_uuid(); j jsonb; cmd uuid:=coalesce(p_cmd,gen_random_uuid()); begin
 select * into e from public.student_enrollments where id=p_enrollment; select * into z from public.sections where id=p_section;
 if e.id is null or z.id is null then raise exception using errcode='P0002',message='enrollment or section not found'; end if;
 perform app_auth.lock_enrollment_parents(e.student_id,array[e.academic_year_id],array[e.grade_level_id],array[z.id]);
 select * into e from public.student_enrollments where id=p_enrollment for update; select * into z from public.sections where id=p_section for update; perform 1 from public.student_section_placements where student_enrollment_id=e.id order by id for update;
 perform app_auth.assert_placement_context(e,z,p_start); if p_correct then perform app_auth.assert_enrollment_permission(e.organization_id,z.school_id,z.campus_id,true); end if;
 if p_status='active' and (p_end is not null or p_end_reason is not null) then raise exception using errcode='22023',message='active placement cannot have terminal fields'; end if;
 if p_status in ('withdrawn','completed') and (p_end not between p_start and least(e.scheduled_end_on,z.end_date) or length(btrim(coalesce(p_end_reason,''))) not between 1 and 500) then raise exception using errcode='22023',message='terminal placement requires valid date and reason'; end if;
 if p_status not in ('active','withdrawn','completed') then raise exception using errcode='22023',message='replacement placement status is invalid'; end if;
 if p_status='active' and (select count(*) from public.student_section_placements where section_id=z.id and status='active')>=z.capacity then raise exception using errcode='22023',message='section capacity is full'; end if;
 insert into public.student_section_placements(id,organization_id,school_id,campus_id,academic_year_id,student_enrollment_id,student_id,section_id,starts_on,ends_on,status,end_reason,supersedes_placement_id,created_by,updated_by)
 values(r,e.organization_id,z.school_id,z.campus_id,z.academic_year_id,e.id,e.student_id,z.id,p_start,p_end,p_status,case when p_status='active' then null else btrim(p_end_reason) end,p_supersedes,a,a) returning to_jsonb(student_section_placements.*) into j;
 perform app_auth.write_enrollment_change(cmd,e.organization_id,a,'student.section_placed','student_section_placement',r,null,j,jsonb_build_object('student_id',e.student_id,'enrollment_id',e.id,'placement_id',r,'academic_year_id',e.academic_year_id,'school_id',z.school_id,'campus_id',z.campus_id,'grade_level_id',e.grade_level_id,'section_id',z.id,'starts_on',p_start)); return r;
end $$;

create function app_auth.end_placement(p_id uuid,p_status public.section_placement_status,p_date date,p_reason text,p_cmd uuid default null) returns uuid
language plpgsql security definer set search_path='' as $$
declare a uuid:=app_auth.assert_enrollment_actor(); p public.student_section_placements%rowtype; e public.student_enrollments%rowtype; oldj jsonb; newj jsonb; cmd uuid:=coalesce(p_cmd,gen_random_uuid()); action text; begin
 if p_status not in ('withdrawn','completed') or length(btrim(coalesce(p_reason,''))) not between 1 and 500 then raise exception using errcode='22023',message='valid placement outcome and bounded reason are required'; end if;
 select * into p from public.student_section_placements where id=p_id; if not found then raise exception using errcode='P0002',message='placement not found'; end if; select * into e from public.student_enrollments where id=p.student_enrollment_id;
 perform app_auth.lock_enrollment_parents(e.student_id,array[e.academic_year_id],array[e.grade_level_id],array[p.section_id]); select * into e from public.student_enrollments where id=e.id for update; select * into p from public.student_section_placements where id=p_id for update;
 if p.status<>'active' then raise exception using errcode='22023',message='active placement is required'; end if; perform app_auth.assert_enrollment_row(e,true); perform app_auth.assert_enrollment_permission(e.organization_id,p.school_id,p.campus_id,false);
 if p_date not between p.starts_on and least(e.scheduled_end_on,(select end_date from public.sections where id=p.section_id)) then raise exception using errcode='22023',message='placement end date is outside placement'; end if;
 oldj:=to_jsonb(p); action:=case p_status when 'withdrawn' then 'student.section_withdrawn' else 'student.section_completed' end;
 update public.student_section_placements set status=p_status,ends_on=p_date,end_reason=btrim(p_reason),updated_by=a where id=p.id returning to_jsonb(student_section_placements.*) into newj;
 perform app_auth.write_enrollment_change(cmd,e.organization_id,a,action,'student_section_placement',p.id,oldj,newj,jsonb_build_object('student_id',e.student_id,'enrollment_id',e.id,'placement_id',p.id,'academic_year_id',e.academic_year_id,'school_id',p.school_id,'campus_id',p.campus_id,'section_id',p.section_id,'ended_on',p_date,'reason',btrim(p_reason))); return p.id;
end $$;

create function app_auth.transfer_placement(p_id uuid,p_destination uuid,p_date date,p_reason text)
returns table(from_placement_id uuid,to_placement_id uuid) language plpgsql security definer set search_path='' as $$
declare a uuid:=app_auth.assert_enrollment_actor(); p public.student_section_placements%rowtype; e public.student_enrollments%rowtype; z public.sections%rowtype; oldj jsonb; newj jsonb; destj jsonb; r uuid:=gen_random_uuid(); cmd uuid:=gen_random_uuid(); begin
 if length(btrim(coalesce(p_reason,''))) not between 1 and 500 then raise exception using errcode='22023',message='bounded transfer reason is required'; end if;
 select * into p from public.student_section_placements where id=p_id; select * into z from public.sections where id=p_destination; if p.id is null or z.id is null then raise exception using errcode='P0002',message='placement or destination section not found'; end if;
 if p.section_id=z.id then raise exception using errcode='22023',message='source and destination sections must differ'; end if; select * into e from public.student_enrollments where id=p.student_enrollment_id;
 perform app_auth.lock_enrollment_parents(e.student_id,array[e.academic_year_id],array[e.grade_level_id],array[p.section_id,z.id]); select * into e from public.student_enrollments where id=e.id for update; select * into p from public.student_section_placements where id=p.id for update; select * into z from public.sections where id=z.id for update; perform 1 from public.student_section_placements where student_enrollment_id=e.id order by id for update;
 if p.status<>'active' or p_date<=p.starts_on then raise exception using errcode='22023',message='transfer date must follow active placement start'; end if; perform app_auth.assert_placement_context(e,z,p_date); perform app_auth.assert_enrollment_permission(e.organization_id,p.school_id,p.campus_id,false);
 if (select count(*) from public.student_section_placements where section_id=z.id and status='active')>=z.capacity then raise exception using errcode='22023',message='destination section capacity is full'; end if;
 oldj:=to_jsonb(p); update public.student_section_placements set status='corrected',correction_reason='[TRANSFER-IN-PROGRESS]',updated_by=a where id=p.id;
 insert into public.student_section_placements(id,organization_id,school_id,campus_id,academic_year_id,student_enrollment_id,student_id,section_id,starts_on,created_by,updated_by)
 values(r,e.organization_id,z.school_id,z.campus_id,z.academic_year_id,e.id,e.student_id,z.id,p_date,a,a) returning to_jsonb(student_section_placements.*) into destj;
 update public.student_section_placements set status='transferred',ends_on=p_date-1,end_reason=btrim(p_reason),transfer_to_placement_id=r,correction_reason=null,updated_by=a where id=p.id returning to_jsonb(student_section_placements.*) into newj;
 perform app_auth.write_enrollment_change(cmd,e.organization_id,a,'student.section_transferred_out','student_section_placement',p.id,oldj,newj,jsonb_build_object('student_id',e.student_id,'enrollment_id',e.id,'placement_id',p.id,'to_placement_id',r,'school_id',p.school_id,'campus_id',p.campus_id,'section_id',p.section_id,'destination_section_id',z.id,'ended_on',p_date-1,'reason',btrim(p_reason)));
 perform app_auth.write_enrollment_change(cmd,e.organization_id,a,'student.section_transferred_in','student_section_placement',r,null,destj,jsonb_build_object('student_id',e.student_id,'enrollment_id',e.id,'placement_id',r,'from_placement_id',p.id,'school_id',z.school_id,'campus_id',z.campus_id,'section_id',z.id,'source_section_id',p.section_id,'starts_on',p_date)); return query select p.id,r;
end $$;

create function app_auth.correct_placement(p_id uuid,p_section uuid,p_start date,p_end date,p_status public.section_placement_status,p_end_reason text,p_create boolean,p_reason text)
returns table(corrected_placement_id uuid,replacement_placement_id uuid) language plpgsql security definer set search_path='' as $$
declare a uuid:=app_auth.assert_enrollment_actor(); p public.student_section_placements%rowtype; mate public.student_section_placements%rowtype; e public.student_enrollments%rowtype; oldj jsonb; newj jsonb; r uuid; mate_id uuid; locked_mate_id uuid; cmd uuid:=gen_random_uuid(); begin
 if length(btrim(coalesce(p_reason,''))) not between 1 and 500 then raise exception using errcode='22023',message='bounded correction reason is required'; end if;
 select * into p from public.student_section_placements where id=p_id; if not found then raise exception using errcode='P0002',message='placement not found'; end if; select * into e from public.student_enrollments where id=p.student_enrollment_id;
 select * into mate from public.student_section_placements where id=p.transfer_to_placement_id or transfer_to_placement_id=p.id order by id limit 1; mate_id:=mate.id;
 perform app_auth.lock_enrollment_parents(e.student_id,array[e.academic_year_id],array[e.grade_level_id],array[p.section_id,mate.section_id,p_section]); select * into e from public.student_enrollments where id=e.id for update; perform 1 from public.student_section_placements where student_enrollment_id=e.id order by id for update; select * into p from public.student_section_placements where id=p.id;
 select q.id into locked_mate_id from public.student_section_placements q where q.id=p.transfer_to_placement_id or q.transfer_to_placement_id=p.id order by q.id limit 1;
 if locked_mate_id is distinct from mate_id then raise exception using errcode='40001',message='transfer placement set changed; retry'; end if;
 if mate_id is not null then select * into mate from public.student_section_placements where id=mate_id; end if;
 if p.status='corrected' then raise exception using errcode='22023',message='corrected placement is terminal'; end if; perform app_auth.assert_enrollment_permission(e.organization_id,p.school_id,p.campus_id,true);
 if mate.id is not null then perform app_auth.assert_enrollment_permission(e.organization_id,mate.school_id,mate.campus_id,true); end if;
 oldj:=to_jsonb(p); update public.student_section_placements set status='corrected',correction_reason=btrim(p_reason),updated_by=a where id=p.id returning to_jsonb(student_section_placements.*) into newj;
 perform app_auth.write_enrollment_change(cmd,e.organization_id,a,'student.section_placement_corrected','student_section_placement',p.id,oldj,newj,jsonb_build_object('student_id',e.student_id,'enrollment_id',e.id,'placement_id',p.id,'section_id',p.section_id,'school_id',p.school_id,'campus_id',p.campus_id,'correction_reason',btrim(p_reason)));
 if mate.id is not null and mate.status<>'corrected' then oldj:=to_jsonb(mate); update public.student_section_placements set status='corrected',correction_reason=btrim(p_reason),updated_by=a where id=mate.id returning to_jsonb(student_section_placements.*) into newj; perform app_auth.write_enrollment_change(cmd,e.organization_id,a,'student.section_placement_corrected','student_section_placement',mate.id,oldj,newj,jsonb_build_object('student_id',e.student_id,'enrollment_id',e.id,'placement_id',mate.id,'section_id',mate.section_id,'school_id',mate.school_id,'campus_id',mate.campus_id,'correction_reason',btrim(p_reason))); end if;
 if p_create then r:=app_auth.place_student(e.id,p_section,p_start,p.id,true,cmd,p_status,p_end,p_end_reason); end if;
 return query select p.id,r;
end $$;

create function public.enroll_student(student_id uuid,academic_year_id uuid,grade_level_id uuid,enrolled_on date) returns uuid language sql security definer set search_path='' as $$ select app_auth.enroll_student(student_id,academic_year_id,grade_level_id,enrolled_on); $$;
create function public.withdraw_student_enrollment(id uuid,ended_on date,reason text) returns uuid language sql security definer set search_path='' as $$ select app_auth.end_enrollment(id,'withdrawn',ended_on,reason); $$;
create function public.complete_student_enrollment(id uuid,ended_on date,reason text) returns uuid language sql security definer set search_path='' as $$ select app_auth.end_enrollment(id,'completed',ended_on,reason); $$;
create function public.correct_student_enrollment(id uuid,replacement_academic_year_id uuid,replacement_grade_level_id uuid,replacement_enrolled_on date,replacement_status public.enrollment_status,replacement_ended_on date,replacement_end_reason text,create_replacement boolean,correction_reason text)
returns table(corrected_enrollment_id uuid,replacement_enrollment_id uuid) language sql security definer set search_path='' as $$ select * from app_auth.correct_enrollment(id,replacement_academic_year_id,replacement_grade_level_id,replacement_enrolled_on,replacement_status,replacement_ended_on,replacement_end_reason,create_replacement,correction_reason); $$;
create function public.place_student_in_section(student_enrollment_id uuid,section_id uuid,starts_on date) returns uuid language sql security definer set search_path='' as $$ select app_auth.place_student(student_enrollment_id,section_id,starts_on); $$;
create function public.transfer_student_section(id uuid,destination_section_id uuid,transfer_on date,reason text) returns table(from_placement_id uuid,to_placement_id uuid) language sql security definer set search_path='' as $$ select * from app_auth.transfer_placement(id,destination_section_id,transfer_on,reason); $$;
create function public.withdraw_student_section_placement(id uuid,ended_on date,reason text) returns uuid language sql security definer set search_path='' as $$ select app_auth.end_placement(id,'withdrawn',ended_on,reason); $$;
create function public.complete_student_section_placement(id uuid,ended_on date,reason text) returns uuid language sql security definer set search_path='' as $$ select app_auth.end_placement(id,'completed',ended_on,reason); $$;
create function public.correct_student_section_placement(id uuid,replacement_section_id uuid,replacement_starts_on date,replacement_ends_on date,replacement_status public.section_placement_status,replacement_end_reason text,create_replacement boolean,correction_reason text)
returns table(corrected_placement_id uuid,replacement_placement_id uuid) language sql security definer set search_path='' as $$ select * from app_auth.correct_placement(id,replacement_section_id,replacement_starts_on,replacement_ends_on,replacement_status,replacement_end_reason,create_replacement,correction_reason); $$;

create or replace function app_auth.write_academic_change(o uuid,actor uuid,action_name text,entity_name text,entity uuid,before_row jsonb,after_row jsonb) returns void
language plpgsql security definer set search_path='' as $$
declare cmd uuid:=gen_random_uuid(); row_data jsonb:=coalesce(after_row,before_row,'{}'); changed jsonb;
 school uuid:=(row_data->>'school_id')::uuid; campus uuid:=(row_data->>'campus_id')::uuid;
 academic_year uuid:=coalesce((row_data->>'academic_year_id')::uuid,case when entity_name='academic_year' then entity end);
 academic_term uuid:=coalesce((row_data->>'academic_term_id')::uuid,case when entity_name='academic_term' then entity end); event_payload jsonb;
begin
 if entity_name='academic_year' and action_name='academic_year.status_changed' and after_row->>'status' in ('closed','archived')
  and exists(select 1 from public.student_enrollments e where e.academic_year_id=entity and e.status='active') then raise exception using errcode='22023',message='academic year has active enrollments'; end if;
 if entity_name='academic_year' and action_name='academic_year.updated' and exists(select 1 from public.student_enrollments e where e.academic_year_id=entity and e.status<>'corrected'
  and (e.enrolled_on<(after_row->>'start_date')::date or e.scheduled_end_on>(after_row->>'end_date')::date)) then raise exception using errcode='22023',message='academic year dates exclude enrollment history'; end if;
 if school is null and academic_year is not null then select y.school_id into school from public.academic_years y where y.id=academic_year; end if;
 select coalesce(jsonb_agg(k order by k),'[]') into changed from(select x.key k from jsonb_object_keys(coalesce(before_row,'{}')||coalesce(after_row,'{}')) x(key) where before_row->x.key is distinct from after_row->x.key) q;
 event_payload:=jsonb_strip_nulls(jsonb_build_object('command_id',cmd,'actor_user_id',actor,'organization_id',o,'entity_id',entity,'aggregate_id',entity,'school_id',school,'campus_id',campus,'academic_year_id',academic_year,'academic_term_id',academic_term,'changed_fields',changed,'before_status',before_row->>'status','after_status',after_row->>'status'));
 insert into public.audit_log(command_id,organization_id,actor_user_id,action,entity_type,entity_id,before_data,after_data) values(cmd,o,actor,action_name,entity_name,entity,before_row,after_row);
 insert into public.event_outbox(command_id,organization_id,event_type,aggregate_type,aggregate_id,payload) values(cmd,o,action_name,entity_name,entity,event_payload);
end $$;

-- Preserve academic capacity/history invariants through wrappers around v0.3 implementations.
alter function public.update_section(uuid,text,text,integer,date,date,uuid,uuid,public.record_status,boolean,boolean) rename to update_section_v0_3_impl;
alter function public.archive_section(uuid) rename to archive_section_v0_3_impl;
alter function public.update_section_v0_3_impl(uuid,text,text,integer,date,date,uuid,uuid,public.record_status,boolean,boolean) set schema app_auth;
alter function public.archive_section_v0_3_impl(uuid) set schema app_auth;
alter function public.update_academic_year(uuid,text,date,date) rename to update_academic_year_v0_3_impl;
alter function public.transition_academic_year_status(uuid,public.academic_period_status) rename to transition_academic_year_status_v0_3_impl;
revoke all on function app_auth.update_section_v0_3_impl(uuid,text,text,integer,date,date,uuid,uuid,public.record_status,boolean,boolean),app_auth.archive_section_v0_3_impl(uuid),public.update_academic_year_v0_3_impl(uuid,text,date,date),public.transition_academic_year_status_v0_3_impl(uuid,public.academic_period_status) from public,anon,authenticated,service_role;
create function public.update_section(id uuid,code text,name text,capacity integer,start_date date,end_date date,academic_term_id uuid,homeroom_room_id uuid,status public.record_status,set_academic_term_id boolean default false,set_homeroom_room_id boolean default false) returns uuid language plpgsql security definer set search_path='' as $$ declare r uuid; begin r:=app_auth.update_section_v0_3_impl(id,code,name,capacity,start_date,end_date,academic_term_id,homeroom_room_id,status,set_academic_term_id,set_homeroom_room_id); if exists(select 1 from public.student_section_placements p where p.section_id=update_section.id and p.status='active') and (update_section.status<>'active' or update_section.capacity<(select count(*) from public.student_section_placements p where p.section_id=update_section.id and p.status='active') or exists(select 1 from public.student_section_placements p where p.section_id=update_section.id and p.status<>'corrected' and (p.starts_on<update_section.start_date or coalesce(p.ends_on,p.starts_on)>update_section.end_date))) then raise exception using errcode='22023',message='section change conflicts with placement history or capacity'; end if; return r; end $$;
create function public.archive_section(id uuid) returns uuid language plpgsql security definer set search_path='' as $$ declare r uuid; begin r:=app_auth.archive_section_v0_3_impl(id); if exists(select 1 from public.student_section_placements p where p.section_id=archive_section.id and p.status='active') then raise exception using errcode='22023',message='section has active placements'; end if; return r; end $$;
create function public.update_academic_year(id uuid,name text,start_date date,end_date date) returns uuid language plpgsql security definer set search_path='' as $$ declare r uuid; begin r:=public.update_academic_year_v0_3_impl(id,name,start_date,end_date); if exists(select 1 from public.student_enrollments e where e.academic_year_id=update_academic_year.id and e.status<>'corrected' and (e.enrolled_on<update_academic_year.start_date or e.scheduled_end_on>update_academic_year.end_date)) then raise exception using errcode='22023',message='academic year dates exclude enrollment history'; end if; return r; end $$;
create function public.transition_academic_year_status(id uuid,status public.academic_period_status) returns uuid language plpgsql security definer set search_path='' as $$ declare r uuid; begin r:=public.transition_academic_year_status_v0_3_impl(id,status); if transition_academic_year_status.status in ('closed','archived') and exists(select 1 from public.student_enrollments e where e.academic_year_id=transition_academic_year_status.id and e.status='active') then raise exception using errcode='22023',message='academic year has active enrollments'; end if; return r; end $$;

-- The v0.3 period bodies qualify parameters by their published function names, so
-- retain those exact bodies/names. Active placements require active sections, and
-- the existing period commands already block close/archive while sections are active.
drop function public.update_academic_year(uuid,text,date,date);
alter function public.update_academic_year_v0_3_impl(uuid,text,date,date) rename to update_academic_year;
drop function public.transition_academic_year_status(uuid,public.academic_period_status);
alter function public.transition_academic_year_status_v0_3_impl(uuid,public.academic_period_status) rename to transition_academic_year_status;

do $$ declare p regprocedure; begin
 foreach p in array array[
  'public.enroll_student(uuid,uuid,uuid,date)'::regprocedure,'public.withdraw_student_enrollment(uuid,date,text)'::regprocedure,'public.complete_student_enrollment(uuid,date,text)'::regprocedure,
  'public.correct_student_enrollment(uuid,uuid,uuid,date,public.enrollment_status,date,text,boolean,text)'::regprocedure,'public.place_student_in_section(uuid,uuid,date)'::regprocedure,
  'public.transfer_student_section(uuid,uuid,date,text)'::regprocedure,'public.withdraw_student_section_placement(uuid,date,text)'::regprocedure,'public.complete_student_section_placement(uuid,date,text)'::regprocedure,
  'public.correct_student_section_placement(uuid,uuid,date,date,public.section_placement_status,text,boolean,text)'::regprocedure,
  'public.update_section(uuid,text,text,integer,date,date,uuid,uuid,public.record_status,boolean,boolean)'::regprocedure,'public.archive_section(uuid)'::regprocedure,
  'public.update_academic_year(uuid,text,date,date)'::regprocedure,'public.transition_academic_year_status(uuid,public.academic_period_status)'::regprocedure]
 loop execute format('alter function %s owner to postgres',p); execute format('revoke all on function %s from public,anon',p); execute format('grant execute on function %s to authenticated,service_role',p); end loop;
end $$;
alter table public.student_enrollments owner to postgres;
alter table public.student_section_placements owner to postgres;
do $$ declare p regprocedure; begin foreach p in array array[
 'app_auth.can_view_enrollment(uuid,uuid,uuid,uuid)'::regprocedure,'app_auth.assert_enrollment_actor()'::regprocedure,'app_auth.assert_enrollment_permission(uuid,uuid,uuid,boolean)'::regprocedure,
 'app_auth.write_enrollment_change(uuid,uuid,uuid,text,text,uuid,jsonb,jsonb,jsonb)'::regprocedure,'app_auth.lock_enrollment_parents(uuid,uuid[],uuid[],uuid[])'::regprocedure,
 'app_auth.assert_enrollment_row(public.student_enrollments,boolean)'::regprocedure,'app_auth.enroll_student(uuid,uuid,uuid,date,uuid,boolean,uuid,public.enrollment_status,date,text)'::regprocedure,
 'app_auth.end_enrollment(uuid,public.enrollment_status,date,text,uuid)'::regprocedure,'app_auth.correct_enrollment(uuid,uuid,uuid,date,public.enrollment_status,date,text,boolean,text)'::regprocedure,
 'app_auth.assert_placement_context(public.student_enrollments,public.sections,date)'::regprocedure,'app_auth.place_student(uuid,uuid,date,uuid,boolean,uuid,public.section_placement_status,date,text)'::regprocedure,
 'app_auth.end_placement(uuid,public.section_placement_status,date,text,uuid)'::regprocedure,'app_auth.transfer_placement(uuid,uuid,date,text)'::regprocedure,
 'app_auth.correct_placement(uuid,uuid,date,date,public.section_placement_status,text,boolean,text)'::regprocedure]
 loop execute format('alter function %s owner to postgres',p); end loop; end $$;
revoke all on function app_auth.assert_enrollment_actor(),app_auth.assert_enrollment_permission(uuid,uuid,uuid,boolean),app_auth.write_enrollment_change(uuid,uuid,uuid,text,text,uuid,jsonb,jsonb,jsonb),app_auth.lock_enrollment_parents(uuid,uuid[],uuid[],uuid[]),app_auth.assert_enrollment_row(public.student_enrollments,boolean),app_auth.enroll_student(uuid,uuid,uuid,date,uuid,boolean,uuid,public.enrollment_status,date,text),app_auth.end_enrollment(uuid,public.enrollment_status,date,text,uuid),app_auth.correct_enrollment(uuid,uuid,uuid,date,public.enrollment_status,date,text,boolean,text),app_auth.assert_placement_context(public.student_enrollments,public.sections,date),app_auth.place_student(uuid,uuid,date,uuid,boolean,uuid,public.section_placement_status,date,text),app_auth.end_placement(uuid,public.section_placement_status,date,text,uuid),app_auth.transfer_placement(uuid,uuid,date,text),app_auth.correct_placement(uuid,uuid,date,date,public.section_placement_status,text,boolean,text) from public,anon,authenticated,service_role;
revoke all on function app_auth.can_view_enrollment(uuid,uuid,uuid,uuid) from public,anon; grant execute on function app_auth.can_view_enrollment(uuid,uuid,uuid,uuid) to authenticated,service_role;

comment on table public.student_enrollments is 'Immutable academic-year enrollment history; writes use typed enrollment commands.';
comment on table public.student_section_placements is 'Immutable effective-dated section-placement episodes; no hard deletes or in-place historical correction.';
comment on function app_auth.lock_enrollment_parents(uuid,uuid[],uuid[],uuid[]) is 'Locks organization, sorted schools/campuses, student, sorted years/grades/terms/sections before enrollment/placements.';
comment on function app_auth.write_enrollment_change(uuid,uuid,uuid,text,text,uuid,jsonb,jsonb,jsonb) is 'Private atomic enrollment audit/outbox writer with server-derived correlation.';
comment on function public.correct_student_section_placement(uuid,uuid,date,date,public.section_placement_status,text,boolean,text) is 'Corrects both original transfer halves atomically and may append at most one replacement placement; recreating a transfer requires a future workflow.';

commit;
