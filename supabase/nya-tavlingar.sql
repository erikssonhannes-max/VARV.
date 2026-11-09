-- VARV. – notis när en ny tävling eller simulering läggs till i appen
-- Kör hela filen en gång i Supabase: SQL Editor → New query → klistra in → Run.
-- Kräver notiser.sql och notiscenter.sql. Går att köra igen utan att något försvinner.
-- Uppdatera sedan koden i funktionen varv-push med supabase/functions/varv-push/index.ts.
--
-- Så fungerar det:
--   1. Varje timme anropas varv-push med {"kind":"newraces"}.
--   2. Funktionen hämtar kommande lopp ur events, sim_races och data/sim-races.json
--      och skickar dem till varv_new_races nedan.
--   3. varv_new_races kommer ihåg alla lopp den har sett och svarar med de som är nya.
--      Första gången lär den sig bara listan och svarar tomt, så ingen får en notis
--      om alla lopp som redan finns.
--   4. Är något nytt får alla användare en notis i notiscentret, och en push om de
--      har notiser påslagna och inte har stängt av Nya tävlingar.

create table if not exists private.races_seen (
  key        text primary key,
  kind       text not null check (kind in ('tavling', 'sim')),
  created_at timestamptz not null default now()
);
alter table private.races_seen enable row level security;

-- p_items: [{"key": "...", "kind": "tavling"|"sim", ...}]. Svarar med de poster som är nya.
create or replace function public.varv_new_races(p_items jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  first_run boolean;
  fresh jsonb;
begin
  if jsonb_typeof(p_items) <> 'array' then return '[]'::jsonb; end if;
  first_run := not exists (select 1 from private.races_seen);

  with items as (
    select x as item, x->>'key' as key, x->>'kind' as kind
    from jsonb_array_elements(p_items) x
    where coalesce(x->>'key', '') <> '' and x->>'kind' in ('tavling', 'sim')
  ),
  ins as (
    insert into private.races_seen (key, kind)
    select distinct on (key) key, kind from items
    on conflict (key) do nothing
    returning key
  )
  select coalesce(jsonb_agg(i.item), '[]'::jsonb) into fresh
  from items i join ins on ins.key = i.key;

  if first_run then return '[]'::jsonb; end if;
  return fresh;
end;
$$;
revoke all on function public.varv_new_races(jsonb) from public, anon, authenticated;
grant execute on function public.varv_new_races(jsonb) to service_role;

select cron.unschedule('varv-newraces') where exists (select 1 from cron.job where jobname = 'varv-newraces');
select cron.schedule('varv-newraces', '17 * * * *', $$ select private.varv_push_call('{"kind":"newraces"}'::jsonb) $$);
