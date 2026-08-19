begin;

revoke insert, update on public.students from authenticated;
revoke insert, update on public.guardians from authenticated;
revoke insert, update on public.student_guardians from authenticated;
revoke insert, update on public.student_identifiers from authenticated;
revoke insert, update on public.student_addresses from authenticated;
revoke insert, update on public.student_emergency_contacts from authenticated;
revoke insert, update on public.student_documents from authenticated;

drop policy students_update on public.students;
create policy students_update on public.students for update to authenticated
  using (
    status <> 'archived'
    and app_auth.has_permission(organization_id, 'students.edit', school_id, campus_id)
  )
  with check (
    status <> 'archived'
    and app_auth.has_permission(organization_id, 'students.edit', school_id, campus_id)
  );

create or replace function app_auth.can_view_student_sensitive(
  target_organization_id uuid,
  target_student_id uuid
)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1
    from public.students s
    where s.organization_id = target_organization_id
      and s.id = target_student_id
      and (
        s.user_id = auth.uid()
        or app_auth.is_linked_guardian(s.id)
        or (
          app_auth.can_staff_view_student(s.organization_id, s.id)
          and app_auth.has_permission(
            s.organization_id,
            'students.sensitive_view',
            s.school_id,
            s.campus_id
          )
        )
      )
  );
$$;

create index students_org_campus_idx
  on public.students(organization_id, campus_id);
create index students_school_campus_idx
  on public.students(school_id, campus_id);

comment on index public.students_org_campus_idx is
  'Supports the students organization/campus composite foreign key and tenant-campus lookups.';
comment on index public.students_school_campus_idx is
  'Supports the students school/campus composite foreign key and school-campus lookups.';

create or replace function app_auth.archive_student(
  target_student_id uuid,
  archive_reason text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  student_before public.students%rowtype;
  student_after public.students%rowtype;
  actor_id uuid := auth.uid();
  normalized_reason text := pg_catalog.btrim(archive_reason);
begin
  if actor_id is null then
    raise exception using
      errcode = '42501',
      message = 'an authenticated actor is required';
  end if;

  if normalized_reason is null or normalized_reason = '' then
    raise exception using
      errcode = '22023',
      message = 'archive reason must not be empty';
  end if;

  select s.*
  into student_before
  from public.students s
  where s.id = target_student_id
  for update;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'student not found';
  end if;

  if student_before.status = 'archived' then
    raise exception using
      errcode = '22023',
      message = 'student is already archived';
  end if;

  if not app_auth.has_permission(
    student_before.organization_id,
    'students.archive',
    student_before.school_id,
    student_before.campus_id
  ) then
    raise exception using
      errcode = '42501',
      message = 'students.archive permission is required';
  end if;

  update public.students
  set status = 'archived',
      updated_by = actor_id,
      updated_at = pg_catalog.now()
  where id = student_before.id
  returning * into student_after;

  insert into public.audit_log (
    organization_id,
    actor_user_id,
    action,
    entity_type,
    entity_id,
    before_data,
    after_data
  ) values (
    student_after.organization_id,
    actor_id,
    'student.archived',
    'student',
    student_after.id,
    pg_catalog.to_jsonb(student_before),
    pg_catalog.to_jsonb(student_after)
      || pg_catalog.jsonb_build_object('reason', normalized_reason)
  );

  insert into public.event_outbox (
    organization_id,
    event_type,
    aggregate_type,
    aggregate_id,
    payload
  ) values (
    student_after.organization_id,
    'student.archived',
    'student',
    student_after.id,
    pg_catalog.jsonb_build_object(
      'student_id', student_after.id,
      'actor_user_id', actor_id,
      'reason', normalized_reason
    )
  );

  return student_after.id;
end;
$$;

revoke all on function app_auth.archive_student(uuid, text) from public, anon;
grant execute on function app_auth.archive_student(uuid, text) to authenticated, service_role;

create or replace function public.archive_student(
  target_student_id uuid,
  archive_reason text
)
returns uuid
language sql
security invoker
set search_path = ''
as $$
  select app_auth.archive_student(target_student_id, archive_reason);
$$;

revoke all on function public.archive_student(uuid, text) from public, anon;
grant execute on function public.archive_student(uuid, text) to authenticated, service_role;

commit;
