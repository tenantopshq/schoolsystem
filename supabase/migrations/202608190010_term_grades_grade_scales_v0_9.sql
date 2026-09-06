begin;

create type public.grade_scale_status as enum ('draft','active','retired');
create type public.grade_result_state as enum ('pass','fail');
create type public.term_grading_configuration_status as enum ('draft','active','retired');
create type public.term_grade_lifecycle_status as enum ('draft','finalized','corrected','cancelled');
create type public.term_grade_publication_state as enum ('unpublished','published');
create type public.grade_scale_band_input as (sequence integer,lower_bound numeric,upper_bound numeric,label text,result_state public.grade_result_state);

create table public.grade_scales(
 id uuid primary key default gen_random_uuid(), organization_id uuid not null, school_id uuid not null,
 academic_year_id uuid, name text not null check(length(btrim(name)) between 1 and 120),
 description text check(description is null or length(btrim(description)) between 1 and 1000),
 status public.grade_scale_status not null default 'draft', supersedes_grade_scale_id uuid,
 activated_at timestamptz, activated_by uuid references auth.users(id) on delete restrict,
 retired_at timestamptz, retired_by uuid references auth.users(id) on delete restrict,
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 created_by uuid not null references auth.users(id) on delete restrict,updated_by uuid not null references auth.users(id) on delete restrict,
 foreign key(organization_id,school_id) references public.schools(organization_id,id) on delete restrict,
 foreign key(organization_id,school_id,academic_year_id) references public.academic_years(organization_id,school_id,id) on delete restrict,
 foreign key(organization_id,school_id,supersedes_grade_scale_id) references public.grade_scales(organization_id,school_id,id) on delete restrict,
 unique(organization_id,school_id,id),check(supersedes_grade_scale_id is null or supersedes_grade_scale_id<>id),
 check((status='draft' and activated_at is null and activated_by is null and retired_at is null and retired_by is null)
  or(status='active' and activated_at is not null and activated_by is not null and retired_at is null and retired_by is null)
  or(status='retired' and activated_at is not null and activated_by is not null and retired_at is not null and retired_by is not null))
);
create unique index grade_scales_active_global_name_key on public.grade_scales(school_id,lower(btrim(name))) where status='active' and academic_year_id is null;
create unique index grade_scales_active_year_name_key on public.grade_scales(school_id,academic_year_id,lower(btrim(name))) where status='active' and academic_year_id is not null;
create unique index grade_scales_draft_global_name_key on public.grade_scales(school_id,lower(btrim(name))) where status='draft' and academic_year_id is null;
create unique index grade_scales_draft_year_name_key on public.grade_scales(school_id,academic_year_id,lower(btrim(name))) where status='draft' and academic_year_id is not null;
create unique index grade_scales_one_draft_successor_key on public.grade_scales(supersedes_grade_scale_id) where supersedes_grade_scale_id is not null and status='draft';
create index grade_scales_scope_idx on public.grade_scales(organization_id,school_id,academic_year_id,status,id);
create index grade_scales_created_by_idx on public.grade_scales(created_by); create index grade_scales_updated_by_idx on public.grade_scales(updated_by);

create table public.grade_scale_bands(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,school_id uuid not null,grade_scale_id uuid not null,
 sequence integer not null check(sequence>=1),lower_units integer not null check(lower_units between 0 and 999999),
 upper_units integer not null check(upper_units between 1 and 1000000 and lower_units<upper_units),
 percentage_range int8range generated always as(int8range(lower_units::bigint,upper_units::bigint,'[)')) stored,
 label text not null check(length(btrim(label)) between 1 and 32),result_state public.grade_result_state not null,
 created_at timestamptz not null default now(),created_by uuid not null references auth.users(id) on delete restrict,
 foreign key(organization_id,school_id,grade_scale_id) references public.grade_scales(organization_id,school_id,id) on delete restrict,
 unique(organization_id,grade_scale_id,id),unique(grade_scale_id,sequence)
);
create unique index grade_scale_bands_label_key on public.grade_scale_bands(grade_scale_id,lower(btrim(label)));
alter table public.grade_scale_bands add constraint grade_scale_bands_no_overlap exclude using gist(grade_scale_id with =,percentage_range with &&);
create index grade_scale_bands_scope_idx on public.grade_scale_bands(organization_id,school_id,grade_scale_id,sequence);

create table public.term_grading_configurations(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,school_id uuid not null,campus_id uuid not null,
 academic_year_id uuid not null,academic_term_id uuid not null,section_id uuid not null,subject_id uuid,grade_scale_id uuid not null,
 status public.term_grading_configuration_status not null default 'draft',require_weights_total_100 boolean not null default true check(require_weights_total_100),
 include_unpublished_finalized boolean not null default false check(not include_unpublished_finalized),supersedes_configuration_id uuid,
 activated_at timestamptz,activated_by uuid references auth.users(id) on delete restrict,retired_at timestamptz,retired_by uuid references auth.users(id) on delete restrict,
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),created_by uuid not null references auth.users(id) on delete restrict,updated_by uuid not null references auth.users(id) on delete restrict,
 foreign key(organization_id,school_id,campus_id,academic_year_id,section_id) references public.sections(organization_id,school_id,campus_id,academic_year_id,id) on delete restrict,
 foreign key(organization_id,academic_year_id,academic_term_id) references public.academic_terms(organization_id,academic_year_id,id) on delete restrict,
 foreign key(organization_id,school_id,subject_id) references public.subjects(organization_id,school_id,id) on delete restrict,
 foreign key(organization_id,school_id,grade_scale_id) references public.grade_scales(organization_id,school_id,id) on delete restrict,
 foreign key(organization_id,supersedes_configuration_id) references public.term_grading_configurations(organization_id,id) on delete restrict,
 unique(organization_id,id),unique(organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,id),
 check(supersedes_configuration_id is null or supersedes_configuration_id<>id),
 check((status='draft' and activated_at is null and activated_by is null and retired_at is null and retired_by is null)
 or(status='active' and activated_at is not null and activated_by is not null and retired_at is null and retired_by is null)
 or(status='retired' and activated_at is not null and activated_by is not null and retired_at is not null and retired_by is not null))
);
create unique index term_configs_active_null_key on public.term_grading_configurations(section_id,academic_term_id) where status='active' and subject_id is null;
create unique index term_configs_active_subject_key on public.term_grading_configurations(section_id,academic_term_id,subject_id) where status='active' and subject_id is not null;
create unique index term_configs_draft_null_key on public.term_grading_configurations(section_id,academic_term_id) where status='draft' and subject_id is null;
create unique index term_configs_draft_subject_key on public.term_grading_configurations(section_id,academic_term_id,subject_id) where status='draft' and subject_id is not null;
create unique index term_configs_one_draft_successor_key on public.term_grading_configurations(supersedes_configuration_id) where supersedes_configuration_id is not null and status='draft';
create index term_configs_scope_idx on public.term_grading_configurations(organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,status);

create table public.term_grade_sets(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,school_id uuid not null,campus_id uuid not null,
 academic_year_id uuid not null,academic_term_id uuid not null,section_id uuid not null,subject_id uuid,term_grading_configuration_id uuid not null,
 lifecycle_status public.term_grade_lifecycle_status not null default 'draft',publication_state public.term_grade_publication_state not null default 'unpublished',
 calculation_sequence integer not null default 1 check(calculation_sequence>=1),source_fingerprint bytea not null check(octet_length(source_fingerprint)=32),
 published_at timestamptz,published_by uuid references auth.users(id) on delete restrict,finalized_at timestamptz,finalized_by uuid references auth.users(id) on delete restrict,
 cancellation_reason text,cancelled_at timestamptz,cancelled_by uuid references auth.users(id) on delete restrict,
 correction_reason text,supersedes_term_grade_set_id uuid,
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),created_by uuid not null references auth.users(id) on delete restrict,updated_by uuid not null references auth.users(id) on delete restrict,
 foreign key(organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,term_grading_configuration_id) references public.term_grading_configurations(organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,id) on delete restrict,
 foreign key(organization_id,supersedes_term_grade_set_id) references public.term_grade_sets(organization_id,id) on delete restrict,
 unique(organization_id,id),unique(organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,id),
 check(cancellation_reason is null or length(btrim(cancellation_reason)) between 1 and 500),check(correction_reason is null or length(btrim(correction_reason)) between 1 and 500),
 check((lifecycle_status='draft' and finalized_at is null and finalized_by is null and cancellation_reason is null and correction_reason is null)
 or(lifecycle_status='finalized' and finalized_at is not null and finalized_by is not null and cancellation_reason is null and correction_reason is null)
 or(lifecycle_status='corrected' and finalized_at is not null and finalized_by is not null and correction_reason is not null and cancellation_reason is null)
 or(lifecycle_status='cancelled' and publication_state='unpublished' and cancelled_at is not null and cancelled_by is not null and cancellation_reason is not null)),
 check((publication_state='unpublished' and published_at is null and published_by is null)or(publication_state='published' and published_at is not null and published_by is not null))
);
create unique index term_grade_sets_live_null_key on public.term_grade_sets(section_id,academic_term_id) where subject_id is null and lifecycle_status not in('corrected','cancelled');
create unique index term_grade_sets_live_subject_key on public.term_grade_sets(section_id,academic_term_id,subject_id) where subject_id is not null and lifecycle_status not in('corrected','cancelled');
create unique index term_grade_sets_one_successor_key on public.term_grade_sets(supersedes_term_grade_set_id) where supersedes_term_grade_set_id is not null;
create index term_grade_sets_scope_idx on public.term_grade_sets(organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,lifecycle_status,publication_state);

create table public.term_grade_records(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,school_id uuid not null,campus_id uuid not null,academic_year_id uuid not null,academic_term_id uuid not null,section_id uuid not null,subject_id uuid,term_grading_configuration_id uuid not null,term_grade_set_id uuid not null,student_id uuid not null,calculation_sequence integer not null check(calculation_sequence>=1),created_at timestamptz not null default now(),created_by uuid not null references auth.users(id) on delete restrict,
 foreign key(organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,term_grade_set_id) references public.term_grade_sets(organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,id) on delete restrict,
 foreign key(organization_id,student_id) references public.students(organization_id,id) on delete restrict,
 unique(organization_id,id),unique(term_grade_set_id,calculation_sequence,student_id)
);
create index term_grade_records_student_idx on public.term_grade_records(organization_id,student_id,term_grade_set_id,calculation_sequence);

create table public.term_grade_calculations(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,term_grade_set_id uuid not null,term_grade_record_id uuid not null,student_id uuid not null,calculation_sequence integer not null,
 raw_percentage numeric(20,10) not null,rounded_percentage numeric(7,4) not null check(rounded_percentage between 0 and 100),grade_scale_id uuid not null,grade_scale_band_id uuid not null,
 grade_label text not null,result_state public.grade_result_state not null,contributing_assessment_count integer not null check(contributing_assessment_count>=0),weight_total numeric(7,4) not null,
 calculated_at timestamptz not null default now(),calculated_by uuid not null references auth.users(id) on delete restrict,
 foreign key(organization_id,term_grade_record_id) references public.term_grade_records(organization_id,id) on delete restrict,
 foreign key(organization_id,grade_scale_id,grade_scale_band_id) references public.grade_scale_bands(organization_id,grade_scale_id,id) on delete restrict,
 unique(organization_id,id),unique(term_grade_record_id)
);
create index term_grade_calculations_set_idx on public.term_grade_calculations(organization_id,term_grade_set_id,student_id);

create table public.term_grade_calculation_sources(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,term_grade_calculation_id uuid not null,student_id uuid not null,
 assessment_root_id uuid not null,assessment_version_id uuid not null,assessment_id uuid not null,assessment_student_id uuid not null,assessment_result_id uuid not null,
 score numeric(12,4) not null,maximum_score numeric(12,4) not null,assessment_weight numeric(7,4) not null,
 score_ratio numeric(20,10) not null,effective_weight numeric(20,10) not null,weighted_points numeric(20,10) not null,
 created_at timestamptz not null default now(),created_by uuid not null references auth.users(id) on delete restrict,
 foreign key(organization_id,term_grade_calculation_id) references public.term_grade_calculations(organization_id,id) on delete restrict,
 foreign key(organization_id,assessment_id) references public.assessments(organization_id,id) on delete restrict,
 foreign key(organization_id,assessment_student_id) references public.assessment_students(organization_id,id) on delete restrict,
 foreign key(organization_id,assessment_result_id) references public.assessment_results(organization_id,id) on delete restrict,
 unique(term_grade_calculation_id,assessment_id)
);
create index term_grade_sources_assessment_idx on public.term_grade_calculation_sources(organization_id,assessment_id,student_id);
create index term_grade_sources_result_idx on public.term_grade_calculation_sources(organization_id,assessment_result_id);

alter table public.term_grade_records
 add constraint term_grade_records_exact_calculation_identity_key
 unique(organization_id,term_grade_set_id,student_id,calculation_sequence,id);
alter table public.term_grade_calculations
 add constraint term_grade_calculations_exact_record_fk
 foreign key(organization_id,term_grade_set_id,student_id,calculation_sequence,term_grade_record_id)
 references public.term_grade_records(organization_id,term_grade_set_id,student_id,calculation_sequence,id) on delete restrict,
 add constraint term_grade_calculations_exact_source_identity_key
 unique(organization_id,id,student_id);
alter table public.assessment_students
 add constraint assessment_students_term_grade_source_key
 unique(organization_id,assessment_id,student_id,id);
alter table public.assessment_results
 add constraint assessment_results_term_grade_source_key
 unique(organization_id,assessment_id,student_id,assessment_student_id,id);
alter table public.term_grade_calculation_sources
 add constraint term_grade_sources_version_matches_assessment check(assessment_version_id=assessment_id),
 add constraint term_grade_sources_exact_calculation_fk
 foreign key(organization_id,term_grade_calculation_id,student_id)
 references public.term_grade_calculations(organization_id,id,student_id) on delete restrict,
 add constraint term_grade_sources_root_fk
 foreign key(organization_id,assessment_root_id) references public.assessments(organization_id,id) on delete restrict,
 add constraint term_grade_sources_version_fk
 foreign key(organization_id,assessment_version_id) references public.assessments(organization_id,id) on delete restrict,
 add constraint term_grade_sources_exact_snapshot_fk
 foreign key(organization_id,assessment_id,student_id,assessment_student_id)
 references public.assessment_students(organization_id,assessment_id,student_id,id) on delete restrict,
 add constraint term_grade_sources_exact_result_fk
 foreign key(organization_id,assessment_id,student_id,assessment_student_id,assessment_result_id)
 references public.assessment_results(organization_id,assessment_id,student_id,assessment_student_id,id) on delete restrict;

insert into public.permissions(code,module,description) values
 ('term_grades.view','term_grades','View grade scales, term-grade configuration, and term grades within assigned scope'),
 ('term_grades.manage','term_grades','Manage grade scales, configuration, drafts, publication, and finalization within assigned scope'),
 ('term_grades.correct','term_grades','Correct finalized term-grade sets within assigned scope');

create function app_auth.term_grade_actor() returns uuid language plpgsql security definer set search_path='' as $$declare a uuid:=auth.uid();begin if a is null then raise exception using errcode='42501',message='authentication required';end if;return a;end$$;
create function app_auth.has_term_grade_assignment(p_section uuid,p_subject uuid,p_roles public.teaching_assignment_role[]) returns boolean language sql stable security definer set search_path='' as $$select app_auth.has_assessment_assignment_context(p_section,p_subject,p_roles)$$;
create function app_auth.can_manage_term_grade_context(o uuid,s uuid,c uuid,sec uuid,sub uuid) returns boolean language sql stable security definer set search_path='' as $$select app_auth.has_permission(o,'term_grades.manage',s,c) or app_auth.has_term_grade_assignment(sec,sub,array['lead','co_teacher','substitute']::public.teaching_assignment_role[])$$;
create function app_auth.write_term_grade_change(cmd uuid,o uuid,actor uuid,action_name text,entity_name text,entity uuid,before_row jsonb,after_row jsonb,payload jsonb,emit boolean default true) returns void language plpgsql security definer set search_path='' as $$begin insert into public.audit_log(command_id,organization_id,actor_user_id,action,entity_type,entity_id,before_data,after_data)values(cmd,o,actor,action_name,entity_name,entity,before_row,after_row);if emit then insert into public.event_outbox(command_id,organization_id,event_type,aggregate_type,aggregate_id,payload)values(cmd,o,action_name,entity_name,entity,jsonb_strip_nulls(coalesce(payload,'{}')||jsonb_build_object('command_id',cmd,'actor_user_id',actor,'organization_id',o,'aggregate_id',entity)));end if;end$$;

create function app_auth.can_read_term_grade_set(x uuid) returns boolean language sql stable security definer set search_path='' as $$select exists(select 1 from public.term_grade_sets g where g.id=x and(app_auth.has_permission(g.organization_id,'term_grades.view',g.school_id,g.campus_id)or app_auth.has_permission(g.organization_id,'term_grades.manage',g.school_id,g.campus_id)or app_auth.has_permission(g.organization_id,'term_grades.correct',g.school_id,g.campus_id)or app_auth.has_term_grade_assignment(g.section_id,g.subject_id,array['lead','co_teacher','assistant','substitute']::public.teaching_assignment_role[])or(g.publication_state='published' and g.lifecycle_status in('draft','finalized')and exists(select 1 from public.term_grade_records r join public.students st on st.id=r.student_id and st.status='active' where r.term_grade_set_id=g.id and r.calculation_sequence=g.calculation_sequence and(app_auth.is_student_self(r.student_id)or app_auth.is_linked_guardian(r.student_id))))))$$;
create function app_auth.can_read_term_grade_record(x uuid) returns boolean language sql stable security definer set search_path='' as $$select exists(select 1 from public.term_grade_records r join public.term_grade_sets g on g.id=r.term_grade_set_id join public.students st on st.id=r.student_id where r.id=x and((app_auth.can_read_term_grade_set(g.id)and not(g.publication_state='published' and not(app_auth.has_permission(g.organization_id,'term_grades.view',g.school_id,g.campus_id)or app_auth.has_permission(g.organization_id,'term_grades.manage',g.school_id,g.campus_id)or app_auth.has_term_grade_assignment(g.section_id,g.subject_id,array['lead','co_teacher','assistant','substitute']::public.teaching_assignment_role[]))))or(g.publication_state='published'and g.lifecycle_status in('draft','finalized')and r.calculation_sequence=g.calculation_sequence and st.status='active'and(app_auth.is_student_self(r.student_id)or app_auth.is_linked_guardian(r.student_id)))))$$;
create function app_auth.can_read_term_grade_calculation(x uuid) returns boolean language sql stable security definer set search_path='' as $$select exists(select 1 from public.term_grade_calculations c where c.id=x and app_auth.can_read_term_grade_record(c.term_grade_record_id))$$;

alter table public.grade_scales enable row level security;alter table public.grade_scales force row level security;
alter table public.grade_scale_bands enable row level security;alter table public.grade_scale_bands force row level security;
alter table public.term_grading_configurations enable row level security;alter table public.term_grading_configurations force row level security;
alter table public.term_grade_sets enable row level security;alter table public.term_grade_sets force row level security;
alter table public.term_grade_records enable row level security;alter table public.term_grade_records force row level security;
alter table public.term_grade_calculations enable row level security;alter table public.term_grade_calculations force row level security;
alter table public.term_grade_calculation_sources enable row level security;alter table public.term_grade_calculation_sources force row level security;
create policy grade_scales_select on public.grade_scales for select to authenticated using(app_auth.has_permission(organization_id,'term_grades.view',school_id,null)or app_auth.has_permission(organization_id,'term_grades.manage',school_id,null));
create policy grade_scale_bands_select on public.grade_scale_bands for select to authenticated using(exists(select 1 from public.grade_scales s where s.id=grade_scale_id));
create policy term_configs_select on public.term_grading_configurations for select to authenticated using(app_auth.has_permission(organization_id,'term_grades.view',school_id,campus_id)or app_auth.has_permission(organization_id,'term_grades.manage',school_id,campus_id)or app_auth.has_term_grade_assignment(section_id,subject_id,array['lead','co_teacher','assistant','substitute']::public.teaching_assignment_role[]));
create policy term_grade_sets_select on public.term_grade_sets for select to authenticated using(app_auth.can_read_term_grade_set(id));
create policy term_grade_records_select on public.term_grade_records for select to authenticated using(app_auth.can_read_term_grade_record(id));
create policy term_grade_calculations_select on public.term_grade_calculations for select to authenticated using(app_auth.can_read_term_grade_calculation(id));
create policy term_grade_sources_select on public.term_grade_calculation_sources for select to authenticated using(app_auth.has_permission(organization_id,'term_grades.view',null,null)or exists(select 1 from public.term_grade_calculations c where c.id=term_grade_calculation_id and app_auth.can_read_term_grade_calculation(c.id)and not(app_auth.is_student_self(student_id)or app_auth.is_linked_guardian(student_id))));
revoke all on public.grade_scales,public.grade_scale_bands,public.term_grading_configurations,public.term_grade_sets,public.term_grade_records,public.term_grade_calculations,public.term_grade_calculation_sources from public,anon,authenticated;
grant select on public.grade_scales,public.grade_scale_bands,public.term_grading_configurations,public.term_grade_sets,public.term_grade_records,public.term_grade_calculations,public.term_grade_calculation_sources to authenticated;

-- Commands are intentionally narrow; all scope and attribution are derived.
create function public.create_grade_scale(school_id uuid,academic_year_id uuid,name text,description text,bands public.grade_scale_band_input[]) returns uuid language plpgsql security definer set search_path='' as $$declare a uuid:=app_auth.term_grade_actor();s public.schools%rowtype;y public.academic_years%rowtype;g public.grade_scales%rowtype;b public.grade_scale_band_input;cmd uuid:=gen_random_uuid();u integer;bid uuid;begin select * into s from public.schools where id=create_grade_scale.school_id for update;if not found then raise exception using errcode='P0002',message='school not found';end if;if not app_auth.has_permission(s.organization_id,'term_grades.manage',s.id,null)then raise exception using errcode='42501',message='term_grades.manage permission is required';end if;if academic_year_id is not null then select * into y from public.academic_years where id=academic_year_id for update;if not found or(y.organization_id,y.school_id)<>(s.organization_id,s.id)then raise exception using errcode='22023',message='compatible academic year is required';end if;end if;if bands is null or cardinality(bands)=0 or cardinality(bands)>100 then raise exception using errcode='22023',message='bounded bands are required';end if;insert into public.grade_scales(organization_id,school_id,academic_year_id,name,description,created_by,updated_by)values(s.organization_id,s.id,academic_year_id,btrim(name),case when description is null then null else btrim(description)end,a,a)returning * into g;for b in select(z).* from unnest(bands)z order by(z).sequence loop if scale((b).lower_bound)>4 or scale((b).upper_bound)>4 then raise exception using errcode='22023',message='band bounds allow four decimals';end if;u:=round((b).lower_bound*10000);insert into public.grade_scale_bands(organization_id,school_id,grade_scale_id,sequence,lower_units,upper_units,label,result_state,created_by)values(g.organization_id,g.school_id,g.id,(b).sequence,u,round((b).upper_bound*10000),btrim((b).label),(b).result_state,a)returning id into bid;perform app_auth.write_term_grade_change(cmd,g.organization_id,a,'grade_scale.band_created','grade_scale_band',bid,null,(select to_jsonb(x)from public.grade_scale_bands x where x.id=bid),null,false);end loop;perform app_auth.write_term_grade_change(cmd,g.organization_id,a,'grade_scale.created','grade_scale',g.id,null,to_jsonb(g),jsonb_build_object('school_id',g.school_id,'academic_year_id',g.academic_year_id,'band_count',cardinality(bands)));return g.id;end$$;

-- Remaining implementation is supplied by private generic commands with typed wrappers.
create function app_auth.grade_scale_command(op text,p_id uuid,p_name text,p_description text,p_set_description boolean,p_bands public.grade_scale_band_input[]) returns uuid language plpgsql security definer set search_path='' as $$declare a uuid:=app_auth.term_grade_actor();g public.grade_scales%rowtype;oldj jsonb;newj jsonb;cmd uuid:=gen_random_uuid();b public.grade_scale_band_input;bid uuid;begin select * into g from public.grade_scales where id=p_id for update;if not found then raise exception using errcode='P0002',message='grade scale not found';end if;if not app_auth.has_permission(g.organization_id,'term_grades.manage',g.school_id,null)then raise exception using errcode='42501',message='term_grades.manage permission is required';end if;oldj:=to_jsonb(g);if op='update' then if g.status<>'draft' then raise exception using errcode='22023',message='draft grade scale is required';end if;for bid in select id from public.grade_scale_bands where grade_scale_id=g.id order by sequence,id loop perform app_auth.write_term_grade_change(cmd,g.organization_id,a,'grade_scale.band_deleted','grade_scale_band',bid,(select to_jsonb(x)from public.grade_scale_bands x where x.id=bid),null,null,false);end loop;delete from public.grade_scale_bands where grade_scale_id=g.id;update public.grade_scales set name=btrim(p_name),description=case when p_set_description then case when p_description is null then null else btrim(p_description)end else description end,updated_by=a where id=g.id returning * into g;for b in select(z).* from unnest(p_bands)z order by(z).sequence loop insert into public.grade_scale_bands(organization_id,school_id,grade_scale_id,sequence,lower_units,upper_units,label,result_state,created_by)values(g.organization_id,g.school_id,g.id,(b).sequence,round((b).lower_bound*10000),round((b).upper_bound*10000),btrim((b).label),(b).result_state,a)returning id into bid;perform app_auth.write_term_grade_change(cmd,g.organization_id,a,'grade_scale.band_created','grade_scale_band',bid,null,(select to_jsonb(x)from public.grade_scale_bands x where x.id=bid),null,false);end loop;perform app_auth.write_term_grade_change(cmd,g.organization_id,a,'grade_scale.updated','grade_scale',g.id,oldj,to_jsonb(g),jsonb_build_object('school_id',g.school_id));elsif op='activate' then if g.status<>'draft'or exists(select 1 from public.grade_scale_bands x where x.grade_scale_id=g.id and(x.sequence<>(select count(*)from public.grade_scale_bands y where y.grade_scale_id=g.id and y.sequence<=x.sequence)or(x.sequence=1 and x.lower_units<>0)or(x.sequence=(select count(*)from public.grade_scale_bands y where y.grade_scale_id=g.id)and x.upper_units<>1000000)or(x.sequence>1 and x.lower_units<>(select p.upper_units from public.grade_scale_bands p where p.grade_scale_id=g.id and p.sequence=x.sequence-1))))then raise exception using errcode='22023',message='complete contiguous grade bands are required';end if;if g.supersedes_grade_scale_id is not null then update public.grade_scales set status='retired',retired_at=now(),retired_by=a,updated_by=a where id=g.supersedes_grade_scale_id and status='active';end if;update public.grade_scales set status='active',activated_at=now(),activated_by=a,updated_by=a where id=g.id returning * into g;perform app_auth.write_term_grade_change(cmd,g.organization_id,a,'grade_scale.activated','grade_scale',g.id,oldj,to_jsonb(g),jsonb_build_object('school_id',g.school_id));elsif op='retire' then if g.status<>'active' then raise exception using errcode='22023',message='active grade scale is required';end if;update public.grade_scales set status='retired',retired_at=now(),retired_by=a,updated_by=a where id=g.id returning * into g;perform app_auth.write_term_grade_change(cmd,g.organization_id,a,'grade_scale.retired','grade_scale',g.id,oldj,to_jsonb(g),jsonb_build_object('school_id',g.school_id));end if;return g.id;end$$;
create function public.update_draft_grade_scale(id uuid,name text,description text,set_description boolean,bands public.grade_scale_band_input[])returns uuid language sql security definer set search_path='' as $$select app_auth.grade_scale_command('update',id,name,description,set_description,bands)$$;
create function public.activate_grade_scale(id uuid)returns uuid language sql security definer set search_path='' as $$select app_auth.grade_scale_command('activate',id,null,null,false,null)$$;
create function public.retire_grade_scale(id uuid)returns uuid language sql security definer set search_path='' as $$select app_auth.grade_scale_command('retire',id,null,null,false,null)$$;
create function public.revise_grade_scale(id uuid,replacement_name text,replacement_description text,replacement_bands public.grade_scale_band_input[])returns uuid language plpgsql security definer set search_path='' as $$declare g public.grade_scales%rowtype;r uuid;begin select * into g from public.grade_scales where grade_scales.id=revise_grade_scale.id for update;if g.status not in('active','retired')then raise exception using errcode='22023',message='active or retired scale head is required';end if;r:=public.create_grade_scale(g.school_id,g.academic_year_id,replacement_name,replacement_description,replacement_bands);update public.grade_scales set supersedes_grade_scale_id=g.id where grade_scales.id=r;return r;end$$;

-- Configuration and term-grade commands.
create function public.create_term_grading_configuration(section_id uuid,academic_term_id uuid,subject_id uuid,grade_scale_id uuid,require_weights_total_100 boolean,include_unpublished_finalized boolean)returns uuid language plpgsql security definer set search_path='' as $$declare a uuid:=app_auth.term_grade_actor();s public.sections%rowtype;g public.grade_scales%rowtype;r public.term_grading_configurations%rowtype;cmd uuid:=gen_random_uuid();begin select * into s from public.sections where id=section_id for update;select * into g from public.grade_scales where id=grade_scale_id for update;if s.id is null or g.id is null or g.status<>'active'or(g.academic_year_id is not null and g.academic_year_id<>s.academic_year_id)or(g.organization_id,g.school_id)<>(s.organization_id,s.school_id)or not require_weights_total_100 or include_unpublished_finalized then raise exception using errcode='22023',message='active compatible parents and approved rules are required';end if;if not app_auth.has_permission(s.organization_id,'term_grades.manage',s.school_id,s.campus_id)then raise exception using errcode='42501',message='term_grades.manage permission is required';end if;insert into public.term_grading_configurations(organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,subject_id,grade_scale_id,created_by,updated_by)values(s.organization_id,s.school_id,s.campus_id,s.academic_year_id,academic_term_id,s.id,subject_id,g.id,a,a)returning*into r;perform app_auth.write_term_grade_change(cmd,r.organization_id,a,'term_grading_configuration.created','term_grading_configuration',r.id,null,to_jsonb(r),jsonb_build_object('school_id',r.school_id,'campus_id',r.campus_id,'section_id',r.section_id));return r.id;end$$;
create function app_auth.term_config_command(op text,p_id uuid,p_scale uuid)returns uuid language plpgsql security definer set search_path='' as $$declare a uuid:=app_auth.term_grade_actor();c public.term_grading_configurations%rowtype;oldj jsonb;cmd uuid:=gen_random_uuid();begin select*into c from public.term_grading_configurations where id=p_id for update;if not found then raise exception using errcode='P0002',message='configuration not found';end if;if not app_auth.has_permission(c.organization_id,'term_grades.manage',c.school_id,c.campus_id)then raise exception using errcode='42501',message='term_grades.manage permission is required';end if;oldj:=to_jsonb(c);if op='update'then if c.status<>'draft'then raise exception using errcode='22023',message='draft configuration required';end if;update public.term_grading_configurations set grade_scale_id=p_scale,updated_by=a where id=c.id returning*into c;elsif op='activate'then if c.status<>'draft'or not exists(select 1 from public.grade_scales g where g.id=c.grade_scale_id and g.status='active')then raise exception using errcode='22023',message='draft configuration with active scale required';end if;if c.supersedes_configuration_id is not null then update public.term_grading_configurations set status='retired',retired_at=now(),retired_by=a,updated_by=a where id=c.supersedes_configuration_id and status='active';end if;update public.term_grading_configurations set status='active',activated_at=now(),activated_by=a,updated_by=a where id=c.id returning*into c;elsif op='retire'then update public.term_grading_configurations set status='retired',retired_at=now(),retired_by=a,updated_by=a where id=c.id and status='active'returning*into c;end if;perform app_auth.write_term_grade_change(cmd,c.organization_id,a,'term_grading_configuration.'||case when op='update'then'updated'else op||'d'end,'term_grading_configuration',c.id,oldj,to_jsonb(c),jsonb_build_object('school_id',c.school_id,'campus_id',c.campus_id));return c.id;end$$;
create function public.update_draft_term_grading_configuration(id uuid,grade_scale_id uuid,require_weights_total_100 boolean,include_unpublished_finalized boolean)returns uuid language plpgsql security definer set search_path='' as $$begin if not require_weights_total_100 or include_unpublished_finalized then raise exception using errcode='22023',message='approved rules are fixed';end if;return app_auth.term_config_command('update',id,grade_scale_id);end$$;
create function public.activate_term_grading_configuration(id uuid)returns uuid language sql security definer set search_path='' as $$select app_auth.term_config_command('activate',id,null)$$;
create function public.retire_term_grading_configuration(id uuid)returns uuid language sql security definer set search_path='' as $$select app_auth.term_config_command('retire',id,null)$$;
create function public.revise_term_grading_configuration(id uuid,replacement_grade_scale_id uuid,replacement_require_weights_total_100 boolean,replacement_include_unpublished_finalized boolean)returns uuid language plpgsql security definer set search_path='' as $$declare c public.term_grading_configurations%rowtype;r uuid;begin select*into c from public.term_grading_configurations where term_grading_configurations.id=revise_term_grading_configuration.id for update;if not found then raise exception using errcode='P0002',message='configuration not found';end if;if c.status<>'active'then raise exception using errcode='22023',message='active configuration required';end if;r:=public.create_term_grading_configuration(c.section_id,c.academic_term_id,c.subject_id,replacement_grade_scale_id,replacement_require_weights_total_100,replacement_include_unpublished_finalized);update public.term_grading_configurations set supersedes_configuration_id=c.id where term_grading_configurations.id=r;return r;end$$;

create function app_auth.populate_term_grade_set(p_set uuid,p_sequence integer,p_actor uuid,p_cmd uuid)returns integer language plpgsql security definer set search_path='' as $$declare g public.term_grade_sets%rowtype;c public.term_grading_configurations%rowtype;st uuid;r public.term_grade_records%rowtype;calc public.term_grade_calculations%rowtype;src record;source_id uuid;raw numeric;rounded numeric;band public.grade_scale_bands%rowtype;n integer:=0;cnt integer;total numeric;begin select*into g from public.term_grade_sets where id=p_set;select*into c from public.term_grading_configurations where id=g.term_grading_configuration_id;select count(*),sum(weight)into cnt,total from public.assessments a where a.section_id=g.section_id and a.academic_term_id=g.academic_term_id and a.subject_id is not distinct from g.subject_id and a.lifecycle_status='finalized'and a.publication_state='published';if cnt=0 then return 0;end if;if total<>100 or exists(select 1 from public.assessments a where a.section_id=g.section_id and a.academic_term_id=g.academic_term_id and a.subject_id is not distinct from g.subject_id and a.lifecycle_status='finalized'and a.publication_state='published'and a.weight is null)then raise exception using errcode='22023',message='contributing weights must total 100 with no nulls';end if;if exists(select student_id from public.assessment_students x join public.assessments a on a.id=x.assessment_id where a.section_id=g.section_id and a.academic_term_id=g.academic_term_id and a.subject_id is not distinct from g.subject_id and a.lifecycle_status='finalized'and a.publication_state='published'group by student_id having count(*)<>cnt)then raise exception using errcode='22023',message='identical complete assessment rosters are required';end if;for st in select distinct x.student_id from public.assessment_students x join public.assessments a on a.id=x.assessment_id where a.section_id=g.section_id and a.academic_term_id=g.academic_term_id and a.subject_id is not distinct from g.subject_id and a.lifecycle_status='finalized'and a.publication_state='published'order by x.student_id loop select sum((ar.score/a.maximum_score)*a.weight)into raw from public.assessments a join public.assessment_results ar on ar.assessment_id=a.id and ar.student_id=st where a.section_id=g.section_id and a.academic_term_id=g.academic_term_id and a.subject_id is not distinct from g.subject_id and a.lifecycle_status='finalized'and a.publication_state='published';rounded:=round(raw,4);select*into band from public.grade_scale_bands b where b.grade_scale_id=c.grade_scale_id and(case when rounded=100 then b.upper_units=1000000 else b.percentage_range@>(rounded*10000)::bigint end);insert into public.term_grade_records(organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,subject_id,term_grading_configuration_id,term_grade_set_id,student_id,calculation_sequence,created_by)values(g.organization_id,g.school_id,g.campus_id,g.academic_year_id,g.academic_term_id,g.section_id,g.subject_id,c.id,g.id,st,p_sequence,p_actor)returning*into r;insert into public.term_grade_calculations(organization_id,term_grade_set_id,term_grade_record_id,student_id,calculation_sequence,raw_percentage,rounded_percentage,grade_scale_id,grade_scale_band_id,grade_label,result_state,contributing_assessment_count,weight_total,calculated_by)values(g.organization_id,g.id,r.id,st,p_sequence,raw,rounded,c.grade_scale_id,band.id,band.label,band.result_state,cnt,total,p_actor)returning*into calc;perform app_auth.write_term_grade_change(p_cmd,g.organization_id,p_actor,'term_grade.calculated','term_grade_record',r.id,null,to_jsonb(r),jsonb_build_object('term_grade_set_id',g.id,'student_id',st,'rounded_percentage',rounded,'grade_label',band.label));perform app_auth.write_term_grade_change(p_cmd,g.organization_id,p_actor,'term_grade.calculation_recorded','term_grade_calculation',calc.id,null,to_jsonb(calc),null,false);for src in select a.*,ar.id result_id,ar.score,ast.id snapshot_id from public.assessments a join public.assessment_students ast on ast.assessment_id=a.id and ast.student_id=st join public.assessment_results ar on ar.assessment_id=a.id and ar.student_id=st where a.section_id=g.section_id and a.academic_term_id=g.academic_term_id and a.subject_id is not distinct from g.subject_id and a.lifecycle_status='finalized'and a.publication_state='published'order by a.id loop insert into public.term_grade_calculation_sources(organization_id,term_grade_calculation_id,student_id,assessment_root_id,assessment_version_id,assessment_id,assessment_student_id,assessment_result_id,score,maximum_score,assessment_weight,score_ratio,effective_weight,weighted_points,created_by)values(g.organization_id,calc.id,st,src.id,src.id,src.id,src.snapshot_id,src.result_id,src.score,src.maximum_score,src.weight,src.score/src.maximum_score,src.weight,(src.score/src.maximum_score)*src.weight,p_actor)returning id into source_id;perform app_auth.write_term_grade_change(p_cmd,g.organization_id,p_actor,'term_grade.calculation_source_recorded','term_grade_calculation_source',source_id,null,(select to_jsonb(x)from public.term_grade_calculation_sources x where x.id=source_id),null,false);end loop;n:=n+1;end loop;return n;end$$;

create function public.calculate_term_grades(term_grading_configuration_id uuid)returns table(term_grade_set_id uuid,grade_count integer)language plpgsql security definer set search_path='' as $$declare a uuid:=app_auth.term_grade_actor();c public.term_grading_configurations%rowtype;g public.term_grade_sets%rowtype;cmd uuid:=gen_random_uuid();fp bytea;begin select*into c from public.term_grading_configurations where id=term_grading_configuration_id for update;if not found then raise exception using errcode='P0002',message='configuration not found';end if;if c.status<>'active'then raise exception using errcode='22023',message='active configuration required';end if;if not app_auth.can_manage_term_grade_context(c.organization_id,c.school_id,c.campus_id,c.section_id,c.subject_id)then raise exception using errcode='42501',message='term grade management authority required';end if;fp:=extensions.digest(c.id::text||clock_timestamp()::text,'sha256');insert into public.term_grade_sets(organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,subject_id,term_grading_configuration_id,source_fingerprint,created_by,updated_by)values(c.organization_id,c.school_id,c.campus_id,c.academic_year_id,c.academic_term_id,c.section_id,c.subject_id,c.id,fp,a,a)returning*into g;grade_count:=app_auth.populate_term_grade_set(g.id,1,a,cmd);perform app_auth.write_term_grade_change(cmd,g.organization_id,a,'term_grade_set.calculated','term_grade_set',g.id,null,to_jsonb(g),jsonb_build_object('school_id',g.school_id,'campus_id',g.campus_id,'grade_count',grade_count));term_grade_set_id:=g.id;return next;end$$;
create function public.recalculate_draft_term_grades(id uuid)returns table(term_grade_set_id uuid,calculation_sequence integer,grade_count integer)language plpgsql security definer set search_path='' as $$declare a uuid:=app_auth.term_grade_actor();g public.term_grade_sets%rowtype;cmd uuid:=gen_random_uuid();oldj jsonb;begin select*into g from public.term_grade_sets where term_grade_sets.id=recalculate_draft_term_grades.id for update;if g.lifecycle_status<>'draft'then raise exception using errcode='22023',message='draft set required';end if;if not app_auth.can_manage_term_grade_context(g.organization_id,g.school_id,g.campus_id,g.section_id,g.subject_id)then raise exception using errcode='42501',message='term grade management authority required';end if;oldj:=to_jsonb(g);calculation_sequence:=g.calculation_sequence+1;grade_count:=app_auth.populate_term_grade_set(g.id,calculation_sequence,a,cmd);update public.term_grade_sets set calculation_sequence=recalculate_draft_term_grades.calculation_sequence,source_fingerprint=extensions.digest(g.id::text||recalculate_draft_term_grades.calculation_sequence::text||clock_timestamp()::text,'sha256'),updated_by=a where id=g.id returning*into g;perform app_auth.write_term_grade_change(cmd,g.organization_id,a,'term_grade_set.recalculated','term_grade_set',g.id,oldj,to_jsonb(g),jsonb_build_object('grade_count',grade_count,'calculation_sequence',calculation_sequence));recalculate_draft_term_grades.term_grade_set_id:=g.id;return next;end$$;
create function app_auth.term_grade_set_transition(op text,p_id uuid,p_reason text default null)returns uuid language plpgsql security definer set search_path='' as $$declare a uuid:=app_auth.term_grade_actor();g public.term_grade_sets%rowtype;oldj jsonb;cmd uuid:=gen_random_uuid();begin select*into g from public.term_grade_sets where id=p_id for update;if not app_auth.can_manage_term_grade_context(g.organization_id,g.school_id,g.campus_id,g.section_id,g.subject_id)then raise exception using errcode='42501',message='term grade management authority required';end if;oldj:=to_jsonb(g);if op='publish'then if g.publication_state<>'unpublished'or g.lifecycle_status not in('draft','finalized')then raise exception using errcode='22023',message='unpublished live set required';end if;update public.term_grade_sets set publication_state='published',published_at=now(),published_by=a,updated_by=a where id=g.id;elsif op='finalize'then if g.lifecycle_status<>'draft'then raise exception using errcode='22023',message='draft set required';end if;update public.term_grade_sets set lifecycle_status='finalized',finalized_at=now(),finalized_by=a,updated_by=a where id=g.id;elsif op='cancel'then if g.lifecycle_status<>'draft'or g.publication_state<>'unpublished'or length(btrim(coalesce(p_reason,'')))not between 1 and 500 then raise exception using errcode='22023',message='unpublished draft and bounded reason required';end if;update public.term_grade_sets set lifecycle_status='cancelled',cancellation_reason=btrim(p_reason),cancelled_at=now(),cancelled_by=a,updated_by=a where id=g.id;end if;select*into g from public.term_grade_sets where id=g.id;perform app_auth.write_term_grade_change(cmd,g.organization_id,a,'term_grade_set.'||case when op='publish'then'published'when op='finalize'then'finalized'else'cancelled'end,'term_grade_set',g.id,oldj,to_jsonb(g),jsonb_build_object('school_id',g.school_id,'campus_id',g.campus_id));return g.id;end$$;
create function public.publish_term_grades(term_grade_set_id uuid)returns uuid language sql security definer set search_path='' as $$select app_auth.term_grade_set_transition('publish',term_grade_set_id,null)$$;
create function public.finalize_term_grades(term_grade_set_id uuid)returns uuid language sql security definer set search_path='' as $$select app_auth.term_grade_set_transition('finalize',term_grade_set_id,null)$$;
create function public.cancel_draft_term_grades(term_grade_set_id uuid,cancellation_reason text)returns uuid language sql security definer set search_path='' as $$select app_auth.term_grade_set_transition('cancel',term_grade_set_id,cancellation_reason)$$;
create function public.correct_term_grades(term_grade_set_id uuid,correction_reason text)returns table(corrected_term_grade_set_id uuid,replacement_term_grade_set_id uuid)language plpgsql security definer set search_path='' as $$begin raise exception 'uninitialized term-grade correction';end$$;

create function app_auth.assessment_chain_root(p_assessment uuid) returns uuid
language plpgsql stable security definer set search_path='' as $$
declare cursor_id uuid:=p_assessment; parent_id uuid;
begin
 loop
  select supersedes_assessment_id into parent_id from public.assessments where id=cursor_id;
  if not found then raise exception using errcode='P0002',message='assessment chain member not found'; end if;
  if parent_id is null then return cursor_id; end if;
  cursor_id:=parent_id;
 end loop;
end $$;

create function app_auth.term_grade_fingerprint(p_configuration uuid) returns bytea
language sql stable security definer set search_path='' as $$
 select extensions.digest(convert_to(jsonb_build_object(
  'configuration',jsonb_build_object('id',c.id,'scale',c.grade_scale_id,'require100',c.require_weights_total_100,'includeUnpublished',c.include_unpublished_finalized),
  'activeConfigurationHead',(select h.id from public.term_grading_configurations h where h.section_id=c.section_id
    and h.academic_term_id=c.academic_term_id and h.subject_id is not distinct from c.subject_id and h.status='active'),
  'bands',coalesce((select jsonb_agg(jsonb_build_array(b.id,b.sequence,b.lower_units,b.upper_units,b.label,b.result_state) order by b.sequence,b.id) from public.grade_scale_bands b where b.grade_scale_id=c.grade_scale_id),'[]'::jsonb),
  'assessments',coalesce((select jsonb_agg(jsonb_build_array(a.id,app_auth.assessment_chain_root(a.id),a.maximum_score,a.weight,
    (select jsonb_agg(jsonb_build_array(ast.id,ast.student_id,ast.student_enrollment_id,ast.student_section_placement_id,ar.id,ar.score) order by ast.student_id,ast.id)
     from public.assessment_students ast join public.assessment_results ar on ar.assessment_student_id=ast.id where ast.assessment_id=a.id)) order by app_auth.assessment_chain_root(a.id),a.id)
   from public.assessments a where a.section_id=c.section_id and a.academic_term_id=c.academic_term_id
    and a.subject_id is not distinct from c.subject_id and a.lifecycle_status='finalized' and a.publication_state='published'),'[]'::jsonb)
 )::text,'UTF8'),'sha256')
 from public.term_grading_configurations c where c.id=p_configuration;
$$;

create function app_auth.enforce_term_grade_source_identity() returns trigger
language plpgsql set search_path='' as $$
begin
 if app_auth.assessment_chain_root(new.assessment_version_id)<>new.assessment_root_id then
  raise exception using errcode='23514',message='assessment root/version provenance mismatch';
 end if;
 return new;
end $$;
create trigger term_grade_source_identity before insert or update on public.term_grade_calculation_sources
 for each row execute function app_auth.enforce_term_grade_source_identity();

create function app_auth.lock_term_grade_context(p_configuration uuid) returns public.term_grading_configurations
language plpgsql security definer set search_path='' as $$
declare c public.term_grading_configurations%rowtype;
begin
 select * into c from public.term_grading_configurations where id=p_configuration;
 if not found then raise exception using errcode='P0002',message='configuration not found'; end if;
 perform 1 from public.organizations where id=c.organization_id for update;
 perform 1 from public.schools where id=c.school_id for update;
 perform 1 from public.campuses where id=c.campus_id for update;
 perform 1 from public.academic_years where id=c.academic_year_id for update;
 perform 1 from public.academic_terms where id=c.academic_term_id for update;
 perform 1 from public.sections where id=c.section_id for update;
 if c.subject_id is not null then perform 1 from public.subjects where id=c.subject_id for update; end if;
 perform 1 from public.teaching_assignments where section_id=c.section_id and subject_id is not distinct from c.subject_id order by id for update;
 perform 1 from public.grade_scales where id=c.grade_scale_id or supersedes_grade_scale_id=c.grade_scale_id order by id for update;
 perform 1 from public.grade_scale_bands where grade_scale_id=c.grade_scale_id order by sequence,id for update;
 perform 1 from public.term_grading_configurations where id=c.id or supersedes_configuration_id=c.id order by id for update;
 perform 1 from public.assessments where section_id=c.section_id and academic_term_id=c.academic_term_id and subject_id is not distinct from c.subject_id order by id for update;
 perform 1 from public.assessment_students ast join public.assessments a on a.id=ast.assessment_id
  where a.section_id=c.section_id and a.academic_term_id=c.academic_term_id and a.subject_id is not distinct from c.subject_id order by ast.student_id,ast.id for update of ast;
 perform 1 from public.assessment_results ar join public.assessments a on a.id=ar.assessment_id
  where a.section_id=c.section_id and a.academic_term_id=c.academic_term_id and a.subject_id is not distinct from c.subject_id order by ar.student_id,ar.id for update of ar;
 perform 1 from public.students st where st.id in(select ast.student_id from public.assessment_students ast join public.assessments a on a.id=ast.assessment_id where a.section_id=c.section_id and a.academic_term_id=c.academic_term_id and a.subject_id is not distinct from c.subject_id) order by st.id for update;
 perform 1 from public.student_enrollments e where e.id in(select ast.student_enrollment_id from public.assessment_students ast join public.assessments a on a.id=ast.assessment_id where a.section_id=c.section_id and a.academic_term_id=c.academic_term_id and a.subject_id is not distinct from c.subject_id) order by e.student_id,e.id for update;
 perform 1 from public.student_section_placements p where p.id in(select ast.student_section_placement_id from public.assessment_students ast join public.assessments a on a.id=ast.assessment_id where a.section_id=c.section_id and a.academic_term_id=c.academic_term_id and a.subject_id is not distinct from c.subject_id) order by p.student_id,p.id for update;
 select * into c from public.term_grading_configurations where id=c.id for update;
 return c;
end $$;

create or replace function app_auth.populate_term_grade_set(p_set uuid,p_sequence integer,p_actor uuid,p_cmd uuid) returns integer
language plpgsql security definer set search_path='' as $$
declare g public.term_grade_sets%rowtype; c public.term_grading_configurations%rowtype; student uuid;
 r public.term_grade_records%rowtype; calc public.term_grade_calculations%rowtype; src record; source_id uuid;
 raw numeric; rounded numeric; band public.grade_scale_bands%rowtype; n integer:=0; assessment_count integer; total numeric;
begin
 select * into g from public.term_grade_sets where id=p_set;
 select * into c from public.term_grading_configurations where id=g.term_grading_configuration_id;
 select count(*),sum(weight) into assessment_count,total from public.assessments a
  where a.section_id=g.section_id and a.academic_term_id=g.academic_term_id and a.subject_id is not distinct from g.subject_id
   and a.lifecycle_status='finalized' and a.publication_state='published';
 if assessment_count=0 then raise exception using errcode='22023',message='at least one published finalized assessment is required'; end if;
 if total<>100 or exists(select 1 from public.assessments a where a.section_id=g.section_id and a.academic_term_id=g.academic_term_id
  and a.subject_id is not distinct from g.subject_id and a.lifecycle_status='finalized' and a.publication_state='published' and a.weight is null)
 then raise exception using errcode='22023',message='contributing weights must total 100 with no nulls'; end if;
 if exists(select ast.student_id from public.assessment_students ast join public.assessments a on a.id=ast.assessment_id
  where a.section_id=g.section_id and a.academic_term_id=g.academic_term_id and a.subject_id is not distinct from g.subject_id
   and a.lifecycle_status='finalized' and a.publication_state='published' group by ast.student_id having count(*)<>assessment_count)
 then raise exception using errcode='22023',message='identical complete assessment rosters are required'; end if;
 for student in select distinct ast.student_id from public.assessment_students ast join public.assessments a on a.id=ast.assessment_id
  where a.section_id=g.section_id and a.academic_term_id=g.academic_term_id and a.subject_id is not distinct from g.subject_id
   and a.lifecycle_status='finalized' and a.publication_state='published' order by ast.student_id
 loop
  select sum((ar.score/a.maximum_score)*a.weight) into raw from public.assessments a
   join public.assessment_results ar on ar.assessment_id=a.id and ar.student_id=student
   where a.section_id=g.section_id and a.academic_term_id=g.academic_term_id and a.subject_id is not distinct from g.subject_id
    and a.lifecycle_status='finalized' and a.publication_state='published';
  rounded:=round(raw,4);
  select * into band from public.grade_scale_bands b where b.grade_scale_id=c.grade_scale_id
   and(case when rounded=100 then b.upper_units=1000000 else b.percentage_range@>(rounded*10000)::bigint end);
  if not found then raise exception using errcode='22023',message='grade scale does not cover calculated percentage'; end if;
  insert into public.term_grade_records(organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,subject_id,
   term_grading_configuration_id,term_grade_set_id,student_id,calculation_sequence,created_by)
  values(g.organization_id,g.school_id,g.campus_id,g.academic_year_id,g.academic_term_id,g.section_id,g.subject_id,c.id,g.id,student,p_sequence,p_actor) returning * into r;
  insert into public.term_grade_calculations(organization_id,term_grade_set_id,term_grade_record_id,student_id,calculation_sequence,
   raw_percentage,rounded_percentage,grade_scale_id,grade_scale_band_id,grade_label,result_state,contributing_assessment_count,weight_total,calculated_by)
  values(g.organization_id,g.id,r.id,student,p_sequence,raw,rounded,c.grade_scale_id,band.id,band.label,band.result_state,assessment_count,total,p_actor) returning * into calc;
  perform app_auth.write_term_grade_change(p_cmd,g.organization_id,p_actor,case when p_sequence=1 then 'term_grade.calculated' else 'term_grade.recalculated' end,'term_grade_record',r.id,null,to_jsonb(r),
   jsonb_build_object('term_grade_set_id',g.id,'student_id',student,'rounded_percentage',rounded,'grade_label',band.label));
  perform app_auth.write_term_grade_change(p_cmd,g.organization_id,p_actor,'term_grade.calculation_recorded','term_grade_calculation',calc.id,null,to_jsonb(calc),null,false);
  for src in select a.*,ar.id result_id,ar.score,ast.id snapshot_id from public.assessments a
   join public.assessment_students ast on ast.assessment_id=a.id and ast.student_id=student
   join public.assessment_results ar on ar.assessment_id=a.id and ar.student_id=student
   where a.section_id=g.section_id and a.academic_term_id=g.academic_term_id and a.subject_id is not distinct from g.subject_id
    and a.lifecycle_status='finalized' and a.publication_state='published' order by app_auth.assessment_chain_root(a.id),a.id
  loop
   insert into public.term_grade_calculation_sources(organization_id,term_grade_calculation_id,student_id,assessment_root_id,
    assessment_version_id,assessment_id,assessment_student_id,assessment_result_id,score,maximum_score,assessment_weight,
    score_ratio,effective_weight,weighted_points,created_by)
   values(g.organization_id,calc.id,student,app_auth.assessment_chain_root(src.id),src.id,src.id,src.snapshot_id,src.result_id,
    src.score,src.maximum_score,src.weight,src.score/src.maximum_score,src.weight,(src.score/src.maximum_score)*src.weight,p_actor)
   returning id into source_id;
   perform app_auth.write_term_grade_change(p_cmd,g.organization_id,p_actor,'term_grade.calculation_source_recorded',
    'term_grade_calculation_source',source_id,null,(select to_jsonb(x) from public.term_grade_calculation_sources x where x.id=source_id),null,false);
  end loop;
  n:=n+1;
 end loop;
 return n;
end $$;

create or replace function public.calculate_term_grades(term_grading_configuration_id uuid)
returns table(term_grade_set_id uuid,grade_count integer) language plpgsql security definer set search_path='' as $$
declare actor uuid:=app_auth.term_grade_actor(); c public.term_grading_configurations%rowtype; g public.term_grade_sets%rowtype;
 cmd uuid:=gen_random_uuid(); fp bytea;
begin
 c:=app_auth.lock_term_grade_context(term_grading_configuration_id);
 if c.status<>'active' then raise exception using errcode='22023',message='active configuration required'; end if;
 if not app_auth.can_manage_term_grade_context(c.organization_id,c.school_id,c.campus_id,c.section_id,c.subject_id)
 then raise exception using errcode='42501',message='term grade management authority required'; end if;
 fp:=app_auth.term_grade_fingerprint(c.id);
 begin
  insert into public.term_grade_sets(organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,subject_id,
   term_grading_configuration_id,source_fingerprint,created_by,updated_by)
  values(c.organization_id,c.school_id,c.campus_id,c.academic_year_id,c.academic_term_id,c.section_id,c.subject_id,c.id,fp,actor,actor) returning * into g;
 exception when unique_violation then raise exception using errcode='40001',message='term-grade set head changed; retry'; end;
 grade_count:=app_auth.populate_term_grade_set(g.id,1,actor,cmd);
 perform app_auth.write_term_grade_change(cmd,g.organization_id,actor,'term_grade_set.calculated','term_grade_set',g.id,null,to_jsonb(g),
  jsonb_build_object('school_id',g.school_id,'campus_id',g.campus_id,'grade_count',grade_count));
 term_grade_set_id:=g.id; return next;
end $$;

create or replace function public.recalculate_draft_term_grades(id uuid)
returns table(term_grade_set_id uuid,calculation_sequence integer,grade_count integer) language plpgsql security definer set search_path='' as $$
declare actor uuid:=app_auth.term_grade_actor(); g public.term_grade_sets%rowtype; c public.term_grading_configurations%rowtype;
 cmd uuid:=gen_random_uuid(); oldj jsonb; fp bytea; old_roster uuid[]; new_roster uuid[];
begin
 select * into g from public.term_grade_sets where term_grade_sets.id=recalculate_draft_term_grades.id;
 if not found then raise exception using errcode='P0002',message='term-grade set not found'; end if;
 c:=app_auth.lock_term_grade_context(g.term_grading_configuration_id);
 perform 1 from public.term_grade_sets tgs where tgs.id=g.id or tgs.supersedes_term_grade_set_id=g.id order by tgs.id for update;
 select * into g from public.term_grade_sets tgs where tgs.id=g.id for update;
 if g.lifecycle_status<>'draft' then raise exception using errcode='22023',message='draft set required'; end if;
 if not app_auth.can_manage_term_grade_context(g.organization_id,g.school_id,g.campus_id,g.section_id,g.subject_id)
 then raise exception using errcode='42501',message='term grade management authority required'; end if;
 select array_agg(tgr.student_id order by tgr.student_id) into old_roster from public.term_grade_records tgr where tgr.term_grade_set_id=g.id and tgr.calculation_sequence=g.calculation_sequence;
 select array_agg(distinct ast.student_id order by ast.student_id) into new_roster from public.assessment_students ast join public.assessments a on a.id=ast.assessment_id
  where a.section_id=g.section_id and a.academic_term_id=g.academic_term_id and a.subject_id is not distinct from g.subject_id and a.lifecycle_status='finalized' and a.publication_state='published';
 if coalesce(old_roster,'{}') is distinct from coalesce(new_roster,'{}') then raise exception using errcode='22023',message='term-grade roster changed; cancel and recreate'; end if;
 oldj:=to_jsonb(g); calculation_sequence:=g.calculation_sequence+1; fp:=app_auth.term_grade_fingerprint(c.id);
 grade_count:=app_auth.populate_term_grade_set(g.id,calculation_sequence,actor,cmd);
 update public.term_grade_sets set calculation_sequence=recalculate_draft_term_grades.calculation_sequence,source_fingerprint=fp,updated_by=actor where term_grade_sets.id=g.id returning * into g;
 perform app_auth.write_term_grade_change(cmd,g.organization_id,actor,'term_grade_set.recalculated','term_grade_set',g.id,oldj,to_jsonb(g),
  jsonb_build_object('grade_count',grade_count,'calculation_sequence',calculation_sequence));
 recalculate_draft_term_grades.term_grade_set_id:=g.id; return next;
end $$;

create or replace function app_auth.term_grade_set_transition(op text,p_id uuid,p_reason text default null) returns uuid
language plpgsql security definer set search_path='' as $$
declare actor uuid:=app_auth.term_grade_actor(); g public.term_grade_sets%rowtype; c public.term_grading_configurations%rowtype;
 oldj jsonb; cmd uuid:=gen_random_uuid(); current_fp bytea;
begin
 select * into g from public.term_grade_sets where id=p_id;
 if not found then raise exception using errcode='P0002',message='term-grade set not found'; end if;
 c:=app_auth.lock_term_grade_context(g.term_grading_configuration_id);
 perform 1 from public.term_grade_sets where id=g.id or supersedes_term_grade_set_id=g.id order by id for update;
 select * into g from public.term_grade_sets where id=g.id for update;
 if not app_auth.can_manage_term_grade_context(g.organization_id,g.school_id,g.campus_id,g.section_id,g.subject_id)
 then raise exception using errcode='42501',message='term grade management authority required'; end if;
 oldj:=to_jsonb(g);
 if op in('publish','finalize') then
  current_fp:=app_auth.term_grade_fingerprint(c.id);
  if current_fp is distinct from g.source_fingerprint then raise exception using errcode='40001',message='term-grade sources changed; recalculate and retry'; end if;
 end if;
 if op='publish' then
  if g.publication_state<>'unpublished' or g.lifecycle_status not in('draft','finalized') then raise exception using errcode='22023',message='unpublished live set required'; end if;
  update public.term_grade_sets set publication_state='published',published_at=now(),published_by=actor,updated_by=actor where id=g.id;
 elsif op='finalize' then
  if g.lifecycle_status<>'draft' then raise exception using errcode='22023',message='draft set required'; end if;
  update public.term_grade_sets set lifecycle_status='finalized',finalized_at=now(),finalized_by=actor,updated_by=actor where id=g.id;
 elsif op='cancel' then
  if g.lifecycle_status<>'draft' or g.publication_state<>'unpublished' or length(btrim(coalesce(p_reason,''))) not between 1 and 500
  then raise exception using errcode='22023',message='unpublished draft and bounded reason required'; end if;
  update public.term_grade_sets set lifecycle_status='cancelled',cancellation_reason=btrim(p_reason),cancelled_at=now(),cancelled_by=actor,updated_by=actor where id=g.id;
 else raise exception using errcode='22023',message='unsupported term-grade transition'; end if;
 select * into g from public.term_grade_sets where id=g.id;
 perform app_auth.write_term_grade_change(cmd,g.organization_id,actor,'term_grade_set.'||case when op='publish' then 'published' when op='finalize' then 'finalized' else 'cancelled' end,
  'term_grade_set',g.id,oldj,to_jsonb(g),jsonb_build_object('school_id',g.school_id,'campus_id',g.campus_id));
 return g.id;
end $$;

create or replace function public.correct_term_grades(term_grade_set_id uuid,correction_reason text)
returns table(corrected_term_grade_set_id uuid,replacement_term_grade_set_id uuid) language plpgsql security definer set search_path='' as $$
declare actor uuid:=app_auth.term_grade_actor(); g public.term_grade_sets%rowtype; successor public.term_grade_sets%rowtype;
 c public.term_grading_configurations%rowtype; cmd uuid:=gen_random_uuid(); grade_count integer; oldj jsonb; correctedj jsonb; fp bytea;
begin
 if length(btrim(coalesce(correct_term_grades.correction_reason,''))) not between 1 and 500 then raise exception using errcode='22023',message='bounded correction reason is required'; end if;
 select * into g from public.term_grade_sets where id=term_grade_set_id;
 if not found then raise exception using errcode='P0002',message='term-grade set not found'; end if;
 c:=app_auth.lock_term_grade_context(g.term_grading_configuration_id);
 perform 1 from public.term_grade_sets where id=g.id or supersedes_term_grade_set_id=g.id order by id for update;
 select * into g from public.term_grade_sets where id=g.id for update;
 if exists(select 1 from public.term_grade_sets where supersedes_term_grade_set_id=g.id) then raise exception using errcode='40001',message='term-grade correction head changed; retry'; end if;
 if g.lifecycle_status<>'finalized' then raise exception using errcode='22023',message='finalized live set required'; end if;
 if not app_auth.has_permission(g.organization_id,'term_grades.manage',g.school_id,g.campus_id)
  or not app_auth.has_permission(g.organization_id,'term_grades.correct',g.school_id,g.campus_id)
 then raise exception using errcode='42501',message='term_grades.manage and term_grades.correct permissions are required'; end if;
 fp:=app_auth.term_grade_fingerprint(c.id); oldj:=to_jsonb(g);
 update public.term_grade_sets set lifecycle_status='corrected',correction_reason=btrim(correct_term_grades.correction_reason),updated_by=actor where term_grade_sets.id=g.id returning to_jsonb(term_grade_sets.*) into correctedj;
 begin
  insert into public.term_grade_sets(organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,subject_id,
   term_grading_configuration_id,lifecycle_status,publication_state,published_at,published_by,finalized_at,finalized_by,
   source_fingerprint,supersedes_term_grade_set_id,created_by,updated_by)
  values(g.organization_id,g.school_id,g.campus_id,g.academic_year_id,g.academic_term_id,g.section_id,g.subject_id,
   g.term_grading_configuration_id,'finalized',g.publication_state,g.published_at,g.published_by,now(),actor,fp,g.id,actor,actor) returning * into successor;
 exception when unique_violation then raise exception using errcode='40001',message='term-grade correction head changed; retry'; end;
 grade_count:=app_auth.populate_term_grade_set(successor.id,1,actor,cmd);
 perform app_auth.write_term_grade_change(cmd,g.organization_id,actor,'term_grade_set.corrected','term_grade_set',g.id,oldj,correctedj,jsonb_build_object('successor_id',successor.id));
 perform app_auth.write_term_grade_change(cmd,g.organization_id,actor,'term_grade_set.finalized','term_grade_set',successor.id,null,to_jsonb(successor),jsonb_build_object('grade_count',grade_count));
 corrected_term_grade_set_id:=g.id; replacement_term_grade_set_id:=successor.id; return next;
end $$;

create or replace function public.activate_grade_scale(id uuid) returns uuid
language plpgsql security definer set search_path='' as $$
declare actor uuid:=app_auth.term_grade_actor(); g public.grade_scales%rowtype; predecessor public.grade_scales%rowtype;
 oldj jsonb; predecessor_old jsonb; predecessor_new jsonb; cmd uuid:=gen_random_uuid(); band_count integer;
begin
 select * into g from public.grade_scales where grade_scales.id=activate_grade_scale.id;
 if not found then raise exception using errcode='P0002',message='grade scale not found'; end if;
 perform 1 from public.organizations o where o.id=g.organization_id for update;
 perform 1 from public.schools s where s.id=g.school_id for update;
 if g.academic_year_id is not null then perform 1 from public.academic_years y where y.id=g.academic_year_id for update; end if;
 perform 1 from public.grade_scales gs where gs.id=g.id or gs.id=g.supersedes_grade_scale_id or gs.supersedes_grade_scale_id=g.id order by gs.id for update;
 perform 1 from public.grade_scale_bands gb where gb.grade_scale_id=g.id order by gb.sequence,gb.id for update;
 select * into g from public.grade_scales gs where gs.id=g.id for update;
 if not app_auth.has_permission(g.organization_id,'term_grades.manage',g.school_id,null) then raise exception using errcode='42501',message='term_grades.manage permission is required'; end if;
 select count(*) into band_count from public.grade_scale_bands where grade_scale_id=g.id;
 if g.status<>'draft' or band_count=0 or exists(select 1 from public.grade_scale_bands x where x.grade_scale_id=g.id and(
  x.sequence<>(select count(*) from public.grade_scale_bands y where y.grade_scale_id=g.id and y.sequence<=x.sequence)
  or(x.sequence=1 and x.lower_units<>0) or(x.sequence=band_count and x.upper_units<>1000000)
  or(x.sequence>1 and x.lower_units<>(select p.upper_units from public.grade_scale_bands p where p.grade_scale_id=g.id and p.sequence=x.sequence-1))))
 then raise exception using errcode='22023',message='complete contiguous grade bands are required'; end if;
 oldj:=to_jsonb(g);
 if g.supersedes_grade_scale_id is not null then
  select * into predecessor from public.grade_scales where grade_scales.id=g.supersedes_grade_scale_id for update;
  if predecessor.status='active' then
   predecessor_old:=to_jsonb(predecessor);
   update public.grade_scales set status='retired',retired_at=now(),retired_by=actor,updated_by=actor where grade_scales.id=predecessor.id returning to_jsonb(grade_scales.*) into predecessor_new;
   perform app_auth.write_term_grade_change(cmd,g.organization_id,actor,'grade_scale.retired','grade_scale',predecessor.id,predecessor_old,predecessor_new,jsonb_build_object('school_id',g.school_id,'successor_id',g.id));
  end if;
 end if;
 update public.grade_scales set status='active',activated_at=now(),activated_by=actor,updated_by=actor where grade_scales.id=g.id returning * into g;
 perform app_auth.write_term_grade_change(cmd,g.organization_id,actor,'grade_scale.activated','grade_scale',g.id,oldj,to_jsonb(g),jsonb_build_object('school_id',g.school_id,'band_count',band_count));
 return g.id;
end $$;

create function app_auth.assert_term_grading_configuration_context(p_section uuid,p_term uuid,p_subject uuid,p_scale uuid)
returns void language plpgsql security definer set search_path='' as $$
declare s public.sections%rowtype; o public.organizations%rowtype; sch public.schools%rowtype; cp public.campuses%rowtype;
 y public.academic_years%rowtype; t public.academic_terms%rowtype; sub public.subjects%rowtype; gs public.grade_scales%rowtype;
begin
 select * into s from public.sections where id=p_section for update;
 if not found then raise exception using errcode='22023',message='active compatible section is required'; end if;
 select * into o from public.organizations where id=s.organization_id for update;
 select * into sch from public.schools where id=s.school_id for update;
 select * into cp from public.campuses where id=s.campus_id for update;
 select * into y from public.academic_years where id=s.academic_year_id for update;
 select * into t from public.academic_terms where id=p_term for update;
 if p_subject is not null then select * into sub from public.subjects where id=p_subject for update; end if;
 select * into gs from public.grade_scales where id=p_scale for update;
 if o.status<>'active' or sch.status<>'active' or cp.status<>'active' or y.status<>'active' or t.status<>'active'
  or s.status<>'active' or(p_subject is not null and(sub.id is null or sub.status<>'active')) or gs.id is null or gs.status<>'active'
  or(sch.organization_id<>s.organization_id) or(cp.organization_id,cp.school_id)<>(s.organization_id,s.school_id)
  or(y.organization_id,y.school_id)<>(s.organization_id,s.school_id) or(t.organization_id,t.academic_year_id)<>(s.organization_id,s.academic_year_id)
  or(p_subject is not null and(sub.organization_id,sub.school_id)<>(s.organization_id,s.school_id))
  or(gs.organization_id,gs.school_id)<>(s.organization_id,s.school_id)
  or(gs.academic_year_id is not null and gs.academic_year_id<>s.academic_year_id)
  or(s.academic_term_id is not null and s.academic_term_id<>t.id)
  or t.start_date<y.start_date or t.end_date>y.end_date or t.start_date<s.start_date or t.end_date>s.end_date
 then raise exception using errcode='22023',message='active scope-compatible parents and dates are required'; end if;
end $$;

create or replace function public.update_draft_grade_scale(id uuid,name text,description text,set_description boolean,
 bands public.grade_scale_band_input[]) returns uuid
language plpgsql security definer set search_path='' as $$
begin
 if bands is null or cardinality(bands) not between 1 and 100 or exists(select 1 from unnest(bands) b where b is null)
  or exists(select 1 from unnest(bands) b where scale((b).lower_bound)>4 or scale((b).upper_bound)>4)
 then raise exception using errcode='22023',message='one to 100 bands with four-decimal bounds are required'; end if;
 return app_auth.grade_scale_command('update',id,name,description,set_description,bands);
end $$;

create or replace function public.create_term_grading_configuration(section_id uuid,academic_term_id uuid,subject_id uuid,
 grade_scale_id uuid,require_weights_total_100 boolean,include_unpublished_finalized boolean) returns uuid
language plpgsql security definer set search_path='' as $$
declare actor uuid:=app_auth.term_grade_actor(); s public.sections%rowtype; r public.term_grading_configurations%rowtype; cmd uuid:=gen_random_uuid();
begin
 if not require_weights_total_100 or include_unpublished_finalized then raise exception using errcode='22023',message='approved rules are fixed'; end if;
 perform app_auth.assert_term_grading_configuration_context(section_id,academic_term_id,subject_id,grade_scale_id);
 select * into s from public.sections where sections.id=create_term_grading_configuration.section_id;
 if not app_auth.has_permission(s.organization_id,'term_grades.manage',s.school_id,s.campus_id) then raise exception using errcode='42501',message='term_grades.manage permission is required'; end if;
 insert into public.term_grading_configurations(organization_id,school_id,campus_id,academic_year_id,academic_term_id,section_id,subject_id,grade_scale_id,created_by,updated_by)
 values(s.organization_id,s.school_id,s.campus_id,s.academic_year_id,academic_term_id,s.id,subject_id,grade_scale_id,actor,actor) returning * into r;
 perform app_auth.write_term_grade_change(cmd,r.organization_id,actor,'term_grading_configuration.created','term_grading_configuration',r.id,null,to_jsonb(r),jsonb_build_object('school_id',r.school_id,'campus_id',r.campus_id,'section_id',r.section_id));
 return r.id;
end $$;

create or replace function public.update_draft_term_grading_configuration(id uuid,grade_scale_id uuid,
 require_weights_total_100 boolean,include_unpublished_finalized boolean) returns uuid
language plpgsql security definer set search_path='' as $$
declare c public.term_grading_configurations%rowtype;
begin
 if not require_weights_total_100 or include_unpublished_finalized then raise exception using errcode='22023',message='approved rules are fixed'; end if;
 select * into c from public.term_grading_configurations where term_grading_configurations.id=update_draft_term_grading_configuration.id;
 if not found then raise exception using errcode='P0002',message='configuration not found'; end if;
 perform app_auth.assert_term_grading_configuration_context(c.section_id,c.academic_term_id,c.subject_id,grade_scale_id);
 return app_auth.term_config_command('update',c.id,grade_scale_id);
end $$;

create or replace function public.activate_term_grading_configuration(id uuid) returns uuid
language plpgsql security definer set search_path='' as $$
declare actor uuid:=app_auth.term_grade_actor(); c public.term_grading_configurations%rowtype; predecessor public.term_grading_configurations%rowtype;
 oldj jsonb; predecessor_old jsonb; predecessor_new jsonb; cmd uuid:=gen_random_uuid();
begin
 select * into c from public.term_grading_configurations where term_grading_configurations.id=activate_term_grading_configuration.id;
 if not found then raise exception using errcode='P0002',message='configuration not found'; end if;
 c:=app_auth.lock_term_grade_context(c.id);
 perform app_auth.assert_term_grading_configuration_context(c.section_id,c.academic_term_id,c.subject_id,c.grade_scale_id);
 if not app_auth.has_permission(c.organization_id,'term_grades.manage',c.school_id,c.campus_id) then raise exception using errcode='42501',message='term_grades.manage permission is required'; end if;
 if c.status<>'draft' or not exists(select 1 from public.grade_scales g where g.id=c.grade_scale_id and g.status='active'
  and(g.academic_year_id is null or g.academic_year_id=c.academic_year_id))
 then raise exception using errcode='22023',message='draft configuration with active compatible scale required'; end if;
 oldj:=to_jsonb(c);
 if c.supersedes_configuration_id is not null then
  select * into predecessor from public.term_grading_configurations where term_grading_configurations.id=c.supersedes_configuration_id for update;
  if predecessor.status='active' then
   predecessor_old:=to_jsonb(predecessor);
   update public.term_grading_configurations set status='retired',retired_at=now(),retired_by=actor,updated_by=actor
    where term_grading_configurations.id=predecessor.id returning to_jsonb(term_grading_configurations.*) into predecessor_new;
   perform app_auth.write_term_grade_change(cmd,c.organization_id,actor,'term_grading_configuration.retired','term_grading_configuration',predecessor.id,
    predecessor_old,predecessor_new,jsonb_build_object('school_id',c.school_id,'campus_id',c.campus_id,'successor_id',c.id));
  end if;
 end if;
 update public.term_grading_configurations set status='active',activated_at=now(),activated_by=actor,updated_by=actor
  where term_grading_configurations.id=c.id returning * into c;
 perform app_auth.write_term_grade_change(cmd,c.organization_id,actor,'term_grading_configuration.activated','term_grading_configuration',c.id,
  oldj,to_jsonb(c),jsonb_build_object('school_id',c.school_id,'campus_id',c.campus_id));
 return c.id;
end $$;

alter function public.update_section(uuid,text,text,integer,date,date,uuid,uuid,public.record_status,boolean,boolean)
 rename to update_section_v0_8_impl;
create function public.update_section(id uuid,code text,name text,capacity integer,start_date date,end_date date,
 academic_term_id uuid,homeroom_room_id uuid,status public.record_status,set_academic_term_id boolean default false,
 set_homeroom_room_id boolean default false) returns uuid
language plpgsql security definer set search_path='' as $$
declare result_id uuid;
begin
 result_id:=app_auth.update_section_v0_3_impl(id,code,name,capacity,start_date,end_date,academic_term_id,homeroom_room_id,status,set_academic_term_id,set_homeroom_room_id);
 if exists(select 1 from public.student_section_placements p where p.section_id=update_section.id and p.status='active')
  and(update_section.status<>'active' or update_section.capacity<(select count(*) from public.student_section_placements p where p.section_id=update_section.id and p.status='active')
   or exists(select 1 from public.student_section_placements p where p.section_id=update_section.id and p.status<>'corrected'
    and(p.starts_on<update_section.start_date or coalesce(p.ends_on,p.starts_on)>update_section.end_date)))
 then raise exception using errcode='22023',message='section change conflicts with placement history or capacity'; end if;
 if exists(select 1 from public.teaching_assignments t where t.section_id=update_section.id and t.status='active') and update_section.status<>'active'
 then raise exception using errcode='22023',message='section has active teaching assignments'; end if;
 if exists(select 1 from public.teaching_assignments t where t.section_id=update_section.id and t.status<>'corrected'
  and(t.starts_on<update_section.start_date or t.scheduled_ends_on>update_section.end_date))
 then raise exception using errcode='22023',message='section dates exclude teaching assignment history'; end if;
 if status<>'active' and exists(select 1 from public.term_grade_sets g where g.section_id=update_section.id and g.lifecycle_status='draft')
 then raise exception using errcode='22023',message='section has draft term-grade sets'; end if;
 if set_academic_term_id and exists(select 1 from public.term_grading_configurations c where c.section_id=update_section.id and c.status<>'retired')
 then raise exception using errcode='22023',message='section term change conflicts with term-grade configuration'; end if;
 if exists(select 1 from public.term_grading_configurations c join public.academic_terms t on t.id=c.academic_term_id
  where c.section_id=update_section.id and c.status<>'retired' and(t.start_date<update_section.start_date or t.end_date>update_section.end_date))
 then raise exception using errcode='22023',message='section dates exclude term-grade configuration'; end if;
 return result_id;
end $$;

alter function public.archive_section(uuid) rename to archive_section_v0_8_impl;
create function public.archive_section(p_id uuid) returns uuid
language plpgsql security definer set search_path='' as $$
declare result_id uuid;
begin
 result_id:=app_auth.archive_section_v0_3_impl(p_id);
 if exists(select 1 from public.student_section_placements p where p.section_id=p_id and p.status='active')
 then raise exception using errcode='22023',message='section has active placements'; end if;
 if exists(select 1 from public.teaching_assignments t where t.section_id=p_id and t.status='active')
 then raise exception using errcode='22023',message='section has active teaching assignments'; end if;
 if exists(select 1 from public.term_grade_sets g where g.section_id=p_id and g.lifecycle_status not in('corrected','cancelled'))
  or exists(select 1 from public.term_grading_configurations c where c.section_id=p_id and c.status<>'retired')
 then raise exception using errcode='22023',message='section has live term-grade history or configuration'; end if;
 return result_id;
end $$;

alter function app_auth.write_academic_change(uuid,uuid,text,text,uuid,jsonb,jsonb)
 rename to write_academic_change_v0_8_impl;
create function app_auth.write_academic_change(o uuid,actor uuid,action_name text,entity_name text,entity uuid,before_row jsonb,after_row jsonb) returns void
language plpgsql security definer set search_path='' as $$
begin
 if entity_name='academic_year' and action_name='academic_year.status_changed' and after_row->>'status' in('closed','archived')
  and(exists(select 1 from public.term_grade_sets g where g.academic_year_id=entity and g.lifecycle_status='draft')
   or exists(select 1 from public.grade_scales s where s.academic_year_id=entity and s.status in('draft','active')))
 then raise exception using errcode='22023',message='academic year has unfinished term-grade work'; end if;
 if entity_name='academic_term' and action_name='academic_term.status_changed' and after_row->>'status' in('closed','archived')
  and exists(select 1 from public.term_grade_sets g where g.academic_term_id=entity and g.lifecycle_status='draft')
 then raise exception using errcode='22023',message='academic term has unfinished term-grade sets'; end if;
 if entity_name='subject' and after_row->>'status' in('inactive','archived')
  and(exists(select 1 from public.term_grade_sets g where g.subject_id=entity and g.lifecycle_status='draft')
   or exists(select 1 from public.term_grading_configurations c where c.subject_id=entity and c.status in('draft','active')))
 then raise exception using errcode='22023',message='subject has live term-grade configuration or drafts'; end if;
 perform app_auth.write_academic_change_v0_8_impl(o,actor,action_name,entity_name,entity,before_row,after_row);
end $$;

create function app_auth.can_read_grade_scale(p_grade_scale uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.grade_scales g where g.id=p_grade_scale and(
  app_auth.has_permission(g.organization_id,'term_grades.view',g.school_id,null)
  or app_auth.has_permission(g.organization_id,'term_grades.manage',g.school_id,null)
  or exists(select 1 from public.term_grading_configurations c where c.grade_scale_id=g.id
   and app_auth.has_term_grade_assignment(c.section_id,c.subject_id,
    array['lead','co_teacher','assistant','substitute']::public.teaching_assignment_role[]))));
$$;
create function app_auth.can_read_term_grade_source(p_source uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.term_grade_calculation_sources src
  join public.term_grade_calculations calc on calc.id=src.term_grade_calculation_id
  join public.term_grade_sets g on g.id=calc.term_grade_set_id
  where src.id=p_source and(
   app_auth.has_permission(g.organization_id,'term_grades.view',g.school_id,g.campus_id)
   or app_auth.has_permission(g.organization_id,'term_grades.manage',g.school_id,g.campus_id)
   or app_auth.has_permission(g.organization_id,'term_grades.correct',g.school_id,g.campus_id)
   or app_auth.has_term_grade_assignment(g.section_id,g.subject_id,
    array['lead','co_teacher','assistant','substitute']::public.teaching_assignment_role[])));
$$;

create or replace function public.revise_grade_scale(id uuid,replacement_name text,replacement_description text,
 replacement_bands public.grade_scale_band_input[]) returns uuid
language plpgsql security definer set search_path='' as $$
declare g public.grade_scales%rowtype; replacement_id uuid; replacement public.grade_scales%rowtype;
begin
 select * into g from public.grade_scales where grade_scales.id=revise_grade_scale.id for update;
 if not found then raise exception using errcode='P0002',message='grade scale not found'; end if;
 if g.status not in('active','retired') then raise exception using errcode='22023',message='active or retired scale head is required'; end if;
 replacement_id:=public.create_grade_scale(g.school_id,g.academic_year_id,replacement_name,replacement_description,replacement_bands);
 update public.grade_scales set supersedes_grade_scale_id=g.id where grade_scales.id=replacement_id returning * into replacement;
 update public.audit_log set after_data=to_jsonb(replacement) where action='grade_scale.created' and entity_id=replacement_id;
 return replacement_id;
end $$;

create or replace function public.revise_term_grading_configuration(id uuid,replacement_grade_scale_id uuid,
 replacement_require_weights_total_100 boolean,replacement_include_unpublished_finalized boolean) returns uuid
language plpgsql security definer set search_path='' as $$
declare c public.term_grading_configurations%rowtype; replacement_id uuid; replacement public.term_grading_configurations%rowtype;
begin
 select * into c from public.term_grading_configurations where term_grading_configurations.id=revise_term_grading_configuration.id for update;
 if not found then raise exception using errcode='P0002',message='configuration not found'; end if;
 if c.status<>'active' then raise exception using errcode='22023',message='active configuration required'; end if;
 replacement_id:=public.create_term_grading_configuration(c.section_id,c.academic_term_id,c.subject_id,replacement_grade_scale_id,
  replacement_require_weights_total_100,replacement_include_unpublished_finalized);
 update public.term_grading_configurations set supersedes_configuration_id=c.id where term_grading_configurations.id=replacement_id returning * into replacement;
 update public.audit_log set after_data=to_jsonb(replacement) where action='term_grading_configuration.created' and entity_id=replacement_id;
 return replacement_id;
end $$;

drop policy grade_scales_select on public.grade_scales;
create policy grade_scales_select on public.grade_scales for select to authenticated using(app_auth.can_read_grade_scale(id));
drop policy term_grade_sources_select on public.term_grade_calculation_sources;
create policy term_grade_sources_select on public.term_grade_calculation_sources for select to authenticated using(app_auth.can_read_term_grade_source(id));

do $$declare f regprocedure;begin foreach f in array array['app_auth.term_grade_actor()'::regprocedure,'app_auth.write_term_grade_change(uuid,uuid,uuid,text,text,uuid,jsonb,jsonb,jsonb,boolean)'::regprocedure,'app_auth.grade_scale_command(text,uuid,text,text,boolean,public.grade_scale_band_input[])'::regprocedure,'app_auth.term_config_command(text,uuid,uuid)'::regprocedure,'app_auth.assessment_chain_root(uuid)'::regprocedure,'app_auth.term_grade_fingerprint(uuid)'::regprocedure,'app_auth.lock_term_grade_context(uuid)'::regprocedure,'app_auth.populate_term_grade_set(uuid,integer,uuid,uuid)'::regprocedure,'app_auth.term_grade_set_transition(text,uuid,text)'::regprocedure,'app_auth.enforce_term_grade_source_identity()'::regprocedure,'app_auth.assert_term_grading_configuration_context(uuid,uuid,uuid,uuid)'::regprocedure]loop execute format('revoke all on function %s from public,anon,authenticated,service_role',f);end loop;end$$;
grant execute on function app_auth.has_term_grade_assignment(uuid,uuid,public.teaching_assignment_role[]),app_auth.can_read_term_grade_set(uuid),app_auth.can_read_term_grade_record(uuid),app_auth.can_read_term_grade_calculation(uuid),app_auth.can_read_grade_scale(uuid),app_auth.can_read_term_grade_source(uuid) to authenticated;
alter function app_auth.write_academic_change(uuid,uuid,text,text,uuid,jsonb,jsonb) owner to postgres;
alter function public.update_section(uuid,text,text,integer,date,date,uuid,uuid,public.record_status,boolean,boolean) owner to postgres;
alter function public.archive_section(uuid) owner to postgres;
revoke all on function app_auth.write_academic_change(uuid,uuid,text,text,uuid,jsonb,jsonb) from public,anon,authenticated,service_role;
revoke all on function public.update_section(uuid,text,text,integer,date,date,uuid,uuid,public.record_status,boolean,boolean),public.archive_section(uuid) from public,anon;
grant execute on function public.update_section(uuid,text,text,integer,date,date,uuid,uuid,public.record_status,boolean,boolean),public.archive_section(uuid) to authenticated,service_role;
revoke all on function public.create_grade_scale(uuid,uuid,text,text,public.grade_scale_band_input[]),public.update_draft_grade_scale(uuid,text,text,boolean,public.grade_scale_band_input[]),public.activate_grade_scale(uuid),public.retire_grade_scale(uuid),public.revise_grade_scale(uuid,text,text,public.grade_scale_band_input[]),public.create_term_grading_configuration(uuid,uuid,uuid,uuid,boolean,boolean),public.update_draft_term_grading_configuration(uuid,uuid,boolean,boolean),public.activate_term_grading_configuration(uuid),public.retire_term_grading_configuration(uuid),public.revise_term_grading_configuration(uuid,uuid,boolean,boolean),public.calculate_term_grades(uuid),public.recalculate_draft_term_grades(uuid),public.publish_term_grades(uuid),public.finalize_term_grades(uuid),public.cancel_draft_term_grades(uuid,text),public.correct_term_grades(uuid,text) from public,anon;
grant execute on function public.create_grade_scale(uuid,uuid,text,text,public.grade_scale_band_input[]),public.update_draft_grade_scale(uuid,text,text,boolean,public.grade_scale_band_input[]),public.activate_grade_scale(uuid),public.retire_grade_scale(uuid),public.revise_grade_scale(uuid,text,text,public.grade_scale_band_input[]),public.create_term_grading_configuration(uuid,uuid,uuid,uuid,boolean,boolean),public.update_draft_term_grading_configuration(uuid,uuid,boolean,boolean),public.activate_term_grading_configuration(uuid),public.retire_term_grading_configuration(uuid),public.revise_term_grading_configuration(uuid,uuid,boolean,boolean),public.calculate_term_grades(uuid),public.recalculate_draft_term_grades(uuid),public.publish_term_grades(uuid),public.finalize_term_grades(uuid),public.cancel_draft_term_grades(uuid,text),public.correct_term_grades(uuid,text) to authenticated;

comment on table public.term_grade_sets is 'Whole-context term-grade lifecycle and append-and-supersede correction aggregate.';
comment on table public.term_grade_records is 'Immutable student children versioned by set calculation sequence.';
comment on table public.term_grade_calculation_sources is 'Immutable exact assessment-result provenance; every row is audited and emits no individual event.';
commit;
