-- Fermer la course entre l'annulation d'un evenement et son versement.
--
-- Les deux fonctions etaient correctes isolement, et dangereuses ensemble :
-- aucune des deux ne savait que l'autre existait.
--
-- ── Le chemin qui fait payer deux fois ──────────────────────────────────────
--
--   1. L'evenement a lieu, il se termine.
--   2. Trois jours passent, `run-payouts` vire 450 $ a l'organisateur.
--   3. L'organisateur annule l'evenement.
--   4. `cancel-event` rembourse les 25 acheteurs depuis le solde de la
--      plateforme.
--
-- HAPPYN paie deux fois, et l'argent de l'organisateur est deja sur son compte
-- bancaire — irrecuperable sans son accord.
--
-- ── Et le meme chemin a l'envers ────────────────────────────────────────────
--
-- `events_due_for_payout()` ne regardait pas le statut de l'evenement. Un
-- evenement ANNULE restait donc payable. Pire : les remboursements ne
-- reduisent le versement que via `refunded_cents`, pose par le webhook
-- `charge.refunded`. Entre l'annulation et l'arrivee de ces webhooks — ou si
-- un remboursement a echoue — le registre montre encore un net positif, et
-- l'organisateur serait paye pour un evenement qui n'a pas eu lieu.

-- ── Garde 1 : on n'annule pas ce qui a deja ete verse ───────────────────────
--
-- `pending` compte autant que `paid` : la ligne est posee AVANT l'appel a
-- Stripe (c'est la reservation qui empeche le double virement), donc un
-- `pending` peut etre un virement en cours de route.
--
-- `failed` et `skipped` n'empechent rien : dans les deux cas aucun argent
-- n'est parti.
--
-- Ce qu'on NE fait PAS : interdire d'annuler un evenement deja termine. Ce
-- serait plus simple, et ce serait une faute. Un organisateur qui ne s'est pas
-- presente doit pouvoir rembourser ses acheteurs le lendemain — c'est
-- exactement a quoi servent les trois jours de retenue. La bonne frontiere est
-- le VERSEMENT, pas la date de fin.

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

  if exists (
    select 1 from public.event_payouts
    where event_id = p_event
      and status in ('pending', 'paid')
  ) then
    raise exception 'already_paid_out';
  end if;

  update public.events
     set status = 'cancelled'
   where id = p_event
     and status <> 'cancelled';
end;
$$;

revoke all on function public.cancel_event(uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.cancel_event(uuid, uuid) to service_role;

-- ── Garde 2 : on ne verse pas pour un evenement annule ──────────────────────
--
-- Sans elle, la course existait dans l'autre sens. Et cette garde ne depend
-- pas des webhooks : elle lit le statut de l'evenement, qui est pose dans la
-- meme transaction que l'annulation.

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
    and coalesce(e.status, 'published') <> 'cancelled'
    and e.end_date is not null
    and e.end_date + (public.payout_delay_days() || ' days')::interval < now()
    and a.transfers_enabled
    and a.disabled_reason is null
  order by e.end_date asc;
$$;

revoke all on function public.events_due_for_payout()
  from public, anon, authenticated;
grant execute on function public.events_due_for_payout() to service_role;
