-- =============================================================================
-- HAPPYN — Phase 04 : Who's Going
-- =============================================================================
-- Croise trois conditions, toutes obligatoires :
--
--   1. la personne a une présence sur cet événement
--   2. elle a EXPLICITEMENT rendu cette présence visible (opt-in par événement)
--   3. elle et le lecteur se suivent MUTUELLEMENT
--
-- Pourquoi la réciprocité, et pas « ceux qui me suivent » : sinon n'importe
-- quel inconnu s'autoriserait en un clic à savoir où quelqu'un sera un samedi
-- soir. Et pas « ceux que je suis » non plus : on suit des organisateurs à sens
-- unique, on ne veut pas leur donner sa position future pour autant.
-- Le suivi mutuel est la seule relation où les deux ont consenti — et c'est
-- exactement ce que dit le libellé « mes connexions ».
--
-- La table `event_attendance` n'est JAMAIS lisible directement (sa policy ne
-- laisse voir que ses propres lignes). Tout passe par cette fonction.
-- La table `tickets` n'est jamais consultée ici : détenir un billet n'est pas
-- une déclaration publique de présence.
--
-- À exécuter dans le SQL Editor du dashboard Supabase.
-- =============================================================================

create or replace function public.who_is_going(p_event uuid)
returns table (
  id         uuid,
  full_name  text,
  avatar_url text,
  status     text
)
language sql
security definer
stable
set search_path = public
as $$
  select p.id, p.full_name, p.avatar_url, a.status
  from public.event_attendance a
  join public.profiles p on p.id = a.user_id
  where a.event_id = p_event
    and a.visible_to_connections
    and a.user_id <> auth.uid()
    -- suivi réciproque, dans les deux sens
    and exists (
      select 1 from public.follows f
      where f.follower_id = auth.uid() and f.following_id = a.user_id
    )
    and exists (
      select 1 from public.follows f
      where f.follower_id = a.user_id and f.following_id = auth.uid()
    )
    -- ni bloqué, ni bloquant
    and not exists (
      select 1 from public.blocked_users b
      where (b.blocker_id = auth.uid() and b.blocked_id = a.user_id)
         or (b.blocker_id = a.user_id  and b.blocked_id = auth.uid())
    )
  order by a.created_at desc;
$$;

-- Un visiteur non connecté ne voit personne : `auth.uid()` étant null, les
-- clauses de réciprocité échouent et la fonction ne renvoie rien.
revoke all on function public.who_is_going(uuid) from public, anon;
grant execute on function public.who_is_going(uuid) to authenticated;
