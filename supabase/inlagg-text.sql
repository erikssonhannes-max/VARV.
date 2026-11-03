-- VARV. – längre text på pass i flödet, så att varje övning kan stå på en egen rad
-- Kör hela filen en gång i Supabase: SQL Editor → New query → klistra in → Run. Går att köra igen.
-- Utan den här filen skickar appen en kortare version av texten, på högst 160 tecken.

alter table public.activity drop constraint if exists activity_detail_check;
alter table public.activity add constraint activity_detail_check check (detail is null or char_length(detail) <= 600);
