-- VARV. – profilsidan
-- Kör hela filen en gång i Supabase: SQL Editor → New query → klistra in → Run.
-- Kräver att profiler.sql redan är körd. Går att köra igen.

-- Det användaren själv har valt att visa på sin profil: ort, ålder, klass,
-- presentation, startår och de statistikdelar som är påslagna. Appen skickar
-- bara med det som är påslaget, så det som inte delas finns inte här alls.
-- Samma regler som för resten av profilen styr vem som kan läsa den.
alter table public.profiles add column if not exists card jsonb;
alter table public.profiles drop constraint if exists profiles_card_check;
alter table public.profiles add constraint profiles_card_check
  check (card is null or (jsonb_typeof(card) = 'object' and pg_column_size(card) <= 16000));
