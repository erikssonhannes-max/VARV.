-- VARV. – kommentarer på inlägg i flödet
-- Kör hela filen en gång i Supabase: SQL Editor → New query → klistra in → Run.
-- Kräver att notiser.sql, notiscenter.sql och varv-2.sql redan är körda. Går att köra igen.

create table if not exists public.activity_comments (
  id          bigint generated always as identity primary key,
  activity_id bigint not null references public.activity (id) on delete cascade,
  user_id     uuid not null references auth.users (id) on delete cascade default auth.uid(),
  body        text not null check (char_length(btrim(body)) between 1 and 300),
  created_at  timestamptz not null default now()
);
create index if not exists activity_comments_act on public.activity_comments (activity_id, created_at);
alter table public.activity_comments enable row level security;

drop policy if exists "Se kommentarer" on public.activity_comments;
drop policy if exists "Skriva kommentar" on public.activity_comments;
drop policy if exists "Ta bort kommentar" on public.activity_comments;
-- Du ser kommentarer på inlägg som du själv får se.
create policy "Se kommentarer" on public.activity_comments for select to authenticated
  using (exists (select 1 from public.activity a where a.id = activity_comments.activity_id));
-- Du kan kommentera inlägg du ser, men inte om någon av er har blockerat den andra.
create policy "Skriva kommentar" on public.activity_comments for insert to authenticated
  with check (user_id = (select auth.uid())
    and exists (select 1 from public.activity a where a.id = activity_comments.activity_id
      and not exists (select 1 from public.blocks b
        where (b.blocker = a.user_id and b.blocked = (select auth.uid()))
           or (b.blocker = (select auth.uid()) and b.blocked = a.user_id))));
-- Du kan ta bort dina egna kommentarer och kommentarer på dina egna inlägg.
create policy "Ta bort kommentar" on public.activity_comments for delete to authenticated
  using (user_id = (select auth.uid())
    or exists (select 1 from public.activity a where a.id = activity_comments.activity_id and a.user_id = (select auth.uid())));

-- Notis till den som äger inlägget. Högst fem notiser i timmen från samma person.
create or replace function public.varv_on_comment()
returns trigger language plpgsql security definer set search_path = '' as $$
declare owner uuid; who text; what text;
begin
  select a.user_id, a.title into owner, what from public.activity a where a.id = new.activity_id;
  if owner is null or owner = new.user_id then return new; end if;
  if (select count(*) from public.notifications n
      where n.user_id = owner and n.actor = new.user_id and n.kind = 'comment'
        and n.created_at > now() - interval '1 hour') >= 5 then
    return new;
  end if;
  select p.username into who from public.profiles p where p.user_id = new.user_id;
  insert into public.notifications (user_id, kind, title, body, url, actor)
  values (owner, 'comment',
          left(coalesce(who, 'Någon') || ' kommenterade ' || coalesce(nullif(what, ''), 'ditt inlägg'), 120),
          left(new.body, 240), '/#feed', new.user_id);
  return new;
end; $$;
revoke all on function public.varv_on_comment() from public, anon, authenticated;
drop trigger if exists varv_comment_notis on public.activity_comments;
create trigger varv_comment_notis after insert on public.activity_comments
  for each row execute function public.varv_on_comment();
