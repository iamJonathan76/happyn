-- =============================================================================
-- HAPPYN — Paiements Stripe (Phase 1, webhook-driven)
-- =============================================================================
-- 1. Ajoute `payment_intent_id` sur tickets : relie chaque ticket payant au
--    PaymentIntent Stripe qui l'a financé (permet à l'app de poller le ticket
--    une fois le webhook traité, et garantit l'idempotence).
-- 2. RPC `issue_tickets_paid` : émission appelée UNIQUEMENT par le webhook
--    (service role). Prend explicitement le user_id (pas d'auth.uid() dans un
--    webhook) et est idempotente sur payment_intent_id.
--
-- Les events GRATUITS continuent d'utiliser `issue_tickets` (client) sans Stripe.
-- =============================================================================

alter table public.tickets
  add column if not exists payment_intent_id text;

create unique index if not exists tickets_payment_intent_unique
  on public.tickets (payment_intent_id, ticket_type_id)
  where payment_intent_id is not null;

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
  v_i         int;
  v_token     text;
  v_existing  int;
begin
  -- Idempotence : si ce PaymentIntent a déjà généré des tickets, on les renvoie
  -- sans rien réémettre (Stripe peut rejouer un webhook).
  select count(*) into v_existing
  from public.tickets
  where payment_intent_id = p_payment_intent_id;

  if v_existing > 0 then
    return query
      select * from public.tickets
      where payment_intent_id = p_payment_intent_id;
    return;
  end if;

  if p_quantity is null or p_quantity < 1 or p_quantity > 10 then
    raise exception 'invalid_quantity';
  end if;

  -- Verrou de ligne sur le ticket_type
  select event_id, (quantity_total - quantity_sold)
    into v_event, v_remaining
  from public.ticket_types
  where id = p_ticket_type_id
  for update;

  if not found then
    raise exception 'ticket_type_not_found';
  end if;
  if v_remaining < p_quantity then
    raise exception 'insufficient_stock';
  end if;

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
end;
$$;

-- IMPORTANT : réservée au service role (le webhook). Si un client pouvait
-- l'appeler, il émettrait des tickets sans payer.
revoke all on function public.issue_tickets_paid(uuid, int, uuid, text)
  from public, anon, authenticated;
