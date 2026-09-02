-- Work Pulse schema
-- Run in the Supabase SQL editor after creating the project.

create extension if not exists "pgcrypto";

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  );
$$;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  name text not null default '',
  mobile text,
  photo_url text,
  role text not null default 'user' check (role in ('admin', 'user')),
  is_active boolean not null default true,
  standby_status text not null default 'out' check (standby_status in ('out', 'in')),
  last_lat double precision,
  last_lng double precision,
  last_location_at timestamptz,
  created_at timestamptz not null default now()
);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, name, mobile, role)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'name', ''),
    new.raw_user_meta_data->>'mobile',
    'user'
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create table if not exists public.companies (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  location text,
  work text,
  contact_name text,
  mobile text,
  lat double precision,
  lng double precision,
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
  created_at timestamptz not null default now()
);

create unique index if not exists jobs_one_active_per_user
  on public.jobs (assigned_to)
  where status in ('accepted', 'checked_in') and assigned_to is not null;

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

alter table public.profiles enable row level security;
alter table public.companies enable row level security;
alter table public.jobs enable row level security;
alter table public.job_proofs enable row level security;
alter table public.attendance enable row level security;
alter table public.leaves enable row level security;
alter table public.location_pings enable row level security;

drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles
  for select to authenticated
  using (id = auth.uid() or public.is_admin());

drop policy if exists profiles_update_self on public.profiles;
create policy profiles_update_self on public.profiles
  for update to authenticated
  using (id = auth.uid() or public.is_admin())
  with check (id = auth.uid() or public.is_admin());

drop policy if exists companies_admin_all on public.companies;
create policy companies_admin_all on public.companies
  for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists companies_read_assigned on public.companies;
create policy companies_read_assigned on public.companies
  for select to authenticated
  using (
    public.is_admin()
    or exists (
      select 1 from public.jobs
      where jobs.company_id = companies.id and jobs.assigned_to = auth.uid()
    )
  );

drop policy if exists jobs_admin_all on public.jobs;
create policy jobs_admin_all on public.jobs
  for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists jobs_user_select on public.jobs;
create policy jobs_user_select on public.jobs
  for select to authenticated
  using (assigned_to = auth.uid() or public.is_admin());

drop policy if exists jobs_user_update on public.jobs;
create policy jobs_user_update on public.jobs
  for update to authenticated
  using (assigned_to = auth.uid())
  with check (assigned_to = auth.uid());

drop policy if exists proofs_select on public.job_proofs;
create policy proofs_select on public.job_proofs
  for select to authenticated
  using (
    public.is_admin()
    or exists (select 1 from public.jobs where jobs.id = job_proofs.job_id and jobs.assigned_to = auth.uid())
  );

drop policy if exists proofs_insert on public.job_proofs;
create policy proofs_insert on public.job_proofs
  for insert to authenticated
  with check (
    public.is_admin()
    or exists (select 1 from public.jobs where jobs.id = job_proofs.job_id and jobs.assigned_to = auth.uid())
  );

drop policy if exists attendance_select on public.attendance;
create policy attendance_select on public.attendance
  for select to authenticated
  using (user_id = auth.uid() or public.is_admin());

drop policy if exists attendance_insert on public.attendance;
create policy attendance_insert on public.attendance
  for insert to authenticated
  with check (user_id = auth.uid() or public.is_admin());

drop policy if exists leaves_select on public.leaves;
create policy leaves_select on public.leaves
  for select to authenticated
  using (user_id = auth.uid() or public.is_admin());

drop policy if exists leaves_insert on public.leaves;
create policy leaves_insert on public.leaves
  for insert to authenticated
  with check (user_id = auth.uid());

drop policy if exists leaves_update_admin on public.leaves;
create policy leaves_update_admin on public.leaves
  for update to authenticated
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists pings_insert on public.location_pings;
create policy pings_insert on public.location_pings
  for insert to authenticated
  with check (user_id = auth.uid());

drop policy if exists pings_select on public.location_pings;
create policy pings_select on public.location_pings
  for select to authenticated
  using (user_id = auth.uid() or public.is_admin());

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('job-proofs', 'job-proofs', false)
on conflict (id) do nothing;

drop policy if exists avatars_public_read on storage.objects;
create policy avatars_public_read on storage.objects
  for select using (bucket_id = 'avatars');

drop policy if exists avatars_write on storage.objects;
create policy avatars_write on storage.objects
  for insert to authenticated
  with check (bucket_id = 'avatars');

drop policy if exists avatars_update on storage.objects;
create policy avatars_update on storage.objects
  for update to authenticated
  using (bucket_id = 'avatars');

drop policy if exists proofs_read on storage.objects;
create policy proofs_read on storage.objects
  for select to authenticated
  using (
    bucket_id = 'job-proofs'
    and (
      public.is_admin()
      or split_part(name, '/', 1) in (
        select id::text from public.jobs where assigned_to = auth.uid()
      )
    )
  );

drop policy if exists proofs_write on storage.objects;
create policy proofs_write on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'job-proofs'
    and (
      public.is_admin()
      or split_part(name, '/', 1) in (
        select id::text from public.jobs where assigned_to = auth.uid()
      )
    )
  );

do $$
begin
  begin
    alter publication supabase_realtime add table public.jobs;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.profiles;
  exception when duplicate_object then null;
  end;
end $$;

-- After creating your first account:
-- update public.profiles set role = 'admin' where email = 'you@example.com';
