-- Phase 07 — « Mes connexions » sur Découvrir.
--
-- Renvoie les événements où au moins une connexion mutuelle a rendu sa présence
-- visible. C'est le pendant, à l'échelle de la découverte, de « Qui y va » sur
-- une fiche : là on demande « qui va à cet événement », ici « à quoi vont les
-- gens que je connais ».
--
-- Le filtre porte sur les ÉVÉNEMENTS, pas sur les publications. C'est le choix
-- de fond du recadrage : un fil « abonnements » de photos ferait d'HAPPYN un
-- Instagram de plus, alors que la question utile est « où vont mes amis ce
-- week-end ». Voir aussi `followingFeedProvider`, laissé débranché pour cette
-- raison.
--
-- Exactement les mêmes trois conditions que `who_is_going` — présence, visible,
-- suivi RÉCIPROQUE — plus l'exclusion des comptes bloqués. Toute divergence
-- entre les deux fonctions serait une fuite : un événement listé ici alors que
-- la fiche ne montre personne révélerait quand même que quelqu'un y va.
--
-- Ne renvoie que des identifiants : l'app croise avec les événements qu'elle a
-- déjà le droit de lire (RLS d'`events`). Un événement privé auquel le lecteur
-- n'a pas accès ne peut donc pas apparaître, même si une connexion y va.

create or replace function public.events_from_connections()
returns setof uuid
language sql
security definer
stable
set search_path = public
as $$
  select distinct a.event_id
  from public.event_attendance a
  where a.visible_to_connections
    and a.user_id <> auth.uid()
    and exists (
      select 1 from public.follows f
      where f.follower_id = auth.uid() and f.following_id = a.user_id
    )
    and exists (
      select 1 from public.follows f
      where f.follower_id = a.user_id and f.following_id = auth.uid()
    )
    and not exists (
      select 1 from public.blocked_users b
      where (b.blocker_id = auth.uid() and b.blocked_id = a.user_id)
         or (b.blocker_id = a.user_id  and b.blocked_id = auth.uid())
    );
$$;

-- Un visiteur non connecté n'a pas de connexions : `auth.uid()` étant null, les
-- clauses de réciprocité échouent et la fonction ne renvoie rien.
revoke all on function public.events_from_connections() from public, anon;
grant execute on function public.events_from_connections() to authenticated;
