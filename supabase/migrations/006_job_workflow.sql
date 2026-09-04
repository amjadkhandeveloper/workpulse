-- 006: Job status history, checkout (signature + photos), workflow RPCs.
-- Status strings stay: pending, accepted, declined, checked_in, pending_review, completed, cancelled.

alter table public.jobs
  add column if not exists updated_at timestamptz not null default now();

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists jobs_touch_updated_at on public.jobs;
create trigger jobs_touch_updated_at
before update on public.jobs
for each row execute function public.touch_updated_at();

create table if not exists public.job_status_history (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.jobs(id) on delete cascade,
  from_status text,
  to_status text not null,
  changed_by uuid references public.profiles(id) on delete set null,
  note text,
  created_at timestamptz not null default now()
);

create index if not exists job_status_history_job_idx
  on public.job_status_history (job_id, created_at desc);

create table if not exists public.job_checkouts (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null unique references public.jobs(id) on delete cascade,
  note text,
  signature_path text,
  submitted_by uuid references public.profiles(id) on delete set null,
  submitted_at timestamptz not null default now()
);

create table if not exists public.job_checkout_photos (
  id uuid primary key default gen_random_uuid(),
  checkout_id uuid not null references public.job_checkouts(id) on delete cascade,
  storage_path text not null,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists job_checkout_photos_checkout_idx
  on public.job_checkout_photos (checkout_id, sort_order);

create or replace function public.job_checkout_photos_cap()
returns trigger
language plpgsql
as $$
declare
  n int;
begin
  select count(*) into n
  from public.job_checkout_photos
  where checkout_id = new.checkout_id;
  if n > 6 then
    raise exception 'A checkout can have at most 6 photos';
  end if;
  return new;
end;
$$;

drop trigger if exists job_checkout_photos_cap on public.job_checkout_photos;
create trigger job_checkout_photos_cap
after insert on public.job_checkout_photos
for each row execute function public.job_checkout_photos_cap();

-- Same-tenant company and assignee
create or replace function public.jobs_enforce_tenant()
returns trigger
language plpgsql
as $$
declare
  company_client uuid;
  assignee_client uuid;
  assignee_role text;
begin
  if new.company_id is not null then
    select client_id into company_client from public.companies where id = new.company_id;
    if company_client is distinct from new.client_id then
      raise exception 'Company belongs to a different client';
    end if;
  end if;
  if new.assigned_to is not null then
    select client_id, role into assignee_client, assignee_role
    from public.profiles where id = new.assigned_to;
    if assignee_role = 'user' and assignee_client is distinct from new.client_id then
      raise exception 'Assignee belongs to a different client';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists jobs_enforce_tenant on public.jobs;
create trigger jobs_enforce_tenant
before insert or update of company_id, assigned_to, client_id on public.jobs
for each row execute function public.jobs_enforce_tenant();

-- Backfill checkouts from job_proofs
insert into public.job_checkouts (job_id, note, signature_path, submitted_by, submitted_at)
select
  j.id,
  j.checkout_note,
  (
    select p.storage_path
    from public.job_proofs p
    where p.job_id = j.id and p.kind = 'signature'
    order by p.sort_order
    limit 1
  ),
  j.assigned_to,
  coalesce(j.reviewed_at, j.created_at)
from public.jobs j
where exists (select 1 from public.job_proofs p where p.job_id = j.id)
on conflict (job_id) do nothing;

insert into public.job_checkout_photos (checkout_id, storage_path, sort_order, created_at)
select c.id, p.storage_path, p.sort_order, p.created_at
from public.job_checkouts c
join public.job_proofs p on p.job_id = c.job_id and p.kind = 'photo'
where not exists (
  select 1 from public.job_checkout_photos existing
  where existing.checkout_id = c.id and existing.storage_path = p.storage_path
);

create or replace function public._record_job_status(
  p_job_id uuid,
  p_from text,
  p_to text,
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.job_status_history (job_id, from_status, to_status, changed_by, note)
  values (p_job_id, p_from, p_to, auth.uid(), p_note);
end;
$$;

create or replace function public.transition_job_status(
  p_job_id uuid,
  p_to_status text,
  p_note text default null,
  p_lat double precision default null,
  p_lng double precision default null
)
returns public.jobs
language plpgsql
security definer
set search_path = public
as $$
declare
  job public.jobs;
  from_status text;
  uid uuid := auth.uid();
  allowed boolean := false;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  if p_to_status not in (
    'pending', 'accepted', 'declined', 'checked_in', 'pending_review', 'completed', 'cancelled'
  ) then
    raise exception 'Invalid status';
  end if;
  if p_to_status in ('pending_review', 'completed') then
    raise exception 'Use submit_job_checkout or complete_job for this transition';
  end if;

  select * into job from public.jobs where id = p_job_id for update;
  if not found then
    raise exception 'Job not found';
  end if;
  from_status := job.status;

  if public.is_admin() or (public.is_client() and job.client_id = public.current_client_id()) then
    if p_to_status = 'cancelled' and from_status not in ('completed', 'cancelled') then
      allowed := true;
    end if;
  end if;

  if job.assigned_to = uid then
    if from_status = 'pending' and p_to_status in ('accepted', 'declined') then
      allowed := true;
    elsif from_status = 'accepted' and p_to_status = 'checked_in' then
      allowed := true;
    end if;
  end if;

  if not allowed then
    raise exception 'Not allowed to set status % from %', p_to_status, from_status;
  end if;

  update public.jobs
  set
    status = p_to_status,
    lat = coalesce(p_lat, lat),
    lng = coalesce(p_lng, lng)
  where id = p_job_id
  returning * into job;

  perform public._record_job_status(p_job_id, from_status, p_to_status, p_note);
  return job;
end;
$$;

create or replace function public.submit_job_checkout(
  p_job_id uuid,
  p_note text,
  p_signature_path text,
  p_photo_paths text[]
)
returns public.jobs
language plpgsql
security definer
set search_path = public
as $$
declare
  job public.jobs;
  v_checkout_id uuid;
  i int;
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  if p_signature_path is null or length(trim(p_signature_path)) = 0 then
    raise exception 'Signature is required';
  end if;
  if p_photo_paths is null or cardinality(p_photo_paths) < 1 or cardinality(p_photo_paths) > 6 then
    raise exception 'Checkout requires 1 to 6 photos';
  end if;

  select * into job from public.jobs where id = p_job_id for update;
  if not found then
    raise exception 'Job not found';
  end if;
  if job.assigned_to is distinct from uid then
    raise exception 'Only the assigned user can check out';
  end if;
  if job.status is distinct from 'checked_in' then
    raise exception 'Job must be checked in before checkout';
  end if;

  insert into public.job_checkouts (job_id, note, signature_path, submitted_by)
  values (p_job_id, p_note, p_signature_path, uid)
  on conflict (job_id) do update
    set note = excluded.note,
        signature_path = excluded.signature_path,
        submitted_by = excluded.submitted_by,
        submitted_at = now()
  returning id into v_checkout_id;

  delete from public.job_checkout_photos where checkout_id = v_checkout_id;
  for i in 1 .. cardinality(p_photo_paths) loop
    insert into public.job_checkout_photos (checkout_id, storage_path, sort_order)
    values (v_checkout_id, p_photo_paths[i], i - 1);
  end loop;

  update public.jobs
  set status = 'pending_review', checkout_note = p_note
  where id = p_job_id
  returning * into job;

  perform public._record_job_status(p_job_id, 'checked_in', 'pending_review', p_note);
  return job;
end;
$$;

create or replace function public.complete_job(p_job_id uuid)
returns public.jobs
language plpgsql
security definer
set search_path = public
as $$
declare
  job public.jobs;
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;

  select * into job from public.jobs where id = p_job_id for update;
  if not found then
    raise exception 'Job not found';
  end if;
  if job.status is distinct from 'pending_review' then
    raise exception 'Job is not awaiting review';
  end if;
  if not (
    public.is_admin()
    or (public.is_client() and job.client_id = public.current_client_id())
  ) then
    raise exception 'Only the client or admin can complete a job';
  end if;

  update public.jobs
  set
    status = 'completed',
    reviewed_by = uid,
    reviewed_at = now()
  where id = p_job_id
  returning * into job;

  perform public._record_job_status(p_job_id, 'pending_review', 'completed', null);
  return job;
end;
$$;

grant execute on function public.transition_job_status(uuid, text, text, double precision, double precision)
  to authenticated, service_role;
grant execute on function public.submit_job_checkout(uuid, text, text, text[])
  to authenticated, service_role;
grant execute on function public.complete_job(uuid)
  to authenticated, service_role;
grant execute on function public._record_job_status(uuid, text, text, text)
  to service_role;
