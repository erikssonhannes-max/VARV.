-- VARV. – skydd mot missbruk av profilbilder och notiser
-- Kör hela filen en gång i Supabase: SQL Editor → New query → klistra in → Run.
-- Kräver profiler.sql, notiser.sql, notiscenter.sql och varv-2.sql. Går att köra igen.

-- ---------- Profilbilder ----------
-- Bara bilder från vår egen lagring eller Google. Gäller nya och ändrade värden.
alter table public.profiles drop constraint if exists profiles_avatar_url_host;
alter table public.profiles add constraint profiles_avatar_url_host check (
  avatar_url is null
  or avatar_url like 'https://kwjnezbazyahyzsmpuyg.supabase.co/storage/v1/object/public/avatars/%'
  or avatar_url ~ '^https://[a-z0-9-]+\.googleusercontent\.com/'
) not valid;

-- ---------- Aktivitet ----------
-- Högst 20 poster i timmen per person. Fler sparas inte och ger ingen notis.
create or replace function public.varv_activity_limit()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if (select count(*) from public.activity a
      where a.user_id = new.user_id and a.created_at > now() - interval '1 hour') >= 20 then
    return null;
  end if;
  return new;
end; $$;
revoke all on function public.varv_activity_limit() from public, anon, authenticated;
drop trigger if exists varv_activity_limit on public.activity;
create trigger varv_activity_limit before insert on public.activity
  for each row execute function public.varv_activity_limit();

-- ---------- Tummar upp ----------
-- Tummen sparas alltid, men samma person ger högst 5 notiser i timmen till samma mottagare.
create or replace function public.varv_on_like()
returns trigger language plpgsql security definer set search_path = '' as $$
declare owner uuid;
begin
  select a.user_id into owner from public.activity a where a.id = new.activity_id;
  if owner is null then return new; end if;
  if (select count(*) from public.notifications n
      where n.user_id = owner and n.actor = new.user_id and n.kind = 'like'
        and n.created_at > now() - interval '1 hour') >= 5 then
    return new;
  end if;
  perform private.varv_push_call(jsonb_build_object('kind', 'like', 'activity', new.activity_id, 'user', new.user_id));
  return new;
end; $$;
revoke all on function public.varv_on_like() from public, anon, authenticated;
