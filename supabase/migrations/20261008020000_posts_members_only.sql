-- Les publications et leurs « j'aime » reserves aux comptes.
--
-- Decide le 2026-10-08 : pas de mode visiteur pour l'instant. Au lancement,
-- l'app aura peu d'evenements, et un visiteur verrait une vitrine presque
-- vide ; le compte reste obligatoire pour tout.
--
-- La base doit le dire aussi. La vue du fil et l'annuaire etaient deja fermes
-- aux anonymes (20261008000000), mais la TABLE `posts` restait lisible en
-- direct : legende, image, evenement, identifiant de l'auteur. Pas une fuite
-- grave — ces publications sont publiques par choix de l'organisateur — mais
-- une regle incoherente, et c'est par les incoherences que passent les
-- failles. Memes conditions qu'avant, seulement pour `authenticated`.
--
-- Si un mode visiteur revient un jour, il se decidera ici, et s'ecrira
-- d'abord comme un test dans tests/rls/access_rules.sql.

drop policy if exists "posts readable" on public.posts;
create policy "posts readable"
  on public.posts for select
  to authenticated
  using (public.event_posts_are_public(event_id) or public.can_attach_event(event_id));

drop policy if exists "likes readable" on public.post_likes;
create policy "likes readable"
  on public.post_likes for select
  to authenticated
  using (exists (
    select 1 from public.posts p
    where p.id = post_likes.post_id
      and (public.event_posts_are_public(p.event_id) or public.can_attach_event(p.event_id))
  ));
