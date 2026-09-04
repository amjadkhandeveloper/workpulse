-- Work Pulse schema (single file)
-- Paste this WHOLE file into Supabase: SQL Editor -> New query -> Run.
--
-- Run order:
--   1. Optional: supabase/reset.sql if you also want Auth logins deleted
--   2. This file (rebuilds public app tables/functions/RLS/storage policies)
--   3. Authentication -> Users: create ONLY the admin (email + password, Auto Confirm ON)
--   4. supabase/run_insert_data.sql (promotes that Auth user to admin)
--   5. Deploy: supabase functions deploy admin-users
--   6. Log in as admin; add Clients and field Users from the app (no more Auth dashboard)
--
-- Auth stays in Authentication (auth.users). Profiles have no passwords.
-- No Google / Apple login. Users do not self-register.
-- Job statuses: pending (assigned), accepted (en route / Enroute UI),
--   checked_in, pending_review (checked out), completed / declined / cancelled.

-- ---------------------------------------------------------------------------
-- Drop public app objects (does NOT delete auth.users)
-- ---------------------------------------------------------------------------
drop view if exists public.users cascade;

drop trigger if exists on_auth_user_created on auth.users;

do $$
begin
  if to_regclass('public.users') is not null then
    execute 'drop trigger if exists on_user_role_changed on public.users';
  end if;
  if to_regclass('public.profiles') is not null then
    execute 'drop trigger if exists on_user_role_changed on public.profiles';
    execute 'drop trigger if exists on_profile_role_changed on public.profiles';
  end if;
end $$;

drop table if exists public.job_checkout_photos cascade;
drop table if exists public.job_checkouts cascade;
drop table if exists public.job_status_history cascade;
drop table if exists public.job_proofs cascade;
drop table if exists public.location_pings cascade;
drop table if exists public.user_live_locations cascade;
drop table if exists public.attendance cascade;
drop table if exists public.leaves cascade;
drop table if exists public.jobs cascade;
drop table if exists public.companies cascade;
drop table if exists public.users cascade;
drop table if exists public.profiles cascade;
drop table if exists public.clients cascade;
drop table if exists public.roles cascade;

drop function if exists public.handle_new_user() cascade;
drop function if exists public.sync_role_to_jwt() cascade;
drop function if exists public.sync_auth_role() cascade;
drop function if exists public.owns_field_user(uuid) cascade;
drop function if exists public.current_client_id() cascade;
drop function if exists public.is_manager() cascade;
drop function if exists public.is_client() cascade;
drop function if exists public.is_admin() cascade;
drop function if exists public.promote_admin(text) cascade;
drop function if exists public.hash_password(text) cascade;
drop function if exists public.login_identifier_to_email(text) cascade;
drop function if exists public.transition_job_status(uuid, text, text, double precision, double precision) cascade;
drop function if exists public.submit_job_checkout(uuid, text, text, text[]) cascade;
drop function if exists public.complete_job(uuid) cascade;
drop function if exists public.update_live_location(double precision, double precision, double precision, text, uuid) cascade;
drop function if exists public._record_job_status(uuid, text, text, text) cascade;
drop function if exists public.jobs_enforce_tenant() cascade;
drop function if exists public.job_checkout_photos_cap() cascade;
drop function if exists public.touch_updated_at() cascade;
drop function if exists public.set_row_client_id_from_user() cascade;

do $$
begin
  create extension if not exists pgcrypto with schema extensions;
exception
  when others then
    raise notice 'pgcrypto extension: %', sqlerrm;
end $$;

-- ---------------------------------------------------------------------------
-- JWT helpers (no table reads — avoids RLS recursion)
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

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------
create table public.roles (
  code text primary key,
  name text not null,
  description text,
  sort_order int not null default 0
);

comment on table public.roles is
  'Lookup of app roles: admin (sees everything), client (sees own tenant), user (own data only).';

insert into public.roles (code, name, description, sort_order)
values
  (
    'admin',
    'Admin',
    'Platform owner. Can view and manage every client, user, company, job, leave request, and map pin.',
    1
  ),
  (
    'client',
    'Client',
    'Tenant under admin. Can view and manage only field users assigned to this client, and only this client''s companies and jobs.',
    2
  ),
  (
    'user',
    'User',
    'Field staff allocated to one client. Can see only their own jobs, attendance, and leave.',
    3
  );

create table public.clients (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  contact_name text,
  email text,
  phone text,
  address text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.clients is
  'Tenant organization. Client logins and field users share profiles.client_id = clients.id.';

create index clients_name_idx on public.clients (name);

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  username text,
  name text not null default '',
  mobile text,
  photo_url text,
  role text not null default 'user' references public.roles(code),
  client_id uuid references public.clients(id) on delete set null,
  is_active boolean not null default true,
  standby_status text not null default 'out' check (standby_status in ('out', 'in')),
  last_lat double precision,
  last_lng double precision,
  last_location_at timestamptz,
  created_at timestamptz not null default now(),
  constraint profiles_role_check check (role in ('admin', 'client', 'user'))
);

comment on table public.profiles is
  'App profile for each auth.users row. No passwords. Login is Authentication only.';
comment on column public.profiles.username is
  'Optional login alias. Resolved to email, then Auth sign-in.';
comment on column public.profiles.client_id is
  'Tenant: clients.id. Set for client logins and field users. Null for admin.';

create unique index profiles_username_lower_idx
  on public.profiles (lower(username))
  where username is not null;
create unique index profiles_email_lower_idx
  on public.profiles (lower(email))
  where email is not null;
create index profiles_client_id_idx on public.profiles (client_id);
create index profiles_role_idx on public.profiles (role);

create or replace function public.current_client_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select p.client_id from public.profiles p where p.id = auth.uid();
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
        where p.id = target
          and p.role = 'user'
          and p.client_id is not null
          and p.client_id = public.current_client_id()
      )
    );
$$;

revoke all on function public.current_client_id() from public;
revoke all on function public.owns_field_user(uuid) from public;
grant execute on function public.current_client_id() to authenticated, service_role;
grant execute on function public.owns_field_user(uuid) to authenticated, service_role;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  meta_role text;
  meta_client uuid;
  meta_username text;
begin
  meta_role := coalesce(new.raw_app_meta_data->>'role', 'user');
  if meta_role not in ('admin', 'client', 'user') then
    meta_role := 'user';
  end if;
  begin
    meta_client := nullif(new.raw_app_meta_data->>'client_id', '')::uuid;
  exception
    when others then meta_client := null;
  end;
  meta_username := nullif(trim(coalesce(new.raw_user_meta_data->>'username', '')), '');

  insert into public.profiles (id, email, name, username, mobile, role, client_id)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'name', split_part(new.email, '@', 1)),
    meta_username,
    new.raw_user_meta_data->>'mobile',
    meta_role,
    meta_client
  )
  on conflict (id) do update
    set email = excluded.email,
        name = coalesce(nullif(public.profiles.name, ''), excluded.name),
        username = coalesce(public.profiles.username, excluded.username),
        mobile = coalesce(excluded.mobile, public.profiles.mobile),
        role = excluded.role,
        client_id = coalesce(excluded.client_id, public.profiles.client_id);

  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

create or replace function public.sync_auth_role()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update auth.users
  set raw_app_meta_data =
        coalesce(raw_app_meta_data, '{}'::jsonb) || jsonb_build_object('role', new.role)
  where id = new.id;
  return new;
end;
$$;

create trigger on_profile_role_changed
after insert or update of role on public.profiles
for each row execute function public.sync_auth_role();

create or replace function public.login_identifier_to_email(identifier text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  trimmed text := lower(trim(identifier));
  found_email text;
begin
  if trimmed is null or trimmed = '' then
    return null;
  end if;
  if position('@' in trimmed) > 0 then
    return trimmed;
  end if;
  select p.email into found_email
  from public.profiles p
  where lower(p.username) = trimmed
  limit 1;
  return found_email;
end;
$$;

revoke all on function public.login_identifier_to_email(text) from public;
grant execute on function public.login_identifier_to_email(text) to anon, authenticated, service_role;

create table public.companies (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  location text,
  work text,
  contact_name text,
  mobile text,
  lat double precision,
  lng double precision,
  client_id uuid references public.clients(id) on delete set null,
  created_at timestamptz not null default now()
);

comment on table public.companies is
  'Companies belong to a client tenant (client_id → clients.id). Admin sees all.';

create table public.jobs (
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
  client_id uuid references public.clients(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on column public.jobs.status is
  'pending=assigned, accepted=en route, checked_in, pending_review=checked out, completed/declined/cancelled.';

create unique index jobs_one_active_per_user
  on public.jobs (assigned_to)
  where status in ('accepted', 'checked_in') and assigned_to is not null;

create index jobs_assigned_to_idx on public.jobs (assigned_to);
create index jobs_status_idx on public.jobs (status);
create index companies_client_id_idx on public.companies (client_id);
create index jobs_client_id_idx on public.jobs (client_id);

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger jobs_touch_updated_at
before update on public.jobs
for each row execute function public.touch_updated_at();

create or replace function public.jobs_enforce_tenant()
returns trigger
language plpgsql
as $$
declare
  company_client uuid;
  assignee_client uuid;
  assignee_role text;
begin
  if new.company_id is not null then
    select client_id into company_client from public.companies where id = new.company_id;
    if company_client is distinct from new.client_id then
      raise exception 'Company belongs to a different client';
    end if;
  end if;
  if new.assigned_to is not null then
    select client_id, role into assignee_client, assignee_role
    from public.profiles where id = new.assigned_to;
    if assignee_role = 'user' and assignee_client is distinct from new.client_id then
      raise exception 'Assignee belongs to a different client';
    end if;
  end if;
  return new;
end;
$$;

create trigger jobs_enforce_tenant
before insert or update of company_id, assigned_to, client_id on public.jobs
for each row execute function public.jobs_enforce_tenant();

create table public.job_status_history (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.jobs(id) on delete cascade,
  from_status text,
  to_status text not null,
  changed_by uuid references public.profiles(id) on delete set null,
  note text,
  created_at timestamptz not null default now()
);

create index job_status_history_job_idx
  on public.job_status_history (job_id, created_at desc);

create table public.job_checkouts (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null unique references public.jobs(id) on delete cascade,
  note text,
  signature_path text,
  submitted_by uuid references public.profiles(id) on delete set null,
  submitted_at timestamptz not null default now()
);

create table public.job_checkout_photos (
  id uuid primary key default gen_random_uuid(),
  checkout_id uuid not null references public.job_checkouts(id) on delete cascade,
  storage_path text not null,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

create index job_checkout_photos_checkout_idx
  on public.job_checkout_photos (checkout_id, sort_order);

create or replace function public.job_checkout_photos_cap()
returns trigger
language plpgsql
as $$
declare
  n int;
begin
  select count(*) into n
  from public.job_checkout_photos
  where checkout_id = new.checkout_id;
  if n > 6 then
    raise exception 'A checkout can have at most 6 photos';
  end if;
  return new;
end;
$$;

create trigger job_checkout_photos_cap
after insert on public.job_checkout_photos
for each row execute function public.job_checkout_photos_cap();

create table public.attendance (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  client_id uuid references public.clients(id) on delete set null,
  type text not null check (type in ('standby_in', 'standby_out')),
  at timestamptz not null default now(),
  lat double precision,
  lng double precision
);

create index attendance_user_at_idx on public.attendance (user_id, at desc);
create index attendance_client_id_idx on public.attendance (client_id);

create table public.leaves (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  client_id uuid references public.clients(id) on delete set null,
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

create index leaves_client_id_idx on public.leaves (client_id);

create table public.location_pings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  client_id uuid references public.clients(id) on delete set null,
  lat double precision not null,
  lng double precision not null,
  accuracy double precision,
  recorded_at timestamptz not null default now(),
  context text not null default 'standby' check (context in ('standby', 'job')),
  job_id uuid references public.jobs(id) on delete set null
);

create index location_pings_user_idx on public.location_pings (user_id, recorded_at desc);
create index location_pings_client_id_idx on public.location_pings (client_id);

create table public.user_live_locations (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  client_id uuid references public.clients(id) on delete set null,
  lat double precision not null,
  lng double precision not null,
  accuracy double precision,
  context text not null default 'standby' check (context in ('standby', 'job')),
  job_id uuid references public.jobs(id) on delete set null,
  recorded_at timestamptz not null default now()
);

create index user_live_locations_client_idx on public.user_live_locations (client_id);
create index user_live_locations_recorded_idx on public.user_live_locations (recorded_at desc);

create or replace function public.set_row_client_id_from_user()
returns trigger
language plpgsql
as $$
begin
  if new.client_id is null and new.user_id is not null then
    select client_id into new.client_id from public.profiles where id = new.user_id;
  end if;
  return new;
end;
$$;

create trigger attendance_set_client_id
before insert on public.attendance
for each row execute function public.set_row_client_id_from_user();

create trigger leaves_set_client_id
before insert on public.leaves
for each row execute function public.set_row_client_id_from_user();

create trigger location_pings_set_client_id
before insert on public.location_pings
for each row execute function public.set_row_client_id_from_user();

-- ---------------------------------------------------------------------------
-- Job workflow RPCs
-- ---------------------------------------------------------------------------
create or replace function public._record_job_status(
  p_job_id uuid,
  p_from text,
  p_to text,
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.job_status_history (job_id, from_status, to_status, changed_by, note)
  values (p_job_id, p_from, p_to, auth.uid(), p_note);
end;
$$;

create or replace function public.transition_job_status(
  p_job_id uuid,
  p_to_status text,
  p_note text default null,
  p_lat double precision default null,
  p_lng double precision default null
)
returns public.jobs
language plpgsql
security definer
set search_path = public
as $$
declare
  job public.jobs;
  from_status text;
  uid uuid := auth.uid();
  allowed boolean := false;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  if p_to_status not in (
    'pending', 'accepted', 'declined', 'checked_in', 'pending_review', 'completed', 'cancelled'
  ) then
    raise exception 'Invalid status';
  end if;
  if p_to_status in ('pending_review', 'completed') then
    raise exception 'Use submit_job_checkout or complete_job for this transition';
  end if;

  select * into job from public.jobs where id = p_job_id for update;
  if not found then
    raise exception 'Job not found';
  end if;
  from_status := job.status;

  if public.is_admin() or (public.is_client() and job.client_id = public.current_client_id()) then
    if p_to_status = 'cancelled' and from_status not in ('completed', 'cancelled') then
      allowed := true;
    end if;
  end if;

  if job.assigned_to = uid then
    if from_status = 'pending' and p_to_status in ('accepted', 'declined') then
      allowed := true;
    elsif from_status = 'accepted' and p_to_status = 'checked_in' then
      allowed := true;
    end if;
  end if;

  if not allowed then
    raise exception 'Not allowed to set status % from %', p_to_status, from_status;
  end if;

  update public.jobs
  set
    status = p_to_status,
    lat = coalesce(p_lat, lat),
    lng = coalesce(p_lng, lng)
  where id = p_job_id
  returning * into job;

  perform public._record_job_status(p_job_id, from_status, p_to_status, p_note);
  return job;
end;
$$;

create or replace function public.submit_job_checkout(
  p_job_id uuid,
  p_note text,
  p_signature_path text,
  p_photo_paths text[]
)
returns public.jobs
language plpgsql
security definer
set search_path = public
as $$
declare
  job public.jobs;
  v_checkout_id uuid;
  i int;
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  if p_signature_path is null or length(trim(p_signature_path)) = 0 then
    raise exception 'Signature is required';
  end if;
  if p_photo_paths is null or cardinality(p_photo_paths) < 1 or cardinality(p_photo_paths) > 6 then
    raise exception 'Checkout requires 1 to 6 photos';
  end if;

  select * into job from public.jobs where id = p_job_id for update;
  if not found then
    raise exception 'Job not found';
  end if;
  if job.assigned_to is distinct from uid then
    raise exception 'Only the assigned user can check out';
  end if;
  if job.status is distinct from 'checked_in' then
    raise exception 'Job must be checked in before checkout';
  end if;

  insert into public.job_checkouts (job_id, note, signature_path, submitted_by)
  values (p_job_id, p_note, p_signature_path, uid)
  on conflict (job_id) do update
    set note = excluded.note,
        signature_path = excluded.signature_path,
        submitted_by = excluded.submitted_by,
        submitted_at = now()
  returning id into v_checkout_id;

  delete from public.job_checkout_photos where checkout_id = v_checkout_id;
  for i in 1 .. cardinality(p_photo_paths) loop
    insert into public.job_checkout_photos (checkout_id, storage_path, sort_order)
    values (v_checkout_id, p_photo_paths[i], i - 1);
  end loop;

  update public.jobs
  set status = 'pending_review', checkout_note = p_note
  where id = p_job_id
  returning * into job;

  perform public._record_job_status(p_job_id, 'checked_in', 'pending_review', p_note);
  return job;
end;
$$;

create or replace function public.complete_job(p_job_id uuid)
returns public.jobs
language plpgsql
security definer
set search_path = public
as $$
declare
  job public.jobs;
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;

  select * into job from public.jobs where id = p_job_id for update;
  if not found then
    raise exception 'Job not found';
  end if;
  if job.status is distinct from 'pending_review' then
    raise exception 'Job is not awaiting review';
  end if;
  if not (
    public.is_admin()
    or (public.is_client() and job.client_id = public.current_client_id())
  ) then
    raise exception 'Only the client or admin can complete a job';
  end if;

  update public.jobs
  set
    status = 'completed',
    reviewed_by = uid,
    reviewed_at = now()
  where id = p_job_id
  returning * into job;

  perform public._record_job_status(p_job_id, 'pending_review', 'completed', null);
  return job;
end;
$$;

create or replace function public.update_live_location(
  p_lat double precision,
  p_lng double precision,
  p_accuracy double precision default null,
  p_context text default 'standby',
  p_job_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  cid uuid;
  ctx text := coalesce(nullif(p_context, ''), 'standby');
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  if ctx not in ('standby', 'job') then
    ctx := 'standby';
  end if;

  select client_id into cid from public.profiles where id = uid;

  insert into public.location_pings (user_id, client_id, lat, lng, accuracy, context, job_id)
  values (uid, cid, p_lat, p_lng, p_accuracy, ctx, p_job_id);

  insert into public.user_live_locations (
    user_id, client_id, lat, lng, accuracy, context, job_id, recorded_at
  )
  values (uid, cid, p_lat, p_lng, p_accuracy, ctx, p_job_id, now())
  on conflict (user_id) do update
    set client_id = excluded.client_id,
        lat = excluded.lat,
        lng = excluded.lng,
        accuracy = excluded.accuracy,
        context = excluded.context,
        job_id = excluded.job_id,
        recorded_at = excluded.recorded_at;

  update public.profiles
  set last_lat = p_lat, last_lng = p_lng, last_location_at = now()
  where id = uid;
end;
$$;

grant execute on function public.transition_job_status(uuid, text, text, double precision, double precision)
  to authenticated, service_role;
grant execute on function public.submit_job_checkout(uuid, text, text, text[])
  to authenticated, service_role;
grant execute on function public.complete_job(uuid)
  to authenticated, service_role;
grant execute on function public.update_live_location(double precision, double precision, double precision, text, uuid)
  to authenticated, service_role;
grant execute on function public._record_job_status(uuid, text, text, text)
  to service_role;

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------
alter table public.roles enable row level security;
alter table public.clients enable row level security;
alter table public.profiles enable row level security;
alter table public.companies enable row level security;
alter table public.jobs enable row level security;
alter table public.job_status_history enable row level security;
alter table public.job_checkouts enable row level security;
alter table public.job_checkout_photos enable row level security;
alter table public.attendance enable row level security;
alter table public.leaves enable row level security;
alter table public.location_pings enable row level security;
alter table public.user_live_locations enable row level security;

create policy roles_select on public.roles
  for select to authenticated
  using (true);

create policy clients_select on public.clients
  for select to authenticated
  using (public.is_admin() or id = public.current_client_id());

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

-- Field users change status only via RPCs (transition_job_status / submit_job_checkout).

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

-- ---------------------------------------------------------------------------
-- Realtime (jobs + live map only)
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
    alter publication supabase_realtime add table public.user_live_locations;
  exception
    when duplicate_object then null;
    when others then raise notice 'realtime live: %', sqlerrm;
  end;
end $$;

-- ---------------------------------------------------------------------------
-- Promote admin (optional; run_insert_data.sql also sets admin)
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
  set
    role = 'admin',
    client_id = null,
    username = coalesce(nullif(username, ''), split_part(admin_email, '@', 1))
  where lower(email) = lower(admin_email);

  get diagnostics updated_count = row_count;

  update auth.users
  set raw_app_meta_data =
        coalesce(raw_app_meta_data, '{}'::jsonb) || jsonb_build_object('role', 'admin')
  where lower(email) = lower(admin_email);

  if updated_count = 0 then
    return 'No profile found for ' || admin_email
      || '. Create the login first in Authentication > Users.';
  end if;

  return 'OK. Log out and log in again as ' || admin_email || ' so the admin role is in the session.';
end;
$$;

grant execute on function public.promote_admin(text) to postgres, service_role;
