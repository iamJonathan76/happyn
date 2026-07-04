-- =============================================================================
-- HAPPYN — Photos de profil (avatars)
-- =============================================================================
-- Bucket public `avatars` (upload dans son propre dossier) + colonne
-- `avatar_url` sur profiles. L'URL est aussi stockée dans les user metadata
-- (lecture facile partout via currentUser). À exécuter dans le SQL Editor.
-- =============================================================================

-- Colonne avatar_url (pour d'éventuelles requêtes futures)
alter table public.profiles
  add column if not exists avatar_url text;

-- Bucket public avatars
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

-- Lecture publique
drop policy if exists "avatars are public" on storage.objects;
create policy "avatars are public"
  on storage.objects for select
  using (bucket_id = 'avatars');

-- Upload dans son propre dossier
drop policy if exists "users upload own avatar" on storage.objects;
create policy "users upload own avatar"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Update de ses propres fichiers
drop policy if exists "users update own avatar" on storage.objects;
create policy "users update own avatar"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Suppression de ses propres fichiers
drop policy if exists "users delete own avatar" on storage.objects;
create policy "users delete own avatar"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
