-- Tableau de bord de l'organisateur, par événement.
--
-- Jusqu'ici un organisateur avait un menu, un scanner, et UN SEUL chiffre : le
-- total vendu. Il ne savait pas comment ses paliers se vendaient, qui venait,
-- ni combien de personnes étaient entrées pendant la soirée. Créer un événement
-- était possible ; le gérer ne l'était pas.
--
-- Tout passe par des fonctions SECURITY DEFINER, pour une raison précise :
-- `tickets` n'est lisible que par le détenteur de chaque billet, et c'est
-- délibéré — c'est ce qui empêche un client d'en fabriquer un. L'organisateur
-- n'y a donc aucun accès direct, et ne doit pas en avoir.

-- ── Ventes par palier ───────────────────────────────────────────────────────
-- `quantity_sold` est tenu à jour à l'émission ; on recompte quand même les
-- billets utilisés et annulés depuis `tickets`, parce que ce sont des états qui
-- changent après la vente.

create or replace function public.organizer_event_stats(p_event uuid)
returns table (
  ticket_type_id uuid,
  name           text,
  price          numeric,
  quantity_total integer,
  quantity_sold  integer,
  used_count     integer,
  cancelled_count integer,
  gross_revenue  numeric
)
language plpgsql
security definer
stable
set search_path = public
as $$
begin
  if not exists (
    select 1 from public.events e
    where e.id = p_event and e.created_by = auth.uid()
  ) then
    raise exception 'not_organizer';
  end if;

  return query
  select
    tt.id,
    tt.name,
    tt.price,
    tt.quantity_total,
    tt.quantity_sold,
    (select count(*)::int from public.tickets t
      where t.ticket_type_id = tt.id and t.status = 'used'),
    (select count(*)::int from public.tickets t
      where t.ticket_type_id = tt.id and t.status = 'cancelled'),
    -- Recette BRUTE : ce que les acheteurs ont payé, avant frais Stripe et
    -- avant toute commission. Ne jamais l'appeler « revenu » dans l'interface —
    -- ce n'est pas ce que l'organisateur touchera.
    (tt.price * tt.quantity_sold)
  from public.ticket_types tt
  where tt.event_id = p_event
  order by tt.price asc;
end;
$$;

revoke all on function public.organizer_event_stats(uuid) from public, anon;
grant execute on function public.organizer_event_stats(uuid) to authenticated;

-- ── Liste des participants ──────────────────────────────────────────────────
--
-- L'organisateur voit QUI a un billet pour SON événement. C'est légitime : il
-- tient la porte, et il doit pouvoir laisser entrer quelqu'un dont le téléphone
-- est mort.
--
-- Ce qu'il ne voit PAS : l'adresse courriel. Le nom suffit à reconnaître une
-- personne à l'entrée ; l'adresse serait une communication de coordonnées sans
-- nécessité, et rien n'empêcherait de s'en servir pour autre chose.
--
-- Ce périmètre doit être décrit dans la politique de confidentialité : acheter
-- un billet, c'est accepter que l'organisateur sache qu'on vient.

create or replace function public.organizer_attendees(p_event uuid)
returns table (
  ticket_id    uuid,
  full_name    text,
  avatar_url   text,
  type_name    text,
  status       text,
  purchased_at timestamptz
)
language plpgsql
security definer
stable
set search_path = public
as $$
begin
  if not exists (
    select 1 from public.events e
    where e.id = p_event and e.created_by = auth.uid()
  ) then
    raise exception 'not_organizer';
  end if;

  return query
  select
    t.id,
    coalesce(nullif(trim(p.full_name), ''), 'Invite'),
    p.avatar_url,
    tt.name,
    t.status,
    t.created_at
  from public.tickets t
  left join public.profiles p on p.id = t.user_id
  left join public.ticket_types tt on tt.id = t.ticket_type_id
  where t.event_id = p_event
    -- Les billets annulés disparaissent de la liste d'entrée : ils ne donnent
    -- plus accès, et les afficher ferait hésiter à la porte.
    and t.status <> 'cancelled'
  -- Les personnes déjà entrées en bas : à la porte, ce qu'on cherche c'est
  -- quelqu'un qui n'est pas encore passé.
  order by (t.status = 'used'), lower(coalesce(p.full_name, '')) asc;
end;
$$;

revoke all on function public.organizer_attendees(uuid) from public, anon;
grant execute on function public.organizer_attendees(uuid) to authenticated;
