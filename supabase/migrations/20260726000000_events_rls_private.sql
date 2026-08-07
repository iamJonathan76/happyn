-- =============================================================================
-- HAPPYN — Correctif RLS : les événements privés étaient lisibles par tous
-- =============================================================================
-- L'ancienne policy « Anyone can view events » utilisait `using (true)` : toute
-- personne disposant de la clé anon (publique, présente dans l'app et bientôt
-- sur le site web) pouvait interroger l'API REST directement et lister TOUS les
-- événements — y compris ceux en `visibility = 'private'` AVEC leur
-- `access_code`. Le filtrage fait dans `eventsProvider` est un filtre de
-- requête, pas une barrière de sécurité.
--
-- Nouvelle règle de lecture, un événement est visible si :
--   1. il est public, OU
--   2. on en est l'organisateur, OU
--   3. on détient un billet pour cet événement (indispensable : « Mes billets »
--      fait un join `events(*)`, et un participant doit voir son événement même
--      s'il est privé, dépublié ou annulé).
--
-- `unlock_private_event(code)` continue de fonctionner : elle est en
-- SECURITY DEFINER et contourne donc la RLS pour l'invité qui a le code.
-- À exécuter dans le SQL Editor du dashboard Supabase.
-- =============================================================================

drop policy if exists "Anyone can view events" on public.events;
drop policy if exists "events readable" on public.events;

create policy "events readable"
  on public.events for select
  to anon, authenticated
  using (
    coalesce(visibility, 'public') = 'public'
    or created_by = auth.uid()
    or exists (
      select 1
      from public.tickets t
      where t.event_id = events.id
        and t.user_id = auth.uid()
    )
  );
