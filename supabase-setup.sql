-- 8-Week Challenge — Supabase schema setup (multi-cohort version)
-- Run this in the Supabase SQL Editor after creating your project.
-- This script is idempotent and can be re-run safely.

-- ---------- helper function: is the current user an admin? ----------

create or replace function public.is_admin(user_id uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
  select coalesce((select is_admin from public.profiles where id = user_id), false);
$$;

-- ---------- tables ----------

create table if not exists public.challenges (
  id uuid default gen_random_uuid() primary key,
  name text not null,
  baseline_opens_at timestamptz not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  locked boolean not null default false,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  constraint valid_dates check (baseline_opens_at < starts_at and starts_at < ends_at)
);

-- Automatically compute baseline (48h before start) and end (8 weeks after start).
create or replace function public.set_challenge_dates()
returns trigger as $$
begin
  new.baseline_opens_at := new.starts_at - interval '48 hours';
  new.ends_at := new.starts_at + interval '56 days';
  return new;
end;
$$ language plpgsql;

drop trigger if exists set_challenge_dates on public.challenges;
create trigger set_challenge_dates
  before insert or update on public.challenges
  for each row execute function public.set_challenge_dates();

-- ---------- helper function: current challenge week ----------
-- Returns the active week number (0 during baseline, 1-8 during challenge, null after end).

create or replace function public.current_challenge_week(challenge_row public.challenges)
returns integer
language sql
stable
as $$
  select case
    when challenge_row is null then null
    when now() < challenge_row.baseline_opens_at then null
    when now() < challenge_row.starts_at then 0
    when now() > challenge_row.ends_at then null
    else least(8, greatest(1, floor(extract(epoch from (now() - challenge_row.starts_at)) / 86400.0 / 7)::integer))
  end;
$$;

create table if not exists public.profiles (
  id uuid references auth.users on delete cascade primary key,
  email text not null,
  full_name text not null,
  phone text,
  tier text not null check (tier in ('standard', 'f2f')),
  paid boolean not null default false,
  is_admin boolean not null default false,
  challenge_id uuid references public.challenges on delete set null,
  starting_weight_kg numeric check (starting_weight_kg > 0),
  age integer check (age between 16 and 99),
  created_at timestamptz not null default now()
);

create table if not exists public.checkins (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users on delete cascade not null,
  challenge_id uuid references public.challenges on delete cascade not null,
  week integer not null check (week between 0 and 8),
  weight_kg numeric not null check (weight_kg > 0),
  photo_path text,
  workouts_completed integer not null default 0 check (workouts_completed between 0 and 7),
  energy_rating integer check (energy_rating between 1 and 5),
  adherence_rating integer check (adherence_rating between 1 and 5),
  notes text,
  created_at timestamptz not null default now(),
  unique(user_id, challenge_id, week)
);

create table if not exists public.progress_photos (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users on delete cascade not null,
  challenge_id uuid references public.challenges on delete cascade,
  photo_path text not null,
  created_at timestamptz not null default now()
);

-- ---------- indexes ----------

create index if not exists idx_checkins_user_id on public.checkins(user_id);
create index if not exists idx_checkins_challenge_id on public.checkins(challenge_id);
create index if not exists idx_checkins_week on public.checkins(week);
create index if not exists idx_progress_photos_user_id on public.progress_photos(user_id);
create index if not exists idx_progress_photos_challenge_id on public.progress_photos(challenge_id);

-- ---------- RLS enablement ----------

alter table public.challenges enable row level security;
alter table public.profiles enable row level security;
alter table public.checkins enable row level security;
alter table public.progress_photos enable row level security;

-- ---------- challenge policies ----------

drop policy if exists "Admins can manage challenges" on public.challenges;
drop policy if exists "Authenticated users can read challenges" on public.challenges;
drop policy if exists "Anyone can read challenges" on public.challenges;

create policy "Authenticated users can read challenges"
  on public.challenges
  for select
  to authenticated
  using (true);

-- Public visitors can see challenge names and dates for leaderboard selection.
create policy "Anyone can read challenges"
  on public.challenges
  for select
  to anon
  using (true);

-- Only admins can create/update/delete challenges.
create policy "Admins can manage challenges"
  on public.challenges
  for all
  to authenticated
  using (public.is_admin(auth.uid()))
  with check (public.is_admin(auth.uid()));

-- ---------- profile policies ----------

drop policy if exists "Users can read own profile" on public.profiles;
drop policy if exists "Users can update own profile" on public.profiles;
drop policy if exists "Admins can manage profiles" on public.profiles;

create policy "Users can read own profile"
  on public.profiles
  for select
  to authenticated
  using (auth.uid() = id);

create policy "Users can update own profile"
  on public.profiles
  for update
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

create policy "Admins can manage profiles"
  on public.profiles
  for all
  to authenticated
  using (public.is_admin(auth.uid()))
  with check (public.is_admin(auth.uid()));

-- ---------- checkin policies ----------

drop policy if exists "Users can read own checkins" on public.checkins;
drop policy if exists "Users can insert own checkins" on public.checkins;
drop policy if exists "Admins can manage checkins" on public.checkins;

create policy "Users can read own checkins"
  on public.checkins
  for select
  to authenticated
  using (auth.uid() = user_id);

create policy "Users can insert own checkins"
  on public.checkins
  for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "Admins can manage checkins"
  on public.checkins
  for all
  to authenticated
  using (public.is_admin(auth.uid()))
  with check (public.is_admin(auth.uid()));

-- ---------- progress photo policies ----------

drop policy if exists "Users can read own progress photos" on public.progress_photos;
drop policy if exists "Users can insert own progress photos" on public.progress_photos;
drop policy if exists "Admins can manage progress photos" on public.progress_photos;

create policy "Users can read own progress photos"
  on public.progress_photos
  for select
  to authenticated
  using (auth.uid() = user_id);

create policy "Users can insert own progress photos"
  on public.progress_photos
  for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "Admins can manage progress photos"
  on public.progress_photos
  for all
  to authenticated
  using (public.is_admin(auth.uid()))
  with check (public.is_admin(auth.uid()));

-- ---------- trigger: enforce challenge lifecycle rules ----------

create or replace function public.enforce_challenge_rules()
returns trigger as $$
declare
  challenge_record public.challenges;
  claims json;
  role text;
  active_week integer;
  current_existing public.checkins;
begin
  claims := coalesce(current_setting('request.jwt.claims', true), '{}')::json;
  role := claims->>'role';

  -- Admins and service-role can bypass lifecycle rules.
  if role = 'service_role' or public.is_admin(auth.uid()) then
    return new;
  end if;

  select * into challenge_record from public.challenges where id = new.challenge_id;
  if challenge_record is null then
    raise exception 'Challenge not found.';
  end if;

  if challenge_record.locked then
    raise exception 'This challenge is locked. No more check-ins can be submitted.';
  end if;

  active_week := public.current_challenge_week(challenge_record);

  if active_week is null then
    if now() < challenge_record.baseline_opens_at then
      raise exception 'Baseline check-in opens at %.', challenge_record.baseline_opens_at;
    else
      raise exception 'This challenge has ended. No more check-ins can be submitted.';
    end if;
  end if;

  if new.week != active_week then
    raise exception 'Only Week % is open for check-ins right now.', active_week;
  end if;

  -- Prevent editing existing check-ins.
  select * into current_existing from public.checkins
  where user_id = new.user_id and challenge_id = new.challenge_id and week = new.week;
  if current_existing is not null then
    raise exception 'Week % has already been submitted for this challenge and cannot be edited.', new.week;
  end if;

  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists enforce_challenge_rules on public.checkins;
create trigger enforce_challenge_rules
  before insert or update on public.checkins
  for each row execute function public.enforce_challenge_rules();

-- ---------- trigger: auto-create profile on signup ----------

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
-- Returns a safe leaderboard payload for a specific challenge.

create or replace function public.get_leaderboard(target_challenge_id uuid)
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
    where c.challenge_id = target_challenge_id
    order by c.user_id, c.week desc
  ),
  baseline as (
    select
      c.user_id,
      c.weight_kg as baseline_weight
    from public.checkins c
    where c.challenge_id = target_challenge_id and c.week = 0
  ),
  counts as (
    select
      c.user_id,
      count(*) filter (where c.week > 0) as weeks_logged,
      count(*) filter (where c.week in (0,4,8) and c.photo_path is not null) as verified_weigh_ins
    from public.checkins c
    where c.challenge_id = target_challenge_id
    group by c.user_id
  )
  select
    p.id as user_id,
    p.full_name,
    case
      when p.full_name is null then '?'
      else regexp_replace(p.full_name, '^([^ ]+).*', '\1') || ' ' || left(coalesce(split_part(p.full_name, ' ', 2), ''), 1)
    end as display_name,
    case
      when coalesce(b.baseline_weight, p.starting_weight_kg) is null
           or coalesce(b.baseline_weight, p.starting_weight_kg) = 0
           or l.latest_weight is null then 0
      else ((coalesce(b.baseline_weight, p.starting_weight_kg) - l.latest_weight)
            / coalesce(b.baseline_weight, p.starting_weight_kg)) * 100
    end as pct_lost,
    coalesce(c.weeks_logged, 0) as weeks_logged,
    coalesce(c.verified_weigh_ins, 0) as verified_weigh_ins
  from public.profiles p
  left join latest_checkin l on l.user_id = p.id
  left join baseline b on b.user_id = p.id
  left join counts c on c.user_id = p.id
  where p.paid = true
    and p.challenge_id = target_challenge_id
  order by pct_lost desc;
end;
$$;

grant execute on function public.get_leaderboard(uuid) to anon;
grant execute on function public.get_leaderboard(uuid) to authenticated;

-- ---------- storage buckets ----------

insert into storage.buckets (id, name, public)
values ('weighin-photos', 'weighin-photos', false)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('progress-photos', 'progress-photos', false)
on conflict (id) do nothing;

-- Drop and recreate weigh-in photo storage policies.
drop policy if exists "Users can upload own weighin photos" on storage.objects;
drop policy if exists "Users can read own weighin photos" on storage.objects;
drop policy if exists "Admins can read all weighin photos" on storage.objects;

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

create policy "Admins can read all weighin photos"
  on storage.objects
  for select
  to authenticated
  using (bucket_id = 'weighin-photos' and public.is_admin(auth.uid()));

-- Drop and recreate progress photo storage policies.
drop policy if exists "Users can upload own progress photos" on storage.objects;
drop policy if exists "Users can read own progress photos" on storage.objects;
drop policy if exists "Admins can read all progress photos" on storage.objects;

create policy "Users can upload own progress photos"
  on storage.objects
  for insert
  to authenticated
  with check (bucket_id = 'progress-photos' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "Users can read own progress photos"
  on storage.objects
  for select
  to authenticated
  using (bucket_id = 'progress-photos' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "Admins can read all progress photos"
  on storage.objects
  for select
  to authenticated
  using (bucket_id = 'progress-photos' and public.is_admin(auth.uid()));

-- ---------- chat / community feed ----------
-- A lightweight real-time chat feed scoped to each challenge cohort.

create table if not exists public.chat_messages (
  id uuid default gen_random_uuid() primary key,
  challenge_id uuid references public.challenges on delete cascade not null,
  user_id uuid references auth.users on delete cascade not null,
  content text not null check (length(content) between 1 and 500),
  is_pinned boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists idx_chat_messages_challenge on public.chat_messages(challenge_id, created_at desc);

-- Add a relationship to public.profiles so Supabase can join sender names in queries.
-- user_id already references auth.users; this adds a second FK to profiles(id).
alter table public.chat_messages
  drop constraint if exists chat_messages_user_id_profiles_fkey;

alter table public.chat_messages
  add constraint chat_messages_user_id_profiles_fkey
  foreign key (user_id) references public.profiles(id)
  on delete cascade;

alter table public.chat_messages enable row level security;

drop policy if exists "Users can read cohort chat" on public.chat_messages;
drop policy if exists "Users can post in cohort chat" on public.chat_messages;
drop policy if exists "Admins can manage chat messages" on public.chat_messages;

-- Users can read messages in their own cohort only.
create policy "Users can read cohort chat"
  on public.chat_messages
  for select
  to authenticated
  using (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.challenge_id = chat_messages.challenge_id
    )
  );

-- Users can post to their own cohort only.
create policy "Users can post in cohort chat"
  on public.chat_messages
  for insert
  to authenticated
  with check (
    auth.uid() = user_id and
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.challenge_id = chat_messages.challenge_id
    )
  );

-- Only admins can delete or pin messages.
create policy "Admins can manage chat messages"
  on public.chat_messages
  for all
  to authenticated
  using (public.is_admin(auth.uid()))
  with check (public.is_admin(auth.uid()));

-- Enable realtime for chat messages.
begin;
  drop publication if exists supabase_realtime;
  create publication supabase_realtime;
commit;

alter publication supabase_realtime add table public.chat_messages;

-- ---------- competition settings ----------
-- Public-facing content and pricing managed by admins.

create table if not exists public.competition_settings (
  id integer primary key default 1 check (id = 1),
  updated_at timestamptz not null default now(),
  challenge_name text not null default '8-Week Challenge',
  headline text not null default 'Show up. Log it. Win the transformation.',
  subheadline text not null default 'An elite 8-week accountability experience.',
  eyebrow text not null default 'Private Coaching Challenge · 8 Weeks · Track in KG',
  intro_video_url text,
  prize_type text not null default 'cash' check (prize_type in ('cash', 'physical', 'both')),
  prize_pool numeric not null default 2000,
  prize_first_cash numeric not null default 1000,
  prize_second_cash numeric not null default 600,
  prize_third_cash numeric not null default 400,
  prize_hero_label text,
  prize_first_text text,
  prize_second_text text,
  prize_third_text text,
  standard_price numeric not null default 280,
  standard_stripe_link text not null default 'https://buy.stripe.com/28E28s92p1Zy8my6oY5os0x',
  f2f_price numeric not null default 792,
  f2f_stripe_link text not null default 'https://buy.stripe.com/dRmeVebax33C1Ya5kU5os0B'
);

-- Migration: add per-place cash columns if they don't exist and seed existing rows.
alter table public.competition_settings
  add column if not exists prize_first_cash numeric not null default 1000,
  add column if not exists prize_second_cash numeric not null default 600,
  add column if not exists prize_third_cash numeric not null default 400,
  add column if not exists prize_hero_label text;

update public.competition_settings
set
  prize_first_cash = coalesce(prize_first_cash, 1000),
  prize_second_cash = coalesce(prize_second_cash, 600),
  prize_third_cash = coalesce(prize_third_cash, 400)
where id = 1;

-- Allow 'both' as a prize display mode and keep existing rows as 'cash'.
alter table public.competition_settings
  drop constraint if exists competition_settings_prize_type_check;

alter table public.competition_settings
  add constraint competition_settings_prize_type_check
  check (prize_type in ('cash', 'physical', 'both'));

alter table public.competition_settings enable row level security;

drop policy if exists "Anyone can read competition settings" on public.competition_settings;
drop policy if exists "Anyone can read competition settings authenticated" on public.competition_settings;
drop policy if exists "Admins can manage competition settings" on public.competition_settings;

create policy "Anyone can read competition settings"
  on public.competition_settings
  for select
  to anon
  using (true);

create policy "Anyone can read competition settings authenticated"
  on public.competition_settings
  for select
  to authenticated
  using (true);

create policy "Admins can manage competition settings"
  on public.competition_settings
  for all
  to authenticated
  using (public.is_admin(auth.uid()))
  with check (public.is_admin(auth.uid()));

-- Seed the single row on first run.
insert into public.competition_settings (id)
values (1)
on conflict (id) do nothing;

-- ---------- clean up legacy single-cohort challenge_settings table ----------

drop table if exists public.challenge_settings cascade;

-- ---------- initial admin setup ----------
-- After deploying, create your own admin account through signup, then run:
-- update public.profiles set is_admin = true where id = 'YOUR_USER_ID';
