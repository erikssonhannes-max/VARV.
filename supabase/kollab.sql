-- VARV. – pass ni körde tillsammans
-- Kör hela filen en gång i Supabase: SQL Editor → New query → klistra in → Run.
-- Kräver schema.sql, profiler.sql, foljare.sql och notiscenter.sql. Går att köra igen.
--
-- Så fungerar det:
--   1. Den som loggade passet bjuder in en vän: varv_share_session(vän, passets id, passet).
--      Vännen får en notis. Ni måste följa varandra, och ingen får ha blockerat den andra.
--   2. Vännen svarar med varv_answer_session(inbjudan, ja/nej).
--      Ja: en kopia av passet läggs i vännens logg och räknas i vännens statistik.
--      Båda passen får fältet "with" med den andras id, så att appen kan visa "Med Elin".
--   3. Den som bjöd in får en notis när vännen har sagt ja.

create table if not exists public.shared_sessions (
  id          bigint generated always as identity primary key,
  from_user   uuid not null references auth.users (id) on delete cascade default auth.uid(),
  to_user     uuid not null references auth.users (id) on delete cascade,
  log_id      text not null check (char_length(log_id) between 1 and 80),
  log         jsonb not null check (pg_column_size(log) < 60000),
  status      text not null default 'pending' check (status in ('pending', 'accepted', 'declined')),
  copy_id     text check (copy_id is null or char_length(copy_id) <= 80),
  created_at  timestamptz not null default now(),
  answered_at timestamptz,
  unique (from_user, to_user, log_id),
  check (from_user <> to_user)
);
create index if not exists shared_sessions_to on public.shared_sessions (to_user, status);
create index if not exists shared_sessions_from on public.shared_sessions (from_user, created_at desc);

alter table public.shared_sessions enable row level security;
drop policy if exists "Se egna gemensamma pass" on public.shared_sessions;
drop policy if exists "Ångra gemensamt pass" on public.shared_sessions;
create policy "Se egna gemensamma pass" on public.shared_sessions for select to authenticated
  using (from_user = (select auth.uid()) or to_user = (select auth.uid()));
-- Den som bjöd in kan ångra en inbjudan som inte är besvarad.
create policy "Ångra gemensamt pass" on public.shared_sessions for delete to authenticated
  using (from_user = (select auth.uid()) and status = 'pending');
-- Inbjudningar skapas och besvaras bara via funktionerna nedan.

-- "2026-11-08" blir "8 nov" i notiserna.
create schema if not exists private;
create or replace function private.varv_sv_date(d text) returns text language sql immutable set search_path = '' as $$
  select case when d ~ '^\d{4}-\d{2}-\d{2}$' then extract(day from d::date)::int || ' ' ||
    (array['jan','feb','mars','april','maj','juni','juli','aug','sep','okt','nov','dec'])[extract(month from d::date)::int] end $$;
revoke all on function private.varv_sv_date(text) from public, anon, authenticated;

-- ---------- Bjud in ----------
create or replace function public.varv_share_session(p_to uuid, p_log_id text, p_log jsonb)
returns text language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid(); who text; what text;
begin
  if me is null then raise exception 'Inte inloggad'; end if;
  if p_to = me then return 'self'; end if;
  if p_log is null or jsonb_typeof(p_log) <> 'object' or pg_column_size(p_log) >= 60000 then return 'invalid'; end if;
  -- Passet måste finnas i ditt eget konto.
  if not exists (select 1 from public.user_docs where user_id = me and id = p_log_id) then return 'nolog'; end if;
  -- Ni måste följa varandra.
  if not (exists (select 1 from public.friends where user_id = me and friend_id = p_to)
          and exists (select 1 from public.friends where user_id = p_to and friend_id = me)) then return 'notfriends'; end if;
  if exists (select 1 from public.blocks b where (b.blocker = me and b.blocked = p_to) or (b.blocker = p_to and b.blocked = me)) then return 'notfriends'; end if;
  -- Högst 30 inbjudningar per dygn, så att funktionen inte kan användas för att skräpposta.
  if (select count(*) from public.shared_sessions where from_user = me and created_at > now() - interval '1 day') >= 30 then return 'limit'; end if;

  insert into public.shared_sessions (from_user, to_user, log_id, log)
  values (me, p_to, p_log_id, p_log)
  on conflict (from_user, to_user, log_id) do nothing;
  if not found then return 'pending'; end if;

  select p.username into who from public.profiles p where p.user_id = me;
  what := concat_ws(' · ', nullif(p_log->>'type', ''), case when p_log ? 'min' then (p_log->>'min') || ' min' end, private.varv_sv_date(p_log->>'date'));
  insert into public.notifications (user_id, kind, title, body, url, actor)
  values (p_to, 'together', left(coalesce(who, 'Någon') || ' säger att ni tränade tillsammans', 120), left(what, 240), '/#notiser', me);
  return 'sent';
end; $$;

-- ---------- Svara ----------
create or replace function public.varv_answer_session(p_id bigint, p_accept boolean)
returns text language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid(); s public.shared_sessions; cid text; c jsonb; who text;
begin
  if me is null then raise exception 'Inte inloggad'; end if;
  select * into s from public.shared_sessions where id = p_id and to_user = me for update;
  if not found then return 'none'; end if;
  if s.status <> 'pending' then return s.status; end if;

  if not p_accept then
    update public.shared_sessions set status = 'declined', answered_at = now() where id = p_id;
    return 'declined';
  end if;

  -- Kopian i din logg. Det som bara gäller den som loggade (plan, källa, benchmark) följer inte med.
  cid := 'logc' || s.id::text;
  c := (s.log - 'id' - 'plan' - 'bench' - 'ext' - 'src' - 'with' - 'shared')
       || jsonb_build_object('with', jsonb_build_array(s.from_user), 'shared', jsonb_build_object('from', s.from_user, 'id', s.id),
                             'created', (extract(epoch from now()) * 1000)::bigint);
  insert into public.user_docs (user_id, id, data, updated_at) values (me, cid, c, now())
  on conflict (user_id, id) do update set data = excluded.data, updated_at = now();

  -- Originalet får "with" med dig, om det fortfarande finns.
  update public.user_docs
     set data = jsonb_set(data, '{with}',
                  (select coalesce(jsonb_agg(distinct x), '[]'::jsonb)
                     from jsonb_array_elements(coalesce(data->'with', '[]'::jsonb) || jsonb_build_array(me)) as x)),
         updated_at = now()
   where user_id = s.from_user and id = s.log_id;

  update public.shared_sessions set status = 'accepted', answered_at = now(), copy_id = cid where id = p_id;

  select p.username into who from public.profiles p where p.user_id = me;
  insert into public.notifications (user_id, kind, title, body, url, actor)
  values (s.from_user, 'together', left(coalesce(who, 'Någon') || ' lade till ert gemensamma pass', 120),
          left(concat_ws(' · ', nullif(s.log->>'type', ''), private.varv_sv_date(s.log->>'date')), 240), '/#logg', me);
  return 'accepted';
end; $$;

revoke all on function public.varv_share_session(uuid, text, jsonb) from public, anon;
revoke all on function public.varv_answer_session(bigint, boolean) from public, anon;
grant execute on function public.varv_share_session(uuid, text, jsonb) to authenticated;
grant execute on function public.varv_answer_session(bigint, boolean) to authenticated;

-- Obesvarade inbjudningar städas bort efter 30 dagar.
select cron.unschedule('varv-together-clean') where exists (select 1 from cron.job where jobname = 'varv-together-clean');
select cron.schedule('varv-together-clean', '55 3 * * *', $$ delete from public.shared_sessions where status = 'pending' and created_at < now() - interval '30 days' $$);
