insert into public.organizations(id,name,slug,status) values
('a1000000-0000-0000-0000-000000000001','E2E Schools','e2e-schools','active')
on conflict(id) do update set name=excluded.name,slug=excluded.slug,status=excluded.status;
insert into public.schools(id,organization_id,name,code,status) values
('a2000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001','E2E School','E2E','active')
on conflict(id) do update set name=excluded.name,code=excluded.code,status=excluded.status;
insert into public.campuses(id,organization_id,school_id,name,code,status) values
('a3000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001','a2000000-0000-0000-0000-000000000001','North Campus','N','active'),
('a3000000-0000-0000-0000-000000000002','a1000000-0000-0000-0000-000000000001','a2000000-0000-0000-0000-000000000001','South Campus','S','active')
on conflict(id) do update set name=excluded.name,code=excluded.code,status=excluded.status;
insert into public.organization_memberships(id,organization_id,user_id,status,joined_at) values
('a5000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001','a4000000-0000-0000-0000-000000000001','active',now()),
('a5000000-0000-0000-0000-000000000002','a1000000-0000-0000-0000-000000000001','a4000000-0000-0000-0000-000000000002','active',now())
on conflict(id) do update set status=excluded.status;
insert into public.roles(id,organization_id,code,name,status) values
('a6000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001','E2E_ADMIN','E2E administrator','active')
on conflict(id) do update set status=excluded.status;
insert into public.role_permissions(organization_id,role_id,permission_id)
select 'a1000000-0000-0000-0000-000000000001','a6000000-0000-0000-0000-000000000001',id
from public.permissions where code in ('students.view','students.create','students.edit','students.archive','student_documents.manage')
on conflict do nothing;
insert into public.role_assignments(id,organization_id,organization_membership_id,role_id,school_id,campus_id,status) values
('a7000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001','a5000000-0000-0000-0000-000000000001','a6000000-0000-0000-0000-000000000001','a2000000-0000-0000-0000-000000000001','a3000000-0000-0000-0000-000000000001','active'),
('a7000000-0000-0000-0000-000000000002','a1000000-0000-0000-0000-000000000001','a5000000-0000-0000-0000-000000000001','a6000000-0000-0000-0000-000000000001','a2000000-0000-0000-0000-000000000001','a3000000-0000-0000-0000-000000000002','active')
on conflict(id) do update set status=excluded.status;
insert into public.students(id,organization_id,school_id,campus_id,student_number,first_name,last_name,date_of_birth,status)
select ('b0000000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid,'a1000000-0000-0000-0000-000000000001','a2000000-0000-0000-0000-000000000001','a3000000-0000-0000-0000-000000000001','E2E-'||lpad(n::text,3,'0'),case when n=1 then 'Private' else 'Student' end,lpad(n::text,2,'0'),'2014-01-01','active'
from generate_series(1,30) n
on conflict(id) do update set first_name=excluded.first_name,last_name=excluded.last_name,status=excluded.status;
insert into public.guardians(id,organization_id,first_name,last_name,email,status) values
('b1000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001','Secret','Guardian','must-not-render@e2e.local','active')
on conflict(id) do update set email=excluded.email,status=excluded.status;
insert into public.student_guardians(id,organization_id,student_id,guardian_id,relationship_type,is_primary,status) values
('b2000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001','b0000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001','parent',true,'active')
on conflict(id) do update set status=excluded.status;
insert into public.student_documents(id,organization_id,student_id,document_type,title,storage_path,visibility,status) values
('b3000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001','b0000000-0000-0000-0000-000000000001','consent','Consent form','never/render/secret.pdf','staff','active')
on conflict(id) do update set storage_path=excluded.storage_path,status=excluded.status;
