-- VARV. – varje användare väljer själv om profilen får visas i förslag.
-- Offentliga profiler fortsätter som förut tills de har valt. Privata profiler visas inte förrän användaren har valt Visa.
alter table public.profiles alter column suggestable set default false;
update public.profiles set suggestable = is_public;
