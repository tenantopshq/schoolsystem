begin;

create type public.assessment_type as enum ('assignment','quiz','exam','project','participation');
create type public.assessment_lifecycle_status as enum ('draft','finalized','corrected','cancelled');
create type public.assessment_publication_state as enum ('unpublished','published');
create type public.assessment_result_input as (
 student_id uuid, score numeric, teacher_comment text
);

create table public.assessments (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null, school_id uuid not null,
 campus_id uuid not null, academic_year_id uuid not null, academic_term_id uuid not null,
 section_id uuid not null, subject_id uuid, assessment_type public.assessment_type not null,
 title text not null check(length(btrim(title)) between 1 and 160),
 description text check(description is null or length(btrim(description)) between 1 and 2000),
 assessment_date date not null, due_date date,
 maximum_score numeric(12,4) not null check(maximum_score>0 and maximum_score<=1000000),
 weight numeric(7,4) check(weight is null or (weight>0 and weight<=100)),
 lifecycle_status public.assessment_lifecycle_status not null default 'draft',
 publication_state public.assessment_publication_state not null default 'unpublished',
 published_at timestamptz, published_by uuid references auth.users(id) on delete restrict,
 finalized_at timestamptz, finalized_by uuid references auth.users(id) on delete restrict,
 supersedes_assessment_id uuid,
 correction_reason text check(correction_reason is null or length(btrim(correction_reason)) between 1 and 500),
 cancellation_reason text check(cancellation_reason is null or length(btrim(cancellation_reason)) between 1 and 500),
 cancelled_at timestamptz, cancelled_by uuid references auth.users(id) on delete restrict,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 created_by uuid not null references auth.users(id) on delete restrict,
 updated_by uuid not null references auth.users(id) on delete restrict,
 foreign key(organization_id,school_id,campus_id,academic_year_id,section_id)
  references public.sections(organization_id,school_id,campus_id,academic_year_id,id) on delete restrict,
 foreign key(organization_id,academic_year_id,academic_term_id)
  references public.academic_terms(organization_id,academic_year_id,id) on delete restrict,
 foreign key(organization_id,school_id,subject_id)
  references public.subjects(organization_id,school_id,id) on delete restrict,
 foreign key(organization_id,supersedes_assessment_id)
  references public.assessments(organization_id,id) on delete restrict,
 unique(organization_id,id),
 unique(organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,id),
 check(due_date is null or due_date>=assessment_date),
 check(supersedes_assessment_id is null or supersedes_assessment_id<>id),
 check(
  (lifecycle_status='draft' and publication_state='unpublished'
   and published_at is null and published_by is null and finalized_at is null and finalized_by is null
   and correction_reason is null and cancellation_reason is null and cancelled_at is null and cancelled_by is null)
  or
  (lifecycle_status='draft' and publication_state='published'
   and published_at is not null and published_by is not null and finalized_at is null and finalized_by is null
   and correction_reason is null and cancellation_reason is null and cancelled_at is null and cancelled_by is null)
  or
  (lifecycle_status='finalized'
   and finalized_at is not null and finalized_by is not null and correction_reason is null
   and cancellation_reason is null and cancelled_at is null and cancelled_by is null
   and ((publication_state='unpublished' and published_at is null and published_by is null)
     or (publication_state='published' and published_at is not null and published_by is not null)))
  or
  (lifecycle_status='corrected'
   and finalized_at is not null and finalized_by is not null and correction_reason is not null
   and cancellation_reason is null and cancelled_at is null and cancelled_by is null
   and ((publication_state='unpublished' and published_at is null and published_by is null)
     or (publication_state='published' and published_at is not null and published_by is not null)))
  or
  (lifecycle_status='cancelled' and publication_state='unpublished'
   and published_at is null and published_by is null and finalized_at is null and finalized_by is null
   and correction_reason is null and cancellation_reason is not null
   and cancelled_at is not null and cancelled_by is not null)
 )
);

create unique index assessments_one_successor_key on public.assessments(supersedes_assessment_id)
 where supersedes_assessment_id is not null;
create unique index assessments_live_title_date_key
 on public.assessments(section_id,lower(btrim(title)),assessment_date)
 where lifecycle_status not in ('corrected','cancelled');
create index assessments_scope_idx on public.assessments
 (organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,lifecycle_status,publication_state);
create index assessments_subject_idx on public.assessments(organization_id,school_id,subject_id,lifecycle_status)
 where subject_id is not null;
create index assessments_supersedes_idx on public.assessments(organization_id,supersedes_assessment_id)
 where supersedes_assessment_id is not null;
create index assessments_created_by_idx on public.assessments(created_by);
create index assessments_updated_by_idx on public.assessments(updated_by);
create index assessments_published_by_idx on public.assessments(published_by) where published_by is not null;
create index assessments_finalized_by_idx on public.assessments(finalized_by) where finalized_by is not null;
create index assessments_cancelled_by_idx on public.assessments(cancelled_by) where cancelled_by is not null;
create trigger assessments_updated_at before update on public.assessments
 for each row execute function public.set_updated_at();

create table public.assessment_students (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null, school_id uuid not null,
 campus_id uuid not null, academic_year_id uuid not null, academic_term_id uuid not null,
 section_id uuid not null, assessment_id uuid not null, student_id uuid not null,
 student_enrollment_id uuid not null, student_section_placement_id uuid not null,
 created_at timestamptz not null default now(), created_by uuid not null references auth.users(id) on delete restrict,
 foreign key(organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,assessment_id)
  references public.assessments(organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,id) on delete restrict,
 foreign key(organization_id,student_id) references public.students(organization_id,id) on delete restrict,
 foreign key(organization_id,school_id,academic_year_id,student_id,student_enrollment_id)
  references public.student_enrollments(organization_id,school_id,academic_year_id,student_id,id) on delete restrict,
 foreign key(organization_id,school_id,campus_id,academic_year_id,section_id,student_id,student_enrollment_id,student_section_placement_id)
  references public.student_section_placements(organization_id,school_id,campus_id,academic_year_id,section_id,student_id,student_enrollment_id,id) on delete restrict,
 unique(organization_id,id), unique(assessment_id,student_id), unique(assessment_id,student_section_placement_id),
 unique(organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,assessment_id,student_id,id)
);
create index assessment_students_assessment_idx on public.assessment_students(organization_id,assessment_id,student_id);
create index assessment_students_student_idx on public.assessment_students(organization_id,student_id,assessment_id);
create index assessment_students_enrollment_idx on public.assessment_students(organization_id,student_enrollment_id);
create index assessment_students_placement_idx on public.assessment_students(organization_id,student_section_placement_id);
create index assessment_students_created_by_idx on public.assessment_students(created_by);

create table public.assessment_results (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null, school_id uuid not null,
 campus_id uuid not null, academic_year_id uuid not null, academic_term_id uuid not null,
 section_id uuid not null, assessment_id uuid not null, assessment_student_id uuid not null,
 student_id uuid not null, score numeric(12,4),
 teacher_comment text check(teacher_comment is null or length(btrim(teacher_comment)) between 1 and 1000),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 created_by uuid not null references auth.users(id) on delete restrict,
 updated_by uuid not null references auth.users(id) on delete restrict,
 foreign key(organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,assessment_id)
  references public.assessments(organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,id) on delete restrict,
 foreign key(organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,assessment_id,student_id,assessment_student_id)
  references public.assessment_students(organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,assessment_id,student_id,id) on delete restrict,
 unique(organization_id,id), unique(assessment_id,student_id), unique(assessment_student_id),
 check(score is null or score>=0), check(score is not null or teacher_comment is null)
);
create index assessment_results_assessment_idx on public.assessment_results(organization_id,assessment_id,student_id);
create index assessment_results_student_idx on public.assessment_results(organization_id,student_id,assessment_id);
create index assessment_results_snapshot_idx on public.assessment_results(organization_id,assessment_student_id);
create index assessment_results_created_by_idx on public.assessment_results(created_by);
create index assessment_results_updated_by_idx on public.assessment_results(updated_by);
create trigger assessment_results_updated_at before update on public.assessment_results
 for each row execute function public.set_updated_at();

create function app_auth.enforce_assessment_immutability() returns trigger
language plpgsql set search_path='' as $$ begin
 if new.organization_id is distinct from old.organization_id or new.school_id is distinct from old.school_id
  or new.campus_id is distinct from old.campus_id or new.academic_year_id is distinct from old.academic_year_id
  or new.academic_term_id is distinct from old.academic_term_id or new.section_id is distinct from old.section_id
  or new.subject_id is distinct from old.subject_id or new.assessment_date is distinct from old.assessment_date
  or new.maximum_score is distinct from old.maximum_score or new.weight is distinct from old.weight
  or new.supersedes_assessment_id is distinct from old.supersedes_assessment_id
  or new.created_at is distinct from old.created_at or new.created_by is distinct from old.created_by
 then raise exception using errcode='22023',message='assessment immutable fields cannot change'; end if;
 if old.lifecycle_status in ('corrected','cancelled') then
  raise exception using errcode='22023',message='terminal assessment cannot change';
 end if;
 if old.lifecycle_status='finalized' and (
  new.assessment_type is distinct from old.assessment_type or new.title is distinct from old.title
  or new.description is distinct from old.description or new.due_date is distinct from old.due_date
  or new.finalized_at is distinct from old.finalized_at or new.finalized_by is distinct from old.finalized_by
 ) then raise exception using errcode='22023',message='finalized academic content cannot change'; end if;
 return new;
end $$;
create trigger assessments_immutable before update on public.assessments
 for each row execute function app_auth.enforce_assessment_immutability();

create function app_auth.enforce_assessment_result_integrity() returns trigger
language plpgsql security definer set search_path='' as $$ declare a public.assessments%rowtype; begin
 select * into a from public.assessments x where x.id=new.assessment_id;
 if not found then raise exception using errcode='23503',message='assessment not found'; end if;
 if tg_op='UPDATE' and (new.organization_id is distinct from old.organization_id
  or new.school_id is distinct from old.school_id or new.campus_id is distinct from old.campus_id
  or new.academic_year_id is distinct from old.academic_year_id or new.academic_term_id is distinct from old.academic_term_id
  or new.section_id is distinct from old.section_id or new.assessment_id is distinct from old.assessment_id
  or new.assessment_student_id is distinct from old.assessment_student_id or new.student_id is distinct from old.student_id
  or new.created_at is distinct from old.created_at or new.created_by is distinct from old.created_by) then
  raise exception using errcode='22023',message='assessment result identity cannot change';
 end if;
 if tg_op='UPDATE' and a.lifecycle_status<>'draft' then
  raise exception using errcode='22023',message='only draft assessment results may change';
 end if;
 if new.score is not null and new.score>a.maximum_score then
  raise exception using errcode='22023',message='score exceeds assessment maximum';
 end if;
 return new;
end $$;
create trigger assessment_results_integrity before insert or update on public.assessment_results
 for each row execute function app_auth.enforce_assessment_result_integrity();

insert into public.permissions(code,module,description) values
 ('assessments.view','assessments','View assessments and results within assigned scope'),
 ('assessments.manage','assessments','Create, grade, publish, finalize, and cancel assessments within assigned scope'),
 ('assessments.correct','assessments','Correct finalized assessment and result history within assigned scope');

create function app_auth.has_assessment_assignment(p_assessment uuid,p_roles public.teaching_assignment_role[]) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(
  select 1 from public.assessments a
  join public.sections s on s.id=a.section_id and s.status='active'
  join public.academic_years y on y.id=a.academic_year_id and y.status='active'
  join public.teaching_assignments t on t.section_id=a.section_id
   and t.subject_id is not distinct from a.subject_id and t.status='active'
   and current_date<@t.effective_range and t.role=any(p_roles)
  join public.staff_profiles sp on (sp.organization_id,sp.id)=(t.organization_id,t.staff_profile_id)
   and sp.status='active'
  join public.organization_memberships m on (m.organization_id,m.id)=(sp.organization_id,sp.organization_membership_id)
   and m.status='active' and m.left_at is null and m.user_id=auth.uid()
  left join public.subjects u on (u.organization_id,u.school_id,u.id)=(a.organization_id,a.school_id,a.subject_id)
  where a.id=p_assessment and (a.subject_id is null or u.status='active'));
$$;

create function app_auth.has_assessment_assignment_context(p_section uuid,p_subject uuid,p_roles public.teaching_assignment_role[]) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.teaching_assignments t
  join public.staff_profiles sp on (sp.organization_id,sp.id)=(t.organization_id,t.staff_profile_id) and sp.status='active'
  join public.organization_memberships m on (m.organization_id,m.id)=(sp.organization_id,sp.organization_membership_id)
   and m.status='active' and m.left_at is null and m.user_id=auth.uid()
  where t.section_id=p_section and t.subject_id is not distinct from p_subject and t.status='active'
   and current_date<@t.effective_range and t.role=any(p_roles));
$$;

create function app_auth.can_read_assessment(p_assessment uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.assessments a where a.id=p_assessment and (
  app_auth.has_permission(a.organization_id,'assessments.view',a.school_id,a.campus_id)
  or app_auth.has_permission(a.organization_id,'assessments.manage',a.school_id,a.campus_id)
  or app_auth.has_permission(a.organization_id,'assessments.correct',a.school_id,a.campus_id)
  or app_auth.has_assessment_assignment(a.id,array['lead','co_teacher','assistant','substitute']::public.teaching_assignment_role[])
  or (a.publication_state='published' and a.lifecycle_status not in ('corrected','cancelled') and exists(
   select 1 from public.assessment_results r join public.students st on st.id=r.student_id and st.status='active'
    where r.assessment_id=a.id and r.score is not null
    and (app_auth.is_student_self(r.student_id) or app_auth.is_linked_guardian(r.student_id))))));
$$;

create function app_auth.can_read_assessment_student(p_assessment_student uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.assessment_students x join public.assessments a on a.id=x.assessment_id
  join public.students st on st.id=x.student_id
  where x.id=p_assessment_student and (
   app_auth.has_permission(a.organization_id,'assessments.view',a.school_id,a.campus_id)
   or app_auth.has_permission(a.organization_id,'assessments.manage',a.school_id,a.campus_id)
   or app_auth.has_permission(a.organization_id,'assessments.correct',a.school_id,a.campus_id)
   or app_auth.has_assessment_assignment(a.id,array['lead','co_teacher','assistant','substitute']::public.teaching_assignment_role[])
   or (a.publication_state='published' and a.lifecycle_status not in ('corrected','cancelled') and st.status='active'
    and (app_auth.is_student_self(x.student_id) or app_auth.is_linked_guardian(x.student_id)))));
$$;

create function app_auth.can_read_assessment_result(p_result uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.assessment_results r join public.assessments a on a.id=r.assessment_id
  join public.students st on st.id=r.student_id
  where r.id=p_result and (
   app_auth.has_permission(a.organization_id,'assessments.view',a.school_id,a.campus_id)
   or app_auth.has_permission(a.organization_id,'assessments.manage',a.school_id,a.campus_id)
   or app_auth.has_permission(a.organization_id,'assessments.correct',a.school_id,a.campus_id)
   or app_auth.has_assessment_assignment(a.id,array['lead','co_teacher','assistant','substitute']::public.teaching_assignment_role[])
   or (a.publication_state='published' and a.lifecycle_status not in ('corrected','cancelled') and r.score is not null and st.status='active'
    and (app_auth.is_student_self(r.student_id) or app_auth.is_linked_guardian(r.student_id)))));
$$;

alter table public.assessments enable row level security; alter table public.assessments force row level security;
alter table public.assessment_students enable row level security; alter table public.assessment_students force row level security;
alter table public.assessment_results enable row level security; alter table public.assessment_results force row level security;
create policy assessments_select on public.assessments for select to authenticated using(app_auth.can_read_assessment(id));
create policy assessment_students_select on public.assessment_students for select to authenticated using(app_auth.can_read_assessment_student(id));
create policy assessment_results_select on public.assessment_results for select to authenticated using(app_auth.can_read_assessment_result(id));
revoke all on public.assessments,public.assessment_students,public.assessment_results from public,anon,authenticated;
grant select on public.assessments,public.assessment_students,public.assessment_results to authenticated;

create function app_auth.assert_assessment_actor() returns uuid
language plpgsql security definer set search_path='' as $$ declare a uuid:=auth.uid(); begin
 if a is null then raise exception using errcode='42501',message='authentication required'; end if; return a;
end $$;

create function app_auth.assert_assessment_authority(a public.assessments,p_correct boolean default false) returns void
language plpgsql security definer set search_path='' as $$ begin
 if p_correct then
  if not app_auth.has_permission(a.organization_id,'assessments.manage',a.school_id,a.campus_id)
   or not app_auth.has_permission(a.organization_id,'assessments.correct',a.school_id,a.campus_id) then
   raise exception using errcode='42501',message='assessments.manage and assessments.correct permissions are required';
  end if; return;
 end if;
 if app_auth.has_permission(a.organization_id,'assessments.manage',a.school_id,a.campus_id) then return; end if;
 if not app_auth.has_assessment_assignment(a.id,array['lead','co_teacher','substitute']::public.teaching_assignment_role[]) then
  raise exception using errcode='42501',message='effective teaching assignment or assessments.manage permission is required';
 end if;
end $$;

create function app_auth.lock_assessment_context(a public.assessments) returns void
language plpgsql security definer set search_path='' as $$ begin
 perform 1 from public.organizations where id=a.organization_id for update;
 perform 1 from public.schools where id=a.school_id for update;
 perform 1 from public.campuses where id=a.campus_id for update;
 perform 1 from public.academic_years where id=a.academic_year_id for update;
 perform 1 from public.academic_terms where id=a.academic_term_id for update;
 perform 1 from public.sections where id=a.section_id for update;
 if a.subject_id is not null then perform 1 from public.subjects where id=a.subject_id for update; end if;
 perform 1 from public.teaching_assignments t where t.section_id=a.section_id
  and t.subject_id is not distinct from a.subject_id order by t.id for update;
end $$;

create function app_auth.write_assessment_change(p_cmd uuid,p_org uuid,p_actor uuid,p_action text,p_type text,p_id uuid,p_before jsonb,p_after jsonb,p_payload jsonb,p_emit boolean default true) returns void
language plpgsql security definer set search_path='' as $$ begin
 insert into public.audit_log(command_id,organization_id,actor_user_id,action,entity_type,entity_id,before_data,after_data)
 values(p_cmd,p_org,p_actor,p_action,p_type,p_id,p_before,p_after);
 if p_emit then insert into public.event_outbox(command_id,organization_id,event_type,aggregate_type,aggregate_id,payload)
  values(p_cmd,p_org,p_action,p_type,p_id,jsonb_strip_nulls(coalesce(p_payload,'{}')||jsonb_build_object(
   'command_id',p_cmd,'actor_user_id',p_actor,'organization_id',p_org,'aggregate_id',p_id))); end if;
end $$;

create function app_auth.assert_assessment_values(p_section public.sections,p_term uuid,p_subject uuid,p_date date,p_due date,p_max numeric,p_weight numeric,p_require_active boolean default true) returns void
language plpgsql security definer set search_path='' as $$ declare y public.academic_years%rowtype; t public.academic_terms%rowtype; u public.subjects%rowtype; begin
 select * into y from public.academic_years where id=p_section.academic_year_id;
 select * into t from public.academic_terms where id=p_term;
 if y.id is null or t.id is null or t.organization_id<>p_section.organization_id or t.academic_year_id<>p_section.academic_year_id
  or (p_section.academic_term_id is not null and p_section.academic_term_id<>t.id) then
  raise exception using errcode='22023',message='compatible section, year, and term are required';
 end if;
 if p_require_active and (p_section.status<>'active' or y.status<>'active' or t.status<>'active') then
  raise exception using errcode='22023',message='active section, year, and term are required';
 end if;
 if p_subject is not null then select * into u from public.subjects where id=p_subject;
  if not found or (u.organization_id,u.school_id)<>(p_section.organization_id,p_section.school_id)
   or (p_require_active and u.status<>'active') then
   raise exception using errcode='22023',message='compatible subject in section school is required'; end if;
 end if;
 if p_date is null or p_date not between p_section.start_date and p_section.end_date
  or p_date not between y.start_date and y.end_date or p_date not between t.start_date and t.end_date
  or (p_due is not null and (p_due<p_date or p_due>p_section.end_date or p_due>y.end_date or p_due>t.end_date)) then
  raise exception using errcode='22023',message='assessment and due dates must be inside section, year, and term';
 end if;
 if p_max is null or p_max<=0 or p_max>1000000 or (p_weight is not null and (p_weight<=0 or p_weight>100)) then
  raise exception using errcode='22023',message='maximum score or weight is outside bounds'; end if;
end $$;

create function public.create_assessment(section_id uuid,academic_term_id uuid,subject_id uuid,
 assessment_type public.assessment_type,title text,description text,assessment_date date,due_date date,
 maximum_score numeric,weight numeric) returns uuid
language plpgsql security definer set search_path='' as $$
declare actor uuid:=app_auth.assert_assessment_actor(); s public.sections%rowtype; y public.academic_years%rowtype;
 t public.academic_terms%rowtype; a public.assessments%rowtype; q record; sid uuid; rid uuid;
 cmd uuid:=gen_random_uuid(); n integer:=0; j jsonb;
begin
 select * into s from public.sections x where x.id=create_assessment.section_id;
 if not found then raise exception using errcode='P0002',message='section not found'; end if;
 perform 1 from public.organizations where id=s.organization_id for update;
 perform 1 from public.schools where id=s.school_id for update;
 perform 1 from public.campuses where id=s.campus_id for update;
 perform 1 from public.academic_years where id=s.academic_year_id for update;
 perform 1 from public.academic_terms where id=create_assessment.academic_term_id for update;
 select * into s from public.sections x where x.id=s.id for update;
 if create_assessment.subject_id is not null then perform 1 from public.subjects where id=create_assessment.subject_id for update; end if;
 perform 1 from public.teaching_assignments ta where ta.section_id=s.id
  and ta.subject_id is not distinct from create_assessment.subject_id order by ta.id for update;
 select * into y from public.academic_years where id=s.academic_year_id;
 select * into t from public.academic_terms where id=create_assessment.academic_term_id;
 if not exists(select 1 from public.organizations o join public.schools sc on sc.organization_id=o.id
  join public.campuses c on (c.organization_id,c.school_id)=(sc.organization_id,sc.id)
  where (o.id,sc.id,c.id)=(s.organization_id,s.school_id,s.campus_id)
   and o.status='active' and sc.status='active' and c.status='active') then
  raise exception using errcode='22023',message='active organization, school, and campus are required'; end if;
 perform app_auth.assert_assessment_values(s,t.id,create_assessment.subject_id,create_assessment.assessment_date,
  create_assessment.due_date,create_assessment.maximum_score,create_assessment.weight);
 if not app_auth.has_permission(s.organization_id,'assessments.manage',s.school_id,s.campus_id)
  and not app_auth.has_assessment_assignment_context(s.id,create_assessment.subject_id,
   array['lead','co_teacher','substitute']::public.teaching_assignment_role[]) then
  raise exception using errcode='42501',message='effective teaching assignment or assessments.manage permission is required';
 end if;
 perform 1 from public.students st join public.student_section_placements p on p.student_id=st.id
  join public.student_enrollments e on e.id=p.student_enrollment_id
  where p.section_id=s.id and p.status<>'corrected' and e.status<>'corrected'
   and create_assessment.assessment_date between p.starts_on and coalesce(p.ends_on,create_assessment.assessment_date)
   and create_assessment.assessment_date<@e.enrollment_range order by st.id,p.id for update of st,e,p;
 insert into public.assessments(organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,
  subject_id,assessment_type,title,description,assessment_date,due_date,maximum_score,weight,created_by,updated_by)
 values(s.organization_id,s.school_id,s.campus_id,s.academic_year_id,t.id,s.id,create_assessment.subject_id,
  create_assessment.assessment_type,btrim(create_assessment.title),case when create_assessment.description is null then null else btrim(create_assessment.description) end,
  create_assessment.assessment_date,create_assessment.due_date,create_assessment.maximum_score,create_assessment.weight,actor,actor)
 returning * into a;
 for q in select p.id placement_id,p.student_id,p.student_enrollment_id
  from public.student_section_placements p join public.student_enrollments e on e.id=p.student_enrollment_id
  where p.section_id=s.id and p.status<>'corrected' and e.status<>'corrected'
   and a.assessment_date between p.starts_on and coalesce(p.ends_on,a.assessment_date)
   and a.assessment_date<@e.enrollment_range order by p.student_id,p.id
 loop
  if exists(select 1 from public.assessment_students x where x.assessment_id=a.id and x.student_id=q.student_id) then
   raise exception using errcode='22023',message='multiple eligible placements exist for one student'; end if;
  sid:=gen_random_uuid();
  insert into public.assessment_students(id,organization_id,school_id,campus_id,academic_year_id,academic_term_id,
   section_id,assessment_id,student_id,student_enrollment_id,student_section_placement_id,created_by)
  values(sid,a.organization_id,a.school_id,a.campus_id,a.academic_year_id,a.academic_term_id,a.section_id,a.id,
   q.student_id,q.student_enrollment_id,q.placement_id,actor);
  perform app_auth.write_assessment_change(cmd,a.organization_id,actor,'assessment.roster_snapshotted','assessment_student',sid,null,
   (select to_jsonb(x) from public.assessment_students x where x.id=sid),null,false);
  rid:=gen_random_uuid();
  insert into public.assessment_results(id,organization_id,school_id,campus_id,academic_year_id,academic_term_id,
   section_id,assessment_id,assessment_student_id,student_id,created_by,updated_by)
  values(rid,a.organization_id,a.school_id,a.campus_id,a.academic_year_id,a.academic_term_id,a.section_id,a.id,sid,q.student_id,actor,actor);
  perform app_auth.write_assessment_change(cmd,a.organization_id,actor,'assessment.result_initialized','assessment_result',rid,null,
   (select to_jsonb(x) from public.assessment_results x where x.id=rid),null,false); n:=n+1;
 end loop;
 j:=to_jsonb(a); perform app_auth.write_assessment_change(cmd,a.organization_id,actor,'assessment.created','assessment',a.id,null,j,
  jsonb_build_object('school_id',a.school_id,'campus_id',a.campus_id,'academic_year_id',a.academic_year_id,
   'academic_term_id',a.academic_term_id,'section_id',a.section_id,'subject_id',a.subject_id,'assessment_type',a.assessment_type,
   'assessment_date',a.assessment_date,'due_date',a.due_date,'maximum_score',a.maximum_score,'weight',a.weight,'roster_count',n));
 return a.id;
end $$;

create function public.update_assessment(id uuid,assessment_type public.assessment_type,title text,description text,due_date date,
 set_description boolean default false,set_due_date boolean default false) returns uuid
language plpgsql security definer set search_path='' as $$
declare actor uuid:=app_auth.assert_assessment_actor(); a public.assessments%rowtype; oldj jsonb; newj jsonb; cmd uuid:=gen_random_uuid(); begin
 select * into a from public.assessments x where x.id=update_assessment.id;
 if not found then raise exception using errcode='P0002',message='assessment not found'; end if;
 perform app_auth.lock_assessment_context(a); select * into a from public.assessments x where x.id=a.id for update;
 perform app_auth.assert_assessment_authority(a,false);
 if a.lifecycle_status<>'draft' then raise exception using errcode='22023',message='draft assessment is required'; end if;
 if set_due_date and update_assessment.due_date is not null and (update_assessment.due_date<a.assessment_date
  or update_assessment.due_date>(select least(s.end_date,y.end_date,t.end_date) from public.sections s
   join public.academic_years y on y.id=s.academic_year_id join public.academic_terms t on t.id=a.academic_term_id where s.id=a.section_id)) then
  raise exception using errcode='22023',message='due date is outside assessment parents'; end if;
 oldj:=to_jsonb(a); update public.assessments set assessment_type=update_assessment.assessment_type,
  title=btrim(update_assessment.title),description=case when set_description then case when update_assessment.description is null then null else btrim(update_assessment.description) end else a.description end,
  due_date=case when set_due_date then update_assessment.due_date else a.due_date end,updated_by=actor where assessments.id=a.id
  returning to_jsonb(assessments.*) into newj;
 perform app_auth.write_assessment_change(cmd,a.organization_id,actor,'assessment.updated','assessment',a.id,oldj,newj,
  jsonb_build_object('school_id',a.school_id,'campus_id',a.campus_id,'academic_year_id',a.academic_year_id,
   'academic_term_id',a.academic_term_id,'section_id',a.section_id,'subject_id',a.subject_id,
   'changed_fields',(select coalesce(jsonb_agg(k order by k),'[]') from (select z.key k from jsonb_object_keys(oldj||newj) z(key) where oldj->z.key is distinct from newj->z.key) q)));
 return a.id;
end $$;

create function public.record_assessment_results(id uuid,results public.assessment_result_input[]) returns uuid
language plpgsql security definer set search_path='' as $$
declare actor uuid:=app_auth.assert_assessment_actor(); a public.assessments%rowtype; m public.assessment_result_input;
 r public.assessment_results%rowtype; oldj jsonb; newj jsonb; cmd uuid:=gen_random_uuid(); begin
 select * into a from public.assessments x where x.id=record_assessment_results.id;
 if not found then raise exception using errcode='P0002',message='assessment not found'; end if;
 perform app_auth.lock_assessment_context(a); select * into a from public.assessments x where x.id=a.id for update;
 perform app_auth.assert_assessment_authority(a,false);
 if a.lifecycle_status<>'draft' then raise exception using errcode='22023',message='draft assessment is required'; end if;
 if results is null or cardinality(results)=0 or cardinality(results)>10000 or exists(select 1 from unnest(results) z where z is null) then
  raise exception using errcode='22023',message='non-empty bounded result array is required'; end if;
 if (select count(*) from unnest(results) z)<>(select count(distinct (z).student_id) from unnest(results) z) then
  raise exception using errcode='22023',message='duplicate result student'; end if;
 for m in select (z).* from unnest(results) z order by (z).student_id loop
  select * into r from public.assessment_results x where x.assessment_id=a.id and x.student_id=m.student_id for update;
  if not found then raise exception using errcode='22023',message='result student is outside roster'; end if;
  if m.score is not null and (m.score<0 or m.score>a.maximum_score) then raise exception using errcode='22023',message='score is outside range'; end if;
  if m.score is null and m.teacher_comment is not null then raise exception using errcode='22023',message='comment requires score'; end if;
  oldj:=to_jsonb(r); update public.assessment_results set score=m.score,
   teacher_comment=case when m.teacher_comment is null then null else btrim(m.teacher_comment) end,updated_by=actor
   where assessment_results.id=r.id returning to_jsonb(assessment_results.*) into newj;
  perform app_auth.write_assessment_change(cmd,a.organization_id,actor,'assessment.result_recorded','assessment_result',r.id,oldj,newj,
   jsonb_build_object('school_id',a.school_id,'campus_id',a.campus_id,'academic_year_id',a.academic_year_id,
    'academic_term_id',a.academic_term_id,'section_id',a.section_id,'assessment_id',a.id,'student_id',r.student_id,
    'score_recorded',m.score is not null,'comment_present',m.teacher_comment is not null));
 end loop; return a.id;
end $$;

create function public.publish_assessment(id uuid) returns uuid
language plpgsql security definer set search_path='' as $$
declare actor uuid:=app_auth.assert_assessment_actor(); a public.assessments%rowtype; oldj jsonb; newj jsonb; cmd uuid:=gen_random_uuid(); n integer; begin
 select * into a from public.assessments x where x.id=publish_assessment.id;
 if not found then raise exception using errcode='P0002',message='assessment not found'; end if;
 perform app_auth.lock_assessment_context(a); select * into a from public.assessments x where x.id=a.id for update;
 perform app_auth.assert_assessment_authority(a,false);
 if a.publication_state<>'unpublished' or a.lifecycle_status not in ('draft','finalized') then
  raise exception using errcode='22023',message='unpublished draft or finalized assessment is required'; end if;
 perform 1 from public.assessment_results r where r.assessment_id=a.id order by r.student_id,r.id for update;
 select count(*) into n from public.assessment_results r where r.assessment_id=a.id;
 if exists(select 1 from public.assessment_results r where r.assessment_id=a.id and r.score is null) then
  raise exception using errcode='22023',message='complete scores are required for publication'; end if;
 oldj:=to_jsonb(a); update public.assessments set publication_state='published',published_at=now(),published_by=actor,updated_by=actor
  where assessments.id=a.id returning to_jsonb(assessments.*) into newj;
 perform app_auth.write_assessment_change(cmd,a.organization_id,actor,'assessment.published','assessment',a.id,oldj,newj,
  jsonb_build_object('school_id',a.school_id,'campus_id',a.campus_id,'academic_year_id',a.academic_year_id,
   'academic_term_id',a.academic_term_id,'section_id',a.section_id,'subject_id',a.subject_id,
   'published_at',newj->>'published_at','result_count',n)); return a.id;
end $$;

create function public.finalize_assessment(id uuid) returns uuid
language plpgsql security definer set search_path='' as $$
declare actor uuid:=app_auth.assert_assessment_actor(); a public.assessments%rowtype; oldj jsonb; newj jsonb; cmd uuid:=gen_random_uuid(); n integer; begin
 select * into a from public.assessments x where x.id=finalize_assessment.id;
 if not found then raise exception using errcode='P0002',message='assessment not found'; end if;
 perform app_auth.lock_assessment_context(a); select * into a from public.assessments x where x.id=a.id for update;
 perform app_auth.assert_assessment_authority(a,false);
 if a.lifecycle_status<>'draft' then raise exception using errcode='22023',message='draft assessment is required'; end if;
 perform 1 from public.assessment_results r where r.assessment_id=a.id order by r.student_id,r.id for update;
 select count(*) into n from public.assessment_results r where r.assessment_id=a.id;
 if exists(select 1 from public.assessment_results r where r.assessment_id=a.id and r.score is null) then
  raise exception using errcode='22023',message='complete scores are required for finalization'; end if;
 oldj:=to_jsonb(a); update public.assessments set lifecycle_status='finalized',finalized_at=now(),finalized_by=actor,updated_by=actor
  where assessments.id=a.id returning to_jsonb(assessments.*) into newj;
 perform app_auth.write_assessment_change(cmd,a.organization_id,actor,'assessment.finalized','assessment',a.id,oldj,newj,
  jsonb_build_object('school_id',a.school_id,'campus_id',a.campus_id,'academic_year_id',a.academic_year_id,
   'academic_term_id',a.academic_term_id,'section_id',a.section_id,'subject_id',a.subject_id,
   'publication_state',a.publication_state,'finalized_at',newj->>'finalized_at','result_count',n)); return a.id;
end $$;

create function public.cancel_draft_assessment(id uuid,cancellation_reason text) returns uuid
language plpgsql security definer set search_path='' as $$
declare actor uuid:=app_auth.assert_assessment_actor(); a public.assessments%rowtype; oldj jsonb; newj jsonb; cmd uuid:=gen_random_uuid(); begin
 if length(btrim(coalesce(cancel_draft_assessment.cancellation_reason,''))) not between 1 and 500 then
  raise exception using errcode='22023',message='bounded cancellation reason is required'; end if;
 select * into a from public.assessments x where x.id=cancel_draft_assessment.id;
 if not found then raise exception using errcode='P0002',message='assessment not found'; end if;
 perform app_auth.lock_assessment_context(a); select * into a from public.assessments x where x.id=a.id for update;
 perform app_auth.assert_assessment_authority(a,false);
 if a.lifecycle_status<>'draft' or a.publication_state<>'unpublished' then
  raise exception using errcode='22023',message='unpublished draft assessment is required'; end if;
 perform 1 from public.assessment_students x where x.assessment_id=a.id order by x.student_id,x.id for update;
 perform 1 from public.assessment_results r where r.assessment_id=a.id order by r.student_id,r.id for update;
 oldj:=to_jsonb(a); update public.assessments set lifecycle_status='cancelled',
  cancellation_reason=btrim(cancel_draft_assessment.cancellation_reason),cancelled_at=now(),cancelled_by=actor,updated_by=actor
  where assessments.id=a.id returning to_jsonb(assessments.*) into newj;
 perform app_auth.write_assessment_change(cmd,a.organization_id,actor,'assessment.cancelled','assessment',a.id,oldj,newj,
  jsonb_build_object('school_id',a.school_id,'campus_id',a.campus_id,'academic_year_id',a.academic_year_id,
   'academic_term_id',a.academic_term_id,'section_id',a.section_id,'subject_id',a.subject_id,
   'cancellation_reason',btrim(cancel_draft_assessment.cancellation_reason),'cancelled_at',newj->>'cancelled_at')); return a.id;
end $$;

create function public.correct_assessment(id uuid,replacement_subject_id uuid,
 replacement_assessment_type public.assessment_type,replacement_title text,replacement_description text,
 replacement_assessment_date date,replacement_due_date date,replacement_maximum_score numeric,replacement_weight numeric,
 replacement_results public.assessment_result_input[],correction_reason text)
returns table(corrected_assessment_id uuid,replacement_assessment_id uuid)
language plpgsql security definer set search_path='' as $$
declare actor uuid:=app_auth.assert_assessment_actor(); a public.assessments%rowtype; s public.sections%rowtype;
 b public.assessments%rowtype; x public.assessment_students%rowtype; m public.assessment_result_input;
 oldr public.assessment_results%rowtype; sid uuid; rid uuid; cmd uuid:=gen_random_uuid(); oldj jsonb; newj jsonb; n integer:=0;
begin
 if length(btrim(coalesce(correct_assessment.correction_reason,''))) not between 1 and 500 then
  raise exception using errcode='22023',message='bounded correction reason is required'; end if;
 if replacement_results is null or cardinality(replacement_results)>10000
  or exists(select 1 from unnest(replacement_results) z where z is null) then
  raise exception using errcode='22023',message='bounded replacement result array is required'; end if;
 if (select count(*) from unnest(replacement_results) z)<>(select count(distinct (z).student_id) from unnest(replacement_results) z) then
  raise exception using errcode='22023',message='duplicate replacement result student'; end if;
 select * into a from public.assessments q where q.id=correct_assessment.id;
 if not found then raise exception using errcode='P0002',message='assessment not found'; end if;
 perform 1 from public.organizations where organizations.id=a.organization_id for update;
 perform 1 from public.schools where schools.id=a.school_id for update;
 perform 1 from public.campuses where campuses.id=a.campus_id for update;
 perform 1 from public.academic_years where academic_years.id=a.academic_year_id for update;
 perform 1 from public.academic_terms where academic_terms.id=a.academic_term_id for update;
 select * into s from public.sections q where q.id=a.section_id for update;
 perform 1 from public.subjects u where u.id in (a.subject_id,replacement_subject_id) order by u.id for update;
 perform 1 from public.students st join public.assessment_students ast on ast.student_id=st.id
  where ast.assessment_id=a.id order by st.id for update of st;
 perform 1 from public.student_enrollments e join public.assessment_students ast on ast.student_enrollment_id=e.id
  where ast.assessment_id=a.id order by e.student_id,e.id for update of e;
 perform 1 from public.student_section_placements p join public.assessment_students ast on ast.student_section_placement_id=p.id
  where ast.assessment_id=a.id order by p.student_id,p.id for update of p;
 select * into a from public.assessments q where q.id=a.id for update;
 perform 1 from public.assessments q where q.supersedes_assessment_id=a.id order by q.id for update;
 if a.lifecycle_status<>'finalized' then raise exception using errcode='22023',message='finalized assessment is required'; end if;
 if exists(select 1 from public.assessments q where q.supersedes_assessment_id=a.id) then
  raise exception using errcode='40001',message='assessment correction head changed; retry'; end if;
 perform app_auth.assert_assessment_authority(a,true);
 perform app_auth.assert_assessment_values(s,a.academic_term_id,replacement_subject_id,replacement_assessment_date,
  replacement_due_date,replacement_maximum_score,replacement_weight,false);
 perform 1 from public.assessment_students q where q.assessment_id=a.id order by q.student_id,q.id for update;
 perform 1 from public.assessment_results q where q.assessment_id=a.id order by q.student_id,q.id for update;
 if cardinality(replacement_results)<>(select count(*) from public.assessment_students q where q.assessment_id=a.id) then
  raise exception using errcode='22023',message='complete replacement results are required'; end if;
 for x in select * from public.assessment_students q where q.assessment_id=a.id order by q.student_id,q.id loop
  if not exists(select 1 from public.student_section_placements p join public.student_enrollments e on e.id=p.student_enrollment_id
   where p.id=x.student_section_placement_id and e.id=x.student_enrollment_id and p.student_id=x.student_id
    and replacement_assessment_date between p.starts_on and coalesce(p.ends_on,replacement_assessment_date)
    and replacement_assessment_date<@e.enrollment_range) then
   raise exception using errcode='22023',message='replacement date changes preserved roster eligibility'; end if;
  select (z).* into m from unnest(replacement_results) z where (z).student_id=x.student_id;
  if not found or m.score is null or m.score<0 or m.score>replacement_maximum_score then
   raise exception using errcode='22023',message='complete in-range replacement scores are required'; end if;
 end loop;
 oldj:=to_jsonb(a); update public.assessments set lifecycle_status='corrected',
  correction_reason=btrim(correct_assessment.correction_reason),updated_by=actor where assessments.id=a.id
  returning to_jsonb(assessments.*) into newj;
 insert into public.assessments(organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,
  subject_id,assessment_type,title,description,assessment_date,due_date,maximum_score,weight,lifecycle_status,
  publication_state,published_at,published_by,finalized_at,finalized_by,supersedes_assessment_id,created_by,updated_by)
 values(a.organization_id,a.school_id,a.campus_id,a.academic_year_id,a.academic_term_id,a.section_id,
  replacement_subject_id,replacement_assessment_type,btrim(replacement_title),
  case when replacement_description is null then null else btrim(replacement_description) end,
  replacement_assessment_date,replacement_due_date,replacement_maximum_score,replacement_weight,'finalized',
  a.publication_state,a.published_at,a.published_by,now(),actor,a.id,actor,actor) returning * into b;
 perform app_auth.write_assessment_change(cmd,a.organization_id,actor,'assessment.corrected','assessment',a.id,oldj,newj,
  jsonb_build_object('school_id',a.school_id,'campus_id',a.campus_id,'academic_year_id',a.academic_year_id,
   'academic_term_id',a.academic_term_id,'section_id',a.section_id,'subject_id',a.subject_id,
   'correction_reason',btrim(correct_assessment.correction_reason),'successor_id',b.id));
 for x in select * from public.assessment_students q where q.assessment_id=a.id order by q.student_id,q.id loop
  sid:=gen_random_uuid(); insert into public.assessment_students(id,organization_id,school_id,campus_id,academic_year_id,
   academic_term_id,section_id,assessment_id,student_id,student_enrollment_id,student_section_placement_id,created_by)
  values(sid,b.organization_id,b.school_id,b.campus_id,b.academic_year_id,b.academic_term_id,b.section_id,b.id,
   x.student_id,x.student_enrollment_id,x.student_section_placement_id,actor);
  perform app_auth.write_assessment_change(cmd,b.organization_id,actor,'assessment.roster_snapshotted','assessment_student',sid,null,
   (select to_jsonb(q) from public.assessment_students q where q.id=sid),null,false);
  select (z).* into m from unnest(replacement_results) z where (z).student_id=x.student_id;
  select * into oldr from public.assessment_results q where q.assessment_id=a.id and q.student_id=x.student_id;
  rid:=gen_random_uuid(); insert into public.assessment_results(id,organization_id,school_id,campus_id,academic_year_id,
   academic_term_id,section_id,assessment_id,assessment_student_id,student_id,score,teacher_comment,created_by,updated_by)
  values(rid,b.organization_id,b.school_id,b.campus_id,b.academic_year_id,b.academic_term_id,b.section_id,b.id,sid,x.student_id,
   m.score,case when m.teacher_comment is null then null else btrim(m.teacher_comment) end,actor,actor);
  perform app_auth.write_assessment_change(cmd,b.organization_id,actor,'assessment.result_corrected','assessment_result',rid,null,
   (select to_jsonb(q) from public.assessment_results q where q.id=rid),jsonb_build_object('school_id',b.school_id,
    'campus_id',b.campus_id,'academic_year_id',b.academic_year_id,'academic_term_id',b.academic_term_id,
    'section_id',b.section_id,'assessment_id',b.id,'student_id',x.student_id,'superseded_result_id',oldr.id,
    'score_recorded',true,'comment_present',m.teacher_comment is not null)); n:=n+1;
 end loop;
 perform app_auth.write_assessment_change(cmd,b.organization_id,actor,'assessment.finalized','assessment',b.id,null,to_jsonb(b),
  jsonb_build_object('school_id',b.school_id,'campus_id',b.campus_id,'academic_year_id',b.academic_year_id,
   'academic_term_id',b.academic_term_id,'section_id',b.section_id,'subject_id',b.subject_id,
   'publication_state',b.publication_state,'finalized_at',b.finalized_at,'result_count',n,'supersedes_assessment_id',a.id));
 return query select a.id,b.id;
end $$;

-- Extend section compatibility while retaining every v0.5-v0.7 predicate.
create or replace function public.update_section(id uuid,code text,name text,capacity integer,start_date date,end_date date,
 academic_term_id uuid,homeroom_room_id uuid,status public.record_status,set_academic_term_id boolean default false,
 set_homeroom_room_id boolean default false) returns uuid
language plpgsql security definer set search_path='' as $$ declare r uuid; begin
 r:=app_auth.update_section_v0_3_impl(id,code,name,capacity,start_date,end_date,academic_term_id,homeroom_room_id,status,set_academic_term_id,set_homeroom_room_id);
 if exists(select 1 from public.student_section_placements p where p.section_id=update_section.id and p.status='active')
  and (update_section.status<>'active' or update_section.capacity<(select count(*) from public.student_section_placements p where p.section_id=update_section.id and p.status='active')
   or exists(select 1 from public.student_section_placements p where p.section_id=update_section.id and p.status<>'corrected'
    and (p.starts_on<update_section.start_date or coalesce(p.ends_on,p.starts_on)>update_section.end_date))) then
  raise exception using errcode='22023',message='section change conflicts with placement history or capacity'; end if;
 if exists(select 1 from public.teaching_assignments t where t.section_id=update_section.id and t.status='active') and update_section.status<>'active' then
  raise exception using errcode='22023',message='section has active teaching assignments'; end if;
 if exists(select 1 from public.teaching_assignments t where t.section_id=update_section.id and t.status<>'corrected'
  and (t.starts_on<update_section.start_date or t.scheduled_ends_on>update_section.end_date)) then
  raise exception using errcode='22023',message='section dates exclude teaching assignment history'; end if;
 if exists(select 1 from public.attendance_sessions a where a.section_id=update_section.id and a.status<>'corrected'
  and (a.session_date<update_section.start_date or a.session_date>update_section.end_date or update_section.status<>'active')) then
  raise exception using errcode='22023',message='section change conflicts with attendance history'; end if;
 if exists(select 1 from public.assessments a where a.section_id=update_section.id
  and a.lifecycle_status not in ('corrected','cancelled')
  and (a.assessment_date<update_section.start_date or a.assessment_date>update_section.end_date
   or a.due_date is not null and (a.due_date<update_section.start_date or a.due_date>update_section.end_date)
   or set_academic_term_id and a.academic_term_id is distinct from update_section.academic_term_id)) then
  raise exception using errcode='22023',message='section change conflicts with assessment history'; end if;
 if update_section.status<>'active' and exists(select 1 from public.assessments a where a.section_id=update_section.id and a.lifecycle_status='draft') then
  raise exception using errcode='22023',message='section has draft assessments'; end if;
 return r;
end $$;

create or replace function public.archive_section(id uuid) returns uuid
language plpgsql security definer set search_path='' as $$ declare r uuid; begin
 r:=app_auth.archive_section_v0_3_impl(archive_section.id);
 if exists(select 1 from public.student_section_placements p where p.section_id=archive_section.id and p.status='active') then
  raise exception using errcode='22023',message='section has active placements'; end if;
 if exists(select 1 from public.teaching_assignments t where t.section_id=archive_section.id and t.status='active') then
  raise exception using errcode='22023',message='section has active teaching assignments'; end if;
 if exists(select 1 from public.attendance_sessions a where a.section_id=archive_section.id and a.status<>'corrected') then
  raise exception using errcode='22023',message='section has attendance history'; end if;
 if exists(select 1 from public.assessments a where a.section_id=archive_section.id and a.lifecycle_status not in ('corrected','cancelled')) then
  raise exception using errcode='22023',message='section has assessment history'; end if;
 return r;
end $$;

-- Preserve all earlier academic lifecycle hooks and add assessment compatibility.
create or replace function app_auth.write_academic_change(o uuid,actor uuid,action_name text,entity_name text,entity uuid,before_row jsonb,after_row jsonb) returns void
language plpgsql security definer set search_path='' as $$
declare cmd uuid:=gen_random_uuid(); row_data jsonb:=coalesce(after_row,before_row,'{}'); changed jsonb;
 school uuid:=(row_data->>'school_id')::uuid; campus uuid:=(row_data->>'campus_id')::uuid;
 academic_year uuid:=coalesce((row_data->>'academic_year_id')::uuid,case when entity_name='academic_year' then entity end);
 academic_term uuid:=coalesce((row_data->>'academic_term_id')::uuid,case when entity_name='academic_term' then entity end); event_payload jsonb;
begin
 if entity_name='academic_year' and action_name='academic_year.status_changed' and after_row->>'status' in ('closed','archived')
  and exists(select 1 from public.student_enrollments e where e.academic_year_id=entity and e.status='active') then
  raise exception using errcode='22023',message='academic year has active enrollments'; end if;
 if entity_name='academic_year' and action_name='academic_year.updated'
  and exists(select 1 from public.student_enrollments e where e.academic_year_id=entity and e.status<>'corrected'
   and (e.enrolled_on<(after_row->>'start_date')::date or e.scheduled_end_on>(after_row->>'end_date')::date)) then
  raise exception using errcode='22023',message='academic year dates exclude enrollment history'; end if;
 if entity_name='academic_year' and action_name='academic_year.status_changed' and after_row->>'status' in ('closed','archived')
  and exists(select 1 from public.teaching_assignments t where t.academic_year_id=entity and t.status='active') then
  raise exception using errcode='22023',message='academic year has active teaching assignments'; end if;
 if entity_name='academic_year' and action_name='academic_year.updated'
  and exists(select 1 from public.teaching_assignments t where t.academic_year_id=entity and t.status<>'corrected'
   and (t.starts_on<(after_row->>'start_date')::date or t.scheduled_ends_on>(after_row->>'end_date')::date)) then
  raise exception using errcode='22023',message='academic year dates exclude teaching assignment history'; end if;
 if entity_name='academic_year' and action_name='academic_year.status_changed' and after_row->>'status' in ('closed','archived')
  and exists(select 1 from public.attendance_sessions a where a.academic_year_id=entity and a.status in ('open','submitted')) then
  raise exception using errcode='22023',message='academic year has unfinished attendance sessions'; end if;
 if entity_name='academic_year' and action_name='academic_year.updated'
  and exists(select 1 from public.attendance_sessions a where a.academic_year_id=entity and a.status<>'corrected'
   and (a.session_date<(after_row->>'start_date')::date or a.session_date>(after_row->>'end_date')::date)) then
  raise exception using errcode='22023',message='academic year dates exclude attendance history'; end if;
 if entity_name='academic_year' and action_name='academic_year.status_changed' and after_row->>'status' in ('closed','archived')
  and exists(select 1 from public.assessments a where a.academic_year_id=entity and a.lifecycle_status='draft') then
  raise exception using errcode='22023',message='academic year has draft assessments'; end if;
 if entity_name='academic_year' and action_name='academic_year.updated'
  and exists(select 1 from public.assessments a where a.academic_year_id=entity and a.lifecycle_status not in ('corrected','cancelled')
   and (a.assessment_date<(after_row->>'start_date')::date or a.assessment_date>(after_row->>'end_date')::date
    or a.due_date is not null and (a.due_date<(after_row->>'start_date')::date or a.due_date>(after_row->>'end_date')::date))) then
  raise exception using errcode='22023',message='academic year dates exclude assessment history'; end if;
 if entity_name='academic_term' and action_name='academic_term.status_changed' and after_row->>'status' in ('closed','archived')
  and exists(select 1 from public.assessments a where a.academic_term_id=entity and a.lifecycle_status='draft') then
  raise exception using errcode='22023',message='academic term has draft assessments'; end if;
 if entity_name='academic_term' and action_name='academic_term.updated'
  and exists(select 1 from public.assessments a where a.academic_term_id=entity and a.lifecycle_status not in ('corrected','cancelled')
   and (a.assessment_date<(after_row->>'start_date')::date or a.assessment_date>(after_row->>'end_date')::date
    or a.due_date is not null and (a.due_date<(after_row->>'start_date')::date or a.due_date>(after_row->>'end_date')::date))) then
  raise exception using errcode='22023',message='academic term dates exclude assessment history'; end if;
 if entity_name='subject' and after_row->>'status' in ('inactive','archived')
  and exists(select 1 from public.assessments a where a.subject_id=entity and a.lifecycle_status='draft') then
  raise exception using errcode='22023',message='subject has draft assessments'; end if;
 if school is null and academic_year is not null then select y.school_id into school from public.academic_years y where y.id=academic_year; end if;
 select coalesce(jsonb_agg(k order by k),'[]') into changed from(select x.key k
  from jsonb_object_keys(coalesce(before_row,'{}')||coalesce(after_row,'{}')) x(key)
  where before_row->x.key is distinct from after_row->x.key) q;
 event_payload:=jsonb_strip_nulls(jsonb_build_object('command_id',cmd,'actor_user_id',actor,'organization_id',o,
  'entity_id',entity,'aggregate_id',entity,'school_id',school,'campus_id',campus,'academic_year_id',academic_year,
  'academic_term_id',academic_term,'changed_fields',changed,'before_status',before_row->>'status','after_status',after_row->>'status'));
 insert into public.audit_log(command_id,organization_id,actor_user_id,action,entity_type,entity_id,before_data,after_data)
  values(cmd,o,actor,action_name,entity_name,entity,before_row,after_row);
 insert into public.event_outbox(command_id,organization_id,event_type,aggregate_type,aggregate_id,payload)
  values(cmd,o,action_name,entity_name,entity,event_payload);
end $$;

alter table public.assessments owner to postgres;
alter table public.assessment_students owner to postgres;
alter table public.assessment_results owner to postgres;

do $$ declare p regprocedure; begin foreach p in array array[
 'public.create_assessment(uuid,uuid,uuid,public.assessment_type,text,text,date,date,numeric,numeric)'::regprocedure,
 'public.update_assessment(uuid,public.assessment_type,text,text,date,boolean,boolean)'::regprocedure,
 'public.record_assessment_results(uuid,public.assessment_result_input[])'::regprocedure,
 'public.publish_assessment(uuid)'::regprocedure,
 'public.finalize_assessment(uuid)'::regprocedure,
 'public.cancel_draft_assessment(uuid,text)'::regprocedure,
 'public.correct_assessment(uuid,uuid,public.assessment_type,text,text,date,date,numeric,numeric,public.assessment_result_input[],text)'::regprocedure,
 'public.update_section(uuid,text,text,integer,date,date,uuid,uuid,public.record_status,boolean,boolean)'::regprocedure,
 'public.archive_section(uuid)'::regprocedure]
 loop execute format('alter function %s owner to postgres',p); execute format('revoke all on function %s from public,anon',p);
  execute format('grant execute on function %s to authenticated,service_role',p); end loop;
end $$;

do $$ declare p regprocedure; begin foreach p in array array[
 'app_auth.enforce_assessment_immutability()'::regprocedure,
 'app_auth.enforce_assessment_result_integrity()'::regprocedure,
 'app_auth.has_assessment_assignment(uuid,public.teaching_assignment_role[])'::regprocedure,
 'app_auth.has_assessment_assignment_context(uuid,uuid,public.teaching_assignment_role[])'::regprocedure,
 'app_auth.can_read_assessment(uuid)'::regprocedure,
 'app_auth.can_read_assessment_student(uuid)'::regprocedure,
 'app_auth.can_read_assessment_result(uuid)'::regprocedure,
 'app_auth.assert_assessment_actor()'::regprocedure,
 'app_auth.assert_assessment_authority(public.assessments,boolean)'::regprocedure,
 'app_auth.lock_assessment_context(public.assessments)'::regprocedure,
 'app_auth.write_assessment_change(uuid,uuid,uuid,text,text,uuid,jsonb,jsonb,jsonb,boolean)'::regprocedure,
 'app_auth.assert_assessment_values(public.sections,uuid,uuid,date,date,numeric,numeric,boolean)'::regprocedure]
 loop execute format('alter function %s owner to postgres',p);
  execute format('revoke all on function %s from public,anon,authenticated,service_role',p); end loop;
end $$;
grant execute on function
 app_auth.has_assessment_assignment(uuid,public.teaching_assignment_role[]),
 app_auth.can_read_assessment(uuid),app_auth.can_read_assessment_student(uuid),app_auth.can_read_assessment_result(uuid)
to authenticated;

comment on table public.assessments is 'Section assessment lifecycle with independent publication and append-and-supersede finalized correction.';
comment on table public.assessment_students is 'Immutable assessment-date roster snapshot with enrollment and placement provenance.';
comment on table public.assessment_results is 'One score and optional teacher comment per snapshotted assessment student.';
comment on function public.publish_assessment(uuid) is 'Publishes a complete draft or finalized assessment without changing academic content.';
comment on function public.cancel_draft_assessment(uuid,text) is 'Terminal cancellation of an unpublished draft preserving roster and result history.';
comment on function public.correct_assessment(uuid,uuid,public.assessment_type,text,text,date,date,numeric,numeric,public.assessment_result_input[],text)
 is 'Whole-assessment append-and-supersede correction using the original immutable roster.';

commit;
