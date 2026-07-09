-- =============================================================================
-- HAPPYN — Policies pour l'upsert du profil
-- =============================================================================
-- Certains comptes (créés avant le trigger, ou via OAuth) n'ont pas de ligne
-- `profiles`. Les écrans font désormais un `upsert` — il faut donc autoriser
-- l'utilisateur à INSÉRER / METTRE À JOUR sa propre ligne. (SELECT own déjà OK.)
-- À exécuter dans le SQL Editor.
-- =============================================================================

alter table public.profiles enable row level security;

drop policy if exists "own profile select" on public.profiles;
create policy "own profile select"
  on public.profiles for select
  to authenticated
  using (auth.uid() = id);

drop policy if exists "own profile insert" on public.profiles;
create policy "own profile insert"
  on public.profiles for insert
  to authenticated
  with check (auth.uid() = id);

drop policy if exists "own profile update" on public.profiles;
create policy "own profile update"
  on public.profiles for update
  to authenticated
  using (auth.uid() = id);
