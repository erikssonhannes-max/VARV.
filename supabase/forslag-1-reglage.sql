-- VARV. – steg 1 av 2: reglaget "Kan föreslås för andra".
-- Kör det här först. Förslagen ändras inte än, men användarna kan välja bort dem innan steg 2 körs.
alter table public.profiles add column if not exists suggestable boolean not null default true;
