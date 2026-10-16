-- La limite de billets fixée par l'organisateur s'applique par personne.
--
-- Elle était vérifiée commande par commande : `p_quantity > max_per_order`.
-- Avec une limite de 2, deux commandes de 2 passaient, puis deux autres. Sur
-- un événement gratuit, une seule personne pouvait tout réserver. La migration
-- d'origine s'appelait pourtant « Limite de billets par personne ».
--
-- Les billets payants sont contrôlés dans create-payment-intent, AVANT le
-- paiement : refuser dans le webhook, après encaissement, obligerait à
-- rembourser et ferait perdre les frais Stripe.
--
-- Seul changement : le compte des billets détenus. Le reste est identique à la
-- version en production (comparée le 2026-10-16).

CREATE OR REPLACE FUNCTION public.issue_tickets(p_ticket_type_id uuid, p_quantity integer)
 RETURNS SETOF tickets
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_user      uuid := auth.uid();
  v_event     uuid;
  v_remaining int;
  v_max       int;
  v_held      int;
  v_end       timestamptz;
  v_status    text;
  v_title     text;
  v_i         int;
  v_token     text;
  v_price     numeric;
  v_min_age   integer;
begin
  if v_user is null then raise exception 'not_authenticated'; end if;
  if p_quantity is null or p_quantity < 1 then
    raise exception 'invalid_quantity';
  end if;

  select event_id, (quantity_total - quantity_sold), coalesce(max_per_order, 10),
         coalesce(price, 0)
    into v_event, v_remaining, v_max, v_price
  from public.ticket_types where id = p_ticket_type_id for update;

  if not found then raise exception 'ticket_type_not_found'; end if;

  -- Cette fonction emet des billets SANS paiement. Elle n'est donc legitime
  -- que pour un palier gratuit ; un palier payant passe par Stripe
  -- (create-payment-intent puis le webhook, issue_tickets_paid). Avant le
  -- 2026-10-08, seule l'app faisait ce tri : un appel direct avec l'id d'un
  -- palier payant rendait des billets valides, gratuitement.
  if v_price > 0 then raise exception 'payment_required'; end if;

  -- Meme regle de visibilite que la fiche : un evenement prive ne s'obtient
  -- qu'apres l'avoir deverrouille avec son code (ou en etant organisateur).
  if not public.event_is_readable(v_event) then
    raise exception 'event_not_available';
  end if;

  select end_date, status, title, coalesce(min_age, 0)
    into v_end, v_status, v_title, v_min_age
  from public.events where id = v_event;

  if v_status <> 'published' then raise exception 'event_not_available'; end if;
  -- Depuis le 2026-10-09, aussi verifie ici et plus seulement dans l'app :
  -- un appel direct a cette fonction contournait l'age minimum d'un
  -- evenement. Sans date de naissance connue, pas de billet non plus.
  if not public.user_meets_age(v_user, v_min_age) then
    raise exception 'age_restricted';
  end if;
  if v_end is not null and v_end < now() then raise exception 'event_ended'; end if;
  if p_quantity > v_max then raise exception 'exceeds_max_per_order'; end if;
  -- La limite de l'organisateur est PAR PERSONNE, pas par commande : sans ce
  -- compte, deux commandes de 2 sur une limite de 2 passaient, et une seule
  -- personne pouvait vider un événement gratuit. Compté après le verrou pris
  -- sur le palier plus haut : deux commandes simultanées de la même personne
  -- passent l'une après l'autre. Un billet utilisé compte (il a été détenu) ;
  -- un billet annulé (« refunded ») ou transféré à quelqu'un d'autre, non.
  select count(*) into v_held
    from public.tickets
   where user_id = v_user
     and ticket_type_id = p_ticket_type_id
     and status in ('valid', 'used');
  if v_held + p_quantity > v_max then raise exception 'exceeds_per_person'; end if;
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
$function$;

revoke all on function public.issue_tickets(uuid, integer) from public, anon;
grant execute on function public.issue_tickets(uuid, integer) to authenticated, service_role;
