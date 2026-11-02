-- VARV. – bilder i inlägg i flödet
-- Kör hela filen en gång i Supabase: SQL Editor → New query → klistra in → Run.
-- Kräver att notiser.sql redan är körd. Går att köra igen.

-- Bilden till ett inlägg. Bara bilder från VARV.:s egen lagring är tillåtna.
alter table public.activity add column if not exists image_url text;
alter table public.activity drop constraint if exists activity_image_url_check;
alter table public.activity add constraint activity_image_url_check check (
  image_url is null or (char_length(image_url) <= 300
    and image_url like 'https://kwjnezbazyahyzsmpuyg.supabase.co/storage/v1/object/public/posts/%'));

-- Lagringen. Bilderna har slumpade namn och syns för den som har länken,
-- på samma sätt som profilbilderna. Högst 2 MB, bara JPEG och WebP.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('posts', 'posts', true, 2097152, array['image/jpeg', 'image/webp'])
on conflict (id) do update set public = true, file_size_limit = 2097152, allowed_mime_types = array['image/jpeg', 'image/webp'];

drop policy if exists "Inläggsbild: ladda upp" on storage.objects;
drop policy if exists "Inläggsbild: ta bort" on storage.objects;
-- Var och en laddar upp och tar bort i sin egen mapp.
create policy "Inläggsbild: ladda upp" on storage.objects for insert to authenticated
  with check (bucket_id = 'posts' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "Inläggsbild: ta bort" on storage.objects for delete to authenticated
  using (bucket_id = 'posts' and (storage.foldername(name))[1] = (select auth.uid())::text);
