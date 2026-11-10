-- VARV. – klockor: Apple Watch och Garmin
-- Kör hela filen en gång i Supabase: SQL Editor → New query → klistra in → Run.
-- Går att köra igen utan att något försvinner. Kräver att schema.sql redan är körd.
--
-- Det här skapas:
--   watch_devices  – klockor som är kopplade till ett konto. Bara en hash av klockans nyckel sparas.
--   watch_codes    – korta koder för att koppla en Garmin, giltiga i 15 minuter
--   watch_plans    – passen som klockan kan visa: Förberedda och Färdiga pass, publicerade av appen
--   funktioner som klockan anropar med sin nyckel, utan inloggning:
--     watch_claim(kod, namn)          → ny nyckel för en Garmin
--   Alla svar till klockan är objekt, eftersom Garmin inte kan läsa ett ensamt värde.
--     watch_sync(nyckel)              → lista med passen, utan övningar (Garmin)
--     watch_pass(nyckel, id)          → ett pass med övningar (Garmin)
--     watch_passes(nyckel)            → alla pass med övningar (Apple Watch)
--     watch_log(nyckel, id, pass)     → sparar ett pass i loggen (user_docs)
--   funktioner som appen anropar inloggad:
--     watch_code()                    → ny kod för att koppla en Garmin
--     watch_add(plattform, namn)      → ny nyckel direkt, för Apple Watch
--     watch_publish(passen)           → sparar passen som klockan visar

create schema if not exists private;

-- ---------- Kopplade klockor ----------
create table if not exists public.watch_devices (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users (id) on delete cascade,
  platform   text not null check (platform in ('apple', 'garmin')),
  name       text not null default '' check (char_length(name) <= 60),
  token_hash text not null unique,
  created_at timestamptz not null default now(),
  last_seen  timestamptz
);
create index if not exists watch_devices_user on public.watch_devices (user_id);

alter table public.watch_devices enable row level security;
drop policy if exists "Se egna klockor" on public.watch_devices;
drop policy if exists "Koppla bort egna klockor" on public.watch_devices;
create policy "Se egna klockor" on public.watch_devices
  for select to authenticated using (user_id = (select auth.uid()));
create policy "Koppla bort egna klockor" on public.watch_devices
  for delete to authenticated using (user_id = (select auth.uid()));
-- Nyckelns hash ska aldrig lämna databasen, inte ens till ägaren.
revoke all on public.watch_devices from anon, authenticated;
grant select (id, platform, name, created_at, last_seen) on public.watch_devices to authenticated;
grant delete on public.watch_devices to authenticated;

-- ---------- Koder för att koppla en Garmin ----------
create table if not exists private.watch_codes (
  code       text primary key,
  user_id    uuid not null references auth.users (id) on delete cascade,
  expires_at timestamptz not null
);
revoke all on private.watch_codes from public, anon, authenticated;

-- ---------- Passen som klockan visar ----------
create table if not exists private.watch_plans (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  data       jsonb not null check (pg_column_size(data) < 150000),
  updated_at timestamptz not null default now()
);
revoke all on private.watch_plans from public, anon, authenticated;

-- ---------- Hjälpfunktioner ----------
create or replace function private.watch_hash(p_token text)
returns text language sql immutable set search_path = '' as $$
  select encode(sha256(convert_to(coalesce(p_token, ''), 'UTF8')), 'hex')
$$;

-- Slumpad nyckel på 64 tecken (två uuid v4)
create or replace function private.watch_new_token()
returns text language sql volatile set search_path = '' as $$
  select replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', '')
$$;

-- Klockan med den här nyckeln, eller null. Uppdaterar när klockan senast hördes av.
create or replace function private.watch_user(p_token text)
returns uuid language plpgsql volatile security definer set search_path = '' as $$
declare
  uid uuid;
begin
  if p_token is null or char_length(p_token) <> 64 then
    return null;
  end if;
  update public.watch_devices
     set last_seen = now()
   where token_hash = private.watch_hash(p_token)
  returning user_id into uid;
  return uid;
end;
$$;

-- Ett tal från klockan, avrundat till en decimal och inom rimliga gränser. Annat blir null.
create or replace function private.watch_num(v jsonb, lo numeric, hi numeric)
returns numeric language sql immutable set search_path = '' as $$
  select case when jsonb_typeof(v) = 'number'
              then trim_scale(round(least(greatest((v #>> '{}')::numeric, lo), hi), 1))
         end
$$;

-- En övning från klockan, byggd om fält för fält i samma form som passläget sparar.
create or replace function private.watch_item(i jsonb)
returns jsonb language sql immutable set search_path = '' as $$
  select jsonb_strip_nulls(jsonb_build_object(
    'ex',   left(coalesce(i ->> 'ex', 'egen'), 40),
    'n',    left(coalesce(nullif(i ->> 'n', ''), 'Övning'), 80),
    'k',    case when i ->> 'k' in ('d', 'r', 'c', 't') then i ->> 'k' else 'r' end,
    'w',    case when i ->> 'w' in ('1', 'true') then 1 else 0 end,
    'st',   case when i ->> 'st' in ('1', 'true') then 1 else 0 end,
    'sec',  round(private.watch_num(i -> 'sec', 0, 86400)),
    'sets', coalesce((
      select jsonb_agg(s.o order by s.nr)
        from (
          select e.nr, jsonb_strip_nulls(jsonb_build_object(
                   'm',  private.watch_num(e.v -> 'm',  0, 100000),
                   'r',  private.watch_num(e.v -> 'r',  0, 10000),
                   'c',  private.watch_num(e.v -> 'c',  0, 10000),
                   't',  private.watch_num(e.v -> 't',  0, 86400),
                   'kg', private.watch_num(e.v -> 'kg', 0, 1000))) as o
            from jsonb_array_elements(case when jsonb_typeof(i -> 'sets') = 'array' then i -> 'sets' else '[]'::jsonb end)
                 with ordinality as e(v, nr)
           where jsonb_typeof(e.v) = 'object' and e.nr <= 50
        ) s
       where s.o <> '{}'::jsonb
    ), '[]'::jsonb)
  ))
$$;

-- Garmins typsnitt saknar några tecken som appen använder i målen, som × och ·. De byts mot x och -.
create or replace function private.watch_plain(d jsonb)
returns jsonb language sql immutable set search_path = '' as $$
  select translate(d::text, '×·–', 'x--')::jsonb
$$;

-- ---------- Appen: koppla en klocka ----------
create or replace function public.watch_code()
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  abc constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  b bytea;
  c text;
  n int := 0;
begin
  if uid is null then
    raise exception 'Inte inloggad';
  end if;
  delete from private.watch_codes where user_id = uid or expires_at < now();
  loop
    b := uuid_send(gen_random_uuid());
    c := '';
    -- byte 6 och 8 har fasta bitar i en uuid v4, så de används inte
    foreach n in array array[0, 1, 2, 3, 4, 5, 10, 11] loop
      c := c || substr(abc, 1 + (get_byte(b, n) % 32), 1);
    end loop;
    exit when not exists (select 1 from private.watch_codes where code = c);
  end loop;
  insert into private.watch_codes (code, user_id, expires_at)
  values (c, uid, now() + interval '15 minutes');
  return jsonb_build_object('code', c, 'expires', now() + interval '15 minutes');
end;
$$;

create or replace function public.watch_add(p_platform text, p_name text)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  t text := private.watch_new_token();
  did uuid;
begin
  if uid is null then
    raise exception 'Inte inloggad';
  end if;
  if p_platform not in ('apple', 'garmin') then
    raise exception 'Okänd klocka';
  end if;
  if (select count(*) from public.watch_devices where user_id = uid) >= 10 then
    raise exception 'Du har redan tio klockor kopplade';
  end if;
  insert into public.watch_devices (user_id, platform, name, token_hash)
  values (uid, p_platform, left(coalesce(p_name, ''), 60), private.watch_hash(t))
  returning id into did;
  return jsonb_build_object('id', did, 'token', t);
end;
$$;

create or replace function public.watch_publish(p_data jsonb)
returns void language plpgsql volatile security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'Inte inloggad';
  end if;
  if jsonb_typeof(p_data) <> 'object' or jsonb_typeof(p_data -> 'passes') <> 'array' then
    raise exception 'Fel format';
  end if;
  insert into private.watch_plans (user_id, data, updated_at)
  values (uid, p_data, now())
  on conflict (user_id) do update set data = excluded.data, updated_at = now();
end;
$$;

-- ---------- Klockan: anropas med nyckel, utan inloggning ----------
create or replace function public.watch_claim(p_code text, p_name text)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  uid uuid;
  t text := private.watch_new_token();
begin
  delete from private.watch_codes
   where code = upper(replace(coalesce(p_code, ''), ' ', ''))
     and expires_at > now()
  returning user_id into uid;
  if uid is null then
    raise exception 'Koden stämmer inte eller har gått ut';
  end if;
  if (select count(*) from public.watch_devices where user_id = uid) >= 10 then
    raise exception 'Du har redan tio klockor kopplade';
  end if;
  insert into public.watch_devices (user_id, platform, name, token_hash)
  values (uid, 'garmin', left(coalesce(nullif(p_name, ''), 'Garmin'), 60), private.watch_hash(t));
  return jsonb_build_object('token', t);
end;
$$;

create or replace function public.watch_sync(p_token text)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  uid uuid := private.watch_user(p_token);
  d jsonb;
begin
  if uid is null then
    raise exception 'Klockan är inte kopplad' using errcode = '28000';
  end if;
  select data into d from private.watch_plans where user_id = uid;
  return private.watch_plain(jsonb_build_object(
    'updated', d ->> 'updated',
    'passes', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', p ->> 'id', 'n', p ->> 'n', 't', p ->> 't', 'm', p -> 'm', 'g', p ->> 'g',
               'c', jsonb_array_length(coalesce(p -> 'items', '[]'::jsonb))) order by nr)
        from jsonb_array_elements(coalesce(d -> 'passes', '[]'::jsonb)) with ordinality as x(p, nr)
    ), '[]'::jsonb)));
end;
$$;

create or replace function public.watch_pass(p_token text, p_id text)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  uid uuid := private.watch_user(p_token);
  r jsonb;
begin
  if uid is null then
    raise exception 'Klockan är inte kopplad' using errcode = '28000';
  end if;
  select p into r
    from private.watch_plans w, jsonb_array_elements(w.data -> 'passes') p
   where w.user_id = uid and p ->> 'id' = p_id
   limit 1;
  return private.watch_plain(jsonb_build_object('pass', r));
end;
$$;

create or replace function public.watch_passes(p_token text)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  uid uuid := private.watch_user(p_token);
begin
  if uid is null then
    raise exception 'Klockan är inte kopplad' using errcode = '28000';
  end if;
  return coalesce((select data from private.watch_plans where user_id = uid), '{"passes":[]}'::jsonb);
end;
$$;

-- Sparar ett pass från klockan i loggen. Samma id två gånger sparas bara en gång,
-- så klockan kan skicka om ett pass som den inte fick svar på.
create or replace function public.watch_log(p_token text, p_id text, p_pass jsonb)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  uid uuid := private.watch_user(p_token);
  plat text;
  items jsonb;
  total int;
  d date;
  doc jsonb;
begin
  if uid is null then
    raise exception 'Klockan är inte kopplad' using errcode = '28000';
  end if;
  if p_id is null or p_id !~ '^w[a-z0-9]{6,40}$' then
    raise exception 'Fel id';
  end if;
  if jsonb_typeof(p_pass) <> 'object' or pg_column_size(p_pass) > 60000
     or jsonb_typeof(p_pass -> 'items') <> 'array' then
    raise exception 'Fel format';
  end if;

  select platform into plat from public.watch_devices where token_hash = private.watch_hash(p_token);

  select coalesce(jsonb_agg(x.o order by x.nr), '[]'::jsonb) into items
    from (select e.nr, private.watch_item(e.v) as o
            from jsonb_array_elements(p_pass -> 'items') with ordinality as e(v, nr)
           where jsonb_typeof(e.v) = 'object' and e.nr <= 60) x
   where jsonb_array_length(x.o -> 'sets') > 0 or x.o ? 'sec';
  if jsonb_array_length(items) = 0 then
    raise exception 'Passet har inga klara övningar';
  end if;

  total := round(coalesce(private.watch_num(p_pass -> 'total', 0, 12 * 3600), 0));
  begin
    d := (p_pass ->> 'date')::date;
  exception when others then
    d := (now() at time zone 'Europe/Stockholm')::date;
  end;
  if d is null or d > (now() at time zone 'Europe/Stockholm')::date + 1 or d < '2020-01-01' then
    d := (now() at time zone 'Europe/Stockholm')::date;
  end if;

  doc := jsonb_build_object(
    'date',     to_char(d, 'YYYY-MM-DD'),
    'type',     left(coalesce(nullif(p_pass ->> 'type', ''), 'Styrka och stationer'), 40),
    'min',      greatest(1, least(600, round(total / 60.0))),
    'total',    total,
    'rpe',      null,
    'stations', coalesce((select jsonb_agg(distinct i ->> 'n')
                            from jsonb_array_elements(items) i where (i ->> 'st') = '1'), '[]'::jsonb),
    'items',    items,
    'note',     left(coalesce(p_pass ->> 'note', ''), 300),
    'created',  round(extract(epoch from now()) * 1000),
    'src',      'watch',
    'watch',    coalesce(plat, 'apple'));
  if p_pass ? 'name' then
    doc := doc || jsonb_build_object('wname', left(p_pass ->> 'name', 80));
  end if;

  insert into public.user_docs (user_id, id, data, updated_at)
  values (uid, p_id, doc, now())
  on conflict (user_id, id) do nothing;
  return jsonb_build_object('id', p_id);
end;
$$;

-- ---------- Behörigheter ----------
revoke all on function private.watch_hash(text) from public, anon, authenticated;
revoke all on function private.watch_new_token() from public, anon, authenticated;
revoke all on function private.watch_user(text) from public, anon, authenticated;
revoke all on function private.watch_num(jsonb, numeric, numeric) from public, anon, authenticated;
revoke all on function private.watch_item(jsonb) from public, anon, authenticated;
revoke all on function private.watch_plain(jsonb) from public, anon, authenticated;

revoke all on function public.watch_code() from public, anon;
revoke all on function public.watch_add(text, text) from public, anon;
revoke all on function public.watch_publish(jsonb) from public, anon;
grant execute on function public.watch_code() to authenticated;
grant execute on function public.watch_add(text, text) to authenticated;
grant execute on function public.watch_publish(jsonb) to authenticated;

revoke all on function public.watch_claim(text, text) from public;
revoke all on function public.watch_sync(text) from public;
revoke all on function public.watch_pass(text, text) from public;
revoke all on function public.watch_passes(text) from public;
revoke all on function public.watch_log(text, text, jsonb) from public;
grant execute on function public.watch_claim(text, text) to anon, authenticated;
grant execute on function public.watch_sync(text) to anon, authenticated;
grant execute on function public.watch_pass(text, text) to anon, authenticated;
grant execute on function public.watch_passes(text) to anon, authenticated;
grant execute on function public.watch_log(text, text, jsonb) to anon, authenticated;
