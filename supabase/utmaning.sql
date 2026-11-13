-- VARV. – veckans utmaning
-- Kör hela filen en gång i Supabase: SQL Editor → New query → klistra in → Run.
-- Kräver varv-3.sql. Går att köra igen.
--
-- Veckans utmaning byts varje onsdag och är densamma för alla. Appen räknar ut hur
-- långt du har kommit från dina egna pass och sparar det i profilens statistik:
--   cw = onsdagen då utmaningen började, cv = hur långt du har kommit (meter, antal eller minuter)
-- Då kan vänner se varandras framsteg. Den här filen släpper igenom de två fälten,
-- och wmin (träningsminuter den här veckan) som appen redan skickar.
-- Allt annat i varv_profiles_clean är oförändrat.

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
    'since',    public.varv_txt(s->'since', 20, '^[0-9]{4}(-[0-9]{2}){0,2}$'),
    'wmin',     public.varv_num(s->'wmin', 0, 10080),
    'cw',       public.varv_txt(s->'cw', 10, day_re),
    'cv',       public.varv_num(s->'cv', 0, 1000000)
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
