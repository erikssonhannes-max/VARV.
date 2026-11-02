-- VARV. – följare, blockering och anmälningar
-- Kör hela filen en gång i Supabase: SQL Editor → New query → klistra in → Run.
-- Kräver profiler.sql, notiser.sql, notiscenter.sql, varv-2.sql och stats.sql. Går att köra igen.
--
-- Tabellen friends behålls men läses nu åt ett håll: en rad (user_id, friend_id) betyder
-- att friend_id följer user_id och får se user_id:s pass och profil. Dagens vänner har en
-- rad åt vardera hållet och följer därför redan varandra. Väntande vänförfrågningar blir
-- följarförfrågningar. Offentliga profiler går att följa direkt, privata måste godkänna.

create index if not exists friends_friend on public.friends (friend_id);

-- ---------- Blockeringar ----------
create table if not exists public.blocks (
  blocker    uuid not null references auth.users (id) on delete cascade,
  blocked    uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker, blocked),
  check (blocker <> blocked)
);
create index if not exists blocks_blocked on public.blocks (blocked);
alter table public.blocks enable row level security;
drop policy if exists "Se egna blockeringar" on public.blocks;
create policy "Se egna blockeringar" on public.blocks for select to authenticated
  using (blocker = (select auth.uid()));

-- Den som blockerat dig ser du inte längre, inte ens om profilen är offentlig.
-- Kontrollen körs med högre behörighet, eftersom du inte får läsa andras blockeringar.
create or replace function public.varv_blocked_me(p_other uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.blocks b where b.blocker = p_other and b.blocked = auth.uid());
$$;
revoke all on function public.varv_blocked_me(uuid) from public, anon;
grant execute on function public.varv_blocked_me(uuid) to authenticated;
drop policy if exists "Se profiler" on public.profiles;
create policy "Se profiler" on public.profiles for select to authenticated
  using (
    user_id = (select auth.uid())
    or exists (select 1 from public.friends f
               where f.user_id = profiles.user_id and f.friend_id = (select auth.uid()))
    or (is_public and not public.varv_blocked_me(profiles.user_id))
  );

-- ---------- Följa ----------
-- Behåller namnet varv_request_friend så att äldre versioner av appen fungerar.
create or replace function public.varv_request_friend(p_to uuid)
returns text language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid(); pub boolean;
begin
  if me is null then raise exception 'Inte inloggad'; end if;
  if p_to = me then return 'self'; end if;
  select p.is_public into pub from public.profiles p where p.user_id = p_to;
  if not found then return 'none'; end if;
  if exists (select 1 from public.blocks b where (b.blocker = p_to and b.blocked = me) or (b.blocker = me and b.blocked = p_to)) then
    return 'none';
  end if;
  if exists (select 1 from public.friends f where f.user_id = p_to and f.friend_id = me) then return 'following'; end if;
  if pub then
    insert into public.friends (user_id, friend_id) values (p_to, me) on conflict do nothing;
    delete from public.friend_requests where from_user = me and to_user = p_to;
    perform private.varv_push_call(jsonb_build_object('kind', 'follow', 'from', me, 'to', p_to));
    return 'following';
  end if;
  if exists (select 1 from public.friend_requests r where r.from_user = me and r.to_user = p_to) then return 'pending'; end if;
  if (select count(*) from public.friend_requests r where r.from_user = me and r.created_at > now() - interval '1 hour') >= 30 then
    return 'limit';
  end if;
  insert into public.friend_requests (from_user, to_user) values (me, p_to) on conflict do nothing;
  return 'sent';
end; $$;

-- Godkänn: den som frågade får följa dig. Du följer inte automatiskt tillbaka.
create or replace function public.varv_answer_friend(p_from uuid, p_accept boolean)
returns text language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid();
begin
  if me is null then raise exception 'Inte inloggad'; end if;
  delete from public.friend_requests where from_user = p_from and to_user = me;
  if not found then return 'none'; end if;
  if not p_accept then return 'declined'; end if;
  insert into public.friends (user_id, friend_id) values (me, p_from) on conflict do nothing;
  perform private.varv_push_call(jsonb_build_object('kind', 'accept', 'from', me, 'to', p_from));
  return 'accepted';
end; $$;

create or replace function public.varv_unfollow(p_other uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid();
begin
  if me is null then raise exception 'Inte inloggad'; end if;
  delete from public.friends where user_id = p_other and friend_id = me;
  delete from public.friend_requests where from_user = me and to_user = p_other;
  update public.profiles set partner_id = null where user_id = me and partner_id = p_other;
end; $$;

create or replace function public.varv_remove_follower(p_other uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid();
begin
  if me is null then raise exception 'Inte inloggad'; end if;
  delete from public.friends where user_id = me and friend_id = p_other;
end; $$;

-- ---------- Blockera ----------
create or replace function public.varv_block(p_other uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid();
begin
  if me is null then raise exception 'Inte inloggad'; end if;
  if p_other = me then return; end if;
  insert into public.blocks (blocker, blocked) values (me, p_other) on conflict do nothing;
  delete from public.friends where (user_id = me and friend_id = p_other) or (user_id = p_other and friend_id = me);
  delete from public.friend_requests where (from_user = me and to_user = p_other) or (from_user = p_other and to_user = me);
  update public.profiles set partner_id = null where (user_id = me and partner_id = p_other) or (user_id = p_other and partner_id = me);
  delete from public.notifications where user_id = me and actor = p_other;
end; $$;

create or replace function public.varv_unblock(p_other uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'Inte inloggad'; end if;
  delete from public.blocks where blocker = auth.uid() and blocked = p_other;
end; $$;

-- ---------- Hitta atleter ----------
-- Sökningen visar bara offentliga profiler. Privata hittas med exakt namn och kod.
create or replace function public.varv_search_users(p_q text)
returns table (user_id uuid, username text, tag text, avatar_url text, is_public boolean)
language sql stable security definer set search_path = '' as $$
  select p.user_id, p.username, p.tag, p.avatar_url, p.is_public
  from public.profiles p
  where (select auth.uid()) is not null
    and char_length(trim(p_q)) >= 2
    and p.is_public
    and p.user_id <> (select auth.uid())
    and p.username ilike replace(replace(replace(trim(p_q), '\', '\\'), '%', '\%'), '_', '\_') || '%'
    and not exists (select 1 from public.blocks b
      where (b.blocker = p.user_id and b.blocked = (select auth.uid()))
         or (b.blocker = (select auth.uid()) and b.blocked = p.user_id))
  order by lower(p.username), p.tag
  limit 25;
$$;

-- Förslag: offentliga profiler som de du följer följer, sedan andra aktiva offentliga profiler.
create or replace function public.varv_suggest()
returns table (user_id uuid, username text, tag text, avatar_url text, is_public boolean, common bigint)
language sql stable security definer set search_path = '' as $$
  with me as (select auth.uid() as id),
  mine as (select f.user_id from public.friends f, me where f.friend_id = me.id),
  fof as (select f.user_id, count(*) as n from public.friends f
          where f.friend_id in (select user_id from mine) group by f.user_id)
  select p.user_id, p.username, p.tag, p.avatar_url, p.is_public, coalesce(fof.n, 0)
  from public.profiles p cross join me
  left join fof on fof.user_id = p.user_id
  where me.id is not null and p.is_public and p.user_id <> me.id
    and p.user_id not in (select user_id from mine)
    and not exists (select 1 from public.friend_requests r where r.from_user = me.id and r.to_user = p.user_id)
    and not exists (select 1 from public.blocks b
      where (b.blocker = p.user_id and b.blocked = me.id) or (b.blocker = me.id and b.blocked = p.user_id))
  order by coalesce(fof.n, 0) desc, p.updated_at desc
  limit 12;
$$;

-- Antal följare och följer. Bara för dig själv, de du följer och offentliga profiler.
create or replace function public.varv_follow_counts(p_id uuid)
returns table (followers bigint, following bigint)
language sql stable security definer set search_path = '' as $$
  select (select count(*) from public.friends f where f.user_id = p_id),
         (select count(*) from public.friends f where f.friend_id = p_id)
  where (select auth.uid()) is not null and (
    p_id = (select auth.uid())
    or exists (select 1 from public.friends f where f.user_id = p_id and f.friend_id = (select auth.uid()))
    or (exists (select 1 from public.profiles p where p.user_id = p_id and p.is_public)
        and not exists (select 1 from public.blocks b where b.blocker = p_id and b.blocked = (select auth.uid()))));
$$;

-- Den som blockerat dig hittas inte med namn och kod och visas inte i namnlistor.
create or replace function public.varv_find_user(p_username text, p_tag text)
returns table (user_id uuid, username text, tag text, avatar_url text)
language sql stable security definer set search_path = '' as $$
  select p.user_id, p.username, p.tag, p.avatar_url
  from public.profiles p
  where (select auth.uid()) is not null
    and lower(p.username) = lower(p_username)
    and p.tag = p_tag
    and not exists (select 1 from public.blocks b where b.blocker = p.user_id and b.blocked = (select auth.uid()))
  limit 1;
$$;

create or replace function public.varv_names(p_ids uuid[])
returns table (user_id uuid, username text, tag text, avatar_url text)
language sql stable security definer set search_path = '' as $$
  select p.user_id, p.username, p.tag, p.avatar_url
  from public.profiles p
  where (select auth.uid()) is not null
    and p.user_id = any (p_ids[1:200])
    and not exists (select 1 from public.blocks b where b.blocker = p.user_id and b.blocked = (select auth.uid()));
$$;

-- ---------- Anmälningar ----------
create table if not exists public.reports (
  id         bigint generated always as identity primary key,
  reporter   uuid references auth.users (id) on delete set null,
  target     uuid references auth.users (id) on delete set null,
  target_name text,
  reason     text not null check (reason in ('trakasserier', 'olampligt', 'spam', 'annat')),
  note       text check (note is null or char_length(note) <= 500),
  status     text not null default 'ny' check (status in ('ny', 'hanterad')),
  created_at timestamptz not null default now()
);
create index if not exists reports_status on public.reports (status, created_at desc);
alter table public.reports enable row level security;
-- Inga regler: användare når tabellen bara via varv_report och kan aldrig läsa den.

create or replace function public.varv_report(p_target uuid, p_reason text, p_note text)
returns text language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid(); nm text;
begin
  if me is null then raise exception 'Inte inloggad'; end if;
  if p_target = me then return 'self'; end if;
  if (select count(*) from public.reports r where r.reporter = me and r.created_at > now() - interval '1 day') >= 20 then return 'limit'; end if;
  select p.username || '#' || p.tag into nm from public.profiles p where p.user_id = p_target;
  if nm is null then return 'none'; end if;
  insert into public.reports (reporter, target, target_name, reason, note)
  values (me, p_target, nm, p_reason, nullif(left(trim(coalesce(p_note, '')), 500), ''));
  return 'ok';
end; $$;

-- Teamets sida läser anmälningar med samma kod som statistiken.
create or replace function public.varv_reports(p_token text)
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
  if not exists (select 1 from private.stats_token t where t.token = p_token) then raise exception 'Fel kod'; end if;
  return jsonb_build_object(
    'open', (select count(*) from public.reports where status = 'ny'),
    'items', coalesce((select jsonb_agg(x) from (
      select r.id, r.target_name, r.reason, r.note, r.status, r.created_at, r.target,
             (select count(*) from public.reports o where o.target = r.target) as total
      from public.reports r order by (r.status = 'ny') desc, r.created_at desc limit 50) x), '[]'::jsonb));
end; $$;

create or replace function public.varv_report_done(p_token text, p_id bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
  if not exists (select 1 from private.stats_token t where t.token = p_token) then raise exception 'Fel kod'; end if;
  update public.reports set status = 'hanterad' where id = p_id;
  return public.varv_reports(p_token);
end; $$;

-- ---------- Behörigheter ----------
revoke all on function public.varv_request_friend(uuid) from public, anon;
revoke all on function public.varv_answer_friend(uuid, boolean) from public, anon;
revoke all on function public.varv_unfollow(uuid) from public, anon;
revoke all on function public.varv_remove_follower(uuid) from public, anon;
revoke all on function public.varv_block(uuid) from public, anon;
revoke all on function public.varv_unblock(uuid) from public, anon;
revoke all on function public.varv_search_users(text) from public, anon;
revoke all on function public.varv_suggest() from public, anon;
revoke all on function public.varv_follow_counts(uuid) from public, anon;
revoke all on function public.varv_find_user(text, text) from public, anon;
revoke all on function public.varv_names(uuid[]) from public, anon;
revoke all on function public.varv_report(uuid, text, text) from public, anon;
grant execute on function public.varv_request_friend(uuid) to authenticated;
grant execute on function public.varv_answer_friend(uuid, boolean) to authenticated;
grant execute on function public.varv_unfollow(uuid) to authenticated;
grant execute on function public.varv_remove_follower(uuid) to authenticated;
grant execute on function public.varv_block(uuid) to authenticated;
grant execute on function public.varv_unblock(uuid) to authenticated;
grant execute on function public.varv_search_users(text) to authenticated;
grant execute on function public.varv_suggest() to authenticated;
grant execute on function public.varv_follow_counts(uuid) to authenticated;
grant execute on function public.varv_find_user(text, text) to authenticated;
grant execute on function public.varv_names(uuid[]) to authenticated;
grant execute on function public.varv_report(uuid, text, text) to authenticated;
revoke all on function public.varv_reports(text) from public;
revoke all on function public.varv_report_done(text, bigint) from public;
grant execute on function public.varv_reports(text) to anon, authenticated;
grant execute on function public.varv_report_done(text, bigint) to anon, authenticated;

-- Hanterade anmälningar raderas efter 12 månader.
select cron.unschedule('varv-reports-clean') where exists (select 1 from cron.job where jobname = 'varv-reports-clean');
select cron.schedule('varv-reports-clean', '55 3 * * *', $$ delete from public.reports where status = 'hanterad' and created_at < now() - interval '12 months' $$);
