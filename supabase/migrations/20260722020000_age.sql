-- =============================================================================
-- HAPPYN — Volet âge : date de naissance + exigence d'âge par événement
-- =============================================================================
--   * profiles.date_of_birth : collectée au signup (min 14 ans). Sert au
--     soft-gate d'achat et au gate 18+ pour organiser.
--   * events.min_age : exigence d'âge fixée par l'organisateur
--     (0 = All Ages, sinon 14 / 16 / 18 / 21).
--
-- Le contrôle est « soft » (âge auto-déclaré) : l'app informe et bloque
-- doucement, la vérification réelle se fait à la porte avec une pièce d'identité
-- (responsabilité de l'organisateur — cf. Organizer Standards).
-- À exécuter dans le SQL Editor du dashboard Supabase.
-- =============================================================================

alter table public.profiles
  add column if not exists date_of_birth date;

alter table public.events
  add column if not exists min_age int not null default 0;

-- Garde-fou : min_age dans un ensemble cohérent
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'events_min_age_check'
  ) then
    alter table public.events
      add constraint events_min_age_check
      check (min_age in (0, 14, 16, 18, 21));
  end if;
end $$;
