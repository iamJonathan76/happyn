-- Le tableau de bord de l'organisateur : une ligne par événement qu'il a créé,
-- avec son revenu net, ses billets vendus/scannés, et l'état de son versement.
--
-- Pourquoi une fonction SECURITY DEFINER : le net vient d'event_ledger(), qui
-- agrège les paiements de TOUT le monde. On la laisse calculer, puis on ne
-- renvoie QUE les événements dont created_by = auth.uid() — un organisateur ne
-- voit jamais l'argent d'un autre. Le net est en CENTS, comme partout.
--
-- payout_status, lu tel quel par l'app :
--   paid       : déjà versé (paid_at renseigné)
--   none       : événement gratuit, rien à verser
--   manual     : retenu par un admin
--   no_scans   : retenu, aucun billet scanné
--   first_event: retenu, premier événement payant (vérif admin)
--   scheduled  : l'événement n'est pas fini, versement 7 jours après la fin
--   counting   : fini, le délai court (payout_days_left donne le compte à rebours)
--   ready      : délai écoulé, part au prochain versement
create or replace function public.organizer_dashboard(
  p_from timestamptz default null,
  p_to   timestamptz default null
)
returns table (
  event_id         uuid,
  title            text,
  image_url        text,
  start_date       timestamptz,
  end_date         timestamptz,
  is_paid          boolean,
  net_cents        bigint,
  tickets_sold     integer,
  scanned          integer,
  payout_status    text,
  payout_days_left integer,
  paid_at          timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  with mine as (
    select e.*
    from public.events e
    where e.created_by = auth.uid()
      and (p_from is null or coalesce(e.start_date, e.created_at) >= p_from)
      and (p_to   is null or coalesce(e.start_date, e.created_at) <= p_to)
  ),
  enriched as (
    select
      e.id,
      e.title,
      e.image_url,
      e.start_date,
      e.end_date,
      exists (
        select 1 from public.ticket_types tt
        where tt.event_id = e.id and coalesce(tt.price, 0) > 0
      ) as is_paid,
      coalesce(greatest(l.gross - l.withheld - l.stripe_fee - l.platform_fee, 0), 0)::bigint
        as net_cents,
      (select count(*) from public.tickets t
         where t.event_id = e.id and t.status in ('valid', 'used'))::int as tickets_sold,
      (select count(*) from public.tickets t
         where t.event_id = e.id and t.status = 'used')::int as scanned,
      public.payout_hold_reason(e.id, e.created_by) as hold_reason,
      pay.status as payout_row_status,
      pay.paid_at,
      e.end_date + (public.payout_delay_days() || ' days')::interval as due_at,
      coalesce(e.start_date, e.created_at) as sort_key
    from mine e
    left join public.event_ledger() l on l.event_id = e.id
    left join public.event_payouts pay on pay.event_id = e.id
  )
  select
    id, title, image_url, start_date, end_date, is_paid, net_cents,
    tickets_sold, scanned,
    case
      when payout_row_status = 'paid'       then 'paid'
      when not is_paid                      then 'none'
      when hold_reason is not null          then hold_reason
      when end_date is null                 then 'scheduled'
      when now() >= due_at                  then 'ready'
      when now() <  end_date                then 'scheduled'
      else 'counting'
    end as payout_status,
    case
      when end_date is null then null
      else greatest(ceil(extract(epoch from (due_at - now())) / 86400)::int, 0)
    end as payout_days_left,
    paid_at
  from enriched
  order by sort_key desc;
$$;

revoke all on function public.organizer_dashboard(timestamptz, timestamptz)
  from public, anon;
grant execute on function public.organizer_dashboard(timestamptz, timestamptz)
  to authenticated;
