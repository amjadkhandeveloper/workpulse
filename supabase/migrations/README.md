# Obsolete migrations

These files (`002`–`008`) were incremental upgrades for older databases that used
`public.users` and a different tenant model.

**Do not run them** on a fresh project.

Use instead:

1. [`../schema.sql`](../schema.sql) — single drop-and-create schema
2. [`../run_insert_data.sql`](../run_insert_data.sql) — demo profiles/company/job after Auth users exist
