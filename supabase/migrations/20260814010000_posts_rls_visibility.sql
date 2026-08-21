-- Correctif : la portée des publications n'était appliquée QUE par la vue.
--
-- La migration précédente filtrait `feed_posts` sur `posts_visibility`, ce qui
-- protège l'app — mais la table `posts` gardait `using (true)`. La clé anon est
-- publique par nature (elle est dans l'app), donc n'importe qui pouvait
-- interroger `posts` directement et lire la légende, l'`image_url` et
-- l'`event_id` de publications censées rester entre invités. Le filtre de la
-- vue ne protégeait rien contre autre chose que notre propre client.
--
-- La règle doit vivre sur la TABLE. La vue peut alors la répéter pour la
-- lisibilité, mais ce n'est plus elle qui garde la porte.
--
-- Fonction SECURITY DEFINER plutôt qu'un sous-select direct sur `events` :
--   1. `events` a sa propre RLS, qui cache les événements privés. Un
--      sous-select direct verrait donc « pas d'événement » et masquerait la
--      publication même à l'organisateur.
--   2. c'est le même piège de récursion de policy qui avait déjà vidé
--      « Mes événements » (voir 20260726040000).

create or replace function public.event_posts_are_public(p_event uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select coalesce(
    (select coalesce(e.posts_visibility, 'public') = 'public'
       from public.events e
      where e.id = p_event),
    false
  );
$$;

revoke all on function public.event_posts_are_public(uuid) from public;
grant execute on function public.event_posts_are_public(uuid)
  to anon, authenticated;

drop policy if exists "posts readable" on public.posts;

create policy "posts readable"
  on public.posts for select
  to anon, authenticated
  using (
    -- L'organisateur a ouvert les photos (ou l'événement est public).
    public.event_posts_are_public(event_id)
    -- Sinon : organisateur ou détenteur de billet. Un visiteur anonyme n'a pas
    -- d'auth.uid(), les deux branches sont donc fausses pour lui.
    or public.can_attach_event(event_id)
  );

-- ── Les likes suivent ───────────────────────────────────────────────────────
-- Sans ça on ne lit pas la publication, mais on peut encore compter ses likes
-- et donc prouver son existence.
drop policy if exists "likes readable" on public.post_likes;

create policy "likes readable"
  on public.post_likes for select
  to anon, authenticated
  using (
    exists (
      select 1 from public.posts p
      where p.id = post_id
        and (public.event_posts_are_public(p.event_id)
             or public.can_attach_event(p.event_id))
    )
  );
