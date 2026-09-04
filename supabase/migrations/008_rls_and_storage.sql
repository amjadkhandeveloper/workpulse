-- 008: Tenant RLS from profiles.client_id / is_admin(), storage, realtime.

alter table public.clients enable row level security;
alter table public.profiles enable row level security;
alter table public.companies enable row level security;
alter table public.jobs enable row level security;
alter table public.job_proofs enable row level security;
alter table public.job_status_history enable row level security;
alter table public.job_checkouts enable row level security;
alter table public.job_checkout_photos enable row level security;
alter table public.attendance enable row level security;
alter table public.leaves enable row level security;
alter table public.location_pings enable row level security;
alter table public.user_live_locations enable row level security;
alter table public.roles enable row level security;

-- Drop legacy + current policies so this file is re-runnable.
drop policy if exists roles_select on public.roles;
-- Drop legacy policies. IF EXISTS only covers the policy name, not a missing table.
do $$
begin
  if to_regclass('public.users') is not null then
    execute 'drop policy if exists users_select_own on public.users';
    execute 'drop policy if exists users_select_admin on public.users';
    execute 'drop policy if exists users_select_client_users on public.users';
    execute 'drop policy if exists users_update_self on public.users';
  end if;
end $$;
drop policy if exists users_select_own on public.profiles;
drop policy if exists users_select_admin on public.profiles;
drop policy if exists users_select_client_users on public.profiles;
drop policy if exists users_update_self on public.profiles;
drop policy if exists profiles_select on public.profiles;
drop policy if exists profiles_select_own on public.profiles;
drop policy if exists profiles_select_admin on public.profiles;
drop policy if exists profiles_select_client_users on public.profiles;
drop policy if exists profiles_update_self on public.profiles;
drop policy if exists clients_select on public.clients;
drop policy if exists clients_admin_all on public.clients;
drop policy if exists companies_admin_all on public.companies;
drop policy if exists companies_manager_all on public.companies;
drop policy if exists companies_read_assigned on public.companies;
drop policy if exists jobs_admin_all on public.jobs;
drop policy if exists jobs_manager_all on public.jobs;
drop policy if exists jobs_user_select on public.jobs;
drop policy if exists jobs_user_update on public.jobs;
drop policy if exists proofs_select on public.job_proofs;
drop policy if exists proofs_insert on public.job_proofs;
drop policy if exists job_history_select on public.job_status_history;
drop policy if exists job_checkouts_select on public.job_checkouts;
drop policy if exists job_checkout_photos_select on public.job_checkout_photos;
drop policy if exists attendance_select on public.attendance;
drop policy if exists attendance_insert on public.attendance;
drop policy if exists leaves_select on public.leaves;
drop policy if exists leaves_insert on public.leaves;
drop policy if exists leaves_update_admin on public.leaves;
drop policy if exists pings_insert on public.location_pings;
drop policy if exists pings_select on public.location_pings;
drop policy if exists live_select on public.user_live_locations;
drop policy if exists live_insert on public.user_live_locations;
drop policy if exists live_update on public.user_live_locations;

create policy roles_select on public.roles
  for select to authenticated
  using (true);

create policy clients_select on public.clients
  for select to authenticated
  using (
    public.is_admin()
    or id = public.current_client_id()
  );

create policy clients_admin_all on public.clients
  for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy profiles_select_own on public.profiles
  for select to authenticated
  using (id = auth.uid());

create policy profiles_select_admin on public.profiles
  for select to authenticated
  using (public.is_admin());

create policy profiles_select_client_users on public.profiles
  for select to authenticated
  using (
    public.is_client()
    and client_id is not null
    and client_id = public.current_client_id()
  );

create policy profiles_update_self on public.profiles
  for update to authenticated
  using (id = auth.uid() or public.is_admin() or public.owns_field_user(id))
  with check (id = auth.uid() or public.is_admin() or public.owns_field_user(id));

create policy companies_manager_all on public.companies
  for all to authenticated
  using (
    public.is_admin()
    or (public.is_client() and client_id = public.current_client_id())
  )
  with check (
    public.is_admin()
    or (public.is_client() and client_id = public.current_client_id())
  );

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
  using (
    public.is_admin()
    or (public.is_client() and client_id = public.current_client_id())
  )
  with check (
    public.is_admin()
    or (public.is_client() and client_id = public.current_client_id())
  );

create policy jobs_user_select on public.jobs
  for select to authenticated
  using (assigned_to = auth.uid());

-- Field users change status only through RPCs (transition_job_status / submit_job_checkout).

create policy proofs_select on public.job_proofs
  for select to authenticated
  using (
    public.is_admin()
    or exists (
      select 1 from public.jobs
      where jobs.id = job_proofs.job_id
        and (
          jobs.assigned_to = auth.uid()
          or (public.is_client() and jobs.client_id = public.current_client_id())
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
        and jobs.assigned_to = auth.uid()
    )
  );

create policy job_history_select on public.job_status_history
  for select to authenticated
  using (
    public.is_admin()
    or exists (
      select 1 from public.jobs
      where jobs.id = job_status_history.job_id
        and (
          jobs.assigned_to = auth.uid()
          or (public.is_client() and jobs.client_id = public.current_client_id())
        )
    )
  );

create policy job_checkouts_select on public.job_checkouts
  for select to authenticated
  using (
    public.is_admin()
    or exists (
      select 1 from public.jobs
      where jobs.id = job_checkouts.job_id
        and (
          jobs.assigned_to = auth.uid()
          or (public.is_client() and jobs.client_id = public.current_client_id())
        )
    )
  );

create policy job_checkout_photos_select on public.job_checkout_photos
  for select to authenticated
  using (
    public.is_admin()
    or exists (
      select 1
      from public.job_checkouts c
      join public.jobs j on j.id = c.job_id
      where c.id = job_checkout_photos.checkout_id
        and (
          j.assigned_to = auth.uid()
          or (public.is_client() and j.client_id = public.current_client_id())
        )
    )
  );

create policy attendance_select on public.attendance
  for select to authenticated
  using (
    user_id = auth.uid()
    or public.is_admin()
    or public.owns_field_user(user_id)
    or (public.is_client() and client_id = public.current_client_id())
  );

create policy attendance_insert on public.attendance
  for insert to authenticated
  with check (user_id = auth.uid() or public.is_admin() or public.owns_field_user(user_id));

create policy leaves_select on public.leaves
  for select to authenticated
  using (
    user_id = auth.uid()
    or public.is_admin()
    or public.owns_field_user(user_id)
    or (public.is_client() and client_id = public.current_client_id())
  );

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
  using (
    user_id = auth.uid()
    or public.is_admin()
    or public.owns_field_user(user_id)
    or (public.is_client() and client_id = public.current_client_id())
  );

create policy live_select on public.user_live_locations
  for select to authenticated
  using (
    user_id = auth.uid()
    or public.is_admin()
    or (public.is_client() and client_id = public.current_client_id())
  );

grant usage on schema public to anon, authenticated, service_role;
grant all on all tables in schema public to postgres, service_role;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant usage, select on all sequences in schema public to authenticated, service_role;
grant select on public.roles to authenticated, service_role, postgres;

-- Storage
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
           or (public.is_client() and client_id = public.current_client_id())
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
      )
    )
  );

-- Realtime: jobs + live locations only (not GPS history, not full profiles).
do $$
begin
  begin
    alter publication supabase_realtime drop table public.users;
  exception
    when undefined_table then null;
    when undefined_object then null;
    when others then raise notice 'realtime drop users: %', sqlerrm;
  end;
  begin
    alter publication supabase_realtime drop table public.profiles;
  exception
    when undefined_table then null;
    when undefined_object then null;
    when others then raise notice 'realtime drop profiles: %', sqlerrm;
  end;
  begin
    alter publication supabase_realtime drop table public.location_pings;
  exception
    when undefined_table then null;
    when undefined_object then null;
    when others then raise notice 'realtime drop pings: %', sqlerrm;
  end;
  begin
    alter publication supabase_realtime add table public.jobs;
  exception
    when duplicate_object then null;
    when others then raise notice 'realtime jobs: %', sqlerrm;
  end;
  begin
    alter publication supabase_realtime add table public.user_live_locations;
  exception
    when duplicate_object then null;
    when others then raise notice 'realtime live: %', sqlerrm;
  end;
end $$;
