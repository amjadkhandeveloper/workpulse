-- Work Pulse schema
-- Paste this WHOLE file into Supabase: SQL Editor -> New query -> Run.
-- Safe to run more than once.
--
-- After it succeeds:
-- 1. Authentication -> Providers -> Email: enable Email, turn OFF "Confirm email"
--    so users can log in immediately with the password created for them.
-- 2. Authentication -> Users -> Add user: create the platform admin
--    (email + password, Auto Confirm User = ON).
-- 3. Run:  select public.promote_admin('admin@email.com');
-- 4. Deploy supabase/functions/admin-users so the app can add clients and field users.
--
-- No Google / Apple login. Users do not self-register.
-- Platform admin creates clients. Clients (or admin) create field users. Field users only log in.

-- gen_random_uuid() is already available on Supabase.
do $$
begin
  create extension if not exists pgcrypto with schema extensions;
exception
  when others then
    raise notice 'pgcrypto extension: %', sqlerrm;
end $$;

-- ---------------------------------------------------------------------------
-- Helpers (JWT role, no RLS recursion on profiles)
-- ---------------------------------------------------------------------------
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '') = 'admin';
$$;

revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to authenticated, service_role;

create or replace function public.is_client()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '') = 'client';
$$;

create or replace function public.is_manager()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '') in ('admin', 'client');
$$;

create or replace function public.owns_field_user(target uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_admin()
    or (
      public.is_client()
      and exists (
        select 1 from public.profiles p
        where p.id = target and p.client_id = auth.uid()
      )
    );
$$;

revoke all on function public.is_client() from public;
revoke all on function public.is_manager() from public;
revoke all on function public.owns_field_user(uuid) from public;
grant execute on function public.is_client() to authenticated, service_role;
grant execute on function public.is_manager() to authenticated, service_role;
grant execute on function public.owns_field_user(uuid) to authenticated, service_role;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_client uuid;
begin
  if (new.raw_app_meta_data->>'client_id') ~* '^[0-9a-f-]{36}$' then
    v_client := (new.raw_app_meta_data->>'client_id')::uuid;
  end if;

  insert into public.profiles (id, email, name, mobile, role, client_id)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'name', ''),
    new.raw_user_meta_data->>'mobile',
    coalesce(new.raw_app_meta_data->>'role', 'user'),
    v_client
  )
  on conflict (id) do update
    set email = excluded.email,
        name = coalesce(nullif(excluded.name, ''), public.profiles.name),
        mobile = coalesce(excluded.mobile, public.profiles.mobile),
        role = excluded.role,
        client_id = coalesce(excluded.client_id, public.profiles.client_id);

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

create or replace function public.sync_role_to_jwt()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update auth.users
  set raw_app_meta_data =
        coalesce(raw_app_meta_data, '{}'::jsonb)
        || jsonb_build_object('role', new.role)
  where id = new.id;
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  name text not null default '',
  mobile text,
  photo_url text,
  role text not null default 'user' check (role in ('admin', 'client', 'user')),
  client_id uuid references public.profiles(id) on delete set null,
  is_active boolean not null default true,
  standby_status text not null default 'out' check (standby_status in ('out', 'in')),
  last_lat double precision,
  last_lng double precision,
  last_location_at timestamptz,
  created_at timestamptz not null default now()
);

drop trigger if exists on_profile_role_changed on public.profiles;
create trigger on_profile_role_changed
  after update of role on public.profiles
  for each row
  when (old.role is distinct from new.role)
  execute procedure public.sync_role_to_jwt();

create table if not exists public.companies (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  location text,
  work text,
  contact_name text,
  mobile text,
  lat double precision,
  lng double precision,
  client_id uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.jobs (
  id uuid primary key default gen_random_uuid(),
  job_number bigint generated always as identity,
  job_type text not null default '',
  job_category text not null default '',
  purpose text not null default '',
  company_id uuid references public.companies(id) on delete set null,
  assigned_to uuid references public.profiles(id) on delete set null,
  customer_name text,
  customer_mobile text,
  location text,
  lat double precision,
  lng double precision,
  start_at timestamptz not null,
  end_at timestamptz not null,
  status text not null default 'pending' check (status in (
    'pending', 'accepted', 'declined', 'checked_in', 'pending_review', 'completed', 'cancelled'
  )),
  assigned_by uuid references public.profiles(id) on delete set null,
  reviewed_by uuid references public.profiles(id) on delete set null,
  reviewed_at timestamptz,
  checkout_note text,
  client_id uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

create unique index if not exists jobs_one_active_per_user
  on public.jobs (assigned_to)
  where status in ('accepted', 'checked_in') and assigned_to is not null;

create index if not exists jobs_assigned_to_idx on public.jobs (assigned_to);
create index if not exists jobs_status_idx on public.jobs (status);
create index if not exists profiles_client_id_idx on public.profiles (client_id);
create index if not exists profiles_role_idx on public.profiles (role);
create index if not exists companies_client_id_idx on public.companies (client_id);
create index if not exists jobs_client_id_idx on public.jobs (client_id);

-- If this file is re-run on a project created before the client role:
alter table public.profiles drop constraint if exists profiles_role_check;
alter table public.profiles
  add constraint profiles_role_check check (role in ('admin', 'client', 'user'));
alter table public.profiles
  add column if not exists client_id uuid references public.profiles(id) on delete set null;
alter table public.companies
  add column if not exists client_id uuid references public.profiles(id) on delete set null;
alter table public.jobs
  add column if not exists client_id uuid references public.profiles(id) on delete set null;

create table if not exists public.job_proofs (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.jobs(id) on delete cascade,
  kind text not null check (kind in ('photo', 'signature')),
  storage_path text not null,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.attendance (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  type text not null check (type in ('standby_in', 'standby_out')),
  at timestamptz not null default now(),
  lat double precision,
  lng double precision
);

create index if not exists attendance_user_at_idx on public.attendance (user_id, at desc);

create table if not exists public.leaves (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  start_date date not null,
  end_date date not null,
  day_type text not null default 'full' check (day_type in ('full', 'first_half', 'second_half')),
  reason text,
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  admin_note text,
  created_at timestamptz not null default now(),
  check (end_date >= start_date),
  check ((end_date - start_date) <= 29)
);

create table if not exists public.location_pings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  lat double precision not null,
  lng double precision not null,
  accuracy double precision,
  recorded_at timestamptz not null default now(),
  context text not null default 'standby' check (context in ('standby', 'job')),
  job_id uuid references public.jobs(id) on delete set null
);

create index if not exists location_pings_user_idx on public.location_pings (user_id, recorded_at desc);

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------
alter table public.profiles enable row level security;
alter table public.companies enable row level security;
alter table public.jobs enable row level security;
alter table public.job_proofs enable row level security;
alter table public.attendance enable row level security;
alter table public.leaves enable row level security;
alter table public.location_pings enable row level security;

drop policy if exists profiles_select on public.profiles;
drop policy if exists profiles_select_own on public.profiles;
drop policy if exists profiles_select_admin on public.profiles;
drop policy if exists profiles_select_client_users on public.profiles;
drop policy if exists profiles_update_self on public.profiles;
drop policy if exists companies_admin_all on public.companies;
drop policy if exists companies_manager_all on public.companies;
drop policy if exists companies_read_assigned on public.companies;
drop policy if exists jobs_admin_all on public.jobs;
drop policy if exists jobs_manager_all on public.jobs;
drop policy if exists jobs_user_select on public.jobs;
drop policy if exists jobs_user_update on public.jobs;
drop policy if exists proofs_select on public.job_proofs;
drop policy if exists proofs_insert on public.job_proofs;
drop policy if exists attendance_select on public.attendance;
drop policy if exists attendance_insert on public.attendance;
drop policy if exists leaves_select on public.leaves;
drop policy if exists leaves_insert on public.leaves;
drop policy if exists leaves_update_admin on public.leaves;
drop policy if exists pings_insert on public.location_pings;
drop policy if exists pings_select on public.location_pings;

create policy profiles_select_own on public.profiles
  for select to authenticated
  using (id = auth.uid());

create policy profiles_select_admin on public.profiles
  for select to authenticated
  using (public.is_admin());

create policy profiles_select_client_users on public.profiles
  for select to authenticated
  using (public.is_client() and client_id = auth.uid());

create policy profiles_update_self on public.profiles
  for update to authenticated
  using (id = auth.uid() or public.is_admin() or public.owns_field_user(id))
  with check (id = auth.uid() or public.is_admin() or public.owns_field_user(id));

create policy companies_manager_all on public.companies
  for all to authenticated
  using (public.is_admin() or (public.is_client() and client_id = auth.uid()))
  with check (public.is_admin() or (public.is_client() and client_id = auth.uid()));

create policy companies_read_assigned on public.companies
  for select to authenticated
  using (
    exists (
      select 1 from public.jobs
      where jobs.company_id = companies.id and jobs.assigned_to = auth.uid()
    )
  );

create policy jobs_manager_all on public.jobs
  for all to authenticated
  using (public.is_admin() or (public.is_client() and client_id = auth.uid()))
  with check (public.is_admin() or (public.is_client() and client_id = auth.uid()));

create policy jobs_user_select on public.jobs
  for select to authenticated
  using (assigned_to = auth.uid());

create policy jobs_user_update on public.jobs
  for update to authenticated
  using (assigned_to = auth.uid())
  with check (assigned_to = auth.uid());

create policy proofs_select on public.job_proofs
  for select to authenticated
  using (
    public.is_admin()
    or exists (
      select 1 from public.jobs
      where jobs.id = job_proofs.job_id
        and (
          jobs.assigned_to = auth.uid()
          or (public.is_client() and jobs.client_id = auth.uid())
        )
    )
  );

create policy proofs_insert on public.job_proofs
  for insert to authenticated
  with check (
    public.is_admin()
    or exists (
      select 1 from public.jobs
      where jobs.id = job_proofs.job_id
        and (
          jobs.assigned_to = auth.uid()
          or (public.is_client() and jobs.client_id = auth.uid())
        )
    )
  );

create policy attendance_select on public.attendance
  for select to authenticated
  using (user_id = auth.uid() or public.is_admin() or public.owns_field_user(user_id));

create policy attendance_insert on public.attendance
  for insert to authenticated
  with check (user_id = auth.uid() or public.is_admin() or public.owns_field_user(user_id));

create policy leaves_select on public.leaves
  for select to authenticated
  using (user_id = auth.uid() or public.is_admin() or public.owns_field_user(user_id));

create policy leaves_insert on public.leaves
  for insert to authenticated
  with check (user_id = auth.uid());

create policy leaves_update_admin on public.leaves
  for update to authenticated
  using (public.is_admin() or public.owns_field_user(user_id))
  with check (public.is_admin() or public.owns_field_user(user_id));

create policy pings_insert on public.location_pings
  for insert to authenticated
  with check (user_id = auth.uid());

create policy pings_select on public.location_pings
  for select to authenticated
  using (user_id = auth.uid() or public.is_admin() or public.owns_field_user(user_id));

grant usage on schema public to anon, authenticated, service_role;
grant all on all tables in schema public to postgres, service_role;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant usage, select on all sequences in schema public to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Storage
-- ---------------------------------------------------------------------------
do $$
begin
  insert into storage.buckets (id, name, public)
  values ('avatars', 'avatars', true)
  on conflict (id) do update set public = excluded.public;

  insert into storage.buckets (id, name, public)
  values ('job-proofs', 'job-proofs', false)
  on conflict (id) do update set public = excluded.public;
exception
  when others then
    raise notice 'Storage buckets skipped: %', sqlerrm;
end $$;

drop policy if exists avatars_public_read on storage.objects;
drop policy if exists avatars_write on storage.objects;
drop policy if exists avatars_update on storage.objects;
drop policy if exists proofs_read on storage.objects;
drop policy if exists proofs_write on storage.objects;

create policy avatars_public_read on storage.objects
  for select
  using (bucket_id = 'avatars');

create policy avatars_write on storage.objects
  for insert to authenticated
  with check (bucket_id = 'avatars');

create policy avatars_update on storage.objects
  for update to authenticated
  using (bucket_id = 'avatars');

create policy proofs_read on storage.objects
  for select to authenticated
  using (
    bucket_id = 'job-proofs'
    and (
      public.is_admin()
      or split_part(name, '/', 1) in (
        select id::text from public.jobs
        where assigned_to = auth.uid()
           or (public.is_client() and client_id = auth.uid())
      )
    )
  );

create policy proofs_write on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'job-proofs'
    and (
      public.is_admin()
      or split_part(name, '/', 1) in (
        select id::text from public.jobs
        where assigned_to = auth.uid()
           or (public.is_client() and client_id = auth.uid())
      )
    )
  );

-- ---------------------------------------------------------------------------
-- Realtime
-- ---------------------------------------------------------------------------
do $$
begin
  begin
    alter publication supabase_realtime add table public.jobs;
  exception
    when duplicate_object then null;
    when others then raise notice 'realtime jobs: %', sqlerrm;
  end;
  begin
    alter publication supabase_realtime add table public.profiles;
  exception
    when duplicate_object then null;
    when others then raise notice 'realtime profiles: %', sqlerrm;
  end;
end $$;

-- ---------------------------------------------------------------------------
-- Promote the platform admin (run once after creating them in Auth > Users)
-- ---------------------------------------------------------------------------
create or replace function public.promote_admin(admin_email text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  updated_count int;
begin
  update public.profiles
  set role = 'admin'
  where lower(email) = lower(admin_email);

  get diagnostics updated_count = row_count;

  update auth.users
  set raw_app_meta_data =
        coalesce(raw_app_meta_data, '{}'::jsonb) || jsonb_build_object('role', 'admin')
  where lower(email) = lower(admin_email);

  if updated_count = 0 then
    return 'No profile found for ' || admin_email
      || '. Create the user first in Authentication > Users.';
  end if;

  return 'OK. Log out and log in again as ' || admin_email || ' so the admin role is in the session.';
end;
$$;

grant execute on function public.promote_admin(text) to postgres, service_role;

-- Example:
-- select public.promote_admin('admin@company.com');
