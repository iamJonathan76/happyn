-- =============================================================================
-- HAPPYN — Supabase Storage pour les images d'événements
-- =============================================================================
-- Crée le bucket public `events` et ses policies :
--   - lecture publique (les images d'events s'affichent pour tout le monde)
--   - upload réservé aux utilisateurs authentifiés, dans LEUR propre dossier
--     ({user_id}/...) pour éviter qu'on écrase les fichiers d'autrui
--   - update/delete de ses propres fichiers uniquement
--
-- Chemin de fichier convenu : `{auth.uid()}/{timestamp}.jpg`
-- À exécuter dans le SQL Editor du dashboard Supabase.
-- =============================================================================

insert into storage.buckets (id, name, public)
values ('events', 'events', true)
on conflict (id) do nothing;

-- Lecture publique des images du bucket events
drop policy if exists "events images are public" on storage.objects;
create policy "events images are public"
  on storage.objects for select
  using (bucket_id = 'events');

-- Upload dans son propre dossier
drop policy if exists "users upload own event images" on storage.objects;
create policy "users upload own event images"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'events'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Mise à jour de ses propres fichiers
drop policy if exists "users update own event images" on storage.objects;
create policy "users update own event images"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'events'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Suppression de ses propres fichiers
drop policy if exists "users delete own event images" on storage.objects;
create policy "users delete own event images"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'events'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
