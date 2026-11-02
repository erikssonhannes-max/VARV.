-- VARV. – mejl till teamet när någon anmäler en användare, och bilder i inlägg som inte blir kvar utan inlägg
-- Kör hela filen en gång i Supabase: SQL Editor → New query → klistra in → Run.
-- Kräver att notiser.sql (pg_net) och foljare.sql (anmälningar) redan är körda. Går att köra igen.
--
-- Fyll i två saker nedan innan du kör:
--   DIN_RESEND_NYCKEL  en API-nyckel från resend.com → API Keys (börjar med re_)
--   DIN_EPOST          adressen som ska få mejlen, till exempel hej@varvtraining.com
-- Nyckeln sparas i ett skyddat schema som appen och användarna aldrig kommer åt.

create table if not exists private.report_mail (
  id        integer primary key default 1 check (id = 1),
  api_key   text not null,
  to_addr   text not null,
  from_addr text not null
);
revoke all on private.report_mail from public, anon, authenticated;

insert into private.report_mail (id, api_key, to_addr, from_addr)
values (1, 'DIN_RESEND_NYCKEL', 'DIN_EPOST', 'VARV. <noreply@varvtraining.com>')
on conflict (id) do update set api_key = excluded.api_key, to_addr = excluded.to_addr, from_addr = excluded.from_addr;

create or replace function private.varv_report_mail()
returns trigger language plpgsql security definer set search_path = '' as $$
declare c record; who text; why text; n integer;
begin
  select api_key, to_addr, from_addr into c from private.report_mail where id = 1;
  if c.api_key is null or c.api_key like 'DIN_%' or c.to_addr like 'DIN_%' then return new; end if;
  select p.username || '#' || p.tag into who from public.profiles p where p.user_id = new.reporter;
  select count(*) into n from public.reports r where r.target = new.target;
  why := case new.reason when 'trakasserier' then 'Hot eller trakasserier' when 'olampligt' then 'Olämpligt namn eller bild'
                         when 'spam' then 'Spam eller falskt konto' else 'Annat' end;
  perform net.http_post(
    url := 'https://api.resend.com/emails',
    headers := jsonb_build_object('Authorization', 'Bearer ' || c.api_key, 'Content-Type', 'application/json'),
    body := jsonb_build_object(
      'from', c.from_addr,
      'to', jsonb_build_array(c.to_addr),
      'subject', 'Ny anmälan i VARV.: ' || coalesce(new.target_name, 'okänd användare'),
      'text', 'Någon har anmält en användare i VARV.' || chr(10) || chr(10)
        || 'Anmäld: ' || coalesce(new.target_name, 'okänd') || chr(10)
        || 'Anledning: ' || why || chr(10)
        || 'Kommentar: ' || coalesce(new.note, '–') || chr(10)
        || 'Anmäld av: ' || coalesce(who, 'okänd') || chr(10)
        || 'Anmälningar mot samma användare totalt: ' || n || chr(10)
        || 'Tid: ' || to_char(new.created_at at time zone 'Europe/Stockholm', 'YYYY-MM-DD HH24:MI') || chr(10) || chr(10)
        || 'Hantera anmälan på teamets sida: https://varvtraining.com/team-xurr4he4pca4/' || chr(10)
        || 'Apple kräver att anmälningar hanteras inom 24 timmar.'));
  return new;
end; $$;
revoke all on function private.varv_report_mail() from public, anon, authenticated;

drop trigger if exists varv_report_mail on public.reports;
create trigger varv_report_mail after insert on public.reports
  for each row execute function private.varv_report_mail();

-- ---------- Inlägg med bild ----------
-- Aktivitet raderas efter 60 dagar. Inlägg med bild får ligga kvar tills ägaren tar bort dem eller sitt konto,
-- så att bilden aldrig blir kvar i lagringen utan sitt inlägg.
select cron.unschedule('varv-activity-clean') where exists (select 1 from cron.job where jobname = 'varv-activity-clean');
select cron.schedule('varv-activity-clean', '30 3 * * *', $$ delete from public.activity where created_at < now() - interval '60 days' and image_url is null $$);
