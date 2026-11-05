-- VARV. – listan Nya på VARV. under Aktivitet → Hitta vänner.
-- Visar de senast anslutna som har valt att synas i förslag: offentliga profiler, och privata bara vid gemensamma personer.
create or replace function public.varv_new_users()
returns table (user_id uuid, username text, tag text, avatar_url text, is_public boolean, common bigint, created_at timestamptz)
language sql stable security definer set search_path = '' as $$
  with me as (select auth.uid() as id),
  mine as (select f.user_id from public.friends f, me where f.friend_id = me.id),
  fof as (select f.user_id, count(*) as n from public.friends f
          where f.friend_id in (select user_id from mine) group by f.user_id)
  select p.user_id, p.username, p.tag, p.avatar_url, p.is_public, coalesce(fof.n, 0), p.created_at
  from public.profiles p cross join me
  left join fof on fof.user_id = p.user_id
  where me.id is not null and p.user_id <> me.id
    and p.suggestable
    and (p.is_public or coalesce(fof.n, 0) > 0)
    and p.user_id not in (select user_id from mine)
    and not exists (select 1 from public.friend_requests r where r.from_user = me.id and r.to_user = p.user_id)
    and not exists (select 1 from public.blocks b
      where (b.blocker = p.user_id and b.blocked = me.id) or (b.blocker = me.id and b.blocked = p.user_id))
  order by p.created_at desc
  limit 20;
$$;
revoke all on function public.varv_new_users() from public, anon;
grant execute on function public.varv_new_users() to authenticated;
