-- =============================================================================
-- HAPPYN — Fondations du social (abonnements, publications, likes)
-- =============================================================================
-- Deuxième pilier du produit (« More than events. A real community »).
-- Objectif au lancement : que l'app ait un fil rempli même avec peu
-- d'événements, et même pour un utilisateur qui ne suit encore personne.
--
--   public_profiles : vue exposant UNIQUEMENT les champs publics d'un profil
--   follows         : abonnements
--   posts           : publications (image + légende, éventuellement liées
--                     à un événement)
--   post_likes      : likes
--
-- À exécuter dans le SQL Editor du dashboard Supabase.
-- =============================================================================

-- ── Profils publics ─────────────────────────────────────────────────────────
-- Le social impose de voir le nom et l'avatar des autres. On n'ouvre PAS la
-- RLS de `profiles` : elle agit ligne par ligne, ce qui exposerait aussi
-- l'email et la date de naissance. On passe par une vue qui ne sélectionne
-- que les colonnes publiques.
create or replace view public.public_profiles as
select
  p.id,
  p.full_name,
  p.avatar_url,
  p.bio,
  p.city
from public.profiles p;

grant select on public.public_profiles to anon, authenticated;

-- ── Abonnements ─────────────────────────────────────────────────────────────
create table if not exists public.follows (
  follower_id  uuid not null references auth.users(id) on delete cascade,
  following_id uuid not null references auth.users(id) on delete cascade,
  created_at   timestamptz not null default now(),
  primary key (follower_id, following_id),
  constraint no_self_follow check (follower_id <> following_id)
);

create index if not exists follows_following_idx
  on public.follows (following_id);

alter table public.follows enable row level security;

-- Lecture publique : nécessaire pour afficher les compteurs d'abonnés.
drop policy if exists "follows readable" on public.follows;
create policy "follows readable"
  on public.follows for select
  to anon, authenticated
  using (true);

drop policy if exists "own follows insert" on public.follows;
create policy "own follows insert"
  on public.follows for insert
  to authenticated
  with check (auth.uid() = follower_id);

drop policy if exists "own follows delete" on public.follows;
create policy "own follows delete"
  on public.follows for delete
  to authenticated
  using (auth.uid() = follower_id);

-- ── Publications ────────────────────────────────────────────────────────────
create table if not exists public.posts (
  id         uuid primary key default gen_random_uuid(),
  author_id  uuid not null references auth.users(id) on delete cascade,
  caption    text,
  image_url  text,
  -- Une publication peut être rattachée à un événement (« je vais à ça »,
  -- photos d'une soirée…). Si l'événement disparaît, la publication reste.
  event_id   uuid references public.events(id) on delete set null,
  created_at timestamptz not null default now(),
  -- Une publication sans image ET sans texte n'a pas de sens.
  constraint post_not_empty check (
    coalesce(trim(caption), '') <> '' or coalesce(image_url, '') <> ''
  )
);

create index if not exists posts_author_idx  on public.posts (author_id, created_at desc);
create index if not exists posts_recent_idx  on public.posts (created_at desc);

alter table public.posts enable row level security;

-- Fil « Découvrir » : les publications sont publiques.
drop policy if exists "posts readable" on public.posts;
create policy "posts readable"
  on public.posts for select
  to anon, authenticated
  using (true);

drop policy if exists "own posts insert" on public.posts;
create policy "own posts insert"
  on public.posts for insert
  to authenticated
  with check (auth.uid() = author_id);

drop policy if exists "own posts update" on public.posts;
create policy "own posts update"
  on public.posts for update
  to authenticated
  using (auth.uid() = author_id);

drop policy if exists "own posts delete" on public.posts;
create policy "own posts delete"
  on public.posts for delete
  to authenticated
  using (auth.uid() = author_id);

-- ── Likes ───────────────────────────────────────────────────────────────────
create table if not exists public.post_likes (
  post_id    uuid not null references public.posts(id) on delete cascade,
  user_id    uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

alter table public.post_likes enable row level security;

drop policy if exists "likes readable" on public.post_likes;
create policy "likes readable"
  on public.post_likes for select
  to anon, authenticated
  using (true);

drop policy if exists "own likes insert" on public.post_likes;
create policy "own likes insert"
  on public.post_likes for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "own likes delete" on public.post_likes;
create policy "own likes delete"
  on public.post_likes for delete
  to authenticated
  using (auth.uid() = user_id);

-- ── Vue du fil : publication + auteur + likes, en une seule requête ─────────
-- `posts` n'a pas de clé étrangère vers la vue `public_profiles`, donc
-- PostgREST ne peut pas imbriquer l'auteur automatiquement. On assemble ici.
-- Comme `public_profiles`, cette vue ne sélectionne que des champs publics.
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
  (select count(*) from public.post_likes l where l.post_id = p.id)
    as like_count,
  exists (
    select 1 from public.post_likes l
    where l.post_id = p.id and l.user_id = auth.uid()
  ) as liked_by_me
from public.posts p
left join public.profiles pr on pr.id = p.author_id
left join public.events   e  on e.id = p.event_id;

grant select on public.feed_posts to anon, authenticated;

-- ── Storage : images de publications ────────────────────────────────────────
insert into storage.buckets (id, name, public)
values ('posts', 'posts', true)
on conflict (id) do nothing;

drop policy if exists "post images are public" on storage.objects;
create policy "post images are public"
  on storage.objects for select
  to anon, authenticated
  using (bucket_id = 'posts');

drop policy if exists "users upload own post images" on storage.objects;
create policy "users upload own post images"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'posts'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "users delete own post images" on storage.objects;
create policy "users delete own post images"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'posts'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
