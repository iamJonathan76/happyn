-- File de modération : voir ce qu'on modère.
--
-- `admin_reports` ne renvoyait que du texte. Pour une publication, ce texte
-- vaut « (image) » quand la légende est vide — c'est-à-dire presque toujours,
-- puisque ce sont justement les images qui se font signaler. Le modérateur
-- devait donc retirer un contenu, ou suspendre un compte, sans avoir vu le
-- contenu en question.
--
-- Apple (guideline 1.2) demande une modération effective sous 24 h. Décider à
-- l'aveugle n'est pas décider : soit on retire tout par précaution, soit on
-- écarte tout par défaut, et dans les deux cas le bouton « signaler » ment.
--
-- On ajoute donc une seule colonne, `target_image` : l'affiche de l'événement,
-- l'image de la publication, ou l'avatar du compte. Rien d'autre ne change —
-- les colonnes existantes gardent leur nom et leur ordre, pour qu'une version
-- de l'app plus ancienne continue de lire la file sans rien casser.

-- Ajouter une colonne au RETURNS TABLE change le type de retour, et
-- `create or replace` le refuse. Il faut donc supprimer d'abord — d'où le
-- `grant` rejoué plus bas : un DROP emporte les droits avec la fonction.
drop function if exists public.admin_reports(text);

create function public.admin_reports(p_status text default 'pending')
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
      end as target_label,
      case r.target_type
        when 'event' then (select e.created_by from public.events e where e.id = r.target_id)
        when 'post'  then (select p.author_id from public.posts p where p.id = r.target_id)
        when 'user'  then r.target_id
      end as target_author,
      -- Ce que le signalement vise, en image. Null si le contenu a déjà été
      -- retiré, ou s'il n'en a jamais eu : la carte affiche alors une pastille
      -- de repli plutôt qu'un trou.
      case r.target_type
        when 'event' then (select e.image_url from public.events e where e.id = r.target_id)
        when 'post'  then (select p.image_url from public.posts p where p.id = r.target_id)
        when 'user'  then (select pr.avatar_url from public.profiles pr where pr.id = r.target_id)
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
