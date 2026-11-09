-- VARV. – notis när en ny tävling eller simulering läggs till i appen
-- Kör hela filen en gång i Supabase: SQL Editor → New query → klistra in → Run.
-- Kräver notiser.sql och notiscenter.sql. Går att köra igen utan att något försvinner.
-- Uppdatera sedan koden i funktionen varv-push med supabase/functions/varv-push/index.ts.
--
-- Så fungerar det:
--   1. Varje timme anropas varv-push med {"kind":"newraces"}.
--   2. Funktionen hämtar kommande lopp ur tabellerna events och sim_races och filerna
--      data/events.json och data/sim-races.json och skickar dem till varv_new_races nedan.
--      Filerna fylls på av schemalagda uppgifter varje måndag.
--   3. varv_new_races kommer ihåg alla lopp den har sett och svarar med de som är nya.
--      En källa som inte har setts förut lärs bara in, så ingen får en notis om alla
--      lopp som redan finns.
--   4. Är något nytt får alla användare en notis i notiscentret, och en push om de
--      har notiser påslagna och inte har stängt av Nya tävlingar.

create table if not exists private.races_seen (
  key        text primary key,
  kind       text not null check (kind in ('tavling', 'sim')),
  created_at timestamptz not null default now()
);
alter table private.races_seen add column if not exists src text;
alter table private.races_seen enable row level security;

-- p_items: [{"key": "...", "kind": "tavling"|"sim", "src": "...", ...}]. Svarar med de poster som är nya.
-- En källa som inte har setts förut (till exempel en ny fil) lärs in utan notis.
create or replace function public.varv_new_races(p_items jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  fresh jsonb;
  new_srcs text[];
begin
  if jsonb_typeof(p_items) <> 'array' then return '[]'::jsonb; end if;

  drop table if exists pg_temp._items;
  create temp table _items on commit drop as
  select x as item, x->>'key' as key, x->>'kind' as kind, coalesce(x->>'src', '') as src
  from jsonb_array_elements(p_items) x
  where coalesce(x->>'key', '') <> '' and x->>'kind' in ('tavling', 'sim');

  select coalesce(array_agg(distinct i.src), '{}') into new_srcs
  from pg_temp._items i
  where not exists (select 1 from private.races_seen s where s.src = i.src);

  with ins as (
    insert into private.races_seen (key, kind, src)
    select distinct on (key) key, kind, src from pg_temp._items order by key, src
    on conflict (key) do nothing
    returning key
  )
  select coalesce(jsonb_agg(f.item), '[]'::jsonb) into fresh
  from (
    select distinct on (i.key) i.item
    from pg_temp._items i join ins on ins.key = i.key
    where not (i.src = any (new_srcs))
    order by i.key
  ) f;

  -- Källor som saknar rader sedan tidigare (även de som bara gav kända lopp) ska räknas som sedda.
  insert into private.races_seen (key, kind, src)
  select distinct on (src) '_src:' || src, kind, src from pg_temp._items
  where src = any (new_srcs)
  order by src
  on conflict (key) do nothing;

  return fresh;
end;
$$;
revoke all on function public.varv_new_races(jsonb) from public, anon, authenticated;
grant execute on function public.varv_new_races(jsonb) to service_role;

select cron.unschedule('varv-newraces') where exists (select 1 from cron.job where jobname = 'varv-newraces');
select cron.schedule('varv-newraces', '17 * * * *', $$ select private.varv_push_call('{"kind":"newraces"}'::jsonb) $$);
