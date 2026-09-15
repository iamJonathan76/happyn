-- Adresses structurées, coordonnées, et protection de l'adresse exacte.
--
-- Deux problèmes réglés ensemble parce qu'ils touchent la même donnée.
--
-- 1. `location` et `city` sont du texte libre. Aucune latitude, aucune
--    longitude. Impossible de calculer une distance, de filtrer par rayon, ou
--    de construire « Near You ». Et surtout : ça ne se rattrape pas — « Bank
--    Street » sans numéro ni ville ne redevient jamais des coordonnées.
--
-- 2. `unlock_private_event` fait `select *` : quiconque possède le code
--    d'accès reçoit l'adresse exacte, avant tout achat. Ce n'est pas une
--    amélioration à prévoir, c'est un défaut à corriger.
--
-- ── Pourquoi une table séparée plutôt que des colonnes sur `events` ─────────
--
-- La RLS de Postgres est PAR LIGNE, pas par colonne. Cacher une colonne
-- imposerait soit une vue qui réénumère tous les champs — fragile, elle casse
-- dès qu'on ajoute une colonne à `events` — soit des privilèges par colonne,
-- qui font échouer tout `select *` existant dans l'app.
--
-- En isolant l'adresse précise dans sa propre table, LA LIGNE devient
-- l'élément sensible et la RLS ordinaire suffit. Aucune vue à maintenir,
-- aucune requête existante cassée.

-- ── Localisation générale : reste sur `events`, visible de tous ─────────────

alter table public.events
  add column if not exists province text,
  add column if not exists country  text default 'Canada';

comment on column public.events.location is
  'Nom du lieu ou repere general, VISIBLE DE TOUS. L''adresse precise vit dans '
  'event_addresses. Un organisateur d''evenement prive ne doit pas y mettre son '
  'adresse civique.';

-- ── Adresse précise : table séparée, protégée ───────────────────────────────

create table if not exists public.event_addresses (
  event_id     uuid primary key references public.events(id) on delete cascade,
  address_line text,
  postal_code  text,
  latitude     double precision,
  longitude    double precision,
  -- Identifiant du fournisseur de géocodage (Photon/OSM). Permet de
  -- reconnaître une adresse déjà résolue sans la redemander.
  place_id     text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create index if not exists event_addresses_coords_idx
  on public.event_addresses (latitude, longitude);

alter table public.event_addresses enable row level security;

-- ── Qui a le droit de voir l'adresse exacte ─────────────────────────────────
--
-- Public, ou organisateur, ou DÉTENTEUR D'UN BILLET VALIDE.
--
-- Volontairement PAS « a déverrouillé avec le code » : connaître l'existence
-- d'un événement privé et savoir où il se tient exactement sont deux niveaux
-- différents. C'est tout l'intérêt de la distinction.
--
-- « Détient un billet » et non « a payé » : un billet gratuit est émis comme
-- un billet payant. Formuler la règle sur le paiement priverait à jamais les
-- événements gratuits de leur propre adresse.
--
-- SECURITY DEFINER, comme partout ailleurs : une sous-requête directe sur
-- `events` déclencherait sa RLS, qui cache justement les événements privés —
-- l'organisateur lui-même ne verrait plus son adresse.

create or replace function public.can_see_exact_address(p_event uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from public.events e
    where e.id = p_event
      and (
        coalesce(e.visibility, 'public') = 'public'
        or e.created_by = auth.uid()
        or public.user_holds_ticket_for(e.id)
      )
  );
$$;

revoke all on function public.can_see_exact_address(uuid) from public;
grant execute on function public.can_see_exact_address(uuid)
  to anon, authenticated;

drop policy if exists "addresses readable when allowed" on public.event_addresses;
create policy "addresses readable when allowed"
  on public.event_addresses for select
  to anon, authenticated
  using (public.can_see_exact_address(event_id));

-- L'organisateur gère l'adresse de ses propres événements.
drop policy if exists "organizer writes address" on public.event_addresses;
create policy "organizer writes address"
  on public.event_addresses for all
  to authenticated
  using (
    auth.uid() = (select e.created_by from public.events e where e.id = event_id)
  );

-- ── Reprise des adresses existantes ─────────────────────────────────────────
-- Best effort : on déplace le texte libre actuel dans `address_line`, sans
-- coordonnées — elles ne peuvent pas être devinées. Ces événements resteront
-- absents de « Near You » jusqu'à ce que leur organisateur les modifie, et
-- c'est la bonne façon d'échouer : mieux vaut un événement manquant qu'un
-- événement placé au mauvais endroit sur une carte.

insert into public.event_addresses (event_id, address_line)
select e.id, e.location
from public.events e
where e.location is not null
  and trim(e.location) <> ''
on conflict (event_id) do nothing;

-- ── Correction de la fuite ──────────────────────────────────────────────────
-- `select *` renvoyait toute la ligne. Maintenant que l'adresse précise vit
-- ailleurs, il reste `location`, qui devient explicitement une information
-- générale — mais on énumère quand même les colonnes plutôt que de faire
-- confiance à `*` : la prochaine colonne sensible ajoutée à `events` ne doit
-- pas se retrouver exposée par inadvertance.

create or replace function public.unlock_private_event(p_code text)
returns setof public.events
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code  text := upper(trim(p_code));
  v_event uuid;
begin
  select id into v_event
  from public.events
  where visibility = 'private'
    and upper(access_code) = v_code
  limit 1;

  if v_event is null then
    return;
  end if;

  if auth.uid() is not null then
    insert into public.event_unlocks (user_id, event_id)
    values (auth.uid(), v_event)
    on conflict do nothing;
  end if;

  -- L'adresse précise n'est PAS ici : elle est dans `event_addresses`, dont la
  -- policy exige un billet. Déverrouiller donne accès à l'événement, pas à son
  -- emplacement exact.
  return query select * from public.events where id = v_event;
end;
$$;

revoke all on function public.unlock_private_event(text) from public;
grant execute on function public.unlock_private_event(text) to authenticated, anon;

-- ── Recherche géographique, pour « Near You » ───────────────────────────────
-- Haversine en SQL pur : pas besoin de PostGIS à cette échelle, et une
-- extension de plus est une dépendance de plus à maintenir.
--
-- Ne renvoie que des événements publics, publiés et à venir : un événement
-- privé n'a pas à apparaître dans une recherche de proximité, c'est le sens
-- même de « il ne se découvre pas, il se raconte ».

create or replace function public.events_near(
  p_lat    double precision,
  p_lng    double precision,
  p_radius double precision default 20  -- kilomètres
)
returns table (event_id uuid, distance_km double precision)
language sql
stable
set search_path = public
as $$
  with candidates as (
    select
      a.event_id,
      -- `least(1.0, ...)` : une imprécision de flottant peut donner
      -- 1.0000000002 à acos(), qui renvoie alors NaN pour deux points
      -- identiques — donc une distance nulle deviendrait « inconnue ».
      6371 * acos(
        least(1.0,
          cos(radians(p_lat)) * cos(radians(a.latitude))
          * cos(radians(a.longitude) - radians(p_lng))
          + sin(radians(p_lat)) * sin(radians(a.latitude))
        )
      ) as distance_km
    from public.event_addresses a
    join public.events e on e.id = a.event_id
    where a.latitude is not null
      and a.longitude is not null
      and coalesce(e.visibility, 'public') = 'public'
      and coalesce(e.status, 'published') = 'published'
      and coalesce(e.end_date, e.start_date) > now()
  )
  select event_id, distance_km
  from candidates
  where distance_km <= p_radius
  order by distance_km asc;
$$;

grant execute on function public.events_near(double precision, double precision, double precision)
  to anon, authenticated;
