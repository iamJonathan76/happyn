-- Signalements : savoir ce qu'on modère.
--
-- Deux manques distincts, qui se corrigent à deux endroits.
--
-- 1. L'ALERTE EST AVEUGLE. `notify-report` ne reçoit que la ligne `reports`,
--    qui porte un `target_id` et rien d'autre de lisible. Le courriel annonce
--    donc « signalement (event) — motif : spam » sans jamais dire QUEL
--    événement. Impossible de juger de l'urgence : un signalement visant une
--    soirée de dix personnes et un autre visant un événement à mille places
--    arrivent avec le même texte.
--
-- 2. LA FILE MONTRE, MAIS NE DIT PAS. Depuis `moderation_thumbnails` on voit
--    une vignette et un titre. C'est assez pour reconnaître, pas pour décider :
--    retirer un événement prive des gens de ce qu'ils ont payé, et ça se
--    tranche sur la description, la date, le lieu — pas sur une image de 58 px.

-- ── 1. Le libellé voyage avec la ligne ──────────────────────────────────────
--
-- Rempli par trigger et stocké sur `reports` plutôt que calculé à l'envoi :
-- le webhook de base transmet la ligne telle quelle, sans jointure possible.
-- C'est la seule façon pour `notify-report` de nommer la cible sans recevoir
-- une clé de service — donc sans qu'une fonction de plus puisse tout lire.
--
-- Figé à l'instant du signalement, ce qui est correct ici : on veut savoir ce
-- qui a été signalé, pas ce que l'auteur a réécrit depuis.

alter table public.reports
  add column if not exists target_label text;

comment on column public.reports.target_label is
  'Nom de la cible au moment du signalement. Pose par trigger : le webhook de '
  'base n''envoie que la ligne, sans jointure.';

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
  end;
  return new;
end;
$$;

drop trigger if exists reports_fill_label on public.reports;
create trigger reports_fill_label
  before insert on public.reports
  for each row execute function public.reports_fill_label();

-- ── 2. De quoi juger, pas seulement reconnaître ─────────────────────────────
--
-- SECURITY DEFINER parce qu'un modérateur doit pouvoir lire ce qu'il modère :
-- un événement privé signalé n'est pas visible de lui par les policies
-- normales, et refuser de l'afficher reviendrait à lui demander de trancher
-- sans regarder.
--
-- Renvoie du jsonb plutôt qu'une table : les trois types n'ont pas les mêmes
-- champs, et une table commune imposerait vingt colonnes nulles aux deux
-- autres.

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
      -- Ce chiffre change la decision : depublier un evenement sans billet
      -- vendu ne lese personne, le faire quand trente personnes ont paye est
      -- une autre affaire. Les billets annules ne comptent pas : leur
      -- detenteur a deja ete rembourse, il n'a plus rien a perdre ici.
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
      -- Un compte qui publie beaucoup et un compte creé hier ne se suspendent
      -- pas avec la meme legerete.
      'post_count',   (select count(*) from public.posts p where p.author_id = pr.id),
      'event_count',  (select count(*) from public.events e where e.created_by = pr.id)
    )
    into result
    from public.profiles pr
    where pr.id = r.target_id;
  end if;

  -- `null` signifie « la cible n'existe plus » : deja retiree, ou compte
  -- supprime. L'ecran doit le dire plutot que d'afficher un cadre vide.
  return result;
end;
$$;

revoke all on function public.admin_report_target(uuid) from public, anon;
grant execute on function public.admin_report_target(uuid) to authenticated;
