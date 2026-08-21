-- Verser en migration les policies de `events`, `tickets` et `ticket_types`.
--
-- Ces trois tables ont été créées depuis le tableau de bord Supabase. Leurs
-- protections existaient donc uniquement là : invisibles depuis le dépôt, donc
-- invisibles pour le second développeur, absentes de toute relecture, et
-- perdues sans bruit si le projet était recréé. Ce sont précisément les tables
-- qui portent l'argent et l'accès.
--
-- Ce fichier reproduit l'état constaté le 2026-08-14 (RLS vérifiée active sur
-- les trois), à une correction près, signalée plus bas.
--
-- Idempotent : rejouable sans effet de bord.

-- ── RLS : déjà active, on le réaffirme ──────────────────────────────────────
-- Une policy sur une table dont la RLS n'est pas activée est silencieusement
-- inerte. L'affirmer ici garantit que ça reste vrai après toute recréation.
alter table public.events      enable row level security;
alter table public.tickets     enable row level security;
alter table public.ticket_types enable row level security;

-- ── events ──────────────────────────────────────────────────────────────────
-- La policy SELECT est déjà versionnée (20260726040000, via
-- user_holds_ticket_for pour éviter la récursion de policy). On ne la retouche
-- pas ici. Seules les écritures manquaient.

drop policy if exists "Authenticated users can create events" on public.events;
create policy "Authenticated users can create events"
  on public.events for insert
  to authenticated
  with check (auth.uid() = created_by);

drop policy if exists "Users can update own events" on public.events;
create policy "Users can update own events"
  on public.events for update
  to authenticated
  using (auth.uid() = created_by);

drop policy if exists "Users can delete own events" on public.events;
create policy "Users can delete own events"
  on public.events for delete
  to authenticated
  using (auth.uid() = created_by);

-- ── tickets ─────────────────────────────────────────────────────────────────
-- Lecture de ses propres billets, et RIEN d'autre. Volontairement : l'absence
-- de policy d'écriture est ce qui empêche un client de se fabriquer un billet
-- ou de repasser le sien de `used` à `valid`. L'émission passe par les
-- fonctions Edge, qui utilisent `service_role` et ne sont donc pas soumises à
-- la RLS.
--
-- NE PAS ajouter de policy insert/update/delete ici sans comprendre que ça
-- ouvre la fabrication de billets côté client.
drop policy if exists "Users see their own tickets" on public.tickets;
create policy "Users see their own tickets"
  on public.tickets for select
  to authenticated
  using (auth.uid() = user_id);

-- ── ticket_types ────────────────────────────────────────────────────────────
-- L'organisateur gère les catégories de ses propres événements. `for all` sans
-- `with check` explicite : Postgres réutilise alors l'expression `using` pour
-- les écritures, l'insertion est donc bien contrôlée.
drop policy if exists "Organizers can manage ticket types" on public.ticket_types;
create policy "Organizers can manage ticket types"
  on public.ticket_types for all
  to authenticated
  using (
    auth.uid() = (
      select e.created_by from public.events e where e.id = event_id
    )
  );

-- CORRECTION par rapport à l'état constaté.
--
-- L'ancienne policy était `using (true)` : les catégories de billets d'un
-- événement PRIVÉ (noms, prix, quantités) étaient lisibles par n'importe qui.
-- Pas un accès, seulement de l'information — mais ça contredit la promesse du
-- privé, et c'est le même schéma d'erreur que les deux failles précédentes :
-- une protection posée sur la fiche, absente de la table qui la détaille.
--
-- La lisibilité des catégories suit désormais celle de l'événement lui-même.
-- Passe par une fonction SECURITY DEFINER plutôt qu'un sous-select sur
-- `events` : la RLS d'`events` s'appliquerait au sous-select, et c'est le
-- terrain exact de la récursion de policy qui avait déjà vidé « Mes
-- événements » (voir 20260726040000).
-- Mémoriser qu'un compte a saisi le bon code.
--
-- Sans ça, restreindre `ticket_types` casse l'achat : après avoir déverrouillé
-- un événement privé, l'invité n'est ni organisateur ni encore détenteur de
-- billet, donc l'événement lui serait « illisible » et la liste des catégories
-- reviendrait vide — il ne pourrait jamais prendre le billet qu'on vient de
-- l'autoriser à prendre.
--
-- Effet secondaire souhaitable : le déverrouillage devient durable. Jusqu'ici
-- il ne vivait que dans l'écran ouvert ; il fallait ressaisir le code à chaque
-- fois.
create table if not exists public.event_unlocks (
  user_id    uuid not null references auth.users(id) on delete cascade,
  event_id   uuid not null references public.events(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, event_id)
);

alter table public.event_unlocks enable row level security;

-- Lecture de ses propres déverrouillages seulement. Aucune policy d'écriture :
-- la ligne est créée par `unlock_private_event`, qui a vérifié le code. Un
-- client ne doit pas pouvoir s'auto-déclarer déverrouillé.
drop policy if exists "own unlocks readable" on public.event_unlocks;
create policy "own unlocks readable"
  on public.event_unlocks for select
  to authenticated
  using (auth.uid() = user_id);

-- `unlock_private_event` enregistre désormais le déverrouillage. Le code est
-- toujours vérifié avant : si aucun événement ne correspond, rien n'est écrit.
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

  return query select * from public.events where id = v_event;
end;
$$;

revoke all on function public.unlock_private_event(text) from public;
grant execute on function public.unlock_private_event(text) to authenticated, anon;

create or replace function public.event_is_readable(p_event uuid)
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
        or exists (
          select 1 from public.event_unlocks u
          where u.event_id = e.id and u.user_id = auth.uid()
        )
      )
  );
$$;

revoke all on function public.event_is_readable(uuid) from public;
grant execute on function public.event_is_readable(uuid) to anon, authenticated;

drop policy if exists "Anyone can view ticket types" on public.ticket_types;
create policy "Anyone can view ticket types"
  on public.ticket_types for select
  to anon, authenticated
  using (public.event_is_readable(event_id));
