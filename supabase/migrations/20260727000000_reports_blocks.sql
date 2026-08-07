-- =============================================================================
-- HAPPYN — Signalement de contenu et blocage d'utilisateurs
-- =============================================================================
-- Exigé par Apple (règle 1.2) pour toute app contenant du contenu généré par
-- les utilisateurs : HAPPYN laisse chacun publier titres, descriptions et
-- images d'événements. Sans mécanisme de signalement ET de blocage, la
-- soumission peut être refusée — au même titre que l'absence de suppression
-- de compte.
--
--   reports       : signalements (contenu ou utilisateur), revus côté admin
--   blocked_users : blocages personnels (« je ne veux plus voir ce compte »)
--
-- À exécuter dans le SQL Editor du dashboard Supabase.
-- =============================================================================

-- ── Signalements ────────────────────────────────────────────────────────────
create table if not exists public.reports (
  id          uuid primary key default gen_random_uuid(),
  -- On garde le signalement si le rapporteur supprime son compte : la
  -- modération garde sa valeur, l'identité n'est plus nécessaire.
  reporter_id uuid references auth.users(id) on delete set null,
  target_type text not null check (target_type in ('event', 'user')),
  target_id   uuid not null,
  reason      text not null,
  details     text,
  status      text not null default 'pending'
              check (status in ('pending', 'reviewed', 'actioned', 'dismissed')),
  created_at  timestamptz not null default now()
);

create index if not exists reports_target_idx
  on public.reports (target_type, target_id, status);

alter table public.reports enable row level security;

-- On peut signaler…
drop policy if exists "own reports insert" on public.reports;
create policy "own reports insert"
  on public.reports for insert
  to authenticated
  with check (auth.uid() = reporter_id);

-- …et relire ses propres signalements. Personne ne lit ceux des autres :
-- la modération se fait côté dashboard (service_role).
drop policy if exists "own reports select" on public.reports;
create policy "own reports select"
  on public.reports for select
  to authenticated
  using (auth.uid() = reporter_id);

-- ── Blocages ────────────────────────────────────────────────────────────────
create table if not exists public.blocked_users (
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  constraint no_self_block check (blocker_id <> blocked_id)
);

alter table public.blocked_users enable row level security;

drop policy if exists "own blocks select" on public.blocked_users;
create policy "own blocks select"
  on public.blocked_users for select
  to authenticated
  using (auth.uid() = blocker_id);

drop policy if exists "own blocks insert" on public.blocked_users;
create policy "own blocks insert"
  on public.blocked_users for insert
  to authenticated
  with check (auth.uid() = blocker_id);

drop policy if exists "own blocks delete" on public.blocked_users;
create policy "own blocks delete"
  on public.blocked_users for delete
  to authenticated
  using (auth.uid() = blocker_id);
