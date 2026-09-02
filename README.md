# Work Pulse

Flutter workforce monitoring app for field jobs, standby attendance, leave, and live location. Two roles: **Admin** and **User**.

## Setup

1. Create a project at [supabase.com](https://supabase.com).
2. Put your keys in `assets/config.env.example` (or copy it to `assets/config.env.example` and replace the placeholders):
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
3. In the Supabase SQL editor, run [`supabase/schema.sql`](supabase/schema.sql).
4. Deploy the admin user function:

```bash
supabase functions deploy admin-users
```

5. Install and run the app:

```bash
flutter pub get
flutter run
```

6. Create the first account from the Login screen (**Create account**), then promote it:

```sql
update public.profiles set role = 'admin' where email = 'you@example.com';
```

Confirm the email in Auth if your project requires it, or disable email confirmation in Authentication settings while testing.

## Roles

**Admin:** dashboard counts, user CRUD, companies, job assign/edit, review checkout proofs and mark complete, leave approval, job/attendance CSV reports, live map.

**User:** job summary dashboard, standby in/out, accept/reject/check-in/check-out, 5 photos + signature at checkout, 2-month attendance, leave (last 10 days through next 60 days, max 30 days, half or full day).

Standby rule: if a user is on standby with no active job and a job is assigned, they must **Standby out** before they can **Accept**.

## Live GPS

Location is shared while Standby In or while a job is accepted / checked in. Android uses a foreground notification. iOS uses background location modes already set in `Info.plist`.
