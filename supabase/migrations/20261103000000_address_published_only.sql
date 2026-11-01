-- Adresse exacte : la restreindre aux evenements PUBLIES.
--
-- can_see_exact_address autorisait la lecture des que visibility = 'public',
-- SANS regarder le statut. Un evenement public encore en BROUILLON (ou annule)
-- voyait donc son adresse exacte lisible par n'importe qui, en anonyme, via
-- event_addresses — alors que la table events, elle, le cache. Trouve en tapant
-- l'API en direct le 2026-10-31 : 5 adresses d'evenements non publies sortaient
-- sans compte. Les evenements prives n'etaient pas touches (la branche publique
-- ne les concerne pas), mais un brouillon ne doit rien exposer avant sa
-- publication : son organisateur ne l'a pas encore rendu public.
--
-- L'angle mort du test : la fixture ne semait une adresse que sur un evenement
-- prive, jamais sur un brouillon public — le seul cas qui distingue « refuse
-- tout » de « refuse seulement le prive ». Le test seme desormais les deux.

create or replace function public.can_see_exact_address(p_event uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from public.events e
    where e.id = p_event
      and (
        (coalesce(e.visibility, 'public') = 'public' and e.status = 'published')
        or e.created_by = auth.uid()
        or public.user_holds_ticket_for(e.id)
      )
  );
$$;

revoke all on function public.can_see_exact_address(uuid) from public;
grant execute on function public.can_see_exact_address(uuid)
  to anon, authenticated;
