-- Work Pulse — promote the first Admin only
-- Run AFTER schema.sql.
--
-- 1. Authentication -> Users -> Add user
--      Email:   admin@workpulse.com   (or your own email)
--      Password: (choose one, remember it)
--      Auto Confirm User = ON
--
-- 2. Run this whole file (change the email below if you used a different one).
-- 3. Deploy: supabase functions deploy admin-users
-- 4. Log in as that admin in the app, then log out and log in again.
-- 5. In the app: Admin -> Clients -> Add (creates client Auth login + profile)
-- 6. As Client (or Admin): Users -> Add (creates field user Auth login + profile)
--
-- Do NOT create client/user in the Auth dashboard for day-to-day use.
-- The app edge function does that.

do $$
declare
  v_admin uuid;
  v_email text := 'admin@workpulse.com';  -- change if your Auth email differs
begin
  select id into v_admin from auth.users where lower(email) = lower(v_email);

  if v_admin is null then
    raise exception
      'No Auth login for %. Create it first in Authentication > Users (Auto Confirm ON). Currently: %',
      v_email,
      coalesce((select string_agg(email, ', ' order by email) from auth.users), '(none)');
  end if;

  insert into public.profiles (id, email, username, name, mobile, role, client_id)
  values (
    v_admin,
    v_email,
    'admin',
    'Platform Admin',
    null,
    'admin',
    null
  )
  on conflict (id) do update
    set email = excluded.email,
        username = coalesce(public.profiles.username, excluded.username),
        name = coalesce(nullif(public.profiles.name, ''), excluded.name),
        role = 'admin',
        client_id = null,
        is_active = true;

  update auth.users
  set
    raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb)
      || jsonb_build_object('name', 'Platform Admin', 'username', 'admin'),
    raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb)
      || jsonb_build_object('role', 'admin')
  where id = v_admin;
end $$;

select email, username, role, client_id, name
from public.profiles
where role = 'admin';
