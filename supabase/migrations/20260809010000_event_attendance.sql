-- =============================================================================
-- HAPPYN — Phase 01 : la relation User ↔ Event
-- =============================================================================
-- Objet atomique du produit : « quelqu'un qui va à quelque chose ». Ni la
-- personne, ni l'événement — l'intersection des deux. C'est ce que ni
-- Instagram ni une billetterie ne possèdent.
--
-- Deux états seulement, dérivés du billet (pas d'« Interested » en v1 : pour un
-- événement gratuit, Going EST le billet — un état de plus, c'est une policy
-- et un cas de test de plus) :
--
--   going    → détient un billet
--   attended → billet scanné à l'entrée
--
-- Plus un drapeau de visibilité, PAR ÉVÉNEMENT et désactivé par défaut.
--
-- ⚠️ Distinction fondamentale : visibilité ≠ diffusion. Activer la visibilité
-- autorise ses connexions à voir la présence EN CONSULTANT l'événement. Ça ne
-- crée aucune publication, aucune notification, aucune entrée de fil.
--
-- À exécuter dans le SQL Editor du dashboard Supabase.
-- =============================================================================

create table if not exists public.event_attendance (
  user_id    uuid not null references auth.users(id) on delete cascade,
  event_id   uuid not null references public.events(id) on delete cascade,
  status     text not null default 'going'
             check (status in ('going', 'attended')),
  -- Réciprocité : seules les connexions mutuelles verront cette présence.
  -- Un abonnement à sens unique ne suffit pas — sinon n'importe qui
  -- s'autoriserait en un clic à savoir où quelqu'un sera.
  visible_to_connections boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, event_id)
);

create index if not exists event_attendance_event_idx
  on public.event_attendance (event_id)
  where visible_to_connections;

alter table public.event_attendance enable row level security;

-- On ne lit que ses propres lignes. « Who's Going » (phase 04) passera par une
-- fonction SECURITY DEFINER : jamais d'accès direct à cette table.
drop policy if exists "own attendance select" on public.event_attendance;
create policy "own attendance select"
  on public.event_attendance for select
  to authenticated
  using (auth.uid() = user_id);

-- Aucune policy INSERT/UPDATE/DELETE : les lignes sont écrites par les
-- triggers, et la visibilité par une RPC dédiée. Laisser le client faire un
-- UPDATE libre lui permettrait de se déclarer « attended » sans être venu —
-- la RLS de Postgres agit sur la ligne, pas sur la colonne.

-- ── Synchronisation depuis les billets ──────────────────────────────────────
-- Le billet est la source de vérité. Un utilisateur peut détenir plusieurs
-- billets pour un même événement : la présence existe tant qu'il en reste au
-- moins un.
create or replace function public.sync_event_attendance()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Billet créé ou modifié : garantir la présence du porteur actuel
  if (tg_op = 'INSERT' or tg_op = 'UPDATE') and new.user_id is not null then
    insert into public.event_attendance (user_id, event_id, status)
    values (new.user_id, new.event_id, 'going')
    on conflict (user_id, event_id) do nothing;

    -- Scanné à l'entrée → présence confirmée
    if new.status = 'used' then
      update public.event_attendance
         set status = 'attended', updated_at = now()
       where user_id = new.user_id
         and event_id = new.event_id
         and status <> 'attended';
    end if;
  end if;

  -- Transfert : l'ancien porteur perd sa présence s'il n'a plus aucun billet
  if tg_op = 'UPDATE' and old.user_id is distinct from new.user_id
     and old.user_id is not null then
    delete from public.event_attendance a
     where a.user_id = old.user_id
       and a.event_id = old.event_id
       and not exists (
         select 1 from public.tickets t
         where t.user_id = old.user_id and t.event_id = old.event_id
       );
  end if;

  -- Billet supprimé (annulation, suppression de compte) : même règle
  if tg_op = 'DELETE' and old.user_id is not null then
    delete from public.event_attendance a
     where a.user_id = old.user_id
       and a.event_id = old.event_id
       and not exists (
         select 1 from public.tickets t
         where t.user_id = old.user_id and t.event_id = old.event_id
       );
    return old;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_sync_event_attendance on public.tickets;
create trigger trg_sync_event_attendance
  after insert or update or delete on public.tickets
  for each row
  execute function public.sync_event_attendance();

-- ── Reprise des billets déjà émis ───────────────────────────────────────────
-- Le trigger ne rétroagit pas : sans cette passe, les détenteurs actuels
-- n'auraient aucune présence et ne pourraient pas documenter leurs événements.
insert into public.event_attendance (user_id, event_id, status)
select
  t.user_id,
  t.event_id,
  case when bool_or(t.status = 'used') then 'attended' else 'going' end
from public.tickets t
where t.user_id is not null
group by t.user_id, t.event_id
on conflict (user_id, event_id) do nothing;

-- ── Réglage de la visibilité ────────────────────────────────────────────────
-- Passe par une RPC plutôt qu'un UPDATE direct : le client ne peut ainsi
-- toucher QUE ce drapeau, jamais le statut.
create or replace function public.set_attendance_visibility(
  p_event   uuid,
  p_visible boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;

  update public.event_attendance
     set visible_to_connections = p_visible,
         updated_at = now()
   where user_id = auth.uid()
     and event_id = p_event;

  if not found then
    raise exception 'not_attending';
  end if;
end;
$$;

revoke all on function public.set_attendance_visibility(uuid, boolean)
  from public, anon;
grant execute on function public.set_attendance_visibility(uuid, boolean)
  to authenticated;

-- ── « Relation légitime » étendue à la présence ─────────────────────────────
-- Prévu dès la phase 00 : on étend la fonction sans toucher à la policy.
create or replace function public.can_attach_event(p_event uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from public.events e
    where e.id = p_event and e.created_by = auth.uid()
  )
  or exists (
    select 1 from public.event_attendance a
    where a.event_id = p_event and a.user_id = auth.uid()
  );
$$;
