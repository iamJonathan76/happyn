-- =============================================================================
-- HAPPYN — Table des catégories officielles
-- =============================================================================
-- Source unique de vérité pour les catégories (fini le texte libre + les 3
-- listes codées en dur dans Home/Discover/Create qui divergeaient).
-- `events.category` reste un texte (le NOM de la catégorie) — non-breaking ;
-- l'app pilote juste tous ses menus/filtres depuis cette table.
-- RLS : lecture publique.
-- =============================================================================

create table if not exists public.categories (
  id         uuid primary key default gen_random_uuid(),
  name       text not null unique,
  emoji      text,
  sort_order int  not null default 0,
  is_active  boolean not null default true,
  created_at timestamptz not null default now()
);

-- Au cas où la table existait déjà sans ces colonnes (run partiel précédent)
alter table public.categories add column if not exists emoji text;
alter table public.categories add column if not exists sort_order int not null default 0;
alter table public.categories add column if not exists is_active boolean not null default true;
alter table public.categories add column if not exists created_at timestamptz not null default now();

alter table public.categories enable row level security;

drop policy if exists "categories are public" on public.categories;
create policy "categories are public"
  on public.categories for select
  using (true);

-- Nécessaire pour le `on conflict (name)` du seed
create unique index if not exists categories_name_unique
  on public.categories (name);

-- Seed (idempotent)
insert into public.categories (name, emoji, sort_order) values
  ('Music',        '🎵', 1),
  ('Party',        '🎉', 2),
  ('Festival',     '🎪', 3),
  ('Networking',   '🤝', 4),
  ('Art',          '🎨', 5),
  ('Sports',       '⚽', 6),
  ('Food & Drink', '🍽️', 7),
  ('Other',        '✨', 8)
on conflict (name) do nothing;
