-- VARV. – radera konto
-- Kör en gång i Supabase: SQL Editor → New query → klistra in → Run.
-- Gör att en inloggad användare kan radera sitt eget konto och allt som sparats
-- i det, direkt från appen (Profil → Konto → Radera konto). Krävs av GDPR och App Store.

create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'Inte inloggad';
  end if;
  delete from public.user_docs where user_id = uid;
  delete from auth.users where id = uid;
end;
$$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;

-- Låter användaren lista sina egna inläggsbilder, så att appen kan ta bort
-- alla bilder i mappen när kontot raderas (även bilder som inte längre hör till ett inlägg).
drop policy if exists "Inläggsbild: se egna" on storage.objects;
create policy "Inläggsbild: se egna" on storage.objects for select to authenticated
  using (bucket_id = 'posts' and (storage.foldername(name))[1] = (select auth.uid())::text);
