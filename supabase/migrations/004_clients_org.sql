-- 004: Tenant org table. Client logins keep their uuid; that uuid becomes clients.id
-- so existing companies/jobs/field-user client_id values stay valid.

-- Drop the compatibility VIEW from 003_roles if present (not the accounts table).
do $$
begin
  if exists (
    select 1 from pg_views where schemaname = 'public' and viewname = 'users'
  ) then
    drop view public.users cascade;
  end if;
end $$;

create table if not exists public.clients (
  id uuid primary key,
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

do $$
declare
  accounts text;
begin
  if to_regclass('public.users') is not null then
    accounts := 'users';
  elsif to_regclass('public.profiles') is not null then
    accounts := 'profiles';
  else
    raise exception 'Neither public.users nor public.profiles exists';
  end if;

  execute format(
    $sql$
      insert into public.clients (id, name, contact_name, email, phone, created_at)
      select
        u.id,
        coalesce(nullif(trim(u.name), ''), nullif(trim(u.email), ''), 'Client'),
        u.name,
        u.email,
        u.mobile,
        u.created_at
      from public.%I u
      where u.role = 'client'
      on conflict (id) do nothing
    $sql$,
    accounts
  );

  execute format(
    'update public.%I set client_id = id where role = ''client''',
    accounts
  );

  execute format('alter table public.%I drop constraint if exists users_client_id_fkey', accounts);
  execute format('alter table public.%I drop constraint if exists profiles_client_id_fkey', accounts);
  execute format('alter table public.%I drop constraint if exists users_client_id_clients_fkey', accounts);
  alter table public.companies drop constraint if exists companies_client_id_fkey;
  alter table public.companies drop constraint if exists companies_client_id_clients_fkey;
  alter table public.jobs drop constraint if exists jobs_client_id_fkey;
  alter table public.jobs drop constraint if exists jobs_client_id_clients_fkey;

  if not exists (
    select 1 from pg_constraint
    where conname = accounts || '_client_id_clients_fkey'
  ) then
    execute format(
      'alter table public.%I add constraint %I foreign key (client_id) references public.clients(id) on delete set null',
      accounts,
      accounts || '_client_id_clients_fkey'
    );
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'companies_client_id_clients_fkey'
  ) then
    alter table public.companies
      add constraint companies_client_id_clients_fkey
      foreign key (client_id) references public.clients(id) on delete set null;
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'jobs_client_id_clients_fkey'
  ) then
    alter table public.jobs
      add constraint jobs_client_id_clients_fkey
      foreign key (client_id) references public.clients(id) on delete set null;
  end if;
end $$;

create index if not exists clients_name_idx on public.clients (name);

alter table public.clients enable row level security;
