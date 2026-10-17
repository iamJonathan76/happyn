-- Noter un événement.
--
-- ── Qui note, et quand ──────────────────────────────────────────────────────
-- Seuls ceux dont le billet a été SCANNÉ à l'entrée (`tickets.status = 'used'`)
-- peuvent noter : c'est ce qui rend une note crédible — personne ne note une
-- soirée où il n'est pas allé. L'organisateur ne note pas la sienne.
--
-- La fenêtre s'ouvre à la fin de l'événement et se ferme au même délai que le
-- versement (`payout_delay_days()`, 3 jours) : tout est clos avant que l'argent
-- parte, et changer l'un change l'autre. La demande part 24 h après la fin.
--
-- ── Qui voit quoi ───────────────────────────────────────────────────────────
-- Personne ne lit la table directement. Le public obtient la MOYENNE d'un
-- organisateur, et seulement à partir de 5 notes (une mauvaise soirée ne juge
-- pas quelqu'un). L'organisateur obtient le détail de SES événements, les
-- commentaires compris, mais SANS l'identité des auteurs : l'anonymat rend
-- les retours honnêtes et empêche toute rancune.
--
-- ── Les tags ────────────────────────────────────────────────────────────────
-- Communs (ambiance, organisation, lieu, et qualité-prix si l'événement était
-- payant) plus ceux de la catégorie : on ne demande pas « musique » pour une
-- soirée tech. La liste vit ici, une seule fois : l'app l'affiche, le serveur
-- refuse tout autre tag.

create table if not exists public.event_ratings (
  id          uuid primary key default gen_random_uuid(),
  event_id    uuid not null references public.events(id) on delete cascade,
  -- Compte supprimé : la note reste dans la moyenne, sans personne derrière.
  user_id     uuid references auth.users(id) on delete set null,
  stars       smallint not null check (stars between 1 and 5),
  tags        text[] not null default '{}' check (cardinality(tags) <= 8),
  comment     text check (char_length(comment) <= 500),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (event_id, user_id)
);

create index if not exists event_ratings_event_idx on public.event_ratings(event_id);

alter table public.event_ratings enable row level security;
revoke all on public.event_ratings from public, anon, authenticated;

-- Les tags proposés pour un événement.
create or replace function public.rating_tags_for(p_event uuid)
returns text[]
language sql stable security definer
set search_path = public
as $$
  select array['ambiance', 'organization', 'venue']
    || case when exists (select 1 from public.ticket_types tt
                          where tt.event_id = p_event and tt.price > 0)
            then array['value'] else array[]::text[] end
    || case lower(coalesce(e.category, ''))
         when 'music'        then array['music', 'sound_light']
         when 'party'        then array['music', 'sound_light']
         when 'festival'     then array['music', 'sound_light']
         when 'technology'   then array['speakers', 'content', 'networking']
         when 'business'     then array['speakers', 'content', 'networking']
         when 'networking'   then array['speakers', 'content', 'networking']
         when 'sports'       then array['level', 'facilities']
         when 'food & drink' then array['food', 'drinks']
         when 'art'          then array['artworks', 'staging']
         when 'faith'        then array['message', 'worship']
         else array[]::text[]
       end
  from public.events e
  where e.id = p_event;
$$;

-- La fin de la fenêtre de notation d'un événement.
create or replace function public.rating_closes_at(p_end timestamptz)
returns timestamptz
language sql stable
set search_path = public
as $$
  select p_end + make_interval(days => public.payout_delay_days());
$$;

-- Noter, ou corriger sa note tant que la fenêtre est ouverte.
create or replace function public.rate_event(
  p_event   uuid,
  p_stars   integer,
  p_tags    text[] default '{}',
  p_comment text default null
)
returns void
language plpgsql security definer
set search_path = public
as $$
declare
  v_user    uuid := auth.uid();
  v_end     timestamptz;
  v_owner   uuid;
  v_status  text;
  v_allowed text[];
  v_tags    text[];
  v_comment text := nullif(trim(p_comment), '');
begin
  if v_user is null then raise exception 'not_authenticated'; end if;

  select end_date, created_by, coalesce(status, 'published')
    into v_end, v_owner, v_status
  from public.events where id = p_event;
  if not found or v_status = 'cancelled' then
    raise exception 'event_not_ratable';
  end if;
  if v_owner = v_user then raise exception 'organizer_cannot_rate'; end if;

  if not exists (select 1 from public.tickets t
                 where t.event_id = p_event and t.user_id = v_user
                   and t.status = 'used') then
    raise exception 'not_attended';
  end if;

  if v_end is null or now() < v_end then raise exception 'not_ended'; end if;
  if now() > public.rating_closes_at(v_end) then raise exception 'rating_closed'; end if;

  if p_stars is null or p_stars not between 1 and 5 then
    raise exception 'invalid_stars';
  end if;

  v_allowed := public.rating_tags_for(p_event);
  select coalesce(array_agg(distinct t), '{}') into v_tags
  from unnest(coalesce(p_tags, '{}')) t;
  if exists (select 1 from unnest(v_tags) t where not (t = any (v_allowed))) then
    raise exception 'invalid_tag';
  end if;

  if char_length(v_comment) > 500 then raise exception 'comment_too_long'; end if;

  insert into public.event_ratings (event_id, user_id, stars, tags, comment)
  values (p_event, v_user, p_stars, v_tags, v_comment)
  on conflict (event_id, user_id) do update
     set stars = excluded.stars,
         tags = excluded.tags,
         comment = excluded.comment,
         updated_at = now();
end;
$$;

-- Ce dont l'écran de notation a besoin : peut-on noter, jusqu'à quand, quels
-- tags proposer, et la note déjà donnée pour la pré-remplir.
create or replace function public.my_event_rating(p_event uuid)
returns table (can_rate boolean, closes_at timestamptz, tags_offered text[],
               stars smallint, tags text[], comment text)
language sql stable security definer
set search_path = public
as $$
  select
    (e.end_date is not null and now() >= e.end_date
       and now() <= public.rating_closes_at(e.end_date)
       and coalesce(e.status, 'published') <> 'cancelled'
       and e.created_by is distinct from auth.uid()
       and exists (select 1 from public.tickets t where t.event_id = e.id
                     and t.user_id = auth.uid() and t.status = 'used')),
    public.rating_closes_at(e.end_date),
    public.rating_tags_for(e.id),
    r.stars, r.tags, r.comment
  from public.events e
  left join public.event_ratings r on r.event_id = e.id and r.user_id = auth.uid()
  where e.id = p_event and auth.uid() is not null;
$$;

-- Le détail pour l'organisateur : moyenne, tags, commentaires — sans auteurs.
create or replace function public.event_rating_summary(p_event uuid)
returns json
language plpgsql stable security definer
set search_path = public
as $$
declare
  v_owner uuid;
begin
  select created_by into v_owner from public.events where id = p_event;
  if v_owner is null or v_owner is distinct from auth.uid() then
    raise exception 'not_organizer';
  end if;
  return (
    select json_build_object(
      'count', count(*),
      'average', round(avg(r.stars)::numeric, 1),
      'tags', coalesce((
         select json_object_agg(tag, n) from (
           select t.tag, count(*) n
           from public.event_ratings r2, unnest(r2.tags) as t(tag)
           where r2.event_id = p_event group by t.tag) x), '{}'::json),
      'comments', coalesce((
         select json_agg(json_build_object(
                  'stars', r3.stars, 'comment', r3.comment, 'at', r3.created_at)
                  order by r3.created_at desc)
         from public.event_ratings r3
         where r3.event_id = p_event and r3.comment is not null), '[]'::json)
    )
    from public.event_ratings r
    where r.event_id = p_event
  );
end;
$$;

-- La moyenne publique d'un organisateur, à partir de 5 notes seulement.
create or replace function public.organizer_public_rating(p_organizer uuid)
returns table (average numeric, ratings integer)
language sql stable security definer
set search_path = public
as $$
  select round(avg(r.stars)::numeric, 1), count(*)::integer
  from public.event_ratings r
  join public.events e on e.id = r.event_id
  where e.created_by = p_organizer
  having count(*) >= 5;
$$;

revoke all on function public.rating_tags_for(uuid) from public, anon;
revoke all on function public.rating_closes_at(timestamptz) from public, anon;
revoke all on function public.rate_event(uuid, integer, text[], text) from public, anon;
revoke all on function public.my_event_rating(uuid) from public, anon;
revoke all on function public.event_rating_summary(uuid) from public, anon;
revoke all on function public.organizer_public_rating(uuid) from public;
grant execute on function public.rating_tags_for(uuid) to authenticated;
grant execute on function public.rating_closes_at(timestamptz) to authenticated;
grant execute on function public.rate_event(uuid, integer, text[], text) to authenticated;
grant execute on function public.my_event_rating(uuid) to authenticated;
grant execute on function public.event_rating_summary(uuid) to authenticated;
grant execute on function public.organizer_public_rating(uuid) to anon, authenticated;

-- ── La demande, 24 h après la fin ───────────────────────────────────────────
-- Une seule par événement : private.rating_requests le retient. Envoyée à ceux
-- dont le billet a été scanné, qui n'ont pas déjà noté, sauf l'organisateur.
-- Dans la langue de chacun, écrite ici comme le font les autres notifications
-- récentes.
create table if not exists private.rating_requests (
  event_id uuid primary key references public.events(id) on delete cascade,
  sent_at  timestamptz not null default now()
);
revoke all on private.rating_requests from public, anon, authenticated;

create or replace function private.send_rating_requests()
returns integer
language plpgsql security definer
set search_path = private, public
as $$
declare
  v_ev   record;
  v_sent integer := 0;
begin
  for v_ev in
    select e.id, e.title, e.created_by
    from public.events e
    where e.end_date <= now() - interval '24 hours'
      and now() < public.rating_closes_at(e.end_date)
      and coalesce(e.status, 'published') <> 'cancelled'
      and not exists (select 1 from private.rating_requests q where q.event_id = e.id)
  loop
    insert into private.rating_requests (event_id) values (v_ev.id)
    on conflict (event_id) do nothing;
    if not found then continue; end if;

    insert into public.notifications (user_id, type, title, body, event_id)
    select t.user_id, 'rate_event',
           case when p.language = 'fr' then 'Comment était ' || v_ev.title || ' ?'
                else 'How was ' || v_ev.title || '?' end,
           case when p.language = 'fr'
                then 'Donne ta note en 10 secondes, et partage un moment de la soirée.'
                else 'Rate it in 10 seconds, and share a moment from the night.' end,
           v_ev.id
    from (select distinct user_id from public.tickets
           where event_id = v_ev.id and status = 'used' and user_id is not null) t
    left join public.profiles p on p.id = t.user_id
    where t.user_id is distinct from v_ev.created_by
      and not exists (select 1 from public.event_ratings r
                      where r.event_id = v_ev.id and r.user_id = t.user_id);
    v_sent := v_sent + 1;
  end loop;
  return v_sent;
end;
$$;

revoke all on function private.send_rating_requests() from public, anon, authenticated;

-- PAS encore planifiée : elle enverrait « Comment était… ? » avant que l'app
-- ait l'écran de notation et que la politique de confidentialité v1.1 soit
-- acceptée. À activer avec eux :
--   select cron.schedule('happyn-rating-requests', '23 * * * *',
--                        'select private.send_rating_requests()');
