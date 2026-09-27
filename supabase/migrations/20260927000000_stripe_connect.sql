-- =============================================================================
-- HAPPYN — Stripe Connect : payer les organisateurs
-- =============================================================================
-- Aujourd'hui l'argent d'un billet arrive sur le compte Stripe de HAPPYN et
-- s'y arrête. Il n'existe aucun moyen de le reverser à l'organisateur autrement
-- qu'à la main, et rien en base ne dit combien lui est dû. C'est le trou que
-- cette migration ferme.
--
-- ── Le choix de fond : « separate charges and transfers » ────────────────────
--
-- Stripe Connect propose trois montages. Celui retenu encaisse la totalité sur
-- le compte HAPPYN, puis crée un virement vers l'organisateur quand NOUS le
-- décidons. Les deux autres (destination charges, direct charges) envoient
-- l'argent au moment de l'achat.
--
-- Ce n'est pas un détail technique, c'est la protection de l'acheteur. Un
-- organisateur payé à la vente peut encaisser et ne jamais tenir l'événement ;
-- il faudrait alors récupérer l'argent sur un compte déjà vidé. En gardant les
-- fonds jusqu'après la date, un remboursement reste toujours possible — et
-- `cancel-ticket` continue de fonctionner sans modification, puisqu'il
-- rembourse depuis le solde de la plateforme.
--
-- La contrepartie est réelle et doit être assumée : HAPPYN est le marchand
-- officiel. C'est HAPPYN qui apparaît sur le relevé bancaire, qui porte les
-- contestations de carte, et qui est redevable des taxes de vente sur la
-- commission. Voir docs/LANCEMENT.md.
--
-- Conséquence utile pour l'inscription : comme l'encaissement n'a jamais lieu
-- sur le compte de l'organisateur, celui-ci n'a besoin que de la capacité
-- `transfers` — pas `card_payments`. Stripe lui demande donc beaucoup moins de
-- pièces qu'à un vrai marchand.
-- =============================================================================


-- ── 1. La commission, figée par événement ───────────────────────────────────
--
-- En points de base (1/100 de pourcent) : 500 = 5 %. Les entiers évitent les
-- surprises d'arrondi des flottants sur de l'argent.
--
-- ⚠️ 500 EST UN PLACEHOLDER. Le taux relève d'une décision d'affaires, pas
--    d'un choix technique — à trancher avant la première vente réelle.

create or replace function public.platform_fee_bps()
returns integer
language sql
immutable
as $$ select 500 $$;

comment on function public.platform_fee_bps() is
  'Commission HAPPYN en points de base. Changer ici ne touche que les '
  'evenements crees ensuite : les anciens gardent le taux accepte.';

alter table public.events
  add column if not exists platform_fee_bps integer not null
    default public.platform_fee_bps();

comment on column public.events.platform_fee_bps is
  'Commission figee a la creation. Un organisateur doit pouvoir compter sur le '
  'taux qu''il a accepte, meme si la plateforme change le sien ensuite.';

-- Le taux ne doit pas être écrit par le client : les policies de `events`
-- autorisent l'organisateur à insérer et modifier SON événement, donc sans ce
-- verrou n'importe qui pourrait se mettre à 0 %. Le trigger écrase la valeur à
-- l'insertion et la rend immuable ensuite.
create or replace function public.events_lock_fee()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'INSERT' then
    new.platform_fee_bps := public.platform_fee_bps();
  else
    new.platform_fee_bps := old.platform_fee_bps;
  end if;
  return new;
end;
$$;

drop trigger if exists events_lock_fee on public.events;
create trigger events_lock_fee
  before insert or update on public.events
  for each row execute function public.events_lock_fee();


-- ── 2. Le délai de retenue ──────────────────────────────────────────────────
--
-- Trois jours après la fin de l'événement. La fenêtre d'annulation se ferme
-- avant le début (`events.cancellation_hours`), donc au moment du versement
-- plus aucun remboursement ne peut être demandé depuis l'app : le net est
-- définitif. Les trois jours laissent en plus le temps à un problème de se
-- signaler avant que l'argent ne soit parti.

create or replace function public.payout_delay_days()
returns integer
language sql
immutable
as $$ select 3 $$;


-- ── 3. Le compte connecté de l'organisateur ─────────────────────────────────
--
-- Miroir local de l'état côté Stripe, tenu par les fonctions Edge. On ne lui
-- fait pas confiance pour décider d'un virement — `run-payouts` relit Stripe —
-- mais il permet à l'app d'afficher où en est l'inscription sans appeler Stripe
-- à chaque ouverture d'écran, et à `create-payment-intent` de refuser une vente
-- qu'on ne pourrait pas reverser.

create table if not exists public.stripe_accounts (
  user_id           uuid primary key references auth.users(id) on delete cascade,
  account_id        text not null unique,
  -- `transfers_enabled` est le seul drapeau qui autorise un virement. Les deux
  -- autres servent à expliquer à l'organisateur ce qu'il lui reste à faire.
  transfers_enabled boolean not null default false,
  payouts_enabled   boolean not null default false,
  details_submitted boolean not null default false,
  -- Renseigné par Stripe quand le compte est bloqué (pièce manquante, refus de
  -- vérification). Affiché tel quel serait illisible ; sert à savoir qu'il faut
  -- renvoyer la personne vers le formulaire.
  disabled_reason   text,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

alter table public.stripe_accounts enable row level security;

-- Lecture de sa propre ligne seulement : savoir qui a un compte Connect, c'est
-- savoir qui vend, et ça ne regarde personne d'autre.
drop policy if exists "own stripe account read" on public.stripe_accounts;
create policy "own stripe account read" on public.stripe_accounts
  for select to authenticated
  using (auth.uid() = user_id);

-- Aucune policy d'écriture, volontairement : seules les fonctions Edge en
-- service_role écrivent ici. Un client qui pourrait poser
-- `transfers_enabled = true` se ferait virer de l'argent sans vérification.
--
-- La RLS suffirait, mais on retire aussi les droits d'écriture au niveau des
-- privilèges. Deux verrous indépendants : si une policy était un jour ajoutée
-- par erreur, le `revoke` tiendrait encore.
revoke insert, update, delete on public.stripe_accounts from anon, authenticated;
grant select on public.stripe_accounts to authenticated;


-- ── 4. Le registre des paiements ────────────────────────────────────────────
--
-- Jusqu'ici, ce qu'un acheteur avait payé n'existait que chez Stripe. La base
-- ne gardait qu'un `payment_intent_id` sur les billets — donc impossible de
-- répondre à « combien dois-je à cet organisateur ? » sans interroger l'API.
--
-- Ce registre est la colonne vertébrale de trois choses : le calcul des
-- versements, l'écran de revenus de l'organisateur, et la réconciliation le
-- jour où un paiement réussit sans que le billet soit émis.

create table if not exists public.payments (
  payment_intent_id text primary key,
  -- Volontairement SANS clé étrangère vers `events`, et c'est le point le plus
  -- important de cette table. Un registre comptable ne doit pas s'effacer parce
  -- qu'on a supprimé un événement : le fait que de l'argent a changé de mains
  -- reste vrai, et c'est la seule trace qui permet de répondre à un acheteur ou
  -- au fisc des années plus tard. Un `on delete cascade` ici transformerait une
  -- suppression d'événement en destruction de preuve.
  event_id          uuid not null,
  ticket_type_id    uuid,
  -- Ceux-là gardent leur clé étrangère : la suppression d'un compte est un droit
  -- (Loi 25), et `set null` la respecte tout en laissant la ligne comptable —
  -- avec un montant, une date, et plus personne de nommé.
  organizer_id      uuid references auth.users(id) on delete set null,
  buyer_id          uuid references auth.users(id) on delete set null,
  quantity          integer not null,
  -- En cents, comme Stripe. Stocker des dollars en numeric obligerait à
  -- reconvertir à chaque appel d'API, et c'est là que les erreurs d'un cent
  -- apparaissent.
  gross_cents       bigint not null,
  -- Frais réels prélevés par Stripe sur CE paiement, lus sur la
  -- `balance_transaction`. Pas estimés : le barème varie (carte étrangère,
  -- Amex), et une estimation ferait un écart permanent dans les comptes.
  stripe_fee_cents  bigint,
  -- Le taux au moment de l'achat, recopié depuis l'événement. Redondant en
  -- apparence, mais c'est ce qui rend le registre auto-suffisant : recalculer
  -- un versement ne dépend plus d'une colonne qui a pu bouger depuis.
  platform_fee_bps  integer not null,
  -- Cumulatif et ABSOLU, pas incrémental : Stripe envoie `amount_refunded`,
  -- déjà cumulé. Un `+=` compterait deux fois si le webhook est rejoué.
  refunded_cents    bigint not null default 0,
  -- Contestation de carte en cours. Dès qu'un acheteur conteste, Stripe retire
  -- l'argent du solde de la plateforme immédiatement, avant tout examen. Verser
  -- ce montant à l'organisateur pendant ce temps reviendrait à payer deux fois :
  -- une fois à la banque de l'acheteur, une fois à l'organisateur.
  --
  -- Un paiement contesté compte donc comme non encaissé tant que ce n'est pas
  -- réglé. Remis à `null` si la contestation est gagnée.
  disputed_at       timestamptz,
  created_at        timestamptz not null default now()
);

create index if not exists payments_event_idx on public.payments (event_id);
create index if not exists payments_organizer_idx on public.payments (organizer_id);

alter table public.payments enable row level security;

-- Aucune policy : le registre est un livre de comptes, pas une donnée
-- d'application. L'organisateur en voit l'agrégat via `my_payouts()`, l'acheteur
-- voit ses billets. Personne n'a besoin des lignes brutes.
--
-- Et aucun droit non plus : une ligne de registre nomme un acheteur, un montant
-- et un moyen de paiement. Sans policy la RLS bloque déjà tout, mais le
-- `revoke all` rend l'intention impossible à défaire par accident.
revoke all on public.payments from anon, authenticated;


-- ── 5. Les versements ───────────────────────────────────────────────────────
--
-- Un seul versement par événement (`unique`), ce qui sert aussi de garde-fou :
-- deux exécutions concurrentes de `run-payouts` ne peuvent pas payer deux fois.
-- Les montants y sont FIGÉS au moment du calcul — un versement est une trace
-- comptable, il ne doit pas changer parce qu'une ligne du registre a bougé.

create table if not exists public.event_payouts (
  id                 uuid primary key default gen_random_uuid(),
  -- Sans clé étrangère, pour la même raison que `payments.event_id` : la preuve
  -- qu'un organisateur a été payé doit survivre à la suppression de l'événement.
  event_id           uuid not null unique,
  organizer_id       uuid references auth.users(id) on delete set null,
  account_id         text not null,
  gross_cents        bigint not null,
  refunded_cents     bigint not null,
  stripe_fee_cents   bigint not null,
  platform_fee_cents bigint not null,
  net_cents          bigint not null,
  -- pending : ligne réservée, virement pas encore confirmé par Stripe.
  -- paid    : `transfer_id` renseigné.
  -- failed  : Stripe a refusé ; `failure_reason` dit pourquoi, à reprendre.
  -- skipped : rien à verser (tout remboursé, ou net à zéro).
  status             text not null default 'pending'
                       check (status in ('pending', 'paid', 'failed', 'skipped')),
  transfer_id        text unique,
  failure_reason     text,
  created_at         timestamptz not null default now(),
  paid_at            timestamptz
);

create index if not exists event_payouts_organizer_idx
  on public.event_payouts (organizer_id);

alter table public.event_payouts enable row level security;

drop policy if exists "own payouts read" on public.event_payouts;
create policy "own payouts read" on public.event_payouts
  for select to authenticated
  using (auth.uid() = organizer_id);

-- Écriture réservée au service_role (`run-payouts`) : un organisateur qui
-- pourrait passer une ligne en `paid` se déclarerait payé lui-même.
revoke insert, update, delete on public.event_payouts from anon, authenticated;
grant select on public.event_payouts to authenticated;


-- ── 6. Écriture du registre, depuis le webhook ──────────────────────────────
--
-- Appelée en service_role par `stripe-webhook`. Idempotente : Stripe rejoue ses
-- webhooks, et un `insert` nu ferait échouer le second appel — donc renverrait
-- une erreur à Stripe, qui rejouerait encore.

create or replace function public.record_payment(
  p_payment_intent_id text,
  p_event_id          uuid,
  p_organizer_id      uuid,
  p_buyer_id          uuid,
  p_ticket_type_id    uuid,
  p_quantity          integer,
  p_gross_cents       bigint,
  p_stripe_fee_cents  bigint,
  p_platform_fee_bps  integer
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.payments (
    payment_intent_id, event_id, organizer_id, buyer_id, ticket_type_id,
    quantity, gross_cents, stripe_fee_cents, platform_fee_bps
  ) values (
    p_payment_intent_id, p_event_id, p_organizer_id, p_buyer_id, p_ticket_type_id,
    p_quantity, p_gross_cents, p_stripe_fee_cents, p_platform_fee_bps
  )
  on conflict (payment_intent_id) do update
    -- Le montant brut ne se corrige pas : s'il différait, c'est un incident, pas
    -- une mise à jour. Seuls les frais peuvent arriver en retard (la
    -- `balance_transaction` n'est pas toujours disponible au premier webhook).
    set stripe_fee_cents = coalesce(
          excluded.stripe_fee_cents, payments.stripe_fee_cents);
end;
$$;

-- On retire `authenticated` en plus de `public` et `anon` : écrire dans le
-- registre n'appartient qu'au webhook. Le `grant` explicite à `service_role`
-- évite de dépendre des privilèges par défaut du projet.
revoke all on function public.record_payment(
  text, uuid, uuid, uuid, uuid, integer, bigint, bigint, integer)
  from public, anon, authenticated;
grant execute on function public.record_payment(
  text, uuid, uuid, uuid, uuid, integer, bigint, bigint, integer)
  to service_role;

-- `amount_refunded` de Stripe est déjà cumulé depuis le début : on le pose tel
-- quel. `greatest` protège contre un webhook arrivé dans le désordre, qui
-- ferait reculer le total remboursé.
create or replace function public.record_refund(
  p_payment_intent_id text,
  p_refunded_cents    bigint
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.payments
     set refunded_cents = greatest(refunded_cents, p_refunded_cents)
   where payment_intent_id = p_payment_intent_id;
end;
$$;

revoke all on function public.record_refund(text, bigint)
  from public, anon, authenticated;
grant execute on function public.record_refund(text, bigint) to service_role;

-- Ouverture et clôture d'une contestation. `p_open = false` n'est appelé que
-- pour une contestation GAGNÉE : perdue, l'argent est parti pour de bon et le
-- paiement doit rester neutralisé.
create or replace function public.record_dispute(
  p_payment_intent_id text,
  p_open              boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.payments
     set disputed_at = case when p_open then coalesce(disputed_at, now()) else null end
   where payment_intent_id = p_payment_intent_id;
end;
$$;

revoke all on function public.record_dispute(text, boolean)
  from public, anon, authenticated;
grant execute on function public.record_dispute(text, boolean) to service_role;


-- ── 7. Peut-on vendre pour cet organisateur ? ───────────────────────────────
--
-- Vendre un billet payant sans pouvoir reverser l'argent, c'est encaisser une
-- dette qu'on ne sait pas honorer. `create-payment-intent` appelle ceci avant
-- de créer le PaymentIntent.

create or replace function public.organizer_is_payable(p_organizer uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select coalesce(
    (select transfers_enabled and disabled_reason is null
       from public.stripe_accounts where user_id = p_organizer),
    false);
$$;

revoke all on function public.organizer_is_payable(uuid) from public, anon;
grant execute on function public.organizer_is_payable(uuid) to authenticated;


-- ── 8. L'arithmétique, à un seul endroit ────────────────────────────────────
--
-- Deux appelants ont besoin des mêmes totaux : l'écran de l'organisateur et le
-- versement automatique. Recopier le calcul dans les deux garantissait qu'ils
-- finiraient par se contredire — et un écran qui annonce un montant différent de
-- celui viré est un litige.
--
-- Ce n'est pas une vue : une vue sur `payments` appartiendrait à `postgres` et
-- contournerait donc la RLS de la table pour tout utilisateur autorisé à la
-- lire. Une fonction qu'aucun client ne peut exécuter n'a pas ce problème.

create or replace function public.event_ledger()
returns table (
  event_id     uuid,
  gross        bigint,
  withheld     bigint,
  stripe_fee   bigint,
  platform_fee bigint
)
language sql
security definer
stable
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
    -- conservé, puis s'additionne. L'appliquer au total ferait payer une
    -- commission sur des billets remboursés.
    sum(round(
      greatest(
        p.gross_cents
          - case when p.disputed_at is not null then p.gross_cents
                 else least(p.refunded_cents, p.gross_cents) end,
        0)::numeric
      * p.platform_fee_bps / 10000))::bigint
  from public.payments p
  group by p.event_id;
$$;

revoke all on function public.event_ledger()
  from public, anon, authenticated;


-- ── 9. Ce que l'organisateur voit ───────────────────────────────────────────
--
-- Son propre état d'inscription. Une ligne absente n'est pas une erreur : ça
-- veut dire « jamais commencé », et l'écran doit proposer de démarrer.

create or replace function public.my_payout_account()
returns table (
  has_account       boolean,
  transfers_enabled boolean,
  payouts_enabled   boolean,
  details_submitted boolean,
  blocked           boolean
)
language sql
security definer
stable
set search_path = public
as $$
  select
    a.user_id is not null,
    coalesce(a.transfers_enabled, false),
    coalesce(a.payouts_enabled, false),
    coalesce(a.details_submitted, false),
    a.disabled_reason is not null
  from (select auth.uid() as uid) me
  left join public.stripe_accounts a on a.user_id = me.uid;
$$;

revoke all on function public.my_payout_account() from public, anon;
grant execute on function public.my_payout_account() to authenticated;

-- Combien, par événement, et où ça en est.
--
-- Deux sources selon l'état : une fois le versement calculé, on affiche SES
-- chiffres figés ; avant, on les calcule en direct depuis le registre. Afficher
-- un calcul en direct après paiement ferait bouger un montant déjà encaissé.
--
-- `greatest(..., 0)` sur le net : un événement entièrement remboursé laisse les
-- frais Stripe à la charge de la plateforme (Stripe ne rend pas sa commission
-- sur un remboursement). Sans ce plancher, le net serait négatif — et un
-- virement négatif n'existe pas.

create or replace function public.my_payouts()
returns table (
  event_id           uuid,
  event_title        text,
  event_end          timestamptz,
  gross_cents        bigint,
  refunded_cents     bigint,
  stripe_fee_cents   bigint,
  platform_fee_cents bigint,
  net_cents          bigint,
  status             text,
  paid_at            timestamptz,
  eligible_at        timestamptz
)
language sql
security definer
stable
set search_path = public
as $$
  select
    e.id,
    e.title,
    e.end_date,
    coalesce(pay.gross_cents,        l.gross)::bigint,
    coalesce(pay.refunded_cents,     l.withheld)::bigint,
    coalesce(pay.stripe_fee_cents,   l.stripe_fee)::bigint,
    coalesce(pay.platform_fee_cents, l.platform_fee)::bigint,
    coalesce(
      pay.net_cents,
      greatest(l.gross - l.withheld - l.stripe_fee - l.platform_fee, 0)
    )::bigint,
    coalesce(pay.status, 'pending'),
    pay.paid_at,
    e.end_date + (public.payout_delay_days() || ' days')::interval
  from public.events e
  -- `join` et non `left join` : un événement qui n'a rien encaissé n'a rien à
  -- montrer ici. L'écran liste des versements, pas des événements.
  join public.event_ledger() l on l.event_id = e.id
  left join public.event_payouts pay on pay.event_id = e.id
  where e.created_by = auth.uid()
  order by e.end_date desc nulls last;
$$;

revoke all on function public.my_payouts() from public, anon;
grant execute on function public.my_payouts() to authenticated;


-- ── 10. Ce que `run-payouts` consomme ────────────────────────────────────────
--
-- Les événements terminés depuis plus que le délai de retenue, qui ont encaissé
-- quelque chose, dont l'organisateur est payable, et qui n'ont pas déjà une
-- ligne de versement.
--
-- Les montants sont calculés ici plutôt que dans la fonction Edge : c'est la
-- base qui détient le registre, et refaire l'arithmétique en TypeScript
-- donnerait deux vérités à maintenir.

create or replace function public.events_due_for_payout()
returns table (
  event_id           uuid,
  event_title        text,
  organizer_id       uuid,
  account_id         text,
  gross_cents        bigint,
  refunded_cents     bigint,
  stripe_fee_cents   bigint,
  platform_fee_cents bigint,
  net_cents          bigint
)
language sql
security definer
stable
set search_path = public
as $$
  select
    e.id,
    e.title,
    e.created_by,
    a.account_id,
    l.gross,
    l.withheld,
    l.stripe_fee,
    l.platform_fee,
    greatest(l.gross - l.withheld - l.stripe_fee - l.platform_fee, 0)::bigint
  from public.events e
  join public.event_ledger() l on l.event_id = e.id
  join public.stripe_accounts a on a.user_id = e.created_by
  left join public.event_payouts pay on pay.event_id = e.id
  where pay.id is null
    and e.end_date is not null
    and e.end_date + (public.payout_delay_days() || ' days')::interval < now()
    and a.transfers_enabled
    and a.disabled_reason is null
  order by e.end_date asc;
$$;

revoke all on function public.events_due_for_payout()
  from public, anon, authenticated;
grant execute on function public.events_due_for_payout() to service_role;


-- ── 11. Réserver le versement avant d'appeler Stripe ────────────────────────
--
-- L'ordre est délibéré et c'est le point le plus délicat du flux. On INSÈRE la
-- ligne `pending` d'abord, puis on demande le virement. L'inverse laisserait,
-- si l'écriture en base échouait après un virement réussi, un organisateur payé
-- sans trace — donc payé une deuxième fois à la prochaine exécution.
--
-- Avec cet ordre, le pire cas est une ligne `pending` sans virement : visible,
-- et rattrapable. L'`unique` sur `event_id` fait le reste du travail.

create or replace function public.claim_payout(
  p_event_id           uuid,
  p_organizer_id       uuid,
  p_account_id         text,
  p_gross_cents        bigint,
  p_refunded_cents     bigint,
  p_stripe_fee_cents   bigint,
  p_platform_fee_cents bigint,
  p_net_cents          bigint
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  insert into public.event_payouts (
    event_id, organizer_id, account_id, gross_cents, refunded_cents,
    stripe_fee_cents, platform_fee_cents, net_cents, status
  ) values (
    p_event_id, p_organizer_id, p_account_id, p_gross_cents, p_refunded_cents,
    p_stripe_fee_cents, p_platform_fee_cents, p_net_cents,
    case when p_net_cents > 0 then 'pending' else 'skipped' end
  )
  -- Déjà réservé par une autre exécution : on ne renvoie rien, l'appelant
  -- passe à l'événement suivant.
  on conflict (event_id) do nothing
  returning id into v_id;

  return v_id;
end;
$$;

revoke all on function public.claim_payout(
  uuid, uuid, text, bigint, bigint, bigint, bigint, bigint)
  from public, anon, authenticated;
grant execute on function public.claim_payout(
  uuid, uuid, text, bigint, bigint, bigint, bigint, bigint) to service_role;

create or replace function public.settle_payout(
  p_payout_id   uuid,
  p_transfer_id text,
  p_failure     text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.event_payouts
     set status         = case when p_transfer_id is not null then 'paid' else 'failed' end,
         transfer_id    = p_transfer_id,
         failure_reason = p_failure,
         paid_at        = case when p_transfer_id is not null then now() else null end
   where id = p_payout_id;
end;
$$;

revoke all on function public.settle_payout(uuid, text, text)
  from public, anon, authenticated;
grant execute on function public.settle_payout(uuid, text, text) to service_role;
