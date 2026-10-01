begin;

create type public.progression_disposition as enum ('promotion','retention','graduation','transfer','withdrawal');
create type public.progression_decision_status as enum ('pending','approved','executed','cancelled','corrected');
create type public.progression_eligibility_state as enum ('eligible','not_eligible','incomplete','stale');
create type public.progression_batch_status as enum ('draft','approved','completed');
create type public.progression_batch_outcome as enum ('completed_successfully','completed_with_exceptions');
create type public.progression_batch_decision_input as (
 student_id uuid, source_enrollment_id uuid, disposition public.progression_disposition,
 source_end_on date, destination_school_id uuid, destination_campus_id uuid,
 destination_academic_year_id uuid, destination_grade_level_id uuid,
 destination_section_id uuid, destination_enrolled_on date, eligibility_override_reason text
);
create type public.progression_execution_result as (
 decision_id uuid, source_enrollment_id uuid, source_placement_id uuid,
 destination_enrollment_id uuid, destination_placement_id uuid
);
create type public.progression_batch_create_result as (batch_id uuid, decision_ids uuid[]);
create type public.progression_batch_item_result as (
 decision_id uuid, executed boolean, retryable boolean, error_code text, error_category text
);

insert into public.permissions(code,module,description) values
 ('progression.view','progression','View student progression decisions in assigned scope'),
 ('progression.manage','progression','Create student progression decisions and batches'),
 ('progression.approve','progression','Approve student progression decisions and batches'),
 ('progression.execute','progression','Execute approved student progression decisions'),
 ('progression.correct','progression','Create and execute progression corrections'),
 ('progression.cancel','progression','Cancel pending or approved progression decisions');

create table public.progression_batches(
 id uuid primary key default gen_random_uuid(), organization_id uuid not null,
 source_school_id uuid not null, source_academic_year_id uuid not null,
 status public.progression_batch_status not null default 'draft',
 approved_at timestamptz, approved_by uuid references auth.users(id) on delete restrict,
 approval_reason text check(approval_reason is null or length(btrim(approval_reason)) between 1 and 500),
 completed_at timestamptz, completed_by_command_id uuid,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 created_by uuid not null references auth.users(id) on delete restrict,
 updated_by uuid not null references auth.users(id) on delete restrict,
 foreign key(organization_id,source_school_id) references public.schools(organization_id,id) on delete restrict,
 foreign key(organization_id,source_school_id,source_academic_year_id) references public.academic_years(organization_id,school_id,id) on delete restrict,
 unique(organization_id,id), unique(organization_id,source_school_id,source_academic_year_id,id),
 check((status='draft' and approved_at is null and approved_by is null and approval_reason is null and completed_at is null)
    or(status='approved' and approved_at is not null and approved_by is not null and approval_reason is not null and completed_at is null)
    or(status='completed' and completed_at is not null and completed_by_command_id is not null))
);

create table public.progression_decisions(
 id uuid primary key default gen_random_uuid(), organization_id uuid not null, student_id uuid not null,
 source_school_id uuid not null, source_campus_id uuid, source_academic_year_id uuid not null,
 source_grade_level_id uuid not null, source_enrollment_id uuid not null, source_placement_id uuid,
 disposition public.progression_disposition not null, source_end_on date not null,
 destination_school_id uuid, destination_campus_id uuid, destination_academic_year_id uuid,
 destination_grade_level_id uuid, destination_section_id uuid, destination_enrolled_on date,
 lineage_id uuid not null, version integer not null check(version>=1), supersedes_decision_id uuid,
 correction_reason text check(correction_reason is null or length(btrim(correction_reason)) between 1 and 500),
 status public.progression_decision_status not null default 'pending',
 current_eligibility_evaluation_id uuid,
 eligibility_override_reason text check(eligibility_override_reason is null or length(btrim(eligibility_override_reason)) between 1 and 500),
 approved_at timestamptz, approved_by uuid references auth.users(id) on delete restrict,
 approval_reason text check(approval_reason is null or length(btrim(approval_reason)) between 1 and 500),
 executed_at timestamptz, executed_by uuid references auth.users(id) on delete restrict,
 cancelled_at timestamptz, cancelled_by uuid references auth.users(id) on delete restrict,
 cancellation_reason text check(cancellation_reason is null or length(btrim(cancellation_reason)) between 1 and 500),
 corrected_at timestamptz, corrected_by uuid references auth.users(id) on delete restrict,
 result_source_enrollment_id uuid, result_source_placement_id uuid,
 destination_enrollment_id uuid, destination_placement_id uuid,
 batch_id uuid,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 created_by uuid not null references auth.users(id) on delete restrict,
 updated_by uuid not null references auth.users(id) on delete restrict,
 foreign key(organization_id,student_id) references public.students(organization_id,id) on delete restrict,
 foreign key(organization_id,source_school_id,source_academic_year_id,student_id,source_enrollment_id)
  references public.student_enrollments(organization_id,school_id,academic_year_id,student_id,id) on delete restrict,
 foreign key(organization_id,source_placement_id) references public.student_section_placements(organization_id,id) on delete restrict,
 foreign key(organization_id,source_school_id,source_grade_level_id) references public.grade_levels(organization_id,school_id,id) on delete restrict,
 foreign key(organization_id,destination_school_id) references public.schools(organization_id,id) on delete restrict,
 foreign key(organization_id,destination_campus_id) references public.campuses(organization_id,id) on delete restrict,
 foreign key(destination_school_id,destination_campus_id) references public.campuses(school_id,id) on delete restrict,
 foreign key(organization_id,destination_school_id,destination_academic_year_id) references public.academic_years(organization_id,school_id,id) on delete restrict,
 foreign key(organization_id,destination_school_id,destination_grade_level_id) references public.grade_levels(organization_id,school_id,id) on delete restrict,
 foreign key(organization_id,destination_school_id,destination_campus_id,destination_academic_year_id,destination_section_id)
  references public.sections(organization_id,school_id,campus_id,academic_year_id,id) on delete restrict,
 foreign key(organization_id,supersedes_decision_id) references public.progression_decisions(organization_id,id) on delete restrict,
 foreign key(organization_id,source_school_id,source_academic_year_id,batch_id)
  references public.progression_batches(organization_id,source_school_id,source_academic_year_id,id) on delete restrict,
 foreign key(organization_id,result_source_enrollment_id) references public.student_enrollments(organization_id,id) on delete restrict,
 foreign key(organization_id,result_source_placement_id) references public.student_section_placements(organization_id,id) on delete restrict,
 foreign key(organization_id,destination_enrollment_id) references public.student_enrollments(organization_id,id) on delete restrict,
 foreign key(organization_id,destination_placement_id) references public.student_section_placements(organization_id,id) on delete restrict,
 unique(organization_id,id), unique(organization_id,lineage_id,version),
 unique(organization_id,source_school_id,source_academic_year_id,student_id,id),
 check((version=1 and lineage_id=id and supersedes_decision_id is null and correction_reason is null)
    or(version>1 and supersedes_decision_id is not null and correction_reason is not null)),
 check((disposition in('promotion','retention','transfer') and destination_school_id is not null and destination_campus_id is not null
       and destination_academic_year_id is not null and destination_grade_level_id is not null and destination_enrolled_on is not null)
    or(disposition in('graduation','withdrawal') and destination_school_id is null and destination_campus_id is null
       and destination_academic_year_id is null and destination_grade_level_id is null and destination_section_id is null and destination_enrolled_on is null)),
 check(destination_enrolled_on is null or destination_enrolled_on>source_end_on),
 check((status='pending' and approved_at is null and executed_at is null and cancelled_at is null and corrected_at is null)
    or(status='approved' and approved_at is not null and approved_by is not null and approval_reason is not null and executed_at is null and cancelled_at is null and corrected_at is null)
    or(status='executed' and approved_at is not null and executed_at is not null and executed_by is not null and cancelled_at is null and corrected_at is null and result_source_enrollment_id is not null)
    or(status='cancelled' and executed_at is null and cancelled_at is not null and cancelled_by is not null and cancellation_reason is not null and corrected_at is null)
    or(status='corrected' and executed_at is not null and corrected_at is not null and corrected_by is not null and cancelled_at is null))
);
create unique index progression_one_root_per_source on public.progression_decisions(source_enrollment_id) where version=1 and status<>'cancelled';
create unique index progression_one_successor on public.progression_decisions(supersedes_decision_id) where supersedes_decision_id is not null;
create unique index progression_one_actionable_per_source on public.progression_decisions(source_enrollment_id) where status in('pending','approved');
create index progression_decisions_scope_idx on public.progression_decisions(organization_id,source_school_id,source_campus_id,source_academic_year_id,status,id);
create index progression_decisions_student_idx on public.progression_decisions(organization_id,student_id,created_at,id);
create index progression_decisions_destination_idx on public.progression_decisions(organization_id,destination_school_id,destination_campus_id,destination_academic_year_id,status,id);
create index progression_decisions_batch_idx on public.progression_decisions(batch_id,status,id) where batch_id is not null;

create table public.progression_eligibility_evaluations(
 id uuid primary key default gen_random_uuid(), organization_id uuid not null,
 progression_decision_id uuid not null, student_id uuid not null, sequence integer not null check(sequence>=1),
 state public.progression_eligibility_state not null, source_fingerprint bytea not null check(octet_length(source_fingerprint)=32),
 evaluated_at timestamptz not null default now(), evaluated_by uuid not null references auth.users(id) on delete restrict,
 foreign key(organization_id,progression_decision_id) references public.progression_decisions(organization_id,id) on delete restrict,
 foreign key(organization_id,student_id) references public.students(organization_id,id) on delete restrict,
 unique(organization_id,id), unique(progression_decision_id,sequence),
 unique(organization_id,progression_decision_id,student_id,id)
);
alter table public.progression_decisions add constraint progression_current_evaluation_fk
 foreign key(organization_id,id,student_id,current_eligibility_evaluation_id)
 references public.progression_eligibility_evaluations(organization_id,progression_decision_id,student_id,id) on delete restrict;

create table public.progression_decision_evidence(
 id uuid primary key default gen_random_uuid(), organization_id uuid not null,
 progression_decision_id uuid not null, eligibility_evaluation_id uuid not null,
 student_id uuid not null, academic_year_id uuid not null, academic_term_id uuid not null,
 report_card_id uuid not null, report_card_lineage_id uuid not null, report_card_version integer not null,
 source_fingerprint bytea not null check(octet_length(source_fingerprint)=32),
 created_at timestamptz not null default now(), created_by uuid not null references auth.users(id) on delete restrict,
 foreign key(organization_id,progression_decision_id,student_id,eligibility_evaluation_id)
  references public.progression_eligibility_evaluations(organization_id,progression_decision_id,student_id,id) on delete restrict,
 foreign key(organization_id,report_card_id) references public.report_cards(organization_id,id) on delete restrict,
 unique(organization_id,id), unique(eligibility_evaluation_id,academic_term_id), unique(eligibility_evaluation_id,report_card_id)
);
create index progression_evaluations_decision_idx on public.progression_eligibility_evaluations(organization_id,progression_decision_id,sequence,id);
create index progression_evidence_report_idx on public.progression_decision_evidence(organization_id,report_card_id,student_id,id);

create table public.progression_batch_items(
 id uuid primary key default gen_random_uuid(), organization_id uuid not null, batch_id uuid not null,
 decision_id uuid not null, student_id uuid not null, source_enrollment_id uuid not null,
 last_attempted_at timestamptz, attempt_count integer not null default 0 check(attempt_count>=0),
 last_error_code text, last_error_category text check(last_error_category is null or length(last_error_category) between 1 and 80),
 created_at timestamptz not null default now(), created_by uuid not null references auth.users(id) on delete restrict,
 foreign key(organization_id,batch_id) references public.progression_batches(organization_id,id) on delete restrict,
 foreign key(organization_id,decision_id) references public.progression_decisions(organization_id,id) on delete restrict,
 foreign key(organization_id,student_id) references public.students(organization_id,id) on delete restrict,
 foreign key(organization_id,source_enrollment_id) references public.student_enrollments(organization_id,id) on delete restrict,
 unique(organization_id,id), unique(batch_id,decision_id), unique(batch_id,source_enrollment_id), unique(batch_id,student_id)
);
create index progression_batch_items_progress_idx on public.progression_batch_items(organization_id,batch_id,decision_id,id);

create table app_auth.progression_command_receipts(
 organization_id uuid not null, actor_user_id uuid not null, command_name text not null,
 request_id uuid not null, argument_hash bytea not null check(octet_length(argument_hash)=32),
 command_id uuid not null, completed boolean not null default false,
 result_id uuid, result_secondary_id uuid, result_ids uuid[],
 created_at timestamptz not null default now(), completed_at timestamptz,
 primary key(organization_id,actor_user_id,command_name,request_id)
);

create trigger progression_batches_updated_at before update on public.progression_batches for each row execute function public.set_updated_at();
create trigger progression_decisions_updated_at before update on public.progression_decisions for each row execute function public.set_updated_at();

alter table public.progression_batches enable row level security; alter table public.progression_batches force row level security;
alter table public.progression_decisions enable row level security; alter table public.progression_decisions force row level security;
alter table public.progression_eligibility_evaluations enable row level security; alter table public.progression_eligibility_evaluations force row level security;
alter table public.progression_decision_evidence enable row level security; alter table public.progression_decision_evidence force row level security;
alter table public.progression_batch_items enable row level security; alter table public.progression_batch_items force row level security;

create function app_auth.can_view_progression(o uuid,student uuid,source_school uuid,source_campus uuid,destination_school uuid,destination_campus uuid,status public.progression_decision_status) returns boolean
language sql stable security definer set search_path='' as $$
 select app_auth.has_permission(o,'progression.view',source_school,source_campus)
   or app_auth.has_permission(o,'progression.manage',source_school,source_campus);
$$;
create policy progression_decisions_select on public.progression_decisions for select to authenticated using(
 app_auth.can_view_progression(organization_id,student_id,source_school_id,source_campus_id,destination_school_id,destination_campus_id,status));
create policy progression_batches_select on public.progression_batches for select to authenticated using(
 app_auth.has_permission(organization_id,'progression.view',source_school_id,null) or app_auth.has_permission(organization_id,'progression.manage',source_school_id,null));
create policy progression_evaluations_select on public.progression_eligibility_evaluations for select to authenticated using(
 exists(select 1 from public.progression_decisions d where d.id=progression_decision_id and
  (app_auth.has_permission(d.organization_id,'progression.view',d.source_school_id,d.source_campus_id) or app_auth.has_permission(d.organization_id,'progression.manage',d.source_school_id,d.source_campus_id))));
create policy progression_evidence_select on public.progression_decision_evidence for select to authenticated using(
 exists(select 1 from public.progression_decisions d where d.id=progression_decision_id and
  (app_auth.has_permission(d.organization_id,'progression.view',d.source_school_id,d.source_campus_id) or app_auth.has_permission(d.organization_id,'progression.manage',d.source_school_id,d.source_campus_id))));
create policy progression_batch_items_select on public.progression_batch_items for select to authenticated using(
 exists(select 1 from public.progression_batches b where b.id=batch_id and
  (app_auth.has_permission(b.organization_id,'progression.view',b.source_school_id,null) or app_auth.has_permission(b.organization_id,'progression.manage',b.source_school_id,null))));

revoke all on public.progression_batches,public.progression_decisions,public.progression_eligibility_evaluations,public.progression_decision_evidence,public.progression_batch_items from public,anon,authenticated;
grant select on public.progression_batches,public.progression_decisions,public.progression_eligibility_evaluations,public.progression_decision_evidence,public.progression_batch_items to authenticated;

create view public.progression_batch_progress with (security_invoker=true) as
select b.id,b.organization_id,b.source_school_id,b.source_academic_year_id,b.status,
 count(i.id)::integer total_count,
 count(*) filter(where d.status='pending')::integer pending_count,
 count(*) filter(where d.status='approved')::integer approved_count,
 count(*) filter(where d.status='executed')::integer executed_count,
 count(*) filter(where d.status='cancelled')::integer cancelled_count,
 count(*) filter(where i.last_error_code is not null and d.status='approved')::integer retryable_failed_last_attempt_count,
 case when b.status='completed' and count(*) filter(where d.status='executed')=count(i.id) then 'completed_successfully'::public.progression_batch_outcome
      when b.status='completed' and count(*) filter(where d.status='cancelled')>0 then 'completed_with_exceptions'::public.progression_batch_outcome end outcome
from public.progression_batches b join public.progression_batch_items i on i.batch_id=b.id
join public.progression_decisions d on d.id=i.decision_id group by b.id;
grant select on public.progression_batch_progress to authenticated;

create view public.student_progression_outcomes with (security_barrier=true) as
select d.id,d.organization_id,d.student_id,d.disposition,d.source_school_id,d.source_academic_year_id,d.source_grade_level_id,
 d.source_end_on,d.destination_school_id,d.destination_campus_id,d.destination_academic_year_id,d.destination_grade_level_id,d.destination_enrolled_on
from public.progression_decisions d where d.status='executed' and (app_auth.is_student_self(d.student_id) or app_auth.is_linked_guardian(d.student_id));
grant select on public.student_progression_outcomes to authenticated;

create function app_auth.progression_actor() returns uuid language plpgsql stable security definer set search_path='' as $$
declare a uuid:=auth.uid(); begin if a is null then raise exception using errcode='42501',message='authenticated actor required'; end if; return a; end $$;

create function app_auth.assert_progression_permission(o uuid,permission text,s uuid,c uuid default null) returns void
language plpgsql stable security definer set search_path='' as $$ begin
 if not app_auth.has_permission(o,permission,s,c) then raise exception using errcode='42501',message=permission||' permission is required'; end if;
end $$;

create function app_auth.claim_progression_receipt(o uuid,a uuid,n text,r uuid,h bytea)
returns table(replayed boolean,command_id uuid,result_id uuid,result_secondary_id uuid,result_ids uuid[])
language plpgsql security definer set search_path='' as $$
declare x app_auth.progression_command_receipts; c uuid:=gen_random_uuid(); begin
 insert into app_auth.progression_command_receipts(organization_id,actor_user_id,command_name,request_id,argument_hash,command_id)
 values(o,a,n,r,h,c) on conflict do nothing;
 if found then return query select false,c,null::uuid,null::uuid,null::uuid[]; return; end if;
 select * into x from app_auth.progression_command_receipts where organization_id=o and actor_user_id=a and command_name=n and request_id=r for update;
 if x.argument_hash<>h then raise exception using errcode='22023',message='request_id was reused with different arguments'; end if;
 if not x.completed then raise exception using errcode='40001',message='matching command is in progress'; end if;
 return query select true,x.command_id,x.result_id,x.result_secondary_id,x.result_ids;
end $$;

create function app_auth.complete_progression_receipt(o uuid,a uuid,n text,r uuid,r1 uuid default null,r2 uuid default null,rs uuid[] default null) returns void
language sql security definer set search_path='' as $$
 update app_auth.progression_command_receipts set completed=true,result_id=r1,result_secondary_id=r2,result_ids=rs,completed_at=now()
 where organization_id=o and actor_user_id=a and command_name=n and request_id=r;
$$;

create function app_auth.write_progression_change(cmd uuid,o uuid,a uuid,event_name text,entity_name text,entity uuid,before_row jsonb,after_row jsonb,payload jsonb) returns void
language plpgsql security definer set search_path='' as $$ begin
 insert into public.audit_log(command_id,organization_id,actor_user_id,action,entity_type,entity_id,before_data,after_data)
 values(cmd,o,a,event_name,entity_name,entity,before_row,after_row);
 insert into public.event_outbox(command_id,organization_id,event_type,aggregate_type,aggregate_id,payload)
 values(cmd,o,event_name,entity_name,entity,coalesce(payload,'{}')||jsonb_build_object('command_id',cmd,'organization_id',o,'aggregate_id',entity));
end $$;

create function app_auth.progression_source_fingerprint(did uuid) returns bytea
language sql stable security definer set search_path='' as $$
 select extensions.digest(coalesce(string_agg(token,'|' order by token),'missing'),'sha256') from(
  select 'term:'||t.id::text||':'||t.status::text token from public.progression_decisions d
   join public.academic_terms t on t.academic_year_id=d.source_academic_year_id and t.status in('active','closed') where d.id=did
  union all
  select 'card:'||rc.academic_term_id::text||':'||rc.id::text||':'||rc.status::text||':'||encode(rc.source_fingerprint,'hex')
   from public.progression_decisions d join public.report_cards rc on rc.organization_id=d.organization_id
    and rc.academic_year_id=d.source_academic_year_id and rc.student_id=d.student_id and rc.status in('finalized','published') where d.id=did
 ) q;
$$;

create function app_auth.refresh_progression_evidence(did uuid,a uuid) returns uuid
language plpgsql security definer set search_path='' as $$
declare d public.progression_decisions; eid uuid:=gen_random_uuid(); seq integer; term_count integer; card_count integer; failed boolean; fp bytea; st public.progression_eligibility_state; begin
 select * into d from public.progression_decisions where id=did for update;
 if d.id is null then raise exception using errcode='P0002',message='progression decision not found'; end if;
 if d.status<>'pending' then raise exception using errcode='22023',message='pending decision required'; end if;
 select coalesce(max(sequence),0)+1 into seq from public.progression_eligibility_evaluations where progression_decision_id=d.id;
 select count(*) into term_count from public.academic_terms where academic_year_id=d.source_academic_year_id and status in('active','closed');
 with live as(
  select rc.*,count(*) over(partition by rc.academic_term_id) n
  from public.report_cards rc where rc.organization_id=d.organization_id and rc.academic_year_id=d.source_academic_year_id
   and rc.student_id=d.student_id and rc.status in('finalized','published'))
 select count(*),coalesce(bool_or(exists(select 1 from public.report_card_grade_snapshots g where g.report_card_id=live.id and g.result_state='fail')),false),
  app_auth.progression_source_fingerprint(d.id)
 into card_count,failed,fp from live where n=1;
 if term_count=0 or card_count<>term_count then st:='incomplete'; elsif failed then st:='not_eligible'; else st:='eligible'; end if;
 insert into public.progression_eligibility_evaluations(id,organization_id,progression_decision_id,student_id,sequence,state,source_fingerprint,evaluated_by)
 values(eid,d.organization_id,d.id,d.student_id,seq,st,fp,a);
 insert into public.progression_decision_evidence(organization_id,progression_decision_id,eligibility_evaluation_id,student_id,academic_year_id,academic_term_id,report_card_id,report_card_lineage_id,report_card_version,source_fingerprint,created_by)
 select d.organization_id,d.id,eid,d.student_id,d.source_academic_year_id,x.academic_term_id,x.id,x.lineage_id,x.version,x.source_fingerprint,a
 from (select rc.*,count(*) over(partition by rc.academic_term_id) n from public.report_cards rc
  where rc.organization_id=d.organization_id and rc.academic_year_id=d.source_academic_year_id and rc.student_id=d.student_id and rc.status in('finalized','published')) x where x.n=1;
 update public.progression_decisions set current_eligibility_evaluation_id=eid,updated_by=a where id=d.id;
 return eid;
end $$;

create function app_auth.progression_evidence_is_current(did uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select e.source_fingerprint=app_auth.progression_source_fingerprint(d.id)
 from public.progression_decisions d join public.progression_eligibility_evaluations e on e.id=d.current_eligibility_evaluation_id where d.id=did;
$$;

create function app_auth.lock_progression_decision_context(did uuid) returns void
language plpgsql security definer set search_path='' as $$
declare d public.progression_decisions; source_section uuid; begin
	select * into d from public.progression_decisions where id=did;
	if d.id is null then raise exception using errcode='P0002',message='decision not found'; end if;
	select section_id into source_section from public.student_section_placements where id=d.source_placement_id;
	perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('school-platform:progression:'||d.organization_id::text,0));
	perform 1 from public.organizations where id=d.organization_id for update;
	perform 1 from public.schools where id in(d.source_school_id,d.destination_school_id) order by id for update;
	perform 1 from public.campuses where id in(d.source_campus_id,d.destination_campus_id) order by id for update;
	perform 1 from public.academic_years where id in(d.source_academic_year_id,d.destination_academic_year_id) order by school_id,id for update;
	perform 1 from public.grade_levels where id in(d.source_grade_level_id,d.destination_grade_level_id) order by school_id,sequence,id for update;
	perform 1 from public.sections where id in(source_section,d.destination_section_id) order by school_id,id for update;
	perform 1 from public.students where id=d.student_id for update;
 perform 1 from public.student_enrollments where id=d.source_enrollment_id for update;
 perform 1 from public.student_section_placements where id=d.source_placement_id for update;
 perform 1 from public.progression_decisions where id=d.id for update;
end $$;

create function app_auth.assert_progression_context(d public.progression_decisions,for_execution boolean default false) returns void
language plpgsql security definer set search_path='' as $$
declare sy public.academic_years; dy public.academic_years; sg public.grade_levels; dg public.grade_levels; sec public.sections; begin
 select * into sy from public.academic_years where id=d.source_academic_year_id;
 select * into sg from public.grade_levels where id=d.source_grade_level_id;
 if d.source_end_on not between (select enrolled_on from public.student_enrollments where id=d.source_enrollment_id) and (select scheduled_end_on from public.student_enrollments where id=d.source_enrollment_id) then raise exception using errcode='22023',message='source end date is outside enrollment'; end if;
 if d.source_placement_id is not null and d.source_end_on<(select starts_on from public.student_section_placements where id=d.source_placement_id) then raise exception using errcode='22023',message='source end date precedes placement'; end if;
 if for_execution and (sy.status<>'active' or sg.status<>'active') then raise exception using errcode='22023',message='active source year and grade required'; end if;
 if d.disposition in('promotion','retention','transfer') then
  select * into dy from public.academic_years where id=d.destination_academic_year_id;
  select * into dg from public.grade_levels where id=d.destination_grade_level_id;
  if dy.start_date<=sy.end_date or d.destination_enrolled_on not between dy.start_date and dy.end_date then raise exception using errcode='22023',message='invalid destination year or date'; end if;
  if for_execution and (dy.status<>'active' or dg.status<>'active') then raise exception using errcode='22023',message='active destination year and grade required'; end if;
  if d.disposition in('promotion','retention') and d.destination_school_id<>d.source_school_id then raise exception using errcode='22023',message='cross-school outcome must be transfer'; end if;
  if d.destination_school_id=d.source_school_id and d.disposition='promotion' and dg.sequence<=sg.sequence then raise exception using errcode='22023',message='promotion destination grade must be higher'; end if;
  if d.destination_school_id=d.source_school_id and d.disposition='retention' and dg.id<>sg.id then raise exception using errcode='22023',message='retention must keep the same grade'; end if;
  if d.destination_section_id is not null then select * into sec from public.sections where id=d.destination_section_id;
   if sec.status<>'active' or sec.grade_level_id<>d.destination_grade_level_id or d.destination_enrolled_on not between sec.start_date and sec.end_date then raise exception using errcode='22023',message='destination section is incompatible'; end if;
  end if;
 end if;
end $$;

create function app_auth.finish_progression_batch(bid uuid,cmd uuid,a uuid) returns void
language plpgsql security definer set search_path='' as $$
declare b public.progression_batches; executed_count integer; cancelled_count integer; total_count integer; begin
 if bid is null then return; end if;
 if not exists(select 1 from public.progression_decisions where batch_id=bid and status not in('executed','cancelled')) then
  select * into b from public.progression_batches where id=bid for update;
  if b.status<>'completed' then
   select count(*),count(*) filter(where status='executed'),count(*) filter(where status='cancelled') into total_count,executed_count,cancelled_count from public.progression_decisions where batch_id=bid;
   update public.progression_batches set status='completed',completed_at=now(),completed_by_command_id=cmd,updated_by=a where id=bid;
   perform app_auth.write_progression_change(cmd,b.organization_id,a,'student.progression_batch_completed','progression_batch',b.id,to_jsonb(b),
    jsonb_build_object('batch_id',b.id,'status','completed'),jsonb_build_object('batch_id',b.id,'outcome',case when cancelled_count=0 then 'completed_successfully' else 'completed_with_exceptions' end,'total_count',total_count,'executed_count',executed_count,'cancelled_count',cancelled_count));
  end if;
 end if;
end $$;

-- Enrollment-owned orchestration service. Only progression execution helpers may call it.
create function app_auth.execute_progression_enrollment_effect(did uuid,a uuid,cmd uuid)
returns public.progression_execution_result language plpgsql security definer set search_path='' as $$
declare d public.progression_decisions; old public.progression_decisions; e public.student_enrollments; p public.student_section_placements; de uuid; dp uuid; source_e uuid; source_p uuid; y public.academic_years; sec public.sections; begin
 select * into d from public.progression_decisions where id=did for update;
 source_e:=d.source_enrollment_id; source_p:=d.source_placement_id;
 if d.supersedes_decision_id is not null then
  select * into old from public.progression_decisions where id=d.supersedes_decision_id for update;
  if exists(select 1 from public.student_enrollments x where x.student_id=d.student_id and x.status<>'corrected' and x.id not in(old.result_source_enrollment_id,old.destination_enrollment_id) and x.enrolled_on>=(select enrolled_on from public.student_enrollments where id=old.result_source_enrollment_id)) then
   raise exception using errcode='22023',message='later enrollment history prevents automatic correction'; end if;
  update public.student_section_placements set status='corrected',correction_reason=d.correction_reason,updated_by=a where id in(old.result_source_placement_id,old.destination_placement_id) and status<>'corrected';
  update public.student_enrollments set status='corrected',correction_reason=d.correction_reason,updated_by=a where id in(old.result_source_enrollment_id,old.destination_enrollment_id) and status<>'corrected';
  select * into e from public.student_enrollments where id=old.result_source_enrollment_id;
  insert into public.student_enrollments(organization_id,school_id,academic_year_id,student_id,grade_level_id,enrolled_on,scheduled_end_on,enrollment_range,status,supersedes_enrollment_id,created_by,updated_by)
  values(e.organization_id,e.school_id,e.academic_year_id,e.student_id,e.grade_level_id,e.enrolled_on,e.scheduled_end_on,daterange(e.enrolled_on,e.scheduled_end_on,'[]'),'active',e.id,a,a) returning id into source_e;
  source_p:=null;
 end if;
 select * into e from public.student_enrollments where id=source_e for update;
 if e.status<>'active' then raise exception using errcode='22023',message='active source enrollment required'; end if;
 select * into p from public.student_section_placements where student_enrollment_id=e.id and status='active' for update;
 if p.id is not null then
 update public.student_section_placements set status=case when d.disposition='withdrawal' then 'withdrawn'::public.section_placement_status else 'completed'::public.section_placement_status end,
   ends_on=d.source_end_on,end_reason='progression decision '||d.id::text,updated_by=a where id=p.id; source_p:=p.id;
  perform app_auth.write_progression_change(cmd,d.organization_id,a,case when d.disposition='withdrawal' then 'student.section_withdrawn' else 'student.section_completed' end,'student_section_placement',p.id,to_jsonb(p),
   jsonb_build_object('placement_id',p.id,'status',case when d.disposition='withdrawal' then 'withdrawn' else 'completed' end),jsonb_build_object('student_id',d.student_id,'school_id',d.source_school_id,'campus_id',p.campus_id,'academic_year_id',d.source_academic_year_id,'section_id',p.section_id,'ended_on',d.source_end_on,'progression_decision_id',d.id));
 end if;
 update public.student_enrollments set status=case when d.disposition='withdrawal' then 'withdrawn'::public.enrollment_status else 'completed'::public.enrollment_status end,
  ended_on=d.source_end_on,enrollment_range=daterange(enrolled_on,d.source_end_on,'[]'),end_reason='progression decision '||d.id::text,updated_by=a where id=e.id;
 perform app_auth.write_progression_change(cmd,d.organization_id,a,case when d.disposition='withdrawal' then 'student.enrollment_withdrawn' else 'student.enrollment_completed' end,'student_enrollment',e.id,to_jsonb(e),
  jsonb_build_object('enrollment_id',e.id,'status',case when d.disposition='withdrawal' then 'withdrawn' else 'completed' end),jsonb_build_object('student_id',d.student_id,'school_id',d.source_school_id,'academic_year_id',d.source_academic_year_id,'ended_on',d.source_end_on,'progression_decision_id',d.id));
 if d.disposition in('promotion','retention','transfer') then
  select * into y from public.academic_years where id=d.destination_academic_year_id for update;
  insert into public.student_enrollments(organization_id,school_id,academic_year_id,student_id,grade_level_id,enrolled_on,scheduled_end_on,enrollment_range,status,created_by,updated_by)
  values(d.organization_id,d.destination_school_id,d.destination_academic_year_id,d.student_id,d.destination_grade_level_id,d.destination_enrolled_on,y.end_date,daterange(d.destination_enrolled_on,y.end_date,'[]'),'active',a,a) returning id into de;
  perform app_auth.write_progression_change(cmd,d.organization_id,a,'student.enrolled','student_enrollment',de,null,jsonb_build_object('enrollment_id',de,'status','active'),jsonb_build_object('student_id',d.student_id,'school_id',d.destination_school_id,'academic_year_id',d.destination_academic_year_id,'enrolled_on',d.destination_enrolled_on,'progression_decision_id',d.id));
  if d.destination_section_id is not null then
   select * into sec from public.sections where id=d.destination_section_id for update;
   if (select count(*) from public.student_section_placements where section_id=sec.id and status='active')>=sec.capacity then raise exception using errcode='22023',message='destination section is at capacity'; end if;
   insert into public.student_section_placements(organization_id,school_id,campus_id,academic_year_id,student_enrollment_id,student_id,section_id,starts_on,status,created_by,updated_by)
   values(d.organization_id,d.destination_school_id,d.destination_campus_id,d.destination_academic_year_id,de,d.student_id,d.destination_section_id,d.destination_enrolled_on,'active',a,a) returning id into dp;
   perform app_auth.write_progression_change(cmd,d.organization_id,a,'student.section_placed','student_section_placement',dp,null,jsonb_build_object('placement_id',dp,'status','active'),jsonb_build_object('student_id',d.student_id,'school_id',d.destination_school_id,'campus_id',d.destination_campus_id,'academic_year_id',d.destination_academic_year_id,'section_id',d.destination_section_id,'starts_on',d.destination_enrolled_on,'progression_decision_id',d.id));
  end if;
 end if;
 return (d.id,source_e,source_p,de,dp)::public.progression_execution_result;
end $$;

create function app_auth.create_progression_decision_impl(a uuid,p_student uuid,p_source_enrollment uuid,p_disposition public.progression_disposition,p_source_end date,
 p_destination_school uuid,p_destination_campus uuid,p_destination_year uuid,p_destination_grade uuid,p_destination_section uuid,p_destination_enrolled date,p_override text,p_batch uuid default null,p_supersedes uuid default null,p_correction_reason text default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare e0 public.student_enrollments; e public.student_enrollments; s0 public.students; s public.students; p public.student_section_placements; d public.progression_decisions; old public.progression_decisions; rid uuid:=gen_random_uuid(); v integer:=1; lin uuid:=rid; begin
 select * into e0 from public.student_enrollments where id=p_source_enrollment;
 if e0.id is null then raise exception using errcode='P0002',message='source enrollment not found'; end if;
 select * into s0 from public.students where id=p_student;
 if s0.id is null or s0.organization_id<>e0.organization_id or e0.student_id<>s0.id or s0.status<>'active' then raise exception using errcode='22023',message='active student and matching enrollment required'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('school-platform:progression:'||e0.organization_id::text,0));
 perform 1 from public.organizations where id=e0.organization_id for update;
 perform 1 from public.schools where id in(e0.school_id,p_destination_school) order by id for update;
 perform 1 from public.campuses where id in(s0.campus_id,p_destination_campus) order by id for update;
 perform 1 from public.academic_years where id in(e0.academic_year_id,p_destination_year) order by school_id,id for update;
 perform 1 from public.grade_levels where id in(e0.grade_level_id,p_destination_grade) order by school_id,sequence,id for update;
	if p_destination_section is not null then perform 1 from public.sections where id=p_destination_section for update; end if;
	select * into s from public.students where id=p_student for update;
	select * into e from public.student_enrollments where id=p_source_enrollment for update;
	if s.organization_id is distinct from s0.organization_id or s.campus_id is distinct from s0.campus_id or s.status is distinct from s0.status
	 or e.organization_id is distinct from e0.organization_id or e.school_id is distinct from e0.school_id or e.academic_year_id is distinct from e0.academic_year_id
	 or e.student_id is distinct from e0.student_id or e.grade_level_id is distinct from e0.grade_level_id or e.status is distinct from e0.status then
	 raise exception using errcode='40001',message='progression source context changed during lock acquisition';
	end if;
	select * into p from public.student_section_placements where student_enrollment_id=e.id and status='active' for update;
 perform app_auth.assert_progression_permission(e.organization_id,'progression.manage',e.school_id,p.campus_id);
 if p_destination_school is not null then perform app_auth.assert_progression_permission(e.organization_id,'progression.manage',p_destination_school,p_destination_campus); end if;
 if p_supersedes is null and e.status<>'active' then raise exception using errcode='22023',message='active source enrollment required'; end if;
 if p_supersedes is not null then
  select * into old from public.progression_decisions where id=p_supersedes for update;
  if old.id is null or old.status<>'executed' or old.source_enrollment_id<>e.id then raise exception using errcode='22023',message='executed predecessor for same source enrollment required'; end if;
  if exists(select 1 from public.progression_decisions where supersedes_decision_id=old.id) then raise exception using errcode='23505',message='predecessor already has a correction'; end if;
  lin:=old.lineage_id; v:=old.version+1;
 end if;
 insert into public.progression_decisions(id,organization_id,student_id,source_school_id,source_campus_id,source_academic_year_id,source_grade_level_id,source_enrollment_id,source_placement_id,
  disposition,source_end_on,destination_school_id,destination_campus_id,destination_academic_year_id,destination_grade_level_id,destination_section_id,destination_enrolled_on,
  lineage_id,version,supersedes_decision_id,correction_reason,eligibility_override_reason,batch_id,created_by,updated_by)
 values(rid,e.organization_id,s.id,e.school_id,p.campus_id,e.academic_year_id,e.grade_level_id,e.id,p.id,p_disposition,p_source_end,p_destination_school,p_destination_campus,p_destination_year,p_destination_grade,p_destination_section,p_destination_enrolled,
  lin,v,p_supersedes,p_correction_reason,nullif(btrim(p_override),''),p_batch,a,a) returning * into d;
 perform app_auth.assert_progression_context(d,false);
 perform app_auth.refresh_progression_evidence(rid,a);
 return rid;
end $$;

create function public.create_progression_decision(request_id uuid,student_id uuid,source_enrollment_id uuid,disposition public.progression_disposition,source_end_on date,
 destination_school_id uuid,destination_campus_id uuid,destination_academic_year_id uuid,destination_grade_level_id uuid,destination_section_id uuid,destination_enrolled_on date,eligibility_override_reason text default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare a uuid:=app_auth.progression_actor(); e public.student_enrollments; h bytea; q record; rid uuid; begin
 select * into e from public.student_enrollments where id=source_enrollment_id; if e.id is null then raise exception using errcode='P0002',message='source enrollment not found'; end if;
 h:=extensions.digest(convert_to(concat_ws('|',student_id,source_enrollment_id,disposition,source_end_on,destination_school_id,destination_campus_id,destination_academic_year_id,destination_grade_level_id,destination_section_id,destination_enrolled_on,eligibility_override_reason),'UTF8'),'sha256');
 select * into q from app_auth.claim_progression_receipt(e.organization_id,a,'create_progression_decision',request_id,h); if q.replayed then return q.result_id; end if;
 rid:=app_auth.create_progression_decision_impl(a,student_id,source_enrollment_id,disposition,source_end_on,destination_school_id,destination_campus_id,destination_academic_year_id,destination_grade_level_id,destination_section_id,destination_enrolled_on,eligibility_override_reason);
 perform app_auth.write_progression_change(q.command_id,e.organization_id,a,'student.progression_decision_created','progression_decision',rid,null,(select to_jsonb(d)-'eligibility_override_reason' from public.progression_decisions d where d.id=rid),jsonb_build_object('decision_id',rid,'student_id',student_id,'disposition',disposition));
 perform app_auth.complete_progression_receipt(e.organization_id,a,'create_progression_decision',request_id,rid); return rid;
end $$;

create function public.refresh_progression_eligibility(request_id uuid,progression_decision_id uuid) returns uuid
language plpgsql security definer set search_path='' as $$
declare a uuid:=app_auth.progression_actor(); d public.progression_decisions; q record; eid uuid; h bytea; begin
 perform app_auth.lock_progression_decision_context(progression_decision_id); select * into d from public.progression_decisions where id=progression_decision_id for update; if d.id is null then raise exception using errcode='P0002',message='decision not found'; end if;
 perform app_auth.assert_progression_permission(d.organization_id,'progression.manage',d.source_school_id,d.source_campus_id);
 h:=extensions.digest(convert_to(d.id::text,'UTF8'),'sha256'); select * into q from app_auth.claim_progression_receipt(d.organization_id,a,'refresh_progression_eligibility',request_id,h); if q.replayed then return q.result_id; end if;
 eid:=app_auth.refresh_progression_evidence(d.id,a);
 perform app_auth.write_progression_change(q.command_id,d.organization_id,a,'student.progression_eligibility_evaluated','progression_decision',d.id,null,jsonb_build_object('decision_id',d.id,'evaluation_id',eid),jsonb_build_object('decision_id',d.id));
 perform app_auth.complete_progression_receipt(d.organization_id,a,'refresh_progression_eligibility',request_id,eid); return eid;
end $$;

create function public.approve_progression_decision(request_id uuid,progression_decision_id uuid,approval_reason text) returns uuid
language plpgsql security definer set search_path='' as $$
declare a uuid:=app_auth.progression_actor(); d public.progression_decisions; ev public.progression_eligibility_evaluations; q record; h bytea; oldj jsonb; begin
 perform app_auth.lock_progression_decision_context(progression_decision_id); select * into d from public.progression_decisions where id=progression_decision_id for update; if d.id is null then raise exception using errcode='P0002',message='decision not found'; end if;
 perform app_auth.assert_progression_permission(d.organization_id,'progression.approve',d.source_school_id,d.source_campus_id);
 if d.destination_school_id is not null then perform app_auth.assert_progression_permission(d.organization_id,'progression.approve',d.destination_school_id,d.destination_campus_id); end if;
 h:=extensions.digest(convert_to(d.id::text||'|'||coalesce($3,''),'UTF8'),'sha256'); select * into q from app_auth.claim_progression_receipt(d.organization_id,a,'approve_progression_decision',request_id,h); if q.replayed then return q.result_id; end if;
 if d.status<>'pending' or d.created_by=a then raise exception using errcode='22023',message='pending decision and different approver required'; end if;
 perform app_auth.assert_progression_context(d,true);
 if not app_auth.progression_evidence_is_current(d.id) then raise exception using errcode='22023',message='eligibility evidence is stale'; end if;
 select * into ev from public.progression_eligibility_evaluations where id=d.current_eligibility_evaluation_id;
 if ev.state<>'eligible' and d.eligibility_override_reason is null then raise exception using errcode='22023',message='eligibility override reason required'; end if;
 oldj:=to_jsonb(d)-'eligibility_override_reason'; update public.progression_decisions set status='approved',approved_at=now(),approved_by=a,approval_reason=btrim($3),updated_by=a where id=d.id;
 perform app_auth.write_progression_change(q.command_id,d.organization_id,a,'student.progression_decision_approved','progression_decision',d.id,oldj,(select to_jsonb(x)-'eligibility_override_reason' from public.progression_decisions x where x.id=d.id),jsonb_build_object('decision_id',d.id,'student_id',d.student_id,'status','approved'));
 perform app_auth.complete_progression_receipt(d.organization_id,a,'approve_progression_decision',request_id,d.id); return d.id;
end $$;

create function app_auth.execute_progression_decision_impl(did uuid,a uuid,cmd uuid) returns public.progression_execution_result
language plpgsql security definer set search_path='' as $$
declare d public.progression_decisions; pred public.progression_decisions; r public.progression_execution_result; begin
 perform app_auth.lock_progression_decision_context(did); select * into d from public.progression_decisions where id=did for update;
 if d.id is null or d.status<>'approved' or d.approved_by=a then raise exception using errcode='22023',message='approved decision and different executor required'; end if;
 perform app_auth.assert_progression_permission(d.organization_id,'progression.execute',d.source_school_id,d.source_campus_id);
 if d.destination_school_id is not null then perform app_auth.assert_progression_permission(d.organization_id,'progression.execute',d.destination_school_id,d.destination_campus_id); end if;
 if d.supersedes_decision_id is not null then perform app_auth.assert_progression_permission(d.organization_id,'progression.correct',d.source_school_id,d.source_campus_id); end if;
 if not app_auth.progression_evidence_is_current(d.id) then raise exception using errcode='22023',message='eligibility evidence is stale'; end if;
 perform app_auth.assert_progression_context(d,true);
 r:=app_auth.execute_progression_enrollment_effect(d.id,a,cmd);
 update public.progression_decisions set status='executed',executed_at=now(),executed_by=a,result_source_enrollment_id=r.source_enrollment_id,
  result_source_placement_id=r.source_placement_id,destination_enrollment_id=r.destination_enrollment_id,destination_placement_id=r.destination_placement_id,updated_by=a where id=d.id;
 if d.supersedes_decision_id is not null then update public.progression_decisions set status='corrected',corrected_at=now(),corrected_by=a,updated_by=a where id=d.supersedes_decision_id; end if;
 perform app_auth.finish_progression_batch(d.batch_id,cmd,a); return r;
end $$;

create function public.execute_progression_decision(request_id uuid,progression_decision_id uuid) returns public.progression_execution_result
language plpgsql security definer set search_path='' as $$
declare a uuid:=app_auth.progression_actor(); d public.progression_decisions; q record; r public.progression_execution_result; h bytea; begin
 select * into d from public.progression_decisions where id=progression_decision_id; if d.id is null then raise exception using errcode='P0002',message='decision not found'; end if;
 h:=extensions.digest(convert_to(d.id::text,'UTF8'),'sha256'); select * into q from app_auth.claim_progression_receipt(d.organization_id,a,'execute_progression_decision',request_id,h);
 if q.replayed then return (q.result_id,(select result_source_enrollment_id from public.progression_decisions where id=q.result_id),(select result_source_placement_id from public.progression_decisions where id=q.result_id),(select destination_enrollment_id from public.progression_decisions where id=q.result_id),(select destination_placement_id from public.progression_decisions where id=q.result_id))::public.progression_execution_result; end if;
 r:=app_auth.execute_progression_decision_impl(d.id,a,q.command_id);
 perform app_auth.write_progression_change(q.command_id,d.organization_id,a,case when d.supersedes_decision_id is null then 'student.progression_executed' else 'student.progression_corrected' end,'progression_decision',d.id,null,jsonb_build_object('decision_id',d.id,'status','executed','source_enrollment_id',r.source_enrollment_id,'destination_enrollment_id',r.destination_enrollment_id),jsonb_build_object('decision_id',d.id,'student_id',d.student_id,'disposition',d.disposition,'source_end_on',d.source_end_on,'destination_enrolled_on',d.destination_enrolled_on));
 perform app_auth.complete_progression_receipt(d.organization_id,a,'execute_progression_decision',request_id,d.id); return r;
end $$;

create function public.cancel_progression_decision(request_id uuid,progression_decision_id uuid,cancellation_reason text) returns uuid
language plpgsql security definer set search_path='' as $$
declare a uuid:=app_auth.progression_actor(); d public.progression_decisions; q record; h bytea; begin
 select * into d from public.progression_decisions where id=progression_decision_id for update; if d.id is null then raise exception using errcode='P0002',message='decision not found'; end if;
 perform app_auth.assert_progression_permission(d.organization_id,'progression.cancel',d.source_school_id,d.source_campus_id);
 h:=extensions.digest(convert_to(d.id::text||'|'||coalesce($3,''),'UTF8'),'sha256'); select * into q from app_auth.claim_progression_receipt(d.organization_id,a,'cancel_progression_decision',request_id,h); if q.replayed then return q.result_id; end if;
 if d.status not in('pending','approved') then raise exception using errcode='22023',message='pending or approved decision required'; end if;
 update public.progression_decisions set status='cancelled',cancelled_at=now(),cancelled_by=a,cancellation_reason=btrim($3),updated_by=a where id=d.id;
 perform app_auth.finish_progression_batch(d.batch_id,q.command_id,a);
 perform app_auth.write_progression_change(q.command_id,d.organization_id,a,'student.progression_decision_cancelled','progression_decision',d.id,null,jsonb_build_object('decision_id',d.id,'status','cancelled'),jsonb_build_object('decision_id',d.id,'student_id',d.student_id,'status','cancelled'));
 perform app_auth.complete_progression_receipt(d.organization_id,a,'cancel_progression_decision',request_id,d.id); return d.id;
end $$;

create function public.create_progression_correction(request_id uuid,executed_decision_id uuid,disposition public.progression_disposition,source_end_on date,
 destination_school_id uuid,destination_campus_id uuid,destination_academic_year_id uuid,destination_grade_level_id uuid,destination_section_id uuid,destination_enrolled_on date,eligibility_override_reason text,correction_reason text)
returns uuid language plpgsql security definer set search_path='' as $$
declare a uuid:=app_auth.progression_actor(); old public.progression_decisions; q record; h bytea; rid uuid; begin
 perform app_auth.lock_progression_decision_context(executed_decision_id); select * into old from public.progression_decisions where id=executed_decision_id for update; if old.id is null or old.status<>'executed' then raise exception using errcode='22023',message='executed decision required'; end if;
 perform app_auth.assert_progression_permission(old.organization_id,'progression.correct',old.source_school_id,old.source_campus_id);
 h:=extensions.digest(convert_to(concat_ws('|',old.id,disposition,source_end_on,destination_school_id,destination_campus_id,destination_academic_year_id,destination_grade_level_id,destination_section_id,destination_enrolled_on,correction_reason),'UTF8'),'sha256');
 select * into q from app_auth.claim_progression_receipt(old.organization_id,a,'create_progression_correction',request_id,h); if q.replayed then return q.result_id; end if;
 rid:=app_auth.create_progression_decision_impl(a,old.student_id,old.source_enrollment_id,disposition,source_end_on,destination_school_id,destination_campus_id,destination_academic_year_id,destination_grade_level_id,destination_section_id,destination_enrolled_on,eligibility_override_reason,old.batch_id,old.id,correction_reason);
 perform app_auth.write_progression_change(q.command_id,old.organization_id,a,'student.progression_correction_created','progression_decision',rid,null,jsonb_build_object('decision_id',rid,'supersedes_decision_id',old.id),jsonb_build_object('decision_id',rid,'student_id',old.student_id,'supersedes_decision_id',old.id));
 perform app_auth.complete_progression_receipt(old.organization_id,a,'create_progression_correction',request_id,rid,old.id); return rid;
end $$;

create function public.create_progression_batch(request_id uuid,source_school_id uuid,source_academic_year_id uuid,items public.progression_batch_decision_input[])
returns public.progression_batch_create_result language plpgsql security definer set search_path='' as $$
declare a uuid:=app_auth.progression_actor(); y public.academic_years; q record; h bytea; bid uuid:=gen_random_uuid(); x public.progression_batch_decision_input; rid uuid; ids uuid[]:='{}'; begin
 select * into y from public.academic_years where id=source_academic_year_id and school_id=source_school_id for update; if y.id is null then raise exception using errcode='P0002',message='source year not found'; end if;
 perform app_auth.assert_progression_permission(y.organization_id,'progression.manage',y.school_id,null);
 if coalesce(array_length(items,1),0) not between 1 and 500 then raise exception using errcode='22023',message='batch must contain 1 to 500 items'; end if;
 h:=extensions.digest(convert_to(source_school_id::text||'|'||source_academic_year_id::text||'|'||items::text,'UTF8'),'sha256');
 select * into q from app_auth.claim_progression_receipt(y.organization_id,a,'create_progression_batch',request_id,h); if q.replayed then return (q.result_id,q.result_ids)::public.progression_batch_create_result; end if;
 insert into public.progression_batches(id,organization_id,source_school_id,source_academic_year_id,created_by,updated_by) values(bid,y.organization_id,y.school_id,y.id,a,a);
 foreach x in array items loop
  if exists(select 1 from unnest(ids) z join public.progression_decisions d on d.id=z where d.source_enrollment_id=x.source_enrollment_id) then raise exception using errcode='22023',message='duplicate source enrollment in batch'; end if;
  rid:=app_auth.create_progression_decision_impl(a,x.student_id,x.source_enrollment_id,x.disposition,x.source_end_on,x.destination_school_id,x.destination_campus_id,x.destination_academic_year_id,x.destination_grade_level_id,x.destination_section_id,x.destination_enrolled_on,x.eligibility_override_reason,bid);
  insert into public.progression_batch_items(organization_id,batch_id,decision_id,student_id,source_enrollment_id,created_by) values(y.organization_id,bid,rid,x.student_id,x.source_enrollment_id,a); ids:=array_append(ids,rid);
 end loop;
 perform app_auth.write_progression_change(q.command_id,y.organization_id,a,'student.progression_batch_created','progression_batch',bid,null,jsonb_build_object('batch_id',bid,'item_count',array_length(ids,1)),jsonb_build_object('batch_id',bid,'source_school_id',y.school_id,'source_academic_year_id',y.id,'item_count',array_length(ids,1)));
 perform app_auth.complete_progression_receipt(y.organization_id,a,'create_progression_batch',request_id,bid,null,ids); return (bid,ids)::public.progression_batch_create_result;
end $$;

create function public.approve_progression_batch(request_id uuid,batch_id uuid,approval_reason text) returns uuid
language plpgsql security definer set search_path='' as $$
declare a uuid:=app_auth.progression_actor(); b public.progression_batches; d public.progression_decisions; q record; h bytea; begin
 select * into b from public.progression_batches where id=batch_id for update; if b.id is null then raise exception using errcode='P0002',message='batch not found'; end if;
 perform app_auth.assert_progression_permission(b.organization_id,'progression.approve',b.source_school_id,null);
 h:=extensions.digest(convert_to(b.id::text||'|'||coalesce($3,''),'UTF8'),'sha256'); select * into q from app_auth.claim_progression_receipt(b.organization_id,a,'approve_progression_batch',request_id,h); if q.replayed then return q.result_id; end if;
 if b.status<>'draft' then raise exception using errcode='22023',message='draft batch required'; end if;
 for d in select x.* from public.progression_decisions x where x.batch_id=b.id order by x.student_id,x.id for update loop
  if d.status<>'pending' or d.created_by=a then raise exception using errcode='22023',message='pending decisions and different approver required'; end if;
  if not app_auth.progression_evidence_is_current(d.id) then raise exception using errcode='22023',message='eligibility evidence is stale'; end if;
  if (select state from public.progression_eligibility_evaluations where id=d.current_eligibility_evaluation_id)<>'eligible' and d.eligibility_override_reason is null then raise exception using errcode='22023',message='eligibility override reason required'; end if;
  if d.destination_school_id is not null then perform app_auth.assert_progression_permission(d.organization_id,'progression.approve',d.destination_school_id,d.destination_campus_id); end if;
 end loop;
 update public.progression_decisions set status='approved',approved_at=now(),approved_by=a,approval_reason=btrim($3),updated_by=a where progression_decisions.batch_id=b.id;
 update public.progression_batches set status='approved',approved_at=now(),approved_by=a,approval_reason=btrim($3),updated_by=a where id=b.id;
 perform app_auth.write_progression_change(q.command_id,b.organization_id,a,'student.progression_batch_approved','progression_batch',b.id,null,jsonb_build_object('batch_id',b.id,'status','approved'),jsonb_build_object('batch_id',b.id,'status','approved'));
 perform app_auth.complete_progression_receipt(b.organization_id,a,'approve_progression_batch',request_id,b.id); return b.id;
end $$;

create function public.execute_progression_batch_item(request_id uuid,batch_id uuid,decision_id uuid) returns public.progression_batch_item_result
language plpgsql security definer set search_path='' as $$
declare a uuid:=app_auth.progression_actor(); b public.progression_batches; d public.progression_decisions; q record; h bytea; r public.progression_execution_result; code text; cat text; begin
 select * into b from public.progression_batches where id=batch_id for update; select * into d from public.progression_decisions where id=decision_id and progression_decisions.batch_id=execute_progression_batch_item.batch_id for update;
 if b.id is null or d.id is null then raise exception using errcode='P0002',message='batch item not found'; end if;
 perform app_auth.assert_progression_permission(b.organization_id,'progression.execute',d.source_school_id,d.source_campus_id);
 h:=extensions.digest(convert_to(b.id::text||'|'||d.id::text,'UTF8'),'sha256'); select * into q from app_auth.claim_progression_receipt(b.organization_id,a,'execute_progression_batch_item',request_id,h);
 if q.replayed then return (d.id,d.status='executed',d.status<>'executed',case when d.status='executed' then null else (select last_error_code from public.progression_batch_items where batch_id=b.id and progression_batch_items.decision_id=d.id) end,case when d.status='executed' then null else (select last_error_category from public.progression_batch_items where batch_id=b.id and progression_batch_items.decision_id=d.id) end)::public.progression_batch_item_result; end if;
 if b.status<>'approved' then raise exception using errcode='22023',message='approved batch item required'; end if;
 begin
  r:=app_auth.execute_progression_decision_impl(d.id,a,q.command_id);
  update public.progression_batch_items set last_attempted_at=now(),attempt_count=attempt_count+1,last_error_code=null,last_error_category=null where progression_batch_items.batch_id=b.id and progression_batch_items.decision_id=d.id;
 exception when serialization_failure or deadlock_detected then raise;
 when others then
  get stacked diagnostics code=returned_sqlstate;
  cat:=case when code='42501' then 'authorization' when code in('23503','23505','23P01') then 'conflict' when code='P0002' then 'not_found' else 'validation' end;
  update public.progression_batch_items set last_attempted_at=now(),attempt_count=attempt_count+1,last_error_code=code,last_error_category=cat where progression_batch_items.batch_id=b.id and progression_batch_items.decision_id=d.id;
  perform app_auth.complete_progression_receipt(b.organization_id,a,'execute_progression_batch_item',request_id,d.id);
  return (d.id,false,true,code,cat)::public.progression_batch_item_result;
 end;
 perform app_auth.write_progression_change(q.command_id,b.organization_id,a,'student.progression_executed','progression_decision',d.id,null,jsonb_build_object('decision_id',d.id,'status','executed'),jsonb_build_object('decision_id',d.id,'student_id',d.student_id,'batch_id',b.id,'disposition',d.disposition));
 perform app_auth.complete_progression_receipt(b.organization_id,a,'execute_progression_batch_item',request_id,d.id); return (d.id,true,false,null,null)::public.progression_batch_item_result;
end $$;

create function public.cancel_progression_batch(request_id uuid,batch_id uuid,cancellation_reason text) returns uuid
language plpgsql security definer set search_path='' as $$
declare a uuid:=app_auth.progression_actor(); b public.progression_batches; q record; h bytea; begin
 select * into b from public.progression_batches where id=batch_id for update; if b.id is null then raise exception using errcode='P0002',message='batch not found'; end if;
 perform app_auth.assert_progression_permission(b.organization_id,'progression.cancel',b.source_school_id,null);
 h:=extensions.digest(convert_to(b.id::text||'|'||coalesce($3,''),'UTF8'),'sha256'); select * into q from app_auth.claim_progression_receipt(b.organization_id,a,'cancel_progression_batch',request_id,h); if q.replayed then return q.result_id; end if;
 if b.status='completed' then raise exception using errcode='22023',message='open batch required'; end if;
	update public.progression_decisions set status='cancelled',cancelled_at=now(),cancelled_by=a,cancellation_reason=btrim($3),updated_by=a where progression_decisions.batch_id=b.id and status in('pending','approved');
	perform app_auth.finish_progression_batch(b.id,q.command_id,a);
	perform app_auth.complete_progression_receipt(b.organization_id,a,'cancel_progression_batch',request_id,b.id); return b.id;
end $$;

create function app_auth.guard_progression_immutable() returns trigger language plpgsql set search_path='' as $$ begin
 if new.organization_id<>old.organization_id or new.student_id<>old.student_id or new.source_enrollment_id<>old.source_enrollment_id or new.disposition<>old.disposition
  or new.source_end_on<>old.source_end_on or new.destination_school_id is distinct from old.destination_school_id or new.destination_campus_id is distinct from old.destination_campus_id
  or new.destination_academic_year_id is distinct from old.destination_academic_year_id or new.destination_grade_level_id is distinct from old.destination_grade_level_id
  or new.destination_section_id is distinct from old.destination_section_id or new.destination_enrolled_on is distinct from old.destination_enrolled_on
  or new.lineage_id<>old.lineage_id or new.version<>old.version or new.supersedes_decision_id is distinct from old.supersedes_decision_id then
  raise exception using errcode='22023',message='progression decision facts are immutable'; end if; return new; end $$;
create trigger progression_decisions_immutable before update on public.progression_decisions for each row execute function app_auth.guard_progression_immutable();

create function app_auth.reject_progression_history_mutation() returns trigger language plpgsql set search_path='' as $$ begin
 raise exception using errcode='22023',message='progression evidence and batch membership are immutable'; end $$;
create trigger progression_evaluations_immutable before update or delete on public.progression_eligibility_evaluations for each row execute function app_auth.reject_progression_history_mutation();
create trigger progression_evidence_immutable before update or delete on public.progression_decision_evidence for each row execute function app_auth.reject_progression_history_mutation();
create trigger progression_batch_items_immutable before delete on public.progression_batch_items for each row execute function app_auth.reject_progression_history_mutation();

create function app_auth.assert_progression_batch_terminal() returns trigger language plpgsql set search_path='' as $$
declare bid uuid; st public.progression_batch_status; open_count integer; item_count integer; begin
 if tg_table_name='progression_batches' then
  bid:=new.id;
 elsif tg_op='DELETE' then
  bid:=old.batch_id;
 else
  bid:=new.batch_id;
 end if;
 select status into st from public.progression_batches where id=bid;
 select count(*),count(*) filter(where d.status not in('executed','cancelled')) into item_count,open_count
 from public.progression_batch_items i join public.progression_decisions d on d.id=i.decision_id where i.batch_id=bid;
 if item_count>0 and ((st='completed' and open_count>0) or(st<>'completed' and open_count=0)) then
  raise exception using errcode='23514',message='batch completion must exactly match terminal children'; end if; return null;
end $$;
create constraint trigger progression_batch_terminal_batch after insert or update on public.progression_batches deferrable initially deferred for each row execute function app_auth.assert_progression_batch_terminal();
create constraint trigger progression_batch_terminal_decision after update on public.progression_decisions deferrable initially deferred for each row when(new.batch_id is not null) execute function app_auth.assert_progression_batch_terminal();
create constraint trigger progression_batch_terminal_item after insert or update or delete on public.progression_batch_items deferrable initially deferred for each row execute function app_auth.assert_progression_batch_terminal();

create function app_auth.protect_progression_parent() returns trigger language plpgsql set search_path='' as $$ begin
 if new.status::text in('closed','archived','inactive') and new.status is distinct from old.status and exists(
  select 1 from public.progression_decisions d where d.status='approved' and
   ((tg_table_name='academic_years' and new.id in(d.source_academic_year_id,d.destination_academic_year_id))
    or(tg_table_name='sections' and new.id=d.destination_section_id)
    or(tg_table_name='grade_levels' and new.id in(d.source_grade_level_id,d.destination_grade_level_id)))) then
  raise exception using errcode='22023',message='approved progression decision blocks parent lifecycle change'; end if; return new; end $$;
create trigger academic_years_progression_guard before update on public.academic_years for each row execute function app_auth.protect_progression_parent();
create trigger sections_progression_guard before update on public.sections for each row execute function app_auth.protect_progression_parent();
create trigger grade_levels_progression_guard before update on public.grade_levels for each row execute function app_auth.protect_progression_parent();

revoke all on function app_auth.progression_actor(),app_auth.assert_progression_permission(uuid,text,uuid,uuid),
 app_auth.claim_progression_receipt(uuid,uuid,text,uuid,bytea),app_auth.complete_progression_receipt(uuid,uuid,text,uuid,uuid,uuid,uuid[]),
 app_auth.write_progression_change(uuid,uuid,uuid,text,text,uuid,jsonb,jsonb,jsonb),app_auth.progression_source_fingerprint(uuid),app_auth.refresh_progression_evidence(uuid,uuid),
 app_auth.progression_evidence_is_current(uuid),app_auth.lock_progression_decision_context(uuid),app_auth.assert_progression_context(public.progression_decisions,boolean),
 app_auth.finish_progression_batch(uuid,uuid,uuid),app_auth.execute_progression_enrollment_effect(uuid,uuid,uuid),
 app_auth.create_progression_decision_impl(uuid,uuid,uuid,public.progression_disposition,date,uuid,uuid,uuid,uuid,uuid,date,text,uuid,uuid,text),
 app_auth.execute_progression_decision_impl(uuid,uuid,uuid),app_auth.guard_progression_immutable(),app_auth.reject_progression_history_mutation(),
 app_auth.assert_progression_batch_terminal(),app_auth.protect_progression_parent()
 from public,anon,authenticated,service_role;
revoke all on function app_auth.can_view_progression(uuid,uuid,uuid,uuid,uuid,uuid,public.progression_decision_status) from public,anon;
grant execute on function app_auth.can_view_progression(uuid,uuid,uuid,uuid,uuid,uuid,public.progression_decision_status) to authenticated,service_role;

do $$ declare p regprocedure; begin foreach p in array array[
 'public.create_progression_decision(uuid,uuid,uuid,public.progression_disposition,date,uuid,uuid,uuid,uuid,uuid,date,text)'::regprocedure,
 'public.refresh_progression_eligibility(uuid,uuid)'::regprocedure,
 'public.approve_progression_decision(uuid,uuid,text)'::regprocedure,
 'public.execute_progression_decision(uuid,uuid)'::regprocedure,
 'public.cancel_progression_decision(uuid,uuid,text)'::regprocedure,
 'public.create_progression_correction(uuid,uuid,public.progression_disposition,date,uuid,uuid,uuid,uuid,uuid,date,text,text)'::regprocedure,
 'public.create_progression_batch(uuid,uuid,uuid,public.progression_batch_decision_input[])'::regprocedure,
 'public.approve_progression_batch(uuid,uuid,text)'::regprocedure,
 'public.execute_progression_batch_item(uuid,uuid,uuid)'::regprocedure,
 'public.cancel_progression_batch(uuid,uuid,text)'::regprocedure]
 loop execute format('alter function %s owner to postgres',p); execute format('revoke all on function %s from public,anon',p); execute format('grant execute on function %s to authenticated',p); end loop; end $$;

alter table public.progression_batches owner to postgres;
alter table public.progression_decisions owner to postgres;
alter table public.progression_eligibility_evaluations owner to postgres;
alter table public.progression_decision_evidence owner to postgres;
alter table public.progression_batch_items owner to postgres;
alter table app_auth.progression_command_receipts owner to postgres;

commit;
