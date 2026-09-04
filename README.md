# Work Pulse

Flutter workforce monitoring app for field jobs, standby attendance, leave, and live location. Three roles: **Admin** (platform), **Client** (tenant), and **User** (field staff).

Login is **Supabase Auth** (`auth.users`) with email or username plus password. Application data lives in `public.profiles` (no passwords) and `public.clients` (tenant org). There is no Google/Apple login and no self-registration.

## Setup (fresh project)

1. Create a project at [supabase.com](https://supabase.com).
2. Put `SUPABASE_URL` and `SUPABASE_ANON_KEY` in `assets/config.env`.
3. **SQL Editor:** paste and run the whole [`supabase/schema.sql`](supabase/schema.sql) file.
   - Optional: run [`supabase/reset.sql`](supabase/reset.sql) first only if you also want every Auth login deleted.
4. **Authentication → Providers → Email**: enable Email. Turn **Confirm email** OFF.
5. **Authentication → Attack Protection**: turn **Leaked password protection** OFF while testing.
6. **Authentication → Users → Add user** — create **only the Admin** (Auto Confirm on):
   - Email: `admin@workpulse.com` (or your email)
   - Password: choose one and keep it
7. **SQL Editor:** run [`supabase/run_insert_data.sql`](supabase/run_insert_data.sql) (promotes that Auth user to Admin). If you used a different email, edit `v_email` in that file first.
8. Deploy the function that creates clients and field users from the app:

```bash
supabase functions deploy admin-users
```

9. Run the app, log in as admin, **log out and log in again** so the admin role is in the JWT.

```bash
flutter pub get
flutter run
```

10. In the app:
    - **Admin → Clients → Add** — creates the Client login (Auth + profile). Give them the username/password you typed.
    - Log in as that Client (or stay as Admin) → **Users → Add** — creates the field User login. No Auth dashboard needed.

Do **not** run the old files under `supabase/migrations/` (002–008). They are obsolete; see [`supabase/migrations/README.md`](supabase/migrations/README.md).

## Tables

- **roles** — admin, client, user
- **clients** — tenant organizations
- **profiles** — one row per Auth login (`id` → `auth.users`). Role and `client_id` tenant. No passwords.
- **companies** — owned by a client tenant
- **jobs** — statuses: pending (assigned), accepted (en route / UI **Enroute**), checked_in, pending_review (checked out), completed / declined / cancelled
- **job_checkouts** / **job_checkout_photos** — checkout signature + photos (app sends 5; DB allows up to 6)
- **job_status_history** — status change audit
- **attendance** — standby in/out events
- **leaves** — full / first_half / second_half
- **location_pings** — GPS history
- **user_live_locations** — one live pin per user (Live Map)

## Roles

**Admin:** all screens plus **Clients**. Sees all tenants. When adding a field user, must pick a client.

**Client:** same screens except Clients. Sees only their tenant. Adding a user assigns that user to the current tenant.

**User:** job summary, standby in/out, accept/reject/check-in/check-out (5 photos + signature), 2-month attendance, leave requests. Login with the username or email the client created.
