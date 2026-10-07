-- Les commentaires sous les publications.
--
-- ── Les regles, decidees le 2026-10-06 ──────────────────────────────────────
--
-- * Qui voit une publication peut la commenter — la meme regle que pour la
--   lire (`event_posts_are_public` ou participant/organisateur), pas une de
--   plus. Un compte suspendu ne commente pas, comme il ne publie pas.
-- * Un blocage, dans un sens ou dans l'autre, fait disparaitre les
--   commentaires de l'un chez l'autre, et empeche de commenter chez quelqu'un
--   qui nous a bloque. Applique ici, en base : un filtre dans l'app ne
--   protegerait rien (la cle anonyme est dans le binaire).
-- * L'auteur d'une publication peut fermer ses commentaires, et supprimer ceux
--   qui sont chez lui. Personne ne modifie un commentaire : on le supprime et
--   on le reecrit, ce qui laisse a la moderation ce qui a vraiment ete dit.
-- * Tout commentaire se signale, et la file de moderation sait le montrer et
--   le retirer — exigence Apple 1.2 pour tout contenu ecrit par les
--   utilisateurs, des le premier jour.
-- * Supprimer son compte emporte ses commentaires (cascade sur auth.users),
--   comme ses publications.
--
-- ── Au passage ──────────────────────────────────────────────────────────────
--
-- `admin_reports` ignorait les messages prives : un message signale arrivait
-- dans la file sans auteur, donc sans bouton « Suspendre ». Corrige avec
-- l'ajout des commentaires.

alter table public.posts
  add column if not exists comments_disabled boolean not null default false;

create table if not exists public.post_comments (
  id         uuid primary key default gen_random_uuid(),
  post_id    uuid not null references public.posts(id) on delete cascade,
  author_id  uuid not null references auth.users(id) on delete cascade,
  body       text not null,
  created_at timestamptz not null default now(),
  -- Un commentaire, pas un article : 500 caracteres suffisent a reagir.
  constraint post_comment_body_length check (
    char_length(trim(body)) between 1 and 500
  )
);

create index if not exists post_comments_post_created_idx
  on public.post_comments (post_id, created_at, id);

alter table public.post_comments enable row level security;

-- Vrai si l'un des deux a bloque l'autre. SECURITY DEFINER : `blocked_users`
-- n'est lisible que par celui qui bloque, et la personne bloquee doit elle
-- aussi cesser de voir.
create or replace function public.blocked_either_way(p_a uuid, p_b uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.blocked_users b
    where (b.blocker_id = p_a and b.blocked_id = p_b)
       or (b.blocker_id = p_b and b.blocked_id = p_a)
  );
$$;

revoke all on function public.blocked_either_way(uuid, uuid) from public, anon;
grant execute on function public.blocked_either_way(uuid, uuid) to authenticated;

drop policy if exists "comments readable" on public.post_comments;
create policy "comments readable"
  on public.post_comments for select
  to authenticated
  using (
    exists (
      select 1 from public.posts p
      where p.id = post_comments.post_id
        and (public.event_posts_are_public(p.event_id)
             or public.can_attach_event(p.event_id))
    )
    and not public.blocked_either_way(auth.uid(), author_id)
  );

drop policy if exists "own comments insert" on public.post_comments;
create policy "own comments insert"
  on public.post_comments for insert
  to authenticated
  with check (
    author_id = auth.uid()
    and not public.is_suspended()
    and exists (
      select 1 from public.posts p
      where p.id = post_comments.post_id
        and not p.comments_disabled
        and (public.event_posts_are_public(p.event_id)
             or public.can_attach_event(p.event_id))
        and not public.blocked_either_way(auth.uid(), p.author_id)
    )
  );

-- Le sien, ou n'importe lequel sous sa propre publication.
drop policy if exists "own or post author comments delete" on public.post_comments;
create policy "own or post author comments delete"
  on public.post_comments for delete
  to authenticated
  using (
    author_id = auth.uid()
    or exists (
      select 1 from public.posts p
      where p.id = post_comments.post_id and p.author_id = auth.uid()
    )
  );

revoke all on public.post_comments from anon, authenticated;
grant select, insert, delete on public.post_comments to authenticated;

-- ── Le fil : nombre de commentaires et fermeture ────────────────────────────
--
-- Reprise de la definition de production, deux colonnes ajoutees A LA FIN :
-- c'est ce qui permet `create or replace` sans supprimer la vue ni perdre ses
-- droits. Le nombre ne tient pas compte des blocages — c'est un compteur, pas
-- une liste ; les commentaires eux-memes sont filtres par la politique.

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
  p.comments_disabled
from public.posts p
join public.events e on e.id = p.event_id
left join public.profiles pr on pr.id = p.author_id
where
  coalesce(e.posts_visibility, 'public') = 'public'
  or public.can_attach_event(p.event_id);

-- ── Prevenir l'auteur de la publication ─────────────────────────────────────

alter table public.notifications
  add column if not exists post_id uuid
    references public.posts(id) on delete cascade;

create or replace function public.notify_post_comment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_author  uuid;
  v_name    text;
  v_lang    text;
  v_preview text;
begin
  select p.author_id into v_author from public.posts p where p.id = new.post_id;

  -- Pas de notification pour soi-meme, ni de la part de quelqu'un de bloque.
  if v_author is null
     or v_author = new.author_id
     or public.blocked_either_way(v_author, new.author_id) then
    return new;
  end if;

  select coalesce(nullif(trim(p.full_name), ''), p.username, 'HAPPYN')
    into v_name
  from public.profiles p where p.id = new.author_id;

  select p.language into v_lang from public.profiles p where p.id = v_author;

  v_preview := left(trim(new.body), 120);
  v_preview := case
    when v_lang = 'fr' then 'A commenté : « ' || v_preview || ' »'
    else                    'Commented: “' || v_preview || '”'
  end;

  -- Une ligne par publication, pas une par commentaire : la precedente non
  -- lue est remplacee. Dix reactions a une photo ne font pas dix bulles.
  delete from public.notifications
  where user_id = v_author
    and type = 'post_comment'
    and post_id = new.post_id
    and read = false;

  insert into public.notifications (user_id, type, title, body, post_id)
  values (v_author, 'post_comment', coalesce(v_name, 'HAPPYN'), v_preview,
          new.post_id);

  return new;
end;
$$;

revoke all on function public.notify_post_comment() from public, anon, authenticated;

drop trigger if exists notify_on_post_comment on public.post_comments;
create trigger notify_on_post_comment
  after insert on public.post_comments
  for each row execute function public.notify_post_comment();

-- ═══════════════════════════════════════════════════════════════════════════
-- Moderation : un commentaire se signale, se lit et se retire
-- ═══════════════════════════════════════════════════════════════════════════
--
-- Les quatre fonctions ci-dessous reprennent a l'identique leur version de
-- production (comparees le 2026-10-07) ; seuls les cas `comment` (et
-- `message` dans `admin_reports`) sont ajoutes.

alter table public.reports
  drop constraint if exists reports_target_type_check;
alter table public.reports
  add constraint reports_target_type_check
  check (target_type in ('event', 'user', 'post', 'message', 'comment'));

create or replace function public.reports_fill_label()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  new.target_label := case new.target_type
    when 'event' then (select e.title from public.events e where e.id = new.target_id)
    when 'post'  then (select coalesce(nullif(trim(p.caption), ''), '(image)')
                         from public.posts p where p.id = new.target_id)
    when 'user'  then (select pr.full_name from public.profiles pr where pr.id = new.target_id)
    when 'message' then (select left(m.body, 120)
                           from public.direct_messages m where m.id = new.target_id)
    when 'comment' then (select left(c.body, 120)
                           from public.post_comments c where c.id = new.target_id)
  end;
  return new;
end;
$$;

create or replace function public.admin_report_target(p_report uuid)
returns jsonb
language plpgsql
security definer
stable
set search_path = public
as $$
declare
  r      public.reports;
  result jsonb;
begin
  if not public.i_am_admin() then
    raise exception 'not_admin';
  end if;

  select * into r from public.reports where id = p_report;
  if not found then
    return null;
  end if;

  if r.target_type = 'event' then
    select jsonb_build_object(
      'type',        'event',
      'title',       e.title,
      'description', e.description,
      'image_url',   e.image_url,
      'start_date',  e.start_date,
      'end_date',    e.end_date,
      'city',        e.city,
      'location',    e.location,
      'category',    e.category,
      'price',       e.price,
      'status',      e.status,
      'visibility',  coalesce(e.visibility, 'public'),
      'author_id',   e.created_by,
      'author_name', (select pr.full_name from public.profiles pr where pr.id = e.created_by),
      'tickets_sold', (
        select count(*) from public.tickets t
        where t.event_id = e.id
          and coalesce(t.status, '') <> 'cancelled'
      )
    )
    into result
    from public.events e
    where e.id = r.target_id;

  elsif r.target_type = 'post' then
    select jsonb_build_object(
      'type',        'post',
      'caption',     p.caption,
      'image_url',   p.image_url,
      'created_at',  p.created_at,
      'edited_at',   p.edited_at,
      'author_id',   p.author_id,
      'author_name', (select pr.full_name from public.profiles pr where pr.id = p.author_id),
      'event_title', (select e.title from public.events e where e.id = p.event_id),
      'like_count',  (select count(*) from public.post_likes l where l.post_id = p.id)
    )
    into result
    from public.posts p
    where p.id = r.target_id;

  elsif r.target_type = 'user' then
    select jsonb_build_object(
      'type',         'user',
      'full_name',    pr.full_name,
      'username',     pr.username,
      'avatar_url',   pr.avatar_url,
      'is_suspended', pr.is_suspended,
      'author_id',    pr.id,
      'post_count',   (select count(*) from public.posts p where p.author_id = pr.id),
      'event_count',  (select count(*) from public.events e where e.created_by = pr.id)
    )
    into result
    from public.profiles pr
    where pr.id = r.target_id;

  elsif r.target_type = 'message' then
    select jsonb_build_object(
      'type',        'message',
      'body',        m.body,
      'created_at',  m.created_at,
      'author_id',   m.sender_id,
      'author_name', (select pr.full_name from public.profiles pr
                       where pr.id = m.sender_id),
      'context', (
        select coalesce(jsonb_agg(x order by x_created), '[]'::jsonb)
        from (
          select jsonb_build_object(
                   'body', prev.body,
                   'mine', prev.sender_id is not distinct from m.sender_id,
                   'created_at', prev.created_at
                 ) as x,
                 prev.created_at as x_created
          from public.direct_messages prev
          where prev.conversation_id = m.conversation_id
            and prev.created_at < m.created_at
          order by prev.created_at desc
          limit 3
        ) q
      )
    )
    into result
    from public.direct_messages m
    where m.id = r.target_id;
  elsif r.target_type = 'comment' then
    -- La publication sous laquelle le commentaire a ete ecrit : « bravo » sous
    -- une photo de soiree et sous la photo d'une personne ne se jugent pas
    -- pareil.
    select jsonb_build_object(
      'type',         'comment',
      'body',         c.body,
      'created_at',   c.created_at,
      'author_id',    c.author_id,
      'author_name',  (select pr.full_name from public.profiles pr
                        where pr.id = c.author_id),
      'post_caption', p.caption,
      'post_image',   p.image_url,
      'post_author',  (select pr.full_name from public.profiles pr
                        where pr.id = p.author_id)
    )
    into result
    from public.post_comments c
    left join public.posts p on p.id = c.post_id
    where c.id = r.target_id;
  end if;

  return result;
end;
$$;

revoke all on function public.admin_report_target(uuid) from public, anon;
grant execute on function public.admin_report_target(uuid) to authenticated;

create or replace function public.admin_remove_content(
  p_type   text,
  p_id     uuid,
  p_report uuid default null,
  p_note   text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.i_am_admin() then
    raise exception 'not_admin';
  end if;

  if p_type = 'post' then
    delete from public.posts where id = p_id;
  elsif p_type = 'event' then
    update public.events set status = 'draft' where id = p_id;
  elsif p_type = 'message' then
    delete from public.direct_messages where id = p_id;
  elsif p_type = 'comment' then
    delete from public.post_comments where id = p_id;
  else
    raise exception 'invalid_type';
  end if;

  insert into public.admin_actions (admin_id, action, target_type, target_id,
                                    report_id, note)
  values (auth.uid(), 'remove_content', p_type, p_id, p_report, p_note);
end;
$$;

revoke all on function public.admin_remove_content(text, uuid, uuid, text)
  from public, anon;
grant execute on function public.admin_remove_content(text, uuid, uuid, text)
  to authenticated;

create or replace function public.admin_reports(p_status text default 'pending')
returns table (
  id            uuid,
  target_type   text,
  target_id     uuid,
  reason        text,
  details       text,
  status        text,
  created_at    timestamptz,
  target_label  text,
  target_author uuid,
  author_name   text,
  target_image  text
)
language plpgsql
security definer
stable
set search_path = public
as $$
begin
  if not public.i_am_admin() then
    raise exception 'not_admin';
  end if;

  return query
  with base as (
    select
      r.id, r.target_type, r.target_id, r.reason, r.details, r.status,
      r.created_at,
      case r.target_type
        when 'event' then (select e.title from public.events e where e.id = r.target_id)
        when 'post'  then (select coalesce(nullif(p.caption, ''), '(image)')
                             from public.posts p where p.id = r.target_id)
        when 'user'  then (select pr.full_name from public.profiles pr where pr.id = r.target_id)
        when 'message' then (select left(m.body, 120) from public.direct_messages m where m.id = r.target_id)
        when 'comment' then (select left(c.body, 120) from public.post_comments c where c.id = r.target_id)
      end as target_label,
      case r.target_type
        when 'event' then (select e.created_by from public.events e where e.id = r.target_id)
        when 'post'  then (select p.author_id from public.posts p where p.id = r.target_id)
        when 'user'  then r.target_id
        when 'message' then (select m.sender_id from public.direct_messages m where m.id = r.target_id)
        when 'comment' then (select c.author_id from public.post_comments c where c.id = r.target_id)
      end as target_author,
      -- Ce que le signalement vise, en image. Null si le contenu a déjà été
      -- retiré, ou s'il n'en a jamais eu : la carte affiche alors une pastille
      -- de repli plutôt qu'un trou.
      case r.target_type
        when 'event' then (select e.image_url from public.events e where e.id = r.target_id)
        when 'post'  then (select p.image_url from public.posts p where p.id = r.target_id)
        when 'user'  then (select pr.avatar_url from public.profiles pr where pr.id = r.target_id)
        -- Un commentaire n'a pas d'image a lui : celle de la publication dit
        -- ou il a ete ecrit.
        when 'comment' then (select p.image_url from public.post_comments c
                               join public.posts p on p.id = c.post_id
                              where c.id = r.target_id)
      end as target_image
    from public.reports r
    where r.status = p_status
  )
  select b.id, b.target_type, b.target_id, b.reason, b.details, b.status,
         b.created_at, b.target_label, b.target_author,
         (select pr.full_name from public.profiles pr where pr.id = b.target_author),
         b.target_image
  from base b
  -- Le plus ancien d'abord : c'est lui qui approche des 24 h.
  order by b.created_at asc;
end;
$$;

revoke all on function public.admin_reports(text) from public, anon;
grant execute on function public.admin_reports(text) to authenticated;
