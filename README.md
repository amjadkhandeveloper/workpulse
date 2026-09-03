# Work Pulse

Flutter workforce monitoring app for field jobs, standby attendance, leave, and live location. Two roles: **Admin** (client) and **User** (field staff).

There is no Google/Apple login and no self-registration. The client creates users in the app; staff only log in with that email and password.

## Setup

1. Create a project at [supabase.com](https://supabase.com).
2. Put `SUPABASE_URL` and `SUPABASE_ANON_KEY` (anon public) in `assets/config.env` or `assets/config.env.example`.
3. In **SQL Editor**, paste and run the whole [`supabase/schema.sql`](supabase/schema.sql) file.
4. **Authentication → Providers → Email**: enable Email. Turn **Confirm email** OFF so new users can log in immediately.
5. **Authentication → Users → Add user**: create the client admin (email + password, Auto Confirm User on).
6. In SQL Editor run (use the admin email):

```sql
select public.promote_admin('client@company.com');
```

Then log in once in the app, **log out, and log in again** so the admin role is in the session.

7. Deploy the function the admin app uses to create field users:

```bash
supabase functions deploy admin-users
```

8. Run the app:

```bash
flutter pub get
flutter run
```

## Roles

**Admin:** dashboard, add/edit/delete users, companies, jobs, review checkout proofs, leave approval, reports, live map.

**User:** job summary, standby in/out, accept/reject/check-in/check-out (5 photos + signature), 2-month attendance, leave requests.
