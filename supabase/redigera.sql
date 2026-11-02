-- VARV. – ändra egna inlägg i efterhand: en kommentar och en bild
-- Kör hela filen en gång i Supabase: SQL Editor → New query → klistra in → Run.
-- Kräver att notiser.sql, bilder.sql och taggning.sql redan är körda. Går att köra igen.

-- En egen kommentar till inlägget, och när det senast ändrades.
alter table public.activity add column if not exists note text;
alter table public.activity drop constraint if exists activity_note_check;
alter table public.activity add constraint activity_note_check check (note is null or char_length(note) <= 300);
alter table public.activity add column if not exists edited_at timestamptz;

-- Bara ägaren får ändra, och bara text, bild och taggar. Typ, rubrik, ägare och datum går aldrig att ändra.
revoke update on public.activity from anon, authenticated;
grant update (detail, note, image_url, mentions, edited_at) on public.activity to authenticated;

drop policy if exists "Ändra egen aktivitet" on public.activity;
create policy "Ändra egen aktivitet" on public.activity for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

-- Texten som appen skrev själv, till exempel en sluttid, ligger fast. Bara egna inlägg (Delade ...) kan få ny text.
create or replace function public.varv_activity_edit_guard()
returns trigger language plpgsql set search_path = '' as $$
begin
  if old.title not like 'Delade%' then new.detail := old.detail; end if;
  new.edited_at := now();
  return new;
end; $$;
drop trigger if exists varv_activity_edit_guard on public.activity;
create trigger varv_activity_edit_guard before update on public.activity
  for each row execute function public.varv_activity_edit_guard();

-- Den som taggas när ett inlägg ändras får en notis, men bara de som inte redan var taggade.
create or replace function public.varv_on_mention_edit()
returns trigger language plpgsql security definer set search_path = '' as $$
declare who text; what text; m uuid;
begin
  if new.mentions is null then return new; end if;
  select p.username into who from public.profiles p where p.user_id = new.user_id;
  what := coalesce(new.note, new.detail, new.title);
  for m in select distinct x from unnest(new.mentions) as x
           where old.mentions is null or not (x = any (old.mentions)) loop
    continue when m = new.user_id;
    continue when not exists (select 1 from public.friends f
      where (f.user_id = new.user_id and f.friend_id = m) or (f.user_id = m and f.friend_id = new.user_id));
    continue when exists (select 1 from public.blocks b
      where (b.blocker = m and b.blocked = new.user_id) or (b.blocker = new.user_id and b.blocked = m));
    insert into public.notifications (user_id, kind, title, body, url, actor)
    values (m, 'mention', left(coalesce(who, 'Någon') || ' taggade dig i ett inlägg', 120), left(what, 240), '/#feed', new.user_id);
  end loop;
  return new;
end; $$;
revoke all on function public.varv_on_mention_edit() from public, anon, authenticated;
drop trigger if exists varv_mention_activity_edit on public.activity;
create trigger varv_mention_activity_edit after update of mentions on public.activity
  for each row execute function public.varv_on_mention_edit();
