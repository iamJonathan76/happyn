-- Villes de repli pour « Near You ».
--
-- Sert uniquement quand l'utilisateur refuse la localisation : il choisit une
-- ville, et on utilise SES COORDONNÉES comme point de référence.
--
-- ── Pourquoi des coordonnées et pas un filtre sur le nom ────────────────────
--
-- Le géocodeur renvoie parfois l'arrondissement plutôt que la ville reconnue :
-- « Nepean » au lieu d'Ottawa, « Hull » au lieu de Gatineau. Un filtre par
-- chaîne de caractères raterait ces événements, et il faudrait maintenir une
-- table de correspondances qui ne serait jamais complète.
--
-- En comparant des distances, le problème disparaît : un événement à Nepean est
-- à 12 km du centre d'Ottawa, donc il apparaît dans « Ottawa » quelle que soit
-- l'étiquette écrite dessus.
--
-- C'est aussi plus juste dans la vraie vie : un événement à Gatineau, à 4 km du
-- centre d'Ottawa, intéresse un Ottavien — alors qu'un filtre par nom de ville
-- l'exclurait.
--
-- Le nom de ville stocké sur `events` reste donc un simple libellé d'affichage.
-- Il n'est plus le mécanisme de filtrage.

create table if not exists public.cities (
  slug       text primary key,
  name       text not null,
  province   text not null,
  country    text not null default 'Canada',
  latitude   double precision not null,
  longitude  double precision not null,
  -- Rayon par défaut autour du centre. Une grande ville étalée mérite plus
  -- qu'une petite ville dense.
  radius_km  double precision not null default 20,
  sort_order integer not null default 100
);

alter table public.cities enable row level security;

-- Lisible par tous, y compris sans compte : la liste doit s'afficher AVANT
-- qu'on demande quoi que ce soit à l'utilisateur.
drop policy if exists "cities readable" on public.cities;
create policy "cities readable"
  on public.cities for select
  to anon, authenticated
  using (true);

-- Aucune policy d'écriture : la liste se gère depuis le tableau de bord.

insert into public.cities (slug, name, province, latitude, longitude, radius_km, sort_order)
values
  ('ottawa',   'Ottawa',   'ON', 45.4215, -75.6972, 25, 1),
  ('gatineau', 'Gatineau', 'QC', 45.4765, -75.7013, 25, 2)
on conflict (slug) do update
  set name      = excluded.name,
      latitude  = excluded.latitude,
      longitude = excluded.longitude,
      radius_km = excluded.radius_km;

comment on table public.cities is
  'Points de reference pour « Near You » quand la localisation est refusee. '
  'Le filtrage se fait par distance, pas par nom : voir events_near().';
