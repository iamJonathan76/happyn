-- Émission des billets payés : idempotente MÊME en cas de livraisons
-- simultanées du webhook.
--
-- La fonction vérifiait déjà « ce paiement a-t-il déjà ses billets ? », mais
-- avant de prendre le moindre verrou. Deux livraisons concurrentes du même
-- événement Stripe passaient donc toutes les deux le contrôle. Le paiement
-- n'était pas doublé — l'acheteur payait une fois — mais il recevait ses
-- billets en double et le stock baissait deux fois.
--
-- Seul changement : le verrou consultatif en tête. Le reste est identique à la
-- version en production (comparée le 2026-10-16).

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
  -- Un verrou par paiement, AVANT de regarder si les billets existent déjà.
  -- Stripe peut livrer deux fois le même `payment_intent.succeeded`, parfois
  -- presque en même temps : sans ce verrou, les deux livraisons voyaient
  -- « aucun billet » et en émettaient chacune — billets en double, stock
  -- décompté deux fois. Le verrou les fait passer l'une après l'autre ; la
  -- seconde trouve les billets de la première et les renvoie.
  perform pg_advisory_xact_lock(hashtextextended('issue_tickets_paid:' || p_payment_intent_id, 0));

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
