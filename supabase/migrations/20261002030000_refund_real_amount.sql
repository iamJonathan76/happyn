-- Rembourser ce qui a ete PAYE, pas le prix actuel du palier.
--
-- Les deux chemins de remboursement — l'acheteur qui annule son billet, et
-- l'organisateur qui annule son evenement — lisaient `ticket_types.price`.
-- C'est le prix AUJOURD'HUI, pas celui du jour de l'achat. La table `tickets`
-- ne garde aucune trace du montant paye.
--
-- Consequence : un organisateur qui ajuste son tarif apres une vente fausse
-- tous les remboursements a venir. Prix baisse de 20 $ a 15 $, l'acheteur
-- perd 5 $ qu'il avait bien payes ; prix monte a 25 $, la plateforme rend 5 $
-- qu'elle n'a jamais recus. Dans les deux cas c'est de l'argent, et personne
-- ne s'en apercevrait avant la plainte.
--
-- La verite se trouve dans `payments` : le montant brut encaisse et le nombre
-- de billets de cette transaction. Le prix unitaire reellement paye en decoule,
-- sans ajouter de colonne ni reecrire l'historique.
--
-- Repli sur `ticket_types.price` pour les billets anterieurs au registre
-- (avant Stripe Connect) : c'est la meilleure approximation disponible, et
-- elle vaut mieux que zero.

create or replace function public.ticket_paid_cents(p_ticket uuid)
returns bigint
language sql
security definer
stable
set search_path = public
as $$
  select coalesce(
    -- Ce qui a vraiment ete encaisse, divise par le nombre de billets de la
    -- meme transaction. Un achat groupe partage son montant.
    (select floor(pay.gross_cents::numeric / greatest(pay.quantity, 1))::bigint
       from public.payments pay
       join public.tickets t2 on t2.payment_intent_id = pay.payment_intent_id
      where t2.id = p_ticket
      limit 1),
    -- Billet d'avant le registre, ou billet gratuit.
    (select round(coalesce(tt.price, 0) * 100)::bigint
       from public.tickets t3
       left join public.ticket_types tt on tt.id = t3.ticket_type_id
      where t3.id = p_ticket),
    0
  );
$$;

revoke all on function public.ticket_paid_cents(uuid) from public, anon;
grant execute on function public.ticket_paid_cents(uuid) to authenticated, service_role;

-- ── Le chemin « l'organisateur annule l'evenement » ─────────────────────────

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
  select t.id,
         t.payment_intent_id,
         public.ticket_paid_cents(t.id)::numeric / 100
  from public.tickets t
  where t.event_id = p_event
    and t.status = 'valid'
  order by t.purchased_at;
$$;

revoke all on function public.event_tickets_to_refund(uuid)
  from public, anon, authenticated;
grant execute on function public.event_tickets_to_refund(uuid) to service_role;

-- ── Le chemin « l'acheteur annule son billet » ──────────────────────────────
-- Meme correction, meme raison. Le montant renvoye ici sert a la fois a
-- afficher « tu seras rembourse de X » et a demander le remboursement a
-- Stripe : il doit etre le vrai.

create or replace function public.can_cancel_ticket(p_ticket uuid)
returns table (
  allowed  boolean,
  reason   text,
  deadline timestamptz,
  amount   numeric
)
language plpgsql
security definer
stable
set search_path = public
as $$
declare
  v_user   uuid;
  v_status text;
  v_start  timestamptz;
  v_ev     text;
  v_hours  integer;
  v_price  numeric;
begin
  select t.user_id, t.status, e.start_date, e.status,
         coalesce(e.cancellation_hours, 24),
         public.ticket_paid_cents(t.id)::numeric / 100
    into v_user, v_status, v_start, v_ev, v_hours, v_price
  from public.tickets t
  join public.events e on e.id = t.event_id
  where t.id = p_ticket;

  if v_user is null then
    return query select false, 'not_found'::text, null::timestamptz, 0::numeric;
    return;
  end if;
  if v_user <> auth.uid() then
    return query select false, 'not_owner'::text, null::timestamptz, 0::numeric;
    return;
  end if;
  if v_status <> 'valid' then
    return query select false, 'ticket_not_valid'::text, null::timestamptz, v_price;
    return;
  end if;

  -- Evenement annule par l'organisateur : le remboursement part tout seul
  -- (`cancel-event`). Ce n'est pas a l'acheteur de le demander.
  if v_ev = 'cancelled' then
    return query select false, 'event_cancelled'::text, null::timestamptz, v_price;
    return;
  end if;

  if v_hours = 0 then
    return query select false, 'not_allowed_by_organizer'::text,
                        null::timestamptz, v_price;
    return;
  end if;

  return query
  select now() < (v_start - make_interval(hours => v_hours)),
         case when now() < (v_start - make_interval(hours => v_hours))
              then 'ok' else 'deadline_passed' end,
         v_start - make_interval(hours => v_hours),
         v_price;
end;
$$;

revoke all on function public.can_cancel_ticket(uuid) from public, anon;
grant execute on function public.can_cancel_ticket(uuid) to authenticated;
