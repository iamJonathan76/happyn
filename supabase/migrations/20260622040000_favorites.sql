-- =============================================================================
-- HAPPYN — Favoris (cœurs persistés)
-- =============================================================================
-- Chaque ligne = un event mis en favori par un utilisateur.
-- RLS : chacun ne gère que SES propres favoris.
-- À exécuter dans le SQL Editor.
-- =============================================================================

create table if not exists public.favorites (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users(id) on delete cascade,
  event_id   uuid not null references public.events(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (user_id, event_id)
);

create index if not exists favorites_user_idx on public.favorites (user_id);

alter table public.favorites enable row level security;

drop policy if exists "own favorites select" on public.favorites;
create policy "own favorites select"
  on public.favorites for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "own favorites insert" on public.favorites;
create policy "own favorites insert"
  on public.favorites for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "own favorites delete" on public.favorites;
create policy "own favorites delete"
  on public.favorites for delete
  to authenticated
  using (auth.uid() = user_id);
