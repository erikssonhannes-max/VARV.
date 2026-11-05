-- VARV. – konton med e-post kan bara skapas med godkända villkor och intygad ålder.
-- Kör en gång i SQL Editor. Gäller nya konton, befintliga påverkas inte.
-- Obs: konton som skapas för hand i Supabase blockeras också. Vill du aktivera Google behöver funktionen ses över, eftersom Google-inloggning saknar samtycket.
create or replace function public.varv_require_consent()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if coalesce(new.raw_app_meta_data->>'provider', 'email') = 'email'
     and not (coalesce((new.raw_user_meta_data->>'health_consent')::boolean, false)
              and coalesce((new.raw_user_meta_data->>'age_16')::boolean, false)
              and coalesce(new.raw_user_meta_data->>'terms_version', '') <> '') then
    raise exception 'Villkoren måste godkännas för att skapa konto';
  end if;
  return new;
end; $$;

revoke all on function public.varv_require_consent() from public, anon, authenticated;

drop trigger if exists varv_require_consent on auth.users;
create trigger varv_require_consent before insert on auth.users
  for each row execute function public.varv_require_consent();
