-- VARV. – i flödet går det bara att dela summeringsbilden från ett pass
-- Kör hela filen en gång i Supabase: SQL Editor → New query → klistra in → Run.
-- Kräver att notiser.sql, bilder.sql och redigera.sql redan är körda. Går att köra igen.
--
-- Ett inlägg måste ha passbilden som appen ritar (posts/<ditt id>/p-….jpg).
-- Då nekas automatiska rekord- och passinlägg, även från äldre versioner av appen.

drop policy if exists "Skapa egen aktivitet" on public.activity;
create policy "Skapa egen aktivitet" on public.activity
  for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and image_url ~ ('/storage/v1/object/public/posts/' || (select auth.uid())::text || '/p-[a-z0-9]+\.jpg$')
  );

-- Passbilden och passets text ligger fast. Bara bildtexten och taggarna kan ändras.
create or replace function public.varv_activity_edit_guard()
returns trigger language plpgsql set search_path = '' as $$
begin
  if old.title not like 'Delade%' then new.detail := old.detail; end if;
  if old.image_url ~ '/p-[a-z0-9]+\.jpg$' then new.image_url := old.image_url; end if;
  new.edited_at := now();
  return new;
end; $$;
