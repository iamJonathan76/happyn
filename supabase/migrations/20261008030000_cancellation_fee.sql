-- Frais de service non remboursables quand l'ACHETEUR annule son billet.
--
-- Décidé le 2026-10-08. Quand un billet est remboursé, Stripe garde ses frais
-- sur le paiement d'origine (2,9 % + 0,30 $). Jusqu'ici, c'est l'organisateur
-- qui les perdait, sans l'avoir choisi : l'acheteur annulait, l'organisateur
-- payait. Les organisateurs sont les partenaires qui font vivre HAPPYN ; ce
-- coût revient à qui le provoque.
--
-- La règle :
--   * l'acheteur annule lui-même → remboursé du prix MOINS des frais de
--     service, égaux à ce que Stripe garde. Ni HAPPYN ni l'organisateur n'y
--     gagnent : on couvre la perte, rien de plus. Les annoncer AVANT l'achat
--     est une obligation (affichage dans l'app) ;
--   * l'organisateur annule l'événement → remboursement intégral, inchangé
--     (`cancel-event`). La loi l'exige : le service n'a pas eu lieu ;
--   * paiement en double, paiement sans billet → intégral, inchangé.
--
-- ── Un seul endroit pour la formule ────────────────────────────────────────
-- `cancellation_fee_terms()` porte les deux chiffres ; l'app les lit pour
-- annoncer les frais avant l'achat, `cancellation_fee_cents()` les applique au
-- remboursement. Deux définitions finiraient par diverger, et l'app
-- promettrait un remboursement que Stripe ne verserait pas.

-- ═══════════════════════════════════════════════════════════════════════════
-- La formule
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function public.cancellation_fee_terms(
  out bps integer, out fixed_cents integer)
language sql immutable
set search_path = public
as $$ select 290, 30 $$;

-- Arrondi au cent le plus proche, plafonné au prix : un billet à 0,25 $ ne
-- peut pas coûter plus que ce qu'il a rapporté.
create or replace function public.cancellation_fee_cents(p_price_cents bigint)
returns bigint
language sql immutable
set search_path = public
as $$
  select case
    when coalesce(p_price_cents, 0) <= 0 then 0
    else least(p_price_cents,
               round(p_price_cents * t.bps / 10000.0)::bigint + t.fixed_cents)
  end
  from public.cancellation_fee_terms() t
$$;

revoke all on function public.cancellation_fee_terms()       from public, anon;
revoke all on function public.cancellation_fee_cents(bigint)  from public, anon;
grant execute on function public.cancellation_fee_terms()      to authenticated, service_role;
grant execute on function public.cancellation_fee_cents(bigint) to authenticated, service_role;

-- ═══════════════════════════════════════════════════════════════════════════
-- Ce que chaque paiement a retenu
-- ═══════════════════════════════════════════════════════════════════════════

-- Somme des frais retenus sur les annulations de ce paiement. Un paiement
-- couvre souvent plusieurs billets : chaque annulation y ajoute les siens.
alter table public.payments
  add column if not exists retained_fee_cents bigint not null default 0;

-- ═══════════════════════════════════════════════════════════════════════════
-- can_cancel_ticket : annonce aussi les frais
-- ═══════════════════════════════════════════════════════════════════════════
-- Une colonne de plus en sortie : Postgres refuse de changer le type de retour
-- d'une fonction existante, d'où le drop. Les appelants lisent les colonnes
-- par leur nom, `fee` s'ajoute sans rien casser.

drop function if exists public.can_cancel_ticket(uuid);

create function public.can_cancel_ticket(p_ticket uuid)
returns table(allowed boolean, reason text, deadline timestamptz,
              amount numeric, fee numeric)
language plpgsql stable security definer
set search_path = public
as $$
declare
  v_user        uuid;
  v_status      text;
  v_start       timestamptz;
  v_ev          text;
  v_hours       integer;
  v_price       numeric;
  v_fee         numeric;
  v_transferred boolean;
begin
  select t.user_id, t.status, e.start_date, e.status,
         coalesce(e.cancellation_hours, 24),
         public.ticket_paid_cents(t.id)::numeric / 100,
         public.cancellation_fee_cents(public.ticket_paid_cents(t.id))::numeric / 100,
         t.transferred_from is not null
    into v_user, v_status, v_start, v_ev, v_hours, v_price, v_fee, v_transferred
  from public.tickets t
  join public.events e on e.id = t.event_id
  where t.id = p_ticket;

  if v_user is null then
    return query select false, 'not_found'::text, null::timestamptz, 0::numeric, 0::numeric;
    return;
  end if;
  if v_user <> auth.uid() then
    return query select false, 'not_owner'::text, null::timestamptz, 0::numeric, 0::numeric;
    return;
  end if;
  if v_status <> 'valid' then
    return query select false, 'ticket_not_valid'::text, null::timestamptz, v_price, v_fee;
    return;
  end if;

  -- Paye puis transfere : plus remboursable a la demande. Stripe ne saurait
  -- rembourser que la carte de l'acheteur, pas la personne qui annule.
  if v_transferred and v_price > 0 then
    return query select false, 'transferred'::text, null::timestamptz, v_price, v_fee;
    return;
  end if;

  -- Evenement annule par l'organisateur : le remboursement part tout seul
  -- (`cancel-event`), et il est integral. Ce n'est pas a l'acheteur de le
  -- demander — ni de payer des frais pour une annulation qui n'est pas la
  -- sienne.
  if v_ev = 'cancelled' then
    return query select false, 'event_cancelled'::text, null::timestamptz, v_price, 0::numeric;
    return;
  end if;

  if v_hours = 0 then
    return query select false, 'not_allowed_by_organizer'::text,
                        null::timestamptz, v_price, v_fee;
    return;
  end if;

  return query
  select now() < (v_start - make_interval(hours => v_hours)),
         case when now() < (v_start - make_interval(hours => v_hours))
              then 'ok' else 'deadline_passed' end,
         v_start - make_interval(hours => v_hours),
         v_price,
         v_fee;
end;
$$;

revoke all on function public.can_cancel_ticket(uuid) from public, anon;
grant execute on function public.can_cancel_ticket(uuid) to authenticated, service_role;

-- ═══════════════════════════════════════════════════════════════════════════
-- cancel_ticket : note les frais retenus sur le paiement
-- ═══════════════════════════════════════════════════════════════════════════

drop function if exists public.cancel_ticket(uuid, uuid, text);

create function public.cancel_ticket(
  p_ticket uuid, p_actor uuid,
  p_refund_id text default null,
  p_retained_fee_cents bigint default 0)
returns void
language plpgsql security definer
set search_path = public
as $$
declare
  v_user   uuid;
  v_status text;
  v_type   uuid;
  v_pi     text;
begin
  select user_id, status, ticket_type_id, payment_intent_id
    into v_user, v_status, v_type, v_pi
  from public.tickets
  where id = p_ticket
  for update;  -- verrou : deux annulations simultanées ne rendraient qu'une place

  if v_user is null then raise exception 'not_found'; end if;
  if v_user <> p_actor then raise exception 'not_owner'; end if;
  if v_status <> 'valid' then raise exception 'ticket_not_valid'; end if;

  update public.tickets
  set status       = 'cancelled',
      cancelled_at = now(),
      refunded_at  = case when p_refund_id is not null then now() else null end,
      refund_id    = p_refund_id
  where id = p_ticket;

  -- Ce qui n'a pas été rendu reste sur le paiement : `event_ledger` doit savoir
  -- que ces cents compensent les frais de Stripe et ne sont pas une vente —
  -- sinon l'organisateur paierait une commission sur un billet annulé.
  if coalesce(p_retained_fee_cents, 0) > 0 and v_pi is not null then
    update public.payments
    set retained_fee_cents = retained_fee_cents + p_retained_fee_cents
    where payment_intent_id = v_pi;
  end if;

  -- La place retourne au stock. `greatest` par prudence : un compteur négatif
  -- casserait l'affichage « x / y vendus » sans qu'on sache pourquoi.
  if v_type is not null then
    update public.ticket_types
    set quantity_sold = greatest(0, quantity_sold - 1)
    where id = v_type;
  end if;

  insert into public.notifications (user_id, type, title, body, event_id)
  select p_actor, 'ticket_cancelled', 'Ticket cancelled',
         'Your ticket for ' || e.title || ' has been cancelled.', t.event_id
  from public.tickets t join public.events e on e.id = t.event_id
  where t.id = p_ticket;
end;
$$;

-- Réservée au serveur, comme avant : seule la fonction Edge, qui rembourse
-- d'abord, a le droit d'annuler.
revoke all on function public.cancel_ticket(uuid, uuid, text, bigint) from public, anon, authenticated;
grant execute on function public.cancel_ticket(uuid, uuid, text, bigint) to service_role;

-- ═══════════════════════════════════════════════════════════════════════════
-- event_ledger : pas de commission sur les frais retenus
-- ═══════════════════════════════════════════════════════════════════════════
-- Les frais retenus restent dans le brut conservé — ils compensent exactement
-- les frais de Stripe déduits plus bas. Mais ce ne sont pas des ventes : la
-- commission ne s'y applique pas. Sans ça, un billet de 20 $ annulé coûterait
-- 4 cents à l'organisateur (5 % des 0,88 $ retenus).

create or replace function public.event_ledger()
returns table(event_id uuid, gross bigint, withheld bigint,
              stripe_fee bigint, platform_fee bigint)
language sql stable security definer
set search_path = public
as $$
  select
    p.event_id,
    sum(p.gross_cents)::bigint,
    -- Tout ce qui ne reste pas : remboursements, et la totalité d'un paiement
    -- contesté. Regroupés parce qu'ils ont le même effet sur le versement —
    -- l'argent n'est plus là.
    sum(case
          when p.disputed_at is not null then p.gross_cents
          else least(p.refunded_cents, p.gross_cents)
        end)::bigint,
    sum(coalesce(p.stripe_fee_cents, 0))::bigint,
    -- La commission se calcule paiement par paiement, sur ce qui est réellement
    -- conservé AU TITRE DES VENTES, puis s'additionne. L'appliquer au total
    -- ferait payer une commission sur des billets remboursés ; l'appliquer aux
    -- frais retenus, sur des billets annulés.
    sum(round(
      greatest(
        p.gross_cents
          - case when p.disputed_at is not null then p.gross_cents
                 else least(p.refunded_cents, p.gross_cents) end
          - case when p.disputed_at is not null then 0
                 else p.retained_fee_cents end,
        0)::numeric
      * p.platform_fee_bps / 10000))::bigint
  from public.payments p
  group by p.event_id;
$$;

revoke all on function public.event_ledger() from public, anon, authenticated;
grant execute on function public.event_ledger() to service_role;
