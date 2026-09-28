-- AskMario Commission Tracker — initial schema
-- Run this in Supabase: SQL Editor → New query → paste → Run.

-- ─────────────────────────────────────────────────────────────
-- Profiles (one per auth user). New users are unapproved until
-- an admin flips `approved` to true in the Table Editor.
-- ─────────────────────────────────────────────────────────────
create table public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  email       text not null unique,
  full_name   text,
  role        text not null default 'member' check (role in ('admin', 'member')),
  approved    boolean not null default false,
  created_at  timestamptz not null default now()
);

-- Only @askmario.co.za accounts may sign up at all.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if lower(new.email) not like '%@askmario.co.za' then
    raise exception 'Only @askmario.co.za accounts may sign up';
  end if;

  insert into public.profiles (id, email, full_name)
  values (
    new.id,
    lower(new.email),
    coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name')
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Helpers used by RLS policies (security definer avoids policy recursion).
create or replace function public.is_approved()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select approved from profiles where id = auth.uid()), false);
$$;

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select approved and role = 'admin' from profiles where id = auth.uid()), false);
$$;

-- ─────────────────────────────────────────────────────────────
-- Projects
-- ─────────────────────────────────────────────────────────────
create table public.projects (
  id              uuid primary key default gen_random_uuid(),
  name            text not null,
  client          text,
  price           numeric(12, 2) not null default 0 check (price >= 0),        -- ZAR charged to client
  commission_pct  numeric(5, 2)  not null default 0 check (commission_pct between 0 and 100),
  start_date      date not null,
  deadline        date not null,
  completed_date  date,
  status          text not null default 'lead'
                  check (status in ('lead', 'active', 'on_hold', 'completed', 'paid', 'cancelled')),
  overdue_waived  boolean not null default false,  -- admin-only override of the overdue rule
  notes           text,
  created_by      uuid references public.profiles (id) default auth.uid(),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  check (deadline >= start_date)
);

create table public.project_members (
  project_id  uuid not null references public.projects (id) on delete cascade,
  user_id     uuid not null references public.profiles (id) on delete cascade,
  split_pct   numeric(5, 2) not null check (split_pct > 0 and split_pct <= 100),
  primary key (project_id, user_id)
);

-- Audit log of deadline changes.
create table public.deadline_changes (
  id            bigint generated always as identity primary key,
  project_id    uuid not null references public.projects (id) on delete cascade,
  old_deadline  date not null,
  new_deadline  date not null,
  changed_by    uuid references public.profiles (id),
  changed_at    timestamptz not null default now()
);

create or replace function public.projects_before_update()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  new.updated_at := now();

  if new.status in ('completed', 'paid') and new.completed_date is null then
    new.completed_date := current_date;
  end if;

  if new.overdue_waived is distinct from old.overdue_waived and not is_admin() then
    raise exception 'Only admins can waive the overdue rule';
  end if;

  if new.deadline is distinct from old.deadline then
    insert into deadline_changes (project_id, old_deadline, new_deadline, changed_by)
    values (old.id, old.deadline, new.deadline, auth.uid());
  end if;
  return new;
end;
$$;

create trigger projects_before_update
  before update on public.projects
  for each row execute function public.projects_before_update();

create or replace function public.projects_before_insert()
returns trigger language plpgsql as $$
begin
  if new.overdue_waived and not public.is_admin() then
    raise exception 'Only admins can waive the overdue rule';
  end if;
  if new.status in ('completed', 'paid') and new.completed_date is null then
    new.completed_date := current_date;
  end if;
  return new;
end;
$$;

create trigger projects_before_insert
  before insert on public.projects
  for each row execute function public.projects_before_insert();

-- Is the current user on this project?
create or replace function public.is_project_member(p_project uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from project_members where project_id = p_project and user_id = auth.uid());
$$;

-- ─────────────────────────────────────────────────────────────
-- Save a project + its splits atomically. Splits must total 100%.
-- p_splits: [{"user_id": "...", "split_pct": 50}, ...]
-- ─────────────────────────────────────────────────────────────
create or replace function public.save_project(p_id uuid, p_project jsonb, p_splits jsonb)
returns uuid
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_id uuid := p_id;
  v_total numeric;
begin
  if not is_approved() then
    raise exception 'Your account has not been approved yet';
  end if;

  select coalesce(sum((s ->> 'split_pct')::numeric), 0) into v_total
  from jsonb_array_elements(p_splits) s;

  if jsonb_array_length(p_splits) = 0 or v_total <> 100 then
    raise exception 'Commission splits must add up to exactly 100%% (currently %)', v_total;
  end if;

  if v_id is null then
    insert into projects (name, client, price, commission_pct, start_date, deadline,
                          completed_date, status, overdue_waived, notes)
    values (
      p_project ->> 'name',
      nullif(p_project ->> 'client', ''),
      (p_project ->> 'price')::numeric,
      (p_project ->> 'commission_pct')::numeric,
      (p_project ->> 'start_date')::date,
      (p_project ->> 'deadline')::date,
      nullif(p_project ->> 'completed_date', '')::date,
      p_project ->> 'status',
      coalesce((p_project ->> 'overdue_waived')::boolean, false),
      nullif(p_project ->> 'notes', '')
    )
    returning id into v_id;
  else
    update projects set
      name           = p_project ->> 'name',
      client         = nullif(p_project ->> 'client', ''),
      price          = (p_project ->> 'price')::numeric,
      commission_pct = (p_project ->> 'commission_pct')::numeric,
      start_date     = (p_project ->> 'start_date')::date,
      deadline       = (p_project ->> 'deadline')::date,
      completed_date = nullif(p_project ->> 'completed_date', '')::date,
      status         = p_project ->> 'status',
      overdue_waived = coalesce((p_project ->> 'overdue_waived')::boolean, overdue_waived),
      notes          = nullif(p_project ->> 'notes', '')
    where id = v_id;

    if not found then
      raise exception 'Project not found or you do not have access to it';
    end if;

  end if;

  -- Upsert first, then remove dropped people, so the editor keeps access mid-save.
  insert into project_members (project_id, user_id, split_pct)
  select v_id, (s ->> 'user_id')::uuid, (s ->> 'split_pct')::numeric
  from jsonb_array_elements(p_splits) s
  on conflict (project_id, user_id) do update set split_pct = excluded.split_pct;

  delete from project_members
  where project_id = v_id
    and user_id not in (select (s ->> 'user_id')::uuid from jsonb_array_elements(p_splits) s);

  return v_id;
end;
$$;

-- ─────────────────────────────────────────────────────────────
-- Row Level Security
-- ─────────────────────────────────────────────────────────────
alter table public.profiles         enable row level security;
alter table public.projects         enable row level security;
alter table public.project_members  enable row level security;
alter table public.deadline_changes enable row level security;

-- Profiles: approved users can see everyone (needed to pick colleagues);
-- everyone can see their own row (to know they're pending).
create policy "profiles: read own" on public.profiles
  for select using (id = auth.uid());
create policy "profiles: approved read all" on public.profiles
  for select using (is_approved());
create policy "profiles: update own name" on public.profiles
  for update using (id = auth.uid()) with check (id = auth.uid());
create policy "profiles: admin manage" on public.profiles
  for all using (is_admin()) with check (is_admin());

-- Stop members from promoting/approving themselves via "update own name".
create or replace function public.profiles_guard()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if (new.role is distinct from old.role or new.approved is distinct from old.approved
      or new.email is distinct from old.email)
     -- auth.uid() is null in the SQL editor / service role, so manual approval still works.
     and auth.uid() is not null and not is_admin() then
    raise exception 'Only admins can change role, approval or email';
  end if;
  return new;
end;
$$;
create trigger profiles_guard before update on public.profiles
  for each row execute function public.profiles_guard();

-- Projects: admins see all; members see projects they're on or created.
create policy "projects: read" on public.projects
  for select using (is_admin() or (is_approved() and (is_project_member(id) or created_by = auth.uid())));
create policy "projects: insert" on public.projects
  for insert with check (is_approved());
create policy "projects: update" on public.projects
  for update using (is_admin() or (is_approved() and (is_project_member(id) or created_by = auth.uid())));
create policy "projects: admin delete" on public.projects
  for delete using (is_admin());

-- Splits: visible to everyone on the project; editable by anyone who can edit the project.
create policy "members: read" on public.project_members
  for select using (
    is_admin() or (is_approved() and exists (
      select 1 from projects p where p.id = project_id
      and (is_project_member(p.id) or p.created_by = auth.uid())))
  );
create policy "members: write" on public.project_members
  for all using (
    is_admin() or (is_approved() and exists (
      select 1 from projects p where p.id = project_id
      and (is_project_member(p.id) or p.created_by = auth.uid())))
  ) with check (
    is_admin() or (is_approved() and exists (
      select 1 from projects p where p.id = project_id
      and (is_project_member(p.id) or p.created_by = auth.uid())))
  );

create policy "deadline log: read" on public.deadline_changes
  for select using (
    is_admin() or (is_approved() and exists (
      select 1 from projects p where p.id = project_id
      and (is_project_member(p.id) or p.created_by = auth.uid())))
  );

-- ─────────────────────────────────────────────────────────────
-- Views with commission maths (respect RLS via security_invoker).
--
-- Overdue rule: no commission if the project was completed after
-- its deadline, or is still open past its deadline — unless an
-- admin has waived it. Cancelled projects earn nothing.
-- ─────────────────────────────────────────────────────────────
create or replace view public.project_summary
with (security_invoker = true) as
select
  p.*,
  round(p.price * p.commission_pct / 100, 2) as gross_commission,
  case
    when p.overdue_waived then false
    when p.completed_date is not null then p.completed_date > p.deadline
    when p.status in ('completed', 'paid', 'cancelled') then false
    else current_date > p.deadline
  end as is_overdue,
  (p.completed_date is null
    and p.status not in ('completed', 'paid', 'cancelled')
    and not p.overdue_waived
    and current_date <= p.deadline
    and p.deadline - current_date <= 7) as due_soon
from public.projects p;

create or replace view public.project_payouts
with (security_invoker = true) as
select
  s.id as project_id,
  s.name as project_name,
  s.status,
  s.is_overdue,
  m.user_id,
  pr.full_name,
  pr.email,
  m.split_pct,
  case
    when s.is_overdue or s.status = 'cancelled' then 0
    else round(s.gross_commission * m.split_pct / 100, 2)
  end as payout
from public.project_summary s
join public.project_members m on m.project_id = s.id
join public.profiles pr on pr.id = m.user_id;

grant select on public.project_summary, public.project_payouts to authenticated;
grant execute on function public.save_project(uuid, jsonb, jsonb) to authenticated;
