-- Notifs à l'organisateur sur ses versements. Jusqu'ici seul l'admin était
-- prévenu d'une retenue, et personne ne disait à l'organisateur que son argent
-- était parti. Deux ajouts, tous deux déclenchant le push via le webhook sur
-- public.notifications :
--   (1) retenue : prévenir l'organisateur, en même temps que l'admin, dans la
--       même boucle dédupliquée (une seule alerte par événement) ;
--   (2) versé : un déclencheur sur event_payouts prévient l'organisateur quand
--       le statut passe à 'paid'.

-- (1) alert_payout_holds : identique, plus une notification à l'organisateur.
-- Le message qu'il reçoit est le sien (« ton versement est en attente »), pas
-- celui de l'admin (« libère ou bloque ») : il ne décide rien, il attend.
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

    -- L'organisateur, dans sa langue. Le délai de retenue n'est pas une
    -- punition : on le dit en clair pour qu'il ne croie pas l'argent perdu.
    insert into public.notifications (user_id, type, title, body, event_id)
    select p.id, 'payout_held',
           case when p.language = 'fr' then 'Versement en attente'
                else 'Payout on hold' end,
           case
             when v_reason = 'no_scans' and p.language = 'fr'
               then 'Ton versement pour « ' || v_ev.title || ' » est en attente : aucun billet n''a été scanné à l''entrée.'
             when v_reason = 'no_scans'
               then 'Your payout for "' || v_ev.title || '" is on hold: no ticket was scanned at the door.'
             when p.language = 'fr'
               then 'Ton premier versement (« ' || v_ev.title || ' ») est en vérification — c''est automatique pour un premier événement payant.'
             else 'Your first payout ("' || v_ev.title || '") is under review — this is automatic for a first paid event.'
           end,
           v_ev.id
    from public.profiles p
    where p.id = v_ev.created_by;

    v_n := v_n + 1;
  end loop;
  return v_n;
end;
$$;
revoke all on function private.alert_payout_holds() from public, anon, authenticated;

-- (2) Versé : prévenir l'organisateur quand le virement part. On se déclenche
-- sur le passage à 'paid' uniquement (insert direct en 'paid', ou update
-- pending -> paid), jamais deux fois pour le même versement. SECURITY DEFINER
-- parce que l'écriture dans notifications vient du déclencheur, pas d'un appel
-- authentifié.
create or replace function public.notify_organizer_paid()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_lang   text;
  v_title  text;
  v_amount text;
begin
  if new.status <> 'paid' then
    return new;
  end if;
  if tg_op = 'UPDATE' and old.status = 'paid' then
    return new;
  end if;
  if new.organizer_id is null then
    return new;
  end if;

  select language into v_lang from public.profiles where id = new.organizer_id;
  select title into v_title from public.events where id = new.event_id;
  -- Montant NET en dollars. L'argent est en cents partout ; la conversion
  -- n'a lieu qu'ici, pour l'affichage dans la notification.
  v_amount := trim(to_char(new.net_cents::numeric / 100, 'FM999999990.00'));

  insert into public.notifications (user_id, type, title, body, event_id)
  values (
    new.organizer_id,
    'payout_paid',
    case when v_lang = 'fr' then 'Versement envoyé 🎉' else 'Payout sent 🎉' end,
    case when v_lang = 'fr'
      then 'Ton versement de ' || replace(v_amount, '.', ',') || ' $ pour « ' || coalesce(v_title, 'ton événement') || ' » est parti.'
      else 'Your payout of $' || v_amount || ' for "' || coalesce(v_title, 'your event') || '" is on its way.'
    end,
    new.event_id
  );
  return new;
end;
$$;

drop trigger if exists notify_organizer_paid on public.event_payouts;
create trigger notify_organizer_paid
  after insert or update of status on public.event_payouts
  for each row execute function public.notify_organizer_paid();
