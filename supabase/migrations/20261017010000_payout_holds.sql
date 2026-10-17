-- Versements : 7 jours après la fin, et trois retenues avant que l'argent parte.
--
-- ── Pourquoi ────────────────────────────────────────────────────────────────
-- La politique de paiement publiée promet que « HAPPYN peut retenir un
-- versement le temps de vérifier un événement — par exemple quand aucun billet
-- n'a été lu à l'entrée, ou pour les premiers événements d'un organisateur ».
-- Rien de tel n'existait : seuls les montants contestés étaient retenus, et un
-- faux événement — billets vendus, personne à la porte — était versé comme les
-- autres au bout du délai. Un escroc encaissait et disparaissait.
--
-- ── Les retenues ────────────────────────────────────────────────────────────
--   no_scans    : aucun billet scanné à l'entrée.
--   first_event : l'organisateur n'a encore jamais été payé.
--   manual      : un administrateur a bloqué le versement.
-- Les deux premières sont CALCULÉES, pas stockées : elles valent même pour un
-- appel manuel de run-payouts, et disparaissent dès qu'un administrateur
-- libère l'événement (payout_reviews). Rien n'est libéré par le temps seul.
--
-- ── Le délai ────────────────────────────────────────────────────────────────
-- 7 jours plutôt que 3 : à peu près « 5 jours ouvrables », sans calendrier des
-- fériés (différents en Ontario et au Québec). La fenêtre de notation suit,
-- elle lit la même fonction.

create or replace function public.payout_delay_days()
returns integer
language sql
immutable
set search_path = public
as $$ select 7 $$;

-- Sans clé étrangère vers events, comme event_payouts : la trace d'une
-- décision sur de l'argent doit survivre à la suppression de l'événement.
create table if not exists public.payout_reviews (
  event_id    uuid primary key,
  decision    text not null check (decision in ('released', 'held')),
  reason      text check (char_length(reason) <= 300),
  decided_by  uuid references auth.users(id) on delete set null,
  decided_at  timestamptz not null default now()
);

alter table public.payout_reviews enable row level security;
revoke all on public.payout_reviews from public, anon, authenticated;

-- Pourquoi le versement d'un événement est retenu ; null s'il ne l'est pas.
create or replace function public.payout_hold_reason(p_event uuid, p_organizer uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select case
    when r.decision = 'held' then 'manual'
    when r.decision = 'released' then null
    when not exists (select 1 from public.tickets t
                     where t.event_id = p_event and t.status = 'used') then 'no_scans'
    when not exists (select 1 from public.event_payouts p
                     where p.organizer_id = p_organizer and p.status = 'paid') then 'first_event'
    else null
  end
  from (select 1) one
  left join public.payout_reviews r on r.event_id = p_event;
$$;

revoke all on function public.payout_hold_reason(uuid, uuid) from public, anon, authenticated;

-- Identique à la version en production (comparée le 2026-10-17), plus la
-- dernière condition : un versement retenu n'est pas dû.
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
    and public.payout_hold_reason(e.id, e.created_by) is null
  order by e.end_date asc;
$$;

revoke all on function public.events_due_for_payout() from public, anon, authenticated;
grant execute on function public.events_due_for_payout() to service_role;

-- ── Pour l'administrateur ───────────────────────────────────────────────────
-- Tout ce qui n'est pas encore versé, avec son état :
--   held    : retenu (hold_reason dit pourquoi) — à libérer ou bloquer
--   failed  : Stripe a refusé le virement (failure_reason) — à reprendre
--   waiting : le délai court encore (due_at)
--   ready   : partira au prochain passage
--   no_account : l'organisateur ne peut pas encore recevoir
create or replace function public.admin_payout_queue()
returns table (
  event_id        uuid,
  event_title     text,
  organizer_id    uuid,
  organizer_name  text,
  end_date        timestamptz,
  due_at          timestamptz,
  net_cents       bigint,
  tickets_sold    integer,
  tickets_scanned integer,
  state           text,
  hold_reason     text,
  failure_reason  text
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.i_am_admin() then raise exception 'not_admin'; end if;
  return query
  select
    e.id, e.title, e.created_by, pr.full_name, e.end_date,
    e.end_date + (public.payout_delay_days() || ' days')::interval,
    greatest(l.gross - l.withheld - l.stripe_fee - l.platform_fee, 0)::bigint,
    (select count(*)::int from public.tickets t
      where t.event_id = e.id and t.status in ('valid', 'used')),
    (select count(*)::int from public.tickets t
      where t.event_id = e.id and t.status = 'used'),
    -- « waiting » passe avant « held » : tant que le délai court, il n'y a
    -- rien à décider, mais hold_reason prévient déjà de ce qui attend.
    case
      when pay.status = 'failed' then 'failed'
      when e.end_date + (public.payout_delay_days() || ' days')::interval >= now() then 'waiting'
      when public.payout_hold_reason(e.id, e.created_by) is not null then 'held'
      when a.account_id is null or not a.transfers_enabled or a.disabled_reason is not null then 'no_account'
      else 'ready'
    end,
    public.payout_hold_reason(e.id, e.created_by),
    pay.failure_reason
  from public.events e
  join public.event_ledger() l on l.event_id = e.id
  left join public.stripe_accounts a on a.user_id = e.created_by
  left join public.event_payouts pay on pay.event_id = e.id
  left join public.profiles pr on pr.id = e.created_by
  where (pay.id is null or pay.status = 'failed')
    and coalesce(e.status, 'published') <> 'cancelled'
    and e.end_date is not null
    and e.end_date < now()
  order by
    case when pay.status = 'failed' then 0
         when public.payout_hold_reason(e.id, e.created_by) is not null then 1
         else 2 end,
    e.end_date asc;
end;
$$;

-- Libérer ou bloquer le versement d'un événement. Une décision par événement,
-- remplacée par la suivante ; qui et quand sont gardés.
create or replace function public.admin_set_payout_review(
  p_event    uuid,
  p_decision text,
  p_reason   text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.i_am_admin() then raise exception 'not_admin'; end if;
  if p_decision not in ('released', 'held') then raise exception 'invalid_decision'; end if;
  if exists (select 1 from public.event_payouts p
             where p.event_id = p_event and p.status = 'paid') then
    raise exception 'already_paid';
  end if;
  insert into public.payout_reviews (event_id, decision, reason, decided_by, decided_at)
  values (p_event, p_decision, nullif(trim(p_reason), ''), auth.uid(), now())
  on conflict (event_id) do update
     set decision = excluded.decision, reason = excluded.reason,
         decided_by = excluded.decided_by, decided_at = excluded.decided_at;
end;
$$;

revoke all on function public.admin_payout_queue() from public, anon;
revoke all on function public.admin_set_payout_review(uuid, text, text) from public, anon;
grant execute on function public.admin_payout_queue() to authenticated;
grant execute on function public.admin_set_payout_review(uuid, text, text) to authenticated;

-- ── Prévenir les administrateurs ────────────────────────────────────────────
-- Une fois par événement retenu, quand son versement serait dû : avant, il n'y
-- a rien à décider. Les blocages manuels ne sont pas signalés, l'administrateur
-- les a posés lui-même.
create table if not exists private.payout_hold_alerts (
  event_id uuid primary key,
  sent_at  timestamptz not null default now()
);
revoke all on private.payout_hold_alerts from public, anon, authenticated;

create or replace function private.alert_payout_holds()
returns integer
language plpgsql
security definer
set search_path = private, public
as $$
declare
  v_ev     record;
  v_reason text;
  v_n      integer := 0;
begin
  for v_ev in
    select e.id, e.title, e.created_by
    from public.events e
    join public.event_ledger() l on l.event_id = e.id
    left join public.event_payouts pay on pay.event_id = e.id
    where pay.id is null
      and coalesce(e.status, 'published') <> 'cancelled'
      and e.end_date + (public.payout_delay_days() || ' days')::interval < now()
      and not exists (select 1 from private.payout_hold_alerts x where x.event_id = e.id)
  loop
    v_reason := public.payout_hold_reason(v_ev.id, v_ev.created_by);
    if v_reason is null or v_reason = 'manual' then continue; end if;

    insert into private.payout_hold_alerts (event_id) values (v_ev.id)
    on conflict (event_id) do nothing;
    if not found then continue; end if;

    insert into public.notifications (user_id, type, title, body, event_id)
    select p.id, 'payout_review',
           case when p.language = 'fr' then 'Versement à vérifier : ' || v_ev.title
                else 'Payout to review: ' || v_ev.title end,
           case
             when v_reason = 'no_scans' and p.language = 'fr'
               then 'Aucun billet n''a été scanné à l''entrée. Libère ou bloque le versement.'
             when v_reason = 'no_scans'
               then 'No ticket was scanned at the door. Release or hold the payout.'
             when p.language = 'fr'
               then 'Premier événement payant de cet organisateur. Libère ou bloque le versement.'
             else 'This organizer''s first paid event. Release or hold the payout.'
           end,
           v_ev.id
    from public.profiles p
    where p.is_admin;
    v_n := v_n + 1;
  end loop;
  return v_n;
end;
$$;

revoke all on function private.alert_payout_holds() from public, anon, authenticated;

-- La tâche quotidienne prévient d'abord, puis appelle run-payouts. Identique
-- à la version précédente, plus la première ligne.
create or replace function private.run_payouts_tick()
returns bigint
language plpgsql
security definer
set search_path = private, public, extensions
as $$
declare
  v_url    text := private.setting('payout_hook_url');
  v_secret text := private.setting('payout_hook_secret');
begin
  perform private.alert_payout_holds();
  if v_url is null or v_secret is null then
    raise notice 'run_payouts_tick : payout_hook_url / payout_hook_secret absents, rien n''est appele';
    return null;
  end if;
  return net.http_post(
    url     := v_url,
    headers := jsonb_build_object(
                 'Content-Type',    'application/json',
                 'x-happyn-secret', v_secret
               ),
    body    := '{}'::jsonb,
    timeout_milliseconds := 60000
  );
end;
$$;

revoke all on function private.run_payouts_tick() from public, anon, authenticated;
