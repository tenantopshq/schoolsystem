begin;

-- SIS Command Layer v0.4. Migrations 001-004 remain immutable.

alter table public.student_identifiers add column status public.record_status not null default 'active';
alter table public.student_addresses add column status public.record_status not null default 'active';
alter table public.student_emergency_contacts add column status public.record_status not null default 'active';

do $$ declare c text; begin
 select conname into c from pg_constraint where conrelid='public.students'::regclass and contype='u'
  and pg_get_constraintdef(oid)='UNIQUE (organization_id, student_number)';
 if c is not null then execute format('alter table public.students drop constraint %I',c); end if;
 select conname into c from pg_constraint where conrelid='public.student_guardians'::regclass and contype='u'
  and pg_get_constraintdef(oid)='UNIQUE (student_id, guardian_id)';
 if c is not null then execute format('alter table public.student_guardians drop constraint %I',c); end if;
 select conname into c from pg_constraint where conrelid='public.student_identifiers'::regclass and contype='u'
  and pg_get_constraintdef(oid)='UNIQUE (student_id, identifier_type, identifier_value)';
 if c is not null then execute format('alter table public.student_identifiers drop constraint %I',c); end if;
 select conname into c from pg_constraint where conrelid='public.student_emergency_contacts'::regclass and contype='u'
  and pg_get_constraintdef(oid)='UNIQUE (student_id, priority)';
 if c is not null then execute format('alter table public.student_emergency_contacts drop constraint %I',c); end if;
end $$;
drop index public.student_addresses_one_primary_type_idx;

create unique index students_org_normalized_number_key
 on public.students(organization_id,lower(btrim(student_number)));
create unique index student_guardians_non_archived_pair_key
 on public.student_guardians(student_id,guardian_id) where status <> 'archived';
create unique index student_identifiers_non_archived_value_key
 on public.student_identifiers(student_id,lower(btrim(identifier_type)),lower(btrim(identifier_value)))
 where status <> 'archived';
create unique index student_addresses_one_active_primary_type_idx
 on public.student_addresses(student_id,lower(btrim(address_type))) where is_primary and status='active';
create unique index student_emergency_contacts_one_active_priority_idx
 on public.student_emergency_contacts(student_id,priority) where status='active';

create index student_guardians_org_guardian_status_student_idx
 on public.student_guardians(organization_id,guardian_id,status,student_id);
create index student_identifiers_org_student_status_idx
 on public.student_identifiers(organization_id,student_id,status);
create index student_addresses_org_student_status_idx
 on public.student_addresses(organization_id,student_id,status);
create index student_emergency_contacts_org_student_status_idx
 on public.student_emergency_contacts(organization_id,student_id,status);
create index student_documents_org_student_status_idx
 on public.student_documents(organization_id,student_id,status);

create table public.student_document_upload_intents (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete restrict,
 student_id uuid not null,
 storage_path text not null check(length(btrim(storage_path)) between 1 and 500),
 expires_at timestamptz not null,
 consumed_at timestamptz,
 consumed_by uuid references auth.users(id) on delete set null,
 created_at timestamptz not null default now(),
 created_by uuid not null references auth.users(id) on delete restrict,
 foreign key(organization_id,student_id) references public.students(organization_id,id) on delete restrict,
 unique(organization_id,storage_path),
 check(expires_at>created_at),
 check((consumed_at is null)=(consumed_by is null))
);
create index student_document_upload_intents_scope_idx
 on public.student_document_upload_intents(organization_id,student_id,id);
create index student_document_upload_intents_unconsumed_expiry_idx
 on public.student_document_upload_intents(expires_at,id) where consumed_at is null;
create index student_document_upload_intents_created_by_idx
 on public.student_document_upload_intents(created_by);
create index student_document_upload_intents_consumed_by_idx
 on public.student_document_upload_intents(consumed_by) where consumed_by is not null;
alter table public.student_document_upload_intents enable row level security;
alter table public.student_document_upload_intents force row level security;

insert into public.permissions(code,module,description) values
 ('students.sensitive_manage','students','Manage sensitive student identifiers within assigned scope');

drop index public.audit_log_academic_command_id_key;
drop index public.event_outbox_academic_command_id_key;
create unique index audit_log_command_entity_key on public.audit_log(command_id,entity_type,entity_id)
 where command_id is not null;
create unique index event_outbox_command_event_key
 on public.event_outbox(command_id,event_type,aggregate_type,aggregate_id)
 where command_id is not null;

drop policy if exists students_insert on public.students;
drop policy if exists students_update on public.students;
drop policy if exists guardians_insert on public.guardians;
drop policy if exists guardians_update on public.guardians;
drop policy if exists student_guardians_insert on public.student_guardians;
drop policy if exists student_guardians_update on public.student_guardians;
drop policy if exists student_identifiers_insert on public.student_identifiers;
drop policy if exists student_identifiers_update on public.student_identifiers;
drop policy if exists student_addresses_insert on public.student_addresses;
drop policy if exists student_addresses_update on public.student_addresses;
drop policy if exists student_emergency_contacts_insert on public.student_emergency_contacts;
drop policy if exists student_emergency_contacts_update on public.student_emergency_contacts;
drop policy if exists student_documents_insert on public.student_documents;
drop policy if exists student_documents_update on public.student_documents;

revoke insert,update,delete,truncate on public.students,public.guardians,public.student_guardians,
 public.student_identifiers,public.student_addresses,public.student_emergency_contacts,
 public.student_documents,public.student_document_upload_intents from public,anon,authenticated;
revoke all on public.student_document_upload_intents from public,anon,authenticated;
grant select,insert on public.student_document_upload_intents to service_role;

create or replace function app_auth.write_sis_change(
 p_command_id uuid,p_organization_id uuid,p_actor uuid,p_action text,p_entity_type text,
 p_entity_id uuid,p_before jsonb,p_after jsonb,p_payload jsonb
) returns void language plpgsql security definer set search_path='' as $$
declare b jsonb:=p_before; a jsonb:=p_after; changed jsonb;
begin
 select coalesce(jsonb_agg(k order by k),'[]'::jsonb) into changed
 from (select x.key k from jsonb_object_keys(coalesce(b,'{}'::jsonb)||coalesce(a,'{}'::jsonb)) x(key)
       where b->x.key is distinct from a->x.key) d;
 if p_entity_type='student_identifier' then
  if b is not null then b:=(b-'identifier_value')||jsonb_build_object('identifier_value','[REDACTED]'); end if;
  if a is not null then a:=(a-'identifier_value')||jsonb_build_object('identifier_value','[REDACTED]'); end if;
 end if;
 if a is not null then a:=a||jsonb_build_object('_changed_fields',changed); end if;
 insert into public.audit_log(command_id,organization_id,actor_user_id,action,entity_type,entity_id,before_data,after_data)
 values(p_command_id,p_organization_id,p_actor,p_action,p_entity_type,p_entity_id,b,a);
 insert into public.event_outbox(command_id,organization_id,event_type,aggregate_type,aggregate_id,payload)
 values(p_command_id,p_organization_id,p_action,p_entity_type,p_entity_id,
  coalesce(p_payload,'{}'::jsonb)||jsonb_build_object('command_id',p_command_id,'actor_user_id',p_actor,
   'organization_id',p_organization_id,'aggregate_id',p_entity_id,'changed_fields',changed));
end $$;

-- Forward private signatures keep typed wrappers resolvable; full guarded bodies
-- replace these definitions later in this same transaction before commit.
create or replace function app_auth.assert_sis_actor() returns uuid language plpgsql security definer set search_path='' as $$ begin raise exception 'uninitialized SIS helper'; end $$;
create or replace function app_auth.assert_student_permission(public.students,text) returns void language plpgsql security definer set search_path='' as $$ begin raise exception 'uninitialized SIS helper'; end $$;
create or replace function app_auth.lock_sis_students(uuid[]) returns void language plpgsql security definer set search_path='' as $$
declare x uuid; begin
 for x in select distinct s.organization_id from public.students s where s.id=any($1) order by 1 loop perform 1 from public.organizations where id=x for update; end loop;
 for x in select distinct s.school_id from public.students s where s.id=any($1) order by 1 loop perform 1 from public.schools where id=x for update; end loop;
 for x in select distinct s.campus_id from public.students s where s.id=any($1) and s.campus_id is not null order by 1 loop perform 1 from public.campuses where id=x for update; end loop;
 for x in select s.id from public.students s where s.id=any($1) order by s.id loop perform 1 from public.students where id=x for update; end loop;
end $$;
create or replace function app_auth.assert_clean_status_transition(p_old public.record_status,p_new public.record_status,p_business_changed boolean)
returns void language plpgsql immutable security definer set search_path='' as $$ begin
 if p_new='archived' then raise exception using errcode='22023',message='use the archive command'; end if;
 if p_old='inactive' and p_new='inactive' then raise exception using errcode='22023',message='inactive rows may only reactivate or archive'; end if;
 if p_old<>p_new and p_business_changed then raise exception using errcode='22023',message='status transition cannot include business or scope changes'; end if;
end $$;
create or replace function app_auth.sis_child_command(text,text,uuid,uuid,jsonb) returns uuid language plpgsql security definer set search_path='' as $$ begin raise exception 'uninitialized SIS helper'; end $$;
create or replace function app_auth.create_sis_student(uuid,uuid,jsonb) returns uuid language plpgsql security definer set search_path='' as $$ begin raise exception 'uninitialized SIS helper'; end $$;
create or replace function app_auth.update_sis_student(uuid,jsonb) returns uuid language plpgsql security definer set search_path='' as $$ begin raise exception 'uninitialized SIS helper'; end $$;
create or replace function app_auth.create_guardian_with_link(uuid,jsonb) returns table(guardian_id uuid,student_guardian_id uuid) language plpgsql security definer set search_path='' as $$ begin raise exception 'uninitialized SIS helper'; end $$;
create or replace function app_auth.assert_guardian_scope(uuid,boolean default false) returns public.guardians language plpgsql security definer set search_path='' as $$ begin raise exception 'uninitialized SIS helper'; end $$;
create or replace function app_auth.update_sis_guardian(uuid,jsonb) returns uuid language plpgsql security definer set search_path='' as $$ begin raise exception 'uninitialized SIS helper'; end $$;
create or replace function app_auth.archive_sis_guardian(uuid,text) returns uuid language plpgsql security definer set search_path='' as $$ begin raise exception 'uninitialized SIS helper'; end $$;

create or replace function app_auth.sis_guardian_link_command(p_operation text,p_id uuid,p_student uuid,p_guardian uuid,p_args jsonb)
returns uuid language plpgsql security definer set search_path='' as $$
declare actor uuid:=app_auth.assert_sis_actor(); s public.students%rowtype; g public.guardians%rowtype; oldj jsonb; newj jsonb; rid uuid:=coalesce(p_id,gen_random_uuid()); cmd uuid:=gen_random_uuid(); st public.record_status; ids uuid[]; current_ids uuid[];
begin
 if p_operation='archive' and nullif(btrim(p_args->>'archive_reason'),'') is null then raise exception using errcode='22023',message='archive reason must not be empty'; end if;
 if p_operation='create' then
  select array_agg(z order by z) into ids from (select p_student z union select sg.student_id from public.student_guardians sg where sg.guardian_id=p_guardian and sg.status='active') q;
  perform app_auth.lock_sis_students(ids);
  select * into s from public.students where id=p_student; if not found or s.status<>'active' then raise exception using errcode='P0002',message='active student is required'; end if;
  select * into g from public.guardians where id=p_guardian for update; if not found then raise exception using errcode='P0002',message='guardian not found'; end if;
  perform 1 from public.student_guardians where guardian_id=g.id order by id for update;
  select array_agg(z order by z) into current_ids from (select p_student z union select sg.student_id from public.student_guardians sg where sg.guardian_id=p_guardian and sg.status='active') q;
  if current_ids is distinct from ids then raise exception using errcode='40001',message='guardian links changed concurrently; retry'; end if;
  for s in select st.* from public.student_guardians sg join public.students st on st.id=sg.student_id where sg.guardian_id=g.id and sg.status='active' order by st.id loop perform app_auth.assert_student_permission(s,'students.edit'); end loop;
  select * into s from public.students where id=p_student;
  if g.organization_id<>s.organization_id or g.status<>'active' then raise exception using errcode='22023',message='active same-tenant guardian is required'; end if;
  perform app_auth.assert_student_permission(s,'students.edit');
  insert into public.student_guardians(id,organization_id,student_id,guardian_id,relationship_type,is_primary,has_portal_access,receives_academic_updates,receives_attendance_alerts,financial_responsibility,pickup_authorized,status,created_by,updated_by)
  values(rid,s.organization_id,s.id,g.id,p_args->>'relationship_type',(p_args->>'is_primary')::boolean,(p_args->>'has_portal_access')::boolean,(p_args->>'receives_academic_updates')::boolean,(p_args->>'receives_attendance_alerts')::boolean,(p_args->>'financial_responsibility')::boolean,(p_args->>'pickup_authorized')::boolean,'active',actor,actor)
  returning to_jsonb(student_guardians.*) into newj;
 else
  select sg.student_id,sg.guardian_id,to_jsonb(sg.*),sg.status into p_student,p_guardian,oldj,st from public.student_guardians sg where id=rid;
  if not found then raise exception using errcode='P0002',message='student guardian link not found'; end if;
  perform app_auth.lock_sis_students(array[p_student]); select * into s from public.students where id=p_student;
  select * into g from public.guardians where id=p_guardian for update;
  perform 1 from public.student_guardians where id=rid for update; perform app_auth.assert_student_permission(s,'students.edit');
  if st='archived' then raise exception using errcode='22023',message='archived guardian link is terminal'; end if;
  if p_operation='archive' then update public.student_guardians set status='archived',updated_by=actor where id=rid returning to_jsonb(student_guardians.*) into newj; newj:=newj||jsonb_build_object('_archive_reason',btrim(p_args->>'archive_reason'));
  else
   perform app_auth.assert_clean_status_transition(st,(p_args->>'status')::public.record_status,
    p_args->>'relationship_type' is distinct from oldj->>'relationship_type'
    or (p_args->>'is_primary')::boolean is distinct from (oldj->>'is_primary')::boolean
    or (p_args->>'has_portal_access')::boolean is distinct from (oldj->>'has_portal_access')::boolean
    or (p_args->>'receives_academic_updates')::boolean is distinct from (oldj->>'receives_academic_updates')::boolean
    or (p_args->>'receives_attendance_alerts')::boolean is distinct from (oldj->>'receives_attendance_alerts')::boolean
    or (p_args->>'financial_responsibility')::boolean is distinct from (oldj->>'financial_responsibility')::boolean
    or (p_args->>'pickup_authorized')::boolean is distinct from (oldj->>'pickup_authorized')::boolean);
   if st='inactive' and (p_args->>'status')::public.record_status<>'active' then raise exception using errcode='22023',message='inactive guardian link may only be reactivated or archived'; end if;
   if (p_args->>'status')::public.record_status='active' and (s.status<>'active' or g.status<>'active') then raise exception using errcode='22023',message='active student and guardian are required'; end if;
   update public.student_guardians set relationship_type=p_args->>'relationship_type',is_primary=(p_args->>'is_primary')::boolean,
    has_portal_access=(p_args->>'has_portal_access')::boolean,receives_academic_updates=(p_args->>'receives_academic_updates')::boolean,
    receives_attendance_alerts=(p_args->>'receives_attendance_alerts')::boolean,financial_responsibility=(p_args->>'financial_responsibility')::boolean,
    pickup_authorized=(p_args->>'pickup_authorized')::boolean,status=(p_args->>'status')::public.record_status,updated_by=actor where id=rid
    returning to_jsonb(student_guardians.*) into newj;
  end if;
 end if;
 perform app_auth.write_sis_change(cmd,s.organization_id,actor,case p_operation when 'create' then 'student.guardian_linked' when 'update' then 'student.guardian_updated' else 'student.guardian_unlinked' end,
  'student_guardian',rid,oldj,newj,jsonb_strip_nulls(jsonb_build_object('student_id',s.id,'guardian_id',g.id,'student_guardian_id',rid,'school_id',s.school_id,'campus_id',s.campus_id,'before_status',oldj->>'status','after_status',newj->>'status','reason',case when p_operation='archive' then btrim(p_args->>'archive_reason') end)));
 return rid;
end $$;

create or replace function app_auth.create_sis_document(p_intent uuid,p_args jsonb)
returns uuid language plpgsql security definer set search_path='' as $$
declare actor uuid:=app_auth.assert_sis_actor(); i public.student_document_upload_intents%rowtype; s public.students%rowtype; rid uuid:=gen_random_uuid(); newj jsonb; cmd uuid:=gen_random_uuid(); st public.record_status;
begin
 select * into i from public.student_document_upload_intents where id=p_intent;
 if not found then raise exception using errcode='P0002',message='upload intent not found'; end if;
 perform app_auth.lock_sis_students(array[i.student_id]); select * into s from public.students where id=i.student_id;
 if not found or s.status<>'active' then raise exception using errcode='P0002',message='active student is required'; end if;
 select * into i from public.student_document_upload_intents where id=p_intent for update;
 if not found or i.student_id<>s.id or i.organization_id<>s.organization_id then raise exception using errcode='22023',message='upload intent scope mismatch'; end if;
 perform app_auth.assert_student_permission(s,'students.edit'); perform app_auth.assert_student_permission(s,'student_documents.manage');
 if i.consumed_at is not null then raise exception using errcode='22023',message='upload intent is already consumed'; end if;
 if i.expires_at<=now() then raise exception using errcode='22023',message='upload intent is expired'; end if;
 st:=coalesce((p_args->>'status')::public.record_status,'active'); if st='archived' then raise exception using errcode='22023',message='document initial status cannot be archived'; end if;
 insert into public.student_documents(id,organization_id,student_id,document_type,title,storage_path,mime_type,file_size,issued_at,expires_at,visibility,status,created_by,updated_by)
 values(rid,s.organization_id,s.id,p_args->>'document_type',p_args->>'title',i.storage_path,p_args->>'mime_type',(p_args->>'file_size')::bigint,(p_args->>'issued_at')::date,(p_args->>'expires_at')::date,(p_args->>'visibility')::public.student_document_visibility,st,actor,actor)
 returning to_jsonb(student_documents.*) into newj;
 update public.student_document_upload_intents set consumed_at=now(),consumed_by=actor where id=i.id;
 perform app_auth.write_sis_change(cmd,s.organization_id,actor,'student.document_added','student_document',rid,null,newj,
  jsonb_build_object('student_id',s.id,'school_id',s.school_id,'campus_id',s.campus_id,'after_status',st,'visibility',p_args->>'visibility'));
 return rid;
end $$;

-- Narrow typed public RPCs. No tenant, actor, attribution, event, or arbitrary JSON input is public.
create function public.create_student(school_id uuid,campus_id uuid,student_number text,first_name text,middle_name text,last_name text,preferred_name text,date_of_birth date,gender text,nationality_code char(2),primary_language text,photo_path text,admission_date date,exit_date date,status public.record_status default 'active')
returns uuid language sql security definer set search_path='' as $$ select app_auth.create_sis_student(school_id,campus_id,jsonb_build_object('student_number',student_number,'first_name',first_name,'middle_name',middle_name,'last_name',last_name,'preferred_name',preferred_name,'date_of_birth',date_of_birth,'gender',gender,'nationality_code',nationality_code,'primary_language',primary_language,'photo_path',photo_path,'admission_date',admission_date,'exit_date',exit_date,'status',status)); $$;
create function public.update_student(id uuid,student_number text,first_name text,middle_name text,set_middle_name boolean,last_name text,preferred_name text,set_preferred_name boolean,date_of_birth date,gender text,set_gender boolean,nationality_code char(2),set_nationality_code boolean,primary_language text,set_primary_language boolean,photo_path text,set_photo_path boolean,admission_date date,set_admission_date boolean,exit_date date,set_exit_date boolean,status public.record_status,school_id uuid,set_school_id boolean,campus_id uuid,set_campus_id boolean)
returns uuid language sql security definer set search_path='' as $$ select app_auth.update_sis_student(id,jsonb_build_object('student_number',student_number,'first_name',first_name,'middle_name',middle_name,'set_middle_name',set_middle_name,'last_name',last_name,'preferred_name',preferred_name,'set_preferred_name',set_preferred_name,'date_of_birth',date_of_birth,'gender',gender,'set_gender',set_gender,'nationality_code',nationality_code,'set_nationality_code',set_nationality_code,'primary_language',primary_language,'set_primary_language',set_primary_language,'photo_path',photo_path,'set_photo_path',set_photo_path,'admission_date',admission_date,'set_admission_date',set_admission_date,'exit_date',exit_date,'set_exit_date',set_exit_date,'status',status,'school_id',school_id,'set_school_id',set_school_id,'campus_id',campus_id,'set_campus_id',set_campus_id)); $$;
create or replace function public.archive_student(target_student_id uuid,archive_reason text) returns uuid language sql security definer set search_path='' as $$ select app_auth.archive_student(target_student_id,archive_reason); $$;

create function public.create_guardian_for_student(student_id uuid,first_name text,middle_name text,last_name text,email text,phone text,alternate_phone text,occupation text,preferred_language text,relationship_type text,is_primary boolean,has_portal_access boolean,receives_academic_updates boolean,receives_attendance_alerts boolean,financial_responsibility boolean,pickup_authorized boolean)
returns table(guardian_id uuid,student_guardian_id uuid) language sql security definer set search_path='' as $$ select * from app_auth.create_guardian_with_link(student_id,jsonb_build_object('first_name',first_name,'middle_name',middle_name,'last_name',last_name,'email',email,'phone',phone,'alternate_phone',alternate_phone,'occupation',occupation,'preferred_language',preferred_language,'relationship_type',relationship_type,'is_primary',is_primary,'has_portal_access',has_portal_access,'receives_academic_updates',receives_academic_updates,'receives_attendance_alerts',receives_attendance_alerts,'financial_responsibility',financial_responsibility,'pickup_authorized',pickup_authorized)); $$;
create function public.update_guardian(id uuid,first_name text,middle_name text,set_middle_name boolean,last_name text,email text,set_email boolean,phone text,set_phone boolean,alternate_phone text,set_alternate_phone boolean,occupation text,set_occupation boolean,preferred_language text,set_preferred_language boolean,status public.record_status)
returns uuid language sql security definer set search_path='' as $$ select app_auth.update_sis_guardian(id,jsonb_build_object('first_name',first_name,'middle_name',middle_name,'set_middle_name',set_middle_name,'last_name',last_name,'email',email,'set_email',set_email,'phone',phone,'set_phone',set_phone,'alternate_phone',alternate_phone,'set_alternate_phone',set_alternate_phone,'occupation',occupation,'set_occupation',set_occupation,'preferred_language',preferred_language,'set_preferred_language',set_preferred_language,'status',status)); $$;
create function public.archive_guardian(id uuid,archive_reason text) returns uuid language sql security definer set search_path='' as $$ select app_auth.archive_sis_guardian(id,archive_reason); $$;
create function public.link_guardian_to_student(student_id uuid,guardian_id uuid,relationship_type text,is_primary boolean,has_portal_access boolean,receives_academic_updates boolean,receives_attendance_alerts boolean,financial_responsibility boolean,pickup_authorized boolean)
returns uuid language sql security definer set search_path='' as $$ select app_auth.sis_guardian_link_command('create',null,student_id,guardian_id,jsonb_build_object('relationship_type',relationship_type,'is_primary',is_primary,'has_portal_access',has_portal_access,'receives_academic_updates',receives_academic_updates,'receives_attendance_alerts',receives_attendance_alerts,'financial_responsibility',financial_responsibility,'pickup_authorized',pickup_authorized)); $$;
create function public.update_student_guardian(id uuid,relationship_type text,is_primary boolean,has_portal_access boolean,receives_academic_updates boolean,receives_attendance_alerts boolean,financial_responsibility boolean,pickup_authorized boolean,status public.record_status)
returns uuid language sql security definer set search_path='' as $$ select app_auth.sis_guardian_link_command('update',id,null,null,jsonb_build_object('relationship_type',relationship_type,'is_primary',is_primary,'has_portal_access',has_portal_access,'receives_academic_updates',receives_academic_updates,'receives_attendance_alerts',receives_attendance_alerts,'financial_responsibility',financial_responsibility,'pickup_authorized',pickup_authorized,'status',status)); $$;
create function public.archive_student_guardian(id uuid,archive_reason text) returns uuid language sql security definer set search_path='' as $$ select app_auth.sis_guardian_link_command('archive',id,null,null,jsonb_build_object('archive_reason',archive_reason)); $$;

create function public.create_student_identifier(student_id uuid,identifier_type text,identifier_value text,country_code char(2),issued_at date,expires_at date,status public.record_status default 'active') returns uuid language sql security definer set search_path='' as $$ select app_auth.sis_child_command('identifier','create',null,student_id,jsonb_build_object('identifier_type',identifier_type,'identifier_value',identifier_value,'country_code',country_code,'issued_at',issued_at,'expires_at',expires_at,'status',status)); $$;
create function public.update_student_identifier(id uuid,identifier_type text,identifier_value text,country_code char(2),set_country_code boolean,issued_at date,set_issued_at boolean,expires_at date,set_expires_at boolean,status public.record_status) returns uuid language sql security definer set search_path='' as $$ select app_auth.sis_child_command('identifier','update',id,null,jsonb_build_object('identifier_type',identifier_type,'identifier_value',identifier_value,'country_code',country_code,'set_country_code',set_country_code,'issued_at',issued_at,'set_issued_at',set_issued_at,'expires_at',expires_at,'set_expires_at',set_expires_at,'status',status)); $$;
create function public.archive_student_identifier(id uuid,archive_reason text) returns uuid language sql security definer set search_path='' as $$ select app_auth.sis_child_command('identifier','archive',id,null,jsonb_build_object('archive_reason',archive_reason)); $$;

create function public.create_student_address(student_id uuid,address_type text,line_1 text,line_2 text,city text,state_region text,postal_code text,country_code char(2),is_primary boolean,status public.record_status default 'active') returns uuid language sql security definer set search_path='' as $$ select app_auth.sis_child_command('address','create',null,student_id,jsonb_build_object('address_type',address_type,'line_1',line_1,'line_2',line_2,'city',city,'state_region',state_region,'postal_code',postal_code,'country_code',country_code,'is_primary',is_primary,'status',status)); $$;
create function public.update_student_address(id uuid,address_type text,line_1 text,line_2 text,set_line_2 boolean,city text,state_region text,set_state_region boolean,postal_code text,set_postal_code boolean,country_code char(2),is_primary boolean,status public.record_status) returns uuid language sql security definer set search_path='' as $$ select app_auth.sis_child_command('address','update',id,null,jsonb_build_object('address_type',address_type,'line_1',line_1,'line_2',line_2,'set_line_2',set_line_2,'city',city,'state_region',state_region,'set_state_region',set_state_region,'postal_code',postal_code,'set_postal_code',set_postal_code,'country_code',country_code,'is_primary',is_primary,'status',status)); $$;
create function public.archive_student_address(id uuid,archive_reason text) returns uuid language sql security definer set search_path='' as $$ select app_auth.sis_child_command('address','archive',id,null,jsonb_build_object('archive_reason',archive_reason)); $$;

create function public.create_student_emergency_contact(student_id uuid,guardian_id uuid,name text,relationship text,phone text,alternate_phone text,priority smallint,status public.record_status default 'active') returns uuid language sql security definer set search_path='' as $$ select app_auth.sis_child_command('emergency_contact','create',null,student_id,jsonb_build_object('guardian_id',guardian_id,'name',name,'relationship',relationship,'phone',phone,'alternate_phone',alternate_phone,'priority',priority,'status',status)); $$;
create function public.update_student_emergency_contact(id uuid,guardian_id uuid,set_guardian_id boolean,name text,relationship text,phone text,alternate_phone text,set_alternate_phone boolean,priority smallint,status public.record_status) returns uuid language sql security definer set search_path='' as $$ select app_auth.sis_child_command('emergency_contact','update',id,null,jsonb_build_object('guardian_id',guardian_id,'set_guardian_id',set_guardian_id,'name',name,'relationship',relationship,'phone',phone,'alternate_phone',alternate_phone,'set_alternate_phone',set_alternate_phone,'priority',priority,'status',status)); $$;
create function public.archive_student_emergency_contact(id uuid,archive_reason text) returns uuid language sql security definer set search_path='' as $$ select app_auth.sis_child_command('emergency_contact','archive',id,null,jsonb_build_object('archive_reason',archive_reason)); $$;

create function public.create_student_document(upload_intent_id uuid,document_type text,title text,mime_type text,file_size bigint,issued_at date,expires_at date,visibility public.student_document_visibility,status public.record_status default 'active') returns uuid language sql security definer set search_path='' as $$ select app_auth.create_sis_document(upload_intent_id,jsonb_build_object('document_type',document_type,'title',title,'mime_type',mime_type,'file_size',file_size,'issued_at',issued_at,'expires_at',expires_at,'visibility',visibility,'status',status)); $$;
create function public.update_student_document(id uuid,document_type text,title text,mime_type text,set_mime_type boolean,file_size bigint,set_file_size boolean,issued_at date,set_issued_at boolean,expires_at date,set_expires_at boolean,visibility public.student_document_visibility,status public.record_status) returns uuid language sql security definer set search_path='' as $$ select app_auth.sis_child_command('document','update',id,null,jsonb_build_object('document_type',document_type,'title',title,'mime_type',mime_type,'set_mime_type',set_mime_type,'file_size',file_size,'set_file_size',set_file_size,'issued_at',issued_at,'set_issued_at',set_issued_at,'expires_at',expires_at,'set_expires_at',set_expires_at,'visibility',visibility,'status',status)); $$;
create function public.archive_student_document(id uuid,archive_reason text) returns uuid language sql security definer set search_path='' as $$ select app_auth.sis_child_command('document','archive',id,null,jsonb_build_object('archive_reason',archive_reason)); $$;

-- Exact ownership and exposure.
alter function app_auth.write_sis_change(uuid,uuid,uuid,text,text,uuid,jsonb,jsonb,jsonb) owner to postgres;
alter function app_auth.assert_sis_actor() owner to postgres;
alter function app_auth.assert_student_permission(public.students,text) owner to postgres;
alter function app_auth.lock_sis_students(uuid[]) owner to postgres;
alter function app_auth.assert_clean_status_transition(public.record_status,public.record_status,boolean) owner to postgres;
alter function app_auth.sis_child_command(text,text,uuid,uuid,jsonb) owner to postgres;
alter function app_auth.create_sis_student(uuid,uuid,jsonb) owner to postgres;
alter function app_auth.update_sis_student(uuid,jsonb) owner to postgres;
alter function app_auth.archive_student(uuid,text) owner to postgres;
alter function app_auth.create_guardian_with_link(uuid,jsonb) owner to postgres;
alter function app_auth.assert_guardian_scope(uuid,boolean) owner to postgres;
alter function app_auth.update_sis_guardian(uuid,jsonb) owner to postgres;
alter function app_auth.archive_sis_guardian(uuid,text) owner to postgres;
alter function app_auth.sis_guardian_link_command(text,uuid,uuid,uuid,jsonb) owner to postgres;
alter function app_auth.create_sis_document(uuid,jsonb) owner to postgres;

revoke all on function app_auth.write_sis_change(uuid,uuid,uuid,text,text,uuid,jsonb,jsonb,jsonb),app_auth.assert_sis_actor(),app_auth.assert_student_permission(public.students,text),app_auth.lock_sis_students(uuid[]),app_auth.assert_clean_status_transition(public.record_status,public.record_status,boolean),app_auth.sis_child_command(text,text,uuid,uuid,jsonb),app_auth.create_sis_student(uuid,uuid,jsonb),app_auth.update_sis_student(uuid,jsonb),app_auth.archive_student(uuid,text),app_auth.create_guardian_with_link(uuid,jsonb),app_auth.assert_guardian_scope(uuid,boolean),app_auth.update_sis_guardian(uuid,jsonb),app_auth.archive_sis_guardian(uuid,text),app_auth.sis_guardian_link_command(text,uuid,uuid,uuid,jsonb),app_auth.create_sis_document(uuid,jsonb) from public,anon,authenticated,service_role;

-- Public wrappers are owner-executed because ordinary roles have no table writes.
-- Their private callees still derive auth.uid(), tenant, and scope and enforce RBAC.
do $$ declare r record; begin
 for r in select p.oid::regprocedure sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname in ('create_student','update_student','archive_student','create_guardian_for_student','update_guardian','archive_guardian','link_guardian_to_student','update_student_guardian','archive_student_guardian','create_student_identifier','update_student_identifier','archive_student_identifier','create_student_address','update_student_address','archive_student_address','create_student_emergency_contact','update_student_emergency_contact','archive_student_emergency_contact','create_student_document','update_student_document','archive_student_document') loop
  execute format('alter function %s owner to postgres',r.sig);
  execute format('revoke all on function %s from public,anon,authenticated,service_role',r.sig);
  execute format('grant execute on function %s to authenticated,service_role',r.sig);
 end loop;
end $$;

comment on table public.student_document_upload_intents is 'Server-only, single-use storage authorization handoff. Browser roles receive no access.';
comment on function app_auth.write_sis_change(uuid,uuid,uuid,text,text,uuid,jsonb,jsonb,jsonb) is 'Private atomic SIS audit/outbox writer; identifier values are redacted before audit serialization.';
comment on function app_auth.sis_child_command(text,text,uuid,uuid,jsonb) is 'Private SIS child dispatcher. Public callers use typed RPCs only.';
comment on function public.create_student_document(uuid,text,text,text,bigint,date,date,public.student_document_visibility,public.record_status) is 'Consumes a locked server-created upload intent; storage_path is never caller supplied.';
comment on function public.create_guardian_for_student(uuid,text,text,text,text,text,text,text,text,text,boolean,boolean,boolean,boolean,boolean,boolean) is 'Atomically creates guardian and initial student link and returns both generated IDs.';

create or replace function app_auth.create_sis_student(p_school uuid,p_campus uuid,p_args jsonb)
returns uuid language plpgsql security definer set search_path='' as $$
declare actor uuid:=app_auth.assert_sis_actor(); o uuid; rid uuid:=gen_random_uuid(); newj jsonb; cmd uuid:=gen_random_uuid(); st public.record_status;
begin
 select sc.organization_id into o from public.organizations org join public.schools sc on sc.organization_id=org.id
 where sc.id=p_school and org.status='active' and sc.status='active' for update of org,sc;
 if not found then raise exception using errcode='P0002',message='active student organization and school are required'; end if;
 if p_campus is not null then
  perform 1 from public.campuses c where (c.organization_id,c.school_id,c.id)=(o,p_school,p_campus) and c.status='active' for update;
  if not found then raise exception using errcode='P0002',message='active campus in student school is required'; end if;
 end if;
 if not app_auth.has_permission(o,'students.create',p_school,p_campus) then raise exception using errcode='42501',message='students.create permission is required'; end if;
 st:=coalesce((p_args->>'status')::public.record_status,'active'); if st='archived' then raise exception using errcode='22023',message='student initial status cannot be archived'; end if;
 insert into public.students(id,organization_id,school_id,campus_id,student_number,first_name,middle_name,last_name,preferred_name,date_of_birth,gender,nationality_code,primary_language,photo_path,admission_date,exit_date,status,created_by,updated_by)
 values(rid,o,p_school,p_campus,p_args->>'student_number',p_args->>'first_name',p_args->>'middle_name',p_args->>'last_name',p_args->>'preferred_name',(p_args->>'date_of_birth')::date,p_args->>'gender',(p_args->>'nationality_code')::char(2),p_args->>'primary_language',p_args->>'photo_path',(p_args->>'admission_date')::date,(p_args->>'exit_date')::date,st,actor,actor)
 returning to_jsonb(students.*) into newj;
 perform app_auth.write_sis_change(cmd,o,actor,'student.created','student',rid,null,newj,
  jsonb_strip_nulls(jsonb_build_object('student_id',rid,'school_id',p_school,'campus_id',p_campus,'after_status',st)));
 return rid;
end $$;

create or replace function app_auth.update_sis_student(p_id uuid,p_args jsonb)
returns uuid language plpgsql security definer set search_path='' as $$
declare actor uuid:=app_auth.assert_sis_actor(); s public.students%rowtype; oldj jsonb; newj jsonb; ns uuid; nc uuid; cmd uuid:=gen_random_uuid(); nst public.record_status; x uuid;
begin
 select * into s from public.students where id=p_id;
 if not found then raise exception using errcode='P0002',message='student not found'; end if;
 ns:=case when (p_args->>'set_school_id')::boolean then (p_args->>'school_id')::uuid else s.school_id end;
 nc:=case when (p_args->>'set_campus_id')::boolean then (p_args->>'campus_id')::uuid else s.campus_id end;
 perform 1 from public.organizations where id=s.organization_id for update;
 for x in select q from unnest(array[s.school_id,ns]) as u(q) where q is not null group by q order by q loop perform 1 from public.schools where id=x for update; end loop;
 for x in select q from unnest(array[s.campus_id,nc]) as u(q) where q is not null group by q order by q loop perform 1 from public.campuses where id=x for update; end loop;
 select * into s from public.students where id=p_id for update;
 if s.status='archived' then raise exception using errcode='22023',message='archived student is terminal'; end if;
 perform app_auth.assert_student_permission(s,'students.edit'); oldj:=to_jsonb(s);
 nst:=(p_args->>'status')::public.record_status; if nst='archived' then raise exception using errcode='22023',message='use archive_student'; end if;
 perform app_auth.assert_clean_status_transition(s.status,nst,
  ns is distinct from s.school_id or nc is distinct from s.campus_id or p_args->>'student_number' is distinct from s.student_number
  or p_args->>'first_name' is distinct from s.first_name or p_args->>'last_name' is distinct from s.last_name
  or (p_args->>'date_of_birth')::date is distinct from s.date_of_birth
  or (case when (p_args->>'set_middle_name')::boolean then p_args->>'middle_name' else s.middle_name end) is distinct from s.middle_name
  or (case when (p_args->>'set_preferred_name')::boolean then p_args->>'preferred_name' else s.preferred_name end) is distinct from s.preferred_name
  or (case when (p_args->>'set_gender')::boolean then p_args->>'gender' else s.gender end) is distinct from s.gender
  or (case when (p_args->>'set_nationality_code')::boolean then (p_args->>'nationality_code')::char(2) else s.nationality_code end) is distinct from s.nationality_code
  or (case when (p_args->>'set_primary_language')::boolean then p_args->>'primary_language' else s.primary_language end) is distinct from s.primary_language
  or (case when (p_args->>'set_photo_path')::boolean then p_args->>'photo_path' else s.photo_path end) is distinct from s.photo_path
  or (case when (p_args->>'set_admission_date')::boolean then (p_args->>'admission_date')::date else s.admission_date end) is distinct from s.admission_date
  or (case when (p_args->>'set_exit_date')::boolean then (p_args->>'exit_date')::date else s.exit_date end) is distinct from s.exit_date);
 if ns<>s.school_id or nc is distinct from s.campus_id or nst='active' then
  perform 1 from public.schools sc join public.organizations org on org.id=sc.organization_id
   where (sc.organization_id,sc.id)=(s.organization_id,ns) and sc.status='active' and org.status='active' for update of sc,org;
  if not found then raise exception using errcode='P0002',message='active destination school is required'; end if;
  if nc is not null then perform 1 from public.campuses c where (c.organization_id,c.school_id,c.id)=(s.organization_id,ns,nc) and c.status='active' for update;
   if not found then raise exception using errcode='P0002',message='active destination campus is required'; end if; end if;
 end if;
 if ns<>s.school_id or nc is distinct from s.campus_id then
  if not app_auth.has_permission(s.organization_id,'students.edit',ns,nc) then raise exception using errcode='42501',message='students.edit permission is required at destination scope'; end if;
 end if;
 update public.students set school_id=ns,campus_id=nc,student_number=p_args->>'student_number',first_name=p_args->>'first_name',
  middle_name=case when (p_args->>'set_middle_name')::boolean then p_args->>'middle_name' else middle_name end,last_name=p_args->>'last_name',
  preferred_name=case when (p_args->>'set_preferred_name')::boolean then p_args->>'preferred_name' else preferred_name end,date_of_birth=(p_args->>'date_of_birth')::date,
  gender=case when (p_args->>'set_gender')::boolean then p_args->>'gender' else gender end,
  nationality_code=case when (p_args->>'set_nationality_code')::boolean then (p_args->>'nationality_code')::char(2) else nationality_code end,
  primary_language=case when (p_args->>'set_primary_language')::boolean then p_args->>'primary_language' else primary_language end,
  photo_path=case when (p_args->>'set_photo_path')::boolean then p_args->>'photo_path' else photo_path end,
  admission_date=case when (p_args->>'set_admission_date')::boolean then (p_args->>'admission_date')::date else admission_date end,
  exit_date=case when (p_args->>'set_exit_date')::boolean then (p_args->>'exit_date')::date else exit_date end,status=nst,updated_by=actor
 where id=p_id returning to_jsonb(students.*) into newj;
 perform app_auth.write_sis_change(cmd,s.organization_id,actor,'student.updated','student',p_id,oldj,newj,
  jsonb_strip_nulls(jsonb_build_object('student_id',p_id,'school_id',ns,'campus_id',nc,'before_status',s.status,'after_status',nst)));
 return p_id;
end $$;

create or replace function app_auth.archive_student(target_student_id uuid,archive_reason text)
returns uuid language plpgsql security definer set search_path='' as $$
declare actor uuid:=app_auth.assert_sis_actor(); s public.students%rowtype; newj jsonb; cmd uuid:=gen_random_uuid(); reason text:=btrim(archive_reason);
begin
 if reason is null or reason='' then raise exception using errcode='22023',message='archive reason must not be empty'; end if;
 perform app_auth.lock_sis_students(array[target_student_id]); select * into s from public.students where id=target_student_id;
 if not found then raise exception using errcode='P0002',message='student not found'; end if;
 if s.status='archived' then raise exception using errcode='22023',message='student is already archived'; end if;
 perform app_auth.assert_student_permission(s,'students.archive');
 if exists(select 1 from public.student_guardians where student_id=s.id and status='active')
  or exists(select 1 from public.student_identifiers where student_id=s.id and status='active')
  or exists(select 1 from public.student_addresses where student_id=s.id and status='active')
  or exists(select 1 from public.student_emergency_contacts where student_id=s.id and status='active')
  or exists(select 1 from public.student_documents where student_id=s.id and status='active') then
  raise exception using errcode='23503',message='active student children must be archived or inactivated first';
 end if;
 update public.students set status='archived',updated_by=actor where id=s.id returning to_jsonb(students.*) into newj;
 newj:=newj||jsonb_build_object('reason',reason,'_archive_reason',reason);
 perform app_auth.write_sis_change(cmd,s.organization_id,actor,'student.archived','student',s.id,to_jsonb(s),newj,
  jsonb_strip_nulls(jsonb_build_object('student_id',s.id,'school_id',s.school_id,'campus_id',s.campus_id,'before_status',s.status,'after_status','archived','reason',reason)));
 return s.id;
end $$;

create or replace function app_auth.create_guardian_with_link(p_student uuid,p_args jsonb)
returns table(guardian_id uuid,student_guardian_id uuid) language plpgsql security definer set search_path='' as $$
declare actor uuid:=app_auth.assert_sis_actor(); s public.students%rowtype; g uuid:=gen_random_uuid(); l uuid:=gen_random_uuid(); cmd uuid:=gen_random_uuid(); gj jsonb; lj jsonb;
begin
 perform app_auth.lock_sis_students(array[p_student]); select * into s from public.students where id=p_student;
 if not found or s.status<>'active' then raise exception using errcode='P0002',message='active student is required'; end if;
 perform app_auth.assert_student_permission(s,'students.edit');
 insert into public.guardians(id,organization_id,first_name,middle_name,last_name,email,phone,alternate_phone,occupation,preferred_language,status,created_by,updated_by)
 values(g,s.organization_id,p_args->>'first_name',p_args->>'middle_name',p_args->>'last_name',p_args->>'email',p_args->>'phone',p_args->>'alternate_phone',p_args->>'occupation',p_args->>'preferred_language','active',actor,actor)
 returning to_jsonb(guardians.*) into gj;
 insert into public.student_guardians(id,organization_id,student_id,guardian_id,relationship_type,is_primary,has_portal_access,receives_academic_updates,receives_attendance_alerts,financial_responsibility,pickup_authorized,status,created_by,updated_by)
 values(l,s.organization_id,s.id,g,p_args->>'relationship_type',(p_args->>'is_primary')::boolean,(p_args->>'has_portal_access')::boolean,(p_args->>'receives_academic_updates')::boolean,(p_args->>'receives_attendance_alerts')::boolean,(p_args->>'financial_responsibility')::boolean,(p_args->>'pickup_authorized')::boolean,'active',actor,actor)
 returning to_jsonb(student_guardians.*) into lj;
 perform app_auth.write_sis_change(cmd,s.organization_id,actor,'guardian.created','guardian',g,null,gj,jsonb_build_object('guardian_id',g,'student_id',s.id,'school_id',s.school_id,'campus_id',s.campus_id));
 perform app_auth.write_sis_change(cmd,s.organization_id,actor,'student.guardian_linked','student_guardian',l,null,lj,jsonb_build_object('guardian_id',g,'student_id',s.id,'student_guardian_id',l,'school_id',s.school_id,'campus_id',s.campus_id));
 guardian_id:=g; student_guardian_id:=l; return next;
end $$;

create or replace function app_auth.assert_guardian_scope(p_guardian uuid,p_historical boolean default false)
returns public.guardians language plpgsql security definer set search_path='' as $$
declare g public.guardians%rowtype; s public.students%rowtype; n int:=0; ids uuid[]; current_ids uuid[];
begin
 select * into g from public.guardians where id=p_guardian;
 if not found then raise exception using errcode='P0002',message='guardian not found'; end if;
 select array_agg(sg.student_id order by sg.student_id) into ids from public.student_guardians sg
  where sg.guardian_id=g.id and (p_historical or sg.status='active');
 if ids is null then raise exception using errcode='42501',message='guardian requires an authorized linked student'; end if;
 perform app_auth.lock_sis_students(ids);
 select * into g from public.guardians where id=p_guardian for update;
 perform 1 from public.student_guardians sg where sg.guardian_id=g.id and (p_historical or sg.status='active') order by sg.id for update;
 select array_agg(sg.student_id order by sg.student_id) into current_ids from public.student_guardians sg
  where sg.guardian_id=g.id and (p_historical or sg.status='active');
 if current_ids is distinct from ids then raise exception using errcode='40001',message='guardian links changed concurrently; retry'; end if;
 for s in select st.* from public.student_guardians sg join public.students st on st.id=sg.student_id
  where sg.guardian_id=g.id and (p_historical or sg.status='active') order by st.id loop
  n:=n+1; perform app_auth.assert_student_permission(s,'students.edit');
 end loop;
 if n=0 then raise exception using errcode='42501',message='guardian requires an authorized linked student'; end if;
 return g;
end $$;

create or replace function app_auth.update_sis_guardian(p_id uuid,p_args jsonb)
returns uuid language plpgsql security definer set search_path='' as $$
declare actor uuid:=app_auth.assert_sis_actor(); g public.guardians%rowtype; oldj jsonb; newj jsonb; cmd uuid:=gen_random_uuid(); nst public.record_status;
begin
 g:=app_auth.assert_guardian_scope(p_id,false); if g.status='archived' then raise exception using errcode='22023',message='archived guardian is terminal'; end if;
 nst:=(p_args->>'status')::public.record_status; if nst='archived' then raise exception using errcode='22023',message='use archive_guardian'; end if;
 perform app_auth.assert_clean_status_transition(g.status,nst,
  p_args->>'first_name' is distinct from g.first_name or p_args->>'last_name' is distinct from g.last_name
  or (case when (p_args->>'set_middle_name')::boolean then p_args->>'middle_name' else g.middle_name end) is distinct from g.middle_name
  or (case when (p_args->>'set_email')::boolean then p_args->>'email' else g.email end) is distinct from g.email
  or (case when (p_args->>'set_phone')::boolean then p_args->>'phone' else g.phone end) is distinct from g.phone
  or (case when (p_args->>'set_alternate_phone')::boolean then p_args->>'alternate_phone' else g.alternate_phone end) is distinct from g.alternate_phone
  or (case when (p_args->>'set_occupation')::boolean then p_args->>'occupation' else g.occupation end) is distinct from g.occupation
  or (case when (p_args->>'set_preferred_language')::boolean then p_args->>'preferred_language' else g.preferred_language end) is distinct from g.preferred_language);
 if nst='active' and not exists(select 1 from public.student_guardians sg join public.students s on s.id=sg.student_id where sg.guardian_id=g.id and sg.status='active' and s.status='active') then raise exception using errcode='22023',message='active linked student is required'; end if;
 oldj:=to_jsonb(g);
 update public.guardians set first_name=p_args->>'first_name',middle_name=case when (p_args->>'set_middle_name')::boolean then p_args->>'middle_name' else middle_name end,
  last_name=p_args->>'last_name',email=case when (p_args->>'set_email')::boolean then p_args->>'email' else email end,
  phone=case when (p_args->>'set_phone')::boolean then p_args->>'phone' else phone end,alternate_phone=case when (p_args->>'set_alternate_phone')::boolean then p_args->>'alternate_phone' else alternate_phone end,
  occupation=case when (p_args->>'set_occupation')::boolean then p_args->>'occupation' else occupation end,preferred_language=case when (p_args->>'set_preferred_language')::boolean then p_args->>'preferred_language' else preferred_language end,
  status=nst,updated_by=actor where id=p_id returning to_jsonb(guardians.*) into newj;
 perform app_auth.write_sis_change(cmd,g.organization_id,actor,'guardian.updated','guardian',g.id,oldj,newj,jsonb_build_object('guardian_id',g.id,'before_status',g.status,'after_status',nst)); return g.id;
end $$;

create or replace function app_auth.archive_sis_guardian(p_id uuid,p_reason text)
returns uuid language plpgsql security definer set search_path='' as $$
declare actor uuid:=app_auth.assert_sis_actor(); g public.guardians%rowtype; newj jsonb; cmd uuid:=gen_random_uuid(); reason text:=btrim(p_reason);
begin
 if reason is null or reason='' then raise exception using errcode='22023',message='archive reason must not be empty'; end if;
 g:=app_auth.assert_guardian_scope(p_id,true); if g.status='archived' then raise exception using errcode='22023',message='archived guardian is terminal'; end if;
 if exists(select 1 from public.student_guardians where guardian_id=g.id and status='active') then raise exception using errcode='23503',message='active guardian links must be inactivated or archived first'; end if;
 update public.guardians set status='archived',updated_by=actor where id=g.id returning to_jsonb(guardians.*) into newj;
 newj:=newj||jsonb_build_object('_archive_reason',reason);
 perform app_auth.write_sis_change(cmd,g.organization_id,actor,'guardian.archived','guardian',g.id,to_jsonb(g),newj,jsonb_build_object('guardian_id',g.id,'before_status',g.status,'after_status','archived','archive_reason',reason)); return g.id;
end $$;

create or replace function app_auth.assert_sis_actor() returns uuid
language plpgsql stable security definer set search_path='' as $$
declare a uuid:=auth.uid(); begin
 if a is null then raise exception using errcode='42501',message='an authenticated actor is required'; end if;
 return a;
end $$;

create or replace function app_auth.assert_student_permission(p_student public.students,p_permission text)
returns void language plpgsql stable security definer set search_path='' as $$
begin
 if not app_auth.has_permission(p_student.organization_id,p_permission,p_student.school_id,p_student.campus_id) then
  raise exception using errcode='42501',message=p_permission||' permission is required';
 end if;
end $$;

create or replace function app_auth.sis_child_command(p_kind text,p_operation text,p_target uuid,p_student uuid,p_args jsonb)
returns uuid language plpgsql security definer set search_path='' as $$
declare actor uuid:=app_auth.assert_sis_actor(); s public.students%rowtype; oldj jsonb; newj jsonb;
 rid uuid:=coalesce(p_target,gen_random_uuid()); o uuid; st public.record_status; cmd uuid:=gen_random_uuid();
 permission text:='students.edit'; action text; payload jsonb; effective_guardian uuid;
begin
 if p_operation not in ('create','update','archive') then raise exception 'unsupported operation'; end if;
 if p_operation='archive' and nullif(btrim(p_args->>'archive_reason'),'') is null then
  raise exception using errcode='22023',message='archive reason must not be empty';
 end if;
 if p_operation='create' then
  perform app_auth.lock_sis_students(array[p_student]); select * into s from public.students where id=p_student;
 else
  if p_kind='identifier' then select student_id into p_student from public.student_identifiers where id=rid;
  elsif p_kind='address' then select student_id into p_student from public.student_addresses where id=rid;
  elsif p_kind='emergency_contact' then select student_id into p_student from public.student_emergency_contacts where id=rid;
  elsif p_kind='document' then select student_id into p_student from public.student_documents where id=rid;
  else raise exception 'unsupported child kind'; end if;
  if not found then raise exception using errcode='P0002',message=p_kind||' not found'; end if;
  perform app_auth.lock_sis_students(array[p_student]); select * into s from public.students where id=p_student;
 end if;
 if not found then raise exception using errcode='P0002',message='student not found'; end if;
 if p_kind='identifier' then
  perform app_auth.assert_student_permission(s,'students.edit');
  perform app_auth.assert_student_permission(s,'students.sensitive_manage');
 elsif p_kind='document' then
  perform app_auth.assert_student_permission(s,'students.edit');
  perform app_auth.assert_student_permission(s,'student_documents.manage');
 else perform app_auth.assert_student_permission(s,'students.edit'); end if;
 o:=s.organization_id;
 if p_operation='create' and s.status<>'active' then raise exception using errcode='22023',message='active student is required'; end if;

 if p_kind='identifier' then
  if p_operation='create' then
   st:=coalesce((p_args->>'status')::public.record_status,'active');
   if st='archived' then raise exception using errcode='22023',message='initial status cannot be archived'; end if;
   insert into public.student_identifiers(id,organization_id,student_id,identifier_type,identifier_value,country_code,issued_at,expires_at,status,created_by,updated_by)
   values(rid,o,s.id,p_args->>'identifier_type',p_args->>'identifier_value',(p_args->>'country_code')::char(2),(p_args->>'issued_at')::date,(p_args->>'expires_at')::date,st,actor,actor)
   returning to_jsonb(student_identifiers.*) into newj;
  else
   select to_jsonb(x.*),x.status into oldj,st from public.student_identifiers x where id=rid for update;
   if st='archived' then raise exception using errcode='22023',message='archived identifier is terminal'; end if;
   if p_operation='archive' then
    update public.student_identifiers set status='archived',updated_by=actor where id=rid returning to_jsonb(student_identifiers.*) into newj;
   else
    perform app_auth.assert_clean_status_transition(st,(p_args->>'status')::public.record_status,
     p_args->>'identifier_type' is distinct from oldj->>'identifier_type' or p_args->>'identifier_value' is distinct from oldj->>'identifier_value'
     or (case when (p_args->>'set_country_code')::boolean then p_args->>'country_code' else oldj->>'country_code' end) is distinct from oldj->>'country_code'
     or (case when (p_args->>'set_issued_at')::boolean then p_args->>'issued_at' else oldj->>'issued_at' end) is distinct from oldj->>'issued_at'
     or (case when (p_args->>'set_expires_at')::boolean then p_args->>'expires_at' else oldj->>'expires_at' end) is distinct from oldj->>'expires_at');
    if st='inactive' and (p_args->>'status')::public.record_status<>'active' then raise exception using errcode='22023',message='inactive identifier may only be reactivated or archived'; end if;
    if (p_args->>'status')::public.record_status='active' and s.status<>'active' then raise exception using errcode='22023',message='active student is required'; end if;
    update public.student_identifiers set identifier_type=p_args->>'identifier_type',identifier_value=p_args->>'identifier_value',
     country_code=case when (p_args->>'set_country_code')::boolean then (p_args->>'country_code')::char(2) else country_code end,
     issued_at=case when (p_args->>'set_issued_at')::boolean then (p_args->>'issued_at')::date else issued_at end,
     expires_at=case when (p_args->>'set_expires_at')::boolean then (p_args->>'expires_at')::date else expires_at end,
     status=(p_args->>'status')::public.record_status,updated_by=actor where id=rid returning to_jsonb(student_identifiers.*) into newj;
   end if;
  end if;
 elsif p_kind='address' then
  if p_operation='create' then
   st:=coalesce((p_args->>'status')::public.record_status,'active'); if st='archived' then raise exception using errcode='22023',message='initial status cannot be archived'; end if;
   insert into public.student_addresses(id,organization_id,student_id,address_type,line_1,line_2,city,state_region,postal_code,country_code,is_primary,status,created_by,updated_by)
   values(rid,o,s.id,p_args->>'address_type',p_args->>'line_1',p_args->>'line_2',p_args->>'city',p_args->>'state_region',p_args->>'postal_code',(p_args->>'country_code')::char(2),(p_args->>'is_primary')::boolean,st,actor,actor)
   returning to_jsonb(student_addresses.*) into newj;
  else
   select to_jsonb(x.*),x.status into oldj,st from public.student_addresses x where id=rid for update;
   if st='archived' then raise exception using errcode='22023',message='archived address is terminal'; end if;
   if p_operation='archive' then update public.student_addresses set status='archived',updated_by=actor where id=rid returning to_jsonb(student_addresses.*) into newj;
   else
    perform app_auth.assert_clean_status_transition(st,(p_args->>'status')::public.record_status,
     p_args->>'address_type' is distinct from oldj->>'address_type' or p_args->>'line_1' is distinct from oldj->>'line_1'
     or p_args->>'city' is distinct from oldj->>'city' or p_args->>'country_code' is distinct from oldj->>'country_code'
     or (p_args->>'is_primary')::boolean is distinct from (oldj->>'is_primary')::boolean
     or (case when (p_args->>'set_line_2')::boolean then p_args->>'line_2' else oldj->>'line_2' end) is distinct from oldj->>'line_2'
     or (case when (p_args->>'set_state_region')::boolean then p_args->>'state_region' else oldj->>'state_region' end) is distinct from oldj->>'state_region'
     or (case when (p_args->>'set_postal_code')::boolean then p_args->>'postal_code' else oldj->>'postal_code' end) is distinct from oldj->>'postal_code');
    if st='inactive' and (p_args->>'status')::public.record_status<>'active' then raise exception using errcode='22023',message='inactive address may only be reactivated or archived'; end if;
    if (p_args->>'status')::public.record_status='active' and s.status<>'active' then raise exception using errcode='22023',message='active student is required'; end if;
    update public.student_addresses set address_type=p_args->>'address_type',line_1=p_args->>'line_1',
     line_2=case when (p_args->>'set_line_2')::boolean then p_args->>'line_2' else line_2 end,city=p_args->>'city',
     state_region=case when (p_args->>'set_state_region')::boolean then p_args->>'state_region' else state_region end,
     postal_code=case when (p_args->>'set_postal_code')::boolean then p_args->>'postal_code' else postal_code end,
     country_code=(p_args->>'country_code')::char(2),is_primary=(p_args->>'is_primary')::boolean,
     status=(p_args->>'status')::public.record_status,updated_by=actor where id=rid returning to_jsonb(student_addresses.*) into newj;
   end if;
  end if;
 elsif p_kind='emergency_contact' then
  if p_operation='create' then
   st:=coalesce((p_args->>'status')::public.record_status,'active'); if st='archived' then raise exception using errcode='22023',message='initial status cannot be archived'; end if;
   effective_guardian:=(p_args->>'guardian_id')::uuid;
   if effective_guardian is not null then
    perform 1 from public.guardians g join public.student_guardians sg on sg.organization_id=g.organization_id and sg.guardian_id=g.id
     where g.id=effective_guardian and g.organization_id=o and g.status='active' and sg.student_id=s.id and sg.status='active' for update of g,sg;
    if not found then raise exception using errcode='22023',message='active linked guardian is required'; end if;
   end if;
   insert into public.student_emergency_contacts(id,organization_id,student_id,guardian_id,name,relationship,phone,alternate_phone,priority,status,created_by,updated_by)
   values(rid,o,s.id,(p_args->>'guardian_id')::uuid,p_args->>'name',p_args->>'relationship',p_args->>'phone',p_args->>'alternate_phone',(p_args->>'priority')::smallint,st,actor,actor)
   returning to_jsonb(student_emergency_contacts.*) into newj;
  else
   select to_jsonb(x.*),x.status into oldj,st from public.student_emergency_contacts x where id=rid for update;
   if st='archived' then raise exception using errcode='22023',message='archived emergency contact is terminal'; end if;
   if p_operation='archive' then update public.student_emergency_contacts set status='archived',updated_by=actor where id=rid returning to_jsonb(student_emergency_contacts.*) into newj;
   else
    effective_guardian:=case when (p_args->>'set_guardian_id')::boolean then (p_args->>'guardian_id')::uuid else (oldj->>'guardian_id')::uuid end;
    perform app_auth.assert_clean_status_transition(st,(p_args->>'status')::public.record_status,
     effective_guardian is distinct from (oldj->>'guardian_id')::uuid or p_args->>'name' is distinct from oldj->>'name'
     or p_args->>'relationship' is distinct from oldj->>'relationship' or p_args->>'phone' is distinct from oldj->>'phone'
     or (case when (p_args->>'set_alternate_phone')::boolean then p_args->>'alternate_phone' else oldj->>'alternate_phone' end) is distinct from oldj->>'alternate_phone'
     or (p_args->>'priority')::smallint is distinct from (oldj->>'priority')::smallint);
    if (p_args->>'status')::public.record_status='active' and effective_guardian is not null then
     perform 1 from public.guardians g join public.student_guardians sg on sg.organization_id=g.organization_id and sg.guardian_id=g.id
      where g.id=effective_guardian and g.organization_id=o and g.status='active' and sg.student_id=s.id and sg.status='active' for update of g,sg;
     if not found then raise exception using errcode='22023',message='active linked guardian is required'; end if;
    end if;
    if st='inactive' and (p_args->>'status')::public.record_status<>'active' then raise exception using errcode='22023',message='inactive emergency contact may only be reactivated or archived'; end if;
    if (p_args->>'status')::public.record_status='active' and s.status<>'active' then raise exception using errcode='22023',message='active student is required'; end if;
    update public.student_emergency_contacts set guardian_id=effective_guardian,
     name=p_args->>'name',relationship=p_args->>'relationship',phone=p_args->>'phone',
     alternate_phone=case when (p_args->>'set_alternate_phone')::boolean then p_args->>'alternate_phone' else alternate_phone end,
     priority=(p_args->>'priority')::smallint,status=(p_args->>'status')::public.record_status,updated_by=actor where id=rid returning to_jsonb(student_emergency_contacts.*) into newj;
   end if;
  end if;
 elsif p_kind='document' then
  select to_jsonb(x.*),x.status into oldj,st from public.student_documents x where id=rid for update;
  if not found then raise exception using errcode='P0002',message='document not found'; end if;
  if st='archived' then raise exception using errcode='22023',message='archived document is terminal'; end if;
  if p_operation='archive' then update public.student_documents set status='archived',updated_by=actor where id=rid returning to_jsonb(student_documents.*) into newj;
  else
   perform app_auth.assert_clean_status_transition(st,(p_args->>'status')::public.record_status,
    p_args->>'document_type' is distinct from oldj->>'document_type' or p_args->>'title' is distinct from oldj->>'title'
    or p_args->>'visibility' is distinct from oldj->>'visibility'
    or (case when (p_args->>'set_mime_type')::boolean then p_args->>'mime_type' else oldj->>'mime_type' end) is distinct from oldj->>'mime_type'
    or (case when (p_args->>'set_file_size')::boolean then p_args->>'file_size' else oldj->>'file_size' end) is distinct from oldj->>'file_size'
    or (case when (p_args->>'set_issued_at')::boolean then p_args->>'issued_at' else oldj->>'issued_at' end) is distinct from oldj->>'issued_at'
    or (case when (p_args->>'set_expires_at')::boolean then p_args->>'expires_at' else oldj->>'expires_at' end) is distinct from oldj->>'expires_at');
   if st='inactive' and (p_args->>'status')::public.record_status<>'active' then raise exception using errcode='22023',message='inactive document may only be reactivated or archived'; end if;
   if (p_args->>'status')::public.record_status='active' and s.status<>'active' then raise exception using errcode='22023',message='active student is required'; end if;
   update public.student_documents set document_type=p_args->>'document_type',title=p_args->>'title',
    mime_type=case when (p_args->>'set_mime_type')::boolean then p_args->>'mime_type' else mime_type end,
    file_size=case when (p_args->>'set_file_size')::boolean then (p_args->>'file_size')::bigint else file_size end,
    issued_at=case when (p_args->>'set_issued_at')::boolean then (p_args->>'issued_at')::date else issued_at end,
    expires_at=case when (p_args->>'set_expires_at')::boolean then (p_args->>'expires_at')::date else expires_at end,
    visibility=(p_args->>'visibility')::public.student_document_visibility,status=(p_args->>'status')::public.record_status,updated_by=actor
    where id=rid returning to_jsonb(student_documents.*) into newj;
  end if;
 end if;
 action:='student.'||case p_kind when 'identifier' then 'identifier_' when 'address' then 'address_' when 'emergency_contact' then 'emergency_contact_' else 'document_' end||
  case p_operation when 'create' then 'added' when 'update' then 'updated' else 'archived' end;
 if p_operation='archive' then newj:=newj||jsonb_build_object('_archive_reason',btrim(p_args->>'archive_reason')); end if;
 payload:=jsonb_strip_nulls(jsonb_build_object('student_id',s.id,'school_id',s.school_id,'campus_id',s.campus_id,
  'before_status',oldj->>'status','after_status',newj->>'status','reason',case when p_operation='archive' then btrim(p_args->>'archive_reason') end));
 perform app_auth.write_sis_change(cmd,o,actor,action,'student_'||p_kind,rid,oldj,newj,payload);
 return rid;
end $$;

commit;
