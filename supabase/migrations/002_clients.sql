-- Work Pulse: Admin / Client / User hierarchy
-- Run this AFTER the original schema.sql if the project already exists.
-- Safe to run more than once.

-- ---------------------------------------------------------------------------
-- Columns
-- ---------------------------------------------------------------------------
alter table public.profiles drop constraint if exists profiles_role_check;
alter table public.profiles
  add constraint profiles_role_check check (role in ('admin', 'client', 'user'));

alter table public.profiles
  add column if not exists client_id uuid references public.profiles(id) on delete set null;

alter table public.companies
  add column if not exists client_id uuid references public.profiles(id) on delete set null;

alter table public.jobs
  add column if not exists client_id uuid references public.profiles(id) on delete set null;

create index if not exists profiles_client_id_idx on public.profiles (client_id);
create index if not exists profiles_role_idx on public.profiles (role);
create index if not exists companies_client_id_idx on public.companies (client_id);
create index if not exists jobs_client_id_idx on public.jobs (client_id);

-- ---------------------------------------------------------------------------
-- JWT helpers
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

revoke all on function public.is_admin() from public;
revoke all on function public.is_client() from public;
revoke all on function public.is_manager() from public;
grant execute on function public.is_admin() to authenticated, service_role;
grant execute on function public.is_client() to authenticated, service_role;
grant execute on function public.is_manager() to authenticated, service_role;

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

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
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

drop policy if exists proofs_read on storage.objects;
drop policy if exists proofs_write on storage.objects;

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
