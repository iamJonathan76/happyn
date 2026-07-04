-- =============================================================================
-- HAPPYN — Champs de profil (onboarding « Complete your profile »)
-- =============================================================================
-- Ajoute ville, bio, centres d'intérêt et un flag `onboarded` sur profiles.
-- `onboarded` = true une fois l'écran d'onboarding complété OU passé (skip),
-- pour ne plus le reproposer. À exécuter dans le SQL Editor.
-- =============================================================================

alter table public.profiles
  add column if not exists city       text,
  add column if not exists bio        text,
  add column if not exists interests  text[] not null default '{}',
  add column if not exists onboarded  boolean not null default false;
