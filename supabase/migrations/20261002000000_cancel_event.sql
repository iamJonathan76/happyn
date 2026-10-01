-- Annuler un evenement : rembourser tout le monde, puis fermer.
-- Et pouvoir revenir en arriere tant que rien n'a ete vendu.
--
-- Ce qui existait : annuler mettait `status = 'cancelled'`, prevenait les
-- detenteurs de billets... et s'arretait la. `can_cancel_ticket` repond meme
-- `event_cancelled` a l'acheteur qui demande son remboursement, avec ce
-- commentaire : « c'est un remboursement qui lui est du. Traite separement. »
-- Ce « separement » n'existait pas. L'argent restait chez la plateforme, et il
-- fallait le rendre a la main dans Stripe, un par un.
--
-- Le remboursement lui-meme ne peut pas vivre ici : il passe par l'API Stripe.
-- Cette migration pose les pieces que la fonction Edge `cancel-event`
-- assemble, et le droit de les appeler est reparti en consequence :
-- l'organisateur voit et decide, le serveur execute.

-- ── Ce que l'annulation va couter ───────────────────────────────────────────
-- Pour l'ecrire dans la confirmation AVANT de la demander. « 12 billets
-- vendus, 180 $ a rembourser » arrete une fausse manoeuvre bien mieux qu'un
-- bouton rouge.

create or replace function public.event_cancellation_preview(p_event uuid)
returns table (ticket_count integer, refund_total numeric)
language plpgsql
security definer
stable
set search_path = public
as $$
begin
  if not exists (
    select 1 from public.events e
    where e.id = p_event and e.created_by = auth.uid()
  ) then
    raise exception 'not_organizer';
  end if;

  return query
  select count(*)::integer,
         coalesce(sum(coalesce(tt.price, 0)), 0)::numeric
  from public.tickets t
  left join public.ticket_types tt on tt.id = t.ticket_type_id
  where t.event_id = p_event
    and t.status = 'valid';
end;
$$;

revoke all on function public.event_cancellation_preview(uuid) from public, anon;
grant execute on function public.event_cancellation_preview(uuid) to authenticated;

-- ── A-t-il deja ete vendu quoi que ce soit ? ────────────────────────────────
-- La question qui decide si un evenement annule peut revivre. On regarde les
-- billets ET les paiements : un paiement sans billet (emission echouee) est
-- justement le cas ou de l'argent a change de mains sans trace visible.

create or replace function public.event_has_sales(p_event uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (select 1 from public.tickets where event_id = p_event)
      or exists (select 1 from public.payments where event_id = p_event);
$$;

revoke all on function public.event_has_sales(uuid) from public, anon;
grant execute on function public.event_has_sales(uuid) to authenticated;

-- ── Fermer l'evenement ──────────────────────────────────────────────────────
-- Appelee par `cancel-event` AVANT les remboursements : `status <> 'published'`
-- fait refuser toute nouvelle vente par `create-payment-intent`. Sans cet
-- ordre, quelqu'un pourrait acheter un billet pendant qu'on rembourse les
-- autres.
--
-- `p_actor` plutot que `auth.uid()` : la fonction Edge agit avec les droits du
-- serveur, c'est donc elle qui doit prouver au nom de qui elle agit. Meme
-- forme que `cancel_ticket`.

create or replace function public.cancel_event(p_event uuid, p_actor uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner uuid;
begin
  select created_by into v_owner from public.events where id = p_event;
  if v_owner is null then raise exception 'not_found'; end if;
  if v_owner <> p_actor then raise exception 'not_organizer'; end if;

  update public.events
     set status = 'cancelled'
   where id = p_event
     and status <> 'cancelled';
end;
$$;

revoke all on function public.cancel_event(uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.cancel_event(uuid, uuid) to service_role;

-- ── Les billets a rembourser ────────────────────────────────────────────────
-- Serveur uniquement : la liste contient les identifiants de paiement Stripe.

create or replace function public.event_tickets_to_refund(p_event uuid)
returns table (
  ticket_id         uuid,
  payment_intent_id text,
  amount            numeric
)
language sql
security definer
stable
set search_path = public
as $$
  select t.id, t.payment_intent_id, coalesce(tt.price, 0)
  from public.tickets t
  left join public.ticket_types tt on tt.id = t.ticket_type_id
  where t.event_id = p_event
    and t.status = 'valid'
  -- `purchased_at`, et non `created_at` : la table `tickets` n'a pas ete creee
  -- par une migration de ce depot, et c'est ce nom-la qu'elle porte.
  order by t.purchased_at;
$$;

revoke all on function public.event_tickets_to_refund(uuid)
  from public, anon, authenticated;
grant execute on function public.event_tickets_to_refund(uuid) to service_role;

-- ── Annuler un billet au nom de l'organisateur ──────────────────────────────
-- `cancel_ticket` exige que l'acteur soit le PROPRIETAIRE du billet : c'est ce
-- qui empeche d'annuler celui d'un autre, et ca doit le rester. L'annulation
-- d'un evenement est un autre chemin, reserve au serveur.
--
-- Idempotente : un billet deja annule ne provoque pas d'erreur. Une reprise
-- apres un remboursement partiellement echoue doit pouvoir etre relancee.

create or replace function public.cancel_ticket_for_event(
  p_ticket    uuid,
  p_refund_id text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_status text;
  v_type   uuid;
begin
  select status, ticket_type_id
    into v_status, v_type
  from public.tickets
  where id = p_ticket
  for update;

  if v_status is null then raise exception 'not_found'; end if;
  if v_status <> 'valid' then return; end if;

  update public.tickets
     set status       = 'cancelled',
         cancelled_at = now(),
         refunded_at  = case when p_refund_id is not null then now() else null end,
         refund_id    = p_refund_id
   where id = p_ticket;

  if v_type is not null then
    update public.ticket_types
       set quantity_sold = greatest(quantity_sold - 1, 0)
     where id = v_type;
  end if;
end;
$$;

revoke all on function public.cancel_ticket_for_event(uuid, text)
  from public, anon, authenticated;
grant execute on function public.cancel_ticket_for_event(uuid, text)
  to service_role;

-- ── Faire revivre un evenement annule ───────────────────────────────────────
-- Seulement si RIEN n'a ete vendu. Avec des ventes, les acheteurs ont ete
-- prevenus que c'etait annule et rembourses : ressusciter l'evenement les
-- obligerait a racheter, et personne ne comprendrait ce qui se passe. Dans ce
-- cas, un nouvel evenement est la reponse honnete — c'en est un.
--
-- Sans vente, personne n'a ete prevenu ni debite : c'est une fausse manoeuvre,
-- et faire ressaisir le titre, les dates, l'adresse, les tarifs et l'affiche
-- serait une punition gratuite.
--
-- Retour en BROUILLON, pas en ligne : republier reste un geste volontaire.

create or replace function public.restore_cancelled_event(p_event uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_status text;
begin
  select status into v_status
  from public.events
  where id = p_event and created_by = auth.uid();

  if v_status is null then raise exception 'not_organizer'; end if;
  if v_status <> 'cancelled' then raise exception 'not_cancelled'; end if;
  if public.event_has_sales(p_event) then raise exception 'event_had_sales'; end if;

  update public.events set status = 'draft' where id = p_event;
end;
$$;

revoke all on function public.restore_cancelled_event(uuid) from public, anon;
grant execute on function public.restore_cancelled_event(uuid) to authenticated;
