-- VARV. – tagga vänner med @ i inlägg och kommentarer
-- Kör hela filen en gång i Supabase: SQL Editor → New query → klistra in → Run.
-- Kräver att notiscenter.sql och kommentarer.sql redan är körda. Går att köra igen.

-- Vilka som taggades. Högst tio per inlägg eller kommentar.
alter table public.activity add column if not exists mentions uuid[];
alter table public.activity drop constraint if exists activity_mentions_check;
alter table public.activity add constraint activity_mentions_check check (mentions is null or cardinality(mentions) <= 10);
alter table public.activity_comments add column if not exists mentions uuid[];
alter table public.activity_comments drop constraint if exists activity_comments_mentions_check;
alter table public.activity_comments add constraint activity_comments_mentions_check check (mentions is null or cardinality(mentions) <= 10);

-- Notis till den som taggas, bara om ni följer varandra åt något håll och ingen har blockerat den andra.
create or replace function public.varv_on_mention()
returns trigger language plpgsql security definer set search_path = '' as $$
declare who text; what text; is_comment boolean := tg_table_name = 'activity_comments'; m uuid;
begin
  if new.mentions is null then return new; end if;
  select p.username into who from public.profiles p where p.user_id = new.user_id;
  what := case when is_comment then to_jsonb(new)->>'body' else coalesce(to_jsonb(new)->>'detail', to_jsonb(new)->>'title') end;
  for m in select distinct x from unnest(new.mentions) as x loop
    continue when m = new.user_id;
    continue when not exists (select 1 from public.friends f
      where (f.user_id = new.user_id and f.friend_id = m) or (f.user_id = m and f.friend_id = new.user_id));
    continue when exists (select 1 from public.blocks b
      where (b.blocker = m and b.blocked = new.user_id) or (b.blocker = new.user_id and b.blocked = m));
    insert into public.notifications (user_id, kind, title, body, url, actor)
    values (m, 'mention',
            left(coalesce(who, 'Någon') || case when is_comment then ' taggade dig i en kommentar' else ' taggade dig i ett inlägg' end, 120),
            left(what, 240), '/#feed', new.user_id);
  end loop;
  return new;
end; $$;
revoke all on function public.varv_on_mention() from public, anon, authenticated;
drop trigger if exists varv_mention_activity on public.activity;
create trigger varv_mention_activity after insert on public.activity
  for each row execute function public.varv_on_mention();
drop trigger if exists varv_mention_comment on public.activity_comments;
create trigger varv_mention_comment after insert on public.activity_comments
  for each row execute function public.varv_on_mention();
