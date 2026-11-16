-- =============================================================================
-- Commission HAPPYN : passage à 3 % + 0,99 $ par billet
-- =============================================================================
-- Décision d'affaires (modèle de tarification d'Emmanuel, 2026-11) : la
-- commission n'est plus 5 % tout court, mais 3 % du prix affiché PLUS une part
-- FIXE de 0,99 $ par billet payant. La part fixe change surtout l'économie des
-- billets bon marché (un plancher), c'est voulu.
--
-- L'affichage ne change pas : le prix reste tout-inclus, saisi en net par
-- l'organisateur. Seule la formule derrière bouge.
--
-- Transition : la commission est FIGÉE par événement à sa création. Les
-- événements déjà publiés gardent donc `bps = 500, fixe = 0` (5 % pur) ; seuls
-- les nouveaux naissent à `bps = 300, fixe = 99`. Idem sur chaque paiement, qui
-- recopie les deux valeurs — le registre comptable reste auto-suffisant.
-- =============================================================================


-- ── 1. Les deux composantes de la commission ────────────────────────────────

create or replace function public.platform_fee_bps()
returns integer
language sql
immutable
as $$ select 300 $$;

comment on function public.platform_fee_bps() is
  'Part proportionnelle de la commission HAPPYN, en points de base (300 = 3 %). '
  'Changer ici ne touche que les evenements crees ensuite.';

-- La part fixe, en cents, par billet payant. 99 = 0,99 $. Les billets gratuits
-- n'en paient pas (aucune commission sur du gratuit).
create or replace function public.platform_fee_fixed_cents()
returns integer
language sql
immutable
as $$ select 99 $$;

comment on function public.platform_fee_fixed_cents() is
  'Part fixe de la commission HAPPYN, en cents, par billet payant (99 = 0,99 $). '
  'Figee par evenement a sa creation, comme le taux.';


-- ── 2. Gel de la part fixe sur l'événement ──────────────────────────────────
--
-- DÉFAUT 0, pas la valeur de la fonction : les événements qui existent déjà ont
-- été vendus sous le modèle 5 % pur, sans part fixe. Leur mettre 99
-- rétroactivement ferait payer à leur organisateur une commission que son
-- affichage n'avait jamais annoncée. Seuls les NOUVEAUX événements reçoivent 99,
-- via le trigger ci-dessous.

alter table public.events
  add column if not exists platform_fee_fixed_cents integer not null default 0;

comment on column public.events.platform_fee_fixed_cents is
  'Part fixe de commission (cents/billet), figee a la creation. 0 sur les '
  'evenements anterieurs au modele 3 % + fixe.';

-- Le trigger qui verrouille déjà le taux verrouille maintenant aussi la part
-- fixe : écrite depuis la fonction à l'insertion, immuable ensuite. Sans ça, un
-- organisateur pourrait se mettre à 0 en modifiant son événement.
create or replace function public.events_lock_fee()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'INSERT' then
    new.platform_fee_bps          := public.platform_fee_bps();
    new.platform_fee_fixed_cents  := public.platform_fee_fixed_cents();
  else
    new.platform_fee_bps          := old.platform_fee_bps;
    new.platform_fee_fixed_cents  := old.platform_fee_fixed_cents;
  end if;
  return new;
end;
$$;


-- ── 3. Gel de la part fixe sur le paiement ──────────────────────────────────
--
-- Même raison que `platform_fee_bps` sur `payments` : recopiée à l'achat depuis
-- l'événement, pour que recalculer un versement ne dépende jamais d'une valeur
-- qui a pu bouger depuis. Défaut 0 : les paiements déjà enregistrés étaient du
-- 5 % pur.

alter table public.payments
  add column if not exists platform_fee_fixed_cents integer not null default 0;

comment on column public.payments.platform_fee_fixed_cents is
  'Part fixe de commission (cents/billet) au moment de l''achat, recopiee depuis '
  'l''evenement. 0 pour les paiements anterieurs au modele 3 % + fixe.';


-- ── 4. record_payment : recopie aussi la part fixe ──────────────────────────
--
-- Nouvelle signature (un paramètre de plus), donc drop puis create : « create or
-- replace » ne peut pas changer la liste d'arguments. Le paramètre a un défaut 0
-- pour qu'un appelant qui ne le passe pas encore (webhook pas redéployé) ne
-- casse pas — il enregistrerait juste 0 de part fixe en attendant.

drop function if exists public.record_payment(
  text, uuid, uuid, uuid, uuid, integer, bigint, bigint, integer);

create function public.record_payment(
  p_payment_intent_id        text,
  p_event_id                 uuid,
  p_organizer_id             uuid,
  p_buyer_id                 uuid,
  p_ticket_type_id           uuid,
  p_quantity                 integer,
  p_gross_cents              bigint,
  p_stripe_fee_cents         bigint,
  p_platform_fee_bps         integer,
  p_platform_fee_fixed_cents integer default 0
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.payments (
    payment_intent_id, event_id, organizer_id, buyer_id, ticket_type_id,
    quantity, gross_cents, stripe_fee_cents, platform_fee_bps,
    platform_fee_fixed_cents
  ) values (
    p_payment_intent_id, p_event_id, p_organizer_id, p_buyer_id, p_ticket_type_id,
    p_quantity, p_gross_cents, p_stripe_fee_cents, p_platform_fee_bps,
    p_platform_fee_fixed_cents
  )
  on conflict (payment_intent_id) do update
    -- Le montant brut ne se corrige pas : s'il différait, c'est un incident, pas
    -- une mise à jour. Seuls les frais peuvent arriver en retard (la
    -- `balance_transaction` n'est pas toujours disponible au premier webhook).
    set stripe_fee_cents = coalesce(
          excluded.stripe_fee_cents, payments.stripe_fee_cents);
end;
$$;

revoke all on function public.record_payment(
  text, uuid, uuid, uuid, uuid, integer, bigint, bigint, integer, integer)
  from public, anon, authenticated;
grant execute on function public.record_payment(
  text, uuid, uuid, uuid, uuid, integer, bigint, bigint, integer, integer)
  to service_role;


-- ── 5. event_ledger : commission = 3 % du conservé + 0,99 $ par billet ──────
--
-- La part fixe ne s'applique QUE si le paiement rapporte encore quelque chose :
-- un paiement entièrement remboursé ou contesté (conservé = 0) ne laisse aucune
-- commission, fixe comprise. C'est la règle convenue — on ne garde pas le
-- 0,99 $ d'un billet qu'on a remboursé.

create or replace function public.event_ledger()
returns table(event_id uuid, gross bigint, withheld bigint,
              stripe_fee bigint, platform_fee bigint)
language sql stable security definer
set search_path = public
as $$
  with per_payment as (
    select
      p.event_id,
      p.gross_cents,
      p.quantity,
      p.stripe_fee_cents,
      p.platform_fee_bps,
      p.platform_fee_fixed_cents,
      -- Tout ce qui n'est plus là : remboursements, et la totalité d'un paiement
      -- contesté. Même effet sur le versement — l'argent n'est plus là.
      case when p.disputed_at is not null then p.gross_cents
           else least(p.refunded_cents, p.gross_cents) end as withheld_cents,
      -- La base de commission : ce qui est réellement conservé au titre des
      -- ventes (ni remboursé/contesté, ni retenu comme frais d'annulation).
      greatest(
        p.gross_cents
          - case when p.disputed_at is not null then p.gross_cents
                 else least(p.refunded_cents, p.gross_cents) end
          - case when p.disputed_at is not null then 0
                 else p.retained_fee_cents end,
        0) as kept_cents
    from public.payments p
  )
  select
    pp.event_id,
    sum(pp.gross_cents)::bigint,
    sum(pp.withheld_cents)::bigint,
    sum(coalesce(pp.stripe_fee_cents, 0))::bigint,
    -- Pourcentage sur le conservé + part fixe par billet (seulement si le
    -- paiement rapporte encore). Le round() n'est que sur la part proportionnelle.
    sum(
      round(pp.kept_cents::numeric * pp.platform_fee_bps / 10000)
      + case when pp.kept_cents > 0
             then pp.quantity * pp.platform_fee_fixed_cents
             else 0 end
    )::bigint
  from per_payment pp
  group by pp.event_id;
$$;
