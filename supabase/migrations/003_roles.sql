-- Adds the roles lookup table and users view.
-- Safe to run after schema.sql / 002_clients.sql.
-- Prefer re-running the full supabase/schema.sql if you can.

create table if not exists public.roles (
  code text primary key,
  name text not null,
  description text,
  sort_order int not null default 0
);

insert into public.roles (code, name, description, sort_order)
values
  ('admin',  'Admin',  'Platform owner. Can view and manage every client, user, company, job, leave request, and map pin.', 1),
  ('client', 'Client', 'Tenant under admin. Can view and manage only field users assigned to this client, and only this client''s companies and jobs.', 2),
  ('user',   'User',   'Field staff allocated to one client. Can see only their own jobs, attendance, and leave.', 3)
on conflict (code) do update
  set name = excluded.name,
      description = excluded.description,
      sort_order = excluded.sort_order;

alter table public.profiles drop constraint if exists profiles_role_check;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'profiles_role_fkey' and conrelid = 'public.profiles'::regclass
  ) then
    alter table public.profiles
      add constraint profiles_role_fkey
      foreign key (role) references public.roles(code);
  end if;
end $$;

create or replace view public.users
with (security_invoker = true) as
select
  p.id,
  p.email,
  p.name,
  p.mobile,
  p.role,
  r.name as role_name,
  r.description as role_description,
  p.client_id,
  parent.name as client_name,
  parent.email as client_email,
  p.is_active,
  p.standby_status,
  p.created_at
from public.profiles p
left join public.roles r on r.code = p.role
left join public.profiles parent on parent.id = p.client_id;

alter table public.roles enable row level security;
drop policy if exists roles_select on public.roles;
create policy roles_select on public.roles
  for select to authenticated
  using (true);

grant select on public.users to authenticated, service_role, postgres;
grant select on public.roles to authenticated, service_role, postgres;
