-- =============================================================================
-- HAPPYN — Notification « billet confirmé »
-- =============================================================================
-- Une notif (une seule) est créée pour l'acheteur à la fin de l'émission,
-- avec le nombre de billets. Insérée DANS les RPC (après la boucle) plutôt que
-- via un trigger par ligne, pour éviter N notifs pour un achat de N billets.
-- Les fonctions sont recréées à l'identique + l'insertion de la notif.
-- À exécuter dans le SQL Editor.
-- =============================================================================

-- ── Émission gratuite (client) ──────────────────────────────────────────────
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
  v_title     text;
  v_i         int;
  v_token     text;
begin
  if v_user is null then raise exception 'not_authenticated'; end if;
  if p_quantity is null or p_quantity < 1 then
    raise exception 'invalid_quantity';
  end if;

  select event_id, (quantity_total - quantity_sold), coalesce(max_per_order, 10)
    into v_event, v_remaining, v_max
  from public.ticket_types where id = p_ticket_type_id for update;

  if not found then raise exception 'ticket_type_not_found'; end if;

  select end_date, status, title into v_end, v_status, v_title
  from public.events where id = v_event;

  if v_status <> 'published' then raise exception 'event_not_available'; end if;
  if v_end is not null and v_end < now() then raise exception 'event_ended'; end if;
  if p_quantity > v_max then raise exception 'exceeds_max_per_order'; end if;
  if v_remaining < p_quantity then raise exception 'insufficient_stock'; end if;

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

  insert into public.notifications (user_id, type, title, body, event_id)
  values (
    v_user, 'ticket_confirmed', 'Ticket confirmed',
    p_quantity::text
      || case when p_quantity > 1 then ' tickets for ' else ' ticket for ' end
      || v_title || ' are in "My Tickets".',
    v_event
  );
end;
$$;

-- ── Émission payée (webhook / service role) ─────────────────────────────────
create or replace function public.issue_tickets_paid(
  p_ticket_type_id   uuid,
  p_quantity         int,
  p_user_id          uuid,
  p_payment_intent_id text
)
returns setof public.tickets
language plpgsql
security definer
set search_path = public
as $$
declare
  v_event     uuid;
  v_remaining int;
  v_max       int;
  v_title     text;
  v_i         int;
  v_token     text;
  v_existing  int;
begin
  select count(*) into v_existing
  from public.tickets where payment_intent_id = p_payment_intent_id;

  if v_existing > 0 then
    return query select * from public.tickets
      where payment_intent_id = p_payment_intent_id;
    return;
  end if;

  if p_quantity is null or p_quantity < 1 then
    raise exception 'invalid_quantity';
  end if;

  select event_id, (quantity_total - quantity_sold), coalesce(max_per_order, 10)
    into v_event, v_remaining, v_max
  from public.ticket_types where id = p_ticket_type_id for update;

  if not found then raise exception 'ticket_type_not_found'; end if;
  if p_quantity > v_max then raise exception 'exceeds_max_per_order'; end if;
  if v_remaining < p_quantity then raise exception 'insufficient_stock'; end if;

  select title into v_title from public.events where id = v_event;

  for v_i in 1..p_quantity loop
    v_token := 'HPN-' || replace(gen_random_uuid()::text, '-', '');
    return query
      insert into public.tickets
        (ticket_type_id, event_id, user_id, qr_token, status, payment_intent_id)
      values
        (p_ticket_type_id, v_event, p_user_id, v_token, 'valid', p_payment_intent_id)
      returning *;
  end loop;

  update public.ticket_types
     set quantity_sold = quantity_sold + p_quantity
   where id = p_ticket_type_id;

  insert into public.notifications (user_id, type, title, body, event_id)
  values (
    p_user_id, 'ticket_confirmed', 'Ticket confirmed',
    p_quantity::text
      || case when p_quantity > 1 then ' tickets for ' else ' ticket for ' end
      || v_title || ' are in "My Tickets".',
    v_event
  );
end;
$$;
