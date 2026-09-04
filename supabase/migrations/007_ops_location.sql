-- 007: Tenant id on ops tables, live location row per user, ping+upsert RPC.

alter table public.attendance
  add column if not exists client_id uuid references public.clients(id) on delete set null;
alter table public.leaves
  add column if not exists client_id uuid references public.clients(id) on delete set null;
alter table public.location_pings
  add column if not exists client_id uuid references public.clients(id) on delete set null;

update public.attendance a
set client_id = p.client_id
from public.profiles p
where p.id = a.user_id and a.client_id is null;

update public.leaves l
set client_id = p.client_id
from public.profiles p
where p.id = l.user_id and l.client_id is null;

update public.location_pings lp
set client_id = p.client_id
from public.profiles p
where p.id = lp.user_id and lp.client_id is null;

create index if not exists attendance_client_id_idx on public.attendance (client_id);
create index if not exists leaves_client_id_idx on public.leaves (client_id);
create index if not exists location_pings_client_id_idx on public.location_pings (client_id);

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

drop trigger if exists attendance_set_client_id on public.attendance;
create trigger attendance_set_client_id
before insert on public.attendance
for each row execute function public.set_row_client_id_from_user();

drop trigger if exists leaves_set_client_id on public.leaves;
create trigger leaves_set_client_id
before insert on public.leaves
for each row execute function public.set_row_client_id_from_user();

drop trigger if exists location_pings_set_client_id on public.location_pings;
create trigger location_pings_set_client_id
before insert on public.location_pings
for each row execute function public.set_row_client_id_from_user();

create table if not exists public.user_live_locations (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  client_id uuid references public.clients(id) on delete set null,
  lat double precision not null,
  lng double precision not null,
  accuracy double precision,
  context text not null default 'standby' check (context in ('standby', 'job')),
  job_id uuid references public.jobs(id) on delete set null,
  recorded_at timestamptz not null default now()
);

create index if not exists user_live_locations_client_idx on public.user_live_locations (client_id);
create index if not exists user_live_locations_recorded_idx on public.user_live_locations (recorded_at desc);

insert into public.user_live_locations (user_id, client_id, lat, lng, recorded_at)
select p.id, p.client_id, p.last_lat, p.last_lng, coalesce(p.last_location_at, now())
from public.profiles p
where p.last_lat is not null and p.last_lng is not null
on conflict (user_id) do nothing;

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

grant execute on function public.update_live_location(
  double precision, double precision, double precision, text, uuid
) to authenticated, service_role;
