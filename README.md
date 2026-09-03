# Work Pulse

Flutter workforce monitoring app for field jobs, standby attendance, leave, and live location. Three roles: **Admin** (platform), **Client** (tenant), and **User** (field staff).

There is no Google/Apple login and no self-registration. Accounts are created by a parent role; everyone logs in with email and password.

## Setup

1. Create a project at [supabase.com](https://supabase.com).
2. Put `SUPABASE_URL` and `SUPABASE_ANON_KEY` (anon public) in `assets/config.env` or `assets/config.env.example`.
3. In **SQL Editor**, paste and run the whole [`supabase/schema.sql`](supabase/schema.sql) file. If the original schema already ran, run [`supabase/migrations/002_clients.sql`](supabase/migrations/002_clients.sql) instead.
4. **Authentication → Providers → Email**: enable Email. Turn **Confirm email** OFF so new users can log in immediately.
5. **Authentication → Users → Add user**: create the platform admin (email + password, Auto Confirm User on).
6. In SQL Editor run (use the admin email):

```sql
select public.promote_admin('admin@company.com');
```

Then log in once in the app, **log out, and log in again** so the admin role is in the session.

7. Deploy the function used to create clients and field users:

```bash
supabase functions deploy admin-users
```

8. Run the app:

```bash
flutter pub get
flutter run
```

Then: log in as admin → add a client → log in as that client → add a field user → that user can log in.

## Roles

**Admin:** same screens as Client, plus a **Clients** list. Sees all data. When adding a field user, must pick a client.

**Client:** dashboard, users, companies, jobs, leave, reports, live map. Sees only their own data. Adding a user assigns that user to the current client.

**User:** job summary, standby in/out, accept/reject/check-in/check-out (5 photos + signature), 2-month attendance, leave requests.
