-- VARV. – index på kolumner som pekar på andra tabeller (Supabase Performance Advisor).
-- Kördes 5 november 2026. Går att köra igen.
create index if not exists activity_comments_user_id_idx on public.activity_comments (user_id);
create index if not exists activity_likes_user_id_idx on public.activity_likes (user_id);
create index if not exists notifications_actor_idx on public.notifications (actor);
create index if not exists profiles_partner_id_idx on public.profiles (partner_id);
create index if not exists reports_reporter_idx on public.reports (reporter);
create index if not exists reports_target_idx on public.reports (target);
