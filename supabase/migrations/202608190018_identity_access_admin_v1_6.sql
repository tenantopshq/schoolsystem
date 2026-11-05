begin;

create function app_auth.write_identity_change(cmd uuid,o uuid,a uuid,event text,kind text,target uuid,before_row jsonb,after_row jsonb,payload jsonb)
returns void language plpgsql security definer set search_path='' as $$ begin
 insert into public.audit_log(command_id,organization_id,actor_user_id,action,entity_type,entity_id,before_data,after_data)
 values(cmd,o,a,event,kind,target,before_row,after_row);
 insert into public.event_outbox(command_id,organization_id,event_type,aggregate_type,aggregate_id,payload)
 values(cmd,o,event,kind,target,coalesce(payload,'{}')||jsonb_build_object('command_id',cmd,'actor_user_id',a,'organization_id',o,'aggregate_id',target));
end $$;

create function app_auth.is_last_org_admin(o uuid,membership uuid,assignment uuid default null)
returns boolean language sql stable security definer set search_path='' as $$
 select not exists(
  select 1 from public.organization_memberships m
  join public.role_assignments ra on (ra.organization_id,ra.organization_membership_id)=(m.organization_id,m.id)
  join public.roles r on (r.organization_id,r.id)=(ra.organization_id,ra.role_id)
  join public.role_permissions rp on (rp.organization_id,rp.role_id)=(r.organization_id,r.id)
  join public.permissions p on p.id=rp.permission_id
  where m.organization_id=o and m.id<>membership and m.status='active' and m.left_at is null
   and r.status='active' and ra.status='active' and ra.school_id is null and ra.campus_id is null
   and ra.starts_at<=now() and (ra.ends_at is null or ra.ends_at>now()) and p.code='organizations.manage'
   and (assignment is null or ra.id<>assignment)
 );
$$;

create function public.search_access_members(p_organization_id uuid,p_query text default null,p_status public.membership_status default null,p_limit integer default 100)
returns table(membership_id uuid,first_name text,middle_name text,last_name text,display_name text,email text,membership_status public.membership_status,staff_profile_id uuid,staff_number text,assignment_count bigint)
language plpgsql stable security definer set search_path='' as $$ declare q text:=nullif(btrim(p_query),''); begin
 if auth.uid() is null or not (app_auth.has_permission(p_organization_id,'memberships.view') or app_auth.has_permission(p_organization_id,'memberships.manage')) then raise exception using errcode='42501',message='membership view permission is required'; end if;
 if length(coalesce(q,''))>100 then raise exception using errcode='22023',message='query is too long'; end if;
 return query select m.id,pr.first_name,pr.middle_name,pr.last_name,pr.display_name,u.email::text,m.status,sp.id,sp.staff_number,
  (select count(*) from public.role_assignments ra where ra.organization_membership_id=m.id and ra.status='active' and ra.starts_at<=now() and(ra.ends_at is null or ra.ends_at>now()))
 from public.organization_memberships m join auth.users u on u.id=m.user_id join public.profiles pr on pr.user_id=m.user_id
 left join public.staff_profiles sp on sp.organization_membership_id=m.id and sp.organization_id=m.organization_id
 where m.organization_id=p_organization_id and(p_status is null or m.status=p_status)
  and(q is null or lower(coalesce(pr.display_name,'')||' '||coalesce(pr.first_name,'')||' '||coalesce(pr.last_name,'')||' '||coalesce(u.email,'')) like '%'||lower(replace(replace(replace(q,'\','\\'),'%','\%'),'_','\_'))||'%' escape '\')
 order by lower(coalesce(pr.display_name,pr.last_name,u.email,'')),m.id limit greatest(1,least(coalesce(p_limit,100),100));
end $$;

create function public.get_access_member(p_membership_id uuid)
returns table(membership_id uuid,organization_id uuid,first_name text,middle_name text,last_name text,display_name text,email text,membership_status public.membership_status,joined_at timestamptz,left_at timestamptz,staff_profile_id uuid,staff_number text)
language sql stable security definer set search_path='' as $$
 select m.id,m.organization_id,pr.first_name,pr.middle_name,pr.last_name,pr.display_name,u.email::text,m.status,m.joined_at,m.left_at,sp.id,sp.staff_number
 from public.organization_memberships m join auth.users u on u.id=m.user_id join public.profiles pr on pr.user_id=m.user_id
 left join public.staff_profiles sp on sp.organization_membership_id=m.id and sp.organization_id=m.organization_id
 where m.id=p_membership_id and(app_auth.has_permission(m.organization_id,'memberships.view')or app_auth.has_permission(m.organization_id,'memberships.manage'));
$$;

create function public.list_access_roles(p_organization_id uuid)
returns table(role_id uuid,code text,name text,description text,permission_codes text[])
language sql stable security definer set search_path='' as $$
 select r.id,r.code,r.name,r.description,coalesce(array_agg(p.code order by p.code)filter(where p.code is not null),'{}')
 from public.roles r left join public.role_permissions rp on(rp.organization_id,rp.role_id)=(r.organization_id,r.id) left join public.permissions p on p.id=rp.permission_id
 where r.organization_id=p_organization_id and r.status='active' and(app_auth.has_permission(r.organization_id,'roles.view')or app_auth.has_permission(r.organization_id,'roles.manage'))
 group by r.id order by r.name,r.id;
$$;

create function public.list_access_assignments(p_membership_id uuid)
returns table(assignment_id uuid,role_id uuid,role_code text,role_name text,school_id uuid,school_name text,campus_id uuid,campus_name text,starts_at timestamptz,ends_at timestamptz,status public.role_assignment_status,permission_codes text[])
language sql stable security definer set search_path='' as $$
 select ra.id,r.id,r.code,r.name,ra.school_id,s.name,ra.campus_id,c.name,ra.starts_at,ra.ends_at,ra.status,
  coalesce(array_agg(p.code order by p.code)filter(where p.code is not null),'{}')
 from public.role_assignments ra join public.roles r on(r.organization_id,r.id)=(ra.organization_id,ra.role_id)
 left join public.schools s on s.id=ra.school_id left join public.campuses c on c.id=ra.campus_id
 left join public.role_permissions rp on(rp.organization_id,rp.role_id)=(r.organization_id,r.id) left join public.permissions p on p.id=rp.permission_id
 where ra.organization_membership_id=p_membership_id and(app_auth.has_permission(ra.organization_id,'roles.view')or app_auth.has_permission(ra.organization_id,'roles.manage'))
 group by ra.id,r.id,s.name,c.name order by ra.status,ra.starts_at desc,ra.id;
$$;

create function public.transition_access_membership_v1_6(request_id uuid,target_membership_id uuid,new_status public.membership_status,reason text)
returns uuid language plpgsql security definer set search_path='' as $$ declare a uuid:=auth.uid();m public.organization_memberships;oldj jsonb;h bytea;q record;cmd uuid:=gen_random_uuid();why text:=btrim(reason); begin
 if a is null or length(why)not between 1 and 500 then raise exception using errcode='22023',message='valid actor and reason are required';end if;
 select*into m from public.organization_memberships where id=target_membership_id for update;
 if not found or not app_auth.has_permission(m.organization_id,'memberships.manage') then raise exception using errcode='42501',message='membership manage permission is required';end if;
 if m.status='left' or new_status not in('active','suspended','left') or m.status=new_status then raise exception using errcode='22023',message='invalid membership transition';end if;
 if m.status='invited' and new_status<>'active' then raise exception using errcode='22023',message='invited membership may only be activated';end if;
 if m.status='active' and new_status in('suspended','left') and app_auth.is_last_org_admin(m.organization_id,m.id) then raise exception using errcode='22023',message='last organization administrator cannot be removed';end if;
 h:=extensions.digest(convert_to(jsonb_build_array(target_membership_id,new_status,why)::text,'UTF8'),'sha256');select*into q from app_auth.claim_sis_receipt(m.organization_id,a,'transition_access_membership_v1_6',request_id,h);if q.replayed then return q.result_id;end if;
 oldj:=to_jsonb(m);update public.organization_memberships set status=new_status,joined_at=case when new_status='active'then coalesce(joined_at,now())else joined_at end,left_at=case when new_status='left'then now()else null end,updated_by=a where id=m.id returning*into m;
 if new_status='left'then update public.role_assignments set status='inactive',ends_at=coalesce(ends_at,now()),updated_by=a where organization_membership_id=m.id and status='active';end if;
 perform app_auth.write_identity_change(cmd,m.organization_id,a,'membership.'||new_status::text,'organization_membership',m.id,oldj,to_jsonb(m),jsonb_build_object('reason',why));perform app_auth.complete_sis_receipt(m.organization_id,a,'transition_access_membership_v1_6',request_id,m.id);return m.id;end $$;

create function public.assign_access_role_v1_6(request_id uuid,target_membership_id uuid,target_role_id uuid,target_school_id uuid,target_campus_id uuid,starts_at timestamptz,ends_at timestamptz)
returns uuid language plpgsql security definer set search_path='' as $$ declare a uuid:=auth.uid();m public.organization_memberships;r public.roles;rid uuid;h bytea;q record;cmd uuid:=gen_random_uuid();begin
 select*into m from public.organization_memberships where id=target_membership_id and status='active' for update;select*into r from public.roles where id=target_role_id and status='active' for update;
 if a is null or m.id is null or r.id is null or m.organization_id<>r.organization_id or not app_auth.has_permission(m.organization_id,'roles.manage',target_school_id,target_campus_id)then raise exception using errcode='42501',message='role assignment permission is required';end if;
 if target_campus_id is not null and not exists(select 1 from public.campuses c where c.id=target_campus_id and c.organization_id=m.organization_id and c.school_id=target_school_id and c.status='active')or target_school_id is not null and not exists(select 1 from public.schools s where s.id=target_school_id and s.organization_id=m.organization_id and s.status='active')then raise exception using errcode='22023',message='active compatible scope is required';end if;
 if ends_at is not null and ends_at<=starts_at then raise exception using errcode='22023',message='assignment end must follow start';end if;
 if exists(select 1 from public.role_permissions rp join public.permissions p on p.id=rp.permission_id where rp.role_id=r.id and not app_auth.has_permission(m.organization_id,p.code,target_school_id,target_campus_id))then raise exception using errcode='42501',message='cannot grant permissions the actor does not hold';end if;
 h:=extensions.digest(convert_to(jsonb_build_array(target_membership_id,target_role_id,target_school_id,target_campus_id,starts_at,ends_at)::text,'UTF8'),'sha256');select*into q from app_auth.claim_sis_receipt(m.organization_id,a,'assign_access_role_v1_6',request_id,h);if q.replayed then return q.result_id;end if;
 perform pg_advisory_xact_lock(hashtextextended(concat_ws(':',m.organization_id,m.id,r.id,coalesce(target_school_id::text,''),coalesce(target_campus_id::text,'')),0));
 if exists(select 1 from public.role_assignments x where x.organization_membership_id=m.id and x.role_id=r.id and x.school_id is not distinct from target_school_id and x.campus_id is not distinct from target_campus_id and x.status='active' and tstzrange(x.starts_at,x.ends_at,'[)')&&tstzrange(assign_access_role_v1_6.starts_at,assign_access_role_v1_6.ends_at,'[)'))then raise exception using errcode='23505',message='overlapping role assignment already exists';end if;
 insert into public.role_assignments(organization_id,organization_membership_id,role_id,school_id,campus_id,starts_at,ends_at,created_by,updated_by)values(m.organization_id,m.id,r.id,target_school_id,target_campus_id,starts_at,ends_at,a,a)returning id into rid;
 perform app_auth.write_identity_change(cmd,m.organization_id,a,'role_assignment.created','role_assignment',rid,null,(select to_jsonb(x)from public.role_assignments x where x.id=rid),jsonb_build_object('membership_id',m.id,'role_id',r.id));perform app_auth.complete_sis_receipt(m.organization_id,a,'assign_access_role_v1_6',request_id,rid);return rid;end $$;

create function public.end_access_role_assignment_v1_6(request_id uuid,target_assignment_id uuid,reason text)
returns uuid language plpgsql security definer set search_path='' as $$ declare a uuid:=auth.uid();ra public.role_assignments;oldj jsonb;why text:=btrim(reason);h bytea;q record;cmd uuid:=gen_random_uuid();begin
 select*into ra from public.role_assignments where id=target_assignment_id for update;
 if a is null or ra.id is null or not app_auth.has_permission(ra.organization_id,'roles.manage',ra.school_id,ra.campus_id)then raise exception using errcode='42501',message='role assignment permission is required';end if;
 if ra.status<>'active'or length(why)not between 1 and 500 then raise exception using errcode='22023',message='active assignment and reason are required';end if;
 if ra.school_id is null and exists(select 1 from public.role_permissions rp join public.permissions p on p.id=rp.permission_id where rp.role_id=ra.role_id and p.code='organizations.manage')and app_auth.is_last_org_admin(ra.organization_id,ra.organization_membership_id,ra.id)then raise exception using errcode='22023',message='last organization administrator cannot be removed';end if;
 h:=extensions.digest(convert_to(jsonb_build_array(target_assignment_id,why)::text,'UTF8'),'sha256');select*into q from app_auth.claim_sis_receipt(ra.organization_id,a,'end_access_role_assignment_v1_6',request_id,h);if q.replayed then return q.result_id;end if;
 oldj:=to_jsonb(ra);update public.role_assignments set status='inactive',ends_at=coalesce(ends_at,now()),updated_by=a where id=ra.id returning*into ra;
 perform app_auth.write_identity_change(cmd,ra.organization_id,a,'role_assignment.ended','role_assignment',ra.id,oldj,to_jsonb(ra),jsonb_build_object('reason',why));perform app_auth.complete_sis_receipt(ra.organization_id,a,'end_access_role_assignment_v1_6',request_id,ra.id);return ra.id;end $$;

revoke insert,update,delete,truncate on public.organization_memberships,public.roles,public.role_permissions,public.role_assignments from authenticated;
do $$declare x record;begin for x in select p.oid::regprocedure sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'and p.proname in('search_access_members','get_access_member','list_access_roles','list_access_assignments','transition_access_membership_v1_6','assign_access_role_v1_6','end_access_role_assignment_v1_6')loop execute format('alter function %s owner to postgres',x.sig);execute format('revoke all on function %s from public,anon,authenticated,service_role',x.sig);execute format('grant execute on function %s to authenticated',x.sig);end loop;end$$;
alter function app_auth.write_identity_change(uuid,uuid,uuid,text,text,uuid,jsonb,jsonb,jsonb)owner to postgres;alter function app_auth.is_last_org_admin(uuid,uuid,uuid)owner to postgres;
revoke all on function app_auth.write_identity_change(uuid,uuid,uuid,text,text,uuid,jsonb,jsonb,jsonb),app_auth.is_last_org_admin(uuid,uuid,uuid)from public,anon,authenticated,service_role;
commit;
