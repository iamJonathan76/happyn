-- =============================================================================
-- HAPPYN — Events privés (non listés + code d'invitation)
-- =============================================================================
-- Un organisateur peut créer un event « privé » : il n'apparaît JAMAIS dans la
-- découverte (Home/Discover/recherche). Seuls ceux à qui il donne le
-- `access_code` peuvent l'ouvrir et prendre un billet.
--
--   * `visibility` : 'public' (défaut) ou 'private'.
--   * `access_code` : code court partageable, généré pour les events privés.
--   * `unlock_private_event(code)` : SECURITY DEFINER, renvoie l'event si le
--     code correspond (permet à un invité de l'ouvrir sans qu'il soit listé).
--
-- Note : le masquage dans la découverte se fait aussi côté requête client
-- (on ne récupère que les events publics + les siens), donc les events privés
-- des autres ne descendent même pas sur l'appareil.
-- À exécuter dans le SQL Editor du dashboard Supabase.
-- =============================================================================

alter table public.events
  add column if not exists visibility  text not null default 'public',
  add column if not exists access_code text;

-- Les events existants restent publics (le défaut couvre déjà, ceci sécurise)
update public.events set visibility = 'public' where visibility is null;

-- Recherche rapide par code (et unicité souple : deux events ne partagent pas
-- un même code actif)
create unique index if not exists events_access_code_key
  on public.events (access_code)
  where access_code is not null;

-- ── Débloquer un event privé via son code ───────────────────────────────────
create or replace function public.unlock_private_event(p_code text)
returns setof public.events
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code text := upper(trim(p_code));
begin
  return query
  select *
  from public.events
  where visibility = 'private'
    and upper(access_code) = v_code
  limit 1;
end;
$$;

revoke all on function public.unlock_private_event(text) from public;
grant execute on function public.unlock_private_event(text) to authenticated, anon;
