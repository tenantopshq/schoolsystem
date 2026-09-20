begin;

create type public.report_card_status as enum ('draft','finalized','published','corrected','cancelled');
create type public.report_card_comment_type as enum ('overall','subject');
create type public.report_card_comment_status as enum ('active','withdrawn');
create type public.report_card_signoff_type as enum ('subject_teacher','homeroom_teacher','administrator_reviewer','administrator_correction_certification');
create type public.report_card_signoff_status as enum ('active','revoked');
create type public.report_card_batch_status as enum ('draft','reviewed','cancelled');
create type public.report_card_batch_student_input as (student_id uuid);

-- Exact keys required by immutable report-card provenance.
alter table public.term_grade_calculations add constraint term_grade_calculations_report_card_key
 unique(organization_id,term_grade_set_id,student_id,calculation_sequence,term_grade_record_id,id);
alter table public.term_grade_calculation_sources add constraint term_grade_sources_report_card_key
 unique(organization_id,id);
alter table public.attendance_marks add constraint attendance_marks_report_card_key
 unique(organization_id,school_id,campus_id,academic_year_id,section_id,session_id,student_id,session_student_id,id);
alter table public.organization_memberships add constraint organization_memberships_report_card_actor_key
 unique(organization_id,user_id,id);
alter table public.staff_profiles add constraint staff_profiles_report_card_actor_key
 unique(organization_id,organization_membership_id,id);
alter table public.teaching_assignments add constraint teaching_assignments_report_card_actor_key
 unique(organization_id,school_id,campus_id,academic_year_id,section_id,subject_id,staff_profile_id,id);

create table public.report_card_batches(
 id uuid primary key default gen_random_uuid(), organization_id uuid not null, school_id uuid not null,
 campus_id uuid not null, academic_year_id uuid not null, academic_term_id uuid not null, section_id uuid not null,
 status public.report_card_batch_status not null default 'draft',
 reviewed_at timestamptz, reviewed_by uuid references auth.users(id) on delete restrict,
 cancelled_at timestamptz, cancelled_by uuid references auth.users(id) on delete restrict,
 cancellation_reason text check(cancellation_reason is null or length(btrim(cancellation_reason)) between 1 and 500),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 created_by uuid not null references auth.users(id) on delete restrict,
 updated_by uuid not null references auth.users(id) on delete restrict,
 foreign key(organization_id,school_id,campus_id,academic_year_id,section_id)
  references public.sections(organization_id,school_id,campus_id,academic_year_id,id) on delete restrict,
 foreign key(organization_id,academic_year_id,academic_term_id)
  references public.academic_terms(organization_id,academic_year_id,id) on delete restrict,
 unique(organization_id,id),
 unique(organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,id),
 check((status='draft' and reviewed_at is null and reviewed_by is null and cancelled_at is null and cancelled_by is null and cancellation_reason is null)
  or(status='reviewed' and reviewed_at is not null and reviewed_by is not null and cancelled_at is null and cancelled_by is null and cancellation_reason is null)
  or(status='cancelled' and reviewed_at is null and reviewed_by is null and cancelled_at is not null and cancelled_by is not null and cancellation_reason is not null))
);

create table public.report_cards(
 id uuid primary key default gen_random_uuid(), organization_id uuid not null, school_id uuid not null,
 campus_id uuid not null, academic_year_id uuid not null, academic_term_id uuid not null, section_id uuid not null,
 student_id uuid not null, student_enrollment_id uuid not null, student_section_placement_id uuid not null,
 lineage_id uuid not null, version integer not null check(version>=1), report_card_number bigint not null check(report_card_number>=1),
 supersedes_report_card_id uuid, report_card_batch_id uuid,
 status public.report_card_status not null default 'draft',
 finalized_at timestamptz, finalized_by uuid references auth.users(id) on delete restrict,
 published_at timestamptz, published_by uuid references auth.users(id) on delete restrict,
 corrected_at timestamptz, corrected_by uuid references auth.users(id) on delete restrict,
 correction_reason text check(correction_reason is null or length(btrim(correction_reason)) between 1 and 500),
 cancelled_at timestamptz, cancelled_by uuid references auth.users(id) on delete restrict,
 cancellation_reason text check(cancellation_reason is null or length(btrim(cancellation_reason)) between 1 and 500),
 source_fingerprint bytea not null check(octet_length(source_fingerprint)=32), snapshot_taken_at timestamptz not null default now(),
 school_code text not null check(length(btrim(school_code)) between 1 and 32), school_name text not null check(length(btrim(school_name)) between 1 and 200),
 campus_code text not null check(length(btrim(campus_code)) between 1 and 32), campus_name text not null check(length(btrim(campus_name)) between 1 and 160),
 academic_year_name text not null check(length(btrim(academic_year_name)) between 1 and 80),
 academic_term_name text not null check(length(btrim(academic_term_name)) between 1 and 60), academic_term_sequence smallint not null check(academic_term_sequence>0),
 term_start_date date not null, term_end_date date not null check(term_end_date>=term_start_date),
 section_code text not null check(length(btrim(section_code)) between 1 and 32), section_name text not null check(length(btrim(section_name)) between 1 and 120),
 grade_level_code text not null check(length(btrim(grade_level_code)) between 1 and 32), grade_level_name text not null check(length(btrim(grade_level_name)) between 1 and 100),
 student_number text not null check(length(btrim(student_number)) between 1 and 48), student_display_name text not null check(length(btrim(student_display_name)) between 1 and 302),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 created_by uuid not null references auth.users(id) on delete restrict, updated_by uuid not null references auth.users(id) on delete restrict,
 foreign key(organization_id,school_id,campus_id,academic_year_id,section_id)
  references public.sections(organization_id,school_id,campus_id,academic_year_id,id) on delete restrict,
 foreign key(organization_id,academic_year_id,academic_term_id) references public.academic_terms(organization_id,academic_year_id,id) on delete restrict,
 foreign key(organization_id,student_id) references public.students(organization_id,id) on delete restrict,
 foreign key(organization_id,school_id,academic_year_id,student_id,student_enrollment_id)
  references public.student_enrollments(organization_id,school_id,academic_year_id,student_id,id) on delete restrict,
 foreign key(organization_id,school_id,campus_id,academic_year_id,section_id,student_id,student_enrollment_id,student_section_placement_id)
  references public.student_section_placements(organization_id,school_id,campus_id,academic_year_id,section_id,student_id,student_enrollment_id,id) on delete restrict,
 foreign key(organization_id,supersedes_report_card_id) references public.report_cards(organization_id,id) on delete restrict,
 foreign key(organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,report_card_batch_id)
  references public.report_card_batches(organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,id) on delete restrict,
 unique(organization_id,id), unique(organization_id,lineage_id,version), unique(school_id,report_card_number),
 unique(organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,student_id,id),
 check(supersedes_report_card_id is null or supersedes_report_card_id<>id),
 check((version=1 and lineage_id=id and supersedes_report_card_id is null)or(version>1 and supersedes_report_card_id is not null)),
 check((status='draft' and finalized_at is null and finalized_by is null and published_at is null and published_by is null and corrected_at is null and corrected_by is null and correction_reason is null and cancelled_at is null and cancelled_by is null and cancellation_reason is null)
  or(status='finalized' and finalized_at is not null and finalized_by is not null and published_at is null and published_by is null and corrected_at is null and corrected_by is null and correction_reason is null and cancelled_at is null and cancelled_by is null and cancellation_reason is null)
  or(status='published' and finalized_at is not null and finalized_by is not null and published_at is not null and published_by is not null and corrected_at is null and corrected_by is null and correction_reason is null and cancelled_at is null and cancelled_by is null and cancellation_reason is null)
  or(status='corrected' and finalized_at is not null and finalized_by is not null and corrected_at is not null and corrected_by is not null and correction_reason is not null and cancelled_at is null and cancelled_by is null and cancellation_reason is null)
  or(status='cancelled' and finalized_at is null and finalized_by is null and published_at is null and published_by is null and corrected_at is null and corrected_by is null and correction_reason is null and cancelled_at is not null and cancelled_by is not null and cancellation_reason is not null))
);
create unique index report_cards_live_lineage_key on public.report_cards(organization_id,lineage_id) where status not in('corrected','cancelled');
create unique index report_cards_live_student_context_key on public.report_cards(section_id,academic_term_id,student_id) where status not in('corrected','cancelled');
create unique index report_cards_one_successor_key on public.report_cards(supersedes_report_card_id) where supersedes_report_card_id is not null;

create table public.report_card_grade_snapshots(
 id uuid primary key default gen_random_uuid(), organization_id uuid not null, school_id uuid not null, campus_id uuid not null,
 academic_year_id uuid not null, academic_term_id uuid not null, section_id uuid not null, report_card_id uuid not null, student_id uuid not null,
 subject_id uuid, subject_code text, subject_name text,
 term_grading_configuration_id uuid not null, term_grade_set_id uuid not null, term_grade_record_id uuid not null,
 term_grade_calculation_id uuid not null, grade_scale_id uuid not null, grade_scale_band_id uuid not null,
 term_grade_calculation_sequence integer not null check(term_grade_calculation_sequence>=1),
 raw_percentage numeric(20,10) not null, rounded_percentage numeric(7,4) not null check(rounded_percentage between 0 and 100),
 grade_label text not null check(length(btrim(grade_label)) between 1 and 32), result_state public.grade_result_state not null,
 contributing_assessment_count integer not null check(contributing_assessment_count>=0), weight_total numeric(7,4) not null,
 source_term_grade_fingerprint bytea not null check(octet_length(source_term_grade_fingerprint)=32),
 created_at timestamptz not null default now(), created_by uuid not null references auth.users(id) on delete restrict,
 foreign key(organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,student_id,report_card_id)
  references public.report_cards(organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,student_id,id) on delete restrict,
 foreign key(organization_id,school_id,subject_id) references public.subjects(organization_id,school_id,id) on delete restrict,
 foreign key(organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,term_grade_set_id)
  references public.term_grade_sets(organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,id) on delete restrict,
 foreign key(organization_id,term_grade_set_id,student_id,term_grade_calculation_sequence,term_grade_record_id)
  references public.term_grade_records(organization_id,term_grade_set_id,student_id,calculation_sequence,id) on delete restrict,
 foreign key(organization_id,term_grade_set_id,student_id,term_grade_calculation_sequence,term_grade_record_id,term_grade_calculation_id)
  references public.term_grade_calculations(organization_id,term_grade_set_id,student_id,calculation_sequence,term_grade_record_id,id) on delete restrict,
 foreign key(organization_id,grade_scale_id,grade_scale_band_id) references public.grade_scale_bands(organization_id,grade_scale_id,id) on delete restrict,
 unique(organization_id,id), unique(organization_id,report_card_id,student_id,id),
 check((subject_id is null and subject_code is null and subject_name is null)or(subject_id is not null and length(btrim(subject_code)) between 1 and 32 and length(btrim(subject_name)) between 1 and 120))
);
create unique index report_card_grades_null_subject_key on public.report_card_grade_snapshots(report_card_id) where subject_id is null;
create unique index report_card_grades_subject_key on public.report_card_grade_snapshots(report_card_id,subject_id) where subject_id is not null;

create table public.report_card_grade_sources(
 id uuid primary key default gen_random_uuid(), organization_id uuid not null, report_card_id uuid not null,
 report_card_grade_snapshot_id uuid not null, student_id uuid not null, term_grade_calculation_source_id uuid not null,
 assessment_root_id uuid not null, assessment_version_id uuid not null, assessment_id uuid not null,
 assessment_student_id uuid not null, assessment_result_id uuid not null,
 score numeric(12,4) not null, maximum_score numeric(12,4) not null, assessment_weight numeric(7,4) not null,
 score_ratio numeric(20,10) not null, effective_weight numeric(20,10) not null, weighted_points numeric(20,10) not null,
 created_at timestamptz not null default now(), created_by uuid not null references auth.users(id) on delete restrict,
 foreign key(organization_id,report_card_id,student_id,report_card_grade_snapshot_id)
  references public.report_card_grade_snapshots(organization_id,report_card_id,student_id,id) on delete restrict,
 foreign key(organization_id,term_grade_calculation_source_id) references public.term_grade_calculation_sources(organization_id,id) on delete restrict,
 foreign key(organization_id,assessment_root_id) references public.assessments(organization_id,id) on delete restrict,
 foreign key(organization_id,assessment_version_id) references public.assessments(organization_id,id) on delete restrict,
 foreign key(organization_id,assessment_id,student_id,assessment_student_id) references public.assessment_students(organization_id,assessment_id,student_id,id) on delete restrict,
 foreign key(organization_id,assessment_id,student_id,assessment_student_id,assessment_result_id) references public.assessment_results(organization_id,assessment_id,student_id,assessment_student_id,id) on delete restrict,
 unique(report_card_grade_snapshot_id,term_grade_calculation_source_id)
);

create table public.report_card_attendance_snapshots(
 id uuid primary key default gen_random_uuid(), organization_id uuid not null, school_id uuid not null, campus_id uuid not null,
 academic_year_id uuid not null, academic_term_id uuid not null, section_id uuid not null, report_card_id uuid not null, student_id uuid not null,
 range_start_date date not null, range_end_date date not null,
 total_session_count integer not null check(total_session_count>=0), present_count integer not null check(present_count>=0),
 absent_count integer not null check(absent_count>=0), late_count integer not null check(late_count>=0), excused_count integer not null check(excused_count>=0),
 source_fingerprint bytea not null check(octet_length(source_fingerprint)=32), calculated_at timestamptz not null default now(),
 created_at timestamptz not null default now(), created_by uuid not null references auth.users(id) on delete restrict,
 foreign key(organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,student_id,report_card_id)
  references public.report_cards(organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,student_id,id) on delete restrict,
 unique(organization_id,id), unique(report_card_id), unique(organization_id,report_card_id,student_id,id),
 check(range_end_date>=range_start_date), check(present_count+absent_count+late_count+excused_count=total_session_count)
);

create table public.report_card_attendance_sources(
 id uuid primary key default gen_random_uuid(), organization_id uuid not null, school_id uuid not null, campus_id uuid not null,
 academic_year_id uuid not null, section_id uuid not null, report_card_id uuid not null, report_card_attendance_snapshot_id uuid not null,
 student_id uuid not null, attendance_session_id uuid not null, attendance_session_student_id uuid not null, attendance_mark_id uuid not null,
 session_date date not null, mark public.attendance_mark_status not null, absence_reason_id uuid,
 created_at timestamptz not null default now(), created_by uuid not null references auth.users(id) on delete restrict,
 foreign key(organization_id,report_card_id,student_id,report_card_attendance_snapshot_id)
  references public.report_card_attendance_snapshots(organization_id,report_card_id,student_id,id) on delete restrict,
 foreign key(organization_id,school_id,campus_id,academic_year_id,section_id,attendance_session_id)
  references public.attendance_sessions(organization_id,school_id,campus_id,academic_year_id,section_id,id) on delete restrict,
 foreign key(organization_id,school_id,campus_id,academic_year_id,section_id,attendance_session_id,student_id,attendance_session_student_id)
  references public.attendance_session_students(organization_id,school_id,campus_id,academic_year_id,section_id,session_id,student_id,id) on delete restrict,
 foreign key(organization_id,school_id,campus_id,academic_year_id,section_id,attendance_session_id,student_id,attendance_session_student_id,attendance_mark_id)
  references public.attendance_marks(organization_id,school_id,campus_id,academic_year_id,section_id,session_id,student_id,session_student_id,id) on delete restrict,
 foreign key(organization_id,school_id,absence_reason_id) references public.attendance_absence_reasons(organization_id,school_id,id) on delete restrict,
 unique(report_card_attendance_snapshot_id,attendance_session_id)
);

create table public.report_card_comments(
 id uuid primary key default gen_random_uuid(), organization_id uuid not null, school_id uuid not null, campus_id uuid not null,
 academic_year_id uuid not null, academic_term_id uuid not null, section_id uuid not null, report_card_id uuid not null, student_id uuid not null,
 comment_type public.report_card_comment_type not null, subject_id uuid, body text not null check(length(btrim(body)) between 1 and 2000),
 author_user_id uuid not null references auth.users(id) on delete restrict, author_membership_id uuid not null,
 author_staff_profile_id uuid,
 author_teaching_assignment_id uuid, status public.report_card_comment_status not null default 'active',
 withdrawn_at timestamptz, withdrawn_by uuid references auth.users(id) on delete restrict,
 withdrawal_reason text check(withdrawal_reason is null or length(btrim(withdrawal_reason)) between 1 and 500),
 created_at timestamptz not null default now(), created_by uuid not null references auth.users(id) on delete restrict,
 foreign key(organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,student_id,report_card_id)
  references public.report_cards(organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,student_id,id) on delete restrict,
 foreign key(organization_id,school_id,subject_id) references public.subjects(organization_id,school_id,id) on delete restrict,
 foreign key(organization_id,author_user_id,author_membership_id) references public.organization_memberships(organization_id,user_id,id) on delete restrict,
 foreign key(organization_id,author_membership_id,author_staff_profile_id) references public.staff_profiles(organization_id,organization_membership_id,id) on delete restrict,
 foreign key(organization_id,school_id,campus_id,academic_year_id,section_id,subject_id,author_staff_profile_id,author_teaching_assignment_id)
  references public.teaching_assignments(organization_id,school_id,campus_id,academic_year_id,section_id,subject_id,staff_profile_id,id) on delete restrict,
 unique(organization_id,id),
 check((comment_type='overall' and subject_id is null)or(comment_type='subject' and subject_id is not null)),
 check((status='active' and withdrawn_at is null and withdrawn_by is null and withdrawal_reason is null)or(status='withdrawn' and withdrawn_at is not null and withdrawn_by is not null and withdrawal_reason is not null))
);
create unique index report_card_comments_active_overall_key on public.report_card_comments(report_card_id) where status='active' and subject_id is null;
create unique index report_card_comments_active_subject_key on public.report_card_comments(report_card_id,subject_id) where status='active' and subject_id is not null;

create table public.report_card_signoffs(
 id uuid primary key default gen_random_uuid(), organization_id uuid not null, school_id uuid not null, campus_id uuid not null,
 academic_year_id uuid not null, academic_term_id uuid not null, section_id uuid not null, report_card_id uuid not null, student_id uuid not null,
 signoff_type public.report_card_signoff_type not null, subject_id uuid, signer_user_id uuid not null references auth.users(id) on delete restrict,
 signer_membership_id uuid not null,
 signer_staff_profile_id uuid, teaching_assignment_id uuid, status public.report_card_signoff_status not null default 'active',
 signed_at timestamptz not null default now(), revoked_at timestamptz, revoked_by uuid references auth.users(id) on delete restrict,
 revocation_reason text check(revocation_reason is null or length(btrim(revocation_reason)) between 1 and 500),
 created_at timestamptz not null default now(), created_by uuid not null references auth.users(id) on delete restrict,
 foreign key(organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,student_id,report_card_id)
  references public.report_cards(organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,student_id,id) on delete restrict,
 foreign key(organization_id,school_id,subject_id) references public.subjects(organization_id,school_id,id) on delete restrict,
 foreign key(organization_id,signer_user_id,signer_membership_id) references public.organization_memberships(organization_id,user_id,id) on delete restrict,
 foreign key(organization_id,signer_membership_id,signer_staff_profile_id) references public.staff_profiles(organization_id,organization_membership_id,id) on delete restrict,
 foreign key(organization_id,school_id,campus_id,academic_year_id,section_id,subject_id,signer_staff_profile_id,teaching_assignment_id)
  references public.teaching_assignments(organization_id,school_id,campus_id,academic_year_id,section_id,subject_id,staff_profile_id,id) on delete restrict,
 unique(organization_id,id),
 check((signoff_type='subject_teacher' and subject_id is not null and teaching_assignment_id is not null and signer_staff_profile_id is not null)
  or(signoff_type='homeroom_teacher' and subject_id is null and teaching_assignment_id is not null and signer_staff_profile_id is not null)
  or(signoff_type in('administrator_reviewer','administrator_correction_certification') and subject_id is null and teaching_assignment_id is null and signer_staff_profile_id is null)),
 check((status='active' and revoked_at is null and revoked_by is null and revocation_reason is null)or(status='revoked' and revoked_at is not null and revoked_by is not null and revocation_reason is not null))
);
create unique index report_card_signoffs_active_subject_key on public.report_card_signoffs(report_card_id,signoff_type,subject_id) where status='active' and subject_id is not null;
create unique index report_card_signoffs_active_null_key on public.report_card_signoffs(report_card_id,signoff_type) where status='active' and subject_id is null;

create function app_auth.enforce_report_card_actor_provenance() returns trigger
language plpgsql set search_path='' as $$
declare membership_id uuid; staff_id uuid; assignment_id uuid; expected_subject uuid;
begin
 if tg_table_name='report_card_comments' then
  membership_id:=new.author_membership_id; staff_id:=new.author_staff_profile_id;
  assignment_id:=new.author_teaching_assignment_id; expected_subject:=new.subject_id;
 else
  membership_id:=new.signer_membership_id; staff_id:=new.signer_staff_profile_id;
  assignment_id:=new.teaching_assignment_id; expected_subject:=new.subject_id;
 end if;
 if assignment_id is not null and not exists(
  select 1 from public.teaching_assignments t
  where (t.organization_id,t.school_id,t.campus_id,t.academic_year_id,t.section_id,t.staff_profile_id,t.id)=
        (new.organization_id,new.school_id,new.campus_id,new.academic_year_id,new.section_id,staff_id,assignment_id)
    and t.subject_id is not distinct from expected_subject)
 then raise exception using errcode='23503',message='report-card assignment provenance must exactly match actor and context'; end if;
 if staff_id is not null and not exists(select 1 from public.staff_profiles p
   where (p.organization_id,p.organization_membership_id,p.id)=(new.organization_id,membership_id,staff_id))
 then raise exception using errcode='23503',message='report-card staff provenance must exactly match membership'; end if;
 return new;
end $$;
create constraint trigger report_card_comments_actor_provenance after insert or update on public.report_card_comments
 deferrable initially immediate for each row execute function app_auth.enforce_report_card_actor_provenance();
create constraint trigger report_card_signoffs_actor_provenance after insert or update on public.report_card_signoffs
 deferrable initially immediate for each row execute function app_auth.enforce_report_card_actor_provenance();

create table public.report_card_batch_items(
 id uuid primary key default gen_random_uuid(), organization_id uuid not null, school_id uuid not null, campus_id uuid not null,
 academic_year_id uuid not null, academic_term_id uuid not null, section_id uuid not null, report_card_batch_id uuid not null,
 report_card_id uuid not null, student_id uuid not null, created_at timestamptz not null default now(),
 created_by uuid not null references auth.users(id) on delete restrict,
 foreign key(organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,report_card_batch_id)
  references public.report_card_batches(organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,id) on delete restrict,
 foreign key(organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,student_id,report_card_id)
  references public.report_cards(organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,student_id,id) on delete restrict,
 unique(report_card_batch_id,student_id), unique(report_card_batch_id,report_card_id)
);

-- Every FK and every RLS traversal has a supporting leading-column index.
create index report_card_batches_scope_idx on public.report_card_batches(organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,status,id);
create index report_cards_portal_idx on public.report_cards(organization_id,student_id,status,academic_term_id,section_id,id);
create index report_cards_scope_idx on public.report_cards(organization_id,school_id,campus_id,section_id,academic_term_id,status,student_id,id);
create index report_cards_lineage_idx on public.report_cards(organization_id,lineage_id,version desc,id);
create index report_cards_batch_idx on public.report_cards(organization_id,report_card_batch_id,id) where report_card_batch_id is not null;
create index report_cards_enrollment_idx on public.report_cards(organization_id,student_enrollment_id);
create index report_cards_placement_idx on public.report_cards(organization_id,student_section_placement_id);
create index report_card_grades_card_idx on public.report_card_grade_snapshots(organization_id,report_card_id,subject_id,id);
create index report_card_grades_set_idx on public.report_card_grade_snapshots(organization_id,term_grade_set_id,student_id);
create index report_card_grades_calc_idx on public.report_card_grade_snapshots(organization_id,term_grade_calculation_id);
create index report_card_grade_sources_card_idx on public.report_card_grade_sources(organization_id,report_card_id,student_id);
create index report_card_grade_sources_result_idx on public.report_card_grade_sources(organization_id,assessment_result_id,student_id);
create index report_card_attendance_student_idx on public.report_card_attendance_snapshots(organization_id,student_id,report_card_id);
create index report_card_attendance_sources_card_idx on public.report_card_attendance_sources(organization_id,report_card_id,student_id);
create index report_card_attendance_sources_session_idx on public.report_card_attendance_sources(organization_id,attendance_session_id);
create index report_card_attendance_sources_mark_idx on public.report_card_attendance_sources(organization_id,attendance_mark_id);
create index report_card_comments_card_idx on public.report_card_comments(organization_id,report_card_id,subject_id,status,id);
create index report_card_comments_author_idx on public.report_card_comments(author_user_id);
create index report_card_comments_actor_provenance_idx on public.report_card_comments(organization_id,author_membership_id,author_staff_profile_id,author_teaching_assignment_id);
create index report_card_signoffs_card_idx on public.report_card_signoffs(organization_id,report_card_id,subject_id,status,id);
create index report_card_signoffs_signer_idx on public.report_card_signoffs(signer_user_id);
create index report_card_signoffs_actor_provenance_idx on public.report_card_signoffs(organization_id,signer_membership_id,signer_staff_profile_id,teaching_assignment_id);
create index report_card_batch_items_card_idx on public.report_card_batch_items(organization_id,report_card_id);
create index report_card_batch_items_student_idx on public.report_card_batch_items(organization_id,student_id,report_card_batch_id);

create trigger report_card_batches_updated_at before update on public.report_card_batches for each row execute function public.set_updated_at();
create trigger report_cards_updated_at before update on public.report_cards for each row execute function public.set_updated_at();

insert into public.permissions(code,module,description) values
 ('report_cards.view','report_cards','View report cards within assigned scope'),
 ('report_cards.manage','report_cards','Create, review, finalize, publish, and cancel report cards within assigned scope'),
 ('report_cards.correct','report_cards','Correct finalized or published report cards within assigned scope');

create function app_auth.report_card_actor() returns uuid language plpgsql security definer set search_path='' as $$
declare a uuid:=auth.uid(); begin
 if a is null then raise exception using errcode='42501',message='authentication required'; end if;
 return a;
end $$;

create function app_auth.enforce_report_card_lineage() returns trigger language plpgsql security definer set search_path='' as $$
declare p public.report_cards%rowtype; begin
 if new.supersedes_report_card_id is not null then
  select * into p from public.report_cards where id=new.supersedes_report_card_id;
  if p.id is null or (p.organization_id,p.school_id,p.section_id,p.academic_term_id,p.student_id,p.lineage_id,p.version+1)
    is distinct from (new.organization_id,new.school_id,new.section_id,new.academic_term_id,new.student_id,new.lineage_id,new.version)
  then raise exception using errcode='22023',message='invalid report-card lineage'; end if;
 end if; return new;
end $$;
create constraint trigger report_cards_lineage_exact after insert on public.report_cards deferrable initially deferred
 for each row execute function app_auth.enforce_report_card_lineage();

-- Cross-module academic snapshot writers take this transaction-scoped organization
-- mutex before any row lock. It is intentionally conservative: report-card builds,
-- attendance corrections, and term-grade corrections cannot acquire their differing
-- child graphs in opposite orders inside one tenant.
create function app_auth.lock_academic_snapshot_domain(p_organization uuid) returns void
language sql security definer set search_path='' as $$
 select pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('school-platform:academic-snapshot:'||p_organization::text,0));
$$;

create function app_auth.lock_report_card_context(p_section uuid,p_term uuid,p_students uuid[]) returns void
language plpgsql security definer set search_path='' as $$
declare s public.sections%rowtype;
begin
 select * into s from public.sections where id=p_section;
 if not found then raise exception using errcode='P0002',message='section not found'; end if;
 perform app_auth.lock_academic_snapshot_domain(s.organization_id);
 perform 1 from public.organizations where id=s.organization_id for update;
 perform 1 from public.schools where id=s.school_id for update;
 perform 1 from public.campuses where id=s.campus_id for update;
 perform 1 from public.academic_years where id=s.academic_year_id for update;
 perform 1 from public.academic_terms where id=p_term for update;
 perform 1 from public.grade_levels where id=s.grade_level_id for update;
 perform 1 from public.sections where id=s.id for update;
 perform 1 from public.subjects u where u.id in(select c.subject_id from public.term_grading_configurations c
   where c.section_id=s.id and c.academic_term_id=p_term and c.status='active') order by u.id for update;
 perform 1 from public.students st where st.id=any(p_students) order by st.id for update;
 perform 1 from public.student_enrollments e where e.student_id=any(p_students) order by e.student_id,e.id for update;
 perform 1 from public.student_section_placements p where p.student_id=any(p_students) order by p.student_id,p.id for update;
 perform 1 from public.teaching_assignments a where a.section_id=s.id order by a.subject_id nulls first,a.id for update;
 perform 1 from public.grade_scales gs where gs.id in(select c.grade_scale_id from public.term_grading_configurations c
   where c.section_id=s.id and c.academic_term_id=p_term) order by gs.id for update;
 perform 1 from public.grade_scale_bands gb where gb.grade_scale_id in(select c.grade_scale_id from public.term_grading_configurations c
   where c.section_id=s.id and c.academic_term_id=p_term) order by gb.grade_scale_id,gb.sequence,gb.id for update;
 perform 1 from public.term_grading_configurations c where c.section_id=s.id and c.academic_term_id=p_term
   order by c.subject_id nulls first,c.id for update;
 perform 1 from public.term_grade_sets x where x.section_id=s.id and x.academic_term_id=p_term
   order by x.subject_id nulls first,x.supersedes_term_grade_set_id nulls first,x.id for update;
 perform 1 from public.term_grade_records r join public.term_grade_sets x on x.id=r.term_grade_set_id
   where x.section_id=s.id and x.academic_term_id=p_term and r.student_id=any(p_students)
   order by r.student_id,x.subject_id nulls first,r.id for update of r;
 perform 1 from public.term_grade_calculations c join public.term_grade_records r on r.id=c.term_grade_record_id
   join public.term_grade_sets x on x.id=r.term_grade_set_id where x.section_id=s.id and x.academic_term_id=p_term and r.student_id=any(p_students)
   order by r.student_id,x.subject_id nulls first,c.id for update of c;
 perform 1 from public.term_grade_calculation_sources z join public.term_grade_calculations c on c.id=z.term_grade_calculation_id
   join public.term_grade_records r on r.id=c.term_grade_record_id join public.term_grade_sets x on x.id=r.term_grade_set_id
   where x.section_id=s.id and x.academic_term_id=p_term and r.student_id=any(p_students) order by r.student_id,z.id for update of z;
 perform 1 from public.attendance_sessions a join public.academic_terms t on t.id=p_term
   where a.section_id=s.id and a.session_date between t.start_date and t.end_date order by a.session_date,a.id for update of a;
 perform 1 from public.attendance_session_students ss join public.attendance_sessions a on a.id=ss.session_id
   join public.academic_terms t on t.id=p_term where a.section_id=s.id and a.session_date between t.start_date and t.end_date
   and ss.student_id=any(p_students) order by ss.student_id,ss.id for update of ss;
 perform 1 from public.attendance_marks m join public.attendance_sessions a on a.id=m.session_id
   join public.academic_terms t on t.id=p_term where a.section_id=s.id and a.session_date between t.start_date and t.end_date
   and m.student_id=any(p_students) order by m.student_id,m.id for update of m;
end $$;

create function app_auth.lock_report_card_aggregate(p_card uuid) returns void
language plpgsql security definer set search_path='' as $$
declare r public.report_cards%rowtype;
begin
 select * into r from public.report_cards where id=p_card;
 if not found then raise exception using errcode='P0002',message='report card not found'; end if;
 perform app_auth.lock_report_card_context(r.section_id,r.academic_term_id,array[r.student_id]);
 perform 1 from public.report_card_batches b where b.id=r.report_card_batch_id for update;
 perform 1 from public.report_card_batch_items i where i.report_card_batch_id=r.report_card_batch_id order by i.student_id,i.id for update;
 perform 1 from public.report_cards q where q.lineage_id=r.lineage_id order by q.version,q.id for update;
 perform 1 from public.report_card_grade_snapshots g where g.report_card_id=r.id order by g.subject_id nulls first,g.id for update;
 perform 1 from public.report_card_grade_sources z where z.report_card_id=r.id order by z.id for update;
 perform 1 from public.report_card_attendance_snapshots a where a.report_card_id=r.id for update;
 perform 1 from public.report_card_attendance_sources a where a.report_card_id=r.id order by a.session_date,a.id for update;
 perform 1 from public.report_card_comments c where c.report_card_id=r.id order by c.subject_id nulls first,c.id for update;
 perform 1 from public.report_card_signoffs s where s.report_card_id=r.id order by s.subject_id nulls first,s.id for update;
end $$;

create function public.create_report_card(student_id uuid,section_id uuid,academic_term_id uuid) returns uuid
language plpgsql security definer set search_path='' as $$
declare a uuid:=app_auth.report_card_actor(); cmd uuid:=gen_random_uuid(); begin
 return app_auth.build_report_card(student_id,section_id,academic_term_id,null,null,a,cmd,'draft');
end $$;

create function public.create_report_card_batch(section_id uuid,academic_term_id uuid,students public.report_card_batch_student_input[])
returns table(report_card_batch_id uuid,report_card_count integer) language plpgsql security definer set search_path='' as $$
declare a uuid:=app_auth.report_card_actor(); s public.sections%rowtype; t public.academic_terms%rowtype; b public.report_card_batches%rowtype;
 x public.report_card_batch_student_input; card uuid; item uuid; cmd uuid:=gen_random_uuid(); n integer:=0;
begin
 if students is null or cardinality(students) not between 1 and 500 or exists(select 1 from unnest(students) z where z is null or (z).student_id is null)
  or(select count(*) from unnest(students))<>(select count(distinct (z).student_id) from unnest(students) z)
 then raise exception using errcode='22023',message='one to 500 distinct students are required'; end if;
 select * into s from public.sections where id=section_id; if not found then raise exception using errcode='P0002',message='section not found'; end if;
 select * into t from public.academic_terms where id=academic_term_id;
 if t.id is null or (t.organization_id,t.academic_year_id)<>(s.organization_id,s.academic_year_id) then raise exception using errcode='22023',message='compatible academic term required'; end if;
 if not app_auth.has_permission(s.organization_id,'report_cards.manage',s.school_id,s.campus_id) then raise exception using errcode='42501',message='report_cards.manage permission is required'; end if;
 perform app_auth.lock_report_card_context(s.id,t.id,array(select (z).student_id from unnest(students) z order by (z).student_id));
 insert into public.report_card_batches(organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,created_by,updated_by)
 values(s.organization_id,s.school_id,s.campus_id,s.academic_year_id,t.id,s.id,a,a) returning * into b;
 perform app_auth.write_report_card_change(cmd,b.organization_id,a,'report_card_batch.created','report_card_batch',b.id,null,to_jsonb(b),jsonb_build_object('school_id',b.school_id,'campus_id',b.campus_id,'section_id',b.section_id,'student_count',cardinality(students)));
 for x in select (z).* from unnest(students) z order by(z).student_id loop
  card:=app_auth.build_report_card(x.student_id,s.id,t.id,b.id,null,a,cmd,'draft');
  insert into public.report_card_batch_items(organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,report_card_batch_id,report_card_id,student_id,created_by)
  values(b.organization_id,b.school_id,b.campus_id,b.academic_year_id,b.academic_term_id,b.section_id,b.id,card,x.student_id,a) returning id into item;
  perform app_auth.write_report_card_change(cmd,b.organization_id,a,'report_card_batch.item_created','report_card_batch_item',item,null,(select to_jsonb(q) from public.report_card_batch_items q where q.id=item),null,false); n:=n+1;
 end loop;
 report_card_batch_id:=b.id; report_card_count:=n; return next;
end $$;

create function public.save_report_card_comment(report_card_id uuid,comment_type public.report_card_comment_type,subject_id uuid,body text) returns uuid
language plpgsql security definer set search_path='' as $$
declare a uuid:=app_auth.report_card_actor(); r public.report_cards%rowtype; old public.report_card_comments%rowtype; c public.report_card_comments%rowtype;
 ta public.teaching_assignments%rowtype; sp uuid; membership uuid; cmd uuid:=gen_random_uuid(); oldj jsonb; newj jsonb;
begin
 perform app_auth.lock_report_card_aggregate(report_card_id);
 if length(btrim(coalesce(body,''))) not between 1 and 2000 or(comment_type='overall' and subject_id is not null)or(comment_type='subject' and subject_id is null)
 then raise exception using errcode='22023',message='valid bounded report-card comment is required'; end if;
 select * into r from public.report_cards where id=report_card_id for update; if not found then raise exception using errcode='P0002',message='report card not found'; end if;
 select m.id into membership from public.organization_memberships m where m.organization_id=r.organization_id and m.user_id=a and m.status='active' and m.left_at is null;
 if membership is null then raise exception using errcode='42501',message='active organization membership required'; end if;
 if r.status<>'draft' then raise exception using errcode='22023',message='draft report card required'; end if;
 if not app_auth.has_permission(r.organization_id,'report_cards.manage',r.school_id,r.campus_id) then
  select t.* into ta from public.teaching_assignments t join public.staff_profiles p on p.id=t.staff_profile_id
   join public.organization_memberships m on m.id=p.organization_membership_id
   where t.section_id=r.section_id and t.subject_id is not distinct from subject_id and t.status='active' and current_date<@t.effective_range
    and m.user_id=a and m.status='active' and p.status='active'
    and((comment_type='subject' and t.role in('lead','co_teacher','substitute'))or(comment_type='overall' and t.role in('lead','co_teacher'))) order by t.id limit 1;
  if ta.id is null then raise exception using errcode='42501',message='report-card comment authority required'; end if; sp:=ta.staff_profile_id;
 end if;
 select * into old from public.report_card_comments where report_card_comments.report_card_id=r.id and status='active' and report_card_comments.subject_id is not distinct from save_report_card_comment.subject_id for update;
 if old.id is not null then oldj:=to_jsonb(old); update public.report_card_comments set status='withdrawn',withdrawn_at=now(),withdrawn_by=a,withdrawal_reason='replaced by newer draft comment' where id=old.id returning to_jsonb(report_card_comments.*) into newj;
  perform app_auth.write_report_card_change(cmd,r.organization_id,a,'report_card.comment_withdrawn','report_card_comment',old.id,oldj,newj,jsonb_build_object('report_card_id',r.id,'student_id',r.student_id,'subject_id',subject_id)); end if;
 insert into public.report_card_comments(organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,report_card_id,student_id,comment_type,subject_id,body,author_user_id,author_membership_id,author_staff_profile_id,author_teaching_assignment_id,created_by)
 values(r.organization_id,r.school_id,r.campus_id,r.academic_year_id,r.academic_term_id,r.section_id,r.id,r.student_id,comment_type,subject_id,btrim(body),a,membership,sp,ta.id,a) returning * into c;
 perform app_auth.write_report_card_change(cmd,r.organization_id,a,'report_card.comment_saved','report_card_comment',c.id,null,to_jsonb(c),jsonb_build_object('report_card_id',r.id,'student_id',r.student_id,'subject_id',subject_id)); return c.id;
end $$;

create function public.withdraw_report_card_comment(id uuid,reason text) returns uuid language plpgsql security definer set search_path='' as $$
declare a uuid:=app_auth.report_card_actor(); c public.report_card_comments%rowtype; r public.report_cards%rowtype; oldj jsonb; newj jsonb; cmd uuid:=gen_random_uuid(); begin
 if length(btrim(coalesce(reason,''))) not between 1 and 500 then raise exception using errcode='22023',message='bounded reason required'; end if;
 perform app_auth.lock_report_card_aggregate((select report_card_id from public.report_card_comments where report_card_comments.id=withdraw_report_card_comment.id));
 select * into c from public.report_card_comments where report_card_comments.id=withdraw_report_card_comment.id for update; if not found then raise exception using errcode='P0002',message='comment not found'; end if;
 select * into r from public.report_cards where report_cards.id=c.report_card_id for update;
 if r.status<>'draft' or c.status<>'active' then raise exception using errcode='22023',message='active draft comment required'; end if;
 if c.author_user_id<>a and not app_auth.has_permission(r.organization_id,'report_cards.manage',r.school_id,r.campus_id) then raise exception using errcode='42501',message='comment author or report_cards.manage required'; end if;
 oldj:=to_jsonb(c); update public.report_card_comments set status='withdrawn',withdrawn_at=now(),withdrawn_by=a,withdrawal_reason=btrim(reason) where report_card_comments.id=c.id returning to_jsonb(report_card_comments.*) into newj;
 perform app_auth.write_report_card_change(cmd,r.organization_id,a,'report_card.comment_withdrawn','report_card_comment',c.id,oldj,newj,jsonb_build_object('report_card_id',r.id,'student_id',r.student_id,'subject_id',c.subject_id)); return c.id;
end $$;

create function public.sign_report_card(report_card_id uuid,signoff_type public.report_card_signoff_type,subject_id uuid) returns uuid
language plpgsql security definer set search_path='' as $$
declare a uuid:=app_auth.report_card_actor(); r public.report_cards%rowtype; ta public.teaching_assignments%rowtype; sp uuid; membership uuid; so public.report_card_signoffs%rowtype; cmd uuid:=gen_random_uuid(); begin
 if sign_report_card.signoff_type='administrator_correction_certification' then raise exception using errcode='22023',message='correction certification is command-only'; end if;
 perform app_auth.lock_report_card_aggregate(sign_report_card.report_card_id);
 select rc.* into r from public.report_cards rc where rc.id=sign_report_card.report_card_id for update; if not found then raise exception using errcode='P0002',message='report card not found'; end if;
 select m.id into membership from public.organization_memberships m where m.organization_id=r.organization_id and m.user_id=a and m.status='active' and m.left_at is null;
 if membership is null then raise exception using errcode='42501',message='active organization membership required'; end if;
 if r.status<>'draft' or r.supersedes_report_card_id is not null then raise exception using errcode='22023',message='root draft report card required'; end if;
 if sign_report_card.signoff_type='administrator_reviewer' then
  if sign_report_card.subject_id is not null or not app_auth.has_permission(r.organization_id,'report_cards.manage',r.school_id,r.campus_id) then raise exception using errcode='42501',message='report_cards.manage administrator review required'; end if;
 else
  if (sign_report_card.signoff_type='subject_teacher' and sign_report_card.subject_id is null)or(sign_report_card.signoff_type='homeroom_teacher' and sign_report_card.subject_id is not null) then raise exception using errcode='22023',message='sign-off subject context mismatch'; end if;
  select t.* into ta from public.teaching_assignments t join public.staff_profiles p on p.id=t.staff_profile_id join public.organization_memberships m on m.id=p.organization_membership_id
   where t.section_id=r.section_id and t.subject_id is not distinct from sign_report_card.subject_id and t.status='active' and current_date<@t.effective_range and m.user_id=a and m.status='active' and p.status='active'
    and((sign_report_card.signoff_type='subject_teacher' and t.role in('lead','co_teacher','substitute'))or(sign_report_card.signoff_type='homeroom_teacher' and t.role in('lead','co_teacher'))) order by t.id limit 1;
  if ta.id is null then raise exception using errcode='42501',message='report-card sign-off authority required'; end if; sp:=ta.staff_profile_id;
 end if;
 insert into public.report_card_signoffs(organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,report_card_id,student_id,signoff_type,subject_id,signer_user_id,signer_membership_id,signer_staff_profile_id,teaching_assignment_id,created_by)
 values(r.organization_id,r.school_id,r.campus_id,r.academic_year_id,r.academic_term_id,r.section_id,r.id,r.student_id,sign_report_card.signoff_type,sign_report_card.subject_id,a,membership,sp,ta.id,a) returning * into so;
 perform app_auth.write_report_card_change(cmd,r.organization_id,a,'report_card.signed','report_card_signoff',so.id,null,to_jsonb(so),jsonb_build_object('report_card_id',r.id,'student_id',r.student_id,'subject_id',sign_report_card.subject_id,'signoff_type',sign_report_card.signoff_type)); return so.id;
exception when unique_violation then raise exception using errcode='40001',message='report-card sign-off changed; retry';
end $$;

create function public.revoke_report_card_signoff(id uuid,reason text) returns uuid language plpgsql security definer set search_path='' as $$
declare a uuid:=app_auth.report_card_actor(); so public.report_card_signoffs%rowtype; r public.report_cards%rowtype; oldj jsonb; newj jsonb; cmd uuid:=gen_random_uuid(); begin
 if length(btrim(coalesce(reason,''))) not between 1 and 500 then raise exception using errcode='22023',message='bounded reason required'; end if;
 perform app_auth.lock_report_card_aggregate((select report_card_id from public.report_card_signoffs where report_card_signoffs.id=revoke_report_card_signoff.id));
 select * into so from public.report_card_signoffs where report_card_signoffs.id=revoke_report_card_signoff.id for update; if not found then raise exception using errcode='P0002',message='sign-off not found'; end if;
 select * into r from public.report_cards where report_cards.id=so.report_card_id for update;
 if r.status<>'draft' or so.status<>'active' then raise exception using errcode='22023',message='active draft sign-off required'; end if;
 if so.signer_user_id<>a and not app_auth.has_permission(r.organization_id,'report_cards.manage',r.school_id,r.campus_id) then raise exception using errcode='42501',message='signer or report_cards.manage required'; end if;
 oldj:=to_jsonb(so); update public.report_card_signoffs set status='revoked',revoked_at=now(),revoked_by=a,revocation_reason=btrim(reason) where report_card_signoffs.id=so.id returning to_jsonb(report_card_signoffs.*) into newj;
 perform app_auth.write_report_card_change(cmd,r.organization_id,a,'report_card.signoff_revoked','report_card_signoff',so.id,oldj,newj,jsonb_build_object('report_card_id',r.id,'student_id',r.student_id,'subject_id',so.subject_id,'signoff_type',so.signoff_type)); return so.id;
end $$;

create function app_auth.assert_report_card_ready(p_card uuid) returns void language plpgsql security definer set search_path='' as $$
declare r public.report_cards%rowtype; current_fp bytea; begin
 select * into r from public.report_cards where id=p_card;
 if r.status<>'draft' then raise exception using errcode='22023',message='draft report card required'; end if;
 if (select count(*) from public.term_grading_configurations c where c.section_id=r.section_id and c.academic_term_id=r.academic_term_id and c.status='active')
    <>(select count(*) from public.report_card_grade_snapshots g where g.report_card_id=r.id)
  or exists(select 1 from public.term_grading_configurations c where c.section_id=r.section_id and c.academic_term_id=r.academic_term_id and c.status='active'
    and not exists(select 1 from public.report_card_grade_snapshots g where g.report_card_id=r.id and g.subject_id is not distinct from c.subject_id))
 then raise exception using errcode='40001',message='report-card required contexts changed; recreate draft and retry'; end if;
 current_fp:=app_auth.report_card_source_fingerprint(r.section_id,r.academic_term_id,r.student_id);
 if current_fp is distinct from r.source_fingerprint then raise exception using errcode='40001',message='report-card sources changed; recreate draft and retry'; end if;
 if exists(select 1 from public.report_card_grade_snapshots g where g.report_card_id=r.id and g.subject_id is not null and not exists(
  select 1 from public.report_card_signoffs s where s.report_card_id=r.id and s.signoff_type='subject_teacher' and s.subject_id=g.subject_id and s.status='active'))
 then raise exception using errcode='22023',message='all subject sign-offs are required'; end if;
 if exists(select 1 from public.teaching_assignments t where t.section_id=r.section_id and t.subject_id is null and t.role in('lead','co_teacher') and t.status<>'corrected'
   and t.effective_range&&daterange(r.term_start_date,r.term_end_date,'[]'))
  and not exists(select 1 from public.report_card_signoffs s where s.report_card_id=r.id and s.signoff_type='homeroom_teacher' and s.status='active')
 then raise exception using errcode='22023',message='homeroom sign-off is required'; end if;
 if not exists(select 1 from public.report_card_signoffs s where s.report_card_id=r.id and s.signoff_type='administrator_reviewer' and s.status='active')
 then raise exception using errcode='22023',message='administrator review sign-off is required'; end if;
end $$;

create function public.review_report_card_batch(report_card_batch_id uuid) returns uuid language plpgsql security definer set search_path='' as $$
declare a uuid:=app_auth.report_card_actor(); b public.report_card_batches%rowtype; r record; oldj jsonb; newj jsonb; cmd uuid:=gen_random_uuid(); begin
 perform app_auth.lock_report_card_aggregate((select i.report_card_id from public.report_card_batch_items i where i.report_card_batch_id=review_report_card_batch.report_card_batch_id order by i.student_id limit 1));
 select rb.* into b from public.report_card_batches rb where rb.id=review_report_card_batch.report_card_batch_id for update; if not found then raise exception using errcode='P0002',message='report-card batch not found'; end if;
 if b.status<>'draft' then raise exception using errcode='40001',message='report-card batch review state changed; retry'; end if;
 if not app_auth.has_permission(b.organization_id,'report_cards.manage',b.school_id,b.campus_id) then raise exception using errcode='42501',message='report_cards.manage permission is required'; end if;
 perform 1 from public.report_card_batch_items i where i.report_card_batch_id=b.id order by i.student_id,i.id for update;
 for r in select c.id from public.report_card_batch_items i join public.report_cards c on c.id=i.report_card_id where i.report_card_batch_id=b.id order by i.student_id loop perform app_auth.assert_report_card_ready(r.id); end loop;
 oldj:=to_jsonb(b); update public.report_card_batches set status='reviewed',reviewed_at=now(),reviewed_by=a,updated_by=a where id=b.id returning to_jsonb(report_card_batches.*) into newj;
 perform app_auth.write_report_card_change(cmd,b.organization_id,a,'report_card_batch.reviewed','report_card_batch',b.id,oldj,newj,jsonb_build_object('school_id',b.school_id,'campus_id',b.campus_id,'section_id',b.section_id)); return b.id;
end $$;

create function public.finalize_report_card(report_card_id uuid) returns uuid language plpgsql security definer set search_path='' as $$
declare a uuid:=app_auth.report_card_actor(); r public.report_cards%rowtype; oldj jsonb; newj jsonb; cmd uuid:=gen_random_uuid(); begin
 perform app_auth.lock_report_card_aggregate(report_card_id);
 select * into r from public.report_cards where id=report_card_id for update; if not found then raise exception using errcode='P0002',message='report card not found'; end if;
 if not app_auth.has_permission(r.organization_id,'report_cards.manage',r.school_id,r.campus_id) then raise exception using errcode='42501',message='report_cards.manage permission is required'; end if;
 if r.status<>'draft' then raise exception using errcode='40001',message='report-card finalization state changed; retry'; end if;
 perform app_auth.assert_report_card_ready(r.id); oldj:=to_jsonb(r);
 update public.report_cards set status='finalized',finalized_at=now(),finalized_by=a,updated_by=a where id=r.id returning to_jsonb(report_cards.*) into newj;
 perform app_auth.write_report_card_change(cmd,r.organization_id,a,'report_card.finalized','report_card',r.id,oldj,newj,jsonb_build_object('school_id',r.school_id,'campus_id',r.campus_id,'section_id',r.section_id,'student_id',r.student_id,'lineage_id',r.lineage_id,'version',r.version)); return r.id;
end $$;

create function public.publish_report_card(report_card_id uuid) returns uuid language plpgsql security definer set search_path='' as $$
declare a uuid:=app_auth.report_card_actor(); r public.report_cards%rowtype; oldj jsonb; newj jsonb; cmd uuid:=gen_random_uuid(); begin
 perform app_auth.lock_report_card_aggregate(report_card_id);
 select * into r from public.report_cards where id=report_card_id for update; if not found then raise exception using errcode='P0002',message='report card not found'; end if;
 if not app_auth.has_permission(r.organization_id,'report_cards.manage',r.school_id,r.campus_id) then raise exception using errcode='42501',message='report_cards.manage permission is required'; end if;
 if r.status<>'finalized' then raise exception using errcode='22023',message='finalized report card required'; end if;
 if r.supersedes_report_card_id is not null and not exists(select 1 from public.report_card_signoffs s where s.report_card_id=r.id and s.signoff_type='administrator_correction_certification' and s.status='active')
 then raise exception using errcode='22023',message='correction certification required'; end if;
 oldj:=to_jsonb(r); update public.report_cards set status='published',published_at=now(),published_by=a,updated_by=a where id=r.id returning to_jsonb(report_cards.*) into newj;
 perform app_auth.write_report_card_change(cmd,r.organization_id,a,'report_card.published','report_card',r.id,oldj,newj,jsonb_build_object('school_id',r.school_id,'campus_id',r.campus_id,'section_id',r.section_id,'student_id',r.student_id,'lineage_id',r.lineage_id,'version',r.version)); return r.id;
end $$;

create function public.cancel_draft_report_card(report_card_id uuid,cancellation_reason text) returns uuid language plpgsql security definer set search_path='' as $$
declare a uuid:=app_auth.report_card_actor(); r public.report_cards%rowtype; oldj jsonb; newj jsonb; cmd uuid:=gen_random_uuid(); begin
 if length(btrim(coalesce(cancellation_reason,''))) not between 1 and 500 then raise exception using errcode='22023',message='bounded cancellation reason required'; end if;
 perform app_auth.lock_report_card_aggregate(report_card_id);
 select * into r from public.report_cards where id=report_card_id for update; if not found then raise exception using errcode='P0002',message='report card not found'; end if;
 if not app_auth.has_permission(r.organization_id,'report_cards.manage',r.school_id,r.campus_id) then raise exception using errcode='42501',message='report_cards.manage permission is required'; end if;
 if r.status<>'draft' then raise exception using errcode='22023',message='draft report card required'; end if;
 oldj:=to_jsonb(r); update public.report_cards set status='cancelled',cancelled_at=now(),cancelled_by=a,cancellation_reason=btrim(cancel_draft_report_card.cancellation_reason),updated_by=a where id=r.id returning to_jsonb(report_cards.*) into newj;
 perform app_auth.write_report_card_change(cmd,r.organization_id,a,'report_card.cancelled','report_card',r.id,oldj,newj,jsonb_build_object('school_id',r.school_id,'campus_id',r.campus_id,'section_id',r.section_id,'student_id',r.student_id,'lineage_id',r.lineage_id,'version',r.version)); return r.id;
end $$;

create function public.cancel_report_card_batch(report_card_batch_id uuid,cancellation_reason text) returns uuid language plpgsql security definer set search_path='' as $$
declare a uuid:=app_auth.report_card_actor(); b public.report_card_batches%rowtype; oldj jsonb; newj jsonb; cmd uuid:=gen_random_uuid(); begin
 if length(btrim(coalesce(cancellation_reason,''))) not between 1 and 500 then raise exception using errcode='22023',message='bounded cancellation reason required'; end if;
 select * into b from public.report_card_batches where id=report_card_batch_id for update; if not found then raise exception using errcode='P0002',message='report-card batch not found'; end if;
 if not app_auth.has_permission(b.organization_id,'report_cards.manage',b.school_id,b.campus_id) then raise exception using errcode='42501',message='report_cards.manage permission is required'; end if;
 if b.status<>'draft' or exists(select 1 from public.report_card_batch_items i join public.report_cards r on r.id=i.report_card_id where i.report_card_batch_id=b.id and r.status not in('draft','cancelled'))
 then raise exception using errcode='22023',message='cancellable draft batch required'; end if;
 oldj:=to_jsonb(b); update public.report_card_batches set status='cancelled',cancelled_at=now(),cancelled_by=a,cancellation_reason=btrim(cancel_report_card_batch.cancellation_reason),updated_by=a where id=b.id returning to_jsonb(report_card_batches.*) into newj;
 perform app_auth.write_report_card_change(cmd,b.organization_id,a,'report_card_batch.cancelled','report_card_batch',b.id,oldj,newj,jsonb_build_object('school_id',b.school_id,'campus_id',b.campus_id,'section_id',b.section_id)); return b.id;
end $$;

create function public.correct_report_card(report_card_id uuid,correction_reason text)
returns table(corrected_report_card_id uuid,replacement_report_card_id uuid) language plpgsql security definer set search_path='' as $$
declare a uuid:=app_auth.report_card_actor(); r public.report_cards%rowtype; successor public.report_cards%rowtype; oldj jsonb; correctedj jsonb;
 cmd uuid:=gen_random_uuid(); replacement uuid; membership uuid; c public.report_card_comments%rowtype; copied public.report_card_comments%rowtype; cert public.report_card_signoffs%rowtype;
begin
 if length(btrim(coalesce(correction_reason,''))) not between 1 and 500 then raise exception using errcode='22023',message='bounded correction reason required'; end if;
 select * into r from public.report_cards where id=report_card_id;
 if not found then raise exception using errcode='P0002',message='report card not found'; end if;
 perform app_auth.lock_report_card_aggregate(r.id);
 select * into r from public.report_cards where id=r.id for update;
 if r.status not in('finalized','published') or exists(select 1 from public.report_cards q where q.supersedes_report_card_id=r.id)
 then raise exception using errcode='40001',message='report-card correction head changed; retry'; end if;
 if not app_auth.has_permission(r.organization_id,'report_cards.manage',r.school_id,r.campus_id) or not app_auth.has_permission(r.organization_id,'report_cards.correct',r.school_id,r.campus_id)
 then raise exception using errcode='42501',message='report_cards.manage and report_cards.correct permissions are required'; end if;
 select m.id into membership from public.organization_memberships m where m.organization_id=r.organization_id and m.user_id=a and m.status='active' and m.left_at is null;
 if membership is null then raise exception using errcode='42501',message='active organization membership required'; end if;
 oldj:=to_jsonb(r); update public.report_cards set status='corrected',corrected_at=now(),corrected_by=a,correction_reason=btrim(correct_report_card.correction_reason),updated_by=a where id=r.id returning to_jsonb(report_cards.*) into correctedj;
 perform app_auth.write_report_card_change(cmd,r.organization_id,a,'report_card.corrected','report_card',r.id,oldj,correctedj,jsonb_build_object('school_id',r.school_id,'campus_id',r.campus_id,'section_id',r.section_id,'student_id',r.student_id,'lineage_id',r.lineage_id,'version',r.version));
 replacement:=app_auth.build_report_card(r.student_id,r.section_id,r.academic_term_id,null,r.id,a,cmd,case when r.published_at is null then 'finalized'::public.report_card_status else 'published'::public.report_card_status end);
 select * into successor from public.report_cards where id=replacement;
 for c in select * from public.report_card_comments q where q.report_card_id=r.id and q.status='active' and(q.subject_id is null or exists(select 1 from public.report_card_grade_snapshots g where g.report_card_id=replacement and g.subject_id=q.subject_id)) order by q.subject_id nulls first,q.id loop
  insert into public.report_card_comments(organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,report_card_id,student_id,comment_type,subject_id,body,author_user_id,author_membership_id,author_staff_profile_id,author_teaching_assignment_id,status,created_at,created_by)
  values(successor.organization_id,successor.school_id,successor.campus_id,successor.academic_year_id,successor.academic_term_id,successor.section_id,successor.id,successor.student_id,c.comment_type,c.subject_id,c.body,c.author_user_id,c.author_membership_id,c.author_staff_profile_id,c.author_teaching_assignment_id,'active',c.created_at,c.created_by) returning * into copied;
  perform app_auth.write_report_card_change(cmd,r.organization_id,a,'report_card.comment_copied','report_card_comment',copied.id,null,to_jsonb(copied),null,false);
 end loop;
 insert into public.report_card_signoffs(organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,report_card_id,student_id,signoff_type,subject_id,signer_user_id,signer_membership_id,created_by)
 values(successor.organization_id,successor.school_id,successor.campus_id,successor.academic_year_id,successor.academic_term_id,successor.section_id,successor.id,successor.student_id,'administrator_correction_certification',null,a,membership,a) returning * into cert;
 perform app_auth.write_report_card_change(cmd,r.organization_id,a,'report_card.correction_certified','report_card_signoff',cert.id,null,to_jsonb(cert),null,false);
 insert into public.event_outbox(command_id,organization_id,event_type,aggregate_type,aggregate_id,payload) values(cmd,r.organization_id,
  case when successor.status='published' then 'report_card.published' else 'report_card.finalized' end,'report_card',successor.id,
  jsonb_build_object('command_id',cmd,'actor_user_id',a,'organization_id',r.organization_id,'aggregate_id',successor.id,'school_id',successor.school_id,'campus_id',successor.campus_id,'section_id',successor.section_id,'student_id',successor.student_id,'lineage_id',successor.lineage_id,'version',successor.version,'predecessor_id',r.id,
   'copied_comment_count',(select count(*) from public.report_card_comments q where q.report_card_id=successor.id),'correction_certified',true));
 corrected_report_card_id:=r.id; replacement_report_card_id:=successor.id; return next;
exception when unique_violation then raise exception using errcode='40001',message='report-card correction head changed; retry';
end $$;

create function app_auth.has_report_card_assignment(p_section uuid,p_subject uuid,p_roles public.teaching_assignment_role[]) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(
  select 1 from public.teaching_assignments t
  join public.staff_profiles sp on (sp.organization_id,sp.id)=(t.organization_id,t.staff_profile_id) and sp.status='active'
  join public.organization_memberships m on (m.organization_id,m.id)=(sp.organization_id,sp.organization_membership_id)
   and m.status='active' and m.left_at is null
  where t.section_id=p_section and t.subject_id is not distinct from p_subject
   and t.status='active' and current_date<@t.effective_range and t.role=any(p_roles) and m.user_id=auth.uid());
$$;

create function app_auth.can_read_report_card_header(p_card uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.report_cards r join public.students st on st.id=r.student_id where r.id=p_card and(
  app_auth.has_permission(r.organization_id,'report_cards.view',r.school_id,r.campus_id)
  or app_auth.has_permission(r.organization_id,'report_cards.manage',r.school_id,r.campus_id)
  or app_auth.has_permission(r.organization_id,'report_cards.correct',r.school_id,r.campus_id)
  or app_auth.has_report_card_assignment(r.section_id,null,array['lead','co_teacher','assistant']::public.teaching_assignment_role[])
  or exists(select 1 from public.teaching_assignments t where t.section_id=r.section_id and t.subject_id is not null and t.status='active'
    and current_date<@t.effective_range and app_auth.has_report_card_assignment(t.section_id,t.subject_id,array[t.role]))
  or(r.status='published' and st.status='active' and(app_auth.is_student_self(r.student_id)or app_auth.is_linked_guardian(r.student_id)))));
$$;

create function app_auth.can_read_report_card_subject(p_card uuid,p_subject uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.report_cards r join public.students st on st.id=r.student_id where r.id=p_card and(
  app_auth.has_permission(r.organization_id,'report_cards.view',r.school_id,r.campus_id)
  or app_auth.has_permission(r.organization_id,'report_cards.manage',r.school_id,r.campus_id)
  or app_auth.has_permission(r.organization_id,'report_cards.correct',r.school_id,r.campus_id)
  or app_auth.has_report_card_assignment(r.section_id,null,array['lead','co_teacher']::public.teaching_assignment_role[])
  or(p_subject is not null and app_auth.has_report_card_assignment(r.section_id,p_subject,array['lead','co_teacher','assistant','substitute']::public.teaching_assignment_role[]))
  or(r.status='published' and st.status='active' and(app_auth.is_student_self(r.student_id)or app_auth.is_linked_guardian(r.student_id)))));
$$;

create function app_auth.can_read_report_card_attendance(p_card uuid,p_portal boolean default true) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.report_cards r join public.students st on st.id=r.student_id where r.id=p_card and(
  app_auth.has_permission(r.organization_id,'report_cards.view',r.school_id,r.campus_id)
  or app_auth.has_permission(r.organization_id,'report_cards.manage',r.school_id,r.campus_id)
  or app_auth.has_permission(r.organization_id,'report_cards.correct',r.school_id,r.campus_id)
  or app_auth.has_report_card_assignment(r.section_id,null,array['lead','co_teacher']::public.teaching_assignment_role[])
  or(p_portal and r.status='published' and st.status='active' and(app_auth.is_student_self(r.student_id)or app_auth.is_linked_guardian(r.student_id)))));
$$;

create function app_auth.can_read_report_card_batch(p_batch uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.report_card_batches b where b.id=p_batch and(
  app_auth.has_permission(b.organization_id,'report_cards.view',b.school_id,b.campus_id)
  or app_auth.has_permission(b.organization_id,'report_cards.manage',b.school_id,b.campus_id)
  or app_auth.has_permission(b.organization_id,'report_cards.correct',b.school_id,b.campus_id)));
$$;

alter table public.report_card_batches enable row level security; alter table public.report_card_batches force row level security;
alter table public.report_cards enable row level security; alter table public.report_cards force row level security;
alter table public.report_card_grade_snapshots enable row level security; alter table public.report_card_grade_snapshots force row level security;
alter table public.report_card_grade_sources enable row level security; alter table public.report_card_grade_sources force row level security;
alter table public.report_card_attendance_snapshots enable row level security; alter table public.report_card_attendance_snapshots force row level security;
alter table public.report_card_attendance_sources enable row level security; alter table public.report_card_attendance_sources force row level security;
alter table public.report_card_comments enable row level security; alter table public.report_card_comments force row level security;
alter table public.report_card_signoffs enable row level security; alter table public.report_card_signoffs force row level security;
alter table public.report_card_batch_items enable row level security; alter table public.report_card_batch_items force row level security;
create policy report_card_batches_select on public.report_card_batches for select to authenticated using(app_auth.can_read_report_card_batch(id));
create policy report_cards_select on public.report_cards for select to authenticated using(app_auth.can_read_report_card_header(id));
create policy report_card_grades_select on public.report_card_grade_snapshots for select to authenticated using(app_auth.can_read_report_card_subject(report_card_id,subject_id));
create policy report_card_grade_sources_select on public.report_card_grade_sources for select to authenticated using(
 exists(select 1 from public.report_card_grade_snapshots g where g.id=report_card_grade_snapshot_id
  and app_auth.can_read_report_card_subject(g.report_card_id,g.subject_id)
  and not exists(select 1 from public.report_cards r where r.id=g.report_card_id and r.status='published'
   and(app_auth.is_student_self(r.student_id)or app_auth.is_linked_guardian(r.student_id)))));
create policy report_card_attendance_select on public.report_card_attendance_snapshots for select to authenticated using(app_auth.can_read_report_card_attendance(report_card_id,true));
create policy report_card_attendance_sources_select on public.report_card_attendance_sources for select to authenticated using(app_auth.can_read_report_card_attendance(report_card_id,false));
create policy report_card_comments_select on public.report_card_comments for select to authenticated using(app_auth.can_read_report_card_subject(report_card_id,subject_id));
create policy report_card_signoffs_select on public.report_card_signoffs for select to authenticated using(app_auth.can_read_report_card_subject(report_card_id,subject_id));
create policy report_card_batch_items_select on public.report_card_batch_items for select to authenticated using(app_auth.can_read_report_card_batch(report_card_batch_id));

revoke all on public.report_card_batches,public.report_cards,public.report_card_grade_snapshots,public.report_card_grade_sources,
 public.report_card_attendance_snapshots,public.report_card_attendance_sources,public.report_card_comments,public.report_card_signoffs,
 public.report_card_batch_items from public,anon,authenticated;
grant select on public.report_card_batches,public.report_cards,public.report_card_grade_snapshots,public.report_card_grade_sources,
 public.report_card_attendance_snapshots,public.report_card_attendance_sources,public.report_card_comments,public.report_card_signoffs,
 public.report_card_batch_items to authenticated;

create function app_auth.enforce_report_card_immutable_child() returns trigger language plpgsql set search_path='' as $$
begin raise exception using errcode='22023',message='report-card snapshot history is immutable'; end $$;
create trigger report_card_grades_immutable before update or delete on public.report_card_grade_snapshots for each row execute function app_auth.enforce_report_card_immutable_child();
create trigger report_card_grade_sources_immutable before update or delete on public.report_card_grade_sources for each row execute function app_auth.enforce_report_card_immutable_child();
create trigger report_card_attendance_immutable before update or delete on public.report_card_attendance_snapshots for each row execute function app_auth.enforce_report_card_immutable_child();
create trigger report_card_attendance_sources_immutable before update or delete on public.report_card_attendance_sources for each row execute function app_auth.enforce_report_card_immutable_child();
create trigger report_card_batch_items_immutable before update or delete on public.report_card_batch_items for each row execute function app_auth.enforce_report_card_immutable_child();

create function app_auth.enforce_report_card_root_immutability() returns trigger language plpgsql set search_path='' as $$
begin
 if tg_op='DELETE' then raise exception using errcode='22023',message='report-card history cannot be deleted'; end if;
 if (to_jsonb(new)-array['status','finalized_at','finalized_by','published_at','published_by','corrected_at','corrected_by','correction_reason','cancelled_at','cancelled_by','cancellation_reason','updated_at','updated_by'])
  is distinct from (to_jsonb(old)-array['status','finalized_at','finalized_by','published_at','published_by','corrected_at','corrected_by','correction_reason','cancelled_at','cancelled_by','cancellation_reason','updated_at','updated_by'])
 then raise exception using errcode='22023',message='report-card immutable fields cannot change'; end if;
 if old.status in('corrected','cancelled') then raise exception using errcode='22023',message='terminal report card cannot change'; end if;
 return new;
end $$;
create trigger report_cards_immutable before update or delete on public.report_cards for each row execute function app_auth.enforce_report_card_root_immutability();

create function app_auth.enforce_report_card_batch_immutability() returns trigger language plpgsql set search_path='' as $$
begin
 if tg_op='DELETE' then raise exception using errcode='22023',message='report-card batch history cannot be deleted'; end if;
 if (to_jsonb(new)-array['status','reviewed_at','reviewed_by','cancelled_at','cancelled_by','cancellation_reason','updated_at','updated_by'])
  is distinct from (to_jsonb(old)-array['status','reviewed_at','reviewed_by','cancelled_at','cancelled_by','cancellation_reason','updated_at','updated_by'])
 then raise exception using errcode='22023',message='report-card batch immutable fields cannot change'; end if;
 if old.status in('reviewed','cancelled') then raise exception using errcode='22023',message='terminal report-card batch cannot change'; end if;
 return new;
end $$;
create trigger report_card_batches_immutable before update or delete on public.report_card_batches for each row execute function app_auth.enforce_report_card_batch_immutability();

create function app_auth.enforce_report_card_authored_immutability() returns trigger language plpgsql set search_path='' as $$
begin
 if tg_op='DELETE' then raise exception using errcode='22023',message='report-card authored history cannot be deleted'; end if;
 if (to_jsonb(new)-array['status','withdrawn_at','withdrawn_by','withdrawal_reason','revoked_at','revoked_by','revocation_reason'])
  is distinct from (to_jsonb(old)-array['status','withdrawn_at','withdrawn_by','withdrawal_reason','revoked_at','revoked_by','revocation_reason'])
 then raise exception using errcode='22023',message='report-card authorship is immutable'; end if;
 return new;
end $$;
create trigger report_card_comments_immutable before update or delete on public.report_card_comments for each row execute function app_auth.enforce_report_card_authored_immutability();
create trigger report_card_signoffs_immutable before update or delete on public.report_card_signoffs for each row execute function app_auth.enforce_report_card_authored_immutability();

create function app_auth.write_report_card_change(cmd uuid,o uuid,actor uuid,action_name text,entity_name text,entity uuid,before_row jsonb,after_row jsonb,payload jsonb,emit boolean default true)
returns void language plpgsql security definer set search_path='' as $$
declare safe_before jsonb:=before_row; safe_after jsonb:=after_row;
begin
 if entity_name='report_card_comment' then
  if safe_before is not null then safe_before:=jsonb_set(safe_before,'{body}','"[REDACTED]"'); end if;
  if safe_after is not null then safe_after:=jsonb_set(safe_after,'{body}','"[REDACTED]"'); end if;
 end if;
 insert into public.audit_log(command_id,organization_id,actor_user_id,action,entity_type,entity_id,before_data,after_data)
 values(cmd,o,actor,action_name,entity_name,entity,safe_before,safe_after);
 if emit then insert into public.event_outbox(command_id,organization_id,event_type,aggregate_type,aggregate_id,payload)
 values(cmd,o,action_name,entity_name,entity,jsonb_strip_nulls(coalesce(payload,'{}')||jsonb_build_object('command_id',cmd,'actor_user_id',actor,'organization_id',o,'aggregate_id',entity))); end if;
end $$;

create function app_auth.report_card_source_fingerprint(p_section uuid,p_term uuid,p_student uuid) returns bytea
language sql stable security definer set search_path='' as $$
 select extensions.digest(
  'report-card-v1|'||coalesce((select concat_ws('|',o.id,sch.id,sch.code,sch.name,cam.id,cam.code,cam.name,y.id,y.name,
    t.id,t.name,t.sequence,t.start_date,t.end_date,gl.id,gl.code,gl.name,s.id,s.code,s.name,st.id,st.student_number,
    concat_ws(' ',st.first_name,nullif(st.middle_name,''),st.last_name))
   from public.sections s join public.organizations o on o.id=s.organization_id join public.schools sch on sch.id=s.school_id
   join public.campuses cam on cam.id=s.campus_id join public.academic_years y on y.id=s.academic_year_id
   join public.academic_terms t on t.id=p_term join public.grade_levels gl on gl.id=s.grade_level_id
   join public.students st on st.id=p_student where s.id=p_section),'')
  ||'|eligibility|'||coalesce((select string_agg(e.id::text||':'||p.id::text,'|' order by e.id,p.id)
   from public.student_enrollments e join public.student_section_placements p on p.student_enrollment_id=e.id
   join public.sections s on s.id=p_section join public.academic_terms t on t.id=p_term
   where e.student_id=p_student and p.student_id=p_student and p.section_id=p_section and e.status<>'corrected' and p.status<>'corrected'
    and e.enrollment_range&&daterange(t.start_date,t.end_date,'[]')
    and daterange(p.starts_on,coalesce(p.ends_on,s.end_date),'[]')&&daterange(t.start_date,t.end_date,'[]')),'')
  ||'|grades|'||coalesce((select string_agg(
   coalesce(c.subject_id::text,'~')||':'||g.id::text||':'||g.term_grading_configuration_id::text||':'||g.calculation_sequence::text||':'||encode(g.source_fingerprint,'hex')||':'||r.id::text||':'||calc.id::text||':'||calc.grade_scale_id::text||':'||calc.grade_scale_band_id::text||':'||calc.raw_percentage::text||':'||calc.rounded_percentage::text||':'||calc.grade_label||':'||calc.result_state::text||':'||calc.contributing_assessment_count::text||':'||calc.weight_total::text||':'||coalesce((select string_agg(concat_ws(':',z.id,z.assessment_root_id,z.assessment_version_id,z.assessment_id,z.assessment_student_id,z.assessment_result_id,z.score,z.maximum_score,z.assessment_weight,z.score_ratio,z.effective_weight,z.weighted_points),'|' order by z.id) from public.term_grade_calculation_sources z where z.term_grade_calculation_id=calc.id),''),
   '|' order by c.subject_id nulls first)
   from public.term_grading_configurations c
   join public.term_grade_sets g on g.section_id=c.section_id and g.academic_term_id=c.academic_term_id
    and g.subject_id is not distinct from c.subject_id and g.lifecycle_status='finalized'
   join public.term_grade_records r on r.term_grade_set_id=g.id and r.student_id=p_student and r.calculation_sequence=g.calculation_sequence
   join public.term_grade_calculations calc on calc.term_grade_record_id=r.id
   where c.section_id=p_section and c.academic_term_id=p_term and c.status='active'),'')
  ||'|attendance|'||coalesce((select string_agg(s.session_date::text||':'||s.id::text||':'||s.status::text||':'||ss.id::text||':'||ss.student_id::text||':'||m.id::text||':'||m.mark::text||':'||coalesce(m.absence_reason_id::text,'~'),'|' order by s.session_date,s.id)
   from public.academic_terms t join public.attendance_sessions s on s.section_id=p_section and s.session_date between t.start_date and t.end_date and s.status='finalized'
   join public.attendance_session_students ss on ss.session_id=s.id and ss.student_id=p_student
   join public.attendance_marks m on m.session_id=s.id and m.session_student_id=ss.id and m.student_id=p_student
   where t.id=p_term),'')
 ,'sha256');
$$;

create function app_auth.build_report_card(p_student uuid,p_section uuid,p_term uuid,p_batch uuid,p_predecessor uuid,p_actor uuid,p_cmd uuid,p_status public.report_card_status)
returns uuid language plpgsql security definer set search_path='' as $$
declare s public.sections%rowtype; t public.academic_terms%rowtype; st public.students%rowtype; e public.student_enrollments%rowtype;
 p public.student_section_placements%rowtype; sch public.schools%rowtype; cam public.campuses%rowtype; y public.academic_years%rowtype; gl public.grade_levels%rowtype;
 old public.report_cards%rowtype; card public.report_cards%rowtype; g record; src public.term_grade_calculation_sources%rowtype;
 ats public.report_card_attendance_snapshots%rowtype; ar record; gid uuid; sid uuid; n bigint; fp bytea; placement_count integer; context_count integer;
begin
 select * into s from public.sections where id=p_section; if not found then raise exception using errcode='P0002',message='section not found'; end if;
 perform app_auth.lock_report_card_context(s.id,p_term,array[p_student]);
 select * into sch from public.schools where id=s.school_id;
 select * into cam from public.campuses where id=s.campus_id;
 select * into y from public.academic_years where id=s.academic_year_id;
 select * into t from public.academic_terms where id=p_term;
 select * into gl from public.grade_levels where id=s.grade_level_id;
 select * into st from public.students where id=p_student;
 if t.id is null or (t.organization_id,t.academic_year_id)<>(s.organization_id,s.academic_year_id)
  or st.id is null or st.organization_id<>s.organization_id then raise exception using errcode='22023',message='compatible section, term, and student are required'; end if;

 if not app_auth.has_permission(s.organization_id,'report_cards.manage',s.school_id,s.campus_id)
  and not exists(select 1 from public.teaching_assignments ta where ta.section_id=s.id and ta.subject_id is not null and ta.status='active' and current_date<@ta.effective_range and ta.role in('lead','co_teacher','substitute') and app_auth.has_report_card_assignment(s.id,ta.subject_id,array[ta.role]))
  and not app_auth.has_report_card_assignment(s.id,null,array['lead','co_teacher']::public.teaching_assignment_role[])
 then raise exception using errcode='42501',message='report-card creation authority required'; end if;

 select count(*) into placement_count from public.student_section_placements q join public.student_enrollments en on en.id=q.student_enrollment_id
  where q.student_id=st.id and q.section_id=s.id and q.status<>'corrected' and en.status<>'corrected'
   and daterange(q.starts_on,coalesce(q.ends_on,s.end_date),'[]')&&daterange(t.start_date,t.end_date,'[]') and en.enrollment_range&&daterange(t.start_date,t.end_date,'[]');
 if placement_count<>1 then raise exception using errcode='22023',message='one unambiguous term placement is required'; end if;
 select q.* into p from public.student_section_placements q join public.student_enrollments en on en.id=q.student_enrollment_id
  where q.student_id=st.id and q.section_id=s.id and q.status<>'corrected' and en.status<>'corrected'
   and daterange(q.starts_on,coalesce(q.ends_on,s.end_date),'[]')&&daterange(t.start_date,t.end_date,'[]') and en.enrollment_range&&daterange(t.start_date,t.end_date,'[]');
 select * into e from public.student_enrollments where id=p.student_enrollment_id;

 select count(*) into context_count from public.term_grading_configurations c where c.section_id=s.id and c.academic_term_id=t.id and c.status='active';
 if context_count=0 then raise exception using errcode='22023',message='active report-card grade contexts are required'; end if;
 if exists(select 1 from public.term_grading_configurations c where c.section_id=s.id and c.academic_term_id=t.id and c.status='active' and
  (select count(*) from public.term_grade_sets x join public.term_grade_records r on r.term_grade_set_id=x.id and r.student_id=st.id and r.calculation_sequence=x.calculation_sequence
   where x.section_id=s.id and x.academic_term_id=t.id and x.subject_id is not distinct from c.subject_id and x.lifecycle_status='finalized')<>1)
 then raise exception using errcode='22023',message='complete finalized term-grade coverage is required'; end if;

 fp:=app_auth.report_card_source_fingerprint(s.id,t.id,st.id);
 select coalesce(max(report_card_number),0)+1 into n from public.report_cards where school_id=s.school_id;
 if p_predecessor is null then card.id:=gen_random_uuid(); card.lineage_id:=card.id; card.version:=1;
 else select * into old from public.report_cards where id=p_predecessor; card.id:=gen_random_uuid(); card.lineage_id:=old.lineage_id; card.version:=old.version+1; end if;
 insert into public.report_cards(id,organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,student_id,student_enrollment_id,student_section_placement_id,
  lineage_id,version,report_card_number,supersedes_report_card_id,report_card_batch_id,status,finalized_at,finalized_by,published_at,published_by,source_fingerprint,
  school_code,school_name,campus_code,campus_name,academic_year_name,academic_term_name,academic_term_sequence,term_start_date,term_end_date,
  section_code,section_name,grade_level_code,grade_level_name,student_number,student_display_name,created_by,updated_by)
 values(card.id,s.organization_id,s.school_id,s.campus_id,s.academic_year_id,t.id,s.id,st.id,e.id,p.id,card.lineage_id,card.version,n,p_predecessor,p_batch,p_status,
  case when p_status in('finalized','published') then now() end,case when p_status in('finalized','published') then p_actor end,
  case when p_status='published' then now() end,case when p_status='published' then p_actor end,fp,
  sch.code,sch.name,cam.code,cam.name,y.name,t.name,t.sequence,t.start_date,t.end_date,s.code,s.name,gl.code,gl.name,st.student_number,
  concat_ws(' ',st.first_name,nullif(st.middle_name,''),st.last_name),p_actor,p_actor) returning * into card;
 perform app_auth.write_report_card_change(p_cmd,card.organization_id,p_actor,case when p_status='draft' then 'report_card.created' when p_status='published' then 'report_card.published' else 'report_card.finalized' end,'report_card',card.id,null,to_jsonb(card),
  jsonb_build_object('school_id',card.school_id,'campus_id',card.campus_id,'academic_year_id',card.academic_year_id,'academic_term_id',card.academic_term_id,'section_id',card.section_id,'student_id',card.student_id,'lineage_id',card.lineage_id,'version',card.version),p_predecessor is null);

 for g in select c.subject_id,x.term_grading_configuration_id,x.id set_id,x.calculation_sequence,x.source_fingerprint,
   r.id record_id,calc.*,u.code subject_code,u.name subject_name
  from public.term_grading_configurations c
  join public.term_grade_sets x on x.section_id=c.section_id and x.academic_term_id=c.academic_term_id and x.subject_id is not distinct from c.subject_id and x.lifecycle_status='finalized'
  join public.term_grade_records r on r.term_grade_set_id=x.id and r.student_id=st.id and r.calculation_sequence=x.calculation_sequence
  join public.term_grade_calculations calc on calc.term_grade_record_id=r.id
  left join public.subjects u on u.id=c.subject_id
  where c.section_id=s.id and c.academic_term_id=t.id and c.status='active' order by c.subject_id nulls first
 loop
  insert into public.report_card_grade_snapshots(organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,report_card_id,student_id,subject_id,subject_code,subject_name,
   term_grading_configuration_id,term_grade_set_id,term_grade_record_id,term_grade_calculation_id,grade_scale_id,grade_scale_band_id,term_grade_calculation_sequence,
   raw_percentage,rounded_percentage,grade_label,result_state,contributing_assessment_count,weight_total,source_term_grade_fingerprint,created_by)
  values(card.organization_id,card.school_id,card.campus_id,card.academic_year_id,card.academic_term_id,card.section_id,card.id,card.student_id,g.subject_id,g.subject_code,g.subject_name,
   g.term_grading_configuration_id,g.set_id,g.record_id,g.id,g.grade_scale_id,g.grade_scale_band_id,g.calculation_sequence,g.raw_percentage,g.rounded_percentage,g.grade_label,g.result_state,g.contributing_assessment_count,g.weight_total,g.source_fingerprint,p_actor)
  returning id into gid;
  perform app_auth.write_report_card_change(p_cmd,card.organization_id,p_actor,'report_card.grade_snapshotted','report_card_grade_snapshot',gid,null,(select to_jsonb(q) from public.report_card_grade_snapshots q where q.id=gid),null,false);
  for src in select * from public.term_grade_calculation_sources z where z.term_grade_calculation_id=g.id order by z.id loop
   insert into public.report_card_grade_sources(organization_id,report_card_id,report_card_grade_snapshot_id,student_id,term_grade_calculation_source_id,assessment_root_id,assessment_version_id,assessment_id,assessment_student_id,assessment_result_id,score,maximum_score,assessment_weight,score_ratio,effective_weight,weighted_points,created_by)
   values(card.organization_id,card.id,gid,card.student_id,src.id,src.assessment_root_id,src.assessment_version_id,src.assessment_id,src.assessment_student_id,src.assessment_result_id,src.score,src.maximum_score,src.assessment_weight,src.score_ratio,src.effective_weight,src.weighted_points,p_actor) returning id into sid;
   perform app_auth.write_report_card_change(p_cmd,card.organization_id,p_actor,'report_card.grade_source_snapshotted','report_card_grade_source',sid,null,(select to_jsonb(q) from public.report_card_grade_sources q where q.id=sid),null,false);
  end loop;
 end loop;

 insert into public.report_card_attendance_snapshots(organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,report_card_id,student_id,range_start_date,range_end_date,total_session_count,present_count,absent_count,late_count,excused_count,source_fingerprint,created_by)
 select card.organization_id,card.school_id,card.campus_id,card.academic_year_id,card.academic_term_id,card.section_id,card.id,card.student_id,t.start_date,t.end_date,count(m.id)::int,
  count(*)filter(where m.mark='present')::int,count(*)filter(where m.mark='absent')::int,count(*)filter(where m.mark='late')::int,count(*)filter(where m.mark='excused')::int,
  extensions.digest(coalesce(string_agg(ax.id::text||':'||m.id::text||':'||m.mark::text,'|' order by ax.session_date,ax.id),''),'sha256'),p_actor
 from public.attendance_sessions ax join public.attendance_session_students ass on ass.session_id=ax.id and ass.student_id=card.student_id
 join public.attendance_marks m on m.session_id=ax.id and m.session_student_id=ass.id and m.student_id=card.student_id
 where ax.section_id=card.section_id and ax.session_date between t.start_date and t.end_date and ax.status='finalized' returning * into ats;
 perform app_auth.write_report_card_change(p_cmd,card.organization_id,p_actor,'report_card.attendance_snapshotted','report_card_attendance_snapshot',ats.id,null,to_jsonb(ats),null,false);
 for ar in select ax.*,ass.id roster_id,m.id mark_id,m.mark,m.absence_reason_id from public.attendance_sessions ax
  join public.attendance_session_students ass on ass.session_id=ax.id and ass.student_id=card.student_id
  join public.attendance_marks m on m.session_id=ax.id and m.session_student_id=ass.id and m.student_id=card.student_id
  where ax.section_id=card.section_id and ax.session_date between t.start_date and t.end_date and ax.status='finalized' order by ax.session_date,ax.id
 loop
  insert into public.report_card_attendance_sources(organization_id,school_id,campus_id,academic_year_id,section_id,report_card_id,report_card_attendance_snapshot_id,student_id,attendance_session_id,attendance_session_student_id,attendance_mark_id,session_date,mark,absence_reason_id,created_by)
  values(card.organization_id,card.school_id,card.campus_id,card.academic_year_id,card.section_id,card.id,ats.id,card.student_id,ar.id,ar.roster_id,ar.mark_id,ar.session_date,ar.mark,ar.absence_reason_id,p_actor) returning id into sid;
  perform app_auth.write_report_card_change(p_cmd,card.organization_id,p_actor,'report_card.attendance_source_snapshotted','report_card_attendance_source',sid,null,(select to_jsonb(q) from public.report_card_attendance_sources q where q.id=sid),null,false);
 end loop;
 return card.id;
exception when unique_violation then raise exception using errcode='40001',message='report-card head changed; retry';
end $$;

-- v0.9's private lock graph remains intact behind the shared cross-module mutex.
alter function app_auth.lock_term_grade_context(uuid) rename to lock_term_grade_context_v1_0_impl;
create function app_auth.lock_term_grade_context(p_configuration uuid) returns public.term_grading_configurations
language plpgsql security definer set search_path='' as $$
declare c public.term_grading_configurations%rowtype;
begin
 select * into c from public.term_grading_configurations where id=p_configuration;
 if not found then raise exception using errcode='P0002',message='configuration not found'; end if;
 perform app_auth.lock_academic_snapshot_domain(c.organization_id);
 return app_auth.lock_term_grade_context_v1_0_impl(p_configuration);
end $$;

-- Preserve the v0.7 public signature and behavior, acquiring the same mutex before
-- the first attendance row lock.
create or replace function public.correct_attendance_session(id uuid,marks public.attendance_mark_input[],correction_reason text)
returns table(corrected_session_id uuid,replacement_session_id uuid)
language plpgsql security definer set search_path='' as $$
declare a uuid:=app_auth.assert_attendance_actor(); x public.attendance_sessions%rowtype; y public.attendance_sessions%rowtype;
 ss public.attendance_session_students%rowtype; rid uuid; oldj jsonb; newj jsonb; cmd uuid:=gen_random_uuid(); n integer;
begin
 if length(btrim(coalesce(correct_attendance_session.correction_reason,''))) not between 1 and 500
 then raise exception using errcode='22023',message='bounded correction reason is required'; end if;
 select * into x from public.attendance_sessions where attendance_sessions.id=correct_attendance_session.id;
 if not found then raise exception using errcode='P0002',message='attendance session not found'; end if;
 perform app_auth.lock_academic_snapshot_domain(x.organization_id);
 select * into x from public.attendance_sessions where attendance_sessions.id=x.id for update;
 perform app_auth.assert_attendance_manager(x.organization_id,x.school_id,x.campus_id,true);
 if x.status<>'finalized' then raise exception using errcode='22023',message='finalized attendance session is required'; end if;
 perform 1 from public.attendance_sessions q where q.supersedes_session_id=x.id order by q.id for update;
 if found then raise exception using errcode='40001',message='attendance correction head changed; retry'; end if;
 oldj:=to_jsonb(x);
 update public.attendance_sessions set status='corrected',correction_reason=btrim(correct_attendance_session.correction_reason),updated_by=a
  where attendance_sessions.id=x.id returning to_jsonb(attendance_sessions.*) into newj;
 perform app_auth.write_attendance_change(cmd,x.organization_id,a,'attendance.session_corrected','attendance_session',x.id,oldj,newj,
  jsonb_build_object('school_id',x.school_id,'campus_id',x.campus_id,'section_id',x.section_id,'session_date',x.session_date,'correction_reason',btrim(correct_attendance_session.correction_reason)));
 insert into public.attendance_sessions(organization_id,school_id,campus_id,academic_year_id,section_id,session_date,status,submitted_at,submitted_by,finalized_at,finalized_by,supersedes_session_id,created_by,updated_by)
 values(x.organization_id,x.school_id,x.campus_id,x.academic_year_id,x.section_id,x.session_date,'finalized',now(),a,now(),a,x.id,a,a) returning * into y;
 for ss in select * from public.attendance_session_students q where q.session_id=x.id order by q.student_id loop
  rid:=gen_random_uuid();
  insert into public.attendance_session_students(id,organization_id,school_id,campus_id,academic_year_id,section_id,session_id,student_id,student_enrollment_id,student_section_placement_id,created_by)
  values(rid,y.organization_id,y.school_id,y.campus_id,y.academic_year_id,y.section_id,y.id,ss.student_id,ss.student_enrollment_id,ss.student_section_placement_id,a);
  perform app_auth.write_attendance_change(cmd,y.organization_id,a,'attendance.roster_snapshotted','attendance_session_student',rid,null,
   (select to_jsonb(q) from public.attendance_session_students q where q.id=rid),null,false);
 end loop;
 n:=app_auth.insert_attendance_marks(y,correct_attendance_session.marks,a,cmd,'attendance.student_mark_corrected');
 perform app_auth.write_attendance_change(cmd,y.organization_id,a,'attendance.session_finalized','attendance_session',y.id,null,to_jsonb(y),
  jsonb_build_object('school_id',y.school_id,'campus_id',y.campus_id,'section_id',y.section_id,'session_date',y.session_date,'mark_count',n,'supersedes_session_id',x.id));
 return query select x.id,y.id;
end $$;

alter function app_auth.write_academic_change(uuid,uuid,text,text,uuid,jsonb,jsonb)
 rename to write_academic_change_v1_0_parent_impl;
create function app_auth.write_academic_change(o uuid,actor uuid,action_name text,entity_name text,entity uuid,before_row jsonb,after_row jsonb) returns void
language plpgsql security definer set search_path='' as $$
begin
 if entity_name='academic_year' and after_row->>'status' in('closed','archived')
  and exists(select 1 from public.report_cards r where r.academic_year_id=entity and r.status='draft')
 then raise exception using errcode='22023',message='academic year has draft report cards'; end if;
 if entity_name='academic_term' then
  if after_row->>'status' in('closed','archived') and exists(select 1 from public.report_cards r where r.academic_term_id=entity and r.status='draft')
  then raise exception using errcode='22023',message='academic term has draft report cards'; end if;
  if (before_row->>'start_date',before_row->>'end_date') is distinct from (after_row->>'start_date',after_row->>'end_date')
   and exists(select 1 from public.report_cards r where r.academic_term_id=entity and r.status<>'cancelled')
  then raise exception using errcode='22023',message='academic term dates are preserved by report-card snapshots'; end if;
 end if;
 if entity_name='subject' and after_row->>'status' in('inactive','archived')
  and exists(select 1 from public.report_card_grade_snapshots g join public.report_cards r on r.id=g.report_card_id
   where g.subject_id=entity and r.status='draft')
 then raise exception using errcode='22023',message='subject has draft report cards'; end if;
 if entity_name='section' then
  if exists(select 1 from public.report_cards r where r.section_id=entity and r.status='draft')
   and((after_row->>'status')<>'active'
    or (before_row->>'start_date',before_row->>'end_date',before_row->>'academic_term_id') is distinct from
       (after_row->>'start_date',after_row->>'end_date',after_row->>'academic_term_id'))
  then raise exception using errcode='22023',message='section change conflicts with draft report cards'; end if;
  if exists(select 1 from public.report_cards r where r.section_id=entity and r.status in('finalized','published'))
   and (before_row->>'start_date',before_row->>'end_date',before_row->>'academic_term_id') is distinct from
       (after_row->>'start_date',after_row->>'end_date',after_row->>'academic_term_id')
  then raise exception using errcode='22023',message='section scope or dates are preserved by issued report cards'; end if;
 end if;
 perform app_auth.write_academic_change_v1_0_parent_impl(o,actor,action_name,entity_name,entity,before_row,after_row);
end $$;

alter function app_auth.write_sis_change(uuid,uuid,uuid,text,text,uuid,jsonb,jsonb,jsonb)
 rename to write_sis_change_v1_0_parent_impl;
create function app_auth.write_sis_change(p_command_id uuid,p_organization_id uuid,p_actor uuid,p_action text,p_entity_type text,
 p_entity_id uuid,p_before jsonb,p_after jsonb,p_payload jsonb) returns void
language plpgsql security definer set search_path='' as $$
begin
 if p_entity_type='student' then
  if p_after->>'status'='archived' and exists(select 1 from public.report_cards r where r.student_id=p_entity_id and r.status='draft')
  then raise exception using errcode='22023',message='student has draft report cards'; end if;
  if (p_before->>'school_id',p_before->>'campus_id') is distinct from (p_after->>'school_id',p_after->>'campus_id')
   and exists(select 1 from public.report_cards r where r.student_id=p_entity_id and r.status in('finalized','published'))
  then raise exception using errcode='22023',message='student scope is preserved by issued report cards'; end if;
 end if;
 perform app_auth.write_sis_change_v1_0_parent_impl(p_command_id,p_organization_id,p_actor,p_action,p_entity_type,p_entity_id,p_before,p_after,p_payload);
end $$;

alter table public.report_card_batches owner to postgres; alter table public.report_cards owner to postgres;
alter table public.report_card_grade_snapshots owner to postgres; alter table public.report_card_grade_sources owner to postgres;
alter table public.report_card_attendance_snapshots owner to postgres; alter table public.report_card_attendance_sources owner to postgres;
alter table public.report_card_comments owner to postgres; alter table public.report_card_signoffs owner to postgres;
alter table public.report_card_batch_items owner to postgres;

do $$declare f regprocedure;begin foreach f in array array[
 'public.create_report_card(uuid,uuid,uuid)'::regprocedure,'public.create_report_card_batch(uuid,uuid,public.report_card_batch_student_input[])'::regprocedure,
 'public.save_report_card_comment(uuid,public.report_card_comment_type,uuid,text)'::regprocedure,'public.withdraw_report_card_comment(uuid,text)'::regprocedure,
 'public.sign_report_card(uuid,public.report_card_signoff_type,uuid)'::regprocedure,'public.revoke_report_card_signoff(uuid,text)'::regprocedure,
 'public.review_report_card_batch(uuid)'::regprocedure,'public.finalize_report_card(uuid)'::regprocedure,'public.publish_report_card(uuid)'::regprocedure,
 'public.cancel_draft_report_card(uuid,text)'::regprocedure,'public.correct_report_card(uuid,text)'::regprocedure,'public.cancel_report_card_batch(uuid,text)'::regprocedure]
 loop execute format('alter function %s owner to postgres',f);execute format('revoke all on function %s from public,anon,service_role',f);execute format('grant execute on function %s to authenticated',f);end loop;end$$;
do $$declare f regprocedure;begin foreach f in array array[
 'app_auth.report_card_actor()'::regprocedure,'app_auth.has_report_card_assignment(uuid,uuid,public.teaching_assignment_role[])'::regprocedure,
 'app_auth.can_read_report_card_header(uuid)'::regprocedure,'app_auth.can_read_report_card_subject(uuid,uuid)'::regprocedure,
 'app_auth.can_read_report_card_attendance(uuid,boolean)'::regprocedure,'app_auth.can_read_report_card_batch(uuid)'::regprocedure,
 'app_auth.enforce_report_card_immutable_child()'::regprocedure,'app_auth.enforce_report_card_root_immutability()'::regprocedure,
 'app_auth.enforce_report_card_batch_immutability()'::regprocedure,
 'app_auth.enforce_report_card_authored_immutability()'::regprocedure,'app_auth.enforce_report_card_actor_provenance()'::regprocedure,
 'app_auth.enforce_report_card_lineage()'::regprocedure,
 'app_auth.write_report_card_change(uuid,uuid,uuid,text,text,uuid,jsonb,jsonb,jsonb,boolean)'::regprocedure,
 'app_auth.report_card_source_fingerprint(uuid,uuid,uuid)'::regprocedure,'app_auth.lock_academic_snapshot_domain(uuid)'::regprocedure,
 'app_auth.lock_report_card_context(uuid,uuid,uuid[])'::regprocedure,'app_auth.lock_report_card_aggregate(uuid)'::regprocedure,
 'app_auth.build_report_card(uuid,uuid,uuid,uuid,uuid,uuid,uuid,public.report_card_status)'::regprocedure,
 'app_auth.assert_report_card_ready(uuid)'::regprocedure,
 'app_auth.write_academic_change_v1_0_parent_impl(uuid,uuid,text,text,uuid,jsonb,jsonb)'::regprocedure,
 'app_auth.write_sis_change_v1_0_parent_impl(uuid,uuid,uuid,text,text,uuid,jsonb,jsonb,jsonb)'::regprocedure,
 'app_auth.lock_term_grade_context(uuid)'::regprocedure,'app_auth.lock_term_grade_context_v1_0_impl(uuid)'::regprocedure]
 loop execute format('alter function %s owner to postgres',f);execute format('revoke all on function %s from public,anon,authenticated,service_role',f);end loop;end$$;
alter function app_auth.write_academic_change(uuid,uuid,text,text,uuid,jsonb,jsonb) owner to postgres;
alter function app_auth.write_sis_change(uuid,uuid,uuid,text,text,uuid,jsonb,jsonb,jsonb) owner to postgres;
revoke all on function app_auth.write_academic_change(uuid,uuid,text,text,uuid,jsonb,jsonb),
 app_auth.write_sis_change(uuid,uuid,uuid,text,text,uuid,jsonb,jsonb,jsonb) from public,anon,authenticated,service_role;
grant execute on function app_auth.has_report_card_assignment(uuid,uuid,public.teaching_assignment_role[]),app_auth.can_read_report_card_header(uuid),
 app_auth.can_read_report_card_subject(uuid,uuid),app_auth.can_read_report_card_attendance(uuid,boolean),app_auth.can_read_report_card_batch(uuid) to authenticated;

comment on table public.report_cards is 'Immutable term report-card lineage root; writes use typed commands and issued history is append-and-supersede.';
comment on table public.report_card_grade_snapshots is 'Immutable finalized term-grade value and actual configuration-version snapshot.';
comment on table public.report_card_grade_sources is 'Immutable complete grade calculation provenance; never portal-visible.';
comment on table public.report_card_attendance_snapshots is 'Immutable exact-term attendance totals for one report card.';
comment on table public.report_card_attendance_sources is 'Immutable finalized attendance session/roster/mark provenance; never portal-visible.';
comment on table public.report_card_comments is 'Append-preserving authored overall and subject comments.';
comment on table public.report_card_signoffs is 'Attribution-only teacher, homeroom, administrator-review, and correction-certification records.';

commit;
