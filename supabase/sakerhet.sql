-- VARV. – säkerhetsfixar november 2026.
-- Kör hela filen en gång i Supabase: SQL Editor → New query → klistra in → Run.
-- Filen går att köra flera gånger.

-- 1. Egna inlägg kan redigeras, men inte bakdateras, byta typ eller byta titel.
--    Appen ändrar bara text (detail eller note), bild och taggningar.
create or replace function public.varv_activity_edit_guard()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.id         := old.id;
  new.user_id    := old.user_id;
  new.kind       := old.kind;
  new.title      := old.title;
  new.created_at := old.created_at;
  if old.title not like 'Delade%' then new.detail := old.detail; end if;
  new.edited_at := now();
  return new;
end; $$;

drop trigger if exists varv_activity_edit_guard on public.activity;
create trigger varv_activity_edit_guard before update on public.activity
  for each row execute function public.varv_activity_edit_guard();

-- 2. Högst 30 kommentarer per person och timme.
create or replace function public.varv_comments_limit()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if (select count(*) from public.activity_comments c
      where c.user_id = new.user_id and c.created_at > now() - interval '1 hour') >= 30 then
    raise exception 'För många kommentarer. Vänta en stund.';
  end if;
  return new;
end; $$;

revoke execute on function public.varv_comments_limit() from public, anon, authenticated;

drop trigger if exists varv_comments_limit on public.activity_comments;
create trigger varv_comments_limit before insert on public.activity_comments
  for each row execute function public.varv_comments_limit();

-- 3. Kommentarer från någon du har blockerat, eller som har blockerat dig, syns inte.
drop policy if exists "Se kommentarer" on public.activity_comments;
create policy "Se kommentarer" on public.activity_comments
  for select to authenticated
  using (
    exists (select 1 from public.activity a where a.id = activity_comments.activity_id)
    and not exists (
      select 1 from public.blocks b
      where b.blocker = (select auth.uid()) and b.blocked = activity_comments.user_id
    )
    -- Tabellen blocks visar bara egna blockeringar, så åt andra hållet frågar vi funktionen.
    and not public.varv_blocked_me(activity_comments.user_id)
  );
