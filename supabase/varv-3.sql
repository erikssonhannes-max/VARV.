-- VARV. – säkrare profildata och gräns för felrapporter
-- Kör hela filen en gång i Supabase: SQL Editor → New query → klistra in → Run.
-- Kräver profiler.sql och varv-2.sql. Går att köra igen.

-- ---------- Profildata ----------
-- Appen räknar ut statistiken på användarens enhet, så databasen kan inte lita på
-- värdena. Bara kända fält av rätt typ sparas. Gränserna stoppar orimliga siffror
-- på topplistan, men träningen är självrapporterad och går inte att kontrollera helt.
create or replace function public.varv_num(p jsonb, lo numeric, hi numeric)
returns numeric
language sql
immutable
set search_path = ''
as $$
  select case when jsonb_typeof(p) = 'number' then least(greatest(p::text::numeric, lo), hi) else lo end;
$$;

create or replace function public.varv_txt(p jsonb, max_len integer, pattern text default null)
returns text
language sql
immutable
set search_path = ''
as $$
  select case
    when jsonb_typeof(p) = 'string'
     and char_length(p #>> '{}') between 1 and max_len
     and (pattern is null or (p #>> '{}') ~ pattern)
    then p #>> '{}'
  end;
$$;

revoke all on function public.varv_num(jsonb, numeric, numeric) from public, anon, authenticated;
revoke all on function public.varv_txt(jsonb, integer, text) from public, anon, authenticated;

create or replace function public.varv_profiles_clean()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  s jsonb := coalesce(new.stats, '{}'::jsonb);
  r jsonb := new.next_race;
  day_re constant text := '^[0-9]{4}-[0-9]{2}-[0-9]{2}$';
begin
  if jsonb_typeof(s) <> 'object' then s := '{}'::jsonb; end if;
  new.stats := jsonb_strip_nulls(jsonb_build_object(
    'wk',       public.varv_txt(s->'wk', 10, day_re),
    'wv',       public.varv_num(s->'wv', 0, 300),
    'sessions', public.varv_num(s->'sessions', 0, 100000),
    'hours',    public.varv_num(s->'hours', 0, 100000),
    'streak',   public.varv_num(s->'streak', 0, 1000),
    'week',     public.varv_num(s->'week', 0, 50),
    'varv',     public.varv_num(s->'varv', 0, 1000000),
    'tier',     public.varv_txt(s->'tier', 10, '^(Start|Brons|Silver|Guld|Platina|Elit)$'),
    'medals',   public.varv_num(s->'medals', 0, 100),
    'since',    public.varv_txt(s->'since', 20, '^[0-9]{4}(-[0-9]{2}){0,2}$')
  ));

  if r is not null then
    if jsonb_typeof(r) <> 'object' or public.varv_txt(r->'date', 10, day_re) is null then
      r := null;
    else
      r := jsonb_strip_nulls(jsonb_build_object(
        'name',    public.varv_txt(r->'name', 60),
        'country', public.varv_txt(r->'country', 60),
        'date',    public.varv_txt(r->'date', 10, day_re),
        'end',     public.varv_txt(r->'end', 10, day_re),
        'venue',   public.varv_txt(r->'venue', 120),
        'div',     public.varv_txt(r->'div', 60)
      ));
    end if;
    new.next_race := r;
  end if;

  new.prs := coalesce((
    select jsonb_object_agg(e.key, e.value)
    from jsonb_each(case when jsonb_typeof(new.prs) = 'object' then new.prs else '{}'::jsonb end) e
    where char_length(e.key) <= 20
      and jsonb_typeof(e.value) = 'number'
      and e.value::text::numeric between 1 and 36000
  ), '{}'::jsonb);

  return new;
end;
$$;
revoke all on function public.varv_profiles_clean() from public, anon, authenticated;

drop trigger if exists varv_profiles_clean on public.profiles;
create trigger varv_profiles_clean
  before update on public.profiles
  for each row execute function public.varv_profiles_clean();

-- Städa det som redan finns.
update public.profiles set stats = stats;

-- ---------- Felrapporter ----------
-- Vem som helst kan skicka in en felrapport. Över 300 i timmen slängs resten tyst,
-- så att ingen kan fylla databasen.
create index if not exists errors_time on public.errors (created_at desc);

create or replace function public.varv_errors_limit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select count(*) from public.errors where created_at > now() - interval '1 hour') >= 300 then
    return null;
  end if;
  return new;
end;
$$;
revoke all on function public.varv_errors_limit() from public, anon, authenticated;

drop trigger if exists varv_errors_limit on public.errors;
create trigger varv_errors_limit
  before insert on public.errors
  for each row execute function public.varv_errors_limit();
