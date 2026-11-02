-- VARV. – simulations-race under Tävlingar
-- Kör hela filen en gång i Supabase: SQL Editor → New query → klistra in → Run.
-- Kräver profiler.sql och notiser.sql. Går att köra igen utan att något försvinner.
--
-- Race hämtas automatiskt till data/sim-races.json i repot. Teamet kan också lägga
-- in egna under Table Editor → sim_races. Själva anmälan sker hos arrangören. I appen
-- kan man markera att man är anmäld: alla ser antalet och vänner ser vilka som ska dit.
-- Ett race identifieras med en nyckel som börjar med datumet, till exempel
-- 2027-05-29-crossfit-highway-linkoping. Egna race får nyckeln datum-db-id.

-- ---------- Race ----------
create table if not exists public.sim_races (
  id         bigint generated always as identity primary key,
  title      text not null check (char_length(title) between 1 and 80),
  organizer  text check (organizer is null or char_length(organizer) <= 80),
  city       text not null check (char_length(city) between 1 and 60),
  venue      text check (venue is null or char_length(venue) <= 120),
  day        date not null,
  start_time time,
  price      text check (price is null or char_length(price) <= 40),
  info       text check (info is null or char_length(info) <= 600),
  url        text check (url is null or (url ~ '^https://' and char_length(url) <= 300)),
  hidden     boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists sim_races_day on public.sim_races (day);

alter table public.sim_races enable row level security;
drop policy if exists "Alla ser simulations-race" on public.sim_races;
create policy "Alla ser simulations-race" on public.sim_races
  for select to anon, authenticated using (not hidden);

-- ---------- Markerat som anmäld ----------
create table if not exists public.sim_going (
  race_id    text not null,
  user_id    uuid not null references auth.users (id) on delete cascade default auth.uid(),
  created_at timestamptz not null default now(),
  primary key (race_id, user_id)
);
create index if not exists sim_going_user on public.sim_going (user_id);

alter table public.sim_going enable row level security;
drop policy if exists "Se egna och vänners" on public.sim_going;
drop policy if exists "Markera sig själv" on public.sim_going;
drop policy if exists "Ta bort sin markering" on public.sim_going;

-- Har den tidigare versionen av filen körts görs race_id om till text.
alter table public.sim_going drop constraint if exists sim_going_race_id_fkey;
alter table public.sim_going alter column race_id type text using race_id::text;
update public.sim_going g set race_id = r.day::text || '-db-' || r.id
  from public.sim_races r where g.race_id = r.id::text;
alter table public.sim_going drop constraint if exists sim_going_race_id_check;
alter table public.sim_going add constraint sim_going_race_id_check
  check (race_id ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}-[a-z0-9-]{1,60}$');

create policy "Se egna och vänners" on public.sim_going
  for select to authenticated
  using (
    user_id = (select auth.uid())
    or exists (select 1 from public.friends f
               where f.user_id = sim_going.user_id and f.friend_id = (select auth.uid()))
  );
create policy "Markera sig själv" on public.sim_going
  for insert to authenticated
  with check (user_id = (select auth.uid()));
create policy "Ta bort sin markering" on public.sim_going
  for delete to authenticated
  using (user_id = (select auth.uid()));

-- ---------- Antal ----------
-- Ger bara antal per race, aldrig vilka som har markerat sig.
drop function if exists public.varv_sim_counts();
create function public.varv_sim_counts()
returns table (race_id text, n bigint)
language sql
stable
security definer
set search_path = ''
as $$
  select g.race_id, count(*)
  from public.sim_going g
  where left(g.race_id, 10) >= (current_date - 1)::text
  group by g.race_id;
$$;
revoke all on function public.varv_sim_counts() from public;
grant execute on function public.varv_sim_counts() to anon, authenticated;

-- ---------- Städning ----------
-- Markeringar raderas 60 dagar efter racet.
select cron.unschedule('varv-sim-clean') where exists (select 1 from cron.job where jobname = 'varv-sim-clean');
select cron.schedule('varv-sim-clean', '45 3 * * *', $$
  delete from public.sim_going
  where left(race_id, 10) < (current_date - 60)::text
$$);
