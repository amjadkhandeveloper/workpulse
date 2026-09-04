-- Work Pulse HARD RESET
-- Wipes all app tables, Auth logins, and uploaded files.
-- Then run schema.sql, create Auth users, then run_insert_data.sql.
-- Do NOT run this against a database with data you want to keep.

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

delete from storage.objects
where bucket_id in ('avatars', 'job-proofs');

delete from auth.identities;
delete from auth.sessions;
delete from auth.refresh_tokens;
delete from auth.users;
