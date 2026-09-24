begin;

create type public.transcript_status as enum ('draft','reviewed','issued','superseded','corrected','cancelled');
create type public.transcript_result_state as enum ('pass','fail','incomplete','withdrawn','transferred','non_credit');
create type public.transcript_exclusion_type as enum ('term','subject');
create type public.transcript_policy_status as enum ('draft','active','retired');
create type public.transcript_term_input as (academic_term_id uuid);
create type public.transcript_exclusion_input as (academic_term_id uuid,subject_id uuid,reason text);
create type public.transcript_gpa_band_input as (sequence integer,lower_bound numeric,upper_bound numeric,result_state public.transcript_result_state,grade_points numeric);
create type public.transcript_subject_credit_input as (subject_id uuid,attempted_credits numeric,earned_credits numeric);

alter table public.report_cards add constraint report_cards_transcript_source_key
 unique(organization_id,school_id,student_id,academic_year_id,academic_term_id,section_id,id);
alter table public.report_card_grade_snapshots add constraint report_card_grades_transcript_source_key
 unique(organization_id,school_id,student_id,academic_term_id,report_card_id,id);

create table public.transcript_calculation_policies(
 id uuid primary key default gen_random_uuid(), organization_id uuid not null, school_id uuid not null,
 policy_lineage_id uuid not null, version integer not null check(version>=1), supersedes_policy_id uuid,
 name text not null check(length(btrim(name)) between 1 and 120), status public.transcript_policy_status not null default 'draft',
 gpa_scale numeric(7,4) not null check(gpa_scale>0), decimal_places smallint not null check(decimal_places between 0 and 4),
 include_fail_in_gpa boolean not null, include_incomplete_in_gpa boolean not null default false,
 include_withdrawn_in_gpa boolean not null default false,
 activated_at timestamptz, activated_by uuid references auth.users(id) on delete restrict,
 retired_at timestamptz, retired_by uuid references auth.users(id) on delete restrict,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 created_by uuid not null references auth.users(id) on delete restrict, updated_by uuid not null references auth.users(id) on delete restrict,
 foreign key(organization_id,school_id) references public.schools(organization_id,id) on delete restrict,
 foreign key(organization_id,supersedes_policy_id) references public.transcript_calculation_policies(organization_id,id) on delete restrict,
 unique(organization_id,id), unique(organization_id,school_id,id), unique(organization_id,policy_lineage_id,version),
 check(supersedes_policy_id is null or supersedes_policy_id<>id),
 check((version=1 and policy_lineage_id=id and supersedes_policy_id is null)or(version>1 and supersedes_policy_id is not null)),
 check((status='draft' and activated_at is null and activated_by is null and retired_at is null and retired_by is null)
  or(status='active' and activated_at is not null and activated_by is not null and retired_at is null and retired_by is null)
  or(status='retired' and activated_at is not null and activated_by is not null and retired_at is not null and retired_by is not null))
);
create unique index transcript_policies_active_school_key on public.transcript_calculation_policies(school_id) where status='active';
create unique index transcript_policies_one_successor_key on public.transcript_calculation_policies(supersedes_policy_id) where supersedes_policy_id is not null;
create index transcript_policies_scope_idx on public.transcript_calculation_policies(organization_id,school_id,status,id);
create index transcript_policies_lineage_idx on public.transcript_calculation_policies(organization_id,policy_lineage_id,version desc);

create table public.transcript_gpa_bands(
 id uuid primary key default gen_random_uuid(), organization_id uuid not null, school_id uuid not null,
 transcript_calculation_policy_id uuid not null, sequence integer not null check(sequence>=1),
 lower_bound numeric(7,4) not null check(lower_bound>=0), upper_bound numeric(7,4) not null check(upper_bound<=100 and upper_bound>lower_bound),
 result_state public.transcript_result_state not null, grade_points numeric(9,4) not null check(grade_points>=0),
 created_at timestamptz not null default now(), created_by uuid not null references auth.users(id) on delete restrict,
 foreign key(organization_id,school_id,transcript_calculation_policy_id)
  references public.transcript_calculation_policies(organization_id,school_id,id) on delete restrict,
 unique(organization_id,id), unique(transcript_calculation_policy_id,sequence),
 check(result_state<>'non_credit' or grade_points=0)
);
create index transcript_gpa_bands_policy_idx on public.transcript_gpa_bands(organization_id,school_id,transcript_calculation_policy_id,sequence);

create table public.transcript_subject_credits(
 id uuid primary key default gen_random_uuid(), organization_id uuid not null, school_id uuid not null,
 transcript_calculation_policy_id uuid not null, subject_id uuid not null,
 attempted_credits numeric(9,4) not null check(attempted_credits>=0), earned_credits numeric(9,4) not null check(earned_credits between 0 and attempted_credits),
 created_at timestamptz not null default now(), created_by uuid not null references auth.users(id) on delete restrict,
 foreign key(organization_id,school_id,transcript_calculation_policy_id)
  references public.transcript_calculation_policies(organization_id,school_id,id) on delete restrict,
 foreign key(organization_id,school_id,subject_id) references public.subjects(organization_id,school_id,id) on delete restrict,
 unique(organization_id,id), unique(transcript_calculation_policy_id,subject_id)
);
create index transcript_subject_credits_policy_idx on public.transcript_subject_credits(organization_id,school_id,transcript_calculation_policy_id);
create index transcript_subject_credits_subject_idx on public.transcript_subject_credits(organization_id,school_id,subject_id);

create table public.transcript_lineages(
 id uuid primary key default gen_random_uuid(), organization_id uuid not null, school_id uuid not null, student_id uuid not null,
 created_at timestamptz not null default now(), created_by uuid not null references auth.users(id) on delete restrict,
 foreign key(organization_id,school_id) references public.schools(organization_id,id) on delete restrict,
 foreign key(organization_id,student_id) references public.students(organization_id,id) on delete restrict,
 unique(organization_id,id), unique(organization_id,school_id,student_id),
 unique(organization_id,school_id,student_id,id)
);
create index transcript_lineages_student_idx on public.transcript_lineages(organization_id,student_id,school_id);

create table public.transcripts(
 id uuid primary key default gen_random_uuid(), organization_id uuid not null, school_id uuid not null, student_id uuid not null,
 transcript_lineage_id uuid not null, version integer not null check(version>=1), supersedes_transcript_id uuid,
 replaces_issued_transcript_id uuid, status public.transcript_status not null default 'draft', transcript_number bigint check(transcript_number>=1),
 transcript_calculation_policy_id uuid, policy_lineage_id uuid, policy_version integer,
 policy_name text check(policy_name is null or length(btrim(policy_name)) between 1 and 120),
 gpa_scale numeric(7,4), gpa_decimal_places smallint,
 attempted_credits numeric(12,4), earned_credits numeric(12,4), cumulative_gpa numeric(12,4), gpa_quality_points numeric(20,8),
 source_fingerprint bytea not null check(octet_length(source_fingerprint)=32), snapshot_taken_at timestamptz not null default now(),
 reviewed_at timestamptz, reviewed_by uuid references auth.users(id) on delete restrict,
 review_reason text check(review_reason is null or length(btrim(review_reason)) between 1 and 500),
 issued_at timestamptz, issued_by uuid references auth.users(id) on delete restrict,
 issuance_reason text check(issuance_reason is null or length(btrim(issuance_reason)) between 1 and 500),
 superseded_at timestamptz, superseded_by uuid references auth.users(id) on delete restrict,
 supersession_reason text check(supersession_reason is null or length(btrim(supersession_reason)) between 1 and 500),
 corrected_at timestamptz, corrected_by uuid references auth.users(id) on delete restrict,
 correction_reason text check(correction_reason is null or length(btrim(correction_reason)) between 1 and 500),
 cancelled_at timestamptz, cancelled_by uuid references auth.users(id) on delete restrict,
 cancellation_reason text check(cancellation_reason is null or length(btrim(cancellation_reason)) between 1 and 500),
 school_code text not null check(length(btrim(school_code)) between 1 and 32), school_name text not null check(length(btrim(school_name)) between 2 and 160),
 student_number text not null check(length(btrim(student_number)) between 1 and 48), student_display_name text not null check(length(btrim(student_display_name)) between 1 and 302),
 student_date_of_birth date,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 created_by uuid not null references auth.users(id) on delete restrict, updated_by uuid not null references auth.users(id) on delete restrict,
 foreign key(organization_id,school_id,student_id,transcript_lineage_id)
  references public.transcript_lineages(organization_id,school_id,student_id,id) on delete restrict,
 foreign key(organization_id,student_id) references public.students(organization_id,id) on delete restrict,
 foreign key(organization_id,school_id) references public.schools(organization_id,id) on delete restrict,
 foreign key(organization_id,supersedes_transcript_id) references public.transcripts(organization_id,id) on delete restrict,
 foreign key(organization_id,replaces_issued_transcript_id) references public.transcripts(organization_id,id) on delete restrict,
 foreign key(organization_id,transcript_calculation_policy_id) references public.transcript_calculation_policies(organization_id,id) on delete restrict,
 unique(organization_id,id), unique(organization_id,transcript_lineage_id,version), unique(school_id,transcript_number),
 unique(organization_id,school_id,student_id,id),
 check(supersedes_transcript_id is null or supersedes_transcript_id<>id),
 check(replaces_issued_transcript_id is null or replaces_issued_transcript_id<>id),
 check((version=1 and supersedes_transcript_id is null)or(version>1 and supersedes_transcript_id is not null)),
 check((transcript_calculation_policy_id is null and policy_lineage_id is null and policy_version is null and policy_name is null and gpa_scale is null and gpa_decimal_places is null and attempted_credits is null and earned_credits is null and cumulative_gpa is null and gpa_quality_points is null)
  or(transcript_calculation_policy_id is not null and policy_lineage_id is not null and policy_version is not null and policy_name is not null and gpa_scale>0 and gpa_decimal_places between 0 and 4 and attempted_credits>=0 and earned_credits between 0 and attempted_credits and gpa_quality_points>=0 and(cumulative_gpa is null or cumulative_gpa between 0 and gpa_scale))),
 check((status='draft' and transcript_number is null and reviewed_at is null and reviewed_by is null and review_reason is null and issued_at is null and issued_by is null and issuance_reason is null and superseded_at is null and corrected_at is null and cancelled_at is null)
  or(status='reviewed' and transcript_number is null and reviewed_at is not null and reviewed_by is not null and review_reason is not null and issued_at is null and superseded_at is null and corrected_at is null and cancelled_at is null)
  or(status='issued' and transcript_number is not null and reviewed_at is not null and issued_at is not null and issued_by is not null and issuance_reason is not null and superseded_at is null and corrected_at is null and cancelled_at is null)
  or(status='superseded' and transcript_number is not null and issued_at is not null and superseded_at is not null and superseded_by is not null and supersession_reason is not null and corrected_at is null and cancelled_at is null)
  or(status='corrected' and transcript_number is not null and issued_at is not null and corrected_at is not null and corrected_by is not null and correction_reason is not null and superseded_at is null and cancelled_at is null)
  or(status='cancelled' and transcript_number is null and issued_at is null and superseded_at is null and corrected_at is null and cancelled_at is not null and cancelled_by is not null and cancellation_reason is not null))
);
create unique index transcripts_open_candidate_key on public.transcripts(transcript_lineage_id) where status in('draft','reviewed');
create unique index transcripts_current_issued_key on public.transcripts(transcript_lineage_id) where status='issued';
create unique index transcripts_one_successor_key on public.transcripts(supersedes_transcript_id) where supersedes_transcript_id is not null;
create index transcripts_lineage_idx on public.transcripts(organization_id,transcript_lineage_id,version desc);
create index transcripts_portal_idx on public.transcripts(organization_id,student_id,status,issued_at desc,id);
create index transcripts_scope_idx on public.transcripts(organization_id,school_id,status,id);
create index transcripts_policy_idx on public.transcripts(organization_id,transcript_calculation_policy_id);
create index transcripts_replaces_idx on public.transcripts(organization_id,replaces_issued_transcript_id) where replaces_issued_transcript_id is not null;

create table public.transcript_period_snapshots(
 id uuid primary key default gen_random_uuid(), organization_id uuid not null, school_id uuid not null, student_id uuid not null,
 transcript_id uuid not null, sequence integer not null check(sequence>=1), report_card_id uuid not null,
 report_card_lineage_id uuid not null, report_card_version integer not null, report_card_number bigint not null,
 academic_year_id uuid not null, academic_term_id uuid not null, campus_id uuid not null, section_id uuid not null, grade_level_id uuid not null,
 academic_year_name text not null, academic_term_name text not null, campus_code text not null, campus_name text not null,
 section_code text not null, section_name text not null, grade_level_code text not null, grade_level_name text not null,
 academic_term_sequence smallint not null, term_start_date date not null, term_end_date date not null,
 source_report_card_fingerprint bytea not null check(octet_length(source_report_card_fingerprint)=32),
 created_at timestamptz not null default now(), created_by uuid not null references auth.users(id) on delete restrict,
 foreign key(organization_id,school_id,student_id,transcript_id) references public.transcripts(organization_id,school_id,student_id,id) on delete restrict,
 foreign key(organization_id,school_id,student_id,academic_year_id,academic_term_id,section_id,report_card_id)
  references public.report_cards(organization_id,school_id,student_id,academic_year_id,academic_term_id,section_id,id) on delete restrict,
 foreign key(organization_id,school_id,grade_level_id) references public.grade_levels(organization_id,school_id,id) on delete restrict,
 unique(organization_id,id), unique(transcript_id,sequence), unique(transcript_id,report_card_id),
 unique(organization_id,transcript_id,academic_term_id,id),
 check(term_end_date>=term_start_date)
);
create index transcript_periods_transcript_idx on public.transcript_period_snapshots(organization_id,transcript_id,sequence);
create index transcript_periods_source_idx on public.transcript_period_snapshots(organization_id,school_id,student_id,academic_year_id,academic_term_id,section_id,report_card_id);

create table public.transcript_entry_snapshots(
 id uuid primary key default gen_random_uuid(), organization_id uuid not null, school_id uuid not null, student_id uuid not null,
 transcript_id uuid not null, transcript_period_snapshot_id uuid not null, academic_term_id uuid not null,
 sequence integer not null check(sequence>=1), report_card_id uuid not null, report_card_grade_snapshot_id uuid not null,
 subject_id uuid not null, subject_code text not null, subject_name text not null,
 raw_percentage numeric(20,10) not null, rounded_percentage numeric(7,4) not null check(rounded_percentage between 0 and 100),
 grade_label text not null check(length(btrim(grade_label)) between 1 and 32), result_state public.transcript_result_state not null,
 term_grading_configuration_id uuid not null, term_grade_set_id uuid not null, term_grade_record_id uuid not null,
 term_grade_calculation_id uuid not null, grade_scale_id uuid not null, grade_scale_band_id uuid not null,
 source_term_grade_fingerprint bytea not null check(octet_length(source_term_grade_fingerprint)=32),
 attempted_credits numeric(9,4), earned_credits numeric(9,4), grade_points numeric(9,4), quality_points numeric(20,8),
 created_at timestamptz not null default now(), created_by uuid not null references auth.users(id) on delete restrict,
 foreign key(organization_id,transcript_id,academic_term_id,transcript_period_snapshot_id)
  references public.transcript_period_snapshots(organization_id,transcript_id,academic_term_id,id) on delete restrict,
 foreign key(organization_id,school_id,student_id,academic_term_id,report_card_id,report_card_grade_snapshot_id)
  references public.report_card_grade_snapshots(organization_id,school_id,student_id,academic_term_id,report_card_id,id) on delete restrict,
 foreign key(organization_id,school_id,subject_id) references public.subjects(organization_id,school_id,id) on delete restrict,
 unique(organization_id,id), unique(transcript_id,transcript_period_snapshot_id,sequence), unique(transcript_id,report_card_grade_snapshot_id),
 check((attempted_credits is null and earned_credits is null and grade_points is null and quality_points is null)
  or(attempted_credits>=0 and earned_credits between 0 and attempted_credits and grade_points>=0 and quality_points=attempted_credits*grade_points)),
 check(result_state not in('fail','incomplete','withdrawn','non_credit') or coalesce(earned_credits,0)=0),
 check(result_state<>'non_credit' or(coalesce(attempted_credits,0)=0 and coalesce(grade_points,0)=0 and coalesce(quality_points,0)=0))
);
create index transcript_entries_transcript_idx on public.transcript_entry_snapshots(organization_id,transcript_id,transcript_period_snapshot_id,sequence);
create index transcript_entries_source_idx on public.transcript_entry_snapshots(organization_id,school_id,student_id,academic_term_id,report_card_id,report_card_grade_snapshot_id);
create index transcript_entries_subject_idx on public.transcript_entry_snapshots(organization_id,school_id,subject_id);

create table public.transcript_exclusions(
 id uuid primary key default gen_random_uuid(), organization_id uuid not null, school_id uuid not null, student_id uuid not null,
 transcript_id uuid not null, exclusion_type public.transcript_exclusion_type not null, academic_term_id uuid not null,
 subject_id uuid, report_card_id uuid, report_card_grade_snapshot_id uuid,
 reason text not null check(length(btrim(reason)) between 1 and 500), excluded_by uuid not null references auth.users(id) on delete restrict,
 created_at timestamptz not null default now(),
 foreign key(organization_id,school_id,student_id,transcript_id) references public.transcripts(organization_id,school_id,student_id,id) on delete restrict,
 foreign key(organization_id,school_id,subject_id) references public.subjects(organization_id,school_id,id) on delete restrict,
 foreign key(organization_id,school_id,student_id,academic_term_id,report_card_id,report_card_grade_snapshot_id)
  references public.report_card_grade_snapshots(organization_id,school_id,student_id,academic_term_id,report_card_id,id) on delete restrict,
 unique(organization_id,id),
 check((exclusion_type='term' and subject_id is null and report_card_id is null and report_card_grade_snapshot_id is null)
  or(exclusion_type='subject' and subject_id is not null and report_card_id is not null and report_card_grade_snapshot_id is not null))
);
create unique index transcript_exclusions_term_key on public.transcript_exclusions(transcript_id,academic_term_id) where exclusion_type='term';
create unique index transcript_exclusions_subject_key on public.transcript_exclusions(transcript_id,academic_term_id,subject_id) where exclusion_type='subject';
create index transcript_exclusions_transcript_idx on public.transcript_exclusions(organization_id,transcript_id,academic_term_id);

create table public.transcript_number_counters(
 organization_id uuid not null, school_id uuid not null, next_number bigint not null check(next_number>=1), updated_at timestamptz not null default now(),
 primary key(organization_id,school_id), foreign key(organization_id,school_id) references public.schools(organization_id,id) on delete restrict
);

create trigger transcript_policies_updated_at before update on public.transcript_calculation_policies for each row execute function public.set_updated_at();
create trigger transcripts_updated_at before update on public.transcripts for each row execute function public.set_updated_at();

insert into public.permissions(code,module,description) values
 ('transcripts.view','transcripts','View transcripts in assigned scope'),
 ('transcripts.manage','transcripts','Create, review, issue, cancel, and configure transcripts'),
 ('transcripts.correct','transcripts','Correct issued transcripts together with transcripts.manage');

create function app_auth.transcript_actor() returns uuid language plpgsql security definer set search_path='' as $$
declare a uuid:=auth.uid(); begin if a is null then raise exception using errcode='42501',message='authentication required'; end if; return a; end $$;

create function app_auth.can_read_transcript(p_transcript uuid,p_protected boolean default false) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.transcripts t join public.students s on s.id=t.student_id where t.id=p_transcript and(
  app_auth.has_permission(t.organization_id,'transcripts.manage',t.school_id,null)
  or(not p_protected and app_auth.has_permission(t.organization_id,'transcripts.view',t.school_id,null))
  or(not p_protected and t.status='issued' and s.status='active' and(app_auth.is_student_self(t.student_id)or app_auth.is_linked_guardian(t.student_id)))));
$$;

create function app_auth.can_read_transcript_policy(p_policy uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.transcript_calculation_policies p where p.id=p_policy and app_auth.has_permission(p.organization_id,'transcripts.manage',p.school_id,null));
$$;

alter table public.transcript_calculation_policies enable row level security; alter table public.transcript_calculation_policies force row level security;
alter table public.transcript_gpa_bands enable row level security; alter table public.transcript_gpa_bands force row level security;
alter table public.transcript_subject_credits enable row level security; alter table public.transcript_subject_credits force row level security;
alter table public.transcript_lineages enable row level security; alter table public.transcript_lineages force row level security;
alter table public.transcripts enable row level security; alter table public.transcripts force row level security;
alter table public.transcript_period_snapshots enable row level security; alter table public.transcript_period_snapshots force row level security;
alter table public.transcript_entry_snapshots enable row level security; alter table public.transcript_entry_snapshots force row level security;
alter table public.transcript_exclusions enable row level security; alter table public.transcript_exclusions force row level security;
alter table public.transcript_number_counters enable row level security; alter table public.transcript_number_counters force row level security;

create policy transcript_policies_select on public.transcript_calculation_policies for select to authenticated using(app_auth.can_read_transcript_policy(id));
create policy transcript_gpa_bands_select on public.transcript_gpa_bands for select to authenticated using(app_auth.can_read_transcript_policy(transcript_calculation_policy_id));
create policy transcript_subject_credits_select on public.transcript_subject_credits for select to authenticated using(app_auth.can_read_transcript_policy(transcript_calculation_policy_id));
create policy transcript_lineages_select on public.transcript_lineages for select to authenticated using(
 app_auth.has_permission(organization_id,'transcripts.view',school_id,null)or app_auth.has_permission(organization_id,'transcripts.manage',school_id,null));
create policy transcripts_select on public.transcripts for select to authenticated using(app_auth.can_read_transcript(id,false));
create policy transcript_periods_select on public.transcript_period_snapshots for select to authenticated using(app_auth.can_read_transcript(transcript_id,false));
create policy transcript_entries_select on public.transcript_entry_snapshots for select to authenticated using(app_auth.can_read_transcript(transcript_id,false));
create policy transcript_exclusions_select on public.transcript_exclusions for select to authenticated using(app_auth.can_read_transcript(transcript_id,true));

revoke all on public.transcript_calculation_policies,public.transcript_gpa_bands,public.transcript_subject_credits,public.transcript_lineages,
 public.transcripts,public.transcript_period_snapshots,public.transcript_entry_snapshots,public.transcript_exclusions,public.transcript_number_counters from public,anon,authenticated;
grant select on public.transcript_calculation_policies,public.transcript_gpa_bands,public.transcript_subject_credits,public.transcript_lineages,
 public.transcript_period_snapshots,public.transcript_entry_snapshots,public.transcript_exclusions to authenticated;
grant select(id,organization_id,school_id,student_id,transcript_lineage_id,version,supersedes_transcript_id,replaces_issued_transcript_id,status,
 transcript_number,transcript_calculation_policy_id,policy_lineage_id,policy_version,policy_name,gpa_scale,gpa_decimal_places,attempted_credits,
 earned_credits,cumulative_gpa,gpa_quality_points,source_fingerprint,snapshot_taken_at,reviewed_at,reviewed_by,review_reason,issued_at,issued_by,
 issuance_reason,superseded_at,superseded_by,supersession_reason,corrected_at,corrected_by,correction_reason,cancelled_at,cancelled_by,
 cancellation_reason,school_code,school_name,student_number,student_display_name,created_at,updated_at,created_by,updated_by)
 on public.transcripts to authenticated;

create function app_auth.enforce_transcript_immutable_child() returns trigger language plpgsql set search_path='' as $$
begin raise exception using errcode='22023',message='transcript snapshot rows are immutable'; end $$;
create trigger transcript_lineages_immutable before update or delete on public.transcript_lineages for each row execute function app_auth.enforce_transcript_immutable_child();
create trigger transcript_periods_immutable before update or delete on public.transcript_period_snapshots for each row execute function app_auth.enforce_transcript_immutable_child();
create trigger transcript_entries_immutable before update or delete on public.transcript_entry_snapshots for each row execute function app_auth.enforce_transcript_immutable_child();
create trigger transcript_exclusions_immutable before update or delete on public.transcript_exclusions for each row execute function app_auth.enforce_transcript_immutable_child();

create function app_auth.enforce_transcript_root_update() returns trigger language plpgsql set search_path='' as $$
begin
 if old.status in('superseded','corrected','cancelled') then raise exception using errcode='22023',message='terminal transcript history is immutable'; end if;
 if old.status='draft' and new.status='draft' then
  if (to_jsonb(new)-array['attempted_credits','earned_credits','cumulative_gpa','gpa_quality_points']) is distinct from
     (to_jsonb(old)-array['attempted_credits','earned_credits','cumulative_gpa','gpa_quality_points'])
   or old.transcript_calculation_policy_id is null
   or old.attempted_credits<>0 or old.earned_credits<>0 or old.gpa_quality_points<>0 or old.cumulative_gpa is not null
  then raise exception using errcode='22023',message='draft transcript identity is immutable'; end if;
  return new;
 end if;
 if old.status='draft' and new.status='reviewed' then
  if (to_jsonb(new)-array['status','reviewed_at','reviewed_by','review_reason','updated_at','updated_by']) is distinct from
     (to_jsonb(old)-array['status','reviewed_at','reviewed_by','review_reason','updated_at','updated_by'])
   or new.reviewed_at is null or new.reviewed_by is null or new.review_reason is null or new.updated_by<>new.reviewed_by
  then raise exception using errcode='22023',message='invalid transcript review transition'; end if;
  return new;
 end if;
 if old.status='reviewed' and new.status='draft' then
  if (to_jsonb(new)-array['status','reviewed_at','reviewed_by','review_reason','updated_at','updated_by']) is distinct from
     (to_jsonb(old)-array['status','reviewed_at','reviewed_by','review_reason','updated_at','updated_by'])
   or new.reviewed_at is not null or new.reviewed_by is not null or new.review_reason is not null
  then raise exception using errcode='22023',message='invalid transcript return transition'; end if;
  return new;
 end if;
 if old.status='reviewed' and new.status='issued' then
  if (to_jsonb(new)-array['status','transcript_number','issued_at','issued_by','issuance_reason','student_date_of_birth','updated_at','updated_by']) is distinct from
     (to_jsonb(old)-array['status','transcript_number','issued_at','issued_by','issuance_reason','student_date_of_birth','updated_at','updated_by'])
   or new.transcript_number is null or new.issued_at is null or new.issued_by is null or new.issuance_reason is null or new.updated_by<>new.issued_by
  then raise exception using errcode='22023',message='invalid transcript issuance transition'; end if;
  return new;
 end if;
 if old.status in('draft','reviewed') and new.status='cancelled' then
  if (to_jsonb(new)-array['status','cancelled_at','cancelled_by','cancellation_reason','updated_at','updated_by']) is distinct from
     (to_jsonb(old)-array['status','cancelled_at','cancelled_by','cancellation_reason','updated_at','updated_by'])
   or new.cancelled_at is null or new.cancelled_by is null or new.cancellation_reason is null or new.updated_by<>new.cancelled_by
  then raise exception using errcode='22023',message='invalid transcript cancellation transition'; end if;
  return new;
 end if;
 if old.status='issued' and new.status='superseded' then
  if (to_jsonb(new)-array['status','superseded_at','superseded_by','supersession_reason','updated_at','updated_by']) is distinct from
     (to_jsonb(old)-array['status','superseded_at','superseded_by','supersession_reason','updated_at','updated_by'])
   or new.superseded_at is null or new.superseded_by is null or new.supersession_reason is null or new.updated_by<>new.superseded_by
  then raise exception using errcode='22023',message='invalid transcript supersession transition'; end if;
  return new;
 end if;
 if old.status='issued' and new.status='corrected' then
  if (to_jsonb(new)-array['status','corrected_at','corrected_by','correction_reason','updated_at','updated_by']) is distinct from
     (to_jsonb(old)-array['status','corrected_at','corrected_by','correction_reason','updated_at','updated_by'])
   or new.corrected_at is null or new.corrected_by is null or new.correction_reason is null or new.updated_by<>new.corrected_by
  then raise exception using errcode='22023',message='invalid transcript correction transition'; end if;
  return new;
 end if;
 raise exception using errcode='22023',message='invalid transcript lifecycle transition';
end $$;
create trigger transcripts_immutable before update on public.transcripts for each row execute function app_auth.enforce_transcript_root_update();
create function app_auth.enforce_transcript_root_delete() returns trigger language plpgsql set search_path='' as $$
begin raise exception using errcode='22023',message='transcript history rows are immutable'; end $$;
create trigger transcripts_delete_immutable before delete on public.transcripts for each row execute function app_auth.enforce_transcript_root_delete();

create function app_auth.enforce_transcript_policy_update() returns trigger language plpgsql set search_path='' as $$
begin
 if old.status='retired' then raise exception using errcode='22023',message='retired transcript policy is immutable'; end if;
 if old.status='draft' and new.status='draft' then
  if (to_jsonb(new)-array['name','gpa_scale','decimal_places','include_fail_in_gpa','include_incomplete_in_gpa','include_withdrawn_in_gpa','updated_at','updated_by']) is distinct from
     (to_jsonb(old)-array['name','gpa_scale','decimal_places','include_fail_in_gpa','include_incomplete_in_gpa','include_withdrawn_in_gpa','updated_at','updated_by'])
  then raise exception using errcode='22023',message='draft transcript policy identity is immutable'; end if;
  return new;
 end if;
 if old.status='draft' and new.status='active' then
  if (to_jsonb(new)-array['status','activated_at','activated_by','updated_at','updated_by']) is distinct from
     (to_jsonb(old)-array['status','activated_at','activated_by','updated_at','updated_by'])
   or new.activated_at is null or new.activated_by is null or new.updated_by<>new.activated_by
  then raise exception using errcode='22023',message='invalid transcript policy activation transition'; end if;
  return new;
 end if;
 if old.status='active' and new.status='retired' then
  if (to_jsonb(new)-array['status','retired_at','retired_by','updated_at','updated_by']) is distinct from
     (to_jsonb(old)-array['status','retired_at','retired_by','updated_at','updated_by'])
   or new.retired_at is null or new.retired_by is null or new.updated_by<>new.retired_by
  then raise exception using errcode='22023',message='invalid transcript policy retirement transition'; end if;
  return new;
 end if;
 raise exception using errcode='22023',message='invalid transcript policy lifecycle transition';
end $$;
create trigger transcript_policies_immutable before update on public.transcript_calculation_policies for each row execute function app_auth.enforce_transcript_policy_update();

create function app_auth.enforce_transcript_policy_child_mutability() returns trigger language plpgsql set search_path='' as $$
declare policy_status public.transcript_policy_status; policy_id uuid; begin
 policy_id:=case when tg_op='INSERT' then new.transcript_calculation_policy_id else old.transcript_calculation_policy_id end;
 select p.status into policy_status from public.transcript_calculation_policies p where p.id=policy_id;
 if policy_status is distinct from 'draft'::public.transcript_policy_status then
  raise exception using errcode='22023',message='active and retired transcript policy rules are immutable';
 end if;
 if tg_op='DELETE' then return old; end if;
 return new;
end $$;
create trigger transcript_gpa_bands_immutable before insert or update or delete on public.transcript_gpa_bands for each row execute function app_auth.enforce_transcript_policy_child_mutability();
create trigger transcript_subject_credits_immutable before insert or update or delete on public.transcript_subject_credits for each row execute function app_auth.enforce_transcript_policy_child_mutability();

create function app_auth.enforce_transcript_lineage() returns trigger language plpgsql security definer set search_path='' as $$
declare p public.transcripts%rowtype; r public.transcripts%rowtype; begin
 if new.version=1 then if new.transcript_lineage_id<>new.id then raise exception using errcode='22023',message='root transcript lineage id must equal transcript id'; end if;
 else select * into p from public.transcripts where id=new.supersedes_transcript_id;
  if p.id is null or(p.organization_id,p.school_id,p.student_id,p.transcript_lineage_id,p.version+1) is distinct from(new.organization_id,new.school_id,new.student_id,new.transcript_lineage_id,new.version)
  then raise exception using errcode='22023',message='invalid transcript lineage'; end if; end if;
 if new.replaces_issued_transcript_id is not null then select * into r from public.transcripts where id=new.replaces_issued_transcript_id;
  if r.id is null or r.transcript_lineage_id<>new.transcript_lineage_id or r.status<>'issued' then raise exception using errcode='22023',message='invalid issued transcript replacement target'; end if; end if;
 return new;
end $$;
create constraint trigger transcripts_lineage_exact after insert on public.transcripts deferrable initially deferred for each row execute function app_auth.enforce_transcript_lineage();

create function app_auth.write_transcript_change(cmd uuid,o uuid,actor uuid,action_name text,entity_name text,entity uuid,before_row jsonb,after_row jsonb,payload jsonb,emit boolean default true)
returns void language plpgsql security definer set search_path='' as $$
declare b jsonb:=before_row; a jsonb:=after_row; begin
 if b is not null and b?'student_date_of_birth' then b:=jsonb_set(b,'{student_date_of_birth}','"[REDACTED]"'); end if;
 if a is not null and a?'student_date_of_birth' then a:=jsonb_set(a,'{student_date_of_birth}','"[REDACTED]"'); end if;
 insert into public.audit_log(command_id,organization_id,actor_user_id,action,entity_type,entity_id,before_data,after_data) values(cmd,o,actor,action_name,entity_name,entity,b,a);
 if emit then insert into public.event_outbox(command_id,organization_id,event_type,aggregate_type,aggregate_id,payload)
 values(cmd,o,action_name,entity_name,entity,jsonb_strip_nulls(coalesce(payload,'{}')||jsonb_build_object('command_id',cmd,'actor_user_id',actor,'organization_id',o,'aggregate_id',entity))); end if;
end $$;

create function app_auth.assert_transcript_manage(o uuid,s uuid,p_correct boolean default false) returns void
language plpgsql security definer set search_path='' as $$ begin
 if not app_auth.has_permission(o,'transcripts.manage',s,null) then raise exception using errcode='42501',message='transcripts.manage permission is required'; end if;
 if p_correct and not app_auth.has_permission(o,'transcripts.correct',s,null) then raise exception using errcode='42501',message='transcripts.correct permission is required'; end if;
end $$;

create function app_auth.validate_transcript_policy_inputs(p_scale numeric,p_places smallint,p_bands public.transcript_gpa_band_input[],p_credits public.transcript_subject_credit_input[]) returns void
language plpgsql security definer set search_path='' as $$
declare n integer; begin
 if p_scale is null or p_scale<=0 or p_places not between 0 and 4 or p_bands is null or cardinality(p_bands) not between 1 and 100 or p_credits is null then
  raise exception using errcode='22023',message='valid policy scale, precision, bands, and credits are required'; end if;
 if exists(select 1 from unnest(p_bands) b where b is null or(b).sequence is null or(b).lower_bound is null or(b).upper_bound is null or(b).result_state is null or(b).grade_points is null
  or(b).lower_bound<0 or(b).upper_bound>100 or(b).lower_bound>=(b).upper_bound or(b).grade_points<0 or(b).grade_points>p_scale or((b).result_state='non_credit' and(b).grade_points<>0))
 then raise exception using errcode='22023',message='invalid GPA band'; end if;
 select count(*) into n from unnest(p_bands); if n<>(select count(distinct(b).sequence) from unnest(p_bands)b) then raise exception using errcode='22023',message='duplicate GPA band sequence'; end if;
 if exists(select 1 from(select(b).*,lag((b).upper_bound)over(order by(b).sequence) prev,row_number()over(order by(b).sequence) rn from unnest(p_bands)b)q
  where sequence<>rn or(sequence=1 and lower_bound<>0)or(sequence>1 and lower_bound<>prev))
  or(select(b).upper_bound from unnest(p_bands)b order by(b).sequence desc limit 1)<>100
 then raise exception using errcode='22023',message='GPA bands must be dense, contiguous, and cover zero through 100'; end if;
 if exists(select 1 from unnest(p_credits)c where c is null or(c).subject_id is null or(c).attempted_credits is null or(c).earned_credits is null or(c).attempted_credits<0 or(c).earned_credits<0 or(c).earned_credits>(c).attempted_credits)
  or(select count(*) from unnest(p_credits))<>(select count(distinct(c).subject_id) from unnest(p_credits)c)
 then raise exception using errcode='22023',message='invalid or duplicate subject credits'; end if;
end $$;

create function app_auth.insert_transcript_policy_children(p public.transcript_calculation_policies,p_bands public.transcript_gpa_band_input[],p_credits public.transcript_subject_credit_input[],a uuid,cmd uuid) returns void
language plpgsql security definer set search_path='' as $$
declare b public.transcript_gpa_band_input; c public.transcript_subject_credit_input; x uuid; begin
 for b in select(z).* from unnest(p_bands)z order by(z).sequence loop
  insert into public.transcript_gpa_bands(organization_id,school_id,transcript_calculation_policy_id,sequence,lower_bound,upper_bound,result_state,grade_points,created_by)
  values(p.organization_id,p.school_id,p.id,b.sequence,b.lower_bound,b.upper_bound,b.result_state,b.grade_points,a) returning id into x;
  perform app_auth.write_transcript_change(cmd,p.organization_id,a,'transcript_policy.band_snapshotted','transcript_gpa_band',x,null,(select to_jsonb(q)from public.transcript_gpa_bands q where q.id=x),null,false);
 end loop;
 for c in select(z).* from unnest(p_credits)z order by(z).subject_id loop
  if not exists(select 1 from public.subjects s where s.id=c.subject_id and(s.organization_id,s.school_id)=(p.organization_id,p.school_id)) then raise exception using errcode='22023',message='subject credit scope mismatch'; end if;
  insert into public.transcript_subject_credits(organization_id,school_id,transcript_calculation_policy_id,subject_id,attempted_credits,earned_credits,created_by)
  values(p.organization_id,p.school_id,p.id,c.subject_id,c.attempted_credits,c.earned_credits,a) returning id into x;
  perform app_auth.write_transcript_change(cmd,p.organization_id,a,'transcript_policy.credit_snapshotted','transcript_subject_credit',x,null,(select to_jsonb(q)from public.transcript_subject_credits q where q.id=x),null,false);
 end loop;
end $$;

create function public.create_transcript_calculation_policy(school_id uuid,name text,gpa_scale numeric,decimal_places smallint,include_fail_in_gpa boolean,include_incomplete_in_gpa boolean,include_withdrawn_in_gpa boolean,bands public.transcript_gpa_band_input[],subject_credits public.transcript_subject_credit_input[]) returns uuid
language plpgsql security definer set search_path='' as $$
declare a uuid:=app_auth.transcript_actor(); s public.schools%rowtype; p public.transcript_calculation_policies%rowtype; cmd uuid:=gen_random_uuid(); new_id uuid:=gen_random_uuid(); begin
 select * into s from public.schools where id=school_id; if not found then raise exception using errcode='P0002',message='school not found'; end if;
 perform app_auth.assert_transcript_manage(s.organization_id,s.id); perform app_auth.validate_transcript_policy_inputs(gpa_scale,decimal_places,bands,subject_credits);
 perform app_auth.lock_academic_snapshot_domain(s.organization_id); perform 1 from public.organizations where id=s.organization_id for update; perform 1 from public.schools where id=s.id for update;
 insert into public.transcript_calculation_policies(id,organization_id,school_id,policy_lineage_id,version,name,gpa_scale,decimal_places,include_fail_in_gpa,include_incomplete_in_gpa,include_withdrawn_in_gpa,created_by,updated_by)
 values(new_id,s.organization_id,s.id,new_id,1,btrim(name),gpa_scale,decimal_places,include_fail_in_gpa,include_incomplete_in_gpa,include_withdrawn_in_gpa,a,a) returning * into p;
 perform app_auth.insert_transcript_policy_children(p,bands,subject_credits,a,cmd);
 perform app_auth.write_transcript_change(cmd,p.organization_id,a,'transcript_policy.draft_created','transcript_calculation_policy',p.id,null,to_jsonb(p),jsonb_build_object('school_id',p.school_id,'policy_lineage_id',p.policy_lineage_id,'version',p.version)); return p.id;
end $$;

create function public.update_draft_transcript_calculation_policy(id uuid,name text,gpa_scale numeric,decimal_places smallint,include_fail_in_gpa boolean,include_incomplete_in_gpa boolean,include_withdrawn_in_gpa boolean,bands public.transcript_gpa_band_input[],subject_credits public.transcript_subject_credit_input[]) returns uuid
language plpgsql security definer set search_path='' as $$
declare a uuid:=app_auth.transcript_actor(); p public.transcript_calculation_policies%rowtype; oldj jsonb; cmd uuid:=gen_random_uuid(); old_band public.transcript_gpa_bands%rowtype; old_credit public.transcript_subject_credits%rowtype; begin
 select * into p from public.transcript_calculation_policies where transcript_calculation_policies.id=update_draft_transcript_calculation_policy.id; if not found then raise exception using errcode='P0002',message='policy not found'; end if;
 perform app_auth.assert_transcript_manage(p.organization_id,p.school_id); perform app_auth.validate_transcript_policy_inputs(gpa_scale,decimal_places,bands,subject_credits);
 perform app_auth.lock_academic_snapshot_domain(p.organization_id); perform 1 from public.organizations o where o.id=p.organization_id for update; perform 1 from public.schools s where s.id=p.school_id for update;
 select * into p from public.transcript_calculation_policies where transcript_calculation_policies.id=update_draft_transcript_calculation_policy.id for update; if p.status<>'draft' then raise exception using errcode='22023',message='draft policy required'; end if; oldj:=to_jsonb(p);
 for old_band in select * from public.transcript_gpa_bands where transcript_calculation_policy_id=p.id order by sequence,id loop
  perform app_auth.write_transcript_change(cmd,p.organization_id,a,'transcript_policy.band_removed','transcript_gpa_band',old_band.id,to_jsonb(old_band),null,null,false);
 end loop;
 for old_credit in select * from public.transcript_subject_credits where transcript_calculation_policy_id=p.id order by subject_id,id loop
  perform app_auth.write_transcript_change(cmd,p.organization_id,a,'transcript_policy.credit_removed','transcript_subject_credit',old_credit.id,to_jsonb(old_credit),null,null,false);
 end loop;
 delete from public.transcript_gpa_bands where transcript_calculation_policy_id=p.id; delete from public.transcript_subject_credits where transcript_calculation_policy_id=p.id;
 update public.transcript_calculation_policies set name=btrim(update_draft_transcript_calculation_policy.name),gpa_scale=update_draft_transcript_calculation_policy.gpa_scale,decimal_places=update_draft_transcript_calculation_policy.decimal_places,include_fail_in_gpa=update_draft_transcript_calculation_policy.include_fail_in_gpa,include_incomplete_in_gpa=update_draft_transcript_calculation_policy.include_incomplete_in_gpa,include_withdrawn_in_gpa=update_draft_transcript_calculation_policy.include_withdrawn_in_gpa,updated_by=a where transcript_calculation_policies.id=p.id returning * into p;
 perform app_auth.insert_transcript_policy_children(p,bands,subject_credits,a,cmd); perform app_auth.write_transcript_change(cmd,p.organization_id,a,'transcript_policy.draft_updated','transcript_calculation_policy',p.id,oldj,to_jsonb(p),jsonb_build_object('school_id',p.school_id,'policy_lineage_id',p.policy_lineage_id,'version',p.version)); return p.id;
end $$;

create function public.activate_transcript_calculation_policy(id uuid) returns uuid language plpgsql security definer set search_path='' as $$
declare a uuid:=app_auth.transcript_actor(); p public.transcript_calculation_policies%rowtype; oldj jsonb; cmd uuid:=gen_random_uuid(); begin
 select * into p from public.transcript_calculation_policies where transcript_calculation_policies.id=activate_transcript_calculation_policy.id; if not found then raise exception using errcode='P0002',message='policy not found'; end if;
 perform app_auth.assert_transcript_manage(p.organization_id,p.school_id); perform app_auth.lock_academic_snapshot_domain(p.organization_id); perform 1 from public.schools s where s.id=p.school_id for update;
 select * into p from public.transcript_calculation_policies where transcript_calculation_policies.id=activate_transcript_calculation_policy.id for update; if p.status<>'draft' then raise exception using errcode='22023',message='draft policy required'; end if;
 if exists(select 1 from public.transcript_calculation_policies q where q.school_id=p.school_id and q.status='active') then raise exception using errcode='22023',message='retire the active policy before activation'; end if;
 oldj:=to_jsonb(p); update public.transcript_calculation_policies set status='active',activated_at=now(),activated_by=a,updated_by=a where transcript_calculation_policies.id=p.id returning * into p;
 perform app_auth.write_transcript_change(cmd,p.organization_id,a,'transcript_policy.activated','transcript_calculation_policy',p.id,oldj,to_jsonb(p),jsonb_build_object('school_id',p.school_id,'policy_lineage_id',p.policy_lineage_id,'version',p.version)); return p.id;
end $$;

create function public.retire_transcript_calculation_policy(id uuid) returns uuid language plpgsql security definer set search_path='' as $$
declare a uuid:=app_auth.transcript_actor(); p public.transcript_calculation_policies%rowtype; oldj jsonb; cmd uuid:=gen_random_uuid(); begin
 select * into p from public.transcript_calculation_policies where transcript_calculation_policies.id=retire_transcript_calculation_policy.id; if not found then raise exception using errcode='P0002',message='policy not found'; end if;
 perform app_auth.assert_transcript_manage(p.organization_id,p.school_id); perform app_auth.lock_academic_snapshot_domain(p.organization_id); perform 1 from public.schools s where s.id=p.school_id for update; select * into p from public.transcript_calculation_policies where transcript_calculation_policies.id=retire_transcript_calculation_policy.id for update;
 if p.status<>'active' then raise exception using errcode='22023',message='active policy required'; end if; oldj:=to_jsonb(p);
 update public.transcript_calculation_policies set status='retired',retired_at=now(),retired_by=a,updated_by=a where transcript_calculation_policies.id=p.id returning * into p;
 perform app_auth.write_transcript_change(cmd,p.organization_id,a,'transcript_policy.retired','transcript_calculation_policy',p.id,oldj,to_jsonb(p),jsonb_build_object('school_id',p.school_id,'policy_lineage_id',p.policy_lineage_id,'version',p.version)); return p.id;
end $$;

create function public.revise_transcript_calculation_policy(id uuid,replacement_name text,replacement_gpa_scale numeric,replacement_decimal_places smallint,replacement_include_fail_in_gpa boolean,replacement_include_incomplete_in_gpa boolean,replacement_include_withdrawn_in_gpa boolean,replacement_bands public.transcript_gpa_band_input[],replacement_subject_credits public.transcript_subject_credit_input[]) returns uuid
language plpgsql security definer set search_path='' as $$
declare a uuid:=app_auth.transcript_actor(); p public.transcript_calculation_policies%rowtype; n public.transcript_calculation_policies%rowtype; cmd uuid:=gen_random_uuid(); begin
 select * into p from public.transcript_calculation_policies where transcript_calculation_policies.id=revise_transcript_calculation_policy.id; if not found then raise exception using errcode='P0002',message='policy not found'; end if;
 perform app_auth.assert_transcript_manage(p.organization_id,p.school_id); perform app_auth.validate_transcript_policy_inputs(replacement_gpa_scale,replacement_decimal_places,replacement_bands,replacement_subject_credits);
 perform app_auth.lock_academic_snapshot_domain(p.organization_id); perform 1 from public.schools s where s.id=p.school_id for update; perform 1 from public.transcript_calculation_policies q where q.policy_lineage_id=p.policy_lineage_id order by q.version for update;
 select * into p from public.transcript_calculation_policies where transcript_calculation_policies.id=revise_transcript_calculation_policy.id for update; if p.status not in('active','retired') then raise exception using errcode='22023',message='active or retired policy required'; end if;
 insert into public.transcript_calculation_policies(organization_id,school_id,policy_lineage_id,version,supersedes_policy_id,name,gpa_scale,decimal_places,include_fail_in_gpa,include_incomplete_in_gpa,include_withdrawn_in_gpa,created_by,updated_by)
 values(p.organization_id,p.school_id,p.policy_lineage_id,p.version+1,p.id,btrim(replacement_name),replacement_gpa_scale,replacement_decimal_places,replacement_include_fail_in_gpa,replacement_include_incomplete_in_gpa,replacement_include_withdrawn_in_gpa,a,a) returning * into n;
 perform app_auth.insert_transcript_policy_children(n,replacement_bands,replacement_subject_credits,a,cmd); perform app_auth.write_transcript_change(cmd,n.organization_id,a,'transcript_policy.revision_created','transcript_calculation_policy',n.id,null,to_jsonb(n),jsonb_build_object('school_id',n.school_id,'policy_lineage_id',n.policy_lineage_id,'version',n.version)); return n.id;
exception when unique_violation then raise exception using errcode='40001',message='transcript policy lineage changed; retry';
end $$;

create function app_auth.transcript_source_fingerprint(p_student uuid,p_school uuid,p_terms public.transcript_term_input[],p_exclusions public.transcript_exclusion_input[],p_policy uuid) returns bytea
language sql stable security definer set search_path='' as $$
 select extensions.digest(convert_to(coalesce(string_agg(v,'|' order by v),'')||case when p_policy is null then '|policy:none' else '' end,'UTF8'),'sha256') from(
  select 'card:'||r.id||':'||r.version||':'||encode(r.source_fingerprint,'hex') v
   from unnest(p_terms)z join public.report_cards r on r.academic_term_id=(z).academic_term_id and r.student_id=p_student and r.school_id=p_school and r.status='published'
  union all select 'grade:'||g.id||':'||g.rounded_percentage||':'||g.grade_label||':'||g.result_state||':'||encode(g.source_term_grade_fingerprint,'hex')
   from unnest(p_terms)z join public.report_cards r on r.academic_term_id=(z).academic_term_id and r.student_id=p_student and r.school_id=p_school and r.status='published'
   join public.report_card_grade_snapshots g on g.report_card_id=r.id and g.subject_id is not null
   where not exists(select 1 from unnest(p_exclusions)e where(e).academic_term_id=r.academic_term_id and(e).subject_id=g.subject_id)
  union all select 'exclusion:'||(e).academic_term_id||':'||coalesce((e).subject_id::text,'')||':'||btrim((e).reason) from unnest(p_exclusions)e
  union all select 'policy:'||p.id||':'||p.policy_lineage_id||':'||p.version||':'||p.name||':'||p.gpa_scale||':'||p.decimal_places||':'||p.include_fail_in_gpa||':'||p.include_incomplete_in_gpa||':'||p.include_withdrawn_in_gpa
   from public.transcript_calculation_policies p where p.id=p_policy
  union all select 'policy-band:'||lpad(b.sequence::text,10,'0')||':'||b.lower_bound||':'||b.upper_bound||':'||b.result_state||':'||b.grade_points
   from public.transcript_gpa_bands b where b.transcript_calculation_policy_id=p_policy
  union all select 'policy-credit:'||c.subject_id||':'||c.attempted_credits||':'||c.earned_credits
   from public.transcript_subject_credits c where c.transcript_calculation_policy_id=p_policy
 )q;
$$;

create function app_auth.lock_transcript_context(p_student uuid,p_school uuid,p_terms uuid[]) returns void
language plpgsql security definer set search_path='' as $$ declare o uuid; begin
 select s.organization_id into o from public.schools s where s.id=p_school; if o is null then raise exception using errcode='P0002',message='school not found'; end if;
 perform app_auth.lock_academic_snapshot_domain(o); perform 1 from public.organizations where id=o for update; perform 1 from public.schools where id=p_school for update; perform 1 from public.students where id=p_student for update;
 perform 1 from public.academic_years y where y.id in(select t.academic_year_id from public.academic_terms t where t.id=any(p_terms)) order by y.id for update;
 perform 1 from public.academic_terms t where t.id=any(p_terms) order by t.id for update;
 perform 1 from public.sections s where s.id in(select r.section_id from public.report_cards r where r.student_id=p_student and r.school_id=p_school and r.academic_term_id=any(p_terms) and r.status='published') order by s.id for update;
 perform 1 from public.report_cards r where r.student_id=p_student and r.school_id=p_school and r.academic_term_id=any(p_terms) order by r.lineage_id,r.version,r.id for update;
 perform 1 from public.report_card_grade_snapshots g join public.report_cards r on r.id=g.report_card_id where r.student_id=p_student and r.school_id=p_school and r.academic_term_id=any(p_terms) order by r.academic_term_id,g.subject_id nulls first,g.id for update of g;
 perform 1 from public.transcript_lineages l where l.student_id=p_student and l.school_id=p_school for update;
 perform 1 from public.transcripts t join public.transcript_lineages l on l.id=t.transcript_lineage_id where l.student_id=p_student and l.school_id=p_school order by t.version,t.id for update of t;
 perform 1 from public.transcript_calculation_policies p where p.school_id=p_school order by p.policy_lineage_id,p.version,p.id for update;
end $$;

create function app_auth.build_transcript(p_student uuid,p_school uuid,p_terms public.transcript_term_input[],p_exclusions public.transcript_exclusion_input[],p_replaces uuid,p_actor uuid,p_cmd uuid,p_operation_reason text default null) returns uuid
language plpgsql security definer set search_path='' as $$
declare st public.students%rowtype; sc public.schools%rowtype; l public.transcript_lineages%rowtype; prev public.transcripts%rowtype; tr public.transcripts%rowtype;
 pol public.transcript_calculation_policies%rowtype; ti public.transcript_term_input; ex public.transcript_exclusion_input; rc public.report_cards%rowtype; sec public.sections%rowtype; gl public.grade_levels%rowtype; ay public.academic_years%rowtype;
 g public.report_card_grade_snapshots%rowtype; cr public.transcript_subject_credits%rowtype; band public.transcript_gpa_bands%rowtype; pid uuid; eid uuid; seq integer:=0; eseq integer; fp bytea;
 attempted numeric:=0; earned numeric:=0; quality numeric:=0; divisor numeric:=0; state public.transcript_result_state; att numeric; ern numeric; points numeric;
 term_ids uuid[]; new_id uuid:=gen_random_uuid(); ver integer; predecessor uuid; display_name text;
begin
 if p_terms is null or cardinality(p_terms) not between 1 and 100 or exists(select 1 from unnest(p_terms)z where z is null or(z).academic_term_id is null)
  or(select count(*)from unnest(p_terms))<>(select count(distinct(z).academic_term_id)from unnest(p_terms)z)
 then raise exception using errcode='22023',message='one to 100 distinct academic terms are required'; end if;
 if p_exclusions is null or exists(select 1 from unnest(p_exclusions)e where e is null or(e).academic_term_id is null or length(btrim(coalesce((e).reason,'')))not between 1 and 500)
 then raise exception using errcode='22023',message='valid bounded exclusions are required'; end if;
 if(select count(*)from unnest(p_exclusions)e)<>(select count(*)from(select distinct(e).academic_term_id,(e).subject_id from unnest(p_exclusions)e)q)
 then raise exception using errcode='22023',message='duplicate exclusion'; end if;
 select array_agg((z).academic_term_id order by(z).academic_term_id) into term_ids from unnest(p_terms)z;
 select * into sc from public.schools where id=p_school; select * into st from public.students where id=p_student;
 if sc.id is null or st.id is null then raise exception using errcode='P0002',message='school or student not found'; end if;
 if sc.organization_id<>st.organization_id then raise exception using errcode='22023',message='student and school must share organization'; end if;
 perform app_auth.assert_transcript_manage(sc.organization_id,sc.id); perform app_auth.lock_transcript_context(st.id,sc.id,term_ids);
 select * into sc from public.schools where id=p_school for update; select * into st from public.students where id=p_student for update;
 if exists(select 1 from unnest(p_terms)z left join public.academic_terms t on t.id=(z).academic_term_id left join public.academic_years y on y.id=t.academic_year_id
  where t.id is null or(y.organization_id,y.school_id)<>(sc.organization_id,sc.id)) then raise exception using errcode='22023',message='all terms must belong to the issuing school'; end if;
 if exists(select 1 from unnest(p_terms)z where(select count(*)from public.report_cards r where r.student_id=st.id and r.school_id=sc.id and r.academic_term_id=(z).academic_term_id and r.status='published')<>1)
 then raise exception using errcode='22023',message='each included term requires exactly one live published report card'; end if;
 if exists(select 1 from unnest(p_exclusions)e where(e).subject_id is null and(e).academic_term_id=any(term_ids)) then raise exception using errcode='22023',message='an included term cannot also be excluded'; end if;
 if exists(select 1 from unnest(p_exclusions)e where(e).subject_id is not null and not exists(select 1 from public.report_cards r join public.report_card_grade_snapshots gs on gs.report_card_id=r.id where r.student_id=st.id and r.school_id=sc.id and r.status='published' and r.academic_term_id=(e).academic_term_id and gs.subject_id=(e).subject_id))
 then raise exception using errcode='22023',message='subject exclusion must identify an eligible report-card subject'; end if;
 if exists(select 1 from public.report_cards r join public.academic_terms t on t.id=r.academic_term_id where r.student_id=st.id and r.school_id=sc.id and r.status='published'
  and exists(select 1 from public.academic_terms x where x.id=any(term_ids) and x.academic_year_id=t.academic_year_id)
  and t.sequence between(select min(x.sequence)from public.academic_terms x where x.id=any(term_ids)and x.academic_year_id=t.academic_year_id)
   and(select max(x.sequence)from public.academic_terms x where x.id=any(term_ids)and x.academic_year_id=t.academic_year_id)
  and not(r.academic_term_id=any(term_ids)) and not exists(select 1 from unnest(p_exclusions)e where(e).academic_term_id=r.academic_term_id and(e).subject_id is null))
 then raise exception using errcode='22023',message='eligible published term gap requires explicit exclusion'; end if;
 select * into pol from public.transcript_calculation_policies where school_id=sc.id and status='active';
 fp:=app_auth.transcript_source_fingerprint(st.id,sc.id,p_terms,p_exclusions,pol.id);
 select * into l from public.transcript_lineages where school_id=sc.id and student_id=st.id for update;
 if l.id is null then insert into public.transcript_lineages(id,organization_id,school_id,student_id,created_by) values(new_id,sc.organization_id,sc.id,st.id,p_actor) returning * into l; ver:=1; predecessor:=null;
 else select * into prev from public.transcripts where transcript_lineage_id=l.id order by version desc limit 1 for update; ver:=coalesce(prev.version,0)+1; predecessor:=prev.id; end if;
 if exists(select 1 from public.transcripts where transcript_lineage_id=l.id and status in('draft','reviewed')) then raise exception using errcode='40001',message='transcript candidate already exists; retry'; end if;
 if p_replaces is not null and not exists(select 1 from public.transcripts x where x.id=p_replaces and x.transcript_lineage_id=l.id and x.status='issued') then raise exception using errcode='40001',message='issued transcript replacement target changed; retry'; end if;
 display_name:=btrim(concat_ws(' ',st.first_name,st.middle_name,st.last_name));
 insert into public.transcripts(id,organization_id,school_id,student_id,transcript_lineage_id,version,supersedes_transcript_id,replaces_issued_transcript_id,
  transcript_calculation_policy_id,policy_lineage_id,policy_version,policy_name,gpa_scale,gpa_decimal_places,attempted_credits,earned_credits,cumulative_gpa,gpa_quality_points,
  source_fingerprint,school_code,school_name,student_number,student_display_name,created_by,updated_by)
 values(new_id,sc.organization_id,sc.id,st.id,l.id,ver,predecessor,p_replaces,pol.id,pol.policy_lineage_id,pol.version,pol.name,pol.gpa_scale,pol.decimal_places,
  case when pol.id is null then null else 0 end,case when pol.id is null then null else 0 end,null,case when pol.id is null then null else 0 end,
  fp,sc.code,sc.name,st.student_number,display_name,p_actor,p_actor) returning * into tr;
 for ti in select(z).* from unnest(p_terms)z join public.academic_terms t on t.id=(z).academic_term_id join public.academic_years y on y.id=t.academic_year_id order by y.start_date,t.sequence,t.start_date,t.id loop
  select * into rc from public.report_cards r where r.student_id=st.id and r.school_id=sc.id and r.academic_term_id=ti.academic_term_id and r.status='published';
  select * into sec from public.sections where id=rc.section_id; select * into gl from public.grade_levels where id=sec.grade_level_id; select * into ay from public.academic_years where id=rc.academic_year_id; seq:=seq+1;
  insert into public.transcript_period_snapshots(organization_id,school_id,student_id,transcript_id,sequence,report_card_id,report_card_lineage_id,report_card_version,report_card_number,academic_year_id,academic_term_id,campus_id,section_id,grade_level_id,academic_year_name,academic_term_name,campus_code,campus_name,section_code,section_name,grade_level_code,grade_level_name,academic_term_sequence,term_start_date,term_end_date,source_report_card_fingerprint,created_by)
  values(tr.organization_id,tr.school_id,tr.student_id,tr.id,seq,rc.id,rc.lineage_id,rc.version,rc.report_card_number,rc.academic_year_id,rc.academic_term_id,rc.campus_id,rc.section_id,sec.grade_level_id,rc.academic_year_name,rc.academic_term_name,rc.campus_code,rc.campus_name,rc.section_code,rc.section_name,rc.grade_level_code,rc.grade_level_name,rc.academic_term_sequence,rc.term_start_date,rc.term_end_date,rc.source_fingerprint,p_actor) returning id into pid;
  perform app_auth.write_transcript_change(p_cmd,tr.organization_id,p_actor,'transcript.period_snapshotted','transcript_period_snapshot',pid,null,(select to_jsonb(q)from public.transcript_period_snapshots q where q.id=pid),null,false);
  eseq:=0;
  for g in select q.* from public.report_card_grade_snapshots q where q.report_card_id=rc.id and q.subject_id is not null and not exists(select 1 from unnest(p_exclusions)e where(e).academic_term_id=rc.academic_term_id and(e).subject_id=q.subject_id) order by lower(q.subject_code),lower(q.subject_name),q.subject_id loop
   eseq:=eseq+1; state:=g.result_state::text::public.transcript_result_state; att:=null;ern:=null;points:=null;
   if state='transferred' then raise exception using errcode='22023',message='transferred transcript results are unsupported'; end if;
   if pol.id is not null then select * into cr from public.transcript_subject_credits c where c.transcript_calculation_policy_id=pol.id and c.subject_id=g.subject_id;
    if cr.id is not null then select * into band from public.transcript_gpa_bands b where b.transcript_calculation_policy_id=pol.id and(g.rounded_percentage>=b.lower_bound and(g.rounded_percentage<b.upper_bound or b.upper_bound=100)) order by b.sequence limit 1;
     att:=case when state='non_credit' or(state='incomplete' and not pol.include_incomplete_in_gpa)or(state='withdrawn' and not pol.include_withdrawn_in_gpa) then 0 else cr.attempted_credits end;
     ern:=case when state='pass' then cr.earned_credits else 0 end; points:=case when state='non_credit' then 0 else band.grade_points end; attempted:=attempted+att; earned:=earned+ern;
     if state='pass' or(state='fail' and pol.include_fail_in_gpa)or(state='incomplete' and pol.include_incomplete_in_gpa)or(state='withdrawn' and pol.include_withdrawn_in_gpa) then quality:=quality+att*points; divisor:=divisor+att; end if;
    end if; end if;
   insert into public.transcript_entry_snapshots(organization_id,school_id,student_id,transcript_id,transcript_period_snapshot_id,academic_term_id,sequence,report_card_id,report_card_grade_snapshot_id,subject_id,subject_code,subject_name,raw_percentage,rounded_percentage,grade_label,result_state,term_grading_configuration_id,term_grade_set_id,term_grade_record_id,term_grade_calculation_id,grade_scale_id,grade_scale_band_id,source_term_grade_fingerprint,attempted_credits,earned_credits,grade_points,quality_points,created_by)
   values(tr.organization_id,tr.school_id,tr.student_id,tr.id,pid,rc.academic_term_id,eseq,rc.id,g.id,g.subject_id,g.subject_code,g.subject_name,g.raw_percentage,g.rounded_percentage,g.grade_label,state,g.term_grading_configuration_id,g.term_grade_set_id,g.term_grade_record_id,g.term_grade_calculation_id,g.grade_scale_id,g.grade_scale_band_id,g.source_term_grade_fingerprint,att,ern,points,case when att is null then null else att*points end,p_actor) returning id into eid;
   perform app_auth.write_transcript_change(p_cmd,tr.organization_id,p_actor,'transcript.entry_snapshotted','transcript_entry_snapshot',eid,null,(select to_jsonb(q)from public.transcript_entry_snapshots q where q.id=eid),null,false);
  end loop;
  if eseq=0 then raise exception using errcode='22023',message='included term must retain at least one subject'; end if;
 end loop;
 for ex in select(z).* from unnest(p_exclusions)z order by(z).academic_term_id,(z).subject_id nulls first loop
  if ex.subject_id is null then insert into public.transcript_exclusions(organization_id,school_id,student_id,transcript_id,exclusion_type,academic_term_id,reason,excluded_by) values(tr.organization_id,tr.school_id,tr.student_id,tr.id,'term',ex.academic_term_id,btrim(ex.reason),p_actor) returning id into eid;
  else select r.id,gs.id into rc.id,g.id from public.report_cards r join public.report_card_grade_snapshots gs on gs.report_card_id=r.id and gs.subject_id=ex.subject_id where r.student_id=st.id and r.school_id=sc.id and r.academic_term_id=ex.academic_term_id and r.status='published';
   insert into public.transcript_exclusions(organization_id,school_id,student_id,transcript_id,exclusion_type,academic_term_id,subject_id,report_card_id,report_card_grade_snapshot_id,reason,excluded_by) values(tr.organization_id,tr.school_id,tr.student_id,tr.id,'subject',ex.academic_term_id,ex.subject_id,rc.id,g.id,btrim(ex.reason),p_actor) returning id into eid; end if;
  perform app_auth.write_transcript_change(p_cmd,tr.organization_id,p_actor,'transcript.exclusion_recorded','transcript_exclusion',eid,null,(select to_jsonb(q)from public.transcript_exclusions q where q.id=eid),null,false);
 end loop;
 if pol.id is not null then update public.transcripts set attempted_credits=attempted,earned_credits=earned,gpa_quality_points=quality,cumulative_gpa=case when divisor=0 then null else round(quality/divisor,pol.decimal_places)end where id=tr.id returning * into tr; end if;
 perform app_auth.write_transcript_change(p_cmd,tr.organization_id,p_actor,case when p_replaces is null then 'transcript.draft_created' else 'transcript.rebuild_started'end,'transcript',tr.id,null,to_jsonb(tr)||case when p_operation_reason is null then '{}'::jsonb else jsonb_build_object('rebuild_reason',btrim(p_operation_reason))end,jsonb_build_object('school_id',tr.school_id,'student_id',tr.student_id,'lineage_id',tr.transcript_lineage_id,'version',tr.version,'term_count',seq,'has_policy',pol.id is not null)); return tr.id;
exception when unique_violation then raise exception using errcode='40001',message='transcript lineage changed; retry';
end $$;

create function public.create_transcript(student_id uuid,school_id uuid,terms public.transcript_term_input[],exclusions public.transcript_exclusion_input[] default '{}') returns uuid language plpgsql security definer set search_path='' as $$
declare a uuid:=app_auth.transcript_actor(); cmd uuid:=gen_random_uuid(); begin return app_auth.build_transcript(student_id,school_id,terms,exclusions,null,a,cmd); end $$;

create function public.rebuild_transcript(transcript_id uuid,terms public.transcript_term_input[],exclusions public.transcript_exclusion_input[] default '{}',rebuild_reason text default null) returns uuid
language plpgsql security definer set search_path='' as $$ declare a uuid:=app_auth.transcript_actor(); t public.transcripts%rowtype; cmd uuid:=gen_random_uuid(); n uuid; begin
 if length(btrim(coalesce(rebuild_reason,'')))not between 1 and 500 then raise exception using errcode='22023',message='bounded rebuild reason required'; end if;
 select * into t from public.transcripts where id=transcript_id; if not found then raise exception using errcode='P0002',message='transcript not found'; end if; if t.status<>'issued' then raise exception using errcode='22023',message='current issued transcript required'; end if;
 n:=app_auth.build_transcript(t.student_id,t.school_id,terms,exclusions,t.id,a,cmd,rebuild_reason); return n; end $$;

create function app_auth.assert_transcript_ready(p_id uuid) returns void language plpgsql security definer set search_path='' as $$
declare t public.transcripts%rowtype; terms public.transcript_term_input[]; exclusions public.transcript_exclusion_input[]; fp bytea; begin
 select * into t from public.transcripts where id=p_id; if t.status not in('draft','reviewed') then raise exception using errcode='22023',message='draft or reviewed transcript required'; end if;
 if exists(select 1 from public.transcript_period_snapshots p left join public.report_cards r on r.id=p.report_card_id where p.transcript_id=t.id and(r.id is null or r.status<>'published' or r.source_fingerprint is distinct from p.source_report_card_fingerprint))
 then raise exception using errcode='40001',message='transcript sources changed; rebuild and retry'; end if;
 if t.transcript_calculation_policy_id is not null and not exists(select 1 from public.transcript_calculation_policies p where p.id=t.transcript_calculation_policy_id and p.status='active') then raise exception using errcode='40001',message='transcript policy changed; rebuild and retry'; end if;
 if t.transcript_calculation_policy_id is null and exists(select 1 from public.transcript_calculation_policies p where p.school_id=t.school_id and p.status='active') then raise exception using errcode='40001',message='transcript policy changed; rebuild and retry'; end if;
 select array_agg(row(p.academic_term_id)::public.transcript_term_input order by p.sequence) into terms from public.transcript_period_snapshots p where p.transcript_id=t.id;
 select coalesce(array_agg(row(e.academic_term_id,e.subject_id,e.reason)::public.transcript_exclusion_input order by e.academic_term_id,e.subject_id nulls first),'{}') into exclusions from public.transcript_exclusions e where e.transcript_id=t.id;
 fp:=app_auth.transcript_source_fingerprint(t.student_id,t.school_id,terms,exclusions,t.transcript_calculation_policy_id);
 if fp is distinct from t.source_fingerprint then raise exception using errcode='40001',message='transcript fingerprint changed; rebuild and retry'; end if;
end $$;

create function app_auth.lock_transcript_aggregate(p_id uuid) returns public.transcripts language plpgsql security definer set search_path='' as $$
declare t public.transcripts%rowtype; ids uuid[]; begin select * into t from public.transcripts where id=p_id; if not found then raise exception using errcode='P0002',message='transcript not found'; end if;
 select array_agg(academic_term_id order by academic_term_id) into ids from public.transcript_period_snapshots where transcript_id=t.id;
 perform app_auth.lock_transcript_context(t.student_id,t.school_id,coalesce(ids,'{}')); perform 1 from public.transcripts q where q.transcript_lineage_id=t.transcript_lineage_id order by q.version,q.id for update;
 perform 1 from public.transcript_period_snapshots p where p.transcript_id=t.id order by p.sequence,p.id for update; perform 1 from public.transcript_entry_snapshots e where e.transcript_id=t.id order by e.transcript_period_snapshot_id,e.sequence,e.id for update; perform 1 from public.transcript_exclusions e where e.transcript_id=t.id order by e.academic_term_id,e.subject_id nulls first,e.id for update;
 select * into t from public.transcripts where id=p_id for update; return t; end $$;

create function public.review_transcript(transcript_id uuid,review_reason text) returns uuid language plpgsql security definer set search_path='' as $$
declare a uuid:=app_auth.transcript_actor(); t public.transcripts%rowtype; oldj jsonb; cmd uuid:=gen_random_uuid(); begin
 if length(btrim(coalesce(review_reason,'')))not between 1 and 500 then raise exception using errcode='22023',message='bounded review reason required'; end if; t:=app_auth.lock_transcript_aggregate(transcript_id); perform app_auth.assert_transcript_manage(t.organization_id,t.school_id);
 if t.status<>'draft' then raise exception using errcode='40001',message='transcript review state changed; retry'; end if; perform app_auth.assert_transcript_ready(t.id); oldj:=to_jsonb(t);
 update public.transcripts set status='reviewed',reviewed_at=now(),reviewed_by=a,review_reason=btrim(review_transcript.review_reason),updated_by=a where id=t.id returning * into t;
 perform app_auth.write_transcript_change(cmd,t.organization_id,a,'transcript.reviewed','transcript',t.id,oldj,to_jsonb(t),jsonb_build_object('school_id',t.school_id,'student_id',t.student_id,'lineage_id',t.transcript_lineage_id,'version',t.version,'term_count',(select count(*)from public.transcript_period_snapshots p where p.transcript_id=t.id),'has_policy',t.transcript_calculation_policy_id is not null)); return t.id; end $$;

create function public.return_transcript_to_draft(transcript_id uuid,reason text) returns uuid language plpgsql security definer set search_path='' as $$
declare a uuid:=app_auth.transcript_actor(); t public.transcripts%rowtype; oldj jsonb; cmd uuid:=gen_random_uuid(); begin
 if length(btrim(coalesce(reason,'')))not between 1 and 500 then raise exception using errcode='22023',message='bounded reason required'; end if; t:=app_auth.lock_transcript_aggregate(transcript_id); perform app_auth.assert_transcript_manage(t.organization_id,t.school_id); if t.status<>'reviewed' then raise exception using errcode='22023',message='reviewed transcript required'; end if; oldj:=to_jsonb(t);
 update public.transcripts set status='draft',reviewed_at=null,reviewed_by=null,review_reason=null,updated_by=a where id=t.id returning * into t;
 perform app_auth.write_transcript_change(cmd,t.organization_id,a,'transcript.returned_to_draft','transcript',t.id,oldj,to_jsonb(t),jsonb_build_object('school_id',t.school_id,'student_id',t.student_id,'lineage_id',t.transcript_lineage_id,'version',t.version)); return t.id; end $$;

create function app_auth.finish_transcript_issue(p_id uuid,p_reason text,p_correct boolean) returns table(old_transcript_id uuid,new_transcript_id uuid) language plpgsql security definer set search_path='' as $$
declare a uuid:=app_auth.transcript_actor(); t public.transcripts%rowtype; old public.transcripts%rowtype; oldj jsonb; newj jsonb; cmd uuid:=gen_random_uuid(); n bigint; action text; begin
 if length(btrim(coalesce(p_reason,'')))not between 1 and 500 then raise exception using errcode='22023',message='bounded issuance or correction reason required'; end if; t:=app_auth.lock_transcript_aggregate(p_id); perform app_auth.assert_transcript_manage(t.organization_id,t.school_id,p_correct);
 if t.status<>'reviewed' then raise exception using errcode='40001',message='transcript issuance state changed; retry'; end if; if t.reviewed_by=a then raise exception using errcode='42501',message='reviewer and issuer must be different users'; end if;
 if not exists(select 1 from public.organization_memberships m where m.organization_id=t.organization_id and m.user_id=t.reviewed_by and m.status='active' and m.left_at is null) then raise exception using errcode='42501',message='active reviewer membership required'; end if;
 perform app_auth.assert_transcript_ready(t.id);
 if t.replaces_issued_transcript_id is not null then select * into old from public.transcripts where id=t.replaces_issued_transcript_id for update; if old.status<>'issued' then raise exception using errcode='40001',message='issued transcript head changed; retry'; end if; end if;
 insert into public.transcript_number_counters(organization_id,school_id,next_number) values(t.organization_id,t.school_id,2) on conflict(organization_id,school_id)do update set next_number=public.transcript_number_counters.next_number+1,updated_at=now() returning next_number-1 into n;
 if old.id is not null then oldj:=to_jsonb(old); if p_correct then action:='transcript.corrected'; update public.transcripts set status='corrected',corrected_at=now(),corrected_by=a,correction_reason=btrim(p_reason),updated_by=a where id=old.id returning to_jsonb(public.transcripts.*) into newj;
  else action:='transcript.superseded'; update public.transcripts set status='superseded',superseded_at=now(),superseded_by=a,supersession_reason=btrim(p_reason),updated_by=a where id=old.id returning to_jsonb(public.transcripts.*) into newj; end if;
  perform app_auth.write_transcript_change(cmd,t.organization_id,a,action,'transcript',old.id,oldj,newj,jsonb_build_object('school_id',t.school_id,'student_id',t.student_id,'lineage_id',t.transcript_lineage_id,'version',old.version,'transcript_number',old.transcript_number)); end if;
 oldj:=to_jsonb(t); update public.transcripts set status='issued',transcript_number=n,issued_at=now(),issued_by=a,issuance_reason=btrim(p_reason),student_date_of_birth=(select date_of_birth from public.students where id=t.student_id),updated_by=a where id=t.id returning * into t;
 perform app_auth.write_transcript_change(cmd,t.organization_id,a,'transcript.issued','transcript',t.id,oldj,to_jsonb(t),jsonb_build_object('school_id',t.school_id,'student_id',t.student_id,'lineage_id',t.transcript_lineage_id,'version',t.version,'transcript_number',t.transcript_number,'term_count',(select count(*)from public.transcript_period_snapshots p where p.transcript_id=t.id),'has_policy',t.transcript_calculation_policy_id is not null));
 old_transcript_id:=old.id; new_transcript_id:=t.id; return next;
exception when unique_violation then raise exception using errcode='40001',message='transcript issuance changed; retry'; end $$;

create function public.issue_transcript(transcript_id uuid,issuance_reason text) returns uuid language plpgsql security definer set search_path='' as $$ declare r record; begin select * into r from app_auth.finish_transcript_issue(transcript_id,issuance_reason,false); return r.new_transcript_id; end $$;
create function public.correct_transcript(transcript_id uuid,correction_reason text) returns table(corrected_transcript_id uuid,replacement_transcript_id uuid) language plpgsql security definer set search_path='' as $$ declare r record; begin select * into r from app_auth.finish_transcript_issue(transcript_id,correction_reason,true); corrected_transcript_id:=r.old_transcript_id; replacement_transcript_id:=r.new_transcript_id; return next; end $$;

create function public.cancel_transcript(transcript_id uuid,cancellation_reason text) returns uuid language plpgsql security definer set search_path='' as $$
declare a uuid:=app_auth.transcript_actor(); t public.transcripts%rowtype; oldj jsonb; cmd uuid:=gen_random_uuid(); begin if length(btrim(coalesce(cancellation_reason,'')))not between 1 and 500 then raise exception using errcode='22023',message='bounded cancellation reason required'; end if;
 t:=app_auth.lock_transcript_aggregate(transcript_id); perform app_auth.assert_transcript_manage(t.organization_id,t.school_id); if t.status not in('draft','reviewed') then raise exception using errcode='22023',message='draft or reviewed transcript required'; end if; oldj:=to_jsonb(t);
 update public.transcripts set status='cancelled',cancelled_at=now(),cancelled_by=a,cancellation_reason=btrim(cancel_transcript.cancellation_reason),updated_by=a where id=t.id returning * into t;
 perform app_auth.write_transcript_change(cmd,t.organization_id,a,'transcript.cancelled','transcript',t.id,oldj,to_jsonb(t),jsonb_build_object('school_id',t.school_id,'student_id',t.student_id,'lineage_id',t.transcript_lineage_id,'version',t.version)); return t.id; end $$;

create view public.transcript_current_versions with(security_invoker=true) as
select t.id,t.organization_id,t.school_id,t.student_id,t.transcript_lineage_id,t.version,t.transcript_number,t.issued_at,
 t.school_code,t.school_name,t.student_number,t.student_display_name,t.policy_name,t.gpa_scale,t.gpa_decimal_places,
 t.attempted_credits,t.earned_credits,t.cumulative_gpa,t.gpa_quality_points,
 (exists(select 1 from public.transcript_period_snapshots p left join public.report_cards r on r.id=p.report_card_id where p.transcript_id=t.id and(r.id is null or r.status<>'published' or r.source_fingerprint is distinct from p.source_report_card_fingerprint))) as is_stale,
 (select count(*) from public.transcript_period_snapshots p left join public.report_cards r on r.id=p.report_card_id where p.transcript_id=t.id and(r.id is null or r.status<>'published' or r.source_fingerprint is distinct from p.source_report_card_fingerprint))::integer stale_source_count,
 (select p.academic_year_name from public.transcript_period_snapshots p where p.transcript_id=t.id order by p.sequence,p.id limit 1) first_academic_year,
 (select p.academic_year_name from public.transcript_period_snapshots p where p.transcript_id=t.id order by p.sequence desc,p.id desc limit 1) last_academic_year,
 (select p.academic_term_name from public.transcript_period_snapshots p where p.transcript_id=t.id order by p.sequence,p.id limit 1) first_academic_term,
 (select p.academic_term_name from public.transcript_period_snapshots p where p.transcript_id=t.id order by p.sequence desc,p.id desc limit 1) last_academic_term
from public.transcripts t where t.status='issued';

create view public.transcript_period_read_model with(security_invoker=true) as select t.id transcript_id,t.organization_id,t.school_id,t.student_id,t.transcript_number,t.issued_at,t.school_code,t.school_name,t.student_number,t.student_display_name,p.sequence,p.academic_year_name,p.academic_term_name,p.academic_term_sequence,p.term_start_date,p.term_end_date,p.campus_code,p.campus_name,p.section_code,p.section_name,p.grade_level_code,p.grade_level_name from public.transcripts t join public.transcript_period_snapshots p on p.transcript_id=t.id where t.status='issued';
create view public.transcript_entry_read_model with(security_invoker=true) as select t.id transcript_id,t.organization_id,t.school_id,t.student_id,t.transcript_number,t.issued_at,p.sequence period_sequence,p.academic_year_name,p.academic_term_name,e.sequence entry_sequence,e.subject_code,e.subject_name,e.rounded_percentage,e.grade_label,e.result_state,e.attempted_credits,e.earned_credits,e.grade_points,e.quality_points,t.attempted_credits total_attempted_credits,t.earned_credits total_earned_credits,t.cumulative_gpa from public.transcripts t join public.transcript_period_snapshots p on p.transcript_id=t.id join public.transcript_entry_snapshots e on e.transcript_period_snapshot_id=p.id where t.status='issued';
revoke all on public.transcript_current_versions,public.transcript_period_read_model,public.transcript_entry_read_model from public,anon,authenticated;
grant select on public.transcript_current_versions,public.transcript_period_read_model,public.transcript_entry_read_model to authenticated;

revoke all on function public.create_transcript(uuid,uuid,public.transcript_term_input[],public.transcript_exclusion_input[]),public.rebuild_transcript(uuid,public.transcript_term_input[],public.transcript_exclusion_input[],text),public.review_transcript(uuid,text),public.return_transcript_to_draft(uuid,text),public.issue_transcript(uuid,text),public.cancel_transcript(uuid,text),public.correct_transcript(uuid,text),
 public.create_transcript_calculation_policy(uuid,text,numeric,smallint,boolean,boolean,boolean,public.transcript_gpa_band_input[],public.transcript_subject_credit_input[]),public.update_draft_transcript_calculation_policy(uuid,text,numeric,smallint,boolean,boolean,boolean,public.transcript_gpa_band_input[],public.transcript_subject_credit_input[]),public.activate_transcript_calculation_policy(uuid),public.revise_transcript_calculation_policy(uuid,text,numeric,smallint,boolean,boolean,boolean,public.transcript_gpa_band_input[],public.transcript_subject_credit_input[]),public.retire_transcript_calculation_policy(uuid) from public,anon;
grant execute on function public.create_transcript(uuid,uuid,public.transcript_term_input[],public.transcript_exclusion_input[]),public.rebuild_transcript(uuid,public.transcript_term_input[],public.transcript_exclusion_input[],text),public.review_transcript(uuid,text),public.return_transcript_to_draft(uuid,text),public.issue_transcript(uuid,text),public.cancel_transcript(uuid,text),public.correct_transcript(uuid,text),
 public.create_transcript_calculation_policy(uuid,text,numeric,smallint,boolean,boolean,boolean,public.transcript_gpa_band_input[],public.transcript_subject_credit_input[]),public.update_draft_transcript_calculation_policy(uuid,text,numeric,smallint,boolean,boolean,boolean,public.transcript_gpa_band_input[],public.transcript_subject_credit_input[]),public.activate_transcript_calculation_policy(uuid),public.revise_transcript_calculation_policy(uuid,text,numeric,smallint,boolean,boolean,boolean,public.transcript_gpa_band_input[],public.transcript_subject_credit_input[]),public.retire_transcript_calculation_policy(uuid) to authenticated;

revoke all on function app_auth.transcript_actor(),app_auth.assert_transcript_manage(uuid,uuid,boolean),app_auth.validate_transcript_policy_inputs(numeric,smallint,public.transcript_gpa_band_input[],public.transcript_subject_credit_input[]),app_auth.insert_transcript_policy_children(public.transcript_calculation_policies,public.transcript_gpa_band_input[],public.transcript_subject_credit_input[],uuid,uuid),app_auth.transcript_source_fingerprint(uuid,uuid,public.transcript_term_input[],public.transcript_exclusion_input[],uuid),app_auth.lock_transcript_context(uuid,uuid,uuid[]),app_auth.build_transcript(uuid,uuid,public.transcript_term_input[],public.transcript_exclusion_input[],uuid,uuid,uuid,text),app_auth.assert_transcript_ready(uuid),app_auth.lock_transcript_aggregate(uuid),app_auth.finish_transcript_issue(uuid,text,boolean),app_auth.write_transcript_change(uuid,uuid,uuid,text,text,uuid,jsonb,jsonb,jsonb,boolean),app_auth.enforce_transcript_policy_child_mutability() from public,anon,authenticated,service_role;
grant execute on function app_auth.can_read_transcript(uuid,boolean),app_auth.can_read_transcript_policy(uuid) to authenticated,service_role;

comment on table public.transcripts is 'Immutable, school-scoped transcript versions with reviewed issuance and append-and-supersede history.';
comment on table public.transcript_period_snapshots is 'Immutable selected published report-card term snapshots.';
comment on table public.transcript_entry_snapshots is 'Immutable report-card subject-grade snapshots with optional versioned credit and GPA facts.';
comment on view public.transcript_current_versions is 'Current issued transcript headers with derived report-card-source staleness.';

commit;
