-- Un evenement ne s'annule (ou ne se retablit) que par les fonctions prevues.
--
-- ── Le trou ─────────────────────────────────────────────────────────────────
--
-- La seule politique de mise a jour d'`events` est « c'est ton evenement ».
-- Elle laissait donc un organisateur passer son evenement a `cancelled` en
-- ecrivant directement dans la table — sans `cancel_event`, donc sans
-- rembourser personne. Trouve le 2026-10-07 : « Stripe Payout » etait annule
-- avec trois billets payes encore valides et 45 $ jamais rendus. (Annule le
-- 1er octobre, avant que l'annulation ne rembourse ; mais la porte, elle,
-- etait toujours ouverte.) Et l'inverse : « desannuler » un evenement deja
-- rembourse le remettait en vente.
--
-- ── La garde ────────────────────────────────────────────────────────────────
--
-- Tout passage vers ou depuis `cancelled` venant directement d'une session
-- (`authenticated`, `anon`) est refuse. Les chemins prevus passent : ce sont
-- des fonctions SECURITY DEFINER (`cancel_event`, `restore_cancelled_event`,
-- `delete_my_account_data`), executees sous leur proprietaire, et le
-- declencheur voit ce proprietaire, pas la session. Publier et depublier
-- (`published` <-> `draft`) restent des mises a jour directes, comme avant.
--
-- Ce declencheur n'est PAS SECURITY DEFINER, expres : il doit voir qui ecrit.

create or replace function public.events_guard_cancellation()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.status is distinct from old.status
     and (new.status = 'cancelled' or old.status = 'cancelled')
     and current_user in ('authenticated', 'anon') then
    raise exception 'use_cancel_event';
  end if;
  return new;
end;
$$;

revoke all on function public.events_guard_cancellation() from public, anon, authenticated;

drop trigger if exists events_guard_cancellation on public.events;
create trigger events_guard_cancellation
  before update of status on public.events
  for each row execute function public.events_guard_cancellation();

-- ── L'ecran des versements ──────────────────────────────────────────────────
--
-- Reprise de 20260927000000 (identique a la production, verifie le
-- 2026-10-07) ; seul le statut change.

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
    -- Annule sans versement : jamais « a venir ». L'ecran affichait 41,34 $
    -- « Upcoming » pour un evenement annule, qui ne sera jamais verse.
    case
      when pay.status is not null then pay.status
      when coalesce(e.status, 'published') = 'cancelled' then 'cancelled'
      else 'pending'
    end,
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
