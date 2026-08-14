-- Séparer « qui peut entrer » de « qui peut voir ce qui s'y est passé ».
--
-- Jusqu'ici `events.visibility` portait les deux questions à la fois, alors
-- que ce sont deux décisions différentes :
--
--   • un lancement veut l'entrée fermée et les photos PUBLIQUES (c'est tout
--     l'intérêt : montrer que ça a eu lieu sans que personne puisse s'inviter) ;
--   • un mariage veut l'entrée fermée et les photos ENTRE INVITÉS.
--
-- Aucune règle globale ne peut deviner laquelle des deux : seul l'organisateur
-- le sait. D'où une seconde colonne, qu'il choisit à la création.
--
-- Défaut volontairement prudent : 'invitees'. Exposer sa soirée doit être un
-- oui explicite ; l'inverse ne doit jamais arriver par accident.
--
-- Ce que ça NE change PAS : qui a le droit de publier (toujours organisateur
-- ou détenteur de billet, via `can_attach_event`), et le fait qu'un événement
-- privé n'apparaisse jamais dans Discover (RLS de `events`, inchangée). Un
-- événement privé ne se découvre pas, il se raconte.

alter table public.events
  add column if not exists posts_visibility text not null default 'invitees';

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'events_posts_visibility_check'
  ) then
    alter table public.events
      add constraint events_posts_visibility_check
      check (posts_visibility in ('invitees', 'public'));
  end if;
end $$;

-- Les événements publics n'ont pas de question à se poser : tout y est public.
-- Sans ce backfill, la valeur par défaut 'invitees' les rendrait plus fermés
-- qu'ils ne l'étaient, ce qui serait une régression silencieuse.
update public.events
set posts_visibility = 'public'
where coalesce(visibility, 'public') = 'public';

comment on column public.events.posts_visibility is
  'Portée des publications rattachées : ''public'' (fil de tous) ou '
  '''invitees'' (organisateur + détenteurs de billet). Ne concerne que les '
  'événements privés ; un événement public est toujours ''public''.';

-- ── La vue applique la règle ────────────────────────────────────────────────
-- Le filtre est ici, pas dans l'app : `posts` est lisible par tous
-- (`using (true)`) et cette vue s'exécute avec les droits de son propriétaire,
-- donc la RLS de `events` ne la protège pas. Un client bidouillé n'y échappe
-- pas non plus.
--
-- `event_visibility` est ajoutée pour que la carte puisse dire « Sur
-- invitation » au lieu de « Obtenir des billets » — promettre un billet qu'on
-- ne peut pas acheter serait pire que ne rien dire.

drop view if exists public.feed_posts;

create view public.feed_posts as
select
  p.id,
  p.author_id,
  p.caption,
  p.image_url,
  p.event_id,
  p.created_at,
  pr.full_name  as author_name,
  pr.avatar_url as author_avatar,
  e.title       as event_title,
  e.start_date  as event_start_date,
  e.image_url   as event_image,
  coalesce(e.visibility, 'public') as event_visibility,
  (e.created_by = p.author_id) as author_is_organizer,
  (select count(*) from public.post_likes l where l.post_id = p.id)
    as like_count,
  exists (
    select 1 from public.post_likes l
    where l.post_id = p.id and l.user_id = auth.uid()
  ) as liked_by_me
from public.posts p
join public.events e on e.id = p.event_id
left join public.profiles pr on pr.id = p.author_id
where
  -- L'organisateur a ouvert les photos (ou l'événement est public).
  coalesce(e.posts_visibility, 'public') = 'public'
  -- Sinon, seuls ceux qui y ont accès les voient. Un visiteur anonyme n'a pas
  -- d'auth.uid() : cette branche est fausse pour lui, il ne voit donc que les
  -- publications ouvertes.
  or public.can_attach_event(p.event_id);

grant select on public.feed_posts to anon, authenticated;

-- `can_attach_event` n'était exécutable que par `authenticated`. La vue est
-- aussi lue par `anon` (fil sans compte) : sans ce droit la lecture échouerait
-- au lieu de simplement masquer les publications réservées aux invités.
grant execute on function public.can_attach_event(uuid) to anon;
