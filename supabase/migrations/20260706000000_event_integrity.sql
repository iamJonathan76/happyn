-- =============================================================================
-- HAPPYN — Intégrité du cycle de vie des events
-- =============================================================================
-- 1. `issue_tickets` (émission gratuite) refuse un event déjà terminé
--    (end_date < maintenant) → les ventes se ferment automatiquement.
-- 2. Trigger BEFORE DELETE sur events : impossible de supprimer un event qui a
--    des billets émis (préserve l'historique de transactions, façon Eventbrite).
--    → l'organisateur devra « annuler » (à venir) au lieu de supprimer.
-- À exécuter dans le SQL Editor.
-- =============================================================================

create or replace function public.issue_tickets(
  p_ticket_type_id uuid,
  p_quantity int
)
returns setof public.tickets
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user      uuid := auth.uid();
  v_event     uuid;
  v_remaining int;
  v_max       int;
  v_end       timestamptz;
  v_i         int;
  v_token     text;
begin
  if v_user is null then
    raise exception 'not_authenticated';
  end if;
  if p_quantity is null or p_quantity < 1 then
    raise exception 'invalid_quantity';
  end if;

  select event_id, (quantity_total - quantity_sold), coalesce(max_per_order, 10)
    into v_event, v_remaining, v_max
  from public.ticket_types
  where id = p_ticket_type_id
  for update;

  if not found then
    raise exception 'ticket_type_not_found';
  end if;

  -- Ventes fermées si l'event est terminé
  select end_date into v_end from public.events where id = v_event;
  if v_end is not null and v_end < now() then
    raise exception 'event_ended';
  end if;

  if p_quantity > v_max then
    raise exception 'exceeds_max_per_order';
  end if;
  if v_remaining < p_quantity then
    raise exception 'insufficient_stock';
  end if;

  for v_i in 1..p_quantity loop
    v_token := 'HPN-' || replace(gen_random_uuid()::text, '-', '');
    return query
      insert into public.tickets (ticket_type_id, event_id, user_id, qr_token, status)
      values (p_ticket_type_id, v_event, v_user, v_token, 'valid')
      returning *;
  end loop;

  update public.ticket_types
     set quantity_sold = quantity_sold + p_quantity
   where id = p_ticket_type_id;
end;
$$;

-- ── Protection suppression : pas de delete si des billets existent ──────────
create or replace function public.prevent_delete_with_tickets()
returns trigger
language plpgsql
as $$
begin
  if exists (select 1 from public.tickets where event_id = old.id) then
    raise exception 'event_has_tickets';
  end if;
  return old;
end;
$$;

drop trigger if exists trg_prevent_event_delete on public.events;
create trigger trg_prevent_event_delete
  before delete on public.events
  for each row
  execute function public.prevent_delete_with_tickets();
