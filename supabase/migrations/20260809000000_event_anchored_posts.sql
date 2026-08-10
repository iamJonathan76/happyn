-- =============================================================================
-- HAPPYN — Phase 00 : les publications sont ancrées à une expérience
-- =============================================================================
-- Décision produit : Happyn documente des expériences réelles. Une publication
-- sans événement n'a pas sa place — « pour poster des photos, il y a Instagram ».
--
-- Deux choses à corriger, dont une faille déjà en production :
--
--   1. `posts.event_id` était optionnelle → fil généraliste possible.
--      Elle devient obligatoire.
--
--   2. La policy d'insertion ne vérifiait QUE `auth.uid() = author_id`.
--      N'importe qui pouvait donc rattacher une publication à n'importe quel
--      événement pour capter de la visibilité, sans billet ni rôle
--      d'organisateur — exactement l'abus décrit dans la spec produit.
--      Le filtrage côté Flutter ne suffit pas : la barrière est ici.
--
-- À exécuter dans le SQL Editor du dashboard Supabase.
-- =============================================================================

-- ── 1. Purge des publications sans événement ────────────────────────────────
-- Avant lancement : ce sont des données de test. On ne code pas de migration
-- de repli pour du contenu qui n'existe que sur nos propres comptes.
delete from public.posts where event_id is null;

-- ── 2. event_id devient obligatoire ─────────────────────────────────────────
-- ATTENTION : la contrainte était en ON DELETE SET NULL. Combinée à NOT NULL,
-- supprimer un événement échouerait (tentative d'écrire null dans une colonne
-- non nulle). On repasse donc en CASCADE : une publication qui documente un
-- événement n'a plus de sens sans lui.
do $$
declare
  v_name text;
begin
  select c.conname into v_name
  from pg_constraint c
  join pg_attribute a
    on a.attrelid = c.conrelid and a.attnum = any(c.conkey)
  where c.contype = 'f'
    and c.conrelid = 'public.posts'::regclass
    and a.attname = 'event_id';

  if v_name is not null then
    execute format('alter table public.posts drop constraint %I', v_name);
  end if;

  alter table public.posts
    add constraint posts_event_id_fkey
    foreign key (event_id) references public.events(id)
    on delete cascade;
end $$;

alter table public.posts alter column event_id set not null;

-- ── 3. « Relation légitime » avec l'événement ───────────────────────────────
-- Organisateur, ou détenteur d'un billet. La phase 01 étendra cette fonction
-- à `event_attendance` (going / attended) sans toucher aux policies.
create or replace function public.can_attach_event(p_event uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from public.events e
    where e.id = p_event
      and e.created_by = auth.uid()
  )
  or exists (
    select 1 from public.tickets t
    where t.event_id = p_event
      and t.user_id = auth.uid()
  );
$$;

revoke all on function public.can_attach_event(uuid) from public, anon;
grant execute on function public.can_attach_event(uuid) to authenticated;

-- ── 4. La policy qui ferme la faille ────────────────────────────────────────
drop policy if exists "own posts insert" on public.posts;
create policy "own posts insert"
  on public.posts for insert
  to authenticated
  with check (
    auth.uid() = author_id
    and public.can_attach_event(event_id)
  );

-- ── 5. Événements que l'utilisateur peut légitimement documenter ────────────
-- Alimente le sélecteur du composeur. `setof public.events` évite toute
-- divergence de types avec la table.
create or replace function public.my_attachable_events()
returns setof public.events
language sql
security definer
stable
set search_path = public
as $$
  select e.*
  from public.events e
  where e.created_by = auth.uid()
     or exists (
       select 1 from public.tickets t
       where t.event_id = e.id
         and t.user_id = auth.uid()
     )
  order by e.start_date desc;
$$;

revoke all on function public.my_attachable_events() from public, anon;
grant execute on function public.my_attachable_events() to authenticated;

-- ── 6. La vue du fil ne contient plus que du contenu événementiel ───────────
-- `event_id` étant NOT NULL, la jointure devient stricte.
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
  (e.created_by = p.author_id) as author_is_organizer,
  (select count(*) from public.post_likes l where l.post_id = p.id)
    as like_count,
  exists (
    select 1 from public.post_likes l
    where l.post_id = p.id and l.user_id = auth.uid()
  ) as liked_by_me
from public.posts p
join public.events e on e.id = p.event_id
left join public.profiles pr on pr.id = p.author_id;

grant select on public.feed_posts to anon, authenticated;
