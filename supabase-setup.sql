-- 8-Week Challenge — Supabase schema setup
-- Run this in the Supabase SQL Editor after creating your project.

-- ---------- tables ----------

create table if not exists public.profiles (
  id uuid references auth.users on delete cascade primary key,
  email text not null,
  full_name text not null,
  phone text,
  tier text not null check (tier in ('standard', 'f2f')),
  paid boolean not null default false,
  is_admin boolean not null default false,
  starting_weight_kg numeric check (starting_weight_kg > 0),
  age integer check (age between 16 and 99),
  created_at timestamptz not null default now()
);

create table if not exists public.checkins (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users on delete cascade not null,
  week integer not null check (week between 0 and 8),
  weight_kg numeric not null check (weight_kg > 0),
  photo_path text,
  workouts_completed integer not null default 0 check (workouts_completed between 0 and 7),
  energy_rating integer check (energy_rating between 1 and 5),
  adherence_rating integer check (adherence_rating between 1 and 5),
  notes text,
  created_at timestamptz not null default now(),
  unique(user_id, week)
);

-- ---------- indexes ----------

create index if not exists idx_checkins_user_id on public.checkins(user_id);
create index if not exists idx_checkins_week on public.checkins(week);

-- ---------- RLS enablement ----------

alter table public.profiles enable row level security;
alter table public.checkins enable row level security;

-- ---------- profile policies ----------

-- Users can view their own profile.
create policy "Users can read own profile"
  on public.profiles
  for select
  to authenticated
  using (auth.uid() = id);

-- Users can update their own profile (phone, tier, starting weight before challenge begins).
create policy "Users can update own profile"
  on public.profiles
  for update
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- Admins can do anything with profiles.
create policy "Admins can manage profiles"
  on public.profiles
  for all
  to authenticated
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin = true))
  with check (exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin = true));

-- ---------- checkin policies ----------

-- Users can view their own check-ins.
create policy "Users can read own checkins"
  on public.checkins
  for select
  to authenticated
  using (auth.uid() = user_id);

-- Users can insert their own check-ins.
create policy "Users can insert own checkins"
  on public.checkins
  for insert
  to authenticated
  with check (auth.uid() = user_id);

-- Users can update their own check-ins (e.g. fix a typo the same week).
create policy "Users can update own checkins"
  on public.checkins
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Admins can do anything with check-ins.
create policy "Admins can manage checkins"
  on public.checkins
  for all
  to authenticated
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin = true))
  with check (exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin = true));

-- ---------- trigger: auto-create profile on signup ----------
-- This is a safety net in case client-side profile insertion fails.

create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, email, full_name, tier, starting_weight_kg, age)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'full_name', new.email),
    coalesce(new.raw_user_meta_data->>'tier', 'standard'),
    (new.raw_user_meta_data->>'starting_weight_kg')::numeric,
    (new.raw_user_meta_data->>'age')::integer
  )
  on conflict (id) do update set
    email = excluded.email,
    full_name = excluded.full_name,
    tier = excluded.tier,
    starting_weight_kg = coalesce(excluded.starting_weight_kg, profiles.starting_weight_kg),
    age = coalesce(excluded.age, profiles.age);
  return new;
end;
$$ language plpgsql security definer;

create or replace trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create or replace function public.handle_user_email_update()
returns trigger as $$
begin
  update public.profiles set email = new.email where id = new.id;
  return new;
end;
$$ language plpgsql security definer;

create or replace trigger on_auth_user_updated
  after update of email on auth.users
  for each row execute function public.handle_user_email_update();

-- ---------- public leaderboard function ----------
-- Returns a safe leaderboard payload accessible by anonymous/public users.

create or replace function public.get_leaderboard()
returns table (
  user_id uuid,
  full_name text,
  display_name text,
  pct_lost numeric,
  weeks_logged bigint,
  verified_weigh_ins bigint
)
language plpgsql
security definer
as $$
begin
  return query
  with latest_checkin as (
    select distinct on (c.user_id)
      c.user_id,
      c.weight_kg as latest_weight,
      c.week as latest_week
    from public.checkins c
    order by c.user_id, c.week desc
  ),
  baseline as (
    select
      c.user_id,
      c.weight_kg as baseline_weight
    from public.checkins c
    where c.week = 0
  ),
  counts as (
    select
      c.user_id,
      count(*) filter (where c.week > 0) as weeks_logged,
      count(*) filter (where c.week in (0,4,8) and c.photo_path is not null) as verified_weigh_ins
    from public.checkins c
    group by c.user_id
  )
  select
    p.id as user_id,
    p.full_name,
    -- Show first name + last initial for privacy.
    case
      when p.full_name is null then '?'
      else regexp_replace(p.full_name, '^([^ ]+).*', '\1') || ' ' || left(coalesce(split_part(p.full_name, ' ', 2), ''), 1)
    end as display_name,
    case
      when b.baseline_weight is null or b.baseline_weight = 0 or l.latest_weight is null then 0
      else ((b.baseline_weight - l.latest_weight) / b.baseline_weight) * 100
    end as pct_lost,
    coalesce(c.weeks_logged, 0) as weeks_logged,
    coalesce(c.verified_weigh_ins, 0) as verified_weigh_ins
  from public.profiles p
  left join latest_checkin l on l.user_id = p.id
  left join baseline b on b.user_id = p.id
  left join counts c on c.user_id = p.id
  where p.paid = true
  order by pct_lost desc;
end;
$$;

-- Allow public/anonymous access to the leaderboard function.
grant execute on function public.get_leaderboard() to anon;
grant execute on function public.get_leaderboard() to authenticated;

-- ---------- storage bucket for weigh-in photos ----------

insert into storage.buckets (id, name, public)
values ('weighin-photos', 'weighin-photos', false)
on conflict (id) do nothing;

-- Users can upload/view their own weigh-in photos.
create policy "Users can upload own weighin photos"
  on storage.objects
  for insert
  to authenticated
  with check (bucket_id = 'weighin-photos' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "Users can read own weighin photos"
  on storage.objects
  for select
  to authenticated
  using (bucket_id = 'weighin-photos' and (storage.foldername(name))[1] = auth.uid()::text);

-- Admins can read all weigh-in photos.
create policy "Admins can read all weighin photos"
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'weighin-photos' and
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin = true)
  );

-- ---------- initial admin setup ----------
-- After deploying, create your own admin account through signup, then run:
-- update public.profiles set is_admin = true where id = 'YOUR_USER_ID';
