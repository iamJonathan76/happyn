-- La forme des images, pour les afficher en entier.
--
-- Le fil forcait toute image en 4:5 et la rognait pour remplir le cadre : une
-- affiche paysage ou carree perdait ses bords. Decide le 2026-10-07 :
-- affichage bord a bord, chaque image dans sa forme, bornee comme sur
-- Instagram entre 4:5 (portrait) et 1.91:1 (paysage).
--
-- Pourquoi stocker la forme plutot que la lire sur l'image : le fil doit
-- connaitre la hauteur de chaque publication AVANT que l'image arrive. Sans
-- elle, chaque image qui se charge pousse tout ce qui est dessous, et le fil
-- saute sous le doigt.
--
-- Largeur / hauteur, mesuree par l'app apres recadrage. NULL pour les
-- publications d'avant, qui restent affichees en 4:5. Bornes larges : ce
-- sont celles d'une image plausible, pas celles de l'affichage.

alter table public.posts
  add column if not exists image_aspect real;

alter table public.posts
  drop constraint if exists posts_image_aspect_range;
alter table public.posts
  add constraint posts_image_aspect_range
  check (image_aspect is null or image_aspect between 0.2 and 5);

-- Le fil : reprise de 20261007010000, deux colonnes ajoutees a la fin — la
-- forme de l'image, et la ville de l'evenement pour la mini-carte qui remplace
-- la pastille « View event ».

create or replace view public.feed_posts as
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
  ) as liked_by_me,
  p.edited_at,
  (select count(*) from public.post_comments c where c.post_id = p.id)
    as comment_count,
  p.comments_disabled,
  p.image_aspect,
  e.city as event_city
from public.posts p
join public.events e on e.id = p.event_id
left join public.profiles pr on pr.id = p.author_id
where
  coalesce(e.posts_visibility, 'public') = 'public'
  or public.can_attach_event(p.event_id);
