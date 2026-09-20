-- Modifier une publication.
--
-- La politique `own posts update` existe depuis `social_foundation`, mais rien
-- ne l'atteignait : l'app n'offrait aucun moyen de modifier une publication.
-- Ouvrir l'édition rend donc atteignables deux trous restés dormants.
--
--   1. Pas de `with check`. Un `using` seul vérifie la ligne AVANT
--      modification, jamais après : l'auteur pouvait réécrire `author_id` et
--      attribuer sa publication à quelqu'un d'autre.
--   2. Pas de garde de suspension. Depuis `admin_moderation`, un compte
--      suspendu ne peut plus publier — mais il pouvait encore réécrire de fond
--      en comble une publication existante, ce qui vide la suspension de son
--      sens : il suffisait d'avoir posté une fois avant d'être écarté.

drop policy if exists "own posts update" on public.posts;
create policy "own posts update"
  on public.posts for update
  to authenticated
  using (auth.uid() = author_id and not public.is_suspended())
  with check (auth.uid() = author_id and not public.is_suspended());

-- ── Une publication modifiée doit le dire ───────────────────────────────────
--
-- Des gens ont aimé ce qu'ils ont lu. Laisser le texte changer en silence
-- après coup transforme leur approbation en caution d'un propos qu'ils n'ont
-- jamais vu.

alter table public.posts
  add column if not exists edited_at timestamptz;

comment on column public.posts.edited_at is
  'Derniere modification du contenu. Posee par trigger, jamais par le client.';

-- Posé en base, pas dans l'app : une app peut oublier — ou choisir — de ne pas
-- le renseigner. Le trigger fige au passage l'auteur et la date de création,
-- qui n'ont aucune raison de bouger, ce que la policy refuse déjà pour
-- l'auteur mais pas pour `created_at`.
create or replace function public.posts_mark_edited()
returns trigger
language plpgsql
as $$
begin
  new.author_id  := old.author_id;
  new.created_at := old.created_at;

  if new.caption is distinct from old.caption
     or new.image_url is distinct from old.image_url then
    new.edited_at := now();
  else
    -- Un like ne modifie pas la publication : seul un changement de contenu
    -- doit marquer la ligne.
    new.edited_at := old.edited_at;
  end if;

  return new;
end;
$$;

drop trigger if exists posts_mark_edited on public.posts;
create trigger posts_mark_edited
  before update on public.posts
  for each row execute function public.posts_mark_edited();

-- ── La vue doit exposer la colonne ──────────────────────────────────────────
--
-- `feed_posts` liste ses colonnes une à une : sans cette redéfinition,
-- `edited_at` existe en base mais reste invisible des trois fils qui lisent la
-- vue (découverte, profil, moments d'un événement).
--
-- Ajoutée en FIN de liste : PostgreSQL n'accepte de nouvelles colonnes qu'à la
-- fin dans un `create or replace view`. C'est ce qui permet de ne pas
-- supprimer la vue, donc de ne pas perdre ses droits en route.

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
  p.edited_at
from public.posts p
join public.events e on e.id = p.event_id
left join public.profiles pr on pr.id = p.author_id
where
  coalesce(e.posts_visibility, 'public') = 'public'
  or public.can_attach_event(p.event_id);

grant select on public.feed_posts to anon, authenticated;
