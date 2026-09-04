-- 005: Application profiles (no passwords). Auth remains auth.users.

do $$
begin
  if to_regclass('public.users') is not null and to_regclass('public.profiles') is null then
    alter table public.users rename to profiles;
  end if;
end $$;

alter table public.profiles drop column if exists password_hash;

do $$
begin
  if exists (
    select 1 from pg_constraint
    where conname = 'users_client_id_clients_fkey'
  ) then
    alter table public.profiles rename constraint users_client_id_clients_fkey to profiles_client_id_fkey;
  end if;
exception
  when others then null;
end $$;

alter index if exists users_pkey rename to profiles_pkey;
alter index if exists users_username_lower_idx rename to profiles_username_lower_idx;
alter index if exists users_email_lower_idx rename to profiles_email_lower_idx;
alter index if exists users_client_id_idx rename to profiles_client_id_idx;
alter index if exists users_role_idx rename to profiles_role_idx;

alter table public.profiles drop constraint if exists users_role_check;
alter table public.profiles drop constraint if exists profiles_role_check;
alter table public.profiles
  add constraint profiles_role_check
  check (role in ('admin', 'client', 'user'));

drop trigger if exists on_user_role_changed on public.profiles;
do $$
begin
  if to_regclass('public.users') is not null then
    execute 'drop trigger if exists on_user_role_changed on public.users';
  end if;
end $$;

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

drop trigger if exists on_profile_role_changed on public.profiles;
create trigger on_profile_role_changed
after insert or update of role on public.profiles
for each row execute function public.sync_auth_role();

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

  insert into public.profiles (id, email, name, username, role, client_id)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'name', split_part(new.email, '@', 1)),
    meta_username,
    meta_role,
    meta_client
  )
  on conflict (id) do update
    set email = excluded.email,
        name = coalesce(nullif(public.profiles.name, ''), excluded.name),
        username = coalesce(public.profiles.username, excluded.username),
        role = excluded.role,
        client_id = coalesce(excluded.client_id, public.profiles.client_id);

  return new;
end;
$$;

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

drop function if exists public.hash_password(text);

grant execute on function public.current_client_id() to authenticated, service_role;
grant execute on function public.login_identifier_to_email(text) to anon, authenticated, service_role;
grant execute on function public.promote_admin(text) to postgres, service_role;
grant execute on function public.owns_field_user(uuid) to authenticated, service_role;
grant execute on function public.handle_new_user() to postgres, service_role;
grant execute on function public.sync_auth_role() to postgres, service_role;
