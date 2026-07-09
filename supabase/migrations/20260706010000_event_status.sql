-- =============================================================================
-- HAPPYN — Cycle de vie des events : champ `status`
-- =============================================================================
-- status : 'published' (visible/vendable) | 'draft' (masqué/dépublié) |
--          'cancelled' (annulé, données préservées).
-- `issue_tickets` refuse la vente si l'event n'est pas 'published' (en plus du
-- contrôle "event terminé"). À exécuter dans le SQL Editor.
-- =============================================================================

alter table public.events
  add column if not exists status text not null default 'published';

-- Contrainte de valeurs (ajoutée seulement si absente)
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'events_status_check'
  ) then
    alter table public.events
      add constraint events_status_check
      check (status in ('published', 'draft', 'cancelled'));
  end if;
end $$;

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
  v_status    text;
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

  select end_date, status into v_end, v_status
  from public.events where id = v_event;

  if v_status <> 'published' then
    raise exception 'event_not_available';
  end if;
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
