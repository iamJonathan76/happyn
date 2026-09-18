-- =============================================================================
-- HAPPYN — Liste des participants, pour l'organisateur
-- =============================================================================
-- L'organisateur voyait COMBIEN de billets étaient vendus, jamais QUI vient.
-- À la porte, le scanner valide un QR mais ne dit pas qui manque encore ; et
-- avant l'événement, rien ne permet de préparer un accueil.
--
-- POURQUOI UNE FONCTION, ET PAS UNE POLICY SUR `tickets`
--
--   1. `tickets` n'a qu'une policy SELECT (`auth.uid() = user_id`) et AUCUNE
--      policy d'écriture — c'est précisément ce qui empêche un client de se
--      fabriquer un billet. On n'élargit pas la surface de la table qui porte
--      l'argent pour un besoin d'affichage.
--
--   2. Une policy sur `tickets` qui sous-interroge `events` retomberait dans
--      la récursion de policy qui a déjà vidé « Mes événements »
--      (voir 20260726040000 et 20260814020000). Le contournement retenu dans
--      ce projet est justement la fonction SECURITY DEFINER.
--
--   3. Une fonction choisit EXACTEMENT les colonnes qui sortent. L'organisateur
--      a besoin d'un nom et d'un décompte — pas du `qr_token` de chacun, qui
--      est la clé d'entrée elle-même.
--
-- UNE LIGNE PAR PERSONNE, PAS PAR BILLET
-- Qui achète trois places est une personne qui vient à trois, pas trois
-- inscrits. L'organisateur compte des arrivées à sa porte.
--
-- ⚠️ À NE PAS CONFONDRE AVEC `who_is_going`
-- Celle-là est sociale : opt-in explicite, réservée aux connexions mutuelles.
-- Celle-ci est opérationnelle : l'organisateur voit tous ses détenteurs de
-- billets. Le drapeau `visible_to_connections` ne filtre donc PAS ici — il
-- gouverne ce que voient les pairs, pas la billetterie. Un blocage entre
-- comptes ne filtre pas non plus : la personne a payé, elle se présentera à la
-- porte, la cacher à l'organisateur ne ferait que la rendre impossible à
-- accueillir.
--
-- À exécuter dans le SQL Editor du dashboard Supabase.
-- =============================================================================

create or replace function public.event_attendees(p_event uuid)
returns table (
  id              uuid,
  full_name       text,
  avatar_url      text,
  ticket_count    bigint,
  scanned_count   bigint,
  first_ticket_at timestamptz
)
language plpgsql
security definer
stable
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;

  -- Seul le créateur de l'événement. On lève plutôt que de renvoyer vide : un
  -- résultat vide se confondrait avec « personne n'a encore de billet », et
  -- l'app n'appelle cette fonction que pour un organisateur — une erreur ici
  -- signale donc un vrai défaut, pas un cas courant.
  if not exists (
    select 1 from public.events e
    where e.id = p_event and e.created_by = auth.uid()
  ) then
    raise exception 'not_authorized';
  end if;

  return query
    select
      t.user_id,
      p.full_name,
      p.avatar_url,
      -- Les billets annulés sont exclus : la place a été rendue au stock, la
      -- personne ne viendra pas. La compter ferait préparer un accueil de trop.
      count(*)                                      as ticket_count,
      count(*) filter (where t.status = 'used')     as scanned_count,
      min(t.purchased_at)                           as first_ticket_at
    from public.tickets t
    -- `left join` : un profil manquant ne doit pas faire disparaître un
    -- détenteur de billet de la liste de porte. L'app affiche alors un libellé
    -- de repli plutôt que rien.
    left join public.profiles p on p.id = t.user_id
    where t.event_id = p_event
      and t.status in ('valid', 'used')
    group by t.user_id, p.full_name, p.avatar_url
    order by min(t.purchased_at) asc;
end;
$$;

comment on function public.event_attendees(uuid) is
  'Liste des détenteurs de billets d''un événement, une ligne par personne. '
  'Réservée à l''organisateur (events.created_by). Usage opérationnel — sans '
  'rapport avec who_is_going, qui est sociale et sur opt-in.';

revoke all on function public.event_attendees(uuid) from public, anon;
grant execute on function public.event_attendees(uuid) to authenticated;
