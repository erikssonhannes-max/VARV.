-- VARV. – intern statistik
-- Kör hela filen en gång i Supabase: SQL Editor → New query → klistra in → Run.
-- Längst ned visas en hemlig kod. Den används för att öppna den interna
-- statistiksidan (och kalkylarket om ni vill).
--
-- Funktionen varv_dashboard ger bara summor (nya användare, aktiva och loggade
-- pass), aldrig namn, e-post eller enskilda pass. Den svarar bara den som
-- skickar med rätt kod. Det går att köra filen igen, koden ändras inte då.

create schema if not exists private;
revoke all on schema private from anon, authenticated;

create table if not exists private.stats_token (
  token text not null primary key
);

insert into private.stats_token (token)
select replace(gen_random_uuid()::text, '-', '')
where not exists (select 1 from private.stats_token);

-- Tolkar ett datum från en användares pass. Ogiltiga datum blir null i stället
-- för att stoppa hela statistiken.
create or replace function private.varv_date(p text)
returns date
language plpgsql
immutable
set search_path = ''
as $$
begin
  if p !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then
    return null;
  end if;
  return p::date;
exception when others then
  return null;
end;
$$;
revoke all on function private.varv_date(text) from public, anon, authenticated;

create or replace function public.varv_dashboard(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  today date := (now() at time zone 'Europe/Stockholm')::date;
  result jsonb;
begin
  if not exists (select 1 from private.stats_token t where t.token = p_token) then
    raise exception 'Fel kod';
  end if;

  with logs as (
    select x.user_id, x.day
    from (
      select d.user_id, private.varv_date(d.data->>'date') as day
      from public.user_docs d
      where d.id not in ('meta', 'settings')
        and coalesce(d.data->>'hidden', 'false') <> 'true'
    ) x
    -- Datum långt bort är felaktiga och får inte blåsa upp månadslistan.
    where x.day between date '2020-01-01' and today + 366
  ),
  users as (
    select u.id, (u.created_at at time zone 'Europe/Stockholm')::date as day
    from auth.users u
  ),
  months as (
    select generate_series(
      least(coalesce((select date_trunc('month', min(day)) from users), today),
            coalesce((select date_trunc('month', min(day)) from logs), today),
            date '2026-11-01')::date,
      date_trunc('month', today)::date,
      interval '1 month')::date as m
  ),
  days as (
    select generate_series(today - 29, today, interval '1 day')::date as d
  )
  select jsonb_build_object(
    'updated', now(),
    'totals', jsonb_build_object(
      'users',            (select count(*) from users),
      'users_today',      (select count(*) from users where day = today),
      'users_7d',         (select count(*) from users where day > today - 7),
      'active_7d',        (select count(distinct user_id) from logs where day > today - 7 and day <= today),
      'active_30d',       (select count(distinct user_id) from logs where day > today - 30 and day <= today),
      'sessions',         (select count(*) from logs),
      'sessions_7d',      (select count(*) from logs where day > today - 7 and day <= today)
    ),
    'monthly', (select coalesce(jsonb_agg(jsonb_build_object(
        'month',        mo.m,
        'new_users',    (select count(*) from users u where date_trunc('month', u.day)::date = mo.m),
        'total_users',  (select count(*) from users u where u.day < (mo.m + interval '1 month')::date),
        'active_users', (select count(distinct l.user_id) from logs l where date_trunc('month', l.day)::date = mo.m),
        'sessions',     (select count(*) from logs l where date_trunc('month', l.day)::date = mo.m)
      ) order by mo.m), '[]'::jsonb) from months mo),
    'daily', (select coalesce(jsonb_agg(jsonb_build_object(
        'day',          dd.d,
        'new_users',    (select count(*) from users u where u.day = dd.d),
        'active_users', (select count(distinct l.user_id) from logs l where l.day = dd.d),
        'sessions',     (select count(*) from logs l where l.day = dd.d)
      ) order by dd.d), '[]'::jsonb) from days dd)
  ) into result;

  return result;
end;
$$;

revoke all on function public.varv_dashboard(text) from public;
grant execute on function public.varv_dashboard(text) to anon, authenticated;

-- Er hemliga kod. Kopiera den.
select token as "Kod till statistiksidan" from private.stats_token;
